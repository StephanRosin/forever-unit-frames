-- The shipped looks per theme (ns.THEME_PRESETS, Core/Preset.lua): a theme
-- set made from now on carries them; a stored one stays as it was.
local ns = H.LoadShipped()
local presets = ns.THEME_PRESETS
H.check("classic: no shipped theme look", presets.CLASSIC, nil)

-- Nothing that places a frame or is personal.
local banned = { width = true, height = true, theme = true }
for _, key in ipairs(ns.Themes.PlacementKeys()) do banned[key] = true end
for _, def in ipairs(ns.Settings.All()) do
    if def.personal or def.type == "text" then banned[def.key] = true end
end
for id, scopes in pairs(presets) do
    H.checkTrue("known theme " .. id, ns.Themes.SPECS[id])
    for scope, values in pairs(scopes) do
        for key in pairs(values) do H.check(id .. "." .. scope .. "." .. key .. " allowed", banned[key], nil) end
    end
end

local stored = { general = { theme = "TECH", backgroundColor = { 0.5, 0.5, 0.5, 0.5 } } }
local db = { profiles = { Default = {
    general = { fontSize = 12 },
    player = { width = 300, x = -200 },
} }, themeSets = { Default = { revision = ns.Themes.REVISION, TECH = stored } } }
ns.Config.Use(ns.Storage.Load(db))
ns.Storage.Attach(db)
local Themes, Config = ns.Themes, ns.Config

H.checkTrue("wood the first time", Themes.Switch("WOOD"))
H.checkTrue("wood: shipped background", ns.SameValue(Config.Get("general", "backgroundColor"), presets.WOOD.general.backgroundColor))
H.check("wood: keeps the own position", Config.Get("player", "x"), -200)
H.checkTrue("frost the first time", Themes.Switch("FROST"))
H.checkTrue("frost: shipped background", ns.SameValue(Config.Get("general", "backgroundColor"), presets.FROST.general.backgroundColor))
H.checkTrue("pitwall the first time", Themes.Switch("PITWALL"))
H.check("pitwall: target portrait aura", Config.Get("target", "portraitAura"), true)

H.checkTrue("tech: stored before", Themes.Switch("TECH"))
H.checkTrue("tech: its stored background, not the shipped one",
    ns.SameValue(Config.Get("general", "backgroundColor"), { 0.5, 0.5, 0.5, 0.5 }))
H.check("tech: revision untouched", db.themeSets.Default.revision, ns.Themes.REVISION)
