-- The raid window's Click-casting tab (Raid/Options/ClickCast.lua): the
-- switches, a row per mouse slot (what it does, its spell, item or macro),
-- the sixteen keys with a warning for a key bound otherwise, Clear all,
-- copy from another character, locked in combat.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
-- Another character with bindings of its own.
ForeverUnitFramesDB = { raid = { ["Alt-Realm"] = { general = { click3 = "assist", clickKey1 = "Q",
    clickKey1Bind = "item:1251", click4 = "spell:Smite", click5 = "spell:flash heal", clickKey2 = "E",
    clickKey2Bind = "spell:Mind Blast" } } } }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
-- A raid, so there are cells to take the bindings.
M.SetRaidRoster({ { name = "A", class = "PRIEST", subgroup = 1, unit = { health = 1, healthMax = 1 } } })
M.RunTimers()
local RO, RC, L = ns.RaidOptions, ns.RaidConfig, ns.L
M.known[2061] = true

local function click(button) button:GetScript("OnClick")(button) end
local function rowFor(key)
    for _, row in ipairs(RO.rows) do if row.key == key then return row end end
end
local function pick(row, value)
    click(row.button)
    for _, r in ipairs(ns.Widgets.list.rows) do
        if r.item and r.item.value == value and r:IsShown() then
            click(r)
            return true
        end
    end
    return false
end
local function enter(box, text)
    M.Type(box, text)
    M.PressEnter(box)
end

RO.Open(nil, "clickCast")
H.check("the tab", RO.currentTab, "clickCast")
H.check("its note", RO.page.note:GetText(), L.RAID_NOTE_clickCast)
H.checkTrue("mode row", rowFor("clickCast"))
H.check("no party row (the unit frames' clickCast, decision 76)", rowFor("clickCastParty"), nil)
local plain, shift = rowFor("click1"), rowFor("click1Shift")
H.check("left: target", plain.button.text:GetText(), "Target")
H.check("left: no value to type", plain.value:IsEnabled(), false)
H.check("shift-left: like the plain click", shift.button.text:GetText(), "Like the plain click")
H.check("a row per slot", (function()
    local n = 0
    for _, slot in ipairs(ns.Raid.CLICK_SLOTS) do if rowFor(slot.key) then n = n + 1 end end
    return n
end)(), 40)

