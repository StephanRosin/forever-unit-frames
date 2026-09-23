local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
for _, f in pairs(ns.Frames) do ns.Movers.Attach(f) end

local f = ns.Frames.player
H.checkTrue("mover exists", f.mover)
local _, rel = f:GetPoint(1)
H.check("frame anchored to mover", rel, f.mover)

H.check("snap 13 -> 16", ns.Movers.Snap(13), 16)
H.check("snap -13 -> -16", ns.Movers.Snap(-13), -16)
H.check("snap 3 -> 0", ns.Movers.Snap(3), 0)

H.checkTrue("unlock", ns.Movers.Unlock())
H.checkTrue("mover shown", f.mover:IsShown())
-- Drag: mover centre moved to (960 + 101, 540 - 50) on a 1920x1080 UIParent.
f.mover._cx, f.mover._cy = 1061, 490
UIParent._cx, UIParent._cy = 960, 540
ns.Movers.OnDragStop(f.mover)
H.check("x saved snapped", ns.Config.Get("player", "x"), 104)
H.check("y saved snapped", ns.Config.Get("player", "y"), -48)
ns.Movers.Lock()
H.check("mover hidden after lock", f.mover:IsShown(), false)

M.combat = true
H.check("no unlock in combat", ns.Movers.Unlock(), false)
M.combat = false

-- Regression: two scope changes in combat must not leave a mover's size
-- stale. Sync reads size from Config directly, never from the frame's own
-- (possibly not-yet-restyled) current size, so queue ordering cannot matter.
M.combat = true
ns.Config.Set("player", "width", 300)
ns.Config.Set("target", "width", 280)
M.SetCombat(false)
H.check("player mover width matches config", ns.Frames.player.mover:GetWidth(), 300)
H.check("target mover width matches config", ns.Frames.target.mover:GetWidth(), 280)
H.check("player mover/frame width match", ns.Frames.player.mover:GetWidth(), ns.Frames.player:GetWidth())
H.check("target mover/frame width match", ns.Frames.target.mover:GetWidth(), ns.Frames.target:GetWidth())
M.combat = false

-- Combat starting locks the frames down before secure lockdown takes effect.
ns.Movers.Unlock()
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("mover hidden on combat start", f.mover:IsShown(), false)
H.check("unlocked cleared on combat start", ns.Movers.IsUnlocked(), false)

-- No dragging while in combat, even if a mover is somehow still shown/enabled.
M.combat = true
local started = false
local origStart = f.mover.StartMoving
f.mover.StartMoving = function(...) started = true end
f.mover:GetScript("OnDragStart")(f.mover)
H.check("no StartMoving while in combat", started, false)
f.mover.StartMoving = origStart
M.combat = false

-- Attach during combat defers the whole thing until combat ends.
local fake = M.newWidget("Button", nil, UIParent)
fake.key = "target"
M.combat = true
ns.Movers.Attach(fake)
H.check("attach deferred: no mover yet", fake.mover, nil)
H.check("attach deferred: not yet anchored", fake._points[1], nil)
M.SetCombat(false)
H.checkTrue("attach completed after combat ends", fake.mover ~= nil)
local _, fakeRel = fake:GetPoint(1)
H.check("deferred frame anchored to its mover", fakeRel, fake.mover)
M.combat = false

-- Unlock must not error over a frame that has no mover.
local bare = M.newWidget("Button", nil, UIParent)
bare.key = "target"
ns.Frames.bare = bare
local ok = pcall(ns.Movers.Unlock)
H.checkTrue("unlock survives a mover-less frame", ok)
ns.Movers.Lock()
ns.Frames.bare = nil

-- Commands
local run = SlashCmdList.FOREVERUNITFRAMES
H.checkTrue("slash registered", run and SLASH_FOREVERUNITFRAMES1 == "/fuf")
run("set player width 300")
H.check("set via command", ns.Config.Get("player", "width"), 300)
run("set player width banana")
H.checkTrue("bad value reported", M.chat[#M.chat]:find("Invalid"))
run("reset player")
H.check("reset via command", ns.Config.Get("player", "width"), 220)
run("status")
H.checkTrue("status mentions storage", table.concat(M.chat, "\n"):find("Settings loaded from"))

run("set player width nan")
H.checkTrue("nan rejected", M.chat[#M.chat]:find("Invalid"))
H.check("width unchanged after nan", ns.Config.Get("player", "width"), 220)

run("set general fontFace garbage")
H.checkTrue("bad media name rejected", M.chat[#M.chat]:find("Invalid"))

run("reset nobody")
H.checkTrue("unknown frame reported", M.chat[#M.chat]:find("Unknown frame"))
