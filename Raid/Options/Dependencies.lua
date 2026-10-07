local _, ns = ...

-- Which rows of the raid window mean something now for the edited size
-- (Raid/Options/Window.lua greys the others; they stay in place, their
-- values kept): a row whose switch is off, or whose mode leaves it
-- without effect. Each rule names what the code reads: a row greys only
-- where its setting truly does nothing. Raid/Options/Buffs.lua has the
-- Buffs tab's.
local Raid, RaidConfig, RaidOptions = ns.Raid, ns.RaidConfig, ns.RaidOptions
local ACTIVE = RaidOptions.ROW_ACTIVE

-- A setting as the window edits it: the character's, or the edited size's.
local function get(key)
    local scope = ns.RaidSettings.Get(key).scope == "general" and "general" or Raid.Scope(RaidOptions.Size())
    return RaidConfig.Get(scope, key)
end

local function on(key) return function() return get(key) == true end end
local function is(key, value) return function() return get(key) == value end end
local function isNot(key, value) return function() return get(key) ~= value end end
local function anyOn(keys)
    return function()
        for _, key in ipairs(keys) do
            if get(key) == true then return true end
        end
        return false
    end
end

local ICON_SWITCHES = { "roleIcon", "raidMarker", "leaderIcon", "looterIcon", "readyCheckIcon" }

-- { test, rows }: every test of a row must pass.
local RULES = {
    -- Raid/Layout.lua: no grouping is one block of everyone (you are
    -- always in it). Its title and ring still show; the gap between
    -- blocks is the own panels' too (Raid/Panel.lua: Shape).
    { isNot("groupBy", "NONE"), { "blockDirection", "blocksPerLine", "hideEmpty" } },
    -- Core/Border.lua through Raid/Cell.lua: no ring, no size; the gold
    -- style paints its own shades.
    { on("cellBorder"), { "cellBorderStyle", "cellBorderSize", "cellBorderColor" } },
    { isNot("cellBorderStyle", "GOLD"), { "cellBorderColor" } },
    -- Elements/Health.lua: the fixed colour only for STATIC (by class,
    -- others take the reaction colour).
    { is("healthColorMode", "STATIC"), { "healthColor" } },
    -- Elements/Texts.lua: a name in the class colour never takes the
    -- plain one. Without a second line its size goes unused; its colour
    -- still paints the status words (dead, offline, AFK).
    { function() return get("nameClassColor") ~= true end, { "nameColor" } },
    { isNot("secondLine", "NONE"), { "secondFontSize" } },
    -- Units/Single.lua: the lane only with heal prediction.
    { on("healPrediction"), { "overheal" } },
    -- Raid/CellAuras.lua: the tint is a switch of its own and takes the
    -- filter too.
    { on("dispelIcon"), { "dispelStyle", "dispelIconSize", "dispelSquarePoint", "dispelSquareSize" } },
    { anyOn({ "dispelIcon", "dispelTint" }), { "dispelFilter" } },
    { is("dispelStyle", "ICON"), { "dispelIconSize" } },
    { is("dispelStyle", "SQUARE"), { "dispelSquarePoint", "dispelSquareSize" } },
    { on("debuffRow"), { "debuffCount", "debuffSize" } },
    { anyOn(ICON_SWITCHES), { "iconSize" } },
    { on("roleIcon"), { "roleIconDamager" } },
    { on("rangeFade"), { "rangeAlpha" } },
    { on("toolsShow"), { "toolsMode", "toolsOpen", "toolsX", "toolsY", "toolsTargets", "toolsReady",
        "toolsMarkers", "toolsRolePoll", "toolsAssist", "toolsConvert", "toolsLoot" } },
    { on("minimapShow"), { "minimapAngle" } },
}
for _, key in ipairs(ICON_SWITCHES) do
    RULES[#RULES + 1] = { on(key), { key .. "Point" } }
end
-- A special panel's settings while it shows at the edited size; its name
-- list is the character's, for every size, and stays.
for _, p in ipairs(Raid.PANELS) do
    local rows = {}
    for _, key in ipairs(p.keys) do
        if key ~= p.id .. "Show" and key ~= p.names then rows[#rows + 1] = key end
    end
    RULES[#RULES + 1] = { on(p.id .. "Show"), rows }
end

local tests = {}
for _, rule in ipairs(RULES) do
    for _, key in ipairs(rule[2]) do
        assert(ns.RaidSettings.Get(key), "dependency: unknown raid setting " .. key)
        tests[key] = tests[key] or {}
        table.insert(tests[key], rule[1])
    end
end
for key, list in pairs(tests) do
    local before = ACTIVE[key]
    ACTIVE[key] = function()
        if before and not before() then return false end
        for _, test in ipairs(list) do
            if not test() then return false end
        end
        return true
    end
end
