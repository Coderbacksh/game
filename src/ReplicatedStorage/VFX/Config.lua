--!strict
--[[
	Config
	======
	Every tunable value for the Life of Grimoire spell VFX system lives here:
	colours, sizes, durations, emit counts, cooldowns, ranges, key binds and
	texture asset IDs. Spell and utility modules read from this table and must
	not hard-code their own numbers.

	Shared by the server (cooldowns / ranges / spell list) and every client
	(visuals / key binds), so keep it free of side effects.
]]

local Types = require(script.Parent.Util.Types)

local Config = {}

-- Master debug switch. When false the VFXTestBinds script does nothing
-- (no key binds, no on-screen label). Ship with this set to false.
Config.DEBUG = true

-- Global intensity. Particles multiplies every burst count and emitter
-- Rate (2 = twice as many particles). MaxPerBurst caps any single :Emit()
-- so a world-boss cast can't freeze low-end phones. Lower Particles to
-- ~0.6 if mobile players struggle.
Config.Intensity = {
	Particles = 1.6,
	MaxPerBurst = 400,
}

---------------------------------------------------------------------------
-- Helpers used only to build the tables below (keeps the data readable).
---------------------------------------------------------------------------

-- NumberSequence from alternating time/value pairs: ns(0, 1, 0.5, 0, 1, 1)
local function ns(...: number): NumberSequence
	local args = { ... }
	local keypoints = {}
	for i = 1, #args, 2 do
		table.insert(keypoints, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(keypoints)
end

-- ColorSequence that fades between two colours (or a constant colour).
local function cs(a: Color3, b: Color3?): ColorSequence
	return ColorSequence.new(a, b or a)
end

local function nr(min: number, max: number?): NumberRange
	return NumberRange.new(min, max or min)
end

-- Typed constructors: each returns its argument unchanged, but makes the
-- type checker validate the table against the matching Types definition.
local function spec(t: Types.EmitterSpec): Types.EmitterSpec
	return t
end
local function bolt(t: Types.BoltParams): Types.BoltParams
	return t
end
local function ring(t: Types.RingParams): Types.RingParams
	return t
end
local function decal(t: Types.GroundDecalParams): Types.GroundDecalParams
	return t
end
local function shards(t: Types.ShardParams): Types.ShardParams
	return t
end
local function rune(t: Types.RuneCircleParams): Types.RuneCircleParams
	return t
end
local function orbit(t: Types.OrbitParams): Types.OrbitParams
	return t
end
local function rocks(t: Types.RockParams): Types.RockParams
	return t
end
local function sphere(t: Types.SphereParams): Types.SphereParams
	return t
end
local function focus(t: Types.FocusLineParams): Types.FocusLineParams
	return t
end
local function impact(t: Types.ImpactFrameParams): Types.ImpactFrameParams
	return t
end

---------------------------------------------------------------------------
-- TEXTURES
-- Placeholder textures. REPLACE EACH ONE with your own uploaded flipbook
-- asset ID (Studio > Asset Manager > Bulk Import, then right-click > Copy ID)
-- e.g. Smoke = "rbxassetid://1234567890".
--
-- The rbxasset:// paths below are textures that ship with every Roblox
-- client, so the effects are visible out of the box. "rbxassetid://0"
-- entries render nothing until you replace them; the effects that use them
-- also have procedural (part/beam based) fallbacks, so nothing breaks.
---------------------------------------------------------------------------
Config.Textures = {
	Smoke = "rbxasset://textures/particles/smoke_main.dds", -- REPLACE: 8x8 black ink smoke flipbook
	InkWisp = "rbxasset://textures/particles/smoke_main.dds", -- REPLACE: 4x4 ink tendril / wisp flipbook
	Spark = "rbxasset://textures/particles/sparkles_main.dds", -- REPLACE: 4x4 white spark / electric crackle flipbook
	Flare = "rbxasset://textures/particles/sparkles_main.dds", -- REPLACE: soft white glow / flare core
	Ring = "rbxassetid://0", -- REPLACE: white ring (transparent centre) for shockwave decals
	Crack = "rbxassetid://0", -- REPLACE: cracked ground decal (white cracks on transparent bg)
	Shard = "rbxasset://textures/particles/sparkles_main.dds", -- REPLACE: sharp shard / fragment sprite
	Rune = "rbxassetid://0", -- REPLACE: rune circle / seal decal
	Glyph = "rbxassetid://0", -- REPLACE: single glowing glyph sprite (used on glyph tiles)
	Crescent = "rbxassetid://0", -- REPLACE: crescent slash streak (used on the GaleReaper beams)
	Snow = "rbxasset://textures/particles/sparkles_main.dds", -- REPLACE: snow / frost speck sprite
	Ember = "rbxasset://textures/particles/fire_sparks_main.dds", -- REPLACE: 4x4 ember flipbook
	Fire = "rbxasset://textures/particles/fire_main.dds", -- REPLACE: 8x8 spiky flame flipbook
}

-- The value that means "no texture uploaded yet". Effects check against it.
Config.PlaceholderTexture = "rbxassetid://0"

-- Flipbook defaults applied to every emitter spec with Flipbook = true.
-- Grid4x4 / Grid8x8 layouts only animate once you swap in a real flipbook;
-- with the built-in placeholder textures set Layout to None if you see
-- the image split into tiles.
Config.Flipbook = {
	Layout = Enum.ParticleFlipbookLayout.Grid4x4,
	LargeLayout = Enum.ParticleFlipbookLayout.Grid8x8, -- used for Smoke / Fire
	Mode = Enum.ParticleFlipbookMode.OneShot,
	Framerate = nr(24, 30),
	StartRandom = false,
	-- While textures are still placeholders, flipbooks are disabled so the
	-- built-in images are not sliced into tiles. Set to true once replaced.
	Enabled = false,
}

---------------------------------------------------------------------------
-- PALETTE (monochrome, high contrast). Accent colours are opt-in per spell.
---------------------------------------------------------------------------
local Palette = {
	Black = Color3.fromRGB(4, 4, 6),
	Ink = Color3.fromRGB(14, 14, 18),
	Smoke = Color3.fromRGB(28, 28, 34),
	Grey = Color3.fromRGB(120, 120, 128),
	White = Color3.fromRGB(255, 255, 255),
	Glow = Color3.fromRGB(236, 242, 255),
	Crimson = Color3.fromRGB(110, 0, 14), -- InfernoSeal accent only
	CrimsonBright = Color3.fromRGB(215, 18, 36), -- InfernoSeal accent only
	PaleCyan = Color3.fromRGB(190, 238, 255), -- FrostRequiem accent only
	Ice = Color3.fromRGB(150, 215, 240), -- FrostRequiem accent only
}
Config.Palette = Palette

-- Brightness conventions for the ink-vs-light look.
local DARK_BRIGHTNESS = 0.6
local LIGHT_BRIGHTNESS = 6

---------------------------------------------------------------------------
-- GENERAL
---------------------------------------------------------------------------
Config.General = {
	FolderName = "GrimoireVFX", -- client-side Workspace folder that holds every effect instance
	AnchorSize = Vector3.new(0.2, 0.2, 0.2), -- size of invisible host parts
	CleanupPadding = 0.5, -- extra seconds before Debris removes an instance
	GroundRayHeight = 12, -- studs above a point to start the ground raycast
	GroundRayDepth = 60, -- how far down to search for ground
	GroundOffset = 0.06, -- lift decals / rings off the floor to avoid z-fighting
	CharacterWaitTimeout = 5, -- seconds a client waits for a caster's character
}

Config.Network = {
	Folder = "Remotes",
	CastRemote = "CastSpell",
	PlayRemote = "PlaySpellVFX",
	DefaultMaxRange = 200, -- studs; used when a spell has no MaxRange
	RangeTolerance = 6, -- extra studs allowed for latency / movement
	GlobalCastInterval = 0.15, -- seconds between ANY two casts per player (anti-spam)
}

-- World boss. Your boss AI casts with SpellService.CastFromModel (server).
-- The Debug* values only matter when DEBUG = true: a test boss spawns and
-- Shift + 1-8 makes it cast at you.
Config.Boss = {
	DebugName = "GrimoireTestBoss",
	DebugScale = 3, -- Model:ScaleTo factor (3 = three times player size)
	DebugPosition = Vector3.new(0, 12, -45),
	DebugColor = Color3.fromRGB(12, 12, 16),
	DebugRemote = "DebugBossCast",
	DebugCastInterval = 0.4, -- seconds between debug boss casts per player
}

-- Debug test harness (VFXTestBinds.client.lua). Only active when DEBUG = true.
Config.TestBinds = {
	GuiName = "GrimoireVFXTestBinds",
	Title = "Life of Grimoire - VFX test binds",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -12),
	Width = 260,
	LineHeight = 18,
	Padding = 8,
	TextSize = 14,
	Font = Enum.Font.Code,
	TextColor = Color3.fromRGB(235, 235, 240),
	BackgroundColor = Color3.fromRGB(8, 8, 10),
	BackgroundTransparency = 0.35,
	ActiveSuffix = "  [ON]", -- shown next to looping spells that are running
	BossHint = "[Shift+key] test boss casts at you",
}

---------------------------------------------------------------------------
-- SHARED UTILITY PRESETS
---------------------------------------------------------------------------
Config.CameraShake = {
	BindName = "GrimoireCameraShake",
	RotationScale = 0.6, -- degrees of rotation per stud of positional shake
	MinDistance = 15, -- full strength inside this distance
	MaxDistance = 220, -- no shake beyond this distance
	MinFov = 30,
	MaxFov = 110,
	-- FOV kicks (CameraShake.Punch): degrees added at the peak.
	Punches = {
		Small = { FovDelta = 4, InTime = 0.05, OutTime = 0.35 },
		Medium = { FovDelta = 8, InTime = 0.05, OutTime = 0.5 },
		Heavy = { FovDelta = 14, InTime = 0.06, OutTime = 0.7 },
		Ultimate = { FovDelta = 24, InTime = 0.08, OutTime = 1.2 },
	},
	Presets = {
		Light = { Magnitude = 0.25, Frequency = 18, Duration = 0.35 },
		Medium = { Magnitude = 0.55, Frequency = 20, Duration = 0.5 },
		Heavy = { Magnitude = 1.1, Frequency = 22, Duration = 0.9 },
		Ultimate = { Magnitude = 2.2, Frequency = 16, Duration = 1.6 },
	},
}

