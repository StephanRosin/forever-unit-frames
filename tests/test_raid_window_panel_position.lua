-- The raid window's Panels tab: a special panel's position is a number
-- with - / + buttons like the main panel's, moves that panel alone
-- without a relayout, and stops at the screen's edge for that panel's
-- size.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, Header = ns.RaidOptions, ns.RaidConfig, ns.RaidHeader
local P = ns.RaidSpecialPanels.panels.mainTanks

local function click(button) button:GetScript("OnClick")(button) end
local function rowFor(key)
    for _, row in ipairs(RO.rows) do if row.key == key then return row end end
end
local function enter(row, text)
    M.Type(row.edit, text)
    M.PressEnter(row.edit)
end
local function count(module, name, fn)
    local original, n = module[name], 0
    module[name] = function(...) n = n + 1; return original(...) end
    local ok, err = pcall(fn)
    module[name] = original
    assert(ok, err)
    return n
end

H.check("the panel of a key", ns.RaidPanel.ByPositionKey("mainTanksY"), P)
H.check("its axis", select(2, ns.RaidPanel.ByPositionKey("mainTanksY")), "y")
H.check("the main panel's", ns.RaidPanel.ByPositionKey("x"), Header)
H.check("not a position", ns.RaidPanel.ByPositionKey("cellWidth"), nil)

RO.Open(10, "panels")
local x, y = rowFor("mainTanksX"), rowFor("mainTanksY")
H.checkTrue("x: - and + buttons", x.minus and x.plus)
H.check("x: no slider", x.slider, nil)
H.checkTrue("y: - and + buttons", y.minus and y.plus)
H.check("x shows the stored value", x.edit:GetText(), "-600")
H.check("label", y.label:GetText(), "Position Y")
H.check("cells per line: a slider", rowFor("mainTanksPerLine").slider ~= nil, true)

click(x.plus)
H.check("+ moves by 1", RC.Get("r10", "mainTanksX"), -599)
M.shiftDown = true
click(y.minus)
M.shiftDown = false
H.check("shift -: the movers' grid", RC.Get("r10", "mainTanksY"), 260 - ns.Movers.GRID)
H.check("typed: no relayout", count(ns.RaidCell, "Style", function() enter(x, "-470") end), 0)
H.check("the panel moved", select(4, P.anchor.mover:GetPoint(1)), -470)
H.check("the main panel did not", select(4, Header.anchor.mover:GetPoint(1)), -600)

-- Beyond the screen: the edge, for this panel's size (a cell while it is
-- empty) and not the main panel's.
local w, h = P.Size()
UIParent._w, UIParent._h = 1000, 600
enter(x, "4000")
H.check("x: right edge for its size", RC.Get("r10", "mainTanksX"), 500 - w)
enter(y, "-4000")
H.check("y: bottom edge for its size", RC.Get("r10", "mainTanksY"), -300 + h)
RO.SelectSize(20)
enter(rowFor("mainTanksX"), "4000")
H.check("size not shown: the screen's edge", RC.Get("r20", "mainTanksX"), 500)
RO.SelectSize(10)
UIParent._w, UIParent._h = 1920, 1080

-- Locked in combat like every row.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: + locked", x.plus:IsEnabled(), false)
M.SetCombat(false)
H.checkTrue("after combat: back", x.plus:IsEnabled())
RO.Close()
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
