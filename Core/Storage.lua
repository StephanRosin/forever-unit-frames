local _, ns = ...

-- Where the profile comes from and where it goes. Load order:
-- SavedVariables -> registered providers -> macro backup -> defaults.
local Storage = {}
ns.Storage = Storage

local providers = {}      -- ordered list of { name =, load =, save = }
local attached            -- the SavedVariables table
local source = "Defaults"
local sourceIsProvider = false
local lastSaved           -- last string handed to SavedVariables and providers
local lastMacro           -- last string the macro backup actually accepted
local macroError          -- LastError of the most recent refused macro write
local unreadableShown     -- MACRO_UNREADABLE was printed this session
local overwriteAllowed    -- the player asked to replace everything
local waiting = false     -- true while character macros may still arrive
local saveHeld = false    -- a save was requested while waiting

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

-- The macro backup as a profile, plus the string it came from (already
-- normalised by Read). A backup with entries that could not be parsed is
-- still loaded, as far as it goes, but must never be overwritten: saving
-- the rest back would make the loss permanent. MacroBackup.Write refuses
-- it; here the player is told once, at the moment it is loaded.
-- Every refusal is printed when it first occurs; MACRO_UNREADABLE only once
-- per session, even if another refusal came in between.
local function report(err)
    if not err or err == macroError then return end
    macroError = err
    if err == "MACRO_UNREADABLE" then
        if unreadableShown then return end
        unreadableShown = true
    end
    ns.Print(ns.L[err])
end

local function fromMacro()
    local str = ns.MacroBackup.Read()
    if type(str) ~= "string" then return nil end
    local profile, _, rejected = ns.Codec.Decode(str)
    if not profile then return nil end
    if rejected > 0 then report("MACRO_UNREADABLE") end
    return profile, str
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
    local profile, str = fromMacro()
    if profile then
        lastMacro = str     -- already in the macros, no need to rewrite it
        return from("MacroBackup", false, profile)
    end
    return from("Defaults", false, fromString("1"))
end

-- The source id and whether it is a provider (whose name is shown as
-- given) rather than one of our own sources (shown via ns.L).
function Storage.Source()
    return source, sourceIsProvider
end

function Storage.MacroError()
    return macroError
end

-- Called by the explicit "replace everything" actions (/fuf reset all, the
-- options window's reset and profile import): the next macro write may
-- replace a backup that could not be read in full. Without it such a
-- backup would win every session, since SavedVariables are not loaded.
-- Holds until a write succeeds.
function Storage.AllowMacroOverwrite()
    overwriteAllowed = true
end

-- A readable backup this session has neither loaded nor written must never
-- be overwritten: it may have arrived after the wait for macros timed out.
-- True while such a backup could still turn up (we run on defaults and have
-- not touched the macros yet). Before PLAYER_LOGIN no profile is in use and
-- nothing may be restored into it.
local function backupUnclaimed()
    return source == "Defaults" and lastMacro == nil and ns.Config.Profile() ~= nil
end

local tryRestore  -- defined with the wait below

local function writeMacro(encoded)
    -- Nothing to write: the one-shot permission is spent all the same.
    if encoded == lastMacro then overwriteAllowed = nil; return end
    -- Checked again here: this may run after combat, long after Save().
    if backupUnclaimed() and tryRestore() then return end
    local ok, written = pcall(ns.MacroBackup.Write, encoded, overwriteAllowed)
    if ok and written then
        lastMacro, macroError, overwriteAllowed = encoded, nil, nil
        return
    end
    report(ns.MacroBackup.LastError())
end

-- SavedVariables and providers get each new string once; the macro backup
-- is retried until it has accepted the current string, since the client
-- may refuse a write (macro window open, no free slot, ...).
-- While waiting for macros nothing is written at all: the profile in
-- memory may be defaults standing in for a backup not yet loaded.
-- Running on defaults without having touched the macros, a backup that
-- has turned up since is restored first and wins over the defaults (and
-- over changes made on top of them).
function Storage.Save()
    if waiting then saveHeld = true; return end
    if backupUnclaimed() then tryRestore() end
    local profile = ns.Config.Profile()
    if not profile then return end
    local encoded = ns.Codec.Encode(profile)
    if encoded ~= lastSaved then
        lastSaved = encoded
        if attached then
            attached.version = ns.Codec.VERSION
            attached.profile = copy(profile)
        end
        for _, p in ipairs(providers) do pcall(p.save, encoded) end
    end
    ns.AfterCombat("macroBackup", function() writeMacro(encoded) end)
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

-- Waiting for macros ----------------------------------------------------------
-- Character macros reach the client from the server after PLAYER_LOGIN
-- (UPDATE_MACROS). With no SavedVariables and no provider data, defaults
-- at login may just mean the backup has not arrived yet. Saving then would
-- overwrite a good backup with defaults, so every save is held back until
-- the backup is read or the wait times out.
--
-- Changes made while waiting stay in memory. If the wait ends with a
-- restored backup, the backup wins (Import replaces them). If it times out
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

-- Returns true once a complete backup has been read and imported.
function tryRestore()
    local profile, str = fromMacro()
    if not profile then return false end
    local before = enabledFrames()
    local beforeHideCastbar = ns.Config.Get("player", "hideBlizzardCastbar")
    ns.Config.Import(profile)   -- its CONFIG_CHANGED save is held or queued
    hintReload(before, beforeHideCastbar)
    lastMacro = str             -- already in the macros, no need to rewrite it
    endWait("MacroBackup")
    ns.Print(ns.L.RESTORED_FROM_MACRO)
    return true
end

-- Called at PLAYER_LOGIN after Load: only when Load fell back to defaults.
function Storage.WaitForMacros()
    if source ~= "Defaults" or waiting then return end
    waiting, saveHeld = true, false
    source, sourceIsProvider = "Waiting", false
    C_Timer.After(WAIT_SECONDS, function()
        if not waiting then return end
        -- One last look in case the event was missed; otherwise defaults.
        if not tryRestore() then endWait("Defaults") end
    end)
end

-- Macros may also arrive after the timeout: keep listening until the
-- macros are ours (restored or written).
ns.On("UPDATE_MACROS", function()
    if waiting or backupUnclaimed() then tryRestore() end
end)

-- Closing the macro window is the moment a refused write can succeed.
-- The window is load-on-demand: hook it now if it exists, else once
-- Blizzard_MacroUI has loaded.
local hookedMacroFrame
local function hookMacroFrame()
    local frame = _G.MacroFrame
    if not frame or frame == hookedMacroFrame or not frame.HookScript then return end
    hookedMacroFrame = frame
    frame:HookScript("OnHide", function() Storage.Save() end)
end

hookMacroFrame()
ns.On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_MacroUI" then hookMacroFrame() end
end)
