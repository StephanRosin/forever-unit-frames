local _, ns = ...

-- Profile access. A profile holds overrides only; everything else comes
-- from inheritance (frame -> general) and the defaults of its registry.
-- ns.NewConfig makes one per settings registry: ns.Config for the unit
-- frames (below), ns.RaidConfig for the raid frames (Raid/Profiles.lua).
-- `event` is the internal event fired on every change; `notCopied` lists
-- the keys CopyScope leaves with the target.

local function sameValue(a, b)
    if type(a) == "table" and type(b) == "table" then
        for i = 1, 4 do if a[i] ~= b[i] then return false end end
        return true
    end
    return a == b
end

local function copyValue(v)
    if type(v) == "table" then return { v[1], v[2], v[3], v[4] } end
    return v
end

function ns.NewConfig(Settings, event, notCopied)
    local Config = {}
    local profile

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

    -- What a scope of profile p gets when it has no override of its own.
    local function fallbackIn(p, scope, def)
        if scope ~= "general" and def.scope == "inherit" then
            local g = p.general and p.general[def.key]
            if g ~= nil then return g end
            -- The frame's own default, if it has one (preset), else the base.
            return Settings.Default(def, scope)
        end
        return Settings.Default(def, scope)
    end

    local function valueIn(p, scope, def)
        local own = p[scope] and p[scope][def.key]
        if own ~= nil then return own end
        return fallbackIn(p, scope, def)
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
        return valueIn(profile, scope, def)
    end

    function Config.IsOverridden(scope, key)
        return profile[scope] ~= nil and profile[scope][key] ~= nil
    end

    -- A value as Set would store it: the setting and the validated value,
    -- or nil when it is refused.
    local function checked(scope, key, value)
        local def = Settings.Get(key)
        if not def or not profile[scope] or not Settings.AppliesTo(def, scope) then return nil end
        local v = Settings.Validate(def, value)
        if v == nil then return nil end
        return def, v
    end

    local function store(scope, def, v)
        -- A general value equal to the base default is still kept when some
        -- frame has a default of its own: it is what those frames follow.
        if sameValue(v, fallbackIn(profile, scope, def)) and not (scope == "general" and hasFrameDefaults(def)) then
            profile[scope][def.key] = nil
        else
            profile[scope][def.key] = v
        end
    end

    function Config.Set(scope, key, value)
        local def, v = checked(scope, key, value)
        if not def then return false end
        store(scope, def, v)
        ns.Fire(event, scope, key)
        return true
    end

    -- Several settings of one scope at once (values: { key, value } pairs),
    -- each stored as Set stores it; one event for everything (scope, nil).
    -- When one is refused, none is set.
    function Config.SetKeys(scope, values)
        local list = {}
        for i, pair in ipairs(values) do
            local def, v = checked(scope, pair[1], pair[2])
            if not def then return false end
            list[i] = { def, v }
        end
        for _, entry in ipairs(list) do store(scope, entry[1], entry[2]) end
        ns.Fire(event, scope, nil)
        return true
    end

    -- One scope's overrides as they are stored (pairs { key, value }, the
    -- value nil where there is none), and back: what Restore puts back
    -- was read by Snapshot, so it is stored as it was. One event (scope,
    -- nil).
    function Config.Snapshot(scope, keys)
        local saved = {}
        if not profile[scope] then return saved end
        for i, key in ipairs(keys) do saved[i] = { key, copyValue(profile[scope][key]) } end
        return saved
    end

    function Config.Restore(scope, saved)
        if not profile[scope] then return end
        for _, pair in ipairs(saved) do profile[scope][pair[1]] = copyValue(pair[2]) end
        ns.Fire(event, scope, nil)
    end

    function Config.ResetScope(scope)
        profile[scope] = {}
        ns.Fire(event, scope, nil)
    end

    function Config.ResetAll()
        for _, scope in ipairs(Settings.SCOPES) do profile[scope] = {} end
        ns.Fire(event, nil, nil)
    end

    function Config.ClearOverride(scope, key)
        if not profile[scope] then return end
        profile[scope][key] = nil
        ns.Fire(event, scope, key)
    end

    -- Removes the given keys' overrides from one scope: they fall back to
    -- their defaults. One event for everything (scope, nil).
    function Config.ResetKeys(scope, keys)
        if not profile[scope] then return end
        for _, key in ipairs(keys) do profile[scope][key] = nil end
        ns.Fire(event, scope, nil)
    end

    -- Removes the given keys from every frame scope, so each frame falls
    -- back to General again. General itself keeps its values. One event
    -- for everything.
    function Config.ClearFrameOverrides(keys)
        for _, scope in ipairs(Settings.SCOPES) do
            if scope ~= "general" then
                for _, key in ipairs(keys) do profile[scope][key] = nil end
            end
        end
        ns.Fire(event, nil, nil)
    end

    -- Copying reproduces the source scope's look as it is shown, including
    -- the per-frame defaults it does not override; `source` is a profile,
    -- this one or another (another character's raid profile, a decoded
    -- import). Keys in notCopied stay with the target. Each value is stored
    -- the way Set stores it, as an override only where it differs from the
    -- target's own fallback, so the target ends up a full copy.
    function Config.CopyScopeFrom(source, from, to)
        if type(source) ~= "table" or type(source[from]) ~= "table" or not profile[to] then return end
        if source == profile and from == to then return end
        local target = profile[to]
        for _, def in ipairs(Settings.All()) do
            local key = def.key
            if not notCopied[key] and Settings.AppliesTo(def, to) and Settings.AppliesTo(def, from) then
                local v = valueIn(source, from, def)
                if sameValue(v, fallbackIn(profile, to, def)) then
                    target[key] = nil
                else
                    target[key] = copyValue(v)
                end
            end
        end
        ns.Fire(event, to, nil)
    end

    function Config.CopyScope(from, to)
        Config.CopyScopeFrom(profile, from, to)
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
        ns.Fire(event, nil, nil)
    end

    return Config
end

-- The unit frames. Position and whether a frame is shown at all stay with
-- the target of a copy: copying must not stack two frames or switch one
-- on or off.
ns.Config = ns.NewConfig(ns.Settings, "CONFIG_CHANGED", { x = true, y = true, enabled = true })

-- Whether a unit frame is on: the master switch "Use unit frames" and
-- the frame's own "enabled" (scope: a frame, or a scope derived from one).
function ns.FrameEnabled(scope)
    return ns.Config.Get("general", "unitFrames") and ns.Config.Get(scope, "enabled")
end
