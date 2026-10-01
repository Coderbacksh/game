--!strict
--[[
	GaleReaper (key 7)
	==================
	A fast crescent wind slash fired forward.

	The blade is built from curved Beams: each half of the crescent is a
	Bezier beam from a tip (attachment axis pointing forward) to the centre
	(attachment axis pointing sideways), so the halves meet smoothly. Three
	layers are stacked: a hot white core, a soft white glow and wider
	black smoky edges set slightly behind. Tip Trails, speed-line
	particles, ink wisps and two spiralling wind trails ride along.

	On contact it splits into smaller fading crescents, kicks up dust and
	debris, and carves a long slash-shaped crack decal along its path.
]]

local Config = require(script.Parent.Parent.Config)
local Util = script.Parent.Parent.Util
local CameraShake = require(Util.CameraShake)
local Debris = require(Util.Debris)
local Emit = require(Util.Emit)
local Flash = require(Util.Flash)
local GroundDecal = require(Util.GroundDecal)
local OrbitTrail = require(Util.OrbitTrail)
local Types = require(Util.Types)

local C = Config.Spells.GaleReaper.VFX
local B = C.Blade

local GaleReaper = {}

type Crescent = {
	Host: Part,
	Beams: { Beam },
	Trails: { Trail },
	BaseTransparency: { number },
}

-- Attachment orientation whose X axis (the Beam curve axis) points along `axis`.
local function axisFrame(position: Vector3, axis: Vector3): CFrame
	local up = if math.abs(axis:Dot(Vector3.yAxis)) > Config.Lightning.MinPerpendicularCheck
		then Vector3.zAxis
		else Vector3.yAxis
	return CFrame.fromMatrix(position, axis, up)
end

local function buildCrescent(scale: number): Crescent
	local host = Emit.anchor(CFrame.identity, nil, C.SpeedLines.BoxSize * scale)
	local beams: { Beam } = {}
	local baseTransparency: { number } = {}
	local forward = Vector3.new(0, 0, -1) -- host-local forward
	local right = Vector3.xAxis
	local hasTexture = Config.Textures.Crescent ~= Config.PlaceholderTexture

	local function layer(
		zOffset: number,
		width: number,
		color: Color3,
		lightEmission: number,
		brightness: number,
		transparency: number
	)
		local hw = B.HalfWidth * scale
		local curve = B.Curve * scale
		local tangent = hw * B.CenterTangentScale
		local left = Emit.attachment(host, axisFrame(Vector3.new(-hw, 0, zOffset), forward))
		local center = Emit.attachment(host, axisFrame(Vector3.new(0, 0, zOffset - curve), right))
		local rightTip = Emit.attachment(host, axisFrame(Vector3.new(hw, 0, zOffset), forward))
		type Half = { A0: Attachment, A1: Attachment, Curve0: number, Curve1: number, W0: number, W1: number }
		local halves: { Half } = {
			-- tip -> centre: bulge forward at the tip, flatten sideways at the centre
			{ A0 = left, A1 = center, Curve0 = curve, Curve1 = tangent, W0 = 0, W1 = width },
			-- centre -> tip: mirror of the first half
			{ A0 = center, A1 = rightTip, Curve0 = tangent, Curve1 = -curve, W0 = width, W1 = 0 },
		}
		for _, half in halves do
			local beam = Instance.new("Beam")
			beam.Attachment0 = half.A0
			beam.Attachment1 = half.A1
			beam.CurveSize0 = half.Curve0
			beam.CurveSize1 = half.Curve1
			beam.Width0 = half.W0 * scale
			beam.Width1 = half.W1 * scale
			beam.Color = ColorSequence.new(color)
			beam.LightEmission = lightEmission
			beam.LightInfluence = 0
			beam.Brightness = brightness
			beam.FaceCamera = true
			beam.Segments = B.Segments
			beam.Transparency = NumberSequence.new(transparency)
			if hasTexture then
				beam.Texture = Config.Textures.Crescent
				beam.TextureMode = Enum.TextureMode.Stretch
			end
			beam.Parent = host
			table.insert(beams, beam)
			table.insert(baseTransparency, transparency)
		end
		return left, rightTip
	end

	-- Back to front: black smoky edges, soft glow, hot core.
	layer(B.EdgeOffset * scale, B.EdgeWidth, B.EdgeColor, 0, B.EdgeBrightness, B.EdgeTransparency)
	layer(0, B.GlowWidth, B.CoreColor, 1, B.CoreBrightness, B.GlowTransparency)
	local leftTip, rightTip = layer(0, B.CoreWidth, B.CoreColor, 1, B.CoreBrightness, 0)

	-- Tip trails.
	local trails: { Trail } = {}
	for _, tip in { leftTip, rightTip } do
		local inward = Emit.attachment(host, CFrame.new(tip.Position * (1 - B.TrailWidth / B.HalfWidth)))
		local trail = Instance.new("Trail")
		trail.Attachment0 = tip
		trail.Attachment1 = inward
		trail.Lifetime = B.TrailLifetime
		trail.Color = ColorSequence.new(B.CoreColor)
		trail.Transparency = NumberSequence.new(0, 1)
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Brightness = B.CoreBrightness
		trail.FaceCamera = true
		trail.Enabled = false
		trail.Parent = host
		table.insert(trails, trail)
	end

	return { Host = host, Beams = beams, Trails = trails, BaseTransparency = baseTransparency }
