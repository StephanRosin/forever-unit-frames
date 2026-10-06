-- The raid window's position rows (Raid/Options/Window.lua): x and y are
-- a number with - / + buttons (a slider over -4000..4000 moved ~40 units
-- per pixel); a click moves the panel by 1, with Shift by the movers'
-- grid, and moves it without a relayout (tests/test_raid_position.lua).
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, Header = ns.RaidOptions, ns.RaidConfig, ns.RaidHeader

local function click(button) button:GetScript("OnClick")(button) end
local function rowFor(key)
    for _, row in ipairs(RO.rows) do if row.key == key then return row end end
end
local function enter(row, text)
    row.edit:SetText(text)
    row.edit:GetScript("OnEnterPressed")(row.edit)
end
local function count(module, name, fn)
    local original, n = module[name], 0
    module[name] = function(...) n = n + 1; return original(...) end
    local ok, err = pcall(fn)
    module[name] = original
    assert(ok, err)
    return n
end

RO.Open(10, "layout")
local x, y = rowFor("x"), rowFor("y")
H.checkTrue("x: - and + buttons", x.minus and x.plus)
H.check("x: no slider", x.slider, nil)
H.checkTrue("y: - and + buttons", y.minus and y.plus)
H.check("x shows the stored value", x.edit:GetText(), tostring(RC.Get("r10", "x")))
H.check("label", x.label:GetText(), "Position X")

click(x.plus)
H.check("+ moves by 1", RC.Get("r10", "x"), -599)
M.shiftDown = true
click(y.minus)
M.shiftDown = false
H.check("shift -: the movers' grid", RC.Get("r10", "y"), 150 - ns.Movers.GRID)
enter(x, "-480")
H.check("typed", RC.Get("r10", "x"), -480)
H.check("typed: no relayout", count(ns.RaidCell, "Style", function() enter(x, "-470") end), 0)
H.check("the panel moved", select(4, Header.anchor.mover:GetPoint(1)), -470)

-- Locked in combat like every row.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: + locked", x.plus:IsEnabled(), false)
H.check("combat: box locked", x.edit:IsEnabled(), false)
M.SetCombat(false)
H.checkTrue("after combat: back", x.plus:IsEnabled())
-- Typed beyond the screen: the mover is clamped to the screen, so the
-- stored value is clamped to where the panel can be (its top-left corner
-- from the centre, the panel's size inside the screen).
local w, h = Header.Size()
UIParent._w, UIParent._h = 1000, 600
enter(x, "4000")
H.check("x: right edge", RC.Get("r10", "x"), 500 - w)
H.check("x: the box shows it", x.edit:GetText(), tostring(500 - w))
enter(x, "-4000")
H.check("x: left edge", RC.Get("r10", "x"), -500)
enter(y, "4000")
H.check("y: top edge", RC.Get("r10", "y"), 300)
enter(y, "-4000")
H.check("y: bottom edge", RC.Get("r10", "y"), -300 + h)
H.check("the panel where the value says", select(5, Header.anchor.mover:GetPoint(1)), -300 + h)
M.shiftDown = true
click(y.minus)
M.shiftDown = false
H.check("- at the edge: stays", RC.Get("r10", "y"), -300 + h)
enter(x, "12")
H.check("inside: as typed", RC.Get("r10", "x"), 12)
-- A size not shown: the screen alone.
RO.SelectSize(20)
enter(rowFor("x"), "4000")
H.check("size not shown: the screen's edge", RC.Get("r20", "x"), 500)
RO.SelectSize(10)
UIParent._w, UIParent._h = 1920, 1080

H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
