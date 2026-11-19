local _, ns = ...

-- The theme's art beyond settings (Core/Themes.lua): a tiled backdrop
-- under the frame, reaching out to the border (the border padding shows
-- it around the bars, like a plaque), corner ornaments on the border and
-- a solid shadow behind it. Only plain textures, placed out of combat
-- with everything else (Style); nothing here is clickable. Auras already
-- keep clear of the border's extent (Elements/Auras.lua), padding
-- included. The backdrop has a rounding mask of its own, concentric with
-- the ring (its radius plus the padding).
--
-- Raid cells name their theme (button.themeOf, Raid/Cell.lua) and get
-- the backdrop only.
local ThemeArt = { name = "ThemeArt" }
ns.ThemeArt = ThemeArt

local Config = ns.Config
-- The textures come with the embedded LibForeverThemes, as Pitwall's wedge rule.
local Lib = LibForeverThemes
-- Texture coordinates of a top-left ornament for each corner
-- (Corners.POINTS order): mirrored, never rotated.
local MIRROR = { { 0, 1, 0, 1 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 1, 0, 1, 0 } }
local SHADOW_COLOR = { 0, 0, 0, 1 }
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- The backdrop on a texture: tiled, tinted; hidden without one.
function ThemeArt.Paint(texture, spec)
    local art = spec.art
    if not art or not art.back then
        texture:Hide()
        return
    end
    texture:SetTexture(Lib.Texture(ns.Themes.Back(spec)), "REPEAT", "REPEAT")
    texture:SetHorizTile(true)
    texture:SetVertTile(true)
    local tint = ns.Themes.Tint(spec) or { 1, 1, 1, 1 }
    texture:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
    texture:Show()
end

function ThemeArt.Build(frame)
    -- Below the frame's own level: under the bars, the title row and the
    -- border.
    local under = CreateFrame("Frame", nil, frame)
    under:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    frame.themeUnder = under
    -- The solid shadow in two forms, as the border (Elements/Shape.lua):
    -- around the frame, or around the unit box with a docked castbar.
    -- Shape.Refresh shows the one that matches (ThemeArt.Refresh).
    frame.themeShadow = under:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.themeShadow:Hide()
    frame.themeBlockShadow = under:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.themeBlockShadow:Hide()
    frame.themeBack = under:CreateTexture(nil, "BACKGROUND", nil, 0)
    frame.themeBack:Hide()
    ns.Corners.Add(under, frame.themeBack)
    frame.themeClip = ns.Corners.Clipper(under)
    -- The backdrop round the frame and its docked castbar, like the ring:
    -- else the castbar's slot showed the game (or black) through it.
    -- Its own holder: a clipper rounds every texture its owner listed.
    local blockUnder = CreateFrame("Frame", nil, frame)
    blockUnder:SetFrameLevel(under:GetFrameLevel())
    frame.themeBlockBack = blockUnder:CreateTexture(nil, "BACKGROUND", nil, 0)
    frame.themeBlockBack:Hide()
    ns.Corners.Add(blockUnder, frame.themeBlockBack)
    frame.themeBlockClip = ns.Corners.Clipper(blockUnder)
    -- The material frame round the ring's outside (Goblin), in
    -- the same two sets as the shadow; below the frame, so auras beside
    -- it stay on top.
    frame.themeFrame, frame.themeBlockFrame = {}, {}
    for i = 1, 4 do
        frame.themeFrame[i] = under:CreateTexture(nil, "BORDER")
        frame.themeFrame[i]:Hide()
        frame.themeBlockFrame[i] = blockUnder:CreateTexture(nil, "BORDER")
        frame.themeBlockFrame[i]:Hide()
    end
    -- Above the border rings and the texts' overlay.
    frame.themeOver = CreateFrame("Frame", nil, frame)
    frame.themeOver:SetAllPoints(frame)
    frame.themeOver:SetFrameLevel(frame:GetFrameLevel() + 12)
    -- Two sets like the shadow: at the frame's corners, and at the unit
    -- box's with a docked castbar.
    frame.themeOrnaments, frame.themeBlockOrnaments = {}, {}
    for i = 1, 4 do
        frame.themeOrnaments[i] = frame.themeOver:CreateTexture(nil, "OVERLAY")
        frame.themeOrnaments[i]:Hide()
        frame.themeBlockOrnaments[i] = frame.themeOver:CreateTexture(nil, "OVERLAY")
        frame.themeBlockOrnaments[i]:Hide()
    end
    -- The rule along the top, below the ornaments (Swiss: its accent sits on it).
    frame.themeRule = frame.themeOver:CreateTexture(nil, "OVERLAY", nil, -1)
    frame.themeRule:Hide()
    frame.themeBlockRule = frame.themeOver:CreateTexture(nil, "OVERLAY", nil, -1)
    frame.themeBlockRule:Hide()
    -- The title wedge: above the title row's strip (BACKGROUND), below
    -- the bars and the texts.
    frame.themeWedge = frame:CreateTexture(nil, "BORDER")
    frame.themeWedge:Hide()
