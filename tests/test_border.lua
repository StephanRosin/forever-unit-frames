local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

-- Settings: thicker borders, a new padding; the size code is unchanged.
H.check("size code kept", S.Get("borderSize").code, "BS")
H.check("size up to 8", S.Validate(S.Get("borderSize"), 20), 8)
local pad = S.Get("borderPadding")
H.check("padding code", pad.code, "BP")
H.check("padding inherited", pad.scope, "inherit")
H.check("padding default", S.Default(pad, "general"), 0)
H.check("padding max", S.Validate(pad, 20), 8)
-- Show toggle, style, drop shadow: inherited, the old look by default.
local function setting(key, code, kind, default)
    local def = S.Get(key)
    H.check(key .. " code", def and def.code, code)
    H.check(key .. " type", def and def.type, kind)
    H.check(key .. " inherited", def and def.scope, "inherit")
    H.check(key .. " default", def and S.Default(def, "general"), default)
    H.checkTrue(key .. " label", ns.L["SETTING_" .. key] ~= "SETTING_" .. key)
    return def
end
setting("borderShow", "BV", "bool", true)
local style = setting("borderStyle", "BY", "enum", "FLAT")
H.check("styles, append only", style and table.concat(style.values, ","), "FLAT,GOLD")
setting("shadowEnabled", "SE", "bool", false)
local alpha = setting("shadowAlpha", "SA", "int", 50)
H.check("shadow strength range", alpha and (alpha.min .. "-" .. alpha.max), "0-100")
local ssize = setting("shadowSize", "SZ", "int", 4)
H.check("shadow size range", ssize and (ssize.min .. "-" .. ssize.max), "1-16")
for _, v in ipairs({ "FLAT", "GOLD" }) do
    H.checkTrue("style text " .. v, ns.Schema.EnumText(style, v) ~= "ENUM_" .. v)
end

-- Options: a Border and a Shadow section on General > Appearance and on
-- the frame Layout tab (not on the Bars tab any more).
local function section(tabs, tabId, id)
    for _, tab in ipairs(tabs) do
        if tab.id == tabId then
            for _, sec in ipairs(tab.sections) do
                if sec.id == id then return table.concat(sec.keys, ",") end
            end
        end
    end
end
local BORDER_KEYS = "borderShow,borderStyle,borderSize,borderPadding,borderColor"
local SHADOW_KEYS = "shadowEnabled,shadowAlpha,shadowSize"
H.check("general border section", section(ns.Schema.GENERAL, "appearance", "border"), BORDER_KEYS)
H.check("general shadow section", section(ns.Schema.GENERAL, "appearance", "shadow"), SHADOW_KEYS)
H.check("frame border section", section(ns.Schema.FRAME, "layout", "border"), BORDER_KEYS)
H.check("frame shadow section", section(ns.Schema.FRAME, "layout", "shadow"), SHADOW_KEYS)
H.check("not on the bars tab", section(ns.Schema.FRAME, "bars", "border"), nil)
H.checkTrue("shadow section title", ns.L.SECTION_shadow ~= "SECTION_shadow")

-- The shadow file: 512 x 32, sixteen 32 x 32 cells, uncompressed 32-bit.
local function tga(path)
    local fh = assert(io.open(ADDONDIR .. "/" .. path, "rb"))
    local data = fh:read("*a")
    fh:close()
    return data
