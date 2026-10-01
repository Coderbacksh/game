--!strict
--[[
	OrbitTrail
	==========
	White ring trails that orbit a character (or any moving centre). Each
	orbit is an invisible anchored part repositioned every frame on a tilted
	circle around the centre; a Trail between two attachments on that part
	draws the glowing ring. Optional RiseSpeed turns the circle into a
	rising helix (used for spiralling smoke).

	  local handle = OrbitTrail.OnCharacter(character, orbit, style, duration?)
	  handle.Stop()  -- optional; also stops automatically after `duration`
	                 -- or when the centre disappears

	After stopping, the part lives for one trail Lifetime so the tail fades
	out naturally, then Debris removes it.
]]

local Config = require(script.Parent.Parent.Config)
local Emit = require(script.Parent.Emit)
local Types = require(script.Parent.Types)

local OrbitTrail = {}

function OrbitTrail.Start(
	getCenter: () -> CFrame?,
	orbit: Types.OrbitParams,
	style: Types.TrailStyle,
	duration: number?
): Types.Handle
	local part = Emit.part(Config.General.AnchorSize, style.Color, Enum.Material.SmoothPlastic)
	part.Name = Config.OrbitTrail.PartName
	part.Transparency = 1

	local halfWidth = style.Width / 2
	local a0 = Emit.attachment(part, CFrame.new(0, halfWidth, 0))
	local a1 = Emit.attachment(part, CFrame.new(0, -halfWidth, 0))

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = style.Lifetime
	trail.Color = ColorSequence.new(style.Color)
	trail.Transparency = style.Transparency
	trail.LightEmission = style.LightEmission
	trail.LightInfluence = 0
	trail.Brightness = style.Brightness
	trail.FaceCamera = true
	trail.MinLength = 0
	trail.Enabled = false
	trail.Parent = part

	local tilt = CFrame.Angles(math.rad(orbit.Tilt.X), math.rad(orbit.Tilt.Y), math.rad(orbit.Tilt.Z))
	local angle = orbit.Phase
	local height = orbit.Height
	local riseSpeed = orbit.RiseSpeed or 0

	local function place(): boolean
		local center = getCenter()
		if center == nil then
			return false
		end
		part.CFrame = center
			* CFrame.new(0, height, 0)
			* tilt
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(orbit.Radius, 0, 0)
		return true
	end

	if not place() then
		part:Destroy()
		return { Stop = function() end }
	end
	part.Parent = Emit.folder()
	trail.Enabled = true

	local stopStep = Emit.step(duration or math.huge, function(_alpha, dt)
		angle += orbit.Speed * dt
		height += riseSpeed * dt
		return not place()
	end, function()
		trail.Enabled = false
		Emit.cleanup(part, style.Lifetime)
	end)

	return { Stop = stopStep }
end

-- Orbit around a character's HumanoidRootPart (position only, so the ring
-- does not swing when the character turns).
function OrbitTrail.OnCharacter(
	character: Model,
	orbit: Types.OrbitParams,
	style: Types.TrailStyle,
	duration: number?
): Types.Handle
	return OrbitTrail.Start(function(): CFrame?
		local root = Emit.root(character)
		if root == nil or not character.Parent then
			return nil
		end
		return CFrame.new(root.Position)
	end, orbit, style, duration)
end

return OrbitTrail
