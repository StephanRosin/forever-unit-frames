local _, ns = ...

-- Rounded corners. Four mask textures, one per corner, each as big as the
-- radius and sitting in its corner of a box. The mask file is the top-left
-- corner of a rounded rectangle (tools/make_corners.py); the other corners
-- mirror it with texture coordinates. CLAMP wrapping repeats the mask's
-- opaque right column and bottom row outwards, so each mask only cuts its
-- own corner and lets the rest of the box through. A texture under all
-- four masks is rounded at every corner of the box it lies in.
local Corners = {}
ns.Corners = Corners

local Config, Pixel = ns.Config, ns.Pixel

local MEDIA = "Interface\\AddOns\\ForeverUnitFrames\\Media\\"
Corners.TEXTURE = MEDIA .. "Corner.tga"
Corners.INVERSE = MEDIA .. "CornerInverse.tga"
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

-- Mask i (1..4, Corners.POINTS order) of file on owner.
function Corners.NewMask(owner, file, i)
    local mask = owner:CreateMaskTexture()
    mask:SetTexture(file, "CLAMP", "CLAMP")
    local c = Corners.COORDS[i]
    mask:SetTexCoord(c[1], c[2], c[3], c[4])
    return mask
end

-- A textures list for owner's rounded block. Elements add their textures
-- while building: a texture, or a function returning one (a status bar's
-- fill is asked for each time).
function Corners.Add(owner, target)
    owner.cornerTargets = owner.cornerTargets or {}
    table.insert(owner.cornerTargets, target)
end

-- The masks of owner (four, or count), made once, for the textures
-- Corners.Add listed. clip.corners (optional) names the corner each mask
-- takes (Corners.POINTS index); by default mask i takes corner i.
function Corners.Clipper(owner, count)
    local clip = { masks = {}, targets = owner.cornerTargets or {} }
    for i = 1, count or 4 do clip.masks[i] = Corners.NewMask(owner, Corners.TEXTURE, i) end
    return clip
end

local function resolve(target)
    if type(target) == "function" then return target() end
    return target
end

-- Puts a set of masks on texture (on) or takes it off again. A set goes
-- on once; the texture remembers each set by its first mask, so several
-- sets (a frame's corners, a docked castbar's) can share one texture.
function Corners.SetMasked(texture, masks, on)
    texture.fufMasked = texture.fufMasked or {}
    local key = masks[1]
    if on and not texture.fufMasked[key] then
        for _, mask in ipairs(masks) do texture:AddMaskTexture(mask) end
        texture.fufMasked[key] = true
    elseif not on and texture.fufMasked[key] then
        for _, mask in ipairs(masks) do texture:RemoveMaskTexture(mask) end
        texture.fufMasked[key] = nil
    end
end

-- Rounds the corners of box by radius (0: square, masks removed).
function Corners.Fit(clip, box, radius)
    local on = radius > 0
    for i, mask in ipairs(clip.masks) do
        local corner = clip.corners and clip.corners[i] or i
        local c = Corners.COORDS[corner]
        mask:SetTexCoord(c[1], c[2], c[3], c[4])
        mask:ClearAllPoints()
        mask:SetPoint(Corners.POINTS[corner], box, Corners.POINTS[corner], 0, 0)
        mask:SetSize(radius, radius)
        mask:SetShown(on)
    end
    for _, target in ipairs(clip.targets) do
        local texture = resolve(target)
        if texture then Corners.SetMasked(texture, clip.masks, on) end
    end
end
