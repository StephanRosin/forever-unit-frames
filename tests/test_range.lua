-- Range fading (Elements/Range.lua): party members, target, focus and
-- pets beyond range are drawn at a lower opacity. Settings, the poll, the
-- two range sources, secrets, combat and test mode.
local M = H.M

local function boot()
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "WARRIOR", className = "WARRIOR", isPlayer = true, health = 1,
        healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

-- Settings -----------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local S = ns.Settings
    local CODES = { rangeFade = "VE", rangeAlpha = "VA" }
    for key, code in pairs(CODES) do
        local def = S.Get(key)
        H.checkTrue("setting " .. key, def)
        H.check("code of " .. key, def and def.code, code)
        for _, scope in ipairs({ "party", "target", "focus", "pet" }) do
            H.checkTrue(key .. " on " .. scope, S.AppliesTo(def, scope))
        end
        for _, scope in ipairs({ "general", "player", "targettarget" }) do
            H.check(key .. " not on " .. scope, S.AppliesTo(def, scope), false)
        end
        H.checkTrue(key .. " label", ns.L["SETTING_" .. key] ~= "SETTING_" .. key)
    end
    H.check("on by default: party", S.Default(S.Get("rangeFade"), "party"), true)
    H.check("on by default: pet", S.Default(S.Get("rangeFade"), "pet"), true)
    -- Enemies only have the follow distance: opt-in.
    H.check("off by default: target", S.Default(S.Get("rangeFade"), "target"), false)
    H.check("off by default: focus", S.Default(S.Get("rangeFade"), "focus"), false)
    H.check("half opacity by default", S.Default(S.Get("rangeAlpha"), "party"), 50)
    H.check("opacity from 0", S.Get("rangeAlpha").min, 0)
    H.check("opacity to 100", S.Get("rangeAlpha").max, 100)
    local found
    for _, tab in ipairs(ns.Schema.Tabs("party")) do
        for _, sec in ipairs(tab.sections or {}) do
            if sec.id == "range" then found = tab.id end
        end
    end
    H.check("range section on the status tab", found, "status")
    H.check("section label", ns.L.SECTION_range, "Range")
end

-- Defaults add nothing to a saved profile.
do
    local ns = boot()
    local C = ns.Config
    C.Set("party", "rangeFade", true)
    C.Set("target", "rangeFade", false)
    C.Set("target", "rangeAlpha", 50)
    for scope, values in pairs(C.Profile()) do
        for key in pairs(values) do
            H.checkTrue("no range key stored for defaults: " .. scope .. "." .. key, not key:match("^range"))
        end
    end
    H.checkTrue("export without range codes", not ns.Codec.Encode(C.Profile()):find("V[EA]"))
end

