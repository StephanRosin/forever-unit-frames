-- The five-second rule on the player's mana bar (0.24.0): after a spell
-- that costs mana, a spark runs across the power bar in 5 s; optional a
-- countdown text and a dimmed fill. On by default with the spark (the
-- maintainer's choice); text and dimming off. Nothing shows at rest.
local M = H.M
local ns = H.LoadAddon()
local S, C, L = ns.Settings, ns.Config, ns.L

-- Settings ------------------------------------------------------------------
local EXPECTED = {
    fsrEnabled = { "FE", "bool", true },
    fsrSpark = { "FK", "bool", true },
    fsrSparkDirection = { "FD", "enum", "LEFT_TO_RIGHT" },
    fsrSparkWidth = { "FW", "int", 3 },
    fsrText = { "FT", "bool", false },
    fsrTextPoint = { "FP", "enum", "CENTER" },
    fsrTextTenths = { "FN", "bool", true },
    fsrSparkColor = { "FC", "color", { 1, 0.9, 0.5, 1 } },
    fsrDim = { "FM", "bool", false },
    fsrDimAlpha = { "FA", "int", 70 },
}
local ORDER = { "fsrEnabled", "fsrSpark", "fsrSparkDirection", "fsrSparkWidth", "fsrSparkColor", "fsrText", "fsrTextPoint",
    "fsrTextTenths", "fsrDim", "fsrDimAlpha" }
for _, key in ipairs(ORDER) do
    local def, want = S.Get(key), EXPECTED[key]
    H.checkTrue(key .. " defined", def)
    H.check(key .. " code", def and def.code, want[1])
    H.check(key .. " type", def and def.type, want[2])
    local default = def and S.Default(def, "player")
    if type(default) == "table" then default = table.concat(default, ",") end
    local wanted = want[3]
    if type(wanted) == "table" then wanted = table.concat(wanted, ",") end
    H.check(key .. " default", default, wanted)
    H.check(key .. " player only", def and S.AppliesTo(def, "target"), false)
    H.check(key .. " label", type(rawget(ns.Locales.enUS, "SETTING_" .. key)), "string")
end
H.check("directions", table.concat(S.Get("fsrSparkDirection").values, ","), "LEFT_TO_RIGHT,RIGHT_TO_LEFT")
H.check("text places", table.concat(S.Get("fsrTextPoint").values, ","), "LEFT,CENTER,RIGHT")
H.check("spark width", S.Get("fsrSparkWidth").min .. "-" .. S.Get("fsrSparkWidth").max, "2-16")
local keys
for _, tab in ipairs(ns.Schema.Tabs("player")) do
    for _, sec in ipairs(tab.sections or {}) do
        if sec.id == "fiveSecondRule" then keys = table.concat(sec.keys, ",") end
    end
end
H.check("its section", keys, table.concat(ORDER, ","))
H.check("section title", L.SECTION_fiveSecondRule, "Five-second rule")

-- A mage with mana; Frostbolt costs mana, a rage spell does not.
M.spells[116] = { name = "Frostbolt", costs = { { type = 0, name = "MANA", cost = 25 } } }
M.spells[78] = { name = "Heroic Strike", costs = { { type = 1, name = "RAGE", cost = 15 } } }
M.spells[999] = { name = "Two costs", costs = { { type = 3, name = "ENERGY", cost = 40 },
    { type = 0, name = "MANA", cost = 50 } } }
M.spells[6603] = { name = "Attack" }
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, health = 10, healthMax = 10,
    power = 800, powerMax = 1000, powerType = 0 }
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local f = ns.Frames.player
local fsr = f.fsr
local fill = f.power:GetStatusBarTexture()
local function running() return fsr.spark:IsShown() and fsr.run:IsPlaying() end

-- At rest ---------------------------------------------------------------------
H.checkTrue("built on the player", fsr)
H.check("not on the target", ns.Frames.target.fsr, nil)
H.check("rest: no spark", fsr.spark:IsShown(), false)
H.check("rest: no text", fsr.text:IsShown(), false)
H.check("rest: the fill in full", fill:GetAlpha(), 1)
H.check("spark: a warm glow", table.concat(fsr.sparkTexture._color or {}, ","), "1,0.9,0.5,1")
H.check("spark: width", fsr.spark:GetWidth(), 3)
H.check("spark: the bar's height", select(2, fsr.spark:GetPoint(1)), f.power)
H.checkTrue("spark above the fill", fsr.spark:GetFrameLevel() > f.power:GetFrameLevel())
H.checkTrue("spark below the power texts", fsr.spark:GetFrameLevel() < f.powerTextLayer:GetFrameLevel())
H.check("animation: a translation", fsr.move:GetObjectType(), "Translation")
H.check("animation: 5 s", fsr.move._duration, 5)

