local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config

-- Settings: party only, permanent codes.
local CODES = { partyShowPets = "PT", partyPetHeight = "PH", partyPetAuras = "PA" }
for key, code in pairs(CODES) do
    local def = S.Get(key)
    H.checkTrue(key .. " defined", def)
    if def then
        H.check(key .. " code", def.code, code)
        H.checkTrue(key .. " applies to party", S.AppliesTo(def, "party"))
        H.check(key .. " not on player", S.AppliesTo(def, "player"), false)
        H.check(key .. " not on general", S.AppliesTo(def, "general"), false)
    end
end
C.Use({})
H.check("pets off by default (plain)", C.Get("party", "partyShowPets"), false)
H.check("pet height default", C.Get("party", "partyPetHeight"), 20)
H.check("pet height min", S.Get("partyPetHeight").min, 10)
H.check("pet height max", S.Get("partyPetHeight").max, 60)
H.check("pet auras off by default", C.Get("party", "partyPetAuras"), false)

-- Codec round trip for the new codes.
C.Set("party", "partyShowPets", true)
C.Set("party", "partyPetHeight", 24)
C.Set("party", "partyPetAuras", true)
local s = ns.Codec.Encode(C.Profile())
H.check("encoded pets", s, "1;yPA1;yPH24;yPT1")
local back = assert(ns.Codec.Decode(s))
H.check("decoded show pets", back.party.partyShowPets, true)
H.check("decoded pet height", back.party.partyPetHeight, 24)
H.check("decoded pet auras", back.party.partyPetAuras, true)

-- Options: a "Pets" section in the party Layout tab, with English texts.
local found
for _, tab in ipairs(ns.Schema.Tabs("party")) do
    if tab.id == "layout" then
        for _, sec in ipairs(tab.sections) do
            if sec.id == "pets" then found = sec end
        end
    end
end
H.checkTrue("pets section in the layout tab", found)
if found then
    H.check("pets section keys", table.concat(found.keys, ","), "partyShowPets,partyPetHeight,partyPetAuras")
end
H.check("section title", ns.L.SECTION_pets, "Pets")
for key in pairs(CODES) do
    H.checkTrue(key .. " label", ns.L["SETTING_" .. key] ~= "SETTING_" .. key)
end

-- The shipped look shows pets.
local shipped = H.LoadShipped()
shipped.Config.Use({})
H.check("shipped: pets on", shipped.Config.Get("party", "partyShowPets"), true)

-- The XML template and the mock mirror of it agree.
local xml = H.ReadFile("Units/PartyPets.xml")
H.checkTrue("xml: template name", xml:find('name="ForeverUnitFramesPartyPetButtonTemplate"', 1, true))
H.checkTrue("xml: secure unit button", xml:find('inherits="SecureUnitButtonTemplate"', 1, true))
H.checkTrue("xml: clicks", xml:find('registerForClicks="AnyUp"', 1, true))
H.checkTrue("xml: size = defaults", xml:find('<Size x="160" y="20"/>', 1, true))
H.checkTrue("xml: left click targets", xml:find('<Attribute name="*type1" type="string" value="target"/>', 1, true))
H.checkTrue("xml: right click menu", xml:find('<Attribute name="*type2" type="string" value="togglemenu"/>', 1, true))
H.checkTrue("xml: OnLoad", xml:find("ForeverUnitFrames.PartyPetButtonOnLoad(self)", 1, true))
H.checkTrue("xml: OnAttributeChanged",
    xml:find("ForeverUnitFrames.PartyPetButtonOnAttributeChanged(self, name, value)", 1, true))
H.checkTrue("xml: no snippet", not xml:find("initialConfigFunction", 1, true))
C.Use({})
H.check("xml width = party width", C.Get("party", "width"), 160)
H.check("xml height = pet height", C.Get("party", "partyPetHeight"), 20)
local toc = H.ReadFile("ForeverUnitFrames.toc")
H.checkTrue("toc lists the xml after the lua", toc:find("Units\\PartyPets.lua\nUnits\\PartyPets.xml", 1, true))

-- Live ------------------------------------------------------------------------
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
C, S = ns.Config, ns.Settings
local P, Pets = ns.Party, ns.PartyPets
local header, pets = P.header, Pets.header
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10 }

