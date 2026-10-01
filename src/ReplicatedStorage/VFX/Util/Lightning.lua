--!strict
--[[
	Lightning
	=========
	Jagged electric bolts built from chains of straight Beams (client only).
	Each bolt is a polyline of attachments with random perpendicular offsets
	(strongest in the middle, zero at the ends). The offsets are re-rolled
	every `FlickerInterval` seconds so the bolt crackles, and optional
	branches fork off the main chain. When Duration ends the bolt fades over
	FadeTime and its host part is destroyed.

	  * Lightning.Strike(from, to, params)          - fixed endpoints
	  * Lightning.Crawl(from, to, crawlTime, params) - tip creeps from -> to
	  * Lightning.Crackle(center, radius, count, params) - arcs jumping around a core
	  * Lightning.GroundArcs(center, arcParams)     - arcs crawling outward on the floor
	  * Lightning.Bolt(getEndpoints, params)        - generic form used by the above
]]

local Config = require(script.Parent.Parent.Config)
local Emit = require(script.Parent.Emit)
local Types = require(script.Parent.Types)

local Settings = Config.Lightning

export type GroundArcParams = {
	Count: number,
	Length: number,
	CrawlTime: number,
	Bolt: Types.BoltParams,
	Lift: number,
}

type Chain = {
	Attachments: { Attachment },
	Beams: { Beam },
	Widths: { number },
}

type Branch = {
	Chain: Chain,
	RootIndex: number,
	Amplitude: number,
}

local Lightning = {}

local function basis(direction: Vector3): (Vector3, Vector3)
	local dir = if direction.Magnitude > 1e-4 then direction.Unit else Vector3.yAxis
	local reference = if math.abs(dir:Dot(Vector3.yAxis)) > Settings.MinPerpendicularCheck
		then Vector3.xAxis
		else Vector3.yAxis
	local u = dir:Cross(reference).Unit
	local v = dir:Cross(u).Unit
	return u, v
end

local function buildChain(host: BasePart, segments: number, params: Types.BoltParams, widthScale: number): Chain
	local attachments: { Attachment } = {}
	for i = 1, segments + 1 do
		attachments[i] = Emit.attachment(host)
	end
	local beams: { Beam } = {}
	local widths: { number } = {}
	local baseTransparency = params.Transparency or 0
	for i = 1, segments do
		local beam = Instance.new("Beam")
		beam.Attachment0 = attachments[i]
		beam.Attachment1 = attachments[i + 1]
		beam.Color = ColorSequence.new(params.Color)
		beam.LightEmission = params.LightEmission
		beam.LightInfluence = 0
		beam.Brightness = params.Brightness
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Transparency = NumberSequence.new(baseTransparency)
		-- Taper from full width at the start to EndWidthScale at the tip.
		local t0 = (i - 1) / segments
		local t1 = i / segments
		local scale = params.Width * widthScale
		beam.Width0 = scale * (1 + (params.EndWidthScale - 1) * t0)
		beam.Width1 = scale * (1 + (params.EndWidthScale - 1) * t1)
		widths[(i - 1) * 2 + 1] = beam.Width0
		widths[(i - 1) * 2 + 2] = beam.Width1
		beam.Parent = host
		beams[i] = beam
	end
	return { Attachments = attachments, Beams = beams, Widths = widths }
end

local function layoutChain(chain: Chain, from: Vector3, to: Vector3, amplitude: number)
	local u, v = basis(to - from)
	local count = #chain.Attachments - 1
	for i, attachment in chain.Attachments do
		local t = (i - 1) / count
		local envelope = math.sin(math.pi * t)
		local offset = (u * Emit.random(-1, 1) + v * Emit.random(-1, 1)) * amplitude * envelope
		attachment.WorldPosition = from:Lerp(to, t) + offset
	end
end

local function setFade(chain: Chain, fade: number, baseTransparency: number)
	local transparency = NumberSequence.new(baseTransparency + (1 - baseTransparency) * fade)
	local keep = 1 - fade
	for i, beam in chain.Beams do
		beam.Transparency = transparency
		beam.Width0 = chain.Widths[(i - 1) * 2 + 1] * keep
		beam.Width1 = chain.Widths[(i - 1) * 2 + 2] * keep
	end
