local M = H.M

-- 1. SavedVariables win when present.
local ns = H.LoadAddon()
local db = { profile = { player = { width = 300 } } }
local p, src = ns.Storage.Load(db)
H.check("source SV", src, "SavedVariables")
H.check("SV value", p.player.width, 300)

-- 2. Provider next.
ns = H.LoadAddon()
ForeverUnitFrames.RegisterStorageProvider("Test provider", {
    load = function() return "1;pW310" end,
    save = function(s) ns._saved = s end,
})
p, src = ns.Storage.Load(nil)
H.check("source provider", src, "Test provider")
H.check("provider value", p.player.width, 310)

-- A broken provider is skipped.
ns = H.LoadAddon()
ForeverUnitFrames.RegisterStorageProvider("Broken", { load = function() error("boom") end, save = function() end })
p, src = ns.Storage.Load(nil)
H.check("broken provider skipped", src, "Defaults")

-- 3. An old macro backup next (migration).
ns = H.LoadAddon()
M.macros = M.BackupMacros("1;pW320")
p, src = ns.Storage.Load(nil)
H.check("source macro", src, "MacroBackup")
H.check("macro value", p.player.width, 320)

-- SavedVariables win over an old macro backup.
p, src = ns.Storage.Load({ profile = { player = { width = 300 } } })
H.check("SV before macro", src, "SavedVariables")

-- 4. Defaults last.
ns = H.LoadAddon()
p, src = ns.Storage.Load(nil)
H.check("source defaults", src, "Defaults")
H.check("empty profile", next(p.player), nil)

-- Save fans out and skips unchanged strings; combat does not delay it.
ns = H.LoadAddon()
local saved = {}
ForeverUnitFrames.RegisterStorageProvider("Rec", { load = function() end, save = function(s) saved[#saved + 1] = s end })
local svdb = {}
ns.Storage.Attach(svdb)
p = ns.Storage.Load(svdb)
ns.Config.Use(p)
ns.Config.Set("player", "width", 280)
ns.Storage.Save()
H.check("provider got string", saved[1], "1;pW280")
H.check("SV written", svdb.profile.player.width, 280)
H.check("SV format version", svdb.version, ns.Codec.VERSION)
ns.Storage.Save()
H.check("unchanged not re-saved", #saved, 1)
M.combat = true
ns.Config.Set("player", "width", 281)
ns.Storage.Save()
H.check("saved in combat", svdb.profile.player.width, 281)
H.check("provider saved in combat", saved[2], "1;pW281")
M.SetCombat(false)
H.check("no macro written", M.macroWrites, 0)
H.check("no macro created", #M.macros, 0)

-- SavedVariables are sanitised: unknown scopes/keys and invalid values go.
ns = H.LoadAddon()
p = ns.Storage.Load({ profile = {
    player = { width = "wide", height = 50, bogus = 1 },
    nonsense = { width = 100 },
    general = { width = 300, fontSize = 14 },
} })
H.check("SV invalid value dropped", p.player.width, nil)
H.check("SV valid value kept", p.player.height, 50)
H.check("SV unknown key dropped", p.player.bogus, nil)
H.check("SV unknown scope dropped", p.nonsense, nil)
H.check("SV frame-only key dropped from general", p.general.width, nil)
H.check("SV general value kept", p.general.fontSize, 14)
ns.Config.Use(p)
H.checkTrue("save after sanitised load does not throw", pcall(ns.Storage.Save))
