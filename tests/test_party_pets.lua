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

-- Live ------------------------------------------------------------------------
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
C, S = ns.Config, ns.Settings
local P, Pets = ns.Party, ns.PartyPets
local header = P.header
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10 }

-- Off: no pet frames at all, spacing as before.
H.check("off: no pet buttons", #Pets.buttons, 0)
H.check("off: spacing without pets", header:GetAttribute("yOffset"), -(12 + 13))
H.check("off: no pet row", P.PetRow(), 0)

-- On, in a party: one pet frame per slot, under its owner's slot.
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.SetGroup({ "party1" })
C.Set("party", "partyShowPets", true)
H.check("on: one per slot", #Pets.buttons, 4)
for i, b in ipairs(Pets.buttons) do
    H.check("pet " .. i .. " unit", b:GetAttribute("unit"), "partypet" .. i)
    H.check("pet " .. i .. " lua unit", b.unit, "partypet" .. i)
    H.check("pet " .. i .. " key", b.key, "partypet")
    H.check("pet " .. i .. " secure", b._template, "SecureUnitButtonTemplate")
    H.check("pet " .. i .. " clicks target", b:GetAttribute("*type1"), "target")
    H.check("pet " .. i .. " menu", b:GetAttribute("*type2"), "togglemenu")
    H.checkTrue("pet " .. i .. " shown by unit watch", b._unitWatch)
    H.check("pet " .. i .. " width = member", b:GetWidth(), 160)
    H.check("pet " .. i .. " height", b:GetHeight(), 20)
end
H.check("not a header", Pets.buttons[1]._template ~= "SecureGroupPetHeaderTemplate", true)

-- Pet row: gap 2, the pet's border on both sides (1 each), the pet.
H.check("pet row", P.PetRow(), 2 + 1 + 20 + 1)
H.check("spacing makes room for the pet row", header:GetAttribute("yOffset"), -(12 + 13 + 24))
-- Below the member's docked castbar and its border, the gap, the pet's border.
H.check("pet offset below the member", P.PetOffset(), 46 + 13 + 2 + 1)
local w, h = P.BlockSize()
H.check("block width", w, 160)
H.check("block height counts the last pet", h, 4 * 46 + 3 * 49 + (62 - 46 + 20))
local _, rel, relPoint, hx, hy = header:GetPoint(1)
for i, b in ipairs(Pets.buttons) do
    local point, prel, prelPoint, px, py = b:GetPoint(1)
    H.check("pet " .. i .. " top left", point, "TOPLEFT")
    H.check("pet " .. i .. " same anchor as the block", prel, rel)
    H.check("pet " .. i .. " same relative point", prelPoint, relPoint)
    H.check("pet " .. i .. " x", px, hx)
    H.check("pet " .. i .. " y", py, hy - (i - 1) * (46 + 49) - 62)
end
-- A pet ends above the next member's top: no overlap.
H.checkTrue("pet clears the next member", 62 + 20 + 1 <= 46 + 49)

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
local pet1 = Pets.buttons[1]
H.check("no castbar built", pet1.castbar, nil)
H.check("no elite layer built", pet1.eliteLayer, nil)
H.checkTrue("health bar built", pet1.health)
H.check("title row hidden", pet1.title:IsShown(), false)
H.check("power bar hidden", pet1.power:IsShown(), false)
C.Set("party", "partyPetAuras", true)
H.check("pet auras follow party buffs", C.Get("partypet", "buffsEnabled"), C.Get("party", "buffsEnabled"))
H.check("pet auras follow party debuffs", C.Get("partypet", "debuffsEnabled"), true)
C.Set("party", "partyPetAuras", false)
H.check("pet scope cannot be set", C.Set("partypet", "width", 300), false)

-- Unit binding: events and data for partypetN.
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.units.partypet1 = { name = "Wolf", health = 3, healthMax = 4 }
M.SetGroup({ "party1" })
H.check("pet events for its unit", pet1.eventListener._events.UNIT_HEALTH[1], "partypet1")
H.check("pet health after roster change", pet1.health:GetValue(), 3)
M.units.partypet1 = { name = "Cat", health = 1, healthMax = 4 }
M.FireEvent("UNIT_PET", "party1")
H.check("new pet after UNIT_PET", pet1.health:GetValue(), 1)
M.units.partypet1.health = 2
M.FireEvent("UNIT_HEALTH", "partypet1")
H.check("pet health event", pet1.health:GetValue(), 2)

-- Taller pets widen the room between members.
C.Set("party", "partyPetHeight", 30)
H.check("taller pet", pet1:GetHeight(), 30)
H.check("taller pet: more room", header:GetAttribute("yOffset"), -(12 + 13 + 34))
C.Set("party", "partyPetHeight", 20)

-- Castbar above the member: the pet follows the member's border directly.
C.Set("party", "castbarDock", "ABOVE")
H.check("dock above: pet offset", P.PetOffset(), 46 + 1 + 2 + 1)
H.check("dock above: same spacing", header:GetAttribute("yOffset"), -(12 + 13 + 24))
C.Set("party", "castbarDock", "BELOW")
C.Set("party", "castbarEnabled", false)
H.check("no castbar: pet offset", P.PetOffset(), 46 + 1 + 2 + 1)
H.check("no castbar: spacing", header:GetAttribute("yOffset"), -(12 + 24))
C.Set("party", "castbarEnabled", true)

-- Horizontal: pets under their owners, the step between members unchanged.
C.Set("party", "partyOrientation", "HORIZONTAL")
H.check("horizontal: step", header:GetAttribute("xOffset"), 12)
_, rel, relPoint, hx, hy = header:GetPoint(1)
for i, b in ipairs(Pets.buttons) do
    local _, _, _, px, py = b:GetPoint(1)
    H.check("horizontal pet " .. i .. " x", px, hx + (i - 1) * (160 + 12))
    H.check("horizontal pet " .. i .. " y", py, hy - 62)
    H.check("horizontal pet " .. i .. " one anchor", #b._points, 1)
end
w, h = P.BlockSize()
H.check("horizontal block height", h, 62 + 20)
C.Set("party", "partyOrientation", "VERTICAL")

-- With the player first, slot 1 is your own pet.
C.Set("party", "partyShowPlayer", true)
H.check("five slots", #Pets.buttons, 5)
H.check("slot 1: your pet", Pets.buttons[1]:GetAttribute("unit"), "pet")
H.check("slot 2: party1's pet", Pets.buttons[2]:GetAttribute("unit"), "partypet1")
H.check("slot 5: party4's pet", Pets.buttons[5]:GetAttribute("unit"), "partypet4")
C.Set("party", "partyShowPlayer", false)
H.check("back to four", Pets.buttons[1]:GetAttribute("unit"), "partypet1")
H.check("fifth released", Pets.buttons[5]._unitWatch, nil)
H.check("fifth hidden", Pets.buttons[5]:IsShown(), false)

-- Changes in combat wait for its end.
M.combat = true
C.Set("party", "width", 180)
H.check("combat: size kept", pet1:GetWidth(), 160)
M.SetCombat(false)
H.check("after combat: resized", pet1:GetWidth(), 180)

-- Party off, or pets off: no unit watch, hidden.
C.Set("party", "enabled", false)
H.check("party off: no unit watch", pet1._unitWatch, nil)
H.check("party off: hidden", pet1:IsShown(), false)
C.Set("party", "enabled", true)
H.checkTrue("party on: unit watch", pet1._unitWatch)
C.Set("party", "partyShowPets", false)
H.check("pets off: no unit watch", pet1._unitWatch, nil)
H.check("pets off: hidden", pet1:IsShown(), false)
H.check("pets off: spacing back", header:GetAttribute("yOffset"), -(12 + 13))
C.Set("party", "partyShowPets", true)

-- Test mode: pretend pets under the pretend members, made once.
H.checkTrue("test mode on", ns.TestMode.Set(true))
H.check("pretend pets", #Pets.fakes, 4)
for i, b in ipairs(Pets.fakes) do
    H.check("fake pet " .. i .. " unit", b:GetAttribute("unit"), "player")
    H.check("fake pet " .. i .. " secure", b._template, "SecureUnitButtonTemplate")
    H.checkTrue("fake pet " .. i .. " pretend", b.pretend)
    H.checkTrue("fake pet " .. i .. " shown", b:IsShown())
    H.check("fake pet " .. i .. " key", b.key, "partypet")
    local _, frel, _, fx, fy = b:GetPoint(1)
    H.check("fake pet " .. i .. " on the test block", frel, P.testBlock)
    H.check("fake pet " .. i .. " x", fx, 0)
    H.check("fake pet " .. i .. " y", fy, -(i - 1) * (46 + 49) - 62)
end
H.check("real pets: no unit watch in test mode", pet1._unitWatch, nil)
H.check("real pets hidden in test mode", pet1:IsShown(), false)
H.check("test block counts the last pet", P.testBlock:GetHeight(), 4 * 46 + 3 * 49 + 36)
local first = Pets.fakes[1]
C.Set("party", "partyShowPets", false)
H.check("pets off in test mode: fake hidden", first:IsShown(), false)
C.Set("party", "partyShowPets", true)
H.checkTrue("pets on in test mode: fake back", first:IsShown())
ns.TestMode.Set(false)
H.check("test mode off: fake hidden", first:IsShown(), false)
H.check("test mode off: fake quiet", first.unit, nil)
H.checkTrue("test mode off: real pets watched", pet1._unitWatch)
ns.TestMode.Set(true)
H.check("made once", Pets.fakes[1], first)
H.check("still four", #Pets.fakes, 4)
-- Combat start ends test mode and releases the pretend pets.
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat start: fake hidden", first:IsShown(), false)
H.checkTrue("combat start: real pets watched", pet1._unitWatch)

-- Blizzard's party member frames carry a pet frame of their own
-- (PartyMemberFrame.PetFrame); it goes with the member.
ns = H.LoadAddon()
ns.Config.Use({})
_G.PartyFrame = M.newWidget("Frame", "PartyFrame")
local member = M.newWidget("Button", "PartyMember1")
member._protected = true
member.PetFrame = M.newWidget("Button", "PartyMember1PetFrame", member)
member.PetFrame._protected = true
member.PetFrame:RegisterEvent("UNIT_PET")
_G.PartyFrame.PartyMemberFramePool = { EnumerateActive = function() return pairs({ [member] = true }) end }
ns.Blizzard.HideDefaults()
H.check("blizzard pet frame: invisible", member.PetFrame:GetAlpha(), 0)
H.check("blizzard pet frame: mouse off", member.PetFrame._mouse, false)
H.check("blizzard pet frame: hidden", member.PetFrame:IsShown(), false)
_G.PartyFrame = nil

-- Fix round 1 -------------------------------------------------------------------

-- Pets follow the party header's own rule: shown in a group, or solo only
-- with "show when solo" (then slot 1 is you, so your pet).
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
C, P, Pets = ns.Config, ns.Party, ns.PartyPets
C.Set("party", "partyShowPets", true)
C.Set("party", "partyShowPlayer", true)
local function watched()
    local n = 0
    for _, b in ipairs(Pets.buttons) do if b._unitWatch then n = n + 1 end end
    return n
end
H.check("solo, not shown solo: header empty", P.header:GetAttribute("child1"):GetAttribute("unit"), nil)
H.check("solo, not shown solo: no pet watched", watched(), 0)
H.checkTrue("solo, not shown solo: no pet shown", not (Pets.buttons[1] and Pets.buttons[1]:IsShown()))
C.Set("party", "partyShowSolo", true)
H.check("solo shown: one pet watched", watched(), 1)
H.check("solo shown: your pet", Pets.buttons[1]:GetAttribute("unit"), "pet")
C.Set("party", "partyShowPlayer", false)
H.check("solo shown without show player: still your pet", Pets.buttons[1]:GetAttribute("unit"), "pet")
H.check("solo shown without show player: one watched", watched(), 1)
C.Set("party", "partyShowSolo", false)
C.Set("party", "partyShowPlayer", true)
H.check("solo hidden again", watched(), 0)
-- Joining a group re-evaluates the slots.
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.units.party2 = { name = "Bob", health = 5, healthMax = 10 }
M.SetGroup({ "party1", "party2" })
H.check("grouped: every slot watched", watched(), 5)
H.check("grouped: slot 1 your pet", Pets.buttons[1]:GetAttribute("unit"), "pet")
H.check("grouped: slot 2 party1's pet", Pets.buttons[2]:GetAttribute("unit"), "partypet1")
-- Leaving in combat: released once combat ends.
M.combat = true
M.SetGroup({})
H.check("left in combat: unchanged until combat ends", watched(), 5)
M.SetCombat(false)
H.check("left: released after combat", watched(), 0)
-- Joining in combat: watched once combat ends.
M.combat = true
M.SetGroup({ "party1" })
H.check("joined in combat: waits", watched(), 0)
M.SetCombat(false)
H.check("joined: watched after combat", watched(), 5)

-- The drop shadow sits between member and pet: the gap makes room for it.
C.Set("party", "castbarEnabled", false)
local plainOffset, plainRow = P.PetOffset(), P.PetRow()
C.Set("party", "shadowEnabled", true)
C.Set("party", "shadowSize", 4)
H.check("shadow: pet further down", P.PetOffset(), plainOffset + 4)
H.check("shadow: pet row larger", P.PetRow(), plainRow + 4)
C.Set("party", "shadowEnabled", false)
H.check("shadow off: plain gap", P.PetOffset(), plainOffset)

-- Logged in while grouped: pets hang from the block's mover, so they
-- follow it while it is dragged.
ns = H.LoadShipped()
_G.ForeverUnitFramesDB = nil
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.group = { "party1" }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local mover = ns.Party.header.mover
H.checkTrue("login: block mover", mover)
local petButton = ns.PartyPets.buttons[1]
H.checkTrue("login: pet made", petButton)
if petButton then
    H.check("login: pet hangs from the mover", select(2, petButton:GetPoint(1)), mover)
    H.check("login: pet one anchor", #petButton._points, 1)
end
M.group = {}
