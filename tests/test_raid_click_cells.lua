-- Click-casting on the raid cells (Raid/ClickCast.lua): every cell a
-- header made, of every panel, gets the bindings as attributes out of
-- combat; a cell made in combat after combat; test mode's cells never.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell, CC = ns.RaidConfig, ns.RaidHeader, ns.RaidCell, ns.ClickCast
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
Header.Create()
CC.ApplyAll()

local function member(name, subgroup, role)
    return { name = name, class = "PRIEST", subgroup = subgroup, role = role,
        unit = { health = 100, healthMax = 100, powerType = 0 } }
end
local list = {}
for i = 1, 7 do list[i] = member("M" .. i, math.floor((i - 1) / 5) + 1, i == 1 and "MAINTANK" or nil) end
M.SetRaidRoster(list)
M.RunTimers()
H.checkTrue("cells made", #Cell.buttons >= 7)

local function all(name, want)
    for i, b in ipairs(Cell.buttons) do
        if b:GetAttribute(name) ~= want then return "cell " .. i .. ": " .. tostring(b:GetAttribute(name)) end
    end
    return want
end
-- The defaults: what the XML gives, nothing else.
H.check("left targets", all("*type1", "target"), "target")
H.check("right menu", all("*type2", "togglemenu"), "togglemenu")
H.check("shift-left: nothing of its own", all("shift-type1", nil), nil)

-- A binding: every cell at once, out of combat.
M.known[2061] = true
RC.Set("general", "click1Shift", "spell:Flash Heal")
H.check("shift-left casts", all("shift-type1", "spell"), "spell")
H.check("the spell by name", all("shift-spell1", "Flash Heal"), "Flash Heal")
H.check("left still targets", all("*type1", "target"), "target")
-- The main tank's own panel has cells too: they are in the list.
local mt = ns.RaidPanel.list[2]
H.check("main tanks panel", mt.id, "mainTanks")
H.checkTrue("its cells take the bindings", #mt.Cells() > 0 and mt.Cells()[1]:GetAttribute("shift-type1") == "spell")

-- Plain left taken from targeting: Nothing.
RC.Set("general", "click1", "")
H.check("left: nothing", all("*type1", nil), nil)
RC.Set("general", "click1", "target")

-- In combat: nothing protected is touched; after combat the change shows.
M.SetCombat(true)
RC.Set("general", "click1Shift", "focus")
H.check("in combat: kept", all("shift-type1", "spell"), "spell")
H.check("nothing blocked", #M.blocked, 0)
-- Someone joins: a new cell, made in combat with the XML's attributes.
local before = #Cell.buttons
list[8] = member("M8", 2)
list[9] = member("M9", 2)
list[10] = member("M10", 2)
list[11] = member("M11", 3)
M.SetRaidRoster(list)
M.RunTimers()
H.check("nothing blocked when cells are made", #M.blocked, 0)
M.SetCombat(false)
M.RunTimers()
H.checkTrue("cells made in combat", #Cell.buttons > before)
H.check("after combat: every cell focuses", all("shift-type1", "focus"), "focus")
H.check("the spell cleared", all("shift-spell1", nil), nil)

-- A cell made out of combat gets them at once.
before = #Cell.buttons
for i = 12, 16 do list[i] = member("M" .. i, 3) end
M.SetRaidRoster(list)
H.checkTrue("more cells", #Cell.buttons > before)
H.check("a new cell takes them at once", all("shift-type1", "focus"), "focus")

-- Test mode's pretend cells keep the XML's left/right.
ns.RaidTestMode.Set(true)
M.RunTimers()
local fakes = 0
for _, b in ipairs(Cell.fakes) do
    fakes = fakes + 1
    H.check("a test cell: no binding", b:GetAttribute("shift-type1"), nil)
end
H.checkTrue("test cells exist", fakes > 0)
ns.RaidTestMode.Set(false)

-- Bindings are not the panel's business: no relayout.
local placed = 0
ns.Listen("RAID_PANEL_PLACED", function() placed = placed + 1 end)
RC.Set("general", "click3", "assist")
M.RunTimers()
H.check("no relayout for a binding", placed, 0)
H.check("middle assists", all("*type3", "assist"), "assist")

-- Off: back to the XML's attributes.
RC.Set("general", "clickCast", "OFF")
H.check("off: shift-left", all("shift-type1", nil), nil)
H.check("off: middle", all("*type3", nil), nil)
H.check("off: left", all("*type1", "target"), "target")
RC.Set("general", "clickCast", "ON")
H.check("on again", all("*type3", "assist"), "assist")
H.check("nothing blocked at all", #M.blocked, 0)