-- A pet header, mirroring the party header; hidden while pets are off.
H.checkTrue("pet header built", pets)
H.check("pet header template", pets._template, "SecureGroupPetHeaderTemplate")
H.check("pet header name", pets:GetName(), "ForeverUnitFramesPartyPets")
H.check("pet child template", pets:GetAttribute("template"), "ForeverUnitFramesPartyPetButtonTemplate")
H.check("no snippet attribute", pets:GetAttribute("initialConfigFunction"), nil)
H.check("off: pet header hidden", pets:IsShown(), false)
H.check("off: party spacing", header:GetAttribute("yOffset"), -(12 + 13))

C.Set("party", "partyShowPets", true)
H.checkTrue("on: pet header shown", pets:IsShown())
H.checkTrue("shows in a party", pets:GetAttribute("showParty"))
H.check("player like the party", pets:GetAttribute("showPlayer"), false)
H.check("solo like the party", pets:GetAttribute("showSolo"), false)
H.check("sorted by index", pets:GetAttribute("sortMethod"), "INDEX")
H.check("stacked downwards", pets:GetAttribute("point"), "TOP")
-- Between pets: gap 2 and both rings (1 each).
H.check("step between pets", pets:GetAttribute("yOffset"), -(2 + 1 + 1))
H.check("x offset", pets:GetAttribute("xOffset"), 0)
-- Pets do not move the members.
H.check("on: party spacing unchanged", header:GetAttribute("yOffset"), -(12 + 13))
local w, h = P.BlockSize()
H.check("block height unchanged", h, 4 * 46 + 3 * 25)
-- Under the members' header: last member's castbar (12) and ring (1), the
-- gap (2), the first pet's ring (1).
local point, rel, relPoint, x, y = pets:GetPoint(1)
H.check("hangs top left", point, "TOPLEFT")
H.check("from the party header", rel, header)
H.check("from its bottom left", relPoint, "BOTTOMLEFT")
H.check("x", x, 0)
H.check("y", y, -(12 + 1 + 2 + 1))
H.check("one anchor", #pets._points, 1)

-- Solo, not shown solo: nothing, even with a pet out.
M.units.pet = { name = "Wolf", health = 3, healthMax = 4 }
M.FireEvent("UNIT_PET", "player")
H.check("solo: no pet button in use", pets:GetAttribute("child1"):GetAttribute("unit"), nil)
C.Set("party", "partyShowPlayer", true)
H.check("solo with show player: still nothing", pets:GetAttribute("child1"):GetAttribute("unit"), nil)
C.Set("party", "partyShowSolo", true)
H.check("shown solo: your pet", pets:GetAttribute("child1"):GetAttribute("unit"), "pet")
C.Set("party", "partyShowPlayer", false)
H.check("shown solo without show player: your pet", pets:GetAttribute("child1"):GetAttribute("unit"), "pet")
C.Set("party", "partyShowSolo", false)
H.check("not shown solo again", pets:GetAttribute("child1"):GetAttribute("unit"), nil)

-- In a party: existing pets only, packed, no holes.
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.units.party2 = { name = "Bob", health = 5, healthMax = 10 }
M.units.party3 = { name = "Cid", health = 5, healthMax = 10 }
M.units.partypet2 = { name = "Cat", health = 1, healthMax = 4 }
M.units.partypet3 = { name = "Imp", health = 2, healthMax = 4 }
M.SetGroup({ "party1", "party2", "party3" })
local b1, b2 = pets:GetAttribute("child1"), pets:GetAttribute("child2")
H.check("first listed: party2's pet", b1:GetAttribute("unit"), "partypet2")
H.check("second: party3's pet", b2:GetAttribute("unit"), "partypet3")
H.check("lua unit", b1.unit, "partypet2")
H.check("button key", b1.key, "partypet")
H.check("button width = member", b1:GetWidth(), 160)
H.check("button height", b1:GetHeight(), 20)
H.check("second below the first", select(2, b2:GetPoint(1)), b1)
H.check("pet health", b1.health:GetValue(), 1)
H.check("pet events for its unit", b1.eventListener._events.UNIT_HEALTH[1], "partypet2")
M.units.partypet2.health = 3
M.FireEvent("UNIT_HEALTH", "partypet2")
H.check("pet health event", b1.health:GetValue(), 3)
-- A pet appears: the header lists it in its place.
M.units.partypet1 = { name = "Owl", health = 4, healthMax = 4 }
M.FireEvent("UNIT_PET", "party1")
H.check("new pet first", pets:GetAttribute("child1"):GetAttribute("unit"), "partypet1")
H.check("then party2's", pets:GetAttribute("child2"):GetAttribute("unit"), "partypet2")
-- With the player shown, your pet leads.
C.Set("party", "partyShowPlayer", true)
H.check("your pet first", pets:GetAttribute("child1"):GetAttribute("unit"), "pet")
C.Set("party", "partyShowPlayer", false)

-- The pet's own look: health bar with the name, nothing else.
H.check("no title row", C.Get("partypet", "titlePercent"), 0)
H.check("no power bar", C.Get("partypet", "powerEnabled"), false)
H.check("no castbar", C.Get("partypet", "castbarEnabled"), false)
H.check("no class badge", C.Get("partypet", "titleClassIcon"), false)
H.check("no portrait", C.Get("partypet", "portraitMode"), "OFF")
H.check("no elite marker", C.Get("partypet", "eliteMarker"), false)
H.check("no combat text", C.Get("partypet", "combatFeedback"), false)
H.check("name on the health bar", C.Get("partypet", "textHealthLeft"), "NAME")
H.check("no buffs by default", C.Get("partypet", "buffsEnabled"), false)
H.check("no debuffs by default", C.Get("partypet", "debuffsEnabled"), false)
H.check("width follows party", C.Get("partypet", "width"), 160)
H.check("height from the pet setting", C.Get("partypet", "height"), 20)
H.check("everything else follows party", C.Get("partypet", "borderSize"), C.Get("party", "borderSize"))
b1 = pets:GetAttribute("child1")
H.check("no castbar built", b1.castbar, nil)
H.check("no elite layer built", b1.eliteLayer, nil)
H.check("title row hidden", b1.title:IsShown(), false)
H.check("power bar hidden", b1.power:IsShown(), false)
C.Set("party", "partyPetAuras", true)
H.check("pet auras follow party debuffs", C.Get("partypet", "debuffsEnabled"), true)
C.Set("party", "partyPetAuras", false)
H.check("pet scope cannot be set", C.Set("partypet", "width", 300), false)

-- Taller pets; castbar above or off; shadow.
C.Set("party", "partyPetHeight", 30)
H.check("taller pet", b1:GetHeight(), 30)
C.Set("party", "partyPetHeight", 20)
C.Set("party", "castbarDock", "ABOVE")
H.check("dock above: just the ring", select(5, pets:GetPoint(1)), -(1 + 2 + 1))
C.Set("party", "castbarDock", "BELOW")
C.Set("party", "castbarEnabled", false)
H.check("no castbar: just the ring", select(5, pets:GetPoint(1)), -(1 + 2 + 1))
C.Set("party", "shadowEnabled", true)
C.Set("party", "shadowSize", 4)
H.check("shadow: room below the block", select(5, pets:GetPoint(1)), -(1 + 2 + 4 + 1))
H.check("shadow: room between pets", pets:GetAttribute("yOffset"), -(2 + 4 + 1 + 1))
C.Set("party", "shadowEnabled", false)
C.Set("party", "castbarEnabled", true)

-- Horizontal: a row of pets under the row of members.
C.Set("party", "partyOrientation", "HORIZONTAL")
H.check("horizontal: pets in a row", pets:GetAttribute("point"), "LEFT")
H.check("horizontal: step", pets:GetAttribute("xOffset"), 4)
H.check("horizontal: y offset", pets:GetAttribute("yOffset"), 0)
H.check("horizontal: still under the members", select(3, pets:GetPoint(1)), "BOTTOMLEFT")
b2 = pets:GetAttribute("child2")
H.check("horizontal: one anchor", #b2._points, 1)
H.check("horizontal: anchored left", b2:GetPoint(1), "LEFT")
C.Set("party", "partyOrientation", "VERTICAL")
H.check("vertical again: anchored top", b2:GetPoint(1), "TOP")

-- A pet summoned in combat: XML size until combat ends.
-- (You and three pets so far use four buttons; the fifth is new.)
C.Set("party", "partyShowPlayer", true)
C.Set("party", "width", 180)
H.check("four buttons so far", pets:GetAttribute("child5"), nil)
M.combat = true
M.units.party4 = { name = "Dan", health = 5, healthMax = 10 }
M.units.partypet4 = { name = "Bat", health = 2, healthMax = 4 }
M.SetGroup({ "party1", "party2", "party3", "party4" })
local b5 = pets:GetAttribute("child5")
H.check("combat: button made", b5:GetAttribute("unit"), "partypet4")
H.check("combat: xml width", b5:GetWidth(), 160)
H.check("combat: data already shown", b5.health:GetValue(), 2)
M.SetCombat(false)
H.check("after combat: sized", b5:GetWidth(), 180)
C.Set("party", "partyShowPlayer", false)

-- Party off or pets off: the pet header hides.
C.Set("party", "enabled", false)
H.check("party off: hidden", pets:IsShown(), false)
C.Set("party", "enabled", true)
H.checkTrue("party on: shown", pets:IsShown())
C.Set("party", "partyShowPets", false)
H.check("pets off: hidden", pets:IsShown(), false)
C.Set("party", "partyShowPets", true)
C.Set("party", "width", 160)

-- Test mode: pretend pets under the pretend block, made once.
M.SetGroup({})
H.checkTrue("test mode on", ns.TestMode.Set(true))
H.check("real pet header hidden", pets:IsShown(), false)
H.check("pretend pets", #Pets.fakes, 4)
local _, blockH = P.BlockSize()
for i, b in ipairs(Pets.fakes) do
    H.check("fake pet " .. i .. " unit", b:GetAttribute("unit"), "player")
    H.check("fake pet " .. i .. " secure", b._template, "SecureUnitButtonTemplate")
    H.checkTrue("fake pet " .. i .. " pretend", b.pretend)
    H.checkTrue("fake pet " .. i .. " shown", b:IsShown())
    H.check("fake pet " .. i .. " key", b.key, "partypet")
    local _, frel, _, fx, fy = b:GetPoint(1)
    H.check("fake pet " .. i .. " on the test block", frel, P.testBlock)
    H.check("fake pet " .. i .. " x", fx, 0)
    H.check("fake pet " .. i .. " y", fy, -(blockH + 16) - (i - 1) * (20 + 4))
end
local first = Pets.fakes[1]
C.Set("party", "partyOrientation", "HORIZONTAL")
H.check("horizontal fake 2 x", select(4, Pets.fakes[2]:GetPoint(1)), 160 + 4)
H.check("horizontal fake 2 y", select(5, Pets.fakes[2]:GetPoint(1)), -(46 + 16))
C.Set("party", "partyOrientation", "VERTICAL")
C.Set("party", "partyShowPets", false)
H.check("pets off in test mode: fake hidden", first:IsShown(), false)
C.Set("party", "partyShowPets", true)
H.checkTrue("pets on in test mode: fake back", first:IsShown())
ns.TestMode.Set(false)
H.check("test mode off: fake hidden", first:IsShown(), false)
H.check("test mode off: fake quiet", first.unit, nil)
H.checkTrue("test mode off: real header back", pets:IsShown())
ns.TestMode.Set(true)
H.check("made once", Pets.fakes[1], first)
H.check("still four", #Pets.fakes, 4)
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat start: fake hidden", first:IsShown(), false)
H.checkTrue("combat start: real header back", pets:IsShown())

-- Logged in with the shipped look: the pet list hangs from the party
-- header, which hangs from the block's mover, so dragging moves both.
ns = H.LoadShipped()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.checkTrue("shipped: pet header shown", ns.PartyPets.header:IsShown())
H.check("shipped: under the party header", select(2, ns.PartyPets.header:GetPoint(1)), ns.Party.header)
H.check("shipped: party header on the mover", select(2, ns.Party.header:GetPoint(1)), ns.Party.header.mover)

-- Blizzard's party member frames carry a pet frame of their own
-- (PartyMemberFrame.PetFrame); it goes with the member.
ns = H.LoadAddon()
ns.Config.Use({})
_G.PartyFrame = M.newWidget("Frame", "PartyFrame")
local member = M.newWidget("Button", "PartyMember1")
member._protected = true
member.PetFrame = M.newWidget("Button", "PartyMember1PetFrame", member)
member.PetFrame._protected = true
_G.PartyFrame.PartyMemberFramePool = { EnumerateActive = function() return pairs({ [member] = true }) end }
ns.Blizzard.HideDefaults()
H.check("blizzard pet frame: invisible", member.PetFrame:GetAlpha(), 0)
H.check("blizzard pet frame: mouse off", member.PetFrame._mouse, false)
H.check("blizzard pet frame: hidden", member.PetFrame:IsShown(), false)
_G.PartyFrame = nil
