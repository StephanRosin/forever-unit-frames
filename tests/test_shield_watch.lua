-- The shield watch (0.25.0): an icon per active absorb shield on the
-- player frame, with the absorb it has left; off by
-- default. Exact amounts only: points[1] of the aura, else the total of
-- the unit's absorbs while exactly one watched shield is known to be up.
local M = H.M
local ns = H.LoadAddon()
local S, C, L = ns.Settings, ns.Config, ns.L
local SW = ns.ShieldWatch

-- Settings ------------------------------------------------------------------
local EXPECTED = {
    shieldsEnabled = { "VB", "bool", false }, shieldsPriest = { "VC", "bool", true },
    shieldsMage = { "VD", "bool", true }, shieldsWarlock = { "VI", "bool", true },
    shieldsItems = { "VJ", "bool", true }, shieldsExtra = { "VL", "text", "" },
    shieldsHideInBuffs = { "VN", "bool", true }, shieldsSize = { "VO", "int", 32 },
    shieldsSpacing = { "VP", "int", 4 }, shieldsGrowth = { "VQ", "enum", "RIGHT" },
    shieldsAmount = { "VT", "bool", true }, shieldsAbbreviate = { "VU", "bool", true },
    shieldsAmountPoint = { "VV", "enum", "CENTER" }, shieldsAmountX = { "VW", "int", 0 },
    shieldsAmountY = { "VX", "int", 0 }, shieldsAmountFont = { "ZA", "media", "" },
    shieldsAmountSize = { "ZB", "int", 0 }, shieldsAmountOutline = { "ZD", "enum", "FRAME" },
    shieldsAmountColor = { "ZI", "color", "1,1,1,1" }, shieldsSwipe = { "ZJ", "bool", true },
    shieldsTime = { "ZK", "bool", false }, shieldsTimePoint = { "ZL", "enum", "TOP" },
    shieldsTimeX = { "ZM", "int", 0 }, shieldsTimeY = { "ZQ", "int", 0 },
    shieldsTimeFont = { "ZV", "media", "" }, shieldsTimeSize = { "ZZ", "int", 0 },
    shieldsTimeOutline = { "KA", "enum", "FRAME" }, shieldsTimeColor = { "KB", "color", "1,1,1,1" },
}
for key, want in pairs(EXPECTED) do
    local def = S.Get(key)
    H.checkTrue(key .. " defined", def)
    H.check(key .. " code", def and def.code, want[1])
    H.check(key .. " type", def and def.type, want[2])
    local default = def and S.Default(def, "player")
    if type(default) == "table" then default = table.concat(default, ",") end
    H.check(key .. " default", default, want[3])
    H.check(key .. " on the player", def and S.AppliesTo(def, "player"), true)
    for _, scope in ipairs({ "target", "focus", "targettarget", "pet", "party", "general" }) do
        H.check(key .. " not on " .. scope, def and S.AppliesTo(def, scope), false)
    end
    H.check(key .. " label", type(rawget(ns.Locales.enUS, "SETTING_" .. key)), "string")
end
H.check("no only mine (target and focus are gone)", S.Get("shieldsOnlyMine"), nil)
H.check("text places", table.concat(S.Get("shieldsAmountPoint").values, ","), "TOP,BOTTOM,LEFT,RIGHT,CENTER")
H.check("growth", table.concat(S.Get("shieldsGrowth").values, ","), "RIGHT,LEFT,UP,DOWN")
H.check("extras: the spell list editor", S.Get("shieldsExtra").spellList, true)
H.check("player's place", S.Default(S.Get("shieldsX"), "player") .. "," .. S.Default(S.Get("shieldsY"), "player"),
    "-300,-140")
H.check("mover label", L.MOVER_SHIELDS:format(L.FRAME_player), "Player shields")

