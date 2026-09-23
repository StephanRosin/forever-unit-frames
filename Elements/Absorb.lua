local _, ns = ...

-- Absorb shields: a bar over the health bar, filling from its right end,
-- as long as the unit's total absorbs on a scale of its maximum health.
-- Both values may be secret; the status bar takes them as they are and
-- clamps at the bar's end itself.
local Absorb = { name = "Absorb", unitEvents = { "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_MAXHEALTH" } }
ns.Absorb = Absorb

local Config = ns.Config

-- Test mode: a shield of 30 % of maximum health.
Absorb.SAMPLE = 0.3
-- The shield multiplies what lies under it by a grey (darker on any class
-- colour), then adds a dim blue lift, which lights the black background
-- where health is missing. On top: Blizzard's shield stripes, tinted by
-- absorbColor. Blend modes do the work: no colour is read or computed.
Absorb.SHADE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
Absorb.SHADE = 0.45
Absorb.LIFT = { 0.12, 0.18, 0.3 }
Absorb.STRIPES = "Interface\\RaidFrame\\Shield-Overlay"

function Absorb.Build(frame)
    local bar = CreateFrame("StatusBar", nil, frame.health)
    bar:SetAllPoints(frame.health)
    -- Above the incoming heals (health + 1 .. + 3), below the overlay.
    bar:SetFrameLevel(frame.health:GetFrameLevel() + 4)
    bar:SetReverseFill(true)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    -- The client tiles the stripes itself: no size is measured here, the
    -- fill's width may come from secret values.
    local lift = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    lift:SetColorTexture(Absorb.LIFT[1], Absorb.LIFT[2], Absorb.LIFT[3], 1)
    lift:SetBlendMode("ADD")
    bar.lift = lift
    local stripes = bar:CreateTexture(nil, "OVERLAY")
    stripes:SetTexture(Absorb.STRIPES, "REPEAT", "REPEAT")
    stripes:SetHorizTile(true)
    stripes:SetVertTile(true)
    bar.stripes = stripes
    frame.absorb = bar
    ns.Corners.Add(frame, function() return bar:GetStatusBarTexture() end)
    ns.Corners.Add(frame, lift)
    ns.Corners.Add(frame, stripes)
end

function Absorb.Style(frame)
    local bar, scope = frame.absorb, frame.key
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
    bar:SetShown(Config.Get(scope, "absorbEnabled"))
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
