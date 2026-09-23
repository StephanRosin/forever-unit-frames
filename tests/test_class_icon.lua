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

-- Badge size and position: inherited ints with their own permanent codes.
for _, want in ipairs({
    { key = "classIconSize", code = "KS", default = 20, min = 10, max = 48, label = "Class icon size" },
    { key = "classIconX", code = "KX", default = -4, min = -64, max = 64, label = "Class icon X" },
    { key = "classIconY", code = "KY", default = 4, min = -64, max = 64, label = "Class icon Y" },
}) do
    local d = S.Get(want.key)
    H.checkTrue(want.key .. ": exists", d)
    H.check(want.key .. ": code", d and d.code, want.code)
    H.check(want.key .. ": inherited", d and d.scope, "inherit")
    H.check(want.key .. ": int", d and d.type, "int")
    H.check(want.key .. ": default", d and S.Default(d, "general"), want.default)
    H.check(want.key .. ": min", d and d.min, want.min)
    H.check(want.key .. ": max", d and d.max, want.max)
    H.check(want.key .. ": label", ns.L["SETTING_" .. want.key], want.label)
    H.checkTrue(want.key .. ": hint", ns.L["HINT_" .. want.key])
end

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, O = ns.Config, ns.Options
local f = ns.Frames.player
local icon, tt = f.classIcon, f.texts.title
local badge, ring = f.classBadge, f.classRing
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

M.units.player = { name = "Me", level = 60, class = "WARLOCK", className = "Warlock", isPlayer = true,
    health = 5, healthMax = 10 }
M.FireEvent("PLAYER_ENTERING_WORLD")

-- A player with a readable class: the atlas, on a round badge over the
-- frame's top right corner.
H.checkTrue("icon exists", icon)
H.checkTrue("shown for a player", icon:IsShown())
H.check("class atlas", icon._atlas, "classicon-warlock")
H.checkTrue("badge exists", badge)
H.check("badge is a child of the frame", badge:GetParent(), f)
H.check("badge: centre", point(badge, "CENTER")[2], f)
H.check("badge: on the frame's top right corner", point(badge, "CENTER")[3], "TOPRIGHT")
H.check("badge: default x", point(badge, "CENTER")[4], -4)
H.check("badge: default y", point(badge, "CENTER")[5], 4)
H.check("badge: width", badge:GetWidth(), 20)
H.check("badge: height", badge:GetHeight(), 20)
H.checkTrue("badge above the health bar", badge:GetFrameLevel() > f.health:GetFrameLevel())
H.checkTrue("badge above the power bar", badge:GetFrameLevel() > f.power:GetFrameLevel())
H.checkTrue("badge above the frame's border", badge:GetFrameLevel() > f:GetFrameLevel())
H.checkTrue("badge clear of texts on the bars", badge:GetFrameLevel() >= f:GetFrameLevel() + 10)
-- Icon inside a ring of the border colour (border size, 1 px by default).
H.check("icon on the badge", icon:GetParent(), badge)
H.check("icon centred", point(icon, "CENTER")[2], badge)
H.check("icon inside the ring", icon:GetWidth(), 18)
H.check("icon round", icon:GetHeight(), 18)
H.check("icon: one mask", icon:GetNumMaskTextures(), 1)
H.check("icon: circular mask", icon._masks[1]._texture, CIRCLE)
H.check("icon: mask clamps", icon._masks[1]._wrap[1], "CLAMPTOBLACKADDITIVE")
H.checkTrue("ring exists", ring)
H.check("ring on the badge", ring:GetParent(), badge)
H.checkTrue("ring shown with the icon", ring:IsShown())
H.check("ring fills the badge", ring._allPoints, badge)
H.check("ring: circular mask", ring._masks[1] and ring._masks[1]._texture, CIRCLE)
H.check("ring: border colour", table.concat(ring._color, ","), "0,0,0,1")
local _, iconSub = icon:GetDrawLayer()
local _, ringSub = ring:GetDrawLayer()
H.checkTrue("icon drawn over the ring", iconSub > ringSub)
-- Default X/Y: the badge's left edge (-14) is inside the title row.
H.check("title text ends at the badge", point(tt, "RIGHT")[2], badge)
H.check("badge side", point(tt, "RIGHT")[3], "LEFT")
H.check("2 px before the badge", point(tt, "RIGHT")[4], -2)
H.check("text stays centred on the row", point(tt, "RIGHT")[5], -f.titleHeight / 2 - 4)

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
H.check("ring hidden with the icon", ring:IsShown(), false)
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

