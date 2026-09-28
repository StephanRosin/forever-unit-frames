-- Combat and PvP icons on the frames other than yours (Elements/UnitIcons.lua).
-- Both may come back secret: that answer sets the opacity, never compared.
local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config
C.Use({})
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, health = 1, healthMax = 1,
    faction = "Alliance" }
M.units.target = { name = "Ogre", hostile = true, health = 5, healthMax = 10, faction = "Horde" }
ns.Single.CreateAll()
local t, p = ns.Frames.target, ns.Frames.player

-- Settings -----------------------------------------------------------------------
for kind, letter in pairs({ combatIcon = "E", pvpIcon = "H" }) do
    for suffix, l in pairs({ [""] = "E", Size = "S", FramePoint = "F", Point = "O", X = "X", Y = "Y" }) do
        local def = S.Get(kind .. suffix)
        H.check("code of " .. kind .. suffix, def.code, letter .. l)
        H.checkTrue(kind .. suffix .. " labelled", ns.L["SETTING_" .. kind .. suffix] ~= "SETTING_" .. kind .. suffix)
    end
    H.check(kind .. " off by default", C.Get("target", kind), false)
    H.check(kind .. " not on the pets", S.AppliesTo(S.Get(kind), "partypet"), false)
end
H.check("combat icon not on the player (it has its own)", S.AppliesTo(S.Get("combatIcon"), "player"), false)
H.checkTrue("pvp icon on the player", S.AppliesTo(S.Get("pvpIcon"), "player"))
H.check("combat icon never built on the player", p.unitIcons.combatIcon, nil)

-- Combat -------------------------------------------------------------------------
local ci = t.unitIcons.combatIcon
C.Set("target", "combatIcon", true)
H.check("out of combat: hidden", ci.holder:IsShown(), false)
M.units.target.inCombat = true
M.FireEvent("UNIT_FLAGS", "target")
H.checkTrue("in combat: shown", ci.holder:IsShown())
H.check("fully visible", ci.holder:GetAlpha(), 1)
M.units.target.inCombat = M.Secret(false)
M.FireEvent("UNIT_FLAGS", "target")
H.checkTrue("secret: shown, opacity from the answer", ci.holder:IsShown())
H.check("secret false: transparent", ci.holder:GetAlpha(), 0)
M.units.target.inCombat = false
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("combat over: hidden", ci.holder:IsShown(), false)
C.Set("target", "combatIconSize", 30)
H.check("size", ci.holder:GetWidth(), 30)
local point, rel, relPoint = ci.holder:GetPoint(1)
H.check("left of the frame", point .. ">" .. relPoint, "RIGHT>LEFT")

-- PvP ----------------------------------------------------------------------------
local pi = t.unitIcons.pvpIcon
C.Set("target", "pvpIcon", true)
M.units.target.pvp = true
M.FireEvent("UNIT_FACTION", "target")
H.check("a flagged NPC: no crest (the elite marker's corner)", pi.holder:IsShown(), false)
M.units.target.pvp = nil
M.units.target.isPlayer = true
M.FireEvent("UNIT_FACTION", "target")
H.check("not flagged: hidden", pi.holder:IsShown(), false)
M.units.target.pvp = true
M.FireEvent("UNIT_FACTION", "target")
H.checkTrue("flagged: shown", pi.holder:IsShown())
local art = pi.tex._atlas or pi.tex._texture
H.checkTrue("horde crest", art and art:find("Horde") ~= nil)
M.units.target.ffa = true
M.FireEvent("UNIT_FACTION", "target")
art = pi.tex._atlas or pi.tex._texture
H.checkTrue("free for all crest", art and art:find("FFA") ~= nil)
M.units.target.ffa = false
M.units.target.faction = M.Secret("Horde")
M.FireEvent("UNIT_FACTION", "target")
H.check("secret faction: no crest", pi.holder:IsShown(), false)
M.units.target.faction = "Horde"
M.units.target.pvp = M.Secret(true)
M.FireEvent("UNIT_FACTION", "target")
H.check("secret flag: opacity from it", pi.holder:GetAlpha(), 1)
C.Set("player", "pvpIcon", true)
M.units.player.pvp = true
M.FireEvent("UNIT_FACTION", "player")
H.checkTrue("player: own crest", p.unitIcons.pvpIcon.holder:IsShown())

-- Test mode ------------------------------------------------------------------------
M.units.target.pvp, M.units.target.inCombat = false, false
M.units.player.pvp = false
M.FireEvent("UNIT_FACTION", "player")
ns.TestMode.Set(true)
local ppi = p.unitIcons.pvpIcon
H.checkTrue("test: the player shows its crest", ppi.holder:IsShown())
local pa = ppi.tex._atlas or ppi.tex._texture
H.checkTrue("test: the player's own faction", pa and pa:find("Alliance") ~= nil)
H.checkTrue("test: target in combat", ci.holder:IsShown())
H.checkTrue("test: target crest", pi.holder:IsShown())
ns.TestMode.Set(false)
H.check("test over: combat icon gone", ci.holder:IsShown(), false)
H.check("test over: the unflagged player's crest gone", ppi.holder:IsShown(), false)

-- Options: with the status icons ---------------------------------------------------
local found
for _, tab in ipairs(ns.Schema.Tabs("party")) do
    for _, sec in ipairs(tab.sections or {}) do
        if sec.id == "combatIcon" then found = tab.id end
    end
end
H.check("on the status tab", found, "status")
