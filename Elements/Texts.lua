local _, ns = ...

local Texts = {
    name = "Texts",
    unitEvents = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
        "UNIT_NAME_UPDATE", "UNIT_LEVEL" },
}
ns.Texts = Texts

local Config, Secrets = ns.Config, ns.Secrets

local SLOTS = {
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

function Texts.Apply(fs, tag, unit, kind)
    if tag == "NONE" then
        fs:SetText("")
    elseif tag == "NAME" then
        fs:SetText(UnitName(unit))
    elseif tag == "NAME_LEVEL" then
        fs:SetFormattedText("%s %s", levelText(unit), UnitName(unit))
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

function Texts.Build(frame)
    frame.texts = {}
    for _, slot in ipairs(SLOTS) do
        -- Parent to the bar so the text sits above it.
        frame.texts[slot.field] = frame[slot.bar]:CreateFontString(nil, "OVERLAY")
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
end

function Texts.Update(frame)
    for _, slot in ipairs(SLOTS) do
        Texts.Apply(frame.texts[slot.field], Config.Get(frame.key, slot.setting), frame.unit, slot.bar)
    end
end

ns.RegisterElement(Texts)
