local _, ns = ...

-- Dispel highlight on the player and party frames: while the unit carries
-- a debuff your class can dispel, a ring over the frame's border takes the
-- debuff type's colour (the aura icons' colours, AuraButton.DISPEL_COLORS).
--
-- Aura reads are refused in combat for party members, so the live ring
-- comes from the client, as the frame's aura icons do (Elements/
-- AuraContainers.lua): a Blizzard CustomAuraContainerTemplate with one
-- group, filter "HARMFUL|RAID" (RAID: "harmful auras the player can
-- dispel", AuraUtil.AuraFilters) and one slot. Its button is never seen
-- itself (one pixel, no mouse); it carries four edge textures, anchored
-- around the unit frame and registered with AddDispelTypeTexture (style
-- PreserveAsset, our colour curve). The client shows the button, and with
-- it the ring, only while such a debuff exists, and colours the edges
-- from the aura's dispel type through the curve
-- (C_UnitAuras.GetAuraDispelTypeColor in Blizzard_CustomAuraButton.lua),
-- in combat too. Nothing is read by the addon.
--
-- The ring hugs the frame, not a docked castbar: its anchors are set out
-- of combat and cannot follow the castbar showing and hiding. Containers
-- are made and configured out of combat only, like the aura containers.
--
-- The client makes a container's buttons in batches of ten
-- (CustomAuraContainerConstants.FrameCreationBatchSize, not an option of
-- AddAuraGroup; maxFrameCount only limits how many show), and dispel type
-- textures must belong to the button: every button carries its own four
-- edges. They stay hidden with their button.
--
-- Where the client cannot make containers, the same ring is a plain one,
-- drawn from our own read (out of combat; in combat the client refuses
-- and the last state stays until combat ends). Test mode uses the plain
-- ring for its sample.
local Dispel = { name = "Dispel", unitEvents = { "UNIT_AURA" } }
ns.Dispel = Dispel

local Config, Pixel, Secrets, Settings = ns.Config, ns.Pixel, ns.Secrets, ns.Settings

Dispel.FILTER = "HARMFUL|RAID"
Dispel.GROUP = "dispel"
-- The ring is at least this many pixels thick (the border's size when
-- that is more).
Dispel.MIN_THICKNESS = 2
-- Above the border rings (+1), below the text overlay (+10).
Dispel.LEVELS = 3
-- Test mode: pretend party member 1 carries a magic debuff.
Dispel.PARTY_SAMPLES = { [1] = "Magic" }

-- Frames with a container, frames waiting for the end of combat.
local all = setmetatable({}, { __mode = "k" })
local waiting = setmetatable({}, { __mode = "k" })

local function testing() return ns.TestMode ~= nil and ns.TestMode.IsOn() end

function Dispel.Applies(scope)
    return Settings.AppliesTo(Settings.Get("dispelHighlight"), scope)
end

local function wanted(frame) return Config.Get(frame.key, "dispelHighlight") end

-- Four edges around frame: the outer edge `reach` outside it (the
-- border's outer edge), `thick` wide inwards.
local function placeRing(edges, frame, reach, thick)
    local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
    for _, edge in ipairs(edges) do edge:ClearAllPoints() end
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", -reach, reach)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", reach, reach)
    top:SetHeight(thick)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -reach, -reach)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", reach, -reach)
    bottom:SetHeight(thick)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", -reach, reach - thick)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -reach, -reach + thick)
    left:SetWidth(thick)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", reach, reach - thick)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", reach, -reach + thick)
    right:SetWidth(thick)
end

local function ringSize(frame)
    local scope = frame.key
    local thick = math.max(ns.Border.Size(scope), Pixel.Snap(Dispel.MIN_THICKNESS, nil, 1))
    return ns.Border.Extent(scope), thick
end

local function newEdges(owner)
    local edges = {}
    for i = 1, 4 do
        edges[i] = owner:CreateTexture(nil, "OVERLAY")
        edges[i]:SetColorTexture(1, 1, 1, 1)
    end
    return edges
end

local function paint(edges, r, g, b, a)
    for _, edge in ipairs(edges) do edge:SetVertexColor(r, g, b, a) end
end

-- Plain ring: test mode and clients without containers ------------------------------

function Dispel.Build(frame)
    if not Dispel.Applies(frame.key) then return end
    local ring = CreateFrame("Frame", nil, frame)
    ring:SetAllPoints(frame)
    ring.edges = newEdges(ring)
    ring:Hide()
    frame.dispel = { ring = ring, buttons = {} }
end

local function showPlain(frame, dispelName)
    local ring = frame.dispel.ring
    local c = ns.AuraButton.DISPEL_COLORS[dispelName]
    if c then paint(ring.edges, c[1], c[2], c[3], 1) end
    ring:SetShown(c ~= nil and wanted(frame))
end

-- Our own read, out of combat: the first debuff you can dispel, coloured
-- by its readable type or else by the client from our curve. Refused:
-- the ring stays as it was.
local function readPlain(frame)
    local ring, unit = frame.dispel.ring, frame.unit
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, Dispel.FILTER, 1)
    if not ok or type(list) ~= "table" or Secrets.IsSecret(list) then return end
    local aura = list[1]
    if type(aura) ~= "table" or Secrets.IsSecret(aura) or not wanted(frame) then
        ring:Hide()
        return
    end
    local name = aura.dispelName
    if not Secrets.IsSecret(name) then
        showPlain(frame, type(name) == "string" and name or "NONE")
        return
    end
    local id = aura.auraInstanceID
    if Secrets.IsSecret(id) or type(id) ~= "number" then return end
    local asked, color = pcall(C_UnitAuras.GetAuraDispelTypeColor, unit, id, ns.AuraButton.DispelCurve())
    if not asked or type(color) == "nil" then return end
    paint(ring.edges, color:GetRGBA())
    ring:Show()
