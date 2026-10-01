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
	-- Documentation only: the flipbook grid now comes from the texture itself
	-- (Config.TextureLayouts), so these just mark specs meant to animate.
	Flipbook: boolean?,
	LargeFlipbook: boolean?,
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

-- One step of an anime impact-frame sequence (ImpactFrame.lua).
export type ImpactFrameStep = {
	Duration: number,
	Saturation: number,
	Contrast: number,
	Brightness: number,
	TintColor: Color3,
	Overlay: Color3?, -- optional full-screen colour flash for this step
	OverlayTransparency: number?,
}

export type ImpactFrameParams = {
	Frames: { ImpactFrameStep },
	MaxDistance: number, -- viewers further than this see nothing
}

-- Screen-space anime focus lines (FocusLines.lua).
export type FocusLineParams = {
	Count: number,
	InnerRadius: number, -- fraction of the shorter screen side kept clear around the centre
	LengthMin: number, -- fraction of the shorter screen side
	LengthMax: number,
	Thickness: number, -- pixels
	Color: Color3,
	Transparency: number,
	Duration: number,
	RerollInterval: number, -- seconds between re-randomising the lines (flicker)
}

-- Rocks erupting from the ground (RockRing.lua).
export type RockParams = {
	Count: number,
	Radius: number,
	SizeMin: number,
	SizeMax: number,
	TiltMin: number, -- degrees leaning outward
	TiltMax: number,
	RadiusJitter: number,
	Stagger: number, -- seconds between consecutive rocks rising
	RiseTime: number,
	Hold: number,
	SinkTime: number,
	UseGroundMaterial: boolean, -- copy the material/colour of whatever is underneath
	Color: Color3, -- fallback when no ground is found / UseGroundMaterial = false
	Material: Enum.Material,
	Spacing: number?, -- RockRing.Line only: studs between rocks
}

-- Expanding energy sphere (Sphere.lua).
export type SphereParams = {
	StartSize: number,
	EndSize: number,
	Duration: number,
	Color: Color3,
	Material: Enum.Material, -- Neon for light, ForceField for shimmering shells
	StartTransparency: number,
	Delay: number?,
}

-- Camera field-of-view kick (CameraShake.Punch).
export type PunchParams = {
	FovDelta: number, -- degrees added to the field of view at the peak
	InTime: number,
	OutTime: number,
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
