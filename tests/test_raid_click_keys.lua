-- Keys on mouse-over (Raid/ClickKeys.lua): a hidden secure button per key
-- with a /cast [@mouseover,help,nodead] macro, bound with an override
-- binding while the raid frames show; set and cleared out of combat only.
local M = H.M
local ns = H.LoadAddon()
local RC, Keys = ns.RaidConfig, ns.ClickKeys
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
ns.RaidHeader.Create()
ns.Party.Create()

H.check("spell macro", Keys.MacroText("spell:Renew"), "/cast [@mouseover,help,nodead] Renew")
H.check("item macro", Keys.MacroText("item:Linen Bandage"), "/use [@mouseover,help,nodead] Linen Bandage")
H.check("item by ID", Keys.MacroText("item:1251"), "/use [@mouseover,help,nodead] item:1251")
H.check("own macro", Keys.MacroText("macro:/cast [@mouseover] Heal"), "/cast [@mouseover] Heal")
H.check("nothing", Keys.MacroText(""), nil)
H.check("no spell yet", Keys.MacroText("spell:"), nil)

RC.Set("general", "clickKey1", "F")
RC.Set("general", "clickKey1Bind", "spell:Renew")
RC.Set("general", "clickKey2", "SHIFT-F")
RC.Set("general", "clickKey2Bind", "macro:/say hi")
RC.Set("general", "clickKey3", "G")
-- Solo: the raid frames do not show, no key is taken.
H.check("solo: F keeps its binding", GetBindingAction("F", true), "")

-- In a raid: bound.
M.SetRaidRoster({ { name = "A", class = "PRIEST", subgroup = 1, unit = { health = 1, healthMax = 1 } } })
M.RunTimers()
H.check("F clicks key 1", GetBindingAction("F", true), "CLICK ForeverUnitFramesClickKey1:LeftButton")
H.check("SHIFT-F clicks key 2", GetBindingAction("SHIFT-F", true), "CLICK ForeverUnitFramesClickKey2:LeftButton")
H.check("G has no binding: not taken", GetBindingAction("G", true), "")
local b1 = _G.ForeverUnitFramesClickKey1
H.check("a secure action button", b1._template, "SecureActionButtonTemplate")
H.check("runs a macro", b1:GetAttribute("type"), "macro")
H.check("its text", b1:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead] Renew")
H.check("key down and up", table.concat(b1._clicks, ","), "AnyUp,AnyDown")
H.check("no mouse on it", b1._mouse, false)

-- A change re-binds; a key taken away is free again.
RC.Set("general", "clickKey1", "R")
H.check("F free again", GetBindingAction("F", true), "")
H.check("R clicks key 1", GetBindingAction("R", true), "CLICK ForeverUnitFramesClickKey1:LeftButton")

-- In combat the bindings stay as they were; after combat they follow.
M.SetCombat(true)
RC.Set("general", "clickKey1", "T")
M.SetRaidRoster({})
M.SetRaid(false)
M.FireEvent("GROUP_ROSTER_UPDATE")
H.check("in combat: kept", GetBindingAction("R", true), "CLICK ForeverUnitFramesClickKey1:LeftButton")
H.check("nothing blocked", #M.blocked, 0)
M.SetCombat(false)
H.check("after combat, solo: none", GetBindingAction("T", true) .. GetBindingAction("R", true), "")

-- Off: no key taken.
M.SetRaidRoster({ { name = "A", class = "PRIEST", subgroup = 1, unit = { health = 1, healthMax = 1 } } })
M.RunTimers()
H.check("in a raid again", GetBindingAction("T", true), "CLICK ForeverUnitFramesClickKey1:LeftButton")
RC.Set("general", "clickCast", "OFF")
H.check("off: none", GetBindingAction("T", true), "")
RC.Set("general", "clickCast", "AUTO")

-- A party without the raid view: bound while the party frames take the
-- bindings.
M.SetRaidRoster({})
M.SetRaid(false)
M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
M.SetGroup({ "party1" })
M.RunTimers()
H.check("party: bound", GetBindingAction("T", true), "CLICK ForeverUnitFramesClickKey1:LeftButton")
RC.Set("general", "clickCastParty", false)
H.check("party switched off: none", GetBindingAction("T", true), "")

-- The warning: a key the player has bound to something else.
H.check("W is taken", Keys.Taken("W"), "MOVEFORWARD")
H.check("T is free", Keys.Taken("T"), nil)
H.check("nothing", Keys.Taken(""), nil)
H.check("nothing blocked at all", #M.blocked, 0)

-- Keys only while our frames show: the raid frames, or the party frames
-- (not merely being in a group).
RC.Set("general", "clickCastParty", true)
RC.Set("general", "enabled", false)
H.check("party, raid frames off, party frames shown: bound", GetBindingAction("T", true),
    "CLICK ForeverUnitFramesClickKey1:LeftButton")
ns.Config.Set("party", "enabled", false)
M.RunTimers()
H.check("party frames off too: none", GetBindingAction("T", true), "")
ns.Config.Set("party", "enabled", true)
M.RunTimers()
H.check("party frames back: bound", GetBindingAction("T", true), "CLICK ForeverUnitFramesClickKey1:LeftButton")
-- A raid: the party frames hide in raids (the default), the raid frames
-- are off: nothing shows, no key is taken.
M.SetGroup({})
M.SetRaidRoster({ { name = "A", class = "PRIEST", subgroup = 1, unit = { health = 1, healthMax = 1 } } })
M.RunTimers()
H.check("party frames hidden in the raid", ns.Party.header:IsVisible(), false)
H.check("raid, nothing of ours shows: none", GetBindingAction("T", true), "")
RC.Set("general", "enabled", true)
M.RunTimers()
H.check("raid frames on: bound", GetBindingAction("T", true), "CLICK ForeverUnitFramesClickKey1:LeftButton")
H.check("nothing blocked at the end", #M.blocked, 0)
