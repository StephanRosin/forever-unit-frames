local _, ns = ...

-- Where the profile comes from and where it goes. Load order:
-- SavedVariables -> registered providers -> old macro backup -> defaults.
-- Saving goes to SavedVariables and the providers.
--
-- The macro backup (see MacroBackup) is only read to migrate a profile
-- that exists nowhere else: when SavedVariables arrive empty. Once the
-- profile is in SavedVariables, the backup macros are deleted.
local Storage = {}
ns.Storage = Storage

local providers = {}      -- ordered list of { name =, load =, save = }
local attached            -- the SavedVariables table
local source = "Defaults"
local sourceIsProvider = false
local lastSaved           -- last string handed to SavedVariables and providers
local waiting = false     -- true while an old backup may still arrive
local saveHeld = false    -- a save was requested while waiting
local lateMigration = false  -- the wait timed out, nothing saved yet
local cleanupDue = false  -- the profile is in SavedVariables: the macros may go
local cleanupDone = false -- deleted (and announced) this session

function ns.api.RegisterStorageProvider(name, provider)
    assert(type(name) == "string" and name ~= "", "provider name required")
    assert(type(provider) == "table" and type(provider.load) == "function"
        and type(provider.save) == "function", "provider needs load and save")
    providers[#providers + 1] = { name = name, load = provider.load, save = provider.save }
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

local function fromString(str)
    if type(str) ~= "string" then return nil end
    return (ns.Codec.Decode(str))
end

-- The old macro backup as a profile. Entries that cannot be parsed are
-- dropped: no version of the addon could read them.
local function fromMacro()
    return fromString(ns.MacroBackup.Read())
end

function Storage.Attach(db)
    attached = db
end

-- Only known scopes and settings that apply to them survive, each with a
-- value that passes validation: a hand-edited or outdated SavedVariables
-- file must never reach Config or the codec.
local function sanitise(profile)
    local Settings = ns.Settings
    local clean = {}
    for _, scope in ipairs(Settings.SCOPES) do
        clean[scope] = {}
        local values = profile[scope]
        if type(values) == "table" then
            for key, v in pairs(values) do
                local def = Settings.Get(key)
                if def and Settings.AppliesTo(def, scope) then
                    clean[scope][key] = Settings.Validate(def, v)
                end
            end
        end
    end
    return clean
end

local function from(name, isProvider, profile)
    source, sourceIsProvider = name, isProvider
    return profile, source
end

function Storage.Load(db)
    if type(db) == "table" and type(db.profile) == "table" then
        return from("SavedVariables", false, sanitise(db.profile))
    end
    for _, p in ipairs(providers) do
        local ok, str = pcall(p.load)
        local profile = ok and fromString(str)
        if profile then return from(p.name, true, profile) end
    end
    local profile = fromMacro()
    if profile then return from("MacroBackup", false, profile) end
    return from("Defaults", false, fromString("1"))
end

-- The source id and whether it is a provider (whose name is shown as
-- given) rather than one of our own sources (shown via ns.L).
function Storage.Source()
    return source, sourceIsProvider
end

-- Deleting the old macros ---------------------------------------------------
-- Tried when the profile is safe in SavedVariables, and again whenever the
-- macros change (they reach the client after PLAYER_LOGIN) or the macro
-- window closes, until something was deleted.
local function cleanup()
    if cleanupDone or not cleanupDue then return end
    local deleted = ns.MacroBackup.Delete()
    if deleted and deleted > 0 then
        -- Silent: the macros were ours, nothing for the player to do.
        cleanupDone = true
    end
end

local function tryCleanup()
    if cleanupDue and not cleanupDone then ns.AfterCombat("macroCleanup", cleanup) end
end

local function startCleanup()
    cleanupDue = true
    tryCleanup()
end

local tryMigrate  -- defined with the wait below

-- SavedVariables and providers get each new string once. While waiting
-- for an old backup nothing is written at all: the profile in memory may
-- be defaults standing in for a backup not yet loaded. After the wait, a
-- backup that has turned up before the first save still wins over the
-- defaults (and over changes made on top of them).
function Storage.Save()
    if waiting then saveHeld = true; return end
    if lateMigration and tryMigrate() then return end
    local profile = ns.Config.Profile()
    if not profile then return end
    lateMigration = false
    local encoded = ns.Codec.Encode(profile)
    if encoded == lastSaved then return end
    lastSaved = encoded
    if attached then
        attached.version = ns.Codec.VERSION
        attached.profile = copy(profile)
    end
    for _, p in ipairs(providers) do pcall(p.save, encoded) end
end

-- Sliders fire many changes per second; one save per half second is plenty.
local saveQueued = false

function Storage.RequestSave()
    if waiting then saveHeld = true; return end
    if saveQueued then return end
    saveQueued = true
    C_Timer.After(0.5, function()
        saveQueued = false
        Storage.Save()
    end)
end

function Storage.Flush()
    Storage.Save()
end

-- A migrated profile goes to SavedVariables at once; from then on the
-- macros hold nothing that SavedVariables do not.
local function handOver()
    Storage.Save()
    if attached and attached.profile then startCleanup() end
end

-- Waiting for an old backup ----------------------------------------------------
-- Character macros reach the client from the server after PLAYER_LOGIN
-- (UPDATE_MACROS). With empty SavedVariables and no provider data,
-- defaults at login may just mean an old backup has not arrived yet.
-- Saving then would put defaults into SavedVariables and lose the backup's
-- settings, so every save is held back until the backup is read or the
-- wait times out.
--
-- Changes made while waiting stay in memory. If the wait ends with a
-- migrated backup, the backup wins (Import replaces them). If it times out
-- (a genuine first install), they are saved as usual.
local WAIT_SECONDS = 15

function Storage.IsWaiting()
    return waiting
end

local function endWait(newSource)
    waiting = false
    source, sourceIsProvider = newSource, false
    if saveHeld then
        saveHeld = false
        Storage.RequestSave()
    end
end

-- Frames switched on at the moment, by scope.
local function enabledFrames()
    local states = {}
    for _, scope in ipairs(ns.Settings.SCOPES) do
        if scope ~= "general" then states[scope] = ns.Config.Get(scope, "enabled") end
    end
    return states
end

-- Blizzard's frames are already hidden for every frame that was on; one
-- the backup turns off only gets Blizzard's back after a /reload. The
-- player's hideBlizzardCastbar is a second such flag: Blizzard.Conceal
-- hides Blizzard's cast bar in response to a change (login, or
-- hideBlizzardCastbar turning on) and never reveals it again on its own,
-- so the same problem applies if the backup turns it back off.
local function hintReload(before, beforeHideCastbar)
    for scope, was in pairs(before) do
        if was and not ns.Config.Get(scope, "enabled") then
            ns.Print(ns.L.RELOAD_FOR_BLIZZARD)
            return
        end
    end
    if beforeHideCastbar and not ns.Config.Get("player", "hideBlizzardCastbar") then
        ns.Print(ns.L.RELOAD_FOR_BLIZZARD)
    end
