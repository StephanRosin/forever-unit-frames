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
-- A fixed rank: its ID, cast by ID. The client's IsSpellKnown may say no
-- for a rank a higher one supersedes (the mock does): the spell book
-- decides.
H.check("the mock: a lower rank not known", C_SpellBook.IsSpellKnown(139), false)
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
M.RunTimers(1)
H.check("pending: the key not bound", GetBindingAction("F", true), "")
M.SpellTextArrives(139)
M.RunTimers(1)
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

-- A fixed rank no longer known (a respec, a copied value): the cell and
-- the key both cast the spell's name (Max), the cell once the book says so.
RC.Set("general", "click1Shift", "spell:139")
H.check("known: the cell casts the ID", cell:GetAttribute("shift-spell1"), "139")
M.known[139] = nil
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.check("unknown rank: the cell casts the name", cell:GetAttribute("shift-spell1"), "Renew")
H.check("unknown rank: the key too", Keys.MacroText("spell:139"), "/cast [@mouseover,help,nodead] Renew")
M.known[139] = true
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.check("learned again: the ID", cell:GetAttribute("shift-spell1"), "139")
RC.Set("general", "click1Shift", "spell:999999")
H.check("an ID the client does not know: nothing", cell:GetAttribute("shift-type1"), nil)

-- The keys read the spell list once per update, however many hold a rank.
RC.Set("general", "clickKey2", "G")
RC.Set("general", "clickKey3", "H")
RC.Set("general", "clickKey3Bind", "spell:6074")
local reads, friendly = 0, ns.RaidSpellbook.FriendlySpells
ns.RaidSpellbook.FriendlySpells = function(...) reads = reads + 1; return friendly(...) end
RC.Set("general", "clickKey2Bind", "spell:139")
H.check("one read per update", reads, 1)
ns.RaidSpellbook.FriendlySpells = friendly

-- The text never arrives (no SPELL_TEXT_UPDATE, or two spells of one
-- name without rank texts): the key tries again a few times over about
-- ten seconds, then casts the bare name rather than stay unbound; once the
-- text comes it casts the rank again. Nothing is said in the chat.
RC.Set("general", "clickKey2Bind", "")
RC.Set("general", "clickKey3Bind", "")
RC.Set("general", "clickKey1Bind", "spell:139")
local chat = #M.chat
M.spellTextPending[139] = true
M.FireEvent("SPELLS_CHANGED")
M.RunTimers(1)
H.check("waiting: unbound", GetBindingAction("F", true), "")
-- One retry (a 2 s timer) alone.
for i, t in ipairs(M.timers) do
    if t.sec == 2 then
        table.remove(M.timers, i)
        t.fn()
        break
    end
end
M.RunTimers(1)
H.check("still waiting after a retry", GetBindingAction("F", true), "")
M.RunTimers()
H.check("given up: the bare name", b1:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead] Renew")
H.check("given up: bound", GetBindingAction("F", true), "CLICK ForeverUnitFramesClickKey1:LeftButton")
H.check("nothing in the chat", #M.chat, chat)
M.SpellTextArrives(139)
M.RunTimers()
H.check("text at last: the rank", b1:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead] Renew(Rank 1)")
-- And the next wait starts afresh.
M.spellTextPending[139] = true
M.FireEvent("SPELLS_CHANGED")
M.RunTimers(1)
H.check("a new wait: unbound again", GetBindingAction("F", true), "")
M.spellTextPending[139] = nil
M.RunTimers()
H.checkTrue("the text event registered (inspectable)", ns.RaidSpellbook.textEventRegistered)
