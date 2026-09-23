local M = H.M
local ns = H.LoadAddon()
local S, Codec = ns.Settings, ns.Codec

-- Setting: inherited, on by default, own permanent code.
local def = S.Get("titleClassIcon")
H.checkTrue("setting exists", def)
H.check("code", def and def.code, "CL")
H.check("inherited", def and def.scope, "inherit")
H.check("bool", def and def.type, "bool")
H.check("on by default", def and S.Default(def, "general"), true)
H.check("label", ns.L.SETTING_titleClassIcon, "Show class icon")

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, O = ns.Config, ns.Options
local f = ns.Frames.player
local icon, tt = f.classIcon, f.texts.title

local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

M.units.player = { name = "Me", level = 60, class = "WARLOCK", className = "Warlock", isPlayer = true,
    health = 5, healthMax = 10 }
M.FireEvent("PLAYER_ENTERING_WORLD")

-- A player with a readable class: the atlas, right-aligned, as tall as the row.
H.checkTrue("icon exists", icon)
H.checkTrue("shown for a player", icon:IsShown())
H.check("class atlas", icon._atlas, "classicon-warlock")
H.check("square: width", icon:GetWidth(), f.titleHeight)
H.check("square: height", icon:GetHeight(), f.titleHeight)
H.check("size is the title height", icon:GetHeight(), 14)
H.check("anchored to the row", point(icon, "RIGHT")[2], f.title)
H.check("at the row's right edge", point(icon, "RIGHT")[3], "RIGHT")
H.check("title text ends at the icon", point(tt, "RIGHT")[2], icon)
H.check("icon side", point(tt, "RIGHT")[3], "LEFT")
H.check("2 px before the icon", point(tt, "RIGHT")[4], -2)

-- Without the atlas: the character-create class texture with its coords.
M.atlases["classicon-warlock"] = nil
M.FireEvent("UNIT_NAME_UPDATE", "player")
H.checkTrue("fallback shown", icon:IsShown())
H.check("fallback file", icon._texture, "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
H.check("fallback coords", table.concat(icon._texCoord, ","), table.concat(CLASS_ICON_TCOORDS.WARLOCK, ","))
M.atlases["classicon-warlock"] = true
M.units.player.class, M.units.player.className = "WARRIOR", "Warrior"
M.FireEvent("UNIT_NAME_UPDATE", "player")
H.check("class switch", icon._atlas, "classicon-warrior")
H.check("full coords with an atlas", table.concat(icon._texCoord, ","), "0,1,0,1")

-- No icon: no atlas and no coords for the class.
M.units.player.class = "TINKER"
M.FireEvent("UNIT_NAME_UPDATE", "player")
H.check("unknown class hidden", icon:IsShown(), false)
H.check("title text back at the row edge", point(tt, "RIGHT")[2], f.title)
H.check("row edge offset", point(tt, "RIGHT")[4], -4)
M.units.player.class = "WARLOCK"

-- NPC target: no icon; target change updates it.
local target = ns.Frames.target
M.units.target = { name = "Wolf", level = 10, health = 1, healthMax = 1, reaction = 2, class = "WARRIOR" }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("npc: hidden", target.classIcon:IsShown(), false)
H.check("npc: title to the row edge", point(target.texts.title, "RIGHT")[2], target.title)
M.units.target = { name = "Ally", level = 60, class = "WARRIOR", className = "Warrior", isPlayer = true,
    health = 1, healthMax = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("player target: shown", target.classIcon:IsShown())
H.check("player target: atlas", target.classIcon._atlas, "classicon-warrior")

-- Secret values: hidden, nothing touched (the strict proxy would throw).
M.units.target.class = M.Secret("WARRIOR")
local errors = #M.errors
local ok = pcall(M.FireEvent, "PLAYER_TARGET_CHANGED")
H.checkTrue("secret token: no error", ok)
H.check("secret token: nothing reported", #M.errors, errors)
H.check("secret token: hidden", target.classIcon:IsShown(), false)
M.units.target.class = "WARRIOR"
M.units.target.isPlayer = M.Secret(true)
ok = pcall(M.FireEvent, "PLAYER_TARGET_CHANGED")
H.checkTrue("secret player flag: no error", ok)
H.check("secret player flag: hidden", target.classIcon:IsShown(), false)
M.units.target.isPlayer = true
local unitClass = _G.UnitClass
_G.UnitClass = function() error("identity restricted") end
ok = pcall(M.FireEvent, "PLAYER_TARGET_CHANGED")
H.checkTrue("UnitClass error: no error", ok)
H.check("UnitClass error: hidden", target.classIcon:IsShown(), false)
_G.UnitClass = unitClass
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("readable again: shown", target.classIcon:IsShown())

-- Setting off (General, then a frame override).
C.Set("general", "titleClassIcon", false)
H.check("off: hidden", icon:IsShown(), false)
H.check("off: title to the row edge", point(tt, "RIGHT")[2], f.title)
C.Set("player", "titleClassIcon", true)
H.checkTrue("frame override on", icon:IsShown())
H.check("other frames stay off", target.classIcon:IsShown(), false)
C.Set("general", "titleClassIcon", true)

-- Title row height follows; no row, no icon.
C.Set("player", "height", 60)
H.check("size follows the row", icon:GetHeight(), f.titleHeight)
C.Set("player", "titlePercent", 0)
H.check("no title row: hidden", icon:IsShown(), false)
H.check("no title row: text hidden", tt:IsShown(), false)
C.Set("player", "titlePercent", 30)
H.checkTrue("title row back: shown", icon:IsShown())

-- Party buttons get it too.
C.Set("party", "titlePercent", 30)
M.units.party1 = { name = "Ann", class = "WARRIOR", className = "Warrior", isPlayer = true,
    health = 1, healthMax = 2 }
M.SetGroup({ "party1" })
local member = ns.Party.header:GetAttribute("child1")
M.FireEvent("UNIT_NAME_UPDATE", "party1")
H.checkTrue("party: icon exists", member.classIcon)
H.checkTrue("party: shown", member.classIcon:IsShown())
H.check("party: atlas", member.classIcon._atlas, "classicon-warrior")
H.check("party: size", member.classIcon:GetHeight(), member.titleHeight)

-- Test mode: the player's own class.
M.units.target = nil
M.FireEvent("PLAYER_TARGET_CHANGED")
ns.TestMode.Set(true)
H.checkTrue("test mode: target shows the player's class", target.classIcon:IsShown())
H.check("test mode: player's atlas", target.classIcon._atlas, "classicon-warlock")
ns.TestMode.Set(false)
M.RunTimers()

-- Options: frame Text tab and General -> Appearance.
local function rowsOf(scope, tab)
    O.Open(scope)
    O.SelectTab(tab)
    local keys = {}
    for _, row in ipairs(O.rows) do if row.key then keys[row.key] = true end end
    return keys
end
H.checkTrue("frame text tab", rowsOf("player", "text").titleClassIcon)
H.checkTrue("general appearance", rowsOf("general", "appearance").titleClassIcon)
M.RunTimers()

-- Codec round trip.
C.Set("general", "titleClassIcon", false)
C.Set("target", "titleClassIcon", true)
local s = Codec.Encode(C.Profile())
H.checkTrue("encoded general", s:find("gCL0", 1, true))
H.checkTrue("encoded target", s:find("tCL1", 1, true))
local back = assert(Codec.Decode(s))
H.check("decoded general", back.general.titleClassIcon, false)
H.check("decoded target", back.target.titleClassIcon, true)
