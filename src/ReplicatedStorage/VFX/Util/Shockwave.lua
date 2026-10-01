--!strict
--[[
	Shockwave
	=========
	Expanding ring made from a loop of camera-facing Beams (client only).
	Every frame the ring's attachments are pushed outward, the beam width
	thins and the transparency rises, so the ring needs no textures.

	  * Shockwave.Ring(cframe, params)   - full ring (or partial arc when
	                                       params.ArcSpan is set) lying in the
	                                       XZ plane of `cframe`
	  * Shockwave.Ground(position, params) - flat ring on the ground, plus a
	                                       textured ring decal when
	                                       Config.Textures.Ring is uploaded

	The host part is removed by Debris right after the ring finishes.
]]

local Config = require(script.Parent.Parent.Config)
local Emit = require(script.Parent.Emit)
local Types = require(script.Parent.Types)

local Shockwave = {}

local function easeOut(alpha: number): number
	return 1 - (1 - alpha) ^ 3
end

function Shockwave.Ring(cframe: CFrame, params: Types.RingParams)
	local host = Emit.anchor(cframe, params.Duration + (params.Delay or 0))
	local span = params.ArcSpan or math.pi * 2
	local closed = params.ArcSpan == nil
	local segments = math.max(params.Segments, 3)
	local pointCount = if closed then segments else segments + 1

	local attachments: { Attachment } = {}
	local angles: { number } = {}
	for i = 1, pointCount do
		local angle = -span / 2 + span * ((i - 1) / segments)
		angles[i] = angle
		attachments[i] = Emit.attachment(host)
	end

	local beams: { Beam } = {}
	for i = 1, segments do
		local beam = Instance.new("Beam")
		beam.Attachment0 = attachments[i]
		beam.Attachment1 = attachments[if closed then (i % pointCount) + 1 else i + 1]
		beam.Color = ColorSequence.new(params.Color)
		beam.LightEmission = params.LightEmission
		beam.LightInfluence = 0
		beam.Brightness = params.Brightness
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Width0 = params.Width
		beam.Width1 = params.Width
		beam.Transparency = NumberSequence.new(1)
		beam.Parent = host
		beams[i] = beam
	end

	local function layout(alpha: number)
		local eased = easeOut(alpha)
		local radius = params.StartRadius + (params.EndRadius - params.StartRadius) * eased
		for i, attachment in attachments do
			local angle = angles[i]
			attachment.Position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		end
		local width = params.Width * (1 - eased)
		local transparency = NumberSequence.new(alpha * alpha)
		for i, beam in beams do
			-- Partial arcs taper at their ends.
			local w0, w1 = width, width
			if not closed then
				w0 = width * math.sin(math.pi * (i - 1) / segments)
				w1 = width * math.sin(math.pi * i / segments)
			end
			beam.Width0 = w0
			beam.Width1 = w1
			beam.Transparency = transparency
		end
	end

	local function start()
		if not host.Parent then
			return
		end
		layout(0)
		Emit.step(params.Duration, function(alpha)
			if not host.Parent then
				return true
			end
			layout(alpha)
			return false
		end)
	end

	if params.Delay and params.Delay > 0 then
		task.delay(params.Delay, start)
	else
		start()
	end
end

function Shockwave.Ground(position: Vector3, params: Types.RingParams)
	local cframe = Emit.groundCFrame(position)
	Shockwave.Ring(cframe, params)

	if Config.Textures.Ring == Config.PlaceholderTexture then
		return
	end
	local delayTime = params.Delay or 0
	local thickness = Config.Shockwave.FlatThickness
	local disc = Emit.part(
		Vector3.new(params.StartRadius * 2, thickness, params.StartRadius * 2),
		params.Color,
		Enum.Material.SmoothPlastic
	)
	disc.Transparency = 1
	disc.CFrame = cframe
	disc.Parent = Emit.folder()
	local decal = Instance.new("Decal")
	decal.Texture = Config.Textures.Ring
	decal.Color3 = params.Color
	decal.Face = Enum.NormalId.Top
	decal.Parent = disc
	local endSize = Vector3.new(params.EndRadius * 2, thickness, params.EndRadius * 2)
	Emit.tween(disc, params.Duration, { Size = endSize }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, delayTime)
	Emit.tween(decal, params.Duration, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, delayTime)
	Emit.cleanup(disc, params.Duration + delayTime + Config.General.CleanupPadding)
end

return Shockwave
