-- Blizzard's raid frames (Blizzard_CompactRaidFrames): the container of
-- compact unit frames (an Edit Mode frame with secure buttons) and the
-- manager panel go while our raid frames are on and set to hide them
-- (Core/Blizzard.lua), out of combat. Blizzard's own code shows them again
-- whenever it likes, also in combat; that must not bring a visible or
-- clickable Blizzard raid button back.
local M = H.M

-- Stand-ins: CompactRaidFrameManager a plain frame with events,
-- CompactRaidFrameContainer an Edit Mode frame (HideBase), protected: it
-- holds secure compact unit frames (CompactRaidFrame1). The roster
-- handler models Blizzard's global one (Blizzard_Game EventImplementation
-- -> UpdateRaidAndPartyFrames -> CompactRaidFrameManager_UpdateShown ->
-- CompactRaidFrameManager_UpdateContainerVisibility): secure code that
-- shows the manager in a group and the container in a raid, in or out of
-- combat. It is made after the addon loads, so it runs after our handlers:
-- the worst order, Blizzard has the last word.
local function blizzardRaid()
    local manager = M.newWidget("Frame", "CompactRaidFrameManager", UIParent)
    manager:RegisterEvent("GROUP_ROSTER_UPDATE")
    local container = M.newWidget("Frame", "CompactRaidFrameContainer", UIParent)
    container:RegisterEvent("GROUP_ROSTER_UPDATE")
    container._protected = true
    local member = M.newWidget("Button", "CompactRaidFrame1", container)
    member._protected = true
    member:EnableMouse(true)
    container.hideBaseCalls = 0
    rawset(container, "HideBase", function(self)
        self.hideBaseCalls = self.hideBaseCalls + 1
        self._shown = false
    end)
    _G.CompactRaidFrameManager, _G.CompactRaidFrameContainer = manager, container
    local roster = M.newWidget("Frame", nil, UIParent)
    roster:RegisterEvent("GROUP_ROSTER_UPDATE")
    roster:SetScript("OnEvent", function()
        M.secureDepth = M.secureDepth + 1
        manager:SetShown(IsInGroup())
        if IsInRaid() then container:Show() else container:Hide() end
        M.secureDepth = M.secureDepth - 1
    end)
    return manager, container, member
end

-- A Blizzard raid button anyone could see or click.
local function reachable(member)
    return member:IsVisible() and member._mouse ~= false
end

local function login(raidProfile)
    local ns = H.LoadAddon()
    local manager, container, member = blizzardRaid()
    _G.ForeverUnitFramesDB = { raid = { ["Tester-Testrealm"] = raidProfile } }
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    return ns, manager, container, member
end

local raid = { { name = "Tester", class = "WARRIOR", subgroup = 1 }, { name = "Two", class = "MAGE", subgroup = 1 } }

-- Default: on, and hidden at login.
local ns, manager, container, member = login({})
H.check("manager hidden", manager:IsVisible(), false)
H.checkTrue("manager under a hidden parent", manager:GetParent() ~= UIParent)
H.check("manager events off", next(manager._events), nil)
H.checkTrue("container under a hidden parent", container:GetParent() ~= UIParent)
H.check("container: hidden by its own Hide", container.hideBaseCalls, 1)
H.check("container events off", next(container._events), nil)
H.check("raid button: unreachable", reachable(member), false)

-- Blizzard shows them again on a roster change, out of combat and in it,
-- and through Edit Mode (a secure Show): nothing reappears.
M.SetRaidRoster(raid)
H.checkTrue("roster change: Blizzard did show the container", container:IsShown())
H.check("roster change: container invisible", container:IsVisible(), false)
H.check("roster change: manager invisible", manager:IsVisible(), false)
H.check("roster change: raid button unreachable", reachable(member), false)
M.combat = true
M.SetRaidRoster({})
M.SetRaidRoster(raid)
H.checkTrue("combat roster change: Blizzard did show the container", container:IsShown())
H.check("combat roster change: raid button unreachable", reachable(member), false)
H.check("combat roster change: manager invisible", manager:IsVisible(), false)
M.SetCombat(false)
M.SetRaidRoster({})
H.check("nothing blocked", #M.blocked, 0)

-- Kept: the setting off, or our raid frames off.
ns, manager, container, member = login({ general = { hideBlizzard = false } })
H.checkTrue("kept: manager shown", manager:IsVisible())
H.checkTrue("kept: raid button reachable", reachable(member))
ns.RaidConfig.Set("general", "hideBlizzard", true)
H.check("switched on: hidden at once", manager:IsVisible(), false)
H.check("switched on: raid button unreachable", reachable(member), false)
ns, manager, container, member = login({ general = { enabled = false } })
H.checkTrue("raid frames off: manager kept", manager:IsVisible())
-- Switched on in combat: the protected container waits for the end of
-- combat; until then Blizzard's raid buttons stay where they were.
M.combat = true
ns.RaidConfig.Set("general", "enabled", true)
H.checkTrue("combat: waits", manager:IsVisible())
H.checkTrue("combat: raid button still reachable (the gap)", reachable(member))
M.SetCombat(false)
H.check("after combat: hidden", manager:IsVisible(), false)
H.check("after combat: raid button unreachable", reachable(member), false)
H.check("nothing blocked either", #M.blocked, 0)

-- A client without them: nothing to do.
ns = H.LoadAddon()
_G.CompactRaidFrameManager, _G.CompactRaidFrameContainer = nil, nil
_G.ForeverUnitFramesDB = {}
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
H.check("no Blizzard raid frames: no error", #M.errors, 0)
