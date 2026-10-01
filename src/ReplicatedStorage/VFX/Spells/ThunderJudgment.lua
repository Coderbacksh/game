--!strict
--[[
	ThunderJudgment (key 4)
	=======================
	1. Ink-smoke clouds gather (inward-swirling smoke pulses) high above the
	   target, with faint white arcs flickering inside them.
	2. A thick jagged white bolt slams down: segmented Beams with random
	   offsets, rebuilt every FlickerInterval for flicker, with branches and
	   a soft wide glow bolt behind it.
	3. Impact: white flash + horizontal flare streak, branching arcs
	   crawling along the ground, scorched crack decal, spark burst and
	   small neon sparks that physically bounce on the ground.

	Bouncing sparks are client-local unanchored parts removed by Debris.
]]

local Config = require(script.Parent.Parent.Config)
local Util = script.Parent.Parent.Util
local CameraShake = require(Util.CameraShake)
local Emit = require(Util.Emit)
local Flash = require(Util.Flash)
local GroundDecal = require(Util.GroundDecal)
local Lightning = require(Util.Lightning)
local Types = require(Util.Types)

local C = Config.Spells.ThunderJudgment.VFX

local ThunderJudgment = {}

local function bouncingSparks(position: Vector3)
	local params = C.BounceSparks
	local folder = Emit.folder()
	for _ = 1, params.Count do
		local spark = Instance.new("Part")
		spark.Name = "BounceSpark"
		spark.Size = params.Size
		spark.Color = params.Color
		spark.Material = params.Material
		spark.Shape = Enum.PartType.Ball
		spark.CastShadow = false
		spark.CanQuery = false
		spark.CanTouch = false
		spark.CanCollide = true
		spark.CustomPhysicalProperties = PhysicalProperties.new(
			params.Density,
			params.Friction,
			params.Elasticity,
			params.FrictionWeight,
			params.ElasticityWeight
		)
		spark.CFrame = CFrame.new(position + Vector3.yAxis * Config.Debris.SpawnHeight)
		spark.Parent = folder

		local angle = Emit.random(0, math.pi * 2)
		local speed = Emit.random(params.SpeedMin, params.SpeedMax)
		spark.AssemblyLinearVelocity =
			Vector3.new(math.cos(angle) * speed, Emit.random(params.UpMin, params.UpMax), math.sin(angle) * speed)

		Emit.tween(
			spark,
			params.FadeTime,
			{ Transparency = 1 },
			Enum.EasingStyle.Linear,
			nil,
			params.Lifetime - params.FadeTime
		)
		Emit.cleanup(spark, params.Lifetime)
	end
end

function ThunderJudgment.Play(_character: Model, targetPosition: Vector3)
	local ground = Emit.groundAt(targetPosition)
	local sky = ground + Vector3.yAxis * C.CloudHeight

	-------------------------------------------------------------------
	-- 1. Clouds gather.
	-------------------------------------------------------------------
	local cloudLife = C.GatherTime + C.MainBolt.Duration + C.Clouds.Spec.Lifetime.Max
	local cloudHost = Emit.anchor(CFrame.new(sky), cloudLife, C.CloudSize)
	local clouds = Emit.emitter(cloudHost, C.Clouds.Spec)
	Emit.pulse(clouds, C.Clouds.Count, C.Clouds.Interval, C.GatherTime + C.MainBolt.Duration)
	Lightning.Crackle(sky, C.CloudCrackle.Radius, C.CloudCrackle.Count, C.CloudCrackle.Bolt)

	task.wait(C.GatherTime)

	-------------------------------------------------------------------
	-- 2. The bolt.
	-------------------------------------------------------------------
	Lightning.Strike(sky, ground, C.GlowBolt)
	Lightning.Strike(sky, ground, C.MainBolt)

	-------------------------------------------------------------------
	-- 3. Impact.
	-------------------------------------------------------------------
	local impact = ground + Vector3.yAxis * C.GroundArcs.Lift
	Flash.Impact(impact, C.Flash)
	Emit.burstAt(CFrame.new(impact), C.Sparks)
	Emit.burstAt(CFrame.new(impact), { Spec = Config.Emitters.CoreFlare, Count = 1 })
	Emit.burstAt(CFrame.new(impact), C.Smoke)
	Lightning.GroundArcs(ground, C.GroundArcs)
	GroundDecal.Spawn(ground, C.Decal)
	bouncingSparks(ground)
	CameraShake.Preset(C.Shake, ground)
end

-- Typed export: the checker verifies this module matches Types.SpellModule.
local module: Types.SpellModule = { Play = ThunderJudgment.Play }
return module
