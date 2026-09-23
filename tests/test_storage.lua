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
H.check("broken provider skipped", src, "defaults")

-- 3. Macro backup next.
ns = H.LoadAddon()
ns.MacroBackup.Write("1;pW320")
p, src = ns.Storage.Load(nil)
H.check("source macro", src, "macro backup")
H.check("macro value", p.player.width, 320)

-- 4. Defaults last.
ns = H.LoadAddon()
p, src = ns.Storage.Load(nil)
H.check("source defaults", src, "defaults")
H.check("empty profile", next(p.player), nil)

-- Macro backup details
ns = H.LoadAddon()
local long = "1;" .. string.rep("pW250;", 60)   -- ~362 chars, needs two macros
H.checkTrue("write long", ns.MacroBackup.Write(long))
H.check("two macros", #M.macros, 2)
H.check("macro name", M.macros[1].name, "FUF Save 1")
H.checkTrue("per character", M.macros[1].perChar)
H.check("read back", ns.MacroBackup.Read(), long)
H.checkTrue("shorter write", ns.MacroBackup.Write("1;pW250"))
H.check("second macro emptied", ns.MacroBackup.Read(), "1;pW250")
H.check("too long refused", ns.MacroBackup.Write(string.rep("x", 600)), false)
M.macroFrameShown = true
H.check("refused while macro frame open", ns.MacroBackup.Write("1;pW251"), false)
M.macroFrameShown = false
M.combat = true
H.check("refused in combat", ns.MacroBackup.Write("1;pW251"), false)
M.combat = false

-- Save fans out and skips unchanged strings.
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
H.check("macro written", ns.MacroBackup.Read(), "1;pW280")
ns.Storage.Save()
H.check("unchanged not re-saved", #saved, 1)
M.combat = true
ns.Config.Set("player", "width", 281)
ns.Storage.Save()
H.check("macro deferred in combat", ns.MacroBackup.Read(), "1;pW280")
M.SetCombat(false)
H.check("macro written after combat", ns.MacroBackup.Read(), "1;pW281")
