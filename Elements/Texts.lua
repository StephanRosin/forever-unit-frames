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
    local flags = (outline == "NONE") and "" or outline
    local shadow = Config.Get(scope, "fontShadow")
    for _, slot in ipairs(SLOTS) do
        local fs = frame.texts[slot.field]
        fs:SetFont(font, size, flags)
        fs:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
        fs:ClearAllPoints()
        fs:SetPoint(slot.point, frame[slot.bar], slot.point, slot.x, 0)
        if slot.before then
            -- A left text ends where the right one begins (an empty right
            -- text is zero wide), so the two never overlap on a narrow
            -- bar. No measuring: the text may be secret.
            fs:SetPoint("RIGHT", frame.texts[slot.before], "LEFT", -4, 0)
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
