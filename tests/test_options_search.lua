-- The search in the options windows' title bars (Options/Search.lua): typing
-- lists the settings that match, a click opens the page with the row in
-- view and lit up.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.RaidProfiles.Attach({})
local Search, Options, Raid, L = ns.OptionsSearch, ns.Options, ns.RaidOptions, ns.L

-- Matching.
local ENTRIES = {
    { title = "Bar height", path = "Party > Layout", key = "a" },
    { title = "Width", path = "Party > Bar", hint = "How wide", key = "b" },
    { title = "Opacity", path = "Player > Status", hint = "0 = invisible", key = "c" },
}
local function keys(list)
    local out = {}
    for i, e in ipairs(list) do out[i] = e.key end
    return table.concat(out, ",")
end
H.check("nothing typed: nothing", keys(Search.Match(ENTRIES, "  ")), "")
H.check("in the title first, then the path", keys(Search.Match(ENTRIES, "BAR")), "a,b")
H.check("the hint counts", keys(Search.Match(ENTRIES, "invisible")), "c")
H.check("every word must be there", keys(Search.Match(ENTRIES, "party width")), "b")
H.check("no pattern: a sign is a sign", keys(Search.Match(ENTRIES, "0 =")), "c")
H.check("no match", keys(Search.Match(ENTRIES, "zzz")), "")

local function shownRows(box)
    local n = 0
    for _, row in ipairs(box.list.rows) do
        if row:IsShown() then n = n + 1 end
    end
    return n
end

-- The unit frames' window, on Party.
Options.Open("party", "layout")
local box = Options.searchBox
H.checkTrue("the box", box)
H.check("no text: no list", box.list:IsShown(), false)
box:SetText(L.SETTING_castbarHeight)
H.check("typing: the list", box.list:IsShown(), true)
local first = box.list.rows[1]
H.check("the setting is found", first.entry.key, "castbarHeight")
H.check("party offers it: on its own page", first.entry.scope, "party")
H.checkTrue("the path names the frame", first.path:GetText():find(L.FRAME_party, 1, true))

first:GetScript("OnClick")(first)
H.check("the click: the list closes", box.list:IsShown(), false)
H.check("the page", Options.currentScope, "party")
H.check("the tab", Options.currentTab, "castbar")
local lit
for _, row in ipairs(Options.page.rows) do
    if row.key == "castbarHeight" then lit = row end
end
H.checkTrue("the row is lit up", lit and lit.searchFlash and lit.searchFlash:IsShown())
M.Tick(2)
M.RunTimers()
H.check("for a moment", lit.searchFlash:IsShown(), false)

-- A setting another frame holds: found from Party too, under that frame.
box:SetText(L.SETTING_playerFadeOOC)
H.check("the player's setting", box.list.rows[1].entry.scope, "player")
box:GetScript("OnEnterPressed")(box)
H.check("Enter takes the first", Options.currentScope, "player")
H.check("its tab", Options.currentTab, "layout")

-- One entry per shared setting: the current frame's, not one per frame.
Options.Select("party")
box:SetText(L.SETTING_castbarHeight)
H.check("shared: the current frame's", box.list.rows[1].entry.scope, "party")
local same = 0
for _, row in ipairs(box.list.rows) do
    if row:IsShown() and row.entry.key == "castbarHeight" then same = same + 1 end
end
H.check("shared: once", same, 1)

-- Too many: the first ten and how many more.
box:SetText("a")
H.check("at most ten rows", shownRows(box), Search.MAX_RESULTS)
H.checkTrue("says how many more", box.list.note:GetText():find("%d"))
box:SetText("zzzzqqq")
H.check("no hit: no rows", shownRows(box), 0)
H.check("says so", box.list.note:GetText(), L.SEARCH_NONE)
box:GetScript("OnEnterPressed")(box)
H.check("Enter on nothing: stays", Options.currentScope, "party")

-- Escape empties it; a click elsewhere closes the list and keeps the text.
box:GetScript("OnEscapePressed")(box)
H.check("Escape: empty", box:GetText(), "")
H.check("Escape: no list", box.list:IsShown(), false)
box:SetText("a")
box.list:GetScript("OnEvent")(box.list, "GLOBAL_MOUSE_DOWN")
H.check("outside click: closed", box.list:IsShown(), false)
H.check("the text stays", box:GetText(), "a")
box:GetScript("OnEditFocusGained")(box)
H.check("back in the box: open again", box.list:IsShown(), true)

Options.Close()
H.check("closing empties it", box:GetText(), "")

-- The raid window.
Raid.Open(10, "buffs")
local rbox = Raid.searchBox
H.checkTrue("raid: the box", rbox)
rbox:SetText(L.RAID_SETTING_buffSolo)
local hit = rbox.list.rows[1]
H.check("raid: the setting", hit.entry.key, "buffSolo")
H.checkTrue("raid: a general one says so", hit.path:GetText():find(L.RAID_GENERAL_TAB, 1, true))
hit:GetScript("OnClick")(hit)
H.check("raid: the tab", Raid.currentTab, "buffs")
H.check("raid: size kept", Raid.Size(), 10)
local rlit
for _, row in ipairs(Raid.page.rows) do
    if row.key == "buffSolo" then rlit = row end
end
H.checkTrue("raid: the row is lit up", rlit and rlit.searchFlash and rlit.searchFlash:IsShown())

-- A size's setting names the size edited, and opening it keeps that size.
Raid.SelectSize(20)
rbox:SetText(ns.RaidSchema.Label("cellHeight"))
hit = rbox.list.rows[1]
H.check("raid: a size's setting", hit.entry.key, "cellHeight")
hit:GetScript("OnClick")(hit)
H.check("raid: still that size", Raid.Size(), 20)

-- Profiles by name: the page without a menu.
rbox:SetText(L.RAID_PROFILES_TAB)
local found
for _, row in ipairs(rbox.list.rows) do
    if row:IsShown() and row.entry.tab == "profiles" then found = row end
end
H.checkTrue("raid: Profiles is found", found)
found:GetScript("OnClick")(found)
H.check("raid: its page", Raid.view, "profiles")
Raid.Close()
H.check("raid: closing empties it", rbox:GetText(), "")
