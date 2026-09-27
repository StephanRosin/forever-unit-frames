local _, ns = ...

-- Player frame out of combat (optional): faded to a set opacity while
-- nothing is going on -- no combat, full health and power (rage
-- and runic-style power rest at 0), no cast. Anything else, or a value
-- that cannot be read (secret), shows it in full. Test mode and unlocked
-- frames always show it in full. Only the opacity changes: allowed on a
-- secure frame at any time.
local CombatFade = {
    name = "CombatFade",
    unitEvents = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" },
}
ns.CombatFade = CombatFade

local Config, Secrets = ns.Config, ns.Secrets

-- Power types that rest at 0 (rage, runic power).
local EMPTY_AT_REST = { [1] = true, [6] = true }

local function full(value, maximum)
    local v, m = Secrets.Number(value), Secrets.Number(maximum)
    return v ~= nil and m ~= nil and v >= m
end

local function powerAtRest()
    local kind = Secrets.Number((UnitPowerType("player")))
    local power, maximum = UnitPower("player"), UnitPowerMax("player")
    if Secrets.Number(maximum) == 0 then return true end
    if kind and EMPTY_AT_REST[kind] then return Secrets.Number(power) == 0 end
    return full(power, maximum)
end

local function casting()
    return type((UnitCastingInfo("player"))) ~= "nil" or type((UnitChannelInfo("player"))) ~= "nil"
end

-- Why the frame is not faded right now, or nil when it is (or may be).
-- The keys are ns.L strings FADE_<reason>, shown by /fuf status.
function CombatFade.Blocker()
    if not Config.Get("player", "playerFadeOOC") then return "OFF" end
    if ns.TestMode and ns.TestMode.IsOn() then return "TEST" end
    if ns.Movers and ns.Movers.IsUnlocked() then return "UNLOCKED" end
    if InCombatLockdown() or Secrets.Bool(UnitAffectingCombat, "player") ~= false then return "COMBAT" end
    if not full(UnitHealth("player"), UnitHealthMax("player")) then return "HEALTH" end
    if not powerAtRest() then return "POWER" end
    if casting() then return "CASTING" end
    return nil
end

function CombatFade.Apply(frame)
    frame = frame or ns.Frames.player
    if not frame then return end
    local faded = CombatFade.Blocker() == nil
    frame:SetAlpha(faded and Config.Get("player", "playerFadeAlpha") / 100 or 1)
end

function CombatFade.Build() end
function CombatFade.Style(frame) if frame.key == "player" then CombatFade.Apply(frame) end end
function CombatFade.Update(frame) if frame.key == "player" then CombatFade.Apply(frame) end end

local function applyPlayer() CombatFade.Apply() end
for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
    ns.On(event, applyPlayer)
end
ns.Listen("TEST_MODE", applyPlayer)
ns.Listen("MOVERS_UNLOCKED", applyPlayer)

ns.RegisterElement(CombatFade)
