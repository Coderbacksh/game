--!strict
--[[
	FrostRequiem (key 6, accent: pale cyan)
	=======================================
	1. Sharp crystal spikes burst out of the ground one after another in a
	   line from the caster to the target. Each spike is a glassy pale-cyan
	   part; a single Highlight on the spike Model gives them all a white
	   rim glow (one Highlight keeps us far below the engine's limit).
	   Frost mist and snow roll along the floor at every spike.
	2. Impact at the target: white shard particles shatter outward, a white
	   flash and ring, and a frozen star-pattern crack decal spreads.
	3. After ShatterDelay seconds every spike shatters into tumbling glass
	   fragments and is destroyed.

	Boss-tier layers: a crown of giant crystals erupts at the target, ice
	rocks burst up in a ring, a blizzard swirls over the impact, and the
	hit adds impact frames, focus lines, an FOV punch and a white core
	inside a pale-cyan ForceField shell. The shatter sends out a cyan ring.
]]

local Config = require(script.Parent.Parent.Config)
local Util = script.Parent.Parent.Util
local CameraShake = require(Util.CameraShake)
local Debris = require(Util.Debris)
local Emit = require(Util.Emit)
local Flash = require(Util.Flash)
local FocusLines = require(Util.FocusLines)
local GroundDecal = require(Util.GroundDecal)
local ImpactFrame = require(Util.ImpactFrame)
local RockRing = require(Util.RockRing)
local Shockwave = require(Util.Shockwave)
local Sphere = require(Util.Sphere)
local Types = require(Util.Types)

local C = Config.Spells.FrostRequiem.VFX
local Padding = Config.General.CleanupPadding

local FrostRequiem = {}

type Spike = { Part: Part, Base: Vector3 }

-- Grows one crystal from under the ground at `base` with the given shape.
local function growCrystal(
	model: Model,
	base: CFrame,
	height: number,
	width: number,
	orientation: CFrame,
	growTime: number
): Spike
	local spike = Emit.part(Vector3.new(width, height, width), C.SpikeColor, C.SpikeMaterial)
	spike.Name = "FrostSpike"
	spike.Transparency = C.SpikeTransparency
	local buried = base * orientation * CFrame.new(0, -height / 2, 0)
	local grown = base * orientation * CFrame.new(0, height * (0.5 - C.SpikeBury), 0)
	spike.CFrame = buried
	spike.Parent = model
	Emit.tween(spike, growTime, { CFrame = grown }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local position = base.Position
	Emit.burstAt(CFrame.new(position), C.Mist)
	Emit.burstAt(CFrame.new(position), C.Snow)
	return { Part = spike, Base = position }
end

local function growSpike(model: Model, base: CFrame, scale: number): Spike
	local height = Emit.random(C.SpikeHeightMin, C.SpikeHeightMax) * scale
	local width = Emit.random(C.SpikeWidthMin, C.SpikeWidthMax) * scale
	local tilt = math.rad(C.SpikeTiltMax)
	-- Diamond cross-section (45 deg yaw) with a random lean.
	local orientation = CFrame.Angles(
		Emit.random(-tilt, tilt),
		math.rad(C.SpikeBaseYaw) + Emit.random(0, math.pi),
		Emit.random(-tilt, tilt)
	)
	return growCrystal(model, base, height, width, orientation, C.SpikeGrowTime)
end

-- Crown of giant crystals leaning outward around `center`.
local function growCluster(model: Model, center: Vector3, spikes: { Spike })
	local cluster = C.Cluster
	for i = 1, cluster.Count do
		local angle = (i / cluster.Count) * math.pi * 2 + Emit.random(-cluster.AngleJitter, cluster.AngleJitter)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local point = Emit.groundAt(center + outward * cluster.Radius)
		local axis = Vector3.yAxis:Cross(outward).Unit
		local lean = CFrame.fromAxisAngle(axis, math.rad(Emit.random(cluster.TiltMin, cluster.TiltMax)))
		local orientation = lean * CFrame.Angles(0, math.rad(C.SpikeBaseYaw) + Emit.random(0, math.pi), 0)
		local height = Emit.random(cluster.HeightMin, cluster.HeightMax)
		local width = Emit.random(cluster.WidthMin, cluster.WidthMax)
		task.delay((i - 1) * cluster.Stagger, function()
			if model.Parent then
				table.insert(
					spikes,
					growCrystal(model, CFrame.new(point), height, width, orientation, cluster.GrowTime)
				)
			end
		end)
	end
end

function FrostRequiem.Play(character: Model, targetPosition: Vector3)
	local root = Emit.root(character)
	if root == nil then
		return
	end
	local startGround = Emit.groundAt(root.Position)
	local endGround = Emit.groundAt(targetPosition)
	local flatDelta = (endGround - startGround) * Vector3.new(1, 0, 1)
	local distance = flatDelta.Magnitude
	local direction = if distance > 1e-3 then flatDelta.Unit else root.CFrame.LookVector
	local side = direction:Cross(Vector3.yAxis)

	local count = math.clamp(math.floor((distance - C.StartGap) / C.SpikeSpacing) + 1, 1, C.MaxSpikes)
	local lifetime = count * C.SpikeInterval + C.ShatterDelay + Padding

	local model = Instance.new("Model")
	model.Name = "FrostRequiem"
	model.Parent = Emit.folder()
	Emit.cleanup(model, lifetime + C.Fragments.RiseTime)

	local rim = Instance.new("Highlight")
	rim.Adornee = model
	rim.DepthMode = Enum.HighlightDepthMode.Occluded
	rim.OutlineColor = C.RimColor
	rim.OutlineTransparency = C.RimTransparency
	rim.FillColor = C.RimFillColor
	rim.FillTransparency = C.RimFillTransparency
	rim.Parent = model

	CameraShake.Preset(C.Shake, root.Position)

	-------------------------------------------------------------------
	-- 1. Spikes erupt along the line.
	-------------------------------------------------------------------
	local spikes: { Spike } = {}
	for i = 1, count do
		local isLast = i == count
		local along = if isLast then distance else math.min(C.StartGap + (i - 1) * C.SpikeSpacing, distance)
		local jitter = if isLast then 0 else Emit.random(-C.SpikeSideJitter, C.SpikeSideJitter)
		local point = Emit.groundAt(startGround + direction * along + side * jitter)
		local scale = if isLast then C.FinalSpikeScale else 1
		table.insert(spikes, growSpike(model, CFrame.new(point), scale))
		task.wait(C.SpikeInterval)
		if not model.Parent then
			return
		end
	end

	-------------------------------------------------------------------
	-- 2. Impact at the target.
	-------------------------------------------------------------------
	local impact = endGround + Vector3.yAxis * C.SpikeHeightMin
	Flash.Impact(impact, C.Flash)
	Emit.burstAt(CFrame.new(impact), C.ImpactShatter)
	Shockwave.Ground(endGround, C.Ring)
	GroundDecal.Spawn(endGround, C.Decal)
	CameraShake.Preset(C.ImpactShake, endGround)

	-- Boss-tier layers.
	growCluster(model, endGround, spikes)
	ImpactFrame.Preset(C.Impact, impact)
	FocusLines.Play(impact, C.Focus)
	CameraShake.PunchPreset(C.Punch, impact)
	Sphere.Layers(impact, C.Spheres)
	RockRing.Ring(endGround, C.IceRocks)
	local blizzard = C.Blizzard
	local stormSize = Vector3.new(blizzard.Radius * 2, Config.General.AnchorSize.Y, blizzard.Radius * 2)
	local storm = Emit.anchor(CFrame.new(endGround), blizzard.Duration + blizzard.Spec.Lifetime.Max, stormSize)
	Emit.pulse(Emit.emitter(storm, blizzard.Spec), blizzard.Count, blizzard.Interval, blizzard.Duration)

	-------------------------------------------------------------------
	-- 3. Spikes shatter.
	-------------------------------------------------------------------
	task.wait(C.ShatterDelay)
	if not model.Parent then
		return
	end
	for _, spike in spikes do
		if spike.Part.Parent then
			local fragments = table.clone(C.Fragments)
			fragments.StartRadius = math.max(spike.Part.Size.X, C.Fragments.StartRadius)
			Debris.Shards(spike.Base, fragments)
			Emit.burstAt(spike.Part.CFrame, { Spec = C.Snow.Spec, Count = C.ShatterSnow })
			spike.Part:Destroy()
		end
	end
	Shockwave.Ground(endGround, C.ShatterRing)
	rim:Destroy()
	model:Destroy()
end

-- Typed export: the checker verifies this module matches Types.SpellModule.
local module: Types.SpellModule = { Play = FrostRequiem.Play }
return module
