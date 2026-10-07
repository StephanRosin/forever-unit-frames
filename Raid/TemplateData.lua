local _, ns = ...

-- The shipped raid templates (Raid/Templates.lua): four role templates
-- and three looks. A role template sets what the cells show and how they
-- are laid out; a look only how they look (LOOK_KEYS), so a role and a
-- look add up. Values per class (heals over time, the buff watch) come
-- from the spell book: a spell it does not know is left out. Spells are
-- shipped as IDs (the Classic ones, as Raid/BuffData.lua) and stored as
-- every rank the spell book knows of the spell's name.
local Templates = ns.RaidTemplates
local BySize, Data = Templates.BySize, ns.RaidBuffData

-- Heals over time per class, each on a corner indicator.
Templates.HOTS = {
    PRIEST = { { indicator = "TopLeft", spell = 139 }, { indicator = "TopRight", spell = 17 } },
    DRUID = { { indicator = "TopLeft", spell = 774 }, { indicator = "TopRight", spell = 8936 },
        { indicator = "BottomLeft", spell = 33763 } },
    SHAMAN = { { indicator = "TopLeft", spell = 974 } },
}

-- Every learned rank of a shipped spell (by its name), as a spell list
-- stores them; nil when the book knows none or the client no name.
function Templates.SpellIDs(id)
    local name = ns.Secrets.Plain(ns.Secrets.Call(C_Spell.GetSpellName, id), "string")
    if not name or name == "" then return nil end
    local ids = ns.RaidSpellbook.IDs(name)
    if #ids == 0 then return nil end
    local text = table.concat(ids, ",")
    if #text > ns.Raid.SPELL_LIST_LETTERS then return nil end
    return text
end

-- Whether the class has a group buff the buff watch knows.
local function hasBuffs(class)
    if class == "PALADIN" then return true end
    for _, buff in ipairs(Data.BUFFS) do
        if buff.class == class then return true end
    end
    return false
end

local function healerExtra(class)
    local values = {}
    if hasBuffs(class) then values.buffWatchShow = true end
    for _, hot in ipairs(Templates.HOTS[class] or {}) do
        local ids = Templates.SpellIDs(hot.spell)
        if ids then
            local key = "indicator" .. hot.indicator
            values[key .. "Spells"], values[key .. "Own"] = ids, true
        end
    end
    return values
end

local DPS = {
    cellWidth = BySize(72, 64, 56), cellHeight = BySize(32, 30, 26),
    groupBy = "GROUP", blockDirection = "HORIZONTAL", blocksPerLine = 8,
    secondLine = "NONE", healPrediction = false, overheal = false,
    dispelIcon = true, dispelFilter = "MINE", dispelStyle = "ICON", debuffRow = false,
}
local DISPEL = {}
for key, v in pairs(DPS) do DISPEL[key] = v end
DISPEL.dispelIconSize, DISPEL.dispelTint = BySize(28, 24, 22), true

Templates.ROLES = {
    { id = "healer", kind = "role", values = {
        cellWidth = BySize(120, 104, 92), cellHeight = BySize(48, 44, 40),
        secondLine = "DEFICIT", healPrediction = true, overheal = true, absorbs = true,
        debuffRow = true, dispelIcon = true, dispelFilter = "MINE", dispelStyle = "ICON",
        rangeFade = true,
    }, extra = healerExtra },
    -- No filter for boss debuffs exists: the row stays off, the centre
    -- icon shows any dispellable debuff.
    { id = "tank", kind = "role", values = {
        cellWidth = BySize(80, 72, 64), cellHeight = BySize(36, 32, 30),
        aggroBorder = true, mainTanksShow = true, mainTanksTitle = true,
        debuffRow = false, dispelIcon = true, dispelFilter = "ALL",
        healPrediction = false,
    } },
    { id = "dps", kind = "role", values = DPS },
    { id = "dispel", kind = "role", values = DISPEL },
}

