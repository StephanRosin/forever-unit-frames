local _, ns = ...

-- Raid templates: named sets of raid settings (key -> value) applied to
-- one raid size or to all three. A template sets only the keys it names,
-- everything else stays. A key that is not per size (the buff watch
-- window) goes to the character's own settings. Applying is one change:
-- every value is checked first, and when one is refused nothing is set.
-- The last change can be undone once in the session (the values from
-- before it, overrides and defaults alike). Nothing is applied or undone
-- in combat: the raid window is locked then anyway.
--
-- template = { id =, values = { key = value }, extra = function(class)
-- (optional): more key -> value for the player's class }. A value that
-- differs per size is Templates.BySize(v10, v20, v40).
local Templates = {}
ns.RaidTemplates = Templates

local Raid, RaidSettings, RaidConfig, Secrets = ns.Raid, ns.RaidSettings, ns.RaidConfig, ns.Secrets

local BY_SIZE = {}
function Templates.BySize(v10, v20, v40)
    return { [BY_SIZE] = true, [10] = v10, [20] = v20, [40] = v40 }
end

local function isBySize(v) return type(v) == "table" and v[BY_SIZE] == true end

-- The player's class token, or nil (secret or unknown).
function Templates.PlayerClass()
    local ok, _, token = pcall(UnitClass, "player")
    if ok and not Secrets.IsSecret(token) and type(token) == "string" then return token end
    return nil
end

local function sameValue(a, b)
    if type(a) == "table" and type(b) == "table" then
        for i = 1, 4 do if a[i] ~= b[i] then return false end end
        return true
    end
    return a == b
end

-- Whether a value is one the setting stores as it is (a value the
-- registry would clamp or change is a mistake in the template).
function Templates.Valid(key, value)
    local def = RaidSettings.Get(key)
    if not def then return false end
    local v = RaidSettings.Validate(def, value)
    return v ~= nil and sameValue(v, value)
end

-- Every key -> value of a template for the player's class (a BySize
-- value still whole).
function Templates.Values(template, class)
    local values = {}
    for key, v in pairs(template.values or {}) do values[key] = v end
    if template.extra then
        for key, v in pairs(template.extra(class or Templates.PlayerClass()) or {}) do values[key] = v end
    end
    return values
end

