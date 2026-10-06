-- The raid options menu (Raid/Options/Schema.lua): every raid setting in
-- exactly one place, every word of it in every language, labels that fit
-- the window's label column.
local M = H.M
local ns = H.LoadAddon()
local Schema, RS, L = ns.RaidSchema, ns.RaidSettings, ns.L

local function ids(list)
    local out = {}
    for i, t in ipairs(list) do out[i] = t.id end
    return table.concat(out, ",")
end
H.check("tabs", ids(Schema.TABS), "general,layout,cell,texts,debuffs,indicators,icons")

-- Every setting once: in a section, or in the header bar.
local seen = {}
for _, tab in ipairs(Schema.TABS) do
    for _, sec in ipairs(tab.sections) do
        for _, key in ipairs(sec.keys) do
            H.checkTrue("known setting " .. key, RS.Get(key))
            H.check("once: " .. key, seen[key], nil)
            seen[key] = tab.id
        end
    end
end
for _, key in ipairs(Schema.HEADER_KEYS) do
    H.check("header bar only: " .. key, seen[key], nil)
    seen[key] = "header"
end
for _, def in ipairs(RS.All()) do H.checkTrue("reachable: " .. def.key, seen[def.key]) end
H.check("character-wide ones on General", tostring(seen.showInParty) .. tostring(seen.hideBlizzard)
    .. tostring(seen.enabled), "generalgeneralgeneral")
H.check("class order beside the grouping", seen.classOrder, "layout")
H.check("position on Layout", seen.x, "layout")
H.check("states with the icons", seen.aggroBorder, "icons")

-- Shared words.
H.check("indicator spells", Schema.WordKey("indicatorBottomLeftSpells"), "indicatorSpells")
H.check("icon switch", Schema.WordKey("looterIcon"), "iconShow")
H.check("icon point", Schema.WordKey("looterIconPoint"), "iconPoint")
H.check("own word", Schema.WordKey("roleIconDamager"), "roleIconDamager")
H.check("label", Schema.Label("indicatorTopSpells"), "Spells")
H.check("section", Schema.SectionTitle("indicatorTopRight"), "Top right corner")
H.check("tab", Schema.TabTitle("icons"), "Icons & states")
H.check("point choices: the unit frames' words", Schema.EnumText(RS.Get("roleIconPoint"), "TOPLEFT"), "Top left")
H.check("raid's own choice", Schema.EnumText(RS.Get("sizeMode"), "AUTO"), "Automatic")
H.check("hint", Schema.Hint("indicatorTopLeftSpells"), "Spell IDs, or names from your spell book")
H.check("no hint", Schema.Hint("cellWidth"), nil)
H.checkTrue("the cell's note", Schema.Note("cell"))

-- Every word in every language: labels, sections, tabs, notes, choices.
local needed = {}
local function need(name) needed[name] = true end
for _, tab in ipairs(Schema.TABS) do
    need("RAID_TAB_" .. tab.id)
    if tab.note then need("RAID_NOTE_" .. tab.note) end
    for _, sec in ipairs(tab.sections) do need("RAID_SECTION_" .. sec.id) end
end
for _, def in ipairs(RS.All()) do
    need("RAID_SETTING_" .. Schema.WordKey(def.key))
    if def.type == "enum" and def.values ~= ns.Settings.POINTS then
        for _, v in ipairs(def.values) do need("RAID_ENUM_" .. Schema.WordKey(def.key) .. "_" .. v) end
    end
end
for _, v in ipairs(ns.Settings.POINTS) do need("ENUM_" .. v) end
for name in pairs(needed) do
    for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
        H.checkTrue(code .. " has " .. name, type(ns.Locales[code][name]) == "string")
    end
end

-- Labels fit the label column, hints are no longer than the unit frames'
-- longest, in every language (mock: half the font size per character).
local function width(text, size)
    local fs = M.newWidget("FontString")
    fs:SetFont("x", size, "")
    fs:SetText(text)
    return fs:GetStringWidth()
end
local longestHint = 0
for key, v in pairs(ns.Locales.enUS) do
    if key:match("^HINT_") then longestHint = math.max(longestHint, width(v, 10)) end
end
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    for key, v in pairs(ns.Locales[code]) do
        if key:match("^RAID_SETTING_") then
            H.checkTrue(code .. " label fits: " .. key, width(v, 12) <= ns.Widgets.LABEL_MAX_W)
        elseif key:match("^RAID_HINT_") then
            H.checkTrue(code .. " hint fits: " .. key, width(v, 10) <= longestHint)
        end
    end
end
