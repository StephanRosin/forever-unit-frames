local _, ns = ...

-- The frame's outline: rounded corners of the whole block (title row,
-- bars and portrait). Built after every other element, so all their
-- textures are listed (ns.Corners.Add) by then. What sticks out of the
-- block (class badge, aura icons, texts) is never listed.
local Shape = { name = "Shape" }
ns.Shape = Shape

function Shape.Build(frame)
    frame.clip = ns.Corners.Clipper(frame)
end

function Shape.Style(frame)
    ns.Corners.Fit(frame.clip, frame, ns.Corners.Radius(frame.key))
end

function Shape.Update() end

ns.RegisterElement(Shape)
