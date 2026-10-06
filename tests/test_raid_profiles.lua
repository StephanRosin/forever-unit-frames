-- Raid settings and profiles (Raid/Settings.lua, Raid/Profiles.lua): one
-- profile per character with a scope per raid size, copying between sizes
-- and characters, export and import of one size.
local M = H.M
local ns = H.LoadAddon()
local Raid, RS, RC, P = ns.Raid, ns.RaidSettings, ns.RaidConfig, ns.RaidProfiles

H.check("sizes", table.concat(Raid.SIZES, ","), "10,20,40")
H.check("scope of a size", Raid.Scope(20), "r20")
H.check("scopes", table.concat(RS.SCOPES, ","), "general,r10,r20,r40")
H.check("size mode code", RS.Get("sizeMode").code, "SM")
H.check("x is per size", RS.AppliesTo(RS.Get("x"), "general"), false)
H.check("size mode is per character", RS.AppliesTo(RS.Get("sizeMode"), "r10"), false)

-- The character key.
H.check("char key", P.CharKey(), "Tester-Testrealm")
M.fullNameRealm = false
H.check("char key without realm from UnitFullName", P.CharKey(), "Tester-Testrealm")
M.fullNameRealm = true

-- Attach: this character's saved profile, cleaned; others stay as they are.
local db = { raid = {
    ["Tester-Testrealm"] = { general = { sizeMode = "20", bogus = 1 }, r10 = { x = 99999 } },
    ["Healer-Testrealm"] = { r20 = { x = -100, y = 40 } },
    ["Broken-Testrealm"] = "not a table",
} }
P.Attach(db)
H.check("own profile in use", RC.Get("general", "sizeMode"), "20")
H.check("unknown key dropped", db.raid["Tester-Testrealm"].general.bogus, nil)
H.check("value clamped", RC.Get("r10", "x"), 4000)
H.checkTrue("saved table is the one in use", RC.Profile() == db.raid["Tester-Testrealm"])
H.check("other characters, sorted, valid only", table.concat(P.Characters(), ","), "Healer-Testrealm")

-- A new character gets an empty profile in the store.
local fresh = {}
M.playerName = "Newbie"
P.Attach(fresh)
H.checkTrue("new character stored", type(fresh.raid["Newbie-Testrealm"]) == "table")
H.check("defaults", RC.Get("general", "sizeMode"), "AUTO")
M.playerName = "Tester"
P.Attach(db)

-- Changes go straight into SavedVariables and fire the raid event only.
local raidEvents, unitEvents = 0, 0
ns.Listen("RAID_CONFIG_CHANGED", function() raidEvents = raidEvents + 1 end)
ns.Listen("CONFIG_CHANGED", function() unitEvents = unitEvents + 1 end)
RC.Set("r10", "x", -250)
H.check("saved at once", db.raid["Tester-Testrealm"].r10.x, -250)
H.check("raid event", raidEvents, 1)
H.check("no unit-frame event", unitEvents, 0)

-- Copy between sizes: everything, position included.
P.CopySize(10, 40)
H.check("copy size: x", RC.Get("r40", "x"), -250)
P.ResetSize(40)
H.check("reset size", RC.Get("r40", "x"), -600)

-- Copy from another character.
H.checkTrue("copy from character", P.CopyFromCharacter("Healer-Testrealm", 20, 10))
H.check("copied x", RC.Get("r10", "x"), -100)
H.check("copied y", RC.Get("r10", "y"), 40)
H.check("source untouched", db.raid["Healer-Testrealm"].r10, nil)
H.check("unknown character", P.CopyFromCharacter("Nobody-Testrealm", 20, 10), false)
H.check("not from yourself", P.CopyFromCharacter("Tester-Testrealm", 20, 10), false)

-- Export one size, import it on another.
RC.Set("r20", "x", 12)
local s = P.Export(20)
H.check("export holds one size", s, "1;bX12")
H.checkTrue("import", P.Import(s, 40))
H.check("imported on 40", RC.Get("r40", "x"), 12)
RC.Set("r40", "y", 77)
H.checkTrue("import replaces the whole size", P.Import(s, 40))
H.check("y back to default", RC.Get("r40", "y"), 150)
H.checkTrue("defaults-only string resets", P.Import("1", 40))
H.check("reset by import", RC.Get("r40", "x"), -600)
local ok, err = P.Import("garbage", 40)
H.check("bad string refused", ok, nil)
H.check("bad string error", err, "CODEC_FORMAT")
H.check("general not exported", P.Export(10):match(";g"), nil)
