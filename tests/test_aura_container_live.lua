-- Live auras through the containers: no reads by the addon, units and
-- refreshes follow the frames, in combat too; test mode shows samples.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Auras, P = ns.Auras, ns.Party

local function aura(id, fields)
    local a = { auraInstanceID = id, icon = 100 + id, applications = 0, duration = 0, expirationTime = 0 }
    for k, v in pairs(fields or {}) do a[k] = v end
    return a
end
M.units.player = { name = "Me", health = 5, healthMax = 10 }
M.units.target = { name = "Foe", health = 5, healthMax = 10,
    auras = { aura(1, { isHelpful = true }), aura(2, { dispelName = "Magic" }) } }

-- A new target: the containers are made for it and refreshed; the addon
-- reads nothing and its holders stay empty.
local t = ns.Frames.target
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("target containers", t.auraContainers)
local dc = t.auraContainers.debuffs.container
H.check("unit", dc:GetUnit(), "target")
H.check("no reads", M.auraQueries, 0)
H.check("holders empty", t.auras.debuffs.count, 0)
local updates = dc._updates
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("another target: refreshed", dc._updates, updates + 1)
-- UNIT_AURA is the container's own business.
updates = dc._updates
M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
H.check("UNIT_AURA: nothing from us", dc._updates, updates)
H.check("UNIT_AURA: still no reads", M.auraQueries, 0)

-- Combat: reads would be refused; the containers are refreshed anyway.
M.auraError = true
M.SetCombat(true)
updates = dc._updates
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("combat: refreshed", dc._updates, updates + 1)
M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
H.check("combat: no errors", #M.errors, 0)
M.SetCombat(false)
M.auraError = false
H.check("after combat: no reads", M.auraQueries, 0)

-- Focus: its own containers and unit.
M.units.focus = { name = "Other", health = 5, healthMax = 10 }
M.FireEvent("PLAYER_FOCUS_CHANGED")
H.check("focus unit", ns.Frames.focus.auraContainers.debuffs.container:GetUnit(), "focus")

-- Target of target: no aura events for that token; the frame's timer
-- refreshes its containers at most every POLL_SECONDS.
M.units.targettarget = { name = "Tank", health = 5, healthMax = 10 }
local tot = ns.Frames.targettarget
M.FireEvent("PLAYER_TARGET_CHANGED")
local tc = tot.auraContainers.buffs.container
H.check("tot unit", tc:GetUnit(), "targettarget")
updates = tc._updates
M.Tick(0.2)
M.Tick(0.2)
H.check("tot: not before 0.5 s", tc._updates, updates)
M.Tick(0.2)
H.check("tot: refreshed after 0.6 s", tc._updates, updates + 1)

-- Party: containers per member, the unit follows the header in combat.
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.units.party2 = { name = "Bob", health = 5, healthMax = 10 }
M.units.party3 = { name = "Cid", health = 5, healthMax = 10 }
M.SetGroup({ "party1" })
local b1 = P.header:GetAttribute("child1")
H.check("member 1 unit", b1.auraContainers.debuffs.container:GetUnit(), "party1")
M.SetCombat(true)
M.SetGroup({ "party2", "party3" })
H.check("combat: slot 1 follows", b1.auraContainers.debuffs.container:GetUnit(), "party2")
local b2 = P.header:GetAttribute("child2")
H.check("combat: new member waits", b2.auraContainers, nil)
M.SetCombat(false)
H.checkTrue("after combat: new member's containers", b2.auraContainers)
H.check("new member unit", b2.auraContainers.debuffs.container:GetUnit(), "party3")
H.check("party: still no reads", M.auraQueries, 0)

-- Test mode: our samples, containers hidden; the pretend party never
-- gets containers.
ns.TestMode.Set(true)
H.check("test: container hidden", dc:IsShown(), false)
H.check("test: samples", t.auras.debuffs.count, 16)
for i, fake in ipairs(P.fakes) do H.check("pretend member " .. i .. ": no containers", fake.auraContainers, nil) end
ns.TestMode.Set(false)
H.checkTrue("test off: container back", dc:IsShown())
H.check("test off: samples gone", t.auras.debuffs.count, 0)
H.check("test off: buffs off stay hidden", ns.Frames.player.auraContainers.buffs.container:IsShown(), false)
H.check("test off: no reads", M.auraQueries, 0)

-- Without client support the addon reads (the fallback).
ns = H.LoadAddon()
M.auraContainerMissing = true
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.units.target = { name = "Foe", health = 5, healthMax = 10, auras = { aura(1, { isHelpful = true }) } }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("fallback: reads", M.auraQueries > 0)
H.check("fallback: icon", ns.Frames.target.auras.buffs.count, 1)
H.check("fallback: no containers", ns.Frames.target.auraContainers, nil)
