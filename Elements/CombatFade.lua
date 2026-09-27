local _, ns = ...

-- Player frame out of combat (optional): faded to a set opacity while
-- nothing is going on -- no combat, no cast, full health. Test mode and
-- unlocked frames always show it in full. Only the opacity changes:
-- allowed on a secure frame at any time.
--
-- The player's health reaches addon code as a secret, out of combat too,
-- so "full" cannot be tested here. The client does it: a step curve maps
-- the health fraction to the opacity (full: the faded opacity, anything
-- less: 1), UnitHealthPercent evaluates it, and SetAlpha takes the
-- (secret) result as it is. Power is not looked at: it has no such
-- curve path to a single opacity together with health, and mana and
-- energy refill quickly out of combat anyway.
local CombatFade = {
    name = "CombatFade",
    unitEvents = { "UNIT_HEALTH", "UNIT_MAXHEALTH",
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" },
}
ns.CombatFade = CombatFade

local Config, Secrets = ns.Config, ns.Secrets

-- The step curve for a faded opacity (rebuilt when it changes).
local curve, curveAlpha
local function healthCurve(alpha)
    if curve and curveAlpha == alpha then return curve end
    curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, 1)
    curve:AddPoint(1, alpha)
    curveAlpha = alpha
    return curve
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
    if casting() then return "CASTING" end
    return nil
end

function CombatFade.Apply(frame)
    frame = frame or ns.Frames.player
    if not frame then return end
    if CombatFade.Blocker() ~= nil then
        frame:SetAlpha(1)
        return
    end
    local alpha = Config.Get("player", "playerFadeAlpha") / 100
    local ok, value = pcall(UnitHealthPercent, "player", false, healthCurve(alpha))
    if ok and type(value) ~= "nil" then frame:SetAlpha(value) else frame:SetAlpha(1) end
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
