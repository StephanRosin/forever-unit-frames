local _, ns = ...

-- States of a raid cell drawn as inner borders (the rest is the unit
-- frames' own: range fading, Elements/Range.lua; the grey of the dead and
-- offline, Elements/UnitStatus.lua):
-- * aggro: a red line along the inside while the unit has aggro.
--   UnitThreatSituation is secret while the unit's threat state is
--   restricted, and a secret status cannot be compared or coloured by
--   addon code (GetThreatStatusColor refuses it). Status bars take a
--   secret value (SetValue: SecretArguments AllowedWhenTainted), so the
--   four edges are status bars from 1 to 2, fed the status as it is: at 2
--   (tanking, not securely) and 3 (tanking) they are full, at 0 and 1
--   empty. Nothing is compared here; whether the client draws a secret
--   value that way is checked in game.
-- * your current target: a light line inside the red one. UnitIsUnit may
--   answer with a secret: the line's opacity takes it as it is
--   (SetAlphaFromBoolean), as the party's target highlight does.
-- Plain frames: they change in combat.
local States = { name = "RaidStates", unitEvents = { "UNIT_THREAT_SITUATION_UPDATE" } }
ns.RaidStates = States

local Cell, Pixel, Secrets = ns.RaidCell, ns.Pixel, ns.Secrets
local get = Cell.Get

States.AGGRO_COLOR = { 1, 0, 0, 1 }
States.TARGET_COLOR = { 1, 1, 1, 0.9 }
-- Each line's thickness in pixels.
States.SIZE = 2
-- Above the bars' texts (+10), below the cell's auras (+12).
States.LEVELS = 11
States.AGGRO_MIN, States.AGGRO_MAX = 1, 2
States.TEXTURE = "Interface\\Buttons\\WHITE8x8"
-- Test mode: the status a pretend member with aggro shows.
States.SAMPLE_AGGRO = 3

-- Four edges inside frame, `inset` from its edge, `thick` wide.
local function placeInner(edges, frame, inset, thick)
    local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
    for _, edge in ipairs(edges) do edge:ClearAllPoints() end
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
    top:SetHeight(thick)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    bottom:SetHeight(thick)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -(inset + thick))
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset + thick)
    left:SetWidth(thick)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -(inset + thick))
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset + thick)
    right:SetWidth(thick)
end

function States.Build(frame)
    if not Cell.Is(frame) then return end
    local aggro, target = CreateFrame("Frame", nil, frame), CreateFrame("Frame", nil, frame)
    local c = States.AGGRO_COLOR
    aggro.bars = {}
    for i = 1, 4 do
        local bar = CreateFrame("StatusBar", nil, aggro)
        bar:SetStatusBarTexture(States.TEXTURE)
        bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
        bar:SetMinMaxValues(States.AGGRO_MIN, States.AGGRO_MAX)
        bar:SetValue(0)
        aggro.bars[i] = bar
    end
    local t = States.TARGET_COLOR
    target.edges = {}
    for i = 1, 4 do
        target.edges[i] = target:CreateTexture(nil, "OVERLAY")
        target.edges[i]:SetColorTexture(t[1], t[2], t[3], t[4])
    end
    target:Hide()
    frame.raidStates = { aggro = aggro, target = target }
end

-- The threat status as it is (plain or secret), 0 for none.
local function threat(unit)
    local ok, status = pcall(UnitThreatSituation, unit)
    if not ok or (not Secrets.IsSecret(status) and type(status) ~= "number") then return 0 end
    return status
end

local function showAggro(s, value)
    for _, bar in ipairs(s.aggro.bars) do bar:SetValue(value) end
end

-- shown: plain; answer: the client's answer (plain or secret), nil when
-- shown says it all.
local function showTarget(s, shown, answer)
    s.target:SetShown(shown)
    if not shown then return end
    -- answer may be secret: its presence is asked with type(), not ==.
    if type(answer) == "nil" then s.target:SetAlpha(1) else s.target:SetAlphaFromBoolean(answer, 1, 0) end
end

local function updateTarget(frame)
    local s = frame.raidStates
    if not get("targetBorder") or not frame.unit then
        showTarget(s, false)
        return
    end
    local ok, answer = pcall(UnitIsUnit, frame.unit, "target")
    if not ok then
        showTarget(s, false)
    elseif Secrets.IsSecret(answer) then
        showTarget(s, true, answer)
    else
        showTarget(s, answer == true)
    end
end

-- Test mode: the pretend member's aggro and whether it is your target.
local function showSample(frame)
    local s, member = frame.raidStates, frame.sample or {}
    showAggro(s, member.aggro and States.SAMPLE_AGGRO or 0)
    showTarget(s, member.target == true and get("targetBorder") == true)
end

function States.Style(frame)
    local s = frame.raidStates
    if not s then return end
    local thick = Pixel.Snap(States.SIZE, nil, 1)
    for _, holder in ipairs({ s.aggro, s.target }) do
        holder:SetFrameLevel(frame:GetFrameLevel() + States.LEVELS)
        holder:SetAllPoints(frame)
    end
    placeInner(s.aggro.bars, frame, 0, thick)
    placeInner(s.target.edges, frame, thick, thick)
    s.aggro:SetShown(get("aggroBorder") == true)
    if s.preview then showSample(frame) else updateTarget(frame) end
end

function States.Update(frame)
    local s = frame.raidStates
    if not s or s.preview then return end
    -- threat() may return a secret: never truth-tested, only passed on.
    local value = 0
    if frame.unit then value = threat(frame.unit) end
    showAggro(s, value)
    updateTarget(frame)
end

function States.Preview(frame, on)
    local s = frame.raidStates
    if not s then return end
    s.preview = on or nil
    if on then
        showSample(frame)
    else
        showAggro(s, 0)
        showTarget(s, false)
    end
end

-- A new target: every cell looks again. After combat, threat and target
-- answers that were secret during combat are readable again: look again.
local function updateAll(event) ns.Units.UpdateElement(States, event) end
ns.On("PLAYER_TARGET_CHANGED", updateAll)
ns.On("PLAYER_REGEN_ENABLED", updateAll)

ns.RegisterElement(States)
