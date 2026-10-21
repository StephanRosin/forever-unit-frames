local M = H.M

-- Migration: the old single profile becomes Default.
local ns = H.LoadAddon()
local db = { profile = { player = { width = 300 } } }
local p, src = ns.Storage.Load(db)
H.check("migrated: source", src, "SavedVariables")
H.check("migrated: value", p.player.width, 300)
H.check("migrated: old key gone", db.profile, nil)
H.check("migrated: Default", db.profiles.Default.player.width, 300)
H.check("migrated: active", ns.UnitProfiles.Active(), "Default")

-- Another character's choice is kept; ours falls back to Default.
ns = H.LoadAddon()
db = { profiles = { Default = { player = { width = 200 } }, Healer = { player = { width = 250 } } },
    active = { ["Alt-Testrealm"] = "Healer" } }
p = ns.Storage.Load(db)
H.check("fallback: Default for a character without entry", p.player.width, 200)
local me = ns.RaidProfiles.CharKey()
db.active[me] = "Gone"
ns = H.LoadAddon()
p = ns.Storage.Load(db)
H.check("fallback: a deleted profile reads Default", p.player.width, 200)
H.check("fallback: active name", ns.UnitProfiles.Active(), "Default")

-- Our own choice.
db.active[me] = "Healer"
ns = H.LoadAddon()
ns.Config.Use(ns.Storage.Load(db))
ns.Storage.Attach(db)
H.check("own choice", ns.Config.Get("player", "width"), 250)
H.check("names", table.concat(ns.UnitProfiles.Names(), ","), "Default,Healer")

-- Save writes the active profile only.
ns.Config.Set("player", "width", 260)
ns.Storage.Save()
H.check("save: active written", db.profiles.Healer.player.width, 260)
H.check("save: Default untouched", db.profiles.Default.player.width, 200)

-- Switch.
H.checkTrue("switch", ns.UnitProfiles.Switch("Default"))
H.check("switch: loaded", ns.Config.Get("player", "width"), 200)
H.check("switch: stored for us", db.active[me], "Default")
H.check("switch: the other character keeps its own", db.active["Alt-Testrealm"], "Healer")
H.check("switch: unknown", select(2, ns.UnitProfiles.Switch("Nope")), "GONE")
M.combat = true
H.check("switch: combat", select(2, ns.UnitProfiles.Switch("Healer")), "COMBAT")
M.combat = false

-- Save as: copy of the current settings, we move onto it.
ns.Config.Set("player", "width", 222)
H.checkTrue("save as", ns.UnitProfiles.SaveAs("  Tank  "))
H.check("save as: trimmed name active", ns.UnitProfiles.Active(), "Tank")
H.check("save as: content", db.profiles.Tank.player.width, 222)
H.check("save as: empty", select(2, ns.UnitProfiles.SaveAs("   ")), "EMPTY")
H.check("save as: too long", select(2, ns.UnitProfiles.SaveAs(("x"):rep(41))), "TOO_LONG")
H.check("save as: taken (any case)", select(2, ns.UnitProfiles.SaveAs("healer")), "TAKEN")

-- Rename: every character on it follows; a change of case is allowed.
db.active["Alt-Testrealm"] = "Tank"
H.checkTrue("rename", ns.UnitProfiles.Rename("Tank Prot"))
H.check("rename: moved", db.profiles["Tank Prot"].player.width, 222)
H.check("rename: old gone", db.profiles.Tank, nil)
H.check("rename: other character follows", db.active["Alt-Testrealm"], "Tank Prot")
H.checkTrue("rename: own name, other case", ns.UnitProfiles.Rename("tank prot"))
H.check("rename: taken", select(2, ns.UnitProfiles.Rename("Healer")), "TAKEN")

-- Delete: everybody on it goes to Default, we load Default.
H.checkTrue("delete", ns.UnitProfiles.Delete())
H.check("delete: gone", db.profiles["tank prot"], nil)
H.check("delete: we are on Default", ns.UnitProfiles.Active(), "Default")
H.check("delete: loaded Default", ns.Config.Get("player", "width"), 200)
H.check("delete: other character back to Default", db.active["Alt-Testrealm"], nil)

-- Default cannot be renamed or deleted.
H.check("default: no rename", select(2, ns.UnitProfiles.Rename("X")), "DEFAULT")
H.check("default: no delete", select(2, ns.UnitProfiles.Delete()), "DEFAULT")
