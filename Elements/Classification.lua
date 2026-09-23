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
-- (Blizzard_NamePlateClassificationFrame.lua). Blizzard marks bosses with
-- the elite badge too; here a boss gets the target frame's high-level
-- icon (Blizzard_UnitFrame/Mainline/TargetFrame.xml), the elite badge if
-- the client lacks it.
Classification.MARKERS = {
    boss = { atlas = "UI-HUD-UnitFrame-Target-HighLevelTarget_Icon", fallback = "nameplates-icon-elite-gold",
        color = GOLD },
    elite = { atlas = "nameplates-icon-elite-gold", color = GOLD },
    rareelite = { atlas = "nameplates-icon-elite-silver", color = SILVER },
    rare = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star", color = SILVER },
}
-- Test mode shows this one.
Classification.SAMPLE = "rareelite"
-- The marker's layer above the unit frame: over aura icons that overlap
-- the frame (holders at + Auras.LEVELS, their buttons' parts up to three
-- above), below the class badge (+ 20).
Classification.LEVELS = 16

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

-- Whether the client knows an atlas. Atlases do not change while the game
-- runs: asked once per name. Without the lookup, trusted.
local known = {}
local function atlasKnown(atlas)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return true end
    local k = known[atlas]
    if k == nil then
        k = C_Texture.GetAtlasInfo(atlas) ~= nil
        known[atlas] = k
    end
    return k
end

-- The atlas to draw for a marker, or nil when the client has none.
local function atlasOf(marker)
    if atlasKnown(marker.atlas) then return marker.atlas end
    if marker.fallback and atlasKnown(marker.fallback) then return marker.fallback end
    return nil
end

local function badgeShown(frame)
    return frame.classIcon ~= nil and frame.classIcon:IsShown() and frame.classBadgeBox ~= nil
end

-- Whether the class badge overlaps the span left..right, bottom..top.
-- Everything is measured from the frame's top right corner.
local function hitsBadge(frame, left, right, bottom, top)
    if not badgeShown(frame) then return false end
    local b = frame.classBadgeBox
    return left < b.right and b.left < right and bottom < b.top and b.bottom < top
end

-- The portrait badge: on the portrait's outer top corner, sticking out by
-- a third of its size; on the inner one when the class badge covers the
-- outer. Under a castbar docked on top it does not reach up into it.
local function placeIcon(frame)
    local scope, Pixel = frame.key, ns.Pixel
    local portrait = Config.Get(scope, "portraitMode")
    if portrait == "OFF" then return end
    local size = Pixel.Snap(math.max(10, Config.Get(scope, "height") * 0.45))
    local out = Pixel.Snap(size / 3)
    local up = ns.Shape.DockReach(frame) == "ABOVE" and 0 or out
    local width, height = ns.Single.Size(scope)
    local left = portrait == "LEFT"
    -- The portrait's left and right edges.
    local pLeft = left and -width or -height
    local pRight = left and -width + height or 0
    local outerX = left and pLeft - out or pRight + out - size
    local inner = hitsBadge(frame, outerX, outerX + size, up - size, up)
    -- Outer corner: the portrait's own side; inner: the other one.
    local onLeft = left
    if inner then onLeft = not left end
    local point = onLeft and "TOPLEFT" or "TOPRIGHT"
    local icon = frame.eliteIcon
    icon:ClearAllPoints()
    icon:SetPoint(point, frame.portraitBg, point, onLeft and -out or out, up)
    icon:SetSize(size, size)
end

-- The word: above the frame's top right corner, and above a castbar
-- docked on top, clear of the border; left of the class badge when that
-- reaches over the spot. All in the frame's coordinates.
local function placeText(frame)
    local scope, text, Pixel = frame.key, frame.eliteText, ns.Pixel
    local side, reach = ns.Shape.DockReach(frame)
    local bottom = (side == "ABOVE" and reach or 0) + ns.Border.Extent(scope) + Pixel.One()
    local x = 0
    if hitsBadge(frame, -math.huge, 0, bottom, bottom + Classification.FontSize(scope)) then
        x = math.min(0, frame.classBadgeBox.left - Pixel.Snap(BADGE_GAP))
    end
    text:ClearAllPoints()
    text:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", x, bottom)
    text:SetJustifyH("RIGHT")
end

-- Shows the marker for kind (nil: none) in the frame's current style.
-- Unchanged kind and class badge: nothing to do (the target of target
-- asks every few frames). force: after a restyle.
local function show(frame, kind, force)
    local badge = badgeShown(frame)
    if not force and frame.eliteDrawn and kind == frame.eliteKind and badge == frame.eliteBadge then return end
    frame.eliteKind, frame.eliteBadge, frame.eliteDrawn = kind, badge, true
    local marker = Classification.MARKERS[kind or ""]
    local mode = frame.eliteMode
    local atlas = marker and mode == "ICON" and atlasOf(marker)
    -- A badge the client lacks falls back to the word.
    if mode == "ICON" and not atlas then mode = "TEXT" end
    local icon, text = frame.eliteIcon, frame.eliteText
    icon:SetShown(marker ~= nil and mode == "ICON")
    text:SetShown(marker ~= nil and mode == "TEXT")
    if not marker then return end
    if mode == "ICON" then
        placeIcon(frame)
        icon:SetAtlas(atlas)
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
    local layer = CreateFrame("Frame", nil, frame)
    layer:SetAllPoints(frame)
    frame.eliteLayer = layer
    frame.eliteIcon = layer:CreateTexture(nil, "OVERLAY")
    frame.eliteText = layer:CreateFontString(nil, "OVERLAY")
    frame.eliteText:SetFont(ns.Media.Font(nil), 10, "")
    frame.eliteIcon:Hide()
    frame.eliteText:Hide()
end

function Classification.Style(frame)
    if not frame.eliteIcon then return end
    local scope = frame.key
    frame.eliteLayer:SetFrameLevel(frame:GetFrameLevel() + Classification.LEVELS)
    if not Config.Get(scope, "eliteMarker") then
        frame.eliteMode = nil
    elseif Config.Get(scope, "portraitMode") == "OFF" then
        frame.eliteMode = "TEXT"
    else
        frame.eliteMode = "ICON"
    end
    local text = frame.eliteText
    ns.Texts.SetFont(text, ns.Media.Font(Config.Get(scope, "fontFace")), Classification.FontSize(scope),
        Config.Get(scope, "fontOutline"))
    local shadow = Config.Get(scope, "fontShadow")
    text:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
    show(frame, frame.eliteKind, true)
end

function Classification.Update(frame)
    if not frame.eliteIcon or frame.eliteIcon.preview then return end
    show(frame, Classification.Kind(frame.unit))
end

function Classification.Preview(frame, on)
    if not frame.eliteIcon then return end
    frame.eliteIcon.preview = on or nil
    show(frame, on and Classification.SAMPLE or nil, true)
end

ns.RegisterElement(Classification)
