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
    -- Whether the SavedVariables held settings before this login (an
    -- update), before anything writes to them.
    ns.News.Begin(ForeverUnitFramesDB)
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
    -- The raid frames last: their profile, the active size, then the
    -- panel built from both (out of combat, like the unit frames). The
    -- party block asks the raid profile whether the raid view takes a
    -- 5-player group: no until it is attached; with the raid view in
    -- party on, building the panel styles the party block again.
    ns.RaidProfiles.Attach(ForeverUnitFramesDB)
    ns.RaidMinimapButton.Create()
    ns.RaidSize.Update()
    ns.AfterCombat("raidCreate", ns.RaidHeader.Create)
    ns.AfterCombat("raidToolsCreate", ns.RaidTools.Create)
    ns.AfterCombat("raidBuffWindowCreate", ns.RaidBuffWindow.Create)
    -- Click-casting on the cells just made and the party members.
    ns.AfterCombat("clickCast", ns.ClickCast.ApplyAll)
    ns.AfterCombat("clickKeys", ns.ClickKeys.Update)
    -- The smart buff key's button (Raid/SmartBuff.lua).
    ns.AfterCombat("smartBuff", ns.SmartBuff.Update)
    ns.Blizzard.HideRaid()
    -- What's new follows once the loading screen is gone (Core/News.lua).
end)

ns.Listen("CONFIG_CHANGED", function()
    ns.Storage.RequestSave()
end)

ns.On("PLAYER_LOGOUT", function()
    ns.Storage.Flush()
end)
