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

function Absorb.Build(frame)
    local bar = CreateFrame("StatusBar", nil, frame.health)
    bar:SetAllPoints(frame.health)
    -- Above the incoming heals (health + 1 .. + 3), below the overlay.
    bar:SetFrameLevel(frame.health:GetFrameLevel() + 4)
    bar:SetReverseFill(true)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    frame.absorb = bar
    ns.Corners.Add(frame, function() return bar:GetStatusBarTexture() end)
end

function Absorb.Style(frame)
    local bar, scope = frame.absorb, frame.key
    bar:SetStatusBarTexture(ns.Media.StatusBar(Config.Get(scope, "barTexture")))
    local c = Config.Get(scope, "absorbColor")
    bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
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
