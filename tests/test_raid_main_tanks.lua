-- The main tanks panel (Raid/SpecialPanels.lua): a raid panel of its own
-- with the raid's main tank assignment, per size switched, titled,
-- arranged and placed; its players stay in their groups; in combat the
-- header follows the assignment by itself. The raid window's Panels tab.
local M = H.M
local ns = H.LoadAddon()
local RC, RS, Header, Special = ns.RaidConfig, ns.RaidSettings, ns.RaidHeader, ns.RaidSpecialPanels
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

-- The settings: per size, permanent codes, the growth stored like the
-- main panel's.
local CODES = { mainTanksShow = "QS", mainTanksTitle = "QT", mainTanksPerLine = "QL", mainTanksGrowth = "QG",
    mainTanksX = "QX", mainTanksY = "QY" }
for key, code in pairs(CODES) do
    local def = RS.Get(key)
    H.check(key .. " code", def and def.code, code)
    H.check(key .. " per size", def and RS.AppliesTo(def, "r20"), true)
end
H.check("growth: the main panel's list", RS.Get("mainTanksGrowth").values, RS.Get("cellGrowth").values)
local DEFAULTS = { mainTanksShow = true, mainTanksTitle = true, mainTanksPerLine = 5, mainTanksGrowth = "RIGHT",
    mainTanksX = -600, mainTanksY = 260 }
for key, want in pairs(DEFAULTS) do H.check(key .. " default", RC.Get("r40", key), want) end
H.check("listed as a panel", ns.Raid.PANELS[1].id, "mainTanks")
H.check("its settings in order", table.concat(ns.Raid.PANELS[1].keys, ","),
    "mainTanksShow,mainTanksTitle,mainTanksPerLine,mainTanksGrowth,mainTanksX,mainTanksY")

-- Built with the main panel.
local P = Special.panels.mainTanks
H.check("not built before the main panel", P.anchor, nil)
Header.Create()
H.check("anchor", P.anchor:GetName(), "ForeverUnitFramesRaidMainTanks")
local h = P.headers[1]
H.check("header", h:GetName(), "ForeverUnitFramesRaidMainTanksBlock1")
H.check("the assignment", h:GetAttribute("roleFilter"), "MAINTANK")
H.check("no group filter", h:GetAttribute("groupFilter"), nil)
H.check("cells in a row", h:GetAttribute("point"), "LEFT")
H.check("room for a whole raid", h:GetAttribute("maxColumns"), 8)
H.check("cells of the main panel", h:GetAttribute("template"), ns.RaidCell.TEMPLATE)
H.check("mover id", P.anchor.mover.spec.id, "raid:mainTanks")
H.check("moved with the raid window", P.anchor.mover.spec.group, "raid")
H.check("mover label", P.anchor.mover.label:GetText(), "Main tanks 10")

local function member(name, subgroup, role)
    return { name = name, class = "WARRIOR", subgroup = subgroup, role = role,
        unit = { health = 100, healthMax = 100, powerType = 1 } }
