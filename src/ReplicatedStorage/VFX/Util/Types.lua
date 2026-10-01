--!strict
--[[
	Types
	=====
	Shared type definitions for the VFX system (no runtime logic). Utilities
	and spells import these so the Config tables they receive are checked.
]]

-- Data used to build a ParticleEmitter (see Emit.emitter). Optional fields
-- fall back to Roblox defaults.
export type EmitterSpec = {
	Texture: string,
	Color: ColorSequence,
	Size: NumberSequence,
	Transparency: NumberSequence,
	Lifetime: NumberRange,
	Speed: NumberRange,
	SpreadAngle: Vector2?,
	LightEmission: number?,
	Brightness: number?,
	LightInfluence: number?,
	Rotation: NumberRange?,
	RotSpeed: NumberRange?,
	Acceleration: Vector3?,
	Drag: number?,
	ZOffset: number?,
	Orientation: Enum.ParticleOrientation?,
	Squash: NumberSequence?,
	Shape: Enum.ParticleEmitterShape?,
	ShapeInOut: Enum.ParticleEmitterShapeInOut?,
	ShapeStyle: Enum.ParticleEmitterShapeStyle?,
	EmissionDirection: Enum.NormalId?,
	LockedToPart: boolean?,
	Rate: number?, -- set only for looping emitters; bursts use :Emit()
	Flipbook: boolean?, -- apply Config.Flipbook settings
	LargeFlipbook: boolean?, -- use the 8x8 layout instead of 4x4
}

export type BurstSpec = {
	Spec: EmitterSpec,
	Count: number,
}

export type LightParams = {
	Color: Color3,
	Brightness: number,
	Range: number,
	Duration: number?,
}

export type StreakParams = {
	Width: number,
	Height: number,
	Duration: number,
	Color: Color3,
	Brightness: number,
}

export type ScreenFlashParams = {
	Color: Color3,
	Transparency: number,
	Duration: number,
}

export type FlashPreset = {
	Light: LightParams,
	Streak: StreakParams,
	Screen: ScreenFlashParams,
}

export type ShakeParams = {
	Magnitude: number,
	Frequency: number,
	Duration: number,
}

export type CrackParams = {
	Pattern: string, -- "Radial" | "Star" | "Slash"
	Count: number,
	Segments: number,
	Jitter: number,
	Thickness: number,
	Color: Color3,
	Material: Enum.Material,
}

export type GroundDecalParams = {
	Radius: number,
	Length: number?, -- only for elongated (slash) decals
	StartScale: number,
	SpreadTime: number,
	Hold: number, -- 0 = stays until the handle's Fade() is called
	FadeTime: number,
	Color: Color3,
	Texture: string,
	Cracks: CrackParams?,
}

export type RingParams = {
	StartRadius: number,
	EndRadius: number,
	Duration: number,
	Segments: number,
	Width: number,
	Color: Color3,
	LightEmission: number,
	Brightness: number,
	ArcSpan: number?, -- radians; omit for a full ring
	Delay: number?,
}

export type ShardParams = {
	Count: number,
	SizeMin: number,
	SizeMax: number,
	StartRadius: number,
	RiseMin: number,
	RiseMax: number,
	Spread: number,
	RiseTime: number,
	HangTime: number,
	FallTime: number,
	FallDistance: number,
	FallSpread: number,
	SpinMax: number,
	HangDrift: number,
	Color: Color3,
	Material: Enum.Material,
}

export type BranchParams = {
	Count: number,
	LengthScale: number,
	Segments: number,
	Amplitude: number,
	WidthScale: number,
}

export type BoltParams = {
	Segments: number,
	Amplitude: number,
	Width: number,
	EndWidthScale: number,
	Color: Color3,
	LightEmission: number,
	Brightness: number,
	FlickerInterval: number,
	Duration: number,
	FadeTime: number,
	Transparency: number?,
	Branches: BranchParams?,
}

export type OrbitParams = {
	Radius: number,
	Height: number,
	Speed: number, -- rad/s (negative = reverse direction)
	Tilt: Vector3, -- degrees
	Phase: number,
	RiseSpeed: number?, -- studs/s; makes the orbit a rising helix
}

export type TrailStyle = {
	Width: number,
	Lifetime: number,
	Color: Color3,
	Transparency: NumberSequence,
	LightEmission: number,
	Brightness: number,
}

export type RuneCircleParams = {
	Radius: number,
	InnerRadiusScale: number,
	StarPoints: number,
	StarStep: number,
	Ticks: number,
	TickLength: number,
	Width: number,
	Color: Color3,
	LightEmission: number,
	Brightness: number,
	DrawTime: number,
	Hold: number,
	FadeTime: number,
	RotationSpeed: number,
	Lift: number,
}

-- Anything that can be stopped early (orbits, loops, persistent decals).
export type Handle = {
	Stop: () -> (),
}

-- Every spell module returns this shape.
export type SpellModule = {
	Play: (character: Model, targetPosition: Vector3) -> (),
	Stop: ((character: Model) -> ())?,
}

return {}
