local _, ns = ...

-- Buffs and debuffs of a unit frame: two groups, each a plain holder frame
-- with a pool of icons (Elements/AuraButton.lua). The holder hangs from a
-- region of the frame (or from the other group) and is as big as the
-- icons it shows, so a group hanging from it follows as it grows.
-- Nothing here is secure: holders and icons may change in combat.
local Auras = { name = "Auras", unitEvents = { "UNIT_AURA" } }
ns.Auras = Auras

local Config, Layout, Pixel, AuraButton, Secrets = ns.Config, ns.Layout, ns.Pixel, ns.AuraButton, ns.Secrets
local AuraContainers = ns.AuraContainers

-- Holders sit this many levels above the unit frame: over its bars, the
-- shield and the text overlay (+10), below the class badge (+20).
Auras.LEVELS = 12
-- Frames refreshed by a timer (target of target) read auras at most this
-- often.
Auras.POLL_SECONDS = 0.5
-- In test mode this many samples of a group count as yours.
Auras.OWN_SAMPLES = 2
-- The client sorts: auras you cast first (UnitAuraSortRule.Default).
local SORT_RULE = Enum and Enum.UnitAuraSortRule and Enum.UnitAuraSortRule.Default

local GROUPS = {
    buffs = { filter = "HELPFUL", isDebuff = false, other = "debuffs" },
    debuffs = { filter = "HARMFUL", isDebuff = true, other = "buffs" },
    -- RAID on harmful auras: those you can dispel (AuraUtil.AuraFilters).
    dispels = { filter = "HARMFUL|RAID", isDebuff = true, other = "debuffs" },
}
-- What a group has no setting for (the dispels group has only some).
local FIXED = { OnlyMine = false, Dispellable = false, HidePermanent = false, HighlightOwn = false,
    CasterBorder = false, OwnSameRow = false }
local ORDER = ns.Settings.AURA_GROUPS

