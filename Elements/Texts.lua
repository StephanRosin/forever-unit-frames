local _, ns = ...

local Texts = {
    name = "Texts",
    unitEvents = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
        "UNIT_NAME_UPDATE", "UNIT_LEVEL" },
}
ns.Texts = Texts

local Config, Secrets = ns.Config, ns.Secrets

-- bar: the row the text sits on; kind: whose values it shows (health or
-- power, default the bar).
local SLOTS = {
    { field = "title", setting = "titleText", bar = "title", kind = "health", point = "LEFT", x = 4 },
    { field = "healthLeft", setting = "textHealthLeft", bar = "health", point = "LEFT", x = 4, before = "healthRight" },
    { field = "healthRight", setting = "textHealthRight", bar = "health", point = "RIGHT", x = -4 },
    { field = "powerLeft", setting = "textPowerLeft", bar = "power", point = "LEFT", x = 4, before = "powerRight" },
    { field = "powerRight", setting = "textPowerRight", bar = "power", point = "RIGHT", x = -4 },
}

local function levelText(unit)
    local level = Secrets.Number(UnitLevel(unit))
    if not level then return "" end
    if level <= 0 then return "??" end
    return tostring(level)
end

-- Values: health or power, depending on the bar the slot sits on.
local function current(unit, kind)
    if kind == "health" then return UnitHealth(unit) end
    return UnitPower(unit)
end
local function maximum(unit, kind)
    if kind == "health" then return UnitHealthMax(unit) end
    return UnitPowerMax(unit)
end

-- Unit names. UnitName returns the first name and, when the unit has one,
-- the secondary name (surname); with regional unique names the first value
-- may itself be "First<separator>Surname". Names can be secret: they are
-- only passed to the font string, never joined, matched or compared.
local function separator()
    local consts = Constants and Constants.CharacterNameSeparatorConsts
    local sep = consts and consts.CHARACTERNAME_SURNAME_SEPARATOR
    if type(sep) == "string" and sep ~= "" then return sep end
    return " "
end

-- Whether the first value may hold "First<separator>Surname": only for
-- players, and only with regional unique names, as Blizzard's
-- NameUtil.GetUnitFirstName. NPC names with spaces are never split.
local function mayHoldSurname(unit)
    if type(RegionalUniqueNamesEnabled) ~= "function" then return false end
    if Secrets.Bool(RegionalUniqueNamesEnabled) ~= true then return false end
    return Secrets.Bool(UnitIsPlayer, unit) == true
end

-- The part before the separator of a readable name. A secret name is
-- returned whole: it cannot be split, so it shows with its surname.
local function firstName(name)
    if Secrets.IsSecret(name) or type(name) ~= "string" then return name end
    local at = string.find(name, separator(), 1, true)
    if at and at > 1 then return string.sub(name, 1, at - 1) end
    return name
end

-- Writes the unit's name into fs, after `prefix` (the level) if given.
-- Every text that shows a name goes through here; soft-outline copies
-- follow through the mirrored setters. Off: a surname returned apart is
-- simply left out; one inside the first value is cut off (see above).
function Texts.SetName(fs, unit, showSurname, prefix)
    local name, surname = UnitName(unit)
    local hasSurname = type(surname) ~= "nil"
    if showSurname and hasSurname then
        if prefix then
            fs:SetFormattedText("%s %s %s", prefix, name, surname)
        else
            fs:SetFormattedText("%s %s", name, surname)
        end
        return
    end
    if not showSurname and not hasSurname and mayHoldSurname(unit) then name = firstName(name) end
    if prefix then
        fs:SetFormattedText("%s %s", prefix, name)
    else
        fs:SetText(name)
    end
end

