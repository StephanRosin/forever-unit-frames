-- The mock's group headers against the client's SecureGroupHeaders.lua,
-- for what the special raid panels use: a list of names (nameList, sorted
-- by the list with NAMELIST) and the pet header's filters, grouping,
-- sorting, owner units and pet names.
local M = H.M
H.LoadAddon()

local function header(attributes, template)
    local h = CreateFrame("Frame", "TestListHeader" .. #M.frames, UIParent, template or "SecureGroupHeaderTemplate")
    h:SetAttribute("_ignore", "attributeChanges")
    h:SetAttribute("template", "SecureUnitButtonTemplate")
    for name, value in pairs(attributes) do h:SetAttribute(name, value) end
    h:SetAttribute("_ignore", nil)
    h:Show()
    return h
end
local function pets(attributes) return header(attributes, "SecureGroupPetHeaderTemplate") end

local function units(h)
    local list, i = {}, 1
    while h:GetAttribute("child" .. i) do
        local unit = h:GetAttribute("child" .. i):GetAttribute("unit")
        if unit then list[#list + 1] = unit end
        i = i + 1
    end
    return table.concat(list, ",")
end

M.SetRaidRoster({
    { name = "Tank", class = "WARRIOR", subgroup = 1, assignedRole = "TANK", role = "MAINTANK" },
    { name = "Mage", class = "MAGE", subgroup = 2, assignedRole = "DAMAGER" },
    { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "HEALER", role = "MAINASSIST" },
    { name = "Zed", class = "HUNTER", subgroup = 3, assignedRole = "DAMAGER" },
    { name = "Bob", class = "WARLOCK", subgroup = 2 },
})

-- A list of names: only those, in raid order, by name, or in the list's
-- order; a filter wins over the list; an empty list shows nobody.
H.check("names", units(header({ showRaid = true, nameList = "Zed,Ann" })), "raid3,raid4")
H.check("names by name", units(header({ showRaid = true, nameList = "Zed,Ann,Bob", sortMethod = "NAME" })),
    "raid3,raid5,raid4")
H.check("names in the list's order", units(header({ showRaid = true, nameList = "Zed,Tank,Ann",
    sortMethod = "NAMELIST" })), "raid4,raid1,raid3")
H.check("list entries trimmed", units(header({ showRaid = true, nameList = " Bob , Mage", sortMethod = "NAMELIST" })),
    "raid5,raid2")
H.check("unknown names: nobody", units(header({ showRaid = true, nameList = "Nobody" })), "")
H.check("an empty list: nobody", units(header({ showRaid = true, nameList = "" })), "")
H.check("a group filter wins over the list", units(header({ showRaid = true, nameList = "Zed", groupFilter = "1" })),
    "raid1,raid3")
H.check("a role filter wins over the list", units(header({ showRaid = true, nameList = "Zed", roleFilter = "MAINTANK" })),
    "raid1")
H.check("main assists", units(header({ showRaid = true, roleFilter = "MAINASSIST" })), "raid3")

-- The pet header: pets that exist, of the members the filter picks.
M.units.raidpet2 = { name = "Imp" }
M.units.raidpet4 = { name = "Wolf" }
M.units.raidpet5 = { name = "Felhunter" }
H.check("pets", units(pets({ showRaid = true })), "raidpet2,raidpet4,raidpet5")
H.check("pets of groups 1-2", units(pets({ showRaid = true, groupFilter = "1,2" })), "raidpet2,raidpet5")
H.check("pets of a class (loose: group or class)", units(pets({ showRaid = true, groupFilter = "3,WARLOCK" })),
    "raidpet4,raidpet5")
H.check("pets, strict: group and class", units(pets({ showRaid = true, groupFilter = "2,WARLOCK",
    strictFiltering = true })), "raidpet5")
H.check("pets by owner name", units(pets({ showRaid = true, sortMethod = "NAME" })), "raidpet5,raidpet2,raidpet4")
H.check("pets by their own name", units(pets({ showRaid = true, sortMethod = "NAME", filterOnPet = true })),
    "raidpet5,raidpet2,raidpet4")
H.check("pets grouped by class", units(pets({ showRaid = true, groupBy = "CLASS",
    groupingOrder = "WARLOCK,HUNTER,MAGE" })), "raidpet5,raidpet4,raidpet2")
H.check("pets grouped by group", units(pets({ showRaid = true, groupBy = "GROUP", groupingOrder = "3,2,1" })),
    "raidpet4,raidpet2,raidpet5")
H.check("the owners' units", units(pets({ showRaid = true, useOwnerUnit = true })), "raid2,raid4,raid5")
H.check("pets of named owners", units(pets({ showRaid = true, nameList = "Bob,Zed,Tank" })), "raidpet4,raidpet5")
H.check("named pets", units(pets({ showRaid = true, nameList = "Wolf", filterOnPet = true })), "raidpet4")
H.check("no role filter for pets", units(pets({ showRaid = true, groupFilter = "MAINTANK" })), "")

-- A party: "pet" is yours, "partypet1" your first member's. A member's
-- name is UnitName's two values joined, as the client does.
M.SetRaidRoster({})
M.units.player = { name = "Me", class = "HUNTER", isPlayer = true }
M.units.pet = { name = "Cat" }
M.units.party1 = { name = "Lea", surname = "Stone", class = "WARLOCK", isPlayer = true }
M.units.partypet1 = { name = "Imp" }
M.units.party2 = { name = "Kim", class = "MAGE", isPlayer = true }
M.SetGroup({ "party1", "party2" })
H.check("party pets", units(pets({ showParty = true, showPlayer = true })), "pet,partypet1")
H.check("party pets without yours", units(pets({ showParty = true })), "partypet1")
H.check("party names joined", units(header({ showParty = true, showPlayer = true, nameList = "Lea-Stone,Me" })),
    "player,party1")
H.check("party: the first name alone does not match", units(header({ showParty = true, nameList = "Lea" })), "")
H.check("nothing blocked", #M.blocked, 0)
