-- The shield watch (0.25.0) on the player frame: the icons of the active
-- watched shields come from a Blizzard aura container (candidate filter
-- includeSpellIDs = the watched IDs); one text shows the exact total of
-- all absorbs (UnitGetTotalAbsorbs), empty at zero. Off by default. No
-- shield is read by the addon.
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
    shieldsX = { "VR", "int", -300 }, shieldsY = { "VS", "int", -140 },
    shieldsTotal = { "VT", "bool", true }, shieldsTotalPoint = { "VV", "enum", "LEFT" },
    shieldsTotalX = { "VW", "int", -3 }, shieldsTotalY = { "VX", "int", 0 },
    shieldsTotalFont = { "ZA", "media", "" }, shieldsTotalSize = { "ZB", "int", 0 },
    shieldsTotalOutline = { "ZD", "enum", "FRAME" }, shieldsTotalColor = { "ZI", "color", "1,1,1,1" },
    shieldsSwipe = { "ZJ", "bool", true }, shieldsTime = { "ZK", "bool", false },
    shieldsTimePoint = { "ZL", "enum", "TOP" }, shieldsTimeX = { "ZM", "int", 0 },
    shieldsTimeY = { "ZQ", "int", 0 }, shieldsTimeFont = { "ZV", "media", "" },
    shieldsTimeSize = { "ZZ", "int", 0 }, shieldsTimeOutline = { "KA", "enum", "FRAME" },
    shieldsTimeColor = { "KB", "color", "1,1,1,1" },
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
-- Gone with the per-shield amounts and target/focus (never released).
for _, key in ipairs({ "shieldsOnlyMine", "shieldsAbbreviate", "shieldsAmount", "shieldsAmountPoint",
    "shieldsAmountColor" }) do
    H.check("gone: " .. key, S.Get(key), nil)
end
H.check("text places", table.concat(S.Get("shieldsTotalPoint").values, ","), "TOP,BOTTOM,LEFT,RIGHT,CENTER")
H.check("growth", table.concat(S.Get("shieldsGrowth").values, ","), "RIGHT,LEFT,UP,DOWN")
H.check("extras: the spell list editor", S.Get("shieldsExtra").spellList, true)
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
H.checkTrue("Holy Protection", ids[7245])
H.checkTrue("Greater Holy Protection", ids[17545])

M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, health = 1000,
    healthMax = 1000, power = 800, powerMax = 1000, powerType = 0, auras = {}, absorbs = 0 }
-- No per-shield reads: the addon never asks for a shield by name.
local byName = 0
local getByName = C_UnitAuras.GetAuraDataBySpellName
C_UnitAuras.GetAuraDataBySpellName = function(...)
    byName = byName + 1
    return getByName(...)
end
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

-- The watched IDs ----------------------------------------------------------------------
local watched = SW.Watched("player")
H.checkTrue("a mage: Power Word: Shield (a priest's lands on anyone)", watched[10901])
H.checkTrue("a mage: the mage's", watched[11426] and watched[13033] and watched[1463])
H.checkTrue("a mage: potions and items", watched[7233] and watched[17545])
H.check("a mage: not the warlock's", watched[6229], nil)
C.Set("player", "shieldsItems", false)
H.check("a group switched off", SW.Watched("player")[7233], nil)
C.Set("player", "shieldsItems", true)
C.Set("player", "shieldsExtra", "555, 17")
H.checkTrue("additions", SW.Watched("player")[555])
C.Set("player", "shieldsExtra", "")
local first = SW.Watched("player")
H.check("kept between aura events", SW.Watched("player"), first)
C.Set("player", "shieldsSize", 30)
H.checkTrue("rebuilt after a change", SW.Watched("player") ~= first)
C.Set("player", "shieldsSize", 32)

-- Off by default: nothing ------------------------------------------------------------
local f = ns.Frames.player
local sw = f.shields
H.checkTrue("built on the player", sw)
H.check("not on the target", ns.Frames.target.shields, nil)
H.check("not on the pet", ns.Frames.pet.shields, nil)
H.check("off: hidden", sw.holder:IsShown(), false)
H.checkTrue("a mover", sw.holder.mover)
H.check("mover hidden while off", SW.MoverSpec(f).active(), false)

