-- The unit frames' master switch "Use unit frames" (General, Core/
-- Settings.lua: unitFrames): off, every unit frame behaves as if its own
-- "enabled" were off, and Blizzard's frames are not hidden; each frame's
-- own switch is kept, so switching it back on restores the choices. The
-- raid frames do not depend on it.
local M = H.M

-- Blizzard.Conceal: a protected frame faded out, another moved under a
-- hidden parent.
local function concealed(f) return f:GetAlpha() == 0 or f:GetParent() ~= UIParent end

local function boot(profile)
    local ns = H.LoadAddon()
    for _, name in ipairs({ "PlayerFrame", "TargetFrame", "PetFrame", "TargetFrameToT", "CompactRaidFrameManager" }) do
        _G[name] = M.newWidget("Frame", name, UIParent)
    end
    M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
    M.units.party1 = { name = "Ann", class = "PRIEST", health = 5, healthMax = 10 }
    M.SetGroup({ "party1" })
    _G.ForeverUnitFramesDB = { profile = profile }
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local ns = boot({ general = { unitFrames = false }, target = { enabled = false } })
local C, L = ns.Config, ns.L
H.check("the setting: off", C.Get("general", "unitFrames"), false)
H.check("its code", ns.Settings.Get("unitFrames").code, "UU")
-- (The mock's unit watch is a flag: a watched frame is one the client shows.)
H.check("player hidden", ns.Frames.player:IsShown(), false)
H.check("player not watched", ns.Frames.player._unitWatch, nil)
H.check("party hidden", ns.Party.header:IsShown(), false)
H.check("no Blizzard player frame hidden", concealed(PlayerFrame), false)
H.check("no Blizzard pet frame hidden", concealed(PetFrame), false)
H.check("no Blizzard target frame hidden", concealed(TargetFrame), false)
H.check("the frame switches kept: player", C.Get("player", "enabled"), true)
H.check("the frame switches kept: target", C.Get("target", "enabled"), false)
H.check("raid frames on", ns.RaidConfig.Get("general", "enabled"), true)
M.FireEvent("GROUP_ROSTER_UPDATE")
M.RunTimers()
H.check("Blizzard's raid manager still hidden by the raid frames", concealed(CompactRaidFrameManager), true)
H.checkTrue("the party frame's mover inactive", not ns.Party.MoverSpec().active())

-- On again: each frame as its own switch says.
C.Set("general", "unitFrames", true)
M.RunTimers()
H.check("player back", ns.Frames.player._unitWatch, true)
H.check("party back", ns.Party.header:IsShown(), true)
H.check("Blizzard's player frame hidden now", concealed(PlayerFrame), true)
H.check("target still off by its own switch", ns.Frames.target._unitWatch, nil)
H.check("Blizzard's target frame kept for it", concealed(TargetFrame), false)

-- Off again in combat: after combat.
M.SetCombat(true)
C.Set("general", "unitFrames", false)
H.check("in combat: still watched", ns.Frames.player._unitWatch, true)
M.SetCombat(false)
H.check("after combat: not watched", ns.Frames.player._unitWatch, nil)
H.check("party too", ns.Party.header:IsShown(), false)

-- Its words, at the top of the General tab.
local first = ns.Schema.GENERAL[1].sections[1]
H.check("first on the General tab", first.keys[1], "unitFrames")
H.check("label", L.SETTING_unitFrames, "Use unit frames")
H.checkTrue("the hint names the /reload", L.HINT_unitFrames:find("/reload", 1, true))
H.check("no error", #M.errors, 0)
