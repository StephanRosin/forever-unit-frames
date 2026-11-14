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
local PATH = "Interface\\AddOns\\ForeverUnitFrames\\Media\\Themes\\"
-- Texture coordinates of a top-left ornament for each corner
-- (Corners.POINTS order): mirrored, never rotated.
local MIRROR = { { 0, 1, 0, 1 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 1, 0, 1, 0 } }
local SHADOW_COLOR = { 0, 0, 0, 1 }

-- The backdrop on a texture: tiled, tinted; hidden without one.
function ThemeArt.Paint(texture, spec)
    local art = spec.art
    if not art or not art.back then
        texture:Hide()
        return
    end
    texture:SetTexture(PATH .. ns.Themes.Back(spec), "REPEAT", "REPEAT")
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
end

local function placeShadowAround(shadow, box, offset, extent)
    shadow:ClearAllPoints()
    shadow:SetPoint("TOPLEFT", box, "TOPLEFT", offset - extent, extent - offset)
    shadow:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", offset + extent, -offset - extent)
    shadow:SetColorTexture(SHADOW_COLOR[1], SHADOW_COLOR[2], SHADOW_COLOR[3], SHADOW_COLOR[4])
end

local function placeShadow(frame, art, extent)
    frame.themeShadowOn = art.hardShadow ~= nil
    if frame.themeShadowOn then
        placeShadowAround(frame.themeShadow, frame, art.hardShadow, extent)
        placeShadowAround(frame.themeBlockShadow, frame.unitBox or frame, art.hardShadow, extent)
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
    local wanted = frame.themeOrnamentsOn or {}
    for i = 1, 4 do
        frame.themeOrnaments[i]:SetShown(wanted[i] == true and not joined)
        frame.themeBlockOrnaments[i]:SetShown(wanted[i] == true and joined)
    end
end

-- The backdrop out to the ring's inner edge.
local function placeBackAround(back, clip, box, padding, radius)
    back:ClearAllPoints()
    back:SetPoint("TOPLEFT", box, "TOPLEFT", -padding, padding)
    back:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", padding, -padding)
    ns.Corners.Fit(clip, back, radius > 0 and radius + padding or 0)
end
local function placeBack(frame, padding, radius)
    placeBackAround(frame.themeBack, frame.themeClip, frame, padding, radius)
    placeBackAround(frame.themeBlockBack, frame.themeBlockClip, frame.unitBox or frame, padding, radius)
end

-- Ornaments sit at the ring's outer corners, art.ornamentInset inwards
-- (negative: outwards).
local function placeOrnamentSet(pieces, box, art, wanted, extent)
    local size, inset = art.ornamentSize or 12, (art.ornamentInset or 0) - extent
    local c = art.ornamentColor or { 1, 1, 1, 1 }
    for i, piece in ipairs(pieces) do
        if wanted[i] then
            local point = ns.Corners.POINTS[i]
            local dx = (i == 1 or i == 3) and inset or -inset
            local dy = (i <= 2) and -inset or inset
            piece:ClearAllPoints()
            piece:SetPoint(point, box, point, dx, dy)
            piece:SetSize(size, size)
            piece:SetTexture(PATH .. art.ornament)
            piece:SetTexCoord(unpack(MIRROR[i]))
            piece:SetVertexColor(c[1], c[2], c[3], c[4])
        end
    end
end

local function placeOrnaments(frame, art, extent)
    local wanted = {}
    for _, i in ipairs(art.ornament and art.corners or {}) do wanted[i] = true end
    frame.themeOrnamentsOn = wanted
    placeOrnamentSet(frame.themeOrnaments, frame, art, wanted, extent)
    placeOrnamentSet(frame.themeBlockOrnaments, frame.unitBox or frame, art, wanted, extent)
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
        frame.themeShadowOn, frame.themeOrnamentsOn = false, nil
        ThemeArt.Refresh(frame, false)
        return
    end
    local spec = ns.Themes.Spec(Config.Get("general", "theme"))
    local art = spec.art or {}
    local extent = ns.Border.Extent(scope)
    ThemeArt.Paint(frame.themeBack, spec)
    ThemeArt.Paint(frame.themeBlockBack, spec)
    frame.themeBackOn = frame.themeBack:IsShown()
    placeOrnaments(frame, art, extent)
    placeShadow(frame, art, extent)
end

function ThemeArt.Update() end

ns.RegisterElement(ThemeArt)
