--!strict
--[[
	RockRing
	========
	Chunks of ground erupting upward (client only), the classic heavy-hit
	Roblox VFX. Rocks punch up out of the floor with a Back ease, lean
	outward, hold, then sink back down and are destroyed.

	With UseGroundMaterial the rocks copy the material and colour of
	whatever is underneath (a part's Material/Color, or the Terrain
	material colour), so they match any map.

	  RockRing.Ring(center, params)          - circle of rocks
	  RockRing.Line(from, to, params)        - two rows along a path (slashes)
]]

local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)
local Emit = require(script.Parent.Emit)
local Types = require(script.Parent.Types)

local Settings = Config.RockRing

local RockRing = {}

type GroundLook = { Material: Enum.Material, Color: Color3 }

local function groundLook(position: Vector3, params: Types.RockParams): GroundLook
	if not params.UseGroundMaterial then
		return { Material = params.Material, Color = params.Color }
	end
	local result = Emit.groundRaycast(position)
	if result == nil then
		return { Material = params.Material, Color = params.Color }
	end
	local hit = result.Instance
	if hit:IsA("Terrain") then
		local ok, color = pcall(function()
			return Workspace.Terrain:GetMaterialColor(result.Material)
		end)
		return { Material = result.Material, Color = if ok then color else params.Color }
	end
	if hit:IsA("BasePart") then
		return { Material = hit.Material, Color = hit.Color }
	end
	return { Material = params.Material, Color = params.Color }
end

-- Raises one rock whose final resting CFrame is `final`.
local function raise(final: CFrame, size: Vector3, look: GroundLook, params: Types.RockParams, delayTime: number)
	local rock = Emit.part(size, look.Color, look.Material)
	rock.Name = "Rock"
	local buried = final * CFrame.new(0, -size.Y * Settings.BuryDepth, 0)
	rock.CFrame = buried
	rock.Parent = Emit.folder()
	Emit.cleanup(rock, delayTime + params.RiseTime + params.Hold + params.SinkTime + Config.General.CleanupPadding)

	local rise = Emit.tween(
		rock,
		params.RiseTime,
		{ CFrame = final },
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out,
		delayTime
	)
	rise.Completed:Once(function(state: Enum.PlaybackState)
		if state ~= Enum.PlaybackState.Completed or not rock.Parent then
			return
		end
		Emit.tween(
			rock,
			params.SinkTime,
			{ CFrame = buried, Transparency = Settings.SinkTransparency },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In,
			params.Hold
		)
	end)
end

local function rockSize(params: Types.RockParams): Vector3
	local base = Emit.random(params.SizeMin, params.SizeMax)
	return Vector3.new(
		base * Emit.random(Settings.AspectMin, Settings.AspectMax),
		base * Emit.random(Settings.AspectMin, Settings.AspectMax),
		base * Emit.random(Settings.AspectMin, Settings.AspectMax)
	)
end

local function placeRock(
	point: Vector3,
	outward: Vector3,
	params: Types.RockParams,
	delayTime: number,
	look: GroundLook
)
	local ground = Emit.groundAt(point)
	local size = rockSize(params)
	local tilt = math.rad(Emit.random(params.TiltMin, params.TiltMax))
	-- Face outward, lean back away from the centre, add a random twist.
	local facing = CFrame.lookAt(ground, ground + outward)
	local final = facing
		* CFrame.Angles(-tilt, 0, 0)
		* CFrame.Angles(0, Emit.random(-math.pi, math.pi), 0)
		* CFrame.new(0, size.Y * Settings.ExposedHeight, 0)
	raise(final, size, look, params, delayTime)
end

function RockRing.Ring(center: Vector3, params: Types.RockParams)
	local look = groundLook(center, params)
	local count = math.max(params.Count, 1)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + Emit.random(-Settings.AngleJitter, Settings.AngleJitter)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local radius = params.Radius + Emit.random(-params.RadiusJitter, params.RadiusJitter)
		placeRock(center + outward * radius, outward, params, (i - 1) * params.Stagger, look)
	end
end

function RockRing.Line(from: Vector3, to: Vector3, params: Types.RockParams)
	local flat = (to - from) * Vector3.new(1, 0, 1)
	local length = flat.Magnitude
	if length < 1e-3 then
		return
	end
	local direction = flat.Unit
	local side = direction:Cross(Vector3.yAxis)
	local spacing = params.Spacing or params.SizeMax
	local look = groundLook(from, params)
	local steps = math.max(math.floor(length / spacing), 1)
	for i = 0, steps do
		local along = from + direction * (i * spacing)
		for _, sign in { 1, -1 } do
			local offset = params.Radius + Emit.random(-params.RadiusJitter, params.RadiusJitter)
			placeRock(along + side * sign * offset, side * sign, params, i * params.Stagger, look)
		end
	end
end

return RockRing
