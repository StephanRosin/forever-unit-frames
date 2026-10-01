local _, ns = ...

local Texts = {
    name = "Texts",
    unitEvents = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
        "UNIT_NAME_UPDATE", "UNIT_LEVEL", "PLAYER_FLAGS_CHANGED" },
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

-- Difficulty colours against the player's level, as Blizzard's
-- (DifficultyUtil): red from 5 above, orange 3-4, yellow within 2, green
-- below, grey from the grey level on (no experience).
Texts.DIFFICULTY = {
    impossible = { 1, 0.1, 0.1 }, verydifficult = { 1, 0.5, 0.25 }, difficult = { 1, 0.82, 0 },
    standard = { 0.25, 0.75, 0.25 }, trivial = { 0.5, 0.5, 0.5 },
}

-- The highest level that is grey for a player of level p (Classic rule).
function Texts.GreyLevel(p)
    if p <= 5 then return 0 end
    if p <= 39 then return p - math.floor(p / 10) - 5 end
    if p <= 59 then return p - math.floor(p / 5) - 1 end
    return p - 9
end

-- r, g, b of a level (-1 or less: a boss, "??").
function Texts.DifficultyColor(level)
    local own = Secrets.Number(UnitLevel("player")) or level
    local d = Texts.DIFFICULTY
    local c
    if level <= 0 then
        c = d.impossible
    else
        local diff = level - own
        if diff >= 5 then c = d.impossible
        elseif diff >= 3 then c = d.verydifficult
        elseif diff >= -2 then c = d.difficult
        elseif level > Texts.GreyLevel(own) then c = d.standard
        else c = d.trivial end
    end
    return c[1], c[2], c[3]
end

-- The level as text; coloured: wrapped in its difficulty colour, so it
-- keeps it whatever colour the rest of the line has. A secret level is
-- left out, as before.
local function levelText(unit, colored)
    local level = Secrets.Number(UnitLevel(unit))
    if not level then return "" end
    local text = level <= 0 and "??" or tostring(level)
    if not colored then return text end
    local r, g, b = Texts.DifficultyColor(level)
    return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, text)
end

-- INFO: "60 Mage Gnome" for players, "60 Humanoid" for creatures. Class,
-- race and type may be secret: passed to the font string untouched,
-- presence asked with type(). A unit of unknown kind counts as a creature.
-- The colour code for the class part of INFO ("%s" around it when none):
-- a player's class colour, a creature's reaction colour, readable only.
local function infoWrap(unit, isPlayer, scope)
    local r, g, b
    if isPlayer then
        local ok, _, token = pcall(UnitClass, unit)
        local c = ok and not Secrets.IsSecret(token) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
        if c then r, g, b = c.r, c.g, c.b end
    else
        local c = ns.Health.ReactionColor(unit, scope)
        if c then r, g, b = c[1], c[2], c[3] end
    end
    if not r or Secrets.IsSecret(r) then return "%s" end
    return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255) .. "%s|r"
end

local function setInfo(fs, unit, opts)
    local level = levelText(unit, opts.levelColored)
    local isPlayer = Secrets.Bool(UnitIsPlayer, unit) == true
    local wrap = opts.infoColor and infoWrap(unit, isPlayer, opts.scope) or "%s"
    if isPlayer then
        local class = UnitClass(unit)
        local race = UnitRace(unit)
        if type(class) ~= "nil" and type(race) ~= "nil" then
            fs:SetFormattedText("%s " .. wrap .. " %s", level, class, race)
            return
        elseif type(class) ~= "nil" then
            fs:SetFormattedText("%s " .. wrap, level, class)
            return
        end
    else
        local kind = UnitCreatureType(unit)
        if type(kind) ~= "nil" then
            fs:SetFormattedText("%s " .. wrap, level, kind)
            return
        end
    end
    fs:SetText(level)
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

-- Test mode: health values that match the sample health bar
-- (Health.SAMPLE) on the scale of the unit's readable maximum, else on
-- SAMPLE_MAX. Plain numbers only; nil when the frame shows live health.
Texts.SAMPLE_MAX = 10000

