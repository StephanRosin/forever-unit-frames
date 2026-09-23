local M = H.M
local ns = H.LoadAddon()
_G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
_G.ForeverUnitFramesDB = nil
local run = SlashCmdList.FOREVERUNITFRAMES

-- Nothing is loaded before PLAYER_LOGIN: dependent addons may still
-- register storage providers and macros may not be readable yet.
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
H.check("no profile before login", ns.Config.Profile(), nil)
run("status")
H.check("slash before login: not ready", M.chat[#M.chat]:find(ns.L.NOT_READY, 1, true) ~= nil, true)
run("set player width 300")
H.check("slash before login does not throw", M.chat[#M.chat]:find(ns.L.NOT_READY, 1, true) ~= nil, true)

M.FireEvent("PLAYER_LOGIN")
H.check("no data: waiting for macros", ns.Storage.Source(), "Waiting")
H.checkTrue("player frame built", ns.Frames.player)
H.checkTrue("mover attached", ns.Frames.player.mover)
H.check("blizzard hidden", PlayerFrame:IsShown(), false)
run("status")
H.checkTrue("status shows localised source",
    table.concat(M.chat, "\n"):find("Settings loaded from: " .. ns.L.SOURCE_Waiting, 1, true))
H.check("waiting source is localised", ns.L.SOURCE_Waiting, "waiting for macros")

-- A change is saved everywhere (once the wait for macros has timed out).
ns.Config.Set("player", "width", 290)
M.RunTimers()
H.check("timeout without backup: defaults", ns.Storage.Source(), "Defaults")
H.check("SV table created", ForeverUnitFramesDB.profile.player.width, 290)
H.check("macro backup written", ns.MacroBackup.Read(), "1;pW290")

-- Next session: SV missing (beta bug), macro backup restores the setting.
local macros = M.macros
ns = H.LoadAddon()
M.macros = macros
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
H.check("restored from macro", ns.Storage.Source(), "MacroBackup")
H.check("width restored", ns.Config.Get("player", "width"), 290)

-- A provider registered after our ADDON_LOADED but before PLAYER_LOGIN
-- (a dependent addon) is still used.
ns = H.LoadAddon()
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
ForeverUnitFrames.RegisterStorageProvider("Late", { load = function() return "1;pW333" end, save = function() end })
M.FireEvent("ADDON_LOADED", "SomeDependentAddon")
M.FireEvent("PLAYER_LOGIN")
H.check("late provider is the source", ns.Storage.Source(), "Late")
H.check("late provider value", ns.Config.Get("player", "width"), 333)
SlashCmdList.FOREVERUNITFRAMES("status")
H.checkTrue("provider name shown as given", table.concat(M.chat, "\n"):find("Settings loaded from: Late", 1, true))

-- Login in combat: frames and movers arrive together after combat.
ns = H.LoadAddon()
_G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
M.combat = true
M.FireEvent("PLAYER_LOGIN")
H.check("combat login: no frames yet", ns.Frames.player, nil)
M.SetCombat(false)
H.checkTrue("combat login: player built after combat", ns.Frames.player)
H.checkTrue("combat login: player mover", ns.Frames.player and ns.Frames.player.mover)
H.checkTrue("combat login: target mover", ns.Frames.target and ns.Frames.target.mover)
if ns.Frames.player then
    local _, rel = ns.Frames.player:GetPoint(1)
    H.check("combat login: frame anchored to mover", rel, ns.Frames.player.mover)
end

-- Invalid SavedVariables are cleaned on login; saving still works.
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = { profile = { player = { width = "wide" } } }
H.checkTrue("login with invalid SV", pcall(M.FireEvent, "PLAYER_LOGIN"))
H.check("invalid SV width falls back", ns.Config.Get("player", "width"), 220)
H.checkTrue("set after invalid SV", ns.Config.Set("player", "height", 50))
M.RunTimers()
H.check("saved after invalid SV", ForeverUnitFramesDB.profile.player.height, 50)

-- Character macros arrive after PLAYER_LOGIN (UPDATE_MACROS). While waiting
-- for them nothing is written anywhere: not SavedVariables, not providers,
-- not the macro backup.
local function countWrites()
    local writes = { macro = 0 }
    local create, edit = CreateMacro, EditMacro
    _G.CreateMacro = function(...) writes.macro = writes.macro + 1; return create(...) end
    _G.EditMacro = function(...) writes.macro = writes.macro + 1; return edit(...) end
    return writes
end
local function chatHas(text)
    return table.concat(M.chat, "\n"):find(text, 1, true) ~= nil
end

-- A backup made in an earlier session (setup only, before counting writes).
ns = H.LoadAddon()
H.checkTrue("setup: backup written", ns.MacroBackup.Write("1;pW310"))
local lateMacros = M.macros

ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
local providerSaves = {}
ForeverUnitFrames.RegisterStorageProvider("Rec", {
    load = function() end, save = function(s) providerSaves[#providerSaves + 1] = s end,
})
local writes = countWrites()
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
H.check("late macros: waiting", ns.Storage.Source(), "Waiting")
H.check("late macros: defaults shown meanwhile", ns.Config.Get("player", "width"), 220)
H.checkTrue("late macros: frames built meanwhile", ns.Frames.player)
ns.Config.Set("player", "width", 290)
M.RunTimers(1)
ns.Storage.RequestSave(); M.RunTimers(1)
ns.Storage.Save()
ns.Storage.Flush()
MacroFrame:GetScript("OnHide")(MacroFrame)
M.combat = true; ns.Storage.Save(); M.SetCombat(false)
M.FireEvent("PLAYER_LOGOUT")
H.check("waiting: no macro write", writes.macro, 0)
H.check("waiting: no provider save", #providerSaves, 0)
H.check("waiting: no SavedVariables profile", ForeverUnitFramesDB.profile, nil)
H.check("waiting: change kept in memory", ns.Config.Get("player", "width"), 290)
M.FireEvent("UPDATE_MACROS")
H.check("no backup yet: still waiting", ns.Storage.Source(), "Waiting")
H.check("no backup yet: still no macro write", writes.macro, 0)
M.macros = lateMacros
M.FireEvent("UPDATE_MACROS")
H.check("late macros: restored", ns.Storage.Source(), "MacroBackup")
H.check("late macros: backup wins over change made while waiting", ns.Config.Get("player", "width"), 310)
H.checkTrue("late macros: restore announced", chatHas(ns.L.RESTORED_FROM_MACRO))
H.check("restore message text", ns.L.RESTORED_FROM_MACRO, "Settings restored from the macro backup.")
H.check("late macros: no write before the restore", writes.macro, 0)
H.check("late macros: no provider save before the restore", #providerSaves, 0)
M.RunTimers()
H.check("after restore: timeout changes nothing", ns.Storage.Source(), "MacroBackup")
H.check("after restore: SavedVariables get the restored profile", ForeverUnitFramesDB.profile.player.width, 310)
H.check("after restore: backup still intact", ns.MacroBackup.Read(), "1;pW310")
H.check("after restore: unchanged backup not rewritten", writes.macro, 0)
ns.Config.Set("player", "width", 320)
M.RunTimers()
H.check("after restore: saving works", ns.MacroBackup.Read(), "1;pW320")
H.check("after restore: provider saved", providerSaves[#providerSaves], "1;pW320")

-- Timeout: a change made while waiting is saved once the wait ends.
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
writes = countWrites()
M.FireEvent("PLAYER_LOGIN")
ns.Config.Set("player", "width", 295)
M.RunTimers(1)
H.check("timeout pending: nothing written", writes.macro, 0)
H.check("timeout pending: no SV profile", ForeverUnitFramesDB.profile, nil)
M.RunTimers()
H.check("timeout: defaults", ns.Storage.Source(), "Defaults")
H.check("timeout: change saved to SV", ForeverUnitFramesDB.profile.player.width, 295)
H.check("timeout: change saved to macro", ns.MacroBackup.Read(), "1;pW295")
local timeoutTimer
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
for _, t in ipairs(M.timers) do if t.sec == 15 then timeoutTimer = t end end
H.checkTrue("timeout is 15 s after login", timeoutTimer)

-- Timeout with no change: a genuine first install writes nothing until a
-- setting changes, then saves normally.
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
writes = countWrites()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.check("first install: defaults", ns.Storage.Source(), "Defaults")
H.check("first install: nothing written on timeout", writes.macro, 0)
H.check("first install: no chat restore message", chatHas(ns.L.RESTORED_FROM_MACRO), false)
ns.Config.Set("player", "height", 44)
M.RunTimers()
H.check("first install: saved after change", ForeverUnitFramesDB.profile.player.height, 44)
H.check("first install: macro after change", ns.MacroBackup.Read(), "1;pH44")
H.checkTrue("first install: the macro was actually written", writes.macro > 0)
M.FireEvent("UPDATE_MACROS")
H.check("first install: later UPDATE_MACROS ignored", ns.Storage.Source(), "Defaults")

-- A fresh copy of a backup holding width 310 (writes must not leak between cases).
local backup310
do
    ns = H.LoadAddon()
    ns.MacroBackup.Write("1;pW310")
    local saved = M.macros
    backup310 = function()
        local t = {}
        for i, m in ipairs(saved) do
            t[i] = { name = m.name, icon = m.icon, body = m.body, perChar = m.perChar }
        end
        return t
    end
end

-- Macros that arrive only after the timeout: a backup this session has not
-- loaded is never overwritten, not even by the save at logout.
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
writes = countWrites()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.check("very late macros: timed out", ns.Storage.Source(), "Defaults")
M.macros = backup310()
M.FireEvent("PLAYER_LOGOUT")
H.check("very late macros, logout: backup intact", ns.MacroBackup.Read(), "1;pW310")
H.check("very late macros, logout: no macro write", writes.macro, 0)
H.check("very late macros, logout: restored instead", ns.Storage.Source(), "MacroBackup")
H.check("very late macros, logout: restored value", ns.Config.Get("player", "width"), 310)
H.check("very late macros, logout: SV gets the backup, not defaults",
    ForeverUnitFramesDB.profile and ForeverUnitFramesDB.profile.player.width, 310)

-- The same with a change made after the timeout: the backup still wins.
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
writes = countWrites()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.macros = backup310()
ns.Config.Set("player", "height", 45)
M.RunTimers()
H.check("very late macros, change: backup intact", ns.MacroBackup.Read(), "1;pW310")
H.check("very late macros, change: no macro write", writes.macro, 0)
H.check("very late macros, change: restored", ns.Storage.Source(), "MacroBackup")

-- Macros after the timeout, announced by UPDATE_MACROS: restored.
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
writes = countWrites()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.macros = backup310()
M.chat = {}
M.FireEvent("UPDATE_MACROS")
H.check("UPDATE_MACROS after timeout: restored", ns.Storage.Source(), "MacroBackup")
H.check("UPDATE_MACROS after timeout: value", ns.Config.Get("player", "width"), 310)
H.checkTrue("UPDATE_MACROS after timeout: announced", chatHas(ns.L.RESTORED_FROM_MACRO))
M.RunTimers()
H.check("UPDATE_MACROS after timeout: backup intact", ns.MacroBackup.Read(), "1;pW310")
H.check("UPDATE_MACROS after timeout: no macro write", writes.macro, 0)

-- Macros arriving while a save waits for combat to end: still not overwritten.
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
writes = countWrites()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.combat = true
ns.Storage.Save()
M.macros = backup310()
M.SetCombat(false)
H.check("macros during combat-held save: backup intact", ns.MacroBackup.Read(), "1;pW310")
H.check("macros during combat-held save: no macro write", writes.macro, 0)
H.check("macros during combat-held save: restored", ns.Storage.Source(), "MacroBackup")

-- Macros readable at PLAYER_LOGIN: restored at once, no waiting.
ns = H.LoadAddon()
M.macros = lateMacros
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
H.check("macros at login: restored at once", ns.Storage.Source(), "MacroBackup")
ns.Config.Set("player", "width", 330)
M.RunTimers(1)
H.check("macros at login: saving not held back", ns.MacroBackup.Read(), "1;pW330")

-- SavedVariables present: no waiting either.
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = { profile = { player = { width = 250 } } }
M.FireEvent("PLAYER_LOGIN")
H.check("SV at login: no waiting", ns.Storage.Source(), "SavedVariables")
ns.Config.Set("player", "width", 251)
M.RunTimers(1)
H.check("SV at login: saving not held back", ForeverUnitFramesDB.profile.player.width, 251)

-- UPDATE_MACROS before PLAYER_LOGIN: no profile is in use yet, so nothing
-- is restored or written; login then loads the backup normally.
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
writes = countWrites()
M.macros = backup310()
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
H.checkTrue("UPDATE_MACROS before login: no error", pcall(M.FireEvent, "UPDATE_MACROS"))
H.check("UPDATE_MACROS before login: no profile yet", ns.Config.Profile(), nil)
H.checkTrue("MacroFrame hide before login: no error",
    pcall(MacroFrame:GetScript("OnHide"), MacroFrame))
H.check("before login: nothing written", writes.macro, 0)
M.FireEvent("PLAYER_LOGIN")
H.check("before login, then login: from backup", ns.Storage.Source(), "MacroBackup")
H.check("before login, then login: value", ns.Config.Get("player", "width"), 310)
ns.Config.Set("player", "width", 311)
M.RunTimers()
H.check("before login, then login: saving works", ns.MacroBackup.Read(), "1;pW311")

-- A backup written by a newer version is never overwritten.
ns = H.LoadAddon()
H.checkTrue("setup: newer backup", ns.MacroBackup.Write("9;pW400"))
local newerMacros = M.macros
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.macros = newerMacros
writes = countWrites()
M.chat = {}
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.check("newer backup: defaults kept", ns.Config.Get("player", "width"), 220)
H.check("newer backup: source defaults", ns.Storage.Source(), "Defaults")
ns.Config.Set("player", "width", 290)
M.RunTimers()
M.FireEvent("PLAYER_LOGOUT")
H.check("newer backup: macros untouched", ns.MacroBackup.Read(), "9;pW400")
H.check("newer backup: no macro write", writes.macro, 0)
H.check("newer backup: SV still saved", ForeverUnitFramesDB.profile.player.width, 290)
H.check("newer backup: reported", ns.Storage.MacroError(), "MACRO_NEWER")
H.checkTrue("newer backup: message shown", chatHas(ns.L.MACRO_NEWER))
H.check("newer backup: message text", ns.L.MACRO_NEWER,
    "Macro backup kept: it was written by a newer version of Forever Unit Frames.")
H.check("newer backup: Write refuses", ns.MacroBackup.Write("1;pW1"), false)
H.check("newer backup: Write error", ns.MacroBackup.LastError(), "MACRO_NEWER")
