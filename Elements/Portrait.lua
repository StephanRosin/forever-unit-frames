local _, ns = ...

-- Unit portrait, off or on the left/right of the frame, as a 2D picture or
-- a 3D model. Takes a square as tall as the frame; the bars make room for
-- it (Layout.PortraitInsets).
local Portrait = { name = "Portrait", unitEvents = { "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED" } }
ns.Portrait = Portrait

local Config, Secrets = ns.Config, ns.Secrets

function Portrait.Build(frame)
    frame.portraitBg = frame:CreateTexture(nil, "BACKGROUND")
    frame.portrait2D = frame:CreateTexture(nil, "ARTWORK")
    frame.portrait2D:SetAllPoints(frame.portraitBg)
    frame.portrait3D = CreateFrame("PlayerModel", nil, frame)
    frame.portrait3D:SetAllPoints(frame.portraitBg)
    -- A model is no texture: the 3D portrait stays square.
    ns.Corners.Add(frame, frame.portraitBg)
    ns.Corners.Add(frame, frame.portrait2D)
end

function Portrait.Style(frame)
    local scope = frame.key
    local mode = Config.Get(scope, "portraitMode")
    local threeD = Config.Get(scope, "portraitStyle") == "3D"
    local on = mode ~= "OFF"
    local bg = frame.portraitBg
    bg:ClearAllPoints()
    if on then
        local point = mode == "LEFT" and "TOPLEFT" or "TOPRIGHT"
        local size = ns.Pixel.Snap(Config.Get(scope, "height"))
        bg:SetPoint(point, frame, point, 0, 0)
        bg:SetSize(size, size)
        local c = Config.Get(scope, "backgroundColor")
        bg:SetColorTexture(c[1], c[2], c[3], c[4])
    end
    bg:SetShown(on)
    frame.portrait2D:SetShown(on and not threeD)
    frame.portrait3D:SetShown(on and threeD)
end

-- A model is only set for a unit the client can see; otherwise, or when
-- the client refuses the unit (restricted identity), it is cleared.
local function updateModel(model, unit)
    if Secrets.Bool(UnitIsVisible, unit) and pcall(model.SetUnit, model, unit) then
        model:SetPortraitZoom(1)
    else
        model:ClearModel()
    end
end

function Portrait.Update(frame, event)
    -- Timer refreshes only move bars and texts; re-setting a model every
    -- few frames would restart its animation.
    if event == ns.Single.POLL then return end
    local scope = frame.key
    if Config.Get(scope, "portraitMode") == "OFF" then return end
    if Config.Get(scope, "portraitStyle") == "3D" then
        updateModel(frame.portrait3D, frame.unit)
    else
        pcall(SetPortraitTexture, frame.portrait2D, frame.unit)
    end
end

ns.RegisterElement(Portrait)
