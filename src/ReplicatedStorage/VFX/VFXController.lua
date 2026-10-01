--!strict
--[[
	VFXController
	=============
	Client-side entry point for spell visuals. Loads every spell module and
	exposes:

	  VFXController.Play(spellName, character, targetPosition, active?)
	      Plays a spell. For looping spells `active == false` stops it
	      instead (the server sends the toggle state).
	  VFXController.Stop(spellName, character)
	  VFXController.StopAll(character)  - stops every looping spell
	  VFXController.Has(spellName)

	Spells run inside task.spawn + pcall, so a spell may sequence itself
	with task.wait and an error in one effect never breaks the others.
	Never call this on the server: the server never builds particles.
]]

local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Util.Types)
local SpellsFolder = script.Parent.Spells

local Spells: { [string]: Types.SpellModule } = {
	GrimoireAwakening = require(SpellsFolder.GrimoireAwakening),
	VoidBurst = require(SpellsFolder.VoidBurst),
	AbyssalAura = require(SpellsFolder.AbyssalAura),
	ThunderJudgment = require(SpellsFolder.ThunderJudgment),
	InfernoSeal = require(SpellsFolder.InfernoSeal),
	FrostRequiem = require(SpellsFolder.FrostRequiem),
	GaleReaper = require(SpellsFolder.GaleReaper),
	CelestialVerdict = require(SpellsFolder.CelestialVerdict),
}

local VFXController = {}

function VFXController.Has(spellName: string): boolean
	return Spells[spellName] ~= nil
end

function VFXController.Stop(spellName: string, character: Model)
	local spell = Spells[spellName]
	local stop = spell and spell.Stop
	if stop then
		local ok, err = pcall(function()
			stop(character)
		end)
		if not ok then
			warn(`[VFX] {spellName}.Stop failed: {err}`)
		end
	end
end

function VFXController.StopAll(character: Model)
	for name in Spells do
		VFXController.Stop(name, character)
	end
end

function VFXController.Play(spellName: string, character: Model, targetPosition: Vector3, active: boolean?)
	if not RunService:IsClient() then
		warn("[VFX] VFXController.Play must only be called on the client")
		return
	end
	local spell = Spells[spellName]
	if spell == nil then
		warn(`[VFX] Unknown spell: {spellName}`)
		return
	end
	local meta = Config.GetSpellMeta(spellName)
	if meta and meta.Looping and active == false then
		VFXController.Stop(spellName, character)
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			spell.Play(character, targetPosition)
		end)
		if not ok then
			warn(`[VFX] {spellName}.Play failed: {err}`)
		end
	end)
end

-- Validate at load time that every configured spell has a module.
for _, name in Config.SpellOrder do
	if Spells[name] == nil then
		warn(`[VFX] Config.SpellOrder lists {name} but no spell module is registered`)
	end
end

return VFXController
