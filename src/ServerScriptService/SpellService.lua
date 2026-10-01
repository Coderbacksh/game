--!strict
--[[
	SpellService
	============
	Server-side spell API. The server never builds particles; it validates
	casts and tells every client to render them.

	  SpellService.CastFromPlayer(player, spellName, targetPosition)
	      Validated path used by the CastSpell remote: argument types, spell
	      exists, caster alive, anti-spam + per-spell cooldown, MaxRange.

	  SpellService.CastFromModel(model, spellName, targetPosition)
	      Trusted path for server code such as a WORLD BOSS AI. `model` is
	      any character Model with a HumanoidRootPart (e.g. a boss rig
	      scaled with Model:ScaleTo). No cooldowns or range checks: your
	      boss script decides when to cast. Looping spells toggle.

	  SpellService.StopLoops(caster)   -- Player or Model

	PlaySpellVFX is fired to all clients with
	  (caster, spellName, origin, targetPosition, active?)
	where `caster` is the player's UserId (number) or the boss Model itself.

	Loops stop automatically on death, respawn, leaving, the model being
	removed, or after the spell's MaxDuration. Nothing here yields.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.VFX.Config)

local Network = Config.Network

local SpellService = {}

---------------------------------------------------------------------------
-- Remotes (created at runtime)
---------------------------------------------------------------------------
local function ensureFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(Network.Folder)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = Network.Folder
	folder.Parent = ReplicatedStorage
	return folder
end

function SpellService.EnsureRemote(name: string): RemoteEvent
	local folder = ensureFolder()
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local castRemote = SpellService.EnsureRemote(Network.CastRemote)
local playRemote = SpellService.EnsureRemote(Network.PlayRemote)

---------------------------------------------------------------------------
-- State. Casters are keyed by Player (player casts) or Model (NPC casts).
---------------------------------------------------------------------------
type CasterState = {
	LastCast: number,
	ReadyAt: { [string]: number },
	ActiveLoops: { [string]: number }, -- spellName -> loop token
}

local states: { [Player | Model]: CasterState } = {}
local nextToken = 0

local function getState(key: Player | Model): CasterState
	local existing = states[key]
	if existing then
		return existing
	end
	local state: CasterState = { LastCast = -math.huge, ReadyAt = {}, ActiveLoops = {} }
	states[key] = state
	return state
end

local function isFiniteVector(v: Vector3): boolean
	for _, n in { v.X, v.Y, v.Z } do
		if n ~= n or n == math.huge or n == -math.huge then
			return false
		end
	end
	return true
end

local function rootOf(model: Model?): BasePart?
	if model == nil then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isAlive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid == nil or humanoid.Health > 0
end

-- What clients receive as the caster: UserId for players, the Model for NPCs.
local function wireCaster(key: Player | Model): number | Model
	if typeof(key) == "Instance" and key:IsA("Player") then
		return key.UserId
	end
	return key :: Model
end

local function characterOf(key: Player | Model): Model?
	if typeof(key) == "Instance" and key:IsA("Player") then
		return key.Character
	end
	return key :: Model
end

function SpellService.StopLoops(key: Player | Model)
	local state = states[key]
	if state == nil then
		return
	end
	local root = rootOf(characterOf(key))
	local origin = if root then root.Position else Vector3.zero
	for spellName in state.ActiveLoops do
		state.ActiveLoops[spellName] = nil
		playRemote:FireAllClients(wireCaster(key), spellName, origin, origin, false)
	end
end

-- Shared broadcast once a cast is accepted. Handles loop toggling.
local function broadcast(key: Player | Model, meta: Config.SpellMeta, root: BasePart, targetPosition: Vector3)
	local state = getState(key)
	local caster = wireCaster(key)
	local spellName = meta.Name
	local origin = root.Position

	if not meta.Looping then
		playRemote:FireAllClients(caster, spellName, origin, targetPosition)
		return
	end

	if state.ActiveLoops[spellName] ~= nil then
		state.ActiveLoops[spellName] = nil
		playRemote:FireAllClients(caster, spellName, origin, targetPosition, false)
		return
	end

	nextToken += 1
	local token = nextToken
	state.ActiveLoops[spellName] = token
	playRemote:FireAllClients(caster, spellName, origin, targetPosition, true)

	local maxDuration = meta.MaxDuration
	if maxDuration then
		task.delay(maxDuration, function()
			local current = states[key]
			if current and current.ActiveLoops[spellName] == token then
				current.ActiveLoops[spellName] = nil
				local position = if root.Parent then root.Position else origin
				playRemote:FireAllClients(caster, spellName, position, position, false)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Player casts (validated)
---------------------------------------------------------------------------
function SpellService.CastFromPlayer(player: Player, spellName: unknown, targetPosition: unknown): boolean
	if typeof(spellName) ~= "string" or typeof(targetPosition) ~= "Vector3" then
		return false
	end
	if not isFiniteVector(targetPosition) then
		return false
	end
	local meta = Config.GetSpellMeta(spellName)
	if meta == nil then
		return false
	end
	local character = player.Character
	local root = rootOf(character)
	if character == nil or root == nil or not isAlive(character) then
		return false
	end

	local state = getState(player)
	local now = os.clock()
	if now - state.LastCast < Network.GlobalCastInterval then
		return false
	end
	if now < (state.ReadyAt[spellName] or 0) then
		return false
	end
	local stopping = meta.Looping and state.ActiveLoops[spellName] ~= nil
	if not stopping and (targetPosition - root.Position).Magnitude > meta.MaxRange + Network.RangeTolerance then
		return false
	end

	state.LastCast = now
	state.ReadyAt[spellName] = now + meta.Cooldown
	broadcast(player, meta, root, targetPosition)
	return true
end

---------------------------------------------------------------------------
-- NPC / world boss casts (trusted server code)
---------------------------------------------------------------------------
local watchedModels: { [Model]: boolean } = {}

local function watchModel(model: Model)
	if watchedModels[model] then
		return
	end
	watchedModels[model] = true
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			SpellService.StopLoops(model)
		end)
	end
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			SpellService.StopLoops(model)
			states[model] = nil
			watchedModels[model] = nil
		end
	end)
end

function SpellService.CastFromModel(model: Model, spellName: string, targetPosition: Vector3): boolean
	local meta = Config.GetSpellMeta(spellName)
	local root = rootOf(model)
	if meta == nil then
		warn(`[SpellService] Unknown spell "{spellName}"`)
		return false
	end
	if root == nil or not isAlive(model) or not isFiniteVector(targetPosition) then
		return false
	end
	if not model:IsDescendantOf(workspace) then
		warn("[SpellService] CastFromModel: the model must be in Workspace so clients can see it")
		return false
	end
	watchModel(model)
	broadcast(model, meta, root, targetPosition)
	return true
end

---------------------------------------------------------------------------
-- Player wiring
---------------------------------------------------------------------------
castRemote.OnServerEvent:Connect(function(player: Player, spellName: unknown, targetPosition: unknown)
	SpellService.CastFromPlayer(player, spellName, targetPosition)
end)

local function onCharacterAdded(player: Player, character: Model)
	local function hook(humanoid: Humanoid)
		humanoid.Died:Once(function()
			SpellService.StopLoops(player)
		end)
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		hook(humanoid)
	else
		local connection: RBXScriptConnection? = nil
		connection = character.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Humanoid") then
				hook(child)
				if connection then
					connection:Disconnect()
				end
			end
		end)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		SpellService.StopLoops(player)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerRemoving:Connect(function(player: Player)
	SpellService.StopLoops(player)
	states[player] = nil
end)

return SpellService