end

-- Returns true once a complete backup has been read, imported and handed
-- to SavedVariables.
function tryMigrate()
    local profile = fromMacro()
    if not profile then return false end
    local before = enabledFrames()
    local beforeHideCastbar = ns.Config.Get("player", "hideBlizzardCastbar")
    lateMigration = false
    ns.Config.Import(profile)   -- its CONFIG_CHANGED save is held or queued
    hintReload(before, beforeHideCastbar)
    endWait("MacroBackup")
    handOver()
    return true
end

-- Called at PLAYER_LOGIN after Load and Attach.
-- * SavedVariables loaded: the old macros can go.
-- * Migrated at load: hand the profile to SavedVariables, then the same.
-- * Defaults (SavedVariables empty, no provider): wait for an old backup.
-- * A provider: nothing to do; SavedVariables take over from the next save.
function Storage.Start()
    if waiting then return end
    if source == "SavedVariables" then
        startCleanup()
    elseif source == "MacroBackup" then
        handOver()
    elseif source == "Defaults" then
        waiting, saveHeld = true, false
        source, sourceIsProvider = "Waiting", false
        C_Timer.After(WAIT_SECONDS, function()
            if not waiting then return end
            -- One last look in case the event was missed; otherwise defaults.
            if not tryMigrate() then
                endWait("Defaults")
                lateMigration = true
            end
        end)
    end
end

ns.On("UPDATE_MACROS", function()
    if waiting or lateMigration then
        if tryMigrate() then return end
    end
    tryCleanup()
end)

-- Closing the macro window is the moment a refused deletion can succeed.
-- The window is load-on-demand: hook it now if it exists, else once
-- Blizzard_MacroUI has loaded.
local hookedMacroFrame
local function hookMacroFrame()
    local frame = _G.MacroFrame
    if not frame or frame == hookedMacroFrame or not frame.HookScript then return end
    hookedMacroFrame = frame
    frame:HookScript("OnHide", tryCleanup)
end

hookMacroFrame()
ns.On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_MacroUI" then hookMacroFrame() end
end)
