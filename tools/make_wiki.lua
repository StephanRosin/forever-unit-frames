-- Writes the settings reference of the GitHub wiki (docs/wiki/Settings-*.md,
-- docs/wiki/Raid-*.md and _Sidebar.md) from the same sources the options
-- windows read: the menus (Options/Schema.lua, Raid/Options/Schema.lua),
-- the English labels and hints, and the defaults of the addon as shipped
-- (preset included). Home.md and FAQ.md are written by hand.
--
-- Run from the repository root:  tools/make_wiki
-- (loads the addon the way the tests do: tests/mock.lua, no game needed).
-- The output is deterministic; running it again changes nothing unless the
-- options did.

local H = _G.H
local ns = H.LoadShipped()
local S, L, Schema = ns.Settings, ns.L, ns.Schema
local RS, RaidSchema = ns.RaidSettings, ns.RaidSchema

-- WIKI_OUT (optional): another folder, e.g. for the test that checks the
-- committed pages are current.
local OUT = (rawget(_G, "WIKI_OUT") or (ADDONDIR .. "/docs/wiki")) .. "/"
local FRAMES = { "player", "target", "targettarget", "focus", "pet", "party" }

local function label(key, fallback)
    local v = L[key]
    if v == nil or v == key then return fallback end
    return v
end

local function frameName(scope) return label("FRAME_" .. scope, scope) end

-- A value as the options window shows it; enumText (optional): the words
-- of an enum's choices, the unit frames' by default.
local function valueText(def, v, enumText)
    if v == nil or v == "" then return "(none)" end
    local t = def.type
    if t == "bool" then return v and "On" or "Off" end
    if t == "enum" then return (enumText or Schema.EnumText)(def, v) or tostring(v) end
    if t == "color" then
        local hex = ("#%02x%02x%02x"):format(math.floor(v[1] * 255 + 0.5), math.floor(v[2] * 255 + 0.5),
            math.floor(v[3] * 255 + 0.5))
        local a = v[4] or 1
        if a < 1 then return ("`%s`, %d %% opaque"):format(hex, math.floor(a * 100 + 0.5)) end
        return "`" .. hex .. "`"
    end
    if t == "int" and v == 0 and def.zeroText then return label(def.zeroText, "0") end
    if t == "media" then return tostring(v) end
    return tostring(v)
end

