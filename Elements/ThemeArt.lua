local _, ns = ...

-- The theme's art beyond settings (Core/Themes.lua): a tiled backdrop
-- under the bars and the title row, corner ornaments on the border and a
-- solid shadow behind it. Only plain textures, placed out of combat with
-- everything else (Style); nothing here is clickable, so auras and texts
-- placed around the frame stay where they are. Built before Shape, so the
-- backdrop is rounded with the frame (ns.Corners.Add).
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
    texture:SetTexture(PATH .. art.back, "REPEAT", "REPEAT")
    texture:SetHorizTile(true)
    texture:SetVertTile(true)
    local tint = art.tint or { 1, 1, 1, 1 }
    texture:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
    texture:Show()
end

function ThemeArt.Build(frame)
    frame.themeBack = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.themeBack:SetAllPoints(frame)
    frame.themeBack:Hide()
    ns.Corners.Add(frame, frame.themeBack)
    -- Below the frame's own level: the shadow lies under the border.
    frame.themeUnder = CreateFrame("Frame", nil, frame)
    frame.themeUnder:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    frame.themeShadow = frame.themeUnder:CreateTexture(nil, "BACKGROUND")
    frame.themeShadow:Hide()
    -- Above the border rings and the texts' overlay.
    frame.themeOver = CreateFrame("Frame", nil, frame)
    frame.themeOver:SetAllPoints(frame)
    frame.themeOver:SetFrameLevel(frame:GetFrameLevel() + 12)
    frame.themeOrnaments = {}
    for i = 1, 4 do
        frame.themeOrnaments[i] = frame.themeOver:CreateTexture(nil, "OVERLAY")
        frame.themeOrnaments[i]:Hide()
    end
end

local function placeShadow(frame, art, extent)
    local shadow, offset = frame.themeShadow, art.hardShadow
    if not offset then
        shadow:Hide()
        return
    end
    shadow:ClearAllPoints()
    shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", offset - extent, extent - offset)
    shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset + extent, -offset - extent)
    shadow:SetColorTexture(SHADOW_COLOR[1], SHADOW_COLOR[2], SHADOW_COLOR[3], SHADOW_COLOR[4])
    shadow:Show()
end

local function placeOrnaments(frame, art)
    local wanted = {}
    for _, i in ipairs(art.ornament and art.corners or {}) do wanted[i] = true end
    local size, inset = art.ornamentSize or 12, art.ornamentInset or 0
    local c = art.ornamentColor or { 1, 1, 1, 1 }
    for i, piece in ipairs(frame.themeOrnaments) do
        if wanted[i] then
            local point = ns.Corners.POINTS[i]
            local dx = (i == 1 or i == 3) and inset or -inset
            local dy = (i <= 2) and -inset or inset
            piece:ClearAllPoints()
            piece:SetPoint(point, frame, point, dx, dy)
            piece:SetSize(size, size)
            piece:SetTexture(PATH .. art.ornament)
            piece:SetTexCoord(unpack(MIRROR[i]))
            piece:SetVertexColor(c[1], c[2], c[3], c[4])
            piece:Show()
        else
            piece:Hide()
        end
    end
end

function ThemeArt.Style(frame)
    -- A raid cell names its own theme and shows only the backdrop.
    if frame.themeOf then
        ThemeArt.Paint(frame.themeBack, ns.Themes.Spec(frame.themeOf()))
        frame.themeShadow:Hide()
        for _, piece in ipairs(frame.themeOrnaments) do piece:Hide() end
        return
    end
    local spec = ns.Themes.Spec(Config.Get("general", "theme"))
    local art = spec.art or {}
    ThemeArt.Paint(frame.themeBack, spec)
    placeShadow(frame, art, ns.Border.Extent(frame.key))
    placeOrnaments(frame, art)
end

function ThemeArt.Update() end

ns.RegisterElement(ThemeArt)
