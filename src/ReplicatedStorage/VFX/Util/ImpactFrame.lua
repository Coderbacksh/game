--!strict
--[[
	ImpactFrame
	===========
	Anime-style impact frames (client only). For a few frames the whole
	screen snaps to stark, high-contrast black and white (optionally with a
	full-screen colour flash), alternating between steps, then returns to
	normal.

	Implemented with a temporary ColorCorrectionEffect in Lighting plus a
	full-screen Frame. Both are destroyed when the sequence ends. Viewers
	further than params.MaxDistance from the source see nothing.

	  ImpactFrame.Play(Config.ImpactFrame.Presets.Heavy, impactPosition)
	  ImpactFrame.Preset("Heavy", impactPosition)
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)
local Emit = require(script.Parent.Emit)
local Types = require(script.Parent.Types)

local Settings = Config.ImpactFrame

local ImpactFrame = {}

local function overlayGui(): ScreenGui?
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

function ImpactFrame.Play(params: Types.ImpactFrameParams, source: Vector3?)
	if not Settings.Enabled or #params.Frames == 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	if source and camera and (camera.CFrame.Position - source).Magnitude > params.MaxDistance then
		return
	end

	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = Settings.EffectName
	effect.Parent = Lighting

	local overlay: Frame? = nil
	local gui = overlayGui()
	if gui then
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BorderSizePixel = 0
		frame.BackgroundTransparency = 1
		frame.Parent = gui
		overlay = frame
	end

	local total = 0
	for _, step in params.Frames do
		total += step.Duration
	end

	local current = 0
	local function apply(index: number)
		local step = params.Frames[index]
		effect.Saturation = step.Saturation
		effect.Contrast = step.Contrast
		effect.Brightness = step.Brightness
		effect.TintColor = step.TintColor
		if overlay then
			if step.Overlay then
				overlay.BackgroundColor3 = step.Overlay
				overlay.BackgroundTransparency = step.OverlayTransparency or 0
			else
				overlay.BackgroundTransparency = 1
			end
		end
	end

	Emit.step(total, function(_alpha, _dt, elapsed)
		-- Find which step `elapsed` falls into.
		local acc = 0
		local index = #params.Frames
		for i, step in params.Frames do
			acc += step.Duration
			if elapsed < acc then
				index = i
				break
			end
		end
		if index ~= current then
			current = index
			apply(index)
		end
		return false
	end, function()
		effect:Destroy()
		if overlay then
			overlay:Destroy()
		end
	end)
	-- Safety net in case the render step never runs (e.g. window minimised).
	Emit.cleanup(effect, total + Config.General.CleanupPadding)
	if overlay then
		Emit.cleanup(overlay, total + Config.General.CleanupPadding)
	end
end

function ImpactFrame.Preset(name: string, source: Vector3?)
	local preset = (Settings.Presets :: any)[name] :: Types.ImpactFrameParams?
	if preset then
		ImpactFrame.Play(preset, source)
	else
		warn("[VFX] Unknown impact frame preset:", name)
	end
end

return ImpactFrame
