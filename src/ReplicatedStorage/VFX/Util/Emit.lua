--!strict
--[[
	Emit
	====
	Low-level helpers shared by every effect (client only):

	  * Emit.folder()            - the Workspace folder all VFX instances live in
	  * Emit.anchor(cf, life)    - invisible, anchored, non-colliding host part
	  * Emit.attachment(...)     - attachment builder
	  * Emit.emitter(parent, s)  - ParticleEmitter from a Types.EmitterSpec
	  * Emit.burstAt(cf, b)      - one-shot :Emit(n) burst that cleans itself up
	  * Emit.pulse(...)          - repeated :Emit(n) bursts for a duration
	  * Emit.tween / fadeSequence- TweenService helpers (always finite)
	  * Emit.step(dur, fn)       - per-frame callback that disconnects itself
	  * Emit.cleanup(inst, t)    - Debris service removal
	  * Emit.groundAt(pos)       - raycast down for ground position + normal

	Nothing here yields.
]]

local DebrisService = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Types)

local General = Config.General
local rng = Random.new()

local Emit = {}

local cachedFolder: Folder? = nil

-- Returns (and lazily creates) the client-side folder that holds all VFX.
function Emit.folder(): Folder
	local current = cachedFolder
	if current and current.Parent then
		return current
	end
	local existing = Workspace:FindFirstChild(General.FolderName)
	if existing and existing:IsA("Folder") then
		cachedFolder = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = General.FolderName
	folder.Parent = Workspace
	cachedFolder = folder
	return folder
end

-- Schedules an instance for removal (Debris never yields).
function Emit.cleanup(instance: Instance, seconds: number)
	DebrisService:AddItem(instance, seconds)
end

