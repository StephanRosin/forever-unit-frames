-- Party targets (Units/PartyTargets.lua): beside each member a small frame
-- with what that member has targeted. Settings, the secure child in the
-- member's template, placement, drawing, the timer and test mode.
local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config
local T = ns.PartyTargets

-- Settings: party only, permanent codes, off by default.
local CODES = { partyTargets = "YA", partyTargetWidth = "YW", partyTargetHeight = "YH",
    partyTargetSide = "YS", partyTargetX = "YX", partyTargetY = "YY" }
for key, code in pairs(CODES) do
    local def = S.Get(key)
    H.checkTrue(key .. " defined", def)
    H.check(key .. " code", def and def.code, code)
    H.checkTrue(key .. " applies to party", S.AppliesTo(def, "party"))
    H.check(key .. " not on player", S.AppliesTo(def, "player"), false)
    H.checkTrue(key .. " labelled", ns.L["SETTING_" .. key] ~= "SETTING_" .. key)
end
C.Use({})
H.check("off by default", C.Get("party", "partyTargets"), false)
H.check("right by default", C.Get("party", "partyTargetSide"), "RIGHT")
H.check("a small gap by default", C.Get("party", "partyTargetX"), 4)
H.check("no separate distance setting", S.Get("partyTargetGap"), nil)
local found
for _, tab in ipairs(ns.Schema.Tabs("party")) do
    for _, sec in ipairs(tab.sections or {}) do
        if sec.id == "partyTargets" then found = tab.id end
    end
end
H.check("in the party group tab", found, "group")

-- The XML declares the child the mock builds.
local xml = H.ReadFile("Units/Party.xml")
H.checkTrue("xml: target child", xml:find('parentKey="targetButton"', 1, true))
H.checkTrue("xml: takes the member's unit", xml:find('<Attribute name="useparent-unit" type="boolean" value="true"/>', 1, true))
H.checkTrue("xml: plus target", xml:find('<Attribute name="unitsuffix" type="string" value="target"/>', 1, true))
H.checkTrue("xml: OnLoad", xml:find("ForeverUnitFrames.PartyTargetOnLoad(self)", 1, true))
H.checkTrue("xml: size = defaults", xml:find('<Size x="100" y="24"/>', 1, true))

M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local header = ns.Party.header
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.units.party2 = { name = "Bob", health = 7, healthMax = 10 }
M.SetGroup({ "party1", "party2" })
local b1 = header:GetAttribute("child1")
local t1 = b1.targetButton
H.checkTrue("member has a target button", t1)
H.check("its scope", t1.key, "partytarget")
H.check("drawing unit follows the member", t1.unit, "party1target")
H.check("off: not watched", t1._unitWatch, nil)
H.check("off: hidden", t1:IsShown(), false)

-- On: watched (the client shows it while the unit exists), sized, placed.
C.Set("party", "partyTargets", true)
H.check("on: watched", t1._unitWatch, true)
H.check("width", t1:GetWidth(), 100)
H.check("height", t1:GetHeight(), 24)
local border = ns.Border.Extent("party") + ns.Border.Extent("partytarget")
local point, rel, relPoint, x, y = t1:GetPoint(1)
H.check("right: point", point .. relPoint, "TOPLEFTTOPRIGHT")
H.check("right: beside its member", rel, b1)
H.check("right: both borders and the default offset", x, border + 4)
C.Set("party", "partyTargetSide", "LEFT")
point, rel, relPoint, x = t1:GetPoint(1)
H.check("left", point .. relPoint, "TOPRIGHTTOPLEFT")
H.check("left: both borders, then the offset (positive: right)", x, -border + 4)
C.Set("party", "partyTargetSide", "BELOW")
point, rel, relPoint, x, y = t1:GetPoint(1)
H.check("below", point .. relPoint, "TOPLEFTBOTTOMLEFT")
H.checkTrue("below: under the member", y < 0)
C.Set("party", "partyTargetSide", "ABOVE")
point, rel, relPoint, x, y = t1:GetPoint(1)
H.check("above", point .. relPoint, "BOTTOMLEFTTOPLEFT")
H.checkTrue("above: over the member", y > 0)
C.Set("party", "partyTargetSide", "RIGHT")
-- Offsets on top of side and gap (positive: right, up).
C.Set("party", "partyTargetX", 11)
C.Set("party", "partyTargetY", -9)
point, rel, relPoint, x, y = t1:GetPoint(1)
H.check("offset x", x, border + 11)
H.check("offset y", y, -9)
C.Set("party", "partyTargetX", 4)
C.Set("party", "partyTargetY", 0)
C.Set("party", "partyTargetWidth", 120)
H.check("width setting", t1:GetWidth(), 120)

-- A small frame: no auras, power or castbar; the name on the bar.
H.check("no buffs", C.Get("partytarget", "buffsEnabled"), false)
H.check("no power bar", C.Get("partytarget", "powerEnabled"), false)
H.check("no castbar", C.Get("partytarget", "castbarEnabled"), false)
H.check("name on the bar", C.Get("partytarget", "textHealthLeft"), "NAME")
H.check("party look otherwise", C.Get("partytarget", "barTexture"), C.Get("party", "barTexture"))

-- Drawing: on the timer, while shown (the watch shows it).
M.units.party1target = { name = "Ogre", health = 30, healthMax = 100, hostile = true }
t1:Show()
T.Tick()
H.check("target's health", t1.health:GetValue(), 30)
M.units.party1target.health = 12
T.Tick()
H.check("refreshed on the timer", t1.health:GetValue(), 12)
M.units.party1target.health = 8
M.FireEvent("UNIT_TARGET", "party1")
H.check("refreshed when the member changes target", t1.health:GetValue(), 8)

-- A member's new unit (the header reorders, in combat too): the drawing
-- unit follows; the secure side resolves it by itself.
M.SetCombat(true)
-- (The header's secure code sets the attribute; its OnAttributeChanged
-- reaches Party.OnUnitChanged.)
ns.Party.OnUnitChanged(b1, "party2")
H.check("in combat: follows the new member", t1.unit, "party2target")
ns.Party.OnUnitChanged(b1, "player")
H.check("the player's own button: your target", t1.unit, "target")
ns.Party.OnUnitChanged(b1, "party1")
M.SetCombat(false)

-- Off again: not watched, hidden.
C.Set("party", "partyTargets", false)
H.check("off: unwatched", t1._unitWatch, nil)
H.check("off: hidden again", t1:IsShown(), false)

-- Test mode: a pretend target beside each pretend member.
C.Set("party", "partyTargets", true)
ns.TestMode.Set(true)
local fake = T.fakes[1]
H.checkTrue("test mode: pretend target", fake and fake:IsShown())
H.check("beside the pretend member", select(2, fake:GetPoint(1)), ns.Party.fakes[1])
C.Set("party", "partyTargetY", 5)
H.check("pretend target: offset too", select(5, fake:GetPoint(1)), 5)
C.Set("party", "partyTargetY", 0)
H.check("live buttons not watched in test mode", t1._unitWatch, nil)
ns.TestMode.Set(false)
H.check("test mode off: pretend hidden", fake:IsShown(), false)
H.check("test mode off: watched again", t1._unitWatch, true)
