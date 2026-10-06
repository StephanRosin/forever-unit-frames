-- The raid panel's position (Raid/Header.lua): a change of the shown
-- size's x or y only moves the anchor (the mover, which the anchor and the
-- headers hang from), out of combat; no relayout of cells and headers.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell = ns.RaidConfig, ns.RaidHeader, ns.RaidCell
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 }, { name = "Bob", class = "MAGE", subgroup = 2 } })
M.RunTimers()
local mover = Header.anchor.mover

-- Counts the calls of a module function while fn runs.
local function count(module, name, fn)
    local original, n = module[name], 0
    module[name] = function(...) n = n + 1; return original(...) end
    local ok, err = pcall(fn)
    module[name] = original
    assert(ok, err)
    return n
end

local function corner()
    local _, _, _, x, y = mover:GetPoint(1)
    return x .. "," .. y
end

H.check("shown size", Cell.Size(), 10)
H.check("refresh on x", count(Header, "Refresh", function() RC.Set("r10", "x", -500) end), 0)
H.check("no cell restyled on x", count(Cell, "Style", function() RC.Set("r10", "x", -400) end), 0)
H.check("no header placed on y", count(Header, "Place", function() RC.Set("r10", "y", 100) end), 0)
H.check("the panel moved", corner(), "-400,100")
local p, rel = Header.anchor:GetPoint(1)
H.checkTrue("the anchor still hangs from the mover", p == "TOPLEFT" and rel == mover)

-- Another setting of the shown size still lays the panel out anew.
H.checkTrue("other keys: a relayout", count(Header, "Refresh", function() RC.Set("r10", "cellSpacing", 4) end) == 1)

-- In combat the panel waits (the secure headers hang from the anchor).
M.combat = true
RC.Set("r10", "x", 64)
H.check("combat: not moved", corner(), "-400,100")
H.check("combat: stored", RC.Get("r10", "x"), 64)
-- (Header.Refresh, queued in combat, is the function of that moment:
-- counted by the cells it restyles.)
H.check("combat: still no relayout queued",
    count(Cell, "Style", function() M.SetCombat(false) end), 0)
H.check("after combat: moved", corner(), "64,100")

-- Test mode's pretend raid hangs from the same anchor.
ns.RaidTestMode.Set(true)
M.RunTimers()
H.check("test mode: no relayout on y", count(Header, "Refresh", function() RC.Set("r10", "y", 40) end), 0)
H.check("test mode: moved", corner(), "64,40")
ns.RaidTestMode.Set(false)
M.RunTimers()

-- Another size's x does nothing to the panel.
H.check("other size: nothing", count(Header, "Refresh", function() RC.Set("r20", "x", 300) end), 0)
H.check("other size: not moved", corner(), "64,40")
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
