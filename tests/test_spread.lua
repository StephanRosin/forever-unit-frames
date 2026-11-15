-- ns.Spread: work after combat over several frames, never in one script.
local M = H.M
local ns = H.LoadAddon()
local done, now = {}, 0
_G.debugprofilestop = function() return now end
ns.Spread({ "a", "b", "c" }, function(x) done[#done + 1] = x; now = now + 30 end)
H.check("nothing in the calling script", #done, 0)
local first = table.remove(M.timers, 1)
first.fn()
H.check("one item per frame over budget", #done, 1)
M.combat = true
table.remove(M.timers, 1).fn()
H.check("combat: stops", #done, 1)
H.check("combat: no further frame", #M.timers, 0)

-- Left over at combat start: handed back.
M.combat = false
M.timers = {}
local back = 0
ns.Spread({ 1, 2, 3 }, function() now = now + 30 end, function() back = back + 1 end)
table.remove(M.timers, 1).fn()
M.combat = true
table.remove(M.timers, 1).fn()
H.check("combat: rest handed back", back, 1)
M.combat = false
