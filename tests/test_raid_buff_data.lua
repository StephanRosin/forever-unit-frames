-- The buff table (Raid/BuffData.lua): the group buffs of each class, single
-- and group form (every rank), the group forms' reagents; the spell book
-- decides which rank is cast, the client names them.
local M = H.M
local ns = H.LoadAddon()
local Data = ns.RaidBuffData

local function find(id)
    for _, b in ipairs(Data.BUFFS) do if b.id == id then return b end end
end

-- The class buffs, by class.
local ids = {}
for _, b in ipairs(Data.BUFFS) do ids[#ids + 1] = b.class .. ":" .. b.id end
H.check("the buffs", table.concat(ids, ","),
    "PRIEST:fortitude,PRIEST:spirit,PRIEST:shadowProtection,MAGE:intellect,DRUID:wild,DRUID:thorns")
local fort = find("fortitude")
H.check("fortitude: every rank", table.concat(fort.single, ","), "1243,1244,1245,2791,10937,10938")
H.check("prayer of fortitude", table.concat(fort.group, ","), "21562,21564")
H.check("its candles", fort.reagents[21562] .. "," .. fort.reagents[21564], "17028,17029")
H.check("brilliance: arcane powder", find("intellect").reagents[23028], 17020)
H.check("gift of the wild: berries, thornroot", find("wild").reagents[21849] .. "," .. find("wild").reagents[21850],
    "17021,17026")
H.check("thorns: no group form", #find("thorns").group, 0)
H.check("who: everyone", fort.who, "ALL")
H.check("who: mana users", find("intellect").who, "MANA")
H.check("who: tanks", find("thorns").who, "TANK")

-- Paladin blessings: one per class, single and greater form; the greater
-- ones take a Symbol of Kings.
H.check("blessings", table.concat(Data.BLESSINGS, ","), "NONE,MIGHT,WISDOM,KINGS,SALVATION,LIGHT,SANCTUARY")
H.check("might: ranks", table.concat(Data.BLESSING.MIGHT.single, ","), "19740,19834,19835,19836,19837,19838,25291")
H.check("greater might", table.concat(Data.BLESSING.MIGHT.group, ","), "25782,25916")
H.check("greater kings: a symbol", Data.BLESSING.KINGS.reagents[25898], 21177)
H.check("the classes, in a fixed order", table.concat(Data.CLASSES, ","),
    "WARRIOR,PALADIN,PRIEST,SHAMAN,DRUID,ROGUE,MAGE,WARLOCK,HUNTER")

-- The highest rank the spell book knows; none known: nil.
H.check("nothing known", Data.Highest(fort.single), nil)
M.known[1243], M.known[1244] = true, true
H.check("the highest known rank", Data.Highest(fort.single), 1244)
-- A form: its highest known rank, the client's name and icon (from the
-- first rank: the group form of another priest counts even unlearned).
local form = Data.Form(fort.group)
H.check("group form unknown: no rank", form.id, nil)
H.check("group form: still its name", form.name, "Prayer of Fortitude")
H.check("single form", Data.Form(fort.single).id, 1244)
H.check("single name", Data.Form(fort.single).name, "Power Word: Fortitude")
-- An ID the client does not know: no form at all.
H.check("unknown ID: no form", Data.Form({ 999999 }), nil)
-- The client's name is secret (not documented as such; guarded): no form.
M.spells[1243].name = M.Secret("Power Word: Fortitude")
H.check("secret name: no form", Data.Form(fort.single), nil)
