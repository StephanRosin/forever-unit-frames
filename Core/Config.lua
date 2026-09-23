local _, ns = ...

-- Profile access. The profile holds overrides only; everything else comes
-- from inheritance (frame -> general) and the defaults in Settings.
local Config = {}
ns.Config = Config

local Settings = ns.Settings
local profile

local function sameValue(a, b)
    if type(a) == "table" and type(b) == "table" then
        for i = 1, 4 do if a[i] ~= b[i] then return false end end
        return true
    end
    return a == b
end

local function ensureScopes(p)
    for _, scope in ipairs(Settings.SCOPES) do
        if type(p[scope]) ~= "table" then p[scope] = {} end
    end
end

function Config.Use(p)
    profile = p
    ensureScopes(profile)
end

function Config.Profile()
    return profile
end

-- What a scope gets when it has no override of its own.
local function fallback(scope, def)
    if scope ~= "general" and def.scope == "inherit" then
        local g = profile.general[def.key]
        if g ~= nil then return g end
        return Settings.Default(def, "general")
    end
    return Settings.Default(def, scope)
end

function Config.Get(scope, key)
    local def = assert(Settings.Get(key), "unknown setting " .. tostring(key))
    local own = profile[scope] and profile[scope][key]
    if own ~= nil then return own end
    return fallback(scope, def)
end

function Config.IsOverridden(scope, key)
    return profile[scope] ~= nil and profile[scope][key] ~= nil
end

function Config.Set(scope, key, value)
    local def = Settings.Get(key)
    if not def or not profile[scope] or not Settings.AppliesTo(def, scope) then return false end
    local v = Settings.Validate(def, value)
    if v == nil then return false end
    if sameValue(v, fallback(scope, def)) then
        profile[scope][key] = nil
    else
        profile[scope][key] = v
    end
    ns.Fire("CONFIG_CHANGED", scope, key)
    return true
end

function Config.ResetScope(scope)
    profile[scope] = {}
    ns.Fire("CONFIG_CHANGED", scope, nil)
end

function Config.ResetAll()
    for _, scope in ipairs(Settings.SCOPES) do profile[scope] = {} end
    ns.Fire("CONFIG_CHANGED", nil, nil)
end

function Config.ClearOverride(scope, key)
    if not profile[scope] then return end
    profile[scope][key] = nil
    ns.Fire("CONFIG_CHANGED", scope, key)
end

-- Positions stay put: copying a frame's look must not stack two frames.
local NOT_COPIED = { x = true, y = true }

function Config.CopyScope(from, to)
    if not profile[from] or not profile[to] or from == to then return end
    local copy = {}
    for key, value in pairs(profile[from]) do
        local def = Settings.Get(key)
        if def and not NOT_COPIED[key] and Settings.AppliesTo(def, to) then
            copy[key] = type(value) == "table" and { value[1], value[2], value[3], value[4] } or value
        end
    end
    for key in pairs(NOT_COPIED) do copy[key] = profile[to][key] end
    profile[to] = copy
    ns.Fire("CONFIG_CHANGED", to, nil)
end

function Config.Import(p)
    for _, scope in ipairs(Settings.SCOPES) do
        profile[scope] = type(p[scope]) == "table" and p[scope] or {}
    end
    ns.Fire("CONFIG_CHANGED", nil, nil)
end
