-- Export of all three raid sizes in one string, and its import
-- (Raid/Profiles.lua): a string of one size goes into the size asked for,
-- as before; a string of several sets every size it holds, as one change
-- that Undo takes back. The character's own settings are never in it.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = {}
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, P, T = ns.RaidConfig, ns.RaidProfiles, ns.RaidTemplates

RC.Set("r10", "cellWidth", 120)
RC.Set("r40", "x", 12)
RC.Set("general", "showInParty", true)
local all = P.ExportAll()
-- Its own format version: a size left at its defaults counts as held too,
-- and a reader of version 1 (an older build) refuses it instead of reading
-- only some sizes.
H.check("all sizes: format version 2", all, "2;aCW120;cX12")
H.check("a version-1 reader refuses it", select(2, ns.RaidCodec.Decode(all)), "CODEC_VERSION")
H.check("the unit frames' reader too", select(2, ns.Codec.Decode(all)), "CODEC_VERSION")
H.check("one size stays version 1", P.Export(10), "1;aCW120")
H.check("no character setting", all:match(";g"), nil)
H.check("held: every size", table.concat(P.ImportSizes(all), ","), "10,20,40")
H.check("held: one size", table.concat(P.ImportSizes(P.Export(10)), ","), "10")
H.check("held: a defaults-only one-size string", table.concat(P.ImportSizes("1"), ","), "")
H.check("held: two sizes without the mark", table.concat(P.ImportSizes("1;aCW100;bCW90"), ","), "10,20")
H.check("held: a bad string", select(2, P.ImportSizes("garbage")), "CODEC_FORMAT")
H.check("held: version 2 alone is every size", table.concat(P.ImportSizes("2"), ","), "10,20,40")
H.check("held: a malformed version 2", select(2, P.ImportSizes("2x;aCW100")), "CODEC_FORMAT")
H.check("held: a newer version", select(2, P.ImportSizes("3;aCW100")), "CODEC_VERSION")

-- Round trip: change everything, import the string back.
RC.Set("r10", "cellWidth", 60)
RC.Set("r20", "cellHeight", 20)
RC.Set("r40", "x", 99)
local ok, rejected = P.ImportAll(all)
H.checkTrue("imported", ok)
H.check("nothing left out", rejected, 0)
H.check("10 back", RC.Get("r10", "cellWidth"), 120)
H.check("20 back to its defaults", RC.Get("r20", "cellHeight"), 40)
H.check("no override left on 20", next(RC.Profile().r20), nil)
H.check("40 back", RC.Get("r40", "x"), 12)
H.check("character setting untouched", RC.Get("general", "showInParty"), true)
-- One change: Undo takes it back.
H.checkTrue("undo offered", T.CanUndo())
T.Undo()
H.check("undo 10", RC.Get("r10", "cellWidth"), 60)
H.check("undo 20", RC.Get("r20", "cellHeight"), 20)
H.check("undo 40", RC.Get("r40", "x"), 99)

-- A string of two sizes (no mark): only those two.
P.ImportAll("1;aCW100;bCW90")
H.check("mixed: 10", RC.Get("r10", "cellWidth"), 100)
H.check("mixed: 20", RC.Get("r20", "cellWidth"), 90)
H.check("mixed: 20's own value replaced", RC.Get("r20", "cellHeight"), 40)
H.check("mixed: 40 kept", RC.Get("r40", "x"), 99)

-- Refusals: a one-size string is not an all-sizes import, and the
-- one-size import does not take several.
H.check("one size to ImportAll", select(2, P.ImportAll(P.Export(10))), "RAID_ONE_SIZE")
H.check("several to Import", select(2, P.Import(all, 20)), "RAID_SEVERAL_SIZES")
H.check("newer string to ImportAll", select(2, P.ImportAll("3;aCW1")), "CODEC_VERSION")
H.check("malformed version 2 to ImportAll", select(2, P.ImportAll("2a;aCW1")), "CODEC_FORMAT")
M.combat = true
H.check("not in combat", select(2, P.ImportAll(all)), "RAID_COMBAT")
M.combat = false
-- Old one-size strings stay valid.
H.checkTrue("old string", P.Import("1;bX12", 10))
H.check("old string imported", RC.Get("r10", "x"), 12)
-- A count of unreadable entries.
local _, bad = P.ImportAll("2;aCW100;junk")
H.check("unreadable counted", bad, 1)
-- Version 2 alone: every size back to its defaults.
H.checkTrue("defaults-only all sizes", P.ImportAll("2"))
H.check("10 at its defaults", next(RC.Profile().r10), nil)
H.check("no error", #M.errors, 0)
