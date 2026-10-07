local _, ns = ...

-- The raid window's Buffs tab (Raid/Options/Schema.lua lists its rows,
-- Raid/Options/Window.lua builds them): which rows mean something now,
-- and the smart buff key as typed. A buff's switch means something for
-- your class when the spell book knows its single form (Raid/BuffData.lua:
-- an unknown one is not offered, its row greys); the blessings for a
-- paladin who knows one, a class's blessing while the blessings are on;
-- the watch window's options while it is switched on, the cell icon's
-- point while the icon is.
local BuffsPage = {}
ns.RaidBuffsPage = BuffsPage

local Data, Raid, L = ns.RaidBuffData, ns.Raid, ns.L
local RaidOptions, RaidConfig = ns.RaidOptions, ns.RaidConfig

local function get(key) return RaidConfig.Get("general", key) end

local playerClass = ns.RaidBuffWatch.PlayerClass

-- A buff of the table: offered to you.
function BuffsPage.Offered(buff)
    return buff.class == playerClass() and Data.Highest(buff.single) ~= nil
end

-- The blessings: a paladin who knows one.
function BuffsPage.BlessingsOffered()
    if playerClass() ~= "PALADIN" then return false end
    for _, spells in pairs(Data.BLESSING) do
        if Data.Highest(spells.single) then return true end
    end
    return false
end

local ACTIVE = RaidOptions.ROW_ACTIVE
for _, buff in ipairs(Data.BUFFS) do
    ACTIVE[buff.key] = function() return BuffsPage.Offered(buff) end
end
ACTIVE[Data.BLESSINGS_KEY] = BuffsPage.BlessingsOffered
for _, key in ipairs(Raid.BLESSING_KEYS) do
    ACTIVE[key] = function() return BuffsPage.BlessingsOffered() and get(Data.BLESSINGS_KEY) == true end
end
local function windowOn() return get("buffWatchShow") == true end
ACTIVE.buffWatchOnlyMissing, ACTIVE.buffWatchX, ACTIVE.buffWatchY = windowOn, windowOn, windowOn
ACTIVE.buffCellIconPoint = function() return get("buffCellIcon") == true end

-- The smart buff key as typed: the client's spelling (Raid.ParseKey), not
-- one of the click-casting keys. nil and why refuses it.
function BuffsPage.TypedKey(text)
    local key = Raid.ParseKey(text)
    if key == nil then return nil, L.RAID_TYPED_KEY_INVALID:format(text) end
    for _, slot in ipairs(Raid.CLICK_KEYS) do
        if key ~= "" and get(slot.key) == key then return nil, L.RAID_TYPED_KEY_TWICE:format(key) end
    end
    return key
end
RaidOptions.TYPED_VALUES.buffKey = BuffsPage.TypedKey
