local M = H.M
local ns = H.LoadAddon()

-- The XML template and the mock mirror of it agree.
local xml = H.ReadFile("Units/Party.xml")
H.checkTrue("xml: template name", xml:find('name="ForeverUnitFramesPartyButtonTemplate"', 1, true))
H.checkTrue("xml: secure unit button", xml:find('inherits="SecureUnitButtonTemplate"', 1, true))
H.checkTrue("xml: clicks", xml:find('registerForClicks="AnyUp"', 1, true))
H.checkTrue("xml: size = party defaults", xml:find('<Size x="160" y="46"/>', 1, true))
H.checkTrue("xml: left click targets", xml:find('<Attribute name="*type1" type="string" value="target"/>', 1, true))
H.checkTrue("xml: right click menu", xml:find('<Attribute name="*type2" type="string" value="togglemenu"/>', 1, true))
H.checkTrue("xml: OnLoad", xml:find("ForeverUnitFrames.PartyButtonOnLoad(self)", 1, true))
H.checkTrue("xml: OnAttributeChanged",
    xml:find("ForeverUnitFrames.PartyButtonOnAttributeChanged(self, name, value)", 1, true))
H.checkTrue("xml: no snippet", not xml:find("initialConfigFunction", 1, true))
H.check("default width = xml", ns.Settings.Default(ns.Settings.Get("width"), "party"), 160)
H.check("default height = xml", ns.Settings.Default(ns.Settings.Get("height"), "party"), 46)
local toc = H.ReadFile("ForeverUnitFrames.toc")
H.checkTrue("toc lists the xml after the lua",
    toc:find("Units\\Party.lua\nUnits\\Party.xml", 1, true))

ns.Config.Use({})
ns.Single.CreateAll()
local header = ns.Party.Create()
H.checkTrue("header built", header)
H.check("header template", header._template, "SecureGroupHeaderTemplate")
H.check("header name", header:GetName(), "ForeverUnitFramesParty")
H.check("child template", header:GetAttribute("template"), "ForeverUnitFramesPartyButtonTemplate")
H.check("no snippet attribute", header:GetAttribute("initialConfigFunction"), nil)
H.checkTrue("shows in a party", header:GetAttribute("showParty"))
H.checkTrue("header shown", header:IsShown())
local point, rel, relPoint, x, y = header:GetPoint(1)
H.check("block anchored top left", point, "TOPLEFT")
H.check("block x from centre", x, -760 - 80)
-- Between members: spacing 12 plus the docked castbar (12, flush, border 1).
-- The block is 259 high (4 * 46 + 3 * 25): centred at 120 its top would
-- sit on a half pixel (249.5); on the pixel grid (one unit here) it
-- moves to 249.
H.check("block y from centre", y, 249)

-- Solo: no member buttons in use.
H.check("solo: first button has no unit", header:GetAttribute("child1"):GetAttribute("unit"), nil)
H.check("solo: first button hidden", header:GetAttribute("child1"):IsShown(), false)

-- Joining a party: one button per member, sized and styled from settings.
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.units.party2 = { name = "Bob", health = 7, healthMax = 10 }
ns.Config.Set("party", "width", 180)
M.SetGroup({ "party1", "party2" })
local b1, b2 = header:GetAttribute("child1"), header:GetAttribute("child2")
H.check("button 1 unit", b1:GetAttribute("unit"), "party1")
H.check("button 2 unit", b2:GetAttribute("unit"), "party2")
H.check("lua unit field", b2.unit, "party2")
H.check("button key", b1.key, "party")
H.check("button width from settings", b2:GetWidth(), 180)
H.check("button height from settings", b2:GetHeight(), 46)
H.check("button health", b2.health:GetValue(), 7)
H.check("button events for its unit", b2.eventListener._events.UNIT_HEALTH[1], "party2")
M.units.party2.health = 3
M.FireEvent("UNIT_HEALTH", "party2")
H.check("member event updates the button", b2.health:GetValue(), 3)
H.check("other member untouched", b1.health:GetValue(), 5)
H.check("left click", b1:GetAttribute("*type1"), "target")
H.check("second stacked below the first", select(2, b2:GetPoint(1)), b1)

-- Someone joins in combat: the header makes the button (XML size), the
-- settings size follows after combat.
M.units.party3 = { name = "Cid", health = 9, healthMax = 10 }
M.combat = true
M.SetGroup({ "party1", "party2", "party3" })
local b3 = header:GetAttribute("child3")
H.check("combat join: button made", b3:GetAttribute("unit"), "party3")
H.check("combat join: xml width until combat ends", b3:GetWidth(), 160)
H.check("combat join: data already shown", b3.health:GetValue(), 9)
M.SetCombat(false)
H.check("combat join: sized after combat", b3:GetWidth(), 180)

-- Settings changes restyle every button; disabling hides the block.
ns.Config.Set("party", "height", 40)
H.check("restyle height", b1:GetHeight(), 40)
ns.Config.Set("party", "enabled", false)
H.check("disabled: header hidden", header:IsShown(), false)
ns.Config.Set("party", "enabled", true)
H.checkTrue("enabled again: header shown", header:IsShown())

-- The header only SetPoints shown buttons; switching orientation must not
-- leave a button anchored on both its old and its new point.
ns.Config.Set("party", "partyOrientation", "HORIZONTAL")
for i, b in ipairs({ b1, b2, b3 }) do
    H.check("horizontal: button " .. i .. " has one anchor", #b._points, 1)
    H.check("horizontal: button " .. i .. " anchored left", b:GetPoint(1), "LEFT")
end
ns.Config.Set("party", "partyOrientation", "VERTICAL")
for i, b in ipairs({ b1, b2, b3 }) do
    H.check("vertical again: button " .. i .. " has one anchor", #b._points, 1)
    H.check("vertical again: button " .. i .. " anchored top", b:GetPoint(1), "TOP")
end
H.check("header width = button width", header:GetWidth(), 180)

-- Leaving the group clears the buttons.
M.SetGroup({})
H.check("left group: unit cleared", b1:GetAttribute("unit"), nil)
H.check("left group: events unbound", next(b1.eventListener._events), nil)

-- Built at login together with the single frames.
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
H.checkTrue("login: header built", ns.Party.header)
H.checkTrue("login: header shown", ns.Party.header:IsShown())

-- Joining in combat from solo: the header sizes itself from child 1 while
-- it still has its XML size. After combat the block is laid out again, so
-- the header matches the configured size and the buttons stay centred.
ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
ns.Config.Set("party", "width", 200)
header = ns.Party.Create()
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.combat = true
M.SetGroup({ "party1" })
H.check("combat join from solo: member assigned", header:GetAttribute("child1"):GetAttribute("unit"), "party1")
M.SetCombat(false)
H.check("combat join from solo: button width", header:GetAttribute("child1"):GetWidth(), 200)
H.check("combat join from solo: header width", header:GetWidth(), 200)
H.check("combat join from solo: header height", header:GetHeight(), 46)
