--!strict
--[[
	InfernoSeal (key 5, accent: deep crimson)
	=========================================
	1. A circular rune seal draws itself on the ground in white lines.
	2. A pillar of black and crimson flames erupts upward with embers,
	   flickering smoke and a flickering crimson PointLight.
	3. Ends with a white flash core and a shockwave ring, leaving glowing
	   embers drifting off a cracked ground decal with crimson ember cracks.

	Boss-tier layers: crimson flames lick up along the seal's edge while it
	draws; the eruption tears a ring of basalt rocks out of the ground with
	an FOV punch, and crimson + black flame ribbons coil up the pillar.
	The finale adds impact frames, focus lines and a white core sphere in a
	crimson ForceField shell.

	Crimson is only used for flames, embers, light, crack glow and the
	finale's outer shell.
]]

local Config = require(script.Parent.Parent.Config)
local Util = script.Parent.Parent.Util
local CameraShake = require(Util.CameraShake)
local Emit = require(Util.Emit)
local Flash = require(Util.Flash)
local FocusLines = require(Util.FocusLines)
local GroundDecal = require(Util.GroundDecal)
local ImpactFrame = require(Util.ImpactFrame)
local OrbitTrail = require(Util.OrbitTrail)
local RockRing = require(Util.RockRing)
local RuneCircle = require(Util.RuneCircle)
local Shockwave = require(Util.Shockwave)
local Sphere = require(Util.Sphere)
local Types = require(Util.Types)

local C = Config.Spells.InfernoSeal.VFX

local InfernoSeal = {}

function InfernoSeal.Play(_character: Model, targetPosition: Vector3)
	local groundCFrame = Emit.groundCFrame(targetPosition)
	local ground = groundCFrame.Position

	-------------------------------------------------------------------
	-- 1. Seal draws itself.
	-------------------------------------------------------------------
	RuneCircle.Spawn(groundCFrame, C.Seal)
	-- Flames licking up along the seal's edge for its whole life.
	local ringLife = C.Seal.DrawTime + C.Seal.Hold
	local ringSize = Vector3.new(C.Seal.Radius * 2, Config.General.AnchorSize.Y, C.Seal.Radius * 2)
	local ringHost = Emit.anchor(groundCFrame, ringLife + C.FireRing.Spec.Lifetime.Max, ringSize)
	Emit.pulse(Emit.emitter(ringHost, C.FireRing.Spec), C.FireRing.Count, C.FireRing.Interval, ringLife)
	task.wait(C.Seal.DrawTime)

	-------------------------------------------------------------------
	-- 2. Flame pillar.
	-------------------------------------------------------------------
	local longestParticle = math.max(
		C.BlackFlames.Spec.Lifetime.Max,
		C.CrimsonFlames.Spec.Lifetime.Max,
		C.Embers.Spec.Lifetime.Max,
		C.FlickerSmoke.Spec.Lifetime.Max
	)
	local pillarSize = Vector3.new(C.PillarRadius * 2, C.PillarHeight, C.PillarRadius * 2)
	local pillar =
		Emit.anchor(groundCFrame * CFrame.new(0, C.PillarHeight / 2, 0), C.PillarDuration + longestParticle, pillarSize)

	for _, burst in { C.BlackFlames, C.CrimsonFlames, C.Embers, C.FlickerSmoke } do
		local emitter = Emit.emitter(pillar, burst.Spec)
		Emit.pulse(emitter, burst.Count, C.PulseInterval, C.PillarDuration)
	end

	-- Eruption: rocks + FOV punch + coiling flame ribbons.
	RockRing.Ring(ground, C.EruptRocks)
	CameraShake.PunchPreset(C.EruptPunch, ground)
	CameraShake.Preset(C.EruptShake, ground)
	local spiral = C.Spirals
	local flameStyle: Types.TrailStyle = {
		Width = spiral.Width,
		Lifetime = spiral.Lifetime,
		Color = spiral.Color,
		Transparency = spiral.Transparency,
		LightEmission = spiral.LightEmission,
		Brightness = spiral.Brightness,
	}
	local inkStyle: Types.TrailStyle = {
		Width = spiral.InkWidth,
		Lifetime = spiral.Lifetime,
		Color = Config.Palette.Black,
		Transparency = spiral.Transparency,
		LightEmission = 0,
		Brightness = spiral.InkBrightness,
	}
	local center = CFrame.new(ground)
	for i = 1, spiral.Count do
		local phase = (i / spiral.Count) * math.pi * 2
		type Ribbon = { Style: Types.TrailStyle, PhaseOffset: number }
		local ribbons: { Ribbon } = {
			{ Style = flameStyle, PhaseOffset = 0 },
			{ Style = inkStyle, PhaseOffset = math.pi / spiral.Count }, -- black ribbons sit between the flames
		}
		for _, ribbon in ribbons do
			OrbitTrail.Start(function(): CFrame?
				return center
			end, {
				Radius = spiral.Radius,
				Height = 0,
				Speed = spiral.Speed,
				Tilt = Vector3.zero,
				Phase = phase + ribbon.PhaseOffset,
				RiseSpeed = spiral.RiseSpeed,
			}, ribbon.Style, C.PillarDuration)
		end
	end

	local light = Instance.new("PointLight")
	light.Color = C.PillarLight.Color
	light.Brightness = C.PillarLight.Brightness
	light.Range = C.PillarLight.Range
	light.Shadows = false
	light.Parent = pillar
	Emit.step(C.PillarDuration, function(alpha)
		if not light.Parent then
			return true
		end
		local flicker = Emit.random(C.LightFlickerMin, C.LightFlickerMax)
		light.Brightness = C.PillarLight.Brightness * flicker * (1 - alpha)
		return false
	end)

	task.wait(C.PillarDuration)

	-------------------------------------------------------------------
	-- 3. White flash core, shockwave, lingering embers on cracked ground.
	-------------------------------------------------------------------
	local core = ground + Vector3.yAxis * C.PillarHeight
	Flash.Impact(core, C.EndFlash)
	Emit.burstAt(CFrame.new(core), { Spec = Config.Emitters.CoreFlare, Count = C.EndCoreCount })
	Shockwave.Ground(ground, C.EndRing)
	GroundDecal.Spawn(ground, C.Decal)
	CameraShake.Preset(C.Shake, ground)
	ImpactFrame.Preset(C.EndImpact, core)
	FocusLines.Play(core, C.EndFocus)
	CameraShake.PunchPreset(C.EndPunch, core)
	Sphere.Layers(core, C.EndSpheres)

	local emberSize = Vector3.new(C.Decal.Radius * 2, C.PillarHeight, C.Decal.Radius * 2)
	local emberHost = Emit.anchor(groundCFrame, C.GroundEmbers.Duration + C.GroundEmbers.Spec.Lifetime.Max, emberSize)
	local embers = Emit.emitter(emberHost, C.GroundEmbers.Spec)
	Emit.pulse(embers, C.GroundEmbers.Count, C.GroundEmbers.Interval, C.GroundEmbers.Duration)
end

-- Typed export: the checker verifies this module matches Types.SpellModule.
local module: Types.SpellModule = { Play = InfernoSeal.Play }
return module
