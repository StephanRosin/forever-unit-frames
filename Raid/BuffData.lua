local _, ns = ...

-- The group buffs the buff watch knows (Raid/BuffWatch.lua): per class,
-- the spell IDs of every rank of the single form and of the group form,
-- and the reagent each rank of the group form takes. The IDs are the
-- Classic ones (as Core/Settings.lua's tracking list); the spell book
-- decides which rank is cast (C_SpellBook.IsSpellKnown), the client names
-- them (C_Spell.GetSpellName): an ID it does not know gives no name, and
-- that form is left out. Nothing here is read in combat.
--
-- who: whom the buff is for: everyone (ALL), those who use mana (MANA:
-- every class but warriors and rogues), tanks (TANK).
local Data = {}
ns.RaidBuffData = Data

local Secrets = ns.Secrets

Data.BUFFS = {
    { id = "fortitude", class = "PRIEST", who = "ALL",
        single = { 1243, 1244, 1245, 2791, 10937, 10938 }, group = { 21562, 21564 },
        -- Holy Candle, Sacred Candle.
        reagents = { [21562] = 17028, [21564] = 17029 } },
    { id = "spirit", class = "PRIEST", who = "MANA",
        single = { 14752, 14818, 14819, 27841 }, group = { 27681 }, reagents = { [27681] = 17029 } },
    { id = "shadowProtection", class = "PRIEST", who = "ALL",
        single = { 976, 10957, 10958 }, group = { 27683 }, reagents = { [27683] = 17029 } },
    -- Arcane Powder.
    { id = "intellect", class = "MAGE", who = "MANA",
        single = { 1459, 1460, 1461, 10156, 10157 }, group = { 23028 }, reagents = { [23028] = 17020 } },
    -- Wild Berries, Wild Thornroot.
    { id = "wild", class = "DRUID", who = "ALL",
        single = { 1126, 5232, 6756, 5234, 8907, 9884, 9885 }, group = { 21849, 21850 },
        reagents = { [21849] = 17021, [21850] = 17026 } },
    { id = "thorns", class = "DRUID", who = "TANK",
        single = { 467, 782, 1075, 8914, 9756, 9910 }, group = {}, reagents = {} },
}

-- Paladin blessings: one per class of the members, chosen in the raid
-- window. The greater forms bless every member of the class and take a
-- Symbol of Kings. Stored by index (the setting's enum): append only.
Data.BLESSINGS = { "NONE", "MIGHT", "WISDOM", "KINGS", "SALVATION", "LIGHT", "SANCTUARY" }
local SYMBOL_OF_KINGS = 21177
local function blessing(single, group)
    local reagents = {}
    for _, id in ipairs(group) do reagents[id] = SYMBOL_OF_KINGS end
    return { single = single, group = group, reagents = reagents }
end
Data.BLESSING = {
    MIGHT = blessing({ 19740, 19834, 19835, 19836, 19837, 19838, 25291 }, { 25782, 25916 }),
    WISDOM = blessing({ 19742, 19850, 19852, 19853, 19854, 25290 }, { 25894, 25918 }),
    KINGS = blessing({ 20217 }, { 25898 }),
    SALVATION = blessing({ 1038 }, { 25895 }),
    LIGHT = blessing({ 19977, 19978, 19979 }, { 25890 }),
    SANCTUARY = blessing({ 20911, 20912, 20913, 20914 }, { 25899 }),
}

-- The classes of this game, in a fixed order (their settings' codes
-- depend on it, not on the client's sort order).
Data.CLASSES = { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER" }
-- Classes without mana.
Data.NO_MANA = { WARRIOR = true, ROGUE = true }

local function known(id)
    local book = C_SpellBook
    if not (book and book.IsSpellKnown) then return false end
    local ok, v = pcall(book.IsSpellKnown, id)
    return ok and not Secrets.IsSecret(v) and v == true
end

-- The highest rank of a form the spell book knows, or nil.
function Data.Highest(ids)
    for i = #ids, 1, -1 do
        if known(ids[i]) then return ids[i] end
    end
    return nil
end

local function plainCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or Secrets.IsSecret(v) then return nil end
    return v
end

-- A form: { id = the highest known rank (nil: none), name = the client's
-- (from its first rank), icon }; nil when the client gives no name.
function Data.Form(ids)
    if #ids == 0 then return nil end
    local name = plainCall(C_Spell.GetSpellName, ids[1])
    if type(name) ~= "string" or name == "" then return nil end
    local id = Data.Highest(ids)
    return { id = id, name = name, icon = plainCall(C_Spell.GetSpellTexture, id or ids[1]) }
end
