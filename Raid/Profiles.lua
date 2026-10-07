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

-- A value of its own (a colour is a table: never share one).
local function copied(v)
    if type(v) == "table" then return { v[1], v[2], v[3], v[4] } end
    return v
end
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

-- Copy between sizes as one change that Undo takes back (Raid/Templates
-- .lua): mode "ALL" copies every per-size setting as the source size
-- shows it, "BEHAVIOUR" leaves the layout and sizes (class "layout") of
-- the target as they are. False for the same size, in combat, or when
-- refused.
Profiles.COPY_MODES = { "ALL", "BEHAVIOUR" }
function Profiles.CopySizeMode(fromSize, toSize, mode)
    if fromSize == toSize then return false end
    local from, to = Raid.Scope(fromSize), Raid.Scope(toSize)
    local values = {}
    for _, def in ipairs(RaidSettings.All()) do
        if RaidSettings.AppliesTo(def, to) and (mode == "ALL" or def.class == "behaviour") then
            values[#values + 1] = { def.key, copied(RaidConfig.Get(from, def.key)) }
        end
    end
    return ns.RaidTemplates.ApplyChanges({ { scope = to, values = values } })
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

-- Every size in one string, under its own format version (decision 56):
-- version 2 is "every size", entries as version 1 writes them (a size left
-- at the defaults has none). A build that reads only version 1 refuses it
-- (CODEC_VERSION) instead of setting only the sizes with entries.
Profiles.ALL_VERSION = 2
function Profiles.ExportAll()
    local scopes = {}
    for i, size in ipairs(Raid.SIZES) do scopes[i] = Raid.Scope(size) end
    local str = RaidCodec.Encode(RaidConfig.Profile(), scopes)
    return (str:gsub("^%d+", tostring(Profiles.ALL_VERSION), 1))
end

-- A string as the codec reads it, and whether it is one of every size.
-- Version 2: the version alone or followed by ";", the rest read as
-- version 1; glued to anything else it is malformed (CODEC_FORMAT).
local function decode(str)
    if type(str) == "string" and str:match("^%d+") == tostring(Profiles.ALL_VERSION) then
        local rest = str:sub(#tostring(Profiles.ALL_VERSION) + 1)
        if rest ~= "" and rest:sub(1, 1) ~= ";" then return nil, "CODEC_FORMAT" end
        local decoded, err, rejected = RaidCodec.Decode(RaidCodec.VERSION .. rest)
        return decoded, err, rejected, true
    end
    local decoded, err, rejected = RaidCodec.Decode(str)
    return decoded, err, rejected, false
end

-- The sizes a string holds (in order): all three for a string of every
-- size, else each that has an entry. nil and an error key for a string
-- the codec refuses; also the decoded profile and how many entries it
-- left out.
function Profiles.ImportSizes(str)
    local decoded, err, rejected, all = decode(str)
    if not decoded then return nil, err end
    local sizes = {}
    for _, size in ipairs(Raid.SIZES) do
        if all or next(decoded[Raid.Scope(size)]) then sizes[#sizes + 1] = size end
    end
    return sizes, nil, decoded, rejected
end

-- Puts an exported size on `size`, replacing everything that size had.
-- A string without any size is refused (RAID_NO_SIZE), unless it is
-- exactly what a size left at the defaults exports: the format version
-- alone, which resets the size; one of several sizes too
-- (RAID_SEVERAL_SIZES: Profiles.ImportAll takes it). Returns true and how
-- many entries the codec could not read (they are left out); or nil and
-- an error key.
function Profiles.Import(str, size)
    local sizes, err, decoded, rejected = Profiles.ImportSizes(str)
    if not sizes then return nil, err end
    if #sizes > 1 then return nil, "RAID_SEVERAL_SIZES" end
    local target = Raid.Scope(size)
    if #sizes == 1 then
        RaidConfig.CopyScopeFrom(decoded, Raid.Scope(sizes[1]), target)
        return true, rejected
    end
    if str ~= tostring(RaidCodec.VERSION) then return nil, "RAID_NO_SIZE" end
    RaidConfig.ResetScope(target)
    return true, rejected
end

-- Every per-size setting of size `to` as a size `from` of a decoded
-- profile shows it: its own values, that size's defaults for the rest.
local function sizeValues(decoded, from, to)
    local values = {}
    for _, def in ipairs(RaidSettings.All()) do
        if RaidSettings.AppliesTo(def, to) and RaidSettings.AppliesTo(def, from) then
            local v = decoded[from][def.key]
            if v == nil then v = RaidSettings.Default(def, from) end
            values[#values + 1] = { def.key, copied(v) }
        end
    end
    return values
end

-- Another character's size onto one of ours, as one change that Undo
-- takes back (Raid/Templates.lua; decision 57). True; or false and why:
-- GONE (no such character), COMBAT, REFUSED.
function Profiles.CopyFromCharacter(key, fromSize, toSize)
    local source = store and store[key]
    if key == charKey or type(source) ~= "table" then return false, "GONE" end
    if InCombatLockdown() then return false, "COMBAT" end
    local from, to = Raid.Scope(fromSize), Raid.Scope(toSize)
    local values = sizeValues(RaidSettings.Sanitise(source), from, to)
    if not ns.RaidTemplates.ApplyChanges({ { scope = to, values = values } }) then return false, "REFUSED" end
    return true
end

-- Sets every size a string of several holds, each replaced as a whole,
-- as one change that Undo takes back (Raid/Templates.lua). Returns true,
-- how many entries were left out and the sizes; or nil and an error key
-- (RAID_ONE_SIZE: a string of one size, which Import takes;
-- RAID_COMBAT).
function Profiles.ImportAll(str)
    local sizes, err, decoded, rejected = Profiles.ImportSizes(str)
    if not sizes then return nil, err end
    if #sizes < 2 then return nil, "RAID_ONE_SIZE" end
    if InCombatLockdown() then return nil, "RAID_COMBAT" end
    local changes = {}
    for i, size in ipairs(sizes) do
        local scope = Raid.Scope(size)
        changes[i] = { scope = scope, values = sizeValues(decoded, scope, scope) }
    end
    if not ns.RaidTemplates.ApplyChanges(changes) then return nil, "RAID_REFUSED" end
    return true, rejected, sizes
end
