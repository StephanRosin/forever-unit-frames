-- Raid size (Raid/Size.lua): fixed mode, raid instance, member count; the
-- change event and what triggers a new look.
local M = H.M
local ns = H.LoadAddon()
local Size, RC = ns.RaidSize, ns.RaidConfig

-- Pure rule.
H.check("fixed 20", Size.Detect("20", "raid", 40, 3), 20)
H.check("fixed 40 outside", Size.Detect("40", "none", 0, 0), 40)
H.check("raid instance 10", Size.Detect("AUTO", "raid", 10, 25), 10)
H.check("raid instance 20, not full", Size.Detect("AUTO", "raid", 20, 6), 20)
H.check("raid instance 40", Size.Detect("AUTO", "raid", 40, 12), 40)
H.check("dungeon: by members", Size.Detect("AUTO", "party", 5, 5), 10)
H.check("outside, 10", Size.Detect("AUTO", "none", 0, 10), 10)
H.check("outside, 11", Size.Detect("AUTO", "none", 0, 11), 20)
H.check("outside, 21", Size.Detect("AUTO", "none", 0, 21), 40)
H.check("solo", Size.Detect("AUTO", "none", 0, 0), 10)
H.check("raid without maxPlayers: by members", Size.Detect("AUTO", "raid", 0, 18), 20)

-- Nothing before the profile is attached.
H.check("no profile yet", Size.Update(), nil)
H.check("no current yet", Size.Current(), nil)

local sizes = {}
ns.Listen("RAID_SIZE_CHANGED", function(size) sizes[#sizes + 1] = size end)
ns.RaidProfiles.Attach({})
H.check("first update", Size.Update(), 10)
H.check("first update fires", sizes[1], 10)
Size.Update()
H.check("no change, no event", #sizes, 1)

-- The client events.
M.inRaid, M.raidMembers = true, 15
M.FireEvent("GROUP_ROSTER_UPDATE")
H.check("roster: 15 members", Size.Current(), 20)
M.instance = { type = "raid", maxPlayers = 40 }
M.FireEvent("PLAYER_ENTERING_WORLD", false, false)
H.check("entering a 40 raid", Size.Current(), 40)
M.instance = { type = "raid", maxPlayers = 10 }
M.FireEvent("ZONE_CHANGED_NEW_AREA")
H.check("zone change", Size.Current(), 10)
M.instance = { type = "raid", maxPlayers = 20 }
M.FireEvent("PLAYER_DIFFICULTY_CHANGED")
H.check("difficulty change", Size.Current(), 20)
M.instance = { type = "raid", maxPlayers = 40 }
M.FireEvent("INSTANCE_GROUP_SIZE_CHANGED")
H.check("group size change", Size.Current(), 40)
H.check("events fired", table.concat(sizes, ","), "10,20,40,10,20,40")

-- The setting.
RC.Set("general", "sizeMode", "10")
H.check("fixed by setting", Size.Current(), 10)
RC.Set("general", "sizeMode", "AUTO")
H.check("back to auto", Size.Current(), 40)
RC.Set("general", "sizeMode", "20")
RC.ResetAll()
H.check("reset: auto again", Size.Current(), 40)
local update, updates = Size.Update, 0
Size.Update = function(...)
    updates = updates + 1
    return update(...)
end
RC.Set("r10", "x", 5)
H.check("other settings: no recomputation", updates, 0)
RC.Set("general", "sizeMode", "10")
H.check("sizeMode: recomputation", updates, 1)
Size.Update = update

-- Outside a raid instance the highest occupied group counts too: nobody
-- sits in a group the profile does not show. Inside one the instance
-- decides; a fixed mode stays fixed.
H.check("9 members, someone in group 3", Size.Detect("AUTO", "none", 0, 9, 3), 20)
H.check("9 members, someone in group 5", Size.Detect("AUTO", "none", 0, 9, 5), 40)
H.check("group 2 fits the 10 profile", Size.Detect("AUTO", "none", 0, 9, 2), 10)
H.check("more members than groups say", Size.Detect("AUTO", "none", 0, 21, 3), 40)
H.check("raid instance 10, someone in group 3", Size.Detect("AUTO", "raid", 10, 9, 3), 10)
H.check("fixed 10, someone in group 5", Size.Detect("10", "none", 0, 9, 5), 10)
H.check("group unknown: members only", Size.Detect("AUTO", "none", 0, 9, nil), 10)

local function members(groups)
    local list = {}
    for i, g in ipairs(groups) do list[i] = { name = "R" .. i, class = "MAGE", subgroup = g } end
    return list
end
RC.Set("general", "sizeMode", "AUTO")
M.instance = { type = "none", maxPlayers = 0 }
M.SetRaidRoster(members({ 1, 1, 1, 1, 1, 2, 2, 2, 2 }))
H.check("roster: 9 in groups 1-2", Size.Current(), 10)
M.SetRaidRoster(members({ 1, 1, 1, 1, 1, 2, 2, 2, 3 }))
H.check("roster: someone moved to group 3", Size.Current(), 20)
M.SetRaidRoster(members({ 1, 1, 1, 1, 1, 2, 2, 2, 5 }))
H.check("roster: someone moved to group 5", Size.Current(), 40)
local secret = members({ 1, 1, 1, 1, 1, 2, 2, 2, 2 })
secret[9].subgroup = M.Secret(5)
M.SetRaidRoster(secret)
H.check("roster: a secret group is not counted", Size.Current(), 10)
M.instance = { type = "raid", maxPlayers = 10 }
M.SetRaidRoster(members({ 1, 1, 1, 1, 1, 2, 2, 2, 3 }))
H.check("roster: a 10 raid instance wins", Size.Current(), 10)
M.instance = { type = "none", maxPlayers = 0 }
M.SetRaidRoster({})
H.check("left the raid", Size.Current(), 10)
