-- Click-casting on the unit frames (decision 76): one unit-frame setting,
-- clickCast (General, inherited by every frame, overridable per frame),
-- on by default. The raid window's bindings go onto the player, pet,
-- target, target of target, focus and party member buttons whose value is
-- on; off, they get exactly their own attributes back. With the default
-- bindings nothing changes (left target, right menu). The raid setting
-- clickCastParty is migrated once per account (a stored false is the
-- party's override) and no longer shown; strings drop it.
local M = H.M

local function login(db, name)
    local ns = H.LoadAddon()
    if name then M.playerName = name end
    _G.ForeverUnitFramesDB = db
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local ns = login({})
local S, C, RC, L = ns.Settings, ns.Config, ns.RaidConfig, ns.L
local def = S.Get("clickCast")
H.checkTrue("setting", def)
H.check("code", def and def.code, "CK")
H.check("inherit", def and def.scope, "inherit")
H.check("on by default", C.Get("target", "clickCast"), true)

local SINGLE = { "player", "pet", "target", "targettarget", "focus" }
M.units.player = { name = "Me", health = 5, healthMax = 10 }
M.units.pet = { name = "Cat", health = 5, healthMax = 10 }
M.units.target = { name = "Ann", health = 5, healthMax = 10 }
M.units.targettarget = { name = "Bob", health = 5, healthMax = 10 }
M.units.focus = { name = "Cid", health = 5, healthMax = 10 }
M.units.party1 = { name = "Dee", health = 5, healthMax = 10 }
M.SetGroup({ "party1" })
M.FireEvent("UNIT_PET", "player")
M.FireEvent("PLAYER_TARGET_CHANGED")
M.FireEvent("PLAYER_FOCUS_CHANGED")
M.RunTimers()
local function frameOf(key)
    if key == "party" then return ns.Party.header:GetAttribute("child1") end
    return ns.Frames[key]
end
local ALL = { "player", "pet", "target", "targettarget", "focus", "party" }

-- Default bindings: every frame as before (left target, right menu).
for _, key in ipairs(ALL) do
    local f = frameOf(key)
    H.checkTrue(key .. ": exists", f)
    H.check(key .. ": left targets", f:GetAttribute("*type1"), "target")
    H.check(key .. ": right menu", f:GetAttribute("*type2"), "togglemenu")
    H.check(key .. ": nothing else", f:GetAttribute("ctrl-type1"), nil)
end

-- A binding reaches every frame.
RC.Set("general", "click1Ctrl", "assist")
M.RunTimers()
for _, key in ipairs(ALL) do H.check(key .. ": the binding", frameOf(key):GetAttribute("ctrl-type1"), "assist") end
-- Off on General: every frame back to its own attributes.
C.Set("general", "clickCast", false)
M.RunTimers()
for _, key in ipairs(ALL) do
    local f = frameOf(key)
    H.check(key .. " off: binding gone", f:GetAttribute("ctrl-type1"), nil)
    H.check(key .. " off: left targets", f:GetAttribute("*type1"), "target")
    H.check(key .. " off: right menu", f:GetAttribute("*type2"), "togglemenu")
end
-- A frame's own value over General's.
C.Set("focus", "clickCast", true)
M.RunTimers()
H.check("focus override on", frameOf("focus"):GetAttribute("ctrl-type1"), "assist")
H.check("target follows General", frameOf("target"):GetAttribute("ctrl-type1"), nil)
C.Set("general", "clickCast", true)
C.Set("target", "clickCast", false)
M.RunTimers()
H.check("target override off", frameOf("target"):GetAttribute("ctrl-type1"), nil)
H.check("player follows General", frameOf("player"):GetAttribute("ctrl-type1"), "assist")
C.ClearOverride("target", "clickCast")
M.RunTimers()
H.check("target inherits again", frameOf("target"):GetAttribute("ctrl-type1"), "assist")

-- In combat: after combat.
M.SetCombat(true)
C.Set("player", "clickCast", false)
M.RunTimers()
H.check("combat: unchanged", frameOf("player"):GetAttribute("ctrl-type1"), "assist")
M.SetCombat(false)
M.RunTimers()
H.check("after combat: off", frameOf("player"):GetAttribute("ctrl-type1"), nil)
C.ClearOverride("player", "clickCast")
M.RunTimers()

-- Party pets and targets: never (their own rules).
for _, b in ipairs(ns.PartyPets and ns.PartyPets.buttons or {}) do
    H.check("party pet untouched", b:GetAttribute("ctrl-type1"), nil)
end
-- Click-casting itself off: nothing anywhere.
RC.Set("general", "clickCast", "OFF")
M.RunTimers()
H.check("mode off", frameOf("pet"):GetAttribute("ctrl-type1"), nil)
RC.Set("general", "clickCast", "AUTO")
M.RunTimers()
H.check("mode back", frameOf("pet"):GetAttribute("ctrl-type1"), "assist")

-- Options: General shows the switch (the bindings have a tab of their
-- own, test_unit_click_cast_tab.lua); each frame as an inherited row.
local Options = ns.Options
Options.Open("general", "frames")
local row
for _, r in ipairs(Options.rows) do
    if r.key == "clickCast" then row = r end
end
H.checkTrue("general: the row", row)
H.check("general: label", row and row.label:GetText(), L.SETTING_clickCast)
H.check("general: no inherit marker", row and row.inherited, nil)
RC.Set("general", "clickCast", "OFF")
H.check("greyed while click-casting is off", row.enabledState, false)
RC.Set("general", "clickCast", "AUTO")
H.check("active again", row.enabledState, true)
-- Automatic with Clique loaded binds nothing either: greyed too.
M.loadedAddons.Clique = true
RC.Set("general", "clickCast", "ON")
RC.Set("general", "clickCast", "AUTO")
H.check("greyed: automatic with Clique", row.enabledState, false)
RC.Set("general", "clickCast", "ON")
H.check("on with Clique: active", row.enabledState, true)
M.loadedAddons.Clique = nil
RC.Set("general", "clickCast", "AUTO")
H.check("without Clique: active", row.enabledState, true)
-- No button to the raid window any more: the editor is a tab here.
local button
for _, r in ipairs(Options.rows) do if r.editBindings then button = r.editBindings end end
H.check("general: no button to the raid window", button, nil)
for _, key in ipairs({ "player", "pet", "target", "targettarget", "focus", "party" }) do
    Options.Open(key, "layout")
    local r
    for _, x in ipairs(Options.rows) do if x.key == "clickCast" then r = x end end
    H.checkTrue(key .. ": inherited row", r and r.inherited)
end
-- The raid window shows the old switch no more.
ns.RaidOptions.Open(nil, "clickCast")
local old
for _, r in ipairs(ns.RaidOptions.rows or {}) do if r.key == "clickCastParty" then old = r end end
H.check("raid window: no party switch", old, nil)
ns.RaidOptions.Close()
H.check("no errors", #M.errors, 0)
H.check("nothing blocked", #M.blocked, 0)

-- Migration, once per account at the first login with this version:
-- every character's stored value goes; a stored false anywhere is the
-- party's override off.
ns = login({ profile = {}, raid = { ["Tester-Testrealm"] = { general = { clickCastParty = false } } } })
H.check("migrated: party off", ns.Config.Get("party", "clickCast"), false)
H.check("migrated: overridden", ns.Config.IsOverridden("party", "clickCast"), true)
H.check("migrated: General still on", ns.Config.Get("general", "clickCast"), true)
H.check("the raid value retired", ForeverUnitFramesDB.raid["Tester-Testrealm"].general.clickCastParty, nil)
H.check("done for the account", ForeverUnitFramesDB.clickCastPartyRetired, true)
ns.Config.Set("party", "clickCast", true)
M.RunTimers()
local saved = ForeverUnitFramesDB
ns = login(saved)
H.check("once only", ns.Config.Get("party", "clickCast"), true)
ns = login({ profile = {}, raid = { ["Tester-Testrealm"] = { general = { clickCastParty = true } } } })
H.check("a stored true: nothing to do", ns.Config.IsOverridden("party", "clickCast"), false)
H.check("a stored true: removed", ForeverUnitFramesDB.raid["Tester-Testrealm"].general.clickCastParty, nil)
-- An alt's stored false is read at the first login of any character; the
-- alt's own later login does not undo a choice made since.
ns = login({ profile = {}, raid = { ["Tester-Testrealm"] = { general = {} },
    ["Alt-Testrealm"] = { general = { clickCastParty = false } } } })
H.check("alt's false: party off", ns.Config.Get("party", "clickCast"), false)
H.check("alt's value removed", ForeverUnitFramesDB.raid["Alt-Testrealm"].general.clickCastParty, nil)
ns.Config.Set("party", "clickCast", true)
M.RunTimers()
saved = ForeverUnitFramesDB
ns = login(saved, "Alt")
H.check("the alt logs in", ns.RaidProfiles.CharKey(), "Alt-Testrealm")
H.check("the alt keeps the choice", ns.Config.Get("party", "clickCast"), true)
-- A value appearing after the migration (an older version on another
-- computer) is cleaned away, never read.
saved = ForeverUnitFramesDB
saved.raid["Alt-Testrealm"].general.clickCastParty = false
ns = login(saved, "Alt")
H.check("later value: choice kept", ns.Config.Get("party", "clickCast"), true)
H.check("later value: cleaned", ForeverUnitFramesDB.raid["Alt-Testrealm"].general.clickCastParty, nil)
-- An old raid string with the setting still reads: the code is known, its
-- value dropped and not counted as lost.
H.checkTrue("old code readable", ns.RaidSettings.ByCode("HP"))
local old, err, rejected = ns.RaidCodec.Decode("1;gHP0;gHA2")
H.check("old string: no error", err, nil)
H.check("old string: nothing lost", rejected, 0)
H.check("old string: the retired value dropped", old and old.general.clickCastParty, nil)
H.check("old string: the rest read", old and old.general.clickCast, "ON")
