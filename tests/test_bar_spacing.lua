local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

-- The frame's parts apart (spacing*, Units/Single.lua, Elements/Boxes.lua).
local CODES = { spacingTitle = "GT", spacingPower = "GP", spacingPortrait = "GQ", spacingDocked = "GD",
    boxBorderShow = "BU", boxBorderSize = "BK", boxBorderColor = "BX", boxCornerRadius = "BR" }
for key, code in pairs(CODES) do
    H.check(key .. " code", S.Get(key).code, code)
    H.check(key .. " per frame", S.Get(key).scope, "frame")
end
for _, key in ipairs({ "spacingTitle", "spacingPower", "spacingPortrait", "spacingDocked" }) do
    H.check(key .. ": one block by default", S.Default(S.Get(key), "player"), 0)
end
-- The box border's defaults are the frame border's (one black pixel, square).
H.check("box border on", S.Default(S.Get("boxBorderShow"), "player"), true)
H.check("box border size as the frame's", S.Default(S.Get("boxBorderSize"), "player"),
    S.Default(S.Get("borderSize"), "player"))
H.check("box border colour as the frame's", table.concat(S.Default(S.Get("boxBorderColor"), "player"), ","),
    table.concat(S.Default(S.Get("borderColor"), "player"), ","))
H.check("box corners as the frame's", S.Default(S.Get("boxCornerRadius"), "player"),
    S.Default(S.Get("cornerRadius"), "player"))

ns.Config.Use({})
ns.Single.CreateAll()
local C = ns.Config
local f = ns.Frames.player
M.units.player = { name = "Me", health = 5, healthMax = 10, power = 5, powerMax = 10 }
local _, h = ns.Single.Size("player")
local function y(region, i) return select(5, region:GetPoint(i or 1)) end
local function x(region, i) return select(4, region:GetPoint(i or 1)) end

-- All 0: one block, as before.
local titleH, powerH, healthH = f.titleHeight, f.powerHeight, f.healthHeight
H.check("0: health right below the title", y(f.health), -titleH)
H.check("0: rows fill the frame", titleH + healthH + powerH, h)
H.check("0: not apart", ns.Single.Apart("player"), false)
H.check("0: no gaps", ns.Single.Gaps("player"), 0)
H.check("0: frame ring drawn", f.frameRing.border[1]:IsShown(), true)
H.check("0: no boxes", f.boxes, nil)

-- Each gap on its own: the player's gap plus both box borders' reach (one
-- pixel each by default); any gap sets the parts apart.
local ring = 1
C.Set("player", "spacingPower", 4)
local powerGap = 4 + 2 * ring
H.check("power gap", ns.Single.Gap("player", "power"), powerGap)
H.check("apart with one gap", ns.Single.Apart("player"), true)
H.check("title gap 0: borders touch", ns.Single.Gap("player", "title"), 2 * ring)
C.Set("player", "spacingTitle", 2)
local titleGap = 2 + 2 * ring
H.check("title gap", ns.Single.Gap("player", "title"), titleGap)
H.check("frame grows by both gaps", f:GetHeight(), h + titleGap + powerGap)
H.check("title keeps its height", f.titleHeight, titleH)
H.check("power keeps its height", f.powerHeight, powerH)
H.check("health keeps its height", f.healthHeight, healthH)
H.check("health below title and its gap", y(f.health), -(titleH + titleGap))
H.check("power at the bottom", y(f.power), 0)
H.check("frame ring off", f.frameRing.border[1]:IsShown(), false)
H.check("frame ring holder stays (glows, elite ring)", f.frameRing:IsShown(), true)
for _, name in ipairs({ "title", "health", "power" }) do
    H.check(name .. ": own box", f.boxes[name].ring:IsShown(), true)
    H.check(name .. ": own ring", f.boxes[name].ring.border[1]:IsShown(), true)
end
H.check("no portrait box without a portrait", f.boxes.portrait, nil)
H.check("the frame's backdrop is off", f.themeBackOn, false)

-- Portrait left: its own gap beside it; the square spans title to power.
C.Set("player", "spacingPortrait", 6)
local sideGap = 6 + 2 * ring
C.Set("player", "portraitMode", "LEFT")
H.check("portrait gap", ns.Single.Gap("player", "portrait"), sideGap)
H.check("portrait: bars right of square and gap", x(f.health), f.layoutHeight + sideGap)
H.check("portrait: square from title to power, gaps included", f.portraitBg:GetHeight(), h + titleGap + powerGap)
H.check("portrait: own box", f.boxes.portrait.ring:IsShown(), true)
H.check("portrait gap: frame height unchanged", f:GetHeight(), h + titleGap + powerGap)

