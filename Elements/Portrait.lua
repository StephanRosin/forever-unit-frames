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
    -- The client loads a model after SetUnit, maybe frames later; until
    -- then (or for good, when there is none) the 2D picture stands in.
    frame.portrait3D:SetScript("OnModelLoaded", function(model)
        if model.wantsUnit then Portrait.ModelReady(frame) end
    end)
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
        -- As tall as the frame is laid out (Single.LayoutSize).
        local size = frame.layoutHeight or ns.Pixel.Snap(Config.Get(scope, "height"))
        bg:SetPoint(point, frame, point, 0, 0)
        bg:SetSize(size, size)
        local c = Config.Get(scope, "backgroundColor")
        bg:SetColorTexture(c[1], c[2], c[3], c[4])
    end
    bg:SetShown(on)
    frame.portrait2D:SetShown(on and (not threeD or not frame.portrait3D.ready))
    frame.portrait3D:SetShown(on and threeD)
end

-- The model has arrived: framed as a portrait, and the 2D stand-in goes.
function Portrait.ModelReady(frame)
    local model = frame.portrait3D
    model.ready = true
    -- As oUF frames it: the clear resets the camera, so all three.
    model:SetCamDistanceScale(1)
    model:SetPortraitZoom(1)
    model:SetPosition(0, 0, 0)
    if Config.Get(frame.key, "portraitStyle") == "3D" then frame.portrait2D:Hide() end
end

-- Whether the model shows something: a file (players) or a creature's
-- display ID. Creatures report no file ID and may never fire
-- OnModelLoaded, so the display ID is what tells them apart.
local function hasModel(model)
    local ok, id = pcall(model.GetModelFileID, model)
    if ok and type(id) == "number" and not Secrets.IsSecret(id) and id > 0 then return true end
    local ok2, display = pcall(model.GetDisplayInfo, model)
    return ok2 and type(display) == "number" and not Secrets.IsSecret(display) and display > 0
end

-- The 2D picture, emptied first: without a portrait for the unit the
-- client leaves the texture as it was, the previous unit's face.
local function updatePicture(frame)
    frame.portrait2D:SetTexture(nil)
    pcall(SetPortraitTexture, frame.portrait2D, frame.unit)
end

-- A creature's NPC ID from its GUID ("Creature-0-realm-map-instance-npcID-
-- spawn"), or nil: a player, a secret or unreadable GUID.
function Portrait.CreatureID(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or type(guid) ~= "string" or Secrets.IsSecret(guid) then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" and kind ~= "Pet" then return nil end
    return tonumber(id)
end

-- Forever's SetUnit loads nothing for creatures (it answers nil and the
-- model stays empty, checked in game): they are set by NPC ID. That may
-- load later, so the model is looked at again a little after.
Portrait.RECHECK = { 0.2, 1 }

local function setCreature(frame, unit)
    local id = Portrait.CreatureID(unit)
    local model = frame.portrait3D
    if not id or not pcall(model.SetCreature, model, id) then return end
    model.wantsUnit = unit
    for _, delay in ipairs(Portrait.RECHECK) do
        C_Timer.After(delay, function()
            if model.wantsUnit == unit and not model.ready and frame.unit == unit and hasModel(model) then
                Portrait.ModelReady(frame)
            end
        end)
    end
    return hasModel(model)
end

-- 3D: the 2D picture first, then the model when the client has it. The
-- model is cleared first (a creature without a loaded model left the
-- previous target's standing). A model only for a unit the client can
-- see and does not refuse (restricted identity).
local function updateModel(frame)
    local model, unit = frame.portrait3D, frame.unit
    model:ClearModel()
    model.ready, model.wantsUnit = false, nil
    updatePicture(frame)
    frame.portrait2D:Show()
    if not Secrets.Bool(UnitIsVisible, unit) then return end
    local ok, success = pcall(model.SetUnit, model, unit)
    if ok and success ~= false then model.wantsUnit = unit end
    -- The model is there (SetUnit succeeded or reports a file or display):
    -- framed now; OnModelLoaded frames it again once it has finished.
    if ok and (success == true or hasModel(model)) then return Portrait.ModelReady(frame) end
    if setCreature(frame, unit) then Portrait.ModelReady(frame) end
end

function Portrait.Update(frame, event)
    -- Timer refreshes only move bars and texts; re-setting a model every
    -- few frames would restart its animation.
    if event == ns.Single.POLL then return end
    local scope = frame.key
    if Config.Get(scope, "portraitMode") == "OFF" then return end
    if Config.Get(scope, "portraitStyle") == "3D" then
        updateModel(frame)
    else
        updatePicture(frame)
    end
end

ns.RegisterElement(Portrait)
