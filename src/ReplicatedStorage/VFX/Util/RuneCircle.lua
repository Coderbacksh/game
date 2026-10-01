--!strict
--[[
	RuneCircle
	==========
	A magic seal drawn with glowing Beams (client only): outer circle, inner
	circle, a star polygon {StarPoints/StarStep} and radial tick marks. The
	lines "draw themselves" in order over DrawTime, the whole seal rotates
	slowly, holds, then fades out and is destroyed.

	  local handle = RuneCircle.Spawn(cframe, params)
	  -- seal lies in the XZ plane of `cframe`
	  handle.Stop() -- fade out early (optional)

	If Config.Textures.Rune is uploaded, a textured decal disc is added
	under the beam lines as well.
]]

local Config = require(script.Parent.Parent.Config)
local Emit = require(script.Parent.Emit)
local Types = require(script.Parent.Types)

local Settings = Config.RuneCircle

type Line = {
	From: Vector3,
	To: Vector3,
	Start: number, -- 0..1 fraction of DrawTime when this line starts drawing
	A1: Attachment,
	Beam: Beam,
}

local RuneCircle = {}

local function onCircle(radius: number, angle: number): Vector3
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

function RuneCircle.Spawn(cframe: CFrame, params: Types.RuneCircleParams): Types.Handle
	local base = cframe * CFrame.new(0, params.Lift, 0)
	local host = Emit.anchor(base)
	local lines: { Line } = {}

	local function addLine(from: Vector3, to: Vector3, start: number)
		local a0 = Emit.attachment(host, CFrame.new(from))
		local a1 = Emit.attachment(host, CFrame.new(from))
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(params.Color)
		beam.LightEmission = params.LightEmission
		beam.LightInfluence = 0
		beam.Brightness = params.Brightness
		beam.Width0 = params.Width
		beam.Width1 = params.Width
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Enabled = false
		beam.Parent = host
		table.insert(lines, { From = from, To = to, Start = start, A1 = a1, Beam = beam })
	end

	local outer = params.Radius
	local inner = params.Radius * params.InnerRadiusScale
	local segments = Settings.ArcSegments
	local order = Settings.DrawOrder

	-- Circles, drawn around their circumference.
	for i = 1, segments do
		local a = (i - 1) / segments * math.pi * 2
		local b = i / segments * math.pi * 2
		local f = (i - 1) / segments
		addLine(onCircle(outer, a), onCircle(outer, b), order.Outer[1] + (order.Outer[2] - order.Outer[1]) * f)
		addLine(onCircle(inner, a), onCircle(inner, b), order.Inner[1] + (order.Inner[2] - order.Inner[1]) * f)
	end

	-- Star polygon inside the inner circle.
	local points = math.max(params.StarPoints, 3)
	for k = 0, points - 1 do
		local a = k / points * math.pi * 2
		local b = ((k + params.StarStep) % points) / points * math.pi * 2
		local f = k / points
		addLine(onCircle(inner, a), onCircle(inner, b), order.Star[1] + (order.Star[2] - order.Star[1]) * f)
	end

	-- Tick marks between the circles.
	for t = 0, params.Ticks - 1 do
		local a = t / params.Ticks * math.pi * 2
		local f = t / math.max(params.Ticks, 1)
		addLine(
			onCircle(outer, a),
			onCircle(outer - params.TickLength, a),
			order.Ticks[1] + (order.Ticks[2] - order.Ticks[1]) * f
		)
	end

	-- Optional textured disc once a rune texture is uploaded.
	local decal: Decal? = nil
	if Config.Textures.Rune ~= Config.PlaceholderTexture then
		local disc = Emit.part(
			Vector3.new(outer * 2, Config.Shockwave.FlatThickness, outer * 2),
			params.Color,
			Enum.Material.SmoothPlastic
		)
		disc.Transparency = 1
		disc.CFrame = base
		disc.Parent = host
		local d = Instance.new("Decal")
		d.Texture = Config.Textures.Rune
		d.Color3 = params.Color
		d.Face = Enum.NormalId.Top
		d.Transparency = 1
		d.Parent = disc
		Emit.tween(d, params.DrawTime, { Transparency = 0 })
		decal = d
	end

	local drawDuration = params.DrawTime * Settings.LineDrawFraction
	local fadeStart: number? = nil
	local angle = 0
	local holdEnd = params.DrawTime + params.Hold
	local stopFade = false

	Emit.step(math.huge, function(_alpha, dt, elapsed)
		if not host.Parent then
			return true
		end
		angle += params.RotationSpeed * dt
		host.CFrame = base * CFrame.Angles(0, angle, 0)

		-- Draw phase: each line grows from its start point to its end point.
		for _, line in lines do
			local startTime = line.Start * (params.DrawTime - drawDuration)
			local t = math.clamp((elapsed - startTime) / drawDuration, 0, 1)
			if t > 0 then
				line.Beam.Enabled = true
				line.A1.Position = line.From:Lerp(line.To, t)
			end
		end

		if fadeStart == nil and (elapsed >= holdEnd or stopFade) then
			fadeStart = elapsed
			if decal then
				Emit.tween(decal, params.FadeTime, { Transparency = 1 })
			end
		end
		local started = fadeStart
		if started then
			local fade = math.clamp((elapsed - started) / params.FadeTime, 0, 1)
			local transparency = NumberSequence.new(fade)
			for _, line in lines do
				line.Beam.Transparency = transparency
			end
			return fade >= 1
		end
		return false
	end, function()
		host:Destroy()
	end)

	-- Safety net: never outlive the configured timeline.
	Emit.cleanup(host, holdEnd + params.FadeTime + Config.General.CleanupPadding)

	return {
		Stop = function()
			stopFade = true
		end,
	}
end

return RuneCircle
