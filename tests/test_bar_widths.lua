local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

-- Health and power bars narrower than their row, placed left, centre or
-- right (Units/Single.lua barSpan).
for key, code in pairs({ healthBarWidth = "HW", powerBarWidth = "PI", barAlign = "BJ" }) do
    H.check(key .. " code", S.Get(key).code, code)
    H.check(key .. " per frame", S.Get(key).scope, "frame")
end
H.check("health full width by default", S.Default(S.Get("healthBarWidth"), "party"), 100)
H.check("power full width by default", S.Default(S.Get("powerBarWidth"), "party"), 100)
H.check("left by default", S.Default(S.Get("barAlign"), "player"), "LEFT")

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
local f = ns.Frames.player
C.Set("player", "portraitMode", "OFF")
local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end
-- Left and right insets of a bar's two anchors.
local function insets(bar, leftPoint, rightPoint)
    -- + 0: -0 reads "-0".
    return (point(bar, leftPoint)[4] + 0) .. "," .. (point(bar, rightPoint)[4] + 0)
end
local function health() return insets(f.health, "TOPLEFT", "TOPRIGHT") end
local function power() return insets(f.power, "BOTTOMLEFT", "BOTTOMRIGHT") end

-- 100 %: the whole row, as before.
H.check("full: health", health(), "0,0")
H.check("full: power", power(), "0,0")
H.check("full: health width", f.healthWidth, 220)
H.check("full: power width", f.powerWidth, 220)

-- 60 % of 220 = 132, the rest (88) right of it, left of it or split.
C.Set("player", "healthBarWidth", 60)
H.check("60 left: health", health(), "0,-88")
H.check("60 left: health width", f.healthWidth, 132)
H.check("60 left: power untouched", power(), "0,0")
H.check("60 left: title row untouched", point(f.title, "TOPRIGHT")[4], 0)
C.Set("player", "barAlign", "CENTER")
H.check("60 centre: health", health(), "44,-44")
C.Set("player", "barAlign", "RIGHT")
H.check("60 right: health", health(), "88,0")
H.check("60 right: health width", f.healthWidth, 132)

-- The power bar on its own share, same alignment.
C.Set("player", "powerBarWidth", 50)
H.check("50 right: power", power(), "110,0")
H.check("50 right: power width", f.powerWidth, 110)

-- With a portrait: the share is of the room beside it.
C.Set("player", "portraitMode", "LEFT")
local room = 220 - f.layoutHeight
local w = ns.Pixel.Snap(room * 0.6)
H.check("portrait: health width", f.healthWidth, w)
H.check("portrait: health right of the portrait", point(f.health, "TOPLEFT")[4], f.layoutHeight + room - w)
C.Set("player", "portraitMode", "OFF")

-- The overheal lane takes the end of the narrow bar; a matching power bar
-- gives up the same lane from its own end.
C.Set("player", "barAlign", "LEFT")
C.Set("player", "healOverflow", true)
local lane = f.overhealLane
H.check("lane from the narrow bar", lane, ns.Pixel.Snap(ns.Layout.OverhealLane(132)))
H.check("lane: health", health(), "0," .. -(88 + lane))
H.check("lane: health width", f.healthWidth, 132 - lane)
C.Set("player", "powerMatchesHealth", true)
H.check("lane: power matches", power(), "0," .. -(110 + lane))
H.check("lane: power width", f.powerWidth, 110 - lane)
