-- Test mode: health texts show values that match the sample health bar
-- (Health.SAMPLE), not the player's live health; live values come back
-- when test mode ends.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, P = ns.Config, ns.Party
M.units.player = { name = "Me", level = 60, health = 100, healthMax = 100, healthPercent = 1, healthMissing = 0,
    power = 30, powerMax = 50, powerPercent = 0.6 }
M.FireEvent("PLAYER_ENTERING_WORLD")

local f = ns.Frames.player
local left, right, title = f.texts.healthLeft, f.texts.healthRight, f.texts.title
H.check("live: percent", right._args[1], 100)
H.check("live: current", left._args[1], "100")

ns.TestMode.Set(true)
H.check("sample: percent", right._args[1], 60)
H.check("sample: format", right._fmt, "%.0f%%")
H.check("sample: current", left._args[1], "60")
H.check("sample: max from the player", left._args[2], "100")
-- Power texts stay live: the power bar is live.
C.Set("player", "textPowerLeft", "CURRENT")
H.check("power stays live", f.texts.powerLeft:GetText(), "30")
-- Real health events keep the sample.
M.units.player.health, M.units.player.healthPercent = 50, 0.5
M.FireEvent("UNIT_HEALTH", "player")
H.check("event: sample kept", right._args[1], 60)
H.check("event: current kept", left._args[1], "60")
-- Every value tag on the health bar, and on the title row.
C.Set("player", "textHealthLeft", "DEFICIT")
H.check("sample: deficit", left:GetText(), 40)
C.Set("player", "textHealthLeft", "CURRENT")
H.check("sample: current alone", left:GetText(), "60")
C.Set("player", "titleText", "PERCENT")
H.check("title: sample percent", title._args[1], 60)
C.Set("player", "titleText", "NAME_LEVEL")
C.Set("player", "textHealthLeft", "CURRENT_MAX")
-- A maximum that cannot be read: a round sample maximum.
M.units.player.healthMax = M.Secret(100)
M.FireEvent("UNIT_MAXHEALTH", "player")
H.check("secret max: sample current", left._args[1], "6000")
H.check("secret max: sample max", left._args[2], "10.0k")
M.units.player.healthMax = 100
-- Other frames and the pretend party.
H.check("target: sample percent", ns.Frames.target.texts.healthRight._args[1], 60)
H.check("party: sample percent", P.fakes[1].texts.healthRight._args[1], 60)

ns.TestMode.Set(false)
H.check("live again: percent", right._args[1], 50)
H.check("live again: current", left._args[1], "50")
H.check("live again: max", left._args[2], "100")
