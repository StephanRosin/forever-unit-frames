-- Every per-size raid setting says what it is (Raid/Settings.lua):
-- "layout" (cell size, spacing, arrangement and panel structure,
-- positions, icon, aura and text sizes) or "behaviour" (sorting,
-- grouping, which auras and indicators show, colours, panels on or off,
-- ...). Copy between sizes (Raid/Profiles.lua) can leave the layout out:
-- one change that Undo takes back.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = {}
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RS, RC, P, T = ns.RaidSettings, ns.RaidConfig, ns.RaidProfiles, ns.RaidTemplates

local CLASSES = { layout = true, behaviour = true }
local counted = 0
for _, def in ipairs(RS.All()) do
    if def.scope ~= "general" then
        counted = counted + 1
        H.checkTrue("a class: " .. def.key, CLASSES[def.class])
    else
        H.check("none for a character setting: " .. def.key, def.class, nil)
    end
end
H.checkTrue("many per-size settings", counted > 100)
for key, want in pairs({ cellWidth = "layout", cellSpacing = "layout", sortBy = "behaviour", groupBy = "behaviour",
    x = "layout", y = "layout", mainTanksX = "layout", panel2Y = "layout", nameFontSize = "layout",
    secondFontSize = "layout", nameColor = "behaviour", secondLineColor = "behaviour", indicatorTopLeftSpells =
    "behaviour", indicatorTopLeftSize = "layout", dispelIconSize = "layout", mainTanksShow = "behaviour",
    healPrediction = "behaviour", classOrder = "behaviour" }) do
    H.check("class of " .. key, RS.Get(key).class, want)
end

-- Copy 10 onto 40: everything, or without the layout and sizes.
RC.Set("r10", "cellWidth", 150)
RC.Set("r10", "sortBy", "NAME")
RC.Set("r10", "nameColor", { 1, 0, 0, 1 })
RC.Set("r40", "x", 33)
RC.Set("r40", "groupBy", "CLASS")
H.checkTrue("copied without layout", P.CopySizeMode(10, 40, "BEHAVIOUR"))
H.check("behaviour copied", RC.Get("r40", "sortBy"), "NAME")
H.check("colour copied", RC.Get("r40", "nameColor")[2], 0)
H.check("behaviour at 10's default copied too", RC.Get("r40", "groupBy"), "GROUP")
H.check("layout kept", RC.Get("r40", "cellWidth"), 80)
H.check("position kept", RC.Get("r40", "x"), 33)
H.checkTrue("undo offered", T.CanUndo())
T.Undo()
H.check("undone", RC.Get("r40", "sortBy"), "INDEX")
H.check("undone too", RC.Get("r40", "groupBy"), "CLASS")
H.checkTrue("copied everything", P.CopySizeMode(10, 40, "ALL"))
H.check("everything: layout", RC.Get("r40", "cellWidth"), 150)
H.check("everything: position", RC.Get("r40", "x"), -600)
H.check("everything: behaviour", RC.Get("r40", "sortBy"), "NAME")
T.Undo()
H.check("everything undone", RC.Get("r40", "x"), 33)
H.check("same size refused", P.CopySizeMode(10, 10, "ALL"), false)
M.combat = true
H.check("not in combat", P.CopySizeMode(10, 40, "ALL"), false)
M.combat = false