-- What applying a template to the sizes sets: { { scope =, values = {
-- { key, value }, ... } }, ... }, the character's scope first, then the
-- sizes in their order, keys sorted. nil and the key when a key is
-- unknown or a value refused.
function Templates.Changes(template, sizes, class)
    local values = Templates.Values(template, class)
    local keys = {}
    for key in pairs(values) do keys[#keys + 1] = key end
    table.sort(keys)
    local general = { scope = "general", values = {} }
    local perSize = {}
    for i, size in ipairs(sizes) do perSize[i] = { scope = Raid.Scope(size), size = size, values = {} } end
    for _, key in ipairs(keys) do
        local def, v = RaidSettings.Get(key), values[key]
        if not def then return nil, key end
        if def.scope == "general" then
            if isBySize(v) or not Templates.Valid(key, v) then return nil, key end
            general.values[#general.values + 1] = { key, v }
        else
            for _, entry in ipairs(perSize) do
                local sized = isBySize(v) and v[entry.size] or v
                if not Templates.Valid(key, sized) then return nil, key end
                entry.values[#entry.values + 1] = { key, sized }
            end
        end
    end
    local changes = {}
    if #general.values > 0 then changes[1] = general end
    for _, entry in ipairs(perSize) do
        if #entry.values > 0 then changes[#changes + 1] = { scope = entry.scope, values = entry.values } end
    end
    return changes
end

local undo   -- the overrides before the last change: { { scope, saved }, ... }

-- Several templates' changes as one (later ones win on the same key).
function Templates.Merge(list)
    local byScope, order = {}, {}
    for _, changes in ipairs(list) do
        for _, c in ipairs(changes) do
            local entry = byScope[c.scope]
            if not entry then
                entry = { scope = c.scope, values = {}, at = {} }
                byScope[c.scope] = entry
                order[#order + 1] = entry
            end
            for _, pair in ipairs(c.values) do
                local i = entry.at[pair[1]]
                if i then entry.values[i] = pair else
                    entry.values[#entry.values + 1] = pair
                    entry.at[pair[1]] = #entry.values
                end
            end
        end
    end
    local merged = {}
    for i, entry in ipairs(order) do merged[i] = { scope = entry.scope, values = entry.values } end
    return merged
end

-- Sets changes (Templates.Changes) as one change that can be undone.
-- False in combat, or when a scope refuses its values (none is set).
function Templates.ApplyChanges(changes)
    if InCombatLockdown() then return false end
    local before = {}
    for i, c in ipairs(changes) do
        local keys = {}
        for j, pair in ipairs(c.values) do keys[j] = pair[1] end
        before[i] = { c.scope, RaidConfig.Snapshot(c.scope, keys) }
    end
    for i, c in ipairs(changes) do
        if not RaidConfig.SetKeys(c.scope, c.values) then
            for j = i - 1, 1, -1 do RaidConfig.Restore(before[j][1], before[j][2]) end
            return false
        end
    end
    undo = before
    ns.Fire("RAID_TEMPLATE_UNDO")
    return true
end

-- Applies a template to the sizes (a list of 10, 20, 40). False when it
-- holds an unknown key or a refused value (nothing is set), or in combat.
function Templates.Apply(template, sizes)
    local changes = Templates.Changes(template, sizes)
    if not changes then return false end
    return Templates.ApplyChanges(changes)
end

function Templates.CanUndo()
    return undo ~= nil
end

-- Puts back what the last change replaced; once.
function Templates.Undo()
    if not undo or InCombatLockdown() then return false end
    local saved = undo
    undo = nil
    for _, entry in ipairs(saved) do RaidConfig.Restore(entry[1], entry[2]) end
    ns.Fire("RAID_TEMPLATE_UNDO")
    return true
end

-- Own templates ------------------------------------------------------------------
-- Per account: ForeverUnitFramesDB.raidTemplates = { { name =, values = {
-- key = value } }, ... }, in the order saved. A template holds every
-- per-size setting of the size it was saved from, as shown then (its own
-- values and the defaults it kept), so applying it makes a size look the
-- same. Cleaned at login like an import: names trimmed and once (case
-- ignored), only known per-size settings, values as the registry takes
-- them.
Templates.OWN_NAME_LETTERS = 32
Templates.OWN_MAX = 20
local OWN_PREFIX = "own:"

local own = {}   -- the saved list itself

local function trimmed(name)
    if type(name) ~= "string" then return nil end
    return name:match("^%s*(.-)%s*$")
end

local function nameKey(name) return name:lower() end

local function withId(t)
    t.id = OWN_PREFIX .. t.name
    return t
end

local function cleanValues(values)
    local clean = {}
    if type(values) ~= "table" then return clean end
    for key, v in pairs(values) do
        local def = type(key) == "string" and RaidSettings.Get(key)
        if def and def.scope ~= "general" then clean[key] = RaidSettings.Validate(def, v) end
    end
    return clean
end

-- At PLAYER_LOGIN.
function Templates.AttachOwn(db)
    local list, seen = {}, {}
    for _, t in ipairs(type(db.raidTemplates) == "table" and db.raidTemplates or {}) do
        local name = type(t) == "table" and trimmed(t.name)
        if name and name ~= "" and #name <= Templates.OWN_NAME_LETTERS and not seen[nameKey(name)]
            and #list < Templates.OWN_MAX then
            seen[nameKey(name)] = true
            list[#list + 1] = withId({ name = name, values = cleanValues(t.values) })
        end
    end
    db.raidTemplates = list
    own = list
end

function Templates.Own()
    return own
end

local function ownIndex(name)
    local key = nameKey(name)
    for i, t in ipairs(own) do
        if nameKey(t.name) == key then return i end
    end
    return nil
end

-- A template by id: a shipped one's, or "own:" and an own one's name.
function Templates.Find(id)
    if type(id) ~= "string" then return nil end
    local name = id:sub(1, #OWN_PREFIX) == OWN_PREFIX and id:sub(#OWN_PREFIX + 1)
    if name then
        local i = ownIndex(name)
        return i and own[i] or nil
    end
    return Templates.Get(id)
end

-- Saves the size's settings under a name (the same name, any case,
-- replaces that template). nil and why: EMPTY, TOO_LONG, FULL.
function Templates.SaveOwn(name, size)
    name = trimmed(name) or ""
    if name == "" then return nil, "EMPTY" end
    if #name > Templates.OWN_NAME_LETTERS then return nil, "TOO_LONG" end
    local scope, values = Raid.Scope(size), {}
    for _, def in ipairs(RaidSettings.All()) do
        if def.scope ~= "general" then
            local v = RaidConfig.Get(scope, def.key)
            if type(v) == "table" then v = { v[1], v[2], v[3], v[4] } end
            values[def.key] = v
        end
    end
    local t = withId({ name = name, values = values })
    local i = ownIndex(name)
    if i then
        own[i] = t
    else
        if #own >= Templates.OWN_MAX then return nil, "FULL" end
        own[#own + 1] = t
    end
    ns.Fire("RAID_TEMPLATES_CHANGED")
    return true
end

-- Deletes an own template by id; false for a shipped or unknown one.
function Templates.DeleteOwn(id)
    local t = Templates.Find(id)
    if not t or t.id ~= id or id:sub(1, #OWN_PREFIX) ~= OWN_PREFIX then return false end
    table.remove(own, ownIndex(t.name))
    ns.Fire("RAID_TEMPLATES_CHANGED")
    return true
end
