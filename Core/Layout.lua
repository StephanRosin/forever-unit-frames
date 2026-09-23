local _, ns = ...

-- Pure layout maths, kept free of widgets so it can be tested directly.
local Layout = {}
ns.Layout = Layout

local function round(v) return math.floor(v + 0.5) end

-- Split a frame height into title row, health bar and power bar; the three
-- always fill the frame. Percentages are shares of the whole frame. Room
-- they leave over goes to health and power in proportion to their shares;
-- shares that do not fit shrink health (power keeps its share). A title of
-- 0 % means no title row; with the power bar off, health takes everything
-- below the title. Health keeps at least 1: the title gives way first.
function Layout.Rows(height, titlePercent, healthPercent, powerPercent, powerEnabled)
    local powered = powerEnabled and powerPercent > 0
    local powerH = powered and math.max(1, math.floor(height * powerPercent / 100)) or 0
    local titleH = 0
    if titlePercent > 0 then
        titleH = math.max(1, round(height * titlePercent / 100))
        titleH = math.max(0, math.min(titleH, height - powerH - 1))
    end
    local rest = height - titleH
    if not powered then
        return titleH, rest, 0
    end
    if round(height * healthPercent / 100) + powerH < rest then
        powerH = math.max(1, math.floor(rest * powerPercent / (healthPercent + powerPercent)))
    end
    return titleH, math.max(1, rest - powerH), powerH
end

-- The two-row split (no title row): health, power.
function Layout.Bars(height, healthPercent, powerPercent, powerEnabled)
    local _, healthH, powerH = Layout.Rows(height, 0, healthPercent, powerPercent, powerEnabled)
    return healthH, powerH
end

-- Width of the overheal lane at the end of a health bar of barWidth: 8 %,
-- at least 4.
function Layout.OverhealLane(barWidth)
    return math.max(4, round(barWidth * 0.08))
end

-- Space the portrait takes from the bars: a square as tall as the frame,
-- on the left or the right. Returns left inset, right inset.
function Layout.PortraitInsets(mode, height)
    if mode == "LEFT" then return height, 0 end
    if mode == "RIGHT" then return 0, height end
    return 0, 0
end

