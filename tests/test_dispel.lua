-- Dispel highlight (Elements/Dispel.lua): the player's and party members'
-- border tints in the debuff type colour while they carry a debuff you can
-- dispel. Live through a one-slot Blizzard aura container (combat-safe),
-- read out of combat where the client has none; settings, test mode.
local M = H.M

local function boot()
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "WARRIOR", className = "WARRIOR", isPlayer = true, health = 1,
        healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local function dispelContainer(frame) return frame.dispel and frame.dispel.container end

-- Settings -----------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local S = ns.Settings
    local def = S.Get("dispelHighlight")
    H.checkTrue("setting", def)
    H.check("code", def and def.code, "HD")
    H.checkTrue("on the player", S.AppliesTo(def, "player"))
    H.checkTrue("on the party", S.AppliesTo(def, "party"))
    for _, scope in ipairs({ "general", "target", "targettarget", "pet", "focus" }) do
        H.check("not on " .. scope, S.AppliesTo(def, scope), false)
    end
    H.check("on by default", S.Default(def, "party"), true)
    local found
    for _, tab in ipairs(ns.Schema.Tabs("party")) do
        for _, sec in ipairs(tab.sections or {}) do
            if sec.id == "dispel" then found = tab.id end
        end
    end
    H.check("dispel section on the status tab", found, "status")
    H.check("section label", ns.L.SECTION_dispel, "Dispellable debuffs")
    H.checkTrue("label", ns.L.SETTING_dispelHighlight ~= "SETTING_dispelHighlight")
end

-- Defaults add nothing to a saved profile.
do
    local ns = boot()
    local C = ns.Config
    C.Set("party", "dispelHighlight", true)
    H.check("nothing stored", next(C.Profile().party), nil)
    C.Set("party", "dispelHighlight", false)
    H.checkTrue("a change is exported", ns.Codec.Encode(C.Profile()):find("yHD0"))
end

