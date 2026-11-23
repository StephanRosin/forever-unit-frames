-- The party's profile (Raid/Profiles.lua: addPartyProfile): once per
-- account each character's party profile becomes the one its party showed
-- up to 0.78 (the 10, or the size sizeMode fixed), so nothing looks
-- different; a new character's party starts at the 10's defaults.
local ns = H.LoadAddon()
local RS, RC, P = ns.RaidSettings, ns.RaidConfig, ns.RaidProfiles

-- Every per-size default of the party is the 10's.
for _, def in ipairs(RS.All()) do
    if RS.AppliesTo(def, "r5") then
        H.check("default " .. def.key, ns.SameValue(RS.Default(def, "r5"), RS.Default(def, "r10")), true)
    end
end

local db = { raid = {
    ["Tester-Testrealm"] = { general = { showInParty = true }, r10 = { cellWidth = 120, x = 40 } },
    -- Fixed at 20: its party showed the 20 (a 20 default differs from the 10's).
    ["Other-Testrealm"] = { general = { sizeMode = "20" }, r10 = { cellWidth = 130 }, r20 = { y = -50 } },
    ["Fresh-Testrealm"] = { general = {} },
} }
P.Attach(db)
H.check("marked done", db.raidPartyProfileAdded, true)
H.check("party: the 10's value", RC.Get("r5", "cellWidth"), 120)
H.check("party: the 10's position", RC.Get("r5", "x"), 40)
H.check("10 kept", RC.Get("r10", "cellWidth"), 120)
local other = db.raid["Other-Testrealm"].r5
H.check("fixed 20: its value", other.y, -50)
H.check("fixed 20: its default where it differs from the 10's", other.cellWidth, RS.Default(RS.Get("cellWidth"), "r20"))
H.check("fresh: nothing stored", next(db.raid["Fresh-Testrealm"].r5), nil)

-- Done once: a party profile set since is kept.
RC.Set("r5", "cellWidth", 70)
db.raid["Tester-Testrealm"].r10.cellWidth = 90
P.Attach(db)
H.check("not again", RC.Get("r5", "cellWidth"), 70)
