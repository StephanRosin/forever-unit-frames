-- Members who join in combat show their auras at once: the party header
-- and the raid blocks make their buttons out of combat ahead of time
-- (Units/Units.lua PrebuildButtons), so each already has its aura
-- containers, made out of combat. A button without a unit holds "none":
-- hidden, no unit, nothing to do. No pretend member is ever seen, and the
-- headers keep their attributes.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local P = ns.Party
local header = P.header

-- Party: every slot's button exists from login, unitless and hidden.
local slots = P.Slots()
H.check("party: four slots", slots, 4)
H.checkTrue("party: last slot made", header:GetAttribute("child" .. slots) ~= nil)
H.check("party: no more than the slots", header:GetAttribute("child" .. (slots + 1)), nil)
local containers = 0
for i = 1, slots do
    local b = header:GetAttribute("child" .. i)
    H.check("party " .. i .. ": no unit", b.unit, nil)
    H.check("party " .. i .. ": not shown", b:IsShown(), false)
    H.checkTrue("party " .. i .. ": containers", b.auraContainers and b.auraContainers.buffs)
    for _, entry in pairs(b.auraContainers) do
        containers = containers + 1
        H.check("party " .. i .. ": idle container", entry.container:GetUnit(), "none")
    end
    H.checkTrue("party " .. i .. ": dispel container", b.dispel and b.dispel.container)
    H.check("party " .. i .. ": dispel idle", b.dispel.container:GetUnit(), "none")
end
H.check("party: buffs, debuffs and dispellable per slot", containers, 3 * slots)
H.check("party: header attributes as before", table.concat({ tostring(header:GetAttribute("startingIndex")),
    tostring(header:GetAttribute("unitsPerColumn")), tostring(header:GetAttribute("maxColumns")) }, " "),
    "nil nil nil")
H.check("party: solo, header hidden", header:IsShown() and header:IsVisible() and header:GetAttribute("child1"):IsShown(),
    false)

-- Unitless containers stay idle: time and events move nothing.
local function total()
    local n = 0
    for i = 1, slots do
        local b = header:GetAttribute("child" .. i)
        for _, entry in pairs(b.auraContainers) do n = n + entry.container._updates end
        n = n + b.dispel.container._updates
    end
    return n
end
local before = total()
M.Tick(1)
M.Tick(1)
M.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
H.check("party: idle, nothing updated", total(), before)

-- Someone joins in combat: their button gets the unit, and so do its
-- containers, at once.
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.units.party2 = { name = "Bob", health = 5, healthMax = 10 }
M.SetGroup({ "party1" })
M.RunTimers()
M.SetCombat(true)
M.SetGroup({ "party1", "party2" })
local b2 = header:GetAttribute("child2")
H.check("combat join: unit", b2.unit, "party2")
H.check("combat join: buffs follow", b2.auraContainers.buffs.container:GetUnit(), "party2")
H.check("combat join: debuffs follow", b2.auraContainers.debuffs.container:GetUnit(), "party2")
H.check("combat join: dispel follows", b2.dispel.container:GetUnit(), "party2")
H.check("combat join: buffs shown", b2.auraContainers.buffs.container:IsShown(), true)
H.check("combat join: nothing blocked", #M.blocked, 0)
H.check("combat join: no new button", header:GetAttribute("child" .. (slots + 1)), nil)
M.SetCombat(false)
M.RunTimers()
H.check("after combat: still party2", b2.auraContainers.buffs.container:GetUnit(), "party2")

-- Showing yourself makes the fifth button, out of combat.
ns.Config.Set(P.KEY, "partyShowPlayer", true)
M.RunTimers()
H.checkTrue("show player: fifth button", header:GetAttribute("child5") ~= nil)
H.checkTrue("show player: its containers", header:GetAttribute("child5").auraContainers ~= nil)
H.check("show player: attributes as before", header:GetAttribute("startingIndex"), nil)
H.check("show player: members kept", header:GetAttribute("child2").unit ~= nil, true)
H.check("errors", #M.errors, 0)

-- Raid: each group block of the shown size has five cells before combat.
ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Header = ns.RaidHeader
local function member(name, subgroup)
    return { name = name, class = "MAGE", subgroup = subgroup, assignedRole = "DAMAGER" }
end
M.SetRaidRoster({ member("Ann", 1), member("Bob", 1), member("Cid", 2) })
M.RunTimers()
H.check("raid: two blocks", #Header.blocks, 2)
local cells, idle = 0, 0
for i = 1, 2 do
    local h = Header.headers[i]
    H.checkTrue("raid block " .. i .. ": five cells", h:GetAttribute("child5") ~= nil)
    H.check("raid block " .. i .. ": not six", h:GetAttribute("child6"), nil)
    H.check("raid block " .. i .. ": attributes as before", h:GetAttribute("startingIndex"), nil)
    for k = 1, 5 do
        local cell = h:GetAttribute("child" .. k)
        cells = cells + 1
        H.checkTrue("raid " .. i .. "." .. k .. ": container", cell.raidAuras.container)
        if not cell.unit then
            idle = idle + 1
            H.check("raid " .. i .. "." .. k .. ": idle", cell.raidAuras.container:GetUnit(), "none")
            H.check("raid " .. i .. "." .. k .. ": hidden", cell:IsShown(), false)
        end
    end
end
H.check("raid: cells made", cells, 10)
H.check("raid: unitless cells", idle, 7)
H.check("raid: members in place", Header.Count(1) .. " " .. Header.Count(2), "2 1")

-- A fourth member joins group 2 in combat: their cell looks at them now.
M.SetCombat(true)
M.SetRaidRoster({ member("Ann", 1), member("Bob", 1), member("Cid", 2), member("Dan", 2) })
local cell = Header.headers[2]:GetAttribute("child2")
H.check("raid combat join: unit", cell.unit, "raid4")
H.check("raid combat join: container follows", cell.raidAuras.container:GetUnit(), "raid4")
H.check("raid combat join: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
M.RunTimers()
H.check("raid errors", #M.errors, 0)
