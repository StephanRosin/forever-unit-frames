local _, ns = ...

-- Rounded corners. One mask texture per rounded box: a rounded rectangle
-- (Media/Rounded*.tga, tools/make_corners.py) drawn as a shader nine-slice
-- (SetTextureSliceMargins, SimpleTextureBaseAPI, which mask textures share
-- with textures). The corner cells keep their shape at any box size; only
-- edges and middle stretch. The mask's scale sets the radius on screen: a
-- corner cell is SLICE units of the mask, SLICE * scale units of the box.
--
-- The client allows three masks per texture and raises beyond that, so a
-- texture here carries one mask at most and leaves room for Blizzard's.
-- A frame whose docked castbar joins it swaps its mask's file (all round,
-- top round, bottom round) instead of stacking a second set of masks;
-- swapping a file is safe in combat, re-anchoring is not needed.
local Corners = {}
ns.Corners = Corners

local Config, Pixel = ns.Config, ns.Pixel

local MEDIA = "Interface\\AddOns\\ForeverUnitFrames\\Media\\"
-- Border ring corner piece (a texture, mirrored per corner with texture
-- coordinates) and its inner cut, a mask file per corner in
-- Corners.POINTS order: masks ignore texture coordinates in the client.
Corners.TEXTURE = MEDIA .. "Corner.tga"
Corners.INVERSE = {
    MEDIA .. "CornerInverseTopLeft.tga", MEDIA .. "CornerInverseTopRight.tga",
    MEDIA .. "CornerInverseBottomLeft.tga", MEDIA .. "CornerInverseBottomRight.tga",
}
-- Rounded-rectangle masks by which corners are round.
Corners.MASKS = {
    ALL = MEDIA .. "Rounded.tga",
    TOP = MEDIA .. "RoundedTop.tga",
    BOTTOM = MEDIA .. "RoundedBottom.tga",
}
-- Corner radius of the Rounded masks in texels = their nine-slice margin
-- (tools/make_corners.py SLICE).
Corners.SLICE = 28
Corners.POINTS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
-- left, right, top, bottom: mirrored copies of the top-left shape.
Corners.COORDS = { { 0, 1, 0, 1 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 1, 0, 1, 0 } }

-- Corner radius of scope on the pixel grid; 0 means square.
function Corners.Radius(scope)
    local r = Config.Get(scope, "cornerRadius")
    if r <= 0 then return 0 end
    return Pixel.Snap(r, nil, 1)
end

-- radius, but never more than half the shorter side of a w x h box (whole
-- pixels): a larger one would overlap the corners and turn the ring's
-- edges inside out.
function Corners.Clamp(radius, w, h)
    local one = Pixel.One()
    local limit = math.floor(math.min(w, h) / 2 / one + 1e-6) * one
    return math.min(radius, limit)
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
    return { mask = owner:CreateMaskTexture(), targets = owner.cornerTargets or {} }
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
    if clip.shape == shape then return end
    clip.shape = shape
    local mask, slice = clip.mask, Corners.SLICE
    mask:SetTexture(Corners.MASKS[shape], "CLAMP", "CLAMP")
    mask:SetTextureSliceMargins(slice, slice, slice, slice)
    mask:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
end

-- Rounds the corners of box by radius (0: square, mask off); shape as
-- Corners.SetShape (default all four).
function Corners.Fit(clip, box, radius, shape)
    local on = radius > 0
    local mask = clip.mask
    mask:ClearAllPoints()
    mask:SetAllPoints(box)
    if on then mask:SetScale(radius / Corners.SLICE) end
    clip.shape = nil
    Corners.SetShape(clip, shape or "ALL")
    mask:SetShown(on)
    for _, target in ipairs(clip.targets) do
        local texture = resolve(target)
        if texture then Corners.SetMasked(texture, mask, on) end
    end
end
