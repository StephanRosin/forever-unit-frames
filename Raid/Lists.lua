local _, ns = ...

-- Your own name lists (my tanks, favourites): kept in the raid profile's
-- General settings, so per character and permanent, as text
-- (Raid/Settings.lua: Raid.ParseNameList), written "Ann, Bob-Realm". The
-- special panels show them through their headers' nameList
-- (Raid/SpecialPanels.lua); the raid window changes them. A changed list
-- reaches the panels out of combat (a header's filter); one changed in
-- combat after combat.
local Lists = {}
ns.RaidLists = Lists

local Raid = ns.Raid

-- A list by its panel's id ("myTanks") -> its setting (Raid.PANELS).
Lists.KEYS = {}
for _, p in ipairs(Raid.PANELS) do
    if p.names then Lists.KEYS[p.id] = p.names end
end

local function key(id) return assert(Lists.KEYS[id], "unknown list " .. tostring(id)) end

-- The names on a list, in its order.
function Lists.Names(id)
    return Raid.ParseNameList(ns.RaidConfig.Get("general", key(id))) or {}
end

function Lists.Has(id, name)
    for _, n in ipairs(Lists.Names(id)) do
        if n == name then return true end
    end
    return false
end

-- False when the list would not fit its setting (or a name is refused).
local function store(id, names)
    return ns.RaidConfig.Set("general", key(id), table.concat(names, ", "))
end

-- At the end of the list; true if it is on it now.
function Lists.Add(id, name)
    if Lists.Has(id, name) then return true end
    local names = Lists.Names(id)
    names[#names + 1] = name
    return store(id, names)
end

function Lists.Remove(id, name)
    local kept = {}
    for _, n in ipairs(Lists.Names(id)) do
        if n ~= name then kept[#kept + 1] = n end
    end
    return store(id, kept)
end

function Lists.Toggle(id, name)
    if Lists.Has(id, name) then return Lists.Remove(id, name) end
    return Lists.Add(id, name)
end

-- A header's nameList: the names, comma-separated; "" for none (a header
-- with an empty list shows nobody, one without a list everybody).
function Lists.Attribute(id)
    return table.concat(Lists.Names(id), ",")
end