end
local shadow = tga("Media/Shadow.tga")
H.check("shadow file size", #shadow, 18 + 512 * 32 * 4)
H.check("shadow width", shadow:byte(13) + 256 * shadow:byte(14), 512)
H.check("shadow height", shadow:byte(15) + 256 * shadow:byte(16), 32)
H.check("shadow 32 bits", shadow:byte(17), 32)
local function shadowAlpha(x, y) -- x right, y down from the top-left
    return shadow:byte(18 + ((31 - y) * 512 + x) * 4 + 4)
end
H.checkTrue("cell 0: (nearly) full next to the box", shadowAlpha(31, 31) >= 250)
H.check("cell 0: gone at the far corner", shadowAlpha(0, 0), 0)
H.checkTrue("cell 0: fades", shadowAlpha(31, 16) > 0 and shadowAlpha(31, 16) < 255)
H.check("cell 8: full inside the rounded part", shadowAlpha(8 * 32 + 20, 31), 255)
H.check("cell 8: gone at the far corner", shadowAlpha(8 * 32, 0), 0)
H.check("shadow black", shadow:byte(19) + shadow:byte(20) + shadow:byte(21), 0)

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, B = ns.Config, ns.Border
local f = ns.Frames.target
-- Two rings, each on a plain holder frame of its own: one around the
-- frame, one around the unit box (frame plus the docked castbar's slot).
-- Which one shows follows the castbar; nothing is re-anchored for that.
local box = f.frameRing
local b = box.border
local unit = f.unitBox
local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

-- Default: one pixel, no padding, square: the ring hugs the frame.
H.check("extent", B.Extent("target"), 1)
H.check("top edge thickness", b[1]:GetHeight(), 1)
H.check("top edge on the box", point(b[1], "BOTTOMLEFT")[2], box)
H.check("top edge from the box's left", point(b[1], "BOTTOMLEFT")[4], 0)
H.check("top edge right on the box's top", point(b[1], "BOTTOMLEFT")[5], 0)
H.check("left edge", point(b[3], "TOPRIGHT")[4], 0)
H.check("corner square", b.corners[1]:GetWidth(), 1)
H.check("corner outside the box", point(b.corners[1], "TOPLEFT")[4], -1)
H.check("corner outside the box (y)", point(b.corners[1], "TOPLEFT")[5], 1)
H.check("square corners unmasked", b.corners[1]:GetNumMaskTextures(), 0)
H.checkTrue("shown", b[1]:IsShown() and b.corners[4]:IsShown())
H.check("colour", b[2]._color[4], 1)
H.check("flat: no gradient", b[1]._gradient, nil)
H.check("flat: no inner line", b.line[1]:IsShown(), false)
H.check("no shadow by default", box.shadow[1]:IsShown(), false)

-- The frame ring's holder covers the frame; the unit box takes in the
-- docked castbar's slot for good (target: docked below).
local reach = ns.Castbar.Height("target")
H.check("frame holder on the frame", box._allPoints, f)
H.check("block holder on the unit box", f.blockRing._allPoints, unit)
H.check("unit box: the castbar's slot below", point(unit, "BOTTOMRIGHT")[5], -reach)
H.check("unit box top on the frame", point(unit, "TOPLEFT")[5], 0)
H.check("idle castbar: frame ring", box:IsShown(), true)
H.check("idle castbar: no block ring", f.blockRing:IsShown(), false)

-- The class badge stays above ring and shadow: they are textures of
-- plain holders just above the frame, the badge is 20 levels up.
H.check("ring on its holder", b[1]:GetParent(), box)
H.check("holder a plain child of the frame", box:GetParent(), f)
H.check("shadow on the holder", box.shadow[1]:GetParent(), box)
H.check("badge above", f.classBadge:GetFrameLevel(), f:GetFrameLevel() + 20)
H.checkTrue("badge above the holders", f.classBadge:GetFrameLevel() > f.blockRing:GetFrameLevel())

-- Thicker, padded.
C.Set("general", "borderSize", 4)
C.Set("general", "borderPadding", 2)
H.check("extent adds up", B.Extent("target"), 6)
H.check("thick edge", b[1]:GetHeight(), 4)
H.check("edge padded away", point(b[1], "BOTTOMLEFT")[5], 2)
H.check("edge between the corners", point(b[1], "BOTTOMLEFT")[4], -2)
H.check("left edge padded", point(b[3], "TOPRIGHT")[4], -2)
H.check("corner square size", b.corners[1]:GetWidth(), 4)
H.check("corner at the ring's corner", point(b.corners[4], "BOTTOMRIGHT")[4], 6)
H.check("corner at the ring's corner (y)", point(b.corners[4], "BOTTOMRIGHT")[5], -6)

-- Rounded: corner squares as big as the outer radius. The outer arc is
-- their texture, the inner arc their one mask.
C.Set("general", "cornerRadius", 5)
local corner = b.corners[1]
H.check("round corner size", corner:GetWidth(), 5 + 6)
H.check("round: edge starts after the corner", point(b[1], "BOTTOMLEFT")[4], 5)
H.check("round: one mask", corner:GetNumMaskTextures(), 1)
H.check("outer arc: the corner's texture", corner._texture, ns.Corners.TEXTURE)
H.check("outer arc clamps", corner._wrap[1], "CLAMP")
H.check("outer arc mirrored for the bottom right", table.concat(b.corners[4]._texCoord, ","),
    table.concat(ns.Corners.COORDS[4], ","))
H.check("inner arc file", b.inner[1]._texture, ns.Corners.INVERSE[1])
H.check("the mask is the inner arc", corner._masks[1], b.inner[1])
H.check("inner arc inset by the thickness", point(b.inner[1], "TOPLEFT")[4], 4)
H.check("inner arc inset by the thickness (y)", point(b.inner[1], "TOPLEFT")[5], -4)
H.check("inner arc size", b.inner[1]:GetWidth(), 7)
H.check("mirrored for the bottom right", point(b.inner[4], "BOTTOMRIGHT")[4], -4)
C.Set("general", "cornerRadius", 6)
H.check("restyle keeps one mask", corner:GetNumMaskTextures(), 1)
C.Set("general", "cornerRadius", 0)
H.check("square again: mask off", corner:GetNumMaskTextures(), 0)
H.check("square again: a plain square", corner._texture, nil)

-- Per frame override, and off.
C.Set("target", "borderSize", 0)
H.check("override: off", b[1]:IsShown(), false)
H.check("override: corners off", b.corners[1]:IsShown(), false)
H.check("no border: no extent", B.Extent("target"), 0)
H.checkTrue("other frames keep theirs", ns.Frames.player.frameRing.border[1]:IsShown())
C.Set("target", "borderSize", 4)
C.Set("target", "borderColor", { 1, 0, 0, 1 })
H.check("own colour", b[1]._color[1], 1)
H.check("own colour on corners", b.corners[2]._color[1], 1)

-- The show toggle: the ring goes, size and padding stay as they are.
C.Set("target", "borderShow", false)
H.check("hidden: edges", b[1]:IsShown(), false)
H.check("hidden: corners", b.corners[3]:IsShown(), false)
H.check("hidden: no extent", B.Extent("target"), 0)
H.check("hidden: size 0", B.Size("target"), 0)
H.check("hidden: size setting kept", C.Get("target", "borderSize"), 4)
C.Set("target", "borderShow", true)
H.check("shown again", b[1]:IsShown(), true)

-- Gold: lit from above, one continuous vertical shading over the whole
-- ring: light at the top, dark at the bottom, with a dark line along the
-- inside; the colour setting is not used.
local function colour(c)
    if c.r then return ("%.3f,%.3f,%.3f"):format(c.r, c.g, c.b) end
    return ("%.3f,%.3f,%.3f"):format(c[1], c[2], c[3])
end
local function mix(a, z, t)
    return { a[1] + (z[1] - a[1]) * t, a[2] + (z[2] - a[2]) * t, a[3] + (z[3] - a[3]) * t }
end
local function shade(piece) -- bottom colour, top colour of a vertical gradient
    local g = piece._gradient
    H.check("vertical gradient", g and g[1], "VERTICAL")
    return g and colour(g[2]), g and colour(g[3])
end
C.Set("target", "borderStyle", "GOLD")
local G = B.GOLD
local function checkGold(label, corner)
    local t = 4 / corner -- the edges are 4 thick, the corner squares `corner`
    local low, high = shade(b[1])
    H.check(label .. "top edge: light outside", high, colour(G.LIGHT))
    H.check(label .. "top edge: as far down the fade as it reaches", low, colour(mix(G.LIGHT, G.MID, t)))
    low, high = shade(b.corners[1])
    H.check(label .. "top corner: light to mid over its height", low .. " " .. high, colour(G.MID) .. " " .. colour(G.LIGHT))
    H.check(label .. "top right corner the same", shade(b.corners[2]), colour(G.MID))
    low, high = shade(b[3])
    H.check(label .. "left edge: from the corner's mid", high, colour(G.MID))
    H.check(label .. "left edge: down to the shade", low, colour(G.SHADE))
    H.check(label .. "right edge the same", shade(b[4]), colour(G.SHADE))
    low, high = shade(b.corners[3])
    H.check(label .. "bottom corner: shade to dark", low .. " " .. high, colour(G.DARK) .. " " .. colour(G.SHADE))
    low, high = shade(b[2])
    H.check(label .. "bottom edge: dark outside", low, colour(G.DARK))
    H.check(label .. "bottom edge: as far up the fade as it reaches", high, colour(mix(G.DARK, G.SHADE, t)))
end
checkGold("square: ", 4)
H.check("white base under the gradient", b[1]._texColor and b[1]._texColor[1], 1)
local line = b.line
H.checkTrue("inner line shown", line[1]:IsShown() and line.corners[1]:IsShown())
H.check("inner line one pixel", line[1]:GetHeight(), 1)
H.check("inner line on the inside of the ring", point(line[1], "BOTTOMLEFT")[5], 2)
H.check("inner line dark", line[1]._color[1], B.GOLD.LINE[1])
H.check("inner line over the ring", select(2, line[1]:GetDrawLayer()) > select(2, b[1]:GetDrawLayer()), true)
C.Set("target", "cornerRadius", 5)
checkGold("round: ", 5 + 6)
H.check("gold, round: ring corner masked", b.corners[1]:GetNumMaskTextures(), 1)
H.check("gold, round: inner line corner masked", line.corners[1]:GetNumMaskTextures(), 1)
H.check("inner line concentric: its corner", line.corners[1]:GetWidth(), 5 + 2 + 1)
H.check("inner line concentric: its inner arc", line.inner[1]:GetWidth(), 5 + 2)
C.Set("target", "cornerRadius", 0)
C.Set("target", "borderSize", 1)
H.check("one pixel gold: no inner line", line[1]:IsShown(), false)
C.Set("target", "borderSize", 4)
C.Set("target", "borderStyle", "FLAT")
H.check("flat again: gradient gone", b[1]._gradient, nil)
H.check("flat again: own colour", b[1]._color[1], 1)
H.check("flat again: inner line hidden", line[1]:IsShown(), false)
C.ClearOverride("target", "borderColor")

-- Drop shadow: soft pieces around the ring, none under the frame.
local sh = box.shadow
C.Set("target", "shadowEnabled", true)
C.Set("target", "shadowSize", 5)
C.Set("target", "shadowAlpha", 40)
H.checkTrue("shadow shown", sh[1]:IsShown() and sh.corners[1]:IsShown())
H.check("shadow file", sh[1]._texture, B.SHADOW)
H.check("shadow behind everything", sh[1]:GetDrawLayer(), "BACKGROUND")
H.check("shadow lowest sublevel", select(2, sh[1]:GetDrawLayer()), -8)
H.check("shadow strength", sh[1]._color[4], 0.4)
H.check("shadow black", sh[1]._color[1] + sh[1]._color[2] + sh[1]._color[3], 0)
H.check("top shadow height", sh[1]:GetHeight(), 5)
H.check("top shadow on the ring", point(sh[1], "BOTTOMLEFT")[5], 6)
H.check("top shadow between the corners", point(sh[1], "BOTTOMLEFT")[4], -6)
H.check("shadow corner size", sh.corners[1]:GetWidth(), 5)
H.check("shadow corner outside the ring", point(sh.corners[1], "TOPLEFT")[4], -11)
H.check("square shadow corner: first cell", sh.corners[1]._texCoord[1], 0.5 / 512)
H.check("square shadow corner unmasked", sh.corners[1]:GetNumMaskTextures(), 0)
H.check("mirrored for the bottom right", sh.corners[4]._texCoord[1], 31.5 / 512)
-- Rounded: the corner pieces reach in to the ring's rounded centre, a
-- cell whose fade starts at the ring's radius, masked off inside it.
C.Set("target", "cornerRadius", 5)
local round = 5 + 6
H.check("round shadow corner size", sh.corners[1]:GetWidth(), round + 5)
local cell = math.floor(round / (round + 5) * 16 + 0.5)
H.check("round shadow cell", sh.corners[1]._texCoord[1], (cell * 32 + 0.5) / 512)
H.check("round shadow corner masked", sh.corners[1]:GetNumMaskTextures(), 1)
H.check("mask: the inverse arc", sh.inner[1]._texture, ns.Corners.INVERSE[1])
H.check("mask: bottom right has its own file", sh.inner[4]._texture, ns.Corners.INVERSE[4])
H.check("mask: the ring's radius", sh.inner[1]:GetWidth(), round)
H.check("mask: at the rounded centre", point(sh.inner[1], "BOTTOMRIGHT")[2], sh.corners[1])
H.check("round: top shadow starts after the corner", point(sh[1], "BOTTOMLEFT")[4], 5)
C.Set("target", "cornerRadius", 0)
H.check("square again: mask off", sh.corners[1]:GetNumMaskTextures(), 0)
C.Set("target", "borderShow", false)
H.check("shadow without a border: on the box", point(sh[1], "BOTTOMLEFT")[5], 0)
C.Set("target", "borderShow", true)
C.Set("target", "shadowEnabled", false)
H.check("shadow off", sh[1]:IsShown(), false)
H.check("shadow corners off", sh.corners[2]:IsShown(), false)

-- A docked castbar joins the block while it shows: the block ring shows
-- instead of the frame ring, the frame's corners next to the castbar go
-- square (the frame's mask swaps to a file with only the top corners
-- round), the castbar's mask rounds the block's corners below.
local bar = f.castbar
local blockRing = f.blockRing
local frameMask = f.clip.mask
C.Set("general", "cornerRadius", 6)
H.check("frame mask over the frame", frameMask._allPoints, f)
H.check("frame textures: one mask", f.healthBg:GetNumMaskTextures(), 1)
H.check("docked castbar mask over the unit box", bar.clip.mask._allPoints, unit)
H.check("docked castbar: one mask", bar.bg:GetNumMaskTextures(), 1)
local function joined()
    return blockRing:IsShown() and not box:IsShown() and frameMask:IsShown()
        and frameMask._texture == ns.Corners.MASKS.TOP
end
local function apart()
    return box:IsShown() and not blockRing:IsShown() and frameMask:IsShown()
        and frameMask._texture == ns.Corners.MASKS.ALL
end
H.checkTrue("idle: the frame alone", apart())

-- One consistent ring: every piece of the shown ring hangs from its own
-- holder (which covers the right box), edges end where the corner pieces
-- begin, and each corner piece is a convex arc for its own corner (the
-- outer arc mirrored by texture coordinates, the inner cut a mask file
-- drawn for that corner: masks ignore texture coordinates in the client).
local function ringConsistent(label, holder, boxWanted)
    H.check(label .. ": holder over the right box", holder._allPoints, boxWanted)
    local ring = holder.border
    local reach = B.Extent("target")
    local corner = ring.corners[1]:GetWidth()
    for i = 1, 4 do
        for j = 1, #ring[i]._points do
            local p = { ring[i]:GetPoint(j) }
            H.check(label .. ": edge " .. i .. " on its holder", p[2], holder)
            local along = (i <= 2) and math.abs(p[4]) or math.abs(p[5])
            H.check(label .. ": edge " .. i .. " meets the corner", along, corner - reach)
        end
        local c = ring.corners[i]
        local p = { c:GetPoint(1) }
        H.check(label .. ": corner " .. i .. " on its holder", p[2], holder)
        H.check(label .. ": corner " .. i .. " in its corner", p[1] .. p[3],
            ns.Corners.POINTS[i] .. ns.Corners.POINTS[i])
        H.check(label .. ": corner " .. i .. " outer arc", c._texture, ns.Corners.TEXTURE)
        H.check(label .. ": corner " .. i .. " mirrored", table.concat(c._texCoord, ","),
            table.concat(ns.Corners.COORDS[i], ","))
        H.check(label .. ": corner " .. i .. " inner cut for its corner", c._masks and c._masks[1]._texture,
            ns.Corners.INVERSE[i])
        H.check(label .. ": corner " .. i .. " inner cut unmirrored", c._masks and c._masks[1]._texCoord, nil)
    end
end
ringConsistent("frame ring", box, f)
ringConsistent("block ring", blockRing, unit)
M.units.target = { name = "Foe", health = 1, healthMax = 1,
    cast = { name = "Bolt", texture = 1, startMs = 1000000, endMs = 1002000 } }
M.FireEvent("UNIT_SPELLCAST_START", "target", "c1", 1)
H.checkTrue("casting: one block", joined())
H.check("docked castbar: no border of its own", bar.border == nil or not bar.border[1]:IsShown(), true)
-- One more row of the frame, flush against it.
H.check("docked castbar right under the frame", point(bar, "TOPLEFT")[5], 0)
M.units.target.cast = nil
M.FireEvent("UNIT_SPELLCAST_STOP", "target", "c1", 1)
H.checkTrue("cast over: the frame alone again", apart())

-- The castbar can hide while the frame is hidden (no OnHide then in the
-- client); showing the frame again still brings back the frame alone.
M.units.target.cast = { name = "Bolt", texture = 1, startMs = 1000000, endMs = 1002000 }
M.FireEvent("UNIT_SPELLCAST_START", "target", "c1", 1)
H.checkTrue("casting again", joined())
f:Hide()
M.units.target.cast = nil
M.FireEvent("UNIT_SPELLCAST_STOP", "target", "c1", 1)
f:Show()
H.checkTrue("hidden while the cast ended: the frame alone", apart())
f:Hide()
bar:Show() -- a castbar shown while its frame was hidden
f:Show()
H.checkTrue("frame shown again: follows the castbar", joined())
ns.Castbar.Stop(bar)

-- In combat nothing is anchored: switching only shows and hides plain
-- holders and swaps the frame mask's file.
local function guard(region)
    for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetAllPoints", "SetSize" }) do
        local original = region[method]
        region[method] = function(self, ...)
            assert(not M.combat, "re-anchored in combat")
            return original(self, ...)
        end
    end
end
for _, region in ipairs({ unit, box, blockRing, frameMask, bar.clip.mask }) do
    guard(region)
end
M.combat = true
M.units.target.cast = { name = "Bolt", texture = 1, startMs = 1000000, endMs = 1002000 }
M.FireEvent("UNIT_SPELLCAST_START", "target", "c1", 1)
H.checkTrue("combat cast: one block", joined())
M.units.target.cast = nil
M.FireEvent("UNIT_SPELLCAST_STOP", "target", "c1", 1)
H.checkTrue("combat stop: the frame alone", apart())
M.SetCombat(false)

-- Above: the slot moves to the top, the frame's top corners go square.
C.Set("target", "castbarPosition", "ABOVE")
H.check("above: unit box grows upwards", point(unit, "TOPLEFT")[5], reach)
H.check("above: bottom on the frame", point(unit, "BOTTOMRIGHT")[5], 0)
ns.Castbar.Preview(f, true)
H.check("above: only the frame's bottom corners round", frameMask._texture, ns.Corners.MASKS.BOTTOM)
ns.Castbar.Preview(f, false)
H.check("above, idle: all four round", frameMask._texture, ns.Corners.MASKS.ALL)
C.Set("target", "castbarPosition", "BELOW")

-- Room for the border in the docked depth (party spacing uses it).
H.check("docked depth counts the whole ring", ns.Castbar.DockedDepth("target"),
    ns.Castbar.Height("target") + 6)

-- The radius never exceeds half the box's shorter side.
H.check("clamp helper", ns.Corners.Clamp(12, 220, 8), 4)
H.check("clamp helper: fits", ns.Corners.Clamp(3, 220, 8), 3)
C.Set("target", "height", 8)
C.Set("target", "cornerRadius", 12)
H.check("low frame: mask clamped", f.clip.mask:GetScale(), 4 / ns.Corners.SLICE)
H.check("low frame: ring corner clamped", b.corners[1]:GetWidth(), 4 + 6)
local sideInset = -point(b[3], "TOPRIGHT")[5]
H.check("low frame: left edge from corner to corner", sideInset, 4)
H.checkTrue("ring edge never negative", f:GetHeight() - 2 * sideInset >= 0)
C.ClearOverride("target", "height")
-- A docked castbar's row holds its whole arc: the frame's corners next to
-- it are square while it shows, so the radius never exceeds its height.
C.Set("target", "castbarHeight", 5)
H.check("low castbar: radius clamped to its row", ns.Shape.Radius(f), 5)
H.check("low castbar: frame mask", f.clip.mask:GetScale(), 5 / ns.Corners.SLICE)
H.check("low castbar: castbar mask", bar.clip.mask:GetScale(), 5 / ns.Corners.SLICE)
H.check("low castbar: ring corner", b.corners[1]:GetWidth(), 5 + 6)
C.Set("target", "castbarEnabled", false)
H.check("castbar off: the frame's radius again", ns.Shape.Radius(f), 12)
C.ClearOverride("target", "castbarEnabled")
C.ClearOverride("target", "castbarHeight")

-- Detached: the castbar has its own ring around bar and icon.
C.Set("target", "castbarPosition", "DETACHED")
ns.Castbar.Preview(f, true)
H.checkTrue("detached: own border", bar.border and bar.border[1]:IsShown())
H.check("detached: around the castbar box", point(bar.border[1], "BOTTOMLEFT")[2], bar.box)
H.check("detached: unit box without castbar", point(unit, "TOPLEFT")[5], 0)
H.check("detached: unit box bottom without castbar", point(unit, "BOTTOMRIGHT")[5], 0)
H.checkTrue("detached: the frame ring", box:IsShown() and not blockRing:IsShown())
H.check("detached: mask on its own box", bar.clip.mask._allPoints, bar.box)
H.check("detached: radius clamped to the castbar (16 high)", bar.clip.mask:GetScale(), 8 / ns.Corners.SLICE)
H.check("detached: ring clamped too", bar.border.corners[1]:GetWidth(), 8 + 6)
H.check("detached: no docked depth", ns.Castbar.DockedDepth("target"), 0)
C.Set("target", "castbarPosition", "BELOW")
H.check("docked again: castbar ring hidden", bar.border[1]:IsShown(), false)
ns.Castbar.Preview(f, false)
C.ClearOverride("target", "cornerRadius")

-- "Always show": the empty castbar belongs to the block all the time.
C.Set("target", "castbarAlwaysShow", true)
H.checkTrue("always shown: one block", joined())
C.Set("target", "castbarAlwaysShow", false)
H.checkTrue("not always: the frame alone", apart())

-- Auras anchored to the unit block land outside the ring.
local debuffs = f.auras.debuffs
local _, rel, _, x, y = debuffs.holder:GetPoint(1)
H.check("auras on the unit box", rel, unit)
H.check("auras above the ring", y, C.Get("target", "debuffsY") + B.Extent("target"))
H.check("x along the edge unchanged", x, 0)
C.Set("target", "debuffsFramePoint", "BOTTOMLEFT")
C.Set("target", "debuffsPoint", "TOPLEFT")
_, rel, _, x, y = debuffs.holder:GetPoint(1)
H.check("below the ring (under the castbar's slot)", y, C.Get("target", "debuffsY") - B.Extent("target"))
C.Set("target", "debuffsAnchor", "CASTBAR")
_, rel, _, x, y = debuffs.holder:GetPoint(1)
H.check("castbar anchor: its whole box", rel, bar.box)
H.check("castbar's outer edge: pushed", y, C.Get("target", "debuffsY") - B.Extent("target"))
C.Set("target", "debuffsFramePoint", "TOPLEFT")
C.Set("target", "debuffsPoint", "BOTTOMLEFT")
_, rel, _, x, y = debuffs.holder:GetPoint(1)
H.check("castbar's edge on the frame: no ring there, no push", y, C.Get("target", "debuffsY"))
C.Set("target", "debuffsFramePoint", "RIGHT")
C.Set("target", "debuffsPoint", "LEFT")
_, rel, _, x = debuffs.holder:GetPoint(1)
H.check("castbar's outer side: pushed", x, C.Get("target", "debuffsX") + B.Extent("target"))
C.Set("target", "castbarPosition", "DETACHED")
C.Set("target", "debuffsFramePoint", "TOPLEFT")
C.Set("target", "debuffsPoint", "BOTTOMLEFT")
_, rel, _, x, y = debuffs.holder:GetPoint(1)
H.check("detached castbar: ringed all round", y, C.Get("target", "debuffsY") + B.Extent("target"))
C.Set("target", "debuffsAnchor", "HEALTH")
_, rel, _, x, y = debuffs.holder:GetPoint(1)
H.check("inner regions: no push", y, C.Get("target", "debuffsY"))
C.ResetScope("target")

-- The options highlight sits outside the whole ring.
C.Set("general", "borderSize", 4)
ns.Options.Open("target")
local hl = f.optionsHighlight
H.check("highlight outside the border", point(hl[1], "BOTTOMLEFT")[5], B.Extent("target"))
H.check("highlight around the unit box", point(hl[1], "BOTTOMLEFT")[2], unit)
M.RunTimers()
