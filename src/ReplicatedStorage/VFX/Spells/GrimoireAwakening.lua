--!strict
--[[
	GrimoireAwakening (key 1, summon)
	=================================
	The caster's grimoire materialises above their open hand:
	  1. Black ink pages spiral out of nothing (plus inward ink wisps) and
	     snap together into a floating book.
	  2. White runes etch across the cover as flickering electric lines.
	  3. The cover flips open with a white flash and spark burst.
	  4. A ring of glowing glyph tiles spins slowly at waist height while two
	     white trails orbit the caster for Orbit.Duration seconds.
	  5. The open book settles into a faint idle glow, then fades away.

	The book follows the caster's hand every frame. Everything is parented
	to one Folder that is destroyed at the end (and scheduled with Debris as
	a safety net), so repeated casts never leak.
]]

local Config = require(script.Parent.Parent.Config)
local Util = script.Parent.Parent.Util
local Emit = require(Util.Emit)
local Flash = require(Util.Flash)
local Lightning = require(Util.Lightning)
local OrbitTrail = require(Util.OrbitTrail)
local Types = require(Util.Types)

local C = Config.Spells.GrimoireAwakening.VFX
local Padding = Config.General.CleanupPadding

local GrimoireAwakening = {}

local function handPosition(character: Model, root: BasePart): Vector3
	for _, name in C.HandNames do
		local hand = character:FindFirstChild(name)
		if hand and hand:IsA("BasePart") then
			return hand.Position
		end
	end
	return (root.CFrame * CFrame.new(C.FallbackOffset)).Position
end

local function totalDuration(): number
	return C.GatherTime
		+ C.SnapTime
		+ #C.RuneLines * C.RuneEtchInterval
		+ C.RuneHoldTime
		+ C.OpenTime
		+ C.Orbit.Duration
		+ C.IdleTime
		+ C.FadeTime
end

