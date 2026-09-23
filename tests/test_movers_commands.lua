local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
for _, f in pairs(ns.Frames) do ns.Movers.Attach(f) end

local f = ns.Frames.player
H.checkTrue("mover exists", f.mover)
local p, rel = f:GetPoint(1)
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
