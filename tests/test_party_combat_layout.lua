-- Party members (and pets) who join in combat: their buttons were made
-- ahead of time, out of combat (Units/Units.lua PrebuildButtons), so
-- they have the configured size at once and their rows fill it. (Until
-- 0.25.1 the header made them in combat at the XML size.)
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
    H.check("a pet button per slot out of combat", #ns.PartyPets.buttons, ns.Party.Slots())
    local first = ns.Party.buttons[1]
    H.check("out of combat: configured size", first:GetHeight(), 65)
    checkFits("member made out of combat", first, 192, 65)

    -- Two join in combat; one brings a pet.
    M.combat = true
    M.units.party2 = { name = "Bob", health = 5, healthMax = 10 }
    M.units.party3 = { name = "Cid", health = 5, healthMax = 10 }
    M.units.partypet3 = { name = "Wolf", health = 5, healthMax = 10 }
    M.SetGroup({ "party1", "party2", "party3" })
    local late = ns.Party.header:GetAttribute("child3")
    H.check("joined in combat: its button", late.unit, "party3")
    H.check("combat: configured size at once", late:GetHeight(), 65)
    checkFits("member joined in combat", late, 192, 65)
    H.check("no pet button made in combat", #ns.PartyPets.buttons, ns.Party.Slots())
    local pet = ns.PartyPets.header:GetAttribute("child2")
    H.check("pet in combat: its button", pet.unit, "partypet3")
    H.check("pet in combat: configured size at once", pet:GetHeight(), 30)
    checkFits("pet in combat", pet, 192, 30)
    H.check("combat: nothing blocked", #M.blocked, 0)

    -- After combat: the configured size and a layout to match.
    M.SetCombat(false)
    H.check("after combat: width", late:GetWidth(), 192)
    H.check("after combat: height", late:GetHeight(), 65)
    checkFits("member after combat", late, 192, 65)
    H.check("pet after combat: height", pet:GetHeight(), 30)
    checkFits("pet after combat", pet, 192, 30)
end