-- A mana spell: the rule runs --------------------------------------------------
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 116)
H.checkTrue("mana spell: the spark runs", running())
H.check("left to right: from the bottom left", (fsr.spark:GetPoint(1)), "BOTTOMLEFT")
H.check("left to right: across the bar", (fsr.move:GetOffset()), f.powerWidth - 3)
H.check("dimming off: fill in full", fill:GetAlpha(), 1)
H.check("text off: none", fsr.text:IsShown(), false)
M.FinishAnimations()
H.check("five seconds later: gone", fsr.spark:IsShown(), false)

M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 78)
H.check("no mana cost: nothing", fsr.spark:IsShown(), false)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 6603)
H.check("free: nothing", fsr.spark:IsShown(), false)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", 4242)
H.check("unknown spell: nothing", fsr.spark:IsShown(), false)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-5", 999)
H.checkTrue("two costs, one mana: runs", running())
M.FinishAnimations()

-- Secrets: a secret ID goes to the client; a secret answer starts nothing.
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", M.Secret("Cast-6"), M.Secret(116))
H.checkTrue("secret spell ID: runs", running())
M.FinishAnimations()
M.spellCostSecret = true
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-7", 116)
H.check("secret costs: nothing", fsr.spark:IsShown(), false)
M.spellCostSecret = false

-- A new spell restarts the five seconds.
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-8", 116)
local started = fsr.startedAt
M.Tick(2)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-9", 116)
H.check("restart: from now", fsr.startedAt, started + 2)
H.checkTrue("restart: still running", running())
M.FinishAnimations()

-- Right to left.
C.Set("player", "fsrSparkDirection", "RIGHT_TO_LEFT")
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-10", 116)
H.check("right to left: from the bottom right", (fsr.spark:GetPoint(1)), "BOTTOMRIGHT")
H.check("right to left: leftwards", (fsr.move:GetOffset()), -(f.powerWidth - 3))
M.FinishAnimations()
C.Set("player", "fsrSparkDirection", "LEFT_TO_RIGHT")
C.Set("player", "fsrSparkWidth", 6)
H.check("own width", fsr.spark:GetWidth(), 6)
H.check("own width: the offset", (fsr.move:GetOffset()), f.powerWidth - 6)
C.Set("player", "fsrSparkWidth", 3)

-- Countdown text -----------------------------------------------------------------
C.Set("player", "fsrText", true)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-11", 116)
H.checkTrue("text: shown", fsr.text:IsShown())
H.check("text: whole seconds", fsr.text:GetText(), "5")
M.Tick(0.1)
H.check("text: 4.9 left reads 5", fsr.text:GetText(), "5")
M.Tick(1.0)
H.check("text: 3.9 left reads 4", fsr.text:GetText(), "4")
M.Tick(3.3)
H.check("text: under a second, tenths", fsr.text:GetText(), "0.6")
C.Set("player", "fsrTextTenths", false)
M.Tick(0.1)
H.check("text: without tenths", fsr.text:GetText(), "1")
H.check("text: centred on the power bar", select(2, fsr.text:GetPoint(1)), f.power)
H.check("text: centre", (fsr.text:GetPoint(1)), "CENTER")
C.Set("player", "fsrTextPoint", "LEFT")
H.check("text: left", (fsr.text:GetPoint(1)), "LEFT")
M.FinishAnimations()
H.check("text: gone at the end", fsr.text:IsShown(), false)
H.check("the ticker stopped", next(M.tickers), nil)
C.Set("player", "fsrTextTenths", true)
C.Set("player", "fsrTextPoint", "CENTER")

-- Dimming -------------------------------------------------------------------------
C.Set("player", "fsrDim", true)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-12", 116)
H.check("dimmed to 70 %", fill:GetAlpha(), 0.7)
C.Set("player", "fsrDimAlpha", 40)
H.check("dimmed to 40 %", fill:GetAlpha(), 0.4)
C.Set("player", "fsrDim", false)
H.check("dimming off mid rule: in full", fill:GetAlpha(), 1)
C.Set("player", "fsrDim", true)
H.check("on again mid rule: dimmed", fill:GetAlpha(), 0.4)
M.FinishAnimations()
H.check("dim: back in full at the end", fill:GetAlpha(), 1)

