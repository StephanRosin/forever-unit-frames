-- Raid icon and state settings (Raid/Settings.lua): one value per raid
-- size, permanent codes; positions are the unit frames' nine points,
-- stored by index.
local ns = H.LoadAddon()
local RS, RC = ns.RaidSettings, ns.RaidConfig

local CODES = {
    roleIcon = "RI", roleIconPoint = "RP", roleIconDamager = "RD", raidMarker = "RM", raidMarkerPoint = "RQ",
    leaderIcon = "LI", leaderIconPoint = "LP", looterIcon = "MI", looterIconPoint = "MP",
    readyCheckIcon = "YI", readyCheckIconPoint = "YP", iconSize = "IZ",
    rangeFade = "RF", rangeAlpha = "RA", aggroBorder = "AB", targetBorder = "TB",
}
for key, code in pairs(CODES) do
    local def = RS.Get(key)
    H.checkTrue(key .. " defined", def)
    if def then
        H.check(key .. " code", def.code, code)
        H.check(key .. " per size", RS.AppliesTo(def, "r10"), true)
        H.check(key .. " not character-wide", RS.AppliesTo(def, "general"), false)
    end
end
H.check("points: the unit frames' list", RS.Get("roleIconPoint").values, ns.Settings.POINTS)

RC.Use({})
local DEFAULTS = {
    roleIcon = true, roleIconPoint = "LEFT", roleIconDamager = false, raidMarker = true, raidMarkerPoint = "RIGHT",
    leaderIcon = true, leaderIconPoint = "TOPLEFT", looterIcon = true, looterIconPoint = "TOPRIGHT",
    readyCheckIcon = true, readyCheckIconPoint = "CENTER", rangeFade = true, rangeAlpha = 40,
    aggroBorder = true, targetBorder = true,
}
for key, want in pairs(DEFAULTS) do
    H.check(key .. " default", RC.Get("r20", key), want)
end
H.check("icons 10", RC.Get("r10", "iconSize"), 14)
H.check("icons 20", RC.Get("r20", "iconSize"), 13)
H.check("icons 40", RC.Get("r40", "iconSize"), 12)

local seen = {}
for _, def in ipairs(RS.All()) do
    H.check("unique code " .. def.code, seen[def.code], nil)
    seen[def.code] = true
end
RC.Set("r40", "roleIconPoint", "BOTTOMRIGHT")
RC.Set("r40", "rangeAlpha", 25)
H.check("export", ns.RaidProfiles.Export(40), "1;cRA25;cRP9")
