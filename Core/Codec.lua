local _, ns = ...

-- Compact text form of a profile: only overrides, each as
-- <scope letter><CODE><value>, joined by ";" behind a format version.
-- Used for export/import, the macro backup and storage providers.
local Codec = {}
ns.Codec = Codec
Codec.VERSION = 1

local Settings = ns.Settings

local scopeByPrefix = {}
for scope, prefix in pairs(Settings.PREFIX) do scopeByPrefix[prefix] = scope end

local function escape(s)
    return (s:gsub("%%", "%%25"):gsub(";", "%%3B"))
end
local function unescape(s)
    return (s:gsub("%%3B", ";"):gsub("%%25", "%%"))
end

local function hexByte(c) return ("%02x"):format(math.floor(c * 255 + 0.5)) end

local function encodeValue(def, v)
    local t = def.type
    if t == "int" then return ("%d"):format(v) end
    if t == "bool" then return v and "1" or "0" end
    if t == "enum" then
        for i, name in ipairs(def.values) do if name == v then return tostring(i) end end
    end
    if t == "color" then return "#" .. hexByte(v[1]) .. hexByte(v[2]) .. hexByte(v[3]) .. hexByte(v[4]) end
    if t == "media" then return "'" .. escape(v) end
    return nil
end

local function decodeValue(def, raw)
    local t = def.type
    if t == "int" then
        local n = raw:match("^%-?%d+$") and tonumber(raw)
        return n and Settings.Validate(def, n)
    end
    if t == "bool" then
        if raw == "1" then return true elseif raw == "0" then return false end
        return nil
    end
    if t == "enum" then
        local i = raw:match("^%d+$") and tonumber(raw)
        return i and def.values[i]
    end
    if t == "color" then
        local r, g, b, a = raw:match("^#(%x%x)(%x%x)(%x%x)(%x%x)$")
        if not r then return nil end
        return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, tonumber(a, 16) / 255 }
    end
    if t == "media" then
        local name = raw:match("^'(.+)$")
        return name and unescape(name)
    end
    return nil
end

function Codec.Encode(profile)
    local parts = { tostring(Codec.VERSION) }
    for _, scope in ipairs(Settings.SCOPES) do
        local entries = {}
        for key, v in pairs(profile[scope] or {}) do
            local def = Settings.Get(key)
            local text = def and encodeValue(def, v)
            if text then entries[#entries + 1] = { def.code, text } end
        end
        table.sort(entries, function(a, b) return a[1] < b[1] end)
        for _, e in ipairs(entries) do
            parts[#parts + 1] = Settings.PREFIX[scope] .. e[1] .. e[2]
        end
    end
    return table.concat(parts, ";")
end

-- Returns profile, nil, rejected; or nil, errorKey. `rejected` counts the
-- entries that could not be read and were dropped. Forward compatibility
-- decides what counts:
-- * An unknown scope or code, a setting on a scope it does not apply to,
--   or an enum index past the known values is what a newer version may
--   write. It is skipped and NOT counted: this version cannot use it.
-- * A known code whose value does not parse for its type, or an entry that
--   is not <scope><CODE><value> at all (empty ones aside), is data this
--   version should have understood. It IS counted, so callers can refuse
--   to write the loss back.
-- No value format starts with an upper-case letter, so a two-letter code
-- that only resolves to its first letter is an unknown code, not a bad value.
function Codec.Decode(str)
    if type(str) ~= "string" or str == "" then return nil, "CODEC_EMPTY" end
    local version = str:match("^(%d+)")
    if not version then return nil, "CODEC_FORMAT" end
    if tonumber(version) ~= Codec.VERSION then return nil, "CODEC_VERSION" end
    local profile = {}
    for _, scope in ipairs(Settings.SCOPES) do profile[scope] = {} end
    local rejected = 0
    local first = true
    for entry in (str .. ";"):gmatch("([^;]*);") do
        local prefix, code, raw = entry:match("^(%l)(%u%u?)(.*)$")
        if first then
            -- The version number; anything glued to it is not an entry.
            first = false
            if entry ~= version then rejected = rejected + 1 end
        elseif not prefix then
            -- An empty entry (";;", a trailing ";") carries nothing to lose.
            if entry ~= "" then rejected = rejected + 1 end
        else
            -- Two-letter codes: prefer the longest code that exists.
            local def = Settings.ByCode(code)
            local shortened = false
            if not def and #code == 2 then
                def = Settings.ByCode(code:sub(1, 1))
                raw = code:sub(2) .. raw
                shortened = true
            end
            local scope = scopeByPrefix[prefix]
            if def and scope and profile[scope] and Settings.AppliesTo(def, scope) then
                local v = decodeValue(def, raw)
                if v ~= nil then
                    profile[scope][def.key] = v
                elseif not shortened and not (def.type == "enum" and raw:match("^%d+$")) then
                    rejected = rejected + 1
                end
            end
        end
    end
    return profile, nil, rejected
end
