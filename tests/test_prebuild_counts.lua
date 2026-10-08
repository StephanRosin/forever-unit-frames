-- How many cells each raid block makes ahead of time (Raid/Panel.lua):
-- a group block five; any other block the cells it holds plus room for
-- those who could still come, at most one line of cells more; the pet
-- panel one cell per member without a pet out.
local M = H.M
local CLASSES = { "MAGE", "PRIEST", "WARRIOR", "ROGUE", "DRUID", "HUNTER", "WARLOCK", "PALADIN", "SHAMAN" }

local function boot(groupBy)
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    for _, scope in ipairs({ "r10", "r20", "r40" }) do ns.RaidConfig.Set(scope, "groupBy", groupBy) end
    M.RunTimers()
    return ns
end

local function roster(n)
    local list = {}
    for i = 1, n do
        list[i] = { name = "M" .. i, class = CLASSES[(i - 1) % #CLASSES + 1], subgroup = math.floor((i - 1) / 5) + 1,
            assignedRole = "DAMAGER" }
    end
    return list
end

local function cells(h)
    local k = 0
    while h:GetAttribute("child" .. (k + 1)) do k = k + 1 end
    return k
end

-- Class blocks at 20 with 11 members: each block its members plus one
-- line (5) of the 9 free places.
local ns = boot("CLASS")
local Header = ns.RaidHeader
M.SetRaidRoster(roster(11))
M.RunTimers()
H.check("class: size", ns.RaidCell.Size(), 20)
local total, members = 0, 0
for i, h in ipairs(Header.headers) do
    if i <= #Header.blocks then
        H.check("class block " .. i .. ": cells", cells(h), Header.Count(i) + 5)
        total, members = total + cells(h), members + Header.Count(i)
    end
end
H.check("class: members placed", members, 11)
H.check("class: cells in all", total, 11 + 9 * 5)

-- Fewer free places than a line: only those.
ns = boot("NONE")
Header = ns.RaidHeader
M.SetRaidRoster(roster(18))
M.RunTimers()
H.check("none 18: cells", cells(Header.headers[1]), 20)
H.check("errors", #M.errors, 0)
