local M = H.M
local ns = H.LoadAddon()
_G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
_G.ForeverUnitFramesDB = nil

M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
H.check("defaults without data", ns.Storage.Source(), "defaults")
M.FireEvent("PLAYER_LOGIN")
H.checkTrue("player frame built", ns.Frames.player)
H.checkTrue("mover attached", ns.Frames.player.mover)
H.check("blizzard hidden", PlayerFrame:IsShown(), false)

-- A change is saved everywhere.
ns.Config.Set("player", "width", 290)
H.check("SV table created", ForeverUnitFramesDB.profile.player.width, 290)
H.check("macro backup written", ns.MacroBackup.Read(), "1;pW290")

-- Next session: SV missing (beta bug), macro backup restores the setting.
local macros = M.macros
ns = H.LoadAddon()
M.macros = macros
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
H.check("restored from macro", ns.Storage.Source(), "macro backup")
H.check("width restored", ns.Config.Get("player", "width"), 290)

-- Other addons' ADDON_LOADED is ignored.
ns = H.LoadAddon()
M.FireEvent("ADDON_LOADED", "SomethingElse")
H.check("not initialised by others", ns.Config.Profile(), nil)
