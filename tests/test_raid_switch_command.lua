-- /fuf raid off | on (Core/Commands.lua): the raid frames' switch without
-- the window, an emergency exit when the raid side raises. Plain /fuf raid
-- still toggles the window. With the raid frames off at login nothing of
-- them is built (panels, tools bar, buff window, keys, smart buff key) and
-- Blizzard's raid frames stay; switched on, they are built then.
local M = H.M

local function login(raidProfile)
    local ns = H.LoadAddon()
    local manager = M.newWidget("Frame", "CompactRaidFrameManager", UIParent)
    _G.CompactRaidFrameManager, _G.CompactRaidFrameContainer = manager, nil
    _G.ForeverUnitFramesDB = { raid = { ["Tester-Testrealm"] = raidProfile } }
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns, manager
end

local function said(text)
    for _, line in ipairs(M.chat) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

local raid = { { name = "Tester", class = "WARRIOR", subgroup = 1 }, { name = "Two", class = "MAGE", subgroup = 1 } }

-- On by default: off and on again by command.
local ns = login({})
local run, L, RC = SlashCmdList.FOREVERUNITFRAMES, ns.L, ns.RaidConfig
M.SetRaidRoster(raid)
H.checkTrue("on by default", RC.Get("general", "enabled"))
run("raid off")
H.check("off", RC.Get("general", "enabled"), false)
H.checkTrue("says so", said("Raid frames off. /reload brings back Blizzard's raid frames."))
H.check("no window", ns.RaidOptions.IsOpen(), false)
run("RAID ON")
H.check("on again", RC.Get("general", "enabled"), true)
H.checkTrue("says so too", said("Raid frames on."))
-- Plain /fuf raid: the window.
run("raid")
H.checkTrue("plain: the window", ns.RaidOptions.IsOpen())
run("raid")
H.check("plain: toggled", ns.RaidOptions.IsOpen(), false)
-- The help names it.
for _, code in ipairs({ "enUS", "deDE", "frFR", "esES" }) do
    H.checkTrue(code .. ": help names /fuf raid off", ns.Locales[code].HELP:find("/fuf raid off", 1, true))
end

-- The raid window broken: the switch does not need it.
local window = ns.RaidOptions
ns.RaidOptions = setmetatable({}, { __index = function() error("raid window broken") end })
run("raid off")
H.check("broken window: off", RC.Get("general", "enabled"), false)
ns.RaidOptions = window

-- A raid-side listener that raises: the value is in, the error printed,
-- the line said.
M.chat = {}
ns.Listen("RAID_CONFIG_CHANGED", function() error("raid side broken") end)
run("raid on")
H.check("raising listener: on", RC.Get("general", "enabled"), true)
H.checkTrue("the error printed", said("raid side broken"))
H.checkTrue("the line said", said("Raid frames on."))
M.SetRaidRoster({})

-- A fresh login with the raid frames off: nothing of them built, no keys,
-- Blizzard's raid frames kept.
local manager
ns, manager = login({ general = { enabled = false, buffKey = "SHIFT-B", clickKey1 = "F", clickKey1Bind = "spell:Heal" } })
M.SetRaidRoster(raid)
M.RunTimers()
H.checkTrue("off: Blizzard's raid frames kept", manager:GetParent() == UIParent and manager:IsShown())
H.check("off: no panel", ns.RaidHeader.anchor, nil)
H.check("off: no tools bar", ns.RaidTools.bar, nil)
H.check("off: no buff window", ns.RaidBuffWindow.frame, nil)
H.check("off: no smart buff button", ns.SmartBuff.button, nil)
-- Click-casting itself stays on for the party frames (decision 74); in a
-- raid they are hidden, so no key is bound.
H.check("off: click-casting still on for the unit frames", ns.ClickCast.On(), true)
H.check("off: no key bound", ns.ClickKeys.Wanted(), false)
M.FireEvent("READY_CHECK", "Two", 30)
M.FireEvent("READY_CHECK_FINISHED")
H.check("off: no ready counts", ns.RaidTools.readyCounts, nil)
-- Switched on: built now.
ns.RaidConfig.Set("general", "enabled", true)
M.RunTimers()
H.checkTrue("on: the panel", ns.RaidHeader.anchor)
H.checkTrue("on: the tools bar", ns.RaidTools.bar)
H.checkTrue("on: the buff window", ns.RaidBuffWindow.frame)
H.check("on: Blizzard's raid frames hidden", manager:IsVisible(), false)
M.SetRaidRoster({})

H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
