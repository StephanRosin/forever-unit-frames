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

local function hasFrameDefaults(def)
    local d = def.default
    if type(d) ~= "table" or d._ == nil then return false end
    for k in pairs(d) do
        if k ~= "_" then return true end
    end
    return false
end

-- What a scope gets when it has no override of its own.
local function fallback(scope, def)
    if scope ~= "general" and def.scope == "inherit" then
        local g = profile.general[def.key]
        if g ~= nil then return g end
        -- The frame's own default, if it has one (preset), else the base.
        return Settings.Default(def, scope)
    end
    return Settings.Default(def, scope)
end

-- Derived scopes have no profile and no options page of their own: a
-- resolver fixes some settings, everything else is the base scope's
-- (party pets follow the party frame, Units/PartyPets.lua). Setting a
-- value on a derived scope is refused.
local derived = {}

function Config.Derive(scope, base, resolve)
    derived[scope] = { base = base, resolve = resolve }
end

function Config.Get(scope, key)
    local def = assert(Settings.Get(key), "unknown setting " .. tostring(key))
    local d = derived[scope]
    if d then
        local v = d.resolve(key)
        if v ~= nil then return v end
        return Config.Get(d.base, key)
    end
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
    -- A general value equal to the base default is still kept when some
    -- frame has a default of its own: it is what those frames follow.
    if sameValue(v, fallback(scope, def)) and not (scope == "general" and hasFrameDefaults(def)) then
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

-- Removes the given keys from every frame scope, so each frame falls back
-- to General again. General itself keeps its values. One CONFIG_CHANGED
-- for everything.
function Config.ClearFrameOverrides(keys)
    for _, scope in ipairs(Settings.SCOPES) do
        if scope ~= "general" then
            for _, key in ipairs(keys) do profile[scope][key] = nil end
        end
    end
    ns.Fire("CONFIG_CHANGED", nil, nil)
end

-- Copying reproduces the source frame's look as it is shown, including the
-- per-frame defaults it does not override. Position and whether the frame
-- is shown at all stay with the target: copying must not stack two frames
-- or switch one on or off. Each value is stored the way Set stores it, as
-- an override only where it differs from the target's own fallback.
local NOT_COPIED = { x = true, y = true, enabled = true }

local function copyValue(v)
    if type(v) == "table" then return { v[1], v[2], v[3], v[4] } end
    return v
end

function Config.CopyScope(from, to)
    if not profile[from] or not profile[to] or from == to then return end
    local target = profile[to]
    for _, def in ipairs(Settings.All()) do
        local key = def.key
        if not NOT_COPIED[key] and Settings.AppliesTo(def, to) and Settings.AppliesTo(def, from) then
            local v = Config.Get(from, key)
            if sameValue(v, fallback(to, def)) then
                target[key] = nil
            else
                target[key] = copyValue(v)
            end
        end
    end
    ns.Fire("CONFIG_CHANGED", to, nil)
end

-- Personal settings (the language) stay the reader's own: a shared
-- profile must not switch the UI to its author's language.
function Config.Import(p)
    local personal, kept = {}, {}
    for _, def in ipairs(Settings.All()) do
        if def.personal then
            personal[#personal + 1] = def.key
            kept[def.key] = profile.general[def.key]
        end
    end
    for _, scope in ipairs(Settings.SCOPES) do
        profile[scope] = type(p[scope]) == "table" and p[scope] or {}
    end
    for _, key in ipairs(personal) do profile.general[key] = kept[key] end
    ns.Fire("CONFIG_CHANGED", nil, nil)
end