-- What can be chosen: a range, or the enum's choices. The raid's own
-- words for its choices and texts (raid = true).
local function choices(def, raid)
    local t = def.type
    local enumText = raid and RaidSchema.EnumText or Schema.EnumText
    if t == "int" then
        local range = ("%d – %d"):format(def.min or 0, def.max or 0)
        if def.zeroText then range = range .. (" (0: %s)"):format(label(def.zeroText, "0")) end
        return range
    end
    if t == "enum" and def.values == S.POINTS then
        return "Any of the 9 points (corners, edges, center)"
    end
    if t == "enum" then
        local list = {}
        for _, v in ipairs(def.values) do list[#list + 1] = enumText(def, v) or v end
        return table.concat(list, ", ")
    end
    if t == "color" then return "Color" end
    if t == "media" then return def.mediaKind == "font" and "Font" or "Texture" end
    if t == "text" then return raid and "Text" or "Text (a spell name or ID)" end
    if t == "bool" then return "On, Off" end
    return ""
end

-- The frames an option is on (in the order of the navigation).
local function framesOf(def)
    local list = {}
    for _, scope in ipairs(FRAMES) do
        if S.AppliesTo(def, scope) then list[#list + 1] = scope end
    end
    return list
end

-- The default, per frame when it differs.
local function defaultText(def, scopes)
    if #scopes == 0 then return valueText(def, S.Default(def, "general")) end
    local groups, order = {}, {}
    for _, scope in ipairs(scopes) do
        local text = valueText(def, S.Default(def, scope))
        if not groups[text] then groups[text] = {}; order[#order + 1] = text end
        table.insert(groups[text], frameName(scope))
    end
    if #order == 1 then return order[1] end
    local parts = {}
    for _, text in ipairs(order) do parts[#parts + 1] = ("%s: %s"):format(table.concat(groups[text], ", "), text) end
    return table.concat(parts, "; ")
end

-- A table cell's HTML: escaped, `code` as <code>.
local function cell(s)
    s = tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\n", " ")
    return (s:gsub("`(.-)`", "<code>%1</code>"))
end

-- Fixed column widths: GitHub sizes Markdown tables to their content, so
-- every table looked different. The wiki's text column is 896 px wide;
-- both layouts fill it without scrolling.
local WIDTHS = {
    [4] = { 190, 350, 190, 160 },
    [5] = { 170, 280, 160, 150, 130 },
}
local HEADINGS = { "Option", "What it does", "Choices", "Default", "Frames" }

-- GitHub's anchor for a heading: lower case, spaces to hyphens, most
-- punctuation dropped.
local function anchor(title)
    return (title:lower():gsub("[^%w%s%-]", ""):gsub("%s", "-"))
end

-- What each frame tab is for (the page's first line).
local TAB_INTRO = {
    layout = "Size, position, the rows of the frame, portrait, markers, border, shadow and corners.",
    group = "The party only: how the members are arranged, their pets and their targets.",
    bars = "Colors and textures of the bars, shields, incoming heals, power colors and the druid's mana.",
    text = "What the texts on the title row and the bars show, how they read, and the font.",
    auras = "Buffs, debuffs, the party's dispellable debuffs and the player's totems.",
    status = "Icons and markers on the frame, combo points, threat, highlights and fading.",
    castbar = "Castbars, and the player's threat bar below them.",
}

local function write(name, lines)
    local fh = assert(io.open(OUT .. name, "w"))
    fh:write(table.concat(lines, "\n"), "\n")
    fh:close()
end

local GENERATED = "<!-- Generated by tools/make_wiki from the addon's own options. Do not edit by hand. -->"

-- A table's start: its fixed column widths and headings, up to <tbody>.
local function tableStart(lines, columns)
    lines[#lines + 1] = "<table>"
    local head = {}
    for i, w in ipairs(WIDTHS[columns]) do
        head[#head + 1] = ('<th align="left" width="%d">%s</th>'):format(w, HEADINGS[i])
    end
    lines[#lines + 1] = "<thead><tr>" .. table.concat(head) .. "</tr></thead>"
    lines[#lines + 1] = "<tbody>"
end

-- One table per section: option, what it does, choices, default, frames.
local function section(lines, sec, keys, scopesFor, showFrames, level)
    lines[#lines + 1] = level .. " " .. label("SECTION_" .. sec.id, sec.id)
    lines[#lines + 1] = ""
    if sec.action then
        lines[#lines + 1] = ("Button: **%s**."):format(label("ACTION_" .. sec.action, sec.action))
        lines[#lines + 1] = ""
    end
    tableStart(lines, showFrames and 5 or 4)
    for _, key in ipairs(keys) do
        local def = S.Get(key)
        local scopes = scopesFor(def)
        local hint = label("HINT_" .. key, "")
        local row = { "<b>" .. cell(label("SETTING_" .. key, key)) .. "</b>", cell(hint), cell(choices(def)),
            cell(defaultText(def, scopes)) }
        if showFrames then
            local names = {}
            for _, scope in ipairs(scopes) do names[#names + 1] = frameName(scope) end
            row[#row + 1] = cell(#scopes == #FRAMES and "all" or table.concat(names, ", "))
        end
        lines[#lines + 1] = "<tr><td>" .. table.concat(row, "</td><td>") .. "</td></tr>"
    end
    lines[#lines + 1] = "</tbody>"
    lines[#lines + 1] = "</table>"
    lines[#lines + 1] = ""
end

-- General ---------------------------------------------------------------------------
local pages = {}
do
    local lines = { GENERATED, "", "# Settings: General", "",
        "The **General** page (top of the list on the left in `/fuf`) sets the look for every frame at once.",
        "Most of these can be overridden on a frame's own page; the frame then keeps its own value.",
        "The **Profile** tab (export, import, reset) is explained on the [[Home]] page.", "" }
    local body, toc = {}, { "**On this page:**", "" }
    for _, tab in ipairs(Schema.Tabs("general")) do
        if not tab.custom then
            local title = label("TAB_" .. tab.id, tab.id)
            body[#body + 1] = "## " .. title
            body[#body + 1] = ""
            local names = {}
            for _, sec in ipairs(tab.sections) do
                local keys = {}
                for _, key in ipairs(sec.keys) do
                    if S.AppliesTo(S.Get(key), "general") then keys[#keys + 1] = key end
                end
                if #keys > 0 then
                    section(body, sec, keys, function() return {} end, false, "###")
                    local name = label("SECTION_" .. sec.id, sec.id)
                    names[#names + 1] = ("[%s](#%s)"):format(name, anchor(name))
                end
            end
            toc[#toc + 1] = ("- **[%s](#%s):** %s"):format(title, anchor(title), table.concat(names, " · "))
        end
    end
    for _, l in ipairs(toc) do lines[#lines + 1] = l end
    lines[#lines + 1] = ""
    for _, l in ipairs(body) do lines[#lines + 1] = l end
    write("Settings-General.md", lines)
    pages[#pages + 1] = { "Settings-General", "General" }
end

-- Frame tabs: one page per tab, every frame that has the option listed.
for _, tab in ipairs(Schema.FRAME) do
    local title = label("TAB_" .. tab.id, tab.id)
    local lines = { GENERATED, "", "# Settings: " .. title, "",
        TAB_INTRO[tab.id] or "",
        "",
        ("The **%s** tab on each frame's page in `/fuf`. The last column says which frames have the option;"
            .. " a default that differs per frame is listed per frame."):format(title), "" }
    local body, names = {}, {}
    local any = false
    for _, sec in ipairs(tab.sections) do
        local keys = {}
        for _, key in ipairs(sec.keys) do
            if #framesOf(S.Get(key)) > 0 then keys[#keys + 1] = key end
        end
        if #keys > 0 then
            any = true
            section(body, sec, keys, framesOf, true, "##")
            local name = label("SECTION_" .. sec.id, sec.id)
            names[#names + 1] = ("[%s](#%s)"):format(name, anchor(name))
        end
    end
    lines[#lines + 1] = "**On this page:** " .. table.concat(names, " · ")
    lines[#lines + 1] = ""
    for _, l in ipairs(body) do lines[#lines + 1] = l end
    if any then
        local name = "Settings-" .. title:gsub("%s+", "-")
        write(name .. ".md", lines)
        pages[#pages + 1] = { name, title }
    end
end

-- Raid tabs: one page per tab of the raid options window ---------------------------

-- What each raid tab is for (the page's first line).
local RAID_TAB_INTRO = {
    general = "The raid frames as a whole: on or off, the raid view in a 5-player group, Blizzard's raid frames,"
        .. " the raid frames' minimap button.",
    layout = "How the panel is made of blocks, how cells and blocks are arranged, the panel's position and borders.",
    arrangement = "Up to nine panels of your own beside the main panel (Panel 2 to Panel 10), per raid size. The"
        .. " tab shows a column per panel with its blocks; drag a block onto another panel's column, or click it"
        .. " for a menu (Move to …). Add and remove panels there, and pick each panel's grouping (group, class or"
        .. " role) and its blocks. A block of the main panel's grouping moves out of the main panel; a block of"
        .. " another grouping shows its players again. Each new panel starts at a spot of its own (the table shows"
        .. " Panel 2's).",
    panels = "Panels of their own beside the main panel, each with its own position per raid size: the main tanks"
        .. " and the main assists of the raid, your own lists of tanks and of favourites, and the raid's pets in"
        .. " smaller cells. Their players stay in their groups as well.",
    cell = "The size of a cell, its bars and colors, its border and corners, heals and shields.",
    tools = "The raid tools bar, in place of Blizzard's raid manager: where it is and which tools it holds.",
    texts = "The name and the second line in the middle of each cell: their colors and fonts.",
    debuffs = "The most important dispellable debuff, as an icon in the centre or a square in a corner, and a"
        .. " row that shows every debuff (the one in the centre may appear there too).",
    indicators = "Up to five small squares at the corners and the top edge, each for spells of your choice"
        .. " (heals over time, shields).",
    clickCast = "Heal, decurse, target, assist or focus raid members with one click: up to 40 mouse combinations"
        .. " (five buttons, with and without Shift, Ctrl and Alt) on the cells of every panel and on the party"
        .. " frames, and up to 16 keys. Spells are kept by name, so the highest rank you know is cast. A key with"
        .. " a spell or an item casts it on the friendly raid member under the mouse; a key with a macro runs it"
        .. " as written, so add [@mouseover] to it yourself. While the raid frames (or, with the party switch, the"
        .. " party frames) show, a key is taken from what it is bound to otherwise (the window warns), so pick"
        .. " keys you do not use; the keys' table below has one row for all sixteen. **Copy from** takes another"
        .. " character's bindings and keys (a spell this character does not know is left out, the chat names it);"
        .. " **Clear all** (click twice) puts back the defaults: the left click targets, the right click opens"
        .. " the menu, no keys. With Clique loaded, click-casting is off until switched on. A cell that joins in"
        .. " combat gets the bindings once combat ends. Blizzard's own click bindings (its click-casting window)"
        .. " win over these on the same click; and since this client lets target and the unit menu act only on"
        .. " clicks bound there (by default the plain left and right clicks), Target on any other click is done"
        .. " by a macro and the menu is offered on those two only.",
    icons = "Role, raid target marker, leader, master looter and ready check icons, and the states: range,"
        .. " aggro, your target.",
}

-- The default per raid size when the sizes differ. A binding
-- (click-casting) in words.
local function raidDefault(def)
    if def.kinds then return RaidSchema.BindingText(RS.Default(def, "general"), def.key) end
    if def.scope == "general" then return valueText(def, RS.Default(def, "general"), RaidSchema.EnumText) end
    local groups, order = {}, {}
    for _, size in ipairs(ns.Raid.SIZES) do
        local text = valueText(def, RS.Default(def, ns.Raid.Scope(size)), RaidSchema.EnumText)
        if not groups[text] then groups[text] = {}; order[#order + 1] = text end
        table.insert(groups[text], RaidSchema.EnumText(RS.Get("sizeMode"), tostring(size)))
    end
    if #order == 1 then return order[1] end
    local parts = {}
    for _, text in ipairs(order) do parts[#parts + 1] = ("%s: %s"):format(table.concat(groups[text], ", "), text) end
    return table.concat(parts, "; ")
end

-- What a raid setting takes: a binding's kinds in words.
local function raidChoices(def)
    if not def.kinds then return choices(def, true) end
    local list = {}
    for _, kind in ipairs(def.kinds) do list[#list + 1] = RaidSchema.KindText(kind, def.key) end
    return table.concat(list, ", ")
end

-- One table of raid settings under a heading. Settings of the section
-- that share their words (the click-casting keys) are one row.
local function raidSection(lines, title, keys)
    lines[#lines + 1] = "## " .. title
    lines[#lines + 1] = ""
    tableStart(lines, 4)
    local listed = {}
    for _, key in ipairs(keys) do
        local def, wordKey = RS.Get(key), RaidSchema.WordKey(key)
        if not listed[wordKey] then
            listed[wordKey] = true
            local row = { "<b>" .. cell(RaidSchema.Label(key)) .. "</b>", cell(RaidSchema.Hint(key) or ""),
                cell(raidChoices(def)), cell(raidDefault(def)) }
            lines[#lines + 1] = "<tr><td>" .. table.concat(row, "</td><td>") .. "</td></tr>"
        end
    end
    lines[#lines + 1] = "</tbody>"
    lines[#lines + 1] = "</table>"
    lines[#lines + 1] = ""
end

-- A tab's sections as the page lists them: { title, keys }. Sections all
-- alike (the own panels) are one, for every panel.
local OWN_PANELS_TITLE = "Each own panel"
local function raidSections(tab)
    if tab.alike then return { { title = OWN_PANELS_TITLE, keys = tab.sections[1].keys } } end
    local list = {}
    for i, sec in ipairs(tab.sections) do list[i] = { title = RaidSchema.SectionTitle(sec.id), keys = sec.keys } end
    return list
end

-- What the tab's settings belong to: a raid size each, or (every setting
-- of the tab per character) the character.
local PER_SIZE = "The **%s** tab of the raid options window (`/fuf raid`). Each raid size (10, 20, 40) has a"
    .. " profile of its own: the size tabs at the top choose which one you edit; a default that differs per size"
    .. " is listed per size."
local PER_CHARACTER = "The **%s** tab of the raid options window (`/fuf raid`). Its settings belong to the"
    .. " character, not to a raid size: they are the same at every size."
local function perCharacter(tab)
    for _, sec in ipairs(tab.sections) do
        for _, key in ipairs(sec.keys) do
            if RS.Get(key).scope ~= "general" then return false end
        end
    end
    return true
end

local raidPages = {}
local function raidPage(tab)
    local title = RaidSchema.TabTitle(tab.id)
    local lines = { GENERATED, "", "# Raid frames: " .. title, "", RAID_TAB_INTRO[tab.id] or "", "",
        (perCharacter(tab) and PER_CHARACTER or PER_SIZE):format(title), "" }
    if tab.note then
        lines[#lines + 1] = RaidSchema.Note(tab.note)
        lines[#lines + 1] = ""
    end
    local body, names = {}, {}
    if tab.id == "general" then
        -- The size switch sits in the window's header bar.
        raidSection(body, "Header bar", RaidSchema.HEADER_KEYS)
        names[#names + 1] = "[Header bar](#header-bar)"
    end
    for _, sec in ipairs(raidSections(tab)) do
        raidSection(body, sec.title, sec.keys)
        names[#names + 1] = ("[%s](#%s)"):format(sec.title, anchor(sec.title))
    end
    lines[#lines + 1] = "**On this page:** " .. table.concat(names, " · ")
    lines[#lines + 1] = ""
    for _, l in ipairs(body) do lines[#lines + 1] = l end
    local name = "Raid-" .. title:gsub("&", "and"):gsub("%s+", "-")
    write(name .. ".md", lines)
    raidPages[#raidPages + 1] = { name, title }
end
-- A tab without settings (Profile: export and import) has no page; the
-- Home page explains it.
for _, tab in ipairs(RaidSchema.TABS) do
    if #tab.sections > 0 then raidPage(tab) end
end

-- Sidebar ---------------------------------------------------------------------------
do
    local lines = { GENERATED, "", "**[[Home]]**", "", "**[[FAQ]]**", "", "**Settings**", "" }
    for _, page in ipairs(pages) do lines[#lines + 1] = ("- [[%s|%s]]"):format(page[2], page[1]) end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "**Raid frames**"
    lines[#lines + 1] = ""
    for _, page in ipairs(raidPages) do lines[#lines + 1] = ("- [[%s|%s]]"):format(page[2], page[1]) end
    write("_Sidebar.md", lines)
end

local all = {}
for _, page in ipairs(pages) do all[#all + 1] = page end
for _, page in ipairs(raidPages) do all[#all + 1] = page end
WIKI_PAGES = all
if not rawget(_G, "WIKI_OUT") then
    print(("wrote %d settings pages, %d raid pages and the sidebar to docs/wiki/"):format(#pages, #raidPages))
end
