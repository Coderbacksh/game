--!strict
--[[
	CameraShake
	===========
	Client-only, additive Perlin-noise camera shake. Any number of shakes can
	run at once; their offsets are summed and applied once per frame, right
	after the default camera scripts (RenderPriority.Camera + 1), so the
	camera never drifts. Strength falls off with distance from the source.
	The render step unbinds itself when the last shake ends.

	  CameraShake.Shake(Config.CameraShake.Presets.Heavy, impactPosition)
	  CameraShake.Preset("Heavy", impactPosition)
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Types)

local Settings = Config.CameraShake

type ActiveShake = {
	Magnitude: number,
	Frequency: number,
	Duration: number,
	Start: number,
	Source: Vector3?,
	Seed: number,
}

local CameraShake = {}

local active: { ActiveShake } = {}
local bound = false
local rng = Random.new()

local function distanceScale(source: Vector3?, camera: Camera): number
	if source == nil then
		return 1
	end
	local distance = (camera.CFrame.Position - source).Magnitude
	if distance <= Settings.MinDistance then
		return 1
	end
	local range = Settings.MaxDistance - Settings.MinDistance
	return math.clamp(1 - (distance - Settings.MinDistance) / range, 0, 1)
end

local function unbind()
	if bound then
		RunService:UnbindFromRenderStep(Settings.BindName)
		bound = false
	end
end

local function update()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local now = os.clock()
	local offset = Vector3.zero
	local rotation = Vector3.zero

	for index = #active, 1, -1 do
		local shake = active[index]
		local t = now - shake.Start
		if t >= shake.Duration then
			table.remove(active, index)
		else
			local fade = 1 - t / shake.Duration
			local strength = shake.Magnitude * fade * fade * distanceScale(shake.Source, camera)
			local n = t * shake.Frequency
			local s = shake.Seed
			offset += Vector3.new(math.noise(n, s, 0), math.noise(s, n, 0), math.noise(0, s, n)) * strength
			rotation += Vector3.new(math.noise(n, s, 1), math.noise(s, n, 1), math.noise(1, s, n)) * strength * Settings.RotationScale
		end
	end

	if #active == 0 then
		unbind()
		return
	end

	camera.CFrame = camera.CFrame
		* CFrame.new(offset)
		* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
end

-- Starts a shake. `source` enables distance falloff.
function CameraShake.Shake(params: Types.ShakeParams, source: Vector3?)
	if not RunService:IsClient() then
		return
	end
	table.insert(active, {
		Magnitude = params.Magnitude,
		Frequency = params.Frequency,
		Duration = params.Duration,
		Start = os.clock(),
		Source = source,
		Seed = rng:NextNumber(0, 1000),
	})
	if not bound then
		bound = true
		RunService:BindToRenderStep(Settings.BindName, Enum.RenderPriority.Camera.Value + 1, update)
	end
end

---------------------------------------------------------------------------
-- FOV punch: the camera's field of view kicks out and eases back. Punches
-- add together; the original FOV is restored exactly when the last ends.
---------------------------------------------------------------------------
type ActivePunch = { Delta: number, InTime: number, OutTime: number, Start: number }
local punches: { ActivePunch } = {}
local baseFov: number? = nil
local punchConnection: RBXScriptConnection? = nil

local function punchOffset(punch: ActivePunch, t: number): number
	if t < punch.InTime then
		local a = t / punch.InTime
		return punch.Delta * (1 - (1 - a) ^ 3)
	end
	local a = math.clamp((t - punch.InTime) / punch.OutTime, 0, 1)
	return punch.Delta * (1 - a) ^ 2
end

function CameraShake.Punch(params: Types.PunchParams, source: Vector3?)
	local camera = Workspace.CurrentCamera
	if not RunService:IsClient() or camera == nil then
		return
	end
	local scale = distanceScale(source, camera)
	if scale <= 0 then
		return
	end
	if baseFov == nil then
		baseFov = camera.FieldOfView
	end
	table.insert(
		punches,
		{ Delta = params.FovDelta * scale, InTime = params.InTime, OutTime = params.OutTime, Start = os.clock() }
	)
	if punchConnection then
		return
	end
	punchConnection = RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		local base = baseFov
		if cam == nil or base == nil then
			return
		end
		local now = os.clock()
		local total = 0
		for index = #punches, 1, -1 do
			local punch = punches[index]
			local t = now - punch.Start
			if t >= punch.InTime + punch.OutTime then
				table.remove(punches, index)
			else
				total += punchOffset(punch, t)
			end
		end
		cam.FieldOfView = math.clamp(base + total, Settings.MinFov, Settings.MaxFov)
		if #punches == 0 then
			cam.FieldOfView = base
			baseFov = nil
			local connection = punchConnection
			punchConnection = nil
			if connection then
				connection:Disconnect()
			end
		end
	end)
end

function CameraShake.PunchPreset(name: string, source: Vector3?)
	local preset = (Settings.Punches :: any)[name] :: Types.PunchParams?
	if preset then
		CameraShake.Punch(preset, source)
	else
		warn("[VFX] Unknown camera punch preset:", name)
	end
end

-- Shake using a named preset from Config.CameraShake.Presets.
function CameraShake.Preset(name: string, source: Vector3?)
	local preset = (Settings.Presets :: any)[name] :: Types.ShakeParams?
	if preset then
		CameraShake.Shake(preset, source)
	else
		warn("[VFX] Unknown camera shake preset:", name)
	end
end

return CameraShake
