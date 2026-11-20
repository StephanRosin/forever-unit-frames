-- The key button (Options/Widgets.lua): a click, then the key pressed, is
-- the binding; the smart buff key's row and the click-casting keys' use it.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.RaidProfiles.Attach({})
local RO, RC, L = ns.RaidOptions, ns.RaidConfig, ns.L

local function rowFor(key)
    for _, row in ipairs(RO.rows) do
        if row.key == key then return row end
    end
end

RO.Open(10, "buffs")
local b = rowFor("buffKey").keyBox
H.checkTrue("the smart buff key is a key button", b and b.Commit)
H.check("none: says so", b.text:GetText(), L.KEY_BUTTON_NONE)
H.check("no keyboard while idle", b._keyboard or false, false)
H.check("the wheel still scrolls the page", b._mouseWheel or false, false)

local function click(mouse) b:GetScript("OnClick")(b, mouse or "LeftButton") end

-- Waiting: the prompt, the keyboard. A modifier alone keeps it waiting.
click()
H.check("waits", b.IsWaiting(), true)
H.check("the prompt", b.text:GetText(), L.KEY_BUTTON_PROMPT)
H.check("takes the keyboard", b._keyboard, true)
M.shiftDown = true
M.PressKey(b, "LSHIFT")
H.check("a modifier alone: still waiting", b.IsWaiting(), true)
M.PressKey(b, "B")
M.shiftDown = false
H.check("Shift and B stored", RC.Get("general", "buffKey"), "SHIFT-B")
H.check("shows it", b.text:GetText(), "SHIFT-B")
H.check("done waiting", b.IsWaiting(), false)
H.check("the keyboard goes back", b._keyboard, false)

-- The client's order of modifiers.
click()
M.shiftDown, M.ctrlDown, M.altDown = true, true, true
M.PressKey(b, "F5")
M.shiftDown, M.ctrlDown, M.altDown = false, false, false
H.check("all modifiers in order", RC.Get("general", "buffKey"), "ALT-CTRL-SHIFT-F5")

-- Escape and another click leave it as it was.
click()
M.PressKey(b, "ESCAPE")
H.check("Escape: unchanged", RC.Get("general", "buffKey"), "ALT-CTRL-SHIFT-F5")
H.check("Escape: shows it again", b.text:GetText(), "ALT-CTRL-SHIFT-F5")
click()
click()
H.check("a second click: no longer waiting", b.IsWaiting(), false)
click()
b:GetScript("OnEvent")(b, "GLOBAL_MOUSE_DOWN")
H.check("a click elsewhere ends it", b.IsWaiting(), false)

-- Mouse buttons and the wheel.
click()
b:GetScript("OnMouseDown")(b, "Button4")
H.check("mouse button 4", RC.Get("general", "buffKey"), "BUTTON4")
click()
M.ctrlDown = true
b:GetScript("OnMouseWheel")(b, 1)
M.ctrlDown = false
H.check("the wheel", RC.Get("general", "buffKey"), "CTRL-MOUSEWHEELUP")
b:GetScript("OnMouseDown")(b, "Button4")
H.check("a mouse button while idle: nothing", RC.Get("general", "buffKey"), "CTRL-MOUSEWHEELUP")

-- A right click clears, and is no way in while waiting.
click("RightButton")
H.check("right click clears", RC.Get("general", "buffKey"), "")
H.check("not waiting after it", b.IsWaiting(), false)
click()
click("RightButton")
H.check("while waiting it only ends", b.IsWaiting(), false)

-- Hiding the page ends it.
click()
b:GetScript("OnHide")(b)
H.check("hidden: no longer waiting", b.IsWaiting(), false)
RO.SelectTab("clickCast")

-- A click-casting key: taken twice is refused, the border says so.
local key1, key2 = rowFor("clickKey1").keyBox, rowFor("clickKey2").keyBox
-- Only the button waiting takes keys (Email 21.11.2026: Key 4 waited, Z
-- landed on Key 9, which held the keyboard since its key script was set).
H.check("idle: no keyboard", rowFor("clickKey9").keyBox._keyboard and true or false, false)
H.check("idle: no wheel (the page scrolls)", rowFor("clickKey9").keyBox._mouseWheel and true or false, false)
key2:GetScript("OnClick")(key2, "LeftButton")
M.PressKey(rowFor("clickKey9").keyBox, "Z")
H.check("a key pressed meanwhile: not on another button", RC.Get("general", "clickKey9"), "")
M.PressKey(key2, "Z")
H.check("the waiting one takes it", RC.Get("general", "clickKey2"), "Z")
H.check("done: no keyboard", key2._keyboard and true or false, false)
key2:GetScript("OnClick")(key2, "RightButton")
key1:GetScript("OnClick")(key1, "LeftButton")
M.PressKey(key1, "G")
H.check("click key stored", RC.Get("general", "clickKey1"), "G")
key2:GetScript("OnClick")(key2, "LeftButton")
M.PressKey(key2, "G")
H.check("the same key refused", RC.Get("general", "clickKey2"), "")
H.check("the button shows its own again", key2.text:GetText(), L.KEY_BUTTON_NONE)
H.check("refused: not waiting", key2.IsWaiting(), false)

-- Combat: locked, and a wait ends before lockdown.
key1:GetScript("OnClick")(key1, "LeftButton")
H.check("waiting before combat", key1.IsWaiting(), true)
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat ends the wait", key1.IsWaiting(), false)
H.check("combat: no keyboard", key1._keyboard, false)
H.check("combat: locked", key1:IsEnabled(), false)
M.combat = false
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("no error", #M.errors, 0)

-- The party's page has the same settings, the same values.
RC.Set("general", "buffKey", "")
local Options = ns.Options
RO.Close()
Options.Open("party", "group")
local function partyRow(key)
    for _, row in ipairs(Options.rows) do
        if row.key == key then return row end
    end
end
local pb = partyRow("buffKey").keyBox
H.checkTrue("party: the key button", pb and pb.Commit)
H.checkTrue("party: solo", partyRow("buffSolo"))
H.checkTrue("party: the window's switch", partyRow("buffWatchShow"))
pb:GetScript("OnClick")(pb, "LeftButton")
M.PressKey(pb, "J")
H.check("party: stored in the raid settings", RC.Get("general", "buffKey"), "J")
RC.Set("general", "buffKey", "K")
H.check("party: follows a change from elsewhere", pb.text:GetText(), "K")
-- A setting of the other window's is found by the search here too.
Options.searchBox:SetText(L.RAID_SETTING_buffSolo)
H.check("party: the search finds it", Options.searchBox.list.rows[1].entry.key, "buffSolo")
Options.searchBox:SetText("")
-- The raid frames off: they do nothing, so they grey.
RC.Set("general", "enabled", false)
H.check("raid frames off: locked", partyRow("buffKey").enabledState, false)
RC.Set("general", "enabled", true)
H.check("raid frames on: open", partyRow("buffKey").enabledState, true)
H.check("no error at the end", #M.errors, 0)
