-- The hidden-auras editor (Options/AuraBlockEditor.lua): in each frame's
-- Auras tab, on General (the account's list) and in the raid window's
-- Debuffs tab. A box takes IDs or names, the list shows IDs with names, a
-- Remove per entry, a note and a mark where the client will not hide the
-- spell everywhere on this list's frames.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, RC, L, Options = ns.Config, ns.RaidConfig, ns.L, ns.Options

M.spells[19705] = { name = "Well Fed" }
M.spells[7353] = { name = "Cozy Fire" }
M.spells[57724] = { name = "Sated" }
M.neverSecretSpells[57724] = true

local function rowOf(rows, key)
    for _, r in ipairs(rows or {}) do if r.key == key then return r end end
end
local function type_(row, text)
    row.edit:SetText(text)
    row.edit:GetScript("OnEnterPressed")(row.edit)
end

-- A frame's Auras tab.
Options.Open("target", "auras")
local row = rowOf(Options.rows, "auraBlock")
H.checkTrue("target: the editor", row and row.edit)
H.check("empty", row.lines[1].text:GetText(), L.AURA_BLOCK_EMPTY)
H.check("no remove", row.lines[1].remove:IsShown(), false)
H.check("note", row.note:GetText(), L.AURA_BLOCK_NOTE)
H.check("count", row.count:GetText(), L.AURA_BLOCK_COUNT:format(0, ns.AuraBlocklist.MAX))
type_(row, "Cozy Fire, 57724")
H.check("stored", C.Get("target", "auraBlock"), "7353, 57724")
H.check("box cleared", row.edit:GetText(), "")
H.check("line: id and name", row.lines[1].text:GetText(), "7353  Cozy Fire")
H.check("mark on the target", row.lines[1].mark:GetText(), L.AURA_BLOCK_MARK_MIXED)
H.check("never secret: no mark", row.lines[2].mark:GetText(), "")
H.check("remove shown", row.lines[1].remove:IsShown(), true)
-- Unknown: refused, said in chat, nothing stored.
type_(row, "Bogus")
H.check("unknown: unchanged", C.Get("target", "auraBlock"), "7353, 57724")
H.checkTrue("unknown: said so", M.chat[#M.chat]:find(L.AURA_BLOCK_UNKNOWN:format("Bogus"), 1, true))
-- Remove.
row.lines[1].remove:GetScript("OnClick")(row.lines[1].remove)
H.check("removed", C.Get("target", "auraBlock"), "57724")
H.check("list follows", row.lines[1].text:GetText(), "57724  Sated")

-- The player's page: the group's mark.
Options.Select("player")
Options.SelectTab("auras")
row = rowOf(Options.rows, "auraBlock")
type_(row, "7353")
H.check("player: group mark", row.lines[1].mark:GetText(), L.AURA_BLOCK_MARK_GROUP)

-- A long list scrolls with the wheel.
local ids = {}
for i = 1, 9 do
    M.spells[50000 + i] = { name = "Spell " .. i }
    ids[i] = 50000 + i
end
C.Set("player", "auraBlock", ns.AuraBlocklist.Text(ids))
H.check("first line", row.lines[1].text:GetText(), "50001  Spell 1")
row:GetScript("OnMouseWheel")(row, -1)
H.check("scrolled", row.lines[1].text:GetText(), "50002  Spell 2")
for _ = 1, 10 do row:GetScript("OnMouseWheel")(row, -1) end
H.check("stops at the end", row.lines[1].text:GetText(), "50004  Spell 4")

-- In combat: locked like every row.
M.SetCombat(true)
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: box off", row.edit:IsEnabled(), false)
H.check("combat: remove off", row.lines[1].remove:IsEnabled(), false)
M.SetCombat(false)
H.check("after combat: on", row.edit:IsEnabled(), true)

-- General: the account's list.
Options.Select("general")
Options.SelectTab("appearance")
row = rowOf(Options.rows, "auraBlockAccount")
H.checkTrue("general: the editor", row and row.edit)
type_(row, "7353")
H.check("account stored", C.Get("general", "auraBlockAccount"), "7353")
H.check("account mark", row.lines[1].mark:GetText(), L.AURA_BLOCK_MARK_MIXED)
Options.Close()

-- The raid window's Debuffs tab: the edited size's list.
local RO = ns.RaidOptions
RO.Open()
RO.SelectSize(20)
RO.SelectTab("debuffs")
row = rowOf(RO.rows, "auraBlock")
H.checkTrue("raid: the editor", row and row.edit)
type_(row, "Well Fed")
H.check("raid: stored on the size", RC.Get("r20", "auraBlock"), "19705")
H.check("raid: other sizes untouched", RC.Get("r10", "auraBlock"), "")
H.check("raid: group mark", row.lines[1].mark:GetText(), L.AURA_BLOCK_MARK_GROUP)
H.check("no errors", #M.errors, 0)
