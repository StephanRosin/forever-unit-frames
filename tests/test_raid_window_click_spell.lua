-- The click-casting tab's spell and rank dropdowns (Raid/Options/
-- ClickCast.lua): for "Cast a spell" the value's box gives way to the
-- spell (the spell book's spells cast on others) and its rank (Max first,
-- greyed with one rank or none), together as wide as the box; "Other..."
-- shows the box for a spell typed as before. Items and macros keep the
-- box. Locked in combat. The binding's words name the rank.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
for _, id in ipairs({ 139, 6074, 2061, 585, 588 }) do M.known[id] = true end
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "A", class = "PRIEST", subgroup = 1, unit = { health = 1, healthMax = 1 } } })
M.RunTimers()
local RO, RC, L, Schema = ns.RaidOptions, ns.RaidConfig, ns.L, ns.RaidSchema

local function click(button) button:GetScript("OnClick")(button) end
local function rowFor(key)
    for _, row in ipairs(RO.rows) do if row.key == key then return row end end
end
-- The items of a dropdown's list, as their texts.
local function listed(button)
    click(button)
    local out = {}
    for _, r in ipairs(ns.Widgets.list.rows) do
        if r:IsShown() and r.item then out[#out + 1] = r.item.text end
    end
    ns.Widgets.CloseList()
    return table.concat(out, ",")
end
local function pick(button, text)
    click(button)
    for _, r in ipairs(ns.Widgets.list.rows) do
        if r:IsShown() and r.item and r.item.text == text then
            click(r)
            return true
        end
    end
    ns.Widgets.CloseList()
    return false
end
local function enter(box, text)
    M.Type(box, text)
    M.PressEnter(box)
end
local function shown(row)
    return (row.value:IsShown() and "box" or "") .. (row.spellDrop:IsShown() and "+spell" or "")
        .. (row.rankDrop:IsShown() and "+rank" or "")
end

RO.Open(nil, "clickCast")
local row = rowFor("click1Shift")
H.check("nothing bound: the box (locked)", shown(row), "box")
H.check("box as wide as before", row.value:GetWidth(), 400)

-- A spell: the two dropdowns instead of the box, as wide together.
H.checkTrue("pick a spell", pick(row.button, "Cast a spell"))
H.check("spell: the dropdowns", shown(row), "+spell+rank")
H.check("same width", row.spellDrop:GetWidth() + 8 + row.rankDrop:GetWidth(), 400)
H.check("no spell yet", row.spellDrop.text:GetText(), "")
H.check("the spells, Other last", listed(row.spellDrop), "Flash Heal,Renew,Other…")
H.check("no spell: no rank to pick", row.rankDrop:IsEnabled(), false)
H.checkTrue("pick Renew", pick(row.spellDrop, "Renew"))
H.check("stored by name (Max)", RC.Get("general", "click1Shift"), "spell:Renew")
H.check("rank: Max", row.rankDrop.text:GetText(), "Max")
H.check("two ranks: the rank can be picked", row.rankDrop:IsEnabled(), true)
H.check("Max first, then the ranks", listed(row.rankDrop), "Max,Rank 1,Rank 2")
H.checkTrue("pick Rank 1", pick(row.rankDrop, "Rank 1"))
H.check("stored by ID", RC.Get("general", "click1Shift"), "spell:139")
H.check("the cell casts that rank", ns.RaidCell.buttons[1]:GetAttribute("shift-spell1"), "139")
H.check("shows the spell", row.spellDrop.text:GetText(), "Renew")
H.check("and the rank", row.rankDrop.text:GetText(), "Rank 1")
H.check("words: the rank", Schema.BindingText(RC.Get("general", "click1Shift")), "Cast a spell: Renew (Rank 1)")
pick(row.rankDrop, "Max")
H.check("back to Max", RC.Get("general", "click1Shift"), "spell:Renew")
H.check("words: Max", Schema.BindingText(RC.Get("general", "click1Shift")), "Cast a spell: Renew")
-- One rank: greyed.
pick(row.spellDrop, "Flash Heal")
H.check("another spell", RC.Get("general", "click1Shift"), "spell:Flash Heal")
H.check("one rank: greyed", row.rankDrop:IsEnabled(), false)
H.checkTrue("dimmed", row.rankDrop:GetAlpha() < 1)
-- A fixed rank, then another spell: Max of that one.
pick(row.spellDrop, "Renew")
pick(row.rankDrop, "Rank 2")
H.check("rank 2", RC.Get("general", "click1Shift"), "spell:6074")
pick(row.spellDrop, "Flash Heal")
H.check("another spell starts at Max", RC.Get("general", "click1Shift"), "spell:Flash Heal")

-- Other...: the box for a spell typed (a harmful one here), kept beside it.
H.checkTrue("pick Other", pick(row.spellDrop, "Other…"))
H.check("other: the dropdown and the box", shown(row), "box+spell")
H.check("still as wide", row.spellDrop:GetWidth() + 8 + row.value:GetWidth(), 400)
H.check("the dropdown says Other", row.spellDrop.text:GetText(), "Other…")
H.check("the value kept meanwhile", RC.Get("general", "click1Shift"), "spell:Flash Heal")
H.check("the box can be typed in", row.value:IsEnabled(), true)
enter(row.value, "smite")
H.check("typed as before", RC.Get("general", "click1Shift"), "spell:Smite")
H.check("still Other", shown(row), "box+spell")
H.check("the box shows it", row.value:GetText(), "Smite")
enter(row.value, "Nope")
H.check("an unknown spell refused", RC.Get("general", "click1Shift"), "spell:Smite")
-- Typing a spell of the list goes back to the dropdowns.
enter(row.value, "renew")
H.check("typed a listed spell", RC.Get("general", "click1Shift"), "spell:Renew")
H.check("the dropdowns again", shown(row), "+spell+rank")
-- A stored spell the list does not hold shows under Other.
RC.Set("general", "click1Shift", "spell:Inner Fire")
H.check("self-only spell: Other", shown(row), "box+spell")
H.check("its name in the box", row.value:GetText(), "Inner Fire")
-- Back to a spell from the list.
pick(row.spellDrop, "Renew")
H.check("picked from the list", RC.Get("general", "click1Shift"), "spell:Renew")
H.check("the dropdowns", shown(row), "+spell+rank")

-- Items and macros keep the box.
pick(row.button, "Use an item")
H.check("item: the box", shown(row), "box")
H.check("item: full width", row.value:GetWidth(), 400)
pick(row.button, "Cast a spell")
H.check("a new spell kind: the dropdowns, nothing picked", shown(row) .. row.spellDrop.text:GetText(), "+spell+rank")

-- Keys: the same, in the key row's narrower width.
local key1 = rowFor("clickKey1")
pick(key1.button, "Cast a spell")
H.check("key: the dropdowns", shown(key1), "+spell+rank")
H.check("key: as wide as its box", key1.spellDrop:GetWidth() + 8 + key1.rankDrop:GetWidth(), 400 - 120 - 8)
pick(key1.spellDrop, "Renew")
pick(key1.rankDrop, "Rank 2")
H.check("key: by ID", RC.Get("general", "clickKey1Bind"), "spell:6074")

-- A rank learned while the window is open: offered at once.
pick(row.spellDrop, "Renew")
M.spells[10927] = { name = "Renew", maxRange = 40, subName = "Rank 3" }
M.known[10927] = true
M.FireEvent("SPELLS_CHANGED")
H.check("the new rank listed", listed(row.rankDrop), "Max,Rank 1,Rank 2,Rank 3")

-- Combat: all locked; after it, the rank as before.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("spell locked", row.spellDrop:IsEnabled(), false)
H.check("rank locked", row.rankDrop:IsEnabled(), false)
H.check("not dimmed twice: the row dims", row.rankDrop:GetAlpha(), 1)
M.SetCombat(false)
H.check("spell unlocked", row.spellDrop:IsEnabled(), true)
H.check("rank unlocked", row.rankDrop:IsEnabled(), true)

-- Shown again: Other... picked earlier is forgotten.
pick(row.spellDrop, "Other…")
RO.Close()
RO.Open(nil, "clickCast")
H.check("reopened: the dropdowns", shown(rowFor("click1Shift")), "+spell+rank")
H.check("nothing blocked", #M.blocked, 0)
-- The words of a rank no longer learned: the ID's name.
M.known[139] = nil
H.check("words: unlearned rank", Schema.BindingText("spell:139"), "Cast a spell: Renew")
H.check("words: unknown ID", Schema.BindingText("spell:999999"), "Cast a spell: 999999")
M.known[139] = true
