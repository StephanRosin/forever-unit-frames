-- Movers for positions outside the unit-frame profile (Core/Movers.lua):
-- a spec may bring its own config, a scope that changes (a function) and
-- a top-left origin. Unit-frame movers keep their centre and profile.
local M = H.M
local ns = H.LoadAddon()
local Movers, RC = ns.Movers, ns.RaidConfig
ns.Config.Use({})
ns.RaidProfiles.Attach({})

local function point(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    return table.concat({ p, rel == UIParent and "UIParent" or "?", relPoint, x, y }, " ")
end

local target = CreateFrame("Frame", nil, UIParent)
local size, current = { 120, 60 }, "r10"
Movers.Attach(target, {
    scope = function() return current end, config = RC, id = "test", point = "TOPLEFT", origin = "TOPLEFT",
    size = function() return size[1], size[2] end, label = function() return "Test " .. current end,
    active = function() return RC.Get("general", "enabled") end,
})
local mover = target.mover
H.check("corner from its own config", point(mover), "TOPLEFT UIParent CENTER -600 150")
local p, rel, relPoint = target:GetPoint(1)
H.checkTrue("target hangs from the handle's corner", p == "TOPLEFT" and rel == mover and relPoint == "TOPLEFT")
H.check("label", mover.label:GetText(), "Test r10")
size = { 200, 80 }
Movers.Sync(target)
H.check("bigger: the corner stays", point(mover), "TOPLEFT UIParent CENTER -600 150")
H.check("bigger: handle size", mover:GetWidth(), 200)

-- Dragged: the corner, snapped to the grid, into its own config and scope.
Movers.Unlock()
mover._cx, mover._cy = 97 + 100, -47 - 40
Movers.OnDragStop(mover)
H.check("x stored as the corner", RC.Get("r10", "x"), 96)
H.check("y stored as the corner", RC.Get("r10", "y"), -48)
H.check("unit-frame profile untouched", next(ns.Config.Profile().general), nil)
Movers.Sync(target)
H.check("synced to the stored corner", point(mover), "TOPLEFT UIParent CENTER 96 -48")

-- The scope changes: the other scope's corner and label.
RC.Set("r20", "x", 200)
current = "r20"
Movers.Sync(target)
H.check("other scope's corner", point(mover), "TOPLEFT UIParent CENTER 200 150")
H.check("label follows", mover.label:GetText(), "Test r20")

-- Its own settings switch it off while unlocked.
H.checkTrue("active: shown", mover:IsShown())
RC.Set("general", "enabled", false)
H.check("inactive: hidden at once", mover:IsShown(), false)
RC.Set("general", "enabled", true)
H.checkTrue("active again", mover:IsShown())
Movers.Lock()

-- A unit frame's mover: its centre, the unit-frame profile.
local frame = CreateFrame("Frame", nil, UIParent)
frame.key = "player"
Movers.Attach(frame)
H.check("unit frame: centre", point(frame.mover), "CENTER UIParent CENTER -300 -220")
Movers.Unlock()
frame.mover._cx, frame.mover._cy = 41, 9
Movers.OnDragStop(frame.mover)
H.check("unit frame: x", ns.Config.Get("player", "x"), 40)
H.check("unit frame: y", ns.Config.Get("player", "y"), 8)
H.check("unit frame: raid profile untouched", RC.Get("r10", "x"), 96)
Movers.Lock()

-- A scope that changes cannot name the mover: such a spec brings an id.
H.checkError("function scope without an id", function()
    Movers.Attach(CreateFrame("Frame", nil, UIParent), {
        scope = function() return "r10" end, config = RC, size = function() return 10, 10 end,
    })
end)
