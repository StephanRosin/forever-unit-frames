-- Party members (and pets) whose buttons the header makes in combat keep
-- the XML size until the relayout after combat. Until then their bars
-- and texts are laid out from that actual size, so the rows fill the
-- button without overlapping; after combat everything takes the
-- configured size.
local M = H.M

local function boot()
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", health = 1, healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

-- The rows of a button, top to bottom, must fill exactly its height.
local function rows(button)
    local title = button.title:IsShown() and button.title:GetHeight() or 0
    local power = button.power:IsShown() and button.power:GetHeight() or 0
    return title, button.health:GetHeight(), power
end

local function checkFits(label, button, w, h)
    local title, health, power = rows(button)
    H.check(label .. ": rows fill the button", title + health + power, h)
    local healthTop = select(5, button.health:GetPoint(1))
    H.check(label .. ": health starts below the title", healthTop, -title)
    H.checkTrue(label .. ": health ends above the power bar", title + health <= h - power)
    H.check(label .. ": bar width", button.healthWidth, w)
end

do
    local ns = boot()
    local C = ns.Config
    C.Set("party", "width", 192)
    C.Set("party", "height", 65)
    C.Set("party", "partyShowPets", true)
    C.Set("party", "partyPetHeight", 30)
    M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
    M.units.partypet1 = { name = "Cat", health = 5, healthMax = 10 }
    M.SetGroup({ "party1" })
    H.check("one pet button out of combat", #ns.PartyPets.buttons, 1)
    local first = ns.Party.buttons[1]
    H.check("out of combat: configured size", first:GetHeight(), 65)
    checkFits("member made out of combat", first, 192, 65)

    -- Two join in combat; one brings a pet.
    M.combat = true
    M.units.party2 = { name = "Bob", health = 5, healthMax = 10 }
    M.units.party3 = { name = "Cid", health = 5, healthMax = 10 }
    M.units.partypet3 = { name = "Wolf", health = 5, healthMax = 10 }
    M.SetGroup({ "party1", "party2", "party3" })
    local late = ns.Party.buttons[3]
    H.checkTrue("button made in combat", late)
    H.check("combat: still the XML size", late:GetHeight(), 46)
    checkFits("member made in combat", late, 160, 46)
    H.check("a second pet button in combat", #ns.PartyPets.buttons, 2)
    local pet = ns.PartyPets.buttons[2]
    H.check("pet made in combat: the XML size", pet:GetHeight(), 20)
    checkFits("pet made in combat", pet, 160, 20)
    H.check("combat: nothing blocked", #M.blocked, 0)

    -- After combat: the configured size and a layout to match.
    M.SetCombat(false)
    H.check("after combat: width", late:GetWidth(), 192)
    H.check("after combat: height", late:GetHeight(), 65)
    checkFits("member after combat", late, 192, 65)
    H.check("pet after combat: height", pet:GetHeight(), 30)
    checkFits("pet after combat", pet, 192, 30)
end
