-- The shield watch's place (0.25.1): free with its own mover (the default,
-- as before), or hanging from the player frame by a point of its own at a
-- point of the frame, with its own offset. On the frame the mover is
-- inactive and the block follows the frame.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C, L, SW = ns.Settings, ns.Config, ns.L, ns.ShieldWatch

-- Settings: permanent codes, player only.
local EXPECTED = {
    shieldsAnchor = { "KD", "enum", "FREE" }, shieldsFramePoint = { "KE", "enum", "TOPLEFT" },
    shieldsPoint = { "KF", "enum", "BOTTOMLEFT" }, shieldsFrameX = { "KG", "int", 0 },
    shieldsFrameY = { "KH", "int", 4 },
}
for key, want in pairs(EXPECTED) do
    local def = S.Get(key)
    H.checkTrue(key .. " defined", def)
    H.check(key .. " code", def and def.code, want[1])
    H.check(key .. " type", def and def.type, want[2])
    H.check(key .. " default", def and S.Default(def, "player"), want[3])
    H.check(key .. " on the player", def and S.AppliesTo(def, "player"), true)
    H.check(key .. " not on the target", def and S.AppliesTo(def, "target"), false)
end
H.check("anchor values", table.concat(S.Get("shieldsAnchor").values, ","), "FREE,FRAME")
H.check("icon size: wider range", S.Get("shieldsSize").min .. "-" .. S.Get("shieldsSize").max, "8-96")
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    for key in pairs(EXPECTED) do
        H.check(code .. " " .. key, type(rawget(ns.Locales[code], "SETTING_" .. key)), "string")
    end
    for _, v in ipairs({ "FREE", "FRAME" }) do
        H.check(code .. " value " .. v, type(rawget(ns.Locales[code], "ENUM_shieldsAnchor_" .. v)), "string")
    end
end

-- Free (default): on its mover, as before.
local f = ns.Frames.player
local sw = f.shields
C.Set("player", "shieldsEnabled", true)
M.RunTimers()
H.check("free: the mover is active", SW.MoverSpec(f).active(), true)
H.check("free: on its mover", sw.holder._allPoints, sw.holder.mover)

-- On the frame: its point at the frame's point, the frame offset.
C.Set("player", "shieldsAnchor", "FRAME")
M.RunTimers()
H.check("frame: the mover is inactive", SW.MoverSpec(f).active(), false)
local p, rel, rp, x, y = sw.holder:GetPoint(1)
H.check("frame: hangs from the player frame", rel, f)
H.check("frame: its points", p .. " " .. rp, "BOTTOMLEFT TOPLEFT")
H.check("frame: the offset", x .. " " .. y, "0 4")
H.check("frame: one anchor", #sw.holder._points, 1)
H.check("frame: not on the mover", sw.holder._allPoints, nil)
local w, h = SW.Size("player")
H.check("frame: its size", sw.holder:GetWidth() .. "x" .. sw.holder:GetHeight(), w .. "x" .. h)
H.check("frame: a child of the frame (moves and scales with it)", sw.holder:GetParent(), f)
C.Set("player", "shieldsFramePoint", "BOTTOMRIGHT")
C.Set("player", "shieldsPoint", "TOPRIGHT")
C.Set("player", "shieldsFrameX", -5)
C.Set("player", "shieldsFrameY", -2)
M.RunTimers()
p, rel, rp, x, y = sw.holder:GetPoint(1)
H.check("frame: points follow", p .. " " .. rp, "TOPRIGHT BOTTOMRIGHT")
H.check("frame: offset follows", x .. " " .. y, "-5 -2")
H.check("frame: free position kept", C.Get("player", "shieldsX") .. " " .. C.Get("player", "shieldsY"), "-300 -140")

-- In combat: nothing moves until combat ends.
M.combat = true
C.Set("player", "shieldsFrameX", 7)
M.RunTimers()
H.check("combat: waits", select(4, sw.holder:GetPoint(1)), -5)
M.SetCombat(false)
M.RunTimers()
H.check("after combat: placed", select(4, sw.holder:GetPoint(1)), 7)
H.check("nothing blocked", #M.blocked, 0)

-- On the frame, size and offset sit on the frame's pixel grid (its
-- effective scale; here a frame drawn at 0.4: one pixel is 2.5 units).
local effectiveScale = f.GetEffectiveScale
f.GetEffectiveScale = function() return 0.4 end
C.Set("player", "shieldsFrameY", 3)
M.RunTimers()
H.check("frame scale: offset on its grid", select(4, sw.holder:GetPoint(1)) .. " " .. select(5, sw.holder:GetPoint(1)),
    "7.5 2.5")
local sw2 = sw.holder:GetWidth() / 2.5
H.check("frame scale: width whole pixels", sw2, math.floor(sw2))
f.GetEffectiveScale = effectiveScale

-- Free again: back on the mover.
C.Set("player", "shieldsAnchor", "FREE")
M.RunTimers()
H.check("free again: on its mover", sw.holder._allPoints, sw.holder.mover)
H.check("free again: mover active", SW.MoverSpec(f).active(), true)

-- The options grey the rows of the other mode.
local function active(key)
    local test = ns.Options.ROW_ACTIVE[key]
    return test == nil or test("player") == true
end
H.check("free: X/Y active", active("shieldsX") and active("shieldsY"), true)
H.check("free: frame rows grey", active("shieldsFramePoint") or active("shieldsPoint") or active("shieldsFrameX")
    or active("shieldsFrameY"), false)
C.Set("player", "shieldsAnchor", "FRAME")
H.check("frame: X/Y grey", active("shieldsX") or active("shieldsY"), false)
H.check("frame: frame rows active", active("shieldsFramePoint") and active("shieldsPoint") and active("shieldsFrameX")
    and active("shieldsFrameY"), true)
C.Set("player", "shieldsEnabled", false)
H.check("watch off: all grey", active("shieldsAnchor") or active("shieldsFramePoint"), false)
H.check("errors", #M.errors, 0)
