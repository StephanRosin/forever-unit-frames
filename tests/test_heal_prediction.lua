local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

for key, code in pairs({ healPrediction = "IH", healOverflow = "OV", healMyColor = "MC", healOtherColor = "OC" }) do
    H.check(key .. " code", S.Get(key).code, code)
end
H.check("toggle per frame", S.Get("healPrediction").scope, "frame")
H.check("colours inherited", S.Get("healMyColor").scope, "inherit")
H.check("lane off by default", S.Default(S.Get("healOverflow"), "player"), false)
H.check("lane width", ns.Layout.OverhealLane(220), 18)
H.check("lane at least 4", ns.Layout.OverhealLane(30), 4)

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
local f = ns.Frames.player
local clip, all, mine = f.healClip, f.healAll, f.healMine
local fill = f.health:GetStatusBarTexture()
local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

-- Two bars in a clipping frame over the health bar.
H.checkTrue("clips", clip._clips)
H.check("clip on the health bar", clip:GetParent(), f.health)
H.check("clip ends with the bar", point(clip, "BOTTOMRIGHT")[4], 0)
H.check("all heals in the clip", all:GetParent(), clip)
H.check("yours in the clip", mine:GetParent(), clip)
H.checkTrue("yours above", mine:GetFrameLevel() > all:GetFrameLevel())
H.checkTrue("below the shield", clip:GetFrameLevel() < f.absorb:GetFrameLevel())
H.checkTrue("yours below the shield too", mine:GetFrameLevel() < f.absorb:GetFrameLevel())
H.checkTrue("texts above the heals", f.overlay:GetFrameLevel() > mine:GetFrameLevel())
for name, bar in pairs({ all = all, mine = mine }) do
    H.check(name .. ": starts at the health fill", point(bar, "TOPLEFT")[2], fill)
    H.check(name .. ": at its right edge", point(bar, "TOPLEFT")[3], "TOPRIGHT")
    H.check(name .. ": bottom too", point(bar, "BOTTOMLEFT")[3], "BOTTOMRIGHT")
    H.check(name .. ": as wide as the health bar", bar:GetWidth(), 220)
end
H.check("your colour", mine._color[2], 0.95)
H.check("others' colour", all._color[2], 0.65)
H.check("no lane", f.overhealBg:IsShown(), false)

-- Secret values pass straight through.
local hpMax, allV, mineV = M.Secret(1000), M.Secret(200), M.Secret(120)
M.units.player = { name = "Me", health = M.Secret(500), healthMax = hpMax, healsAll = allV, healsMine = mineV }
M.FireEvent("UNIT_HEAL_PREDICTION", "player")
H.check("all heals: the secret", all:GetValue(), allV)
H.check("yours: the secret", mine:GetValue(), mineV)
H.check("scale: maximum health", select(2, mine:GetMinMaxValues()), hpMax)
H.check("others' scale too", select(2, all:GetMinMaxValues()), hpMax)
M.units.player.healsAll, M.units.player.healsMine = nil, nil
M.FireEvent("UNIT_HEAL_PREDICTION", "player")
H.check("nothing known: empty", all:GetValue(), 0)
H.check("nothing known: yours empty", mine:GetValue(), 0)

-- Colours from General, per frame override.
C.Set("general", "healMyColor", { 1, 1, 0, 1 })
H.check("general colour", mine._color[1], 1)
C.Set("player", "healOtherColor", { 0, 0, 1, 1 })
H.check("own colour", all._color[3], 1)

-- Overheal lane: the health bar gives up the end of its row.
C.Set("player", "healOverflow", true)
local lane = f.overhealLane
H.check("lane width", lane, 18)
H.check("health bar shorter", point(f.health, "TOPRIGHT")[4], -18)
H.check("power bar keeps the width", point(f.power, "BOTTOMRIGHT")[4], 0)
H.check("title row keeps the width", point(f.title, "TOPRIGHT")[4], 0)
H.check("clip reaches into the lane", point(clip, "BOTTOMRIGHT")[4], 18)
H.check("bars on the health scale", mine:GetWidth(), 220 - 18)
H.checkTrue("lane background", f.overhealBg:IsShown())
H.check("lane right of the bar", point(f.overhealBg, "TOPLEFT")[3], "TOPRIGHT")
H.check("lane in the background colour", f.overhealBg._color[4], C.Get("player", "backgroundColor")[4])

-- A portrait on the right: the lane sits left of it.
C.Set("player", "portraitMode", "RIGHT")
H.check("portrait: lane from the bars' width", f.overhealLane, ns.Layout.OverhealLane(220 - 46))
H.check("portrait: bars on the health scale", mine:GetWidth(), 220 - 46 - f.overhealLane)
H.check("portrait: health bar", point(f.health, "TOPRIGHT")[4], -(46 + f.overhealLane))
C.Set("player", "portraitMode", "OFF")

-- Off: no bars, no lane.
C.Set("player", "healPrediction", false)
H.check("off: hidden", clip:IsShown(), false)
H.check("off: no lane", f.overhealLane, 0)
H.check("off: lane hidden", f.overhealBg:IsShown(), false)
H.check("off: full bar", point(f.health, "TOPRIGHT")[4], 0)
M.units.player.healsAll = 5
M.FireEvent("UNIT_HEAL_PREDICTION", "player")
H.check("off: not updated", all:GetValue(), 0)
C.Set("player", "healPrediction", true)

-- Rounded with the frame.
C.Set("general", "cornerRadius", 4)
H.check("heals rounded", mine:GetStatusBarTexture():GetNumMaskTextures(), 4)
H.check("others' heals rounded", all:GetStatusBarTexture():GetNumMaskTextures(), 4)
H.check("lane rounded", f.overhealBg:GetNumMaskTextures(), 4)
C.Set("general", "cornerRadius", 0)

-- Test mode: sample heals.
ns.TestMode.Set(true)
H.check("sample: all", all:GetValue(), ns.HealPrediction.SAMPLE_ALL)
H.check("sample: yours", mine:GetValue(), ns.HealPrediction.SAMPLE_MINE)
H.check("sample scale", select(2, all:GetMinMaxValues()), 1)
M.FireEvent("UNIT_HEAL_PREDICTION", "player")
H.check("sample kept", all:GetValue(), ns.HealPrediction.SAMPLE_ALL)
H.check("party sample", ns.Party.fakes[2].healMine:GetValue(), ns.HealPrediction.SAMPLE_MINE)
H.check("shield sample alongside", f.absorb:GetValue(), ns.Absorb.SAMPLE)
ns.TestMode.Set(false)
H.check("real value back", all:GetValue(), 5)
H.check("preview flag cleared", clip.preview, nil)

-- Party members get the bars as well.
ns.TestMode.Set(true)
local member = ns.Party.fakes[1]
H.check("party: bars as wide as the member's health bar", member.healAll:GetWidth(), 160)
ns.TestMode.Set(false)