Config.Flash = {
	ScreenGuiName = "GrimoireScreenFlash",
	ScreenDisplayOrder = 50,
	ScreenMaxDistance = 160, -- screen flashes fade with distance and vanish beyond this
	StreakCoreHeightScale = 0.35, -- core line height relative to the streak's glow height
	StreakStartWidthScale = 0.3, -- streak starts this fraction of its width then stretches
	StreakAlwaysOnTop = true,
	StreakGradient = ns(0, 1, 0.2, 0.55, 0.5, 0, 0.8, 0.55, 1, 1),
	Presets = {
		Small = {
			Light = { Color = Palette.White, Brightness = 6, Range = 18, Duration = 0.25 },
			Streak = { Width = 14, Height = 0.8, Duration = 0.25, Color = Palette.White, Brightness = 4 },
			Screen = { Color = Palette.White, Transparency = 0.85, Duration = 0.18 },
		},
		Medium = {
			Light = { Color = Palette.White, Brightness = 10, Range = 30, Duration = 0.35 },
			Streak = { Width = 34, Height = 1.6, Duration = 0.35, Color = Palette.White, Brightness = 6 },
			Screen = { Color = Palette.White, Transparency = 0.7, Duration = 0.25 },
		},
		Large = {
			Light = { Color = Palette.White, Brightness = 16, Range = 50, Duration = 0.5 },
			Streak = { Width = 60, Height = 2.4, Duration = 0.45, Color = Palette.White, Brightness = 8 },
			Screen = { Color = Palette.White, Transparency = 0.45, Duration = 0.35 },
		},
		Ultimate = {
			Light = { Color = Palette.White, Brightness = 24, Range = 90, Duration = 0.9 },
			Streak = { Width = 140, Height = 4, Duration = 0.7, Color = Palette.White, Brightness = 10 },
			Screen = { Color = Palette.White, Transparency = 0.15, Duration = 0.6 },
		},
	},
}

-- Anime impact frames: a few frames of stark black/white (ImpactFrame.lua).
-- Set Enabled = false for players sensitive to flashing.
local WHITE_TINT = Color3.new(1, 1, 1)
Config.ImpactFrame = {
	Enabled = true,
	EffectName = "GrimoireImpactFrame",
	GuiName = "GrimoireImpactFrames",
	DisplayOrder = 60,
	Presets = {
		Medium = impact({
			MaxDistance = 140,
			Frames = {
				{ Duration = 0.045, Saturation = -1, Contrast = 1, Brightness = 0.35, TintColor = WHITE_TINT },
				{ Duration = 0.045, Saturation = -1, Contrast = 1, Brightness = -0.45, TintColor = WHITE_TINT },
			},
		}),
		Heavy = impact({
			MaxDistance = 220,
			Frames = {
				{
					Duration = 0.04,
					Saturation = -1,
					Contrast = 1,
					Brightness = 0.5,
					TintColor = WHITE_TINT,
					Overlay = Palette.White,
					OverlayTransparency = 0.3,
				},
				{ Duration = 0.05, Saturation = -1, Contrast = 1, Brightness = -0.55, TintColor = WHITE_TINT },
				{ Duration = 0.04, Saturation = -1, Contrast = 1, Brightness = 0.4, TintColor = WHITE_TINT },
				{ Duration = 0.06, Saturation = -0.6, Contrast = 0.6, Brightness = -0.2, TintColor = WHITE_TINT },
			},
		}),
		Ultimate = impact({
			MaxDistance = 400,
			Frames = {
				{
					Duration = 0.05,
					Saturation = -1,
					Contrast = 1,
					Brightness = 0.6,
					TintColor = WHITE_TINT,
					Overlay = Palette.White,
					OverlayTransparency = 0.1,
				},
				{
					Duration = 0.06,
					Saturation = -1,
					Contrast = 1,
					Brightness = -0.7,
					TintColor = WHITE_TINT,
					Overlay = Palette.Black,
					OverlayTransparency = 0.35,
				},
				{ Duration = 0.05, Saturation = -1, Contrast = 1, Brightness = 0.5, TintColor = WHITE_TINT },
				{ Duration = 0.06, Saturation = -1, Contrast = 1, Brightness = -0.5, TintColor = WHITE_TINT },
				{ Duration = 0.08, Saturation = -0.7, Contrast = 0.7, Brightness = 0.1, TintColor = WHITE_TINT },
			},
		}),
	},
}

Config.FocusLines = {
	GuiName = "GrimoireFocusLines",
	DisplayOrder = 55,
	MaxDistance = 260, -- no focus lines for impacts further away than this
	TaperPeak = 0.25, -- lines are brightest a quarter of the way out
	ThinScale = 0.35, -- thinnest line relative to Thickness
}

Config.RockRing = {
	BuryDepth = 1.1, -- rocks start this many of their own heights underground
	ExposedHeight = 0.15, -- how much of a rock's height sits above ground
	SinkTransparency = 0.4,
	AspectMin = 0.7, -- per-axis size variation so rocks aren't cubes
	AspectMax = 1.3,
	AngleJitter = 0.12, -- radians
}

Config.GroundDecal = {
	Thickness = 0.05,
	DecalTransparency = 0.1,
	SegmentHeight = 0.08,
	SegmentDelayPerStud = 0.012, -- cracks propagate outward at this speed
	SegmentFadeIn = 0.06, -- each crack segment fades in over this time
	RadialAngleJitter = 0.5, -- fraction of the even spacing a radial crack may wander
	RadialLengthMin = 0.6, -- radial cracks are 60%..100% of the radius
	StarBranchScale = 0.45, -- side spikes on star arms, relative to radius
	SlashBranchAngleMin = 0.3, -- radians off the slash line
	SlashBranchAngleMax = 1.1,
}

Config.Shockwave = {
	FlatThickness = 0.05,
}

Config.Debris = {
	SpawnHeight = 0.5, -- shards start this far above the ground
	HangSpinScale = 0.1, -- fraction of SpinMax applied while hanging
}

Config.Lightning = {
	DefaultSegments = 10,
	MinPerpendicularCheck = 0.99, -- dot threshold for choosing a perpendicular axis
	BranchDeviation = 0.8, -- how far branches veer from the main bolt direction
	CrackleInnerScale = 0.3, -- crackle arc endpoints sit between 30% and 100% of the radius
	ArcAngleJitter = 0.35, -- radians of randomness between evenly spaced ground arcs
	ArcLengthMin = 0.6, -- ground arcs reach 60%..100% of their Length
}

Config.OrbitTrail = {
	PartName = "OrbitTrail",
}

Config.RuneCircle = {
	ArcSegments = 40, -- beams used to approximate each circle
	LineDrawFraction = 0.25, -- each line takes this fraction of DrawTime to grow
	-- When each group of lines draws, as {start, end} fractions of DrawTime.
	DrawOrder = {
		Outer = { 0, 0.45 },
		Inner = { 0.15, 0.6 },
		Star = { 0.45, 0.85 },
		Ticks = { 0.6, 1 },
	},
}

-- Reusable emitter specs ----------------------------------------------------
local Emitters = {
	InkSmoke = spec({
		Texture = Config.Textures.Smoke,
		Color = cs(Palette.Black, Palette.Ink),
		Size = ns(0, 1.5, 0.4, 3.5, 1, 5),
		Transparency = ns(0, 1, 0.15, 0.1, 0.7, 0.4, 1, 1),
		Lifetime = nr(0.6, 1.1),
		Speed = nr(4, 10),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0,
		Brightness = DARK_BRIGHTNESS,
		LightInfluence = 0,
		Rotation = nr(0, 360),
		RotSpeed = nr(-90, 90),
		Drag = 3,
		Flipbook = true,
		LargeFlipbook = true,
	}),
	WhiteSparks = spec({
		Texture = Config.Textures.Spark,
		Color = cs(Palette.White),
		Size = ns(0, 0.6, 1, 0),
		Transparency = ns(0, 0, 0.7, 0.2, 1, 1),
		Lifetime = nr(0.25, 0.6),
		Speed = nr(30, 70),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Brightness = LIGHT_BRIGHTNESS,
		LightInfluence = 0,
		Drag = 6,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = ns(0, 2.5, 1, 1),
		Flipbook = true,
	}),
	CoreFlare = spec({
		Texture = Config.Textures.Flare,
		Color = cs(Palette.White),
		Size = ns(0, 2, 0.15, 14, 1, 18),
		Transparency = ns(0, 0, 0.4, 0.3, 1, 1),
		Lifetime = nr(0.35, 0.45),
		Speed = nr(0),
		LightEmission = 1,
		Brightness = LIGHT_BRIGHTNESS * 2,
		LightInfluence = 0,
		ZOffset = 2,
	}),
}
Config.Emitters = Emitters

---------------------------------------------------------------------------
-- SPELLS
-- Key        : test-bind key (VFXTestBinds)
-- Cooldown   : seconds, enforced on the server per player per spell
-- MaxRange   : studs from the caster the target may be
-- Looping    : true = toggle spell with Play/Stop
-- VFX        : everything the spell module needs to render
---------------------------------------------------------------------------
Config.SpellOrder = {
	"GrimoireAwakening",
	"VoidBurst",
	"AbyssalAura",
	"ThunderJudgment",
	"InfernoSeal",
	"FrostRequiem",
	"GaleReaper",
	"CelestialVerdict",
}

