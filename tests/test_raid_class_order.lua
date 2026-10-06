-- The order of the class blocks (Raid/Settings.lua classOrder,
-- Raid/Layout.lua): the classes named first, the others after them in
-- Blizzard's order; empty is Blizzard's order.
local M = H.M
local ns = H.LoadAddon()
local Raid, RS, RC, Layout, Header, Test = ns.Raid, ns.RaidSettings, ns.RaidConfig, ns.RaidLayout, ns.RaidHeader,
    ns.RaidTestMode
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

local def = RS.Get("classOrder")
H.checkTrue("defined", def)
H.check("code", def and def.code, "CO")
H.check("text", def and def.type, "text")
H.check("per size", def and RS.AppliesTo(def, "r20"), true)
H.check("not character-wide", def and RS.AppliesTo(def, "general"), false)
H.check("default: Blizzard's order", RC.Get("r10", "classOrder"), "")

-- Only class tokens, each once.
H.checkTrue("tokens", RC.Set("r10", "classOrder", "PRIEST,DRUID"))
H.check("stored", RC.Get("r10", "classOrder"), "PRIEST,DRUID")
H.checkTrue("spaces too", RC.Set("r20", "classOrder", "MAGE SHAMAN"))
H.check("unknown class refused", RC.Set("r10", "classOrder", "PRIEST,MONK"), false)
H.check("lower case refused", RC.Set("r10", "classOrder", "priest"), false)
H.check("twice refused", RC.Set("r10", "classOrder", "PRIEST,DRUID,PRIEST"), false)
H.check("kept after refusals", RC.Get("r10", "classOrder"), "PRIEST,DRUID")
H.check("exported", ns.RaidProfiles.Export(10), "1;aCO'PRIEST,DRUID")

-- The class list: named classes first, the rest in Blizzard's order.
H.check("Blizzard's order", table.concat(Layout.Classes(""), ","), table.concat(CLASS_SORT_ORDER, ","))
H.check("named first", table.concat(Layout.Classes("PRIEST,DRUID"), ","),
    "PRIEST,DRUID,WARRIOR,PALADIN,SHAMAN,ROGUE,MAGE,WARLOCK,HUNTER")
H.check("spaces", table.concat(Layout.Classes("MAGE SHAMAN"), ",", 1, 2), "MAGE,SHAMAN")
H.check("no order given", #Layout.Classes(nil), 9)
local function ids(blocks)
    local list = {}
    for i, b in ipairs(blocks) do list[i] = b.id end
    return table.concat(list, ",")
end
H.check("class blocks in the given order", ids(Layout.Blocks("CLASS", 10, "INDEX", "PRIEST,DRUID")),
    "PRIEST,DRUID,WARRIOR,PALADIN,SHAMAN,ROGUE,MAGE,WARLOCK,HUNTER")
H.check("first block's filter", Layout.Blocks("CLASS", 10, "INDEX", "PRIEST,DRUID")[1].filter.groupFilter,
    "1,2,PRIEST")

-- What the options window turns into tokens: tokens in any case, or the
-- game's class names.
H.check("parse tokens", Raid.ParseClassOrder("priest, Druid"), "PRIEST,DRUID")
H.check("parse empty", Raid.ParseClassOrder("  "), "")
H.check("parse unknown", Raid.ParseClassOrder("Priest, Monk"), nil)
H.check("parse twice", Raid.ParseClassOrder("Priest, priest"), nil)
local male, female = LOCALIZED_CLASS_NAMES_MALE.PRIEST, LOCALIZED_CLASS_NAMES_FEMALE
LOCALIZED_CLASS_NAMES_MALE.PRIEST = "Priester"
_G.LOCALIZED_CLASS_NAMES_FEMALE = { PRIEST = "Priesterin" }
H.check("parse class names", Raid.ParseClassOrder("priester; Druid"), nil)
H.check("parse class names, commas", Raid.ParseClassOrder("priester, Druid"), "PRIEST,DRUID")
H.check("parse female class names", Raid.ParseClassOrder("Priesterin"), "PRIEST")
LOCALIZED_CLASS_NAMES_MALE.PRIEST, _G.LOCALIZED_CLASS_NAMES_FEMALE = male, female

-- The headers follow the order of the size shown.
RC.Set("r10", "groupBy", "CLASS")
Header.Create()
H.check("header 1: priests", Header.headers[1]:GetAttribute("groupFilter"), "1,2,PRIEST")
H.check("header 2: druids", Header.headers[2]:GetAttribute("groupFilter"), "1,2,DRUID")
RC.Set("r10", "classOrder", "")
H.check("back to Blizzard's order", Header.headers[1]:GetAttribute("groupFilter"), "1,2,WARRIOR")

-- Test mode places its pretend members in the same blocks.
local lists = Test.Distribute(Layout.Blocks("CLASS", 10, "INDEX", "PRIEST,DRUID"), Test.Members(10), 10, "INDEX")
H.check("test mode: the priest first", lists[1][1].index, 2)
H.check("test mode: the druid second", lists[2][1].index, 7)
H.check("nothing blocked", #M.blocked, 0)
