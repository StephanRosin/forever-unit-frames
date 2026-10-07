-- The smart buff key (Raid/SmartBuff.lua): a hidden secure button whose
-- spell and unit are set out of combat to the best next cast, clicked by
-- an override binding on the key; at the start of combat it is emptied, so
-- the key does nothing until combat ends.
local M = H.M
local ns = H.LoadAddon()
local RC, Watch, Smart = ns.RaidConfig, ns.RaidBuffWatch, ns.SmartBuff
ns.Config.Use({})
ns.RaidProfiles.Attach({})

M.units.player = { name = "Tester", class = "PRIEST", className = "Priest", isPlayer = true, auras = {} }
M.known[1243] = true

-- Made out of combat at login (Core/Boot.lua).
H.check("not made at load", _G[Smart.BUTTON_NAME], nil)
Smart.Update()
local b = _G[Smart.BUTTON_NAME]
H.checkTrue("the button", b)
H.check("a secure action button", b._template, "SecureActionButtonTemplate")
H.check("key down and up", table.concat(b._clicks, ","), "AnyUp,AnyDown")
H.check("no mouse on it", b._mouse, false)

-- No key: nothing bound.
RC.Set("general", "buffKey", "SHIFT-B")
H.check("solo: the key keeps its binding", GetBindingAction("SHIFT-B", true), "")

-- A party with someone who needs Fortitude.
M.units.party1 = { name = "Ann", class = "MAGE", className = "Mage", isPlayer = true, auras = {}, distance = 10 }
M.units.player.auras = { { name = "Power Word: Fortitude", spellId = 1243, isHelpful = true,
    expirationTime = M.now + 1700 } }
M.SetGroup({ "party1" })
M.Tick(1)
H.check("bound in a group", GetBindingAction("SHIFT-B", true), "CLICK " .. Smart.BUTTON_NAME .. ":LeftButton")
H.check("casts a spell", b:GetAttribute("type"), "spell")
H.check("the rank's ID", b:GetAttribute("spell"), 1243)
H.check("on Ann", b:GetAttribute("unit"), "party1")
H.check("the key casts", M.PressBinding("SHIFT-B"), "spell")
H.check("once", #M.casts, 1)
H.check("Fortitude on Ann", M.casts[1][1] .. "@" .. M.casts[1][2], "1243@party1")
-- What the next press does, in words.
H.check("described", Smart.Describe(Watch.Next()), "Power Word: Fortitude: Ann")

-- Everyone buffed: nothing to cast, the key does nothing.
M.units.party1.auras = { { name = "Power Word: Fortitude", spellId = 1243, isHelpful = true,
    expirationTime = M.now + 1700 } }
M.FireEvent("UNIT_AURA", "party1")
M.Tick(1)
H.check("nobody needs it: no type", b:GetAttribute("type"), nil)
H.check("no spell", b:GetAttribute("spell"), nil)
H.check("the key does nothing", M.PressBinding("SHIFT-B"), nil)
H.check("still one cast", #M.casts, 1)

-- Combat: emptied as it starts (lockdown follows PLAYER_REGEN_DISABLED);
-- the key stays bound but does nothing; after combat it casts again.
M.units.party1.auras = {}
M.FireEvent("UNIT_AURA", "party1")
M.Tick(1)
H.check("needed again", b:GetAttribute("unit"), "party1")
M.FireEvent("PLAYER_REGEN_DISABLED")
M.SetCombat(true)
H.check("combat: emptied", b:GetAttribute("type"), nil)
H.check("combat: still bound", GetBindingAction("SHIFT-B", true), "CLICK " .. Smart.BUTTON_NAME .. ":LeftButton")
H.check("combat: the key does nothing", M.PressBinding("SHIFT-B"), nil)
M.FireEvent("UNIT_AURA", "party1")
M.Tick(1)
H.check("combat: nothing set", b:GetAttribute("type"), nil)
H.check("nothing blocked", #M.blocked, 0)
M.SetCombat(false)
M.Tick(1)
H.check("after combat: set again", b:GetAttribute("unit"), "party1")

-- Another key: bound anew, the old one free; no key: nothing bound.
RC.Set("general", "buffKey", "CTRL-B")
H.check("old key free", GetBindingAction("SHIFT-B", true), "")
H.check("new key", GetBindingAction("CTRL-B", true), "CLICK " .. Smart.BUTTON_NAME .. ":LeftButton")
RC.Set("general", "buffKey", "")
H.check("no key", GetBindingAction("CTRL-B", true), "")
RC.Set("general", "buffKey", "CTRL-B")
-- Nothing watched (fortitude off): no key taken.
RC.Set("general", "buffFortitude", false)
M.Tick(1)
H.check("nothing watched: free", GetBindingAction("CTRL-B", true), "")
RC.Set("general", "buffFortitude", true)
M.Tick(1)
H.check("watched again: bound", GetBindingAction("CTRL-B", true), "CLICK " .. Smart.BUTTON_NAME .. ":LeftButton")
-- Solo: free.
M.SetGroup({})
M.Tick(1)
H.check("solo: free", GetBindingAction("CTRL-B", true), "")
-- Raid frames off altogether: free.
M.SetGroup({ "party1" })
M.Tick(1)
RC.Set("general", "enabled", false)
M.Tick(1)
H.check("raid frames off: free", GetBindingAction("CTRL-B", true), "")
H.check("no error", #M.errors, 0)
