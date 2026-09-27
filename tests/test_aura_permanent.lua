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
