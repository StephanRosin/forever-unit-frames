local ADDON, ns = ...

-- Startup order: settings first (ADDON_LOADED), frames once the player
-- exists (PLAYER_LOGIN). Every settings change is persisted.

ns.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON or ns.booted then return end
    ns.booted = true
    ForeverUnitFramesDB = ForeverUnitFramesDB or {}
    local profile = ns.Storage.Load(ForeverUnitFramesDB)
    ns.Config.Use(profile)
    ns.Storage.Attach(ForeverUnitFramesDB)
end)

ns.On("PLAYER_LOGIN", function()
    ns.Single.CreateAll()
    ns.AfterCombat("attachMovers", function()
        for _, frame in pairs(ns.Frames) do ns.Movers.Attach(frame) end
    end)
    ns.Blizzard.HideDefaults()
end)

ns.Listen("CONFIG_CHANGED", function()
    ns.Storage.Save()
end)
