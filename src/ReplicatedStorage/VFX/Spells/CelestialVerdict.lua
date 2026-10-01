--!strict
--[[
	CelestialVerdict (key 8, ultimate)
	==================================
	1. The sky dims: Lighting.ExposureCompensation is tweened down and a
	   temporary ColorCorrectionEffect desaturates the world.
	2. A giant white rune circle draws itself high above the target and
	   rotates.
	3. A massive pillar of white light crashes down (beams whose lower end
	   races from the circle to the ground), outlined by crackling bolts
	   and wrapped in black ink smoke and ink trails spiralling upward.
	4. Impact: ultimate flare streak + screen flash, double shockwave ring,
	   heavy camera shake, crater-sized crack decal, and dozens of shards
	   hanging mid-air before falling.
	5. The pillar fades and Lighting is restored to its original values.

	Overlapping casts share one dim: a reference count makes sure Lighting
	is only restored after the last cast finishes.
]]

local Lighting = game:GetService("Lighting")

local Config = require(script.Parent.Parent.Config)
local Util = script.Parent.Parent.Util
local CameraShake = require(Util.CameraShake)
local Debris = require(Util.Debris)
local Emit = require(Util.Emit)
local Flash = require(Util.Flash)
local GroundDecal = require(Util.GroundDecal)
local Lightning = require(Util.Lightning)
local OrbitTrail = require(Util.OrbitTrail)
local RuneCircle = require(Util.RuneCircle)
local Shockwave = require(Util.Shockwave)
local Types = require(Util.Types)

local C = Config.Spells.CelestialVerdict.VFX
local Dim = C.SkyDim

local CelestialVerdict = {}

---------------------------------------------------------------------------
-- Sky dimming (reference counted).
---------------------------------------------------------------------------
local dimCount = 0
local savedExposure = 0
local correction: ColorCorrectionEffect? = nil
local restoreToken = 0

local function dimSky()
	dimCount += 1
	restoreToken += 1
	if dimCount == 1 and correction == nil then
		savedExposure = Lighting.ExposureCompensation
	end
	local effect: ColorCorrectionEffect
	local existing = correction
	if existing then
		effect = existing
	else
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "CelestialVerdictDim"
		effect.Parent = Lighting
		correction = effect
	end
	Emit.tween(Lighting, Dim.FadeIn, { ExposureCompensation = savedExposure + Dim.ExposureCompensation })
	Emit.tween(effect, Dim.FadeIn, {
		Saturation = Dim.Saturation,
		Contrast = Dim.Contrast,
		Brightness = Dim.Brightness,
	})
end

