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

-- The frame's mask shape by which of its sides join another row: the
-- corners away from it stay round; joined on both sides, none are.
local function frameShape(top, bottom)
    if top and bottom then return "NONE" end
    if bottom then return "TOP" end
    if top then return "BOTTOM" end
    return "ALL"
end

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
-- The threat bar's row (Elements/ThreatBar.lua) is held to the same rule.
function Shape.Radius(frame)
    local w, h = ns.Single.Size(frame.key)
    local radius = ns.Corners.Clamp(ns.Corners.Radius(frame.key), w, h)
    if dockSide(frame) then
        radius = math.min(radius, math.floor(ns.Castbar.Height(frame.key) + 1e-6))
    end
    local threat = ns.ThreatBar and ns.ThreatBar.Height(frame.key) or 0
    if threat > 0 then radius = math.min(radius, math.floor(threat + 1e-6)) end
    return radius
end

-- Whether a castbar is docked below the frame, and the room it takes
-- there (0 without one): the threat bar goes below it.
function Shape.CastbarBelow(frame)
    local side, reach = Shape.DockReach(frame)
    if side == "BELOW" then return true, reach end
    return false, 0
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
    local threat = ns.ThreatBar and ns.ThreatBar.Height(frame.key) or 0
    local box = frame.unitBox
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, side == "ABOVE" and reach or 0)
    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -((side == "BELOW" and reach or 0) + threat))
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
-- A threat bar row (Elements/ThreatBar.lua) is always shown while it is
-- on, so it joins the frame's bottom for good.
function Shape.Refresh(frame)
    local side = frame.dockSide
    local castbar = side ~= nil and frame.castbar:IsShown()
    local threat = ns.ThreatBar and ns.ThreatBar.Active(frame.key) or false
    local top = castbar and side == "ABOVE"
    local bottom = (castbar and side == "BELOW") or threat
    local joined = top or bottom
    frame.frameRing:SetShown(not joined)
    frame.blockRing:SetShown(joined)
    ns.Corners.SetShape(frame.clip, frameShape(top, bottom))
end

function Shape.Update() end

ns.RegisterElement(Shape)
