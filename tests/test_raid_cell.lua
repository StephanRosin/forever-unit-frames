-- Raid cells (Raid/Cell.lua, Raid/Cell.xml): unit buttons made by a group
-- header that run the unit-frame elements under the derived scope "raid":
-- a cell's fixed choices, the raid profile of the active size, the unit
-- frames' shipped defaults for the rest. Clicks, click-casting, events
-- per unit, the power strip's rule.
local M = H.M
local ns = H.LoadAddon()
local RC, Cell = ns.RaidConfig, ns.RaidCell

-- The XML template and the mock mirror of it agree.
local xml = H.ReadFile("Raid/Cell.xml")
H.checkTrue("xml: template name", xml:find('name="ForeverUnitFramesRaidButtonTemplate"', 1, true))
H.checkTrue("xml: secure unit button", xml:find('inherits="SecureUnitButtonTemplate"', 1, true))
H.checkTrue("xml: clicks", xml:find('registerForClicks="AnyUp"', 1, true))
H.checkTrue("xml: size = 40-player cell defaults", xml:find('<Size x="80" y="38"/>', 1, true))
H.checkTrue("xml: left click targets", xml:find('<Attribute name="*type1" type="string" value="target"/>', 1, true))
H.checkTrue("xml: right click menu", xml:find('<Attribute name="*type2" type="string" value="togglemenu"/>', 1, true))
H.checkTrue("xml: OnLoad", xml:find("ForeverUnitFrames.RaidButtonOnLoad(self)", 1, true))
H.checkTrue("xml: OnAttributeChanged",
    xml:find("ForeverUnitFrames.RaidButtonOnAttributeChanged(self, name, value)", 1, true))
H.checkTrue("xml: no snippet", not xml:find("initialConfigFunction", 1, true))
H.check("default width = xml", ns.RaidSettings.Default(ns.RaidSettings.Get("cellWidth"), "r40"), 80)
H.check("default height = xml", ns.RaidSettings.Default(ns.RaidSettings.Get("cellHeight"), "r40"), 38)
local toc = H.ReadFile("ForeverUnitFrames.toc")
H.checkTrue("toc lists the xml after the lua", toc:find("Raid\\Cell.lua\nRaid\\Cell.xml", 1, true))

ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
H.check("size before a raid", Cell.Size(), 10)

-- The derived scope: the cell's own look from the active size's profile.
local C = ns.Config
H.check("width from the 10 profile", C.Get("raid", "width"), 96)
H.check("height from the 10 profile", C.Get("raid", "height"), 44)
RC.Set("r10", "cellWidth", 110)
H.check("width follows the profile", C.Get("raid", "width"), 110)
H.check("no title row", C.Get("raid", "titlePercent"), 0)
H.check("no portrait", C.Get("raid", "portraitMode"), "OFF")
H.check("no castbar", C.Get("raid", "castbarEnabled"), false)
H.check("no buffs", C.Get("raid", "buffsEnabled"), false)
H.check("no debuffs", C.Get("raid", "debuffsEnabled"), false)
H.check("no combat numbers", C.Get("raid", "combatFeedback"), false)
H.check("no threat glow", C.Get("raid", "threatGlow"), false)
H.check("no shadow", C.Get("raid", "shadowEnabled"), false)
H.check("name on the bar", C.Get("raid", "textHealthLeft"), "NAME")
H.check("second line: missing health", C.Get("raid", "textHealthRight"), "DEFICIT")
H.check("class colour", C.Get("raid", "healthColorMode"), "CLASS")
H.check("name white", C.Get("raid", "barNameColorMode"), "WHITE")
H.check("no cell border", C.Get("raid", "borderShow"), false)
H.check("power strip on", C.Get("raid", "powerEnabled"), true)
C.Set("party", "barTexture", "Other")
H.check("not the party frame's look", C.Get("raid", "barTexture") == "Other", false)
C.Set("party", "barTexture", "Flat")
RC.Set("r10", "secondLine", "PERCENT")
RC.Set("r10", "nameClassColor", true)
RC.Set("r10", "cellBorder", true)
RC.Set("r10", "powerStrip", "OFF")
H.check("second line percent", C.Get("raid", "textHealthRight"), "PERCENT")
H.check("name in class colour", C.Get("raid", "barNameColorMode"), "CLASS")
H.check("cell border", C.Get("raid", "borderShow"), true)
H.check("power strip off", C.Get("raid", "powerEnabled"), false)
RC.ResetScope("r10")
H.checkError("a raid cell's settings are not stored", function() assert(C.Set("raid", "width", 50)) end)

-- A header makes cells in a raid.
local function member(name, class, subgroup, role)
    return { name = name, class = class, subgroup = subgroup, assignedRole = role,
        unit = { health = 60, healthMax = 100, healthMissing = 40, powerType = class == "WARRIOR" and 1 or 0 } }
