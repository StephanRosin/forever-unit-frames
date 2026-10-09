-- The names under a buff (Raid/BuffWatchNames.lua): missing first, then
-- running out (dimmed, minutes left), each alphabetical; out of range
-- grey; unknown and preview states name nobody; packed into two lines
-- with "+N".
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "Priest", isPlayer = true, auras = {} }
M.known[1243] = true
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Names, L = ns.RaidBuffNames, ns.L

M.units.party1 = { name = "Zed", class = "WARRIOR", isPlayer = true, auras = {}, distance = 10 }
M.units.party2 = { name = "Ann", class = "DRUID", isPlayer = true, auras = {}, distance = 10 }
M.units.party3 = { name = "Bob", class = "WARLOCK", isPlayer = true, auras = {}, distance = 80 }
M.units.party4 = { name = "Cy", class = "WARRIOR", isPlayer = true, auras = {}, distance = 10 }
local entry = { single = { id = 1243 } }
local st = { entry = entry, needs = {
    { unit = "party4", member = { class = "WARRIOR" }, left = 90 },
    { unit = "party1", member = { class = "WARRIOR" }, left = -1 },
    { unit = "party3", member = { class = "WARLOCK" }, left = -1 },
    { unit = "party2", member = { class = "DRUID" }, left = -1 },
} }
local list = Names.Of(st)
local order = {}
for i, item in ipairs(list) do order[i] = item.name end
H.check("missing first, alphabetical; running out last", table.concat(order, ","), "Ann,Bob,Zed,Cy")
H.check("missing", list[1].missing, true)
H.check("running out", list[4].missing, false)
H.check("out of range", list[2].reach, false)
H.check("in range", list[1].reach, true)
H.check("unknown names nobody", #Names.Of({ entry = entry, unknown = true, needs = st.needs }), 0)
H.check("preview names nobody", #Names.Of({ entry = entry, preview = true }), 0)
H.check("nil names nobody", #Names.Of(nil), 0)

-- Words: plain for measuring; colours: class, grey out of range, dimmed with minutes when running out.
H.check("plain: running out has minutes", Names.Plain(list[4]), "Cy " .. L.RAID_BUFF_MINUTES:format(2))
H.check("plain: missing has none", Names.Plain(list[1]), "Ann")
H.checkTrue("grey out of range", Names.Text(list[2]):find("|cff808080Bob|r", 1, true))
local c = RAID_CLASS_COLORS.DRUID
H.checkTrue("class colour", Names.Text(list[1]):find(("|cff%02x%02x%02xAnn|r"):format(c.r * 255, c.g * 255,
    c.b * 255), 1, true))
local w = RAID_CLASS_COLORS.WARRIOR
H.checkTrue("dimmed when running out", Names.Text(list[4]):find(("|cff%02x%02x%02x"):format(w.r * 255 * 0.6,
    w.g * 255 * 0.6, w.b * 255 * 0.6), 1, true))

-- Packing: one character = 1 px here.
local function measure(text) return #text end
local many = {}
for i = 1, 12 do many[i] = { name = ("N%02d"):format(i), missing = true, left = -1, reach = true } end
local lines = Names.Pack(many, 20, measure)
H.check("at most two lines", #lines, 2)
H.checkTrue("first line fits", measure((lines[1]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))) <= 20)
local shown = select(2, (lines[1] .. lines[2]):gsub("N%d%d", ""))
H.check("seven names shown", shown, 7)
H.checkTrue("the rest as +N (shown + N == 12)", lines[2]:find(L.RAID_BUFF_MORE:format(12 - shown), 1, true))
H.check("one short line", #Names.Pack({ many[1] }, 20, measure), 1)
H.check("nothing, no line", #Names.Pack({}, 20, measure), 0)
