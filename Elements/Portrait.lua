local _, ns = ...

-- Unit portrait, off or on the left/right of the frame, as a 2D picture, a
-- 3D model or a player's class icon (the 2D picture for anyone else). Takes a square as tall as the frame; the bars make room for
-- it (Layout.PortraitInsets). TOP: a strip as wide as the frame between
-- title row and health bar, the frame grown by its height (Single.Size).
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
    local style = Config.Get(scope, "portraitStyle")
    local threeD, class = style == "3D", style == "CLASS"
    local on = mode ~= "OFF"
    local bg, pic = frame.portraitBg, frame.portrait2D
    bg:ClearAllPoints()
    pic:ClearAllPoints()
    pic:SetAllPoints(bg)
    -- The class icon keeps its own coords (the class sheet's cell).
    if not class then pic:SetTexCoord(0, 1, 0, 1) end
    if mode == "TOP" then
        local top = -(frame.titleHeight or 0)
        bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, top)
        bg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, top)
        local strip = frame.portraitStrip or 0
        bg:SetHeight(strip)
        -- The square picture's middle band, as wide as the strip.
        if class then
            -- Whole, as a square in the strip's middle.
            pic:ClearAllPoints()
            pic:SetPoint("CENTER", bg, "CENTER", 0, 0)
            pic:SetSize(strip, strip)
        else
            local w = ns.Single.Size(scope)
            local band = math.min(1, strip / w) / 2
            pic:SetTexCoord(0, 1, 0.5 - band, 0.5 + band)
        end
    elseif on then
        local point = mode == "LEFT" and "TOPLEFT" or "TOPRIGHT"
        -- As tall as the frame is laid out (Single.LayoutSize).
        local size = frame.layoutHeight or ns.Pixel.Snap(Config.Get(scope, "height"))
        bg:SetPoint(point, frame, point, 0, 0)
        bg:SetSize(size, size)
    end
    if on then
        local c = Config.Get(scope, "backgroundColor")
        bg:SetColorTexture(c[1], c[2], c[3], c[4])
    end
    bg:SetShown(on)
    frame.portrait2D:SetShown(on and (not threeD or not frame.portrait3D.ready))
    frame.portrait3D:SetShown(on and threeD)
    if frame.portrait3D.ready then Portrait.Frame(frame) end
end

-- The camera: the client's portrait framing, zoomed in (portraitZoom
-- percent) and the view shifted up or down (portraitOffsetY pixels).
-- How the face sits differs by model; the shift is there to fix that.
function Portrait.Frame(frame)
    local model, scope = frame.portrait3D, frame.key
    -- As oUF frames it: the clear resets the camera, so all of it.
    model:SetCamDistanceScale(100 / Config.Get(scope, "portraitZoom"))
    model:SetPortraitZoom(1)
    model:SetPosition(0, 0, 0)
    if model.SetViewTranslation then model:SetViewTranslation(0, Config.Get(scope, "portraitOffsetY")) end
end

-- The model has arrived: framed as a portrait, and the 2D stand-in goes.
function Portrait.ModelReady(frame)
    local model = frame.portrait3D
    model.ready = true
    Portrait.Frame(frame)
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

-- The class icon; the 2D picture, uncropped, for a unit without a class.
local function updateClassIcon(frame)
    local token = ns.Texts.ClassToken(frame.unit)
    if token and ns.Texts.DrawClassIcon(frame.portrait2D, token) then return end
    frame.portrait2D:SetTexCoord(0, 1, 0, 1)
    updatePicture(frame)
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
-- Players too: a model can finish loading without OnModelLoaded (reported:
-- the 2D picture stayed behind a player's model now and then).
Portrait.RECHECK = { 0.05, 0.2, 1 }

-- Looks at the model again a little later, as long as nothing newer was
-- set (the generation: "target" is the same token for every target).
local function watch(frame)
    local model = frame.portrait3D
    local generation = model.generation
    for _, delay in ipairs(Portrait.RECHECK) do
        C_Timer.After(delay, function()
            if model.generation == generation and not model.ready and hasModel(model) then
                Portrait.ModelReady(frame)
            end
        end)
    end
end

local function setCreature(frame, unit)
    local id = Portrait.CreatureID(unit)
    local model = frame.portrait3D
    if not id or not pcall(model.SetCreature, model, id) then return end
    model.wantsUnit = unit
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
    model.generation = (model.generation or 0) + 1
    updatePicture(frame)
    frame.portrait2D:Show()
    if not Secrets.Bool(UnitIsVisible, unit) then return end
    local ok, success = pcall(model.SetUnit, model, unit)
    if ok and success ~= false then model.wantsUnit = unit end
    -- The model is there (SetUnit succeeded or reports a file or display):
    -- framed now; OnModelLoaded frames it again once it has finished.
    if ok and (success == true or hasModel(model)) then return Portrait.ModelReady(frame) end
    if setCreature(frame, unit) then return Portrait.ModelReady(frame) end
    watch(frame)
end

function Portrait.Update(frame, event)
    -- Timer refreshes only move bars and texts; re-setting a model every
    -- few frames would restart its animation.
    if event == ns.Single.POLL then return end
    local scope = frame.key
    if Config.Get(scope, "portraitMode") == "OFF" then return end
    local style = Config.Get(scope, "portraitStyle")
    if style == "3D" then
        updateModel(frame)
    elseif style == "CLASS" then
        updateClassIcon(frame)
    else
        updatePicture(frame)
    end
end

ns.RegisterElement(Portrait)
