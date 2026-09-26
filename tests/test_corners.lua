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
local FILES = { "Media/Corner.tga", "Media/Rounded.tga", "Media/RoundedTop.tga", "Media/RoundedBottom.tga" }
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

-- The nine-slice masks: arcs of radius SLICE in the corner cells, all
-- opaque between them, so the stretched edges and middle cut nothing.
local SLICE = ns.Corners.SLICE
H.check("slice margin", SLICE, 28)
local function roundAt(data, x, y) return alphaAt(data, x, y) == 0 end
local function opaqueBetween(data)
    for i = 0, 63 do
        for _, xy in ipairs({ { SLICE, i }, { 63 - SLICE, i }, { i, SLICE }, { i, 63 - SLICE } }) do
            if alphaAt(data, xy[1], xy[2]) ~= 255 then return false end
        end
    end
    return true
end
local ROUND = { -- file: top-left, top-right, bottom-left, bottom-right round
    ["Media/Rounded.tga"] = { true, true, true, true },
    ["Media/RoundedTop.tga"] = { true, true, false, false },
    ["Media/RoundedBottom.tga"] = { false, false, true, true },
}
for file, round in pairs(ROUND) do
    local d = tga(file)
    local corners = { { 0, 0 }, { 63, 0 }, { 0, 63 }, { 63, 63 } }
    for i, xy in ipairs(corners) do
        H.check(file .. " corner " .. i .. " round", roundAt(d, xy[1], xy[2]), round[i])
    end
    H.checkTrue(file .. " opaque between the corner cells", opaqueBetween(d))
    H.check(file .. " arc ends at the cell's edge", alphaAt(d, SLICE - 1, 0) > 200, true)
    H.check(file .. " middle opaque", alphaAt(d, 32, 32), 255)
end

-- The installer ships them (it copies only what the TOC lists otherwise).
local dir = os.tmpname()
os.remove(dir)
os.execute("mkdir -p '" .. dir .. "'")
os.execute("'" .. ADDONDIR .. "/install' '" .. dir .. "' > /dev/null")
local shipped = io.open(dir .. "/ForeverUnitFrames/Media/Corner.tga", "rb")
H.checkTrue("installed corner mask", shipped)
if shipped then shipped:close() end
for _, file in ipairs({ "Rounded", "RoundedTop", "RoundedBottom", "CornerInverseTopLeft", "CornerInverseTopRight",
    "CornerInverseBottomLeft", "CornerInverseBottomRight" }) do
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
-- whole frame, scaled so its corner cells are the radius. One mask per
-- texture, however the castbar sits (Elements/Shape.lua).
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
H.check("mask file", mask._texture, Co.MASKS.ALL)
H.check("mask clamps", mask._wrap[1] .. mask._wrap[2], "CLAMPCLAMP")
H.check("mask sliced", table.concat(mask._slice, ","), "28,28,28,28")
H.check("mask stretched", mask._sliceMode, Enum.UITextureSliceMode.Stretched)
H.check("mask scaled to the radius", mask:GetScale(), 6 / 28)
H.checkTrue("mask shown", mask:IsShown())
H.check("file path", Co.MASKS.ALL, "Interface\\AddOns\\ForeverUnitFrames\\Media\\Rounded.tga")

-- The class badge sticks out of the block: it keeps only its round mask.
H.check("badge icon not clipped", masked(f.classIcon), badgeMasks)
H.check("badge ring not clipped", masked(f.classRing), badgeMasks)

-- Restyling does not stack masks.
C.Set("general", "cornerRadius", 8)
H.check("no masks stacked", masked(f.healthBg), 1)
H.check("new scale", f.clip.mask:GetScale(), 8 / 28)

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