function Texts.Apply(fs, tag, unit, kind, showSurname)
    if tag == "NONE" then
        fs:SetText("")
    elseif tag == "NAME" then
        Texts.SetName(fs, unit, showSurname)
    elseif tag == "NAME_LEVEL" then
        Texts.SetName(fs, unit, showSurname, levelText(unit))
    elseif tag == "LEVEL" then
        fs:SetText(levelText(unit))
    elseif tag == "CURRENT" then
        fs:SetText(Secrets.Abbreviate(current(unit, kind)))
    elseif tag == "CURRENT_MAX" then
        fs:SetFormattedText("%s / %s", Secrets.Abbreviate(current(unit, kind)), Secrets.Abbreviate(maximum(unit, kind)))
    elseif tag == "PERCENT" then
        local pct
        if kind == "health" then
            pct = UnitHealthPercent(unit, true, Secrets.PercentCurve())
        else
            pct = UnitPowerPercent(unit, nil, false, Secrets.PercentCurve())
        end
        fs:SetFormattedText("%.0f%%", pct)
    elseif tag == "DEFICIT" then
        if kind == "health" then
            fs:SetText(C_StringUtil.TruncateWhenZero(UnitHealthMissing(unit)))
        else
            fs:SetText(C_StringUtil.TruncateWhenZero(UnitPowerMissing(unit)))
        end
    else
        fs:SetText("")
    end
end

-- Soft outline. The client only has OUTLINE and THICKOUTLINE, both hard
-- at small sizes. SOFT draws the text without a flag over four black
-- copies of itself, shifted one physical pixel left, right, up and down.
-- The copies are made once per text, the first time it is styled SOFT,
-- and follow every write, secret or not: arguments are passed on
-- untouched.
local SOFT_OFFSETS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local MIRRORED = { "SetText", "SetFormattedText", "SetJustifyH", "SetWordWrap" }

local function mirror(fs, method)
    local original = fs[method]
    fs[method] = function(self, ...)
        original(self, ...)
        for _, copy in ipairs(self.softCopies) do copy[method](copy, ...) end
    end
end

local function showCopies(fs)
    local shown = fs.soft and fs:IsShown()
    for _, copy in ipairs(fs.softCopies) do copy:SetShown(shown) end
end

local function follow(fs, method)
    local original = fs[method]
    fs[method] = function(self, ...)
        original(self, ...)
        showCopies(self)
    end
end

local function makeCopies(fs)
    local parent = fs:GetParent()
    local layer, sublevel = fs:GetDrawLayer()
    local copies = {}
    for i = 1, #SOFT_OFFSETS do
        local copy = parent:CreateFontString(nil, layer)
        copy:SetDrawLayer(layer, math.max(sublevel - 1, -8))
        local path, size = fs:GetFont()
        copy:SetFont(path, size, "")
        copy:SetTextColor(0, 0, 0, 1)
        copy:SetShadowOffset(0, 0)
        copy:SetText(fs:GetText())
        copies[i] = copy
    end
    fs.softCopies = copies
    for _, method in ipairs(MIRRORED) do mirror(fs, method) end
    for _, method in ipairs({ "SetShown", "Show", "Hide" }) do follow(fs, method) end
end

-- Sets font, size and outline style of a text. Returns nothing.
function Texts.SetFont(fs, font, size, outline)
    local soft = outline == "SOFT"
    local flags = (outline == "NONE" or soft) and "" or outline
    fs:SetFont(font, size, flags)
    if soft and not fs.softCopies then makeCopies(fs) end
    if not fs.softCopies then return end
    fs.soft = soft
    -- Exactly one physical pixel: thinner than the client's OUTLINE.
    -- Recomputed on every restyle, which a UI scale or window size change
    -- triggers too.
    local step = ns.Pixel.One(fs)
    for i, copy in ipairs(fs.softCopies) do
        local x, y = SOFT_OFFSETS[i][1] * step, SOFT_OFFSETS[i][2] * step
        copy:SetFont(font, size, "")
        copy:ClearAllPoints()
        copy:SetPoint("TOPLEFT", fs, "TOPLEFT", x, y)
        copy:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", x, y)
    end
    showCopies(fs)
