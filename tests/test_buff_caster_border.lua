-- Buff borders by caster: yours in one colour, everyone else's in another.
-- The container's "own" (PLAYER) and "other" (!PLAYER) groups tell them
-- apart; without "mine first" both keep the normal size and rows.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C = ns.Settings, ns.Config
C.Use({})

for key, code in pairs({ buffsCasterBorder = "JW", buffsOwnBorderColor = "JQ", buffsOtherBorderColor = "JU" }) do
    H.check("code of " .. key, S.Get(key).code, code)
    H.checkTrue(key .. " labelled", ns.L["SETTING_" .. key] ~= "SETTING_" .. key)
end
H.check("no debuff counterpart", S.Get("debuffsCasterBorder"), nil)
H.check("off by default", C.Get("target", "buffsCasterBorder"), false)

M.units.target = { name = "Friend", health = 5, healthMax = 10 }
local t = ns.Frames.target
H.checkTrue("containers", ns.AuraContainers.Ensure(t))
local bc = t.auraContainers.buffs.container
C.Set("target", "buffsHighlightOwn", false)
H.check("off: no own group", bc._groups.own.enabled, false)

C.Set("target", "buffsCasterBorder", true)
H.checkTrue("on: own group", bc._groups.own.enabled)
H.check("own: yours", bc._groups.own.filter, "HELPFUL|PLAYER")
H.check("other: the rest", bc._groups.other.filter, "HELPFUL|!PLAYER")
H.check("same size for yours", bc._groups.own.layout.elementWidth, bc._groups.other.layout.elementWidth)
H.check("same rows", bc._groups.other.layout.forceNewLine, false)

-- Buttons the client makes get the colours.
local g = t.auras.buffs
local function fake()
    local b = CreateFrame("Frame")
    for _, m in ipairs({ "SetIcon", "SetDurationCooldown", "SetApplicationCount", "SetTooltipAnchorPoint" }) do
        b[m] = function() end
    end
    return b
end
local entry = t.auraContainers.buffs
local ob, xb = fake(), fake()
ns.AuraContainers.InitButton(entry, true, ob)
ns.AuraContainers.InitButton(entry, false, xb)
local function tint(b) return b.border._color end
H.check("own button green", tint(ob)[2], C.Get("target", "buffsOwnBorderColor")[2])
H.check("other button red", tint(xb)[1], C.Get("target", "buffsOtherBorderColor")[1])
-- A colour change reaches buttons already made.
C.Set("target", "buffsOtherBorderColor", { 0, 0, 1, 1 })
H.check("restyled other", tint(xb)[3], 1)
-- Off again: the plain border.
C.Set("target", "buffsCasterBorder", false)
H.check("off: plain border", tint(xb)[1], C.Get("target", "borderColor")[1])
H.check("off: own group off", bc._groups.own.enabled, false)

-- With "mine first" the own size and rows stay as they were.
C.Set("target", "buffsCasterBorder", true)
C.Set("target", "buffsHighlightOwn", true)
H.check("mine first: own size", bc._groups.own.layout.elementWidth, C.Get("target", "buffsOwnSize"))
H.check("mine first: new line", bc._groups.other.layout.forceNewLine, true)

-- Debuffs keep their dispel colours: never split for it.
H.check("debuffs untouched", t.auraContainers.debuffs.container._groups.own.enabled,
    C.Get("target", "debuffsHighlightOwn"))

-- Test mode: the first samples count as yours.
C.Set("target", "buffsHighlightOwn", false)
M.units.player = M.units.player or { name = "Me", class = "PRIEST", isPlayer = true, health = 1, healthMax = 1 }
ns.TestMode.Set(true)
local first, last = g.buttons[1], g.buttons[g.count]
H.check("sample 1 is yours", tint(first)[2], C.Get("target", "buffsOwnBorderColor")[2])
H.check("the last is someone else's", tint(last)[3], 1)
ns.TestMode.Set(false)
