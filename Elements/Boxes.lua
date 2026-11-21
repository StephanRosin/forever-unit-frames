local _, ns = ...

-- The frame's parts standing apart (spacing*, a CurseForge wish): title
-- row, portrait, health bar (its overheal lane included), power bar and
-- footer each get their own ring, drop shadow and theme backdrop, so the
-- gaps between them show nothing (Units/Single.lua lays out the gaps,
-- Elements/Shape.lua and Elements/ThemeArt.lua drop the frame's own ring,
-- backdrop and shadow). A docked castbar and the threat bar draw their
-- own ring here too (Elements/Castbar.lua, Elements/ThreatBar.lua).
--
-- The ring: the parts' own border (boxBorder*: flat, one colour, no
-- padding), independent of the frame's. Under a theme other than CLASSIC
-- the theme's border art stays (the frame's border settings, which the
-- theme sets); only boxBorderShow applies there.
--
-- Per part, made when first needed: a ring holder, anchored on the part;
-- below the frame its backdrop holder, and below that its shadow holder,
-- so no part's shadow falls on its neighbour's backdrop. Ornaments, the
-- rule, the glows and the elite ring stay the whole frame's. With
-- spacingFill one plate lies behind all parts and fills the gaps.
local Boxes = { name = "Boxes" }
ns.Boxes = Boxes

local Config = ns.Config

-- Apart, a part's textures are rounded only at the frame's outer corners
-- (the one mask, Core/Corners.lua), yet its ring at all four: a square
-- corner stays under the ring while radius * (sqrt 2 - 1) <= the ring's
-- reach.
local SQUARE_CORNER = math.sqrt(2) - 1

-- Whether the parts take their own plain border (CLASSIC), not the theme's.
function Boxes.Plain()
    return Config.Get("general", "theme") == ns.Themes.CLASSIC
end

-- How far a part's ring reaches out from it; 0 without one.
function Boxes.Extent(scope)
    if not Config.Get(scope, "boxBorderShow") then return 0 end
    if not Boxes.Plain() then return ns.Border.Extent(scope) end
    return ns.Pixel.Snap(Config.Get(scope, "boxBorderSize"), nil, 1)
end

-- The parts' corner radius before clamping to a part (see SQUARE_CORNER).
function Boxes.Radius(scope)
    local radius = Boxes.Plain() and Config.Get(scope, "boxCornerRadius") or ns.Corners.Radius(scope)
    return math.min(math.floor(radius), math.floor(Boxes.Extent(scope) / SQUARE_CORNER + 1e-6))
end

-- Draws the parts' ring on owner around box (w x h), its shadow on
-- shadowOwner (optional); returns the radius used, for the box's mask.
function Boxes.DrawRing(owner, frame, box, w, h, shadowOwner)
    local scope = frame.key
    local radius = ns.Corners.Clamp(Boxes.Radius(scope), w, h)
    local own = { shadowOwner = shadowOwner }
    if not Config.Get(scope, "boxBorderShow") then
        own.size = 0
    elseif Boxes.Plain() then
        own.size, own.color = Boxes.Extent(scope), Config.Get(scope, "boxBorderColor")
    end
    local id = frame.themeOf and frame.themeOf() or ns.Themes.Current()
    ns.Border.Draw(owner, scope, box, radius, ns.Themes.Rim(id), own)
    return radius
end

local function newBox(frame)
    local level = frame:GetFrameLevel()
    local ring = CreateFrame("Frame", nil, frame)
    local under = CreateFrame("Frame", nil, frame)
    under:SetFrameLevel(math.max(level - 1, 0))
    local shade = CreateFrame("Frame", nil, frame)
    shade:SetFrameLevel(math.max(level - 2, 0))
    local back = under:CreateTexture(nil, "BACKGROUND")
    ns.Corners.Add(under, back)
    return {
        ring = ring, under = under, shade = shade, back = back, clip = ns.Corners.Clipper(under),
        hard = shade:CreateTexture(nil, "BACKGROUND", nil, -7),
    }
end

local function showBox(box, shown)
    box.ring:SetShown(shown)
    box.under:SetShown(shown)
    box.shade:SetShown(shown)
end

