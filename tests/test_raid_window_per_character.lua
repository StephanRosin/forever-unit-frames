-- The raid window's top bar (decision 71): General | 10 | 20 | 40 |
-- Profiles. General shows the tabs whose settings all belong to the
-- character (General, Click-casting, Buffs, Tools); a size the tabs of
-- its profile (Cell .. Own panels); Profiles its page, no tabs. The tab
-- row is laid out for the tabs shown (one row when they fit). The window
-- opens on the size shown and its first tab; General and the sizes keep
-- their last tab for the session. The note on a size not shown only on a
-- size. The special panels' name lists say they are per character.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, S, L = ns.RaidOptions, ns.RaidSchema, ns.L
local TAB_H = 30

local function click(button) button:GetScript("OnClick")(button) end

local ids = {}
for _, tab in ipairs(S.TABS) do ids[#ids + 1] = tab.id end
H.check("tab order", table.concat(ids, ","),
    "general,cell,texts,debuffs,indicators,icons,layout,panels,arrangement,clickCast,buffs,tools")
H.check("special panels", S.TabTitle("panels"), "Special panels")
H.check("own panels", S.TabTitle("arrangement"), "Own panels")
H.check("German special panels", ns.Locales.deDE.RAID_TAB_panels, "Sonderfelder")
H.check("German own panels", ns.Locales.deDE.RAID_TAB_arrangement, "Eigene Felder")

local per = {}
for _, tab in ipairs(S.TABS) do if S.PerCharacter(tab) then per[#per + 1] = tab.id end end
H.check("per character", table.concat(per, ","), "general,clickCast,buffs,tools")

-- The tabs shown, in their order; the rows they take.
local function shownTabs()
    local list = {}
    for _, b in ipairs(RO.tabButtons) do if b:IsShown() then list[#list + 1] = b.tabId end end
    return table.concat(list, ",")
end
local function rowCount()
    local rows = 0
    for _, b in ipairs(RO.tabButtons) do
        if b:IsShown() and select(2, b:GetPoint(1)) == RO.frame.tabRow then rows = rows + 1 end
    end
    return rows
end

-- The top bar's entries, left to right.
RO.Open()
local order = { RO.generalTab, RO.sizeTabs[10], RO.sizeTabs[20], RO.sizeTabs[40], RO.profilesTab }
H.check("General first", select(2, RO.generalTab:GetPoint(1)), RO.frame.sizeBar)
for i = 2, #order do H.check("entry " .. i .. " beside the one before", select(2, order[i]:GetPoint(1)), order[i - 1]) end
H.check("General's word", RO.generalTab.text:GetText(), "General")
H.check("German General", ns.Locales.deDE.RAID_GENERAL_TAB, "Allgemein")
H.check("German Profiles", ns.Locales.deDE.RAID_PROFILES_TAB, "Profile")

-- Opens on the size shown and its first tab.
H.check("opens on a size", RO.view, "size")
H.check("the size shown", RO.Size(), 10)
H.check("its first tab", RO.currentTab, "cell")
H.check("the size's tabs", shownTabs(), "cell,texts,debuffs,indicators,icons,layout,panels,arrangement")
H.checkTrue("10 underlined", RO.sizeTabs[10].underline:IsShown())
H.check("General not", RO.generalTab.underline:IsShown(), false)
RO.SelectTab("layout")

-- General: the character's tabs in one row, no size underlined.
click(RO.generalTab)
H.check("General picked", RO.view, "general")
H.check("the character's tabs", shownTabs(), "general,clickCast,buffs,tools")
H.check("its first tab", RO.currentTab, "general")
H.check("one row", rowCount(), 1)
H.check("the row's height", RO.frame.tabRow:GetHeight(), TAB_H)
H.checkTrue("General underlined", RO.generalTab.underline:IsShown())
for _, size in ipairs(ns.Raid.SIZES) do
    H.check(size .. " not underlined", RO.sizeTabs[size].underline:IsShown(), false)
    H.check(size .. " not dimmed", RO.sizeTabs[size]:GetAlpha(), 1)
end
H.check("no bar note any more", RO.sizeBarNote, nil)
RO.SelectTab("buffs")

-- Each part keeps its last tab.
click(RO.sizeTabs[20])
H.check("a size: its last tab", RO.currentTab, "layout")
H.check("edits 20", RO.Size(), 20)
H.check("the size note on a size", RO.sizeNotice:IsShown(), true)
click(RO.generalTab)
H.check("General: its last tab", RO.currentTab, "buffs")
H.check("no size note on General", RO.sizeNotice:IsShown(), false)
H.check("the page under the tabs", select(2, RO.frame.scroll:GetPoint(1)), RO.frame.tabRow)
-- A tab of the other part switches the top bar too.
RO.SelectTab("cell")
H.check("a size's tab: the size picked", RO.view, "size")
H.checkTrue("20 underlined", RO.sizeTabs[20].underline:IsShown())
RO.SelectTab("tools")
H.check("a character's tab: General", RO.view, "general")

-- Profiles: its page, no tabs; back to the part's last tab.
click(RO.profilesTab)
H.check("profiles", RO.view, "profiles")
H.check("no tabs", RO.frame.tabRow:IsShown(), false)
H.check("no size note", RO.sizeNotice:IsShown(), false)
H.check("General not underlined", RO.generalTab.underline:IsShown(), false)
click(RO.generalTab)
H.check("General again", RO.currentTab, "tools")
H.checkTrue("tabs back", RO.frame.tabRow:IsShown())

-- Reopened in the session: the top choice and its tab; a size given:
-- that size.
RO.Close()
RO.Open()
H.check("reopened on General", RO.currentTab, "tools")
RO.Close()
RO.Open(40)
H.check("a size given: the size", RO.view, "size")
H.check("a size given: its last tab", RO.currentTab, "cell")
RO.Close()

-- The name lists of the special panels say they are per character.
RO.Open(10, "panels")
local names
for _, row in ipairs(RO.rows) do if row.key and ns.RaidSettings.Get(row.key).names then names = row end end
H.checkTrue("a name list", names ~= nil)
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    H.checkTrue(code .. ": per character", ns.Locales[code].RAID_HINT_nameList:find(({
        enUS = "Per character", deDE = "Pro Charakter", esES = "Por personaje", frFR = "Par personnage" })[code], 1, true) == 1)
end
H.checkTrue("the row's hint", names.hintText:GetText():find("Per character", 1, true) == 1)
RO.Close()

-- The top bar fits at 880 in every language, whichever size is shown
-- (its entry says so); General's tabs in one row.
local sizeOf = ns.RaidCell.Size
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    ns.Config.Set("general", "language", code)
    RO.Open(10, "general")
    H.check(code .. ": General in one row", rowCount(), 1)
    for _, shown in ipairs({ 10, 20, 40 }) do
        ns.RaidCell.Size = function() return shown end
        ns.Fire("RAID_SIZE_CHANGED")
        local used = RO.SIZE_BAR_LEFT + RO.generalTab:GetWidth() + RO.profilesTab:GetWidth()
        for _, size in ipairs(ns.Raid.SIZES) do used = used + RO.sizeTabs[size]:GetWidth() end
        local right = RO.SIZE_BAR_RIGHT + RO.sizeModeRow:GetWidth() + RO.SIZE_BAR_GAP
            + RO.sizeModeLabel:GetStringWidth() + RO.SIZE_BAR_GAP
        H.checkTrue(code .. ": the top bar fits, " .. shown .. " shown", used + right <= 880)
        for _, b in ipairs({ RO.generalTab, RO.sizeTabs[10], RO.sizeTabs[20], RO.sizeTabs[40], RO.profilesTab }) do
            H.checkTrue(code .. ": word fits its entry", b.text:GetStringWidth() < b:GetWidth())
        end
    end
    ns.RaidCell.Size = sizeOf
    RO.Close()
end
ns.Config.Set("general", "language", "AUTO")
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    H.check(code .. ": no 'same at every size' any more", ns.Locales[code].RAID_SIZE_ALL_SAME, nil)
end
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
