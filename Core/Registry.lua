local _, ns = ...

-- A settings registry: one list of setting definitions, the scopes they
-- live in and the letter each scope is written with. The unit frames have
-- one (Core/Settings.lua), the raid frames another (Raid/Settings.lua).
-- Codes only have to be unique within a registry: every saved or exported
-- string belongs to exactly one.

local function inList(values, v)
    for i = 1, #values do if values[i] == v then return true end end
    return false
end

-- The longest free text a setting takes (a spell name, or its ID).
local TEXT_MAX = 64

local function validate(def, v)
    local t = def.type
    if t == "int" then
        if type(v) ~= "number" then return nil end
        if v ~= v or v == math.huge or v == -math.huge then return nil end
        v = math.floor(v + 0.5)
        if def.min and v < def.min then v = def.min end
        if def.max and v > def.max then v = def.max end
        -- def.lowest (optional): with 0 standing for "Automatic", the
        -- smallest number of its own; anything between goes up to it.
        if def.lowest and v ~= 0 and v < def.lowest then v = def.lowest end
        return v
    elseif t == "bool" then
        if type(v) ~= "boolean" then return nil end
        return v
    elseif t == "enum" then
        if not inList(def.values, v) then return nil end
        return v
    elseif t == "color" then
        if type(v) ~= "table" then return nil end
        for i = 1, 4 do
            local c = v[i]
            if type(c) ~= "number" or c < 0 or c > 1 then return nil end
        end
        return { v[1], v[2], v[3], v[4] }
    elseif t == "media" then
        if type(v) ~= "string" or v == "" then return nil end
        return v
    elseif t == "text" then
        -- Free text, trimmed; empty is allowed. def.maxLetters caps it;
        -- def.check (optional) refuses what does not parse.
        if type(v) ~= "string" then return nil end
        v = v:match("^%s*(.-)%s*$")
        if #v > (def.maxLetters or TEXT_MAX) then return nil end
        if def.check and not def.check(v) then return nil end
        return v
    end
    return nil
end

-- scopes: ordered list, "general" first; prefix: scope -> one lower-case
-- letter, unique within the registry.
function ns.NewRegistry(scopes, prefix)
    local R = { SCOPES = scopes, PREFIX = prefix, TEXT_MAX = TEXT_MAX, Validate = validate }
    local list, byKey, byCode = {}, {}, {}

    function R.Define(def)
        assert(not byKey[def.key], "duplicate key " .. def.key)
        assert(not byCode[def.code], "duplicate code " .. def.code)
        list[#list + 1] = def
        byKey[def.key] = def
        byCode[def.code] = def
    end

    function R.Get(key) return byKey[key] end
    function R.ByCode(code) return byCode[code] end
    function R.All() return list end

    function R.Default(def, scope)
        local d = def.default
        if type(d) == "table" and d._ ~= nil then
            local v = d[scope]
            if v == nil then v = d._ end
            return v
        end
        return d
    end

    -- def.only (optional) limits a frame setting to some frames, e.g.
    -- { party = true } for the party layout.
    function R.AppliesTo(def, scope)
        if scope == "general" then return def.scope ~= "frame" end
        if def.scope == "general" then return false end
        if def.only then return def.only[scope] == true end
        return true
    end

    -- A shipped look on top of the plain defaults: preset[scope][key] =
    -- value. A general value becomes the setting's base default, a frame
    -- value that frame's own default.
    local plainOf = {}   -- def -> { its plain default }, before any preset
    -- d with the preset's values of key (d itself when it has none).
    local function withPreset(d, preset, key)
        for scope, values in pairs(preset) do
            local value = values[key]
            if value ~= nil then
                if type(d) ~= "table" or d._ == nil then d = { _ = d } end
                if scope == "general" then d._ = value else d[scope] = value end
            end
        end
        return d
    end

    function R.ApplyPreset(preset)
        for scope, values in pairs(preset) do
            for key, value in pairs(values) do
                local def = assert(byKey[key], "preset: unknown setting " .. key)
                assert(R.AppliesTo(def, scope), "preset: " .. key .. " does not apply to " .. scope)
                assert(validate(def, value) == value or def.type == "color", "preset: invalid " .. key)
            end
        end
        for _, def in ipairs(list) do
            local d = def.default
            if not plainOf[def] then
                local plain = d
                if type(d) == "table" and d._ ~= nil then
                    plain = {}
                    for k, v in pairs(d) do plain[k] = v end
                end
                plainOf[def] = { plain }
            end
            def.default = withPreset(d, preset, def.key)
        end
        R.presetApplied = true
    end

    -- The defaults as another preset would make them (an earlier version's
    -- shipped look, Core/PresetUpgrade.lua): a function (def, scope) like
    -- R.Default.
    function R.DefaultsUnder(preset)
        return function(def, scope)
            local d = def.default
            if plainOf[def] then d = plainOf[def][1] end
            if type(d) == "table" and d._ ~= nil then
                local c = {}
                for k, v in pairs(d) do c[k] = v end
                d = c
            end
            return R.Default({ default = withPreset(d, preset, def.key) }, scope)
        end
    end

    -- def.offBelowMin (optional): the switch that a stored number under
    -- def.min stood for (an earlier version's "0 = none"). Such a value
    -- (raw[scope]: as stored, before validation) becomes that switch off
    -- in every scope that stored it; General gets the setting's default, a
    -- frame none of its own (it follows General). A scope with a size of
    -- its own over a general "none" had its border: it keeps it (its
    -- switch on, unless it stores one). One that stored its switch on
    -- without a size of its own had none: it stays without (switch off).
    local function below(def, v) return type(v) == "number" and v < def.min end
    local function rawValue(raw, scope, key)
        return type(raw[scope]) == "table" and raw[scope][key] or nil
    end
    function R.Upgrade(profile, raw)
        for _, def in ipairs(list) do
            if def.offBelowMin then
                local generalNone = below(def, rawValue(raw, "general", def.key))
                for _, scope in ipairs(scopes) do
                    local v = rawValue(raw, scope, def.key)
                    local values = profile[scope]
                    if values and R.AppliesTo(def, scope) then
                        if below(def, v) then
                            values[def.key] = scope == "general" and R.Default(def, scope) or nil
                            values[def.offBelowMin] = false
                        elseif generalNone and scope ~= "general" and type(v) == "number"
                            and values[def.offBelowMin] == nil then
                            values[def.offBelowMin] = true
                        elseif generalNone and scope ~= "general" and v == nil
                            and values[def.offBelowMin] == true then
                            values[def.offBelowMin] = false
                        end
                    end
                end
            end
        end
    end

    -- Only known scopes and settings that apply to them survive, each with
    -- a value that passes validation: a hand-edited or outdated
    -- SavedVariables file must never reach Config or the codec. A retired
    -- setting (def.retired: its code is kept so old strings still read,
    -- the value means nothing any more) never survives.
    function R.Sanitise(profile)
        local clean = {}
        for _, scope in ipairs(scopes) do
            clean[scope] = {}
            local values = profile[scope]
            if type(values) == "table" then
                for key, v in pairs(values) do
                    local def = byKey[key]
                    if def and not def.retired and R.AppliesTo(def, scope) then
                        clean[scope][key] = validate(def, v)
                    end
                end
            end
        end
        R.Upgrade(clean, profile)
        return clean
    end

    return R
end
