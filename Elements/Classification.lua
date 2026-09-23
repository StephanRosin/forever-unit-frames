local _, ns = ...

-- Elite / rare / boss marker. With a portrait: Blizzard's nameplate badge
-- on the portrait's outer top corner. Without: a short word above the
-- frame's top right corner. UnitClassification is not documented as
-- secret; it is still only compared when it is a plain string.
--
-- The class badge (Elements/Texts.lua) also sits on the top right corner,
-- for players. Where it shows and would cover the marker, the marker
-- moves: the word ends left of the badge, the portrait badge goes to the
-- portrait's inner top corner. Both geometries are plain numbers.
local Classification = { name = "Classification", unitEvents = { "UNIT_CLASSIFICATION_CHANGED" } }
ns.Classification = Classification

local Config, Secrets, Settings, L = ns.Config, ns.Secrets, ns.Settings, ns.L

local GOLD, SILVER = { 1, 0.82, 0 }, { 0.78, 0.8, 0.85 }
-- Atlas names as Blizzard's nameplates use them for every game type
-- (Blizzard_NamePlateClassificationFrame.lua).
Classification.MARKERS = {
    boss = { atlas = "nameplates-icon-elite-gold", color = GOLD },
    elite = { atlas = "nameplates-icon-elite-gold", color = GOLD },
    rareelite = { atlas = "nameplates-icon-elite-silver", color = SILVER },
    rare = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star", color = SILVER },
}
-- Test mode shows this one.
Classification.SAMPLE = "rareelite"

-- Gap between the word and the class badge, in pixels.
local BADGE_GAP = 2

function Classification.Applies(scope)
    return Settings.AppliesTo(Settings.Get("eliteMarker"), scope)
end

-- "boss", "elite", "rareelite", "rare" or nil.
function Classification.Kind(unit)
    if Secrets.Bool(UnitIsBossMob, unit) then return "boss" end
    local ok, c = pcall(UnitClassification, unit)
    if not ok or Secrets.IsSecret(c) or type(c) ~= "string" then return nil end
    if c == "worldboss" then return "boss" end
    if Classification.MARKERS[c] then return c end
    return nil
end

-- Whether the client knows the atlas; without the lookup, trust it.
local function atlasKnown(atlas)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return true end
    return C_Texture.GetAtlasInfo(atlas) ~= nil
end

-- The class badge's box (from the frame's top right corner) while it
-- shows, else nil.
local function badgeBox(frame)
    if not (frame.classIcon and frame.classIcon:IsShown()) then return nil end
    return frame.classBadgeBox
end

local function overlaps(a, b)
    return a.left < b.right and b.left < a.right and a.bottom < b.top and b.bottom < a.top
end

-- The portrait badge: on the portrait's outer top corner, sticking out by
-- a third of its size; on the inner one when the class badge covers the
-- outer. Boxes are relative to the frame's top right corner.
local function placeIcon(frame)
    local scope, Pixel = frame.key, ns.Pixel
    local portrait = Config.Get(scope, "portraitMode")
    if portrait == "OFF" then return end
    local size = Pixel.Snap(math.max(10, Config.Get(scope, "height") * 0.45))
    local out = Pixel.Snap(size / 3)
    local width, height = ns.Single.Size(scope)
    local left = portrait == "LEFT"
    -- The portrait's left and right edges.
    local pLeft = left and -width or -height
    local pRight = left and -width + height or 0
    local outerX = left and pLeft - out or pRight + out - size
    local box = { left = outerX, right = outerX + size, bottom = out - size, top = out }
    local badge = badgeBox(frame)
    local inner = badge ~= nil and overlaps(box, badge)
    -- Outer corner: the portrait's own side; inner: the other one.
    local onLeft = left
    if inner then onLeft = not left end
    local point = onLeft and "TOPLEFT" or "TOPRIGHT"
    local icon = frame.eliteIcon
    icon:ClearAllPoints()
    icon:SetPoint(point, frame.portraitBg, point, onLeft and -out or out, out)
    icon:SetSize(size, size)
end

-- The word: above the unit box's top right corner, clear of the border;
-- left of the class badge when that reaches over the spot.
local function placeText(frame)
    local scope, text, Pixel = frame.key, frame.eliteText, ns.Pixel
    local bottom = ns.Border.Extent(scope) + Pixel.One()
    local height = Classification.FontSize(scope)
    local x = 0
    local badge = badgeBox(frame)
    if badge and badge.left < 0 and badge.top > bottom and badge.bottom < bottom + height then
        x = math.min(0, badge.left - Pixel.Snap(BADGE_GAP))
    end
    text:ClearAllPoints()
    text:SetPoint("BOTTOMRIGHT", frame.unitBox, "TOPRIGHT", x, bottom)
    text:SetJustifyH("RIGHT")
end

-- Shows the marker for kind (nil: none) in the frame's current style.
local function show(frame, kind)
    frame.eliteKind = kind
    local marker = Classification.MARKERS[kind or ""]
    local mode = frame.eliteMode
    -- A badge the client lacks falls back to the word.
    if mode == "ICON" and marker and not atlasKnown(marker.atlas) then mode = "TEXT" end
    local icon, text = frame.eliteIcon, frame.eliteText
    icon:SetShown(marker ~= nil and mode == "ICON")
    text:SetShown(marker ~= nil and mode == "TEXT")
    if not marker then return end
    if mode == "ICON" then
        placeIcon(frame)
        icon:SetAtlas(marker.atlas)
    else
        placeText(frame)
    end
    text:SetText(L["CLASS_" .. kind])
    text:SetTextColor(marker.color[1], marker.color[2], marker.color[3], 1)
end

-- The word's font size: a little below the frame's.
function Classification.FontSize(scope)
    return math.max(Config.Get(scope, "fontSize") - 2, 6)
end

function Classification.Build(frame)
    if not Classification.Applies(frame.key) then return end
    -- On the overlay: above bars and a 3D portrait.
    frame.eliteIcon = frame.overlay:CreateTexture(nil, "OVERLAY")
    frame.eliteText = frame.overlay:CreateFontString(nil, "OVERLAY")
    frame.eliteText:SetFont(ns.Media.Font(nil), 10, "")
    frame.eliteIcon:Hide()
    frame.eliteText:Hide()
end

function Classification.Style(frame)
    if not frame.eliteIcon then return end
    local scope = frame.key
    if not Config.Get(scope, "eliteMarker") then
        frame.eliteMode = nil
    elseif Config.Get(scope, "portraitMode") == "OFF" then
        frame.eliteMode = "TEXT"
    else
        frame.eliteMode = "ICON"
    end
    local font = ns.Media.Font(Config.Get(scope, "fontFace"))
    ns.Texts.SetFont(frame.eliteText, font, Classification.FontSize(scope), Config.Get(scope, "fontOutline"))
    show(frame, frame.eliteKind)
end

function Classification.Update(frame)
    if not frame.eliteIcon or frame.eliteIcon.preview then return end
    show(frame, Classification.Kind(frame.unit))
end

function Classification.Preview(frame, on)
    if not frame.eliteIcon then return end
    frame.eliteIcon.preview = on or nil
    show(frame, on and Classification.SAMPLE or nil)
end

ns.RegisterElement(Classification)
