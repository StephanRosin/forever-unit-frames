local _, ns = ...

-- The shield watch on the player frame: the icons of your active absorb
-- shields and the exact total of all your absorbs, in a block of its own
-- that has a mover, or hangs from the player frame (shieldsAnchor FRAME,
-- the mover inactive then). Off by default (shieldsEnabled).
--
-- The icons come from a Blizzard aura container (CustomAuraContainerTemplate,
-- the machinery of Elements/AuraContainers.lua): one group, filter HELPFUL,
-- whose candidate filter admits only the watched spell IDs
-- (includeSpellIDs). The client reads the auras and fills the icons from
-- secure code, in combat too; it allows filtering helpful auras by spell on
-- the player (CanApplyIdentityCandidateFilters). Icon, swipe and countdown
-- numbers are the container's own. The addon reads no shield itself.
-- The container is made and configured out of combat only.
--
-- The watched spells are shipped groups (all Classic ranks) and the
-- player's additions: the player's class's group, the Priest group (a
-- priest's shield lands on anyone) and the potions and items. Their IDs go
-- to the container as they are: an ID the client does not know matches
-- nothing.
--
-- The number is one text: UnitGetTotalAbsorbs("player"), every absorb on
-- you. It may be secret, so it is never compared: the client writes it
-- through C_StringUtil.TruncateWhenZero, which gives the whole number and
-- an empty text for zero. So the text shows exactly while the total is
-- above zero. It hangs at a side of the container (which the client sizes
-- to its icons) from a frame with the untrusted-layout aspect, the only
-- kind the client lets anchor to a container.
local ShieldWatch = { name = "ShieldWatch", unitEvents = { "UNIT_AURA", "UNIT_ABSORB_AMOUNT_CHANGED" } }
ns.ShieldWatch = ShieldWatch

local Config, Pixel, AuraButton = ns.Config, ns.Pixel, ns.AuraButton

ShieldWatch.SCOPES = { player = true }
ShieldWatch.FILTER = "HELPFUL"
-- The container's one group.
ShieldWatch.GROUP = "shields"
-- The total text's frame: may anchor to the container.
ShieldWatch.TEXT_TEMPLATE = "DisableUntrustedLayoutScriptsTemplate"

