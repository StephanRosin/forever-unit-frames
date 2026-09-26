-- Raid target markers (Elements/RaidMarker.lua): settings, Blizzard's art,
-- secret indices, events, placement, test mode and the shipped look.
local M = H.M

local function boot(files)
    local ns = H.LoadAddon(files)
    M.units.player = { name = "Me", class = "WARRIOR", className = "WARRIOR", isPlayer = true, health = 1,
        healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

local FRAMES = { "player", "target", "targettarget", "pet", "focus", "party" }

-- Settings -----------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local S = ns.Settings
    local CODES = { raidMarker = "RE", raidMarkerSize = "RS", raidMarkerFramePoint = "RF",
        raidMarkerPoint = "RO", raidMarkerX = "RX", raidMarkerY = "RY" }
    for key, code in pairs(CODES) do
        local def = S.Get(key)
        H.checkTrue("setting " .. key, def)
        H.check("code of " .. key, def and def.code, code)
        for _, scope in ipairs(FRAMES) do
            H.checkTrue(key .. " on " .. scope, S.AppliesTo(def, scope))
        end
        H.check(key .. " not general", S.AppliesTo(def, "general"), false)
        H.checkTrue(key .. " label", ns.L["SETTING_" .. key] ~= "SETTING_" .. key)
    end
    for _, scope in ipairs(FRAMES) do
        H.check("on by default: " .. scope, S.Default(S.Get("raidMarker"), scope), true)
    end
    H.check("default size", S.Default(S.Get("raidMarkerSize"), "target"), 20)
    H.check("smaller on the target of target", S.Default(S.Get("raidMarkerSize"), "targettarget"), 16)
    H.check("smaller on the pet", S.Default(S.Get("raidMarkerSize"), "pet"), 16)
    H.check("default: the frame's top edge", S.Default(S.Get("raidMarkerFramePoint"), "party"), "TOP")
    H.check("default: centred on it", S.Default(S.Get("raidMarkerPoint"), "party"), "CENTER")
    H.check("default x", S.Default(S.Get("raidMarkerX"), "party"), 0)
    H.check("default y", S.Default(S.Get("raidMarkerY"), "party"), 0)

    -- Options: a Status tab on every frame, raid marker first.
    for _, scope in ipairs(FRAMES) do
        local found
        for _, tab in ipairs(ns.Schema.Tabs(scope)) do
            if tab.id == "status" then found = tab end
        end
        H.checkTrue("status tab on " .. scope, found)
        H.check("raid marker section first on " .. scope, found and found.sections[1].id, "raidMarker")
    end
    H.check("tab label", ns.L.TAB_status, "Status")
    H.check("section label", ns.L.SECTION_raidMarker, "Raid target marker")
end

-- Defaults add nothing to a saved profile.
do
    local ns = boot()
    local C = ns.Config
    C.Set("target", "raidMarker", true)
    C.Set("target", "raidMarkerSize", 20)
    C.Set("pet", "raidMarkerSize", 16)
    C.Set("party", "raidMarkerFramePoint", "TOP")
    for scope, values in pairs(C.Profile()) do
        for key in pairs(values) do
            H.checkTrue("no raid marker key stored for defaults: " .. scope .. "." .. key, not key:match("^raidMarker"))
        end
    end
    H.checkTrue("export without raid marker codes", not ns.Codec.Encode(C.Profile()):find("R[ESFOXY]"))
    C.Set("target", "raidMarkerSize", 24)
    H.checkTrue("a changed size is exported", ns.Codec.Encode(C.Profile()):find("tRS24"))
end

-- Build, art and placement ----------------------------------------------------------
do
    local ns = boot()
    local f = ns.Frames.target
    local r = f.raidMarker
    H.checkTrue("target has a raid marker", r)
    for _, key in ipairs({ "player", "targettarget", "pet", "focus" }) do
        H.checkTrue("raid marker on " .. key, ns.Frames[key].raidMarker)
    end
    H.check("a plain holder", r.holder._kind, "Frame")
    H.check("child of the frame", r.holder:GetParent(), f)
    -- Blizzard's sheet (TargetFrame.xml, RaidTargetIcon) and grid
    -- (TargetFrame.lua, RAID_TARGET_TEXTURE_ROWS/COLUMNS).
    H.check("Blizzard's raid target sheet", r.icon._texture, "Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    H.check("hidden without a marker", r.icon:IsShown(), false)
    local p = point(r.holder, "CENTER")
    H.check("on the frame", p[2], f)
    H.check("its top edge", p[3], "TOP")
    H.check("x", p[4], 0)
    H.check("y", p[5], 0)
    H.check("size", r.holder:GetWidth(), 20)
    H.check("square", r.holder:GetHeight(), 20)
    -- Above the elite marker (+16), below the class badge (+20).
    H.checkTrue("above the elite marker", r.holder:GetFrameLevel() > f:GetFrameLevel() + ns.Classification.LEVELS)
    H.checkTrue("below the class badge", r.holder:GetFrameLevel() < f.classBadge:GetFrameLevel())

    local C = ns.Config
    C.Set("target", "raidMarkerSize", 24)
    C.Set("target", "raidMarkerFramePoint", "TOPLEFT")
    C.Set("target", "raidMarkerPoint", "BOTTOMLEFT")
    C.Set("target", "raidMarkerX", 3)
    C.Set("target", "raidMarkerY", -2)
    p = point(r.holder, "BOTTOMLEFT")
    H.check("moved: point", p[3], "TOPLEFT")
    H.check("moved: x", p[4], 3)
    H.check("moved: y", p[5], -2)
    H.check("resized", r.holder:GetWidth(), 24)
    C.Set("target", "raidMarker", false)
    H.check("off: holder hidden", r.holder:IsShown(), false)
end

-- Live markers ---------------------------------------------------------------------
do
    local ns = boot()
    local f, r = ns.Frames.target, ns.Frames.target.raidMarker
    M.units.target = { name = "Boar", health = 5, healthMax = 10, raidTarget = 8 }
    M.FireEvent("PLAYER_TARGET_CHANGED")
    H.check("skull shown", r.icon:IsShown(), true)
    H.check("skull cell", r.icon._spriteCell and r.icon._spriteCell[1], 8)
    H.check("4 rows", r.icon._spriteCell and r.icon._spriteCell[2], 4)
    H.check("4 columns", r.icon._spriteCell and r.icon._spriteCell[3], 4)

    -- RAID_TARGET_UPDATE carries no unit: every frame looks again.
    M.units.target.raidTarget = 1
    M.units.player.raidTarget = 6
    M.FireEvent("RAID_TARGET_UPDATE")
    H.check("star now", r.icon._spriteCell[1], 1)
    H.check("the player's square", ns.Frames.player.raidMarker.icon._spriteCell[1], 6)
    H.check("player marker shown", ns.Frames.player.raidMarker.icon:IsShown(), true)

    M.units.target.raidTarget = nil
    M.FireEvent("RAID_TARGET_UPDATE")
    H.check("cleared: hidden", r.icon:IsShown(), false)

    -- Secret index: handed to the texture untouched, never compared.
    M.raidTargetsSecret = true
    M.units.target.raidTarget = 3
    M.combat = true
    local ok, err = pcall(M.FireEvent, "RAID_TARGET_UPDATE")
    H.check("secret index: no error", ok and "ok" or tostring(err), "ok")
    H.check("secret index shown", r.icon:IsShown(), true)
    H.check("secret index drawn", r.icon._spriteCell[1], 3)
    H.check("drawn from the secret", r.icon._spriteSecret, true)
    H.check("nothing blocked", #M.blocked, 0)
    M.SetCombat(false)
    M.raidTargetsSecret = false

    -- A client that refuses the call: no marker, no error.
    local real = _G.GetRaidTargetIndex
    _G.GetRaidTargetIndex = function() error("refused") end
    ok = pcall(M.FireEvent, "RAID_TARGET_UPDATE")
    H.check("refused: no error", ok, true)
    H.check("refused: hidden", r.icon:IsShown(), false)
    _G.GetRaidTargetIndex = real

    -- Switched off: never shown.
    M.units.target.raidTarget = 2
    ns.Config.Set("target", "raidMarker", false)
    M.FireEvent("RAID_TARGET_UPDATE")
    H.check("off: not shown", r.icon:IsShown(), false)

    -- Party members and the target of target (on its timer).
    ns.Config.Set("target", "raidMarker", true)
    M.units.party1 = { name = "Ann", health = 5, healthMax = 10, raidTarget = 4 }
    M.SetGroup({ "party1" })
    local member = ns.Party.buttons[1]
    H.check("party member marker", member.raidMarker.icon._spriteCell[1], 4)
    M.units.targettarget = { name = "Bob", health = 5, healthMax = 10, raidTarget = 5 }
    M.Tick(0.25)
    H.check("target of target on its timer", ns.Frames.targettarget.raidMarker.icon._spriteCell[1], 5)
end

-- Test mode --------------------------------------------------------------------------
do
    local ns = boot()
    H.checkTrue("test mode on", ns.TestMode.Set(true))
    local r = ns.Frames.target.raidMarker
    H.check("target sample: skull", r.icon:IsShown() and r.icon._spriteCell[1], 8)
    local fake = ns.Party.fakes[1]
    H.check("pretend member 1: star", fake.raidMarker.icon:IsShown() and fake.raidMarker.icon._spriteCell[1], 1)
    H.check("pretend member 2: none", ns.Party.fakes[2].raidMarker.icon:IsShown(), false)
    M.FireEvent("RAID_TARGET_UPDATE")
    H.check("real events leave the sample alone", r.icon:IsShown(), true)
    ns.Config.Set("target", "raidMarker", false)
    H.check("test mode: off stays off", r.icon:IsShown(), false)
    ns.Config.Set("target", "raidMarker", true)
    ns.TestMode.Set(false)
    H.check("test mode off: sample gone", r.icon:IsShown(), false)
    H.check("pretend member sample gone", fake.raidMarker.icon:IsShown(), false)
end

-- The shipped look: clear of the class badge and of the status icons.
do
    local ns = H.LoadShipped()
    M.units.player = { name = "Me", class = "WARRIOR", className = "WARRIOR", isPlayer = true, health = 1,
        healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    local C = ns.Config
    for _, scope in ipairs(FRAMES) do
        local w = ns.Single.Size(scope)
        local size = C.Get(scope, "raidMarkerSize")
        -- The marker's horizontal span from the frame's right edge.
        local left, right = -w / 2 - size / 2, -w / 2 + size / 2
        local badgeSize, badgeX = C.Get(scope, "classIconSize"), C.Get(scope, "classIconX")
        local badgeLeft = badgeX - badgeSize / 2
        H.checkTrue("shipped " .. scope .. ": left of the class badge", right < badgeLeft)
        H.checkTrue("shipped " .. scope .. ": inside the frame", left > -w)
    end
    -- The player's status icons are centred on the health bar, below the
    -- title row: the marker reaches half its size down from the top edge.
    local f = ns.Frames.player
    local size = C.Get("player", "raidMarkerSize")
    H.checkTrue("shipped player: above the status icons", size / 2 <= f.titleHeight)
end
