local _, ns = ...

-- Where the profile comes from and where it goes. Load order:
-- SavedVariables -> registered providers -> macro backup -> defaults.
local Storage = {}
ns.Storage = Storage

local providers = {}      -- ordered list of { name =, load =, save = }
local attached            -- the SavedVariables table
local source = "defaults"
local lastSaved

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

function Storage.Load(db)
    if type(db) == "table" and type(db.profile) == "table" then
        source = "SavedVariables"
        return copy(db.profile), source
    end
    for _, p in ipairs(providers) do
        local ok, str = pcall(p.load)
        local profile = ok and fromString(str)
        if profile then
            source = p.name
            return profile, source
        end
    end
    local profile = fromString(ns.MacroBackup.Read())
    if profile then
        source = "macro backup"
        return profile, source
    end
    source = "defaults"
    return fromString("1"), source
end

function Storage.Source()
    return source
end

function Storage.Save()
    local profile = ns.Config.Profile()
    local encoded = ns.Codec.Encode(profile)
    if encoded == lastSaved then return end
    lastSaved = encoded
    if attached then
        attached.version = ns.Codec.VERSION
        attached.profile = copy(profile)
    end
    for _, p in ipairs(providers) do pcall(p.save, encoded) end
    ns.AfterCombat("macroBackup", function() ns.MacroBackup.Write(encoded) end)
end
