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
