local _, ns = ...

-- The frame's parts standing apart (barSpacing, a CurseForge wish): title
-- row, portrait, health bar (its overheal lane included), power bar and
-- footer each get their own ring, drop shadow and theme backdrop, so the
-- gaps between them show nothing (Units/Single.lua lays out the gaps,
-- Elements/Shape.lua and Elements/ThemeArt.lua drop the frame's own ring,
-- backdrop and shadow). A docked castbar and the threat bar draw their
-- own ring (Elements/Castbar.lua, Elements/ThreatBar.lua).
--
-- Per part, made when first needed: a ring holder, anchored on the part;
-- below the frame its backdrop holder, and below that its shadow holder,
-- so no part's shadow falls on its neighbour's backdrop. Ornaments, the
-- rule, the glows and the elite ring stay the whole frame's.
local Boxes = { name = "Boxes" }
ns.Boxes = Boxes

local Config = ns.Config

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

-- The parts that show: name, region, extra width right of it (the
-- overheal lane), width and height (the layout's numbers: the regions'
-- own sizes may not be known yet).
function Boxes.Parts(frame)
    local parts = {}
    local function add(name, region, extra, w, h) parts[#parts + 1] = { name, region, extra, w, h } end
    if frame.titleHeight > 0 then add("title", frame.title, 0, frame.titleWidth, frame.titleHeight) end
    local mode = Config.Get(frame.key, "portraitMode")
    if mode == "TOP" then
        add("portrait", frame.portraitBg, 0, frame.footerWidth, frame.portraitStrip)
    elseif mode ~= "OFF" then
        add("portrait", frame.portraitBg, 0, frame.layoutHeight, frame.layoutHeight)
    end
    local lane = frame.overhealLane or 0
    add("health", frame.health, lane, frame.healthWidth + lane, frame.healthHeight)
    if frame.power and frame.power:IsShown() then
        add("power", frame.power, 0, frame.powerWidth, frame.powerHeight)
    end
    if frame.footerHeight > 0 then add("footer", frame.footer, 0, frame.footerWidth, frame.footerHeight) end
    return parts
end

local function drawBox(frame, box, part, look)
    local _, region, extra, w, h = part[1], part[2], part[3], part[4], part[5]
    local scope = frame.key
    box.ring:ClearAllPoints()
    box.ring:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
    box.ring:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", extra, 0)
    local radius = ns.Corners.Clamp(ns.Shape.Radius(frame), w, h)
    ns.Border.Draw(box.ring, scope, box.ring, radius, look.rim, box.shade)
    ns.ThemeArt.PlaceBack(box.back, box.clip, box.ring, ns.Border.Padding(scope), radius)
    ns.ThemeArt.Paint(box.back, look.spec)
    local offset = look.spec.art and look.spec.art.hardShadow
    if offset then ns.ThemeArt.PlaceShadow(box.hard, box.ring, offset, ns.Border.Extent(scope)) end
    box.hard:SetShown(offset ~= nil)
    showBox(box, true)
end

function Boxes.Build() end

-- After the layout (Units/Single.lua) and the portrait: out of combat,
-- or for a party button whenever it is styled.
function Boxes.Style(frame)
    local boxes = frame.boxes or {}
    for _, box in pairs(boxes) do showBox(box, false) end
    if not ns.Shape.Apart(frame) then return end
    frame.boxes = boxes
    local id = frame.themeOf and frame.themeOf() or Config.Get("general", "theme")
    local look = { spec = ns.Themes.Spec(id), rim = ns.Themes.Rim(id) }
    for _, part in ipairs(Boxes.Parts(frame)) do
        local name = part[1]
        boxes[name] = boxes[name] or newBox(frame)
        drawBox(frame, boxes[name], part, look)
    end
end

function Boxes.Update() end

ns.RegisterElement(Boxes)
