--!strict
--[[
	FocusLines
	==========
	Anime "focus lines" / speed lines (client only): thin white streaks
	radiating from the impact point's position on screen, re-randomised
	every RerollInterval for a flickering manga look, fading out over
	Duration.

	Built from Frames inside a CanvasGroup so the whole set fades with one
	GroupTransparency tween. Everything is destroyed when it ends.

	  FocusLines.Play(worldPosition, Config...FocusLines)
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)
local Emit = require(script.Parent.Emit)
local Types = require(script.Parent.Types)

local Settings = Config.FocusLines

local FocusLines = {}

local function screenGui(): ScreenGui?
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local existing = playerGui:FindFirstChild(Settings.GuiName)
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = Settings.GuiName
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = Settings.DisplayOrder
	gui.Parent = playerGui
	return gui
end

function FocusLines.Play(worldPosition: Vector3, params: Types.FocusLineParams)
	local gui = screenGui()
	local camera = Workspace.CurrentCamera
	if gui == nil or camera == nil then
		return
	end
	local viewport = camera.ViewportSize
	local screenPoint, onScreen = camera:WorldToViewportPoint(worldPosition)
	if (camera.CFrame.Position - worldPosition).Magnitude > Settings.MaxDistance then
		return
	end
	local center = if onScreen then Vector2.new(screenPoint.X, screenPoint.Y) else viewport / 2
	local short = math.min(viewport.X, viewport.Y)

	local group = Instance.new("CanvasGroup")
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = params.Transparency
	group.Parent = gui

	local taper = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(Settings.TaperPeak, 0),
		NumberSequenceKeypoint.new(1, 1),
	})

	local lines: { Frame } = {}
	for _ = 1, params.Count do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = params.Color
		line.Parent = group
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = taper
		gradient.Parent = line
		table.insert(lines, line)
	end

	local function reroll()
		for _, line in lines do
			local angle = Emit.random(0, math.pi * 2)
			local length = Emit.random(params.LengthMin, params.LengthMax) * short
			local inner = params.InnerRadius * short
			local mid = center + Vector2.new(math.cos(angle), math.sin(angle)) * (inner + length / 2)
			line.Position = UDim2.fromOffset(mid.X, mid.Y)
			line.Size = UDim2.fromOffset(length, Emit.random(params.Thickness * Settings.ThinScale, params.Thickness))
			line.Rotation = math.deg(angle)
		end
	end
	reroll()

	local accumulator = 0
	Emit.step(params.Duration, function(_alpha, dt)
		if not group.Parent then
			return true
		end
		accumulator += dt
		if accumulator >= params.RerollInterval then
			accumulator = 0
			reroll()
		end
		return false
	end, function()
		group:Destroy()
	end)
	Emit.tween(group, params.Duration, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Emit.cleanup(group, params.Duration + Config.General.CleanupPadding)
end

return FocusLines