end

-- Moves a crescent from `from` along `direction` for `distance` studs over
-- `duration` seconds. When `fade` is set the blade fades out as it goes.
-- `onArrive` runs when it reaches the end (not if destroyed early).
local function launch(
	crescent: Crescent,
	from: Vector3,
	direction: Vector3,
	distance: number,
	duration: number,
	fade: boolean,
	onArrive: (() -> ())?
)
	local host = crescent.Host
	local roll = CFrame.Angles(0, 0, math.rad(C.RollDegrees))
	local function place(alpha: number)
		local position = from + direction * distance * alpha
		host.CFrame = CFrame.lookAt(position, position + direction) * roll
	end
	place(0)
	for _, trail in crescent.Trails do
		trail.Enabled = true
	end

	Emit.step(duration, function(alpha)
		if not host.Parent then
			return true
		end
		place(alpha)
		if fade then
			for i, beam in crescent.Beams do
				local base = crescent.BaseTransparency[i]
				beam.Transparency = NumberSequence.new(base + (1 - base) * alpha)
			end
		end
		return false
	end, function()
		if not host.Parent then
			return
		end
		for _, beam in crescent.Beams do
			beam.Enabled = false
		end
		for _, trail in crescent.Trails do
			trail.Enabled = false
		end
		-- Keep the host until the trails and particles have faded.
		Emit.cleanup(host, math.max(B.TrailLifetime, C.SpeedLines.Spec.Lifetime.Max, C.WakeSmoke.Spec.Lifetime.Max))
		if onArrive then
			onArrive()
		end
	end)
end

function GaleReaper.Play(character: Model, targetPosition: Vector3)
	local root = Emit.root(character)
	if root == nil then
		return
	end
	local start = (root.CFrame * CFrame.new(C.LaunchOffset)).Position
	local finish = Emit.groundAt(targetPosition) + Vector3.yAxis * C.BladeHeight
	local delta = finish - start
	local distance = delta.Magnitude
	local direction = if distance > 1e-3 then delta.Unit else root.CFrame.LookVector
	local travelTime = math.max(distance / C.Speed, C.MinTravelTime)

	local blade = buildCrescent(1)
	local speedLines = Emit.emitter(blade.Host, C.SpeedLines.Spec)
	local wake = Emit.emitter(blade.Host, C.WakeSmoke.Spec)
	Emit.pulse(speedLines, C.SpeedLines.Count, C.SpeedLines.Interval, travelTime)
	Emit.pulse(wake, C.WakeSmoke.Count, C.SpeedLines.Interval, travelTime)

	-- Wind spirals wrapping the travel axis.
	local spiralStyle: Types.TrailStyle = {
		Width = C.Spirals.Width,
		Lifetime = C.Spirals.Lifetime,
		Color = C.Spirals.Color,
		Transparency = C.Spirals.Transparency,
		LightEmission = C.Spirals.LightEmission,
		Brightness = C.Spirals.Brightness,
	}
	local axisTurn = CFrame.Angles(math.pi / 2, 0, 0) -- orbit plane perpendicular to travel
	for i = 1, C.Spirals.Count do
		OrbitTrail.Start(function(): CFrame?
			if not blade.Host.Parent then
				return nil
			end
			return blade.Host.CFrame * axisTurn
		end, {
			Radius = C.Spirals.Radius,
			Height = 0,
			Speed = C.Spirals.Speed,
			Tilt = Vector3.zero,
			Phase = (i / C.Spirals.Count) * math.pi * 2,
		}, spiralStyle, travelTime)
	end

	launch(blade, start, direction, distance, travelTime, false, function()
		local ground = Emit.groundAt(finish)
		local flat = Vector3.new(direction.X, 0, direction.Z)
		local flatDirection = if flat.Magnitude > 1e-3 then flat.Unit else root.CFrame.LookVector

		-- Split into smaller crescents fanning outward.
		local spread = math.rad(C.Split.SpreadDegrees)
		for i = 1, C.Split.Count do
			local t = if C.Split.Count > 1 then (i - 1) / (C.Split.Count - 1) else 0.5
			local yaw = CFrame.Angles(0, -spread / 2 + spread * t, 0)
			local splitDirection = (yaw * direction).Unit
			launch(buildCrescent(C.Split.Scale), finish, splitDirection, C.Split.Distance, C.Split.Duration, true, nil)
		end

		Flash.Impact(finish, C.Flash)
		Emit.burstAt(CFrame.new(ground), C.Dust)
		Debris.Shards(ground, C.Shards)
		-- The slash decal is centred half its length back along the path.
		local slashLength = C.Decal.Length or C.Decal.Radius * 2
		local decalCenter = ground - flatDirection * (slashLength / 2)
		GroundDecal.Spawn(decalCenter, C.Decal, flatDirection)
		CameraShake.Preset(C.Shake, ground)
	end)
end

-- Typed export: the checker verifies this module matches Types.SpellModule.
local module: Types.SpellModule = { Play = GaleReaper.Play }
return module