-- Makes a part invisible, anchored and inert to physics / raycasts.
function Emit.makeInert(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Locked = true
end

-- Invisible host part for attachments, emitters, lights and beams.
-- Pass a lifetime to have it (and everything parented to it) auto-removed.
function Emit.anchor(cframe: CFrame, lifetime: number?, size: Vector3?): Part
	local part = Instance.new("Part")
	part.Name = "VFXAnchor"
	part.Transparency = 1
	part.Size = size or General.AnchorSize
	part.CFrame = cframe
	Emit.makeInert(part)
	part.Parent = Emit.folder()
	if lifetime then
		Emit.cleanup(part, lifetime + General.CleanupPadding)
	end
	return part
end

-- Visible effect part (shards, spikes, pages...). Not parented.
function Emit.part(size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = "VFXPart"
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	Emit.makeInert(part)
	return part
end

function Emit.attachment(parent: BasePart, offset: CFrame?): Attachment
	local attachment = Instance.new("Attachment")
	attachment.CFrame = offset or CFrame.identity
	attachment.Parent = parent
	return attachment
end

-- Builds a ParticleEmitter from a spec. Burst emitters stay disabled with
-- Rate 0 and are fired with :Emit(n); looping emitters set spec.Rate.
function Emit.emitter(parent: Instance, spec: Types.EmitterSpec): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = spec.Rate or 0
	emitter.Enabled = spec.Rate ~= nil
	emitter.Texture = spec.Texture
	emitter.Color = spec.Color
	emitter.Size = spec.Size
	emitter.Transparency = spec.Transparency
	emitter.Lifetime = spec.Lifetime
	emitter.Speed = spec.Speed
	emitter.SpreadAngle = spec.SpreadAngle or Vector2.zero
	emitter.LightEmission = spec.LightEmission or 0
	emitter.LightInfluence = spec.LightInfluence or 0
	emitter.Brightness = spec.Brightness or 1
	emitter.Rotation = spec.Rotation or NumberRange.new(0)
	emitter.RotSpeed = spec.RotSpeed or NumberRange.new(0)
	emitter.Acceleration = spec.Acceleration or Vector3.zero
	emitter.Drag = spec.Drag or 0
	emitter.ZOffset = spec.ZOffset or 0
	emitter.Orientation = spec.Orientation or Enum.ParticleOrientation.FacingCamera
	emitter.LockedToPart = spec.LockedToPart or false
	if spec.Squash then
		emitter.Squash = spec.Squash
	end
	if spec.Shape then
		emitter.Shape = spec.Shape
	end
	if spec.ShapeInOut then
		emitter.ShapeInOut = spec.ShapeInOut
	end
	if spec.ShapeStyle then
		emitter.ShapeStyle = spec.ShapeStyle
	end
	if spec.EmissionDirection then
		emitter.EmissionDirection = spec.EmissionDirection
	end
	if spec.Flipbook and Config.Flipbook.Enabled then
		emitter.FlipbookLayout = if spec.LargeFlipbook then Config.Flipbook.LargeLayout else Config.Flipbook.Layout
		emitter.FlipbookMode = Config.Flipbook.Mode
		emitter.FlipbookFramerate = Config.Flipbook.Framerate
		emitter.FlipbookStartRandom = Config.Flipbook.StartRandom
	end
	emitter.Parent = parent
	return emitter
end

-- One-shot burst at a CFrame. The host part lives exactly as long as the
-- longest particle, then Debris removes it. `size` gives the host part a
-- volume for Shape-based emitters.
function Emit.burstAt(cframe: CFrame, burst: Types.BurstSpec, size: Vector3?): ParticleEmitter
	local host = Emit.anchor(cframe, burst.Spec.Lifetime.Max, size)
	local emitter = Emit.emitter(host, burst.Spec)
	emitter:Emit(burst.Count)
	return emitter
end

-- Burst on an existing emitter.
function Emit.burst(emitter: ParticleEmitter, count: number)
	emitter:Emit(count)
end

-- Per-frame callback for `duration` seconds (math.huge = until stopped).
-- fn(alpha 0..1, dt, elapsed) may return true to stop early. onDone runs
-- exactly once when the step ends for any reason. Returns a stop function.
function Emit.step(
	duration: number,
	fn: (alpha: number, dt: number, elapsed: number) -> boolean?,
	onDone: (() -> ())?
): () -> ()
	local elapsed = 0
	local connection: RBXScriptConnection? = nil
	local finished = false

	local function stop()
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if onDone then
			onDone()
		end
	end

	connection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		local alpha = if duration == math.huge then 0 else math.clamp(elapsed / duration, 0, 1)
		local ok, result = pcall(fn, alpha, dt, elapsed)
		if not ok then
			warn("[VFX] step callback errored:", result)
			stop()
			return
		end
		if result == true or elapsed >= duration then
			stop()
		end
	end)
	return stop
end

-- Repeated :Emit(count) every `interval` seconds for `duration` seconds.
function Emit.pulse(emitter: ParticleEmitter, count: number, interval: number, duration: number): () -> ()
	if interval <= 0 then
		-- Misconfigured interval: emit once instead of looping forever.
		emitter:Emit(count)
		return function() end
	end
	local accumulator = interval -- fire immediately on the first frame
	return Emit.step(duration, function(_alpha, dt)
		if not emitter.Parent then
			return true
		end
		accumulator += dt
		while accumulator >= interval do
			accumulator -= interval
			emitter:Emit(count)
		end
		return false
	end)
end

-- Creates and plays a finite tween (RepeatCount 0, never reverses).
function Emit.tween(
	instance: Instance,
	duration: number,
	goals: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?,
	delayTime: number?
): Tween
	local info = TweenInfo.new(
		duration,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out,
		0,
		false,
		delayTime or 0
	)
	local tween = TweenService:Create(instance, info, goals)
	tween:Play()
	return tween
end

-- NumberSequence properties (Beam/Trail Transparency) cannot be tweened
-- directly, so this tweens a NumberValue proxy and writes a uniform
-- sequence each change. The proxy is destroyed when the tween ends.
function Emit.fadeSequence(instance: Instance, property: string, from: number, to: number, duration: number): Tween
	local proxy = Instance.new("NumberValue")
	proxy.Value = from
	local target = instance :: any
	target[property] = NumberSequence.new(from)
	local connection = proxy.Changed:Connect(function(value: number)
		if instance.Parent then
			target[property] = NumberSequence.new(value)
		end
	end)
	local tween = Emit.tween(proxy, duration, { Value = to }, Enum.EasingStyle.Linear)
	tween.Completed:Once(function()
		connection:Disconnect()
		proxy:Destroy()
	end)
	return tween
end

-- Raycasts straight down from above `position`, ignoring characters and
-- VFX. Returns the ground point and surface normal (or the input position
-- and world up when nothing is hit).
function Emit.groundAt(position: Vector3): (Vector3, Vector3)
	local ignore: { Instance } = { Emit.folder() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = false

	local origin = position + Vector3.yAxis * General.GroundRayHeight
	local direction = -Vector3.yAxis * (General.GroundRayHeight + General.GroundRayDepth)
	local result = Workspace:Raycast(origin, direction, params)
	if result then
		return result.Position, result.Normal
	end
	return position, Vector3.yAxis
end

-- CFrame on the ground whose UpVector is the surface normal. `forward`
-- (optional) sets the yaw; otherwise a random yaw is used.
function Emit.groundCFrame(position: Vector3, forward: Vector3?): CFrame
	local point, normal = Emit.groundAt(position)
	local look: Vector3
	if forward and forward.Magnitude >= 1e-3 then
		look = forward
	else
		local angle = rng:NextNumber(0, math.pi * 2)
		look = Vector3.new(math.cos(angle), 0, math.sin(angle))
	end
	-- Project the look direction onto the ground plane.
	local flat = look - normal * look:Dot(normal)
	if flat.Magnitude < 1e-3 then
		flat = normal:Cross(Vector3.xAxis)
	end
	local right = flat.Unit:Cross(normal)
	return CFrame.fromMatrix(point + normal * General.GroundOffset, right, normal)
end

-- Root part of a character model, if it still exists.
function Emit.root(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Random helpers ------------------------------------------------------------
function Emit.random(min: number, max: number): number
	return rng:NextNumber(min, max)
end

function Emit.randomInt(min: number, max: number): number
	return rng:NextInteger(min, max)
end

function Emit.randomUnit(): Vector3
	return rng:NextUnitVector()
end

return Emit
