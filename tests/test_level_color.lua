-- The level number in its difficulty colour (levelColorMode DIFFICULTY),
-- wrapped in a colour code so the rest of the line keeps its colour.
local M = H.M
local ns = H.LoadAddon()
local S, C, T = ns.Settings, ns.Config, ns.Texts
C.Use({})
M.units.player = { name = "Me", level = 30, class = "MAGE", className = "Mage", isPlayer = true,
    health = 1, healthMax = 1 }
M.units.target = { name = "Ogre", level = 36, hostile = true, health = 5, healthMax = 10 }
ns.Single.CreateAll()
local t = ns.Frames.target

H.check("code", S.Get("levelColorMode").code, "LV")
H.check("text colour by default", C.Get("target", "levelColorMode"), "TEXT")

-- The rule against a level-30 player (grey from 22 down).
H.check("grey level at 30", T.GreyLevel(30), 22)
H.check("grey level at 60", T.GreyLevel(60), 51)
H.check("grey level at 5", T.GreyLevel(5), 0)
local function col(level) return table.concat({ T.DifficultyColor(level) }, ",") end
local D = T.DIFFICULTY
H.check("+5: red", col(35), table.concat(D.impossible, ","))
H.check("+4: orange", col(34), table.concat(D.verydifficult, ","))
H.check("+3: orange", col(33), table.concat(D.verydifficult, ","))
H.check("+2: yellow", col(32), table.concat(D.difficult, ","))
H.check("-2: yellow", col(28), table.concat(D.difficult, ","))
H.check("-3: green", col(27), table.concat(D.standard, ","))
H.check("grey level: grey", col(22), table.concat(D.trivial, ","))
H.check("boss: red", col(-1), table.concat(D.impossible, ","))

-- Title row: "36 Ogre" with only the number coloured.
C.Set("target", "titleText", "NAME_LEVEL")
H.check("off: plain level", t.texts.title._args[1], "36")
C.Set("target", "levelColorMode", "DIFFICULTY")
H.check("on: the number wrapped in red", t.texts.title._args[1], "|cffff1919" .. "36|r")
H.check("the name stays apart", t.texts.title._args[2], "Ogre")
-- Level tag and INFO too.
C.Set("target", "textHealthLeft", "LEVEL")
H.check("level tag coloured", t.texts.healthLeft._text, "|cffff191936|r")
C.Set("target", "textPowerLeft", "INFO")
H.check("info without a type: the coloured level", t.texts.powerLeft._text, "|cffff191936|r")
-- A secret level: left out as before, nothing compared.
M.units.target.level = M.Secret(36)
M.FireEvent("UNIT_LEVEL", "target")
H.check("secret: no level", t.texts.healthLeft._text, "")

-- Options: next to the title colour.
local found
for _, tab in ipairs(ns.Schema.Tabs("target")) do
    for _, sec in ipairs(tab.sections or {}) do
        for _, k in ipairs(sec.keys) do if k == "levelColorMode" then found = tab.id .. ":" .. sec.id end end
    end
end
H.check("in the title text section", found, "text:titleText")
