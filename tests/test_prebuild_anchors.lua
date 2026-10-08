-- Cells made ahead of time keep only the anchors of the real layout: the
-- hidden layout that makes them (Units/Units.lua PrebuildButtons) chains
-- every cell to the one before, and the header's configureChildren never
-- clears the points of the cells it shows again, so a cell starting a new
-- column would keep the old chain anchor as well (wrong height).
local M = H.M

local function boot(groupBy, cellsPerLine)
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    for _, scope in ipairs({ "r10", "r20", "r40" }) do
        ns.RaidConfig.Set(scope, "groupBy", groupBy)
        ns.RaidConfig.Set(scope, "cellsPerLine", cellsPerLine)
    end
    M.RunTimers()
    return ns
end

local CLASSES = { "MAGE", "PRIEST", "WARRIOR", "ROGUE", "DRUID" }
local ROLES = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }
local function roster(n)
    local list = {}
    for i = 1, n do
        list[i] = { name = "M" .. i, class = CLASSES[(i - 1) % 5 + 1], subgroup = math.floor((i - 1) / 5) + 1,
            assignedRole = ROLES[(i - 1) % 5 + 1] }
    end
    return list
end

-- Every shown cell: one anchor per point the header gives it (the first
-- cell of a block two when it has columns, a column's first one, every
-- other cell one); a hidden cell none.
local function anchorsRight(label, Header)
    local ok = true
    for i, h in ipairs(Header.headers) do
        local k = 1
        while h:GetAttribute("child" .. k) do
            local cell = h:GetAttribute("child" .. k)
            local want = 0
            if cell.unit then
                local perColumn = h:GetAttribute("unitsPerColumn")
                local columns = (h:GetAttribute("maxColumns") or 1) > 1 and Header.Count(i) > perColumn
                want = (k == 1 and columns) and 2 or 1
            end
            if cell:GetNumPoints() ~= want then
                ok = false
                H.check(label .. ": block " .. i .. " cell " .. k .. " anchors", cell:GetNumPoints(), want)
            end
            k = k + 1
        end
    end
    H.checkTrue(label .. ": every cell anchored once", ok)
end

-- No grouping, two cells a line: a raid of three formed out of combat.
local ns = boot("NONE", 2)
local Header = ns.RaidHeader
M.SetRaidRoster(roster(3))
M.RunTimers()
H.check("none: members", Header.Count(1), 3)
local h = Header.headers[1]
H.checkTrue("none: cells made ahead", h:GetAttribute("child4") ~= nil)
local child3 = h:GetAttribute("child3")
H.check("none: third cell one anchor", child3:GetNumPoints(), 1)
H.check("none: third cell starts a column", (child3:GetPoint(1)), "LEFT")
anchorsRight("none", Header)
H.check("none: errors", #M.errors, 0)

-- Role blocks, a raid of 25.
ns = boot("ROLE", 2)
Header = ns.RaidHeader
M.SetRaidRoster(roster(25))
M.RunTimers()
anchorsRight("role 25", Header)
H.check("role 25: errors", #M.errors, 0)

-- Behind a loading screen (UIParent hidden) the header cannot lay out:
-- nothing is made and nothing claimed; once UIParent shows, the buttons
-- are made (out of combat), each with its containers.
ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.LoadingScreenStarts()
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local party = ns.Party.header
H.check("hidden: nothing made", party:GetAttribute("child1"), nil)
H.check("hidden: nothing claimed", ns.Units.PrebuildButtons(party, 4), false)
H.check("hidden: still nothing", party:GetAttribute("child1"), nil)
M.LoadingScreenEnds()
M.RunTimers()
H.checkTrue("shown: slots made", party:GetAttribute("child" .. ns.Party.Slots()) ~= nil)
H.checkTrue("shown: containers", party:GetAttribute("child4").auraContainers ~= nil)
H.check("shown: header attributes as before", party:GetAttribute("startingIndex"), nil)
H.check("shown: not shown solo", party:GetAttribute("child1"):IsShown(), false)
H.check("shown: errors", #M.errors, 0)

-- Combat starts as UIParent shows: made once combat ends.
ns = H.LoadAddon()
M.LoadingScreenStarts()
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
party = ns.Party.header
M.LoadingScreenEnds()
M.SetCombat(true)
M.RunTimers()
H.check("combat: nothing made", party:GetAttribute("child1"), nil)
M.SetCombat(false)
M.RunTimers()
H.checkTrue("after combat: slots made", party:GetAttribute("child4") ~= nil)
H.check("after combat: nothing blocked", #M.blocked, 0)