-- Party members: UnitInRange --------------------------------------------------------
do
    local ns = boot()
    M.units.party1 = { name = "Ann", isPlayer = true, health = 5, healthMax = 10 }
    M.SetGroup({ "party1" })
    local b = ns.Party.buttons[1]
    H.check("in range: full", b:GetAlpha(), 1)
    M.units.party1.inRange = false
    M.Tick(0.1)
    H.check("not yet checked again", b:GetAlpha(), 1)
    M.Tick(0.15)
    H.check("out of range: faded", b:GetAlpha(), 0.5)
    M.units.party1.inRange = true
    M.Tick(0.25)
    H.check("back in range", b:GetAlpha(), 1)

    -- A new unit on the button is checked at once.
    M.units.party1.inRange = false
    M.FireEvent("GROUP_ROSTER_UPDATE")
    H.check("roster change checks at once", b:GetAlpha(), 0.5)

    -- A secret "in range" (checked plainly) goes to SetAlphaFromBoolean
    -- untouched.
    M.rangeSecret = "inRange"
    M.combat = true
    local ok, err = pcall(M.Tick, 0.25)
    H.check("secret: no error", ok and "ok" or tostring(err), "ok")
    H.check("secret: faded", b:GetAlpha(), 0.5)
    H.check("secret: through SetAlphaFromBoolean", b._alphaSecret, true)
    H.check("combat: nothing blocked", #M.blocked, 0)
    M.units.party1.inRange = true
    M.Tick(0.25)
    H.check("secret: back", b:GetAlpha(), 1)
    -- A secret "checked": the range is unknown, full opacity.
    M.rangeSecret = true
    M.units.party1.inRange = false
    ok = pcall(M.Tick, 0.25)
    H.check("secret checked: no error", ok, true)
    H.check("secret checked: full", b:GetAlpha(), 1)
    M.rangeSecret = false
    M.SetCombat(false)

    -- Unchecked: full opacity.
    M.units.party1.rangeChecked = false
    M.units.party1.inRange = false
    M.Tick(0.25)
    H.check("unchecked: full", b:GetAlpha(), 1)
    M.units.party1.rangeChecked = nil

    -- The opacity setting and the switch.
    ns.Config.Set("party", "rangeAlpha", 30)
    M.Tick(0.25)
    H.check("own opacity", b:GetAlpha(), 0.3)
    ns.Config.Set("party", "rangeFade", false)
    H.check("off: full at once", b:GetAlpha(), 1)
    M.Tick(0.25)
    H.check("off: stays full", b:GetAlpha(), 1)
    ns.Config.Set("party", "rangeFade", true)

    -- The player's own slot never fades.
    ns.Config.Set("party", "partyShowPlayer", true)
    for _, button in ipairs(ns.Party.buttons) do
        if button.unit == "player" then
            M.Tick(0.25)
            H.check("player slot: full", button:GetAlpha(), 1)
        end
    end
end

-- Target, focus and pet: UnitInRange for group members, else the
-- interaction distance.
do
    local ns = boot()
    local f = ns.Frames.target
    M.units.target = { name = "Boar", health = 5, healthMax = 10, near = false }
    M.FireEvent("PLAYER_TARGET_CHANGED")
    H.check("off by default: far enemy full", f:GetAlpha(), 1)
    ns.Config.Set("target", "rangeFade", true)
    M.FireEvent("PLAYER_TARGET_CHANGED")
    H.check("far enemy: faded", f:GetAlpha(), 0.5)
    M.units.target.near = true
    M.Tick(0.25)
    H.check("near enemy: full", f:GetAlpha(), 1)
    -- No answer: full opacity (only a plain true or false counts).
    M.units.target.near = "nil"
    M.Tick(0.25)
    H.check("no answer: full", f:GetAlpha(), 1)
    M.units.target.near = M.Secret(false)
    M.Tick(0.25)
    H.check("secret answer: full", f:GetAlpha(), 1)
    M.units.target.near = false
    M.Tick(0.25)
    H.check("far again", f:GetAlpha(), 0.5)
    -- A party member as target: the group range.
    M.units.target = { name = "Ann", isPlayer = true, health = 5, healthMax = 10, inParty = true, inRange = false,
        near = true }
    M.FireEvent("PLAYER_TARGET_CHANGED")
    H.check("group member target: group range", f:GetAlpha(), 0.5)
    -- Yourself as target: never faded.
    M.units.target = M.units.player
    M.units.player.near = false
    M.FireEvent("PLAYER_TARGET_CHANGED")
    H.check("targeting yourself", f:GetAlpha(), 1)
    M.units.player.near = nil

    -- Refused once: full opacity, and never asked again this session.
    M.units.target = { name = "Boar", health = 5, healthMax = 10, near = false }
    M.FireEvent("PLAYER_TARGET_CHANGED")
    M.interactError = true
    local ok = pcall(M.Tick, 0.25)
    H.check("refused: no error", ok, true)
    H.check("refused: full", f:GetAlpha(), 1)
    M.interactError = false
    local asked = M.interactQueries
    M.Tick(0.25)
    M.Tick(0.25)
    H.check("refused: not asked again", M.interactQueries, asked)
    H.check("refused: stays full", f:GetAlpha(), 1)

    -- Pet and focus.
    M.units.pet = { name = "Wolf", health = 5, healthMax = 10, inParty = true, inRange = false }
    M.FireEvent("UNIT_PET", "player")
    H.check("far pet: faded", ns.Frames.pet:GetAlpha(), 0.5)
    -- The player frame and the target of target never fade.
    M.units.player.near = false
    M.units.targettarget = { name = "Bob", health = 5, healthMax = 10, near = false }
    M.Tick(0.25)
    H.check("player frame: full", ns.Frames.player:GetAlpha(), 1)
    H.check("target of target: full", ns.Frames.targettarget:GetAlpha(), 1)
end

-- Test mode: one pretend member out of range.
do
    local ns = boot()
    H.checkTrue("test mode on", ns.TestMode.Set(true))
    local fakes = ns.Party.fakes
    H.check("member 4 out of range", fakes[4]:GetAlpha(), 0.5)
    H.check("member 1 in range", fakes[1]:GetAlpha(), 1)
    H.check("target in range", ns.Frames.target:GetAlpha(), 1)
    M.Tick(0.25)
    H.check("the poll leaves the sample alone", fakes[4]:GetAlpha(), 0.5)
    ns.Config.Set("party", "rangeAlpha", 20)
    H.check("sample follows the setting", fakes[4]:GetAlpha(), 0.2)
    ns.TestMode.Set(false)
    H.check("off: back to full", fakes[4]:GetAlpha(), 1)
end

-- Blocked by the client (ADDON_ACTION_BLOCKED naming the call): never
-- asked again.
do
    local ns = boot()
    ns.Config.Set("target", "rangeFade", true)
    M.units.target = { name = "Boar", health = 5, healthMax = 10, near = false }
    M.FireEvent("PLAYER_TARGET_CHANGED")
    H.check("far enemy faded", ns.Frames.target:GetAlpha(), 0.5)
    M.FireEvent("ADDON_ACTION_BLOCKED", "SomeOtherAddon", "CheckInteractDistance()")
    local asked = M.interactQueries
    M.Tick(0.25)
    H.check("another addon blocked: still asked", M.interactQueries > asked, true)
    M.FireEvent("ADDON_ACTION_BLOCKED", "ForeverUnitFrames", "CheckInteractDistance()")
    asked = M.interactQueries
    M.Tick(0.25)
    H.check("blocked: not asked again", M.interactQueries, asked)
    H.check("blocked: full", ns.Frames.target:GetAlpha(), 1)
end

-- No timer while fading is off on every frame.
do
    local ns = boot()
    local C = ns.Config
    M.units.party1 = { name = "Ann", isPlayer = true, health = 5, healthMax = 10 }
    M.SetGroup({ "party1" })
    H.checkTrue("timer runs", ns.Range.driver:IsShown())
    C.Set("party", "rangeFade", false)
    C.Set("pet", "rangeFade", false)
    H.check("all off: timer stopped", ns.Range.driver:IsShown(), false)
    local asked = M.rangeQueries
    M.Tick(0.25)
    H.check("all off: nothing asked", M.rangeQueries, asked)
    C.Set("focus", "rangeFade", true)
    H.check("one on: timer runs", ns.Range.driver:IsShown(), true)
end
