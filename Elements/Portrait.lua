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

-- The inner square of the round picture: 0.5 - 0.5 / sqrt(2), a little in
-- so the round edge never shows.
Portrait.SQUARE_INSET = 0.15

-- The 2D picture's coords: whole or its inner square, in the TOP strip
-- only the middle band of that; mirrored when asked (portraitMirror).
local function pictureCoords(frame)
    local scope = frame.key
    local inset = Config.Get(scope, "portraitSquare") and Portrait.SQUARE_INSET or 0
    local lo, hi = inset, 1 - inset
    -- Mirrored: left and right swapped.
    local left, right = lo, hi
    if Config.Get(scope, "portraitMirror") then left, right = hi, lo end
    if Config.Get(scope, "portraitMode") == "TOP" then
        local band = math.min(1, (frame.portraitStrip or 0) / ns.Single.Size(scope)) * (hi - lo) / 2
        frame.portrait2D:SetTexCoord(left, right, 0.5 - band, 0.5 + band)
    else
        frame.portrait2D:SetTexCoord(left, right, lo, hi)
    end
end

function Portrait.Style(frame)
    local scope = frame.key
    local mode = Config.Get(scope, "portraitMode")
    local style = Config.Get(scope, "portraitStyle")
    local threeD, class = style == "3D", style == "CLASS"
    local on = mode ~= "OFF"
    local bg, pic = frame.portraitBg, frame.portrait2D
    -- The side of the square the portrait aura covers; nil: no portrait.
    frame.portraitSide = nil
    bg:ClearAllPoints()
    pic:ClearAllPoints()
    pic:SetAllPoints(bg)
    -- The class icon keeps its own coords (the class sheet's cell).
    if not class then pictureCoords(frame) end
    if mode == "TOP" then
        -- Below the title row, and its gap when the parts stand apart.
        local top = -(frame.stripTop or frame.titleHeight or 0)
        bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, top)
        bg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, top)
        local strip = frame.portraitStrip or 0
        bg:SetHeight(strip)
        frame.portraitSide = strip
        -- The class icon whole; the picture's middle band (pictureCoords).
        if class then
            -- Whole, as a square in the strip's middle.
            pic:ClearAllPoints()
            pic:SetPoint("CENTER", bg, "CENTER", 0, 0)
            pic:SetSize(strip, strip)
        end
    elseif on then
        local point = mode == "LEFT" and "TOPLEFT" or "TOPRIGHT"
        -- As tall as the frame is laid out (Single.LayoutSize).
        local size = frame.layoutHeight or ns.Pixel.Snap(Config.Get(scope, "height"))
        bg:SetPoint(point, frame, point, 0, 0)
        bg:SetSize(size, size)
        frame.portraitSide = size
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

-- The class icon; the 2D picture for a unit without a class.
local function updateClassIcon(frame)
    local token = ns.Texts.ClassToken(frame.unit)
    if token and ns.Texts.DrawClassIcon(frame.portrait2D, token) then return end
    pictureCoords(frame)
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

-- Portrait aura --------------------------------------------------------------------
-- The unit's crowd control big on its portrait (a CurseForge wish, as
-- BigDebuffs does it), optionally its big defensives. Every aura is secret
-- to addons in Forever, so the client picks the aura: one aura container
-- (as Elements/AuraContainers.lua) with an aura slot per kind, one aura
-- each, placed by us like the raid cells' centre icon (Raid/CellAuras.lua).
-- CROWD_CONTROL and BIG_DEFENSIVE are filters the client evaluates itself
-- (AuraUtil.AuraFilters); Blizzard uses them on nameplates and raid frames
-- only. Both slots cover the portrait, crowd control above: it wins while
-- both show. Made the first time it is switched on and configured out of
-- combat only, like the dispel ring's container (Elements/Dispel.lua).
local PortraitAura = { name = "PortraitAura", unitEvents = { "UNIT_AURA" } }
ns.PortraitAura = PortraitAura

PortraitAura.CC_FILTER = "HARMFUL|CROWD_CONTROL"
-- Big defensives cast on the unit by itself (shield wall, divine shield);
-- EXTERNAL_DEFENSIVE (pain suppression) has Blizzard's own frame.
PortraitAura.DEFENSIVE_FILTER = "HELPFUL|BIG_DEFENSIVE"
-- Above the aura icons (Auras.LEVELS): this icon is the one to see.
PortraitAura.LEVELS = 13
PortraitAura.SLOTS = {
    { key = "defensive", filter = PortraitAura.DEFENSIVE_FILTER, isDebuff = false, level = 1 },
    { key = "cc", filter = PortraitAura.CC_FILTER, isDebuff = true, level = 2 },
}
-- Test mode: a polymorph on the portrait.
PortraitAura.SAMPLE = { icon = "Interface\\Icons\\Spell_Magic_PolymorphChicken", duration = 30 }

local auraFrames = setmetatable({}, { __mode = "k" })
local auraWaiting = setmetatable({}, { __mode = "k" })

function PortraitAura.Applies(scope)
    return ns.Settings.AppliesTo(ns.Settings.Get("portraitAura"), scope)
end

-- Whether slot key shows on frame: switched on, and a portrait to cover.
function PortraitAura.Wanted(frame, key)
    local scope = frame.key
    if not Config.Get(scope, "portraitAura") or Config.Get(scope, "portraitMode") == "OFF" then return false end
    return key == "cc" or Config.Get(scope, "portraitAuraDefensive") == true
end

local function auraTesting(frame) return ns.TestMode ~= nil and ns.TestMode.Covers(frame) end

