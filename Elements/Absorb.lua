local _, ns = ...

-- Absorb shields: a bar docked where the health fill ends, after the
-- incoming heals (Elements/HealPrediction.lua), as wide as the health bar
-- and on the same scale, so a point of shield is as wide as a point of
-- health. absorbMode END instead fills it from the bar's right end over
-- the health, so a shield shows at full health too. Both values may be secret; the status bar takes them as they
-- are, the anchor places the bar and a clipping frame cuts it at the
-- health bar's end (or the end of the overheal lane).
local Absorb = { name = "Absorb", unitEvents = { "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_MAXHEALTH" } }
ns.Absorb = Absorb

local Config = ns.Config

-- Test mode: a shield of 30 % of maximum health.
Absorb.SAMPLE = 0.3
-- The shield multiplies what lies under it by a grey (darker on any class
-- colour), then adds a dim lift in absorbColor (a share of it), which
-- lights the black background where health is missing. On top: Blizzard's
-- shield stripes, tinted by absorbColor. Blend modes do the work: no
-- colour is read from the screen.
Absorb.SHADE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
Absorb.SHADE = 0.45
Absorb.LIFT_SHARE = 0.3
Absorb.STRIPES = "Interface\\RaidFrame\\Shield-Overlay"
-- Blizzard's over-absorb glow (CompactUnitFrameUtil), 16 wide. Blizzard
-- lets it reach 7 back over the bar's end; here it starts at the end, as
-- only the part past it can show at full health (the shield's fill starts
-- there). It shows when the shield runs past the
-- bar's end (absorbMode AFTER), so a full-health shield is seen without
-- the overheal lane. "Past the end" is not computed (the values may be
-- secret): the glow sits in a clipping frame laid over the shield's fill,
-- which is only as long as the shield and extends past the bar exactly
-- when health, incoming heals and shield add up to more than the maximum.
Absorb.GLOW = "Interface\\RaidFrame\\Shield-Overshield"
Absorb.GLOW_WIDTH = 16
Absorb.GLOW_OVERLAP = 0

function Absorb.Build(frame)
    local clip = CreateFrame("Frame", nil, frame.health)
    clip:SetClipsChildren(true)
    -- Above the incoming heals (health + 1 .. + 3), below the overlay.
    clip:SetFrameLevel(frame.health:GetFrameLevel() + 4)
    frame.absorbClip = clip
    local bar = CreateFrame("StatusBar", nil, clip)
    bar:SetFrameLevel(clip:GetFrameLevel())
    bar:SetReverseFill(false)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    -- The client tiles the stripes itself: no size is measured here, the
    -- fill's width may come from secret values.
    local lift = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    lift:SetColorTexture(1, 1, 1, 1)
    lift:SetBlendMode("ADD")
    bar.lift = lift
    local stripes = bar:CreateTexture(nil, "OVERLAY")
    stripes:SetTexture(Absorb.STRIPES, "REPEAT", "REPEAT")
    stripes:SetHorizTile(true)
    stripes:SetVertTile(true)
    bar.stripes = stripes
    -- Not inside the clip: the glow reaches past the bar's end.
    local gate = CreateFrame("Frame", nil, frame.health)
    gate:SetClipsChildren(true)
    gate:SetFrameLevel(clip:GetFrameLevel() + 1)
    local glow = gate:CreateTexture(nil, "OVERLAY")
    glow:SetTexture(Absorb.GLOW)
    glow:SetBlendMode("ADD")
    bar.gate, bar.glow = gate, glow
    frame.absorb = bar
    ns.Corners.Add(frame, function() return bar:GetStatusBarTexture() end)
    ns.Corners.Add(frame, lift)
    ns.Corners.Add(frame, stripes)
end

