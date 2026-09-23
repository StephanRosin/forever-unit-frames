local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})

_G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
_G.PlayerFrame._protected = true
_G.PlayerFrame:RegisterEvent("UNIT_HEALTH")
_G.TargetFrame = M.newWidget("Frame", "TargetFrame")
local reparented
_G.TargetFrame.SetParent = function(self, p) reparented = p end

ns.Blizzard.HideDefaults()
H.check("protected: alpha 0", PlayerFrame:GetAlpha(), 0)
H.check("protected: mouse off", PlayerFrame._mouse, false)
H.check("protected: events off", next(PlayerFrame._events), nil)
H.check("protected: hidden out of combat", PlayerFrame:IsShown(), false)
H.checkTrue("unprotected: reparented", reparented ~= nil and reparented ~= UIParent)

-- A disabled frame keeps Blizzard's.
ns = H.LoadAddon()
ns.Config.Use({ player = { enabled = false } })
_G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
ns.Blizzard.HideDefaults()
H.check("kept when ours is disabled", PlayerFrame:GetAlpha(), 1)

-- Missing Blizzard frames are ignored.
ns = H.LoadAddon()
ns.Config.Use({})
_G.PlayerFrame, _G.TargetFrame = nil, nil
H.checkTrue("no error without frames", pcall(ns.Blizzard.HideDefaults))
