local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
local C = ns.Config

-- ClearOverride
C.Set("target", "fontSize", 9)
H.checkTrue("override set", C.IsOverridden("target", "fontSize"))
C.ClearOverride("target", "fontSize")
H.check("override cleared", C.IsOverridden("target", "fontSize"), false)
H.check("falls back to general", C.Get("target", "fontSize"), 12)

-- CopyScope copies look, not position
C.Set("player", "width", 333); C.Set("player", "x", -500); C.Set("player", "fontSize", 15)
C.Set("target", "height", 60)
C.CopyScope("player", "target")
H.check("width copied", C.Get("target", "width"), 333)
H.check("font copied", C.Get("target", "fontSize"), 15)
H.check("x not copied", C.Get("target", "x"), 300)
H.check("target's own override replaced", C.Get("target", "height"), 46)

-- Copy reproduces the source's look, including its per-frame defaults.
C.Import({ general = {}, player = { enabled = false }, target = { y = 12 } })
H.check("setup: player has no text overrides", C.IsOverridden("player", "textHealthRight"), false)
C.CopyScope("player", "target")
H.check("copy: player's default castbar switch", C.Get("target", "castbarEnabled"), false)
H.check("copy: player's default power text", C.Get("target", "textPowerRight"), "CURRENT")
H.check("copy: same default stays no override", C.IsOverridden("target", "width"), false)
H.check("copy: enabled not copied", C.Get("target", "enabled"), true)
H.check("copy: target's y kept", C.Get("target", "y"), 12)
C.Set("target", "enabled", false)
C.CopyScope("player", "target")
H.check("copy: target's own enabled kept", C.Get("target", "enabled"), false)
-- Inherited settings follow general unless the source overrides them.
C.Import({ general = { fontSize = 10 }, player = {}, target = { fontSize = 16 } })
C.CopyScope("player", "target")
H.check("copy: inherited value", C.Get("target", "fontSize"), 10)
H.check("copy: inherited value is no override", C.IsOverridden("target", "fontSize"), false)

-- Import replaces everything
C.Import({ general = { fontSize = 10 }, player = {}, target = { width = 111 } })
H.check("import general", C.Get("player", "fontSize"), 10)
H.check("import target", C.Get("target", "width"), 111)
H.check("import cleared player width", C.Get("player", "width"), 220)

-- Debounced save
ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
local writes = 0
local realWrite = ns.MacroBackup.Write
ns.MacroBackup.Write = function(s) writes = writes + 1; return realWrite(s) end
for w = 230, 240 do ns.Config.Set("player", "width", w) end
H.check("nothing saved before the timer", writes, 0)
M.RunTimers()
H.check("one save after the timer", writes, 1)
H.check("last value saved", ns.MacroBackup.Read(), "1;pW240")
ns.Config.Set("player", "width", 250)
M.FireEvent("PLAYER_LOGOUT")
H.check("flush on logout", ns.MacroBackup.Read(), "1;pW250")

-- Texts: unknown tag clears, power deficit uses UnitPowerMissing
ns = H.LoadAddon()
ns.Config.Use({})
M.units.player = { name = "T", level = 60, health = 1, healthMax = 1, power = 30, powerMax = 100, powerMissing = 70 }
ns.Single.CreateAll()
local fs = ns.Frames.player.texts.powerLeft
fs:SetText("stale")
ns.Texts.Apply(fs, "SOMETHING_NEW", "player", "power")
H.check("unknown tag clears", fs._text, "")
ns.Texts.Apply(fs, "DEFICIT", "player", "power")
H.check("power deficit", fs._text, 70)

-- Movers: locking mid-drag saves the position
ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
for _, f in pairs(ns.Frames) do ns.Movers.Attach(f) end
ns.Movers.Unlock()
local mv = ns.Frames.player.mover
mv:GetScript("OnDragStart")(mv)
mv._cx, mv._cy = 960 + 64, 540 - 32
UIParent._cx, UIParent._cy = 960, 540
ns.Movers.Lock()
H.check("lock during drag saves x", ns.Config.Get("player", "x"), 64)
H.check("lock during drag saves y", ns.Config.Get("player", "y"), -32)
