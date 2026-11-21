local _, ns = ...

-- Incoming heals: two status bars starting where the health fill ends,
-- each as wide as the health bar and on the same scale (0 .. maximum
-- health), so a point of healing is as wide as a point of health. The
-- lower bar holds all incoming heals in the other-heals colour, the upper
-- one only yours: what shows of the lower one past yours is everyone
-- else's. No value is added, subtracted or compared; they may be secret.
-- A clipping frame over the health bar cuts them at full health, or at
-- the end of the overheal lane when that is on (Units/Single.lua makes
-- the room). With healBeyond it reaches one more bar width past the
-- frame, so a heal shows in full; the bars then skip the frame's rounded
-- mask, which would cut off whatever lies outside the frame.
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
    -- Rounded with the frame, unless drawn past its edge (healBeyond).
    local function masked(bar)
        return function()
            if frame.healBeyond then return nil end
            return bar:GetStatusBarTexture()
        end
    end
    ns.Corners.Add(frame, masked(all))
    ns.Corners.Add(frame, masked(mine))
end

-- Runs after Health.Style (element order), so the fill texture the bars
-- hang from is the one the health bar now uses.
function HealPrediction.Style(frame)
    local scope, health = frame.key, frame.health
    local lane = frame.overhealLane or 0
    local healthFill = health:GetStatusBarTexture()
    local tex = ns.Media.StatusBar(Config.Get(scope, "barTexture"))
    local clip = frame.healClip
    local beyond = Config.Get(scope, "healBeyond")
    -- The fill's direction (barVertical, barReverse): the heals run on
    -- from its finish, the lane and the reach lie past that edge.
    local Layout = ns.Layout
    local fill = Layout.FillOf(scope)
    frame.healBeyond = beyond and not fill.vertical
    local length = frame.healthLength or frame.healthWidth
    -- Past the frame only sideways: above or below lie the frame's own rows.
    local reach = (beyond and not fill.vertical) and math.max(lane, length) or lane
    local x1, y1, x2, y2 = Layout.Beyond(fill, reach)
    clip:ClearAllPoints()
    clip:SetPoint("TOPLEFT", health, "TOPLEFT", x1, y1)
    clip:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", x2, y2)
    clip:SetShown(Config.Get(scope, "healPrediction"))
    for _, pair in ipairs({ { frame.healAll, "healOtherColor" }, { frame.healMine, "healMyColor" } }) do
        local bar, key = pair[1], pair[2]
        bar:SetStatusBarTexture(tex)
        local c = Config.Get(scope, key)
        bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
        bar:ClearAllPoints()
        bar:SetOrientation(fill.orientation)
        bar:SetReverseFill(fill.reverse)
        for _, side in ipairs(fill.sides) do
            bar:SetPoint(Layout.Corner(fill, fill.start, side), healthFill, Layout.Corner(fill, fill.finish, side), 0, 0)
        end
        if fill.vertical then bar:SetHeight(length) else bar:SetWidth(length) end
        -- Past the frame the rounded mask must be off (Elements/Shape.lua
        -- puts it on the listed textures, which skip themselves then).
        if beyond and not fill.vertical and frame.clip then
            ns.Corners.SetMasked(bar:GetStatusBarTexture(), frame.clip.mask, false)
        end
    end
    -- The lane: a strip lane deep past the finish edge, along the bar.
    local laneBg = frame.overhealBg
    laneBg:ClearAllPoints()
    for _, side in ipairs(fill.sides) do
        laneBg:SetPoint(Layout.Corner(fill, fill.start, side), health, Layout.Corner(fill, fill.finish, side), 0, 0)
    end
    if fill.vertical then laneBg:SetHeight(math.max(lane, 1)) else laneBg:SetWidth(math.max(lane, 1)) end
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
