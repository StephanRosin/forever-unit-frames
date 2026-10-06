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
for _, page in ipairs(WIKI_PAGES or {}) do
    if page[1]:match("^Raid%-") then raid[#raid + 1] = page[1] end
end
H.check("raid pages", table.concat(raid, ","),
    "Raid-General,Raid-Layout,Raid-Panels,Raid-Cell,Raid-Texts,Raid-Debuffs,Raid-Indicators,Raid-Icons-and-states,Raid-Tools")

-- Every setting on its tab's page, by its label. The Profile tab (export
-- and import, no settings) has no page.
local ns = H.LoadShipped()
local Schema, RS = ns.RaidSchema, ns.RaidSettings
local settingTabs = {}
for _, tab in ipairs(Schema.TABS) do
    if not tab.custom then settingTabs[#settingTabs + 1] = tab end
end
H.check("custom tabs: the Profile tab", #Schema.TABS - #settingTabs, 1)
H.check("one page per settings tab", #raid, #settingTabs)
for i, tab in ipairs(settingTabs) do
    local text = read(raid[i] .. ".md")
    H.checkTrue(tab.id .. ": title", text:find("# Raid frames: " .. Schema.TabTitle(tab.id), 1, true))
    for _, sec in ipairs(tab.sections) do
        H.checkTrue(tab.id .. ": section " .. sec.id, text:find("## " .. Schema.SectionTitle(sec.id), 1, true))
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
H.checkTrue("raid words for choices", read("Raid-Texts.md"):find("Missing health", 1, true))
H.checkTrue("the cell's own fonts", read("Raid-Texts.md"):find("<b>Second line size</b>", 1, true))
H.checkTrue("the dispel square", read("Raid-Debuffs.md"):find("Icon in the center, Square in a corner", 1, true))
H.checkTrue("the raid minimap button", general:find("<b>Show the button</b>", 1, true))

local sidebar = read("_Sidebar.md")
H.checkTrue("sidebar: raid heading", sidebar:find("**Raid frames**", 1, true))
H.checkTrue("sidebar: raid page", sidebar:find("[[Icons & states|Raid-Icons-and-states]]", 1, true))
H.checkTrue("sidebar: settings kept", sidebar:find("[[General|Settings-General]]", 1, true))
os.execute("rm -rf '" .. dir .. "'")
