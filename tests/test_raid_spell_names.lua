-- Corner indicator spells by name (Raid/Spellbook.lua): a name stands for
-- every rank of it in the player's spell book; the options window stores
-- the IDs. Nothing read from the spell book is compared while secret.
local M = H.M
local ns = H.LoadAddon()
local Book, Raid = ns.RaidSpellbook, ns.Raid
M.known[2050], M.known[2052] = true, true

-- The mock's spell book: learned spells in line 1, every rank an item.
H.check("two skill lines", C_SpellBook.GetNumSpellBookSkillLines(), 2)
local line = C_SpellBook.GetSpellBookSkillLineInfo(1)
H.check("learned spells", line.numSpellBookItems, 2)
local item = C_SpellBook.GetSpellBookItemInfo(line.itemIndexOffset + 1, Enum.SpellBookSpellBank.Player)
H.check("an item", item.name .. " " .. item.spellID .. " " .. item.itemType, "Lesser Heal 2050 1")
H.check("pet bank: nothing", C_SpellBook.GetSpellBookItemInfo(1, Enum.SpellBookSpellBank.Pet), nil)
H.checkError("slot required", function() C_SpellBook.GetSpellBookItemInfo(nil, 0) end)

-- Every learned rank of a name, case ignored.
H.check("ranks", table.concat(Book.IDs("lesser heal"), ","), "2050,2052")
H.check("a spell not learned", #Book.IDs("Heal"), 0)
M.futureSpells[2053] = true
H.check("future spells are not learned", table.concat(Book.IDs("Lesser Heal"), ","), "2050,2052")

-- A typed list: IDs (commas or spaces) and names (between commas).
H.check("a name", Book.Resolve("Lesser Heal"), "2050,2052")
H.check("IDs and a name", Book.Resolve("139, Lesser Heal"), "139,2050,2052")
H.check("IDs only", Book.Resolve("139 6074"), "139,6074")
H.check("each once", Book.Resolve("2050, Lesser Heal"), "2050,2052")
H.check("empty", Book.Resolve("  "), "")
local ids, unknown = Book.Resolve("Lesser Heal, Nope")
H.check("unknown name refused", ids, nil)
H.check("the unknown name", unknown, "Nope")
H.check("zero refused", Book.Resolve("0"), nil)
H.checkTrue("a valid spell list", Raid.SpellList(Book.Resolve("139, Lesser Heal")))

-- Secret items are skipped, never compared.
local real = C_SpellBook.GetSpellBookItemInfo
C_SpellBook.GetSpellBookItemInfo = function()
    return { name = M.Secret("Lesser Heal"), spellID = M.Secret(2050), itemType = M.Secret(1) }
end
H.check("secret items skipped", #Book.IDs("Lesser Heal"), 0)
C_SpellBook.GetSpellBookItemInfo = real

-- Without the spell book API names cannot be read; IDs still can.
C_SpellBook.GetNumSpellBookSkillLines = nil
H.check("no spell book: no ranks", #Book.IDs("Lesser Heal"), 0)
H.check("no spell book: IDs", Book.Resolve("139"), "139")
H.check("no spell book: names refused", Book.Resolve("Lesser Heal"), nil)
