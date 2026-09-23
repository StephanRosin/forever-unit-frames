local _, ns = ...

-- Shows every enabled frame with the player's data, so frames can be
-- configured without a target, and a sample cast on every castbar. The
-- party block is replaced by a pretend party (Units/Party.lua). Only
-- touches secure attributes and unit watch out of combat (existing
-- ns.AfterCombat paths).
local TestMode = {}
ns.TestMode = TestMode

local L = ns.L

local on = false
-- [frame] = the unit it watched before test mode took over.
local saved = {}

-- Always the player's own unit, even when the frame's real unit currently
-- exists: clearing that unit later (e.g. losing a target) must not leave
-- test mode showing stale data with nothing left to refresh it, since the
-- unit watch is unregistered for as long as test mode owns the frame.
local function applyOn(frame)
    saved[frame] = frame.unit
    ns.Single.SetUnit(frame, "player")
    UnregisterUnitWatch(frame)
    frame:Show()
    ns.Castbar.Preview(frame, true)
    ns.Single.UpdateAll(frame)
end

-- Restores the exact unit test mode took over from, regardless of what
-- applyOn forced it to. A frame no longer enabled is hidden outright
-- instead of re-registering its unit watch.
local function applyOff(frame)
    local unit = saved[frame]
    saved[frame] = nil
    ns.Single.SetUnit(frame, unit)
    ns.Castbar.Preview(frame, false)
    if ns.Config.Get(frame.key, "enabled") then
        RegisterUnitWatch(frame)
    else
        UnregisterUnitWatch(frame)
        frame:Hide()
    end
    ns.Single.UpdateAll(frame)
end

function TestMode.IsOn()
    return on
end

function TestMode.Set(state)
    if InCombatLockdown() then
        ns.Print(L.TEST_MODE_COMBAT)
        return false
    end
    state = not not state
    if state == on then return true end
    on = state
    if on then
        for _, frame in pairs(ns.Frames) do
            if ns.Config.Get(frame.key, "enabled") then applyOn(frame) end
        end
    else
        for frame in pairs(saved) do applyOff(frame) end
    end
    ns.Party.SetTest(on)
    ns.Fire("TEST_MODE", on)
    return true
end

-- Out of combat, ns.Fire runs listeners in registration order, and
-- Units/Single.lua's own CONFIG_CHANGED listener is registered earlier (see
-- ForeverUnitFrames.toc), so it always restyles first; its AfterCombat job
-- runs immediately and re-registers the unit watch through applyEnabled,
-- which this listener then undoes for every frame still in test mode.
-- The "last" queue mode keeps this job behind every restyle queued in
-- combat. That only matters if test mode is on during combat, which the
-- release at combat start (below) prevents.
--
-- A frame's enabled state can also change while test mode is on: an
-- enabled frame not yet owned by test mode is taken over (applyOn), and a
-- frame test mode owns that is no longer enabled is released (applyOff,
-- which hides it since it is disabled).
ns.Listen("CONFIG_CHANGED", function()
    if not on then return end
    ns.AfterCombat("testmode", function()
        for _, frame in pairs(ns.Frames) do
            local enabled = ns.Config.Get(frame.key, "enabled")
            local owned = saved[frame] ~= nil
            if enabled and not owned then
                applyOn(frame)
            elseif not enabled and owned then
                applyOff(frame)
            elseif enabled and owned then
                UnregisterUnitWatch(frame)
                frame:Show()
            end
        end
    end, "last")
end)

-- Usually fires before secure lockdown takes effect, so turning test mode
-- off here is still allowed. If lockdown has already started, test mode
-- ends at once and the frames are handed back as soon as combat is over.
ns.On("PLAYER_REGEN_DISABLED", function()
    if not on then return end
    if not InCombatLockdown() then
        TestMode.Set(false)
        return
    end
    on = false
    ns.AfterCombat("testmode", function()
        for frame in pairs(saved) do applyOff(frame) end
        ns.Party.SetTest(false)
    end, "last")
    ns.Fire("TEST_MODE", false)
end)
