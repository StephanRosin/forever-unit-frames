local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

-- The frame's parts apart (barSpacing, Units/Single.lua, Elements/Boxes.lua).
H.check("code", S.Get("barSpacing").code, "SG")
H.check("per frame", S.Get("barSpacing").scope, "frame")
H.check("one block by default", S.Default(S.Get("barSpacing"), "player"), 0)

ns.Config.Use({})
ns.Single.CreateAll()
local C = ns.Config
local f = ns.Frames.player
M.units.player = { name = "Me", health = 5, healthMax = 10, power = 5, powerMax = 10 }
local _, h = ns.Single.Size("player")
local function y(region, i) return select(5, region:GetPoint(i or 1)) end
local function x(region, i) return select(4, region:GetPoint(i or 1)) end

-- 0: one block, as before.
local titleH, powerH = f.titleHeight, f.powerHeight
local healthH = f.healthHeight
H.check("0: health right below the title", y(f.health), -titleH)
H.check("0: rows fill the frame", titleH + healthH + powerH, h)
H.check("0: no gap", ns.Single.BoxGap("player"), 0)
H.check("0: frame ring drawn", f.frameRing.border[1]:IsShown(), true)
H.check("0: no boxes", f.boxes, nil)

-- 4: the spacing plus both borders' reach between the parts; the frame
-- grows by the gaps, every part keeps its height.
C.Set("player", "barSpacing", 4)
local reach = ns.Border.Extent("player")
local gap = 4 + 2 * reach
H.check("gap: spacing and two borders", ns.Single.BoxGap("player"), gap)
H.check("two gaps: below title, above power", ns.Single.Gaps("player"), 2 * gap)
H.check("frame grows by the gaps", f:GetHeight(), h + 2 * gap)
H.check("title keeps its height", f.titleHeight, titleH)
H.check("power keeps its height", f.powerHeight, powerH)
H.check("health keeps its height", f.healthHeight, healthH)
H.check("health below title and gap", y(f.health), -(titleH + gap))
H.check("power at the bottom", y(f.power), 0)
H.check("frame ring off", f.frameRing.border[1]:IsShown(), false)
H.check("frame ring holder stays (glows, elite ring)", f.frameRing:IsShown(), true)
for _, name in ipairs({ "title", "health", "power" }) do
    H.check(name .. ": own box", f.boxes[name].ring:IsShown(), true)
    H.check(name .. ": own ring", f.boxes[name].ring.border[1]:IsShown(), true)
end
H.check("no portrait box without a portrait", f.boxes.portrait, nil)
H.check("the frame's backdrop is off", f.themeBackOn, false)

-- Portrait left: the bars move right by the gap; the square spans title
-- to power.
C.Set("player", "portraitMode", "LEFT")
H.check("portrait: bars right of square and gap", x(f.health), f.layoutHeight + gap)
H.check("portrait: square from title to power, gaps included", f.portraitBg:GetHeight(), h + 2 * gap)
H.check("portrait: own box", f.boxes.portrait.ring:IsShown(), true)

-- Footer: one more gap above it, the square ends above it.
C.Set("player", "footerHeight", 12)
H.check("footer: frame grows by it and its gap", f:GetHeight(), h + 3 * gap + 12)
H.check("footer: power above footer and gap", y(f.power), 12 + gap)
H.check("footer: square ends above the gap", f.layoutHeight, h + 2 * gap)
H.check("footer: health keeps its height", f.healthHeight, healthH)
H.check("footer: own box", f.boxes.footer.ring:IsShown(), true)
C.Set("player", "footerHeight", 0)
H.check("footer gone: its box hides", f.boxes.footer.ring:IsShown(), false)

-- Portrait strip: a gap below the title and below the strip.
C.Set("player", "portraitMode", "TOP")
H.check("strip below title and gap", y(f.portraitBg), -(titleH + gap))
H.check("health below strip and gap", y(f.health), -(titleH + gap + f.portraitStrip + gap))
H.check("strip: health keeps its height", f.healthHeight, healthH)

-- Power off: no gap for it, health takes the row.
C.Set("player", "portraitMode", "OFF")
C.Set("player", "powerEnabled", false)
H.check("power off: one gap", ns.Single.Gaps("player"), gap)
H.check("power off: health to the bottom", f.healthHeight, h - titleH)
H.check("power off: no power box", f.boxes.power.ring:IsShown(), false)
C.Set("player", "powerEnabled", true)
-- A unit without power (Elements/Power.lua): health takes the row and its gap.
f.powerEmpty = true
ns.Single.LayoutBars(f)
H.check("unit without power: health takes row and gap", f.healthHeight, healthH + powerH + gap)
H.check("unit without power: no power box", f.boxes.power.ring:IsShown(), false)
f.powerEmpty = nil
ns.Single.LayoutBars(f)

-- The dispel ring goes round the health box, not across the gaps.
H.check("dispel ring round the health box", select(2, f.dispel.ring.edges[1]:GetPoint(1)), f.boxes.health.ring)

-- The overheal lane belongs to the health box.
C.Set("player", "healPrediction", true)
C.Set("player", "healOverflow", true)
H.check("lane: in the health box", select(4, f.boxes.health.ring:GetPoint(2)), f.overhealLane)

-- Back to 0: everything as before.
C.Set("player", "barSpacing", 0)
C.Set("player", "healOverflow", false)
H.check("back: health right below the title", y(f.health), -titleH)
H.check("back: health height", f.healthHeight, healthH)
H.check("back: frame ring", f.frameRing.border[1]:IsShown(), true)
H.check("back: boxes hidden", f.boxes.title.ring:IsShown(), false)
H.check("back: frame height", f:GetHeight(), h)
H.check("back: dispel ring round the frame", select(2, f.dispel.ring.edges[1]:GetPoint(1)), f)
