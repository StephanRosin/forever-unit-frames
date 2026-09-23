local M = H.M
local ns = H.LoadAddon()
local S, Lay = ns.Settings, ns.Layout

-- Settings: new codes; the health colour enum keeps its order.
H.check("title height code", S.Get("titlePercent").code, "TP")
H.check("title text code", S.Get("titleText").code, "NT")
H.check("title colour code", S.Get("titleColorMode").code, "NC")
H.check("colour modes", table.concat(S.Get("titleColorMode").values, ","), "CLASS,REACTION,WHITE")
H.check("health colour modes unchanged", table.concat(S.Get("healthColorMode").values, ","),
    "CLASS,REACTION,STATIC,GRADIENT")
H.check("health colour now static", S.Default(S.Get("healthColorMode"), "general"), "STATIC")
H.check("static colour is green", S.Default(S.Get("healthColor"), "general")[2], 0.75)
for scope, want in pairs({ player = 30, target = 30, focus = 30, party = 0, targettarget = 0, pet = 0 }) do
    H.check(scope .. " title default", S.Default(S.Get("titlePercent"), scope), want)
end
H.check("player health default", S.Default(S.Get("healthPercent"), "player"), 45)
H.check("party health default", S.Default(S.Get("healthPercent"), "party"), 75)
H.check("player title text", S.Default(S.Get("titleText"), "player"), "NAME_LEVEL")
H.check("player health left", S.Default(S.Get("textHealthLeft"), "player"), "CURRENT_MAX")
H.check("party health left keeps the name", S.Default(S.Get("textHealthLeft"), "party"), "NAME")

-- Layout maths: title, health, gap, power.
local function rows(...) return table.concat({ Lay.Rows(...) }, ",") end
H.check("three rows", rows(46, 30, 45, 25, true), "14,21,0,11")
H.check("gap is the rest", rows(50, 20, 40, 20, true), "10,20,10,10")
H.check("no title: two rows", rows(40, 0, 75, 25, true), "0,30,0,10")
H.check("power off: health takes the rest", rows(46, 30, 45, 25, false), "14,32,0,0")
H.check("too much: title gives way", rows(20, 60, 50, 50, true), "9,1,0,10")
H.check("two-row helper unchanged", table.concat({ Lay.Bars(46, 75, 25, true) }, ","), "35,0,11")

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, L = ns.Config, ns.L
local f = ns.Frames.player
local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

-- The player frame: title row on top, health below it, power at the bottom.
H.checkTrue("title row shown", f.title:IsShown())
H.check("title height", f.title:GetHeight(), 14)
H.check("title at the top", point(f.title, "TOPLEFT")[5], 0)
H.check("health below the title", point(f.health, "TOPLEFT")[5], -14)
H.check("health height", f.health:GetHeight(), 21)
H.check("power height", f.power:GetHeight(), 11)
H.check("title background colour", f.title._color[4], C.Get("player", "backgroundColor")[4])

-- Title text: name and level, class coloured for players.
M.units.player = { name = "Me", level = 60, class = "WARLOCK", className = "Warlock", isPlayer = true,
    health = 5, healthMax = 10 }
M.FireEvent("PLAYER_ENTERING_WORLD")
local tt = f.texts.title
H.check("title text on the title row", point(tt, "LEFT")[2], f.title)
H.check("ends at the class icon", point(tt, "RIGHT")[2], f.classIcon)
H.checkTrue("title text shown", tt:IsShown())
H.check("name and level", tt._args[2], "Me")
H.check("class colour", tt._color[1], RAID_CLASS_COLORS.WARLOCK.r)
H.check("health shows values", f.texts.healthLeft._fmt, "%s / %s")
H.check("static green health", f.health._color[2], 0.75)

-- NPCs: reaction colour; REACTION and WHITE modes.
M.units.target = { name = "Wolf", level = 10, health = 1, healthMax = 1, reaction = 2 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("npc: reaction red", ns.Frames.target.texts.title._color[1], 0.85)
C.Set("player", "titleColorMode", "REACTION")
M.units.player.reaction = 5
M.FireEvent("PLAYER_ENTERING_WORLD")
H.check("reaction mode for a player", tt._color[2], 0.75)
C.Set("player", "titleColorMode", "WHITE")
H.check("white", tt._color[1] + tt._color[2] + tt._color[3], 3)

-- A portrait takes the title row's left end too.
C.Set("player", "portraitMode", "LEFT")
H.check("title after the portrait", point(f.title, "TOPLEFT")[4], 46)

-- No title row: the old two rows.
C.Set("player", "titlePercent", 0)
H.check("title hidden", f.title:IsShown(), false)
H.check("title text hidden", tt:IsShown(), false)
H.check("health at the top", point(f.health, "TOPLEFT")[5], 0)
local header = ns.Party.header
M.units.party1 = { name = "Ann", health = 1, healthMax = 2 }
M.SetGroup({ "party1" })
local member = header:GetAttribute("child1")
H.check("party: no title row", member.title:IsShown(), false)
H.check("party: name on the health bar", member.texts.healthLeft:GetText(), "Ann")

-- Options: the row heights in Layout, the title text in Text.
local O = ns.Options
O.Open("player")
O.SelectTab("layout")
local keys = {}
for _, row in ipairs(O.rows) do if row.key then keys[row.key] = true end end
H.checkTrue("layout: title height", keys.titlePercent)
O.SelectTab("text")
keys = {}
for _, row in ipairs(O.rows) do if row.key then keys[row.key] = true end end
H.checkTrue("text: title text", keys.titleText)
H.checkTrue("text: title colour", keys.titleColorMode)
H.check("class mode label", ns.Schema.EnumText(S.Get("titleColorMode"), "CLASS"), L.ENUM_titleColorMode_CLASS)
M.RunTimers()
