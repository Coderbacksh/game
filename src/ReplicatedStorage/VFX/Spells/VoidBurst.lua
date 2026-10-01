--!strict
--[[
	VoidBurst (key 2)
	=================
	1. Implode (ImplodeTime): black smoke and thick black ink tendrils
	   collapse inward toward a single point above the target.
	2. Detonate: blinding white starburst + core flare, long horizontal
	   lens-flare streak, white crackling electricity around the core,
	   curved black shockwave arcs spraying outward, a white ground ring,
	   a circular crack decal and dark shards that float up then drop.

	All instances are owned by self-cleaning utilities (Debris / step
	callbacks), so nothing persists after the effect.
]]

local Config = require(script.Parent.Parent.Config)
local Util = script.Parent.Parent.Util
local CameraShake = require(Util.CameraShake)
local Debris = require(Util.Debris)
local Emit = require(Util.Emit)
local Flash = require(Util.Flash)
local GroundDecal = require(Util.GroundDecal)
local Lightning = require(Util.Lightning)
local Shockwave = require(Util.Shockwave)
local Types = require(Util.Types)

local C = Config.Spells.VoidBurst.VFX

local VoidBurst = {}

function VoidBurst.Play(_character: Model, targetPosition: Vector3)
	local ground = Emit.groundAt(targetPosition)
	local core = ground + Vector3.yAxis * C.CoreHeight
	local coreCFrame = CFrame.new(core)

	-------------------------------------------------------------------
	-- 1. Implode: smoke + tendrils collapse inward.
	-------------------------------------------------------------------
	Emit.burstAt(coreCFrame, C.ImplodeSmoke, Vector3.one * C.ImplodeRadius * 2)
	for _ = 1, C.Tendrils.Count do
		local direction = Emit.randomUnit()
		Lightning.Bolt(function(elapsed: number)
			-- The outer end slides inward until it reaches the core.
			local t = math.clamp(elapsed / C.ImplodeTime, 0, 1)
			local outer = core + direction * C.ImplodeRadius * (1 - t * t)
			return outer, core
		end, C.Tendrils.Bolt)
	end

	task.wait(C.ImplodeTime)

	-------------------------------------------------------------------
	-- 2. Detonation.
	-------------------------------------------------------------------
	Flash.Impact(core, C.Flash)
	Emit.burstAt(coreCFrame, C.Starburst)
	Emit.burstAt(coreCFrame, { Spec = Config.Emitters.CoreFlare, Count = C.CoreCount })
	Emit.burstAt(coreCFrame, C.Smoke)
	Lightning.Crackle(core, C.Crackle.Radius, C.Crackle.Count, C.Crackle.Bolt)

	-- Curved black shockwave arcs at random tilts.
	for _ = 1, C.Arcs.Count do
		local tilt = math.rad(C.Arcs.MaxTilt)
		local orientation =
			CFrame.Angles(Emit.random(-tilt, tilt), Emit.random(0, math.pi * 2), Emit.random(-tilt, tilt))
		Shockwave.Ring(coreCFrame * orientation, C.Arcs.Ring)
	end

	Shockwave.Ground(ground, C.GroundRing)
	GroundDecal.Spawn(ground, C.Decal)
	Debris.Shards(ground, C.Shards)
	CameraShake.Preset(C.Shake, core)
end

-- Typed export: the checker verifies this module matches Types.SpellModule.
local module: Types.SpellModule = { Play = VoidBurst.Play }
return module
