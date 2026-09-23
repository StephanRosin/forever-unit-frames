local _, ns = ...

-- The unit's outline: rounded corners of the whole block (title row,
-- bars, portrait and a docked castbar) and the outer border around it.
-- Built after every other element, so all their textures are listed
-- (ns.Corners.Add) and the castbar exists by then. What sticks out of the
-- block (class badge, aura icons, texts) is never listed.
--
-- A docked castbar joins the frame's block while it shows. Nothing is
-- re-anchored for that, so it is safe in combat: everything that follows
-- the castbar is laid out twice, out of combat, and switched by showing
-- and hiding plain regions only.
-- * frame.unitBox: the frame plus the docked castbar's slot (it keeps the
--   slot while the castbar is idle), for auras and the options outline.
-- * Two rings (Core/Border.lua), each on a plain holder frame: frameRing
--   around the frame, blockRing around the unit box. One shows at a time.
-- * Corner masks: frame.clip in the frame's corners, frame.dockClip in the
--   unit box's two corners on the castbar's side. While the castbar shows,
--   the frame's masks on that side hide (those corners go square) and the
--   dock masks show. A hidden mask masks nothing (Blizzard switches mask
--   shapes that way, GamepadActionBars/ActionBarButton.lua).
local Shape = { name = "Shape" }
ns.Shape = Shape

local Config = ns.Config

-- The unit box's corners on each docked side (Corners.POINTS indices).
local DOCK_CORNERS = { BELOW = { 3, 4 }, ABOVE = { 1, 2 } }

-- "BELOW" or "ABOVE" while the frame has a docked castbar, else nil.
local function dockSide(frame)
    if not frame.castbar or not Config.Get(frame.key, "castbarEnabled") then return nil end
    local placement = ns.Castbar.Placement(frame.key)
    if placement == "DETACHED" then return nil end
    return placement
end

-- The unit's corner radius, clamped to the frame (the smaller of its two
-- boxes, so one radius serves both).
function Shape.Radius(frame)
    local w, h = ns.Single.Size(frame.key)
    return ns.Corners.Clamp(ns.Corners.Radius(frame.key), w, h)
end

local function placeUnitBox(frame, side)
    local reach = side and ns.Castbar.Gap(frame.key) + ns.Castbar.Height(frame.key) or 0
    local box = frame.unitBox
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, side == "ABOVE" and reach or 0)
    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, side == "BELOW" and -reach or 0)
end

local function ringHolder(frame, box)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(box)
    return holder
end

function Shape.Build(frame)
    frame.clip = ns.Corners.Clipper(frame)
    frame.dockClip = ns.Corners.Clipper(frame, 2)
    frame.unitBox = CreateFrame("Frame", nil, frame)
    frame.frameRing = ringHolder(frame, frame)
    frame.blockRing = ringHolder(frame, frame.unitBox)
    -- The castbar may have changed while the frame was hidden.
    frame:HookScript("OnShow", function() Shape.Refresh(frame) end)
end

-- Out of combat: both layouts.
function Shape.Style(frame)
    local scope, side = frame.key, dockSide(frame)
    local radius = Shape.Radius(frame)
    frame.shapeRadius, frame.dockSide = radius, side
    placeUnitBox(frame, side)
    ns.Corners.Fit(frame.clip, frame, radius)
    frame.dockClip.corners = DOCK_CORNERS[side or "BELOW"]
    ns.Corners.Fit(frame.dockClip, frame.unitBox, side and radius or 0)
    ns.Border.Draw(frame.frameRing, scope, frame.frameRing, radius)
    ns.Border.Draw(frame.blockRing, scope, frame.blockRing, radius)
    Shape.Refresh(frame)
end

-- Any time, combat included: which layout shows. Only shows and hides.
function Shape.Refresh(frame)
    local side = frame.dockSide
    local joined = side ~= nil and frame.castbar:IsShown()
    frame.frameRing:SetShown(not joined)
    frame.blockRing:SetShown(joined)
    local round = (frame.shapeRadius or 0) > 0
    local dock = DOCK_CORNERS[side or "BELOW"]
    for i, mask in ipairs(frame.clip.masks) do
        local onDockSide = side ~= nil and (i == dock[1] or i == dock[2])
        mask:SetShown(round and not (joined and onDockSide))
    end
    for _, mask in ipairs(frame.dockClip.masks) do mask:SetShown(round and joined) end
end

function Shape.Update() end

ns.RegisterElement(Shape)