-- Aura icons ------------------------------------------------------------------
-- Icons grow in a primary direction and wrap into rows that run across
-- it. Offsets are measured from the corner the icons grow away from.
local VECTOR = { RIGHT = { 1, 0 }, LEFT = { -1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
local HORIZONTAL = { RIGHT = true, LEFT = true }

-- The row direction, or the default one (down for horizontal growth,
-- right for vertical) when it does not run across the primary direction.
function Layout.AuraRowDirection(primary, row)
    if HORIZONTAL[primary] then
        if row == "UP" or row == "DOWN" then return row end
        return "DOWN"
    end
    if row == "LEFT" or row == "RIGHT" then return row end
    return "RIGHT"
end

-- Where the first icon sits: TOPLEFT for icons growing right with rows
-- going down, and so on.
function Layout.AuraCorner(primary, row)
    row = Layout.AuraRowDirection(primary, row)
    local horizontal, vertical = primary, row
    if not HORIZONTAL[primary] then horizontal, vertical = row, primary end
    local v = vertical == "DOWN" and "TOP" or "BOTTOM"
    local h = horizontal == "RIGHT" and "LEFT" or "RIGHT"
    return v .. h
end

-- Offset of icon i (1-based) from that corner; step = icon size + spacing.
function Layout.AuraOffset(i, perRow, step, primary, row)
    row = Layout.AuraRowDirection(primary, row)
    local col, line = (i - 1) % perRow, math.floor((i - 1) / perRow)
    local p, r = VECTOR[primary], VECTOR[row]
    return (p[1] * col + r[1] * line) * step, (p[2] * col + r[2] * line) * step
end

-- Width and height of count icons laid out this way (0, 0 for none).
function Layout.AuraExtent(count, perRow, size, spacing, primary)
    if count <= 0 then return 0, 0 end
    local cols = math.min(count, perRow)
    local lines = math.ceil(count / perRow)
    local along = cols * size + (cols - 1) * spacing
    local across = lines * size + (lines - 1) * spacing
    if HORIZONTAL[primary] then return along, across end
    return across, along
end

-- Icons per row: a fixed number, or 0 for as many as fit the length (the
-- frame's extent along the growth direction), at least one.
function Layout.AuraPerRow(perRow, length, size, spacing)
    if perRow > 0 then return perRow end
    return math.max(1, math.floor((length + spacing) / (size + spacing)))
end

-- Two size classes: the first `own` icons (yours) in their own leading
-- rows at shape.ownSize, shape.ownPerRow per row; the rest in the rows
-- after them at shape.size, shape.perRow per row. shape also holds
-- primary, row and spacing. Plain numbers in, plain numbers out: nothing
-- is allocated.

-- How far across the growth direction the own rows reach, with the gap to
-- the rows after them (0 without own icons).
local function ownDepth(shape, own)
    if own <= 0 then return 0 end
    local lines = math.ceil(own / shape.ownPerRow)
    return lines * shape.ownSize + lines * shape.spacing
end

-- Offset of icon i from the corner, and its size.
function Layout.AuraPlace(shape, i, own)
    local row = Layout.AuraRowDirection(shape.primary, shape.row)
    local p, r = VECTOR[shape.primary], VECTOR[row]
    local index, perRow, size, shift = i, shape.ownPerRow, shape.ownSize, 0
    if i > own then
        index, perRow, size, shift = i - own, shape.perRow, shape.size, ownDepth(shape, own)
    end
    local step = size + shape.spacing
    local along, across = ((index - 1) % perRow) * step, math.floor((index - 1) / perRow) * step + shift
    -- + 0 turns a negative zero into 0.
    return p[1] * along + r[1] * across + 0, p[2] * along + r[2] * across + 0, size
end

-- Width and height of count icons, the first `own` of them yours.
function Layout.AuraBlock(shape, own, count)
    own = math.min(own, count)
    local ownAlong, ownAcross = Layout.AuraExtent(own, shape.ownPerRow, shape.ownSize, shape.spacing, "RIGHT")
    local along, across = Layout.AuraExtent(count - own, shape.perRow, shape.size, shape.spacing, "RIGHT")
    along = math.max(along, ownAlong)
    if own > 0 and count > own then across = across + shape.spacing end
    across = across + ownAcross
    if HORIZONTAL[shape.primary] then return along, across end
    return across, along
end

-- Pixel grid ------------------------------------------------------------------
-- Sizes and offsets are rounded to whole physical pixels with Blizzard's
-- PixelUtil (Blizzard_SharedXML, loaded for every game type): one pixel is
-- 768 / physical screen height / effective scale UI units. Edges then land
-- on pixel boundaries instead of being smeared across two, and a one-unit
-- border is exactly as thick on every side. Positions measured from the
-- screen centre assume that centre is on a pixel boundary (an even
-- physical screen size, as every common resolution is).
local Pixel = {}
ns.Pixel = Pixel

local function scaleOf(region) return (region or UIParent):GetEffectiveScale() end

-- The nearest whole-pixel length to v in region's (default UIParent's)
-- units. minPixels (optional) keeps a non-zero length at least that many
-- pixels long.
function Pixel.Snap(v, region, minPixels)
    return PixelUtil.GetNearestPixelSize(v, scaleOf(region), minPixels)
end

-- One physical pixel in region's (default UIParent's) units.
function Pixel.One(region)
    return PixelUtil.GetPixelToUIUnitFactor() / scaleOf(region)
end

-- Offset for a centre anchor: a span of the given (snapped) size centred
-- there has both edges on pixels.
function Pixel.Centre(v, size, region)
    return Pixel.Snap(v - size / 2, region) + size / 2
end

-- The pixel grid moves with the UI scale and the window size: whatever
-- was laid out on it is laid out again.
local function gridChanged() ns.Fire("PIXEL_GRID_CHANGED") end
ns.On("UI_SCALE_CHANGED", gridChanged)
ns.On("DISPLAY_SIZE_CHANGED", gridChanged)
