local _, ns = ...

-- UNIT_POWER_FREQUENT, not UNIT_POWER_UPDATE: the latter comes throttled
-- and at uneven moments, so regenerating energy and mana jumped in odd
-- steps. Blizzard's player frame reads every change too (frequentUpdates).
local Power = { name = "Power", unitEvents = { "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" } }
ns.Power = Power

local Config = ns.Config

-- Own colours, one setting per power type: Blizzard's PowerBarColor is
-- only guaranteed on mainline game types. Index = power type number.
Power.COLOR_KEYS = {
    [0] = "powerColorMana",
    [1] = "powerColorRage",
    [2] = "powerColorFocus",
    [3] = "powerColorEnergy",
}
local DEFAULT = { 0.6, 0.6, 0.6 }

function Power.Build(frame)
    frame.power = CreateFrame("StatusBar", nil, frame)
    frame.powerBg = frame.power:CreateTexture(nil, "BACKGROUND")
    frame.powerBg:SetAllPoints(frame.power)
    ns.Corners.Add(frame, frame.powerBg)
    ns.Corners.Add(frame, function() return frame.power:GetStatusBarTexture() end)
end

function Power.Style(frame)
    local tex = ns.Media.StatusBar(Config.Get(frame.key, "barTexture"))
    frame.power:SetStatusBarTexture(tex)
    frame.powerBg:SetTexture(tex)
    local bg = Config.Get(frame.key, "backgroundColor")
    frame.powerBg:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
end

Power.RAGE = 1

-- True when the unit has no power to show. A readable maximum of 0 says so.
-- WoW: Forever hands out an enemy NPC's power as secret values, though, so
-- the maximum often cannot be read. Then the power type (readable) decides:
-- an NPC with rage never builds any, its rage bar is always empty. Players
-- and what they control (pets) do build rage, so for them the bar stays,
-- as it does whenever nothing can be told.
function Power.IsEmpty(unit)
    local max = UnitPowerMax(unit)
    if not ns.Secrets.IsSecret(max) then return ns.Secrets.Number(max) == 0 end
    if ns.Secrets.Number(UnitPowerType(unit)) ~= Power.RAGE then return false end
    return ns.Secrets.Bool(UnitIsPlayer, unit) == false and ns.Secrets.Bool(UnitPlayerControlled, unit) == false
end

-- With "Hide without power" the bar goes and the health bar takes its row;
-- the frame is laid out again only when that changes (a new target).
local function checkEmpty(frame)
    -- Config.Get answers every scope; the setting exists for some only.
    local applies = ns.Settings.AppliesTo(ns.Settings.Get("powerHideEmpty"), frame.key)
    local empty = applies and Config.Get(frame.key, "powerHideEmpty") == true and Power.IsEmpty(frame.unit)
    -- A rule of the frame's own (raid cells: the power strip setting,
    -- Raid/Cell.lua); no unit frame has one.
    if not empty and frame.showsPower then empty = not frame.showsPower(frame) end
    if empty == (frame.powerEmpty == true) then return end
    frame.powerEmpty = empty
    -- The rows only: the health bar takes the power bar's row. Auras hung
    -- from the power bar stay put: its hidden one-pixel strip lies at the
    -- frame's bottom edge, where the health bar now ends.
    ns.Single.LayoutBars(frame)
end

function Power.Update(frame)
    local unit = frame.unit
    checkEmpty(frame)
    local powerType = UnitPowerType(unit)
    local key = Power.COLOR_KEYS[ns.Secrets.Number(powerType) or -1]
    local c = key and Config.Get(frame.key, key) or DEFAULT
    -- Dead, ghost and offline units (Elements/UnitStatus.lua) are grey.
    if ns.UnitStatus.Of(frame) then c = ns.UnitStatus.GREY end
    frame.power:SetStatusBarColor(c[1], c[2], c[3])
    frame.power:SetMinMaxValues(0, UnitPowerMax(unit))
    frame.power:SetValue(UnitPower(unit))
end

ns.RegisterElement(Power)
