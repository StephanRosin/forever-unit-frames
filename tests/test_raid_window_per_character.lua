-- The raid window's tabs (decision 67): General, Cell, Text, Debuffs,
-- Indicators, Icons & states, Layout, Special panels, Own panels, then
-- the character's own Click-casting, Buffs, Tools. A tab whose settings
-- all belong to the character (the same at every size) dims the size
-- tabs and says so in the size bar; the note on a size not shown has
-- nothing to say there.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, S, L = ns.RaidOptions, ns.RaidSchema, ns.L

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

local function dimmed()
    for _, size in ipairs(ns.Raid.SIZES) do
        if RO.sizeTabs[size]:GetAlpha() >= 1 then return false end
    end
    return true
end
RO.Open(10, "cell")
H.check("a size's tab: sizes not dimmed", dimmed(), false)
H.check("a size's tab: no note", RO.sizeBarNote:IsShown(), false)
for _, id in ipairs({ "clickCast", "buffs", "tools", "general" }) do
    RO.SelectTab(id)
    H.check(id .. ": sizes dimmed", dimmed(), true)
    H.check(id .. ": the note", RO.sizeBarNote:IsShown() and RO.sizeBarNote:GetText(), L.RAID_SIZE_ALL_SAME)
end
-- Editing a size not shown: its note stays away on a character's tab and
-- comes back on a size's tab.
RO.SelectSize(20)
H.check("character's tab: no size note", RO.sizeNotice:IsShown(), false)
H.check("character's tab: the page under the tabs", select(2, RO.frame.scroll:GetPoint(1)), RO.frame.tabRow)
RO.SelectTab("cell")
H.check("size's tab: the size note", RO.sizeNotice:IsShown(), true)
H.check("size's tab: undimmed", dimmed(), false)
H.check("size's tab: no bar note", RO.sizeBarNote:IsShown(), false)
RO.SelectTab("buffs")
RO.ShowProfiles()
H.check("profiles: undimmed", dimmed(), false)
H.check("profiles: no bar note", RO.sizeBarNote:IsShown(), false)
RO.Close()

-- The note fits between the Profiles tab and the size mode's label in
-- every language, whichever size is shown (its tab says so).
local sizeOf = ns.RaidCell.Size
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    ns.Config.Set("general", "language", code)
    RO.Open(10, "clickCast")
    for _, shown in ipairs({ 10, 20, 40 }) do
        ns.RaidCell.Size = function() return shown end
        ns.Fire("RAID_SIZE_CHANGED")
        local used = RO.SIZE_BAR_LEFT
        for _, size in ipairs(ns.Raid.SIZES) do used = used + RO.sizeTabs[size]:GetWidth() end
        used = used + RO.profilesTab:GetWidth() + RO.SIZE_BAR_GAP + RO.sizeBarNote:GetStringWidth()
        local right = RO.SIZE_BAR_RIGHT + RO.sizeModeRow:GetWidth() + RO.SIZE_BAR_GAP
            + RO.sizeModeLabel:GetStringWidth() + RO.SIZE_BAR_GAP
        H.checkTrue(code .. ": the note fits, " .. shown .. " shown", used + right <= RO.frame:GetWidth())
    end
    ns.RaidCell.Size = sizeOf
    RO.Close()
end
ns.Config.Set("general", "language", "AUTO")
H.check("no error", #M.errors, 0)
