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
    local ok, name = pcall(C_Spell.GetSpellName, id)
    if not ok or ns.Secrets.IsSecret(name) or type(name) ~= "string" or name == "" then return nil end
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

-- Forever: today's defaults, read from the registry (per size where they
-- differ), so it stays the default when a default changes.
local function defaults()
    local RS, values = ns.RaidSettings, {}
    for _, key in ipairs(Templates.LOOK_KEYS) do
        local def = RS.Get(key)
        local v10, v20, v40 = RS.Default(def, "r10"), RS.Default(def, "r20"), RS.Default(def, "r40")
        if type(v10) ~= "table" and (v10 ~= v20 or v10 ~= v40) then
            values[key] = BySize(v10, v20, v40)
        else
            values[key] = v10
        end
    end
    return values
end

local WHITE, BLACK = { 1, 1, 1, 1 }, { 0, 0, 0, 1 }
Templates.LOOKS = {
    { id = "forever", kind = "look", values = defaults() },
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
