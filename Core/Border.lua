local _, ns = ...

-- The outer border: a ring around a box, `borderPadding` away from it and
-- `borderSize` thick. A unit frame's box takes in a docked castbar while
-- it shows (Elements/Shape.lua), so frame, portrait and castbar sit in one
-- border. Eight pieces: four edges and four corner squares. With rounded
-- corners each corner square shows the outer arc as its texture
-- (Corner.tga) and is masked once, by the inner arc (CornerInverse*.tga);
-- both are centred where the box's own rounded corner is centred, so ring
-- and box stay concentric. One mask per texture: the client allows three.
-- The pieces are white; paint colours them with vertex colours.
--
-- Styles: FLAT is one colour (`borderColor`). GOLD is shaded like a bevel,
-- lighter at the top and left, darker at the bottom and right, with a dark
-- one-pixel line along the inside (a second, thin ring).
--
-- The drop shadow is a soft band around the ring (or the box, without a
-- ring); nothing is drawn under the box, so translucent bars stay as they
-- are. Its corner pieces reach in to the ring's rounded centre and come
-- from Media/Shadow.tga (tools/make_shadow.py): one cell per ratio of
-- radius to shadow size, so the fade always starts at the ring.
local Border = {}
ns.Border = Border

local Config, Pixel = ns.Config, ns.Pixel

Border.SHADOW = "Interface\\AddOns\\ForeverUnitFrames\\Media\\Shadow.tga"
local SHADOW_WIDTH, CELL, CELLS = 512, 32, 16
-- Texture coordinates: half a texel inside a cell, so no neighbour bleeds.
local HALF_U, HALF_V = 0.5 / SHADOW_WIDTH, 0.5 / CELL
-- Cell 0's last column and bottom row: the plain fade the edges use.
local EDGE_U, EDGE_V = (CELL - 0.5) / SHADOW_WIDTH, (CELL - 0.5) / CELL

-- Gold shades. LIGHT and MID are Blizzard's own gold gradient (the
-- animated dispel border, Blizzard_PrivateAurasUI.lua); SHADE, DARK and
-- LINE are the same hue, darker.
Border.GOLD = {
    LIGHT = { 1, 1, 0.557, 1 },
    MID = { 1, 0.792, 0.188, 1 },
    SHADE = { 0.78, 0.59, 0.13, 1 },
    DARK = { 0.55, 0.38, 0.07, 1 },
    LINE = { 0.2, 0.12, 0.02, 1 },
}

-- Outward direction of each corner (Corners.POINTS order).
local OUT = { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }
-- The corner opposite each corner (Corners.POINTS order).
local INNER = { "BOTTOMRIGHT", "BOTTOMLEFT", "TOPRIGHT", "TOPLEFT" }

-- Thickness on the pixel grid: at least one pixel unless the border is
-- off (size 0 or hidden).
function Border.Size(scope)
    local size = Config.Get(scope, "borderSize")
    if size <= 0 or not Config.Get(scope, "borderShow") then return 0 end
    return Pixel.Snap(size, nil, 1)
end

function Border.Padding(scope)
    local padding = Config.Get(scope, "borderPadding")
    if padding <= 0 then return 0 end
    return Pixel.Snap(padding, nil, 1)
end

-- How far the border reaches out from its box; 0 without a border.
function Border.Extent(scope)
    local size = Border.Size(scope)
    if size == 0 then return 0 end
    return Border.Padding(scope) + size
end

-- Shadow width on the pixel grid; 0 while the shadow is off.
function Border.ShadowSize(scope)
    if not Config.Get(scope, "shadowEnabled") then return 0 end
    return Pixel.Snap(Config.Get(scope, "shadowSize"), nil, 1)
end

-- Ring ------------------------------------------------------------------------

local function newRing(owner, sublevel)
    local ring = { corners = {}, inner = {} }
    for i = 1, 4 do
        ring[i] = owner:CreateTexture(nil, "OVERLAY", nil, sublevel)
        ring[i]:SetColorTexture(1, 1, 1, 1)
    end
    for i = 1, 4 do
        ring.corners[i] = owner:CreateTexture(nil, "OVERLAY", nil, sublevel)
        ring.inner[i] = ns.Corners.NewInnerMask(owner, i)
    end
    return ring
end

-- Edges first, then corners: [1..4] top, bottom, left, right; corners in
-- Corners.POINTS order. Rings and the shadow share this layout.
local function ringPieces(ring)
    return { ring[1], ring[2], ring[3], ring[4], ring.corners[1], ring.corners[2], ring.corners[3], ring.corners[4] }
end

