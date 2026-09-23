local M = H.M
local ns = H.LoadAddon()

-- A 1440 px high screen at UI scale 0.9: one pixel is 768 / 1440 / 0.9
-- (about 0.593) UI units, so whole-unit settings are off the grid.
M.screenW, M.screenH = 2560, 1440
M.scale = 0.9
local px = 768 / 1440 / 0.9

local function onGrid(v)
    local n = v / px
    return math.abs(n - math.floor(n + 0.5)) < 1e-6
end
local function checkGrid(label, v)
    H.check(label .. " on the pixel grid", type(v) == "number" and onGrid(v), true)
end

H.check("snap 0", ns.Pixel.Snap(0), 0)
checkGrid("snap 10", ns.Pixel.Snap(10))
H.checkTrue("snap 10 is nearest", math.abs(ns.Pixel.Snap(10) - 10) <= px / 2)
H.check("snap keeps a minimum", ns.Pixel.Snap(0.1, nil, 1), px)
checkGrid("centre", ns.Pixel.Centre(7, ns.Pixel.Snap(35)) - ns.Pixel.Snap(35) / 2)

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
C.Set("player", "x", -251)
C.Set("player", "y", -163)
C.Set("player", "portraitMode", "LEFT")
C.Set("player", "castbarEnabled", true)

local function pointOf(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

-- Unit frame, its mover, bars, border, portrait, texts.
local f = ns.Frames.player
checkGrid("frame width", f:GetWidth())
checkGrid("frame height", f:GetHeight())
local mover = f.mover
H.check("mover as wide as the frame", mover:GetWidth(), f:GetWidth())
H.check("mover as high as the frame", mover:GetHeight(), f:GetHeight())
local p = pointOf(mover, "CENTER")
checkGrid("mover left edge", p[4] - mover:GetWidth() / 2)
checkGrid("mover bottom edge", p[5] - mover:GetHeight() / 2)
H.checkTrue("mover near its setting", math.abs(p[4] - -251) < px)
checkGrid("health height", f.health:GetHeight())
checkGrid("power height", f.power:GetHeight())
checkGrid("health left inset", pointOf(f.health, "TOPLEFT")[4])
H.check("health + gap + power fill the frame",
    math.abs(f.health:GetHeight() + f.gap + f.power:GetHeight() - f:GetHeight()) < 1e-6, true)
checkGrid("border", f.border[1]:GetHeight())
H.check("one-unit border is at least a pixel", f.border[1]:GetHeight() >= px, true)
checkGrid("border offset", pointOf(f.border[1], "BOTTOMLEFT")[4])
checkGrid("portrait", f.portraitBg:GetWidth())
H.check("portrait as wide as the inset", f.portraitBg:GetWidth(), pointOf(f.health, "TOPLEFT")[4])
H.check("portrait as high as the frame", f.portraitBg:GetHeight(), f:GetHeight())
checkGrid("text offset", pointOf(f.texts.healthLeft, "LEFT")[4])
checkGrid("text gap", pointOf(f.texts.healthLeft, "RIGHT")[4])
checkGrid("right text offset", pointOf(f.texts.healthRight, "RIGHT")[4])
checkGrid("soft copy offset", pointOf(f.texts.healthLeft.softCopies[1], "TOPLEFT")[4])
H.check("soft copy offset at least a pixel", pointOf(f.texts.healthLeft.softCopies[1], "TOPLEFT")[4] >= px, true)

-- Castbar: docked, then detached with its mover.
local bar = f.castbar
checkGrid("castbar height", bar:GetHeight())
checkGrid("castbar gap", pointOf(bar, "TOPLEFT")[5])
checkGrid("castbar icon inset", pointOf(bar, "TOPLEFT")[4])
checkGrid("castbar icon", bar.icon:GetWidth())
checkGrid("castbar name offset", pointOf(bar.text, "LEFT")[4])
checkGrid("castbar time offset", pointOf(bar.time, "RIGHT")[4])
C.Set("player", "castbarPosition", "DETACHED")
C.Set("player", "castbarX", 13)
C.Set("player", "castbarY", -201)
local cm = bar.mover
checkGrid("castbar mover width", cm:GetWidth())
checkGrid("castbar mover height", cm:GetHeight())
local cp = pointOf(cm, "CENTER")
checkGrid("castbar mover left edge", cp[4] - cm:GetWidth() / 2)
checkGrid("castbar mover bottom edge", cp[5] - cm:GetHeight() / 2)

-- Party block, header attributes and (test mode) buttons.
local P = ns.Party
C.Set("party", "x", 301)
C.Set("party", "y", 77)
local pm = P.header.mover
checkGrid("party mover width", pm:GetWidth())
checkGrid("party mover height", pm:GetHeight())
local pp = pointOf(pm, "CENTER")
checkGrid("party mover left edge", pp[4] - pm:GetWidth() / 2)
checkGrid("party mover top edge", pp[5] + pm:GetHeight() / 2)
checkGrid("header y offset", P.header:GetAttribute("yOffset"))
P.SetTest(true)
for i, button in ipairs(P.fakes) do
    if button:IsShown() then
        checkGrid("party button " .. i .. " width", button:GetWidth())
        checkGrid("party button " .. i .. " height", button:GetHeight())
        checkGrid("party button " .. i .. " y", pointOf(button, "TOPLEFT")[5])
    end
end
checkGrid("test block width", P.testBlock:GetWidth())
checkGrid("test block height", P.testBlock:GetHeight())
P.SetTest(false)

-- A new UI scale: everything is laid out on the new grid.
M.scale = 0.64
px = 768 / 1440 / 0.64
M.FireEvent("UI_SCALE_CHANGED")
checkGrid("rescaled frame width", f:GetWidth())
checkGrid("rescaled mover width", mover:GetWidth())
checkGrid("rescaled mover left edge", pointOf(mover, "CENTER")[4] - mover:GetWidth() / 2)
checkGrid("rescaled text offset", pointOf(f.texts.healthLeft, "LEFT")[4])
checkGrid("rescaled party mover", pm:GetWidth())
checkGrid("rescaled castbar mover", cm:GetWidth())
M.screenH = 1080
px = 768 / 1080 / 0.64
M.FireEvent("DISPLAY_SIZE_CHANGED")
checkGrid("resized screen: frame height", f:GetHeight())
checkGrid("resized screen: party mover", pm:GetHeight())

-- Frames without a mover (created before the movers exist) are placed
-- on the grid too.
do
    local ns2 = H.LoadAddon()
    M.screenW, M.screenH = 2560, 1440
    M.scale = 0.9
    px = 768 / 1440 / 0.9
    ns2.Config.Use({ target = { x = 99, y = -31 } })
    ns2.Single.CreateAll()
    local t = ns2.Frames.target
    local tp = pointOf(t, "CENTER")
    H.check("no mover: anchored to the screen", tp[2], UIParent)
    checkGrid("no mover: left edge", tp[4] - t:GetWidth() / 2)
    checkGrid("no mover: bottom edge", tp[5] - t:GetHeight() / 2)
end
