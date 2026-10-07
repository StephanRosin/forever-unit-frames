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

-- A section's first paragraph, where its table alone does not say enough.
local SECTION_NOTE = {
    unitFrames = "Off, every unit frame counts as off and none of Blizzard's frames is hidden any more (they come"
        .. " back after a `/reload`). Each frame's own switch (the **Frames** tab, or the frame's page) keeps its"
        .. " value and is greyed meanwhile; switched on again, every frame is as its own switch says. The raid"
        .. " frames do not depend on it: they have their own switch in `/fuf raid`.",
}

-- One table per section: option, what it does, choices, default, frames.
local function section(lines, sec, keys, scopesFor, showFrames, level)
    lines[#lines + 1] = level .. " " .. label("SECTION_" .. sec.id, sec.id)
    lines[#lines + 1] = ""
    if SECTION_NOTE[sec.id] then
        lines[#lines + 1] = SECTION_NOTE[sec.id]
        lines[#lines + 1] = ""
    end
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
        .. " the raid frames' minimap button. Below the settings, the **Templates** section applies a role"
        .. " template or a look to the size you edit or to all sizes (with **Undo**), and its **Setup wizard**"
        .. " button opens the setup wizard: see [[Templates|Raid-Templates]].",
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
    buffs = "The buff watch: your class's group buffs (Fortitude, Divine Spirit, Shadow Protection, Arcane"
        .. " Intellect, Mark of the Wild, Thorns, the paladin blessings) on everyone in your raid or party."
        .. " Arcane Intellect and Divine Spirit go to those who use mana, Thorns to tanks only; a paladin picks one"
        .. " blessing per class. A buff your spell book does not know is not offered (its row is greyed)."
        .. " A small window shows each watched buff with how many members miss it and how many have it running"
        .. " out (under the time set here, at most a third of how long the buff lasts: a fresh blessing is not"
        .. " running out); members too far away for the client to see are not counted. By default it shows only"
        .. " while something is missing or running out. A click on its row casts it on the member who needs it most, and the **smart buff key** (set"
        .. " here, not one of the click-casting keys; taken while you are in a group) casts the next buff of all"
        .. " of them. The group form (Prayer of Fortitude, Arcane Brilliance, Gift of the Wild, a greater"
        .. " blessing, which takes a Symbol of Kings and blesses a whole class) is cast when enough members of one"
        .. " group miss it or have it running out and its reagent is in your bags; otherwise the single form, on the member with the least"
        .. " time left, missing first, alive and in range. Rebuffing is out of combat only (a rule of the client):"
        .. " in combat the rows and the key do nothing and the window shows its last state greyed. While the"
        .. " client keeps auras secret the window shows unknown rather than guess. Optionally an icon on a cell"
        .. " marks a member who misses a watched buff.",
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
-- that share their words and their name (the click-casting keys) are one
-- row; the blessings share their words but each is named by its class.
local function raidSection(lines, title, keys)
    lines[#lines + 1] = "## " .. title
    lines[#lines + 1] = ""
    tableStart(lines, 4)
    local listed = {}
    for _, key in ipairs(keys) do
        local def, name = RS.Get(key), RaidSchema.Label(key)
        if not listed[name] then
            listed[name] = true
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
-- Every menu tab holds settings; the Profiles tab (beside the sizes) has
-- a page of its own below.
for _, tab in ipairs(RaidSchema.TABS) do
    if #tab.sections > 0 then raidPage(tab) end
end

-- The Profiles tab (Raid/Options/Profiles.lua, Raid/Profiles.lua): no menu
-- tab, a page before the templates page. Which settings "Without layout
-- and sizes" keeps, per section, from the registry's classes.
do
    local L, T = ns.L, ns.RaidTemplates
    local lines = { GENERATED, "", "# Raid frames: Profiles", "",
        "The **Profiles** tab sits next to the size tabs 10, 20 and 40 at the top of the raid options window"
            .. " (`/fuf raid`). Picked, the window shows only this page: everything that acts on raid sizes as a"
            .. " whole. Applying a profile, copying between sizes and importing several sizes are each one change:"
            .. " **Undo** takes the last one back (once, until you log out or change something else). Nothing here"
            .. " works in combat.", "",
        "**On this page:** [Own profiles](#own-profiles) · [Copy between sizes](#copy-between-sizes) ·"
            .. " [Copy from another character](#copy-from-another-character) · [Reset](#reset) · [Export](#export)"
            .. " · [Import](#import)", "",
        "## Own profiles", "",
        ("**Save as** keeps your raid settings under a name, for every character of your account: **All three"
            .. " sizes** (the default) or one size, every setting as it shows (positions included; not the"
            .. " character's own settings such as click-casting or the buff watch). A name has at most %d letters;"
            .. " a name in use asks for a second click and then replaces that profile. Up to %d own profiles."
            .. " **Apply** puts a profile of all sizes into each size it holds; a profile of one size goes to the"
            .. " size you pick under **Apply to**, or to all three. **Delete** takes two clicks. Profiles saved by"
            .. " earlier versions (one size) still load."):format(T.OWN_NAME_LETTERS, T.OWN_MAX), "",
        "## Copy between sizes", "",
        "Copies one size onto another as it shows. **Everything** copies every setting; **Without layout and"
            .. " sizes** copies how the cells behave and look but keeps the target's layout and sizes: the"
            .. " settings below stay as they are. Click-casting, the buff watch, the name lists and the minimap"
            .. " button belong to the character and are the same at every size: there is nothing to copy.", "" }
    for _, tab in ipairs(RaidSchema.TABS) do
        local sections = tab.alike and { tab.sections[1] } or tab.sections
        for _, sec in ipairs(sections) do
            local names, seen = {}, {}
            for _, key in ipairs(sec.keys) do
                local name = RaidSchema.Label(key)
                if RS.Get(key).class == "layout" and not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end
            if #names > 0 then
                local title = tab.alike and "Each own panel" or RaidSchema.SectionTitle(sec.id)
                lines[#lines + 1] = ("- **%s**: %s"):format(title, table.concat(names, ", "))
            end
        end
    end
    for _, l in ipairs({ "",
        "The rest (grouping, sorting, the class order, colours, textures, fonts, borders, heals, which debuffs,"
            .. " icons and indicators show, the special panels on or off) is copied.", "",
        "## Copy from another character", "",
        "Takes one size of another of your characters (every character with raid settings is listed) onto the"
            .. " size you pick, after a second click. The click-casting bindings of another character are copied on"
            .. " the Click-casting tab.", "",
        "## Reset", "",
        "Puts one size back to its defaults, after a second click.", "",
        "## Export", "",
        "**All three sizes** (the default) gives one text with the 10, 20 and 40 player settings; or pick one"
            .. " size. The character's own settings are not in it. Copy the text to share it or keep a backup.", "",
        "## Import", "",
        "Paste a text and click **" .. L.IMPORT .. "**. A text of one size replaces the size picked under **"
            .. L.RAID_PROFILES_IMPORT_TO .. "**. A text of all sizes names them and asks for a second click,"
            .. " then replaces every size it holds as one change (**Undo** takes it back). Texts exported by"
            .. " earlier versions (one size) still import. Entries this version cannot read are left out and"
            .. " counted." }) do
        lines[#lines + 1] = l
    end
    write("Raid-Profiles.md", lines)
    raidPages[#raidPages + 1] = { "Raid-Profiles", "Profiles" }
end

-- Templates and the setup wizard (Raid/Templates.lua, Raid/TemplateData.lua,
-- Raid/Wizard.lua): no tab of their own, a page after the tabs' pages.
do
    local T, Page = ns.RaidTemplates, ns.RaidTemplatesPage
    -- A raid setting's name with its section's ("Main tanks: Show the
    -- panel"): many share their words.
    local sectionOf = {}
    for _, tab in ipairs(RaidSchema.TABS) do
        for _, sec in ipairs(tab.sections) do
            for _, key in ipairs(sec.keys) do sectionOf[key] = sec.id end
        end
    end
    local function settingName(key)
        local name = RaidSchema.Label(key)
        if sectionOf[key] then
            name = RaidSchema.SectionTitle(sectionOf[key]) .. ": " .. name
        end
        return name
    end
    local function sizeName(size) return RaidSchema.EnumText(RS.Get("sizeMode"), tostring(size)) end
    -- A template's value: per size where it differs.
    local function templateValue(key, v)
        local def = RS.Get(key)
        if type(v) == "table" and v[10] ~= nil then
            local parts = {}
            for _, size in ipairs(ns.Raid.SIZES) do
                parts[#parts + 1] = ("%s: %s"):format(sizeName(size), valueText(def, v[size], RaidSchema.EnumText))
            end
            return table.concat(parts, "; ")
        end
        return valueText(def, v, RaidSchema.EnumText)
    end
    local function sortedKeys(values)
        local keys = {}
        for key in pairs(values) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return settingName(a) < settingName(b) end)
        return keys
    end
    local function spellName(id) return C_Spell.GetSpellName(id) or ("spell " .. id) end
    local function htmlTable(lines, headings, widths, rows)
        lines[#lines + 1] = "<table>"
        local head = {}
        for i, h in ipairs(headings) do head[i] = ('<th align="left" width="%d">%s</th>'):format(widths[i], h) end
        lines[#lines + 1] = "<thead><tr>" .. table.concat(head) .. "</tr></thead>"
        lines[#lines + 1] = "<tbody>"
        for _, row in ipairs(rows) do lines[#lines + 1] = "<tr><td>" .. table.concat(row, "</td><td>") .. "</td></tr>" end
        lines[#lines + 1] = "</tbody>"
        lines[#lines + 1] = "</table>"
        lines[#lines + 1] = ""
    end
    local ROLE_TEXT = {
        healer = "Wider cells with the missing health, heals, overheal and shields, the debuff row and the dispel"
            .. " icon, range fading. A class with group buffs also gets the buff watch window, and its helpful"
            .. " spells that last on a member, as far as your spell book knows them, show as corner indicators"
            .. " (your own casts): heals over time, and shields such as Power Word: Shield and Earth Shield:",
        tank = "Compact cells, the aggro border, the main tanks panel. No filter for boss debuffs exists: the debuff"
            .. " row stays off and the centre icon shows any dispellable debuff. No heal prediction.",
        dps = "Small cells by group, every group in one line, no second line, no heal prediction, only the debuffs"
            .. " you can dispel.",
        dispel = "The DPS template, with the dispel icon large and the cell tinted in the debuff's color. Its"
            .. " click-casting suggestion (in the wizard) puts your dispel on the plain left click.",
    }
    local lines = { GENERATED, "", "# Raid frames: Templates and setup wizard", "",
        "A template sets many raid settings in one go. The **Templates** section of the raid window's **General**"
            .. " tab applies a role template or a look to the size you edit or to all"
            .. " three sizes. A template sets only the settings listed below; everything else stays as it is."
            .. " Applying is one change, and **Undo** takes back the last one (once, until you log out). Nothing"
            .. " is applied in combat.", "",
        "**On this page:** [Role templates](#role-templates) · [Looks](#looks) · [Own templates](#own-templates) ·"
            .. " [Setup wizard](#setup-wizard)", "",
        "## Role templates", "" }
    for _, t in ipairs(T.ROLES) do
        lines[#lines + 1] = "### " .. L["RAID_TEMPLATE_" .. t.id]
        lines[#lines + 1] = ""
        lines[#lines + 1] = ROLE_TEXT[t.id]
        lines[#lines + 1] = ""
        if t.id == "healer" then
            for _, class in ipairs(ns.RaidBuffData.CLASSES) do
                local hots = T.HOTS[class]
                if hots then
                    local names = {}
                    for _, hot in ipairs(hots) do
                        names[#names + 1] = ("%s (%s)"):format(spellName(hot.spell),
                            RaidSchema.SectionTitle("indicator" .. hot.indicator))
                    end
                    lines[#lines + 1] = ("- %s: %s"):format(LOCALIZED_CLASS_NAMES_MALE[class] or class,
                        table.concat(names, ", "))
                end
            end
            lines[#lines + 1] = ""
        end
        local rows = {}
        for _, key in ipairs(sortedKeys(t.values)) do
            rows[#rows + 1] = { "<b>" .. cell(settingName(key)) .. "</b>", cell(templateValue(key, t.values[key])) }
        end
        htmlTable(lines, { "Setting", "Value" }, { 300, 596 }, rows)
    end
    lines[#lines + 1] = "## Looks"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "A look sets only how the cells look; a role template never touches these, so a role and a"
        .. " look add up. **Forever** is the default look."
    lines[#lines + 1] = ""
    local heads, widths, rows = { "Setting" }, { 230 }, {}
    for _, look in ipairs(T.LOOKS) do
        heads[#heads + 1] = L["RAID_TEMPLATE_" .. look.id]
        widths[#widths + 1] = 222
    end
    for _, key in ipairs(sortedKeys(T.LOOKS[1].values)) do
        local row = { "<b>" .. cell(settingName(key)) .. "</b>" }
        for _, look in ipairs(T.LOOKS) do row[#row + 1] = cell(templateValue(key, look.values[key])) end
        rows[#rows + 1] = row
    end
    htmlTable(lines, heads, widths, rows)
    for _, l in ipairs({ "## Own templates", "",
        ("Your own templates are your own profiles, on the [[Profiles|Raid-Profiles]] tab: all three sizes or"
            .. " one under a name (at most %d letters; a name in use replaces it after a second click), for every"
            .. " character of your account, applied like the shipped ones (with **Undo**), deleted after a second"
            .. " click. Up to %d own templates."):format(T.OWN_NAME_LETTERS, T.OWN_MAX), "",
        "## Setup wizard", "",
        "The wizard opens by itself once: the first time a character whose raid settings nobody has changed opens"
            .. " the raid window, after the login loading screen is gone, out of combat and while the interface is"
            .. " shown (otherwise it waits for the next time). **Setup wizard** on the General tab opens it at any"
            .. " time (not in combat). Its steps: your role template (suggested from your specialization's role,"
            .. " else your assigned role, else your class), a look, which raid sizes, click-casting suggestions for"
            .. " the spells your spell book knows (none is ticked at first: tick the ones you want), and a summary"
            .. " that lists every binding with its click. **Apply** sets all of it as one change, which **Undo**"
            .. " takes back. Nothing is set or bound before Apply.", "",
        "Click-casting suggestions (the healer template; the dispel template puts the first dispel you know on"
            .. " the plain left click and offers the dispels):", "" }) do
        lines[#lines + 1] = l
    end
    rows = {}
    for _, class in ipairs(ns.RaidBuffData.CLASSES) do
        local data = T.CLICKS[class]
        if data then
            local parts = {}
            for _, group in ipairs({ data.heals, data.dispels }) do
                for _, entry in ipairs(group) do
                    local slot = ns.Raid.CLICK_SLOT_BY_KEY[entry[1]]
                    local buttonName
                    for _, b in ipairs(ns.Raid.CLICK_BUTTONS) do
                        if b.button == slot.button then buttonName = RaidSchema.SectionTitle("click" .. b.name) end
                    end
                    local names = {}
                    for _, id in ipairs(entry[2]) do names[#names + 1] = spellName(id) end
                    parts[#parts + 1] = ("%s, %s: %s"):format(buttonName, RaidSchema.Label(entry[1]),
                        table.concat(names, " or "))
                end
            end
            rows[#rows + 1] = { "<b>" .. cell(LOCALIZED_CLASS_NAMES_MALE[class] or class) .. "</b>",
                cell(table.concat(parts, " · ")) }
        end
    end
    htmlTable(lines, { "Class", "Suggestions" }, { 150, 746 }, rows)
    lines[#lines] = nil
    write("Raid-Templates.md", lines)
    raidPages[#raidPages + 1] = { "Raid-Templates", "Templates" }
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
