-- The mock's model of the container's identity filters
-- (Blizzard_AuraContainerUtil.lua, CanApplyIdentityCandidateFilters and
-- DoesAuraPassCandidateFilters): where an excluded spell ID is left out,
-- and where the client keeps it.
local M = H.M
H.LoadAddon()

local FOOD, SATED = 19705, 57724
M.neverSecretSpells[SATED] = true
local function buff(id) return { auraInstanceID = id, spellId = id, isHelpful = true, duration = 0 } end
local function debuff(id) return { auraInstanceID = id, spellId = id, isHelpful = false, duration = 30 } end
local EXCLUDE = { excludeSpellIDs = { [FOOD] = true, [SATED] = true } }

M.units.player = { name = "Me" }
M.units.party1 = { name = "Ann" }
M.units.pet = { name = "Cat" }
M.units.target = { name = "Foe", hostile = true }
M.units.focus = { name = "Friend" }

local function passes(unit, aura) return M.PassesCandidateFilters(unit, aura, EXCLUDE) end

-- Never-secret spells: on anyone.
H.check("sated on you", passes("player", debuff(SATED)), false)
H.check("sated on an enemy", passes("target", buff(SATED)), false)
-- Buffs on you, a member, a pet: yes; on an enemy: no.
H.check("buff on you", passes("player", buff(FOOD)), false)
H.check("buff on a member", passes("party1", buff(FOOD)), false)
H.check("buff on your pet", passes("pet", buff(FOOD)), false)
H.check("buff on an enemy stays", passes("target", buff(FOOD)), true)
H.check("buff on another friendly unit", passes("focus", buff(FOOD)), false)
-- Debuffs: only on units you cannot assist.
H.check("debuff on you stays", passes("player", debuff(FOOD)), true)
H.check("debuff on a member stays", passes("party1", debuff(FOOD)), true)
H.check("debuff on a friendly unit stays", passes("focus", debuff(FOOD)), true)
H.check("debuff on an enemy", passes("target", debuff(FOOD)), false)
-- No filters, other spells: shown.
H.check("no filters", M.PassesCandidateFilters("player", buff(FOOD), nil), true)
H.check("other spell", passes("player", buff(1)), true)
-- An include list where identity filters do not apply refuses everything.
H.check("include on an enemy's buff", M.PassesCandidateFilters("target", buff(FOOD),
    { includeSpellIDs = { [FOOD] = true } }), false)
-- maxDuration leaves out permanent and longer auras.
H.check("max duration: permanent out", M.PassesCandidateFilters("player", buff(5), { maxDuration = 60 }), false)
H.check("max duration: shorter in", M.PassesCandidateFilters("player", debuff(6), { maxDuration = 60 }), true)

-- The secrecy query: never, always, contextually; a secret argument raises.
H.check("secrecy never", C_Secrets.GetSpellAuraSecrecy(SATED), Enum.SecrecyLevel.NeverSecret)
H.check("secrecy context", C_Secrets.GetSpellAuraSecrecy(FOOD), Enum.SecrecyLevel.ContextuallySecret)
M.secretSpellAuras[7] = true
H.check("secrecy always", C_Secrets.GetSpellAuraSecrecy(7), Enum.SecrecyLevel.AlwaysSecret)
H.checkError("secret argument", function() C_Secrets.GetSpellAuraSecrecy(M.Secret(FOOD)) end)

-- A container's choice: filter string, candidate filters, maximum.
M.units.player.auras = { buff(FOOD), buff(2), debuff(3), buff(4) }
local c = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
c:AddAuraGroup("b", "HELPFUL", { maxFrameCount = 2, candidateFilters = EXCLUDE })
c:SetUnit("player")
H.check("container shows", table.concat(M.AuraContainerShows(c, "b"), ","), "2,4")
c:SetAuraGroupEnabled("b", false)
H.check("switched off: nothing", #M.AuraContainerShows(c, "b"), 0)
