-- A power tick does no text work on a frame that shows no power value
-- (Elements/Texts.lua: frame.textKinds).
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local f = ns.Frames.player
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100,
    power = 50, powerMax = 100, powerType = 0 }
local looks = 0
-- Texts.Update's first read.
local real = ns.Config.Get
ns.Config.Get = function(scope, key)
    if key == "showSurname" then looks = looks + 1 end
    return real(scope, key)
end
M.FireEvent("UNIT_POWER_FREQUENT", "player")
H.checkTrue("power texts shown: updated", looks > 0)
for _, key in ipairs({ "titleText", "titleTextRight", "titleTextCenter", "textHealthLeft", "textHealthRight",
    "textHealthCenter", "textPowerLeft", "textPowerRight", "textPowerCenter", "footerTextLeft", "footerTextRight",
    "footerTextCenter" }) do
    if ns.Settings.Get(key) then ns.Config.Set("player", key, "NONE") end
end
M.RunTimers()
looks = 0
M.FireEvent("UNIT_POWER_FREQUENT", "player")
H.check("no power text: skipped", looks, 0)
M.FireEvent("UNIT_HEALTH", "player")
H.checkTrue("a health tick still looks", looks > 0)
ns.Config.Get = real