-- What a look sets: the cell's shape, borders, bars, colours and fonts.
Templates.LOOK_KEYS = { "cellBorder", "cellBorderStyle", "cellBorderSize", "cellBorderColor", "cellCornerRadius",
    "panelBorder", "blockBorder", "barTexture", "backgroundColor", "healthColorMode", "healthColor",
    "nameClassColor", "nameColor", "secondLineColor", "fontFace", "nameFontSize", "secondFontSize", "fontOutline",
    "fontShadow" }
Templates.LOOK_KEYS_SORTED = {}
for i, key in ipairs(Templates.LOOK_KEYS) do Templates.LOOK_KEYS_SORTED[i] = key end
table.sort(Templates.LOOK_KEYS_SORTED)

-- The defaults of the keys, each size's own (a BySize value; one value
-- where every size has the same). Forever is the look keys' defaults,
-- read from the registry, so it stays the default when a default changes.
local function sameValue(a, b)
    if type(a) == "table" and type(b) == "table" then
        for i = 1, 4 do if a[i] ~= b[i] then return false end end
        return true
    end
    return a == b
end

function Templates.SizeDefaults(keys)
    local RS, values = ns.RaidSettings, {}
    for _, key in ipairs(keys) do
        local def = RS.Get(key)
        local v10, v20, v40 = RS.Default(def, "r10"), RS.Default(def, "r20"), RS.Default(def, "r40")
        if sameValue(v10, v20) and sameValue(v10, v40) then
            values[key] = v10
        else
            values[key] = BySize(v10, v20, v40)
        end
    end
    return values
end

local WHITE, BLACK = { 1, 1, 1, 1 }, { 0, 0, 0, 1 }
Templates.LOOKS = {
    { id = "forever", kind = "look", values = Templates.SizeDefaults(Templates.LOOK_KEYS) },
    -- No ring: a thin flat border, square corners, flat bars.
    { id = "flat", kind = "look", values = {
        cellBorder = true, cellBorderStyle = "FLAT", cellBorderSize = 1, cellBorderColor = BLACK,
        cellCornerRadius = 0, panelBorder = false, blockBorder = false,
        barTexture = "Flat", backgroundColor = { 0.1, 0.1, 0.1, 0.8 },
        healthColorMode = "CLASS", healthColor = { 0.2, 0.75, 0.3, 1 },
        nameClassColor = false, nameColor = WHITE, secondLineColor = WHITE,
        fontFace = "Arial Narrow", nameFontSize = 11, secondFontSize = 10, fontOutline = "OUTLINE",
        fontShadow = false,
    } },
    -- Blizzard-like: the raid bar texture, square cells, a border around
    -- each group, plain text with a shadow, the second line grey.
    { id = "classic", kind = "look", values = {
        cellBorder = false, cellBorderStyle = "FLAT", cellBorderSize = 1, cellBorderColor = BLACK,
        cellCornerRadius = 0, panelBorder = false, blockBorder = true,
        barTexture = "Raid", backgroundColor = { 0, 0, 0, 0.8 },
        healthColorMode = "CLASS", healthColor = { 0.2, 0.75, 0.3, 1 },
        nameClassColor = false, nameColor = WHITE, secondLineColor = { 0.7, 0.7, 0.7, 1 },
        fontFace = "Friz Quadrata", nameFontSize = 10, secondFontSize = 9, fontOutline = "NONE",
        fontShadow = true,
    } },
}

-- A shipped template by id, or nil.
function Templates.Get(id)
    for _, list in ipairs({ Templates.ROLES, Templates.LOOKS }) do
        for _, t in ipairs(list) do
            if t.id == id then return t end
        end
    end
    return nil
end

-- Suggestions --------------------------------------------------------------------

-- The role template a class plays when nothing else says.
Templates.CLASS_ROLE = { PRIEST = "healer", DRUID = "healer", PALADIN = "healer", SHAMAN = "healer",
    WARRIOR = "tank" }
local ROLE_TEMPLATE = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }

-- A role token as the client gives it, when it is plain and one of the
-- three.
local function roleOf(v)
    v = ns.Secrets.Plain(v, "string")
    return v and ROLE_TEMPLATE[v]
end