-- The shipped shields, Classic spell IDs (every rank). class: a group
-- watched only for that class; anyone: for every class.
ShieldWatch.GROUPS = {
    { key = "Priest", class = "PRIEST", anyone = true, spells = {
        -- Power Word: Shield, ranks 1-10.
        { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 },
    } },
    { key = "Mage", class = "MAGE", spells = {
        { 11426, 13031, 13032, 13033 },              -- Ice Barrier
        { 1463, 8494, 8495, 10191, 10192, 10193 },   -- Mana Shield
        { 543, 8457, 8458, 10223, 10225 },           -- Fire Ward
        { 6143, 8461, 8462, 10177, 28609 },          -- Frost Ward
    } },
    { key = "Warlock", class = "WARLOCK", spells = {
        { 6229, 11739, 11740, 28610 },               -- Shadow Ward
        { 7812, 19438, 19440, 19441, 19442, 19443 }, -- Sacrifice (the Voidwalker's shield)
    } },
    { key = "Items", anyone = true, spells = {
        -- The protection potions' buffs: the normal and the Greater one.
        { 7233, 17543 },                             -- Fire Protection
        { 7239, 17544 },                             -- Frost Protection
        { 7242, 17548 },                             -- Shadow Protection
        { 7254, 17546 },                             -- Nature Protection
        { 7245, 17545 },                             -- Holy Protection
        { 17549 },                                   -- Arcane Protection
        { 23506 },                                   -- Aura of Protection (Arena Grand Master)
        { 29506 },                                   -- The Burrower's Shell
        { 13234 },                                   -- Harm Prevention Belt
    } },
}

-- Test mode: two shields and their total, so the block can be placed.
ShieldWatch.SAMPLES = {
    { icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", duration = 30 },
    { icon = "Interface\\Icons\\Spell_Ice_Lament", duration = 60 },
}
ShieldWatch.SAMPLE_TOTAL = 2068
-- The handle's length in icons.
ShieldWatch.HANDLE_ICONS = 2
-- Automatic text sizes: this share of the icon size.
ShieldWatch.AUTO_TIME = 0.4
ShieldWatch.AUTO_TOTAL = 0.5
-- Where a text placed at a side hangs from: outside it.
local OPPOSITE = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT", CENTER = "CENTER" }
-- Per growth direction: the corner icons start in, the step of the samples,
-- and the container's flow.
local CORNER = { RIGHT = "TOPLEFT", LEFT = "TOPRIGHT", UP = "BOTTOMLEFT", DOWN = "TOPLEFT" }
local STEP = { RIGHT = { 1, 0 }, LEFT = { -1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
local FLOW = {
    RIGHT = { horizontal = true, h = "Right", v = "Down" },
    LEFT = { horizontal = true, h = "Left", v = "Down" },
    UP = { horizontal = false, h = "Right", v = "Up" },
    DOWN = { horizontal = false, h = "Right", v = "Down" },
}

local function setting(scope, key) return Config.Get(scope, key) end

local function playerClass()
    local _, class = UnitClass("player")
    if ns.Secrets.IsSecret(class) then return nil end
    return class
end

-- Whether a group is watched: switched on, and the player's class's or
-- one for anyone.
function ShieldWatch.GroupWatched(scope, group)
    if setting(scope, "shields" .. group.key) ~= true then return false end
    if group.anyone then return true end
    return group.class == playerClass()
end

-- The watched spell IDs, a map ID -> true (the container's includeSpellIDs).
-- Kept until the settings change or a new world loads.
local watchedCache = {}

local function buildWatched(scope)
    local set = {}
    for _, group in ipairs(ShieldWatch.GROUPS) do
        if ShieldWatch.GroupWatched(scope, group) then
            for _, ids in ipairs(group.spells) do
                for _, id in ipairs(ids) do set[id] = true end
            end
        end
    end
    for _, id in ipairs(ns.AuraBlocklist.Parse(setting(scope, "shieldsExtra")) or {}) do set[id] = true end
    return set
end

function ShieldWatch.Watched(scope)
    local set = watchedCache[scope]
    if not set then
        set = buildWatched(scope)
        watchedCache[scope] = set
    end
    return set
end

local function copy(set)
    local out
    for id in pairs(set) do
        out = out or {}
        out[id] = true
    end
    return out
end

-- The spell IDs the frame's buffs leave out (Elements/Auras.lua): every
-- watched ID while the watch and "hide them in the buffs" are on; nil
-- otherwise.
function ShieldWatch.HiddenSet(scope)
    if not ShieldWatch.SCOPES[scope] then return nil end
    if setting(scope, "shieldsEnabled") ~= true or setting(scope, "shieldsHideInBuffs") ~= true then return nil end
    return copy(ShieldWatch.Watched(scope))
end

-- The total -------------------------------------------------------------------------
-- Writes a total (plain or secret): the whole number, empty at zero, by
-- the client. Nothing is compared; a refusal leaves the text empty.
function ShieldWatch.SetTotal(fs, v)
    local ok, text = pcall(C_StringUtil.TruncateWhenZero, v)
    if ok then
        fs:SetText(text)
    else
        fs:SetText("")
    end
end

local function writeTotal(sw, unit)
    local ok, v = pcall(UnitGetTotalAbsorbs, unit)
    if ok then
        ShieldWatch.SetTotal(sw.total, v)
    else
        sw.total:SetText("")
    end
end

-- Building ----------------------------------------------------------------------------

function ShieldWatch.Build(frame)
    if not ShieldWatch.SCOPES[frame.key] then return end
    local holder = CreateFrame("Frame", nil, frame)
    holder:Hide()
    local sw = { holder = holder, samples = {}, buttons = {}, shown = 0 }
    frame.shields = sw
    for i = 1, #ShieldWatch.SAMPLES do sw.samples[i] = AuraButton.Create(holder, false) end
    local ok, host = pcall(CreateFrame, "Frame", nil, holder, ShieldWatch.TEXT_TEMPLATE)
    if not ok then host = CreateFrame("Frame", nil, holder) end
    host:SetAllPoints(holder)
    sw.textHost = host
    sw.total = host:CreateFontString(nil, "OVERLAY")
end

local function iconSize(scope) return Pixel.Snap(setting(scope, "shieldsSize")) end
local function spacing(scope) return Pixel.Snap(setting(scope, "shieldsSpacing")) end

-- The handle's (and the block's) size: HANDLE_ICONS icons in the growth
-- direction.
function ShieldWatch.Size(scope)
    local size, n = iconSize(scope), ShieldWatch.HANDLE_ICONS
    local length = n * size + (n - 1) * spacing(scope)
    local growth = setting(scope, "shieldsGrowth")
    if growth == "UP" or growth == "DOWN" then return size, length end
    return length, size
end

local function enabled(scope)
    return ns.FrameEnabled(scope) and setting(scope, "shieldsEnabled") == true
end

-- On the player frame (shieldsAnchor FRAME) rather than free on its mover.
function ShieldWatch.OnFrame(scope)
    return setting(scope, "shieldsAnchor") == "FRAME"
end

-- Inside the screen: the block's centre at most half the screen minus half
-- the block from the middle.
local function clamp(scope, axis, v)
    local w, h = ShieldWatch.Size(scope)
    local half = axis == "x" and (UIParent:GetWidth() - w) / 2 or (UIParent:GetHeight() - h) / 2
    if half <= 0 then return 0 end
    return math.max(-half, math.min(half, v))
end

function ShieldWatch.MoverSpec(frame)
    local scope = frame.key
    return {
        id = "shields:" .. scope, scope = scope, xKey = "shieldsX", yKey = "shieldsY", anchor = false,
        label = function() return ns.L.MOVER_SHIELDS:format(ns.L["FRAME_" .. scope]) end,
        size = function() return ShieldWatch.Size(scope) end,
        active = function() return enabled(scope) and not ShieldWatch.OnFrame(scope) end,
        clamp = function(axis, v) return clamp(scope, axis, v) end,
    }
end

-- The block on its handle, or (no handle yet) where the handle would be;
-- on the frame: its point at the frame's point (it is the frame's child,
-- so it moves and scales with it). Out of combat, like every restyle.
local function place(frame)
    local sw, scope = frame.shields, frame.key
    local holder = sw.holder
    local w, h = ShieldWatch.Size(scope)
    holder:ClearAllPoints()
    if ShieldWatch.OnFrame(scope) then
        if holder.mover then ns.Movers.Sync(holder) end
        holder:SetSize(Pixel.Snap(w), Pixel.Snap(h))
        holder:SetPoint(setting(scope, "shieldsPoint"), frame, setting(scope, "shieldsFramePoint"),
            Pixel.Snap(setting(scope, "shieldsFrameX")), Pixel.Snap(setting(scope, "shieldsFrameY")))
    elseif holder.mover then
        ns.Movers.Sync(holder)
        holder:SetAllPoints(holder.mover)
    else
        holder:SetSize(w, h)
        holder:SetPoint("CENTER", UIParent, "CENTER", Pixel.Centre(setting(scope, "shieldsX"), w),
            Pixel.Centre(setting(scope, "shieldsY"), h))
    end
end

local function fontOf(scope, key)
    local face = setting(scope, key)
    if face == "" then face = setting(scope, "fontFace") end
    return ns.Media.Font(face)
end

local function textSize(scope, key, share)
    local own = setting(scope, key)
    if own > 0 then return own end
    return math.max(6, math.floor(setting(scope, "shieldsSize") * share + 0.5))
end

local function outlineOf(scope, key)
    local outline = setting(scope, key)
    if outline == "FRAME" then outline = setting(scope, "fontOutline") end
    return outline
end

-- Size, swipe and the countdown numbers (the time text) of an icon: a
-- sample of ours or a container's button (managed). The client writes the
-- numbers, so a soft outline becomes the plain one.
local function styleButton(button, scope, managed)
    local showTime = setting(scope, "shieldsTime") == true
    if managed then
        AuraButton.StyleManaged(button, scope, iconSize(scope), showTime)
    else
        AuraButton.Style(button, scope, iconSize(scope), showTime)
    end
    button.cooldown:SetDrawSwipe(setting(scope, "shieldsSwipe") == true)
    local numbers = button.cooldown:GetCountdownFontString()
    if numbers then
        local outline = outlineOf(scope, "shieldsTimeOutline")
        local flags = (outline == "SOFT" or outline == "NONE") and (outline == "SOFT" and "OUTLINE" or "") or outline
        numbers:SetFont(fontOf(scope, "shieldsTimeFont"), textSize(scope, "shieldsTimeSize", ShieldWatch.AUTO_TIME),
            flags)
        local t = setting(scope, "shieldsTimeColor")
        numbers:SetTextColor(t[1], t[2], t[3], t[4])
        local point = setting(scope, "shieldsTimePoint")
        numbers:ClearAllPoints()
        numbers:SetPoint(OPPOSITE[point], button, point, setting(scope, "shieldsTimeX"), setting(scope, "shieldsTimeY"))
    end
end

-- The samples in a row from the block's first corner.
local function layoutSample(frame, button, i)
    local scope = frame.key
    local growth = setting(scope, "shieldsGrowth")
    local corner, step = CORNER[growth], STEP[growth]
    local offset = (i - 1) * (iconSize(scope) + spacing(scope))
    button:ClearAllPoints()
    button:SetPoint(corner, frame.shields.holder, corner, step[1] * offset, step[2] * offset)
end

-- The container ----------------------------------------------------------------------------

-- A container's button: our regions and look, then the regions the client
-- fills (icon, swipe with its countdown, count). In initializeFrame only:
-- afterwards it refuses us while auras are secret.
local function initButton(frame, button)
    AuraButton.Decorate(button, false)
    styleButton(button, frame.key, true)
    frame.shields.buttons[#frame.shields.buttons + 1] = button
    ns.AuraContainers.Wire(button, false)
end

local function layout(scope)
    local size, gap = iconSize(scope), spacing(scope)
    return { elementWidth = size, elementHeight = size, elementSpacing = gap, lineSpacing = gap, groupSpacing = gap,
        groupLineSpacing = gap }
end

local function candidateFilters(scope)
    return { includeSpellIDs = ShieldWatch.Watched(scope) }
end

-- Made the first time the block is styled with the watch on (out of
-- combat): with it off there is none. On a refusal nothing is kept: the
-- block shows the total only.
local function ensureContainer(frame)
    local sw = frame.shields
    if sw.container or sw.containerFailed or not enabled(frame.key) then return sw.container end
    if not ns.AuraContainers.Supported() then return nil end
    local container
    local ok, err = pcall(function()
        container = CreateFrame("AuraContainer", nil, sw.holder, ns.AuraContainers.TEMPLATE)
        container:SetEditModePreviewEnabled(false)
        container:AddAuraGroup(ShieldWatch.GROUP, ShieldWatch.FILTER, { layout = layout(frame.key),
            candidateFilters = candidateFilters(frame.key),
            initializeFrame = function(button) initButton(frame, button) end })
        container:SetUnit(frame.unit or "none")
    end)
    if not ok then
        if container then container:Hide() end
        sw.containerFailed = true
        geterrorhandler()(err)
        return nil
    end
    sw.container = container
    return container
end

-- The buttons made so far get the current look; refused while auras are
-- secret (tried again after combat).
local function restyle(frame)
    local sw = frame.shields
    sw.stale = false
    for _, button in ipairs(sw.buttons) do
        if not pcall(styleButton, button, frame.key, true) then sw.stale = true end
    end
end

-- Settings onto the container: flow from the block's first corner, the
-- icons' size and spacing, the watched spells; shown with the watch,
-- hidden in test mode (it shows only real auras). Out of combat only.
local function configure(frame)
    local sw, scope = frame.shields, frame.key
    local container = ensureContainer(frame)
    if not container then return end
    local growth = setting(scope, "shieldsGrowth")
    local flow, corner = FLOW[growth], CORNER[growth]
    container:SetFlowLayoutAxis(flow.horizontal and AnchorUtil.FlowLayoutAxis.Horizontal
        or AnchorUtil.FlowLayoutAxis.Vertical)
    container:SetFlowLayoutAnchorPoint(corner)
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection[flow.h], AnchorUtil.FlowDirection[flow.v])
    container:SetAuraGroupLayout(ShieldWatch.GROUP, layout(scope))
    container:SetAuraGroupCandidateFilters(ShieldWatch.GROUP, candidateFilters(scope))
    restyle(frame)
    container:ClearAllPoints()
    container:SetPoint(corner, sw.holder, corner, 0, 0)
    container:SetFrameLevel(sw.holder:GetFrameLevel() + 1)
    container:SetShown(enabled(scope) and not sw.preview)
    if container:GetUnit() ~= (frame.unit or "none") then container:SetUnit(frame.unit or "none") end
end

-- The total at its side of the icons: the container's (the client sizes it
-- to its icons), or the handle's in test mode and without a container.
local function placeTotal(frame)
    local sw, scope = frame.shields, frame.key
    local region = (not sw.preview and sw.container) or sw.holder
    local point = setting(scope, "shieldsTotalPoint")
    sw.total:ClearAllPoints()
    sw.total:SetPoint(OPPOSITE[point], region, point, setting(scope, "shieldsTotalX"), setting(scope, "shieldsTotalY"))
end

local function styleTotal(frame)
    local sw, scope = frame.shields, frame.key
    ns.Texts.SetFont(sw.total, fontOf(scope, "shieldsTotalFont"),
        textSize(scope, "shieldsTotalSize", ShieldWatch.AUTO_TOTAL), outlineOf(scope, "shieldsTotalOutline"))
    local c = setting(scope, "shieldsTotalColor")
    sw.total:SetTextColor(c[1], c[2], c[3], c[4])
    sw.textHost:SetFrameLevel(sw.holder:GetFrameLevel() + 2)
end

-- Out of combat (the unit frames restyle there).
function ShieldWatch.Style(frame)
    local sw = frame.shields
    if not sw then return end
    local scope = frame.key
    place(frame)
    sw.holder:SetFrameLevel(frame:GetFrameLevel() + ns.Auras.LEVELS)
    for i, button in ipairs(sw.samples) do
        styleButton(button, scope, false)
        layoutSample(frame, button, i)
    end
    configure(frame)
    styleTotal(frame)
    placeTotal(frame)
    sw.styled = true
    ShieldWatch.Refresh(frame)
end

-- Showing ------------------------------------------------------------------------------------

local function showSamples(sw, on)
    if not on and not sw.sampleStart then return end
    sw.sampleStart = on and (sw.sampleStart or GetTime()) or nil
    for i, button in ipairs(sw.samples) do
        if on then
            AuraButton.ShowSample(button, ShieldWatch.SAMPLES[i], sw.sampleStart)
        else
            AuraButton.Clear(button)
        end
    end
    sw.shown = on and #sw.samples or 0
end

-- Any time, combat included: the total and, in test mode, the samples.
-- The container follows the player's auras by itself.
function ShieldWatch.Refresh(frame)
    local sw = frame.shields
    if not (sw and sw.styled) then return end
    local scope = frame.key
    local on = enabled(scope)
    sw.holder:SetShown(on)
    showSamples(sw, on and sw.preview or false)
    sw.total:SetShown(on and setting(scope, "shieldsTotal") == true)
    if not on then return sw.total:SetText("") end
    if sw.preview then return ShieldWatch.SetTotal(sw.total, ShieldWatch.SAMPLE_TOTAL) end
    writeTotal(sw, frame.unit or "none")
end

function ShieldWatch.Update(frame)
    if frame.shields then ShieldWatch.Refresh(frame) end
end

-- Test mode: the two samples and a sample total; the container hides.
function ShieldWatch.Preview(frame, on)
    local sw = frame.shields
    if not sw then return end
    sw.preview = on or nil
    ShieldWatch.Refresh(frame)
    ns.AfterCombat("shieldsPreview:" .. frame.key, function()
        if sw.container then sw.container:SetShown(enabled(frame.key) and not sw.preview) end
        placeTotal(frame)
    end)
end

-- The handle: made with the frames, out of combat.
function ShieldWatch.AttachMover(frame)
    local sw = frame.shields
    if not sw then return end
    ns.Movers.Attach(sw.holder, ShieldWatch.MoverSpec(frame))
    ns.AfterCombat("shieldsStyle:" .. frame.key, function() ShieldWatch.Style(frame) end)
end

local function forEachBlock(fn)
    for scope in pairs(ShieldWatch.SCOPES) do
        local frame = ns.Frames and ns.Frames[scope]
        if frame and frame.shields and frame.shields.styled then fn(frame) end
    end
end

-- The watched list again after a settings change; after a new world the
-- container gets it too (the class is known by then).
ns.Listen("CONFIG_CHANGED", function() watchedCache = {} end)
ns.On("PLAYER_ENTERING_WORLD", function()
    watchedCache = {}
    forEachBlock(function(frame)
        ns.AfterCombat("shieldsStyle:" .. frame.key, function() ShieldWatch.Style(frame) end)
    end)
end)

-- Buttons the client refused to restyle (auras were secret): again now.
ns.On("PLAYER_REGEN_ENABLED", function()
    forEachBlock(function(frame)
        if frame.shields.stale then restyle(frame) end
    end)
end)

ns.RegisterElement(ShieldWatch)
