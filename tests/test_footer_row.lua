local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local C, S = ns.Config, ns.Settings
local f = ns.Frames.player
M.units.player = { name = "Me", health = 500, healthMax = 1000, power = 200, powerMax = 300, role = "TANK" }
local w, h = ns.Single.Size("player")

-- Settings: own codes, off by default; the new tags appended.
H.check("height code", S.Get("footerHeight").code, "FY")
H.check("off by default", S.Default(S.Get("footerHeight"), "player"), 0)
H.check("tags appended", table.concat(S.TEXT_TAGS, ",", 9), "INFO,POWER_CURRENT_MAX,ROLE")
H.checkTrue("no footer: hidden", not f.footer:IsShown())

-- On: the frame grows by it, the power bar sits on top of it.
C.Set("player", "footerHeight", 14)
H.check("frame grows", f:GetHeight(), h + 14)
H.check("width unchanged", f:GetWidth(), w)
H.checkTrue("footer shown", f.footer:IsShown())
H.check("footer height", f.footer:GetHeight(), 14)
H.check("power above the footer", select(5, f.power:GetPoint(1)), 14)
H.check("bars keep their height", f.layoutHeight, h)

-- Mana left, role centre, health right.
C.Set("player", "footerTextLeft", "POWER_CURRENT_MAX")
C.Set("player", "footerTextCenter", "ROLE")
C.Set("player", "footerTextRight", "CURRENT_MAX")
M.FireEvent("UNIT_HEALTH", "player")
local t = f.texts
local function text(fs) return fs._text or (fs._fmt and fs._fmt:format(unpack(fs._args))) end
H.check("power left", text(t.footerLeft), "200 / 300")
H.check("health right", text(t.footerRight), "500 / 1000")
H.checkTrue("role icon", (t.footerCenter:GetText() or ""):find("UI-LFG-RoleIcon-Tank", 1, true))
H.checkTrue("centre shown", t.footerCenter:IsShown())

-- Value events update their own numbers, power on the footer too.
M.units.player.power = 150
M.FireEvent("UNIT_POWER_FREQUENT", "player")
H.check("power follows", text(t.footerLeft), "150 / 300")
M.units.player.health = 400
M.FireEvent("UNIT_HEALTH", "player")
H.check("health follows", text(t.footerRight), "400 / 1000")
H.check("power kept", text(t.footerLeft), "150 / 300")

-- The role follows the group's roles; none: empty.
M.units.player.role = "NONE"
M.FireEvent("PLAYER_ROLES_ASSIGNED")
H.check("no role: empty", t.footerCenter:GetText(), "")

-- Off again: back to the old height, texts hidden.
C.Set("player", "footerHeight", 0)
H.check("height back", f:GetHeight(), h)
H.check("power at the bottom", select(5, f.power:GetPoint(1)), 0)
H.checkTrue("texts hidden", not t.footerLeft:IsShown() and not t.footerCenter:IsShown())
