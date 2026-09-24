local _, ns = ...

-- Party pets: one small secure button per party slot, directly under its
-- owner (Party.PetOffset). Not a SecureGroupPetHeaderTemplate: that
-- header lists only the pets that exist, one after another, so a member
-- without a pet would shift every later pet under the wrong owner (see
-- Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua,
-- SecureGroupPetHeader_Update). The party header sorts by index, so slot
-- i is always the same unit; its pet token is fixed, and a unit watch
-- shows the button only while that pet exists, in combat too.
--
-- The buttons read their settings through a derived scope: the party
-- frame's look, with a plain health bar carrying the name.
local Pets = {}
ns.PartyPets = Pets

local Config, Single, Party = ns.Config, ns.Single, ns.Party

Pets.KEY = Party.PET_KEY
-- Every real pet button, by slot; made out of combat, reused.
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
    if (key == "buffsEnabled" or key == "debuffsEnabled") and not get("partyPetAuras") then return false end
    return nil
end
Config.Derive(Pets.KEY, Party.KEY, resolve)

-- The pet token of slot i in a group: the party header puts the player
-- first when shown, then party1..party4 in index order.
function Pets.Unit(i)
    if get("partyShowPlayer") then
        if i == 1 then return "pet" end
        return "partypet" .. (i - 1)
    end
    return "partypet" .. i
end

-- The pet tokens of the slots the party header shows now, by its own rule
-- (SecureGroupHeaders.lua, GetGroupHeaderType): in a group (a raid too,
-- as the header has no showRaid) every slot; solo only with "show when
-- solo", and then slot 1 is you whatever "show player" says; else none.
function Pets.Units()
    local units = {}
    if IsInGroup() then
        for i = 1, Party.Slots() do units[i] = Pets.Unit(i) end
    elseif get("partyShowSolo") then
        units[1] = "pet"
    end
    return units
end

local function newButton(name, parent)
    local button = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate")
    button.key = Pets.KEY
    button:SetAttribute("*type1", "target")
    button:SetAttribute("*type2", "togglemenu")
    button:RegisterForClicks("AnyUp")
    for _, el in ipairs(ns.Elements) do el.Build(button) end
    -- The unit watch shows it when the pet appears: fill it then.
    button:HookScript("OnShow", function(self) Single.UpdateAll(self) end)
    return button
end

local function realButton(i)
    local button = Pets.buttons[i]
    if button then return button end
    button = newButton("ForeverUnitFramesPartyPet" .. i, UIParent)
    Pets.buttons[i] = button
    return button
end

local function fakeButton(i)
    local button = Pets.fakes[i]
    if button then return button end
    button = newButton("ForeverUnitFramesPartyPetTest" .. i, Party.testBlock)
    -- Shows samples only; never gets live aura containers.
    button.pretend = true
    Pets.fakes[i] = button
    return button
end

local function style(button)
    button:SetSize(Single.Size(Pets.KEY))
    Single.StyleContent(button)
end

-- Under slot i of the block hanging from relative.
local function place(button, i, relative, relPoint, x, y)
    local sx, sy = Party.SlotOffset(i)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", relative, relPoint, x + sx, y + sy - Party.PetOffset())
end

local function release(button)
    UnregisterUnitWatch(button)
    button:Hide()
end

local function showReal()
    local units = Pets.Units()
    local slots = #units
    local relative, relPoint, x, y = Party.BlockAnchor()
    for i = 1, slots do
        local button = realButton(i)
        Single.SetUnit(button, units[i])
        place(button, i, relative, relPoint, x, y)
        style(button)
        RegisterUnitWatch(button)
        Single.UpdateAll(button)
    end
    for i = slots + 1, #Pets.buttons do release(Pets.buttons[i]) end
end

local function showFakes(slots)
    for i = 1, slots do
        local button = fakeButton(i)
        Single.SetUnit(button, "player")
        place(button, i, Party.testBlock, "TOPLEFT", 0, 0)
        style(button)
        Single.Preview(button, true)
        button:Show()
        Single.UpdateAll(button)
    end
    for i = slots + 1, #Pets.fakes do Party.ReleaseFake(Pets.fakes[i]) end
end

-- Out of combat only (Party.StyleAll): units, anchors, size and unit
-- watch are protected.
function Pets.StyleAll(testing)
    Pets.testing = testing
    local on = get("enabled") and get("partyShowPets")
    local slots = Party.Slots()
    if on and not testing then
        showReal()
    else
        for _, button in ipairs(Pets.buttons) do release(button) end
    end
    if on and testing then
        showFakes(slots)
    else
        for _, button in ipairs(Pets.fakes) do Party.ReleaseFake(button) end
    end
end

-- A pet summoned, dismissed or swapped, or the roster reshuffled: the
-- same token may now be another pet. UpdateAll skips missing pets.
local function refresh(event)
    for _, button in ipairs(Pets.buttons) do Single.UpdateAll(button, event) end
end
ns.On("UNIT_PET", refresh)
-- Joining or leaving a group changes which slots the header shows: the
-- pet slots follow, out of combat.
ns.On("GROUP_ROSTER_UPDATE", function(event)
    refresh(event)
    ns.AfterCombat("partyPets", function() Pets.StyleAll(Pets.testing) end)
end)