-- The shipped groups ------------------------------------------------------------
local groups = {}
for _, g in ipairs(SW.GROUPS) do groups[#groups + 1] = g.key end
H.check("groups", table.concat(groups, ","), "Priest,Mage,Warlock,Items")
local ids = {}
for _, g in ipairs(SW.GROUPS) do
    for _, spell in ipairs(g.spells) do
        for _, id in ipairs(spell) do
            H.check("ID listed once: " .. id, ids[id], nil)
            ids[id] = true
        end
    end
end
H.checkTrue("Power Word: Shield rank 1", ids[17])
H.checkTrue("Power Word: Shield rank 10", ids[10901])
H.checkTrue("Ice Barrier", ids[11426])
H.checkTrue("Sacrifice", ids[7812])
H.checkTrue("Greater Arcane Protection", ids[17549])

-- Names: Classic's spell data (the ones these tests use). Others the mock
-- does not know: dropped.
M.spells[17] = { name = "Power Word: Shield" }
M.spells[10901] = { name = "Power Word: Shield" }
M.spells[11426] = { name = "Ice Barrier" }
M.spells[13033] = { name = "Ice Barrier" }
M.spells[1463] = { name = "Mana Shield" }
M.spells[6229] = { name = "Shadow Ward" }
M.spells[7233] = { name = "Fire Protection" }
M.spells[17543] = { name = "Fire Protection" }
M.spells[555] = { name = "Some Barrier" }

local function names(list)
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = e.name end
    return table.concat(out, ",")
end

M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, health = 1000,
    healthMax = 1000, power = 800, powerMax = 1000, powerType = 0, auras = {}, absorbs = 0 }
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

H.check("player (mage): priest, own class, items", names(SW.Watched("player")),
    "Power Word: Shield,Ice Barrier,Mana Shield,Fire Protection")
local pws = SW.Watched("player")[1]
H.check("all ranks the client knows", table.concat(pws.ids, ","), "17,10901")
C.Set("player", "shieldsItems", false)
H.check("a group switched off", names(SW.Watched("player")), "Power Word: Shield,Ice Barrier,Mana Shield")
C.Set("player", "shieldsItems", true)
C.Set("player", "shieldsExtra", "555, 17")
H.check("additions last, once", names(SW.Watched("player")),
    "Power Word: Shield,Ice Barrier,Mana Shield,Fire Protection,Some Barrier")
C.Set("player", "shieldsExtra", "")
-- Kept between aura events; built again after a settings change.
local first = SW.Watched("player")
H.check("kept", SW.Watched("player"), first)
C.Set("player", "shieldsSize", 30)
H.checkTrue("rebuilt after a change", SW.Watched("player") ~= first)
C.Set("player", "shieldsSize", 32)

-- Off by default: nothing ------------------------------------------------------------
local f = ns.Frames.player
local sw = f.shields
H.checkTrue("built on the player", sw)
H.check("not on the target", ns.Frames.target.shields, nil)
H.check("not on the focus", ns.Frames.focus and ns.Frames.focus.shields, nil)
H.check("not on the pet", ns.Frames.pet.shields, nil)
H.check("off: hidden", sw.holder:IsShown(), false)
H.checkTrue("a mover", sw.holder.mover)
H.check("mover hidden while off", SW.MoverSpec(f).active(), false)

-- On: the shields of the player -------------------------------------------------------
local function aura(id, name, points, extra)
    local a = { auraInstanceID = id, name = name, spellId = id, icon = 100000 + id, isHelpful = true,
        mine = true, duration = 30, expirationTime = M.now + 20, applications = 0, points = points }
    for k, v in pairs(extra or {}) do a[k] = v end
    return a
end
local player = M.units.player
C.Set("player", "shieldsEnabled", true)
H.checkTrue("on: shown", sw.holder:IsShown())
H.check("mover shown while on", SW.MoverSpec(f).active(), true)
H.check("no shield: no icon", sw.shown, 0)

player.auras = { aura(10901, "Power Word: Shield", { 1500 }) }
player.absorbs = 1500
M.FireEvent("UNIT_AURA", "player")
local icon = sw.icons[1]
H.check("a shield: one icon", sw.shown, 1)
H.checkTrue("its icon shows", icon:IsShown())
H.check("the aura's texture", icon.icon._texture, 100000 + 10901)
H.check("the amount", icon.amount:GetText(), "1500")
H.checkTrue("its swipe", icon.cooldown._cooldown)

