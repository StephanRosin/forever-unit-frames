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

-- 3. Macro backup next.
ns = H.LoadAddon()
ns.MacroBackup.Write("1;pW320")
p, src = ns.Storage.Load(nil)
H.check("source macro", src, "MacroBackup")
H.check("macro value", p.player.width, 320)

-- 4. Defaults last.
ns = H.LoadAddon()
p, src = ns.Storage.Load(nil)
H.check("source defaults", src, "Defaults")
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

-- Capacity: character macros full, no free slot for a new backup macro.
ns = H.LoadAddon()
for i = 1, 30 do
    table.insert(M.macros, { name = "Other Macro " .. i, icon = "", body = "", perChar = true })
end
H.check("full: write refused", ns.MacroBackup.Write("1;pW1"), false)
H.check("full: last error", ns.MacroBackup.LastError(), "MACRO_FULL")
H.check("full: macros untouched", #M.macros, 30)

-- Capacity: exactly one free slot but two chunks needed.
ns = H.LoadAddon()
for i = 1, 29 do
    table.insert(M.macros, { name = "Other Macro " .. i, icon = "", body = "", perChar = true })
end
H.check("one free slot: write refused", ns.MacroBackup.Write(long), false)
H.check("one free slot: last error", ns.MacroBackup.LastError(), "MACRO_FULL")
H.check("one free slot: macros untouched", #M.macros, 29)

-- Ownership: a macro named "FUF Save 1" that isn't ours is never touched.
ns = H.LoadAddon()
table.insert(M.macros, { name = "FUF Save 1", icon = "", body = "/cast Fireball", perChar = true })
H.check("foreign: write refused", ns.MacroBackup.Write("1;pW1"), false)
H.check("foreign: last error", ns.MacroBackup.LastError(), "MACRO_FOREIGN")
H.check("foreign: body untouched", M.macros[1].body, "/cast Fireball")

-- Read: header says 1/2 but macro 2 is missing -> incomplete backup, no backup.
ns = H.LoadAddon()
H.checkTrue("write for incomplete-read test", ns.MacroBackup.Write(long))
table.remove(M.macros, 2)
H.check("incomplete backup unread", ns.MacroBackup.Read(), nil)

-- Read: "FUF Save 1" exists but its body is a foreign macro, not ours.
ns = H.LoadAddon()
table.insert(M.macros, { name = "FUF Save 1", icon = "", body = "/cast Fireball", perChar = true })
H.check("foreign body unread", ns.MacroBackup.Read(), nil)

-- Stale indices: only "FUF Save 2" exists. Creating "FUF Save 1" re-sorts
-- the list, so the index of macro 2 must be looked up again before editing.
ns = H.LoadAddon()
table.insert(M.macros, { name = "FUF Save 2", icon = "", body = "", perChar = true })
H.checkTrue("re-sort: write two chunks", ns.MacroBackup.Write(long))
H.check("re-sort: two macros", #M.macros, 2)
local names = {}
for _, m in ipairs(M.macros) do names[m.name] = true end
H.checkTrue("re-sort: both names present", names["FUF Save 1"] and names["FUF Save 2"])
H.check("re-sort: read back", ns.MacroBackup.Read(), long)

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

-- A refused macro write is retried: on the next Save and when the macro
-- window closes. Each distinct error is reported once.
local function countChat(text)
    local n = 0
    for _, line in ipairs(M.chat) do if line:find(text, 1, true) then n = n + 1 end end
    return n
end
ns = H.LoadAddon()
ns.Config.Use({})
M.macroFrameShown = true
ns.Config.Set("player", "width", 290)
H.check("retry: refused while window open", ns.MacroBackup.Read(), nil)
H.check("retry: error printed", countChat(ns.L.MACRO_FRAME_OPEN), 1)
H.check("retry: last macro error kept", ns.Storage.MacroError(), "MACRO_FRAME_OPEN")
ns.Config.Set("player", "width", 291)
H.check("retry: same error not printed again", countChat(ns.L.MACRO_FRAME_OPEN), 1)
M.macroFrameShown = false
MacroFrame:GetScript("OnHide")(MacroFrame)
H.check("retry: written when window closes", ns.MacroBackup.Read(), "1;pW291")
H.check("retry: error cleared", ns.Storage.MacroError(), nil)

-- Same profile, write refused, then a plain Save retries the macro.
ns = H.LoadAddon()
ns.Config.Use({})
M.macroFrameShown = true
ns.Config.Set("player", "width", 292)
M.macroFrameShown = false
ns.Storage.Save()
H.check("retry: unchanged profile still retried on Save", ns.MacroBackup.Read(), "1;pW292")

-- Load-on-demand macro window: hooked once Blizzard_MacroUI loads.
ns = H.LoadAddon()
_G.MacroFrame = nil
ns.Config.Use({})
M.macroFrameShown = true
_G.MacroFrame = M.NewMacroFrame()
ns.Config.Set("player", "width", 293)
H.check("lod: refused while window open", ns.MacroBackup.Read(), nil)
M.FireEvent("ADDON_LOADED", "Blizzard_MacroUI")
M.macroFrameShown = false
H.checkTrue("lod: OnHide hooked", MacroFrame:GetScript("OnHide"))
if MacroFrame:GetScript("OnHide") then MacroFrame:GetScript("OnHide")(MacroFrame) end
H.check("lod: written when window closes", ns.MacroBackup.Read(), "1;pW293")