-- The live container ---------------------------------------------------------------
do
    local ns = boot()
    local f = ns.Frames.player
    for _, key in ipairs({ "target", "targettarget", "pet", "focus" }) do
        H.check("none on " .. key, ns.Frames[key].dispel, nil)
    end
    local c = dispelContainer(f)
    H.checkTrue("player: a container", c)
    H.check("Blizzard's container", c._template, "CustomAuraContainerTemplate")
    H.check("a child of the frame", c:GetParent(), f)
    H.check("for the player", c:GetUnit(), "player")
    H.check("no made-up auras in Edit Mode", c:IsEditModePreviewEnabled(), false)
    local group = c._groups.dispel
    H.checkTrue("one group", group)
    -- RAID: harmful auras the player can dispel (AuraUtil.AuraFilters).
    H.check("debuffs you can dispel", group.filter, "HARMFUL|RAID")
    H.check("one slot", group.max, 1)
    H.checkTrue("shown", c:IsShown())
    H.checkTrue("above the border rings", c:GetFrameLevel() > f.frameRing:GetFrameLevel())

    -- Every button: a ring of four dispel type textures around the frame,
    -- coloured by the client from our curve; no mouse.
    for i, button in ipairs(group.frames) do
        H.check("button " .. i .. ": four textures", #button._dispelTextures, 4)
        local entry = button._dispelTextures[1]
        H.check("button " .. i .. ": keeps our asset", entry.options.style,
            Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset)
        H.check("button " .. i .. ": our colours", entry.options.customDispelColorCurve, ns.AuraButton.DispelCurve())
        H.check("button " .. i .. ": no clicks", button._clickEnabled, false)
        H.check("button " .. i .. ": no tooltip", button._motionEnabled, false)
    end
    local top = group.frames[1]._dispelTextures[1].texture
    local p = { top:GetPoint(1) }
    H.check("ring on the frame", p[2], f)
    H.check("from the border's outer edge", p[5], ns.Border.Extent("player"))
    H.check("at least two pixels thick", top:GetHeight(), 2)

    -- A new unit on a party button reaches its container.
    M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
    M.SetGroup({ "party1" })
    local b = ns.Party.buttons[1]
    H.check("party member's container", dispelContainer(b):GetUnit(), "party1")
    M.units.party2 = { name = "Bob", health = 5, healthMax = 10 }
    M.SetGroup({ "party2" })
    H.check("slot handed to someone else", dispelContainer(b):GetUnit(), "party2")

    -- Off: hidden.
    ns.Config.Set("party", "dispelHighlight", false)
    H.check("off: hidden", dispelContainer(b):IsShown(), false)
    ns.Config.Set("party", "dispelHighlight", true)
    H.check("on again", dispelContainer(b):IsShown(), true)
end

-- Made in combat: waits for the end of combat.
do
    local ns = boot()
    M.combat = true
    M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
    M.SetGroup({ "party1" })
    local b = ns.Party.buttons[1]
    H.check("combat: not made yet", dispelContainer(b), nil)
    H.check("combat: nothing blocked", #M.blocked, 0)
    M.SetCombat(false)
    H.checkTrue("after combat: made", dispelContainer(b))
    H.check("after combat: its unit", dispelContainer(b):GetUnit(), "party1")
    -- Restyled in combat: the buttons refuse us while auras are secret;
    -- tried again after combat.
    M.combat = true
    local ok, err = pcall(ns.Config.Set, "party", "borderSize", 3)
    H.check("restyle in combat: no error", ok and "ok" or tostring(err), "ok")
    M.SetCombat(false)
    local top = dispelContainer(b)._groups.dispel.frames[1]._dispelTextures[1].texture
    H.check("after combat: thicker ring", top:GetHeight(), 3)
end

-- A client without aura containers: read out of combat, kept in combat.
do
    M.Reset()
    local ns = H.LoadAddon()
    M.auraContainerMissing = true
    M.units.player = { name = "Me", health = 1, healthMax = 1, auras = {} }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    local f = ns.Frames.player
    H.check("no container", dispelContainer(f), nil)
    local ring = f.dispel.ring
    H.check("nothing to dispel", ring:IsShown(), false)
    M.units.player.auras = { { auraInstanceID = 7, icon = 1, dispelName = "Curse", isHelpful = false, dispellable = true } }
    M.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
    H.check("curse: ring", ring:IsShown(), true)
    local c = ns.AuraButton.DISPEL_COLORS.Curse
    H.check("curse colour", ring.edges[1]._color[1], c[1])
    H.check("asked for what you can dispel", M.lastAuraQuery.filter, "HARMFUL|RAID")
    -- In combat the client refuses: the last state stays.
    M.combat = true
    M.auraError = true
    M.units.player.auras = {}
    local ok = pcall(M.FireEvent, "UNIT_AURA", "player", { isFullUpdate = true })
    H.check("combat: no error", ok, true)
    H.check("combat: kept", ring:IsShown(), true)
    M.auraError = false
    M.SetCombat(false)
    H.check("after combat: read again", ring:IsShown(), false)
    -- A secret dispel type: the client's colour from our curve.
    M.units.player.auras = { { auraInstanceID = 8, icon = 1, dispelName = M.Secret("Magic"), dispelType = M.Secret(1),
        isHelpful = false, dispellable = true } }
    M.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
    H.check("secret type: ring", ring:IsShown(), true)
    H.check("secret type: client colour", M.Reveal(ring.edges[1]._color[1]), ns.AuraButton.DISPEL_COLORS.Magic[1])
end

-- Test mode: one pretend member carries a magic debuff.
do
    local ns = boot()
    H.checkTrue("test mode on", ns.TestMode.Set(true))
    local fakes = ns.Party.fakes
    local ring = fakes[1].dispel.ring
    H.check("member 1: ring", ring:IsShown(), true)
    H.check("member 1: magic", ring.edges[1]._color[3], ns.AuraButton.DISPEL_COLORS.Magic[3])
    H.check("member 2: none", fakes[2].dispel.ring:IsShown(), false)
    H.check("no live container on pretend members", dispelContainer(fakes[1]), nil)
    H.check("the player's container hidden", dispelContainer(ns.Frames.player):IsShown(), false)
    ns.Config.Set("party", "dispelHighlight", false)
    H.check("off: sample hidden", ring:IsShown(), false)
    ns.Config.Set("party", "dispelHighlight", true)
    ns.TestMode.Set(false)
    H.check("off: sample gone", ring:IsShown(), false)
    H.check("the player's container back", dispelContainer(ns.Frames.player):IsShown(), true)
end
