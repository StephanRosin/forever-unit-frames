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
    { name = "Three", sizes = { r10 = { cellWidth = 101, enabled = false }, r20 = { cellWidth = 102 },
        r40 = { cellWidth = 9999 }, r99 = { cellWidth = 1 } } },
    { name = "Broken", sizes = "not a table", values = { cellWidth = 77 } },
} }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local T, RC = ns.RaidTemplates, ns.RaidConfig
local saved = ForeverUnitFramesDB.raidTemplates

-- Cleaned at login: valid names once (case ignored), known per-size
-- settings with values they take (clamped as an import is).
local names = {}
for i, t in ipairs(T.Own()) do names[i] = t.name end
H.check("kept", table.concat(names, ","), "Old,NoValues,Three,Broken")
H.checkTrue("the saved table is the cleaned one", saved == ForeverUnitFramesDB.raidTemplates and #saved == 4)
-- A template of several sizes: each size cleaned like an import.
local three = T.Find("own:Three")
H.check("sizes held", table.concat(T.Held(three), ","), "10,20,40")
H.check("its 10", three.sizes.r10.cellWidth, 101)
H.check("its 40 clamped", three.sizes.r40.cellWidth, 200)
H.check("character key dropped from a size", three.sizes.r10.enabled, nil)
H.check("unknown size dropped", three.sizes.r99, nil)
H.check("one-size: held nothing of its own", T.Held(T.Find("own:Old")), nil)
H.check("sizes not a table: one size", T.Find("own:Broken").values.cellWidth, 77)
H.check("broken sizes dropped", T.Find("own:Broken").sizes, nil)
-- Applied: each held size into its size, as one change.
T.Apply(three, { 20 })
H.check("applied 10", RC.Get("r10", "cellWidth"), 101)
H.check("applied 20", RC.Get("r20", "cellWidth"), 102)
H.check("applied 40", RC.Get("r40", "cellWidth"), 200)
T.Undo()
H.check("undone 10", RC.Get("r10", "cellWidth"), 96)
H.check("undone 40", RC.Get("r40", "cellWidth"), 80)
T.DeleteOwn("own:Three")
T.DeleteOwn("own:Broken")
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
-- Save all three sizes: each as shown.
RC.Set("r40", "cellHeight", 77)
H.checkTrue("saved all", T.SaveOwn("All of them", "ALL"))
local allOf = T.Find("own:All of them")
H.check("all: 20", allOf.sizes.r20.cellWidth, 150)
H.check("all: 40", allOf.sizes.r40.cellHeight, 77)
H.check("all: 10 default", allOf.sizes.r10.cellWidth, 96)
H.check("all: no one-size values", allOf.values, nil)
H.check("all: in the saved variables", saved[#saved].sizes.r40.cellHeight, 77)
T.DeleteOwn("own:All of them")
RC.Set("r40", "cellHeight", 38)
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