player.auras[1].points = { 25000 }
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("absorbed: the new amount, abbreviated", icon.amount:GetText(), "25.0k")
C.Set("player", "shieldsAbbreviate", false)
H.check("in full", icon.amount._fmt, "%d")
H.check("in full: the number", icon.amount._args and icon.amount._args[1], 25000)
C.Set("player", "shieldsAbbreviate", true)

-- Two shields: each its own amount.
player.auras[2] = aura(11426, "Ice Barrier", { 800 })
player.absorbs = 25800
M.FireEvent("UNIT_AURA", "player")
H.check("two shields: two icons", sw.shown, 2)
H.check("first: Power Word: Shield", sw.icons[1].icon._texture, 100000 + 10901)
H.check("second: Ice Barrier", sw.icons[2].icon._texture, 100000 + 11426)
H.check("second's amount", sw.icons[2].amount:GetText(), "800")
local x1 = select(4, sw.icons[1]:GetPoint(1))
local x2 = select(4, sw.icons[2]:GetPoint(1))
H.check("a row: one icon and a space apart", x2 - x1, 36)

-- Unreadable points: with another shield up, no number (never guessed).
player.auras[2].points = nil
M.FireEvent("UNIT_AURA", "player")
H.check("two up, one unreadable: no number", sw.icons[2].amount:GetText(), "")
H.check("the readable one keeps its own", sw.icons[1].amount:GetText(), "25.0k")
-- Alone: the total stands in.
player.auras = { player.auras[2] }
player.absorbs = 640
M.FireEvent("UNIT_AURA", "player")
H.check("one up, unreadable: the total", sw.icons[1].amount:GetText(), "640")
M.absorbsSecret = true
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.checkTrue("a secret total: through the client", M.IsSecret(sw.icons[1].amount:GetText()))
C.Set("player", "shieldsAbbreviate", false)
H.checkTrue("a secret total in full: as it is", M.IsSecret(sw.icons[1].amount:GetText()))
C.Set("player", "shieldsAbbreviate", true)
M.absorbsSecret = false
-- Secret points: handed to the text, never read.
player.auras[1].points = { M.Secret(700) }
M.FireEvent("UNIT_AURA", "player")
H.checkTrue("secret amount: to the text", M.IsSecret(sw.icons[1].amount:GetText()))
H.check("secret amount: abbreviated by the client", M.Reveal(sw.icons[1].amount:GetText()), "700~")
player.auras[1].points = M.Secret({ 700 })
M.FireEvent("UNIT_AURA", "player")
H.check("secret points list, one up: the total", sw.icons[1].amount:GetText(), "640")

-- Restricted auras: presence is not told; nothing shows, nothing guessed.
player.auras = { aura(17, "Power Word: Shield", { 300 }) }
M.aurasSecret = true
M.FireEvent("UNIT_AURA", "player")
H.check("restricted: no icon", sw.shown, 0)
H.check("restricted: icon hidden", sw.icons[1]:IsShown(), false)
M.aurasSecret = false
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("after combat: read again", sw.shown, 1)
-- A secret spell's aura: the call fails; the other shield shows, but
-- without the total (the count is not known).
player.auras = { aura(17, "Power Word: Shield", nil), aura(11426, "Ice Barrier", { 90 }) }
M.secretSpellAuras[11426] = true
M.FireEvent("UNIT_AURA", "player")
H.check("one refused: the other shows", sw.shown, 1)
H.check("one refused: no total", sw.icons[1].amount:GetText(), "")
M.secretSpellAuras[11426] = nil
-- Nothing found while the spell's aura may be secret: unknown too.
player.auras = { aura(17, "Power Word: Shield", nil) }
M.secretSpellAuras[13033] = true
M.FireEvent("UNIT_AURA", "player")
H.check("absence not told: no total", sw.icons[1].amount:GetText(), "")
M.secretSpellAuras[13033] = nil
M.FireEvent("UNIT_AURA", "player")
H.check("absence told: the total", sw.icons[1].amount:GetText(), "640")
-- Refused altogether.
M.auraError = true
M.FireEvent("UNIT_AURA", "player")
H.check("refused: nothing", sw.shown, 0)
M.auraError = false

