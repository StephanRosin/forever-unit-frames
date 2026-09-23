local _, ns = ...

-- Pure layout maths, kept free of widgets so it can be tested directly.
local Layout = {}
ns.Layout = Layout

local function round(v) return math.floor(v + 0.5) end

-- Split a frame height into health bar, gap and power bar. Percentages are
-- of the whole frame; whatever they leave over becomes the gap. With the
-- power bar off, health takes everything.
function Layout.Bars(height, healthPercent, powerPercent, powerEnabled)
    if not powerEnabled or powerPercent <= 0 then
        return height, 0, 0
    end
    local powerH = math.max(1, math.floor(height * powerPercent / 100))
    local healthH = round(height * healthPercent / 100)
    if healthH + powerH > height then
        healthH = height - powerH
    end
    healthH = math.max(1, healthH)
    return healthH, height - healthH - powerH, powerH
end

-- Space the portrait takes from the bars: a square as tall as the frame,
-- on the left or the right. Returns left inset, right inset.
function Layout.PortraitInsets(mode, height)
    if mode == "LEFT" then return height, 0 end
    if mode == "RIGHT" then return 0, height end
    return 0, 0
end
