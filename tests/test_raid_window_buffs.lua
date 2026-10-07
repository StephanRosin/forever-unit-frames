-- The raid window's Buffs tab (Raid/Options/Buffs.lua): a buff's switch
-- only means something for your class when your spell book knows it (else
-- it greys), the blessings only for a paladin; the window's and the cell
-- icon's options only while they are on; the smart buff key typed as the
-- click-casting keys are, never one of theirs.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "Priest", health = 1, healthMax = 1 }
M.known[1243] = true
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, L = ns.RaidOptions, ns.RaidConfig, ns.L

local function rowFor(key)
    for _, row in ipairs(RO.rows) do
        if row.key == key then return row end
    end
end
local function enabled(key) return rowFor(key).enabledState end
RO.Open(10, "buffs")
H.check("the Buffs tab", RO.currentTab, "buffs")
H.check("fortitude: known, on", enabled("buffFortitude"), true)
H.check("divine spirit: not in the spell book", enabled("buffSpirit"), false)
H.check("arcane intellect: not your class", enabled("buffIntellect"), false)
H.check("blessings: not a paladin", enabled("buffBlessings"), false)
H.check("a class's blessing: not a paladin", enabled("blessingWARRIOR"), false)
H.check("rules: always", enabled("buffExpiring"), true)
H.check("the key: always", enabled("buffKey"), true)
H.check("window position while it shows", enabled("buffWatchX"), true)
H.check("cell icon point: icon off", enabled("buffCellIconPoint"), false)
RC.Set("general", "buffCellIcon", true)
H.check("cell icon point: icon on", enabled("buffCellIconPoint"), true)
RC.Set("general", "buffWatchShow", false)
H.check("only when missing: window off", enabled("buffWatchOnlyMissing"), false)
H.check("position: window off", enabled("buffWatchY"), false)
RC.Set("general", "buffWatchShow", true)
-- Learnt: the switch wakes up when the window shows the tab again.
M.known[14752] = true
RO.SelectTab("buffs")
H.check("divine spirit learnt", enabled("buffSpirit"), true)
-- A paladin with a blessing: the blessings mean something.
M.units.player.class = "PALADIN"
M.known[19740] = true
RO.SelectTab("buffs")
H.check("paladin: blessings", enabled("buffBlessings"), true)
H.check("paladin: each class", enabled("blessingWARRIOR"), true)
RC.Set("general", "buffBlessings", false)
H.check("blessings off: the classes grey", enabled("blessingWARRIOR"), false)
RC.Set("general", "buffBlessings", true)
-- In combat everything locks.
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: locked", enabled("buffKey"), false)
M.SetCombat(false)
H.check("after combat", enabled("buffKey"), true)

-- The key: typed in any spelling, stored as the client names it.
local function enter(text)
    local row = rowFor("buffKey")
    M.Type(row.edit, text)
    M.PressEnter(row.edit)
end
enter("shift-b")
H.check("stored", RC.Get("general", "buffKey"), "SHIFT-B")
enter("foo")
H.check("refused: no key", RC.Get("general", "buffKey"), "SHIFT-B")
H.check("says why", M.chat[#M.chat]:find(L.RAID_TYPED_KEY_INVALID:format("foo"), 1, true) ~= nil, true)
-- Taken by a click-casting key: refused, both ways.
RC.Set("general", "clickKey1", "F")
enter("f")
H.check("a click-casting key's: refused", RC.Get("general", "buffKey"), "SHIFT-B")
H.check("says so", M.chat[#M.chat]:find(L.RAID_TYPED_KEY_TWICE:format("F"), 1, true) ~= nil, true)
RO.SelectTab("clickCast")
local keyRow = rowFor("clickKey2")
M.Type(keyRow.keyBox, "shift-b")
M.PressEnter(keyRow.keyBox)
H.check("the smart buff key's: refused for a click key", RC.Get("general", "clickKey2"), "")
RO.SelectTab("buffs")
enter("")
H.check("cleared", RC.Get("general", "buffKey"), "")
H.check("no error", #M.errors, 0)
