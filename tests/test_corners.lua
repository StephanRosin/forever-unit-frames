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
for _, file in ipairs({ "Media/Corner.tga", "Media/CornerInverse.tga" }) do
    local d = tga(file)
    H.check(file .. " size", #d, 18 + 64 * 64 * 4)
    H.check(file .. " type: uncompressed true colour", d:byte(3), 2)
    H.check(file .. " width", d:byte(13) + 256 * d:byte(14), 64)
    H.check(file .. " height", d:byte(15) + 256 * d:byte(16), 64)
    H.check(file .. " 32 bits", d:byte(17), 32)
    H.check(file .. " 8 alpha bits, bottom-up rows", d:byte(18), 8)
end
local corner, inverse = tga("Media/Corner.tga"), tga("Media/CornerInverse.tga")
H.check("corner: outer texel cut", alphaAt(corner, 0, 0), 0)
H.check("corner: inner texel kept", alphaAt(corner, 63, 63), 255)
H.check("corner: whole right column kept", alphaAt(corner, 63, 0), 255)
H.check("corner: whole bottom row kept", alphaAt(corner, 0, 63), 255)
H.check("corner: white", corner:byte(19) + corner:byte(20) + corner:byte(21), 3 * 255)
H.check("inverse: outer texel kept", alphaAt(inverse, 0, 0), 255)
H.check("inverse: inner texel cut", alphaAt(inverse, 63, 63), 0)
H.check("inverse: whole left column kept", alphaAt(inverse, 0, 63), 255)
H.check("inverse: whole top row kept", alphaAt(inverse, 63, 0), 255)

-- The installer ships them (it copies only what the TOC lists otherwise).
local dir = os.tmpname()
os.remove(dir)
os.execute("mkdir -p '" .. dir .. "'")
os.execute("'" .. ADDONDIR .. "/install' '" .. dir .. "' > /dev/null")
local shipped = io.open(dir .. "/ForeverUnitFrames/Media/Corner.tga", "rb")
H.checkTrue("installed corner mask", shipped)
if shipped then shipped:close() end
H.checkTrue("installed inverse mask", io.open(dir .. "/ForeverUnitFrames/Media/CornerInverse.tga", "rb"))
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

-- Square: nothing masked, masks hidden.
H.check("square: health background unmasked", masked(f.healthBg), 0)
H.check("square: masks hidden", f.clip.masks[1]:IsShown(), false)
H.check("radius 0", Co.Radius("target"), 0)

-- General radius 6 reaches every frame. A frame with a docked castbar
-- carries its four corner masks plus two for the castbar's side of the
-- block (Elements/Shape.lua); the player's castbar is off.
local BLOCK = 6
C.Set("general", "cornerRadius", 6)
H.check("radius", Co.Radius("target"), 6)
for _, name in ipairs({ "title", "healthBg", "powerBg", "portraitBg", "portrait2D" }) do
    H.check(name .. " rounded", masked(f[name]), BLOCK)
end
H.check("health fill rounded", masked(f.health:GetStatusBarTexture()), BLOCK)
H.check("power fill rounded", masked(f.power:GetStatusBarTexture()), BLOCK)
for i, mask in ipairs(f.clip.masks) do
    local point = Co.POINTS[i]
    local p, rel, relPoint = mask:GetPoint(1)
    H.check("mask " .. i .. " in its corner", p, point)
    H.check("mask " .. i .. " of the frame", rel, f)
    H.check("mask " .. i .. " same corner", relPoint, point)
    H.check("mask " .. i .. " size", mask:GetWidth(), 6)
    H.check("mask " .. i .. " file", mask._texture, Co.TEXTURE)
    H.check("mask " .. i .. " clamps", mask._wrap[1] .. mask._wrap[2], "CLAMPCLAMP")
    H.check("mask " .. i .. " mirrored", table.concat(mask._texCoord, ","), table.concat(Co.COORDS[i], ","))
    H.checkTrue("mask " .. i .. " shown", mask:IsShown())
end
H.check("file path", Co.TEXTURE, "Interface\\AddOns\\ForeverUnitFrames\\Media\\Corner.tga")

-- The class badge sticks out of the block: it keeps only its round mask.
H.check("badge icon not clipped", masked(f.classIcon), badgeMasks)
H.check("badge ring not clipped", masked(f.classRing), badgeMasks)

-- Restyling does not stack masks.
C.Set("general", "cornerRadius", 8)
H.check("no masks stacked", masked(f.healthBg), BLOCK)
H.check("new size", f.clip.masks[1]:GetWidth(), 8)

-- Castbar: its own block, icon (and the slot behind it) included.
H.check("castbar background rounded", masked(bar.bg), 4)
H.check("castbar channel paint rounded", masked(bar.remain), 4)
H.check("castbar fill rounded", masked(bar:GetStatusBarTexture()), 4)
H.check("castbar icon rounded", masked(bar.icon), 4)
H.check("castbar icon slot rounded", masked(bar.iconBg), 4)
H.check("docked castbar: masks on the unit box", select(2, bar.clip.masks[1]:GetPoint(1)), f.unitBox)
H.check("box starts at the icon", select(4, bar.box:GetPoint(1)), -16)
C.Set("target", "castbarIcon", false)
H.check("no icon: box starts at the bar", select(4, bar.box:GetPoint(1)), 0)

-- A frame can stay square.
C.Set("target", "cornerRadius", 0)
H.check("override: square again", masked(f.healthBg), 0)
H.check("override: fill square again", masked(f.health:GetStatusBarTexture()), 0)
H.check("override: castbar square", masked(bar.bg), 0)
H.check("override: masks hidden", f.clip.masks[1]:IsShown(), false)
H.check("other frames keep theirs", masked(ns.Frames.player.healthBg), 4)

-- Party buttons are rounded too.
local header = ns.Party.Create()
M.units.party1 = { name = "Ann", health = 1, healthMax = 2 }
M.SetGroup({ "party1" })
H.check("party rounded", masked(header:GetAttribute("child1").healthBg), BLOCK)