end

-- The solid shadow behind box's ring (extent: its reach), offset down
-- and right.
function ThemeArt.PlaceShadow(shadow, box, offset, extent)
    shadow:ClearAllPoints()
    shadow:SetPoint("TOPLEFT", box, "TOPLEFT", offset - extent, extent - offset)
    shadow:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", offset + extent, -offset - extent)
    shadow:SetColorTexture(SHADOW_COLOR[1], SHADOW_COLOR[2], SHADOW_COLOR[3], SHADOW_COLOR[4])
end

local function placeShadow(frame, art, extent, apart)
    frame.themeShadowOn = art.hardShadow ~= nil and not apart
    if frame.themeShadowOn then
        ThemeArt.PlaceShadow(frame.themeShadow, frame, art.hardShadow, extent)
        ThemeArt.PlaceShadow(frame.themeBlockShadow, frame.unitBox or frame, art.hardShadow, extent)
    end
    ThemeArt.Refresh(frame, frame.blockRing ~= nil and frame.blockRing:IsShown())
end

-- Any time, combat included (Elements/Shape.lua: Refresh): shadow and
-- ornaments of the frame alone, or of the frame with its docked castbar
-- (joined). Only shows and hides.
function ThemeArt.Refresh(frame, joined)
    if not frame.themeShadow then return end
    local on = frame.themeShadowOn == true
    frame.themeShadow:SetShown(on and not joined)
    frame.themeBlockShadow:SetShown(on and joined)
    local back = frame.themeBackOn == true
    frame.themeBack:SetShown(back and not joined)
    frame.themeBlockBack:SetShown(back and joined)
    local rule = frame.themeRuleOn == true
    frame.themeRule:SetShown(rule and not joined)
    frame.themeBlockRule:SetShown(rule and joined)
    local framed = frame.themeFrameOn == true
    for i = 1, 4 do
        frame.themeFrame[i]:SetShown(framed and not joined)
        frame.themeBlockFrame[i]:SetShown(framed and joined)
    end
    local wanted = frame.themeOrnamentsOn or {}
    for i = 1, 4 do
        frame.themeOrnaments[i]:SetShown(wanted[i] == true and not joined)
        frame.themeBlockOrnaments[i]:SetShown(wanted[i] == true and joined)
    end
end

-- The backdrop out to the ring's inner edge.
function ThemeArt.PlaceBack(back, clip, box, padding, radius)
    back:ClearAllPoints()
    back:SetPoint("TOPLEFT", box, "TOPLEFT", -padding, padding)
    back:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", padding, -padding)
    ns.Corners.Fit(clip, back, radius > 0 and radius + padding or 0)
end
local function placeBack(frame, padding, radius)
    ThemeArt.PlaceBack(frame.themeBack, frame.themeClip, frame, padding, radius)
    ThemeArt.PlaceBack(frame.themeBlockBack, frame.themeBlockClip, frame.unitBox or frame, padding, radius)
end

-- Ornaments sit at the ring's outer corners, art.ornamentInset inwards
-- (negative: outwards).
local function placeOrnamentSet(pieces, box, art, wanted, extent, c)
    local size, inset = art.ornamentSize or 12, (art.ornamentInset or 0) - extent
    for i, piece in ipairs(pieces) do
        if wanted[i] then
            local point = ns.Corners.POINTS[i]
            local dx = (i == 1 or i == 3) and inset or -inset
            local dy = (i <= 2) and -inset or inset
            piece:ClearAllPoints()
            piece:SetPoint(point, box, point, dx, dy)
            piece:SetSize(size, art.ornamentHeight or size)
            piece:SetTexture(Lib.Texture(art.ornament))
            piece:SetTexCoord(unpack(MIRROR[i]))
            piece:SetVertexColor(c[1], c[2], c[3], c[4])
        end
    end
end

