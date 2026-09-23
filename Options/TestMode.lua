local _, ns = ...

-- Shows every enabled frame with the player's data, so frames can be
-- configured without a target. Only touches secure attributes and unit
-- watch out of combat (existing ns.AfterCombat paths).
local TestMode = {}
ns.TestMode = TestMode

local L = ns.L

local on = false
-- [frame] = the unit it watched before test mode took over.
local saved = {}

local function applyOn(frame)
    saved[frame] = frame.unit
    if not UnitExists(frame.unit) then
        frame.unit = "player"
        frame:SetAttribute("unit", "player")
    end
    UnregisterUnitWatch(frame)
    frame:Show()
    ns.Single.UpdateAll(frame)
end

local function applyOff(frame)
    local unit = saved[frame]
    saved[frame] = nil
    frame.unit = unit
    frame:SetAttribute("unit", unit)
    if ns.Config.Get(frame.key, "enabled") then
        RegisterUnitWatch(frame)
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
    ns.Fire("TEST_MODE", on)
    return true
end

-- Single's own CONFIG_CHANGED listener (registered earlier, in
-- Units/Single.lua) restyles the frame first, which re-registers the unit
-- watch through applyEnabled. This listener is registered after it, so it
-- always runs afterwards and undoes that for any frame still in test mode.
ns.Listen("CONFIG_CHANGED", function()
    if not on then return end
    ns.AfterCombat("testmode", function()
        for frame in pairs(saved) do
            UnregisterUnitWatch(frame)
            frame:Show()
        end
    end)
end)

-- Fires before secure lockdown takes effect, so turning test mode off here
-- is still allowed.
ns.On("PLAYER_REGEN_DISABLED", function()
    if on then TestMode.Set(false) end
end)
