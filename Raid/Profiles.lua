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
