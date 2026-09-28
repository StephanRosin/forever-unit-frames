-- A druid's mana while shapeshifted (Elements/DruidMana.lua): a strip at
-- the bottom of the power bar, only while the power shown is not mana.
local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config
C.Use({})
M.units.player = { name = "Druid", class = "DRUID", className = "Druid", isPlayer = true, health = 1, healthMax = 1,
    power = 400, powerMax = 1000, powerType = 0, mana = 400, manaMax = 1000 }
ns.Single.CreateAll()
local p = ns.Frames.player
local bar = p.druidMana

H.check("code", S.Get("druidMana").code, "MD")
H.check("height code", S.Get("druidManaHeight").code, "MH")
H.check("on by default", C.Get("player", "druidMana"), true)
H.check("player only", S.AppliesTo(S.Get("druidMana"), "target"), false)
H.checkTrue("built on the player", bar)
H.check("not on the target", ns.Frames.target.druidMana, nil)

-- Caster form: mana is the power bar itself.
M.FireEvent("UNIT_DISPLAYPOWER", "player")
H.check("caster form: no strip", bar:IsShown(), false)

-- Bear form: rage in the bar, mana in the strip.
M.units.player.powerType, M.units.player.power, M.units.player.powerMax = 1, 20, 100
M.FireEvent("UNIT_DISPLAYPOWER", "player")
H.checkTrue("bear: strip shown", bar:IsShown())
H.check("bear: mana value", bar:GetValue(), 400)
local _, max = bar:GetMinMaxValues()
H.check("bear: mana maximum", max, 1000)
H.check("at the power bar's bottom", select(2, bar:GetPoint(1)), p.power)
H.check("4 px", bar:GetHeight(), 4)
H.check("mana colour", bar._color[3], C.Get("player", "powerColorMana")[3])
-- Secret mana goes through.
M.units.player.mana = M.Secret(350)
M.FireEvent("UNIT_POWER_UPDATE", "player")
H.check("secret mana passed on", bar:GetValue(), M.units.player.mana)
-- Height and switch.
C.Set("player", "druidManaHeight", 8)
H.check("taller", bar:GetHeight(), 8)
C.Set("player", "druidMana", false)
H.check("off: hidden", bar:IsShown(), false)
C.Set("player", "druidMana", true)
-- A secret power type: unknown, hidden.
M.units.player.powerType = M.Secret(1)
M.FireEvent("UNIT_DISPLAYPOWER", "player")
H.check("secret power type: hidden", bar:IsShown(), false)

-- Other classes never.
local ns2 = H.LoadAddon()
ns2.Config.Use({})
M.units.player = { name = "Warrior", class = "WARRIOR", className = "Warrior", isPlayer = true, health = 1,
    healthMax = 1, power = 20, powerMax = 100, powerType = 1 }
ns2.Single.CreateAll()
M.FireEvent("UNIT_DISPLAYPOWER", "player")
H.check("warrior: no strip", ns2.Frames.player.druidMana:IsShown(), false)