-- Test mode samples, repeated up to each group's maximum. Icons Blizzard's
-- own UI uses, so the files exist.
Auras.SAMPLES = {
    buffs = {
        { icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", duration = 1800 },
        { icon = "Interface\\Icons\\Ability_Defend", duration = 600, count = 3 },
        { icon = "Interface\\Icons\\spell_holy_surgeoflight", duration = 120 },
        { icon = "Interface\\Icons\\Spell_Nature_TimeStop", duration = 3600 },
    },
    debuffs = {
        { icon = "Interface\\Icons\\Spell_Shadow_Teleport", duration = 300, dispel = "Magic" },
        { icon = "Interface\\Icons\\INV_Misc_Bone_Skull_02", duration = 240, dispel = "Curse" },
        { icon = "Interface\\Icons\\INV_AzeriteDebuff", duration = 180, count = 5, dispel = "Poison" },
        { icon = "Interface\\Icons\\Spell_Magic_PolymorphChicken", duration = 90, dispel = "Disease" },
        { icon = "Interface\\Icons\\INV_Misc_QuestionMark", duration = 600 },
    },
    dispels = {
        { icon = "Interface\\Icons\\Spell_Shadow_Teleport", duration = 300, dispel = "Magic" },
        { icon = "Interface\\Icons\\INV_Misc_Bone_Skull_02", duration = 240, dispel = "Curse" },
        { icon = "Interface\\Icons\\INV_AzeriteDebuff", duration = 180, count = 5, dispel = "Poison" },
    },
}
-- When the samples of this test mode session started (their swipes run
-- from there).
local sampleStart

-- Every frame with aura groups; weak, frames are never destroyed anyway.
local built = setmetatable({}, { __mode = "k" })

local function get(frame, group, suffix)
    local key = group.key .. suffix
    if not ns.Settings.Get(key) then return FIXED[suffix] end
    return Config.Get(frame.key, key)
end

-- Whether the frame shows the dispels group: its own switch, on the frames
-- it applies to (not the party's pets and targets, which derive from it).
function Auras.DispelsShown(frame)
    return ns.Settings.AppliesTo(ns.Settings.Get("dispelsEnabled"), frame.key)
        and Config.Get(frame.key, "dispelsEnabled") == true
end

-- Each group holds a second block, group.free: yours placed freely (with
-- "mine first", place Free), a holder of its own with icons at the own
-- size, laid out like a group without own icons (Layout.AuraPlace).
local function block(frame, key)
    return { key = key, frame = frame, isDebuff = GROUPS[key].isDebuff, holder = CreateFrame("Frame", nil, frame),
        buttons = {}, count = 0, own = 0 }
end

function Auras.Build(frame)
    frame.auras = {}
    for _, key in ipairs(ORDER) do
        frame.auras[key] = block(frame, key)
        frame.auras[key].free = block(frame, key)
    end
    built[frame] = true
end

-- The region a group hangs from. live: the frame's aura containers
-- (Elements/AuraContainers.lua) rather than its holders hang from each
-- other.
function Auras.AnchorRegion(frame, key, live)
    local scope, to = frame.key, Config.Get(frame.key, key .. "Anchor")
    -- The frame means the unit's block: a docked castbar included.
    local unit = frame.unitBox or frame
    if to == "HEALTH" then return frame.health end
    if to == "POWER" then
        if frame.power and frame.power:IsShown() then return frame.power end
        return frame.health
    end
    if to == "CASTBAR" then
        -- The castbar's whole rectangle, icon included.
        if frame.castbar and Config.Get(scope, "castbarEnabled") then return frame.castbar.box end
        return unit
    end
    if to == "OTHER" then
        -- Two groups hanging from each other: the debuffs take the frame.
        if key == "debuffs" and Config.Get(scope, "buffsAnchor") == "OTHER" then return unit end
        local other = GROUPS[key].other
        if live then return frame.auraContainers[other].container end
        return frame.auras[other].holder
    end
    return unit
end

-- Horizontal and vertical side of each anchor point.
local SIDES = {
    TOPLEFT = { -1, 1 }, TOP = { 0, 1 }, TOPRIGHT = { 1, 1 },
    LEFT = { -1, 0 }, CENTER = { 0, 0 }, RIGHT = { 1, 0 },
    BOTTOMLEFT = { -1, -1 }, BOTTOM = { 0, -1 }, BOTTOMRIGHT = { 1, -1 },
}

-- The vertical side (1 top, -1 bottom) where region touches the frame and
-- carries no ring: a docked castbar's side towards the frame. 0: none.
local function seamSide(frame, region)
    if not frame.castbar or region ~= frame.castbar.box then return 0 end
    local placement = ns.Castbar.Placement(frame.key)
    if placement == "BELOW" then return 1 end
    if placement == "ABOVE" then return -1 end
    return 0
end

-- A group's offset from its anchor region, on the pixel grid. Offsets
-- count from the outer border: a group that sits outside the unit box or
-- a castbar box, across an edge its frame point names that carries the
-- ring, is pushed out by the border's extent on that axis. part "Own":
-- the place of yours placed freely (OwnX, OwnFramePoint, ...).
function Auras.AnchorOffset(frame, key, region, part)
    local scope, prefix = frame.key, key .. (part or "")
    local x, y = Pixel.Snap(Config.Get(scope, prefix .. "X")), Pixel.Snap(Config.Get(scope, prefix .. "Y"))
    local ringed = region == frame.unitBox or (frame.castbar ~= nil and region == frame.castbar.box)
    if not ringed then return x, y end
    local extent = ns.Border.Extent(scope)
    local at, own = SIDES[Config.Get(scope, prefix .. "FramePoint")], SIDES[Config.Get(scope, prefix .. "Point")]
    if at[1] ~= 0 and own[1] == -at[1] then x = x + at[1] * extent end
    if at[2] ~= 0 and own[2] == -at[2] and at[2] ~= seamSide(frame, region) then y = y + at[2] * extent end
    return x, y
end

-- Where icon i goes depends on how many of the shown icons are yours
-- (group.own): those come first, at their own size. An icon is styled
-- again only when its size changes.
local function place(group, i)
    local button = group.buttons[i]
    local x, y, size = Layout.AuraPlace(group, i, group.own)
    if button.styledSize ~= size then
        AuraButton.Style(button, group.frame.key, size, group.showTime)
        button.styledSize = size
    end
    button:ClearAllPoints()
    button:SetPoint(group.corner, group.holder, group.corner, x, y)
end

-- A different number of own icons moves every icon after them.
local function arrange(group, own)
    if own == group.own then return end
    group.own = own
    for i = 1, #group.buttons do place(group, i) end
end

-- The pool grows up to the group's maximum and never shrinks.
local function acquire(frame, group, i)
    local button = group.buttons[i]
    if not button then
        button = AuraButton.Create(group.holder, group.isDebuff)
        group.buttons[i] = button
        place(group, i)
    end
    return button
end

-- As big as the shown icons; one pixel when there are none.
local function fit(group)
    local w, h = Layout.AuraBlock(group, group.own, group.count)
    local one = Pixel.One()
    group.holder:SetSize(math.max(w, one), math.max(h, one))
end

-- Shows the first `count` icons of the group, hides the rest; the first
-- `own` of them are yours.
local function settle(group, count, own)
    arrange(group, own or 0)
    group.count = count
    if count == 0 then group.hasUnknownIDs = false end
    for i = count + 1, #group.buttons do AuraButton.Clear(group.buttons[i]) end
    fit(group)
end

-- No icons in the group, nor in its block for yours placed freely.
local function empty(group)
    settle(group, 0, 0)
    if group.free.count > 0 then settle(group.free, 0, 0) end
end

-- Growing sideways, rows wrap at the frame's width; growing up or down, at
-- its height (a party button's own size).
local function frameLength(frame, primary)
    local side = (primary == "UP" or primary == "DOWN") and "height" or "width"
    return Pixel.Snap(Config.Get(frame.key, side))
end

-- Yours placed freely: group.ownFree, and the block's shape (group.free)
-- at the own size, its own growth and icons per row. Otherwise the block
-- stays empty.
local function readFree(frame, group)
    group.ownFree = group.highlightOwn and get(frame, group, "OwnPlacement") == "FREE" or false
    local free = group.free
    free.filter, free.max, free.showTime, free.spacing = group.filter, group.max, group.showTime, group.spacing
    free.size, free.ownSize, free.ownSameRow = group.ownSize, group.ownSize, false
    if not group.ownFree then return end
    free.primary = get(frame, group, "OwnGrowth")
    free.row = Layout.AuraRowDirection(free.primary, get(frame, group, "OwnRowGrowth"))
    free.corner = Layout.AuraCorner(free.primary, free.row)
    local perRow, length = get(frame, group, "OwnPerRow"), frameLength(frame, free.primary)
    free.perRowSetting, free.length = perRow, length
    free.perRow = Layout.AuraPerRow(perRow, length, free.size, free.spacing)
    free.ownPerRow = free.perRow
end

local function readSettings(frame, group)
    local filter = GROUPS[group.key].filter
    local onlyMine = get(frame, group, "OnlyMine")
    if onlyMine then filter = filter .. "|PLAYER" end
    local dispellableOnly = group.isDebuff and get(frame, group, "Dispellable")
    if dispellableOnly then filter = filter .. "|RAID" end
    -- The dispellable ones have their own group: the debuffs leave them out.
    local moved = group.key == "debuffs" and Auras.DispelsShown(frame)
    if moved and not dispellableOnly then filter = filter .. "|!RAID" end
    group.filter = filter
    -- Yours first: the client tells them apart ("PLAYER": cast by you,
    -- your pet or vehicle; "!PLAYER": everything else), so no aura field
    -- is ever compared here.
    group.highlightOwn = get(frame, group, "HighlightOwn")
    -- Yours first in the same rows as the rest instead of rows of their own.
    group.ownSameRow = group.highlightOwn and get(frame, group, "OwnSameRow") == true
    -- Borders by caster (buffs): yours and the rest must be told apart
    -- too, in the same rows and at the same size unless "mine first".
    group.casterBorder = not group.isDebuff and get(frame, group, "CasterBorder") or false
    group.split = group.highlightOwn or group.casterBorder
    if group.casterBorder then
        group.ownBorder = get(frame, group, "OwnBorderColor")
        group.otherBorder = get(frame, group, "OtherBorderColor")
    else
        group.ownBorder, group.otherBorder = nil, nil
    end
    group.ownFilter = onlyMine and filter or filter .. "|PLAYER"
    group.otherFilter = not onlyMine and filter .. "|!PLAYER" or nil
    group.hidePermanent = get(frame, group, "HidePermanent")
    -- Seconds; nil when off (debuffs have no such setting).
    local longer = not group.isDebuff and get(frame, group, "HideLonger") or 0
    group.hideLonger = longer > 0 and longer * 60 or nil
    group.hideTracking = not group.isDebuff and get(frame, group, "HideTracking") or false
    -- Hidden auras: the account's list and the frame's (Core/AuraBlocklist.lua).
    group.blockSet = ns.AuraBlocklist.ForFrame(frame.key)
    group.enabled = get(frame, group, "Enabled")
    -- Only dispellable debuffs, and those moved out: nothing is left.
    if moved and dispellableOnly then group.enabled = false end
    if group.key == "dispels" then group.enabled = Auras.DispelsShown(frame) end
    group.max = get(frame, group, "Max")
    group.size = Pixel.Snap(get(frame, group, "Size"), nil, 1)
    local ownSize = group.highlightOwn and get(frame, group, "OwnSize") or get(frame, group, "Size")
    group.ownSize = Pixel.Snap(ownSize, nil, 1)
    group.spacing = Pixel.Snap(get(frame, group, "Spacing"))
    group.primary = get(frame, group, "Growth")
    group.row = Layout.AuraRowDirection(group.primary, get(frame, group, "RowGrowth"))
    group.corner = Layout.AuraCorner(group.primary, group.row)
    local perRow, length = get(frame, group, "PerRow"), frameLength(frame, group.primary)
    group.perRowSetting, group.length = perRow, length
    group.perRow = Layout.AuraPerRow(perRow, length, group.size, group.spacing)
    group.ownPerRow = Layout.AuraPerRow(perRow, length, group.ownSize, group.spacing)
    group.showTime = get(frame, group, "ShowTime")
    readFree(frame, group)
end

-- The block for yours placed freely: its icons restyled and placed, or
-- emptied while yours are with the rest.
local function styleFree(frame, group)
    local free = group.free
    free.holder:SetFrameLevel(frame:GetFrameLevel() + Auras.LEVELS)
    if not (group.ownFree and group.enabled) then
        if free.count > 0 then settle(free, 0, 0) end
        return
    end
    for i, button in ipairs(free.buttons) do
        button.styledSize = nil
        place(free, i)
    end
    settle(free, math.min(free.count, group.max), 0)
end

function Auras.Style(frame)
    for _, key in ipairs(ORDER) do
        local group = frame.auras[key]
        readSettings(frame, group)
        group.holder:SetFrameLevel(frame:GetFrameLevel() + Auras.LEVELS)
        for i, button in ipairs(group.buttons) do
            button.styledSize = nil
            place(group, i)
        end
        local count = group.enabled and math.min(group.count, group.max) or 0
        settle(group, count, group.highlightOwn and not group.ownFree and math.min(group.own, count) or 0)
        styleFree(frame, group)
    end
    -- Anchors last: a group may hang from the other one.
    for _, key in ipairs(ORDER) do
        local group = frame.auras[key]
        group.holder:ClearAllPoints()
        local region = Auras.AnchorRegion(frame, key)
        group.holder:SetPoint(get(frame, group, "Point"), region, get(frame, group, "FramePoint"),
            Auras.AnchorOffset(frame, key, region))
        group.free.holder:ClearAllPoints()
        if group.ownFree then
            local unit = frame.unitBox or frame
            group.free.holder:SetPoint(get(frame, group, "OwnPoint"), unit, get(frame, group, "OwnFramePoint"),
                Auras.AnchorOffset(frame, key, unit, "Own"))
        end
    end
    AuraContainers.Style(frame)
end

local function showSamples(frame)
    sampleStart = sampleStart or GetTime()
    for _, key in ipairs(ORDER) do
        local group, samples = frame.auras[key], Auras.SAMPLES[key]
        local count = group.enabled and group.max or 0
        -- The first samples pass for yours, so "mine first" and borders by
        -- caster can be seen.
        local mine = group.split and math.min(Auras.OWN_SAMPLES, count) or 0
        -- Placed freely: yours in their block, the rest from the first row.
        local free = group.ownFree and group.free
        local skip = free and mine or 0
        local own = group.highlightOwn and not free and mine or 0
        arrange(group, own)
        for i = 1, count do
            local sample = samples[(i - 1) % #samples + 1]
            local button = i <= skip and acquire(frame, free, i) or acquire(frame, group, i - skip)
            AuraButton.ShowSample(button, sample, sampleStart)
            AuraButton.SetCasterBorder(button, AuraContainers.CasterBorder(group, i <= mine))
        end
        settle(group, count - skip, own)
        if free then
            settle(free, skip, 0)
        elseif group.free.count > 0 then
            settle(group.free, 0, 0)
        end
    end
    frame.auraSamples = true
end

local function clear(frame)
    for _, key in ipairs(ORDER) do empty(frame.auras[key]) end
    frame.auraSamples = nil
end

local function testing()
    return ns.TestMode ~= nil and ns.TestMode.IsOn()
end

-- One list from the client; nil when it refused.
Auras.IS_TRACKING = {}
for _, id in ipairs(ns.Settings.TRACKING_SPELLS) do Auras.IS_TRACKING[id] = true end

local function query(frame, filter, max)
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, frame.unit, filter, max, SORT_RULE)
    if ok and type(list) == "table" then return list end
end

-- Shows the auras of a list from icon count + 1 on, up to the maximum.
-- Returns the new count.
-- Whether a listed spell is left out on this frame's unit: only where the
-- client's containers would leave it out too (Core/AuraBlocklist.lua,
-- Applies), so the query path and the containers show the same auras.
-- The row's part is asked once per fill.
local function blocked(group, aura, rowApplies)
    if not (group.blockSet and not Secrets.IsSecret(aura) and type(aura) == "table") then return false end
    local id = Secrets.Number(aura.spellId)
    if not (id and group.blockSet[id]) then return false end
    return rowApplies or ns.AuraBlocklist.NeverSecret(id)
end

-- into: the icons' block (default the group; group.free for yours placed
-- freely), max: how many it may show (default the group's maximum).
local function fill(frame, group, list, count, mine, into, max)
    into, max = into or group, max or group.max
    local rowApplies = group.blockSet ~= nil and next(group.blockSet) ~= nil
        and ns.AuraBlocklist.RowApplies(frame.unit, not group.isDebuff)
    for i = 1, #list do
        if count >= max then break end
        local aura = list[i]
        -- Hide permanent: a readable duration of 0 is skipped (a secret one
        -- cannot be told apart and stays).
        if group.hidePermanent and not Secrets.IsSecret(aura) and type(aura) == "table"
            and Secrets.Number(aura.duration) == 0 then
            aura = nil
        end
        -- Hide longer: a readable full duration past the limit is skipped,
        -- and one of 0 too (the container's maxDuration does the same).
        if aura and group.hideLonger and not Secrets.IsSecret(aura) and type(aura) == "table" then
            local duration = Secrets.Number(aura.duration)
            if duration and (duration == 0 or duration > group.hideLonger) then aura = nil end
        end
        if aura and group.hideTracking and not Secrets.IsSecret(aura) and type(aura) == "table"
            and Auras.IS_TRACKING[Secrets.Number(aura.spellId) or false] then
            aura = nil
        end
        -- Hidden auras: a readable spell ID on the lists is skipped where
        -- the client's containers skip it too; a secret one cannot be
        -- looked up and stays.
        if aura and blocked(group, aura, rowApplies) then aura = nil end
        local button = aura ~= nil and not Secrets.IsSecret(aura) and type(aura) == "table"
            and acquire(frame, into, count + 1)
        if button and AuraButton.Show(button, frame.unit, aura, group.filter) then
            AuraButton.SetCasterBorder(button, AuraContainers.CasterBorder(group, mine))
            count = count + 1
            -- Shown from a secret instance ID: later events cannot name it.
            if not button.auraID then into.hasUnknownIDs = true end
        end
    end
    return count
end

-- Reads one group in full. Returns false when the client refused; the
-- group is then left as it was. With yours first that takes two lists,
-- and both are asked for before anything is shown.
local function readGroup(frame, group)
    local own, other
    if group.split then
        own = query(frame, group.ownFilter, group.max)
        if not own then return false end
        if group.otherFilter and #own < group.max then
            other = query(frame, group.otherFilter, group.max)
            if not other then return false end
        end
    else
        other = query(frame, group.filter, group.max)
        if not other then return false end
    end
    group.hasUnknownIDs, group.free.hasUnknownIDs = false, false
    if group.ownFree then
        -- Yours in their own block; the maximum counts both.
        local mine = own and fill(frame, group, own, 0, true, group.free) or 0
        local count = other and fill(frame, group, other, 0, false, group, group.max - mine) or 0
        settle(group.free, mine, 0)
        settle(group, count, 0)
        return true
    end
    local mine = own and fill(frame, group, own, 0, true) or 0
    local count = other and fill(frame, group, other, mine, false) or mine
    -- Only "mine first" lays yours out apart (own size, own rows).
    settle(group, count, group.highlightOwn and mine or 0)
    if group.free.count > 0 then settle(group.free, 0, 0) end
    return true
end

-- keep: the unit is the same as before (an aura event), so a refused
-- read may leave the last known icons up; otherwise they belong to
-- another unit and go.
local function readAll(frame, keep)
    frame.auraSamples = nil
    for _, key in ipairs(ORDER) do
        local group = frame.auras[key]
        if not group.enabled or (not readGroup(frame, group) and not keep) then
            empty(group)
        end
    end
end

-- Incremental aura events -------------------------------------------------------
-- UNIT_AURA says what changed. A changed aura that is shown is asked for
-- again on its own; an added or removed one that concerns a group makes
-- that group read again; everything else is ignored. Anything unreadable
-- (a secret ID or flag, a refused call) falls back to a full read. A group
-- showing icons whose IDs were secret when read (hasUnknownIDs) cannot tell
-- whether a removed or changed ID is one of them, so any such ID it does
-- not know makes it read again.

local function shownIn(block, id)
    for i = 1, block.count do
        local button = block.buttons[i]
        if button.auraID == id then return button end
    end
end

-- In the group or its block for yours placed freely.
local function shownButton(group, id)
    return shownIn(group, id) or shownIn(group.free, id)
end

local function unknownIDs(group)
    return group.hasUnknownIDs or group.free.hasUnknownIDs
end

local function readableID(id)
    if Secrets.IsSecret(id) or type(id) ~= "number" then error("unreadable aura instance ID") end
    return id
end

local function markAdded(frame, aura)
    local id = readableID(aura.auraInstanceID)
    for _, key in ipairs(ORDER) do
        local group = frame.auras[key]
        if group.enabled then
            local out = C_UnitAuras.IsAuraFilteredOutByInstanceID(frame.unit, id, group.filter)
            if Secrets.IsSecret(out) then error("unreadable filter answer") end
            if out == false then group.dirty = true end
        end
    end
end

local function markRemoved(frame, id)
    id = readableID(id)
    for _, key in ipairs(ORDER) do
        local group = frame.auras[key]
        if unknownIDs(group) or shownButton(group, id) then group.dirty = true end
    end
end

local function refreshShown(frame, id)
    id = readableID(id)
    for _, key in ipairs(ORDER) do
        local group = frame.auras[key]
        local button = not group.dirty and shownButton(group, id)
        if not button and unknownIDs(group) then group.dirty = true end
        if button then
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(frame.unit, id)
            if Secrets.IsSecret(aura) or type(aura) ~= "table"
                or not AuraButton.Show(button, frame.unit, aura, group.filter) then
                group.dirty = true
            end
        end
    end
end

-- Shared, never written: no table is made per event.
local NONE = {}

local function applyChanges(frame, info)
    for _, aura in ipairs(info.addedAuras or NONE) do markAdded(frame, aura) end
    for _, id in ipairs(info.removedAuraInstanceIDs or NONE) do markRemoved(frame, id) end
    for _, id in ipairs(info.updatedAuraInstanceIDs or NONE) do refreshShown(frame, id) end
end

local function fullFlag(info) return info.isFullUpdate end

local function clearDirty(frame)
    for _, key in ipairs(ORDER) do frame.auras[key].dirty = false end
end

-- Returns false when a full read is needed instead.
local function applyEvent(frame, info)
    if type(info) ~= "table" or Secrets.IsSecret(info) then return false end
    if Secrets.Bool(fullFlag, info) ~= false then return false end
    clearDirty(frame)
    if not pcall(applyChanges, frame, info) then
        clearDirty(frame)
        return false
    end
    for _, key in ipairs(ORDER) do
        local group = frame.auras[key]
        if group.dirty then
            group.dirty = false
            -- Refused: the group keeps its icons, as a full read would.
            readGroup(frame, group)
        end
    end
    return true
end

-- A timer refresh (target of target) runs at most every POLL_SECONDS.
local function tooSoon(frame, event)
    local now = GetTime()
    if event == ns.Single.POLL and frame.auraPolled and now - frame.auraPolled < Auras.POLL_SECONDS then
        return true
    end
    frame.auraPolled = now
    return false
end

-- Live auras come from the frame's containers where the client makes
-- them (Elements/AuraContainers.lua); the reads below are the fallback.
function Auras.Update(frame, event, _, info)
    if testing() then
        AuraContainers.Hide(frame)
        showSamples(frame)
        return
    end
    if AuraContainers.Ensure(frame) then
        if frame.auraSamples then clear(frame) end
        if not tooSoon(frame, event) then AuraContainers.Refresh(frame, event) end
        return
    end
    if event == "UNIT_AURA" and not frame.auraSamples and applyEvent(frame, info) then return end
    if tooSoon(frame, event) then return end
    readAll(frame, event == "UNIT_AURA")
end

-- After combat every shown frame that reads its auras itself reads again:
-- reads refused in combat left icons out of date.
ns.On("PLAYER_REGEN_ENABLED", function()
    for frame in pairs(built) do
        if not frame.auraContainers and frame.unit and frame:IsShown() and UnitExists(frame.unit) then
            Auras.Update(frame)
        end
    end
end)

-- Test mode off: samples go everywhere, also on frames that are hidden or
-- have no unit now (the pretend party).
ns.Listen("TEST_MODE", function(on)
    if on then return end
    sampleStart = nil
    for frame in pairs(built) do
        if frame.auraSamples then clear(frame) end
    end
end)

ns.RegisterElement(Auras)
