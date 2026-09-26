local _, ns = ...

-- Which language ns.L speaks. The general setting `language` (AUTO or a
-- language code) is known only once the settings are loaded, so Boot
-- applies it at PLAYER_LOGIN, before any frame or the options window is
-- built. Until then the game's language is used. A later change applies at
-- once: listeners of LANGUAGE_CHANGED (the options window, the movers)
-- rebuild their texts, and the CONFIG_CHANGED restyle that follows redraws
-- the unit frames ("Dead", "Offline", ...).
--
-- Registered before the unit frames' CONFIG_CHANGED listeners (TOC order),
-- so their restyle already reads the new language.
local Locale = {}
ns.Locale = Locale

-- The game's locale -> the translation used for it.
Locale.GAME = { deDE = "deDE", esES = "esES", esMX = "esES", frFR = "frFR" }
Locale.DEFAULT = "enUS"

local current

-- The language a setting value stands for: AUTO follows the game.
function Locale.Resolve(setting, gameLocale)
    if setting ~= nil and setting ~= "AUTO" and ns.Locales[setting] then return setting end
    return Locale.GAME[gameLocale] or Locale.DEFAULT
end

function Locale.Current()
    return current
end

-- Shows `code` through ns.L. Returns true if the language changed.
local function use(code)
    if code == current then return false end
    current = code
    ns.SetActiveLocale(code)
    return true
end

local function fromSettings()
    local setting = ns.Config.Profile() and ns.Config.Get("general", "language") or "AUTO"
    return Locale.Resolve(setting, GetLocale())
end

-- Boot: once the profile is in use. Nothing is built yet, so no event.
function Locale.Apply()
    use(fromSettings())
end

use(Locale.Resolve("AUTO", GetLocale()))

-- A nil key is a reset or an import: the language may have changed too.
ns.Listen("CONFIG_CHANGED", function(scope, key)
    if key ~= nil and key ~= "language" then return end
    if scope ~= nil and scope ~= "general" then return end
    if use(fromSettings()) then ns.Fire("LANGUAGE_CHANGED", current) end
end)
