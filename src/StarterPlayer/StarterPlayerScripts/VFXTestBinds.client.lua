--!strict
--[[
	VFXTestBinds (debug only)
	=========================
	Keys 1-8 cast each spell at the mouse hit position, clamped to the
	spell's MaxRange from Config. Shift + 1-8 makes the debug world boss
	(spawned by SpellServer) cast that spell at you instead. A small on-screen label lists the binds
	(looping spells show [ON] while active).

	Disable everything here by setting Config.DEBUG = false.
	Casts go through the real server flow (CastSpell -> validation ->
	PlaySpellVFX), so cooldowns and range checks are exercised too.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.VFX.Config)

if not Config.DEBUG then
	return
end

local Settings = Config.TestBinds
local Network = Config.Network
local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild(Network.Folder)
local castRemote = remotes:WaitForChild(Network.CastRemote) :: RemoteEvent
local playRemote = remotes:WaitForChild(Network.PlayRemote) :: RemoteEvent

local keyToSpell: { [Enum.KeyCode]: Config.SpellMeta } = {}
local ordered: { Config.SpellMeta } = {}
for _, name in Config.SpellOrder do
	local meta = Config.GetSpellMeta(name)
	if meta then
		keyToSpell[meta.Key] = meta
		table.insert(ordered, meta)
	end
end

---------------------------------------------------------------------------
-- Targeting
---------------------------------------------------------------------------
local function mouseTarget(root: BasePart, maxRange: number): Vector3
	local camera = Workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local vfxFolder = Workspace:FindFirstChild(Config.General.FolderName)
	if vfxFolder then
		table.insert(ignore, vfxFolder)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	-- Cast far enough to reach anything within range of the character.
	local reach = maxRange + (camera.CFrame.Position - root.Position).Magnitude
	local result = Workspace:Raycast(ray.Origin, ray.Direction * reach, params)
	local hit = if result then result.Position else ray.Origin + ray.Direction * reach

	local offset = hit - root.Position
	if offset.Magnitude > maxRange then
		hit = root.Position + offset.Unit * maxRange
	end
	return hit
end

---------------------------------------------------------------------------
-- On-screen label
---------------------------------------------------------------------------
local activeLoops: { [string]: boolean } = {}
local lines: { [string]: TextLabel } = {}

local function buildLabel()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = Settings.GuiName
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Settings.AnchorPoint
	frame.Position = Settings.Position
	frame.Size = UDim2.fromOffset(Settings.Width, Settings.LineHeight * (#ordered + 2) + Settings.Padding * 2)
	frame.BackgroundColor3 = Settings.BackgroundColor
	frame.BackgroundTransparency = Settings.BackgroundTransparency
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local padding = Instance.new("UIPadding")
	local pad = UDim.new(0, Settings.Padding)
	padding.PaddingTop, padding.PaddingBottom, padding.PaddingLeft, padding.PaddingRight = pad, pad, pad, pad
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local function addLine(text: string, order: number): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, Settings.LineHeight)
		label.Font = Settings.Font
		label.TextSize = Settings.TextSize
		label.TextColor3 = Settings.TextColor
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = text
		label.LayoutOrder = order
		label.Parent = frame
		return label
	end

	addLine(Settings.Title, 0)
	for index, meta in ordered do
		local keyName = UserInputService:GetStringForKeyCode(meta.Key)
		lines[meta.Name] = addLine(`[{keyName}] {meta.DisplayName}`, index)
	end
	addLine(Settings.BossHint, #ordered + 1)
end

local function refreshLine(meta: Config.SpellMeta)
	local label = lines[meta.Name]
	if label then
		local keyName = UserInputService:GetStringForKeyCode(meta.Key)
		local suffix = if activeLoops[meta.Name] then Settings.ActiveSuffix else ""
		label.Text = `[{keyName}] {meta.DisplayName}{suffix}`
	end
end

buildLabel()

-- Track our own loop state for the [ON] marker.
playRemote.OnClientEvent:Connect(
	function(casterUserId: number, spellName: string, _origin: Vector3, _target: Vector3?, active: boolean?)
		if casterUserId ~= player.UserId or active == nil then
			return
		end
		activeLoops[spellName] = active
		local meta = Config.GetSpellMeta(spellName)
		if meta then
			refreshLine(meta)
		end
	end
)

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	local meta = keyToSpell[input.KeyCode]
	if meta == nil then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	if shift then
		local bossRemote = remotes:FindFirstChild(Config.Boss.DebugRemote)
		if bossRemote and bossRemote:IsA("RemoteEvent") then
			bossRemote:FireServer(meta.Name)
		end
		return
	end
	castRemote:FireServer(meta.Name, mouseTarget(root, meta.MaxRange))
end)
