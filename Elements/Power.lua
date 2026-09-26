local _, ns = ...

local Power = { name = "Power", unitEvents = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" } }
ns.Power = Power

local Config = ns.Config

-- Own colours: Blizzard's PowerBarColor is only guaranteed on mainline
-- game types. Index = power type number.
Power.COLORS = {
    [0] = { 0.25, 0.5, 1.0 },   -- mana
    [1] = { 0.85, 0.2, 0.2 },   -- rage
    [2] = { 1.0, 0.5, 0.25 },   -- focus
    [3] = { 1.0, 0.85, 0.2 },   -- energy
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
    local c = Power.COLORS[ns.Secrets.Number(powerType) or -1] or DEFAULT
    -- Dead, ghost and offline units (Elements/UnitStatus.lua) are grey.
    if ns.UnitStatus.Of(frame) then c = ns.UnitStatus.GREY end
    frame.power:SetStatusBarColor(c[1], c[2], c[3])
    frame.power:SetMinMaxValues(0, UnitPowerMax(unit))
    frame.power:SetValue(UnitPower(unit))
end

ns.RegisterElement(Power)