-- Texts: places, fonts, the time ----------------------------------------------------------
M.FireEvent("UNIT_AURA", "player")
icon = sw.icons[1]
H.check("amount: centred", (icon.amount:GetPoint(1)), "CENTER")
C.Set("player", "shieldsAmountPoint", "BOTTOM")
C.Set("player", "shieldsAmountY", -2)
local p, rel, rp, _, y = icon.amount:GetPoint(1)
H.check("amount below: its top", p, "TOP")
H.check("amount below: at the icon's bottom", rp, "BOTTOM")
H.check("amount below: on the icon", rel, icon)
H.check("amount offset", y, -2)
H.check("amount size: auto from the icon", select(2, icon.amount:GetFont()), 13)
C.Set("player", "shieldsAmountSize", 20)
H.check("amount size: own", select(2, icon.amount:GetFont()), 20)
C.Set("player", "shieldsAmountColor", { 1, 0.5, 0, 1 })
H.check("amount colour", table.concat(icon.amount._color, ","), "1,0.5,0,1")
C.Set("player", "shieldsAmount", false)
H.check("amount off", icon.amount:IsShown(), false)
C.Set("player", "shieldsAmount", true)
H.check("time off: no numbers", icon.cooldown._hideNumbers, true)
C.Set("player", "shieldsTime", true)
H.check("time on: the client's numbers", icon.cooldown._hideNumbers, false)
local numbers = icon.cooldown:GetCountdownFontString()
H.check("time: above the icon", select(3, numbers:GetPoint(1)), "TOP")
C.Set("player", "shieldsTimeOutline", "SOFT")
H.check("time: soft becomes outline (the client writes it)", select(3, numbers:GetFont()), "OUTLINE")
C.Set("player", "shieldsTimeColor", { 0, 1, 0, 1 })
H.check("time colour", table.concat(numbers._color, ","), "0,1,0,1")

-- Growth.
player.auras[2] = aura(11426, "Ice Barrier", { 90 })
M.FireEvent("UNIT_AURA", "player")
C.Set("player", "shieldsGrowth", "UP")
H.check("up: from the bottom", (sw.icons[1]:GetPoint(1)), "BOTTOM")
H.check("up: the next above", select(5, sw.icons[2]:GetPoint(1)), 36)
local w, h = SW.Size("player")
H.check("up: the handle is a column", w .. "x" .. h, "32x68")
C.Set("player", "shieldsGrowth", "RIGHT")

-- Clamped to the screen.
local spec = SW.MoverSpec(f)
H.check("clamp: inside", spec.clamp("x", 100), 100)
H.check("clamp: past the right edge", spec.clamp("x", 99999), (UIParent:GetWidth() - 68) / 2)
H.check("clamp: past the bottom", spec.clamp("y", -99999), -(UIParent:GetHeight() - 32) / 2)

-- Hide them in the buffs ---------------------------------------------------------------------
local buffs = f.auras.buffs
H.checkTrue("in the buffs' excluded set", buffs.blockSet and buffs.blockSet[10901] and buffs.blockSet[11426])
H.check("not in the debuffs'", f.auras.debuffs.blockSet and f.auras.debuffs.blockSet[10901], nil)
C.Set("player", "shieldsHideInBuffs", false)
H.check("hide off: not excluded", buffs.blockSet and buffs.blockSet[10901], nil)
C.Set("player", "shieldsHideInBuffs", true)
C.Set("player", "shieldsEnabled", false)
H.check("watch off: not excluded", buffs.blockSet and buffs.blockSet[10901], nil)
C.Set("player", "auraBlock", "5019")
C.Set("player", "shieldsEnabled", true)
H.checkTrue("with the frame's hidden auras", buffs.blockSet[5019] and buffs.blockSet[10901])
H.check("the container's filters", ns.AuraContainers.CandidateFilters(buffs).excludeSpellIDs[10901], true)
H.check("not for the target", SW.HiddenSet("target"), nil)
H.check("not for the party", SW.HiddenSet("party"), nil)

-- Test mode: two samples -----------------------------------------------------------------------------
ns.TestMode.Set(true)
H.check("test mode samples", sw.shown, 2)
H.check("a sample amount", sw.icons[1].amount:GetText(), "1250")
ns.TestMode.Set(false)
H.check("test mode over: the player's own again", sw.shown, 2)
