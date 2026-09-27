local _, ns = ...

local Power = { name = "Power", unitEvents = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" } }
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

function Power.Update(frame)
    local unit = frame.unit
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
