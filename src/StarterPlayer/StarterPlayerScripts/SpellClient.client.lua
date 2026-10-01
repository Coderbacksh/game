--!strict
--[[
	SpellClient
	===========
	Listens for the server's PlaySpellVFX broadcast and renders the effect
	locally through VFXController. Every client (including the caster)
	renders every cast, so all players see the same spell.

	PlaySpellVFX args: (casterUserId, spellName, origin, targetPosition, active?)
	`origin` is the caster's position on the server at cast time; it is used
	as the target fallback when a loop-stop arrives without one.

	Your own input code (or VFXTestBinds in debug) casts spells by firing
	ReplicatedStorage.Remotes.CastSpell:FireServer(spellName, targetPosition).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.VFX.Config)
local VFXController = require(ReplicatedStorage.VFX.VFXController)

local Network = Config.Network

local remotes = ReplicatedStorage:WaitForChild(Network.Folder)
local playRemote = remotes:WaitForChild(Network.PlayRemote) :: RemoteEvent

playRemote.OnClientEvent:Connect(
	function(casterUserId: number, spellName: string, origin: Vector3, targetPosition: Vector3?, active: boolean?)
		if typeof(spellName) ~= "string" or not VFXController.Has(spellName) then
			return
		end
		local caster = Players:GetPlayerByUserId(casterUserId)
		local character = caster and caster.Character
		if character == nil then
			-- Caster left or their character has not streamed in; nothing to attach to.
			return
		end
		VFXController.Play(spellName, character, targetPosition or origin, active)
	end
)

-- Stop any looping effects attached to a character that is being removed.
local function watch(player: Player)
	player.CharacterRemoving:Connect(function(character: Model)
		VFXController.StopAll(character)
	end)
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end