-- Size and position settings; the ring follows the border.
C.Set("player", "height", 60)
H.check("badge size independent of the row", badge:GetHeight(), 20)
C.Set("player", "height", 46)
C.Set("general", "classIconX", 6)
C.Set("general", "classIconY", -3)
H.check("x from General", point(badge, "CENTER")[4], 6)
H.check("y from General", point(badge, "CENTER")[5], -3)
H.check("target inherits x", point(target.classBadge, "CENTER")[4], 6)
C.Set("player", "classIconX", 30)
H.check("frame x override", point(badge, "CENTER")[4], 30)
H.check("left edge right of the row: title to the row edge", point(tt, "RIGHT")[2], f.title)
H.check("row edge offset again", point(tt, "RIGHT")[4], -4)
C.Set("player", "classIconX", -4)
H.check("left edge in the row again", point(tt, "RIGHT")[2], badge)
C.Set("player", "portraitMode", "RIGHT")
H.check("badge over a right portrait: title to the row edge", point(tt, "RIGHT")[2], f.title)
C.Set("player", "portraitMode", "OFF")
C.Set("player", "classIconSize", 31)
H.check("size setting: badge", badge:GetWidth(), 31)
H.check("size setting: icon", icon:GetWidth(), 29)
C.Set("player", "borderColor", { 1, 0, 0, 1 })
H.check("ring colour follows", table.concat(ring._color, ","), "1,0,0,1")
C.Set("player", "borderSize", 2)
H.check("thicker ring", icon:GetWidth(), 27)
C.Set("player", "borderSize", 0)
H.check("no border: no ring", ring:IsShown(), false)
H.check("no border: icon fills the badge", icon:GetWidth(), 31)
C.Set("player", "borderSize", 1)
C.Set("player", "classIconSize", 20)
C.Set("general", "classIconX", -4)
C.Set("general", "classIconY", 4)

-- No title row, no icon.
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
H.check("party: badge size", member.classBadge:GetHeight(), 20)
H.check("party: badge on the corner", point(member.classBadge, "CENTER")[3], "TOPRIGHT")
H.check("party: badge offset", point(member.classBadge, "CENTER")[5], 4)
H.checkTrue("party: badge above the bars", member.classBadge:GetFrameLevel() > member.health:GetFrameLevel())
H.check("party: masked", member.classIcon:GetNumMaskTextures(), 1)
H.checkTrue("party: ring shown", member.classRing:IsShown())
H.check("party: title text ends at the badge", point(member.texts.title, "RIGHT")[2], member.classBadge)

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
for _, key in ipairs({ "titleClassIcon", "classIconSize", "classIconX", "classIconY" }) do
    H.checkTrue("frame text tab: " .. key, rowsOf("player", "text")[key])
    H.checkTrue("general appearance: " .. key, rowsOf("general", "appearance")[key])
end
M.RunTimers()

-- Codec round trip.
C.Set("general", "titleClassIcon", false)
C.Set("target", "titleClassIcon", true)
C.Set("general", "classIconSize", 24)
C.Set("party", "classIconX", -10)
C.Set("target", "classIconY", 0)
local s = Codec.Encode(C.Profile())
H.checkTrue("encoded general", s:find("gCL0", 1, true))
H.checkTrue("encoded target", s:find("tCL1", 1, true))
H.checkTrue("encoded size", s:find("gKS24", 1, true))
H.checkTrue("encoded x", s:find("yKX-10", 1, true))
H.checkTrue("encoded y", s:find("tKY0", 1, true))
local back = assert(Codec.Decode(s))
H.check("decoded general", back.general.titleClassIcon, false)
H.check("decoded target", back.target.titleClassIcon, true)
H.check("decoded size", back.general.classIconSize, 24)
H.check("decoded x", back.party.classIconX, -10)
H.check("decoded y", back.target.classIconY, 0)