-- Footer: the title gap above it too.
C.Set("player", "footerHeight", 12)
H.check("footer: frame grows by it and its gap", f:GetHeight(), h + 2 * titleGap + powerGap + 12)
H.check("footer: power above footer and gap", y(f.power), 12 + titleGap)
H.check("footer: health keeps its height", f.healthHeight, healthH)
H.check("footer: own box", f.boxes.footer.ring:IsShown(), true)
C.Set("player", "footerHeight", 0)
H.check("footer gone: its box hides", f.boxes.footer.ring:IsShown(), false)

-- Portrait strip: the title gap above it, the portrait gap below it.
C.Set("player", "portraitMode", "TOP")
H.check("strip below title and its gap", y(f.portraitBg), -(titleH + titleGap))
H.check("health below strip and portrait gap", y(f.health), -(titleH + titleGap + f.portraitStrip + sideGap))
H.check("strip: health keeps its height", f.healthHeight, healthH)

-- Power off: no gap for it, health takes the row.
C.Set("player", "portraitMode", "OFF")
C.Set("player", "powerEnabled", false)
H.check("power off: only the title gap", ns.Single.Gaps("player"), titleGap)
H.check("power off: health to the bottom", f.healthHeight, h - titleH)
H.check("power off: no power box", f.boxes.power.ring:IsShown(), false)
C.Set("player", "powerEnabled", true)
-- A unit without power (Elements/Power.lua): health takes the row and its gap.
f.powerEmpty = true
ns.Single.LayoutBars(f)
H.check("unit without power: health takes row and gap", f.healthHeight, healthH + powerH + powerGap)
H.check("unit without power: no power box", f.boxes.power.ring:IsShown(), false)
f.powerEmpty = nil
ns.Single.LayoutBars(f)

-- Docked castbar: its own gap and box below the frame.
C.Set("player", "castbarEnabled", true)
C.Set("player", "castbarDock", "BELOW")
C.Set("player", "spacingDocked", 3)
local dockGap = 3 + 2 * ring
H.check("docked gap", ns.Single.Gap("player", "docked"), dockGap)
H.check("castbar docked", ns.Castbar.Docked("player"), true)
H.check("castbar below the frame and the gap", y(f.castbar), -dockGap)
H.check("castbar: its own ring", f.castbar.border[1]:IsShown(), true)
H.check("docked depth: bar, ring and gap", ns.Castbar.DockedDepth("player"),
    ns.Castbar.Height("player") + ring + dockGap)

-- The overheal lane belongs to the health box.
C.Set("player", "healPrediction", true)
C.Set("player", "healOverflow", true)
H.check("lane: in the health box", select(4, f.boxes.health.ring:GetPoint(2)), f.overhealLane)
C.Set("player", "healOverflow", false)

-- The dispel ring goes round the health box, not across the gaps.
H.check("dispel ring round the health box", select(2, f.dispel.ring.edges[1]:GetPoint(1)), f.boxes.health.ring)

-- The box border: own size, colour, radius; the gaps make room for it.
C.Set("player", "boxBorderSize", 3)
C.Set("player", "boxBorderColor", { 1, 0, 0, 1 })
C.Set("player", "boxCornerRadius", 4)
H.check("thick border: wider gap", ns.Single.Gap("player", "power"), 4 + 2 * 3)
local edge = f.boxes.health.ring.border[1]
H.check("box border size", edge:GetHeight(), 3)
H.check("box border colour", edge._color and edge._color[1], 1)
H.check("box radius kept under the border", ns.Boxes.Radius("player"), 4)
C.Set("player", "boxCornerRadius", 12)
H.check("box radius clamped so the border covers the corners", ns.Boxes.Radius("player"),
    math.floor(3 / (math.sqrt(2) - 1)))
-- Off: no ring, the gaps keep only the player's spacing.
C.Set("player", "boxBorderShow", false)
H.check("border off: no ring", f.boxes.health.ring.border[1]:IsShown(), false)
H.check("border off: plain gap", ns.Single.Gap("player", "power"), 4)
C.Set("player", "boxBorderShow", true)
C.Set("player", "boxBorderSize", 1)
C.Set("player", "boxBorderColor", { 0, 0, 0, 1 })
C.Set("player", "boxCornerRadius", 0)

-- Back to all 0: everything as before.
for _, key in ipairs({ "spacingTitle", "spacingPower", "spacingPortrait", "spacingDocked" }) do C.Set("player", key, 0) end
C.Set("player", "castbarEnabled", false)
H.check("back: health right below the title", y(f.health), -titleH)
H.check("back: health height", f.healthHeight, healthH)
H.check("back: frame ring", f.frameRing.border[1]:IsShown(), true)
H.check("back: boxes hidden", f.boxes.title.ring:IsShown(), false)
H.check("back: frame height", f:GetHeight(), h)
H.check("back: dispel ring round the frame", select(2, f.dispel.ring.edges[1]:GetPoint(1)), f)
