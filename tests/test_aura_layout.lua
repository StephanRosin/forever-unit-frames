local ns = H.LoadAddon()
local Layout = ns.Layout

-- Rows run across the growth direction; anything else gets the default.
H.check("right, down", Layout.AuraRowDirection("RIGHT", "DOWN"), "DOWN")
H.check("right, up", Layout.AuraRowDirection("RIGHT", "UP"), "UP")
H.check("right, left -> down", Layout.AuraRowDirection("RIGHT", "LEFT"), "DOWN")
H.check("left, right -> down", Layout.AuraRowDirection("LEFT", "RIGHT"), "DOWN")
H.check("up, left", Layout.AuraRowDirection("UP", "LEFT"), "LEFT")
H.check("down, up -> right", Layout.AuraRowDirection("DOWN", "UP"), "RIGHT")

-- The first icon sits in the corner the icons grow away from.
H.check("corner right/down", Layout.AuraCorner("RIGHT", "DOWN"), "TOPLEFT")
H.check("corner right/up", Layout.AuraCorner("RIGHT", "UP"), "BOTTOMLEFT")
H.check("corner left/down", Layout.AuraCorner("LEFT", "DOWN"), "TOPRIGHT")
H.check("corner left/up", Layout.AuraCorner("LEFT", "UP"), "BOTTOMRIGHT")
H.check("corner up/right", Layout.AuraCorner("UP", "RIGHT"), "BOTTOMLEFT")
H.check("corner up/left", Layout.AuraCorner("UP", "LEFT"), "BOTTOMRIGHT")
H.check("corner down/right", Layout.AuraCorner("DOWN", "RIGHT"), "TOPLEFT")
H.check("corner down/left", Layout.AuraCorner("DOWN", "LEFT"), "TOPRIGHT")
H.check("corner with a bad row direction", Layout.AuraCorner("RIGHT", "RIGHT"), "TOPLEFT")

-- Offsets of icon i from that corner (step = size + spacing).
local function at(i, perRow, primary, row)
    local x, y = Layout.AuraOffset(i, perRow, 22, primary, row)
    return x .. "," .. y
end
H.check("first icon", at(1, 4, "RIGHT", "DOWN"), "0,0")
H.check("third icon", at(3, 4, "RIGHT", "DOWN"), "44,0")
H.check("fifth icon wraps", at(5, 4, "RIGHT", "DOWN"), "0,-22")
H.check("sixth icon", at(6, 4, "RIGHT", "DOWN"), "22,-22")
H.check("growing left, rows up", at(6, 4, "LEFT", "UP"), "-22,22")
H.check("growing up, rows right", at(6, 4, "UP", "RIGHT"), "22,22")
H.check("growing down, rows left", at(3, 2, "DOWN", "LEFT"), "-22,0")
H.check("bad row direction falls back", at(5, 4, "RIGHT", "LEFT"), "0,-22")

-- Size of the block of shown icons.
local function extent(count, perRow, primary)
    local w, h = Layout.AuraExtent(count, perRow, 20, 2, primary)
    return w .. "x" .. h
end
H.check("no icons", extent(0, 4, "RIGHT"), "0x0")
H.check("one icon", extent(1, 4, "RIGHT"), "20x20")
H.check("one row", extent(3, 4, "RIGHT"), "64x20")
H.check("two rows", extent(5, 4, "LEFT"), "86x42")
H.check("vertical", extent(5, 4, "UP"), "42x86")
