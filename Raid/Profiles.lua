local _, ns = ...

-- Raid profiles, one set per character, kept in the account-wide
-- SavedVariables: ForeverUnitFramesDB.raid["Name-Realm"] = { general = {},
-- r10 = {}, r20 = {}, r40 = {} }, overrides only, like the unit-frame
-- profile. Having every character in one table is what lets one copy
-- another's sizes. The table in use is the saved one itself: every change
-- is in SavedVariables at once, nothing has to be flushed.
local Profiles = {}
ns.RaidProfiles = Profiles

local Raid, RaidSettings = ns.Raid, ns.RaidSettings
local RaidConfig = ns.NewConfig(RaidSettings, "RAID_CONFIG_CHANGED", {})
ns.RaidConfig = RaidConfig
local RaidCodec = ns.NewCodec(RaidSettings)
ns.RaidCodec = RaidCodec

local store     -- ForeverUnitFramesDB.raid
local charKey   -- this character's key in it

-- "Name-Realm". UnitFullName can leave the realm out early in the login;
-- the normalised realm name stands in.
function Profiles.CharKey()
    local name, realm = UnitFullName("player")
    if not realm or realm == "" then realm = GetNormalizedRealmName() end
    return name .. "-" .. realm
end

-- At PLAYER_LOGIN: this character's profile, cleaned, becomes the one in use.
function Profiles.Attach(db)
    if type(db.raid) ~= "table" then db.raid = {} end
    store = db.raid
    charKey = Profiles.CharKey()
    local own = store[charKey]
    local profile = RaidSettings.Sanitise(type(own) == "table" and own or {})
    store[charKey] = profile
    RaidConfig.Use(profile)
end

-- The other characters that have a raid profile, sorted.
function Profiles.Characters()
    local keys = {}
    for key, p in pairs(store or {}) do
        if key ~= charKey and type(p) == "table" then keys[#keys + 1] = key end
    end
    table.sort(keys)
    return keys
end

function Profiles.CopySize(fromSize, toSize)
    RaidConfig.CopyScope(Raid.Scope(fromSize), Raid.Scope(toSize))
end

-- Another character's size onto one of ours. False if there is no such
-- character.
function Profiles.CopyFromCharacter(key, fromSize, toSize)
    local source = store and store[key]
    if key == charKey or type(source) ~= "table" then return false end
    RaidConfig.CopyScopeFrom(RaidSettings.Sanitise(source), Raid.Scope(fromSize), Raid.Scope(toSize))
    return true
end

-- The click-casting bindings and keys (per character, Raid.CLICK_SLOTS
-- and Raid.CLICK_KEYS): every one, for a copy or Clear all.
function Profiles.ClickKeys()
    local keys = {}
    for _, slot in ipairs(Raid.CLICK_SLOTS) do keys[#keys + 1] = slot.key end
    for _, slot in ipairs(Raid.CLICK_KEYS) do
        keys[#keys + 1] = slot.key
        keys[#keys + 1] = slot.bind
    end
    return keys
end

-- A copied binding as this character has it: a spell through its spell
-- book (as the book writes it), or nil and the spell's name when it does
-- not know it. Everything else as it is.
local function ownBinding(binding)
    local kind, value = Raid.ParseBinding(binding)
    if kind ~= "spell" or value == "" then return binding end
    local name = ns.ClickCast.TypedValue("spell", value)
    if name == nil then return nil, value end
    return "spell:" .. name
end

-- Another character's click-casting bindings and keys onto ours (the
-- switches stay); what it left at the defaults is the default here too.
-- A spell this character does not know is left out (the default stays)
-- and named in the chat; so is a key that is this character's smart buff
-- key (buffKey: one key, one meaning). False if there is no such
-- character.
function Profiles.CopyClickCast(key)
    local source = store and store[key]
    if key == charKey or type(source) ~= "table" then return false end
    local general = RaidSettings.Sanitise(source).general
    local keySlots = {}
    for _, slot in ipairs(Raid.CLICK_KEYS) do keySlots[slot.key] = true end
    local buffKey = RaidConfig.Get("general", "buffKey")
    local values, dropped, buffKeyDropped = {}, {}, false
    for _, k in ipairs(Profiles.ClickKeys()) do
        local default = RaidSettings.Default(RaidSettings.Get(k), "general")
        local v = general[k]
        if v == nil then v = default end
        if RaidSettings.Get(k).kinds then
            local own, unknown = ownBinding(v)
            if own == nil then dropped[#dropped + 1] = unknown end
            v = own or default
        elseif keySlots[k] and v ~= "" and v == buffKey then
            v, buffKeyDropped = default, true
        end
        values[#values + 1] = { k, v }
    end
    if #dropped > 0 then ns.Print(ns.L.RAID_CLICK_COPY_DROPPED:format(table.concat(dropped, ", "))) end
    if buffKeyDropped then ns.Print(ns.L.RAID_CLICK_COPY_BUFF_KEY:format(buffKey)) end
    return RaidConfig.SetKeys("general", values)
end

function Profiles.ResetSize(size)
    RaidConfig.ResetScope(Raid.Scope(size))
end

-- One size as a string; the size itself is written as the scope letter.
function Profiles.Export(size)
    return RaidCodec.Encode(RaidConfig.Profile(), { Raid.Scope(size) })
end

-- Puts an exported size on `size`, replacing everything that size had.
-- The first size found in the string counts (an export holds one). A
-- string without any is refused (RAID_NO_SIZE), unless it is exactly
-- what a size left at the defaults exports: the format version alone,
-- which resets the size. Returns true and how many entries the codec
-- could not read (they are left out); or nil and an error key.
function Profiles.Import(str, size)
    local decoded, err, rejected = RaidCodec.Decode(str)
    if not decoded then return nil, err end
    local target = Raid.Scope(size)
    for _, s in ipairs(Raid.SIZES) do
        local scope = Raid.Scope(s)
        if next(decoded[scope]) then
            RaidConfig.CopyScopeFrom(decoded, scope, target)
            return true, rejected
        end
    end
    if str ~= tostring(RaidCodec.VERSION) then return nil, "RAID_NO_SIZE" end
    RaidConfig.ResetScope(target)
    return true, rejected
end