local function restoreSky()
	dimCount = math.max(dimCount - 1, 0)
	if dimCount > 0 then
		return
	end
	restoreToken += 1
	local token = restoreToken
	Emit.tween(Lighting, Dim.FadeOut, { ExposureCompensation = savedExposure })
	local effect = correction
	if effect then
		local tween = Emit.tween(effect, Dim.FadeOut, { Saturation = 0, Contrast = 0, Brightness = 0 })
		tween.Completed:Once(function()
			-- A new cast may have started while we were restoring.
			if token == restoreToken and dimCount == 0 then
				effect:Destroy()
				if correction == effect then
					correction = nil
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- The light pillar.
---------------------------------------------------------------------------
local function pillar(sky: Vector3, ground: Vector3)
	local P = C.Pillar
	local total = P.CrashTime + P.Duration + P.FadeTime
	local host = Emit.anchor(CFrame.new(ground), total)
	local top = Emit.attachment(host, CFrame.new(sky - ground))
	local bottom = Emit.attachment(host, CFrame.new(sky - ground))

	local function beam(width: number, transparency: number): Beam
		local b = Instance.new("Beam")
		b.Attachment0 = top
		b.Attachment1 = bottom
		b.Color = ColorSequence.new(P.Color)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = P.Brightness
		b.FaceCamera = true
		b.Segments = 1
		b.Width0 = width
		b.Width1 = width
		b.Transparency = NumberSequence.new(transparency)
		b.Parent = host
		return b
	end
	local glow = beam(P.GlowWidth, P.GlowTransparency)
	local core = beam(P.CoreWidth, 0)

	Emit.step(total, function(_alpha, _dt, elapsed)
		if not host.Parent then
			return true
		end
		-- Crash: the lower end races down to the ground.
		local crash = math.clamp(elapsed / P.CrashTime, 0, 1)
		bottom.Position = (sky - ground) * (1 - crash * crash)
		-- Fade: shrink + turn transparent.
		local fadeStart = P.CrashTime + P.Duration
		if elapsed > fadeStart then
			local fade = math.clamp((elapsed - fadeStart) / P.FadeTime, 0, 1)
			core.Width0 = P.CoreWidth * (1 - fade)
			core.Width1 = core.Width0
			glow.Width0 = P.GlowWidth * (1 - fade)
			glow.Width1 = glow.Width0
			core.Transparency = NumberSequence.new(fade)
			glow.Transparency = NumberSequence.new(P.GlowTransparency + (1 - P.GlowTransparency) * fade)
		end
		return false
	end)
end

function CelestialVerdict.Play(_character: Model, targetPosition: Vector3)
	local groundCFrame = Emit.groundCFrame(targetPosition)
	local ground = groundCFrame.Position
	local sky = ground + Vector3.yAxis * C.CircleHeight

	-------------------------------------------------------------------
	-- 1-2. Sky dims, rune circle appears high above.
	-------------------------------------------------------------------
	dimSky()
	-- Restore is scheduled up front so Lighting always comes back, even if
	-- something later in this function errors.
	task.delay(C.CircleTime + C.Pillar.CrashTime + C.Pillar.Duration + C.Pillar.FadeTime, restoreSky)
	RuneCircle.Spawn(CFrame.new(sky), C.Circle)
	task.wait(C.CircleTime)

	-------------------------------------------------------------------
	-- 3. Pillar crashes down.
	-------------------------------------------------------------------
	pillar(sky, ground)

	local boltParams = C.PillarBolts.Bolt
	for i = 1, C.PillarBolts.Count do
		local angle = (i / C.PillarBolts.Count) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * C.PillarBolts.Radius
		Lightning.Strike(sky + offset, ground + offset, boltParams)
	end

	local spiral = C.InkSpiral
	local spiralSize = Vector3.new(spiral.Radius * 2, Config.General.AnchorSize.Y, spiral.Radius * 2)
	local spiralHost = Emit.anchor(CFrame.new(ground), C.Pillar.Duration + spiral.Spec.Lifetime.Max, spiralSize)
	Emit.pulse(Emit.emitter(spiralHost, spiral.Spec), spiral.Count, spiral.Interval, C.Pillar.Duration)

	local inkStyle: Types.TrailStyle = {
		Width = C.InkTrails.Width,
		Lifetime = C.InkTrails.Lifetime,
		Color = C.InkTrails.Color,
		Transparency = C.InkTrails.Transparency,
		LightEmission = C.InkTrails.LightEmission,
		Brightness = C.InkTrails.Brightness,
	}
	local center = CFrame.new(ground)
	for i = 1, C.InkTrails.Count do
		OrbitTrail.Start(function(): CFrame?
			return center
		end, {
			Radius = C.InkTrails.Radius,
			Height = 0,
			Speed = C.InkTrails.Speed,
			Tilt = Vector3.zero,
			Phase = (i / C.InkTrails.Count) * math.pi * 2,
			RiseSpeed = C.InkTrails.RiseSpeed,
		}, inkStyle, C.Pillar.Duration)
	end

	task.wait(C.Pillar.CrashTime)

	-------------------------------------------------------------------
	-- 4. Impact.
	-------------------------------------------------------------------
	Flash.Impact(ground, C.Flash)
	Emit.burstAt(CFrame.new(ground), { Spec = Config.Emitters.CoreFlare, Count = C.CoreCount })
	Emit.burstAt(CFrame.new(ground), C.Sparks)
	Emit.burstAt(CFrame.new(ground), C.Smoke)
	for _, ring in C.Rings do
		Shockwave.Ground(ground, ring)
	end
	GroundDecal.Spawn(ground, C.Decal)
	Debris.Shards(ground, C.Shards)
	CameraShake.Preset(C.Shake, ground)
	-- 5. The pillar fades by itself; Lighting is restored by the delay above.
end

-- Typed export: the checker verifies this module matches Types.SpellModule.
local module: Types.SpellModule = { Play = CelestialVerdict.Play }
return module
