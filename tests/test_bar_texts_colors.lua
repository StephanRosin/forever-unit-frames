-- Wishes from a CurseForge comment: names on the bars in class colour, a
-- level/class/race text, power colours per type, and a shield that shows
-- at full health (absorbMode END).
local M = H.M
local ns = H.LoadAddon()
local S, C, L = ns.Settings, ns.Config, ns.L
C.Use({})
M.units.player = { name = "Tester", level = 60, class = "MAGE", className = "Mage", race = "Gnome", isPlayer = true,
    health = 1000, healthMax = 1000, power = 400, powerMax = 500, powerType = 0 }
M.units.target = { name = "Ogre", level = 58, creatureType = "Humanoid", hostile = true, health = 5, healthMax = 10 }
ns.Single.CreateAll()
local p, t = ns.Frames.player, ns.Frames.target

-- Settings -----------------------------------------------------------------------
local codes = { barNameColorMode = "NY", absorbMode = "AP", powerColorMana = "UM", powerColorRage = "UG",
    powerColorFocus = "UF", powerColorEnergy = "UE" }
for key, code in pairs(codes) do
    H.check("code of " .. key, S.Get(key).code, code)
    H.checkTrue(key .. " labelled", L["SETTING_" .. key] ~= "SETTING_" .. key)
end
H.check("INFO appended (stored by index)", S.TEXT_TAGS[#S.TEXT_TAGS], "INFO")
H.check("INFO labelled", L.ENUM_INFO, "Level, class and race")
H.check("names white by default", C.Get("party", "barNameColorMode"), "WHITE")
H.check("shield after the health by default", C.Get("player", "absorbMode"), "AFTER")

-- Name colour on the bars --------------------------------------------------------
C.Set("player", "titlePercent", 0)
C.Set("player", "textHealthLeft", "NAME")
C.Set("player", "textHealthRight", "PERCENT")
H.check("white by default", table.concat(p.texts.healthLeft._color, ","), "1,1,1,1")
C.Set("player", "barNameColorMode", "CLASS")
local r, g, b = ns.Health.UnitColor("player", "CLASS")
H.check("name in class colour", table.concat(p.texts.healthLeft._color, ",", 1, 3), table.concat({ r, g, b }, ","))
H.check("value text stays white", table.concat(p.texts.healthRight._color, ","), "1,1,1,1")
C.Set("player", "textHealthLeft", "CURRENT")
H.check("a value tag is never coloured", table.concat(p.texts.healthLeft._color, ","), "1,1,1,1")

-- Level, class and race ----------------------------------------------------------
C.Set("player", "textPowerLeft", "INFO")
H.check("player: format", p.texts.powerLeft._fmt, "%s %s %s")
H.check("player: level, class, race", table.concat(p.texts.powerLeft._args, " "), "60 Mage Gnome")
C.Set("target", "textPowerLeft", "INFO")
H.check("creature: level and type", table.concat(t.texts.powerLeft._args, " "), "58 Humanoid")
M.units.target.creatureType = nil
M.FireEvent("UNIT_LEVEL", "target")
H.check("no type: the level alone", t.texts.powerLeft._text, "58")
-- Secret class and race go through untouched.
M.units.player.className, M.units.player.race = M.Secret("Mage"), M.Secret("Gnome")
M.FireEvent("UNIT_LEVEL", "player")
H.check("secret class passed on", p.texts.powerLeft._args[2], M.units.player.className)
H.checkTrue("INFO counts as a name", ns.Texts.NAME_TAGS.INFO)

-- Power colours ------------------------------------------------------------------
C.Set("general", "powerColorMana", { 0.1, 0.2, 0.9, 1 })
M.FireEvent("UNIT_DISPLAYPOWER", "player")
H.check("mana colour from General", p.power._color[3], 0.9)
C.Set("player", "powerColorMana", { 0.5, 0.5, 0.5, 1 })
M.FireEvent("UNIT_DISPLAYPOWER", "player")
H.check("overridden per frame", p.power._color[1], 0.5)
M.units.player.powerType = 1
M.FireEvent("UNIT_DISPLAYPOWER", "player")
H.check("rage has its own", p.power._color[1], C.Get("player", "powerColorRage")[1])

-- Shield at the bar's end --------------------------------------------------------
local bar = p.absorb
local point, rel = bar:GetPoint(1)
H.check("after: from the end of the incoming heals", rel, p.healAll:GetStatusBarTexture())
H.check("after: fills right", bar._reverse, false)
C.Set("player", "absorbMode", "END")
point, rel = bar:GetPoint(1)
H.check("end: at the bar's right end", point, "TOPRIGHT")
H.check("end: on the health bar", rel, p.health)
H.check("end: fills to the left", bar._reverse, true)
M.units.player.absorbs = 300
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("end: full health still shows it", bar:GetValue(), 300)
C.Set("player", "absorbMode", "AFTER")
H.check("back after the health", bar._reverse, false)

-- Options ------------------------------------------------------------------------
local function sectionOf(scope, key)
    for _, tab in ipairs(ns.Schema.Tabs(scope)) do
        for _, sec in ipairs(tab.sections or {}) do
            for _, k in ipairs(sec.keys) do if k == key then return tab.id .. ":" .. sec.id end end
        end
    end
end
H.check("name colour with the health texts", sectionOf("party", "barNameColorMode"), "text:healthText")
H.check("shield position with the shields", sectionOf("party", "absorbMode"), "bars:absorbs")
H.check("power colours on the bars tab", sectionOf("party", "powerColorMana"), "bars:powerColors")
H.check("power colours in General", sectionOf("general", "powerColorMana"), "colors:powerColors")