end

-- Class icon: a round badge on the frame's top right corner. Blizzard's
-- own class icons are
-- the atlases "classicon-<class>" (GetClassAtlas, lower-cased by the
-- character creation screen of this game type); when the client has no
-- such atlas, the class sheet with CLASS_ICON_TCOORDS, as Blizzard's
-- raid and community lists use it.
local CLASS_SHEET = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

-- The class token of a player unit, or nil: not a player, or the class
-- unknown or secret (identity can be restricted). A secret token is never
-- used as an index or an atlas name.
local function classToken(unit)
    if Secrets.Bool(UnitIsPlayer, unit) ~= true then return nil end
    local ok, _, token = pcall(UnitClass, unit)
    if not ok or Secrets.IsSecret(token) or type(token) ~= "string" then return nil end
    return token
end

-- Draws token's icon into tex. Returns false when there is none.
local function drawClassIcon(tex, token)
    local atlas = "classicon-" .. string.lower(token)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        tex:SetAtlas(atlas)
        tex:SetTexCoord(0, 1, 0, 1)
        return true
    end
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token]
    if not coords then return false end
    tex:SetTexture(CLASS_SHEET)
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    return true
end

local function classIconWanted(frame)
    return frame.titleHeight > 0 and Config.Get(frame.key, "titleClassIcon") == true
end

-- Round, as Blizzard's portrait icons: the circular alpha mask, clamped.
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- The badge's frame level above the unit frame: over the bars, their
-- texts and the border (textures of the frame itself).
local BADGE_LEVELS = 20

-- Ring thickness on the pixel grid: at least one pixel unless it is off.
local function ringSize(scope)
    local size = Config.Get(scope, "classIconRing")
    if size <= 0 then return 0 end
    return ns.Pixel.Snap(size, nil, 1)
end

local function makeRound(badge, tex)
    local mask = badge:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
end

local function showClassIcon(frame, shown)
    frame.classIcon:SetShown(shown)
    frame.classRing:SetShown(shown and frame.classRingSize > 0)
end

-- The title text ends before the badge when it shows and its left edge
-- lies within the title row, else at the row's right edge. No measuring:
-- the text may be secret; the badge's place is plain numbers. The
-- vertical offset keeps the text centred on the row.
local function placeTitleEnd(frame)
    local title = frame.texts.title
    if frame.classIcon:IsShown() and frame.classBadgeInRow then
        title:SetPoint("RIGHT", frame.classBadge, "LEFT", ns.Pixel.Snap(-2, title),
            -frame.titleHeight / 2 - frame.classBadgeY)
    else
        title:SetPoint("RIGHT", frame.title, "RIGHT", ns.Pixel.Snap(-4, title), 0)
    end
end

local function updateClassIcon(frame)
    local token = classIconWanted(frame) and classToken(frame.unit)
    showClassIcon(frame, token and drawClassIcon(frame.classIcon, token) or false)
    placeTitleEnd(frame)
end

-- Size, ring and place of the badge, on the pixel grid. Its centre sits
-- at the configured offset from the frame's top right corner.
local function styleBadge(frame)
    local scope, Pixel = frame.key, ns.Pixel
    local badge = frame.classBadge
    local size = Pixel.Snap(Config.Get(scope, "classIconSize"), nil, 1)
    local ring = ringSize(scope)
    local x = Pixel.Centre(Config.Get(scope, "classIconX"), size)
    local y = Pixel.Centre(Config.Get(scope, "classIconY"), size)
    badge:SetFrameLevel(frame:GetFrameLevel() + BADGE_LEVELS)
    badge:SetSize(size, size)
    badge:ClearAllPoints()
    badge:SetPoint("CENTER", frame, "TOPRIGHT", x, y)
    local c = Config.Get(scope, "classIconRingColor")
    frame.classRing:SetColorTexture(c[1], c[2], c[3], c[4])
    frame.classRingSize = ring
    frame.classIcon:SetSize(size - 2 * ring, size - 2 * ring)
    -- Edges relative to the frame's right edge.
    local width = ns.Single.Size(scope)
    local left = x - size / 2
    frame.classBadgeInRow = left < -frame.titleRight and left > frame.titleLeft - width
    frame.classBadgeY = y
    -- The badge's box from the frame's top right corner, for what must
    -- stay clear of it (Elements/Classification.lua).
    local half = size / 2
    frame.classBadgeBox = { left = left, right = x + half, bottom = y - half, top = y + half }
