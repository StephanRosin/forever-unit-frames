-- A click-casting spell kept at a fixed rank (Raid/ClickCast.lua,
-- Raid/ClickKeys.lua): stored as its spell ID ("spell:6074"), cast
-- exactly so (the client's SECURE_ACTIONS.spell casts a number with
-- CastSpellByID); a key casts "Name(Rank text)". The highest rank is the
-- spell's name, as before.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, Keys = ns.RaidConfig, ns.ClickKeys
for _, id in ipairs({ 139, 6074, 2061 }) do M.known[id] = true end
M.SetRaidRoster({ { name = "A", class = "PRIEST", subgroup = 1, unit = { health = 1, healthMax = 1 } } })
M.RunTimers()
local cell = ns.RaidCell.buttons[1]

-- Max: the name, cast by name (the highest rank the client knows).
RC.Set("general", "click1Shift", "spell:Renew")
H.check("max: the name", cell:GetAttribute("shift-spell1"), "Renew")
M.shiftDown = true
H.check("max: a spell cast", M.SecureClick(cell, "LeftButton"), "spell")
H.check("by name", M.casts[#M.casts][1], "Renew")
-- A fixed rank: its ID, cast by ID.
RC.Set("general", "click1Shift", "spell:139")
H.check("rank: the ID", cell:GetAttribute("shift-spell1"), "139")
M.SecureClick(cell, "LeftButton")
H.check("by ID", M.casts[#M.casts][1], 139)
M.shiftDown = false

-- Keys: the rank by its text, as /cast takes it.
H.check("key: max", Keys.MacroText("spell:Renew"), "/cast [@mouseover,help,nodead] Renew")
H.check("key: a rank", Keys.MacroText("spell:139"), "/cast [@mouseover,help,nodead] Renew(Rank 1)")
H.check("key: a spell without rank text", Keys.MacroText("spell:2061"), "/cast [@mouseover,help,nodead] Flash Heal")
-- A rank no longer learned: its name (the highest rank known).
M.known[139] = nil
H.check("key: an unlearned rank by name", Keys.MacroText("spell:139"), "/cast [@mouseover,help,nodead] Renew")
H.check("key: an unknown ID", Keys.MacroText("spell:999999"), nil)
M.known[139] = true

-- The keys follow the spell book: built before it was read, set again
-- once it changes.
RC.Set("general", "clickKey1", "F")
M.known[139] = nil
RC.Set("general", "clickKey1Bind", "spell:139")
local b1 = _G.ForeverUnitFramesClickKey1
H.check("before: the name", b1:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead] Renew")
M.known[139] = true
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.check("after SPELLS_CHANGED: the rank", b1:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead] Renew(Rank 1)")
H.check("nothing blocked", #M.blocked, 0)

-- The rank text not loaded yet (the client hands "" until
-- SPELL_TEXT_UPDATE): a fixed rank never falls back to the name (Max);
-- the key waits, unbound, until the text arrives.
M.spellTextPending[139] = true
H.check("pending: no macro", Keys.MacroText("spell:139"), nil)
H.check("pending: max unaffected", Keys.MacroText("spell:Renew"), "/cast [@mouseover,help,nodead] Renew")
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.check("pending: the key not bound", GetBindingAction("F", true), "")
M.SpellTextArrives(139)
M.RunTimers()
H.check("text arrived: the rank", b1:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead] Renew(Rank 1)")
H.check("text arrived: bound", GetBindingAction("F", true), "CLICK ForeverUnitFramesClickKey1:LeftButton")
-- A spell of one rank has no rank text to wait for.
M.spellTextPending[2061] = true
H.check("one rank: the name", Keys.MacroText("spell:2061"), "/cast [@mouseover,help,nodead] Flash Heal")
M.spellTextPending[2061] = nil
-- The words while pending: the ID instead of the text.
M.spellTextPending[6074] = true
H.check("pending words", ns.RaidSchema.BindingText("spell:6074"), "Cast a spell: Renew (6074)")
M.spellTextPending[6074] = nil
