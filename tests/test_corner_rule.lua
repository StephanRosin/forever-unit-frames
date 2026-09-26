-- The fill's rounded corners and the border ring's arcs are concentric at
-- every radius and UI scale. The client draws a sliced mask's corner cell
-- `margin` UI units of the box (measured in game; the mask's scale and
-- the file's size do not change it), so a radius of r UI units needs the
-- file with r-texel arcs sliced with margins r (Core/Corners.lua). The
-- ring's corner pieces are measured in the same UI units: outer arc
-- r + padding + size, inner arc r + padding, around the same centre.
local M = H.M

local function boot(scale)
    local ns = H.LoadAddon()
    M.screenW, M.screenH, M.scale = 2560, 1440, scale
    M.units.player = { name = "Me", health = 1, healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    local C = ns.Config
    C.Set("general", "borderStyle", "GOLD")
    C.Set("general", "borderSize", 2)
    C.Set("general", "borderPadding", 1)
    C.Set("target", "castbarAlwaysShow", true)
    return ns
end

-- The arc a sliced mask draws, in UI units of its box, by the rule.
local function maskArc(ns, mask)
    local margin = mask._slice[1]
    for _, side in ipairs(mask._slice) do
        if side ~= margin then return nil end
    end
    -- The file's arcs must be as many texels as the margin.
    local file = mask._texture:match("Rounded(%d%d)")
    if tonumber(file) ~= margin then return nil end
    return margin
end

local function close(a, b) return math.abs(a - b) < 1e-9 end

for _, scale in ipairs({ 0.64, 0.9, 1, 1.15 }) do
    local ns = boot(scale)
    local C, B = ns.Config, ns.Border
    local f = ns.Frames.target
    local label = "scale " .. scale
    H.checkTrue(label .. ": castbar joins the block", f.blockRing:IsShown())
    local reach, padding = B.Extent("target"), B.Padding("target")
    for r = 1, ns.Settings.Get("cornerRadius").max do
        C.Set("general", "cornerRadius", r)
        local want = ns.Shape.Radius(f)
        local ring = f.blockRing.border
        local fill, castbar = maskArc(ns, f.clip.mask), maskArc(ns, f.castbar.clip.mask)
        local at = label .. ", radius " .. r
        H.check(at .. ": frame fill arc", fill, want)
        H.check(at .. ": castbar fill arc", castbar, want)
        H.checkTrue(at .. ": ring outer arc around the same centre",
            close(ring.corners[4]:GetWidth(), (fill or 0) + reach))
        H.checkTrue(at .. ": ring inner arc around the same centre",
            close(ring.inner[4]:GetWidth(), (fill or 0) + padding))
        H.check(at .. ": no mask scale", f.clip.mask._scale, nil)
    end
end
M.screenW, M.screenH, M.scale = nil, nil, 1