local function placeEdges(ring, box, size, padding, reach, corner)
    local inset = corner - reach
    ring[1]:ClearAllPoints()
    ring[1]:SetPoint("BOTTOMLEFT", box, "TOPLEFT", inset, padding)
    ring[1]:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -inset, padding)
    ring[1]:SetHeight(size)
    ring[2]:ClearAllPoints()
    ring[2]:SetPoint("TOPLEFT", box, "BOTTOMLEFT", inset, -padding)
    ring[2]:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", -inset, -padding)
    ring[2]:SetHeight(size)
    ring[3]:ClearAllPoints()
    ring[3]:SetPoint("TOPRIGHT", box, "TOPLEFT", -padding, -inset)
    ring[3]:SetPoint("BOTTOMRIGHT", box, "BOTTOMLEFT", -padding, inset)
    ring[3]:SetWidth(size)
    ring[4]:ClearAllPoints()
    ring[4]:SetPoint("TOPLEFT", box, "TOPRIGHT", padding, -inset)
    ring[4]:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", padding, inset)
    ring[4]:SetWidth(size)
end

-- A corner square: the outer arc (mirrored for corner i) when round,
-- else a plain white square.
local function cornerArt(piece, i, round)
    if not round then
        piece:SetColorTexture(1, 1, 1, 1)
        return
    end
    piece:SetTexture(ns.Corners.TEXTURE, "CLAMP", "CLAMP")
    local c = ns.Corners.COORDS[i]
    piece:SetTexCoord(c[1], c[2], c[3], c[4])
end

local function placeCorners(ring, box, size, reach, corner, round)
    for i, point in ipairs(ns.Corners.POINTS) do
        local piece, sx, sy = ring.corners[i], OUT[i][1], OUT[i][2]
        piece:ClearAllPoints()
        piece:SetPoint(point, box, point, sx * reach, sy * reach)
        piece:SetSize(corner, corner)
        cornerArt(piece, i, round)
        local inner = ring.inner[i]
        inner:ClearAllPoints()
        inner:SetPoint(point, piece, point, -sx * size, -sy * size)
        inner:SetSize(corner - size, corner - size)
        inner:SetShown(round)
        ns.Corners.SetMasked(piece, inner, round)
    end
end

-- A ring `size` thick, `padding` away from box, concentric with a box
-- rounded by radius.
local function placeRing(ring, box, size, padding, radius)
    local round = size > 0 and radius > 0
    local reach = padding + size
    -- Corner squares: as big as the ring's outer radius when round, else
    -- just the size x size corner of the ring.
    local corner = round and (radius + reach) or size
    placeEdges(ring, box, size, padding, reach, corner)
    placeCorners(ring, box, size, reach, corner, round)
    return corner
end

local function showRing(ring, shown)
    for _, piece in ipairs(ringPieces(ring)) do piece:SetShown(shown) end
    if shown then return end
    for i = 1, 4 do ring.inner[i]:Hide() end
end

-- One colour on the white pieces.
local function paintFlat(ring, c)
    for _, piece in ipairs(ringPieces(ring)) do piece:SetVertexColor(c[1], c[2], c[3], c[4]) end
end

local function color(c) return CreateColor(c[1], c[2], c[3], c[4]) end

local function mix(from, to, share)
    local c = {}
    for i = 1, 4 do c[i] = from[i] + (to[i] - from[i]) * share end
    return c
end

-- Lit from above: one vertical shading, continuous over the whole ring.
-- The top corners fade LIGHT to MID over their height, the sides MID to
-- SHADE, the bottom corners SHADE to DARK. An edge is only `share` of a
-- corner's height thick (size / corner square), so it takes that part of
-- its corner's fade and meets the corner without a step. Gradients are
-- minColor (bottom) first.
local function goldShades(share)
    local G = Border.GOLD
    local function vertical(bottom, top) return { color(bottom), color(top) } end
    local top = vertical(mix(G.LIGHT, G.MID, share), G.LIGHT)
    local bottom = vertical(G.DARK, mix(G.DARK, G.SHADE, share))
    local side = vertical(G.SHADE, G.MID)
    local topCorner, bottomCorner = vertical(G.MID, G.LIGHT), vertical(G.DARK, G.SHADE)
    return { top, bottom, side, side, topCorner, topCorner, bottomCorner, bottomCorner }
end

local function paintGold(ring, share)
    local shades = goldShades(share)
    for i, piece in ipairs(ringPieces(ring)) do piece:SetGradient("VERTICAL", shades[i][1], shades[i][2]) end
end

-- Shadow ----------------------------------------------------------------------

local function newShadow(owner)
    local shadow = { corners = {}, inner = {} }
    local function piece()
        local texture = owner:CreateTexture(nil, "BACKGROUND", nil, -8)
        texture:SetTexture(Border.SHADOW, "CLAMP", "CLAMP")
        return texture
    end
    for i = 1, 4 do shadow[i] = piece() end
    for i = 1, 4 do
        shadow.corners[i] = piece()
        shadow.inner[i] = ns.Corners.NewInnerMask(owner, i)
    end
    return shadow
end

