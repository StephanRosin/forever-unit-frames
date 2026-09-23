local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

H.check("toggle code", S.Get("absorbEnabled").code, "AB")
H.check("toggle per frame", S.Get("absorbEnabled").scope, "frame")
H.check("colour code", S.Get("absorbColor").code, "AC")
H.check("colour inherited", S.Get("absorbColor").scope, "inherit")

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
local f = ns.Frames.player
local bar = f.absorb

-- A bar over the health bar, filling from the right.
-- Docked where the health fill ends, after the incoming heals, like them
-- as wide as the health bar and cut at its end by a clipping frame.
local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end
H.check("inside its clip", bar:GetParent(), f.absorbClip)
H.check("clip on the health bar", f.absorbClip:GetParent(), f.health)
H.checkTrue("clip cuts", f.absorbClip._clips)
H.check("starts after the incoming heals", point(bar, "TOPLEFT")[2], f.healAll:GetStatusBarTexture())
H.check("at their end", point(bar, "TOPLEFT")[3], "TOPRIGHT")
H.check("as wide as the health bar", bar:GetWidth(), f.healthWidth)
H.check("fills from the left", bar._reverse, false)
H.checkTrue("above the health bar", bar:GetFrameLevel() > f.health:GetFrameLevel())
H.checkTrue("shown by default", bar:IsShown())
-- The shield darkens what lies under it (any class colour) and carries
-- Blizzard's shield stripes, which also show on the empty background.
-- Over the health fill it multiplies (darker on any class colour); a lift
-- added on top lights the black background where health is missing.
H.check("fill is a flat shade", bar._texture, ns.Absorb.SHADE_TEXTURE)
H.check("shade multiplies", bar:GetStatusBarTexture()._blend, "MOD")
H.check("shade grey", bar._color[1], ns.Absorb.SHADE)
H.checkTrue("shade darkens", ns.Absorb.SHADE < 1)
local lift = bar.lift
H.check("lift adds", lift._blend, "ADD")
H.check("lift on the filled part", lift._allPoints, bar:GetStatusBarTexture())
H.checkTrue("lift is dim", lift._color[1] + lift._color[2] + lift._color[3] < 1)
local stripes = bar.stripes
H.check("stripes texture", stripes._texture, ns.Absorb.STRIPES)
H.checkTrue("stripes tile across", stripes._horizTile and stripes._vertTile)
H.check("stripes cover the filled part", stripes._allPoints, bar:GetStatusBarTexture())
H.check("stripes colour", stripes._color[4], 0.65)

-- Title and health texts stay on top of it; power texts stay on their bar.
H.check("health text on the overlay", f.texts.healthLeft:GetParent(), f.overlay)
H.check("title text on the overlay", f.texts.title:GetParent(), f.overlay)
H.checkTrue("overlay above the shield", f.overlay:GetFrameLevel() > bar:GetFrameLevel())
H.check("overlay covers the frame", f.overlay._allPoints, f)
H.check("power text on its bar", f.texts.powerRight:GetParent(), f.power)
H.checkTrue("badge still above the overlay", f.classBadge:GetFrameLevel() > f.overlay:GetFrameLevel())
-- Aura icons over the health row draw above texts and shield, below the
-- badge.
local auraLevel = f:GetFrameLevel() + ns.Auras.LEVELS
H.checkTrue("auras above the overlay", auraLevel > f.overlay:GetFrameLevel())
H.checkTrue("auras above the shield", auraLevel > bar:GetFrameLevel())
H.checkTrue("auras below the badge", auraLevel < f.classBadge:GetFrameLevel())

-- Secret values pass straight through.
local shield, hpMax = M.Secret(300), M.Secret(1000)
M.units.player = { name = "Me", health = M.Secret(900), healthMax = hpMax, absorbs = shield }
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("value is the secret", bar:GetValue(), shield)
H.check("max is the secret", select(2, bar:GetMinMaxValues()), hpMax)
M.units.player.absorbs = nil
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("no shield: empty", bar:GetValue(), 0)
M.units.player.absorbs = 50
M.units.player.healthMax = 200
M.FireEvent("UNIT_MAXHEALTH", "player")
H.check("max health change rescales", select(2, bar:GetMinMaxValues()), 200)

-- Colour from General, overridable per frame.
C.Set("general", "absorbColor", { 1, 1, 1, 0.5 })
H.check("general colour", stripes._color[4], 0.5)
C.Set("player", "absorbColor", { 0, 0, 1, 0.8 })
H.check("own colour", stripes._color[3], 1)
H.check("the shade stays grey", bar._color[3], ns.Absorb.SHADE)

-- Off: hidden and left alone.
C.Set("player", "absorbEnabled", false)
H.check("off: hidden", f.absorbClip:IsShown(), false)
M.units.player.absorbs = 99
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("off: not updated", bar:GetValue(), 50)
C.Set("player", "absorbEnabled", true)

-- Rounded with the frame.
C.Set("general", "cornerRadius", 4)
H.check("shield rounded", bar:GetStatusBarTexture():GetNumMaskTextures(), 4)
H.check("stripes rounded", stripes:GetNumMaskTextures(), 4)
H.check("lift rounded", lift:GetNumMaskTextures(), 4)
C.Set("general", "cornerRadius", 0)
H.check("square again", bar:GetStatusBarTexture():GetNumMaskTextures(), 0)

-- Test mode: a sample shield, real events ignored until it ends.
ns.TestMode.Set(true)
H.check("sample shield", bar:GetValue(), ns.Absorb.SAMPLE)
H.check("sample scale", select(2, bar:GetMinMaxValues()), 1)
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("sample kept", bar:GetValue(), ns.Absorb.SAMPLE)
H.check("target shows a sample too", ns.Frames.target.absorb:GetValue(), ns.Absorb.SAMPLE)
H.check("pretend party too", ns.Party.fakes[1].absorb:GetValue(), ns.Absorb.SAMPLE)
H.checkTrue("sample cast still shown", ns.Frames.target.castbar.preview)
ns.TestMode.Set(false)
H.check("real value back", bar:GetValue(), 99)
H.check("preview flag cleared", bar.preview, nil)
H.check("party sample dropped", ns.Party.fakes[1].absorb.preview, nil)

-- Without incoming heals shown, the shield starts right at the health.
ns.TestMode.Set(false)
C.Set("player", "healPrediction", false)
local p = { bar:GetPoint(1) }
local start
for i = 1, #bar._points do local q = { bar:GetPoint(i) } if q[1] == "TOPLEFT" then start = q end end
H.check("no heals: after the health fill", start[2], f.health:GetStatusBarTexture())
C.Set("player", "healPrediction", true)
