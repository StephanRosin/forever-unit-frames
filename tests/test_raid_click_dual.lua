-- Spells that target friend or foe (Dispel Magic, Holy Shock): the client
-- does not answer them as helpful, yet they belong in the click-casting
-- list (Raid/Spellbook.lua: a short list of them, matched by the name the
-- client gives their IDs, every learned rank). The migration takes them
-- like the others.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
for _, id in ipairs({ 139, 527, 988 }) do M.known[id] = true end
local me = ns.RaidProfiles.CharKey()
ForeverUnitFramesDB = { raid = { [me] = { general = { click2Ctrl = "spell:dispel magic", click2Alt = "spell:527" } } } }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Spellbook = ns.RaidSpellbook

H.check("the mock: not helpful", C_Spell.IsSpellHelpful(527), false)
H.check("the mock: harmful", C_Spell.IsSpellHarmful(527), true)
local dispel = Spellbook.FriendlySpell("Dispel Magic")
H.checkTrue("listed anyway", dispel)
local ids = {}
for i, r in ipairs(dispel and dispel.ranks or {}) do ids[i] = r.id .. "=" .. r.subName end
H.check("every learned rank", table.concat(ids, ","), "527=Rank 1,988=Rank 2")
-- Still a spell cast on others: no range, not listed.
M.spells[988].maxRange = 0
H.check("no range: that rank left out", #Spellbook.FriendlySpell("Dispel Magic").ranks, 1)
M.spells[988].maxRange = 30
-- A harmful spell stays out.
M.known[585] = true
H.check("harmful only: out", Spellbook.FriendlySpell("Smite"), nil)
-- The name cannot be read: the list cannot tell, the spell left out.
local getInfo = C_Spell.GetSpellInfo
C_Spell.GetSpellInfo = function(id) if id == 527 or id == 988 then error("refused") end return getInfo(id) end
H.check("unreadable: left out", Spellbook.FriendlySpell("Dispel Magic"), nil)
C_Spell.GetSpellInfo = getInfo

-- Migration: a stored Dispel Magic becomes the listed spell (Max).
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.check("migrated by name", ns.RaidConfig.Get("general", "click2Ctrl"), "spell:Dispel Magic")
H.check("a lower rank kept", ns.RaidConfig.Get("general", "click2Alt"), "spell:527")
