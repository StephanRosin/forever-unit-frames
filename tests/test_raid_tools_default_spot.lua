-- The tools bar's default spot (free): at its largest (every tool, in
-- every language) it covers no panel's default spot (the main panel, the
-- special panels, panels 2 to 10: each one's first cell at the largest
-- default cell size) and stays on the smallest screen (1365 x 768 around
-- the centre).
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1, isPlayer = true }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, RS, Raid, Tools = ns.RaidConfig, ns.RaidSettings, ns.Raid, ns.RaidTools

RC.Set("general", "toolsMode", "FREE")
ns.RaidTestMode.Set(true)
M.RunTimers()
local width, height = 0, 0
for _, language in ipairs({ "enUS", "deDE", "frFR", "esES" }) do
    ns.Config.Set("general", "language", language)
    M.RunTimers()
    Tools.Refresh()
    local w, h = Tools.Size()
    width, height = math.max(width, w), math.max(height, h)
end
H.checkTrue("every tool shown: more than one row", height > Tools.ICON + 2 * Tools.PADDING)

local function largest(key)
    local most = 0
    for _, v in pairs(RS.Get(key).default) do most = math.max(most, v) end
    return most
end
local CELL_W, CELL_H = largest("cellWidth"), largest("cellHeight")

-- Rectangles from the screen centre, top-left corner (x, y), y up.
local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y - a.h < b.y and b.y - b.h < a.y
end
local bar = { x = RS.Get("toolsX").default, y = RS.Get("toolsY").default, w = width, h = height }
local spots = { { "main panel", RS.Get("x").default, RS.Get("y").default } }
for _, p in ipairs(Raid.PANELS) do spots[#spots + 1] = { p.id, p.x, p.y } end
for _, slot in ipairs(Raid.OWN_PANELS) do
    spots[#spots + 1] = { slot.id, RS.Get(slot.id .. "X").default, RS.Get(slot.id .. "Y").default }
end
H.check("every panel's spot", #spots, 1 + #Raid.PANELS + 9)
for _, spot in ipairs(spots) do
    H.check("clear of " .. spot[1], overlap(bar, { x = spot[2], y = spot[3], w = CELL_W, h = CELL_H }), false)
end
H.checkTrue("on screen: left", bar.x >= -1365 / 2)
H.checkTrue("on screen: right", bar.x + bar.w <= 1365 / 2)
H.checkTrue("on screen: top", bar.y <= 768 / 2)
H.checkTrue("on screen: bottom", bar.y - bar.h >= -768 / 2)