end
local function point(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    local name = rel == UIParent and "UIParent" or rel == P.anchor and "anchor" or rel == P.panel and "panel" or "?"
    return table.concat({ p, name, relPoint, x, y }, " ")
end
local roster = { member("A", 1), member("Tank", 1, "MAINTANK"), member("B", 1), member("C", 1),
    member("Off", 2, "MAINTANK"), member("D", 2), member("Helper", 2, "MAINASSIST") }
M.SetRaidRoster(roster)
M.RunTimers()
H.checkTrue("shown in a raid", P.panel:IsShown())
H.check("two main tanks", P.Count(1), 2)
H.check("in raid order", h:GetAttribute("child1").unit .. "," .. h:GetAttribute("child2").unit, "raid2,raid5")
H.check("still in their groups", Header.Count(1) + Header.Count(2), 7)
H.check("the main panel's cells", h:GetAttribute("child1"):GetWidth(), 96)
H.check("a row of two under the title", P.width .. "x" .. P.height, (2 * 96 + 2) .. "x" .. (14 + 44))
H.check("title", P.decor[1].title:GetText(), "Main tanks")
H.checkTrue("title shown", P.decor[1].title:IsShown())
H.check("cells below the title", point(h), "TOPLEFT anchor TOPLEFT 0 -14")
H.checkTrue("the gold ring", P.panel.border and P.panel.border[1]:IsShown())
H.check("at its position", point(P.anchor.mover), "TOPLEFT UIParent CENTER -600 260")

-- Per size: title, cells per line, growth.
RC.Set("r10", "mainTanksTitle", false)
H.check("no title: no title row", P.height, 44)
H.check("no title: cells at the top", point(h), "TOPLEFT anchor TOPLEFT 0 0")
RC.Set("r10", "mainTanksPerLine", 1)
M.RunTimers()
H.check("one per line: a column", P.width .. "x" .. P.height, "96x" .. (2 * 44 + 2))
RC.Set("r10", "mainTanksGrowth", "DOWN")
H.check("growing down", h:GetAttribute("point"), "TOP")
RC.ResetScope("r10")
M.RunTimers()
H.check("other size: not this one", RC.Get("r10", "mainTanksGrowth"), "RIGHT")

-- Its own position: only it moves.
RC.Set("r10", "mainTanksX", -500)
H.check("moved", point(P.anchor.mover), "TOPLEFT UIParent CENTER -500 260")
H.check("the main panel stays", select(4, Header.anchor.mover:GetPoint(1)), -600)
RC.Set("r10", "mainTanksX", -600)

-- The raid window's lock shows its handle; off, the handle goes too.
ns.Movers.Unlock("raid")
H.checkTrue("handle shown", P.anchor.mover:IsShown())
RC.Set("r10", "mainTanksShow", false)
H.check("off: handle hidden", P.anchor.mover:IsShown(), false)
H.check("off: header hidden", h:IsShown(), false)
H.check("off: panel hidden", P.panel:IsShown(), false)
H.checkTrue("off: the main panel stays", Header.panel:IsShown())
RC.Set("r10", "mainTanksShow", true)
H.checkTrue("on again", h:IsShown() and P.panel:IsShown() and P.anchor.mover:IsShown())
ns.Movers.Lock("raid")

-- In combat the header follows the assignment; the panel is tidied after.
M.combat = true
roster[7].role = "MAINTANK"
M.SetRaidRoster(roster)
H.check("combat: a third main tank", P.Count(1), 3)
H.check("combat: placed later", P.width, 2 * 96 + 2)
H.check("combat: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
M.RunTimers()
H.check("after combat: room for three", P.width, 3 * 96 + 2 * 2)

-- Nobody assigned: no room, no ring.
for _, m in ipairs(roster) do m.role = nil end
M.SetRaidRoster(roster)
M.RunTimers()
H.check("no main tanks: no room", P.width, 0)
H.check("no main tanks: no ring", P.panel.border[1]:IsShown(), false)
H.check("no main tanks: no title", P.decor[1]:IsShown(), false)

-- A party with the raid view: a party member's assignment counts.
M.SetRaidRoster({})
M.units.player = { name = "Me", class = "MAGE", isPlayer = true }
M.units.party1 = { name = "Ann", class = "WARRIOR", isPlayer = true, assignment = "MAINTANK" }
M.SetGroup({ "party1" })
RC.Set("general", "showInParty", true)
M.RunTimers()
H.check("party: the main tank", h:GetAttribute("child1").unit, "party1")
H.checkTrue("party: shown", P.panel:IsShown())
RC.Set("general", "showInParty", false)
H.check("party without the raid view: hidden", P.panel:IsShown(), false)

-- The raid window: a Panels tab with a section per panel.
local tab = ns.RaidSchema.TABS[3]
H.check("Panels tab after Layout", tab.id, "panels")
H.check("its section", tab.sections[1].id, "mainTanks")
H.check("its note", ns.RaidSchema.Note("panels"), ns.L.RAID_NOTE_panels)
H.check("show label", ns.RaidSchema.Label("mainTanksShow"), "Show the panel")
H.check("the main panel's words", ns.RaidSchema.Label("mainTanksPerLine"), "Cells per line")
H.check("growth choices", ns.RaidSchema.EnumText(RS.Get("mainTanksGrowth"), "RIGHT"), "Right")
H.check("section title", ns.RaidSchema.SectionTitle("mainTanks"), "Main tanks")

-- Every tab fits the row, in every language.
local RO = ns.RaidOptions
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    ns.Config.Set("general", "language", code)
    RO.Open()
    local right = 8
    for _, b in ipairs(RO.tabButtons) do
        right = right + b:GetWidth()
        H.checkTrue(code .. ": word fits its tab " .. b.tabId, b.text:GetStringWidth() < b:GetWidth())
    end
    H.checkTrue(code .. ": the tabs fit the row", right <= RO.frame:GetWidth() - 8)
    RO.Close()
end
ns.Config.Set("general", "language", "AUTO")
RO.Open()
-- English fits without squeezing: every tab its word and the padding,
-- at least 70, as before the tabs were fitted to the row.
for _, b in ipairs(RO.tabButtons) do
    H.check("English: tab " .. b.tabId .. " as before", b:GetWidth(), math.max(70, b.text:GetStringWidth() + 28))
end
RO.Close()
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
