local _, ns = ...

-- What the spell being cast will cost, faded over the end of the player's
-- power bar, as Blizzard's player frame shows it (myManaCostPredictionBar,
-- UnitFrameManaCostPredictionBars_Update): from the cast's start until it
-- ends. Instant spells have no cast and show nothing.
--
-- Blizzard subtracts the cost from the bar's value in Lua; the values may
-- be secret here, so the layout does it instead: a status bar as wide as
-- the power bar and on its scale (0 .. maximum power), filling from the
-- right, with its right edge at the end of the power fill. The cost is
-- passed to it as it comes. A clipping frame over the power bar cuts off
-- what would reach past the bar's start (a cost above what is left).
--
-- The cost comes from C_Spell.GetSpellPowerCost with the spell ID of the
-- UNIT_SPELLCAST_START payload (it takes a secret ID too); the entry for
-- the bar's power type counts. A plain frame: shown and hidden in combat.
local PowerCost = {
    name = "PowerCost",
    unitEvents = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" },
}
ns.PowerCost = PowerCost

local Config, Secrets, Settings = ns.Config, ns.Secrets, ns.Settings

-- Above the power bar's fill, below its texts (Texts.POWER_TEXT_LEVELS).
PowerCost.LEVELS = 2
-- Test mode: a cast costing a fifth of the bar.
PowerCost.SAMPLE = 0.2

local ENDS = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_SUCCEEDED = true }

local function applies(frame)
    return Settings.AppliesTo(Settings.Get("powerCostPrediction"), frame.key)
end

local function wanted(frame)
    return Config.Get(frame.key, "powerCostPrediction") == true
end

function PowerCost.Build(frame)
    if not applies(frame) or not frame.power then return end
    local clip = CreateFrame("Frame", nil, frame.power)
    clip:SetAllPoints(frame.power)
    clip:SetClipsChildren(true)
    local bar = CreateFrame("StatusBar", nil, clip)
    bar:SetReverseFill(true)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    clip:Hide()
    frame.powerCost = { clip = clip, bar = bar }
    ns.Corners.Add(frame, function() return bar:GetStatusBarTexture() end)
end

-- Runs after Power.Style and the layout (element order): the fill texture
-- it hangs from and the bar's width are current.
function PowerCost.Style(frame)
    local p = frame.powerCost
    if not p then return end
    local scope = frame.key
    p.clip:SetFrameLevel(frame.power:GetFrameLevel() + PowerCost.LEVELS)
    p.bar:SetFrameLevel(p.clip:GetFrameLevel())
    p.bar:SetStatusBarTexture(ns.Media.StatusBar(Config.Get(scope, "barTexture")))
    local c = Config.Get(scope, "powerCostColor")
    p.bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
    local fill = frame.power:GetStatusBarTexture()
    p.bar:ClearAllPoints()
    p.bar:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, 0)
    p.bar:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
    p.bar:SetWidth(math.max(frame.powerWidth or frame.power:GetWidth() or 1, 1))
    if p.preview then PowerCost.Preview(frame, true) elseif not wanted(frame) then p.clip:Hide() end
end

-- The cost of spellID in the power bar's power type: a number, a secret,
-- or nil (no cost in it, or unreadable). A secret type cannot be matched;
-- a spell with a single cost then counts that one.
function PowerCost.Cost(unit, spellID)
    if type(spellID) == "nil" or not (C_Spell and C_Spell.GetSpellPowerCost) then return nil end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
    if not ok or type(costs) ~= "table" then return nil end
    local powerType = Secrets.Number(UnitPowerType(unit))
    for i, info in ipairs(costs) do
        local kind = Secrets.Number(info.type)
        if (kind ~= nil and kind == powerType) or (kind == nil and i == 1 and #costs == 1) then
            local cost = info.cost
            if Secrets.Number(cost) == 0 then return nil end
            return cost
        end
    end
    return nil
end

local function hide(frame)
    local p = frame.powerCost
    p.castGUID = nil
    p.clip:Hide()
end

local function show(frame, cost, max)
    local p = frame.powerCost
    p.bar:SetMinMaxValues(0, max)
    p.bar:SetValue(cost)
    p.clip:Show()
end

-- The cast it shows ended: a matching cast GUID, or one that cannot be
-- compared (secret, or none kept).
local function ended(p, castGUID)
    if Secrets.IsSecret(castGUID) or Secrets.IsSecret(p.castGUID) or p.castGUID == nil then return true end
    return castGUID == p.castGUID
end

function PowerCost.Update(frame, event, _, castGUID, spellID)
    local p = frame.powerCost
    if not p or p.preview then return end
    if not wanted(frame) or event == "UNIT_DISPLAYPOWER" then return hide(frame) end
    if event == "UNIT_SPELLCAST_START" then
        local cost = PowerCost.Cost(frame.unit, spellID)
        if type(cost) == "nil" then return hide(frame) end
        p.castGUID = castGUID
        return show(frame, cost, UnitPowerMax(frame.unit))
    end
    if ENDS[event] then
        if ended(p, castGUID) then hide(frame) end
        return
    end
    -- Anything else (the maximum, a whole-frame refresh): the scale.
    if p.clip:IsShown() then p.bar:SetMinMaxValues(0, UnitPowerMax(frame.unit)) end
end

function PowerCost.Preview(frame, on)
    local p = frame.powerCost
    if not p then return end
    p.preview = on or nil
    if on and wanted(frame) then
        show(frame, PowerCost.SAMPLE, 1)
    elseif on then
        p.clip:Hide()
    else
        hide(frame)
    end
end

ns.RegisterElement(PowerCost)
