-- The buff watch window's gear for a paladin: one entry for the blessings,
-- greyed while no blessing is known, enabled once one is.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PALADIN", className = "Paladin", isPlayer = true, auras = {} }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Win, L = ns.RaidBuffWindow, ns.L
local function blessingEntries()
    local list = {}
    for _, e in ipairs(M.menu.elements) do
        if e.text == L.RAID_SETTING_buffBlessings then list[#list + 1] = e end
    end
    return list
end
Win.OpenMenu(Win.gear)
local entries = blessingEntries()
H.check("one blessings entry", #entries, 1)
H.check("none known: greyed", entries[1].enabled, false)
M.known[19740] = true   -- Blessing of Might
M.menu = nil
Win.OpenMenu(Win.gear)
entries = blessingEntries()
H.check("one blessings entry, reopened", #entries, 1)
H.check("one known: enabled", entries[1].enabled ~= false, true)
