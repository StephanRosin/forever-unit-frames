local M = H.M
local ns = H.LoadAddon()
local S, Co = ns.Settings, ns.Corners

-- The mask files: 64 x 64 uncompressed 32-bit TGA, rows bottom to top.
local function tga(path)
    local fh = assert(io.open(ADDONDIR .. "/" .. path, "rb"))
    local data = fh:read("*a")
    fh:close()
    return data
end
local function alphaAt(data, x, y) -- x right, y down from the top-left
    local row = 63 - y
    return data:byte(18 + (row * 64 + x) * 4 + 4)
end
local INVERSE = { "Media/CornerInverseTopLeft.tga", "Media/CornerInverseTopRight.tga",
    "Media/CornerInverseBottomLeft.tga", "Media/CornerInverseBottomRight.tga" }
local FILES = { "Media/Corner.tga" }
for _, file in ipairs(INVERSE) do FILES[#FILES + 1] = file end
for _, file in ipairs(FILES) do
    local d = tga(file)
    H.check(file .. " size", #d, 18 + 64 * 64 * 4)
    H.check(file .. " type: uncompressed true colour", d:byte(3), 2)
    H.check(file .. " width", d:byte(13) + 256 * d:byte(14), 64)
    H.check(file .. " height", d:byte(15) + 256 * d:byte(16), 64)
    H.check(file .. " 32 bits", d:byte(17), 32)
    H.check(file .. " 8 alpha bits, bottom-up rows", d:byte(18), 8)
    H.check(file .. " white", d:byte(19) + d:byte(20) + d:byte(21), 3 * 255)
end
local corner, inverse = tga("Media/Corner.tga"), tga(INVERSE[1])
H.check("corner: outer texel cut", alphaAt(corner, 0, 0), 0)
H.check("corner: inner texel kept", alphaAt(corner, 63, 63), 255)
H.check("corner: whole right column kept", alphaAt(corner, 63, 0), 255)
H.check("corner: whole bottom row kept", alphaAt(corner, 0, 63), 255)
H.check("inverse: outer texel cut", alphaAt(inverse, 0, 0), 255)
H.check("inverse: inner texel cut", alphaAt(inverse, 63, 63), 0)
H.check("inverse: whole left column kept", alphaAt(inverse, 0, 63), 255)
H.check("inverse: whole top row kept", alphaAt(inverse, 63, 0), 255)
-- Masks ignore texture coordinates in the client: each corner's inverse
-- arc is mirrored in its own file, cut towards the box's inside.
local INSIDE = { { 63, 63 }, { 0, 63 }, { 63, 0 }, { 0, 0 } }
local OUTSIDE = { { 0, 0 }, { 63, 0 }, { 0, 63 }, { 63, 63 } }
for i, file in ipairs(INVERSE) do
    local d = tga(file)
    H.check(file .. ": cut towards the inside", alphaAt(d, INSIDE[i][1], INSIDE[i][2]), 0)
    H.check(file .. ": outer corner kept", alphaAt(d, OUTSIDE[i][1], OUTSIDE[i][2]), 255)
    H.check("path of " .. file, ns.Corners.INVERSE[i], "Interface\\AddOns\\ForeverUnitFrames\\" .. file:gsub("/", "\\"))
end

-- The client's rule for a sliced mask (measured in game at radius 9: the
-- fill's arc came out ~29 UI units with 28-texel margins and the mask
-- scaled to 9/28): a corner cell is `margin` UI units of the box, and the
-- mask's scale is ignored. So radius r uses a file whose arcs are r texels,
-- sliced with margins r. Each file: 32 x 32, arcs of r texels in the
-- corner cells, opaque between them.
local MASK = 32
local function maskAlpha(data, x, y) return data:byte(18 + ((MASK - 1 - y) * MASK + x) * 4 + 4) end
local ROUND = { ALL = { true, true, true, true }, TOP = { true, true, false, false },
    BOTTOM = { false, false, true, true } }
local CORNER = { { 0, 0 }, { MASK - 1, 0 }, { 0, MASK - 1 }, { MASK - 1, MASK - 1 } }
H.check("radii up to the setting's max", ns.Corners.MAX_RADIUS, ns.Settings.Get("cornerRadius").max)
for r = 1, ns.Corners.MAX_RADIUS do
    for shape, round in pairs(ROUND) do
        local path = ns.Corners.MaskFile(r, shape)
        local file = path:gsub("^Interface\\AddOns\\ForeverUnitFrames\\", ""):gsub("\\", "/")
        local d = tga(file)
        local label = file
        H.check(label .. " size", #d, 18 + MASK * MASK * 4)
        H.check(label .. " width", d:byte(13), MASK)
        for i, xy in ipairs(CORNER) do
            H.check(label .. " corner " .. i .. " round", maskAlpha(d, xy[1], xy[2]) < 255, round[i])
        end
        -- The arc spans exactly r texels: its end texels at r - 1 are
        -- (nearly) opaque, the texel r in from the corner along the
        -- diagonal is outside the arc's reach.
        local opaqueBetween = true
        for i = 0, MASK - 1 do
            for _, xy in ipairs({ { r, i }, { MASK - 1 - r, i }, { i, r }, { i, MASK - 1 - r } }) do
                if maskAlpha(d, xy[1], xy[2]) ~= 255 then opaqueBetween = false end
            end
        end
        H.checkTrue(label .. " opaque beyond the corner cells", opaqueBetween)
        if round[1] then
            H.checkTrue(label .. " arc reaches the cell's edge", maskAlpha(d, r - 1, 0) > 128)
            local d45 = math.floor(r * (1 - math.sqrt(0.5)) - 0.5)
            H.checkTrue(label .. " arc radius r (diagonal)", d45 < 0 or maskAlpha(d, d45, d45) < 128)
        end
    end
end

-- The installer ships them (it copies only what the TOC lists otherwise).
local dir = os.tmpname()
os.remove(dir)
os.execute("mkdir -p '" .. dir .. "'")
os.execute("'" .. ADDONDIR .. "/install' '" .. dir .. "' > /dev/null")
local shipped = io.open(dir .. "/ForeverUnitFrames/Media/Corner.tga", "rb")
H.checkTrue("installed corner mask", shipped)
if shipped then shipped:close() end
for _, file in ipairs({ "Rounded01", "Rounded12Top", "Rounded07Bottom", "CornerInverseTopLeft",
    "CornerInverseTopRight", "CornerInverseBottomLeft", "CornerInverseBottomRight" }) do
    H.checkTrue("installed mask " .. file, io.open(dir .. "/ForeverUnitFrames/Media/" .. file .. ".tga", "rb"))
end
os.execute("rm -rf '" .. dir .. "'")

-- Setting: inherited, 0..12, square by default.
local def = S.Get("cornerRadius")
H.check("code", def.code, "CR")
H.check("inherited", def.scope, "inherit")
H.check("default square", S.Default(def, "general"), 0)
H.check("max", S.Validate(def, 40), 12)
H.check("label", ns.L.SETTING_cornerRadius, "Corner radius")
H.checkTrue("hint", ns.L.HINT_cornerRadius)

ns.Config.Use({})
ns.Single.CreateAll()
local C = ns.Config
local f = ns.Frames.target
local bar = f.castbar
local function masked(texture) return texture:GetNumMaskTextures() end
local badgeMasks = masked(f.classIcon)

-- Square: nothing masked, mask hidden.
H.check("square: health background unmasked", masked(f.healthBg), 0)
H.check("square: mask hidden", f.clip.mask:IsShown(), false)
H.check("radius 0", Co.Radius("target"), 0)

-- General radius 6 reaches every frame: one nine-slice mask over the
-- whole frame, the file for that radius sliced with margins of the radius.
-- One mask per texture, however the castbar sits (Elements/Shape.lua).
C.Set("general", "cornerRadius", 6)
H.check("radius", Co.Radius("target"), 6)
for _, name in ipairs({ "title", "healthBg", "powerBg", "portraitBg", "portrait2D" }) do
    H.check(name .. " rounded", masked(f[name]), 1)
    H.check(name .. " by the frame's mask", f[name]._masks[1], f.clip.mask)
end
H.check("health fill rounded", masked(f.health:GetStatusBarTexture()), 1)
H.check("power fill rounded", masked(f.power:GetStatusBarTexture()), 1)
local mask = f.clip.mask
H.check("mask over the frame", mask._allPoints, f)
H.check("mask file", mask._texture, Co.MaskFile(6, "ALL"))
H.check("mask clamps", mask._wrap[1] .. mask._wrap[2], "CLAMPCLAMP")
H.check("mask sliced by the radius", table.concat(mask._slice, ","), "6,6,6,6")
H.check("mask stretched", mask._sliceMode, Enum.UITextureSliceMode.Stretched)
H.check("mask not scaled", mask._scale, nil)
H.checkTrue("mask shown", mask:IsShown())
H.check("file path", Co.MaskFile(6, "ALL"), "Interface\\AddOns\\ForeverUnitFrames\\Media\\Rounded06.tga")
H.check("file path, top round", Co.MaskFile(12, "TOP"), "Interface\\AddOns\\ForeverUnitFrames\\Media\\Rounded12Top.tga")

-- The class badge sticks out of the block: it keeps only its round mask.
H.check("badge icon not clipped", masked(f.classIcon), badgeMasks)
H.check("badge ring not clipped", masked(f.classRing), badgeMasks)

-- Restyling does not stack masks.
C.Set("general", "cornerRadius", 8)
H.check("no masks stacked", masked(f.healthBg), 1)
H.check("new radius: its file", f.clip.mask._texture, Co.MaskFile(8, "ALL"))
H.check("new radius: its margins", f.clip.mask._slice[1], 8)

-- Castbar: its own mask, icon (and the slot behind it) included.
H.check("castbar background rounded", masked(bar.bg), 1)
H.check("castbar channel paint rounded", masked(bar.remain), 1)
H.check("castbar fill rounded", masked(bar:GetStatusBarTexture()), 1)
H.check("castbar icon rounded", masked(bar.icon), 1)
H.check("castbar icon slot rounded", masked(bar.iconBg), 1)
H.check("castbar: its own mask", bar.bg._masks[1], bar.clip.mask)
H.check("docked castbar: mask over the unit box", bar.clip.mask._allPoints, f.unitBox)
H.check("box starts at the icon", select(4, bar.box:GetPoint(1)), -16)
C.Set("target", "castbarIcon", false)
H.check("no icon: box starts at the bar", select(4, bar.box:GetPoint(1)), 0)

-- A frame can stay square.
C.Set("target", "cornerRadius", 0)
H.check("override: square again", masked(f.healthBg), 0)
H.check("override: fill square again", masked(f.health:GetStatusBarTexture()), 0)
H.check("override: castbar square", masked(bar.bg), 0)
H.check("override: mask hidden", f.clip.mask:IsShown(), false)
H.check("other frames keep theirs", masked(ns.Frames.player.healthBg), 1)

-- Party buttons are rounded too.
local header = ns.Party.Create()
M.units.party1 = { name = "Ann", health = 1, healthMax = 2 }
M.SetGroup({ "party1" })
H.check("party rounded", masked(header:GetAttribute("child1").healthBg), 1)