end
local header = CreateFrame("Frame", "TestRaidCells", UIParent, "SecureGroupHeaderTemplate")
header:SetAttribute("template", Cell.TEMPLATE)
header:SetAttribute("showRaid", true)
M.SetRaidRoster({ member("Tank", "WARRIOR", 1, "TANK"), member("Ann", "PRIEST", 1, "HEALER") })
header:Show()
local tank, ann = header:GetAttribute("child1"), header:GetAttribute("child2")
H.check("cell unit", tank.unit, "raid1")
H.check("cell key", tank.key, "raid")
H.check("cells listed", #Cell.buttons, 2)
H.check("cell size from the profile", tank:GetWidth(), 96)
H.check("events for its unit", tank.eventListener._events.UNIT_HEALTH[1], "raid1")
H.checkTrue("click-cast registered", ClickCastFrames[tank])
H.check("left click targets", M.SecureClick(tank, "LeftButton"), "target")
H.check("right click menu", M.SecureClick(tank, "RightButton"), "togglemenu")
H.check("name centred", tank.texts.healthLeft._justifyH, "CENTER")
H.check("name", tank.texts.healthLeft:GetText(), "Tank")
H.check("missing health", tank.texts.healthRight:GetText(), 40)
H.check("health", tank.health:GetValue(), 60)
local onCells = 0
for _, container in ipairs(M.auraContainers) do
    if container:GetParent() == tank or container:GetParent() == ann then onCells = onCells + 1 end
end
-- The unit frames' aura groups stay off (frame.auraGroupKeys); the one
-- container per cell is the cell's own (Raid/CellAuras.lua).
H.check("no unit-frame aura containers on cells", next(tank.auraContainers or {}), nil)
H.check("one container of its own per cell", onCells, 2)
H.check("no castbar", tank.castbar, nil)
H.check("title row hidden", tank.title:IsShown(), false)
local seen = {}
ns.Units.ForEachFrame(function(frame) seen[frame] = true end)
H.checkTrue("every-frame loop reaches cells", seen[tank] and seen[ann])

-- Power strip: mana users by default.
H.check("mana rule: warrior without strip", tank.power:IsShown(), false)
H.checkTrue("mana rule: priest with strip", ann.power:IsShown())
RC.Set("r10", "powerStrip", "HEALERS")
ns.Power.Update(tank)
ns.Power.Update(ann)
H.check("healers: tank without", tank.power:IsShown(), false)
H.checkTrue("healers: healer with", ann.power:IsShown())
M.units.raid1.role = "HEALER"
M.FireEvent("PLAYER_ROLES_ASSIGNED")
H.checkTrue("roles assigned: new healer gets the strip", tank.power:IsShown())
M.units.raid1.role = M.Secret("HEALER")
M.units.raid2.class = M.Secret("PRIEST")
RC.Set("r10", "powerStrip", "MANA")
H.checkTrue("unknown class keeps the strip", Cell.ShowsPower(ann))
RC.Set("r10", "powerStrip", "HEALERS")
H.checkTrue("unknown role keeps the strip", Cell.ShowsPower(tank))
RC.Set("r10", "powerStrip", "ALL")
H.checkTrue("all: everyone", Cell.ShowsPower(tank))
RC.ResetScope("r10")

-- Someone joins in combat: the cell is made at the XML size.
M.combat = true
M.SetRaidRoster({ member("Tank", "WARRIOR", 1, "TANK"), member("Ann", "PRIEST", 1, "HEALER"),
    member("Cid", "MAGE", 1, "DAMAGER") })
local cid = header:GetAttribute("child3")
H.check("combat join: cell made", cid.unit, "raid3")
H.check("combat join: xml width", cid:GetWidth(), 80)
H.check("combat join: data shown", cid.texts.healthLeft:GetText(), "Cid")
H.check("combat join: nothing blocked", #M.blocked, 0)
M.combat = false

-- A roster update that keeps a cell's unit: no new event binding and no
-- RAID_CELLS_CHANGED, but the cell still shows the person now behind it.
-- A cell whose unit changes binds anew.
local binds, cellsChanged = {}, 0
local bind = ns.UnitEvents.Bind
ns.UnitEvents.Bind = function(frame)
    binds[frame] = (binds[frame] or 0) + 1
    return bind(frame)
end
ns.Listen("RAID_CELLS_CHANGED", function() cellsChanged = cellsChanged + 1 end)
M.SetRaidRoster({ member("Tank", "WARRIOR", 1, "TANK"), member("Bea", "PRIEST", 1, "HEALER"),
    member("Cid", "MAGE", 1, "DAMAGER") })
H.check("same unit: no rebind", binds[ann], nil)
H.check("same unit: events kept", ann.eventListener._events.UNIT_HEALTH[1], "raid2")
H.check("same units: no cells-changed", cellsChanged, 0)
H.check("same unit: new person shown", ann.texts.healthLeft:GetText(), "Bea")
M.SetRaidRoster({ member("Tank", "WARRIOR", 1, "TANK"), member("Bea", "PRIEST", 1, "HEALER") })
H.check("cleared unit: rebound", binds[cid], 1)
H.check("cleared unit: no events", cid.eventListener._events.UNIT_HEALTH, nil)
H.check("cleared unit: cells-changed", cellsChanged, 1)
H.check("kept units: still no rebind", binds[tank], nil)
ns.UnitEvents.Bind = bind
