--!strict
--[[
	Flash
	=====
	Impact-moment light effects (client only):

	  * Flash.Light(pos, params)    - PointLight that tweens to darkness
	  * Flash.Streak(pos, params)   - flat horizontal lens-flare streak
	                                  (BillboardGui so it is always screen-horizontal)
	  * Flash.Screen(params, pos?)  - full-screen white flash, weaker with distance
	  * Flash.Impact(pos, preset)   - all three using a Config.Flash.Presets entry

	Every instance is destroyed by Debris once its tween finishes.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)
local Emit = require(script.Parent.Emit)
local Types = require(script.Parent.Types)

local Settings = Config.Flash

local Flash = {}

function Flash.Light(position: Vector3, params: Types.LightParams): PointLight
	local duration = params.Duration or 0
	local host = Emit.anchor(CFrame.new(position), duration)
	local light = Instance.new("PointLight")
	light.Color = params.Color
	light.Brightness = params.Brightness
	light.Range = params.Range
	light.Shadows = false
	light.Parent = host
	if duration > 0 then
		Emit.tween(light, duration, { Brightness = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	return light
end

function Flash.Streak(position: Vector3, params: Types.StreakParams)
	local host = Emit.anchor(CFrame.new(position), params.Duration)

	local gui = Instance.new("BillboardGui")
	gui.Name = "FlareStreak"
	gui.Adornee = host
	gui.AlwaysOnTop = Settings.StreakAlwaysOnTop
	gui.LightInfluence = 0
	gui.Brightness = params.Brightness
	gui.Size = UDim2.fromScale(params.Width * Settings.StreakStartWidthScale, params.Height)
	gui.Parent = host

	-- Soft outer glow.
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundColor3 = params.Color
	glow.BorderSizePixel = 0
	glow.Parent = gui
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0.5, 0)
	glowCorner.Parent = glow
	local glowGradient = Instance.new("UIGradient")
	glowGradient.Transparency = Settings.StreakGradient
	glowGradient.Parent = glow

	-- Thin, hot core line.
	local core = glow:Clone()
	core.Size = UDim2.fromScale(1, Settings.StreakCoreHeightScale)
	core.Parent = gui

	-- Optional flare texture once a real asset is uploaded.
	if Config.Textures.Flare ~= Config.PlaceholderTexture then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = Config.Textures.Flare
		image.ImageColor3 = params.Color
		image.Parent = gui
		Emit.tween(image, params.Duration, { ImageTransparency = 1 })
	end

	Emit.tween(gui, params.Duration, { Size = UDim2.fromScale(params.Width, 0) }, Enum.EasingStyle.Quart)
	Emit.tween(glow, params.Duration, { BackgroundTransparency = 1 })
	Emit.tween(core, params.Duration, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

local function screenGui(): ScreenGui?
	local player = Players.LocalPlayer
	if player == nil then
		return nil
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local existing = playerGui:FindFirstChild(Settings.ScreenGuiName)
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = Settings.ScreenGuiName
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = Settings.ScreenDisplayOrder
	gui.Parent = playerGui
	return gui
end

function Flash.Screen(params: Types.ScreenFlashParams, source: Vector3?)
	local gui = screenGui()
	local camera = Workspace.CurrentCamera
	if gui == nil or camera == nil then
		return
	end
	local strength = 1
	if source then
		local distance = (camera.CFrame.Position - source).Magnitude
		strength = math.clamp(1 - distance / Settings.ScreenMaxDistance, 0, 1)
	end
	if strength <= 0 then
		return
	end
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = params.Color
	-- Lerp from fully transparent toward the preset opacity by strength.
	frame.BackgroundTransparency = 1 - (1 - params.Transparency) * strength
	frame.Parent = gui
	Emit.tween(frame, params.Duration, { BackgroundTransparency = 1 })
	Emit.cleanup(frame, params.Duration)
end

-- Light + streak + screen flash from a named Config.Flash.Presets entry.
function Flash.Impact(position: Vector3, presetName: string)
	local preset = (Settings.Presets :: any)[presetName] :: Types.FlashPreset?
	if preset == nil then
		warn("[VFX] Unknown flash preset:", presetName)
		return
	end
	Flash.Light(position, preset.Light)
	Flash.Streak(position, preset.Streak)
	Flash.Screen(preset.Screen, position)
end

return Flash
