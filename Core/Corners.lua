local _, ns = ...

-- Rounded corners. One mask texture per rounded box: a rounded rectangle
-- (Media/RoundedNN*.tga, tools/make_corners.py) drawn as a shader
-- nine-slice (SetTextureSliceMargins, SimpleTextureBaseAPI, which mask
-- textures share with textures). The corner cells keep their shape at any
-- box size; only edges and middle stretch.
--
-- The client's rule for a sliced mask, measured in game: a corner cell is
-- drawn `margin` UI units of the box wide and high, whatever the file's
-- size, the box's size or the mask's own scale (SetScale on a mask is
-- ignored). So the radius picks the file: RoundedNN has arcs of NN texels
-- and is sliced with margins of NN, giving arcs of NN UI units, the same
-- units the border ring's corner pieces use, at every UI scale. Radii are
-- whole UI units (the setting is an integer) so a file exists for each.
--
-- The client allows three masks per texture and raises beyond that, so a
-- texture here carries one mask at most and leaves room for Blizzard's.
-- A frame whose docked castbar joins it swaps its mask's file (all round,
-- top round, bottom round) instead of stacking a second set of masks;
-- swapping a file is safe in combat, re-anchoring is not needed.
local Corners = {}
ns.Corners = Corners

local Config = ns.Config

local MEDIA = "Interface\\AddOns\\ForeverUnitFrames\\Media\\"
-- Border ring corner piece (a texture, mirrored per corner with texture
-- coordinates) and its inner cut, a mask file per corner in
-- Corners.POINTS order: masks ignore texture coordinates in the client.
Corners.TEXTURE = MEDIA .. "Corner.tga"
Corners.INVERSE = {
    MEDIA .. "CornerInverseTopLeft.tga", MEDIA .. "CornerInverseTopRight.tga",
    MEDIA .. "CornerInverseBottomLeft.tga", MEDIA .. "CornerInverseBottomRight.tga",
}
-- The largest radius with mask files (the cornerRadius setting's max,
-- tools/make_corners.py MAX_RADIUS).
Corners.MAX_RADIUS = 12
-- File name suffix by which corners are round.
local SHAPE_SUFFIX = { ALL = "", TOP = "Top", BOTTOM = "Bottom" }
Corners.POINTS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
-- left, right, top, bottom: mirrored copies of the top-left shape.
Corners.COORDS = { { 0, 1, 0, 1 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 1, 0, 1, 0 } }

-- The mask file for a whole radius (1..MAX_RADIUS) and a shape ("ALL",
-- "TOP" or "BOTTOM").
function Corners.MaskFile(radius, shape)
    return ("%sRounded%02d%s.tga"):format(MEDIA, radius, SHAPE_SUFFIX[shape])
end

-- Corner radius of scope in whole UI units; 0 means square.
function Corners.Radius(scope)
    local r = math.floor(Config.Get(scope, "cornerRadius"))
    return math.max(0, math.min(r, Corners.MAX_RADIUS))
end

-- radius, but never more than half the shorter side of a w x h box (whole
-- UI units): a larger one would overlap the corners and turn the ring's
-- edges inside out.
function Corners.Clamp(radius, w, h)
    return math.min(radius, math.floor(math.min(w, h) / 2 + 1e-6))
end

-- The inner-arc mask of corner i (1..4, Corners.POINTS order) on owner,
-- clamped so it lets everything beyond its square through.
function Corners.NewInnerMask(owner, i)
    local mask = owner:CreateMaskTexture()
    mask:SetTexture(Corners.INVERSE[i], "CLAMP", "CLAMP")
    return mask
end

-- A textures list for owner's rounded block. Elements add their textures
-- while building: a texture, or a function returning one (a status bar's
-- fill is asked for each time).
function Corners.Add(owner, target)
    owner.cornerTargets = owner.cornerTargets or {}
    table.insert(owner.cornerTargets, target)
end

-- The rounding of owner's box: one mask, made once, for the textures
-- Corners.Add listed.
function Corners.Clipper(owner)
    return { mask = owner:CreateMaskTexture(), targets = owner.cornerTargets or {}, radius = 0 }
end

local function resolve(target)
    if type(target) == "function" then return target() end
    return target
end

-- Puts mask on texture (on) or takes it off again; never twice.
function Corners.SetMasked(texture, mask, on)
    if on and texture.fufMask ~= mask then
        texture:AddMaskTexture(mask)
        texture.fufMask = mask
    elseif not on and texture.fufMask == mask then
        texture:RemoveMaskTexture(mask)
        texture.fufMask = nil
    end
end

-- Which corners of clip's box are round: "ALL", "TOP" or "BOTTOM". Only
-- changes the mask's file, so it is safe in combat.
function Corners.SetShape(clip, shape)
    if clip.shape == shape or clip.radius <= 0 then return end
    clip.shape = shape
    local mask, radius = clip.mask, clip.radius
    mask:SetTexture(Corners.MaskFile(radius, shape), "CLAMP", "CLAMP")
    mask:SetTextureSliceMargins(radius, radius, radius, radius)
    mask:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
end

-- Rounds the corners of box by radius (whole UI units; 0: square, mask
-- off); shape as Corners.SetShape (default all four).
function Corners.Fit(clip, box, radius, shape)
    local on = radius > 0
    local mask = clip.mask
    mask:ClearAllPoints()
    mask:SetAllPoints(box)
    clip.radius, clip.shape = radius, nil
    Corners.SetShape(clip, shape or "ALL")
    mask:SetShown(on)
    for _, target in ipairs(clip.targets) do
        local texture = resolve(target)
        if texture then Corners.SetMasked(texture, mask, on) end
    end
end
