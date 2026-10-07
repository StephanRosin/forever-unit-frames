-- The two test modes are separate (Options/TestMode.lua, Raid/TestMode.lua):
-- the unit frames' shows no pretend raid, no tools bar and no buff watch
-- preview; the raid frames' shows no sample on a unit frame, while its
-- pretend cells keep theirs.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell, Test = ns.RaidConfig, ns.RaidHeader, ns.RaidCell, ns.RaidTestMode
M.units.player = { name = "Me", class = "PRIEST", className = "Priest", isPlayer = true, level = 60,
    health = 100, healthMax = 100, healthMissing = 0, power = 50, powerMax = 100, auras = {} }
M.known[1243] = true
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
RC.Set("general", "toolsMode", "FREE")
RC.Set("general", "buffWatchOnlyMissing", false)

-- The main panel's pretend cells (ten), and every special panel's.
local function pretendShown(list)
    local n = 0
    for _, f in ipairs(list or Cell.fakes) do if f:IsShown() then n = n + 1 end end
    return n
end
local function partyFakesShown()
    local n = 0
    for _, f in ipairs(ns.Party.fakes or {}) do if f:IsShown() then n = n + 1 end end
    return n
end
local player = ns.Frames.player

-- The unit frames' test mode: their samples, nothing of the raid frames'.
H.checkTrue("unit test mode on", ns.TestMode.Set(true))
M.Tick(1)
H.checkTrue("unit: party fakes shown", partyFakesShown() > 0)
H.checkTrue("unit: player samples", player.auraSamples)
H.check("unit: raid test mode off", Test.IsOn(), false)
H.check("unit: no pretend cells", pretendShown(), 0)
H.check("unit: no special panel's pretend cells", pretendShown(Cell.panelFakes), 0)
H.check("unit: no raid panel solo", Header.panel:IsShown(), false)
H.check("unit: no tools bar solo", ns.RaidTools.IsShown(), false)
H.check("unit: no buff watch preview", ns.RaidBuffWindow.frame and ns.RaidBuffWindow.frame:IsShown() or false, false)
ns.TestMode.Set(false)
M.Tick(1)

-- The raid frames' test mode: its pretend cells with their samples,
-- nothing on the unit frames.
H.checkTrue("raid test mode on", Test.Set(true))
M.Tick(1)
H.check("raid: unit test mode off", ns.TestMode.IsOn(), false)
H.check("raid: ten pretend cells", pretendShown(), 10)
H.checkTrue("raid: special panels' pretend cells", pretendShown(Cell.panelFakes) > 0)
H.checkTrue("raid: tools bar shown", ns.RaidTools.IsShown())
H.checkTrue("raid: buff watch preview", ns.RaidBuffWindow.frame:IsShown())
H.check("raid: no party fakes", partyFakesShown(), 0)
H.check("raid: player frame no aura samples", player.auraSamples, nil)
H.check("raid: player frame no dispel sample", player.dispel and player.dispel.sample, nil)
H.check("raid: player frame its own unit", player.unit, "player")
H.check("raid: player frame no preview", player.health.preview or false, false)
local f2 = Cell.fakes[2]
H.check("raid: sample name", f2.texts.healthLeft:GetText(), "Priest")
H.checkTrue("raid: sample debuff icon", f2.raidAuras.samples.icon:IsShown())
H.checkTrue("raid: sample role", f2.raidRole.icon:IsShown())
H.check("raid: sample marker", Cell.fakes[1].raidMarker.icon._spriteCell[1], 8)
H.checkTrue("raid: sample group icons", Cell.fakes[1].groupIcons.leader:IsShown())

-- Both on, then combat: each ends on its own.
H.checkTrue("both: unit on too", ns.TestMode.Set(true))
H.check("both: still ten pretend cells", pretendShown(), 10)
ns.TestMode.Set(false)
H.check("unit off: raid stays on", Test.IsOn(), true)
H.check("unit off: pretend cells stay", pretendShown(), 10)
ns.TestMode.Set(true)
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: unit test mode off", ns.TestMode.IsOn(), false)
H.check("combat: raid test mode off", Test.IsOn(), false)
H.check("combat: no pretend cells", pretendShown(), 0)
M.FireEvent("PLAYER_REGEN_ENABLED")

-- A live raid cell shows none of the unit frames' samples in their test
-- mode, also when its auras change.
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "HEALER" },
    { name = "Bob", class = "MAGE", subgroup = 1, assignedRole = "DAMAGER" } })
M.RunTimers()
local cell = Header.headers[1]:GetAttribute("child1")
ns.TestMode.Set(true)
M.FireEvent("UNIT_AURA", "raid1")
M.Tick(1)
H.check("live cell: no unit-frame aura samples", cell.auraSamples, nil)
H.check("live cell: not a pretend one", cell.sample, nil)
ns.TestMode.Set(false)
H.check("no errors", #M.errors, 0)
H.check("nothing blocked", #M.blocked, 0)
