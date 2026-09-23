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
    local profile = fromString(ns.MacroBackup.Read())
    if profile then return from("MacroBackup", false, profile) end
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

local function writeMacro(encoded)
    if encoded == lastMacro then return end
    local ok, written = pcall(ns.MacroBackup.Write, encoded)
    if ok and written then
        lastMacro, macroError = encoded, nil
        return
    end
    local err = ns.MacroBackup.LastError()
    if err and err ~= macroError then ns.Print(ns.L[err]) end
    macroError = err
end

-- SavedVariables and providers get each new string once; the macro backup
-- is retried until it has accepted the current string, since the client
-- may refuse a write (macro window open, no free slot, ...).
function Storage.Save()
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
    if encoded ~= lastMacro then
        ns.AfterCombat("macroBackup", function() writeMacro(encoded) end)
    end
end

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
