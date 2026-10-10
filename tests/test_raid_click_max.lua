-- "Max" is what the client casts for the spell's name (CastSpellByName:
-- the highest rank known), read as C_Spell.GetSpellInfo(name).spellID,
-- not the spell book's order: a higher rank may have the lower ID and
-- stand anywhere in the book. When that cannot be read, a stored ID is
-- kept (never turned into Max by guess).
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Spellbook, CC = ns.RaidSpellbook, ns.ClickCast
-- Greater Heal: rank 5 is 25314, rank 6 is 25210 (the lower ID).
for _, id in ipairs({ 2060, 25314, 25210 }) do M.known[id] = true end

local spell = Spellbook.FriendlySpell("Greater Heal")
local order = {}
for i, r in ipairs(spell.ranks) do order[i] = r.subName end
H.check("the book's order is not the ranks'", table.concat(order, ","), "Rank 1,Rank 6,Rank 5")
H.check("max: the rank the name casts", Spellbook.HighestRank(spell).id, 25210)
H.check("the top rank's ID: Max", (CC.NormaliseSpell("25210")), "Greater Heal")
H.check("rank 5 (last in the book): kept", (CC.NormaliseSpell("25314")), "25314")

-- The name cannot be resolved: no Max by guess.
local getInfo = C_Spell.GetSpellInfo
C_Spell.GetSpellInfo = function(id)
    if type(id) == "string" then return nil end
    return getInfo(id)
end
H.check("unresolved: no highest rank", Spellbook.HighestRank(spell), nil)
local value, listed = CC.NormaliseSpell("25210")
H.check("unresolved: the ID kept", value, "25210")
H.check("still listed", listed, true)
C_Spell.GetSpellInfo = function(id)
    if type(id) == "string" then error("refused") end
    return getInfo(id)
end
H.check("a lookup that raises: no highest rank", Spellbook.HighestRank(spell), nil)
C_Spell.GetSpellInfo = getInfo
