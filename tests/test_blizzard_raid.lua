-- Blizzard's raid frames (Blizzard_CompactRaidFrames): the container of
-- compact unit frames (an Edit Mode frame with secure buttons) and the
-- manager panel go while our raid frames are on and set to hide them
-- (Core/Blizzard.lua), out of combat, again after roster changes.
local M = H.M

-- Stand-ins: CompactRaidFrameManager a plain frame with events,
-- CompactRaidFrameContainer an Edit Mode frame (HideBase), protected: it
-- holds secure compact unit frames.
local function blizzardRaid()
    local manager = M.newWidget("Frame", "CompactRaidFrameManager", UIParent)
    manager:RegisterEvent("GROUP_ROSTER_UPDATE")
    local container = M.newWidget("Frame", "CompactRaidFrameContainer", UIParent)
    container:RegisterEvent("GROUP_ROSTER_UPDATE")
    container._protected = true
    local member = M.newWidget("Button", "CompactRaidFrame1", container)
    member._protected = true
    container.hideBaseCalls = 0
    rawset(container, "HideBase", function(self)
        self.hideBaseCalls = self.hideBaseCalls + 1
        self._shown = false
    end)
    _G.CompactRaidFrameManager, _G.CompactRaidFrameContainer = manager, container
    return manager, container
end

local function login(raidProfile)
    local ns = H.LoadAddon()
    local manager, container = blizzardRaid()
    _G.ForeverUnitFramesDB = { raid = { ["Tester-Testrealm"] = raidProfile } }
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    return ns, manager, container
end

-- Default: on, and hidden at login.
local ns, manager, container = login({})
H.check("manager hidden", manager:IsShown(), false)
H.checkTrue("manager under a hidden parent", manager:GetParent() ~= UIParent)
H.check("manager events off", next(manager._events), nil)
H.check("container: invisible", container:GetAlpha(), 0)
H.check("container: mouse off", container._mouse, false)
H.check("container: hidden by its own Hide", container.hideBaseCalls, 1)
H.check("container events off", next(container._events), nil)

-- Shown again by someone: hidden again on the next roster change.
manager:Show()
M.SetGroup({ "party1" })
H.check("roster change: manager hidden again", manager:IsShown(), false)
M.SetGroup({})

-- Kept: the setting off, or our raid frames off.
ns, manager, container = login({ general = { hideBlizzard = false } })
H.checkTrue("kept: manager shown", manager:IsShown())
H.check("kept: container visible", container:GetAlpha(), 1)
ns.RaidConfig.Set("general", "hideBlizzard", true)
H.check("switched on: hidden at once", manager:IsShown(), false)
ns, manager, container = login({ general = { enabled = false } })
H.checkTrue("raid frames off: manager kept", manager:IsShown())
M.combat = true
ns.RaidConfig.Set("general", "enabled", true)
H.checkTrue("combat: waits", manager:IsShown())
M.SetCombat(false)
H.check("after combat: hidden", manager:IsShown(), false)
H.check("nothing blocked", #M.blocked, 0)

-- A client without them: nothing to do.
ns = H.LoadAddon()
_G.CompactRaidFrameManager, _G.CompactRaidFrameContainer = nil, nil
_G.ForeverUnitFramesDB = {}
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
H.check("no Blizzard raid frames: no error", #M.errors, 0)
