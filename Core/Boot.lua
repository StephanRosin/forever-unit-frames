local _, ns = ...

-- Startup happens at PLAYER_LOGIN: SavedVariables are available, dependent
-- addons have had their ADDON_LOADED to register storage providers.
-- With empty SavedVariables an old macro backup may still arrive (see
-- Storage.Start). Every settings change is persisted.

-- Runs in the same out-of-combat run that built the single frames.
local function afterBuild()
    ns.Party.Create()
    for _, frame in pairs(ns.Frames) do ns.Movers.Attach(frame) end
    ns.Movers.Attach(ns.Party.header, ns.Party.MoverSpec())
    for _, frame in pairs(ns.Frames) do ns.Castbar.AttachMover(frame) end
end

ns.On("PLAYER_LOGIN", function()
    if ns.booted then return end
    ns.booted = true
    ForeverUnitFramesDB = ForeverUnitFramesDB or {}
    ns.Config.Use(ns.Storage.Load(ForeverUnitFramesDB))
    ns.Storage.Attach(ForeverUnitFramesDB)
    -- Before anything writes a text: frames, movers, the options window.
    ns.Locale.Apply()
    -- Migrates or waits for an old macro backup, or deletes it.
    ns.Storage.Start()
    -- Party and movers follow in the same (possibly deferred) run that
    -- builds the single frames.
    ns.Single.CreateAll(afterBuild)
    ns.Blizzard.HideDefaults()
    ns.MinimapButton.Create()
end)

ns.Listen("CONFIG_CHANGED", function()
    ns.Storage.RequestSave()
end)

ns.On("PLAYER_LOGOUT", function()
    ns.Storage.Flush()
end)
