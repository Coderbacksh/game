--!strict
--[[
	GroundDecal
	===========
	Cracked-ground mark that spreads out, holds, then fades (client only).

	Two layers:
	  1. A Decal (Config.Textures.Crack) on a thin flat part aligned to the
	     ground normal. Invisible until you upload a crack texture.
	  2. Procedural cracks: thin jagged parts radiating from the centre
	     ("Radial"), straight star arms ("Star") or a long slash with side
	     branches ("Slash"). These work with no textures at all.

	GroundDecal.Spawn(position, params, forward?) returns a Handle. When
	params.Hold > 0 it fades automatically; with Hold = 0 it stays until
	handle.Stop() is called (used by looping spells).
]]

local Config = require(script.Parent.Parent.Config)
local Emit = require(script.Parent.Emit)
local Types = require(script.Parent.Types)

local Settings = Config.GroundDecal

local GroundDecal = {}

-- Adds one thin crack segment between two points in the root's space.
local function addSegment(root: BasePart, a: Vector3, b: Vector3, cracks: Types.CrackParams, delayTime: number)
	local length = (b - a).Magnitude
	if length < 1e-3 then
		return
	end
	local segment =
		Emit.part(Vector3.new(cracks.Thickness, Settings.SegmentHeight, length), cracks.Color, cracks.Material)
	local mid = (a + b) / 2
	segment.CFrame = root.CFrame * CFrame.lookAt(mid, b, Vector3.yAxis)
	segment.Transparency = 1
	segment.Parent = root
	Emit.tween(segment, Settings.SegmentFadeIn, { Transparency = 0 }, Enum.EasingStyle.Linear, nil, delayTime)
end

-- Jagged polyline from `origin` along `direction` (local space, y = 0).
local function addCrack(
	root: BasePart,
	origin: Vector3,
	direction: Vector3,
	length: number,
	cracks: Types.CrackParams,
	startDistance: number
)
	local segments = math.max(cracks.Segments, 1)
	local step = length / segments
	local side = Vector3.new(-direction.Z, 0, direction.X)
	local previous = origin
	for i = 1, segments do
		local along = origin + direction * (step * i)
		-- Jitter fades toward the tip so cracks taper naturally.
		local jitter = if i == segments then 0 else Emit.random(-cracks.Jitter, cracks.Jitter) * step
		local point = along + side * jitter
		local distance = startDistance + step * i
		addSegment(root, previous, point, cracks, distance * Settings.SegmentDelayPerStud)
		previous = point
	end
end

local function buildCracks(root: BasePart, params: Types.GroundDecalParams, cracks: Types.CrackParams)
	local radius = params.Radius
	if cracks.Pattern == "Slash" then
		local halfLength = (params.Length or radius * 2) / 2
		-- Main slash runs along local -Z (the decal's forward).
		addCrack(root, Vector3.new(0, 0, halfLength), Vector3.new(0, 0, -1), halfLength * 2, cracks, 0)
		for _ = 1, cracks.Count do
			local z = Emit.random(-halfLength, halfLength)
			local sideSign = if Emit.randomInt(0, 1) == 1 then 1 else -1
			local angle = Emit.random(Settings.SlashBranchAngleMin, Settings.SlashBranchAngleMax) * sideSign
			local direction = Vector3.new(math.sin(angle), 0, -math.cos(angle))
			addCrack(root, Vector3.new(0, 0, z), direction, radius, cracks, halfLength - z)
		end
		return
	end

	local count = math.max(cracks.Count, 1)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		if cracks.Pattern ~= "Star" then
			angle += Emit.random(-Settings.RadialAngleJitter, Settings.RadialAngleJitter) * (math.pi * 2 / count)
		end
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local length = if cracks.Pattern == "Star" then radius else radius * Emit.random(Settings.RadialLengthMin, 1)
		addCrack(root, Vector3.zero, direction, length, cracks, 0)
		-- Star pattern: a short side spike on each arm for the frost look.
		if cracks.Pattern == "Star" then
			local branchAngle = angle + math.pi / count
			local branch = Vector3.new(math.cos(branchAngle), 0, math.sin(branchAngle))
			addCrack(root, Vector3.zero, branch, radius * Settings.StarBranchScale, cracks, 0)
		end
	end
end

function GroundDecal.Spawn(position: Vector3, params: Types.GroundDecalParams, forward: Vector3?): Types.Handle
	local cframe = Emit.groundCFrame(position, forward)
	local width = params.Radius * 2
	local length = params.Length or width
	local fullSize = Vector3.new(width, Settings.Thickness, length)

	local root = Emit.part(
		fullSize * Vector3.new(params.StartScale, 1, params.StartScale),
		params.Color,
		Enum.Material.SmoothPlastic
	)
	root.Name = "GroundDecal"
	root.Transparency = 1
	root.CFrame = cframe
	root.Parent = Emit.folder()

	local decal: Decal? = nil
	if params.Texture ~= Config.PlaceholderTexture then
		local d = Instance.new("Decal")
		d.Texture = params.Texture
		d.Color3 = params.Color
		d.Face = Enum.NormalId.Top
		d.Transparency = Settings.DecalTransparency
		d.Parent = root
		decal = d
	end
	Emit.tween(root, params.SpreadTime, { Size = fullSize }, Enum.EasingStyle.Quint)

	-- Cracks are built at full size; their staggered fade-in sells the spread.
	local cracks = params.Cracks
	if cracks then
		buildCracks(root, params, cracks)
	end

	local faded = false
	local function fade()
		if faded then
			return
		end
		faded = true
		if not root.Parent then
			return
		end
		if decal then
			Emit.tween(decal, params.FadeTime, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		for _, child in root:GetChildren() do
			if child:IsA("BasePart") then
				Emit.tween(child, params.FadeTime, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end
		Emit.cleanup(root, params.FadeTime + Config.General.CleanupPadding)
	end

	if params.Hold > 0 then
		-- Delayed fade with no yielding: Debris guarantees removal even if the
		-- delayed callback were somehow skipped.
		task.delay(params.SpreadTime + params.Hold, fade)
		Emit.cleanup(root, params.SpreadTime + params.Hold + params.FadeTime + Config.General.CleanupPadding)
	end

	return { Stop = fade }
end

return GroundDecal
