--!strict
--[[
	Sphere
	======
	Expanding energy spheres (client only): a Ball part that swells from
	StartSize to EndSize while fading out. Neon material reads as a solid
	burst of light; ForceField material gives a shimmering shell. Removed by
	Debris after its tween.

	  Sphere.Burst(position, params)
]]

local Config = require(script.Parent.Parent.Config)
local Emit = require(script.Parent.Emit)
local Types = require(script.Parent.Types)

local Sphere = {}

local function burstNow(position: Vector3, params: Types.SphereParams)
	local ball = Emit.part(Vector3.one * params.StartSize, params.Color, params.Material)
	ball.Name = "EnergySphere"
	ball.Shape = Enum.PartType.Ball
	ball.Transparency = params.StartTransparency
	ball.CFrame = CFrame.new(position)
	ball.Parent = Emit.folder()
	Emit.tween(
		ball,
		params.Duration,
		{ Size = Vector3.one * params.EndSize },
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.Out
	)
	Emit.tween(ball, params.Duration, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Emit.cleanup(ball, params.Duration + Config.General.CleanupPadding)
end

function Sphere.Burst(position: Vector3, params: Types.SphereParams)
	local delayTime = params.Delay or 0
	if delayTime > 0 then
		task.delay(delayTime, burstNow, position, params)
	else
		burstNow(position, params)
	end
end

-- Several spheres at once (e.g. a hot white core inside a dark shell).
function Sphere.Layers(position: Vector3, layers: { Types.SphereParams })
	for _, layer in layers do
		Sphere.Burst(position, layer)
	end
end

return Sphere