end

-- Generic bolt. getEndpoints(elapsed) is called on every rebuild, so
-- endpoints can move (crawl) or jump (crackle).
function Lightning.Bolt(getEndpoints: (elapsed: number) -> (Vector3, Vector3), params: Types.BoltParams): Types.Handle
	local from, to = getEndpoints(0)
	local total = params.Duration + params.FadeTime
	local host = Emit.anchor(CFrame.new(from), total)
	local baseTransparency = params.Transparency or 0

	local main = buildChain(host, math.max(params.Segments, 1), params, 1)
	local branches: { Branch } = {}
	local branchParams = params.Branches
	if branchParams and params.Segments > 2 then
		for _ = 1, branchParams.Count do
			table.insert(branches, {
				Chain = buildChain(host, math.max(branchParams.Segments, 1), params, branchParams.WidthScale),
				RootIndex = Emit.randomInt(2, params.Segments),
				Amplitude = branchParams.Amplitude,
			})
		end
	end

	local function rebuild(elapsed: number)
		from, to = getEndpoints(elapsed)
		layoutChain(main, from, to, params.Amplitude)
		if branchParams then
			local length = (to - from).Magnitude * branchParams.LengthScale
			local direction = if (to - from).Magnitude > 1e-4 then (to - from).Unit else Vector3.yAxis
			for _, branch in branches do
				local start = main.Attachments[branch.RootIndex].WorldPosition
				local deviation = (direction + Emit.randomUnit() * Settings.BranchDeviation).Unit
				layoutChain(branch.Chain, start, start + deviation * length, branch.Amplitude)
			end
		end
	end

	rebuild(0)
	local accumulator = 0
	local stopStep = Emit.step(total, function(_alpha, dt, elapsed)
		if not host.Parent then
			return true
		end
		accumulator += dt
		if accumulator >= params.FlickerInterval then
			accumulator = 0
			rebuild(elapsed)
		end
		if elapsed > params.Duration and params.FadeTime > 0 then
			local fade = math.clamp((elapsed - params.Duration) / params.FadeTime, 0, 1)
			setFade(main, fade, baseTransparency)
			for _, branch in branches do
				setFade(branch.Chain, fade, baseTransparency)
			end
		end
		return false
	end, function()
		host:Destroy()
	end)

	return { Stop = stopStep }
end

function Lightning.Strike(from: Vector3, to: Vector3, params: Types.BoltParams): Types.Handle
	return Lightning.Bolt(function()
		return from, to
	end, params)
end

function Lightning.Crawl(from: Vector3, to: Vector3, crawlTime: number, params: Types.BoltParams): Types.Handle
	return Lightning.Bolt(function(elapsed: number)
		local t = if crawlTime > 0 then math.clamp(elapsed / crawlTime, 0, 1) else 1
		return from, from:Lerp(to, t)
	end, params)
end

-- `count` short arcs that jump to new random spots around `center`.
function Lightning.Crackle(center: Vector3, radius: number, count: number, params: Types.BoltParams)
	for _ = 1, count do
		Lightning.Bolt(function()
			local a = center + Emit.randomUnit() * radius * Emit.random(Settings.CrackleInnerScale, 1)
			local b = center + Emit.randomUnit() * radius * Emit.random(Settings.CrackleInnerScale, 1)
			return a, b
		end, params)
	end
end

-- Arcs that crawl outward along the ground from `center`.
function Lightning.GroundArcs(center: Vector3, arc: GroundArcParams)
	local ground = Emit.groundAt(center)
	local lift = Vector3.yAxis * arc.Lift
	for i = 1, arc.Count do
		local angle = (i / arc.Count) * math.pi * 2 + Emit.random(-Settings.ArcAngleJitter, Settings.ArcAngleJitter)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local reach = arc.Length * Emit.random(Settings.ArcLengthMin, 1)
		local endPoint = Emit.groundAt(ground + direction * reach)
		Lightning.Crawl(ground + lift, endPoint + lift, arc.CrawlTime, arc.Bolt)
	end
end

return Lightning
