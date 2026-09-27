-- "Hide permanent": buffs or debuffs without a duration (tracking, stances,
-- auras) are left out, by the aura container's own candidate filter, so it
-- works in combat too.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C, AC = ns.Settings, ns.Config, ns.AuraContainers

H.check("buffs code", S.Get("buffsHidePermanent").code, "JP")
H.check("debuffs code", S.Get("debuffsHidePermanent").code, "DP")
C.Use({})
H.check("off by default", C.Get("target", "buffsHidePermanent"), false)

M.units.target = { name = "Foe", health = 5, healthMax = 10 }
local t = ns.Frames.target
H.checkTrue("target: containers", AC.Ensure(t))
local bc = t.auraContainers.buffs.container
H.check("off: no candidate filter", bc._groups.other.candidateFilters, nil)

C.Set("target", "buffsHidePermanent", true)
local filters = bc._groups.other.candidateFilters
H.checkTrue("on: a max duration hides permanent auras", filters and filters.maxDuration ~= nil)
H.checkTrue("on: timed auras of any length stay", filters.maxDuration >= 86400 * 365)
H.checkTrue("on: the own group too", bc._groups.own.candidateFilters ~= nil)
H.check("debuffs untouched", t.auraContainers.debuffs.container._groups.other.candidateFilters, nil)

C.Set("target", "buffsHidePermanent", false)
H.check("off again: filter gone", bc._groups.other.candidateFilters, nil)

-- Options: next to "Only mine".
local found
for _, tab in ipairs(ns.Schema.Tabs("target")) do
    for _, sec in ipairs(tab.sections or {}) do
        for _, key in ipairs(sec.keys or {}) do if key == "buffsHidePermanent" then found = sec.id end end
    end
end
H.check("in the buffs section", found, "buffs")
H.checkTrue("labelled", ns.L.SETTING_buffsHidePermanent ~= "SETTING_buffsHidePermanent")

-- "Hide tracking": only the tracking and sensing spells are left out, by
-- the container's excludeSpellIDs; auras and stances stay.
H.check("tracking code", S.Get("buffsHideTracking").code, "JK")
H.check("buffs only", S.Get("debuffsHideTracking"), nil)
H.check("tracking off by default", C.Get("target", "buffsHideTracking"), false)
C.Set("target", "buffsHideTracking", true)
local tf = bc._groups.other.candidateFilters
H.checkTrue("tracking: excluded ids", tf and type(tf.excludeSpellIDs) == "table")
local ids = {}
for _, id in ipairs(tf.excludeSpellIDs) do ids[id] = true end
H.checkTrue("Find Herbs", ids[2383])
H.checkTrue("Find Minerals", ids[2580])
H.checkTrue("Track Beasts", ids[1494])
H.check("no duration limit from tracking alone", tf.maxDuration, nil)
C.Set("target", "buffsHidePermanent", true)
tf = bc._groups.other.candidateFilters
H.checkTrue("both: ids and duration", tf.excludeSpellIDs ~= nil and tf.maxDuration ~= nil)
C.Set("target", "buffsHidePermanent", false)
C.Set("target", "buffsHideTracking", false)
H.check("both off: no filter", bc._groups.other.candidateFilters, nil)
