-- Typed values the raid options window refuses (Raid/Options/Window.lua,
-- Raid/Settings.lua, Raid/Spellbook.lua) say why in the chat: the spell
-- name the spell book does not know, a list too long to store, a class
-- that is unknown or named twice. The field flashes and keeps what was
-- stored, as before.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, Raid = ns.RaidOptions, ns.RaidConfig, ns.Raid

local function rowFor(key)
    for _, row in ipairs(RO.rows) do
        if row.key == key then return row end
    end
end
local function enter(row, text)
    row.edit:SetText(text)
    row.edit:GetScript("OnEnterPressed")(row.edit)
end
local function said() return M.chat[#M.chat] end

-- The class order: why a typed order is refused.
H.check("unknown class", select(2, Raid.ParseClassOrder("Priest, Monk")), "UNKNOWN")
H.check("the word", select(3, Raid.ParseClassOrder("Priest, Monk")), "Monk")
H.check("named twice", select(2, Raid.ParseClassOrder("Priest, priest")), "TWICE")
H.check("the second naming", select(3, Raid.ParseClassOrder("Priest, priest")), "priest")
H.check("fine", Raid.ParseClassOrder("Priest, Druid"), "PRIEST,DRUID")

RO.Open(10, "layout")
local before = #M.chat
enter(rowFor("classOrder"), "Druid, Mage")
H.check("stored", RC.Get("r10", "classOrder"), "DRUID,MAGE")
H.check("nothing said when stored", #M.chat, before)
enter(rowFor("classOrder"), "Priest, Monk")
H.check("said: unknown class", said(), "|cff4fc3f7Forever Unit Frames:|r Unknown class: Monk")
H.check("refused: the stored order kept", RC.Get("r10", "classOrder"), "DRUID,MAGE")
enter(rowFor("classOrder"), "Priest, Shaman, priest")
H.check("said: twice", said(), "|cff4fc3f7Forever Unit Frames:|r Class named twice: priest")
H.check("refused again: still kept", RC.Get("r10", "classOrder"), "DRUID,MAGE")
H.check("one line per refusal", #M.chat, before + 2)

-- Spells: the name the spell book does not know.
RO.SelectTab("indicators")
local spells = rowFor("indicatorTopLeftSpells")
enter(spells, "139")
H.check("spells stored", RC.Get("r10", "indicatorTopLeftSpells"), "139")
enter(spells, "17, Nope")
H.check("said: not in the spell book", said(), "|cff4fc3f7Forever Unit Frames:|r Not a spell in your spell book: Nope")
H.check("spells unchanged", RC.Get("r10", "indicatorTopLeftSpells"), "139")

-- A name with more ranks than the list can hold.
for i = 1, 40 do
    M.spells[100000 + i] = { name = "Long Spell", maxRange = 40 }
    M.known[100000 + i] = true
end
enter(spells, "Long Spell")
H.check("said: too long", said(),
    ("|cff4fc3f7Forever Unit Frames:|r Too many spells: the list may hold %d characters."):format(Raid.SPELL_LIST_LETTERS))
H.check("still unchanged", RC.Get("r10", "indicatorTopLeftSpells"), "139")
M.known[2050] = true
enter(spells, "Lesser Heal")
H.check("a name stored", RC.Get("r10", "indicatorTopLeftSpells"), "2050")
RO.Close()
