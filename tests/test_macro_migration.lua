-- Versions up to 0.2.x kept a copy of the settings in character macros,
-- because the client did not load SavedVariables on a full restart. The
-- client loads them again: the addon no longer writes macros, reads an old
-- backup once to migrate a profile that exists nowhere else, and removes
-- its own backup macros once the profile is safe in SavedVariables.
local M = H.M

-- The clean-up is silent: nothing about macros reaches the chat.
local function chatCount(text)
    local n = 0
    for _, line in ipairs(M.chat) do
        if line:find(text, 1, true) then n = n + 1 end
    end
    return n
end

local function names()
    local list = {}
    for i, m in ipairs(M.macros) do list[i] = m.name end
    return table.concat(list, ",")
end

local function withOthers(list)
    table.insert(list, 1, { name = "Another Macro", icon = "", body = "/dance", perChar = true })
    list[#list + 1] = { name = "Zz Other", icon = "", body = "/wave", perChar = true }
    return list
end

-- One session. `db`: the SavedVariables as the client hands them back.
-- `macros`: the character macros; with `late` they arrive only after
-- PLAYER_LOGIN (UPDATE_MACROS), as on a full restart.
local function login(db, macros, late)
    local ns = H.LoadAddon()
    _G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
    _G.ForeverUnitFramesDB = db
    M.macros = late and {} or (macros or {})
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    if late then
        M.macros = macros or {}
        M.FireEvent("UPDATE_MACROS")
    end
    return ns
end

local function sv(width) return { profile = { player = { width = width } } } end
local function status()
    M.chat = {}
    SlashCmdList.FOREVERUNITFRAMES("status")
    return table.concat(M.chat, "\n")
end

-- Reading ----------------------------------------------------------------------
local ns = H.LoadAddon()
M.macros = M.BackupMacros("1;pW260;tHM4")
M.RoundTripMacros("\r\n", true)
H.check("read: CRLF and trailing line break", ns.MacroBackup.Read(), "1;pW260;tHM4")
M.macros = { { name = "FUF Save 1", icon = "", perChar = true,
    body = "#Forever Unit Frames backup 1/1 - keep\r1;pW260 \t\r\n\n" } }
H.check("read: lone CR and mixed whitespace", ns.MacroBackup.Read(), "1;pW260")
M.macros = M.BackupMacros({ "1;pW2", "60" })
M.RoundTripMacros("\r\n", true)
H.check("read: chunks joined without their line breaks", ns.MacroBackup.Read(), "1;pW260")
M.macros = M.BackupMacros({ "a", "b", "c", "d", "e", "f" })
H.check("read: six chunks", ns.MacroBackup.Read(), "abcdef")
M.macros = M.BackupMacros({ "a", "b", "c", "d", "e", "f", "g" })
H.check("read: seven chunks are not ours", ns.MacroBackup.Read(), nil)
M.macros = M.BackupMacros({ "a", "b", "c" })
table.remove(M.macros, 2)
H.check("read: missing chunk means no backup", ns.MacroBackup.Read(), nil)
M.macros = M.BackupMacros({ "a", "b", "c" })
M.macros[3].body = "#Forever Unit Frames backup 3/2 - keep\nc"
H.check("read: chunks disagree on n", ns.MacroBackup.Read(), nil)
M.macros = M.BackupMacros({ "abc" })
for i = 2, 6 do
    M.macros[i] = { name = "FUF Save " .. i, icon = "", perChar = true,
        body = ("#Forever Unit Frames backup %d/1 - keep\n"):format(i) }
end
H.check("read: blanked macros 2 to 6 ignored", ns.MacroBackup.Read(), "abc")
M.macros = { { name = "FUF Save 1", icon = "", body = "/cast Fireball", perChar = true } }
H.check("read: foreign body is no backup", ns.MacroBackup.Read(), nil)
M.macros = {}
H.check("read: no macros", ns.MacroBackup.Read(), nil)

-- Deleting ---------------------------------------------------------------------
ns = H.LoadAddon()
M.macros = withOthers(M.BackupMacros({ "a", "b", "c" }))
H.check("delete: count", ns.MacroBackup.Delete(), 3)
H.check("delete: only ours removed", names(), "Another Macro,Zz Other")
H.check("delete: nothing left", ns.MacroBackup.Delete(), 0)

-- Blanked leftovers of a shrunk backup and an incomplete backup are ours too.
M.macros = M.BackupMacros({ "abc" })
M.macros[2] = { name = "FUF Save 2", icon = "", perChar = true,
    body = "#Forever Unit Frames backup 2/1 - keep\r\n" }
M.macros[3] = { name = "FUF Save 4", icon = "", perChar = true,
    body = "#Forever Unit Frames backup 4/5 - keep\nd" }
H.check("delete: blanked and stray chunks", ns.MacroBackup.Delete(), 3)
H.check("delete: all gone", #M.macros, 0)

-- A macro under one of our names but with the player's body stays, and so
-- does our header under a name that is not ours or with the wrong number.
M.macros = {
    { name = "FUF Save 1", icon = "", body = "/cast Fireball", perChar = true },
    { name = "FUF Save 2", icon = "", perChar = true, body = "#Forever Unit Frames backup 3/3 - keep\nx" },
    { name = "My Copy", icon = "", perChar = true, body = "#Forever Unit Frames backup 1/1 - keep\n1;pW1" },
    { name = "FUF Save 3", icon = "", perChar = true, body = "#Forever Unit Frames backup 3/3 - keep\nc" },
    { name = "FUF Save 5", icon = "", perChar = true, body = "# Forever Unit Frames backup 5/6 - keep\nc" },
}
H.check("delete: foreign bodies kept", ns.MacroBackup.Delete(), 1)
H.check("delete: foreign names kept", names(), "FUF Save 1,FUF Save 2,My Copy,FUF Save 5")
H.check("delete: foreign body untouched", M.macros[1].body, "/cast Fireball")

-- Never in combat, never while the macro window is open.
M.macros = M.BackupMacros("1;pW260")
M.combat = true
H.check("delete: refused in combat", ns.MacroBackup.Delete(), nil)
M.combat = false
M.macroFrameShown = true
H.check("delete: refused while the macro window is open", ns.MacroBackup.Delete(), nil)
M.macroFrameShown = false
H.check("delete: macros kept while refused", #M.macros, 1)
H.check("delete: no macro write", M.macroWrites, 0)

-- SavedVariables loaded: the old macros go ------------------------------------
ns = login(sv(250), withOthers(M.BackupMacros({ "1;pW2", "60" })))
H.check("SV: source", ns.Storage.Source(), "SavedVariables")
H.check("SV: SV value wins over the backup", ns.Config.Get("player", "width"), 250)
H.check("SV: backup removed at login", names(), "Another Macro,Zz Other")
H.check("SV: silent", chatCount("macros removed") + chatCount("migrated"), 0)
M.FireEvent("UPDATE_MACROS")
M.RunTimers()
H.check("SV: still silent", chatCount("macros removed") + chatCount("migrated"), 0)
ns.Config.Set("player", "width", 251)
M.RunTimers()
M.FireEvent("PLAYER_LOGOUT")
H.check("SV: changes saved", ForeverUnitFramesDB.profile.player.width, 251)
H.check("SV: no macro written", M.macroWrites, 0)
H.check("SV: no macro created", #M.macros, 2)

-- Macros that reach the client after PLAYER_LOGIN are removed when they come.
ns = login(sv(250), M.BackupMacros("1;pW260"), true)
H.check("SV late: removed on UPDATE_MACROS", #M.macros, 0)
H.check("SV late: silent", chatCount("macros removed") + chatCount("migrated"), 0)
H.check("SV late: SV value kept", ns.Config.Get("player", "width"), 250)

-- SavedVariables loaded: saving is never held back for macros.
ns = login(sv(250))
ns.Config.Set("player", "width", 252)
M.RunTimers(1)
H.check("SV: no waiting", ns.Storage.IsWaiting(), false)
H.check("SV: saved at once", ForeverUnitFramesDB.profile.player.width, 252)
H.check("SV without backup: nothing said", chatCount("macros removed") + chatCount("migrated"), 0)
H.check("SV without backup: nothing deleted", M.macroDeletes, 0)

-- In combat: removed only once combat has ended.
ns = login(sv(250))
M.combat = true
M.macros = M.BackupMacros("1;pW260")
M.FireEvent("UPDATE_MACROS")
H.check("combat: kept in combat", #M.macros, 1)
M.SetCombat(false)
H.check("combat: removed after combat", #M.macros, 0)
H.check("combat: silent", chatCount("macros removed") + chatCount("migrated"), 0)

-- Macro window open: removed once it closes.
ns = login(sv(250))
M.macroFrameShown = true
M.macros = M.BackupMacros("1;pW260")
M.FireEvent("UPDATE_MACROS")
H.check("window open: kept", #M.macros, 1)
H.check("window open: nothing said", chatCount("macros removed") + chatCount("migrated"), 0)
M.macroFrameShown = false
MacroFrame:GetScript("OnHide")(MacroFrame)
H.check("window closed: removed", #M.macros, 0)
H.check("window closed: silent", chatCount("macros removed") + chatCount("migrated"), 0)

-- A player's macro under our name survives the clean-up.
ns = login(sv(250), { { name = "FUF Save 1", icon = "", body = "/cast Fireball", perChar = true } })
H.check("foreign at cleanup: kept", M.macros[1] and M.macros[1].body, "/cast Fireball")
H.check("foreign at cleanup: nothing said", chatCount("macros removed") + chatCount("migrated"), 0)

-- A storage provider: no waiting and no clean-up (SavedVariables are empty).
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.macros = M.BackupMacros("1;pW260")
ForeverUnitFrames.RegisterStorageProvider("Test provider", { load = function() return "1;pW333" end, save = function() end })
M.FireEvent("PLAYER_LOGIN")
H.check("provider: source", ns.Storage.Source(), "Test provider")
H.check("provider: value", ns.Config.Get("player", "width"), 333)
H.check("provider: no waiting", ns.Storage.IsWaiting(), false)
H.check("provider: backup not removed", #M.macros, 1)

-- Migration: SavedVariables empty, backup readable at login ---------------------
ns = login(nil, withOthers(M.BackupMacros({ "1;pW260;tH", "M4" })))
H.check("migrate: source", ns.Storage.Source(), "MacroBackup")
H.check("migrate: no waiting", ns.Storage.IsWaiting(), false)
H.check("migrate: value", ns.Config.Get("player", "width"), 260)
H.check("migrate: last entry", ns.Config.Get("target", "healthColorMode"), "GRADIENT")
H.check("migrate: handed to SV at once", ForeverUnitFramesDB.profile and ForeverUnitFramesDB.profile.player.width, 260)
H.check("migrate: SV format version", ForeverUnitFramesDB.version, ns.Codec.VERSION)
H.check("migrate: backup removed", names(), "Another Macro,Zz Other")
H.check("migrate: silent", chatCount("macros removed") + chatCount("migrated"), 0)
H.check("migrate: told about the removal", chatCount("macros removed") + chatCount("migrated"), 0)
H.checkTrue("migrate: status", status():find("Settings loaded from: macro backup (migrated)", 1, true))
H.check("migrate: no macro write", M.macroWrites, 0)

-- The next session loads SavedVariables; nothing left to do.
local after = ForeverUnitFramesDB
ns = login(after, {})
H.check("after migration: SV", ns.Storage.Source(), "SavedVariables")
H.check("after migration: value", ns.Config.Get("player", "width"), 260)
H.check("after migration: quiet", chatCount("macros removed") + chatCount("migrated"), 0)

-- Migration with the backup arriving after PLAYER_LOGIN (full restart): the
-- defaults in use meanwhile are never saved over it.
ns = H.LoadAddon()
_G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
H.check("late: waiting", ns.Storage.IsWaiting(), true)
H.checkTrue("late: waiting shown in status", status():find("Settings loaded from: " .. ns.L.SOURCE_Waiting, 1, true))
ns.Config.Set("player", "width", 290)
M.RunTimers(1)
ns.Storage.Save()
H.check("late: nothing saved while waiting", ForeverUnitFramesDB.profile, nil)
M.FireEvent("UPDATE_MACROS")
H.check("late: still waiting without macros", ns.Storage.IsWaiting(), true)
M.macros = M.BackupMacros("1;pW310;tHM4")
M.RoundTripMacros("\r\n", true)
M.FireEvent("UPDATE_MACROS")
H.check("late: migrated", ns.Storage.Source(), "MacroBackup")
H.check("late: backup wins over the change made while waiting", ns.Config.Get("player", "width"), 310)
H.check("late: last entry survives the line break", ns.Config.Get("target", "healthColorMode"), "GRADIENT")
H.check("late: handed to SV", ForeverUnitFramesDB.profile.player.width, 310)
H.check("late: removed", #M.macros, 0)
H.check("late: silent", chatCount("macros removed") + chatCount("migrated"), 0)
M.RunTimers()
H.check("late: timeout changes nothing", ns.Storage.Source(), "MacroBackup")
ns.Config.Set("player", "width", 320)
M.RunTimers()
H.check("late: later changes saved", ForeverUnitFramesDB.profile.player.width, 320)
H.check("late: no macro write", M.macroWrites, 0)

-- Found by the last look at the timeout (UPDATE_MACROS missed).
ns = login(nil)
M.macros = M.BackupMacros("1;pW305")
M.RunTimers()
H.check("timeout look: migrated", ns.Storage.Source(), "MacroBackup")
H.check("timeout look: SV", ForeverUnitFramesDB.profile.player.width, 305)
H.check("timeout look: removed", #M.macros, 0)

-- No backup at all: a first install. Defaults, nothing deleted or said.
ns = login(nil)
M.RunTimers()
H.check("first install: defaults", ns.Storage.Source(), "Defaults")
H.checkTrue("first install: status", status():find("Settings loaded from: defaults", 1, true))
H.check("first install: nothing written on timeout", ForeverUnitFramesDB.profile, nil)
ns.Config.Set("player", "height", 44)
M.RunTimers()
H.check("first install: saved after a change", ForeverUnitFramesDB.profile.player.height, 44)
H.check("first install: nothing deleted", M.macroDeletes, 0)
H.check("first install: no migration message", chatCount("macros removed") + chatCount("migrated"), 0)

-- A backup that turns up after the timeout is still migrated while nothing
-- has been saved yet (UPDATE_MACROS, or the save at logout)...
ns = login(nil)
M.RunTimers()
M.macros = M.BackupMacros("1;pW310")
M.FireEvent("UPDATE_MACROS")
H.check("after timeout: migrated", ns.Storage.Source(), "MacroBackup")
H.check("after timeout: SV", ForeverUnitFramesDB.profile.player.width, 310)
H.check("after timeout: removed", #M.macros, 0)

ns = login(nil)
M.RunTimers()
M.macros = M.BackupMacros("1;pW310")
M.FireEvent("PLAYER_LOGOUT")
H.check("at logout: migrated", ns.Storage.Source(), "MacroBackup")
H.check("at logout: SV gets the backup, not defaults", ForeverUnitFramesDB.profile.player.width, 310)

-- ... but once the defaults went to SavedVariables they are the profile.
ns = login(nil)
M.RunTimers()
ns.Config.Set("player", "height", 45)
M.RunTimers()
M.macros = M.BackupMacros("1;pW310")
M.FireEvent("UPDATE_MACROS")
M.FireEvent("PLAYER_LOGOUT")
H.check("after a save: defaults stay", ns.Storage.Source(), "Defaults")
H.check("after a save: SV kept", ForeverUnitFramesDB.profile.player.height, 45)
H.check("after a save: backup left alone this session", #M.macros, 1)

-- Migrated in combat: SavedVariables at once, the macros after combat.
ns = login(nil)
M.combat = true
M.macros = M.BackupMacros("1;pW315")
M.FireEvent("UPDATE_MACROS")
H.check("combat migration: SV at once", ForeverUnitFramesDB.profile.player.width, 315)
H.check("combat migration: macros kept in combat", #M.macros, 1)
M.SetCombat(false)
H.check("combat migration: removed after combat", #M.macros, 0)

-- A garbled entry: what can be read is migrated, the rest is lost anyway.
ns = login(nil, M.BackupMacros("1;pH40;pW2x0;tHM4"))
H.check("garbled: readable entries", ns.Config.Get("player", "height"), 40)
H.check("garbled: last entry", ns.Config.Get("target", "healthColorMode"), "GRADIENT")
H.check("garbled: unreadable entry at default", ns.Config.Get("player", "width"), 220)
H.check("garbled: SV", ForeverUnitFramesDB.profile.player.height, 40)
H.check("garbled: removed", #M.macros, 0)

-- A backup in a format this version cannot read is not migrated and not
-- removed while SavedVariables are empty.
ns = login(nil, M.BackupMacros("9;pW400"))
M.RunTimers()
H.check("newer: defaults", ns.Storage.Source(), "Defaults")
H.check("newer: width at default", ns.Config.Get("player", "width"), 220)
H.check("newer: kept", #M.macros, 1)

-- A trailing space in a media name survives the migration.
ns = login(nil, M.BackupMacros("1;gFF'Spaced Font%20"))
H.check("trailing space: kept", ns.Config.Get("general", "fontFace"), "Spaced Font ")

-- Nothing happens before PLAYER_LOGIN: no profile is in use yet.
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.macros = M.BackupMacros("1;pW310")
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
H.checkTrue("before login: UPDATE_MACROS does not throw", pcall(M.FireEvent, "UPDATE_MACROS"))
H.checkTrue("before login: macro window closing does not throw",
    pcall(MacroFrame:GetScript("OnHide"), MacroFrame))
H.check("before login: nothing deleted", #M.macros, 1)
M.FireEvent("PLAYER_LOGIN")
H.check("before login, then login: migrated", ns.Config.Get("player", "width"), 310)
H.check("before login, then login: removed", #M.macros, 0)

-- The macro window loads on demand: its OnHide is hooked once it exists.
ns = H.LoadAddon()
_G.MacroFrame = nil
_G.ForeverUnitFramesDB = sv(250)
M.FireEvent("PLAYER_LOGIN")
_G.MacroFrame = M.NewMacroFrame()
M.FireEvent("ADDON_LOADED", "Blizzard_MacroUI")
M.macroFrameShown = true
M.macros = M.BackupMacros("1;pW310")
M.FireEvent("UPDATE_MACROS")
H.check("lod: kept while open", #M.macros, 1)
M.macroFrameShown = false
H.checkTrue("lod: OnHide hooked", MacroFrame:GetScript("OnHide"))
if MacroFrame:GetScript("OnHide") then MacroFrame:GetScript("OnHide")(MacroFrame) end
H.check("lod: removed when the window closes", #M.macros, 0)

-- Nothing of the write path is left.
ns = H.LoadAddon()
H.check("no Write", ns.MacroBackup.Write, nil)
H.check("no macro error", ns.Storage.MacroError, nil)
H.check("no overwrite permission", ns.Storage.AllowMacroOverwrite, nil)
for _, key in ipairs({ "MACRO_FULL", "MACRO_FOREIGN", "MACRO_COMBAT", "MACRO_FRAME_OPEN",
    "MACRO_TOO_LONG", "MACRO_NEWER", "MACRO_UNREADABLE", "RESTORED_FROM_MACRO" }) do
    H.check("no locale " .. key, rawget(ns.L, key), nil)
end
H.check("source label", ns.L.SOURCE_MacroBackup, "macro backup (migrated)")