local function sampleHealth(frame)
    if not frame.health.preview then return nil end
    local max = Secrets.Number(UnitHealthMax(frame.unit))
    if not max or max <= 0 then max = Texts.SAMPLE_MAX end
    local current = math.floor(max * ns.Health.SAMPLE + 0.5)
    return { current = current, max = max, missing = max - current, percent = ns.Health.SAMPLE * 100 }
end

-- The value tags drawn from sample numbers.
local function applySample(fs, tag, sample, compact)
    if tag == "CURRENT" then
        fs:SetText(Secrets.Abbreviate(sample.current))
    elseif tag == "CURRENT_MAX" then
        fs:SetFormattedText(compact and "%s/%s" or "%s / %s", Secrets.Abbreviate(sample.current),
            Secrets.Abbreviate(sample.max))
    elseif tag == "PERCENT" then
        fs:SetFormattedText("%.0f%%", sample.percent)
    else
        fs:SetText(C_StringUtil.TruncateWhenZero(sample.missing))
    end
end
local SAMPLE_TAGS = { CURRENT = true, CURRENT_MAX = true, PERCENT = true, DEFICIT = true }

-- sample (optional): plain health numbers that replace the unit's for
-- the value tags of health texts (test mode).
-- opts (optional): levelColored (the level in its difficulty colour),
-- compact ("1234/1234"), infoColor (INFO's class part coloured), scope.
local NO_OPTS = {}
function Texts.Apply(fs, tag, unit, kind, showSurname, sample, opts)
    opts = opts or NO_OPTS
    if sample and kind == "health" and SAMPLE_TAGS[tag] then
        applySample(fs, tag, sample, opts.compact)
    elseif tag == "NONE" then
        fs:SetText("")
    elseif tag == "NAME" then
        Texts.SetName(fs, unit, showSurname)
    elseif tag == "NAME_LEVEL" then
        Texts.SetName(fs, unit, showSurname, levelText(unit, opts.levelColored))
    elseif tag == "LEVEL" then
        fs:SetText(levelText(unit, opts.levelColored))
    elseif tag == "INFO" then
        setInfo(fs, unit, opts)
    elseif tag == "CURRENT" then
        fs:SetText(Secrets.Abbreviate(current(unit, kind)))
    elseif tag == "CURRENT_MAX" then
        fs:SetFormattedText(opts.compact and "%s/%s" or "%s / %s", Secrets.Abbreviate(current(unit, kind)),
            Secrets.Abbreviate(maximum(unit, kind)))
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

-- Away badge ------------------------------------------------------------------
-- A small pill right after the name in the title row: "AFK" in gold, "DND"
-- in red, each on a dark ground with a rim of its colour. Round ends: two
-- circle-masked squares either side of a plain middle, once for the rim and
-- once, a pixel smaller, for the ground.
Texts.AWAY_STYLES = {
    AFK = { rim = { 0.80, 0.55, 0.12 }, ground = { 0.16, 0.11, 0.03 }, text = { 1, 0.82, 0.25 } },
    DND = { rim = { 0.72, 0.12, 0.12 }, ground = { 0.22, 0.03, 0.03 }, text = { 1, 0.45, 0.40 } },
}
local AWAY_GAP = 5

-- AFK, DND or nil. The flags are secret in chat lockdown (encounters): then
-- nil, no badge.
function Texts.AwayState(unit)
    if Secrets.Bool(UnitIsAFK, unit) then return "AFK" end
    if Secrets.Bool(UnitIsDND, unit) then return "DND" end
    return nil
end

local function pillLayer(badge, sublevel)
    local layer = {}
    for i, part in ipairs({ "left", "middle", "right" }) do
        local tex = badge:CreateTexture(nil, "ARTWORK", nil, sublevel)
        tex:SetColorTexture(1, 1, 1, 1)
        if part ~= "middle" then makeRound(badge, tex) end
        layer[i] = tex
    end
    return layer
end

-- A layer of the pill, inset pixels from the badge's edge.
local function placePill(badge, layer, inset)
    local h = math.max(1, badge:GetHeight() - 2 * inset)
    local left, middle, right = layer[1], layer[2], layer[3]
    left:ClearAllPoints()
    left:SetPoint("LEFT", badge, "LEFT", inset, 0)
    left:SetSize(h, h)
    right:ClearAllPoints()
    right:SetPoint("RIGHT", badge, "RIGHT", -inset, 0)
    right:SetSize(h, h)
    middle:ClearAllPoints()
    middle:SetPoint("TOPLEFT", left, "TOP", 0, 0)
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOM", 0, 0)
end

local function paintPill(layer, c)
    for _, tex in ipairs(layer) do tex:SetVertexColor(c[1], c[2], c[3], 1) end
end

function Texts.BuildAwayBadge(frame)
    local badge = CreateFrame("Frame", nil, frame.overlay)
    badge.rim = pillLayer(badge, 0)
    badge.ground = pillLayer(badge, 1)
    badge.text = badge:CreateFontString(nil, "OVERLAY")
    badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
    badge:Hide()
    frame.awayBadge = badge
end

-- The title back to its own anchors (as Style set them).
local function restoreTitle(frame)
    local title = frame.texts.title
    title:ClearAllPoints()
    title:SetWidth(0)
    title:SetPoint("LEFT", frame.title, "LEFT", ns.Pixel.Snap(4, title), 0)
    placeTitleEnd(frame)
end

-- The room the title text has: the title row less its insets, and less the
-- class badge where that sits in the row.
local function titleRoom(frame)
    local width = (frame.title:GetWidth() or 0) - 8
    if frame.classIcon:IsShown() and frame.classBadgeInRow then
        width = width - (frame.classBadgeBox.right - frame.classBadgeBox.left) - 2
    end
    return math.max(0, width)
end

function Texts.UpdateAwayBadge(frame)
    local badge = frame.awayBadge
    local state = frame.titleHeight > 0 and Config.Get(frame.key, "awayBadge") and Texts.AwayState(frame.unit)
    if not state then
        if badge:IsShown() then
            badge:Hide()
            restoreTitle(frame)
        end
        return
    end
    local style = Texts.AWAY_STYLES[state]
    local title = frame.texts.title
    local titleSize = select(2, title:GetFont()) or 12
    local height = ns.Pixel.Snap(math.floor(titleSize * 1.05 + 0.5), nil, 1)
    local textSize = math.max(7, math.floor(titleSize * 0.62 + 0.5))
    Texts.SetFont(badge.text, ns.Media.Font(Config.Get(frame.key, "fontFace")), textSize, "NONE")
    badge.text:SetText(state)
    badge.text:SetTextColor(style.text[1], style.text[2], style.text[3], 1)
    local width = ns.Pixel.Snap((badge.text:GetStringWidth() or 0) + height, nil, 1)
    badge:SetSize(width, height)
    local px = ns.Pixel.Snap(1, nil, 1)
    placePill(badge, badge.rim, 0)
    placePill(badge, badge.ground, px)
    paintPill(badge.rim, style.rim)
    paintPill(badge.ground, style.ground)
    -- The title is as wide as its text (at most the room left for it), so
    -- the badge sits right after the name; a long name ends in "...".
    -- A secret name cannot be measured: then it takes all the room.
    local room = math.max(1, titleRoom(frame) - width - AWAY_GAP)
    local measure = title.GetUnboundedStringWidth or title.GetStringWidth
    local nameWidth = Secrets.Number(measure(title))
    title:ClearAllPoints()
    title:SetPoint("LEFT", frame.title, "LEFT", ns.Pixel.Snap(4, title), 0)
    title:SetWidth(math.min(nameWidth and (nameWidth + 1) or room, room))
    badge:ClearAllPoints()
    badge:SetPoint("LEFT", title, "RIGHT", AWAY_GAP, 0)
    badge:Show()
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
    Texts.BuildAwayBadge(frame)
    frame.texts = {}
    -- Power texts: on a layer of their own, a child of the power bar (so
    -- they hide with it) above what lies on the bar, e.g. the druid's mana
    -- strip (Elements/DruidMana.lua).
    frame.powerTextLayer = CreateFrame("Frame", nil, frame.power)
    frame.powerTextLayer:SetAllPoints(frame.power)
    for _, slot in ipairs(SLOTS) do
        -- Title and health texts sit on the overlay, above shields and
        -- heals; power texts on the power bar's text layer.
        local parent = slot.bar == "power" and frame.powerTextLayer or frame.overlay
        frame.texts[slot.field] = parent:CreateFontString(nil, "OVERLAY")
    end
end

-- The power texts' layer above the power bar and anything on it.
Texts.POWER_TEXT_LEVELS = 5

function Texts.Style(frame)
    local scope = frame.key
    frame.powerTextLayer:SetFrameLevel(frame.power:GetFrameLevel() + Texts.POWER_TEXT_LEVELS)
    local font = ns.Media.Font(Config.Get(scope, "fontFace"))
    local size = Config.Get(scope, "fontSize")
    local outline = Config.Get(scope, "fontOutline")
    local shadow = Config.Get(scope, "fontShadow")
    local valueSize = Config.Get(scope, "valueFontSize")
    for _, slot in ipairs(SLOTS) do
        local fs = frame.texts[slot.field]
        -- Value texts (numbers, percent) may have a size of their own.
        local isValue = SAMPLE_TAGS[Config.Get(scope, slot.setting)] ~= nil
        Texts.SetFont(fs, font, (isValue and valueSize > 0) and valueSize or size, outline)
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
    if mode ~= "WHITE" then r, g, b = ns.Health.UnitColor(frame.unit, mode, frame.key) end
    frame.texts.title:SetTextColor(r, g, b, 1)
end

-- Texts on the bars that name the unit take barNameColorMode; value
-- texts and the status word stay white.
Texts.NAME_TAGS = { NAME = true, NAME_LEVEL = true, INFO = true }

local function paintBars(frame, wordSlot)
    local mode = Config.Get(frame.key, "barNameColorMode")
    local r, g, b = 1, 1, 1
    if mode ~= "WHITE" then r, g, b = ns.Health.UnitColor(frame.unit, mode, frame.key) end
    for _, slot in ipairs(SLOTS) do
        if slot.bar ~= "title" then
            local named = slot.field ~= wordSlot and Texts.NAME_TAGS[Config.Get(frame.key, slot.setting)]
            if named then
                frame.texts[slot.field]:SetTextColor(r, g, b, 1)
            else
                frame.texts[slot.field]:SetTextColor(1, 1, 1, 1)
            end
        end
    end
end

-- Dead, ghost and offline units (Elements/UnitStatus.lua): the health
-- bar's value texts give way to one word, in the first of them; a bar
-- without a value text shows it on the right when that side is empty.
-- Returns the slot field that shows the word, or nil.
local function statusSlot(frame)
    local empty
    for _, slot in ipairs(SLOTS) do
        if slot.bar == "health" then
            local tag = Config.Get(frame.key, slot.setting)
            if SAMPLE_TAGS[tag] then return slot.field end
            if tag == "NONE" then empty = slot.field end
        end
    end
    return empty
end

local function isHealthValue(frame, slot)
    return slot.bar == "health" and SAMPLE_TAGS[Config.Get(frame.key, slot.setting)] ~= nil
end

function Texts.Update(frame)
    local showSurname = Config.Get(frame.key, "showSurname")
    local opts = {
        levelColored = Config.Get(frame.key, "levelColorMode") == "DIFFICULTY",
        compact = Config.Get(frame.key, "textCompact"),
        infoColor = Config.Get(frame.key, "infoClassColor"),
        scope = frame.key,
    }
    local sample = sampleHealth(frame)
    local word = ns.UnitStatus.Word(ns.UnitStatus.Of(frame))
    local wordSlot = word and statusSlot(frame)
    for _, slot in ipairs(SLOTS) do
        local fs = frame.texts[slot.field]
        if slot.field == wordSlot then
            fs:SetText(word)
        elseif word and isHealthValue(frame, slot) then
            fs:SetText("")
        else
            Texts.Apply(fs, Config.Get(frame.key, slot.setting), frame.unit, slot.kind or slot.bar, showSurname,
                sample, opts)
        end
    end
    paintTitle(frame)
    paintBars(frame, wordSlot)
    updateClassIcon(frame)
    Texts.UpdateAwayBadge(frame)
end

-- Test mode: Health.Preview (an earlier element) has switched the health
-- bar to or from its sample; the texts follow at once.
function Texts.Preview(frame)
    if frame.unit and UnitExists(frame.unit) then Texts.Update(frame) end
end

ns.RegisterElement(Texts)
