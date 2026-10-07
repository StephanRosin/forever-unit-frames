-- The wiki's raid pages (tools/make_wiki.lua): one per tab of the raid
-- options window that holds settings, every raid setting on the page of its tab, the size
-- switch with the General tab, defaults per size, listed in the sidebar.
local dir = os.tmpname()
os.remove(dir)
os.execute("mkdir -p '" .. dir .. "'")
_G.WIKI_OUT = dir
local ok, err = pcall(dofile, ADDONDIR .. "/tools/make_wiki.lua")
_G.WIKI_OUT = nil
H.checkTrue("generator runs", ok, err)
local function read(name)
    local fh = io.open(dir .. "/" .. name)
    if not fh then return "" end
    local text = fh:read("*a")
    fh:close()
    return text
end

local raid = {}
H.checkTrue("the generator lists its pages", type(WIKI_PAGES) == "table" and #WIKI_PAGES > 0)
for _, page in ipairs(WIKI_PAGES or {}) do
    if page[1]:match("^Raid%-") then raid[#raid + 1] = page[1] end
end
H.check("raid pages", table.concat(raid, ","),
    "Raid-General,Raid-Layout,Raid-Panels,Raid-Arrangement,Raid-Cell,Raid-Texts,Raid-Debuffs,Raid-Indicators,"
        .. "Raid-Icons-and-states,Raid-Tools,Raid-Click-casting,Raid-Buffs")

-- Every setting on its tab's page, by its label. The Profile tab (export
-- and import, no settings) has no page; the own panels' sections are all
-- alike: one table for every panel.
local ns = H.LoadShipped()
local Schema, RS = ns.RaidSchema, ns.RaidSettings
local settingTabs = {}
for _, tab in ipairs(Schema.TABS) do
    if #tab.sections > 0 then settingTabs[#settingTabs + 1] = tab end
end
H.check("tabs without settings: the Profile tab", #Schema.TABS - #settingTabs, 1)
H.check("one page per settings tab", #raid, #settingTabs)
for i, tab in ipairs(settingTabs) do
    local text = read(raid[i] .. ".md")
    H.checkTrue(tab.id .. ": title", text:find("# Raid frames: " .. Schema.TabTitle(tab.id), 1, true))
    local sections = tab.alike and { tab.sections[1] } or tab.sections
    for _, sec in ipairs(sections) do
        local title = tab.alike and "Each own panel" or Schema.SectionTitle(sec.id)
        H.checkTrue(tab.id .. ": section " .. sec.id, text:find("## " .. title, 1, true))
        for _, key in ipairs(sec.keys) do
            H.checkTrue(tab.id .. ": " .. key, text:find("<b>" .. Schema.Label(key) .. "</b>", 1, true))
        end
    end
end
local general = read("Raid-General.md")
H.checkTrue("size switch on General", general:find("<b>Raid size shown</b>", 1, true))
H.checkTrue("its choices", general:find("Automatic, 10 players, 20 players, 40 players", 1, true))
H.checkTrue("defaults per size", read("Raid-Cell.md"):find("10 players: 96; 20 players: 88; 40 players: 80", 1, true))
H.checkTrue("the cell's note", read("Raid-Cell.md"):find(ns.L.RAID_NOTE_cell, 1, true))
H.checkTrue("own panels: one table", select(2, read("Raid-Arrangement.md"):gsub("\n## ", "")) == 1)
H.checkTrue("raid words for choices", read("Raid-Texts.md"):find("Missing health", 1, true))
H.checkTrue("the cell's own fonts", read("Raid-Texts.md"):find("<b>Second line size</b>", 1, true))
H.checkTrue("the dispel square", read("Raid-Debuffs.md"):find("Icon in the center, Square in a corner", 1, true))
H.checkTrue("the raid minimap button", general:find("<b>Show the button</b>", 1, true))
-- The click-casting page is per character: no size tabs, no "per raid
-- size"; it names Copy from and Clear all, that a key's own macro runs as
-- written, and that Blizzard's click bindings win.
local click = read("Raid-Click-casting.md")
H.check("click-casting: no size tabs", click:find("size tabs", 1, true), nil)
H.check("click-casting: not per raid size", click:find("per raid size", 1, true), nil)
H.checkTrue("click-casting: per character", click:find("belong to the character", 1, true))
H.checkTrue("click-casting: Copy from", click:find("**Copy from**", 1, true))
H.checkTrue("click-casting: Clear all", click:find("**Clear all**", 1, true))
H.checkTrue("click-casting: a macro as written", click:find("runs it as written", 1, true))
H.checkTrue("click-casting: Blizzard's bindings", click:find("Blizzard's own click bindings", 1, true))
H.checkTrue("click-casting: party frames for keys", click:find("party frames) show", 1, true))

-- The buff watch page: per character, out of combat only, the group form
-- and its reagent, the blessings by class, the smart buff key apart from
-- the click-casting keys, unknown while secret, each blessing row by its
-- class.
local buffs = read("Raid-Buffs.md")
H.checkTrue("buffs: per character", buffs:find("belong to the character", 1, true))
H.checkTrue("buffs: out of combat", buffs:find("out of combat only", 1, true))
H.checkTrue("buffs: reagent", buffs:find("its reagent is in your bags", 1, true))
H.checkTrue("buffs: greater blessings", buffs:find("Symbol of Kings", 1, true))
H.checkTrue("buffs: the key", buffs:find("**smart buff key**", 1, true))
H.checkTrue("buffs: not a click key", buffs:find("not one of the click-casting keys", 1, true))
H.checkTrue("buffs: not offered", buffs:find("greyed", 1, true))
H.checkTrue("buffs: unknown", buffs:find("unknown", 1, true))
H.checkTrue("buffs: the cell icon", buffs:find("icon on a cell", 1, true))
H.checkTrue("buffs: each class its row", buffs:find("<b>Warlock</b>", 1, true))

local sidebar = read("_Sidebar.md")
H.checkTrue("sidebar: raid heading", sidebar:find("**Raid frames**", 1, true))
H.checkTrue("sidebar: raid page", sidebar:find("[[Icons & states|Raid-Icons-and-states]]", 1, true))
H.checkTrue("sidebar: settings kept", sidebar:find("[[General|Settings-General]]", 1, true))
os.execute("rm -rf '" .. dir .. "'")
