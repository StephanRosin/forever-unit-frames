-- Importing one raid size (Raid/Profiles.lua): a string must hold a raid
-- size, or be exactly the string of a size left at the defaults; what the
-- codec could not read is counted and handed back.
local ns = H.LoadAddon()
local RC, P, L = ns.RaidConfig, ns.RaidProfiles, ns.L
P.Attach({})

-- A size's export goes on, nothing skipped.
RC.Set("r20", "cellWidth", 120)
local ok, skipped = P.Import(P.Export(20), 10)
H.check("export imports", ok, true)
H.check("nothing skipped", skipped, 0)
H.check("imported", RC.Get("r10", "cellWidth"), 120)

-- The defaults string resets the size.
RC.Set("r40", "cellWidth", 150)
ok, skipped = P.Import("1", 40)
H.check("defaults string imports", ok, true)
H.check("defaults string: nothing skipped", skipped, 0)
H.check("defaults string resets", RC.Get("r40", "cellWidth"), 80)

-- Anything else without a size is refused, and the size kept.
RC.Set("r40", "cellWidth", 150)
local err
ok, err = P.Import("1;gSM2", 40)
H.check("only character-wide entries: refused", ok, nil)
H.check("refused: no size", err, "RAID_NO_SIZE")
ok, err = P.Import("1;zzz", 40)
H.check("unreadable entries only: refused", ok, nil)
H.check("refused: no size either", err, "RAID_NO_SIZE")
ok, err = P.Import("1;", 40)
H.check("an empty entry is not the defaults string", ok, nil)
H.check("size kept after a refusal", RC.Get("r40", "cellWidth"), 150)
H.check("a codec error stays the codec's", select(2, P.Import("garbage", 40)), "CODEC_FORMAT")

-- Entries the codec could not read are counted.
ok, skipped = P.Import("1;aCW100;aCWx;aZZ1;junk", 20)
H.check("readable part imports", ok, true)
H.check("unreadable entries counted", skipped, 2)
H.check("readable part applied", RC.Get("r20", "cellWidth"), 100)

-- The messages for the window.
H.check("no-size message", L.IMPORT_RAID_NO_SIZE, "This text holds no raid size.")
H.check("skipped message", L.IMPORT_SKIPPED:format(2), "Imported; 2 entries could not be read and were left out.")