function GrimoireAwakening.Play(character: Model, _targetPosition: Vector3)
	local root = Emit.root(character)
	if root == nil then
		return
	end

	local group = Instance.new("Folder")
	group.Name = "GrimoireAwakening"
	group.Parent = Emit.folder()
	Emit.cleanup(group, totalDuration() + Padding)

	-- Book placement: above the hand, oriented with the character.
	local lastBookCFrame = CFrame.new(handPosition(character, root)) * root.CFrame.Rotation * CFrame.new(C.BookOffset)
	local bob = 0
	local function bookCFrame(): CFrame
		local currentRoot = Emit.root(character)
		if currentRoot and character.Parent then
			lastBookCFrame = CFrame.new(handPosition(character, currentRoot))
				* currentRoot.CFrame.Rotation
				* CFrame.new(C.BookOffset)
		end
		return lastBookCFrame * CFrame.new(0, bob, 0)
	end

	-------------------------------------------------------------------
	-- 1. Pages spiral in from nothing.
	-------------------------------------------------------------------
	local start = bookCFrame()
	local wispHost = Emit.anchor(start, C.InkGather.Spec.Lifetime.Max, Vector3.one * C.InkGather.Radius * 2)
	Emit.emitter(wispHost, C.InkGather.Spec):Emit(C.InkGather.Count)

	type Page = { Part: Part, Angle: number, Height: number, Tumble: Vector3 }
	local pages: { Page } = {}
	for i = 1, C.PageCount do
		local page = Emit.part(C.PageSize, C.PageColor, C.PageMaterial)
		page.Name = "Page"
		page.Transparency = 1
		page.Parent = group
		Emit.tween(page, C.PageFadeIn, { Transparency = 0 })
		table.insert(pages, {
			Part = page,
			Angle = (i / C.PageCount) * math.pi * 2,
			Height = Emit.random(-C.PageStartHeight, C.PageStartHeight),
			Tumble = Emit.randomUnit() * C.PageTumble,
		})
	end

	local function placePages(alpha: number)
		local eased = 1 - (1 - alpha) ^ 3
		local center = bookCFrame()
		for i, page in pages do
			local radius = C.PageStartRadius * (1 - eased)
			local angle = page.Angle + C.PageSpinTurns * math.pi * 2 * eased
			local height = page.Height * (1 - eased) + (i - 1) * C.PageStackGap
			local tumble = page.Tumble * (1 - eased)
			page.Part.CFrame = center
				* CFrame.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
				* CFrame.Angles(tumble.X, angle + tumble.Y, tumble.Z)
		end
	end
	placePages(0)
	Emit.step(C.GatherTime, function(alpha)
		if not group.Parent then
			return true
		end
		placePages(alpha)
		return false
	end)
	task.wait(C.GatherTime)
	if not group.Parent then
		return
	end
	for _, page in pages do
		page.Part:Destroy()
	end

	-------------------------------------------------------------------
	-- 2. Book forms (block + hinged cover) and snaps into place.
	-------------------------------------------------------------------
	local block = Emit.part(C.BookSize, C.PageColor, C.PageMaterial)
	block.Name = "Book"
	block.Parent = group
	local coverSize = Vector3.new(C.BookSize.X, C.CoverThickness, C.BookSize.Z)
	local cover = Emit.part(coverSize, C.CoverColor, C.CoverMaterial)
	cover.Name = "Cover"
	cover.Parent = group

	local light = Instance.new("PointLight")
	light.Color = C.IdleLight.Color
	light.Brightness = 0
	light.Range = C.IdleLight.Range
	light.Shadows = false
	light.Parent = block

	local coverAngle = 0
	local scale = C.SnapScale
	local function coverCFrame(): CFrame
		-- Hinge along the spine (local -X edge of the book's top face).
		local book = bookCFrame()
		local halfX = C.BookSize.X / 2
		local top = C.BookSize.Y / 2 + C.CoverThickness / 2
		return book * CFrame.new(-halfX, top, 0) * CFrame.Angles(0, 0, coverAngle) * CFrame.new(halfX, 0, 0)
	end

	local idleTime = 0
	local followDuration = totalDuration() - C.GatherTime
	Emit.step(followDuration, function(_alpha, dt, elapsed)
		if not group.Parent then
			return true
		end
		if elapsed > followDuration - C.FadeTime - C.IdleTime then
			idleTime += dt
			bob = math.sin(idleTime * C.IdleBobSpeed) * C.IdleBobAmplitude
		end
		block.Size = C.BookSize * scale
		cover.Size = coverSize * scale
		block.CFrame = bookCFrame()
		cover.CFrame = coverCFrame()
		return false
	end)

	-- Snap: pop to SnapScale then settle to 1.
	local snapValue = Instance.new("NumberValue")
	snapValue.Value = C.SnapScale
	snapValue.Changed:Connect(function(value: number)
		scale = value
	end)
	local snap = Emit.tween(snapValue, C.SnapTime, { Value = 1 }, Enum.EasingStyle.Back)
	snap.Completed:Once(function()
		snapValue:Destroy()
	end)
	task.wait(C.SnapTime)
	if not group.Parent then
		return
	end

	-------------------------------------------------------------------
	-- 3. Runes etch across the cover as electric lines.
	-------------------------------------------------------------------
	local runeLift = C.CoverThickness / 2 + C.RuneHeight
	local function coverPoint(p: Vector2): Vector3
		return (coverCFrame() * CFrame.new(p.X * C.BookSize.X / 2, runeLift, p.Y * C.BookSize.Z / 2)).Position
	end
	local runeHandles: { Types.Handle } = {}
	local remainingEtch = #C.RuneLines * C.RuneEtchInterval + C.RuneHoldTime
	for index, line in C.RuneLines do
		local params = table.clone(C.RuneBolt)
		-- Every line lives until the book opens, however late it was etched.
		params.Duration = remainingEtch - (index - 1) * C.RuneEtchInterval
		table.insert(
			runeHandles,
			Lightning.Bolt(function()
				return coverPoint(line[1]), coverPoint(line[2])
			end, params)
		)
		task.wait(C.RuneEtchInterval)
	end
	task.wait(C.RuneHoldTime)
	if not group.Parent then
		return
	end

	-------------------------------------------------------------------
	-- 4. The cover flips open with a white flash.
	-------------------------------------------------------------------
	Emit.step(C.OpenTime, function(alpha)
		coverAngle = math.pi * (1 - (1 - alpha) ^ 2)
		return false
	end)
	task.wait(C.OpenTime)
	if not group.Parent then
		return
	end
	local openPosition = block.Position
	Flash.Impact(openPosition, C.OpenFlash)
	Emit.burstAt(CFrame.new(openPosition), { Spec = Config.Emitters.WhiteSparks, Count = C.OpenSparks })
	Emit.burstAt(CFrame.new(openPosition), { Spec = Config.Emitters.CoreFlare, Count = 1 })
	light.Brightness = C.IdleLight.Brightness

	-------------------------------------------------------------------
	-- 5. Glyph ring at waist height + two orbiting trails.
	-------------------------------------------------------------------
	local glyphs: { Part } = {}
	local hasGlyphTexture = Config.Textures.Glyph ~= Config.PlaceholderTexture
	for _ = 1, C.GlyphCount do
		local glyph = Emit.part(C.GlyphSize, C.GlyphColor, Enum.Material.Neon)
		glyph.Name = "Glyph"
		glyph.Transparency = 1
		glyph.Parent = group
		if hasGlyphTexture then
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local decal = Instance.new("Decal")
				decal.Texture = Config.Textures.Glyph
				decal.Face = face
				decal.Parent = glyph
			end
		end
		Emit.tween(glyph, C.GlyphFadeIn, { Transparency = C.GlyphTransparency })
		table.insert(glyphs, glyph)
	end
	local glyphAngle = 0
	local glyphCenter = CFrame.new(root.Position)
	Emit.step(C.Orbit.Duration + C.GlyphFadeIn, function(_alpha, dt, elapsed)
		if not group.Parent then
			return true
		end
		local currentRoot = Emit.root(character)
		if currentRoot then
			glyphCenter = CFrame.new(currentRoot.Position)
		end
		glyphAngle += C.GlyphSpinSpeed * dt
		for i, glyph in glyphs do
			local a = glyphAngle + (i / #glyphs) * math.pi * 2
			local bobOffset = math.sin(elapsed * C.GlyphBobSpeed + i) * C.GlyphBobAmplitude
			local offset =
				Vector3.new(math.cos(a) * C.GlyphRadius, C.GlyphHeight + bobOffset, math.sin(a) * C.GlyphRadius)
			local position = glyphCenter.Position + offset
			glyph.CFrame = CFrame.lookAt(position, glyphCenter.Position + Vector3.yAxis * offset.Y)
		end
		return false
	end)

	local style: Types.TrailStyle = {
		Width = C.Orbit.Width,
		Lifetime = C.Orbit.Lifetime,
		Color = C.Orbit.Color,
		Transparency = C.Orbit.Transparency,
		LightEmission = C.Orbit.LightEmission,
		Brightness = C.Orbit.Brightness,
	}
	for _, orbit in C.Orbit.Trails do
		OrbitTrail.OnCharacter(character, orbit, style, C.Orbit.Duration)
	end
	task.wait(C.Orbit.Duration)
	if not group.Parent then
		return
	end
	for _, glyph in glyphs do
		Emit.tween(glyph, C.GlyphFadeIn, { Transparency = 1 })
	end

	-------------------------------------------------------------------
	-- 6. Faint idle glow, then fade everything out.
	-------------------------------------------------------------------
	task.wait(C.IdleTime)
	if not group.Parent then
		return
	end
	Emit.tween(light, C.FadeTime, { Brightness = 0 })
	Emit.tween(block, C.FadeTime, { Transparency = 1 })
	Emit.tween(cover, C.FadeTime, { Transparency = 1 })
	Emit.cleanup(group, C.FadeTime)
	for _, handle in runeHandles do
		handle.Stop()
	end
end

-- Typed export: the checker verifies this module matches Types.SpellModule.
local module: Types.SpellModule = { Play = GrimoireAwakening.Play }
return module