-- The parts that show: name, region, extra width beside it (the overheal
-- lane: right of it, left when negative, as with reversed bars), width and height (the layout's numbers: the regions'
-- own sizes may not be known yet), extra height (the lane of vertical
-- bars: above it, below when negative).
function Boxes.Parts(frame)
    local parts = {}
    local function add(name, region, extra, w, h, extraY)
        parts[#parts + 1] = { name, region, extra, w, h, extraY or 0 }
    end
    if frame.titleHeight > 0 then add("title", frame.title, 0, frame.titleWidth, frame.titleHeight) end
    local mode = Config.Get(frame.key, "portraitMode")
    if mode == "TOP" then
        add("portrait", frame.portraitBg, 0, frame.footerWidth, frame.portraitStrip)
    elseif mode ~= "OFF" then
        add("portrait", frame.portraitBg, 0, frame.layoutHeight, frame.layoutHeight)
    end
    local lane = frame.overhealLane or 0
    local fill = ns.Layout.FillOf(frame.key)
    local side = (fill.finish == "RIGHT" or fill.finish == "TOP") and lane or -lane
    if fill.vertical then
        add("health", frame.health, 0, frame.healthWidth, frame.healthHeight + lane, side)
    else
        add("health", frame.health, side, frame.healthWidth + lane, frame.healthHeight)
    end
    if frame.power and frame.power:IsShown() then
        add("power", frame.power, 0, frame.powerWidth, frame.powerHeight)
    end
    if frame.footerHeight > 0 then add("footer", frame.footer, 0, frame.footerWidth, frame.footerHeight) end
    return parts
end

-- The plate behind all parts while the gaps are filled (spacingFill),
-- out to their rings plus the padding. It lies on the frame's own
-- backdrop holder below that backdrop, which then stands in for the
-- parts' own (Elements/ThemeArt.lua): holders of one frame level draw in
-- no fixed order, layers of one holder do. A docked castbar or threat
-- bar stays a box of its own outside it.
local function drawFill(frame, fill)
    if not fill then
        if frame.boxFill then frame.boxFill:Hide() end
        return
    end
    frame.boxFill = frame.boxFill or frame.themeUnder:CreateTexture(nil, "BACKGROUND", nil, -7)
    local scope, plate = frame.key, frame.boxFill
    local reach = Boxes.Extent(scope) + ns.Pixel.Snap(Config.Get(scope, "spacingFillPadding"))
    local c = Config.Get(scope, "spacingFillColor")
    plate:ClearAllPoints()
    plate:SetPoint("TOPLEFT", frame, "TOPLEFT", -reach, reach)
    plate:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", reach, -reach)
    plate:SetColorTexture(c[1], c[2], c[3], c[4])
    plate:Show()
end

local function drawBox(frame, box, part, look)
    local _, region, extra, w, h, extraY = part[1], part[2], part[3], part[4], part[5], part[6] or 0
    local scope = frame.key
    box.ring:ClearAllPoints()
    box.ring:SetPoint("TOPLEFT", region, "TOPLEFT", math.min(extra, 0), math.max(extraY, 0))
    box.ring:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", math.max(extra, 0), math.min(extraY, 0))
    local radius = Boxes.DrawRing(box.ring, frame, box.ring, w, h, box.shade)
    local padding = Boxes.Plain() and 0 or ns.Border.Padding(scope)
    ns.ThemeArt.PlaceBack(box.back, box.clip, box.ring, padding, radius)
    ns.ThemeArt.Paint(box.back, look.spec)
    local offset = look.spec.art and look.spec.art.hardShadow
    if offset then ns.ThemeArt.PlaceShadow(box.hard, box.ring, offset, Boxes.Extent(scope)) end
    box.hard:SetShown(offset ~= nil)
    showBox(box, true)
    -- On the plate the frame's backdrop is the parts' (see drawFill), and
    -- a part's shadow would fall into the seams.
    box.under:SetShown(not look.fill)
    box.shade:SetShown(not look.fill)
end

function Boxes.Build() end

-- After the layout (Units/Single.lua) and the portrait: out of combat,
-- or for a party button whenever it is styled.
function Boxes.Style(frame)
    local boxes = frame.boxes or {}
    for _, box in pairs(boxes) do showBox(box, false) end
    local apart = ns.Shape.Apart(frame)
    local fill = apart and Config.Get(frame.key, "spacingFill")
    drawFill(frame, fill)
    if not apart then return end
    frame.boxes = boxes
    local id = frame.themeOf and frame.themeOf() or Config.Get("general", "theme")
    local look = { spec = ns.Themes.Spec(id), fill = fill }
    for _, part in ipairs(Boxes.Parts(frame)) do
        local name = part[1]
        boxes[name] = boxes[name] or newBox(frame)
        drawBox(frame, boxes[name], part, look)
    end
end

function Boxes.Update() end

ns.RegisterElement(Boxes)
