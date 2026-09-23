local _, ns = ...

-- The unit's outline: rounded corners of the whole block (title row,
-- bars, portrait and a docked castbar) and the outer border around it.
-- Built after every other element, so all their textures are listed
-- (ns.Corners.Add) and the castbar exists by then. What sticks out of the
-- block (class badge, aura icons, texts) is never listed.
local Shape = { name = "Shape" }
ns.Shape = Shape

-- The unit's box: the frame, and a docked castbar while it shows. A plain
-- frame, so it may follow the castbar in combat. The frame's corner masks
-- (and a docked castbar's) sit in its corners: the block is rounded as a
-- whole, the frame's corners next to a shown castbar stay square.
function Shape.FitBox(frame)
    local scope, bar = frame.key, frame.castbar
    local above, below = 0, 0
    if bar and bar:IsShown() then
        local reach = ns.Castbar.Gap(scope) + ns.Castbar.Height(scope)
        local placement = ns.Castbar.Placement(scope)
        if placement == "ABOVE" then above = reach elseif placement == "BELOW" then below = reach end
    end
    local box = frame.unitBox
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, above)
    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -below)
end

function Shape.Build(frame)
    frame.clip = ns.Corners.Clipper(frame)
    frame.unitBox = CreateFrame("Frame", nil, frame)
    local bar = frame.castbar
    if bar then
        bar:HookScript("OnShow", function() Shape.FitBox(frame) end)
        bar:HookScript("OnHide", function() Shape.FitBox(frame) end)
    end
end

function Shape.Style(frame)
    local scope = frame.key
    ns.Corners.Fit(frame.clip, frame.unitBox, ns.Corners.Radius(scope))
    Shape.FitBox(frame)
    ns.Border.Draw(frame, scope, frame.unitBox)
end

function Shape.Update() end

ns.RegisterElement(Shape)
