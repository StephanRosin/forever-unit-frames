local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})

_G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
_G.PlayerFrame._protected = true
_G.PlayerFrame:RegisterEvent("UNIT_HEALTH")
_G.TargetFrame = M.newWidget("Frame", "TargetFrame")
_G.TargetFrame._protected = true
_G.TargetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
local targetChild = M.newWidget("Frame", "TargetFrameSpellBar", _G.TargetFrame)
targetChild:EnableMouse(true)
_G.ComboFrame = M.newWidget("Frame", "ComboFrame")
local blizzardMenu = M.newWidget("Frame", "Menu")
_G.TargetFrame_OpenMenu = function(owner)
    M.openMenu = blizzardMenu
    blizzardMenu:ClearAllPoints()
    blizzardMenu:SetPoint("LEFT", owner, "RIGHT")
end
local reparented
_G.ComboFrame.SetParent = function(self, p) reparented = p end

ns.Blizzard.HideDefaults()
H.check("protected: alpha 0", PlayerFrame:GetAlpha(), 0)
H.check("protected: mouse off", PlayerFrame._mouse, false)
H.check("protected: events off", next(PlayerFrame._events), nil)
H.check("protected: hidden out of combat", PlayerFrame:IsShown(), false)
H.checkTrue("unprotected: reparented", reparented ~= nil and reparented ~= UIParent)

-- TargetFrame: the controller's unit menu needs it visible (menu owner).
H.checkTrue("target: kept shown", TargetFrame:IsShown())
H.check("target: alpha 0", TargetFrame:GetAlpha(), 0)
H.check("target: mouse off", TargetFrame._mouse, false)
H.check("target: events off", next(TargetFrame._events), nil)
H.check("target: child hidden", targetChild:IsShown(), false)
H.checkTrue("target: child moved away", targetChild:GetParent() ~= TargetFrame)
-- The controller's menu: moved above our target frame.
ns.Frames.target = M.newWidget("Button", "FUFTarget")
TargetFrame_OpenMenu(TargetFrame)
local point, rel, relPoint, _, y = blizzardMenu:GetPoint(1)
H.check("menu above ours", point .. relPoint, "BOTTOMLEFTTOPLEFT")
H.check("menu on ours", rel, ns.Frames.target)
H.check("menu gap", y, 4)
ns.Frames.target:Hide()
TargetFrame_OpenMenu(TargetFrame)
H.check("ours hidden: Blizzard's place", (blizzardMenu:GetPoint(1)), "LEFT")
ns.Frames.target = nil
TargetFrame:Hide()
M.RunTimers()
H.checkTrue("target: shown again after a hide", TargetFrame:IsShown())

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

-- IsProtected may be secret or fail: either way, treat the frame as protected.
ns = H.LoadAddon()
ns.Config.Use({})
_G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
_G.PlayerFrame.IsProtected = function() return M.Secret(false) end
local secretReparented
_G.PlayerFrame.SetParent = function() secretReparented = true end
_G.TargetFrame = M.newWidget("Frame", "TargetFrame")
_G.TargetFrame.IsProtected = function() error("no") end
local failReparented
_G.TargetFrame.SetParent = function() failReparented = true end
H.checkTrue("secret/failed IsProtected: no error", pcall(ns.Blizzard.HideDefaults))
H.check("secret IsProtected: not reparented", secretReparented, nil)
H.check("secret IsProtected: alpha 0", PlayerFrame:GetAlpha(), 0)
H.check("failed IsProtected: not reparented", failReparented, nil)
H.check("failed IsProtected: alpha 0", TargetFrame:GetAlpha(), 0)
_G.PlayerFrame, _G.TargetFrame = nil, nil
