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
local b = f.border
local box = f.unitBox
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
H.check("no shadow by default", f.shadow[1]:IsShown(), false)

-- The box is the frame while no castbar shows.
H.check("idle castbar: box bottom on the frame", point(box, "BOTTOMRIGHT")[5], 0)
H.check("box top on the frame", point(box, "TOPLEFT")[5], 0)

-- The class badge stays above ring and shadow: they are textures of the
-- frame itself, the badge is a frame 20 levels up.
H.check("ring drawn by the frame", b[1]:GetParent(), f)
H.check("shadow drawn by the frame", f.shadow[1]:GetParent(), f)
H.check("badge above", f.classBadge:GetFrameLevel(), f:GetFrameLevel() + 20)

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

-- Rounded: corner squares as big as the outer radius, masked twice.
C.Set("general", "cornerRadius", 5)
local corner = b.corners[1]
H.check("round corner size", corner:GetWidth(), 5 + 6)
H.check("round: edge starts after the corner", point(b[1], "BOTTOMLEFT")[4], 5)
H.check("round: two masks", corner:GetNumMaskTextures(), 2)
H.check("outer arc file", b.outer[1]._texture, ns.Corners.TEXTURE)
H.check("inner arc file", b.inner[1]._texture, ns.Corners.INVERSE)
H.check("outer arc on the corner", point(b.outer[1], "TOPLEFT")[2], corner)
H.check("outer arc size", b.outer[1]:GetWidth(), 11)
H.check("inner arc inset by the thickness", point(b.inner[1], "TOPLEFT")[4], 4)
H.check("inner arc inset by the thickness (y)", point(b.inner[1], "TOPLEFT")[5], -4)
H.check("inner arc size", b.inner[1]:GetWidth(), 7)
H.check("mirrored for the bottom right", point(b.inner[4], "BOTTOMRIGHT")[4], -4)
C.Set("general", "cornerRadius", 6)
H.check("restyle keeps two masks", corner:GetNumMaskTextures(), 2)
C.Set("general", "cornerRadius", 0)
H.check("square again: masks off", corner:GetNumMaskTextures(), 0)

-- Per frame override, and off.
C.Set("target", "borderSize", 0)
H.check("override: off", b[1]:IsShown(), false)
H.check("override: corners off", b.corners[1]:IsShown(), false)
H.check("no border: no extent", B.Extent("target"), 0)
H.checkTrue("other frames keep theirs", ns.Frames.player.border[1]:IsShown())
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

-- Gold: bevelled, lighter at the top and left, darker at the bottom and
-- right, a dark line along the inside; the colour setting is not used.
local function colour(c)
    if c.r then return ("%.2f,%.2f,%.2f"):format(c.r, c.g, c.b) end
    return ("%.2f,%.2f,%.2f"):format(c[1], c[2], c[3])
end
C.Set("target", "borderStyle", "GOLD")
local g = b[1]._gradient
H.check("top edge: vertical gradient", g and g[1], "VERTICAL")
H.check("top edge: light outside (top)", g and colour(g[3]), colour(B.GOLD.LIGHT))
H.check("top edge: gold inside (bottom)", g and colour(g[2]), colour(B.GOLD.MID))
g = b[2]._gradient
H.check("bottom edge: dark outside (bottom)", g and colour(g[2]), colour(B.GOLD.DARK))
g = b[3]._gradient
H.check("left edge: horizontal", g and g[1], "HORIZONTAL")
H.check("left edge: light outside (left)", g and colour(g[2]), colour(B.GOLD.LIGHT))
g = b[4]._gradient
H.check("right edge: dark outside (right)", g and colour(g[3]), colour(B.GOLD.DARK))
H.checkTrue("corners shaded too", b.corners[1]._gradient and b.corners[4]._gradient)
H.check("white base under the gradient", b[1]._texColor and b[1]._texColor[1], 1)
local line = b.line
H.checkTrue("inner line shown", line[1]:IsShown() and line.corners[1]:IsShown())
H.check("inner line one pixel", line[1]:GetHeight(), 1)
H.check("inner line on the inside of the ring", point(line[1], "BOTTOMLEFT")[5], 2)
H.check("inner line dark", line[1]._color[1], B.GOLD.LINE[1])
H.check("inner line over the ring", select(2, line[1]:GetDrawLayer()) > select(2, b[1]:GetDrawLayer()), true)
C.Set("target", "cornerRadius", 5)
H.check("gold, round: ring corner masked", b.corners[1]:GetNumMaskTextures(), 2)
H.check("gold, round: inner line corner masked", line.corners[1]:GetNumMaskTextures(), 2)
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
local sh = f.shadow
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
H.check("mask: the inverse arc", sh.inner[1]._texture, ns.Corners.INVERSE)
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

-- A docked castbar joins the box while it shows.
local bar = f.castbar
M.units.target = { name = "Foe", health = 1, healthMax = 1,
    cast = { name = "Bolt", texture = 1, startMs = 1000000, endMs = 1002000 } }
