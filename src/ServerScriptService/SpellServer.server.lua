--!strict
--[[
	SpellServer
	===========
	Authoritative spell networking. The server never builds particles.

	Creates ReplicatedStorage.Remotes with two RemoteEvents:
	  CastSpell    (client -> server)  (spellName, targetPosition)
	  PlaySpellVFX (server -> clients) (casterUserId, spellName, origin,
	                                    targetPosition, active?)

	Validation for every cast:
	  * argument types (string / finite Vector3)
	  * the spell exists in Config
	  * the caster is alive and has a HumanoidRootPart
	  * global anti-spam interval + per-player, per-spell cooldown
	  * target within the spell's MaxRange (+ tolerance)

	Looping spells (AbyssalAura) are toggles: the server tracks whether each
	player's loop is active and sends `active` so every client agrees. Loops
	are stopped on death, respawn, leaving, or after MaxDuration.

	Handlers never yield (task.delay only schedules work).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.VFX.Config)

local Network = Config.Network

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

local function ensureRemote(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local remotes = ensureFolder()
local castRemote = ensureRemote(remotes, Network.CastRemote)
local playRemote = ensureRemote(remotes, Network.PlayRemote)

---------------------------------------------------------------------------
-- Per-player state
---------------------------------------------------------------------------
type PlayerState = {
	LastCast: number,
	ReadyAt: { [string]: number },
	-- spellName -> token of the active loop (nil when not active)
	ActiveLoops: { [string]: number },
}

local states: { [Player]: PlayerState } = {}
local nextToken = 0

local function getState(player: Player): PlayerState
	local existing = states[player]
	if existing then
		return existing
	end
	local state: PlayerState = { LastCast = -math.huge, ReadyAt = {}, ActiveLoops = {} }
	states[player] = state
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

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Ends every active loop for a player and tells all clients.
local function stopLoops(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local origin = if root and root:IsA("BasePart") then root.Position else Vector3.zero
	for spellName in state.ActiveLoops do
		state.ActiveLoops[spellName] = nil
		playRemote:FireAllClients(player.UserId, spellName, origin, origin, false)
	end
end

---------------------------------------------------------------------------
-- Cast handling
---------------------------------------------------------------------------
castRemote.OnServerEvent:Connect(function(player: Player, spellName: unknown, targetPosition: unknown)
	if typeof(spellName) ~= "string" or typeof(targetPosition) ~= "Vector3" then
		return
	end
	if not isFiniteVector(targetPosition) then
		return
	end
	local meta = Config.GetSpellMeta(spellName)
	if meta == nil then
		return
	end
	local root = aliveRoot(player)
	if root == nil then
		return
	end

	local state = getState(player)
	local now = os.clock()
	if now - state.LastCast < Network.GlobalCastInterval then
		return
	end
	if now < (state.ReadyAt[spellName] or 0) then
		return
	end

	local stopping = meta.Looping and state.ActiveLoops[spellName] ~= nil
	if not stopping and (targetPosition - root.Position).Magnitude > meta.MaxRange + Network.RangeTolerance then
		return
	end

	state.LastCast = now
	state.ReadyAt[spellName] = now + meta.Cooldown
	local origin = root.Position

	if not meta.Looping then
		playRemote:FireAllClients(player.UserId, spellName, origin, targetPosition)
		return
	end

	if stopping then
		state.ActiveLoops[spellName] = nil
		playRemote:FireAllClients(player.UserId, spellName, origin, targetPosition, false)
		return
	end

	nextToken += 1
	local token = nextToken
	state.ActiveLoops[spellName] = token
	playRemote:FireAllClients(player.UserId, spellName, origin, targetPosition, true)

	local maxDuration = meta.MaxDuration
	if maxDuration then
		task.delay(maxDuration, function()
			local current = states[player]
			if current and current.ActiveLoops[spellName] == token then
				current.ActiveLoops[spellName] = nil
				local position = if root.Parent then root.Position else origin
				playRemote:FireAllClients(player.UserId, spellName, position, position, false)
			end
		end)
	end
end)

---------------------------------------------------------------------------
-- Lifecycle: stop loops on death / respawn, clear state on leave
---------------------------------------------------------------------------
local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			stopLoops(player)
		end)
	else
		-- Humanoid not replicated yet; hook it as soon as it appears.
		local connection: RBXScriptConnection? = nil
		connection = character.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Humanoid") then
				child.Died:Once(function()
					stopLoops(player)
				end)
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
		stopLoops(player)
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
	stopLoops(player)
	states[player] = nil
end)
