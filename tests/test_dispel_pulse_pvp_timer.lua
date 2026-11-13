-- Asked for on CurseForge: the dispel highlights pulse (Elements/Pulse.lua,
-- an option, off by default) and the player frame shows the PvP timer
-- (Elements/UnitIcons.lua, on by default).
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "PRIEST", isPlayer = true, health = 1, healthMax = 1 }
local pvpLeft
_G.IsPVPTimerRunning = function() return pvpLeft ~= nil end
_G.GetPVPTimer = function() return pvpLeft or -1 end
_G.ForeverUnitFramesDB = nil
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, S, RC, RS = ns.Config, ns.Settings, ns.RaidConfig, ns.RaidSettings

-- Settings.
H.check("pulse: player and party", S.AppliesTo(S.Get("dispelPulse"), "player") and S.AppliesTo(S.Get("dispelPulse"), "party"), true)
H.check("pulse: not on target", S.AppliesTo(S.Get("dispelPulse"), "target"), false)
H.check("pulse: off by default", S.Default(S.Get("dispelPulse"), "party"), false)
H.check("raid pulse: off by default", RS.Default(RS.Get("dispelPulse"), "r10"), false)
H.check("timer: player only", S.AppliesTo(S.Get("pvpTimer"), "target"), false)
H.check("timer: on by default", S.Default(S.Get("pvpTimer"), "player"), true)

-- The unit frame ring: every edge of every container button.
local f = ns.Frames.player
local function edges()
    local list = {}
    for _, button in ipairs(f.dispel.container._groups.dispel.frames) do
        for _, entry in ipairs(button._dispelTextures) do list[#list + 1] = entry.texture end
    end
    for _, edge in ipairs(f.dispel.ring.edges) do list[#list + 1] = edge end
    return list
end
local function allPlaying(list)
    for _, region in ipairs(list) do
        if not (region.fufPulse and region.fufPulse:IsPlaying()) then return false end
    end
    return #list > 0
end
H.check("off: still", allPlaying(edges()), false)
C.Set("player", "dispelPulse", true)
H.check("on: every edge pulses", allPlaying(edges()), true)
local g = edges()[1].fufPulse
H.check("bounces", g._looping, "BOUNCE")
H.check("down to faint", g._anims[1]._to, ns.Pulse.LOW)
C.Set("player", "dispelPulse", false)
for _, edge in ipairs(edges()) do H.check("off again: stopped", edge.fufPulse:IsPlaying(), false) end

-- Raid: tint and border pulse together.
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "DAMAGER" } })
M.RunTimers()
local cell = ns.RaidHeader.headers[1]:GetAttribute("child1")
local c = cell.raidAuras.container
RC.Set("r10", "dispelTint", true)
RC.Set("r10", "dispelBorder", true)
RC.Set("r10", "dispelPulse", true)
local pieces = ns.Border.InnerRingPieces(c._slots.border.frame.ring)
H.check("raid border pulses", allPlaying(pieces), true)
H.check("raid tint pulses", allPlaying({ c._slots.tint.frame.tint }), true)
RC.Set("r10", "dispelPulse", false)
H.check("raid off: border still", pieces[1].fufPulse:IsPlaying(), false)

-- PvP timer: hidden without a running timer, counts down, gone at zero.
local timer = f.pvpTimer
H.checkTrue("timer made", timer)
H.check("no timer: hidden", timer:IsShown(), false)
pvpLeft = 125000
M.FireEvent("PVP_TIMER_UPDATE", "player")
H.check("running: shown", timer:IsShown(), true)
H.check("2:05", timer.text:GetText(), "2:05")
H.check("left of the crest", select(2, timer:GetPoint(1)), f.unitIcons.pvpIcon.holder)
M.Tick(65)
H.check("counts down", timer.text:GetText(), "1:00")
C.Set("player", "pvpTimer", false)
H.check("switched off: hidden", timer:IsShown(), false)
C.Set("player", "pvpTimer", true)
H.check("on again: shown", timer:IsShown(), true)
M.Tick(61)
H.check("ran out: hidden", timer:IsShown(), false)
pvpLeft = nil
M.FireEvent("PVP_TIMER_UPDATE", "player")
H.check("stopped: hidden", timer:IsShown(), false)
H.check("format", ns.UnitIcons.TimerText(299.2), "5:00")
H.check("no errors", #M.errors, 0)
