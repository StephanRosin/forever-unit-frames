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
-- * One corner mask, frame.clip, on the frame (Core/Corners.lua). While
--   the castbar shows, the mask swaps to a file whose corners on the
--   castbar's side are square; the castbar's own mask rounds the unit
--   box's corners on that side (Elements/Castbar.lua). Swapping a mask's
--   file anchors nothing.
local Shape = { name = "Shape" }
ns.Shape = Shape

local Config = ns.Config

-- The frame's mask shape while a castbar docked on that side shows: the
-- corners away from the castbar stay round.
local JOINED_SHAPE = { BELOW = "TOP", ABOVE = "BOTTOM" }

-- "BELOW" or "ABOVE" while the frame has a docked castbar, else nil.
local function dockSide(frame)
    if not frame.castbar or not Config.Get(frame.key, "castbarEnabled") then return nil end
    local placement = ns.Castbar.Placement(frame.key)
    if placement == "DETACHED" then return nil end
    return placement
end

-- The unit's corner radius, clamped to the frame (the smaller of its two
-- boxes, so one radius serves both). A docked castbar's row must hold its
-- whole arc too: the frame's own corners on that side are square while
-- the castbar shows, so an arc reaching past the row would leave a notch.
function Shape.Radius(frame)
    local w, h = ns.Single.Size(frame.key)
    local radius = ns.Corners.Clamp(ns.Corners.Radius(frame.key), w, h)
    if not dockSide(frame) then return radius end
    return math.min(radius, ns.Castbar.Height(frame.key))
end

-- The docked castbar's side ("BELOW", "ABOVE" or nil) and how far its
-- slot reaches out from the frame (its height; 0 without one).
function Shape.DockReach(frame)
    local side = dockSide(frame)
    if not side then return nil, 0 end
    return side, ns.Castbar.Height(frame.key)
end

local function placeUnitBox(frame, side)
    local _, reach = Shape.DockReach(frame)
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
    ns.Border.Draw(frame.frameRing, scope, frame.frameRing, radius)
    ns.Border.Draw(frame.blockRing, scope, frame.blockRing, radius)
    Shape.Refresh(frame)
end

-- Any time, combat included: which layout shows. Only shows and hides,
-- and swaps the frame mask's file.
function Shape.Refresh(frame)
    local side = frame.dockSide
    local joined = side ~= nil and frame.castbar:IsShown()
    frame.frameRing:SetShown(not joined)
    frame.blockRing:SetShown(joined)
    ns.Corners.SetShape(frame.clip, joined and JOINED_SHAPE[side] or "ALL")
end

function Shape.Update() end

ns.RegisterElement(Shape)
