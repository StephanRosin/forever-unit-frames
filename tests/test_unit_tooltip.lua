-- Hovering a unit frame shows the unit's tooltip, as Blizzard's frames do.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

local function hover(frame)
    M.tooltipUnit = nil
    frame:GetScript("OnEnter")(frame)
    return M.tooltipUnit
end

local player = ns.Frames.player
H.check("player: tooltip for its unit", hover(player), "player")
H.checkTrue("owned by the frame", GameTooltip:IsOwned(player))
player:GetScript("OnLeave")(player)
H.check("leave: tooltip gone", GameTooltip._shown, false)

M.units.target = { name = "Foe", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("target: tooltip for its unit", hover(ns.Frames.target), "target")

-- Party members and their pets.
local header = ns.Party.Create()
M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
M.SetGroup({ "party1" })
local member = header:GetAttribute("child1")
H.check("party member: its unit", hover(member), "party1")

-- Blizzard's own handler is used where the client has it.
local called
_G.UnitFrame_OnEnter = function(self) called = self end
ns = H.LoadAddon()
_G.UnitFrame_OnEnter = function(self) called = self end
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
ns.Frames.player:GetScript("OnEnter")(ns.Frames.player)
H.check("Blizzard's UnitFrame_OnEnter", called, ns.Frames.player)
_G.UnitFrame_OnEnter = nil