H.check("off: no container yet", sw.container, nil)

-- The container -------------------------------------------------------------------------
local player = M.units.player
C.Set("player", "shieldsEnabled", true)
H.checkTrue("on: shown", sw.holder:IsShown())
H.check("mover shown while on", SW.MoverSpec(f).active(), true)
local container = sw.container
H.checkTrue("a Blizzard aura container", container)
H.check("on the player", container:GetUnit(), "player")
H.check("in the block", container:GetParent(), sw.holder)
local group = container._groups[SW.GROUP]
H.check("one group, helpful auras", group and group.filter, "HELPFUL")
H.check("only the watched spells", group.candidateFilters.includeSpellIDs[10901], true)
H.check("not the others", group.candidateFilters.includeSpellIDs[6229], nil)
H.check("its icons: the icon size", group.layout.elementWidth, 32)
H.check("its icons: the spacing", group.layout.elementSpacing, 4)
H.check("grows right from the first corner", container._flow.anchor, "TOPLEFT")
H.check("grows right", container._flow.horizontal, AnchorUtil.FlowDirection.Right)
H.check("its corner at the block's", select(2, container:GetPoint(1)), sw.holder)
H.check("on: the container shows", container:IsShown(), true)

local function aura(id, extra)
    local a = { auraInstanceID = id, spellId = id, icon = 100000 + id, isHelpful = true, mine = true,
        duration = 30, expirationTime = M.now + 20, applications = 0 }
    for k, v in pairs(extra or {}) do a[k] = v end
    return a
end

-- What the container shows: the watched shields, nothing else.
player.auras = { aura(10901), aura(1459), aura(11426), aura(6229) }
M.FireEvent("UNIT_AURA", "player")
H.check("the client shows the watched shields", table.concat(M.AuraContainerShows(container, SW.GROUP), ","),
    "10901,11426")

-- Its buttons: our look, the client's icon, swipe and countdown.
local button = group.frames[1]
H.check("button: the icon size", button:GetWidth(), 32)
H.check("button: the client fills its icon", button._icon, button.icon)
H.check("button: the client runs its swipe", button._durationCooldown, button.cooldown)
H.check("button: swipe on", button.cooldown._drawSwipe, true)
H.check("button: time off", button.cooldown._hideNumbers, true)

-- The total -------------------------------------------------------------------------------
local total = sw.total
player.absorbs = 1500
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("the total", total:GetText(), "1500")
H.checkTrue("shown", total:IsShown())
player.absorbs = 2200
M.FireEvent("UNIT_AURA", "player")
H.check("follows aura changes too", total:GetText(), "2200")
player.absorbs = 0
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("zero: empty", total:GetText(), "")
player.absorbs = 640
M.absorbsSecret = true
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.checkTrue("a secret total: the client writes it", M.IsSecret(total:GetText()))
H.check("a secret total: the number", M.Reveal(total:GetText()), "640")
player.absorbs = 0
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("a secret zero: empty", M.Reveal(total:GetText()), "")
M.absorbsSecret = false
player.absorbs = 640
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("no shield read by name", byName, 0)

-- Its place: at the container's side (the client sizes it to its icons),
-- from a frame allowed to anchor there.
local p, rel, rp, x, y = total:GetPoint(1)
H.check("before the icons: its right", p, "RIGHT")
H.check("before the icons: at the container's left", rp, "LEFT")
H.check("before the icons: on the container", rel, container)
H.check("a small gap", x, -3)
C.Set("player", "shieldsTotalPoint", "TOP")
C.Set("player", "shieldsTotalY", 2)
p, rel, rp, x, y = total:GetPoint(1)
H.check("above: its bottom", p, "BOTTOM")
H.check("above: at the top", rp, "TOP")
H.check("above: the offset", y, 2)
H.check("automatic size: half the icon", select(2, total:GetFont()), 16)
C.Set("player", "shieldsTotalSize", 20)
H.check("own size", select(2, total:GetFont()), 20)
C.Set("player", "shieldsTotalColor", { 1, 0.5, 0, 1 })
H.check("colour", table.concat(total._color, ","), "1,0.5,0,1")
C.Set("player", "shieldsTotal", false)
H.check("total off", total:IsShown(), false)
C.Set("player", "shieldsTotal", true)