M.FireEvent("UNIT_SPELLCAST_START", "target", "c1", 1)
local reach = ns.Castbar.Gap("target") + ns.Castbar.Height("target")
H.check("casting: box takes the castbar in", point(box, "BOTTOMRIGHT")[5], -reach)
H.check("docked castbar: no border of its own", bar.border == nil or not bar.border[1]:IsShown(), true)
-- One more row of the frame: the same seam as between its own rows.
H.check("docked seam: the rows' gap", ns.Castbar.Gap("target"), f.gap)
H.check("docked castbar right under the frame", point(bar, "TOPLEFT")[5], -f.gap)
M.units.target.cast = nil
M.FireEvent("UNIT_SPELLCAST_STOP", "target", "c1", 1)
H.check("cast over: box back to the frame", point(box, "BOTTOMRIGHT")[5], 0)
C.Set("target", "castbarPosition", "ABOVE")
ns.Castbar.Preview(f, true)
H.check("above: box grows upwards", point(box, "TOPLEFT")[5], reach)
H.check("above: bottom on the frame", point(box, "BOTTOMRIGHT")[5], 0)
ns.Castbar.Preview(f, false)

-- Room for the border in the docked depth (party spacing uses it).
H.check("docked depth counts the whole ring", ns.Castbar.DockedDepth("target"),
    ns.Castbar.Gap("target") + ns.Castbar.Height("target") + 6)

-- Rounded as one block: the masks sit in the unit box's corners, so the
-- frame's corners next to a shown castbar stay square and the castbar's
-- outer corners are round.
C.Set("target", "castbarPosition", "BELOW")
C.Set("general", "cornerRadius", 6)
H.check("frame masks on the unit box", select(2, f.clip.masks[3]:GetPoint(1)), box)
H.check("docked castbar masks on the unit box", select(2, bar.clip.masks[4]:GetPoint(1)), box)
H.check("docked castbar still rounded", bar.bg:GetNumMaskTextures(), 4)
ns.Castbar.Preview(f, true)
H.check("castbar shows: box to its bottom", point(box, "BOTTOMRIGHT")[5], -reach)
ns.Castbar.Preview(f, false)
H.check("castbar gone: box is the frame, frame corners round again", point(box, "BOTTOMRIGHT")[5], 0)
C.Set("general", "cornerRadius", 0)

-- Detached: the castbar has its own ring around bar and icon.
C.Set("target", "castbarPosition", "DETACHED")
ns.Castbar.Preview(f, true)
H.checkTrue("detached: own border", bar.border and bar.border[1]:IsShown())
H.check("detached: around the castbar box", point(bar.border[1], "BOTTOMLEFT")[2], bar.box)
H.check("detached: frame box without castbar", point(box, "TOPLEFT")[5], 0)
H.check("detached: frame box bottom without castbar", point(box, "BOTTOMRIGHT")[5], 0)
H.check("detached: masks on its own box", select(2, bar.clip.masks[1]:GetPoint(1)), bar.box)
H.check("detached: old gap no longer used", ns.Castbar.DockedDepth("target"), 0)
C.Set("target", "castbarPosition", "BELOW")
H.check("docked again: castbar ring hidden", bar.border[1]:IsShown(), false)
ns.Castbar.Preview(f, false)

-- "Always show": the empty castbar belongs to the block all the time.
C.Set("target", "castbarAlwaysShow", true)
H.check("always shown: box takes it in", point(box, "BOTTOMRIGHT")[5], -reach)
C.Set("target", "castbarAlwaysShow", false)
H.check("not always: box back", point(box, "BOTTOMRIGHT")[5], 0)

-- Auras anchored to the unit block land outside the ring.
local debuffs = f.auras.debuffs
local _, rel, _, x, y = debuffs.holder:GetPoint(1)
H.check("auras on the unit box", rel, box)
H.check("auras above the ring", y, C.Get("target", "debuffsY") + B.Extent("target"))
H.check("x along the edge unchanged", x, 0)
C.Set("target", "debuffsFramePoint", "BOTTOMLEFT")
C.Set("target", "debuffsPoint", "TOPLEFT")
_, rel, _, x, y = debuffs.holder:GetPoint(1)
H.check("below the ring", y, C.Get("target", "debuffsY") - B.Extent("target"))
C.Set("target", "debuffsAnchor", "CASTBAR")
_, rel = debuffs.holder:GetPoint(1)
H.check("castbar anchor: its whole box", rel, bar.box)
C.Set("target", "debuffsAnchor", "HEALTH")
_, rel, _, x, y = debuffs.holder:GetPoint(1)
H.check("inner regions: no push", y, C.Get("target", "debuffsY"))
C.ResetScope("target")

-- The options highlight sits outside the whole ring.
C.Set("general", "borderSize", 4)
ns.Options.Open("target")
local hl = f.optionsHighlight
H.check("highlight outside the border", point(hl[1], "BOTTOMLEFT")[5], B.Extent("target"))
H.check("highlight around the unit box", point(hl[1], "BOTTOMLEFT")[2], box)
M.RunTimers()