end

function Texts.Build(frame)
    -- Its own frame so it draws above the bars; a child of the unit frame
    -- so it hides with it.
    local badge = CreateFrame("Frame", nil, frame)
    frame.classBadge = badge
    frame.classRing = badge:CreateTexture(nil, "ARTWORK", nil, 0)
    frame.classRing:SetAllPoints(badge)
    frame.classIcon = badge:CreateTexture(nil, "ARTWORK", nil, 1)
    frame.classIcon:SetPoint("CENTER", badge, "CENTER", 0, 0)
    makeRound(badge, frame.classRing)
    makeRound(badge, frame.classIcon)
    frame.classRingSize = 0
    showClassIcon(frame, false)
    frame.texts = {}
    for _, slot in ipairs(SLOTS) do
        -- Title and health texts sit on the overlay, above shields and
        -- heals; power texts on their bar, so they hide with it.
        local parent = slot.bar == "power" and frame.power or frame.overlay
        frame.texts[slot.field] = parent:CreateFontString(nil, "OVERLAY")
    end
end

function Texts.Style(frame)
    local scope = frame.key
    local font = ns.Media.Font(Config.Get(scope, "fontFace"))
    local size = Config.Get(scope, "fontSize")
    local outline = Config.Get(scope, "fontOutline")
    local shadow = Config.Get(scope, "fontShadow")
    for _, slot in ipairs(SLOTS) do
        local fs = frame.texts[slot.field]
        Texts.SetFont(fs, font, size, outline)
        fs:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
        fs:ClearAllPoints()
        fs:SetPoint(slot.point, frame[slot.bar], slot.point, ns.Pixel.Snap(slot.x, fs), 0)
        if slot.before then
            -- A left text ends where the right one begins (an empty right
            -- text is zero wide), so the two never overlap on a narrow
            -- bar. No measuring: the text may be secret.
            fs:SetPoint("RIGHT", frame.texts[slot.before], "LEFT", ns.Pixel.Snap(-4, fs), 0)
            fs:SetWordWrap(false)
        end
        fs:SetJustifyH(slot.point)
    end
    local title = frame.texts.title
    title:SetWordWrap(false)
    title:SetShown(frame.titleHeight > 0)
    styleBadge(frame)
    if not classIconWanted(frame) then
        showClassIcon(frame, false)
    else
        -- The ring may have been switched on or off with the border.
        showClassIcon(frame, frame.classIcon:IsShown())
    end
    placeTitleEnd(frame)
end

-- Title text colour: class (players) or reaction, or plain white.
local function paintTitle(frame)
    local mode = Config.Get(frame.key, "titleColorMode")
    local r, g, b = 1, 1, 1
    if mode ~= "WHITE" then r, g, b = ns.Health.UnitColor(frame.unit, mode) end
    frame.texts.title:SetTextColor(r, g, b, 1)
end

function Texts.Update(frame)
    local showSurname = Config.Get(frame.key, "showSurname")
    for _, slot in ipairs(SLOTS) do
        Texts.Apply(frame.texts[slot.field], Config.Get(frame.key, slot.setting), frame.unit, slot.kind or slot.bar,
            showSurname)
    end
    paintTitle(frame)
    updateClassIcon(frame)
end

ns.RegisterElement(Texts)