-- Settings onto the container --------------------------------------------------------------
C.Set("player", "shieldsTime", true)
H.check("time on: the countdown", button.cooldown._hideNumbers, false)
local numbers = button.cooldown:GetCountdownFontString()
H.check("time: above the icon", select(3, numbers:GetPoint(1)), "TOP")
C.Set("player", "shieldsTimeOutline", "SOFT")
H.check("time: soft becomes outline (the client writes it)", select(3, numbers:GetFont()), "OUTLINE")
C.Set("player", "shieldsTimeColor", { 0, 1, 0, 1 })
H.check("time colour", table.concat(numbers._color, ","), "0,1,0,1")
C.Set("player", "shieldsSwipe", false)
H.check("swipe off", button.cooldown._drawSwipe, false)
C.Set("player", "shieldsSwipe", true)
C.Set("player", "shieldsGrowth", "UP")
H.check("up: from the bottom corner", container._flow.anchor, "BOTTOMLEFT")
H.check("up: a column", container._flow.axis, AnchorUtil.FlowLayoutAxis.Vertical)
H.check("up: grows up", container._flow.vertical, AnchorUtil.FlowDirection.Up)
local w, h = SW.Size("player")
H.check("up: the handle is a column", w .. "x" .. h, "32x68")
C.Set("player", "shieldsGrowth", "RIGHT")
C.Set("player", "shieldsExtra", "555")
H.check("an addition reaches the container", group.candidateFilters.includeSpellIDs[555], true)
C.Set("player", "shieldsExtra", "")

-- In combat: nothing configured until it ends; the total keeps up.
M.SetCombat(true)
C.Set("player", "shieldsSize", 40)
H.check("combat: the layout waits", group.layout.elementWidth, 32)
player.absorbs = 900
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("combat: the total follows", total:GetText(), "900")
M.SetCombat(false)
H.check("after combat: the layout", group.layout.elementWidth, 40)
H.check("after combat: the buttons", button:GetWidth(), 40)
-- Auras secret out of combat (an instance): the buttons refuse; again
-- after the next combat.
M.aurasSecret = true
C.Set("player", "shieldsSize", 36)
H.check("refused: the old size", rawget(button, "_w"), 40)
M.aurasSecret = false
M.SetCombat(true)
M.SetCombat(false)
H.check("restyled after combat", button:GetWidth(), 36)
C.Set("player", "shieldsSize", 32)

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
H.check("watch off: the container hides", container:IsShown(), false)
C.Set("player", "auraBlock", "5019")
C.Set("player", "shieldsEnabled", true)
H.checkTrue("with the frame's hidden auras", buffs.blockSet[5019] and buffs.blockSet[10901])
H.check("the buffs container's filters", ns.AuraContainers.CandidateFilters(buffs).excludeSpellIDs[10901], true)
H.check("not for the target", SW.HiddenSet("target"), nil)

-- Test mode: two samples and a sample total ------------------------------------------------------
ns.TestMode.Set(true)
H.check("test mode: two samples", sw.shown, 2)
H.checkTrue("test mode: a sample icon", sw.samples[1]:IsShown())
H.check("test mode: the container hides", container:IsShown(), false)
H.check("test mode: a sample total", total:GetText(), "2068")
H.check("test mode: the total on the handle", select(2, total:GetPoint(1)), sw.holder)
ns.TestMode.Set(false)
H.check("test mode over: no samples", sw.shown, 0)
H.check("test mode over: the container again", container:IsShown(), true)
H.check("test mode over: the total again", total:GetText(), "900")
H.check("test mode over: the total at the container", select(2, total:GetPoint(1)), container)
H.check("still no shield read by name", byName, 0)
