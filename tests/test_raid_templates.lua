-- Raid templates (Raid/Templates.lua): a template names raid settings
-- and their values; applying it sets only those, on one raid size or on
-- all three (and the character's own settings, for a key that is not per
-- size), as one change that can be undone once.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = {}
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local T, RC, RS = ns.RaidTemplates, ns.RaidConfig, ns.RaidSettings

local events = {}
ns.Listen("RAID_CONFIG_CHANGED", function(scope) events[#events + 1] = tostring(scope) end)

local sample = { id = "sample", values = {
    cellWidth = 120, secondLine = "NONE", cellBorderColor = { 1, 0, 0, 1 },
    cellHeight = T.BySize(50, 45, 40), buffWatchShow = false,
} }

-- The changes, per scope: the sizes asked for, the character's for a key
-- that is not per size.
local changes = assert(T.Changes(sample, { 20 }))
local scopes = {}
for _, c in ipairs(changes) do scopes[#scopes + 1] = c.scope .. ":" .. #c.values end
H.check("changes: the size and the character", table.concat(scopes, ","), "general:1,r20:4")

-- Apply to one size: only the named keys, nothing else.
RC.Set("r20", "cellSpacing", 7)
events = {}
H.checkTrue("applied", T.Apply(sample, { 20 }))
H.check("width", RC.Get("r20", "cellWidth"), 120)
H.check("height of the size", RC.Get("r20", "cellHeight"), 45)
H.check("second line", RC.Get("r20", "secondLine"), "NONE")
H.check("colour", RC.Get("r20", "cellBorderColor")[1], 1)
H.check("character-wide key", RC.Get("general", "buffWatchShow"), false)
H.check("a key it does not name stays", RC.Get("r20", "cellSpacing"), 7)
H.check("another size untouched", RC.Get("r10", "cellWidth"), 96)
H.check("one event per scope", table.concat(events, ","), "general,r20")

-- Undo: everything as before, overrides and defaults alike.
H.checkTrue("undo offered", T.CanUndo())
events = {}
H.checkTrue("undone", T.Undo())
H.check("width back to the default", RC.Get("r20", "cellWidth"), 88)
H.check("no override left", RC.Profile().r20.cellWidth, nil)
H.check("own value kept", RC.Get("r20", "cellSpacing"), 7)
H.check("character-wide back", RC.Get("general", "buffWatchShow"), true)
H.check("undo: one event per scope", table.concat(events, ","), "general,r20")
H.check("one step only", T.CanUndo(), false)
H.check("nothing more to undo", T.Undo(), false)

-- Undo puts back an override as it was.
RC.Set("r10", "cellWidth", 150)
T.Apply(sample, { 10, 20, 40 })
H.check("all sizes: 10", RC.Get("r10", "cellHeight"), 50)
H.check("all sizes: 40", RC.Get("r40", "cellHeight"), 40)
H.check("all sizes: width", RC.Get("r40", "cellWidth"), 120)
T.Undo()
H.check("override back", RC.Get("r10", "cellWidth"), 150)
H.check("40 back", RC.Get("r40", "cellWidth"), 80)

-- Only the last change is undone.
T.Apply(sample, { 10 })
T.Apply({ id = "b", values = { cellWidth = 60 } }, { 10 })
T.Undo()
H.check("last change undone", RC.Get("r10", "cellWidth"), 120)
H.check("then nothing", T.CanUndo(), false)

-- A template with an unknown key or a value its setting refuses is not
-- applied at all.
local before = RC.Get("r10", "cellHeight")
H.check("unknown key", T.Apply({ id = "x", values = { cellHeight = 30, noSuchKey = 1 } }, { 10 }), false)
H.check("out of range", T.Apply({ id = "x", values = { cellHeight = 30, cellWidth = 5000 } }, { 10 }), false)
H.check("wrong choice", T.Apply({ id = "x", values = { cellHeight = 30, secondLine = "BIG" } }, { 10 }), false)
H.check("nothing set", RC.Get("r10", "cellHeight"), before)
H.check("unknown size refused", pcall(T.Apply, sample, { 25 }), false)

-- In combat nothing is applied or undone (the window is locked anyway).
T.Apply(sample, { 10 })
M.combat = true
H.check("no apply in combat", T.Apply({ id = "c", values = { cellWidth = 70 } }, { 10 }), false)
H.check("no undo in combat", T.Undo(), false)
M.combat = false
H.check("still the last change to undo", T.CanUndo(), true)

-- Values the template computes (per class): a function of the class.
local computed = { id = "f", values = { cellWidth = 100 }, extra = function(class)
    return class == "MAGE" and { secondLine = "PERCENT" } or {}
end }
T.Apply(computed, { 40 })
H.check("computed for the class", RC.Get("r40", "secondLine"), "PERCENT")

-- A change made anywhere else (a setting row, a copy, an import) ends the
-- undo: putting back the values from before the template would undo that
-- change too. The undo button hears of it.
T.Apply(sample, { 10 })
H.checkTrue("undo before another change", T.CanUndo())
local told = 0
ns.Listen("RAID_TEMPLATE_UNDO", function() told = told + 1 end)
RC.Set("r10", "cellSpacing", 4)
H.check("another change ends the undo", T.CanUndo(), false)
H.check("the undo button told", told, 1)
H.check("the change kept", RC.Get("r10", "cellSpacing"), 4)
-- Its own events (the apply's, the undo's) do not.
T.Apply(sample, { 10, 20 })
H.check("an apply keeps its own undo", T.CanUndo(), true)
-- Nor does folding the tools bar in or out: a state of the screen, not a
-- setting a template or the undo touches (the bar shows in test mode).
ns.RaidTestMode.Set(true)
ns.RaidTools.Fold()
H.check("folded", RC.Get("general", "toolsOpen"), true)
H.check("the fold keeps the undo", T.CanUndo(), true)
ns.RaidTools.Fold()
ns.RaidTestMode.Set(false)

-- Nothing to change: no change, the undo there was stays.
told = 0
H.checkTrue("nothing to apply", T.ApplyChanges({}))
H.checkTrue("only empty scopes", T.ApplyChanges({ { scope = "r10", values = {} } }))
H.check("the undo kept", T.CanUndo(), true)
H.check("nothing told", told, 0)
T.Undo()
H.check("the earlier change undone", RC.Get("r20", "cellWidth"), 88)

-- A snapshot of a scope the profile does not have: nothing, as Restore.
H.check("snapshot of an unknown scope", #RC.Snapshot("r99", { "cellWidth" }), 0)