-- A spell on shift-left: the kind, then its name (typed as an ID).
H.checkTrue("pick a spell", pick(shift, "spell"))
H.check("stored without a name yet", RC.Get("general", "click1Shift"), "spell:")
H.check("now typed", shift.value:IsEnabled(), true)
enter(shift.value, "2061")
H.check("the ID became the name", RC.Get("general", "click1Shift"), "spell:Flash Heal")
H.check("the box shows it", shift.value:GetText(), "Flash Heal")
H.check("the cells' attributes", ns.RaidCell.buttons[1]:GetAttribute("shift-spell1"), "Flash Heal")
enter(shift.value, "Smite")
H.check("an unknown spell refused", RC.Get("general", "click1Shift"), "spell:Flash Heal")
H.checkTrue("said why", M.chat[#M.chat]:find("Not a spell in your spell book: Smite", 1, true))
H.check("the box back", shift.value:GetText(), "Flash Heal")
-- Another kind starts empty.
pick(shift, "macro")
H.check("a macro", RC.Get("general", "click1Shift"), "macro:")
enter(shift.value, "/cast [@mouseover] Flash Heal")
H.check("macro stored", RC.Get("general", "click1Shift"), "macro:/cast [@mouseover] Flash Heal")
pick(shift, "focus")
H.check("focus: no value", RC.Get("general", "click1Shift"), "focus")
H.check("box empty and locked", shift.value:GetText() .. tostring(shift.value:IsEnabled()), "false")
-- The menu only on the plain left and right clicks (Blizzard's click
-- bindings stop it elsewhere).
H.check("shift-left: no menu to pick", pick(shift, "menu"), false)
H.check("still focus", RC.Get("general", "click1Shift"), "focus")
H.check("plain left: the menu offered", pick(plain, "menu"), true)
H.check("left: menu", RC.Get("general", "click1"), "menu")
pick(plain, "target")

-- Keys: the key, what it casts, a warning for a key bound otherwise.
local key1 = rowFor("clickKey1")
H.checkTrue("key row", key1)
H.check("key row label", key1.label:GetText(), "Key 1")
H.check("16 key rows", (function()
    local n = 0
    for _, slot in ipairs(ns.Raid.CLICK_KEYS) do if rowFor(slot.key) then n = n + 1 end end
    return n
end)(), 16)
enter(key1.keyBox, "shift-ctrl-r")
H.check("key stored, normalised", RC.Get("general", "clickKey1"), "CTRL-SHIFT-R")
H.check("key box shows it", key1.keyBox:GetText(), "CTRL-SHIFT-R")
enter(key1.keyBox, "button1")
H.check("left button refused", RC.Get("general", "clickKey1"), "CTRL-SHIFT-R")
H.checkTrue("why", M.chat[#M.chat]:find(L.RAID_TYPED_KEY_INVALID:format("button1"), 1, true))
enter(rowFor("clickKey2").keyBox, "ctrl-shift-r")
H.check("a key twice refused", RC.Get("general", "clickKey2"), "")
H.checkTrue("why twice", M.chat[#M.chat]:find(L.RAID_TYPED_KEY_TWICE:format("CTRL-SHIFT-R"), 1, true))
H.check("no warning for a free key", key1.hintText:GetText(), "")
enter(key1.keyBox, "w")
H.check("W taken", RC.Get("general", "clickKey1"), "W")
H.check("warns: bound otherwise", key1.hintText:GetText(), L.RAID_CLICK_KEY_TAKEN:format("MOVEFORWARD"))
H.check("the kinds of a key", (function()
    click(key1.button)
    local n = 0
    for _, r in ipairs(ns.Widgets.list.rows) do if r:IsShown() and r.item then n = n + 1 end end
    ns.Widgets.CloseList()
    return n
end)(), 4)
pick(key1, "spell")
enter(key1.value, "Flash Heal")
H.check("key casts", RC.Get("general", "clickKey1Bind"), "spell:Flash Heal")

-- Copy from another character: its bindings and keys.
local copy = RO.clickCopyRow
H.checkTrue("copy row", copy)
H.check("copy button locked until a character is picked", RO.clickCopyButton:IsEnabled(), false)
pick(copy, "Alt-Realm")
click(RO.clickCopyButton)
H.check("copied: middle", RC.Get("general", "click3"), "assist")
H.check("copied: key", RC.Get("general", "clickKey1"), "Q")
H.check("copied: what it casts", RC.Get("general", "clickKey1Bind"), "item:1251")
H.check("copied: the rest back to the defaults", RC.Get("general", "click1Shift"), "")
-- Spells go through this character's spell book: a known one as it
-- writes it, an unknown one is left out (the slot keeps its default) and
-- named in the chat.
H.check("copied: a known spell", RC.Get("general", "click5"), "spell:Flash Heal")
H.check("not copied: an unknown spell", RC.Get("general", "click4"), "")
H.check("not copied: a key's unknown spell", RC.Get("general", "clickKey2Bind"), "")
H.check("its key copied all the same", RC.Get("general", "clickKey2"), "E")
H.checkTrue("said which", M.chat[#M.chat]:find(L.RAID_CLICK_COPY_DROPPED:format("Smite, Mind Blast"), 1, true))
-- A copied key that is this character's smart buff key is left out (its
-- slot keeps the default), and the chat says so.
RC.Set("general", "buffKey", "E")
ns.RaidProfiles.CopyClickCast("Alt-Realm")
H.check("not copied: the smart buff key", RC.Get("general", "clickKey2"), "")
H.check("the buff key stays", RC.Get("general", "buffKey"), "E")
H.checkTrue("said so", M.chat[#M.chat]:find(L.RAID_CLICK_COPY_BUFF_KEY:format("E"), 1, true))
RC.Set("general", "buffKey", "")

-- Clear all: two clicks, back to the defaults.
RC.Set("general", "click4", "assist")
click(RO.clickClearButton)
H.check("armed", RC.Get("general", "click4"), "assist")
click(RO.clickClearButton)
H.check("cleared", RC.Get("general", "click4"), "")
H.check("left targets again", RC.Get("general", "click1"), "target")
H.check("keys cleared", RC.Get("general", "clickKey1"), "")

-- Clique loaded: the mode row says so.
H.check("hint without Clique", rowFor("clickCast").hintText:GetText(), L.RAID_HINT_clickCast)
M.loadedAddons.Clique = true
RO.SelectTab("clickCast")
H.check("hint with Clique", rowFor("clickCast").hintText:GetText(), L.RAID_CLICK_CLIQUE)
M.loadedAddons.Clique = nil

-- Combat: everything locked.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("kind locked", plain.button:IsEnabled(), false)
H.check("value locked", rowFor("click3").value:IsEnabled(), false)
H.check("key locked", key1.keyBox:IsEnabled(), false)
H.check("clear locked", RO.clickClearButton:IsEnabled(), false)
H.check("copy locked", copy.button:IsEnabled(), false)
M.SetCombat(false)
H.check("unlocked", plain.button:IsEnabled(), true)
H.check("value of a kind without one stays locked", rowFor("click3").value:IsEnabled(), false)
H.check("nothing blocked", #M.blocked, 0)
