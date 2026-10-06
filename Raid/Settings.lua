local _, ns = ...

-- Every raid-frame setting, in a registry of its own (Core/Registry.lua).
-- "general" holds what applies to the character as a whole; r10, r20 and
-- r40 are one profile per raid size. Codes are permanent, as in
-- Core/Settings.lua, but only unique within this registry.
local Raid = {}
ns.Raid = Raid

Raid.SIZES = { 10, 20, 40 }

-- The scope that holds the profile of a raid size.
function Raid.Scope(size) return "r" .. size end

local RaidSettings = ns.NewRegistry(
    { "general", "r10", "r20", "r40" },
    { general = "g", r10 = "a", r20 = "b", r40 = "c" })
ns.RaidSettings = RaidSettings

-- Character-wide ----------------------------------------------------------------
RaidSettings.Define({ key = "enabled", code = "E", scope = "general", type = "bool", default = true })
-- Which size profile shows (Raid/Size.lua): AUTO follows the raid
-- instance, elsewhere the member count; a number fixes it. Stored by
-- index: append only.
RaidSettings.Define({ key = "sizeMode", code = "SM", scope = "general", type = "enum",
    values = { "AUTO", "10", "20", "40" }, default = "AUTO" })
-- A 5-player group in the raid view (10-player profile), party frames hidden.
RaidSettings.Define({ key = "showInParty", code = "SP", scope = "general", type = "bool", default = false })
-- Blizzard's raid frames hidden while ours are on.
RaidSettings.Define({ key = "hideBlizzard", code = "HB", scope = "general", type = "bool", default = true })

-- Per size ------------------------------------------------------------------------
-- Position of the panel's top left corner, relative to the screen centre.
RaidSettings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000, default = -600 })
RaidSettings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000, default = 150 })