Config.Spells = {
	---------------------------------------------------------------------
	GrimoireAwakening = {
		DisplayName = "Grimoire Awakening",
		Key = Enum.KeyCode.One,
		Cooldown = 6,
		MaxRange = 300,
		Looping = false,
		VFX = {
			HandNames = { "RightHand", "Right Arm" },
			BookOffset = Vector3.new(0, 1.6, -0.6), -- above the open hand (character space)
			FallbackOffset = Vector3.new(1.2, 1.2, -1.8), -- used when no hand is found
			PageCount = 16,
			PageSize = Vector3.new(1.3, 0.04, 1.7),
			PageColor = Palette.Ink,
			PageMaterial = Enum.Material.SmoothPlastic,
			PageStartRadius = 5,
			PageStartHeight = 2.5, -- pages start spread vertically around the book
			PageSpinTurns = 2.5, -- spiral turns while gathering
			PageTumble = 3, -- radians of extra tumble while pages fly in
			PageFadeIn = 0.35, -- seconds for pages to materialise from nothing
			PageStackGap = 0.03,
			GatherTime = 0.9,
			InkGather = {
				Spec = spec({
					Texture = Config.Textures.InkWisp,
					Color = cs(Palette.Black),
					Size = ns(0, 0.4, 0.5, 1.2, 1, 0),
					Transparency = ns(0, 1, 0.2, 0.05, 1, 1),
					Lifetime = nr(0.8, 0.9),
					Speed = nr(5, 6),
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					LightInfluence = 0,
					Rotation = nr(0, 360),
					RotSpeed = nr(-200, 200),
					Shape = Enum.ParticleEmitterShape.Sphere,
					ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
					Flipbook = true,
				}),
				Count = 45,
				Radius = 4.5,
			},
			BookSize = Vector3.new(1.4, 0.35, 1.8),
			CoverThickness = 0.08,
			CoverColor = Palette.Black,
			CoverMaterial = Enum.Material.SmoothPlastic,
			SnapScale = 1.15, -- the book pops to this scale when it forms
			SnapTime = 0.12,
			-- Rune lines etched on the cover, in cover-space (-1..1 on X/Z).
			RuneLines = {
				{ Vector2.new(-0.85, -0.85), Vector2.new(0.85, -0.85) },
				{ Vector2.new(0.85, -0.85), Vector2.new(0.85, 0.85) },
				{ Vector2.new(0.85, 0.85), Vector2.new(-0.85, 0.85) },
				{ Vector2.new(-0.85, 0.85), Vector2.new(-0.85, -0.85) },
				{ Vector2.new(0, -0.6), Vector2.new(0.5, 0.35) },
				{ Vector2.new(0.5, 0.35), Vector2.new(-0.5, 0.35) },
				{ Vector2.new(-0.5, 0.35), Vector2.new(0, -0.6) },
				{ Vector2.new(0, 0.6), Vector2.new(0, -0.2) },
			},
			RuneEtchInterval = 0.07,
			RuneBolt = bolt({
				Segments = 4,
				Amplitude = 0.05,
				Width = 0.07,
				EndWidthScale = 0.6,
				Color = Palette.White,
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS,
				FlickerInterval = 0.05,
				Duration = 0.9,
				FadeTime = 0.2,
			}),
			RuneHeight = 0.02, -- runes float just above the cover
			RuneHoldTime = 0.6,
			OpenTime = 0.3,
			OpenFlash = "Small", -- Config.Flash.Presets key
			OpenSparks = 30,
			GlyphCount = 12,
			GlyphRadius = 4,
			GlyphHeight = -0.2, -- relative to HumanoidRootPart (≈ waist)
			GlyphSize = Vector3.new(0.9, 0.9, 0.05),
			GlyphColor = Palette.White,
			GlyphSpinSpeed = 0.6, -- rad/s
			GlyphBobAmplitude = 0.15,
			GlyphBobSpeed = 2,
			GlyphFadeIn = 0.35,
			GlyphTransparency = 0.15,
			Orbit = {
				Duration = 2,
				Trails = {
					orbit({ Radius = 3, Height = 0, Speed = 7, Tilt = Vector3.new(18, 0, 0), Phase = 0 }),
					orbit({ Radius = 3.4, Height = 0.4, Speed = -6, Tilt = Vector3.new(-22, 0, 12), Phase = math.pi }),
				},
				Width = 0.35,
				Lifetime = 0.35,
				Color = Palette.White,
				Transparency = ns(0, 0, 1, 1),
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS,
			},
			IdleTime = 3, -- faint idle glow duration after the orbit ends
			IdleLight = { Color = Palette.Glow, Brightness = 1.2, Range = 8 },
			IdleBobAmplitude = 0.12,
			IdleBobSpeed = 2.4,
			FadeTime = 0.6,
			-- Boss-tier layers --------------------------------------------
			GlyphWeb = { -- white arcs jumping between neighbouring glyphs
				Interval = 0.1,
				Bolt = bolt({
					Segments = 5,
					Amplitude = 0.35,
					Width = 0.09,
					EndWidthScale = 0.5,
					Color = Palette.White,
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					FlickerInterval = 0.04,
					Duration = 0.14,
					FadeTime = 0.06,
				}),
			},
			InkStorm = { -- ink wisps swirling up around the caster during the glyph phase
				Spec = spec({
					Texture = Config.Textures.InkWisp,
					Color = cs(Palette.Black, Palette.Ink),
					Size = ns(0, 0.6, 0.4, 2.2, 1, 0),
					Transparency = ns(0, 1, 0.2, 0.15, 1, 1),
					Lifetime = nr(0.8, 1.3),
					Speed = nr(3, 6),
					SpreadAngle = Vector2.new(20, 20),
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					LightInfluence = 0,
					Rotation = nr(0, 360),
					RotSpeed = nr(-220, 220),
					Acceleration = Vector3.new(0, 5, 0),
					Shape = Enum.ParticleEmitterShape.Cylinder,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
					EmissionDirection = Enum.NormalId.Top,
					Flipbook = true,
				}),
				Count = 5,
				Interval = 0.05,
				Radius = 4.5,
				Height = 1,
			},
			RisingRunes = { -- white motes drifting up out of the glyph ring
				Spec = spec({
					Texture = Config.Textures.Spark,
					Color = cs(Palette.White),
					Size = ns(0, 0.35, 1, 0),
					Transparency = ns(0, 0, 0.8, 0.2, 1, 1),
					Lifetime = nr(0.8, 1.4),
					Speed = nr(4, 9),
					SpreadAngle = Vector2.new(10, 10),
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					LightInfluence = 0,
					Drag = 1,
					Shape = Enum.ParticleEmitterShape.Cylinder,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
					EmissionDirection = Enum.NormalId.Top,
				}),
				Count = 4,
				Interval = 0.05,
			},
			OpenSpheres = {
				sphere({
					StartSize = 1,
					EndSize = 9,
					Duration = 0.4,
					Color = Palette.White,
					Material = Enum.Material.Neon,
					StartTransparency = 0.15,
				}),
				sphere({
					StartSize = 2,
					EndSize = 16,
					Duration = 0.6,
					Color = Palette.Black,
					Material = Enum.Material.ForceField,
					StartTransparency = 0,
					Delay = 0.04,
				}),
			},
			OpenRing = ring({
				StartRadius = 1,
				EndRadius = 12,
				Duration = 0.4,
				Segments = 28,
				Width = 0.6,
				Color = Palette.White,
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS,
			}),
			OpenFocus = focus({
				Count = 26,
				InnerRadius = 0.1,
				LengthMin = 0.2,
				LengthMax = 0.5,
				Thickness = 3,
				Color = Palette.White,
				Transparency = 0.2,
				Duration = 0.3,
				RerollInterval = 0.05,
			}),
			OpenImpact = "Medium", -- Config.ImpactFrame.Presets
			OpenPunch = "Small", -- Config.CameraShake.Punches
			OpenShake = "Light",
		},
	},

	---------------------------------------------------------------------
	VoidBurst = {
		DisplayName = "Void Burst",
		Key = Enum.KeyCode.Two,
		Cooldown = 4,
		MaxRange = 140,
		Looping = false,
		VFX = {
			CoreHeight = 3,
			ImplodeTime = 0.4,
			ImplodeRadius = 9,
			ImplodeSmoke = {
				Spec = spec({
					Texture = Config.Textures.Smoke,
					Color = cs(Palette.Black),
					Size = ns(0, 4, 1, 0.5),
					Transparency = ns(0, 1, 0.25, 0.05, 1, 0.6),
					Lifetime = nr(0.4),
					Speed = nr(22), -- ≈ ImplodeRadius / ImplodeTime
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					LightInfluence = 0,
					Rotation = nr(0, 360),
					RotSpeed = nr(-180, 180),
					Shape = Enum.ParticleEmitterShape.Sphere,
					ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
					Flipbook = true,
					LargeFlipbook = true,
				}),
				Count = 60,
			},
			Tendrils = {
				Count = 12,
				Bolt = bolt({
					Segments = 8,
					Amplitude = 1.4,
					Width = 0.9,
					EndWidthScale = 0.15,
					Color = Palette.Black,
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					FlickerInterval = 0.06,
					Duration = 0.4,
					FadeTime = 0.05,
				}),
			},
			Flash = "Large",
			Starburst = {
				Spec = spec({
					Texture = Config.Textures.Spark,
					Color = cs(Palette.White),
					Size = ns(0, 1.2, 1, 0),
					Transparency = ns(0, 0, 0.6, 0.1, 1, 1),
					Lifetime = nr(0.3, 0.55),
					Speed = nr(60, 110),
					SpreadAngle = Vector2.new(180, 180),
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS * 1.5,
					LightInfluence = 0,
					Drag = 5,
					Orientation = Enum.ParticleOrientation.VelocityParallel,
					Squash = ns(0, 3, 1, 1), -- Squash is clamped to -3..3 by the engine
					Flipbook = true,
				}),
				Count = 80,
			},
			CoreCount = 2,
			Crackle = {
				Count = 10,
				Radius = 3.5,
				Duration = 0.55,
				Bolt = bolt({
					Segments = 6,
					Amplitude = 0.7,
					Width = 0.18,
					EndWidthScale = 0.3,
					Color = Palette.White,
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					FlickerInterval = 0.04,
					Duration = 0.55,
					FadeTime = 0.15,
				}),
			},
			Arcs = {
				Count = 10,
				Ring = ring({
					StartRadius = 2,
					EndRadius = 18,
					Duration = 0.45,
					Segments = 10,
					Width = 1.6,
					Color = Palette.Black,
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					ArcSpan = math.rad(110),
				}),
				MaxTilt = 55, -- degrees
			},
			GroundRing = ring({
				StartRadius = 1,
				EndRadius = 22,
				Duration = 0.5,
				Segments = 32,
				Width = 1.2,
				Color = Palette.White,
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS,
			}),
			Smoke = { Spec = Emitters.InkSmoke, Count = 30 },
			Decal = decal({
				Radius = 9,
				StartScale = 0.3,
				SpreadTime = 0.25,
				Hold = 1.2,
				FadeTime = 2,
				Color = Palette.Black,
				Texture = Config.Textures.Crack,
				Cracks = {
					Pattern = "Radial",
					Count = 9,
					Segments = 5,
					Jitter = 0.45,
					Thickness = 0.22,
					Color = Palette.Black,
					Material = Enum.Material.SmoothPlastic,
				},
			}),
			Shards = shards({
				Count = 30,
				SizeMin = 0.25,
				SizeMax = 0.7,
				StartRadius = 8,
				RiseMin = 2,
				RiseMax = 6,
				Spread = 1.5,
				RiseTime = 0.45,
				HangTime = 0.4,
				FallTime = 0.55,
				FallDistance = 6,
				FallSpread = 1,
				SpinMax = 360,
				HangDrift = 0.3,
				Color = Palette.Ink,
				Material = Enum.Material.SmoothPlastic,
			}),
			Shake = "Medium",
			-- Boss-tier layers --------------------------------------------
			Spheres = {
				sphere({
					StartSize = 2,
					EndSize = 18,
					Duration = 0.4,
					Color = Palette.White,
					Material = Enum.Material.Neon,
					StartTransparency = 0.05,
				}),
				sphere({
					StartSize = 4,
					EndSize = 32,
					Duration = 0.7,
					Color = Palette.Black,
					Material = Enum.Material.ForceField,
					StartTransparency = 0,
					Delay = 0.05,
				}),
				sphere({
					StartSize = 6,
					EndSize = 44,
					Duration = 0.9,
					Color = Palette.White,
					Material = Enum.Material.ForceField,
					StartTransparency = 0.2,
					Delay = 0.14,
				}),
			},
			Rocks = rocks({
				Count = 18,
				Radius = 10,
				SizeMin = 1.6,
				SizeMax = 3.6,
				TiltMin = 20,
				TiltMax = 45,
				RadiusJitter = 1.5,
				Stagger = 0.008,
				RiseTime = 0.25,
				Hold = 1.6,
				SinkTime = 0.6,
				UseGroundMaterial = true,
				Color = Palette.Smoke,
				Material = Enum.Material.Slate,
			}),
			Focus = focus({
				Count = 42,
				InnerRadius = 0.08,
				LengthMin = 0.25,
				LengthMax = 0.7,
				Thickness = 4,
				Color = Palette.White,
				Transparency = 0.1,
				Duration = 0.4,
				RerollInterval = 0.04,
			}),
			Impact = "Heavy",
			Punch = "Heavy",
			Aftershock = {
				Delay = 0.35,
				Ring = ring({
					StartRadius = 3,
					EndRadius = 34,
					Duration = 0.6,
					Segments = 40,
					Width = 2.6,
					Color = Palette.Black,
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
				}),
				Smoke = { Spec = Emitters.InkSmoke, Count = 40 },
				Shake = "Light",
			},
			LingerSmoke = {
				Spec = spec({
					Texture = Config.Textures.Smoke,
					Color = cs(Palette.Black, Palette.Smoke),
					Size = ns(0, 4, 1, 10),
					Transparency = ns(0, 1, 0.2, 0.35, 1, 1),
					Lifetime = nr(1.6, 2.4),
					Speed = nr(1, 3),
					SpreadAngle = Vector2.new(180, 30),
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					LightInfluence = 0,
					Rotation = nr(0, 360),
					RotSpeed = nr(-20, 20),
					Acceleration = Vector3.new(0, 1.5, 0),
					Shape = Enum.ParticleEmitterShape.Disc,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					Flipbook = true,
					LargeFlipbook = true,
				}),
				Count = 3,
				Interval = 0.1,
				Duration = 2,
				Radius = 9,
			},
		},
	},

	---------------------------------------------------------------------
	AbyssalAura = {
		DisplayName = "Abyssal Aura",
		Key = Enum.KeyCode.Three,
		Cooldown = 1,
		MaxRange = 300,
		Looping = true,
		MaxDuration = 30, -- auto-stops after this many seconds (server + client)
		VFX = {
			FootOffset = Vector3.new(0, -2.8, 0), -- from HumanoidRootPart to the feet
			BaseSize = Vector3.new(4, 0.2, 4), -- emitter disc under the feet
			Flames = {
				Spec = spec({
					Texture = Config.Textures.Fire,
					Color = cs(Palette.Black),
					Size = ns(0, 1.6, 0.5, 1.1, 1, 0),
					Transparency = ns(0, 0.2, 0.7, 0.3, 1, 1),
					Lifetime = nr(0.5, 0.9),
					Speed = nr(5, 9),
					SpreadAngle = Vector2.new(8, 8),
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					LightInfluence = 0,
					Acceleration = Vector3.new(0, 6, 0),
					Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
					Squash = ns(0, 0.6, 1, 1.2), -- positive squash = tall, thin spiky flames
					Shape = Enum.ParticleEmitterShape.Disc,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					EmissionDirection = Enum.NormalId.Top,
					Rate = 55,
					Flipbook = true,
					LargeFlipbook = true,
				}),
			},
			BaseGlow = {
				Spec = spec({
					Texture = Config.Textures.Flare,
					Color = cs(Palette.White),
					Size = ns(0, 4, 1, 6),
					Transparency = ns(0, 1, 0.3, 0.6, 1, 1),
					Lifetime = nr(0.8, 1),
					Speed = nr(0),
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS * 0.5,
					LightInfluence = 0,
					Rate = 6,
				}),
			},
			Light = { Color = Palette.Glow, Brightness = 2, Range = 12 },
			PulseAmplitude = 1.5, -- light brightness wobble
			PulseSpeed = 4, -- rad/s
			Orbit = {
				Trails = {
					orbit({ Radius = 2.6, Height = 0, Speed = 6, Tilt = Vector3.new(25, 0, 0), Phase = 0 }),
					orbit({
						Radius = 3,
						Height = 0.8,
						Speed = -5,
						Tilt = Vector3.new(-15, 0, 30),
						Phase = math.pi * 0.5,
					}),
				},
				Width = 0.3,
				Lifetime = 0.4,
				Color = Palette.White,
				Transparency = ns(0, 0, 1, 1),
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS,
			},
			Shards = {
				Count = 14,
				Size = Vector3.new(0.25, 0.5, 0.25),
				Color = Palette.Ink,
				Material = Enum.Material.SmoothPlastic,
				MinRadius = 1.5,
				MaxRadius = 3.2,
				LoopHeight = 6, -- shards rise from the feet to this height, then loop
				RiseSpeed = 1.6, -- studs/s
				SpinSpeed = 1.2, -- rad/s around the player
				TumbleSpeed = 3, -- rad/s self-rotation
			},
			Decal = decal({
				Radius = 6,
				StartScale = 0.2,
				SpreadTime = 0.8,
				Hold = 0, -- 0 = persistent until the aura moves / stops
				FadeTime = 1.2,
				Color = Palette.Black,
				Texture = Config.Textures.Crack,
				Cracks = {
					Pattern = "Radial",
					Count = 7,
					Segments = 4,
					Jitter = 0.5,
					Thickness = 0.16,
					Color = Palette.Black,
					Material = Enum.Material.SmoothPlastic,
				},
			}),
			DecalRespawnDistance = 4, -- re-spawn the decal under the player after moving this far
			StopFlash = "Large",
			StopSparks = { Spec = Emitters.WhiteSparks, Count = 70 },
			StopCoreCount = 2,
			StopRing = ring({
				StartRadius = 1,
				EndRadius = 16,
				Duration = 0.45,
				Segments = 28,
				Width = 1,
				Color = Palette.White,
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS,
			}),
			StopShake = "Medium",
			-- Boss-tier layers --------------------------------------------
			ChargeRocks = rocks({
				Count = 12,
				Radius = 5,
				SizeMin = 0.9,
				SizeMax = 2,
				TiltMin = 10,
				TiltMax = 30,
				RadiusJitter = 0.8,
				Stagger = 0.02,
				RiseTime = 0.3,
				Hold = 1.4,
				SinkTime = 0.5,
				UseGroundMaterial = true,
				Color = Palette.Smoke,
				Material = Enum.Material.Slate,
			}),
			ChargeSphere = sphere({
				StartSize = 2,
				EndSize = 16,
				Duration = 0.6,
				Color = Palette.Black,
				Material = Enum.Material.ForceField,
				StartTransparency = 0,
			}),
			ChargeShake = "Light",
			InkPillar = { -- looping column of ink wisps shooting up from the feet
				Spec = spec({
					Texture = Config.Textures.InkWisp,
					Color = cs(Palette.Black),
					Size = ns(0, 1.2, 0.5, 2, 1, 0),
					Transparency = ns(0, 0.6, 0.3, 0.2, 1, 1),
					Lifetime = nr(0.6, 1),
					Speed = nr(10, 16),
					SpreadAngle = Vector2.new(6, 6),
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					LightInfluence = 0,
					Rotation = nr(0, 360),
					RotSpeed = nr(-120, 120),
					Shape = Enum.ParticleEmitterShape.Disc,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
					EmissionDirection = Enum.NormalId.Top,
					Rate = 30,
					Flipbook = true,
				}),
			},
			RisingSparks = {
				Spec = spec({
					Texture = Config.Textures.Spark,
					Color = cs(Palette.White),
					Size = ns(0, 0.3, 1, 0),
					Transparency = ns(0, 0, 1, 1),
					Lifetime = nr(0.5, 0.9),
					Speed = nr(6, 12),
					SpreadAngle = Vector2.new(15, 15),
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					LightInfluence = 0,
					Orientation = Enum.ParticleOrientation.VelocityParallel,
					Squash = ns(0, 2, 1, 1),
					Shape = Enum.ParticleEmitterShape.Disc,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					EmissionDirection = Enum.NormalId.Top,
					Rate = 18,
				}),
			},
			ArcPulse = { -- electricity crackling over the body
				Interval = 0.3,
				Count = 2,
				Radius = 3.2,
				Bolt = bolt({
					Segments = 6,
					Amplitude = 0.6,
					Width = 0.12,
					EndWidthScale = 0.3,
					Color = Palette.White,
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					FlickerInterval = 0.04,
					Duration = 0.16,
					FadeTime = 0.06,
				}),
			},
			GroundPulse = { -- a thin white ring every Interval seconds
				Interval = 1.1,
				Ring = ring({
					StartRadius = 2,
					EndRadius = 12,
					Duration = 0.7,
					Segments = 28,
					Width = 0.4,
					Color = Palette.White,
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS * 0.6,
				}),
			},
			StopSpheres = {
				sphere({
					StartSize = 2,
					EndSize = 22,
					Duration = 0.45,
					Color = Palette.White,
					Material = Enum.Material.Neon,
					StartTransparency = 0.05,
				}),
				sphere({
					StartSize = 4,
					EndSize = 34,
					Duration = 0.75,
					Color = Palette.Black,
					Material = Enum.Material.ForceField,
					StartTransparency = 0,
					Delay = 0.05,
				}),
			},
			StopRocks = rocks({
				Count = 16,
				Radius = 8,
				SizeMin = 1.4,
				SizeMax = 3,
				TiltMin = 20,
				TiltMax = 45,
				RadiusJitter = 1.2,
				Stagger = 0.008,
				RiseTime = 0.25,
				Hold = 1.4,
				SinkTime = 0.6,
				UseGroundMaterial = true,
				Color = Palette.Smoke,
				Material = Enum.Material.Slate,
			}),
			StopFocus = focus({
				Count = 40,
				InnerRadius = 0.08,
				LengthMin = 0.25,
				LengthMax = 0.7,
				Thickness = 4,
				Color = Palette.White,
				Transparency = 0.1,
				Duration = 0.4,
				RerollInterval = 0.04,
			}),
			StopImpact = "Heavy",
			StopPunch = "Heavy",
		},
	},

	---------------------------------------------------------------------
	ThunderJudgment = {
		DisplayName = "Thunder Judgment",
		Key = Enum.KeyCode.Four,
		Cooldown = 5,
		MaxRange = 160,
		Looping = false,
		VFX = {
			CloudHeight = 45,
			GatherTime = 0.9,
			CloudSize = Vector3.new(26, 4, 26),
			Clouds = {
				Spec = spec({
					Texture = Config.Textures.Smoke,
					Color = cs(Palette.Black, Palette.Smoke),
					Size = ns(0, 4, 0.5, 9, 1, 11),
					Transparency = ns(0, 1, 0.25, 0.1, 0.8, 0.3, 1, 1),
					Lifetime = nr(1.8, 2.4),
					Speed = nr(3, 6),
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					LightInfluence = 0,
					Rotation = nr(0, 360),
					RotSpeed = nr(-30, 30),
					Shape = Enum.ParticleEmitterShape.Cylinder,
					ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					Drag = 1,
					Flipbook = true,
					LargeFlipbook = true,
				}),
				Count = 18, -- per pulse
				Interval = 0.15,
			},
			CloudCrackle = {
				Count = 3,
				Radius = 7,
				Duration = 0.9,
				Bolt = bolt({
					Segments = 6,
					Amplitude = 1.2,
					Width = 0.2,
					EndWidthScale = 0.3,
					Color = Palette.White,
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					FlickerInterval = 0.08,
					Duration = 0.9,
					FadeTime = 0.1,
				}),
			},
			MainBolt = bolt({
				Segments = 14,
				Amplitude = 3,
				Width = 2.2,
				EndWidthScale = 0.7,
				Color = Palette.White,
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS * 2,
				FlickerInterval = 0.05, -- rebuilt every few frames
				Duration = 0.45,
				FadeTime = 0.2,
				Branches = {
					Count = 7,
					LengthScale = 0.3,
					Segments = 5,
					Amplitude = 1.5,
					WidthScale = 0.35,
				},
			}),
			GlowBolt = bolt({ -- wide soft glow behind the main bolt
				Segments = 14,
				Amplitude = 3,
				Width = 6,
				EndWidthScale = 0.8,
				Color = Palette.Glow,
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS * 0.4,
				FlickerInterval = 0.05,
				Duration = 0.45,
				FadeTime = 0.2,
				Transparency = 0.6,
			}),
			Flash = "Large",
			GroundArcs = {
				Count = 11,
				Length = 14,
				CrawlTime = 0.6, -- arcs crawl for this long; Bolt.Duration controls lifetime
				Bolt = bolt({
					Segments = 8,
					Amplitude = 1,
					Width = 0.25,
					EndWidthScale = 0.1,
					Color = Palette.White,
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					FlickerInterval = 0.05,
					Duration = 1,
					FadeTime = 0.3,
				}),
				Lift = 0.25,
			},
			Decal = decal({
				Radius = 8,
				StartScale = 0.4,
				SpreadTime = 0.15,
				Hold = 1.2,
				FadeTime = 2,
				Color = Palette.Black,
				Texture = Config.Textures.Crack,
				Cracks = {
					Pattern = "Radial",
					Count = 8,
					Segments = 5,
					Jitter = 0.6,
					Thickness = 0.2,
					Color = Palette.Black,
					Material = Enum.Material.SmoothPlastic,
				},
			}),
			BounceSparks = {
				Count = 24,
				Size = Vector3.new(0.15, 0.15, 0.15),
				Color = Palette.White,
				Material = Enum.Material.Neon,
				SpeedMin = 25,
				SpeedMax = 45,
				UpMin = 15,
				UpMax = 30,
				Density = 0.1,
				Friction = 0.2,
				Elasticity = 0.8, -- high = bouncy
				FrictionWeight = 1,
				ElasticityWeight = 1,
				Lifetime = 1.4,
				FadeTime = 0.4,
			},
			Sparks = { Spec = Emitters.WhiteSparks, Count = 50 },
			Smoke = { Spec = Emitters.InkSmoke, Count = 20 },
			Shake = "Heavy",
			-- Boss-tier layers --------------------------------------------
			PreStrikes = { -- smaller bolts that hit around the target before the big one
				Count = 2,
				Interval = 0.2,
				Scatter = 10,
				WidthScale = 0.5,
				Flash = "Small",
				Sparks = { Spec = Emitters.WhiteSparks, Count = 20 },
			},
			Spheres = {
				sphere({
					StartSize = 2,
					EndSize = 16,
					Duration = 0.35,
					Color = Palette.White,
					Material = Enum.Material.Neon,
					StartTransparency = 0,
				}),
				sphere({
					StartSize = 4,
					EndSize = 28,
					Duration = 0.65,
					Color = Palette.Glow,
					Material = Enum.Material.ForceField,
					StartTransparency = 0.1,
					Delay = 0.04,
				}),
			},
			Rocks = rocks({
				Count = 16,
				Radius = 7,
				SizeMin = 1.4,
				SizeMax = 3.2,
				TiltMin = 25,
				TiltMax = 50,
				RadiusJitter = 1.2,
				Stagger = 0.006,
				RiseTime = 0.22,
				Hold = 1.5,
				SinkTime = 0.6,
				UseGroundMaterial = true,
				Color = Palette.Smoke,
				Material = Enum.Material.Slate,
			}),
			Focus = focus({
				Count = 44,
				InnerRadius = 0.06,
				LengthMin = 0.3,
				LengthMax = 0.75,
				Thickness = 4,
				Color = Palette.White,
				Transparency = 0.05,
				Duration = 0.4,
				RerollInterval = 0.04,
			}),
			Impact = "Heavy",
			Punch = "Heavy",
			Residual = { -- static electricity lingering on the scorched ground
				Duration = 2.4,
				Interval = 0.22,
				Count = 2,
				Radius = 7,
				ArcLengthMin = 1, -- studs
				ArcLengthMax = 3.5,
				AngleWander = 1, -- radians each arc may turn from the radial direction
				Bolt = bolt({
					Segments = 5,
					Amplitude = 0.5,
					Width = 0.12,
					EndWidthScale = 0.2,
					Color = Palette.White,
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					FlickerInterval = 0.04,
					Duration = 0.12,
					FadeTime = 0.06,
				}),
			},
		},
	},

	---------------------------------------------------------------------
	InfernoSeal = {
		DisplayName = "Inferno Seal",
		Key = Enum.KeyCode.Five,
		Cooldown = 6,
		MaxRange = 140,
		Looping = false,
		VFX = {
			Seal = rune({
				Radius = 9,
				InnerRadiusScale = 0.78,
				StarPoints = 5,
				StarStep = 2,
				Ticks = 24,
				TickLength = 0.8,
				Width = 0.22,
				Color = Palette.White,
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS,
				DrawTime = 0.8,
				Hold = 1.6,
				FadeTime = 0.6,
				RotationSpeed = 0.4,
				Lift = 0.12,
			}),
			PillarRadius = 4,
			PillarHeight = 2, -- emitter part height (flames travel far higher)
			PillarDuration = 1.4,
			PulseInterval = 0.05,
			BlackFlames = {
				Spec = spec({
					Texture = Config.Textures.Fire,
					Color = cs(Palette.Black),
					Size = ns(0, 3, 0.6, 2.4, 1, 0),
					Transparency = ns(0, 0.1, 0.8, 0.3, 1, 1),
					Lifetime = nr(0.6, 0.9),
					Speed = nr(30, 45),
					SpreadAngle = Vector2.new(6, 6),
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					LightInfluence = 0,
					Rotation = nr(-15, 15),
					Squash = ns(0, 0.5, 1, 1),
					Shape = Enum.ParticleEmitterShape.Cylinder,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					EmissionDirection = Enum.NormalId.Top,
					Flipbook = true,
					LargeFlipbook = true,
				}),
				Count = 7, -- per pulse
			},
			CrimsonFlames = {
				Spec = spec({
					Texture = Config.Textures.Fire,
					Color = cs(Palette.CrimsonBright, Palette.Crimson),
					Size = ns(0, 2.4, 0.6, 1.8, 1, 0),
					Transparency = ns(0, 0.2, 0.7, 0.4, 1, 1),
					Lifetime = nr(0.5, 0.8),
					Speed = nr(28, 40),
					SpreadAngle = Vector2.new(5, 5),
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS * 0.6,
					LightInfluence = 0,
					Rotation = nr(-15, 15),
					Squash = ns(0, 0.5, 1, 1),
					Shape = Enum.ParticleEmitterShape.Cylinder,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					EmissionDirection = Enum.NormalId.Top,
					ZOffset = 0.5,
					Flipbook = true,
					LargeFlipbook = true,
				}),
				Count = 5,
			},
			Embers = {
				Spec = spec({
					Texture = Config.Textures.Ember,
					Color = cs(Palette.CrimsonBright, Palette.Crimson),
					Size = ns(0, 0.35, 1, 0),
					Transparency = ns(0, 0, 0.8, 0.2, 1, 1),
					Lifetime = nr(0.9, 1.6),
					Speed = nr(18, 34),
					SpreadAngle = Vector2.new(25, 25),
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					LightInfluence = 0,
					Drag = 1.5,
					Acceleration = Vector3.new(0, 4, 0),
					Shape = Enum.ParticleEmitterShape.Cylinder,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					EmissionDirection = Enum.NormalId.Top,
					Flipbook = true,
				}),
				Count = 3,
			},
			FlickerSmoke = {
				Spec = spec({
					Texture = Config.Textures.Smoke,
					Color = cs(Palette.Black, Palette.Smoke),
					Size = ns(0, 3, 1, 8),
					Transparency = ns(0, 0.4, 0.5, 0.6, 1, 1),
					Lifetime = nr(1, 1.5),
					Speed = nr(14, 22),
					SpreadAngle = Vector2.new(15, 15),
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					LightInfluence = 0,
					Rotation = nr(0, 360),
					RotSpeed = nr(-60, 60),
					Shape = Enum.ParticleEmitterShape.Cylinder,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					EmissionDirection = Enum.NormalId.Top,
					Flipbook = true,
					LargeFlipbook = true,
				}),
				Count = 2,
			},
			PillarLight = { Color = Palette.CrimsonBright, Brightness = 8, Range = 26 },
			LightFlickerMin = 0.6, -- multiplier range for the crimson light flicker
			LightFlickerMax = 1.2,
			EndFlash = "Medium",
			EndCoreCount = 2,
			EndRing = ring({
				StartRadius = 2,
				EndRadius = 20,
				Duration = 0.5,
				Segments = 32,
				Width = 1.2,
				Color = Palette.White,
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS,
			}),
			GroundEmbers = {
				Spec = spec({
					Texture = Config.Textures.Ember,
					Color = cs(Palette.CrimsonBright, Palette.Crimson),
					Size = ns(0, 0.25, 1, 0),
					Transparency = ns(0, 0, 0.8, 0.3, 1, 1),
					Lifetime = nr(1.5, 2.5),
					Speed = nr(0.5, 2),
					SpreadAngle = Vector2.new(60, 60),
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					LightInfluence = 0,
					Acceleration = Vector3.new(0, 1, 0),
					Shape = Enum.ParticleEmitterShape.Box,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					EmissionDirection = Enum.NormalId.Top,
					Flipbook = true,
				}),
				Count = 4,
				Interval = 0.1,
				Duration = 2.5,
			},
			Decal = decal({
				Radius = 9,
				StartScale = 0.5,
				SpreadTime = 0.3,
				Hold = 1.5,
				FadeTime = 2,
				Color = Palette.Black,
				Texture = Config.Textures.Crack,
				Cracks = {
					Pattern = "Radial",
					Count = 10,
					Segments = 5,
					Jitter = 0.5,
					Thickness = 0.2,
					Color = Palette.CrimsonBright, -- glowing ember cracks
					Material = Enum.Material.Neon,
				},
			}),
			Shake = "Medium",
			-- Boss-tier layers --------------------------------------------
			FireRing = { -- crimson flames licking up along the seal's edge
				Spec = spec({
					Texture = Config.Textures.Fire,
					Color = cs(Palette.CrimsonBright, Palette.Crimson),
					Size = ns(0, 1.6, 0.6, 1.2, 1, 0),
					Transparency = ns(0, 0.2, 0.7, 0.4, 1, 1),
					Lifetime = nr(0.4, 0.7),
					Speed = nr(6, 12),
					SpreadAngle = Vector2.new(8, 8),
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS * 0.6,
					LightInfluence = 0,
					Squash = ns(0, 0.5, 1, 1),
					Shape = Enum.ParticleEmitterShape.Disc,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
					EmissionDirection = Enum.NormalId.Top,
					Flipbook = true,
					LargeFlipbook = true,
				}),
				Count = 6,
				Interval = 0.04,
			},
			Spirals = { -- flame ribbons coiling up the pillar
				Count = 3,
				Radius = 5,
				Speed = 6,
				RiseSpeed = 26,
				Width = 1.2,
				Lifetime = 0.5,
				Color = Palette.CrimsonBright,
				Transparency = ns(0, 0, 1, 1),
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS,
				InkWidth = 1.8, -- matching black ribbons, offset by half a turn
				InkBrightness = DARK_BRIGHTNESS,
			},
			EruptRocks = rocks({
				Count = 14,
				Radius = 6,
				SizeMin = 1.4,
				SizeMax = 3,
				TiltMin = 20,
				TiltMax = 45,
				RadiusJitter = 1,
				Stagger = 0.01,
				RiseTime = 0.25,
				Hold = 2,
				SinkTime = 0.6,
				UseGroundMaterial = true,
				Color = Palette.Smoke,
				Material = Enum.Material.Basalt,
			}),
			EruptPunch = "Medium",
			EruptShake = "Medium",
			EndSpheres = {
				sphere({
					StartSize = 2,
					EndSize = 18,
					Duration = 0.4,
					Color = Palette.White,
					Material = Enum.Material.Neon,
					StartTransparency = 0,
				}),
				sphere({
					StartSize = 4,
					EndSize = 30,
					Duration = 0.7,
					Color = Palette.CrimsonBright,
					Material = Enum.Material.ForceField,
					StartTransparency = 0,
					Delay = 0.05,
				}),
			},
			EndFocus = focus({
				Count = 36,
				InnerRadius = 0.08,
				LengthMin = 0.25,
				LengthMax = 0.65,
				Thickness = 4,
				Color = Palette.White,
				Transparency = 0.1,
				Duration = 0.35,
				RerollInterval = 0.04,
			}),
			EndImpact = "Heavy",
			EndPunch = "Heavy",
		},
	},

	---------------------------------------------------------------------
	FrostRequiem = {
		DisplayName = "Frost Requiem",
		Key = Enum.KeyCode.Six,
		Cooldown = 5,
		MaxRange = 120,
		Looping = false,
		VFX = {
			SpikeSpacing = 4, -- studs between spikes along the line
			MaxSpikes = 24,
			StartGap = 3, -- first spike this far in front of the caster
			SpikeInterval = 0.04, -- delay between consecutive spikes
			SpikeHeightMin = 4,
			SpikeHeightMax = 8,
			FinalSpikeScale = 1.6, -- the spike at the target is bigger
			SpikeWidthMin = 0.8,
			SpikeWidthMax = 1.5,
			SpikeTiltMax = 20, -- degrees
			SpikeBaseYaw = 45, -- degrees; rotates the square spike into a diamond cross-section
			SpikeSideJitter = 1.2, -- studs sideways
			SpikeBury = 0.6, -- fraction of the spike below ground when fully grown
			SpikeGrowTime = 0.15,
			SpikeColor = Palette.PaleCyan,
			SpikeMaterial = Enum.Material.Glass,
			SpikeTransparency = 0.15,
			RimColor = Palette.White, -- Highlight outline (the white rim glow)
			RimTransparency = 0,
			RimFillColor = Palette.PaleCyan,
			RimFillTransparency = 0.75,
			ShatterDelay = 1.5,
			Mist = {
				Spec = spec({
					Texture = Config.Textures.Smoke,
					Color = cs(Palette.White, Palette.PaleCyan),
					Size = ns(0, 2, 1, 6),
					Transparency = ns(0, 1, 0.3, 0.6, 1, 1),
					Lifetime = nr(1.2, 1.8),
					Speed = nr(2, 5),
					SpreadAngle = Vector2.new(180, 5),
					LightEmission = 0.3,
					Brightness = 1.5,
					LightInfluence = 0,
					Rotation = nr(0, 360),
					RotSpeed = nr(-25, 25),
					Drag = 1,
					Acceleration = Vector3.new(0, -0.5, 0),
					Flipbook = true,
					LargeFlipbook = true,
				}),
				Count = 4,
			},
			Snow = {
				Spec = spec({
					Texture = Config.Textures.Snow,
					Color = cs(Palette.White, Palette.PaleCyan),
					Size = ns(0, 0.25, 1, 0),
					Transparency = ns(0, 0, 1, 1),
					Lifetime = nr(0.8, 1.4),
					Speed = nr(3, 8),
					SpreadAngle = Vector2.new(60, 60),
					LightEmission = 1,
					Brightness = 3,
					LightInfluence = 0,
					Acceleration = Vector3.new(0, -4, 0),
				}),
				Count = 6,
			},
			ImpactShatter = {
				Spec = spec({
					Texture = Config.Textures.Shard,
					Color = cs(Palette.White, Palette.PaleCyan),
					Size = ns(0, 0.7, 1, 0),
					Transparency = ns(0, 0, 0.7, 0.2, 1, 1),
					Lifetime = nr(0.4, 0.8),
					Speed = nr(35, 60),
					SpreadAngle = Vector2.new(180, 180),
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					LightInfluence = 0,
					Drag = 4,
					Acceleration = Vector3.new(0, -20, 0),
					Rotation = nr(0, 360),
					RotSpeed = nr(-300, 300),
					Flipbook = true,
				}),
				Count = 60,
			},
			Flash = "Medium",
			Ring = ring({
				StartRadius = 1,
				EndRadius = 16,
				Duration = 0.45,
				Segments = 28,
				Width = 0.9,
				Color = Palette.White,
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS,
			}),
			Decal = decal({
				Radius = 10,
				StartScale = 0.2,
				SpreadTime = 0.35,
				Hold = 1.5,
				FadeTime = 2,
				Color = Palette.Ice,
				Texture = Config.Textures.Crack,
				Cracks = {
					Pattern = "Star", -- straight frozen star arms
					Count = 8,
					Segments = 4,
					Jitter = 0.08,
					Thickness = 0.18,
					Color = Palette.PaleCyan,
					Material = Enum.Material.Neon,
				},
			}),
			Fragments = shards({
				Count = 8, -- per spike
				SizeMin = 0.2,
				SizeMax = 0.5,
				StartRadius = 0.6,
				RiseMin = 0.5,
				RiseMax = 3,
				Spread = 3,
				RiseTime = 0.25,
				HangTime = 0.1,
				FallTime = 0.45,
				FallDistance = 5,
				FallSpread = 1.5,
				SpinMax = 540,
				HangDrift = 0.1,
				Color = Palette.PaleCyan,
				Material = Enum.Material.Glass,
			}),
			ShatterSnow = 10, -- snow particles per shattered spike
			Shake = "Light",
			ImpactShake = "Medium",
			-- Boss-tier layers --------------------------------------------
			Cluster = { -- giant crystals erupting in a crown at the target
				Count = 9,
				HeightMin = 9,
				HeightMax = 18,
				WidthMin = 1.8,
				WidthMax = 3.2,
				TiltMin = 15, -- degrees leaning outward
				TiltMax = 50,
				Radius = 2.5,
				AngleJitter = 0.3, -- radians
				GrowTime = 0.18,
				Stagger = 0.02,
			},
			IceRocks = rocks({
				Count = 18,
				Radius = 8,
				SizeMin = 1.4,
				SizeMax = 3,
				TiltMin = 20,
				TiltMax = 45,
				RadiusJitter = 1.4,
				Stagger = 0.008,
				RiseTime = 0.22,
				Hold = 1.4,
				SinkTime = 0.6,
				UseGroundMaterial = false,
				Color = Palette.Ice,
				Material = Enum.Material.Ice,
			}),
			Spheres = {
				sphere({
					StartSize = 1,
					EndSize = 14,
					Duration = 0.35,
					Color = Palette.White,
					Material = Enum.Material.Neon,
					StartTransparency = 0.1,
				}),
				sphere({
					StartSize = 3,
					EndSize = 28,
					Duration = 0.7,
					Color = Palette.PaleCyan,
					Material = Enum.Material.ForceField,
					StartTransparency = 0,
					Delay = 0.05,
				}),
			},
			Blizzard = { -- swirling snow storm around the impact
				Spec = spec({
					Texture = Config.Textures.Snow,
					Color = cs(Palette.White, Palette.PaleCyan),
					Size = ns(0, 0.4, 1, 0),
					Transparency = ns(0, 0, 0.8, 0.3, 1, 1),
					Lifetime = nr(1, 1.6),
					Speed = nr(8, 16),
					SpreadAngle = Vector2.new(180, 30),
					LightEmission = 1,
					Brightness = 3,
					LightInfluence = 0,
					Drag = 1,
					Acceleration = Vector3.new(0, -2, 0),
					Shape = Enum.ParticleEmitterShape.Disc,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				}),
				Count = 10,
				Interval = 0.06,
				Duration = 1.6,
				Radius = 10,
			},
			Focus = focus({
				Count = 34,
				InnerRadius = 0.08,
				LengthMin = 0.25,
				LengthMax = 0.65,
				Thickness = 3,
				Color = Palette.White,
				Transparency = 0.15,
				Duration = 0.35,
				RerollInterval = 0.04,
			}),
			Impact = "Medium",
			Punch = "Medium",
			ShatterRing = ring({
				StartRadius = 2,
				EndRadius = 22,
				Duration = 0.5,
				Segments = 32,
				Width = 0.8,
				Color = Palette.PaleCyan,
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS,
			}),
		},
	},

	---------------------------------------------------------------------
	GaleReaper = {
		DisplayName = "Gale Reaper",
		Key = Enum.KeyCode.Seven,
		Cooldown = 3,
		MaxRange = 150,
		Looping = false,
		VFX = {
			LaunchOffset = Vector3.new(0, 0.5, -3), -- from HumanoidRootPart
			BladeHeight = 2, -- blade arrives this far above the target's ground
			Speed = 140, -- studs/s
			MinTravelTime = 0.12,
			RollDegrees = 12, -- slight diagonal slash tilt
			Blade = {
				HalfWidth = 7, -- tip-to-centre
				Curve = 5, -- how far the crescent bulges forward
				CenterTangentScale = 0.5, -- sideways handle length at the centre, relative to HalfWidth
				CoreWidth = 1.6,
				CoreColor = Palette.White,
				CoreBrightness = LIGHT_BRIGHTNESS * 1.5,
				GlowWidth = 3.2,
				GlowTransparency = 0.6,
				EdgeWidth = 4,
				EdgeOffset = 0.8, -- black edge sits slightly behind the white core
				EdgeColor = Palette.Black,
				EdgeBrightness = DARK_BRIGHTNESS,
				EdgeTransparency = 0.25,
				TrailLifetime = 0.25,
				TrailWidth = 0.5,
				Segments = 20,
			},
			SpeedLines = {
				Spec = spec({
					Texture = Config.Textures.Spark,
					Color = cs(Palette.White),
					Size = ns(0, 0.25, 1, 0),
					Transparency = ns(0, 0.2, 1, 1),
					Lifetime = nr(0.15, 0.3),
					Speed = nr(40, 80),
					SpreadAngle = Vector2.new(10, 10),
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					LightInfluence = 0,
					Orientation = Enum.ParticleOrientation.VelocityParallel,
					Squash = ns(0, 3, 1, 2),
					Shape = Enum.ParticleEmitterShape.Box,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					EmissionDirection = Enum.NormalId.Back,
				}),
				Count = 4,
				Interval = 0.02,
				BoxSize = Vector3.new(12, 3, 1),
			},
			WakeSmoke = {
				Spec = spec({
					Texture = Config.Textures.InkWisp,
					Color = cs(Palette.Black, Palette.Smoke),
					Size = ns(0, 1.5, 1, 3),
					Transparency = ns(0, 0.3, 1, 1),
					Lifetime = nr(0.3, 0.5),
					Speed = nr(2, 5),
					SpreadAngle = Vector2.new(180, 180),
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					LightInfluence = 0,
					Rotation = nr(0, 360),
					Shape = Enum.ParticleEmitterShape.Box,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					Flipbook = true,
				}),
				Count = 2,
			},
			Spirals = {
				Count = 3,
				Radius = 1.6,
				Speed = 24, -- rad/s around the travel axis
				Width = 0.18,
				Lifetime = 0.3,
				Color = Palette.White,
				Transparency = ns(0, 0.2, 1, 1),
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS,
			},
			Split = {
				Count = 6,
				Scale = 0.4,
				Distance = 14,
				Duration = 0.3,
				SpreadDegrees = 70,
			},
			Flash = "Small",
			Dust = {
				Spec = spec({
					Texture = Config.Textures.Smoke,
					Color = cs(Palette.Grey, Palette.Smoke),
					Size = ns(0, 2, 1, 6),
					Transparency = ns(0, 0.4, 1, 1),
					Lifetime = nr(0.6, 1.1),
					Speed = nr(10, 22),
					SpreadAngle = Vector2.new(70, 15),
					LightEmission = 0,
					Brightness = 1,
					LightInfluence = 0,
					Drag = 3,
					Rotation = nr(0, 360),
					RotSpeed = nr(-60, 60),
					Flipbook = true,
					LargeFlipbook = true,
				}),
				Count = 25,
			},
			Shards = shards({
				Count = 18,
				SizeMin = 0.2,
				SizeMax = 0.55,
				StartRadius = 4,
				RiseMin = 1.5,
				RiseMax = 4,
				Spread = 2,
				RiseTime = 0.35,
				HangTime = 0.25,
				FallTime = 0.5,
				FallDistance = 5,
				FallSpread = 1,
				SpinMax = 360,
				HangDrift = 0.2,
				Color = Palette.Ink,
				Material = Enum.Material.SmoothPlastic,
			}),
			Decal = decal({
				Radius = 2.5, -- half-width of the slash
				Length = 22,
				StartScale = 0.1,
				SpreadTime = 0.18,
				Hold = 1.2,
				FadeTime = 2,
				Color = Palette.Black,
				Texture = Config.Textures.Crack,
				Cracks = {
					Pattern = "Slash",
					Count = 6, -- side branches
					Segments = 8,
					Jitter = 0.3,
					Thickness = 0.24,
					Color = Palette.Black,
					Material = Enum.Material.SmoothPlastic,
				},
			}),
			Shake = "Light",
			-- Boss-tier layers --------------------------------------------
			Slashes = { -- three crescents fired in quick succession
				Count = 3,
				Interval = 0.11,
				Rolls = { 12, -24, 38 }, -- degrees; one entry per slash (cycled)
				SideOffset = 2.5, -- studs between the slashes' paths
			},
			PathRocks = rocks({
				Count = 0, -- unused for lines; Spacing decides the count
				Spacing = 3,
				Radius = 2.6, -- distance either side of the slash line
				SizeMin = 1,
				SizeMax = 2.2,
				TiltMin = 25,
				TiltMax = 55,
				RadiusJitter = 0.6,
				Stagger = 0.012,
				RiseTime = 0.2,
				Hold = 1.4,
				SinkTime = 0.6,
				UseGroundMaterial = true,
				Color = Palette.Smoke,
				Material = Enum.Material.Slate,
			}),
			Spheres = {
				sphere({
					StartSize = 1,
					EndSize = 12,
					Duration = 0.3,
					Color = Palette.White,
					Material = Enum.Material.Neon,
					StartTransparency = 0.1,
				}),
				sphere({
					StartSize = 2,
					EndSize = 22,
					Duration = 0.55,
					Color = Palette.Black,
					Material = Enum.Material.ForceField,
					StartTransparency = 0,
					Delay = 0.04,
				}),
			},
			Focus = focus({
				Count = 36,
				InnerRadius = 0.08,
				LengthMin = 0.3,
				LengthMax = 0.7,
				Thickness = 3,
				Color = Palette.White,
				Transparency = 0.1,
				Duration = 0.3,
				RerollInterval = 0.04,
			}),
			Impact = "Medium",
			Punch = "Medium",
		},
	},

	---------------------------------------------------------------------
	CelestialVerdict = {
		DisplayName = "Celestial Verdict",
		Key = Enum.KeyCode.Eight,
		Cooldown = 15,
		MaxRange = 200,
		Looping = false,
		VFX = {
			SkyDim = {
				FadeIn = 0.6,
				FadeOut = 1.2,
				ExposureCompensation = -1.6, -- added to the current value
				Saturation = -1,
				Contrast = 0.35,
				Brightness = -0.1,
			},
			CircleHeight = 70,
			CircleTime = 1.4, -- rune circle draws + spins before the pillar
			Circle = rune({
				Radius = 22,
				InnerRadiusScale = 0.82,
				StarPoints = 7,
				StarStep = 3,
				Ticks = 28,
				TickLength = 1.6,
				Width = 0.5,
				Color = Palette.White,
				LightEmission = 1,
				Brightness = LIGHT_BRIGHTNESS * 1.5,
				DrawTime = 0.9,
				Hold = 2.6,
				FadeTime = 0.8,
				RotationSpeed = 0.5,
				Lift = 0,
			}),
			Pillar = {
				CrashTime = 0.12,
				Duration = 1.4,
				FadeTime = 0.5,
				CoreWidth = 9,
				GlowWidth = 18,
				GlowTransparency = 0.55,
				Color = Palette.White,
				Brightness = LIGHT_BRIGHTNESS * 2,
			},
			PillarBolts = {
				Count = 10,
				Radius = 6,
				Bolt = bolt({
					Segments = 16,
					Amplitude = 1.6,
					Width = 0.35,
					EndWidthScale = 0.5,
					Color = Palette.White,
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					FlickerInterval = 0.05,
					Duration = 1.4,
					FadeTime = 0.4,
				}),
			},
			InkSpiral = {
				Spec = spec({
					Texture = Config.Textures.Smoke,
					Color = cs(Palette.Black, Palette.Ink),
					Size = ns(0, 3, 1, 7),
					Transparency = ns(0, 1, 0.2, 0.15, 0.8, 0.4, 1, 1),
					Lifetime = nr(1.2, 1.8),
					Speed = nr(18, 30),
					SpreadAngle = Vector2.new(10, 10),
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					LightInfluence = 0,
					Rotation = nr(0, 360),
					RotSpeed = nr(90, 180),
					Shape = Enum.ParticleEmitterShape.Cylinder,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
					EmissionDirection = Enum.NormalId.Top,
					Flipbook = true,
					LargeFlipbook = true,
				}),
				Count = 6,
				Interval = 0.05,
				Radius = 11,
			},
			InkTrails = {
				Count = 6,
				Radius = 10,
				Speed = 5, -- rad/s
				RiseSpeed = 40, -- studs/s
				Width = 2.2,
				Lifetime = 0.9,
				Color = Palette.Black,
				Transparency = ns(0, 0.1, 1, 1),
				LightEmission = 0,
				Brightness = DARK_BRIGHTNESS,
			},
			Flash = "Ultimate",
			CoreCount = 3,
			Sparks = { Spec = Emitters.WhiteSparks, Count = 120 },
			Smoke = { Spec = Emitters.InkSmoke, Count = 50 },
			Rings = {
				ring({
					StartRadius = 4,
					EndRadius = 45,
					Duration = 0.7,
					Segments = 48,
					Width = 3,
					Color = Palette.White,
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					Delay = 0,
				}),
				ring({
					StartRadius = 2,
					EndRadius = 30,
					Duration = 0.8,
					Segments = 40,
					Width = 2,
					Color = Palette.Black,
					LightEmission = 0,
					Brightness = DARK_BRIGHTNESS,
					Delay = 0.18,
				}),
			},
			Decal = decal({
				Radius = 22,
				StartScale = 0.3,
				SpreadTime = 0.3,
				Hold = 2,
				FadeTime = 2.2,
				Color = Palette.Black,
				Texture = Config.Textures.Crack,
				Cracks = {
					Pattern = "Radial",
					Count = 14,
					Segments = 7,
					Jitter = 0.5,
					Thickness = 0.4,
					Color = Palette.Black,
					Material = Enum.Material.SmoothPlastic,
				},
			}),
			Shards = shards({
				Count = 70,
				SizeMin = 0.3,
				SizeMax = 1.2,
				StartRadius = 20,
				RiseMin = 4,
				RiseMax = 14,
				Spread = 2,
				RiseTime = 0.6,
				HangTime = 1.2, -- dozens of shards hanging mid-air
				FallTime = 0.7,
				FallDistance = 14,
				FallSpread = 1,
				SpinMax = 360,
				HangDrift = 0.6,
				Color = Palette.Ink,
				Material = Enum.Material.SmoothPlastic,
			}),
			Shake = "Ultimate",
			-- Boss-tier layers --------------------------------------------
			ChargeArcs = { -- lightning crawling over the rune circle while it charges
				Count = 5,
				Radius = 20,
				Span = 1, -- radians each arc may stretch around the circle
				Bolt = bolt({
					Segments = 8,
					Amplitude = 2,
					Width = 0.35,
					EndWidthScale = 0.3,
					Color = Palette.White,
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
					FlickerInterval = 0.05,
					Duration = 1.4,
					FadeTime = 0.2,
				}),
			},
			ChargeFocus = focus({ -- focus lines toward the circle as it finishes charging
				Count = 30,
				InnerRadius = 0.12,
				LengthMin = 0.2,
				LengthMax = 0.5,
				Thickness = 2,
				Color = Palette.White,
				Transparency = 0.35,
				Duration = 0.5,
				RerollInterval = 0.05,
			}),
			Spears = { -- smaller light pillars slamming down around the main one
				Count = 8,
				Radius = 18,
				AngleJitter = 0.2, -- radians
				Delay = 0.2, -- after the main impact
				Interval = 0.06,
				Height = 50,
				CoreWidth = 2.4,
				GlowWidth = 6,
				GlowTransparency = 0.55,
				CrashTime = 0.08,
				Duration = 0.45,
				FadeTime = 0.3,
				Flash = "Small",
				Ring = ring({
					StartRadius = 1,
					EndRadius = 9,
					Duration = 0.35,
					Segments = 20,
					Width = 0.8,
					Color = Palette.White,
					LightEmission = 1,
					Brightness = LIGHT_BRIGHTNESS,
				}),
			},
			Spheres = {
				sphere({
					StartSize = 4,
					EndSize = 40,
					Duration = 0.5,
					Color = Palette.White,
					Material = Enum.Material.Neon,
					StartTransparency = 0,
				}),
				sphere({
					StartSize = 8,
					EndSize = 70,
					Duration = 1,
					Color = Palette.Black,
					Material = Enum.Material.ForceField,
					StartTransparency = 0,
					Delay = 0.08,
				}),
				sphere({
					StartSize = 10,
					EndSize = 95,
					Duration = 1.3,
					Color = Palette.White,
					Material = Enum.Material.ForceField,
					StartTransparency = 0.2,
					Delay = 0.2,
				}),
			},
			Rocks = rocks({
				Count = 28,
				Radius = 16,
				SizeMin = 3,
				SizeMax = 6.5,
				TiltMin = 25,
				TiltMax = 55,
				RadiusJitter = 2.5,
				Stagger = 0.006,
				RiseTime = 0.3,
				Hold = 2.6,
				SinkTime = 0.8,
				UseGroundMaterial = true,
				Color = Palette.Smoke,
				Material = Enum.Material.Slate,
			}),
			OuterRocks = rocks({
				Count = 36,
				Radius = 28,
				SizeMin = 2,
				SizeMax = 4.5,
				TiltMin = 15,
				TiltMax = 40,
				RadiusJitter = 3,
				Stagger = 0.006,
				RiseTime = 0.3,
				Hold = 2.4,
				SinkTime = 0.8,
				UseGroundMaterial = true,
				Color = Palette.Smoke,
				Material = Enum.Material.Slate,
			}),
			OuterRocksDelay = 0.12,
			Focus = focus({
				Count = 64,
				InnerRadius = 0.05,
				LengthMin = 0.3,
				LengthMax = 0.85,
				Thickness = 5,
				Color = Palette.White,
				Transparency = 0,
				Duration = 0.55,
				RerollInterval = 0.035,
			}),
			Impact = "Ultimate",
			Punch = "Ultimate",
		},
	},
}

---------------------------------------------------------------------------
-- Typed accessor for code that looks spells up by a runtime string
-- (the server, the controller and the test binds).
---------------------------------------------------------------------------
export type SpellMeta = {
	Name: string,
	DisplayName: string,
	Key: Enum.KeyCode,
	Cooldown: number,
	MaxRange: number,
	Looping: boolean,
	MaxDuration: number?,
}

function Config.GetSpellMeta(name: string): SpellMeta?
	local entry = (Config.Spells :: any)[name]
	if entry == nil then
		return nil
	end
	return {
		Name = name,
		DisplayName = entry.DisplayName,
		Key = entry.Key,
		Cooldown = entry.Cooldown,
		MaxRange = entry.MaxRange or Config.Network.DefaultMaxRange,
		Looping = entry.Looping == true,
		MaxDuration = entry.MaxDuration,
	}
end

return Config