-- Only while the bar shows mana; spark off still times text and dimming.
C.Set("player", "fsrSpark", false)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-13", 116)
H.check("spark off: no spark drawn", fsr.sparkTexture:IsShown(), false)
H.check("spark off: dimming still on", fill:GetAlpha(), 0.4)
H.checkTrue("spark off: still timed by the animation", fsr.run:IsPlaying())
M.FinishAnimations()
H.check("spark off: the end", fill:GetAlpha(), 1)
C.Set("player", "fsrSpark", true)

M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-14", 116)
M.units.player.powerType = 1
M.FireEvent("UNIT_DISPLAYPOWER", "player")
H.check("no longer mana: stopped", fsr.spark:IsShown(), false)
H.check("no longer mana: fill in full", fill:GetAlpha(), 1)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-15", 999)
H.check("rage bar: nothing", fsr.spark:IsShown(), false)
M.units.player.powerType = 0
M.FireEvent("UNIT_DISPLAYPOWER", "player")

C.Set("player", "fsrEnabled", false)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-16", 116)
H.check("master off: nothing", fsr.spark:IsShown(), false)
C.Set("player", "fsrEnabled", true)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-17", 116)
C.Set("player", "fsrEnabled", false)
H.check("master off mid rule: stopped", fsr.spark:IsShown(), false)
H.check("master off mid rule: fill in full", fill:GetAlpha(), 1)
C.Set("player", "fsrEnabled", true)

-- In combat: plain frames only, nothing refused.
M.SetCombat(true)
M.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-18", 116)
H.checkTrue("in combat: runs", running())
M.FinishAnimations()
H.check("in combat: ends", fsr.spark:IsShown(), false)
H.check("in combat: nothing refused", #M.blocked, 0)
M.SetCombat(false)

-- Test mode: a running sample, gone after.
ns.TestMode.Set(true)
H.checkTrue("test mode: the spark runs", running())
H.check("test mode: it repeats", fsr.run._looping, "REPEAT")
H.checkTrue("test mode: the text", fsr.text:IsShown())
H.check("test mode: dimmed", fill:GetAlpha(), 0.4)
ns.TestMode.Set(false)
H.check("test mode over: no spark", fsr.spark:IsShown(), false)
H.check("test mode over: no text", fsr.text:IsShown(), false)
H.check("test mode over: fill in full", fill:GetAlpha(), 1)
H.check("test mode over: no repeat", fsr.run._looping, "NONE")
C.ResetScope("player")

-- Test mode entered while a real countdown runs: its ticker stops and the
-- sample stays.
do
    local ns2 = H.LoadAddon()
    _G.ForeverUnitFramesDB = nil
    H.M.units.player = { name = "Me", level = 60, class = "PRIEST", className = "PRIEST", isPlayer = true,
        health = 5, healthMax = 10, power = 50, powerMax = 100, powerType = 0 }
    H.M.FireEvent("PLAYER_LOGIN")
    H.M.RunTimers()
    ns2.Config.Set("player", "fsrText", true)
    local f = ns2.Frames.player
    ns2.FiveSecondRule.Start(f)
    H.checkTrue("live countdown: a ticker", f.fsr.ticker ~= nil)
    ns2.TestMode.Set(true)
    H.check("test mode: no ticker", f.fsr.ticker, nil)
    ns2.TestMode.Set(false)
end

-- The spark's colour comes from its setting.
do
    local ns3 = H.LoadAddon()
    _G.ForeverUnitFramesDB = nil
    H.M.units.player = { name = "Me", level = 60, class = "PRIEST", className = "PRIEST", isPlayer = true,
        health = 5, healthMax = 10, power = 50, powerMax = 100, powerType = 0 }
    H.M.FireEvent("PLAYER_LOGIN")
    H.M.RunTimers()
    local f = ns3.Frames.player
    H.check("spark colour: default", table.concat(f.fsr.sparkTexture._color or {}, ","), "1,0.9,0.5,1")
    ns3.Config.Set("player", "fsrSparkColor", { 0.2, 0.6, 1, 1 })
    H.check("spark colour: set", table.concat(f.fsr.sparkTexture._color or {}, ","), "0.2,0.6,1,1")
end
