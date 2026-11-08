local _, ns = ...

-- Player frame out of combat (optional): faded to a set opacity while
-- nothing is going on -- no combat, no cast, (optional, on by default)
-- full health, and (optional)
-- no target, so a target brings it back before the pull; and (optional)
-- not in a party or raid, where a healer heals by mouse-over. Test mode and
-- unlocked frames always show it in full. Only the opacity changes:
-- allowed on a secure frame at any time.
--
-- The player's health reaches addon code as a secret, out of combat too,
-- so "full" cannot be tested here. The client does it: a step curve maps
-- the health fraction to the opacity (full: the faded opacity, anything
-- less: frameAlpha), UnitHealthPercent evaluates it, and SetAlpha takes the
-- (secret) result as it is. Power is not looked at: it has no such
-- curve path to a single opacity together with health, and mana and
-- energy refill quickly out of combat anyway.
--
-- The pet frame may fade with it (playerFadePet, off by default): it gets
-- the very value the player frame gets, secret or not, through SetAlpha
-- only. While it does, the pet's range fading (Elements/Range.lua) leaves
-- its opacity alone (CombatFade.HoldsPet); whenever the player frame is in
-- full (a blocker above), the pet goes back to its range fading.
local CombatFade = {
    name = "CombatFade",
    unitEvents = { "UNIT_HEALTH", "UNIT_MAXHEALTH",
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" },
}
ns.CombatFade = CombatFade

local Config, Secrets = ns.Config, ns.Secrets
local function setAlpha(frame, value) ns.Range.SetAlpha(frame, value) end

-- The step curve from full to faded opacity (rebuilt when either changes).
local curve, curveFull, curveAlpha
local function healthCurve(full, alpha)
    if curve and curveFull == full and curveAlpha == alpha then return curve end
    curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, full)
    curve:AddPoint(1, alpha)
    curveFull, curveAlpha = full, alpha
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
    if Config.Get("player", "playerFadeTarget") and Secrets.Bool(UnitExists, "target") then return "TARGET" end
    if Config.Get("player", "playerFadeGroup") and IsInGroup() then return "GROUP" end
    return nil
end


-- Whether the pet frame's opacity is the player frame's right now.
function CombatFade.HoldsPet(frame)
    return frame ~= nil and frame == ns.Frames.pet and Config.Get("player", "playerFadePet") == true
        and CombatFade.Blocker() == nil
end

-- The pet frame takes value while it follows; one that followed and no
-- longer does goes back to its range fading (3D portrait included).
local function applyPet(value)
    local pet = ns.Frames.pet
    if not pet then return end
    if CombatFade.HoldsPet(pet) then
        setAlpha(pet, value)
        pet.fadeFollowed = true
    elseif pet.fadeFollowed then
        pet.fadeFollowed = nil
        ns.Range.Update(pet)
    end
end

function CombatFade.Apply()
    local frame = ns.Frames.player
    if not frame then return end
    -- frameAlpha is full; the fade is a share of it.
    local full = ns.Range.FullAlpha(frame)
    if CombatFade.Blocker() ~= nil then
        setAlpha(frame, full)
        applyPet(full)
        return
    end
    local alpha = full * Config.Get("player", "playerFadeAlpha") / 100
    local value = alpha
    if Config.Get("player", "playerFadeHurt") then
        local ok
        ok, value = pcall(UnitHealthPercent, "player", false, healthCurve(full, alpha))
        if not ok or type(value) == "nil" then value = full end
    end
    setAlpha(frame, value)
    applyPet(value)
end

local FRAMES = { player = true, pet = true }
function CombatFade.Build() end
function CombatFade.Style(frame) if FRAMES[frame.key] then CombatFade.Apply() end end
function CombatFade.Update(frame) if FRAMES[frame.key] then CombatFade.Apply() end end

local function applyPlayer() CombatFade.Apply() end
for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE" }) do
    ns.On(event, applyPlayer)
end
ns.Listen("TEST_MODE", applyPlayer)
ns.Listen("MOVERS_UNLOCKED", applyPlayer)

ns.RegisterElement(CombatFade)
