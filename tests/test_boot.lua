local M = H.M
local ns = H.LoadAddon()
_G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
_G.ForeverUnitFramesDB = nil
local run = SlashCmdList.FOREVERUNITFRAMES

-- Nothing is loaded before PLAYER_LOGIN: dependent addons may still
-- register storage providers.
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
H.check("no profile before login", ns.Config.Profile(), nil)
run("status")
H.check("slash before login: not ready", M.chat[#M.chat]:find(ns.L.NOT_READY, 1, true) ~= nil, true)
run("set player width 300")
H.check("slash before login does not throw", M.chat[#M.chat]:find(ns.L.NOT_READY, 1, true) ~= nil, true)

M.FireEvent("PLAYER_LOGIN")
H.check("no data: waiting for an old backup", ns.Storage.Source(), "Waiting")
H.checkTrue("player frame built", ns.Frames.player)
H.checkTrue("mover attached", ns.Frames.player.mover)
H.check("blizzard hidden", PlayerFrame:IsShown(), false)
run("status")
H.checkTrue("status shows localised source",
    table.concat(M.chat, "\n"):find("Settings loaded from: " .. ns.L.SOURCE_Waiting, 1, true))
H.check("waiting source is localised", ns.L.SOURCE_Waiting, "defaults (looking for an old macro backup)")

-- A change is saved (once the wait has timed out).
ns.Config.Set("player", "width", 290)
M.RunTimers()
H.check("timeout without backup: defaults", ns.Storage.Source(), "Defaults")
H.check("SV table created", ForeverUnitFramesDB.profile.player.width, 290)
H.check("no macro written", M.macroWrites, 0)
run("status")
H.checkTrue("status shows defaults", table.concat(M.chat, "\n"):find("Settings loaded from: defaults", 1, true))

-- Next session: SavedVariables are loaded.
local saved = ForeverUnitFramesDB
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = saved
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
H.check("next session: SavedVariables", ns.Storage.Source(), "SavedVariables")
H.check("next session: width", ns.Config.Get("player", "width"), 290)
SlashCmdList.FOREVERUNITFRAMES("status")
H.checkTrue("status shows SavedVariables",
    table.concat(M.chat, "\n"):find("Settings loaded from: SavedVariables", 1, true))

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

-- While waiting for an old backup nothing is written anywhere: not
-- SavedVariables, not providers.
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
local providerSaves = {}
ForeverUnitFrames.RegisterStorageProvider("Rec", {
    load = function() end, save = function(s) providerSaves[#providerSaves + 1] = s end,
})
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
H.check("waiting: source", ns.Storage.Source(), "Waiting")
ns.Config.Set("player", "width", 290)
M.RunTimers(1)
ns.Storage.Flush()
M.FireEvent("PLAYER_LOGOUT")
H.check("waiting: no provider save", #providerSaves, 0)
H.check("waiting: no SavedVariables profile", ForeverUnitFramesDB.profile, nil)
H.check("waiting: change kept in memory", ns.Config.Get("player", "width"), 290)
M.RunTimers()
H.check("waiting over: provider saved", providerSaves[#providerSaves], "1;pW290")
H.check("waiting over: SavedVariables saved", ForeverUnitFramesDB.profile.player.width, 290)

local timeoutTimer
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
for _, t in ipairs(M.timers) do if t.sec == 15 then timeoutTimer = t end end
H.checkTrue("timeout is 15 s after login", timeoutTimer)
