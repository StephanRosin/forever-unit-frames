-- Click-casting on the party frames works while the raid frames are off
-- (decision 74): the party members get the bindings and the mouse-over
-- keys are bound while the party frames show. The raid cells' bindings
-- and keys still follow the raid frames.
local M = H.M

local function login(raidProfile)
    local ns = H.LoadAddon()
    _G.ForeverUnitFramesDB = { raid = { ["Tester-Testrealm"] = raidProfile } }
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

-- Raid frames off at login, party click-casting on (its default).
local ns = login({ general = { enabled = false, click1Ctrl = "assist", clickKey1 = "F",
    clickKey1Bind = "spell:Heal" } })
local RC, L = ns.RaidConfig, ns.L
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.SetGroup({ "party1" })
M.RunTimers()
local b1 = ns.Party.header:GetAttribute("child1")
H.check("raid off: no panel", ns.RaidHeader.anchor, nil)
H.check("raid off: party binding", b1:GetAttribute("ctrl-type1"), "assist")
H.check("raid off: left still targets", b1:GetAttribute("*type1"), "target")
H.check("raid off: key bound while the party shows", GetBindingAction("F", true),
    "CLICK ForeverUnitFramesClickKey1:LeftButton")
-- The party switch off: the XML's again, no key.
ns.Config.Set("party", "clickCast", false)
M.RunTimers()
H.check("party off: the XML's", b1:GetAttribute("ctrl-type1"), nil)
H.check("party off: no key", GetBindingAction("F", true), "")
ns.Config.Set("party", "clickCast", true)
M.RunTimers()
H.check("party on again", b1:GetAttribute("ctrl-type1"), "assist")
-- Click-casting switched off: nothing anywhere.
RC.Set("general", "clickCast", "OFF")
M.RunTimers()
H.check("mode off: the XML's", b1:GetAttribute("ctrl-type1"), nil)
H.check("mode off: no key", GetBindingAction("F", true), "")
RC.Set("general", "clickCast", "AUTO")
M.RunTimers()
-- Solo: the party frames do not show, no key.
M.SetGroup({})
M.RunTimers()
H.check("solo: no key", GetBindingAction("F", true), "")
M.SetGroup({ "party1" })
M.RunTimers()

-- The raid frames switched on and off again: the cells follow them, the
-- party keeps its bindings.
RC.Set("general", "enabled", true)
M.RunTimers()
RC.Set("general", "enabled", false)
M.RunTimers()
H.check("raid off again: party keeps its binding", b1:GetAttribute("ctrl-type1"), "assist")
for _, cell in ipairs(ns.RaidCell.buttons) do
    H.check("raid off: a cell has the XML's", cell:GetAttribute("ctrl-type1"), nil)
end
H.checkTrue("cells were made", #ns.RaidCell.buttons > 0)

H.check("no errors", #M.errors, 0)
H.check("nothing blocked", #M.blocked, 0)
