local _, ns = ...

-- Pure layout maths, kept free of widgets so it can be tested directly.
local Layout = {}
ns.Layout = Layout

local function round(v) return math.floor(v + 0.5) end

-- Split a frame height into title row, health bar, gap and power bar.
-- Percentages are of the whole frame; whatever they leave over becomes the
-- gap between health and power. A title of 0 % means no title row; with
-- the power bar off, health takes everything below the title. Health keeps
-- at least 1: the title gives way first.
function Layout.Rows(height, titlePercent, healthPercent, powerPercent, powerEnabled)
    local powered = powerEnabled and powerPercent > 0
    local powerH = powered and math.max(1, math.floor(height * powerPercent / 100)) or 0
    local titleH = 0
    if titlePercent > 0 then
        titleH = math.max(1, round(height * titlePercent / 100))
        titleH = math.max(0, math.min(titleH, height - powerH - 1))
    end
    if not powered then
        return titleH, height - titleH, 0, 0
    end
    local healthH = round(height * healthPercent / 100)
    if titleH + healthH + powerH > height then
        healthH = height - titleH - powerH
    end
    healthH = math.max(1, healthH)
    return titleH, healthH, height - titleH - healthH - powerH, powerH
end

-- The two-row split (no title row): health, gap, power.
function Layout.Bars(height, healthPercent, powerPercent, powerEnabled)
    local _, healthH, gap, powerH = Layout.Rows(height, 0, healthPercent, powerPercent, powerEnabled)
    return healthH, gap, powerH
end

-- Space the portrait takes from the bars: a square as tall as the frame,
-- on the left or the right. Returns left inset, right inset.
function Layout.PortraitInsets(mode, height)
    if mode == "LEFT" then return height, 0 end
    if mode == "RIGHT" then return 0, height end
    return 0, 0
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