local function placeOrnaments(frame, id, art, extent)
    local wanted = {}
    for _, i in ipairs(art.ornament and art.corners or {}) do wanted[i] = true end
    frame.themeOrnamentsOn = wanted
    local c = ns.Themes.Accent(id, "ornament") or art.ornamentColor or { 1, 1, 1, 1 }
    placeOrnamentSet(frame.themeOrnaments, frame, art, wanted, extent, c)
    placeOrnamentSet(frame.themeBlockOrnaments, frame.unitBox or frame, art, wanted, extent, c)
end

-- The frame's four strips round box's ring (extent: its reach), size
-- wide; top and bottom run across the corners. The material repeats at
-- its own size.
local function placeFrameOn(strips, box, art, extent, size)
    local o = extent + size
    local spots = {
        { "TOPLEFT", -o, o, "TOPRIGHT", o, extent },
        { "BOTTOMLEFT", -o, -extent, "BOTTOMRIGHT", o, -o },
        { "TOPLEFT", -o, extent, "BOTTOMLEFT", -extent, -extent },
        { "TOPRIGHT", extent, extent, "BOTTOMRIGHT", o, -extent },
    }
    for i, strip in ipairs(strips) do
        local p = spots[i]
        strip:ClearAllPoints()
        strip:SetPoint("TOPLEFT", box, p[1], p[2], p[3])
        strip:SetPoint("BOTTOMRIGHT", box, p[4], p[5], p[6])
        strip:SetTexture(Lib.Texture(art.frame), "REPEAT", "REPEAT")
        strip:SetHorizTile(true)
        strip:SetVertTile(true)
        strip:SetVertexColor(1, 1, 1, 1)
    end
end

-- The frame's width (0 without one): only round a ring (extent > 0).
local function placeFrame(frame, art, extent)
    local size = (art.frame and extent > 0) and ns.Pixel.Snap(art.frameSize, nil, 1) or 0
    frame.themeFrameOn = size > 0
    if size == 0 then return 0 end
    placeFrameOn(frame.themeFrame, frame, art, extent, size)
    placeFrameOn(frame.themeBlockFrame, frame.unitBox or frame, art, extent, size)
    return size
end

-- The rule (a colour) from the ring's outer top corners down art.ruleSize pixels.
local function placeRuleOn(rule, box, art, extent)
    rule:ClearAllPoints()
    rule:SetPoint("TOPLEFT", box, "TOPLEFT", -extent, extent)
    rule:SetPoint("TOPRIGHT", box, "TOPRIGHT", extent, extent)
    rule:SetHeight(ns.Pixel.Snap(art.ruleSize, nil, 1))
    local c = art.rule
    rule:SetColorTexture(c[1], c[2], c[3], c[4])
end

local function placeRule(frame, art, extent)
    frame.themeRuleOn = art.rule ~= nil
    if not frame.themeRuleOn then return end
    placeRuleOn(frame.themeRule, frame, art, extent)
    placeRuleOn(frame.themeBlockRule, frame.unitBox or frame, art, extent)
end

-- The wedge texture is square with a thin slanted piece in its left part:
-- that part only, as wide as the title row is high, makes a bold wedge
-- (the whole texture read as a stray stroke).
-- Drawn h wide, its right edge runs from 0.98 h (top) to 0.62 h (bottom);
-- the text starts Lib.TITLE_GAP past it at the text's mid-height, as in
-- every Forever addon (LibForeverThemes).
local function wedgeHeight(frame)
    if frame.themeOf or not frame.titleHeight then return 0 end
    local art = ns.Themes.Spec(Config.Get("general", "theme")).art
    return art and art.wedge and frame.titleHeight or 0
end

-- How far the title text moves right (beyond its usual 4) to clear the
-- title wedge.
function ThemeArt.TitleIndent(frame)
    local h = wedgeHeight(frame)
    return h > 0 and Lib.WedgeReach(h, h / 2) + Lib.TITLE_GAP - 4 or 0
end

-- The title row as a strip of its own colour and the wedge at its start.
-- Health.Style painted the row before (elements style in order).
local function placeTitle(frame, id, art)
    local wedge = frame.themeWedge
    local width = wedgeHeight(frame)
    if art.strip then
        local c = art.strip
        frame.title:SetTexture(WHITE)
        frame.title:SetVertexColor(c[1], c[2], c[3], c[4])
    end
    wedge:SetShown(width > 0 and frame.titleHeight > 0)
    if not wedge:IsShown() then return end
    wedge:ClearAllPoints()
    wedge:SetPoint("TOPLEFT", frame.title, "TOPLEFT", 0, 0)
    wedge:SetPoint("BOTTOMLEFT", frame.title, "BOTTOMLEFT", 0, 0)
    wedge:SetWidth(width)
    wedge:SetTexture(Lib.Texture(art.wedge))
    wedge:SetTexCoord(0, Lib.WEDGE_PART, 0, 1)
    local c = ns.Themes.Accent(id, "wedge") or art.wedgeColor
    wedge:SetVertexColor(c[1], c[2], c[3], c[4])