local function specRole()
    local spec = C_SpecializationInfo
    if type(spec) ~= "table" or type(spec.GetSpecialization) ~= "function"
        or type(spec.GetSpecializationInfo) ~= "function" then
        return nil
    end
    local index = ns.Secrets.Plain(ns.Secrets.Call(spec.GetSpecialization), "number")
    if not index or index < 1 then return nil end
    local okInfo, _, _, _, _, role, _, points = pcall(spec.GetSpecializationInfo, index)
    if not okInfo then return nil end
    -- No point spent in it (a plain 0): the specialization says nothing.
    if not ns.Secrets.IsSecret(points) and points == 0 then return nil end
    return roleOf(role)
end

local function assignedRole()
    if type(UnitGroupRolesAssigned) ~= "function" then return nil end
    return roleOf(ns.Secrets.Call(UnitGroupRolesAssigned, "player"))
end

-- The role template to suggest: the specialization's role, else the
-- role assigned in the group, else the class's; DPS for an unknown class.
function Templates.SuggestRole()
    local role = specRole() or assignedRole()
    if role then return role end
    local class = Templates.PlayerClass()
    return class and Templates.CLASS_ROLE[class] or "dps"
end

-- Click-casting suggestions per class: a mouse slot and the spells for it
-- (the first one the spell book knows). heals: for the healer template;
-- dispels: for the healer and the dispel template, whose plain left click
-- casts the first dispel the book knows.
Templates.CLICKS = {
    PRIEST = {
        heals = { { "click1Shift", { 2061 } }, { "click1Ctrl", { 139 } }, { "click1Alt", { 17 } },
            { "click2Shift", { 2060, 2054 } } },
        dispels = { { "click2Ctrl", { 527 } }, { "click2Alt", { 552, 528 } } },
    },
    DRUID = {
        heals = { { "click1Shift", { 5185 } }, { "click1Ctrl", { 774 } }, { "click1Alt", { 8936 } },
            { "click2Shift", { 33763 } } },
        dispels = { { "click2Ctrl", { 2782 } }, { "click2Alt", { 2893, 8946 } } },
    },
    PALADIN = {
        heals = { { "click1Shift", { 19750 } }, { "click1Ctrl", { 635 } } },
        dispels = { { "click2Ctrl", { 4987, 1152 } } },
    },
    SHAMAN = {
        heals = { { "click1Shift", { 8004 } }, { "click1Ctrl", { 331 } }, { "click1Alt", { 1064 } },
            { "click2Shift", { 974 } } },
        dispels = { { "click2Ctrl", { 526 } }, { "click2Alt", { 2870 } } },
    },
    MAGE = { heals = {}, dispels = { { "click2Ctrl", { 475 } } } },
}

-- The binding of the first spell of the list the spell book knows, or nil.
local function knownBinding(spells)
    for _, id in ipairs(spells) do
        local name = ns.ClickCast.TypedValue("spell", tostring(id))
        if name and name ~= "" then return "spell:" .. name end
    end
    return nil
end

local function add(list, key, binding)
    if binding then list[#list + 1] = { key = key, binding = binding } end
end

-- The suggestions for a role template and a class: { key =, binding = }
-- in the order offered; spells the book does not know are left out.
function Templates.ClickSuggestions(roleId, class)
    local data = class and Templates.CLICKS[class]
    local list = {}
    if not data or (roleId ~= "healer" and roleId ~= "dispel") then return list end
    if roleId == "dispel" then
        local first
        for _, entry in ipairs(data.dispels) do first = first or knownBinding(entry[2]) end
        add(list, "click1", first)
    else
        for _, entry in ipairs(data.heals) do add(list, entry[1], knownBinding(entry[2])) end
    end
    for _, entry in ipairs(data.dispels) do add(list, entry[1], knownBinding(entry[2])) end
    return list
end

-- Suggestions (all or those picked) as changes for ApplyChanges.
function Templates.ClickChanges(list)
    local values = {}
    for i, s in ipairs(list) do values[i] = { s.key, s.binding } end
    if #values == 0 then return {} end
    return { { scope = "general", values = values } }
end
