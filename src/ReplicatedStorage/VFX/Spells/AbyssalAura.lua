--!strict
--[[
	AbyssalAura (key 3, toggle loop)
	================================
	Charge-up aura that follows the caster until stopped:
	  * black spiky flames rising from the feet (looping emitter)
	  * a pulsing white glow + PointLight at the base
	  * two white ring trails orbiting at different tilts
	  * small black shards drifting upward in helical loops
	  * a cracked dark decal spreading under the player (re-spawned when
	    they move away from it)

	Boss-tier layers: a charge-up burst (rocks erupting in a ring + a black
	ForceField shell), a looping column of ink wisps and rising sparks,
	electricity crackling over the body, and a white ground pulse every
	GroundPulse.Interval. Stopping adds impact frames, focus lines, an FOV
	punch, layered spheres and a second rock ring. Body-attached sizes
	scale with the caster (a world boss scaled to 3x gets a 3x aura).

	Play(character) starts it (ignored if already active).
	Stop(character) ends it with a heavy white flash burst. The aura also
	stops itself when the character dies / is removed, or after
	Config.Spells.AbyssalAura.MaxDuration seconds, so it can never leak.
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
local OrbitTrail = require(Util.OrbitTrail)
local RockRing = require(Util.RockRing)
local Shockwave = require(Util.Shockwave)
local Sphere = require(Util.Sphere)
local Types = require(Util.Types)

local Spell = Config.Spells.AbyssalAura
local C = Spell.VFX

type Shard = { Part: Part, Angle: number, Radius: number, Phase: number }

local AbyssalAura = {}

-- character -> function that ends that character's aura
local active: { [Model]: () -> () } = {}

local function stopBurst(position: Vector3)
	local cframe = CFrame.new(position)
	Flash.Impact(position, C.StopFlash)
	Emit.burstAt(cframe, C.StopSparks)
	Emit.burstAt(cframe, { Spec = Config.Emitters.CoreFlare, Count = C.StopCoreCount })
	Shockwave.Ground(position, C.StopRing)
	CameraShake.Preset(C.StopShake, position)
	-- Boss-tier layers.
	ImpactFrame.Preset(C.StopImpact, position)
	FocusLines.Play(position, C.StopFocus)
	CameraShake.PunchPreset(C.StopPunch, position)
	Sphere.Layers(position, C.StopSpheres)
	RockRing.Ring(position, C.StopRocks)
end

local function isAlive(character: Model): boolean
	if not character.Parent then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid == nil or humanoid.Health > 0
end

function AbyssalAura.Play(character: Model, _targetPosition: Vector3)
	if active[character] then
		return
	end
	local root = Emit.root(character)
	if root == nil then
		return
	end

	local group = Instance.new("Folder")
	group.Name = "AbyssalAura"
	group.Parent = Emit.folder()

	-- Feet from HipHeight when available (correct for scaled boss rigs).
	local function feetPosition(part: BasePart): Vector3
		return Emit.feet(character) or (part.CFrame * CFrame.new(C.FootOffset)).Position
	end
	local scale = Emit.characterScale(character)

	-- Base: flames + glow + light, all following the feet.
	local base = Emit.anchor(CFrame.new(feetPosition(root)), nil, C.BaseSize * scale)
	base.Parent = group
	local flames = Emit.emitter(base, C.Flames.Spec)
	local glow = Emit.emitter(base, C.BaseGlow.Spec)
	local inkPillar = Emit.emitter(base, C.InkPillar.Spec)
	local risingSparks = Emit.emitter(base, C.RisingSparks.Spec)

	-- Charge-up burst.
	local startFeet = feetPosition(root)
	RockRing.Ring(startFeet, C.ChargeRocks)
	Sphere.Burst(root.Position, C.ChargeSphere)
	CameraShake.Preset(C.ChargeShake, startFeet)
	local light = Instance.new("PointLight")
	light.Color = C.Light.Color
	light.Brightness = C.Light.Brightness
	light.Range = C.Light.Range
	light.Shadows = false
	light.Parent = base

	-- Orbiting rings.
	local style: Types.TrailStyle = {
		Width = C.Orbit.Width,
		Lifetime = C.Orbit.Lifetime,
		Color = C.Orbit.Color,
		Transparency = C.Orbit.Transparency,
		LightEmission = C.Orbit.LightEmission,
		Brightness = C.Orbit.Brightness,
	}
	local orbits: { Types.Handle } = {}
	for _, orbit in C.Orbit.Trails do
		table.insert(orbits, OrbitTrail.OnCharacter(character, orbit, style, nil))
	end

	-- Drifting shards.
	local shards: { Shard } = {}
	for i = 1, C.Shards.Count do
		local part = Emit.part(C.Shards.Size, C.Shards.Color, C.Shards.Material)
		part.Name = "AuraShard"
		part.Transparency = 1
		part.Parent = group
		table.insert(shards, {
			Part = part,
			Angle = (i / C.Shards.Count) * math.pi * 2,
			Radius = Emit.random(C.Shards.MinRadius, C.Shards.MaxRadius),
			Phase = Emit.random(0, C.Shards.LoopHeight),
		})
	end

	-- Ground decal, re-spawned under the player when they wander off.
	local decalCenter = feetPosition(root)
	local decal = GroundDecal.Spawn(decalCenter, C.Decal)

	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		active[character] = nil
		flames.Enabled = false
		glow.Enabled = false
		inkPillar.Enabled = false
		risingSparks.Enabled = false
		for _, orbit in orbits do
			orbit.Stop()
		end
		decal.Stop()
		for _, shard in shards do
			Emit.tween(shard.Part, C.Orbit.Lifetime, { Transparency = 1 })
		end
		Emit.tween(light, C.Orbit.Lifetime, { Brightness = 0 })
		-- Let the last flame particles finish before destroying the group.
		local linger = math.max(
			C.Flames.Spec.Lifetime.Max,
			C.BaseGlow.Spec.Lifetime.Max,
			C.InkPillar.Spec.Lifetime.Max,
			C.RisingSparks.Spec.Lifetime.Max
		)
		Emit.cleanup(group, linger)
		stopBurst(base.Position)
	end

	local arcTimer = 0
	local pulseTimer = 0
	local stopStep = Emit.step(Spell.MaxDuration, function(_alpha, dt, elapsed)
		local currentRoot = Emit.root(character)
		if currentRoot == nil or not group.Parent or not isAlive(character) then
			return true
		end
		local feet = feetPosition(currentRoot)
		base.CFrame = CFrame.new(feet)
		light.Brightness = C.Light.Brightness + math.sin(elapsed * C.PulseSpeed) * C.PulseAmplitude

		for _, shard in shards do
			local height = (shard.Phase + elapsed * C.Shards.RiseSpeed) % C.Shards.LoopHeight
			local loopAlpha = height / C.Shards.LoopHeight
			local angle = shard.Angle + elapsed * C.Shards.SpinSpeed
			local tumble = elapsed * C.Shards.TumbleSpeed
			shard.Part.CFrame = CFrame.new(
				feet + Vector3.new(math.cos(angle) * shard.Radius, height, math.sin(angle) * shard.Radius)
			) * CFrame.Angles(tumble, tumble, 0)
			-- Fade in at the bottom of the loop and out at the top so the
			-- wrap-around is invisible.
			shard.Part.Transparency = 1 - math.sin(math.pi * loopAlpha)
		end

		-- Electricity crackling over the body.
		arcTimer += dt
		if arcTimer >= C.ArcPulse.Interval then
			arcTimer = 0
			Lightning.Crackle(currentRoot.Position, C.ArcPulse.Radius * scale, C.ArcPulse.Count, C.ArcPulse.Bolt)
		end
		-- Periodic white ground pulse.
		pulseTimer += dt
		if pulseTimer >= C.GroundPulse.Interval then
			pulseTimer = 0
			Shockwave.Ground(feet, C.GroundPulse.Ring)
		end

		if (feet - decalCenter).Magnitude > C.DecalRespawnDistance then
			decal.Stop()
			decalCenter = feet
			decal = GroundDecal.Spawn(decalCenter, C.Decal)
		end
		return false
	end, finish)

	active[character] = stopStep
end

function AbyssalAura.Stop(character: Model)
	local stop = active[character]
	if stop then
		stop()
	end
end

-- Typed export: the checker verifies this module matches Types.SpellModule.
local module: Types.SpellModule = { Play = AbyssalAura.Play, Stop = AbyssalAura.Stop }
return module
