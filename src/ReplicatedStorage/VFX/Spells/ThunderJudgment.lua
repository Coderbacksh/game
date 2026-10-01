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

	Boss-tier layers: smaller pre-strikes hammer the area around the target
	before the main bolt; the main impact adds impact frames, focus lines,
	an FOV punch, a white core sphere in a glowing ForceField shell, a ring
	of rocks erupting from the ground, and static electricity that keeps
	crackling over the crater for Residual.Duration seconds.

	Bouncing sparks are client-local unanchored parts removed by Debris.
]]

local Config = require(script.Parent.Parent.Config)
local Util = script.Parent.Parent.Util
local CameraShake = require(Util.CameraShake)
local Emit = require(Util.Emit)
local Flash = require(Util.Flash)
local FocusLines = require(Util.FocusLines)
local GroundDecal = require(Util.GroundDecal)
local ImpactFrame = require(Util.ImpactFrame)
local Lightning = require(Util.Lightning)
local RockRing = require(Util.RockRing)
local Sphere = require(Util.Sphere)
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
	local pre = C.PreStrikes
	local stormTime = C.GatherTime + pre.Count * pre.Interval + C.MainBolt.Duration
	local cloudHost = Emit.anchor(CFrame.new(sky), stormTime + C.Clouds.Spec.Lifetime.Max, C.CloudSize)
	local clouds = Emit.emitter(cloudHost, C.Clouds.Spec)
	Emit.pulse(clouds, C.Clouds.Count, C.Clouds.Interval, stormTime)
	Lightning.Crackle(sky, C.CloudCrackle.Radius, C.CloudCrackle.Count, C.CloudCrackle.Bolt)

	task.wait(C.GatherTime)

	-- Pre-strikes scattered around the target.
	local preBolt = table.clone(C.MainBolt)
	preBolt.Width = C.MainBolt.Width * pre.WidthScale
	for _ = 1, pre.Count do
		local angle = Emit.random(0, math.pi * 2)
		local spot =
			Emit.groundAt(ground + Vector3.new(math.cos(angle), 0, math.sin(angle)) * Emit.random(0, pre.Scatter))
		Lightning.Strike(sky + (spot - ground) * Vector3.new(1, 0, 1), spot, preBolt)
		Flash.Impact(spot, pre.Flash)
		Emit.burstAt(CFrame.new(spot), pre.Sparks)
		task.wait(pre.Interval)
	end

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

	-- Boss-tier layers.
	ImpactFrame.Preset(C.Impact, impact)
	FocusLines.Play(impact, C.Focus)
	CameraShake.PunchPreset(C.Punch, impact)
	Sphere.Layers(impact, C.Spheres)
	RockRing.Ring(ground, C.Rocks)

	-- Residual static crackling over the crater.
	local residual = C.Residual
	local timer = residual.Interval
	Emit.step(residual.Duration, function(_alpha, dt)
		timer += dt
		if timer >= residual.Interval then
			timer = 0
			for _ = 1, residual.Count do
				local a = Emit.random(0, math.pi * 2)
				local from = ground + Vector3.new(math.cos(a), 0, math.sin(a)) * Emit.random(0, residual.Radius)
				local b = a + Emit.random(-residual.AngleWander, residual.AngleWander)
				local to = from
					+ Vector3.new(math.cos(b), 0, math.sin(b))
						* Emit.random(residual.ArcLengthMin, residual.ArcLengthMax)
				local lift = Vector3.yAxis * C.GroundArcs.Lift
				Lightning.Strike(Emit.groundAt(from) + lift, Emit.groundAt(to) + lift, residual.Bolt)
			end
		end
		return false
	end)
end

-- Typed export: the checker verifies this module matches Types.SpellModule.
local module: Types.SpellModule = { Play = ThunderJudgment.Play }
return module
