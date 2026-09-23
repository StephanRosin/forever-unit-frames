local _, ns = ...

-- Missing keys fall back to the key itself, so an untranslated string is
-- visible in-game instead of raising an error.
ns.L = setmetatable({}, { __index = function(_, key) return key end })
local L = ns.L

L.ADDON_NAME = "Forever Unit Frames"
