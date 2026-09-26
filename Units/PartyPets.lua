local _, ns = ...

-- Party pets: their own list directly under the party members, same
-- width, their own height, packed, in the party's orientation. A
-- SecureGroupPetHeaderTemplate lists the pets that exist, one after
-- another (Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua,
-- SecureGroupPetHeader_Update), and uses the party header's own rule for
-- when it shows (showParty / showPlayer / showSolo, GetGroupHeaderType),
-- in combat too. The pet header hangs from the party header's bottom
-- edge, so it follows the members shown and the block's mover.
--
-- Same rules as the party header: no initialConfigFunction (secure
-- snippets do not run on this client); the XML template in
-- Units/PartyPets.xml gives each button its starting size and clicks;
-- Lua sizes and styles out of combat only.
--
-- The buttons read their settings through a derived scope: the party
-- frame's look, with a plain health bar carrying the name.
local Pets = {}
ns.PartyPets = Pets

local Config, Single, Party = ns.Config, ns.Single, ns.Party

Pets.KEY = Party.PET_KEY
Pets.HEADER = "ForeverUnitFramesPartyPets"
Pets.TEMPLATE = "ForeverUnitFramesPartyPetButtonTemplate"
-- Every button the header made, in creation order.
Pets.buttons = {}
-- Test mode: pretend pets under the pretend party.
Pets.fakes = {}

local function get(key) return Config.Get(Party.KEY, key) end

-- What a pet frame never shows, whatever the party frame does.
local FIXED = {
    titlePercent = 0, powerEnabled = false, castbarEnabled = false, titleClassIcon = false,
    portraitMode = "OFF", eliteMarker = false, combatFeedback = false, textHealthLeft = "NAME",
}

local function resolve(key)
    local fixed = FIXED[key]
    if fixed ~= nil then return fixed end
    if key == "height" then return get("partyPetHeight") end
    -- A marker no taller than the pet frame.
    if key == "raidMarkerSize" then return math.min(get("raidMarkerSize"), get("partyPetHeight")) end
    if (key == "buffsEnabled" or key == "debuffsEnabled") and not get("partyPetAuras") then return false end
    return nil
end
Config.Derive(Pets.KEY, Party.KEY, resolve)

-- Offset of pet i (1-based) from the pet list's top-left corner.
function Pets.SlotOffset(i)
    local w, h = Single.Size(Pets.KEY)
    local step = (i - 1) * Party.PetStep()
    if get("partyOrientation") == "HORIZONTAL" then
        return (i - 1) * w + step, 0
    end
    return 0, -((i - 1) * h + step)
end

local function setAttributes(header, attributes)
    header:SetAttribute("_ignore", "attributeChanges")
    for name, value in pairs(attributes) do header:SetAttribute(name, value) end
    header:SetAttribute("_ignore", nil)
end

-- Mirrors the party header's attributes, so pets show exactly when
-- their owners' block does.
local function headerAttributes()
    local horizontal = get("partyOrientation") == "HORIZONTAL"
    local step = Party.PetStep()
    return {
        template = Pets.TEMPLATE, templateType = "Button", sortMethod = "INDEX",
        showParty = true, showPlayer = get("partyShowPlayer"), showSolo = get("partyShowSolo"),
        point = horizontal and "LEFT" or "TOP",
        xOffset = horizontal and step or 0,
        yOffset = horizontal and 0 or -step,
    }
end

local function style(button)
    if not InCombatLockdown() then button:SetSize(Single.Size(Pets.KEY)) end
    Single.StyleContent(button)
    Single.UpdateAll(button)
end

-- A pretend pet: like Party's pretend members, a secure button on the
-- player, made once, out of combat.
local function fakeButton(i)
    local button = Pets.fakes[i]
    if button then return button end
    button = CreateFrame("Button", "ForeverUnitFramesPartyPetTest" .. i, Party.testBlock, "SecureUnitButtonTemplate")
    ns.Units.EnableTooltip(button)
    button.key = Pets.KEY
    -- Shows samples only; never gets live aura containers.
    button.pretend = true
    button:SetAttribute("*type1", "target")
    button:SetAttribute("*type2", "togglemenu")
    button:RegisterForClicks("AnyUp")
    for _, el in ipairs(ns.Elements) do el.Build(button) end
    Pets.fakes[i] = button
    return button
end

-- Under the pretend block (every slot filled), one pet per slot.
local function showFakes()
    local _, blockH = Party.BlockSize()
    local top = -(blockH + Party.PetListOffset())
    local slots = Party.Slots()
    for i = 1, slots do
        local button = fakeButton(i)
        Single.SetUnit(button, "player")
        local x, y = Pets.SlotOffset(i)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", Party.testBlock, "TOPLEFT", x, top + y)
        style(button)
        Single.Preview(button, true)
        button:Show()
    end
    for i = slots + 1, #Pets.fakes do Party.ReleaseFake(Pets.fakes[i]) end
end

-- Out of combat only (Party.StyleAll): attributes, anchors, size and
-- visibility are protected.
function Pets.StyleAll(testing)
    local on = get("enabled") and get("partyShowPets")
    local header = Pets.header
    if header then
        setAttributes(header, headerAttributes())
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", Party.header, "BOTTOMLEFT", 0, -Party.PetListOffset())
        -- The header only SetPoints the buttons it shows.
        for _, button in ipairs(Pets.buttons) do
            style(button)
            button:ClearAllPoints()
        end
        -- Hide + Show lays the list out again (OnShow).
        header:Hide()
        if on and not testing then header:Show() end
    end
    if on and testing then
        showFakes()
    else
        for _, button in ipairs(Pets.fakes) do Party.ReleaseFake(button) end
    end
end

-- XML OnLoad: the button exists, its unit is not known yet.
function Pets.InitButton(button)
    button.key = Pets.KEY
    for _, el in ipairs(ns.Elements) do el.Build(button) end
    Pets.buttons[#Pets.buttons + 1] = button
    ns.Units.EnableTooltip(button)
    -- Made in combat it keeps the XML size until the relayout after combat.
    if not InCombatLockdown() then button:SetSize(Single.Size(Pets.KEY)) end
    Single.StyleContent(button)
end

-- The header assigns or clears a unit, in or out of combat.
function Pets.OnUnitChanged(button, unit)
    button.unit = unit
    ns.UnitEvents.Bind(button)
    if not unit then return end
    if InCombatLockdown() then ns.AfterCombat("partyStyle", Party.StyleAll) end
    Single.UpdateAll(button)
end

-- Out of combat, from Party.Create.
function Pets.Create()
    if Pets.header then return Pets.header end
    Pets.header = CreateFrame("Frame", Pets.HEADER, UIParent, "SecureGroupPetHeaderTemplate")
    Pets.header.key = Pets.KEY
    return Pets.header
end

-- Called from Units/PartyPets.xml; not part of the public API.
ns.api.PartyPetButtonOnLoad = Pets.InitButton
function ns.api.PartyPetButtonOnAttributeChanged(button, name, value)
    if name == "unit" then Pets.OnUnitChanged(button, value) end
end

-- A pet swapped under the same token: the header may hand out the same
-- unit again, so refresh the bound buttons. UpdateAll skips missing pets.
ns.On("UNIT_PET", function(event)
    for _, button in ipairs(Pets.buttons) do Single.UpdateAll(button, event) end
end)
