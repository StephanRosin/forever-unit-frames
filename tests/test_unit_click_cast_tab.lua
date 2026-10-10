-- The unit frames' options window has the click-casting editor on a
-- General tab of its own (Options/Window.lua, built by Raid/Options/
-- ClickCast.lua): the same rows as the raid window's tab, bound to the
-- same values (the raid profile's character scope), so a change in one
-- window shows in the other. It works with the raid frames off and locks
-- in combat.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
for _, id in ipairs({ 139, 6074, 2061 }) do M.known[id] = true end
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Options, RO, RC, L = ns.Options, ns.RaidOptions, ns.RaidConfig, ns.L

local function click(button) button:GetScript("OnClick")(button) end
local function rowIn(rows, key)
    for _, row in ipairs(rows or {}) do if row.key == key then return row end end
end
local function pick(button, text)
    click(button)
    for _, r in ipairs(ns.Widgets.list.rows) do
        if r:IsShown() and r.item and r.item.text == text then
            click(r)
            return true
        end
    end
    ns.Widgets.CloseList()
    return false
end

-- The tab: after Frames, on General only.
local ids = {}
for i, tab in ipairs(ns.Schema.Tabs("general")) do ids[i] = tab.id end
H.check("General's tabs", table.concat(ids, ","), "frames,clickCast,appearance,bars,status,profile")
local frameTabs = {}
for _, tab in ipairs(ns.Schema.Tabs("player")) do frameTabs[#frameTabs + 1] = tab.id end
H.checkTrue("not on a frame's page", not table.concat(frameTabs, ","):find("clickCast", 1, true))
H.check("its title", L.TAB_clickCast, L.RAID_TAB_clickCast)

-- The raid frames off: the editor is there all the same.
RC.Set("general", "enabled", false)
Options.Open("general", "clickCast")
H.check("on the tab", Options.currentTab, "clickCast")
local rows = Options.rows
H.checkTrue("the mode row", rowIn(rows, "clickCast"))
H.checkTrue("a mouse slot", rowIn(rows, "click1Shift"))
H.checkTrue("a key", rowIn(rows, "clickKey16"))
H.checkTrue("copy and clear", Options.page.clickCopyRow and Options.page.clickClearButton)
local n = 0
for _, slot in ipairs(ns.Raid.CLICK_SLOTS) do if rowIn(rows, slot.key) then n = n + 1 end end
H.check("every mouse slot", n, 40)
H.check("the note", Options.page.note:GetText(), L.RAID_NOTE_clickCast)
-- Everything within the window's width.
local shift = rowIn(rows, "click1Shift")
pick(shift.button, L.RAID_CLICK_spell)
H.check("a spell: the dropdowns", shift.spellDrop:IsShown() and shift.rankDrop:IsShown(), true)
H.checkTrue("fits the page", shift.button:GetWidth() + shift.spellDrop:GetWidth() + shift.rankDrop:GetWidth() + 16
    + select(4, shift.button:GetPoint(1)) <= Options.page:GetWidth())
local key1 = rowIn(rows, "clickKey1")
pick(key1.button, L.RAID_CLICK_spell)
H.checkTrue("a key's spell dropdown has room", key1.spellDrop:GetWidth() >= 100)
H.checkTrue("labels stop before the controls", key1.hintText:GetWidth() < select(4, key1.keyBox:GetPoint(1)))
pick(shift.spellDrop, "Renew")
pick(shift.rankDrop, "Rank 1")
H.check("stored: the same values", RC.Get("general", "click1Shift"), "spell:139")
H.check("raid frames still off", RC.Get("general", "enabled"), false)

-- The raid window shows it, and a change there shows here at once.
RO.Open(nil, "clickCast")
local raidShift = rowIn(RO.rows, "click1Shift")
H.check("raid window: the same spell", raidShift.spellDrop.text:GetText(), "Renew")
H.check("raid window: the same rank", raidShift.rankDrop.text:GetText(), "Rank 1")
pick(raidShift.rankDrop, "Rank 2")
H.check("unit window follows", shift.rankDrop.text:GetText(), "Rank 2")
pick(raidShift.spellDrop, "Flash Heal")
H.check("unit window: the spell", shift.spellDrop.text:GetText(), "Flash Heal")
-- And a change here shows there.
pick(shift.spellDrop, "Renew")
H.check("raid window follows", raidShift.spellDrop.text:GetText(), "Renew")
RO.Close()

-- The mode row is never greyed by the unit frames' rule for their own
-- clickCast switch (that would keep it off for good).
local mode = rowIn(rows, "clickCast")
pick(mode.button, ns.RaidSchema.EnumText(ns.RaidSettings.Get("clickCast"), "OFF"))
H.check("mode off", RC.Get("general", "clickCast"), "OFF")
H.check("mode row usable while off", mode.enabledState, true)
pick(mode.button, ns.RaidSchema.EnumText(ns.RaidSettings.Get("clickCast"), "AUTO"))
H.check("mode back", RC.Get("general", "clickCast"), "AUTO")

-- A spell learned while the tab shows: offered at once.
M.spells[10927] = { name = "Renew", maxRange = 40, subName = "Rank 3", rank = 3 }
M.known[10927] = true
M.FireEvent("SPELLS_CHANGED")
click(shift.rankDrop)
local texts = {}
for _, r in ipairs(ns.Widgets.list.rows) do if r:IsShown() and r.item then texts[#texts + 1] = r.item.text end end
ns.Widgets.CloseList()
H.check("the new rank here too", table.concat(texts, ","), "Max,Rank 1,Rank 2,Rank 3")

-- Combat: locked like every row.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("kind locked", shift.button:IsEnabled(), false)
H.check("spell locked", shift.spellDrop:IsEnabled(), false)
H.check("key box locked", key1.keyBox:IsEnabled(), false)
H.check("clear locked", Options.page.clickClearButton:IsEnabled(), false)
M.SetCombat(false)
H.check("unlocked", shift.spellDrop:IsEnabled(), true)

-- Clear all here: two clicks, the raid window's values too.
click(Options.page.clickClearButton)
click(Options.page.clickClearButton)
H.check("cleared", RC.Get("general", "click1Shift"), "")
H.check("the row follows", shift.button.text:GetText(), L.RAID_CLICK_LIKE_PLAIN)
H.check("nothing blocked", #M.blocked, 0)
Options.Close()
