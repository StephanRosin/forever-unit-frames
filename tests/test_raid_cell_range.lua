-- Range fading and the grey of the dead and offline on raid cells: the
-- unit frames' elements (Elements/Range.lua, Elements/UnitStatus.lua),
-- switch and opacity from the raid profile of the active size.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell = ns.RaidConfig, ns.RaidHeader, ns.RaidCell
M.units.player = { name = "Me", class = "WARRIOR", className = "Warrior", isPlayer = true, level = 60,
    health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
-- The unit frames do not fade: the timer runs for cells only.
for _, scope in ipairs({ "party", "pet", "target", "targettarget", "focus" }) do ns.Config.Set(scope, "rangeFade", false) end
H.check("solo: no timer for cells", ns.Range.driver:IsShown(), false)
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 },
    { name = "Bob", class = "MAGE", subgroup = 1, unit = { inRange = false } },
    { name = "Cid", class = "ROGUE", subgroup = 1, unit = { dead = true } },
    { name = "Dan", class = "DRUID", subgroup = 1, unit = { offline = true } } })
M.RunTimers()
local function cell(i) return Header.headers[1]:GetAttribute("child" .. i) end

H.checkTrue("in a raid: the timer runs", ns.Range.driver:IsShown())
M.Tick(0.25)
H.check("in range: full", cell(1):GetAlpha(), 1)
H.check("out of range: the raid profile's opacity", cell(2):GetAlpha(), 0.4)
RC.Set("r10", "rangeAlpha", 20)
H.check("opacity per size", cell(2):GetAlpha(), 0.2)
M.units.raid2.inRange = true
M.Tick(0.25)
H.check("back in range", cell(2):GetAlpha(), 1)
M.units.raid2.inRange = false
M.rangeSecret = "inRange"
M.Tick(0.25)
H.check("secret answer: alpha from it", cell(2)._alphaSecret, true)
M.rangeSecret = false
RC.Set("r10", "rangeFade", false)
M.Tick(0.25)
H.check("off: full", cell(2):GetAlpha(), 1)
H.check("off: no timer", ns.Range.driver:IsShown(), false)
RC.ResetScope("r10")
H.checkTrue("on: the timer again", ns.Range.driver:IsShown())

-- The dead and the offline: grey bars, their word.
H.check("dead: grey", cell(3).health._color[1], ns.UnitStatus.GREY[1])
H.check("dead: word", cell(3).texts.healthRight:GetText(), ns.L.STATUS_DEAD)
H.check("offline: grey", cell(4).health._color[1], ns.UnitStatus.GREY[1])
H.check("offline: word", cell(4).texts.healthRight:GetText(), ns.L.STATUS_OFFLINE)
H.checkTrue("alive: class colour", cell(1).health._color[1] ~= ns.UnitStatus.GREY[1])

-- Leaving the raid: no cell shows a unit, the timer stops.
M.SetRaidRoster({})
M.RunTimers()
H.check("left: no timer", ns.Range.driver:IsShown(), false)

-- Test mode: the pretend rogue is out of range.
H.check("member 4 out of range", ns.RaidTestMode.Members(10)[4].outOfRange, true)
H.check("member 14 too", ns.RaidTestMode.Members(20)[14].outOfRange, true)
ns.RaidTestMode.Set(true)
H.check("pretend rogue: faded", Cell.fakes[4]:GetAlpha(), 0.4)
H.check("pretend priest: full", Cell.fakes[2]:GetAlpha(), 1)
ns.RaidTestMode.Set(false)
H.check("no errors", #M.errors, 0)