-- An icon as big as the portrait, on its middle, with the time left.
-- Refused on a slot's button while auras are secret.
local function placeIcon(frame, button, level)
    button:SetFrameLevel(frame:GetFrameLevel() + PortraitAura.LEVELS + level)
    button:ClearAllPoints()
    button:SetPoint("CENTER", frame.portraitBg, "CENTER", 0, 0)
    ns.AuraButton.Style(button, frame.key, ns.Pixel.Snap(frame.portraitSide or 0, nil, 1), true)
end

local function initIcon(frame, slot, button)
    ns.AuraButton.Decorate(button, slot.isDebuff)
    placeIcon(frame, button, slot.level)
    ns.AuraContainers.Wire(button, slot.isDebuff)
end

-- The slots onto the container; a slot is made the first time it is
-- wanted. A refused restyle is tried again when auras are free.
local function applyAura(frame)
    local p = frame.portraitAura
    local container = p.container
    p.stale = false
    container:SetFrameLevel(frame:GetFrameLevel() + PortraitAura.LEVELS)
    for _, slot in ipairs(PortraitAura.SLOTS) do
        local on = PortraitAura.Wanted(frame, slot.key)
        if on and not p.buttons[slot.key] then
            p.buttons[slot.key] = container:AddAuraSlot(slot.key, slot.filter,
                { initializeFrame = function(button) initIcon(frame, slot, button) end })
        end
        if p.buttons[slot.key] then
            container:SetAuraSlotEnabled(slot.key, on)
            if not pcall(placeIcon, frame, p.buttons[slot.key], slot.level) then p.stale = true end
        end
    end
    container:SetShown(not auraTesting(frame))
end

-- The container, out of combat. A refusal (reported once) leaves the
-- frame without a portrait aura for the session.
local function buildAura(frame)
    local p = frame.portraitAura
    local ok, err = pcall(function()
        local container = CreateFrame("AuraContainer", nil, frame, ns.AuraContainers.TEMPLATE)
        p.container = container
        container:SetEditModePreviewEnabled(false)
        container:SetPoint("CENTER", frame.portraitBg, "CENTER", 0, 0)
        applyAura(frame)
        container:SetUnit(frame.unit or "none")
    end)
    if not ok then
        if p.container then p.container:Hide() end
        p.container, p.failed = nil, true
        geterrorhandler()(err)
        return false
    end
    auraFrames[frame] = true
    return true
end

local function later(frame)
    auraWaiting[frame] = true
    ns.AfterCombat("portraitAura", PortraitAura.Flush)
end

-- Whether the frame has its container now; made when first wanted,
-- after combat when that is in combat.
local function ensureAura(frame)
    local p = frame.portraitAura
    if p.container then return true end
    if frame.pretend or p.failed or not PortraitAura.Wanted(frame, "cc") then return false end
    if not ns.AuraContainers.Supported() then return false end
    if InCombatLockdown() then
        later(frame)
        return false
    end
    return buildAura(frame)
end

function PortraitAura.Flush()
    local frames = {}
    for frame in pairs(auraWaiting) do frames[#frames + 1] = frame end
    for _, frame in ipairs(frames) do
        auraWaiting[frame] = nil
        if frame.portraitAura.container then applyAura(frame) else ensureAura(frame) end
    end
end

-- Test mode's sample: a plain icon where the live one would be.
local function showSample(frame)
    local p = frame.portraitAura
    local on = p.sampleStart ~= nil and PortraitAura.Wanted(frame, "cc")
    if on and not p.sample then p.sample = ns.AuraButton.Create(frame, true) end
    if not p.sample then return end
    if not on then return ns.AuraButton.Clear(p.sample) end
    placeIcon(frame, p.sample, PortraitAura.SLOTS[2].level)
    ns.AuraButton.ShowSample(p.sample, PortraitAura.SAMPLE, p.sampleStart)
end

function PortraitAura.Build(frame)
    if PortraitAura.Applies(frame.key) then frame.portraitAura = { buttons = {} } end
end

function PortraitAura.Style(frame)
    local p = frame.portraitAura
    if not p then return end
    showSample(frame)
    if frame.pretend then return end
    if InCombatLockdown() then return later(frame) end
    if p.container then applyAura(frame) else ensureAura(frame) end
end

-- A new unit is read by SetUnit; the same token (a new target) again.
function PortraitAura.Update(frame, event)
    local p = frame.portraitAura
    if not p or frame.pretend or not ensureAura(frame) then return end
    local container, unit = p.container, frame.unit or "none"
    if container:GetUnit() ~= unit then
        container:SetUnit(unit)
    elseif event ~= "UNIT_AURA" then
        container:UpdateAllAuras()
    end
end

-- A party button made ahead of time (Units/Units.lua).
function PortraitAura.Prepare(frame)
    if frame.portraitAura then ensureAura(frame) end
end

function PortraitAura.Preview(frame, on)
    local p = frame.portraitAura
    if not p then return end
    p.sampleStart = on and (p.sampleStart or GetTime()) or nil
    showSample(frame)
end

-- Party slots reshuffled: the same token may be someone else now.
ns.On("GROUP_ROSTER_UPDATE", function(event)
    for frame in pairs(auraFrames) do
        if frame.key == ns.Party.KEY and frame.unit and UnitExists(frame.unit) then PortraitAura.Update(frame, event) end
    end
end)

-- Test mode hides the live icons (they show real auras only).
ns.Listen("TEST_MODE", function()
    for frame in pairs(auraFrames) do
        if InCombatLockdown() then later(frame) else applyAura(frame) end
    end
end)

ns.OnAurasFree(function()
    for frame in pairs(auraFrames) do
        if frame.portraitAura.stale and not auraWaiting[frame] then applyAura(frame) end
    end
end)

ns.RegisterElement(PortraitAura)
