--!strict
--[[
	Debris (VFX)
	============
	Floating debris shards (client only). Each shard is an anchored part that:
	  1. rises (and drifts outward) from the ground with a random spin,
	  2. hangs in the air with a slow drift,
	  3. falls back down while fading out, then is destroyed.

	Phases are chained with Tween.Completed, so if a shard is destroyed
	early the chain simply stops. Debris (the Roblox service, aliased
	DebrisService here) guarantees cleanup regardless.

	  Debris.Shards(centerPosition, Config...Shards)
]]

local DebrisService = game:GetService("Debris")

local Config = require(script.Parent.Parent.Config)
local Emit = require(script.Parent.Emit)
local Types = require(script.Parent.Types)

local Debris = {}

local function randomRotation(maxDegrees: number): CFrame
	local r = math.rad(maxDegrees)
	return CFrame.Angles(Emit.random(-r, r), Emit.random(-r, r), Emit.random(-r, r))
end

function Debris.Shards(center: Vector3, params: Types.ShardParams)
	local ground = Emit.groundAt(center)
	local total = params.RiseTime + params.HangTime + params.FallTime + Config.General.CleanupPadding
	local folder = Emit.folder()

	for _ = 1, params.Count do
		local angle = Emit.random(0, math.pi * 2)
		local distance = Emit.random(0, params.StartRadius)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local start = ground + outward * distance + Vector3.yAxis * Config.Debris.SpawnHeight

		local size = Vector3.new(
			Emit.random(params.SizeMin, params.SizeMax),
			Emit.random(params.SizeMin, params.SizeMax),
			Emit.random(params.SizeMin, params.SizeMax)
		)
		local shard = Emit.part(size, params.Color, params.Material)
		shard.Name = "Shard"
		shard.CFrame = CFrame.new(start) * randomRotation(params.SpinMax)
		shard.Parent = folder
		DebrisService:AddItem(shard, total)

		local risePosition = start
			+ Vector3.yAxis * Emit.random(params.RiseMin, params.RiseMax)
			+ outward * params.Spread
		local rise = Emit.tween(shard, params.RiseTime, {
			CFrame = CFrame.new(risePosition) * randomRotation(params.SpinMax),
		}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

		rise.Completed:Once(function(state: Enum.PlaybackState)
			if state ~= Enum.PlaybackState.Completed or not shard.Parent then
				return
			end
			local hangPosition = risePosition + Vector3.yAxis * params.HangDrift
			local hang = Emit.tween(shard, params.HangTime, {
				CFrame = CFrame.new(hangPosition) * shard.CFrame.Rotation * randomRotation(
					params.SpinMax * Config.Debris.HangSpinScale
				),
			}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

			hang.Completed:Once(function(hangState: Enum.PlaybackState)
				if hangState ~= Enum.PlaybackState.Completed or not shard.Parent then
					return
				end
				local fallPosition = hangPosition - Vector3.yAxis * params.FallDistance + outward * params.FallSpread
				Emit.tween(shard, params.FallTime, {
					CFrame = CFrame.new(fallPosition) * randomRotation(params.SpinMax),
					Transparency = 1,
				}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end)
		end)
	end
end

return Debris
