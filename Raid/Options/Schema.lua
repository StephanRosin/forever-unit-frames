local _, ns = ...

-- The raid options window's menu (Raid/Options/Window.lua) and the raid
-- pages of the wiki (tools/make_wiki.lua): tabs, their sections and the
-- raid settings in them, and the words for all of it. Every raid setting
-- is in exactly one section of a settings tab (a custom tab has none), except sizeMode, which the window's header
-- bar holds. The words are the raid's own (RAID_SETTING_<key>, ...): a
-- raid key may share its name with a unit-frame setting of another
-- meaning.
local Schema = {}
ns.RaidSchema = Schema

local L = ns.L

-- The settings of one corner indicator position.
local function indicator(name)
    local key = "indicator" .. name
    return { id = key, keys = { key .. "Spells", key .. "Color", key .. "Size", key .. "Own", key .. "Time" } }
end

-- One icon: its switch and its point.
local function icon(id, key, extra)
    local keys = { key, key .. "Point" }
    if extra then keys[#keys + 1] = extra end
    return { id = id, keys = keys }
end

-- One section per special panel (Raid.PANELS), its settings in their
-- order.
local function panelSections()
    local list = {}
    for _, p in ipairs(ns.Raid.PANELS) do list[#list + 1] = { id = p.id, keys = p.keys } end
    return list
end

Schema.TABS = {
    { id = "general", sections = {
        { id = "raidFrames", keys = { "enabled", "showInParty", "hideBlizzard" } },
        { id = "minimap", keys = { "minimapShow", "minimapAngle" } },
    } },
    { id = "layout", sections = {
        { id = "grouping", keys = { "groupBy", "sortBy", "classOrder", "hideEmpty", "blockTitles" } },
        { id = "arrangement", keys = { "blockDirection", "blocksPerLine", "blockSpacing", "cellGrowth",
            "cellsPerLine", "cellSpacing" } },
        { id = "position", keys = { "x", "y" } },
        { id = "borders", keys = { "panelBorder", "blockBorder" } },
    } },
    -- The special panels; the note says who is in them.
    { id = "panels", note = "panels", sections = panelSections() },
    -- Heals, shields and the power strip keep the unit frames' shipped
    -- colours (Raid/Cell.lua): the note says so.
    { id = "cell", note = "cell", sections = {
        { id = "size", keys = { "cellWidth", "cellHeight" } },
        { id = "bars", keys = { "healthColorMode", "healthColor", "barTexture", "backgroundColor", "powerStrip" } },
        { id = "cellShape", keys = { "cellBorder", "cellBorderStyle", "cellBorderSize", "cellBorderColor",
            "cellCornerRadius" } },
        { id = "heals", keys = { "healPrediction", "overheal", "absorbs", "combatText" } },
    } },
    { id = "texts", sections = {
        { id = "texts", keys = { "nameClassColor", "nameColor", "secondLine", "secondLineColor" } },
        { id = "fonts", keys = { "fontFace", "nameFontSize", "secondFontSize", "fontOutline", "fontShadow" } },
    } },
    { id = "debuffs", sections = {
        { id = "dispel", keys = { "dispelIcon", "dispelFilter", "dispelStyle", "dispelIconSize", "dispelSquarePoint",
            "dispelSquareSize", "dispelTint" } },
        { id = "debuffRow", keys = { "debuffRow", "debuffCount", "debuffSize" } },
    } },
    { id = "indicators", sections = {
        indicator("TopLeft"), indicator("TopRight"), indicator("BottomLeft"), indicator("BottomRight"),
        indicator("Top"),
    } },
    { id = "icons", sections = {
        { id = "icons", keys = { "iconSize" } },
        icon("role", "roleIcon", "roleIconDamager"),
        icon("raidMarker", "raidMarker"),
        icon("leader", "leaderIcon"),
        icon("looter", "looterIcon"),
        icon("readyCheck", "readyCheckIcon"),
        { id = "states", keys = { "rangeFade", "rangeAlpha", "aggroBorder", "targetBorder" } },
    } },
    -- The raid tools bar: where it is, which tools it holds; the note says
    -- who sees which.
    { id = "tools", note = "tools", sections = {
        { id = "toolsBar", keys = { "toolsShow", "toolsMode", "toolsOpen", "toolsX", "toolsY" } },
        { id = "toolsList", keys = { "toolsTargets", "toolsReady", "toolsMarkers" } },
    } },
    -- The window's own page: export and import of the edited size
    -- (Raid/Options/Window.lua). No settings; the wiki has no page for it.
    { id = "profile", custom = "profile", sections = {} },
}

-- Held by the header bar, not by a tab.
Schema.HEADER_KEYS = { "sizeMode" }

-- Settings that share their words: the five indicator positions (the
-- section names the position), the icons' switches and points (the
-- section names the icon), the special panels' settings (the section
-- names the panel; their layout has the main panel's words).
local SHARED = {}
for _, ind in ipairs(ns.Raid.INDICATORS) do
    for _, part in ipairs({ "Spells", "Color", "Size", "Own", "Time" }) do
        SHARED["indicator" .. ind.name .. part] = "indicator" .. part
    end
end
for _, key in ipairs({ "roleIcon", "raidMarker", "leaderIcon", "looterIcon", "readyCheckIcon" }) do
    SHARED[key], SHARED[key .. "Point"] = "iconShow", "iconPoint"
end
local PANEL_WORDS = { Show = "panelShow", Title = "panelTitle", PerLine = "cellsPerLine", Growth = "cellGrowth",
    X = "x", Y = "y" }
for _, p in ipairs(ns.Raid.PANELS) do
    for part, wordKey in pairs(PANEL_WORDS) do SHARED[p.id .. part] = wordKey end
    if p.names then SHARED[p.names] = "nameList" end
end
SHARED.petsCellHeight = "cellHeight"
SHARED.toolsX, SHARED.toolsY = "x", "y"

-- The name a setting's words go by.
function Schema.WordKey(key)
    return SHARED[key] or key
end

local function word(prefix, key)
    local name = prefix .. key
    local v = L[name]
    if v ~= name then return v end
    return nil
end

function Schema.Label(key) return word("RAID_SETTING_", Schema.WordKey(key)) or key end
function Schema.Hint(key) return word("RAID_HINT_", Schema.WordKey(key)) end
function Schema.SectionTitle(id) return word("RAID_SECTION_", id) or id end
function Schema.TabTitle(id) return word("RAID_TAB_", id) or id end
function Schema.Note(id) return word("RAID_NOTE_", id) end

-- A choice of an enum: the raid's own word, else the unit frames' (the
-- nine points).
function Schema.EnumText(def, value)
    return word("RAID_ENUM_" .. Schema.WordKey(def.key) .. "_", value) or word("ENUM_", value) or value
end
