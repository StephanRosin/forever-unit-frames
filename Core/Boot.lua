local _, ns = ...

-- Startup happens at PLAYER_LOGIN: SavedVariables are available, dependent
-- addons have had their ADDON_LOADED to register storage providers, and
-- character macros can be read. Every settings change is persisted.

local function attachMovers()
    for _, frame in pairs(ns.Frames) do ns.Movers.Attach(frame) end
end

ns.On("PLAYER_LOGIN", function()
    if ns.booted then return end
    ns.booted = true
    ForeverUnitFramesDB = ForeverUnitFramesDB or {}
    ns.Config.Use(ns.Storage.Load(ForeverUnitFramesDB))
    ns.Storage.Attach(ForeverUnitFramesDB)
    -- Movers go on in the same (possibly deferred) run that builds frames.
    ns.Single.CreateAll(attachMovers)
    ns.Blizzard.HideDefaults()
end)

ns.Listen("CONFIG_CHANGED", function()
    ns.Storage.Save()
end)
