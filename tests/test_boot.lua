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
H.check("defaults without data", ns.Storage.Source(), "Defaults")
H.checkTrue("player frame built", ns.Frames.player)
H.checkTrue("mover attached", ns.Frames.player.mover)
H.check("blizzard hidden", PlayerFrame:IsShown(), false)
run("status")
H.checkTrue("status shows localised source",
    table.concat(M.chat, "\n"):find("Settings loaded from: " .. ns.L.SOURCE_Defaults, 1, true))

-- A change is saved everywhere.
ns.Config.Set("player", "width", 290)
M.RunTimers()
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
