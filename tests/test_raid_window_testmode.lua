-- Test mode from the raid options window (Raid/TestMode.lua, Raid/Cell.lua,
-- Raid/Options/Window.lua): the pretend raid shows the size the window
-- edits, at that size's position; closing the window or entering combat
-- ends it; the unit frames' test mode stays its own.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100, healthMissing = 0, power = 50, powerMax = 100 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, Test, Cell, Header = ns.RaidOptions, ns.RaidConfig, ns.RaidTestMode, ns.RaidCell, ns.RaidHeader

local function click(button) button:GetScript("OnClick")(button) end
local function shown()
    local n = 0
    for _, f in ipairs(Cell.fakes) do if f:IsShown() then n = n + 1 end end
    return n
end
local function moverPoint()
    local p, _, relPoint, x, y = Header.anchor.mover:GetPoint(1)
    return table.concat({ p, relPoint, x, y }, " ")
end
local function outlined(button) return button.edges[1]._color[1] == ns.Style.COLORS.accent[1] end

-- Solo the panel shows 10; the window edits 20.
RC.Set("r20", "x", -304)
RO.Open(20)
H.check("button", RO.testButton.text:GetText(), "Test mode")
H.check("off", Test.IsOn(), false)
H.check("nothing previewed while off", Cell.Size(), 10)
click(RO.testButton)
H.checkTrue("on", Test.IsOn())
H.check("the window's switch", Test.IsOwnOn(), true)
H.check("unit frames' test mode untouched", ns.TestMode.IsOn(), false)
H.checkTrue("button outlined", outlined(RO.testButton))
H.check("the edited size", Cell.Size(), 20)
H.check("twenty pretend cells", shown(), 20)
H.check("cells of the 20 profile", Cell.fakes[1]:GetWidth(), 88)
H.check("at the 20 profile's place", moverPoint(), "TOPLEFT CENTER -304 150")
H.checkTrue("panel shown solo", Header.panel:IsShown())

-- Another size in the window: the pretend raid follows.
click(RO.sizeTabs[40])
H.check("forty", shown(), 40)
H.check("cells of the 40 profile", Cell.fakes[1]:GetWidth(), 80)
H.check("at the 40 profile's place", moverPoint(), "TOPLEFT CENTER -600 150")
RC.Set("r40", "cellWidth", 90)
H.check("an edit shows at once", Cell.fakes[1]:GetWidth(), 90)
RC.Set("r10", "cellWidth", 70)
H.check("another size's edit does not", Cell.fakes[1]:GetWidth(), 90)

-- Closing the window ends it: the real headers of the active size.
RO.Close()
H.check("closed: off", Test.IsOn(), false)
H.check("closed: switch off", Test.IsOwnOn(), false)
H.check("closed: no pretend cells", shown(), 0)
H.check("closed: active size again", Cell.Size(), 10)
H.checkTrue("closed: headers back", Header.headers[1]:IsShown())
H.check("closed: mover at the active size's place", moverPoint(), "TOPLEFT CENTER -600 150")

-- Entering combat ends it.
RO.Open(20)
click(RO.testButton)
H.check("on again", shown(), 20)
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: off", Test.IsOn(), false)
H.check("combat: no pretend cells", shown(), 0)
H.check("combat: button plain", outlined(RO.testButton), false)
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("locked in combat", RO.testButton:IsEnabled(), false)
H.check("refused in combat", Test.Set(true), false)
H.check("says why", M.chat[#M.chat]:find(ns.L.TEST_MODE_COMBAT, 1, true) ~= nil, true)
H.check("still off", Test.IsOn(), false)
M.SetCombat(false)
H.check("unlocked after combat", RO.testButton:IsEnabled(), true)

-- Lockdown had begun: the panel goes at once, the cells after combat.
click(RO.testButton)
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("lockdown: off", Test.IsOn(), false)
H.check("lockdown: panel hidden at once", Header.panel:IsShown(), false)
H.check("lockdown: cells wait", shown(), 20)
M.SetCombat(false)
H.check("after combat: cells gone", shown(), 0)

-- The unit frames' test mode with the raid window open shows the edited
-- size too; closing the window hands it back to the active size.
ns.TestMode.Set(true)
H.check("unit test mode: the edited size", shown(), 20)
H.check("the window's switch stays off", Test.IsOwnOn(), false)
RO.Close()
H.checkTrue("unit test mode stays on", ns.TestMode.IsOn())
H.check("the active size", shown(), 10)
ns.TestMode.Set(false)
H.check("all off", shown(), 0)
H.check("nothing blocked", #M.blocked, 0)
