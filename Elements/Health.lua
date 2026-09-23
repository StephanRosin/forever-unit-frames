local _, ns = ...

local Health = { name = "Health", unitEvents = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION" } }
ns.Health = Health

local Secrets, Config = ns.Secrets, ns.Config

local REACTION = {
    hostile = { 0.85, 0.2, 0.2 },
    neutral = { 0.9, 0.8, 0.25 },
    friendly = { 0.2, 0.75, 0.3 },
}

local gradientCurve
local function gradient()
    if not gradientCurve then
        gradientCurve = C_CurveUtil.CreateColorCurve()
        gradientCurve:AddPoint(0, CreateColor(0.85, 0.2, 0.2))
        gradientCurve:AddPoint(0.5, CreateColor(0.9, 0.8, 0.25))
        gradientCurve:AddPoint(1, CreateColor(0.2, 0.75, 0.3))
    end
    return gradientCurve
end

-- { r, g, b } of the unit's reaction to the player.
function Health.ReactionColor(unit)
    local r = Secrets.Number(UnitReaction(unit, "player"))
    if r then
        if r <= 3 then return REACTION.hostile end
        if r == 4 then return REACTION.neutral end
        return REACTION.friendly
    end
    -- Reaction can be secret; friend/foe is the coarse fallback.
    if Secrets.Bool(UnitIsFriend, "player", unit) then return REACTION.friendly end
    return REACTION.hostile
end

-- r, g, b of a player's class, or nothing (not a player, class unknown).
function Health.ClassColor(unit)
    if not Secrets.Bool(UnitIsPlayer, unit) then return end
    local ok, c = pcall(function()
        local _, class = UnitClass(unit)
        return RAID_CLASS_COLORS[class]
    end)
    if ok and c then return c.r, c.g, c.b end
end

-- Class colour for players, reaction colour for everyone else.
function Health.UnitColor(unit, mode)
    if mode == "CLASS" then
        local r, g, b = Health.ClassColor(unit)
        if r then return r, g, b end
    end
    local c = Health.ReactionColor(unit)
    return c[1], c[2], c[3]
end

function Health.ColorFor(frame)
    local scope, unit = frame.key, frame.unit
    local mode = Config.Get(scope, "healthColorMode")
    if mode == "CLASS" or mode == "REACTION" then
        return Health.UnitColor(unit, mode)
    end
    if mode == "GRADIENT" then
        return UnitHealthPercent(unit, true, gradient()):GetRGB()
    end
    local c = Config.Get(scope, "healthColor")
    return c[1], c[2], c[3]
end

function Health.Build(frame)
    -- The title row: its own background above the health bar; its text
    -- is Elements/Texts.lua's.
    frame.title = frame:CreateTexture(nil, "BACKGROUND")
    frame.health = CreateFrame("StatusBar", nil, frame)
    frame.healthBg = frame.health:CreateTexture(nil, "BACKGROUND")
    frame.healthBg:SetAllPoints(frame.health)
end

function Health.Style(frame)
    local scope = frame.key
    local tex = ns.Media.StatusBar(Config.Get(scope, "barTexture"))
    frame.health:SetStatusBarTexture(tex)
    frame.healthBg:SetTexture(tex)
    local bg = Config.Get(scope, "backgroundColor")
    frame.healthBg:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    frame.title:SetTexture(tex)
    frame.title:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
end

function Health.Update(frame)
    local unit = frame.unit
    frame.health:SetMinMaxValues(0, UnitHealthMax(unit))
    frame.health:SetValue(UnitHealth(unit))
    frame.health:SetStatusBarColor(Health.ColorFor(frame))
end

ns.RegisterElement(Health)
