-- The spells the click-casting tab offers (Raid/Spellbook.lua:
-- FriendlySpells): the spell book's spells, no passives, helpful and cast
-- on someone else (range above 0), each name once with its learned ranks,
-- sorted by name. A secret or missing answer leaves the spell out.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Spellbook = ns.RaidSpellbook

local function names(list)
    local out = {}
    for i, spell in ipairs(list) do out[i] = spell.name end
    return table.concat(out, ",")
end
local function ranks(spell)
    local out = {}
    for i, r in ipairs(spell and spell.ranks or {}) do out[i] = r.id .. "=" .. r.subName end
    return table.concat(out, ",")
end
local function find(list, name)
    for _, spell in ipairs(list) do if spell.name == name then return spell end end
end

H.check("an empty book", names(Spellbook.FriendlySpells()), "")

for _, id in ipairs({ 139, 6074, 2061, 585, 591, 588, 596, 15237, 15270, 2050, 2052, 2053, 17, 1243 }) do
    M.known[id] = true
end
-- Not learned yet: in the book as a future spell, never offered.
M.futureSpells[2060] = true
local list = Spellbook.FriendlySpells()
H.check("helpful, cast on others, sorted", names(list),
    "Flash Heal,Lesser Heal,Power Word: Fortitude,Power Word: Shield,Renew")
H.check("ranks in book order with their text", ranks(find(list, "Renew")), "139=Rank 1,6074=Rank 2")
H.check("three ranks", ranks(find(list, "Lesser Heal")), "2050=Rank 1,2052=Rank 2,2053=Rank 3")
H.check("no ranks: one item, empty text", ranks(find(list, "Flash Heal")), "2061=")

-- Sorted ignoring case.
M.spells[900001] = { name = "abolish Thing", maxRange = 30 }
M.known[900001] = true
H.check("case ignored in the order", names(Spellbook.FriendlySpells()):sub(1, 24), "abolish Thing,Flash Heal")
M.known[900001] = nil

-- A secret answer leaves that spell (rank) out.
M.spellHelpfulSecret[2061] = true
H.check("secret helpful: left out", find(Spellbook.FriendlySpells(), "Flash Heal"), nil)
M.spellHelpfulSecret[2061] = nil
M.spellBookSecret[6074] = true
H.check("secret book item: that rank left out", ranks(find(Spellbook.FriendlySpells(), "Renew")), "139=Rank 1")
M.spellBookSecret[6074] = nil
-- A spell the client has no info for.
local getInfo = C_Spell.GetSpellInfo
C_Spell.GetSpellInfo = function(id) if id ~= 17 then return getInfo(id) end end
H.check("no info: left out", find(Spellbook.FriendlySpells(), "Power Word: Shield"), nil)
C_Spell.GetSpellInfo = function(id) if id == 17 then error("refused") end return getInfo(id) end
H.check("a lookup that raises: left out", find(Spellbook.FriendlySpells(), "Power Word: Shield"), nil)
C_Spell.GetSpellInfo = getInfo
-- No IsSpellHelpful on this client: nothing can be told, nothing listed.
local helpful = C_Spell.IsSpellHelpful
C_Spell.IsSpellHelpful = nil
H.check("no helpful check: nothing", names(Spellbook.FriendlySpells()), "")
C_Spell.IsSpellHelpful = helpful
H.check("back", #Spellbook.FriendlySpells(), 5)

-- A spell's entry by name (case ignored) and a rank by its ID.
H.check("by name", Spellbook.FriendlySpell("renew").name, "Renew")
H.check("unknown name", Spellbook.FriendlySpell("Smite"), nil)
local spell, rank = Spellbook.FriendlyRank(139)
H.check("rank's spell", spell and spell.name, "Renew")
H.check("rank's text", rank and rank.subName, "Rank 1")
H.check("not a learned rank", Spellbook.FriendlyRank(585), nil)
H.check("highest rank", Spellbook.HighestRank(find(Spellbook.FriendlySpells(), "Renew")).id, 6074)