end

function ThemeArt.Style(frame)
    local scope = frame.key
    placeBack(frame, ns.Border.Padding(scope), ns.Corners.Clamp(ns.Corners.Radius(scope), ns.Single.Size(scope)))
    -- A raid cell names its own theme and shows only the backdrop.
    if frame.themeOf then
        local cell = ns.Themes.Spec(frame.themeOf())
        ThemeArt.Paint(frame.themeBack, cell)
        ThemeArt.Paint(frame.themeBlockBack, cell)
        frame.themeBackOn = frame.themeBack:IsShown()
        frame.themeShadowOn, frame.themeOrnamentsOn, frame.themeRuleOn = false, nil, false
        frame.themeFrameOn = false
        frame.themeWedge:Hide()
        ThemeArt.Refresh(frame, false)
        return
    end
    local id = Config.Get("general", "theme")
    local spec = ns.Themes.Spec(id)
    local art = spec.art or {}
    local extent = ns.Border.Extent(scope)
    -- Apart (spacing*), backdrop and shadow are each part's own
    -- (Elements/Boxes.lua): the gaps show nothing. Filled (spacingFill),
    -- the frame's backdrop lies over the plate instead of the parts' own.
    local apart = ns.Shape.Apart(frame)
    local filled = apart and Config.Get(scope, "spacingFill")
    ThemeArt.Paint(frame.themeBack, spec)
    ThemeArt.Paint(frame.themeBlockBack, spec)
    frame.themeBackOn = frame.themeBack:IsShown() and (not apart or filled)
    -- Apart, the parts have no common ring to frame.
    local framed = placeFrame(frame, art, apart and 0 or extent)
    -- On a frame, the ornaments sit on its outer corners.
    placeOrnaments(frame, id, art, extent + framed)
    placeRule(frame, art, extent)
    placeShadow(frame, art, extent, apart)
    placeTitle(frame, id, art)
end

function ThemeArt.Update() end

-- A window's title banner (with bannerEnd: its ends a swallowtail; Goblin:
-- warning stripes) under theme id, along owner's top, made on first use.
-- The swallowtail banner is height high, the title on it; the stripes
-- only STRIPE_H high, in the window's padding (text on them is
-- unreadable), and only where stripes is true. Returns the banner ends'
-- width (the title moves in by it), 0 for stripes, nil for none.
-- Never 0 high: SetHeight(0) draws a texture at its file's height in game.
local STRIPE_H, BANNER_END = 5, 0.5
function ThemeArt.Banner(owner, id, height, stripes)
    local art = ns.Themes.Spec(id).art
    local tiled = art and art.banner and art.bannerTile == true
    local shown = art and art.banner and height > 0 and (stripes or not tiled)
    local b = owner.themeBanner
    if not shown then
        if b then
            b.band:Hide()
            for _, e in ipairs(b.ends) do e:Hide() end
        end
        return nil
    end
    if not b then
        b = { band = owner:CreateTexture(nil, "BORDER"), ends = {} }
        for i = 1, 2 do b.ends[i] = owner:CreateTexture(nil, "BORDER") end
        owner.themeBanner = b
    end
    local h = tiled and STRIPE_H or height
    local w = (not tiled and art.bannerEnd) and math.floor(h * BANNER_END + 0.5) or 0
    for i, e in ipairs(b.ends) do
        e:SetShown(w > 0)
        if w > 0 then
            local point = i == 1 and "TOPLEFT" or "TOPRIGHT"
            e:ClearAllPoints()
            e:SetPoint(point, owner, point, 0, 0)
            e:SetSize(w, h)
            e:SetTexture(Lib.Texture(art.bannerEnd))
            -- The right end mirrored.
            if i == 1 then e:SetTexCoord(0, 1, 0, 1) else e:SetTexCoord(1, 0, 0, 1) end
        end
    end
    local band = b.band
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", owner, "TOPLEFT", w, 0)
    band:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -w, 0)
    band:SetHeight(h)
    band:SetTexture(Lib.Texture(art.banner), tiled and "REPEAT" or nil, tiled and "REPEAT" or nil)
    band:SetHorizTile(tiled)
    band:SetVertTile(tiled)
    band:Show()
    return w
end

ns.RegisterElement(ThemeArt)