-- Edges: a band `size` wide just outside the ring's straight part.
local function placeShadowEdges(shadow, box, reach, radius, size)
    local inset = radius - reach
    shadow[1]:ClearAllPoints()
    shadow[1]:SetPoint("BOTTOMLEFT", box, "TOPLEFT", inset, reach)
    shadow[1]:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -inset, reach)
    shadow[1]:SetHeight(size)
    shadow[1]:SetTexCoord(EDGE_U, EDGE_U, 0, 1)
    shadow[2]:ClearAllPoints()
    shadow[2]:SetPoint("TOPLEFT", box, "BOTTOMLEFT", inset, -reach)
    shadow[2]:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", -inset, -reach)
    shadow[2]:SetHeight(size)
    shadow[2]:SetTexCoord(EDGE_U, EDGE_U, 1, 0)
    shadow[3]:ClearAllPoints()
    shadow[3]:SetPoint("TOPRIGHT", box, "TOPLEFT", -reach, -inset)
    shadow[3]:SetPoint("BOTTOMRIGHT", box, "BOTTOMLEFT", -reach, inset)
    shadow[3]:SetWidth(size)
    shadow[3]:SetTexCoord(0, EDGE_U, EDGE_V, EDGE_V)
    shadow[4]:ClearAllPoints()
    shadow[4]:SetPoint("TOPLEFT", box, "TOPRIGHT", reach, -inset)
    shadow[4]:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", reach, inset)
    shadow[4]:SetWidth(size)
    shadow[4]:SetTexCoord(EDGE_U, 0, EDGE_V, EDGE_V)
end

-- Corners: from the shadow's outer corner in to the ring's rounded
-- centre; inside the ring's radius masked off (the inverse arc).
local function placeShadowCorners(shadow, box, reach, radius, size)
    local span = radius + size
    local cell = math.min(CELLS - 1, math.floor(radius / span * CELLS + 0.5))
    local left, right = (cell * CELL) / SHADOW_WIDTH + HALF_U, ((cell + 1) * CELL) / SHADOW_WIDTH - HALF_U
    local top, bottom = HALF_V, 1 - HALF_V
    -- Mirrored for each corner, as Corners.COORDS.
    local coords = { { left, right, top, bottom }, { right, left, top, bottom },
        { left, right, bottom, top }, { right, left, bottom, top } }
    local round = radius > 0
    for i, point in ipairs(ns.Corners.POINTS) do
        local piece, mask, out = shadow.corners[i], shadow.inner[i], reach + size
        piece:ClearAllPoints()
        piece:SetPoint(point, box, point, OUT[i][1] * out, OUT[i][2] * out)
        piece:SetSize(span, span)
        piece:SetTexCoord(coords[i][1], coords[i][2], coords[i][3], coords[i][4])
        mask:ClearAllPoints()
        mask:SetPoint(INNER[i], piece, INNER[i], 0, 0)
        mask:SetSize(radius, radius)
        mask:SetShown(round)
        ns.Corners.SetMasked(piece, mask, round)
    end
end

local function hideShadow(shadow)
    for _, piece in ipairs(ringPieces(shadow)) do piece:Hide() end
    for i = 1, 4 do shadow.inner[i]:Hide() end
end

local function drawShadow(owner, scope, box, radius)
    local shadow = owner.shadow
    local size = Border.ShadowSize(scope)
    if size == 0 then
        hideShadow(shadow)
        return
    end
    for _, piece in ipairs(ringPieces(shadow)) do piece:Show() end
    local reach = Border.Extent(scope)
    -- The ring's outer radius; square stays square, as the ring does.
    local outer = radius > 0 and radius + reach or 0
    placeShadowEdges(shadow, box, reach, outer, size)
    placeShadowCorners(shadow, box, reach, outer, size)
    local alpha = Config.Get(scope, "shadowAlpha") / 100
    for _, piece in ipairs(ringPieces(shadow)) do piece:SetVertexColor(0, 0, 0, alpha) end
end

-- Drawing ---------------------------------------------------------------------

local function pieces(owner)
    if not owner.border then
        owner.border = newRing(owner, 0)
        owner.border.line = newRing(owner, 1)
        owner.shadow = newShadow(owner)
    end
    return owner.border
end

-- Draws owner's border and shadow around box in scope's settings: show,
-- style, size, padding, colour, shadow; rounded by radius (default: the
-- scope's corner radius; callers clamp it to the box).
function Border.Draw(owner, scope, box, radius)
    local ring = pieces(owner)
    local size, padding = Border.Size(scope), Border.Padding(scope)
    radius = radius or ns.Corners.Radius(scope)
    local corner = placeRing(ring, box, size, padding, radius)
    local isGold = Config.Get(scope, "borderStyle") == "GOLD"
    if isGold then
        paintGold(ring, corner > 0 and size / corner or 1)
    else
        paintFlat(ring, Config.Get(scope, "borderColor"))
    end
    showRing(ring, size > 0)
    -- The dark inner line of the gold style, the ring's innermost pixel;
    -- a one-pixel ring would be all line.
    local pixel = Pixel.Snap(1, nil, 1)
    local hasLine = isGold and size >= 2 * pixel
    if hasLine then
        placeRing(ring.line, box, pixel, padding, radius)
        paintFlat(ring.line, Border.GOLD.LINE)
    end
    showRing(ring.line, hasLine)
    drawShadow(owner, scope, box, radius)
end

function Border.Hide(owner)
    local ring = owner.border
    if not ring then return end
    showRing(ring, false)
    showRing(ring.line, false)
    hideShadow(owner.shadow)
end
