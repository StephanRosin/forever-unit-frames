local _, ns = ...

-- Named unit frame profiles (decision 78): account-wide in
-- ForeverUnitFramesDB.profiles, each character's choice in .active
-- ("Name-Realm" -> name). Default always exists. Storage loads and
-- saves the active one; the raid frames keep their own per character.
local UnitProfiles = {}
ns.UnitProfiles = UnitProfiles

UnitProfiles.DEFAULT = "Default"
UnitProfiles.NAME_LETTERS = 40

local db = { profiles = {}, active = {} }
local active = UnitProfiles.DEFAULT

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

local function trimmed(name)
    return type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
end

local function charKey() return ns.RaidProfiles.CharKey() end

-- The stored name with this name ignoring case, if any.
local function find(name)
    local key = name:lower()
    for stored in pairs(db.profiles) do
        if stored:lower() == key then return stored end
    end
    return nil
end

-- At login, before Storage reads the profile. The old single profile
-- becomes Default; it wins over a Default already there, since only an
-- older version (which knows one profile) writes it besides our mirror.
function UnitProfiles.Attach(saved)
    db = type(saved) == "table" and saved or { }
    if type(db.profiles) ~= "table" then db.profiles = {} end
    if type(db.active) ~= "table" then db.active = {} end
    -- db.profile stays as a mirror of Default (see Write): it is our own copy
    -- or what an older version edited since.
    if type(db.profile) == "table" then db.profiles[UnitProfiles.DEFAULT] = db.profile end
    for name, p in pairs(db.profiles) do
        if type(name) ~= "string" or type(p) ~= "table" then db.profiles[name] = nil end
    end
    local chosen = db.active[charKey()]
    active = (type(chosen) == "string" and db.profiles[chosen]) and chosen or UnitProfiles.DEFAULT
end

function UnitProfiles.Active() return active end

function UnitProfiles.Stored() return db.profiles[active] end

function UnitProfiles.Names()
    local names = {}
    for name in pairs(db.profiles) do
        if name ~= UnitProfiles.DEFAULT then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    table.insert(names, 1, UnitProfiles.DEFAULT)
    return names
end

function UnitProfiles.Write(profile)
    db.profiles[active] = copy(profile)
    -- An older version reads only this key; the mirror keeps its Default.
    if active == UnitProfiles.DEFAULT then db.profile = copy(profile) end
end

local function setActive(name)
    active = name
    db.active[charKey()] = name
end

-- Loads a stored profile into the frames (Config.Import keeps the
-- personal settings, the language).
local function load(name)
    ns.Storage.Save()   -- the current one, before it is left
    setActive(name)
    ns.Config.Import(ns.Settings.Sanitise(copy(db.profiles[name] or {})))
    ns.Storage.Save()
end

local function changed() ns.Fire("UNIT_PROFILES_CHANGED") return true end

-- nil and why for a name that cannot be used; except: the stored name
-- that may keep it (renaming changes only the case).
local function refuse(name, except)
    if name == "" then return "EMPTY" end
    if select(2, name:gsub("[^\128-\191]", "")) > UnitProfiles.NAME_LETTERS then return "TOO_LONG" end
    -- It would look identical to Default in the dropdown.
    if name:lower() == ns.L.PROFILE_DEFAULT:lower() then return "TAKEN" end
    local taken = find(name)
    if taken and taken ~= except then return "TAKEN" end
    return nil
end

function UnitProfiles.Switch(name)
    if InCombatLockdown() then return nil, "COMBAT" end
    if ns.Storage.IsWaiting() then return nil, "WAITING" end
    -- Default may not be written yet (fresh install); load() copes.
    if not db.profiles[name] and name ~= UnitProfiles.DEFAULT then return nil, "GONE" end
    if name == active then return true end
    load(name)
    return changed()
end

-- The current settings under a new name; this character moves onto it and
-- the old profile keeps what it last saved. Written at once: Storage.Save
-- skips a text equal to the last one.
function UnitProfiles.SaveAs(name)
    if ns.Storage.IsWaiting() then return nil, "WAITING" end
    name = trimmed(name)
    local why = refuse(name)
    if why then return nil, why end
    db.profiles[name] = copy(ns.Config.Profile())
    setActive(name)
    return changed()
end

function UnitProfiles.Rename(name)
    if ns.Storage.IsWaiting() then return nil, "WAITING" end
    name = trimmed(name)
    if active == UnitProfiles.DEFAULT then return nil, "DEFAULT" end
    local why = refuse(name, active)
    if why then return nil, why end
    if name == active then return true end   -- the move below would drop it
    local old = active
    db.profiles[name], db.profiles[old] = db.profiles[old], nil
    for key, chosen in pairs(db.active) do
        if chosen == old then db.active[key] = name end
    end
    active = name
    return changed()
end

function UnitProfiles.Delete()
    if ns.Storage.IsWaiting() then return nil, "WAITING" end
    if active == UnitProfiles.DEFAULT then return nil, "DEFAULT" end
    if InCombatLockdown() then return nil, "COMBAT" end
    local old = active
    for key, chosen in pairs(db.active) do
        if chosen == old then db.active[key] = nil end
    end
    -- Not saved back: load() would write the current settings under it again.
    active = UnitProfiles.DEFAULT
    db.profiles[old] = nil
    ns.Config.Import(ns.Settings.Sanitise(copy(db.profiles[UnitProfiles.DEFAULT] or {})))
    ns.Storage.Save()
    return changed()
end
