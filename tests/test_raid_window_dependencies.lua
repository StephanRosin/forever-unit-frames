-- The raid window greys a row while its switch is off or its mode leaves
-- it without effect for the edited size (Raid/Options/Dependencies.lua);
-- it never hides one. Table-driven: the parent with a value that greys
-- the rows and one that wakes them, the rows, and what else must be set.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "Priest", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC = ns.RaidOptions, ns.RaidConfig

local function tabOf(key)
    for _, tab in ipairs(ns.RaidSchema.TABS) do
        for _, section in ipairs(tab.sections) do
            for _, k in ipairs(section.keys) do
                if k == key then return tab.id end
            end
        end
    end
end

local function rowFor(key)
    for _, row in ipairs(RO.rows) do
        if row.key == key then return row end
    end
end

local function scopeOf(key)
    return ns.RaidSettings.Get(key).scope == "general" and "general" or ns.Raid.Scope(RO.Size())
end
local function set(key, value) RC.Set(scopeOf(key), key, value) end
local function default(key) return ns.RaidSettings.Default(ns.RaidSettings.Get(key), scopeOf(key)) end

local CASES = {
    { "groupBy", "NONE", "GROUP", { "blockDirection", "blocksPerLine", "hideEmpty" } },
    { "cellBorder", false, true, { "cellBorderStyle", "cellBorderSize", "cellBorderColor" },
        { cellBorderStyle = "FLAT" } },
    { "cellBorderStyle", "GOLD", "FLAT", { "cellBorderColor" }, { cellBorder = true } },
    { "healthColorMode", "CLASS", "STATIC", { "healthColor" } },
    { "healthColorMode", "GRADIENT", "STATIC", { "healthColor" } },
    { "nameClassColor", true, false, { "nameColor" } },
    { "secondLine", "NONE", "PERCENT", { "secondFontSize" } },
    { "healPrediction", false, true, { "overheal" } },
    { "dispelIcon", false, true, { "dispelFilter", "dispelStyle", "dispelIconSize" },
        { dispelTint = false, dispelStyle = "ICON" } },
    { "dispelIcon", false, true, { "dispelSquarePoint", "dispelSquareSize" }, { dispelStyle = "SQUARE" } },
    { "dispelTint", false, true, { "dispelFilter" }, { dispelIcon = false } },
    { "dispelStyle", "ICON", "SQUARE", { "dispelSquarePoint", "dispelSquareSize" }, { dispelIcon = true } },
    { "dispelStyle", "SQUARE", "ICON", { "dispelIconSize" }, { dispelIcon = true } },
    { "debuffRow", false, true, { "debuffCount", "debuffSize" } },
    { "roleIcon", false, true, { "roleIconPoint", "roleIconDamager", "iconSize" },
        { raidMarker = false, leaderIcon = false, looterIcon = false, readyCheckIcon = false } },
    { "raidMarker", false, true, { "raidMarkerPoint" } },
    { "leaderIcon", false, true, { "leaderIconPoint" } },
    { "looterIcon", false, true, { "looterIconPoint" } },
    { "readyCheckIcon", false, true, { "readyCheckIconPoint", "iconSize" },
        { roleIcon = false, raidMarker = false, leaderIcon = false, looterIcon = false } },
    { "rangeFade", false, true, { "rangeAlpha" } },
    { "mainTanksShow", false, true, { "mainTanksTitle", "mainTanksPerLine", "mainTanksGrowth", "mainTanksX",
        "mainTanksY" } },
    { "petsShow", false, true, { "petsTitle", "petsPerLine", "petsCellHeight", "petsGrowth", "petsX", "petsY" } },
    { "toolsShow", false, true, { "toolsMode", "toolsX", "toolsY", "toolsTargets", "toolsReady", "toolsMarkers",
        "toolsRolePoll", "toolsAssist", "toolsConvert", "toolsLoot" }, { toolsMode = "FREE" } },
    { "toolsShow", false, true, { "toolsOpen" }, { toolsMode = "DOCKED" } },
    { "minimapShow", false, true, { "minimapAngle" } },
}

RO.Open(10, "general")
for _, case in ipairs(CASES) do
    local parent, off, wake, rows, with = case[1], case[2], case[3], case[4], case[5] or {}
    for key, value in pairs(with) do set(key, value) end
    for _, key in ipairs(rows) do
        RO.SelectTab(tabOf(key))
        set(parent, wake)
        H.check(parent .. " wakes " .. key, rowFor(key) and rowFor(key).enabledState, true)
        set(parent, off)
        H.check(parent .. " greys " .. key, rowFor(key) and rowFor(key).enabledState, false)
        H.checkTrue(parent .. " keeps the row " .. key, rowFor(key) and rowFor(key):IsShown())
    end
    set(parent, default(parent))
    for key in pairs(with) do set(key, default(key)) end
end

-- Rows that stay: the title and ring of the single block, the gap (the
-- own panels' too), the second line's colour (the status words), the
-- tint itself, a special panel's name list (every size's).
local function stays(label, parent, value, key)
    RO.SelectTab(tabOf(key))
    set(parent, value)
    H.check(label, rowFor(key).enabledState, true)
    set(parent, default(parent))
end
stays("no grouping: block titles", "groupBy", "NONE", "blockTitles")
stays("no grouping: block border", "groupBy", "NONE", "blockBorder")
stays("no grouping: block spacing", "groupBy", "NONE", "blockSpacing")
stays("no second line: its colour", "secondLine", "NONE", "secondLineColor")
stays("dispel icon off: the tint", "dispelIcon", false, "dispelTint")
stays("my tanks off: the names", "myTanksShow", false, "myTankNames")

-- Another size is edited: its own values count.
RO.SelectTab("debuffs")
RC.Set(ns.Raid.Scope(10), "debuffRow", true)
RC.Set(ns.Raid.Scope(20), "debuffRow", false)
H.check("size 10: row on", rowFor("debuffCount").enabledState, true)
RO.SelectSize(20)
H.check("size 20: row off", rowFor("debuffCount").enabledState, false)
H.check("no error", #M.errors, 0)
