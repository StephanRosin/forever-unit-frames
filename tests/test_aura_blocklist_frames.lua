-- Hidden auras on the unit frames: the account list and the frame's own
-- go into the containers' excludeSpellIDs (with "hide tracking"), in and
-- out of combat; the client leaves them out where it allows filtering by
-- spell. The addon's own reads skip a readable spell ID on the lists; a
-- secret one is shown, without an error.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, AC = ns.Config, ns.AuraContainers

local FOOD, FIRE, OTHER = 19705, 7353, 1459
M.spells[FOOD] = { name = "Well Fed" }
M.spells[FIRE] = { name = "Cozy Fire" }
local function aura(id, spell, helpful)
    return { auraInstanceID = id, spellId = spell, isHelpful = helpful, icon = id, applications = 0,
        duration = 0, expirationTime = 0 }
end
local function auras()
    return { aura(1, FOOD, true), aura(2, FIRE, true), aura(3, OTHER, true), aura(4, FOOD, false),
        aura(5, OTHER, false) }
end
M.units.player = { name = "Me", health = 5, healthMax = 10, auras = auras() }
M.units.target = { name = "Foe", health = 5, healthMax = 10, hostile = true, auras = auras() }

local function shows(frame, key, part)
    return table.concat(M.AuraContainerShows(frame.auraContainers[key].container, part or "other"), ",")
end
local function excluded(frame, key, part)
    local f = frame.auraContainers[key].container._groups[part or "other"].candidateFilters
    local ids = {}
    for id in pairs(f and f.excludeSpellIDs or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    return table.concat(ids, ",")
end

local p, t = ns.Frames.player, ns.Frames.target
C.Set("player", "buffsEnabled", true)
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("player containers", AC.Ensure(p))
H.checkTrue("target containers", AC.Ensure(t))
H.check("empty lists: no filters", t.auraContainers.buffs.container._groups.other.candidateFilters, nil)
H.check("empty lists: everything", shows(t, "buffs"), FOOD .. "," .. FIRE .. "," .. OTHER)

-- The frame's own list: only that frame.
C.Set("player", "auraBlock", tostring(FOOD))
H.check("player: excluded", excluded(p, "buffs"), tostring(FOOD))
H.check("player: the own group too", excluded(p, "buffs", "own"), tostring(FOOD))
H.check("player: debuffs get it too", excluded(p, "debuffs"), tostring(FOOD))
H.check("player: buff hidden", shows(p, "buffs"), FIRE .. "," .. OTHER)
H.check("player: debuff stays (not on your group)", shows(p, "debuffs"), FOOD .. "," .. OTHER)
H.check("target: untouched", excluded(t, "buffs"), "")

-- The account list: every frame, merged with the frame's.
C.Set("general", "auraBlockAccount", tostring(FIRE))
H.check("player: both lists", excluded(p, "buffs"), FIRE .. "," .. FOOD)
H.check("target: the account's", excluded(t, "buffs"), tostring(FIRE))
-- On an enemy the client keeps buffs, hides debuffs.
C.Set("target", "auraBlock", tostring(FOOD))
H.check("enemy: buffs stay", shows(t, "buffs"), FOOD .. "," .. FIRE .. "," .. OTHER)
H.check("enemy: debuff hidden", shows(t, "debuffs"), tostring(OTHER))

-- With "hide tracking": both sets in one.
C.Set("target", "buffsHideTracking", true)
local f = t.auraContainers.buffs.container._groups.other.candidateFilters.excludeSpellIDs
H.checkTrue("tracking and lists", f[2383] and f[FOOD] and f[FIRE])
H.check("the shipped tracking set unchanged", AC.TRACKING_SET[FOOD], nil)
C.Set("target", "buffsHideTracking", false)
H.check("tracking off again", excluded(t, "buffs"), FIRE .. "," .. FOOD)

-- In combat: the change waits for the end of combat, then applies.
M.SetCombat(true)
C.Set("target", "auraBlock", "")
H.check("combat: unchanged", excluded(t, "buffs"), FIRE .. "," .. FOOD)
M.SetCombat(false)
H.check("after combat: applied", excluded(t, "buffs"), tostring(FIRE))
H.check("no errors", #M.errors, 0)

-- The account list cleared: no filter left.
C.Set("general", "auraBlockAccount", "")
H.check("cleared: no filters", t.auraContainers.buffs.container._groups.other.candidateFilters, nil)

-- The addon's own reads (no containers).
ns = H.LoadAddon()
M.auraContainerMissing = true
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
C = ns.Config
M.spells[FOOD] = { name = "Well Fed" }
M.units.player = { name = "Me", health = 5, healthMax = 10 }
M.units.target = { name = "Foe", health = 5, healthMax = 10, auras = auras() }
t = ns.Frames.target
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("read: three buffs", t.auras.buffs.count, 3)
C.Set("target", "auraBlock", tostring(FOOD))
M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
H.check("read: listed buff skipped", t.auras.buffs.count, 2)
H.check("read: listed debuff skipped", t.auras.debuffs.count, 1)
-- A secret spell ID: shown, no error.
M.units.target.auras[1].spellId = M.Secret(FOOD)
M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
H.check("read: secret ID shown", t.auras.buffs.count, 3)
H.check("read: no errors", #M.errors, 0)
