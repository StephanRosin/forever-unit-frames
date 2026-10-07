-- Own raid templates (Raid/Templates.lua): the edited size's settings
-- saved under a name, per account (ForeverUnitFramesDB.raidTemplates),
-- applied to a size like a shipped one, deleted; checked when loaded like
-- an import.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = { raidTemplates = {
    { name = "Old", values = { cellWidth = 130, noSuchKey = 1, secondLine = "BIG", cellHeight = 9999,
        enabled = false } },
    { name = "  ", values = { cellWidth = 100 } },
    { name = "old", values = { cellWidth = 90 } },
    "not a table",
    { name = "NoValues" },
} }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local T, RC = ns.RaidTemplates, ns.RaidConfig
local saved = ForeverUnitFramesDB.raidTemplates

-- Cleaned at login: valid names once (case ignored), known per-size
-- settings with values they take (clamped as an import is).
local names = {}
for i, t in ipairs(T.Own()) do names[i] = t.name end
H.check("kept", table.concat(names, ","), "Old,NoValues")
H.checkTrue("the saved table is the cleaned one", saved == ForeverUnitFramesDB.raidTemplates and #saved == 2)
local old = T.Own()[1]
H.check("value kept", old.values.cellWidth, 130)
H.check("unknown key dropped", old.values.noSuchKey, nil)
H.check("refused value dropped", old.values.secondLine, nil)
H.check("clamped", old.values.cellHeight, 100)
H.check("character-wide key dropped", old.values.enabled, nil)
H.check("own id", old.id, "own:Old")
H.check("found by id", T.Find("own:Old"), old)
H.check("shipped found too", T.Find("healer"), T.Get("healer"))

-- Save the edited size: every per-size setting as shown.
RC.Set("r20", "cellWidth", 150)
H.checkTrue("saved", T.SaveOwn("Mine", 20))
local mine = T.Find("own:Mine")
H.check("own value", mine.values.cellWidth, 150)
H.check("default as shown", mine.values.cellHeight, 40)
H.check("no character-wide key", mine.values.buffWatchShow, nil)
H.check("in the saved variables", saved[3].name, "Mine")
-- Applied to another size: that size looks the same.
T.Apply(mine, { 40 })
H.check("applied", RC.Get("r40", "cellWidth"), 150)
H.check("its height", RC.Get("r40", "cellHeight"), 40)
T.Undo()
H.check("undone", RC.Get("r40", "cellWidth"), 80)
-- The same name (any case) replaces it.
RC.Set("r20", "cellWidth", 160)
H.checkTrue("replaced", T.SaveOwn("MINE", 20))
H.check("still three", #T.Own(), 3)
H.check("new value", T.Find("own:MINE").values.cellWidth, 160)
-- Names: trimmed, not empty, not too long.
H.check("empty name", select(2, T.SaveOwn("   ", 20)), "EMPTY")
H.check("too long", select(2, T.SaveOwn(("x"):rep(T.OWN_NAME_LETTERS + 1), 20)), "TOO_LONG")
H.checkTrue("trimmed", T.SaveOwn("  Spaced  ", 20) and T.Find("own:Spaced"))
-- At most OWN_MAX.
for i = #T.Own() + 1, T.OWN_MAX do T.SaveOwn("T" .. i, 10) end
H.check("full", select(2, T.SaveOwn("One more", 10)), "FULL")
H.checkTrue("replacing still works when full", T.SaveOwn("Old", 10))
-- Delete.
H.checkTrue("deleted", T.DeleteOwn("own:Spaced"))
H.check("gone", T.Find("own:Spaced"), nil)
H.check("unknown", T.DeleteOwn("own:Nope"), false)
H.check("shipped cannot be deleted", T.DeleteOwn("healer"), false)
-- The list changes are announced.
local fired = 0
ns.Listen("RAID_TEMPLATES_CHANGED", function() fired = fired + 1 end)
T.SaveOwn("Ann", 10)
T.DeleteOwn("own:Ann")
H.check("announced", fired, 2)