end

-- The live container ----------------------------------------------------------------

-- A button of the container: one pixel, no mouse, the ring's edges around
-- the unit frame as its dispel type textures.
local function initButton(frame, button)
    pcall(button.SetMouseClickEnabled, button, false)
    pcall(button.SetMouseMotionEnabled, button, false)
    local edges = newEdges(button)
    placeRing(edges, frame, ringSize(frame))
    local options = { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        customDispelColorCurve = ns.AuraButton.DispelCurve() }
    for _, edge in ipairs(edges) do button:AddDispelTypeTexture(edge, options) end
    local d = frame.dispel
    d.buttons[#d.buttons + 1] = edges
end

-- Size and place of every ring made so far. Refused while auras are
-- secret (the buttons lock): tried again after combat.
local function apply(frame)
    local d = frame.dispel
    d.stale = false
    local reach, thick = ringSize(frame)
    for _, edges in ipairs(d.buttons) do
        if not pcall(placeRing, edges, frame, reach, thick) then d.stale = true end
    end
    d.container:SetFrameLevel(frame:GetFrameLevel() + Dispel.LEVELS)
    d.container:SetShown(wanted(frame) and not testing())
end

local function build(frame)
    local d = frame.dispel
    local ok, err = pcall(function()
        local container = CreateFrame("AuraContainer", nil, frame, ns.AuraContainers.TEMPLATE)
        d.container = container
        container:SetEditModePreviewEnabled(false)
        container:AddAuraGroup(Dispel.GROUP, Dispel.FILTER, { maxFrameCount = 1,
            layout = { elementWidth = 1, elementHeight = 1 },
            initializeFrame = function(button) initButton(frame, button) end })
        container:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        container:SetUnit(frame.unit or "none")
    end)
    if not ok then
        if d.container then d.container:Hide() end
        d.container, d.failed = nil, true
        geterrorhandler()(err)
        return
    end
    all[frame] = true
    apply(frame)
end

local function flush()
    local frames = {}
    for frame in pairs(waiting) do frames[#frames + 1] = frame end
    for _, frame in ipairs(frames) do
        waiting[frame] = nil
        if frame.dispel.container then apply(frame) elseif not frame.dispel.failed then build(frame) end
    end
end

local function later(frame)
    waiting[frame] = true
    ns.AfterCombat("dispelContainers", flush)
end

-- Whether the frame's ring comes from a container (made now, or after
-- combat). False: the plain ring, from our own read.
local function ensure(frame)
    local d = frame.dispel
    if d.container then return true end
    if frame.pretend or d.failed or not ns.AuraContainers.Supported() then return false end
    if InCombatLockdown() then
        later(frame)
        return true
    end
    build(frame)
    return d.container ~= nil
end

-- Element -----------------------------------------------------------------------------

function Dispel.Style(frame)
    local d = frame.dispel
    if not d then return end
    placeRing(d.ring.edges, frame, ringSize(frame))
    if d.sample then showPlain(frame, d.sample) end
    if not d.container then return end
    if InCombatLockdown() then later(frame) else apply(frame) end
end

-- Pretend party members show their sample only.
function Dispel.Update(frame, event)
    local d = frame.dispel
    if not d or d.sample ~= nil or frame.pretend then return end
    if ensure(frame) then
        d.ring:Hide()
        local container = d.container
        if not container then return end
        local unit = frame.unit or "none"
        if container:GetUnit() ~= unit then
            container:SetUnit(unit)
        elseif event ~= "UNIT_AURA" then
            container:UpdateAllAuras()
        end
        return
    end
    readPlain(frame)
end

-- In test mode d.sample is the frame's sample dispel type, false for none.
function Dispel.Preview(frame, on)
    local d = frame.dispel
    if not d then return end
    if on then
        d.sample = frame.sampleIndex and Dispel.PARTY_SAMPLES[frame.sampleIndex] or false
        showPlain(frame, d.sample or nil)
    else
        d.sample = nil
        d.ring:Hide()
        if frame.unit and UnitExists(frame.unit) then Dispel.Update(frame) end
    end
end

-- Party slots reshuffled: party2 may now be someone else under the same
-- token, which the container does not notice by itself (as the aura
-- containers, Elements/AuraContainers.lua).
ns.On("GROUP_ROSTER_UPDATE", function(event)
    for frame in pairs(all) do
        if frame.key == ns.Party.KEY and frame.unit and UnitExists(frame.unit) then Dispel.Update(frame, event) end
    end
end)

-- Test mode hides the live rings (they show real debuffs only); out of
-- combat, as test mode itself.
ns.Listen("TEST_MODE", function()
    for frame in pairs(all) do
        if InCombatLockdown() then later(frame) else apply(frame) end
    end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    for frame in pairs(all) do
        if frame.dispel.stale and not waiting[frame] then apply(frame) end
    end
    -- Frames without a container look again: reads refused in combat left
    -- their plain ring out of date.
    ns.Units.ForEachFrame(function(frame)
        local d = frame.dispel
        if d and not d.container and frame.unit and UnitExists(frame.unit) then Dispel.Update(frame) end
    end)
end)

ns.RegisterElement(Dispel)
