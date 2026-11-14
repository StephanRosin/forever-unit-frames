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
--
-- The bar (shieldsBar): a vertical StatusBar beside the first icon, as
-- tall as it, that empties with the same total. Its maximum is the total
-- read shortly after one of the watched spells was cast by you or your pet
-- (UNIT_SPELLCAST_SUCCEEDED, as Shield Aura Forever does): the client takes
-- the secret value as the maximum too. Until then the maximum is the total
-- itself (full while any absorb is up).
-- It has no background: whether a shield is up cannot be asked (the total
-- is secret), so with none the empty fill is all there is and nothing
-- shows. The designs draw on the fill only, in a frame on the fill that
-- clips (as Elements/Absorb.lua's glow): stripes, segment lines, a frame.
-- It sits beside the first icon (shieldsBarAnchor ICONS) or free on a
-- mover of its own (FREE), then a child of UIParent so the player frame's
-- scale does not move it off its handle.
-- shortcut: a shield cast on someone else also captures your total (the
-- event names no target), and a shield from another player captures
-- nothing; the bar then shows full until it falls below the old maximum.
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
-- Test mode: the bar's fill.
ShieldWatch.SAMPLE_BAR = 0.7
-- The designs: Blizzard's shield stripes; segment lines over the bar's
-- whole height (shown where the fill is); a dark frame round the fill.
ShieldWatch.STRIPES = "Interface\\RaidFrame\\Shield-Overlay"
ShieldWatch.SEGMENTS = 5
ShieldWatch.LINE_COLOR = { 0, 0, 0, 0.8 }
-- Colour mode GRADIENT: bottom and top. No Lua knows the share left (the
-- total is secret, and colour curves take secrets from Blizzard's code
-- only), so the gradient spans the whole height and the fill shows of it
-- what it covers.
ShieldWatch.GRADIENT_EMPTY = { 0.9, 0.15, 0.1, 1 }
ShieldWatch.GRADIENT_FULL = { 0.2, 0.9, 0.2, 1 }
-- The frame's four lines: their two corners, and whether they run across.
local FRAME_EDGES = { { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
    { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }
-- After a watched cast: when the new total is read as the bar's maximum
-- (the absorb lands a moment after the cast event).
ShieldWatch.CAPTURE_DELAYS = { 0.05, 0.2 }
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

-- The total, plain or secret, onto the text and the bar; never compared.
local function writeTotal(sw, unit)
    local ok, v = pcall(UnitGetTotalAbsorbs, unit)
    if ok then
        ShieldWatch.SetTotal(sw.total, v)
        pcall(sw.bar.SetMinMaxValues, sw.bar, 0, sw.barMax or v)
        pcall(sw.bar.SetValue, sw.bar, v)
    else
        sw.total:SetText("")
        sw.bar:SetValue(0)
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
    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0, 1)
    bar:Hide()
    sw.bar = bar
    -- The fill's frame (anchored in Style, the fill texture is set there).
    local gate = CreateFrame("Frame", nil, bar)
    gate:SetClipsChildren(true)
    bar.gate = gate
    local stripes = gate:CreateTexture(nil, "OVERLAY")
    stripes:SetTexture(ShieldWatch.STRIPES, "REPEAT", "REPEAT")
    stripes:SetHorizTile(true)
    stripes:SetVertTile(true)
    stripes:SetAllPoints(gate)
    bar.stripes = stripes
    bar.gradient = gate:CreateTexture(nil, "ARTWORK")
    local c = ShieldWatch.LINE_COLOR
    bar.lines = {}
    for i = 1, ShieldWatch.SEGMENTS - 1 + 4 do
        local t = gate:CreateTexture(nil, "OVERLAY", nil, 1)
        t:SetColorTexture(c[1], c[2], c[3], c[4])
        bar.lines[i] = t
    end
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
        -- Size and offset in the frame's units: on its pixel grid.
        holder:SetSize(Pixel.Snap(w, frame), Pixel.Snap(h, frame))
        holder:SetPoint(setting(scope, "shieldsPoint"), frame, setting(scope, "shieldsFramePoint"),
            Pixel.Snap(setting(scope, "shieldsFrameX"), frame), Pixel.Snap(setting(scope, "shieldsFrameY"), frame))
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
        AuraButton.Style(button, scope, iconSize(scope), showTime)
    else
        AuraButton.Style(button, scope, iconSize(scope), showTime)
    end
    button.cooldown:SetDrawSwipe(setting(scope, "shieldsSwipe") == true)
    local numbers = button.cooldown:GetCountdownFontString()
    if numbers then
        numbers:SetFont(fontOf(scope, "shieldsTimeFont"), textSize(scope, "shieldsTimeSize", ShieldWatch.AUTO_TIME),
            ns.Texts.CountdownFlags(outlineOf(scope, "shieldsTimeOutline")))
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

-- The bar's side: before the first icon, the icons grow away from it.
local function barSide(scope)
    return setting(scope, "shieldsGrowth") == "LEFT" and "RIGHT" or "LEFT"
end

-- The bar's size: its width, its height or (0) an icon's.
function ShieldWatch.BarSize(scope)
    local h = setting(scope, "shieldsBarHeight")
    return Pixel.Snap(setting(scope, "shieldsBarWidth")), h > 0 and Pixel.Snap(h) or iconSize(scope)
end

local function barFree(scope) return setting(scope, "shieldsBarAnchor") == "FREE" end

function ShieldWatch.BarMoverSpec(frame)
    local scope = frame.key
    return {
        id = "shieldBar:" .. scope, scope = scope, xKey = "shieldsBarFreeX", yKey = "shieldsBarFreeY", anchor = false,
        label = function() return ns.L.MOVER_SHIELD_BAR:format(ns.L["FRAME_" .. scope]) end,
        size = function() return ShieldWatch.BarSize(scope) end,
        active = function()
            return enabled(scope) and setting(scope, "shieldsBar") == true and barFree(scope)
        end,
    }
end

local function placeBar(frame)
    local sw, scope = frame.shields, frame.key
    local bar, corner = sw.bar, CORNER[setting(scope, "shieldsGrowth")]
    local side = barSide(scope)
    local point = corner:gsub(side, OPPOSITE[side])
    bar:ClearAllPoints()
    local w, h = ShieldWatch.BarSize(scope)
    bar:SetSize(w, h)
    if barFree(scope) then
        bar:SetParent(UIParent)
        bar:SetFrameStrata(sw.holder:GetFrameStrata())
        if bar.mover then
            ns.Movers.Sync(bar)
            bar:SetAllPoints(bar.mover)
        else
            bar:SetPoint("CENTER", UIParent, "CENTER", Pixel.Centre(setting(scope, "shieldsBarFreeX"), w),
                Pixel.Centre(setting(scope, "shieldsBarFreeY"), h))
        end
    else
        bar:SetParent(sw.holder)
        bar:SetPoint(point, sw.holder, corner,
            (side == "LEFT" and -1 or 1) * spacing(scope) + setting(scope, "shieldsBarX"), setting(scope, "shieldsBarY"))
    end
    bar:SetFrameLevel(sw.holder:GetFrameLevel() + 1)
    bar:SetStatusBarTexture(ns.Media.StatusBar(setting(scope, "barTexture")))
    local c = setting(scope, "shieldsBarColor")
    local gradient = setting(scope, "shieldsBarColorMode") == "GRADIENT"
    -- With the gradient the fill only measures; the gradient is seen.
    bar:SetStatusBarColor(c[1], c[2], c[3], gradient and 0 or c[4])
    local gate, style = bar.gate, setting(scope, "shieldsBarStyle")
    gate:ClearAllPoints()
    gate:SetAllPoints(bar:GetStatusBarTexture())
    gate:SetFrameLevel(bar:GetFrameLevel() + 1)
    local g = bar.gradient
    g:SetAllPoints(bar)
    g:SetTexture(ns.Media.StatusBar(setting(scope, "barTexture")))
    local lo, hi = ShieldWatch.GRADIENT_EMPTY, ShieldWatch.GRADIENT_FULL
    g:SetGradient("VERTICAL", CreateColor(lo[1], lo[2], lo[3], lo[4]), CreateColor(hi[1], hi[2], hi[3], hi[4]))
    g:SetShown(gradient)
    bar.stripes:SetShown(style == "STRIPES")
    -- Lines 1..SEGMENTS-1 split the bar's height; the last four frame the fill.
    local one, n = Pixel.One(bar), ShieldWatch.SEGMENTS
    for i, t in ipairs(bar.lines) do
        t:ClearAllPoints()
        if i < n then
            t:SetHeight(one)
            local y = Pixel.Snap(h * i / n)
            t:SetPoint("LEFT", bar, "BOTTOMLEFT", 0, y)
            t:SetPoint("RIGHT", bar, "BOTTOMRIGHT", 0, y)
            t:SetShown(style == "SEGMENTS")
        else
            local edge = FRAME_EDGES[i - n + 1]
            t:SetPoint(edge[1], gate, edge[1])
            t:SetPoint(edge[2], gate, edge[2])
            if edge[3] then t:SetHeight(one) else t:SetWidth(one) end
            t:SetShown(style == "FRAMED")
        end
    end
end

-- The total at its side of the icons: the container's (the client sizes it
-- to its icons), or the handle's in test mode and without a container.
local function placeTotal(frame)
    local sw, scope = frame.shields, frame.key
    local region = (not sw.preview and sw.container) or sw.holder
    local point = setting(scope, "shieldsTotalPoint")
    -- On the bar's side: outside the bar.
    if setting(scope, "shieldsBar") == true and not barFree(scope) and point == barSide(scope) then region = sw.bar end
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
    placeBar(frame)
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
    sw.bar:SetShown(on and setting(scope, "shieldsBar") == true)
    if not on then return sw.total:SetText("") end
    if sw.preview then
        sw.bar:SetMinMaxValues(0, 1)
        sw.bar:SetValue(ShieldWatch.SAMPLE_BAR)
        return ShieldWatch.SetTotal(sw.total, ShieldWatch.SAMPLE_TOTAL)
    end
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
    ns.Movers.Attach(sw.bar, ShieldWatch.BarMoverSpec(frame))
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

-- A watched shield cast by you or your pet: the total a moment later is the
-- bar's full. A secret spell ID captures nothing.
function ShieldWatch.Capture(frame)
    local ok, v = pcall(UnitGetTotalAbsorbs, frame.unit or "player")
    if not ok then return end
    frame.shields.barMax = v
    ShieldWatch.Refresh(frame)
end

ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit ~= "player" and unit ~= "pet" then return end
    if spellID == nil or ns.Secrets.IsSecret(spellID) then return end
    forEachBlock(function(frame)
        if not (enabled(frame.key) and ShieldWatch.Watched(frame.key)[spellID]) then return end
        for _, delay in ipairs(ShieldWatch.CAPTURE_DELAYS) do
            C_Timer.After(delay, function() ShieldWatch.Capture(frame) end)
        end
    end)
end)

-- Buttons the client refused to restyle (auras were secret): again now.
ns.On("PLAYER_REGEN_ENABLED", function()
    forEachBlock(function(frame)
        if frame.shields.stale then restyle(frame) end
    end)
end)

ns.RegisterElement(ShieldWatch)
