local _, ns = ...

-- Incoming heals: two status bars starting where the health fill ends,
-- each as wide as the health bar and on the same scale (0 .. maximum
-- health), so a point of healing is as wide as a point of health. The
-- lower bar holds all incoming heals in the other-heals colour, the upper
-- one only yours: what shows of the lower one past yours is everyone
-- else's. No value is added, subtracted or compared; they may be secret.
-- A clipping frame over the health bar cuts them at full health, or at
-- the end of the overheal lane when that is on (Units/Single.lua makes
-- the room).
--
-- Blizzard's own frames (UnitFrameHealPredictionBars_Update) split and
-- clamp the amounts in Lua; that is only possible for secure code. Here
-- the layout does the work: the anchor to the fill texture places the
-- bars, the status bar scales them, the clip frame cuts them.
local HealPrediction = {
    name = "HealPrediction",
    unitEvents = { "UNIT_HEAL_PREDICTION", "UNIT_MAXHEALTH" },
}
ns.HealPrediction = HealPrediction

local Config = ns.Config

-- Test mode: 25 % of maximum health coming in, 12 % of it yours.
HealPrediction.SAMPLE_ALL, HealPrediction.SAMPLE_MINE = 0.25, 0.12

function HealPrediction.Build(frame)
    local clip = CreateFrame("Frame", nil, frame.health)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(frame.health:GetFrameLevel() + 1)
    local all = CreateFrame("StatusBar", nil, clip)
    local mine = CreateFrame("StatusBar", nil, clip)
    all:SetFrameLevel(clip:GetFrameLevel() + 1)
    mine:SetFrameLevel(all:GetFrameLevel() + 1)
    for _, bar in ipairs({ all, mine }) do
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
    end
    -- The empty lane looks like the rest of the bar's background.
    frame.overhealBg = frame:CreateTexture(nil, "BACKGROUND")
    frame.healClip, frame.healAll, frame.healMine = clip, all, mine
    ns.Corners.Add(frame, frame.overhealBg)
    ns.Corners.Add(frame, function() return all:GetStatusBarTexture() end)
    ns.Corners.Add(frame, function() return mine:GetStatusBarTexture() end)
end

-- Runs after Health.Style (element order), so the fill texture the bars
-- hang from is the one the health bar now uses.
function HealPrediction.Style(frame)
    local scope, health = frame.key, frame.health
    local lane = frame.overhealLane or 0
    local fill = health:GetStatusBarTexture()
    local tex = ns.Media.StatusBar(Config.Get(scope, "barTexture"))
    local clip = frame.healClip
    clip:ClearAllPoints()
    clip:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
    clip:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", lane, 0)
    clip:SetShown(Config.Get(scope, "healPrediction"))
    for _, pair in ipairs({ { frame.healAll, "healOtherColor" }, { frame.healMine, "healMyColor" } }) do
        local bar, key = pair[1], pair[2]
        bar:SetStatusBarTexture(tex)
        local c = Config.Get(scope, key)
        bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
        bar:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
        bar:SetWidth(frame.healthWidth)
    end
    local laneBg = frame.overhealBg
    laneBg:ClearAllPoints()
    laneBg:SetPoint("TOPLEFT", health, "TOPRIGHT", 0, 0)
    laneBg:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", lane, 0)
    laneBg:SetTexture(tex)
    local bg = Config.Get(scope, "backgroundColor")
    laneBg:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    laneBg:SetShown(lane > 0)
end

local function show(bar, amount, maximum)
    -- Presence is asked with type(): a secret cannot be tested by truth.
    if type(amount) == "nil" then amount = 0 end
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(amount)
end

function HealPrediction.Update(frame)
    if frame.healClip.preview or not Config.Get(frame.key, "healPrediction") then return end
    local unit = frame.unit
    local maximum = UnitHealthMax(unit)
    show(frame.healAll, UnitGetIncomingHeals(unit), maximum)
    show(frame.healMine, UnitGetIncomingHeals(unit, "player"), maximum)
end

function HealPrediction.Preview(frame, on)
    frame.healClip.preview = on or nil
    if not on then return end
    show(frame.healAll, HealPrediction.SAMPLE_ALL, 1)
    show(frame.healMine, HealPrediction.SAMPLE_MINE, 1)
end

ns.RegisterElement(HealPrediction)
