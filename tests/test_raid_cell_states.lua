-- Aggro and target lines on raid cells (Raid/CellStates.lua): status bars
-- along the inside fed the threat status as it is (secret or not), and a
-- light line on your current target.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell, States = ns.RaidConfig, ns.RaidHeader, ns.RaidCell, ns.RaidStates
M.units.player = { name = "Me", class = "WARRIOR", className = "Warrior", isPlayer = true, level = 60,
    health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Tank", class = "WARRIOR", subgroup = 1, unit = { threat = 3 } },
    { name = "Ann", class = "PRIEST", subgroup = 1, unit = { threat = 1 } },
    { name = "Bob", class = "MAGE", subgroup = 1 } })
M.RunTimers()
local function cell(i) return Header.headers[1]:GetAttribute("child" .. i) end
local tank, ann, bob = cell(1).raidStates, cell(2).raidStates, cell(3).raidStates

-- Aggro: four bars from 1 to 2, red, fed the status.
local bar = tank.aggro.bars[1]
H.check("four bars", #tank.aggro.bars, 4)
H.check("a status bar", bar:GetObjectType(), "StatusBar")
H.check("from 1 to 2", table.concat({ bar:GetMinMaxValues() }, ","), "1,2")
H.check("red", bar._color[1] .. "," .. bar._color[2], "1,0")
H.check("tanking: status 3", bar:GetValue(), 3)
H.check("not tanking: status 1", ann.aggro.bars[1]:GetValue(), 1)
H.check("no threat: 0", bob.aggro.bars[1]:GetValue(), 0)
H.checkTrue("shown", tank.aggro:IsShown())
local p, rel, _, x, y = bar:GetPoint(1)
H.checkTrue("top edge along the inside", p == "TOPLEFT" and rel == cell(1) and x == 0 and y == 0)
H.check("two pixels", bar:GetHeight(), 2)
H.check("above the texts", tank.aggro:GetFrameLevel(), cell(1):GetFrameLevel() + States.LEVELS)

-- The mock's secret is a truthy table: a truth test on a secret (x and y
-- or z) cannot be caught offline, only in the client.
M.units.raid2.threat = M.Secret(2)
M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "raid2")
H.checkTrue("secret status: passed on as it is", M.IsSecret(ann.aggro.bars[1]:GetValue()))
M.units.raid2.threat = 0
M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "raid2")
H.check("threat gone", ann.aggro.bars[2]:GetValue(), 0)
RC.Set("r10", "aggroBorder", false)
H.check("off: hidden", tank.aggro:IsShown(), false)
RC.ResetScope("r10")
H.checkTrue("on again", tank.aggro:IsShown())

-- Your target: a light line, two pixels further in.
H.check("no target: none", ann.target:IsShown(), false)
M.units.target = M.units.raid2
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("target: shown", ann.target:IsShown())
H.check("target: opaque", ann.target:GetAlpha(), 1)
H.check("others: none", tank.target:IsShown(), false)
local edge = ann.target.edges[1]
p, rel, _, x, y = edge:GetPoint(1)
H.check("inside the red line", x .. "," .. y, "2,-2")
H.check("light", edge._color[1] .. "," .. edge._color[4], "1,0.9")
RC.Set("r10", "targetBorder", false)
H.check("off: hidden", ann.target:IsShown(), false)
RC.ResetScope("r10")
H.checkTrue("on: back", ann.target:IsShown())
M.units.target = nil
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("target cleared", ann.target:IsShown(), false)

-- Unit frames: none.
H.check("player frame: none", ns.Frames.player.raidStates, nil)

-- Test mode: the pretend tank has aggro, member 2 is your target.
ns.RaidTestMode.Set(true)
H.check("pretend tank: aggro", Cell.fakes[1].raidStates.aggro.bars[1]:GetValue(), States.SAMPLE_AGGRO)
H.check("pretend priest: none", Cell.fakes[2].raidStates.aggro.bars[1]:GetValue(), 0)
H.checkTrue("pretend priest: your target", Cell.fakes[2].raidStates.target:IsShown())
H.check("pretend tank: not your target", Cell.fakes[1].raidStates.target:IsShown(), false)
ns.RaidTestMode.Set(false)
H.check("no errors", #M.errors, 0)
