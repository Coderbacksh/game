--!strict
--[[
	SpellServer
	===========
	Boots the spell networking by requiring SpellService (which creates the
	Remotes folder, validates player casts and broadcasts PlaySpellVFX).

	To make a WORLD BOSS cast from your own server code:

	  local SpellService = require(game:GetService("ServerScriptService").SpellService)
	  SpellService.CastFromModel(bossModel, "CelestialVerdict", targetPosition)

	When Config.DEBUG is true this script also spawns a test boss (a black
	R15 rig scaled by Config.Boss.DebugScale) and lets testers make it cast
	with Shift + 1-8 (see VFXTestBinds.client.lua).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.VFX.Config)
local SpellService = require(ServerScriptService.SpellService)

if not Config.DEBUG then
	return
end

---------------------------------------------------------------------------
-- Debug test boss
---------------------------------------------------------------------------
local Boss = Config.Boss
local debugRemote = SpellService.EnsureRemote(Boss.DebugRemote)
local boss: Model? = nil
local lastDebugCast: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player: Player)
	lastDebugCast[player] = nil
end)

local function spawnBoss(): Model?
	local description = Instance.new("HumanoidDescription")
	for _, property in { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" } do
		(description :: any)[property] = Boss.DebugColor
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or model == nil then
		warn("[SpellServer] Could not create the debug boss:", model)
		return nil
	end
	model.Name = Boss.DebugName
	model:ScaleTo(Boss.DebugScale)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.MaxHealth = math.huge
		humanoid.Health = math.huge
	end
	model:PivotTo(CFrame.new(Boss.DebugPosition))
	model.Parent = Workspace
	return model
end

-- Spawning yields (CreateHumanoidModelFromDescription), so run it in its own thread.
task.spawn(function()
	boss = spawnBoss()
end)

debugRemote.OnServerEvent:Connect(function(player: Player, spellName: unknown)
	local current = boss
	if typeof(spellName) ~= "string" or current == nil or current.Parent == nil then
		return
	end
	local now = os.clock()
	if now - (lastDebugCast[player] or -math.huge) < Boss.DebugCastInterval then
		return
	end
	lastDebugCast[player] = now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	-- The boss turns to face the player and casts at them.
	local bossRoot = current:FindFirstChild("HumanoidRootPart")
	if bossRoot and bossRoot:IsA("BasePart") then
		local flatTarget = Vector3.new(root.Position.X, bossRoot.Position.Y, root.Position.Z)
		if (flatTarget - bossRoot.Position).Magnitude > 1e-3 then
			current:PivotTo(CFrame.lookAt(bossRoot.Position, flatTarget))
		end
	end
	SpellService.CastFromModel(current, spellName, root.Position)
end)
