-- Compact values ("1234/1234"), a size of their own for value texts, and
-- INFO with only the class (players) or creature type (reaction colour)
-- coloured, e.g. "30[red] Druid[orange] Night Elf[white]".
local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config
C.Use({})
M.units.player = { name = "Me", level = 30, class = "PRIEST", className = "Priest", isPlayer = true,
    health = 1234, healthMax = 1234, power = 500, powerMax = 900, powerType = 0 }
M.units.target = { name = "Leaf", level = 30, class = "DRUID", className = "Druid", race = "Night Elf",
    isPlayer = true, health = 800, healthMax = 1000, power = 1, powerMax = 1 }
ns.Single.CreateAll()
local p, t = ns.Frames.player, ns.Frames.target

for key, code in pairs({ textCompact = "TC", valueFontSize = "TV", infoClassColor = "NK" }) do
    H.check("code of " .. key, S.Get(key).code, code)
end

-- Compact --------------------------------------------------------------------------
C.Set("player", "textHealthLeft", "CURRENT_MAX")
H.check("spaced by default", p.texts.healthLeft._fmt, "%s / %s")
C.Set("general", "textCompact", true)
H.check("compact", p.texts.healthLeft._fmt, "%s/%s")

-- Value size -----------------------------------------------------------------------
C.Set("player", "fontSize", 12)
C.Set("player", "titleText", "NAME")
C.Set("player", "titlePercent", 30)
local function size(fs) return select(2, fs:GetFont()) end
H.check("auto: the font size", size(p.texts.healthLeft), 12)
C.Set("player", "valueFontSize", 16)
H.check("numbers bigger", size(p.texts.healthLeft), 16)
H.check("the name keeps the font size", size(p.texts.title), 12)
C.Set("player", "textHealthRight", "INFO")
H.check("level/class/race keeps the font size", size(p.texts.healthRight), 12)

-- INFO with the class coloured ----------------------------------------------------
C.Set("target", "textPowerLeft", "INFO")
C.Set("target", "levelColorMode", "DIFFICULTY")
H.check("plain by default", t.texts.powerLeft._fmt, "%s %s %s")
C.Set("target", "infoClassColor", true)
local druid = RAID_CLASS_COLORS.DRUID
local hex = ("%02x%02x%02x"):format(druid.r * 255, druid.g * 255, druid.b * 255)
H.check("class wrapped in its colour", t.texts.powerLeft._fmt, "%s |cff" .. hex .. "%s|r %s")
H.check("class passed as it is", t.texts.powerLeft._args[2], "Druid")
H.check("race plain", t.texts.powerLeft._args[3], "Night Elf")
H.checkTrue("level keeps its difficulty colour", t.texts.powerLeft._args[1]:find("^|cff") ~= nil)
-- A creature: its type in the reaction colour.
M.units.target = { name = "Lumberjack", level = 30, creatureType = "Humanoid", reaction = 5, health = 5,
    healthMax = 10 }
M.FireEvent("PLAYER_TARGET_CHANGED")
ns.Single.UpdateAll(t)
local g = C.Get("target", "reactionFriendlyColor")
local ghex = ("%02x%02x%02x"):format(g[1] * 255, g[2] * 255, g[3] * 255)
H.check("creature type in the friendly colour", t.texts.powerLeft._fmt, "%s |cff" .. ghex .. "%s|r")
-- A secret class token: no colour, the class still shows.
M.units.target = { name = "Leaf", level = 30, class = M.Secret("DRUID"), className = M.Secret("Druid"),
    race = "Night Elf", isPlayer = true, health = 800, healthMax = 1000 }
M.FireEvent("PLAYER_TARGET_CHANGED")
ns.Single.UpdateAll(t)
H.check("secret class: plain", t.texts.powerLeft._fmt, "%s %s %s")
