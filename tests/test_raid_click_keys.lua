-- Keys on mouse-over (Raid/ClickKeys.lua): a hidden secure button per key
-- with a /cast [@mouseover,help,nodead] macro; the key is bound only while
-- the mouse is over a frame that takes the click bindings (secure
-- snippets wrapped around its OnEnter, OnLeave and OnHide), in combat too.
local M = H.M
local ns = H.LoadAddon()
local RC, Keys = ns.RaidConfig, ns.ClickKeys
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

H.check("spell macro", Keys.MacroText("spell:Renew"), "/cast [@mouseover,help,nodead] Renew")
H.check("item macro", Keys.MacroText("item:Linen Bandage"), "/use [@mouseover,help,nodead] Linen Bandage")
H.check("item by ID", Keys.MacroText("item:1251"), "/use [@mouseover,help,nodead] item:1251")
H.check("own macro", Keys.MacroText("macro:/cast [@mouseover] Heal"), "/cast [@mouseover] Heal")
H.check("nothing", Keys.MacroText(""), nil)
H.check("no spell yet", Keys.MacroText("spell:"), nil)

local KEY1 = "CLICK ForeverUnitFramesClickKey1:LeftButton"
-- A key as bound while the mouse is over frame.
local function on(frame, key)
    M.Hover(frame)
    local action = GetBindingAction(key, true)
    M.Leave(frame)
    return action
end

RC.Set("general", "clickKey1", "F")
RC.Set("general", "clickKey1Bind", "spell:Renew")
RC.Set("general", "clickKey2", "SHIFT-F")
RC.Set("general", "clickKey2Bind", "macro:/say hi")
RC.Set("general", "clickKey3", "G")
M.RunTimers()

-- Solo, the player frame (CurseForge 20./21.11.2026: alone, the wheel on
-- yourself; the zoom elsewhere).
local player = ns.Frames.player
H.check("no frame under the mouse: F keeps its binding", GetBindingAction("F", true), "")
M.Hover(player)
H.check("over the player frame: F clicks key 1", GetBindingAction("F", true), KEY1)
H.check("SHIFT-F clicks key 2", GetBindingAction("SHIFT-F", true), "CLICK ForeverUnitFramesClickKey2:LeftButton")
H.check("G has no binding: not taken", GetBindingAction("G", true), "")
M.Leave(player)
H.check("left: F free again", GetBindingAction("F", true), "")
local b1 = _G.ForeverUnitFramesClickKey1
H.check("a secure action button", b1._template, "SecureActionButtonTemplate")
H.check("runs a macro", b1:GetAttribute("type"), "macro")
H.check("its text", b1:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead] Renew")
H.check("key down and up", table.concat(b1._clicks, ","), "AnyUp,AnyDown")
H.check("no mouse on it", b1._mouse, false)
-- The player frame's own clickCast off: not there.
ns.Config.Set("player", "clickCast", false)
M.RunTimers()
H.check("player clickCast off: none", on(player, "F"), "")
ns.Config.ClearOverride("player", "clickCast")
M.RunTimers()
H.check("player clickCast back", on(player, "F"), KEY1)

-- A raid cell; a frame hiding under the mouse lets go (no OnLeave then).
M.SetRaidRoster({ { name = "A", class = "PRIEST", subgroup = 1, unit = { health = 1, healthMax = 1 } } })
M.RunTimers()
local cell = ns.RaidCell.buttons[1]
H.check("over a cell", on(cell, "F"), KEY1)
M.Hover(cell)
cell:Hide()
H.check("cell hidden under the mouse: free", GetBindingAction("F", true), "")
cell:Show()
cell._mouseOver = nil

-- In combat: the snippets bind and free, nothing blocked.
M.SetCombat(true)
M.Hover(cell)
H.check("combat: bound", GetBindingAction("F", true), KEY1)
M.Leave(cell)
H.check("combat: free again", GetBindingAction("F", true), "")
-- A change in combat waits for its end.
RC.Set("general", "clickKey1", "R")
H.check("combat: the old key still", on(cell, "F"), KEY1)
M.SetCombat(false)
M.RunTimers()
H.check("after combat: the new key", on(cell, "R"), KEY1)
H.check("the old one gone", on(cell, "F"), "")
H.check("nothing blocked", #M.blocked, 0)

-- A frame under the mouse when the keys change takes them at once.
M.Hover(cell)
RC.Set("general", "clickKey1", "T")
M.RunTimers()
H.check("hovered while changed: the new key", GetBindingAction("T", true), KEY1)
H.check("hovered while changed: the old one free", GetBindingAction("R", true), "")
M.Leave(cell)

-- Off: no key taken anywhere.
RC.Set("general", "clickCast", "OFF")
M.RunTimers()
H.check("off: none on a cell", on(cell, "T"), "")
H.check("off: none on the player", on(player, "T"), "")
RC.Set("general", "clickCast", "AUTO")
M.RunTimers()
H.check("on again", on(cell, "T"), KEY1)
-- The raid frames off: the cells take none.
RC.Set("general", "enabled", false)
M.RunTimers()
H.check("raid frames off: the cell none", on(cell, "T"), "")
RC.Set("general", "enabled", true)
M.RunTimers()

-- A party member's frame, its party switch.
M.SetRaidRoster({})
M.SetRaid(false)
M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
M.SetGroup({ "party1" })
M.RunTimers()
local member = ns.Party.header:GetAttribute("child1")
H.check("over a party frame", on(member, "T"), KEY1)
ns.Config.Set("party", "clickCast", false)
M.RunTimers()
H.check("party switched off: none", on(member, "T"), "")
ns.Config.Set("party", "clickCast", true)
M.RunTimers()

-- The warning: a key the player has bound to something else.
H.check("W is taken", Keys.Taken("W"), "MOVEFORWARD")
H.check("T is free", Keys.Taken("T"), nil)
H.check("nothing", Keys.Taken(""), nil)
-- An unbound chord does what its key alone does (the client falls back):
-- taking it takes that.
H.check("SHIFT-W falls back to W", Keys.Taken("SHIFT-W"), "MOVEFORWARD")
H.check("ALT-CTRL-W too", Keys.Taken("ALT-CTRL-W"), "MOVEFORWARD")
M.bindings["CTRL-W"] = "TOGGLEWORLDMAP"
H.check("a bound chord: its own", Keys.Taken("CTRL-W"), "TOGGLEWORLDMAP")
M.bindings["CTRL-W"] = nil
H.check("SHIFT-T: free", Keys.Taken("SHIFT-T"), nil)
H.check("a sign after a modifier", Keys.Taken("CTRL--"), nil)
H.check("nothing blocked at all", #M.blocked, 0)
