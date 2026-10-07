-- Decision 77: 0.23.0 ships a revised look for new installs only. A unit
-- frame profile saved before (no marker, or an older one) keeps 0.22.0's
-- shipped look: every value whose preset changed and that it did not set
-- itself becomes an override holding the old value (Core/PresetUpgrade.lua).
local M = H.M

-- Every effective value of every scope.
local function values(ns)
    local out = {}
    for _, scope in ipairs(ns.Settings.SCOPES) do
        out[scope] = {}
        for _, def in ipairs(ns.Settings.All()) do
            if ns.Settings.AppliesTo(def, scope) then out[scope][def.key] = ns.Config.Get(scope, def.key) end
        end
    end
    return out
end

local function same(a, b)
    if type(a) == "table" and type(b) == "table" then
        for i = 1, 4 do if a[i] ~= b[i] then return false end end
        return true
    end
    return a == b
end

local function compare(label, got, want)
    local wrong, first = 0, nil
    for scope, list in pairs(want) do
        for key, v in pairs(list) do
            if not same(got[scope][key], v) then
                wrong = wrong + 1
                first = first or (scope .. "." .. key .. " = " .. tostring(got[scope][key]) .. ", want " .. tostring(v))
            end
        end
    end
    H.check(label .. (first and (" (" .. first .. ")") or ""), wrong, 0)
end

-- What 0.22.0 showed: the plain defaults with its preset (kept as data in
-- the upgrade), on a profile with the given overrides.
local shipped = H.LoadShipped()
local OLD = shipped.PresetUpgrade.PRESET_0_22
H.check("the version of the revised look", shipped.PresetUpgrade.VERSION, "0.23.0")
local function oldLook(profile)
    local ns = H.LoadAddon()
    ns.Settings.ApplyPreset(OLD)
    ns.Config.Use(profile)
    return values(ns)
end
local function newLook(profile)
    local ns = H.LoadShipped()
    ns.Config.Use(profile)
    return values(ns)
end
local function copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = copy(v) end
    return c
end

-- The revised look differs from 0.22.0's (or there is nothing to keep).
local changed = 0
do
    local old, new = oldLook({}), newLook({})
    for scope, list in pairs(new) do
        for key, v in pairs(list) do if not same(old[scope][key], v) then changed = changed + 1 end end
    end
end
H.checkTrue("the look changed", changed > 0)

-- The expected looks, worked out before any boot (loading the addon again
-- resets the mock, and with it a booted addon's events).
local own = { general = { classIconY = -2, showSurname = true }, player = { width = 250, height = 40 },
    target = { buffsPerRow = 7 }, party = { width = 180 } }
local OLD_LOOK, NEW_LOOK, OLD_OWN = oldLook({}), newLook({}), oldLook(copy(own))
local OLD_MACRO, NEW_PROVIDER = oldLook({ player = { width = 260 } }), newLook({ player = { width = 260 } })

-- A boot with these SavedVariables: the addon and its profile's values.
local function boot(db)
    local ns = H.LoadShipped()
    _G.ForeverUnitFramesDB = db
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns, values(ns)
end

-- A 0.22.0 profile that kept every default: 0.22.0's look, every value.
local db = { version = 1, profile = {} }
local ns, got = boot(db)
compare("0.22.0 profile, no overrides: as 0.22.0", got, OLD_LOOK)
H.checkTrue("its overrides now hold the old values", next(ns.Config.Profile().player) ~= nil)
M.FireEvent("PLAYER_LOGOUT")
H.check("marked once saved", db.presetVersion, "0.23.0")
-- Saved: once. The next login reads it as it is and changes nothing.
local saved = copy(db.profile)
local again
ns, again = boot(db)
compare("next login: the same look", again, OLD_LOOK)
M.FireEvent("PLAYER_LOGOUT")
local changedAgain = 0
for scope, list in pairs(db.profile) do
    for key, v in pairs(list) do if not same(saved[scope][key], v) then changedAgain = changedAgain + 1 end end
    for key in pairs(saved[scope] or {}) do if list[key] == nil then changedAgain = changedAgain + 1 end end
end
H.check("runs once: nothing more stored", changedAgain, 0)

-- A profile with overrides of its own keeps them; the rest looks as in 0.22.0.
ns, got = boot({ version = 1, profile = copy(own) })
compare("0.22.0 profile with overrides: as 0.22.0", got, OLD_OWN)
local p = ns.Config.Profile()
H.check("own player width kept", p.player.width, 250)
H.check("own target row kept", p.target.buffsPerRow, 7)
H.check("own general value kept", p.general.classIconY, -2)
H.check("own party width kept", p.party.width, 180)

-- An older marker counts as before the revised look.
ns, got = boot({ version = 1, presetVersion = "0.22.9", profile = {} })
compare("older marker: as 0.22.0", got, OLD_LOOK)

-- A fresh install (no SavedVariables): the revised look, nothing stored.
local fresh = {}
ns, got = boot(nil)
compare("fresh install: the revised look", got, NEW_LOOK)
for _, scope in ipairs(ns.Settings.SCOPES) do
    H.check("fresh install: no override in " .. scope, next(ns.Config.Profile()[scope]), nil)
end
M.FireEvent("PLAYER_LOGOUT")
H.check("fresh install marked", _G.ForeverUnitFramesDB.presetVersion, "0.23.0")
-- A profile already marked: no upgrade.
ns, got = boot({ version = 1, presetVersion = "0.23.0", profile = {} })
compare("marked profile: the revised look", got, NEW_LOOK)

-- An old macro backup is from before: it keeps 0.22.0's look.
ns = H.LoadShipped()
ns.MacroBackup.Read = function() return "1;pW260" end
local fromMacro = ns.Storage.Load({})
ns.Config.Use(fromMacro)
compare("macro backup: as 0.22.0", values(ns), OLD_MACRO)

-- A storage provider's string is read like an import: relative to the
-- shipped look of this version (strings carry no version of the look).
ns = H.LoadShipped()
ForeverUnitFrames.RegisterStorageProvider("Plain", { load = function() return "1;pW260" end, save = function() end })
local fromProvider = ns.Storage.Load({})
ns.Config.Use(fromProvider)
compare("provider string: the revised look", values(ns), NEW_PROVIDER)

-- Without the shipped look (the other tests) nothing is upgraded.
local plain = H.LoadAddon()
local plainProfile = { player = {} }
H.check("no preset, no upgrade", plain.PresetUpgrade.Apply(plainProfile), 0)

-- The data: 0.22.0's preset, every value valid for its setting and scope.
local plainDefaults = H.LoadAddon()
H.checkTrue("0.22.0's preset applies", pcall(plainDefaults.Settings.ApplyPreset, OLD))