-- Runs after Health.Style and HealPrediction.Style (element order): the
-- textures it hangs from are the current ones.
function Absorb.Style(frame)
    local bar, scope = frame.absorb, frame.key
    local health, clip = frame.health, frame.absorbClip
    -- The fill's direction (barVertical, barReverse): "end" is its
    -- finish edge, the lane lies past it.
    local Layout = ns.Layout
    local dir = Layout.FillOf(scope)
    local start, finish = dir.start, dir.finish
    local lane = frame.overhealLane or 0
    local x1, y1, x2, y2 = Layout.Beyond(dir, lane)
    clip:ClearAllPoints()
    clip:SetPoint("TOPLEFT", health, "TOPLEFT", x1, y1)
    clip:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", x2, y2)
    bar:ClearAllPoints()
    bar:SetOrientation(dir.orientation)
    if Config.Get(scope, "absorbMode") == "END" then
        -- From the bar's end back towards its start, over the health: seen
        -- at full health too. No arithmetic with the (secret) values.
        bar:SetReverseFill(not dir.reverse)
        for _, side in ipairs(dir.sides) do
            local point = Layout.Corner(dir, finish, side)
            bar:SetPoint(point, health, point, 0, 0)
        end
    else
        -- After all incoming heals when they show, else right at the health.
        local after = Config.Get(scope, "healPrediction") and frame.healAll:GetStatusBarTexture()
            or health:GetStatusBarTexture()
        bar:SetReverseFill(dir.reverse)
        for _, side in ipairs(dir.sides) do
            bar:SetPoint(Layout.Corner(dir, start, side), after, Layout.Corner(dir, finish, side), 0, 0)
        end
    end
    local length = frame.healthLength or frame.healthWidth
    if dir.vertical then bar:SetHeight(length) else bar:SetWidth(length) end
    bar:SetStatusBarTexture(Absorb.SHADE_TEXTURE)
    local shade = Absorb.SHADE
    bar:SetStatusBarColor(shade, shade, shade, 1)
    local fill = bar:GetStatusBarTexture()
    fill:SetBlendMode("MOD")
    -- A new fill texture may have replaced the one these hung on.
    bar.lift:SetAllPoints(fill)
    bar.stripes:SetAllPoints(fill)
    local c = Config.Get(scope, "absorbColor")
    bar.stripes:SetVertexColor(c[1], c[2], c[3], c[4])
    local share = Absorb.LIFT_SHARE
    bar.lift:SetVertexColor(c[1] * share, c[2] * share, c[3] * share, 1)
    local gate, glow = bar.gate, bar.glow
    gate:ClearAllPoints()
    gate:SetAllPoints(fill)
    -- At the end of the clip: the bar's, or the overheal lane's. The
    -- texture fades from its left edge: turned to fade away from the end.
    glow:ClearAllPoints()
    local overlap = Absorb.GLOW_OVERLAP
    local dx = (finish == "RIGHT" and -overlap) or (finish == "LEFT" and overlap) or 0
    local dy = (finish == "TOP" and -overlap) or (finish == "BOTTOM" and overlap) or 0
    for _, side in ipairs(dir.sides) do
        glow:SetPoint(Layout.Corner(dir, start, side), clip, Layout.Corner(dir, finish, side), dx, dy)
    end
    if finish == "RIGHT" then glow:SetTexCoord(0, 1, 0, 1)
    elseif finish == "LEFT" then glow:SetTexCoord(1, 0, 0, 1)
    -- Corners in the order UL, LL, UR, LR: the texture's left edge at the
    -- bottom (fill upward) or the top (downward).
    elseif finish == "TOP" then glow:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
    else glow:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1) end
    if dir.vertical then glow:SetHeight(Absorb.GLOW_WIDTH) else glow:SetWidth(Absorb.GLOW_WIDTH) end
    glow:SetVertexColor(c[1], c[2], c[3], 1)
    local enabled = Config.Get(scope, "absorbEnabled")
    clip:SetShown(enabled)
    -- At the bar's end the shield never runs past it: no glow there.
    gate:SetShown(enabled and Config.Get(scope, "absorbMode") ~= "END")
end

function Absorb.Update(frame)
    local bar = frame.absorb
    if bar.preview or not Config.Get(frame.key, "absorbEnabled") then return end
    local amount = UnitGetTotalAbsorbs(frame.unit)
    -- Presence is asked with type(): a secret cannot be tested by truth.
    if type(amount) == "nil" then amount = 0 end
    bar:SetMinMaxValues(0, UnitHealthMax(frame.unit))
    bar:SetValue(amount)
end

function Absorb.Preview(frame, on)
    local bar = frame.absorb
    bar.preview = on or nil
    if not on then return end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(Absorb.SAMPLE)
end

ns.RegisterElement(Absorb)
