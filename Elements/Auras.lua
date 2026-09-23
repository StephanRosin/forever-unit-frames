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

-- Holders sit this many levels above the unit frame: over its bars.
Auras.LEVELS = 5
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
}
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
}
-- When the samples of this test mode session started (their swipes run
-- from there).
local sampleStart

-- Every frame with aura groups; weak, frames are never destroyed anyway.
local built = setmetatable({}, { __mode = "k" })

local function get(frame, group, suffix)
    return Config.Get(frame.key, group.key .. suffix)
end

function Auras.Build(frame)
    frame.auras = {}
    for _, key in ipairs(ORDER) do
        frame.auras[key] = { key = key, frame = frame, isDebuff = GROUPS[key].isDebuff,
            holder = CreateFrame("Frame", nil, frame), buttons = {}, count = 0, own = 0 }
    end
    built[frame] = true
end

-- The region a group hangs from. live: the frame's aura containers
-- (Elements/AuraContainers.lua) rather than its holders hang from each
-- other.
function Auras.AnchorRegion(frame, key, live)
    local scope, to = frame.key, Config.Get(frame.key, key .. "Anchor")
    if to == "HEALTH" then return frame.health end
    if to == "POWER" then
        if frame.power and frame.power:IsShown() then return frame.power end
        return frame.health
    end
    if to == "CASTBAR" then
        if frame.castbar and Config.Get(scope, "castbarEnabled") then return frame.castbar end
        return frame
    end
    if to == "OTHER" then
        -- Two groups hanging from each other: the debuffs take the frame.
        if key == "debuffs" and Config.Get(scope, "buffsAnchor") == "OTHER" then return frame end
        local other = GROUPS[key].other
        if live then return frame.auraContainers[other].container end
        return frame.auras[other].holder
    end
    return frame
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

-- Growing sideways, rows wrap at the frame's width; growing up or down, at
-- its height (a party button's own size).
local function frameLength(frame, primary)
    local side = (primary == "UP" or primary == "DOWN") and "height" or "width"
    return Pixel.Snap(Config.Get(frame.key, side))
end

local function readSettings(frame, group)
    local filter = GROUPS[group.key].filter
    local onlyMine = get(frame, group, "OnlyMine")
    if onlyMine then filter = filter .. "|PLAYER" end
    if group.isDebuff and get(frame, group, "Dispellable") then filter = filter .. "|RAID" end
    group.filter = filter
    -- Yours first: the client tells them apart ("PLAYER": cast by you,
    -- your pet or vehicle; "!PLAYER": everything else), so no aura field
    -- is ever compared here.
    group.highlightOwn = get(frame, group, "HighlightOwn")
    group.ownFilter = onlyMine and filter or filter .. "|PLAYER"
    group.otherFilter = not onlyMine and filter .. "|!PLAYER" or nil
    group.enabled = get(frame, group, "Enabled")
    group.max = get(frame, group, "Max")
    group.size = Pixel.Snap(get(frame, group, "Size"), nil, 1)
    group.ownSize = Pixel.Snap(get(frame, group, "OwnSize"), nil, 1)
    group.spacing = Pixel.Snap(get(frame, group, "Spacing"))
    group.primary = get(frame, group, "Growth")
    group.row = Layout.AuraRowDirection(group.primary, get(frame, group, "RowGrowth"))
    group.corner = Layout.AuraCorner(group.primary, group.row)
    local perRow, length = get(frame, group, "PerRow"), frameLength(frame, group.primary)
    group.perRowSetting, group.length = perRow, length
    group.perRow = Layout.AuraPerRow(perRow, length, group.size, group.spacing)
    group.ownPerRow = Layout.AuraPerRow(perRow, length, group.ownSize, group.spacing)
    group.showTime = get(frame, group, "ShowTime")
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
        settle(group, count, group.highlightOwn and math.min(group.own, count) or 0)
    end
    -- Anchors last: a group may hang from the other one.
    for _, key in ipairs(ORDER) do
        local group = frame.auras[key]
        group.holder:ClearAllPoints()
        group.holder:SetPoint(get(frame, group, "Point"), Auras.AnchorRegion(frame, key), get(frame, group, "FramePoint"),
            Pixel.Snap(get(frame, group, "X")), Pixel.Snap(get(frame, group, "Y")))
    end
    AuraContainers.Style(frame)
end

local function showSamples(frame)
    sampleStart = sampleStart or GetTime()
    for _, key in ipairs(ORDER) do
        local group, samples = frame.auras[key], Auras.SAMPLES[key]
        local count = group.enabled and group.max or 0
        -- The first samples pass for yours, so "mine first" can be seen.
        local own = group.highlightOwn and math.min(Auras.OWN_SAMPLES, count) or 0
        arrange(group, own)
        for i = 1, count do
            AuraButton.ShowSample(acquire(frame, group, i), samples[(i - 1) % #samples + 1], sampleStart)
        end
        settle(group, count, own)
    end
    frame.auraSamples = true
end

local function clear(frame)
    for _, key in ipairs(ORDER) do settle(frame.auras[key], 0, 0) end
    frame.auraSamples = nil
end

local function testing()
    return ns.TestMode ~= nil and ns.TestMode.IsOn()
end

-- One list from the client; nil when it refused.
local function query(frame, filter, max)
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, frame.unit, filter, max, SORT_RULE)
    if ok and type(list) == "table" then return list end
end

-- Shows the auras of a list from icon count + 1 on, up to the maximum.
-- Returns the new count.
local function fill(frame, group, list, count)
    for i = 1, #list do
        if count >= group.max then break end
        local aura = list[i]
        local button = not Secrets.IsSecret(aura) and type(aura) == "table" and acquire(frame, group, count + 1)
        if button and AuraButton.Show(button, frame.unit, aura, group.filter) then
            count = count + 1
            -- Shown from a secret instance ID: later events cannot name it.
            if not button.auraID then group.hasUnknownIDs = true end
        end
    end
    return count
end

-- Reads one group in full. Returns false when the client refused; the
-- group is then left as it was. With yours first that takes two lists,
-- and both are asked for before anything is shown.
local function readGroup(frame, group)
    local own, other
    if group.highlightOwn then
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
    group.hasUnknownIDs = false
    local mine = own and fill(frame, group, own, 0) or 0
    local count = other and fill(frame, group, other, mine) or mine
    settle(group, count, mine)
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
            settle(group, 0, 0)
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

local function shownButton(group, id)
    for i = 1, group.count do
        local button = group.buttons[i]
        if button.auraID == id then return button end
    end
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
        if group.hasUnknownIDs or shownButton(group, id) then group.dirty = true end
    end
end

local function refreshShown(frame, id)
    id = readableID(id)
    for _, key in ipairs(ORDER) do
        local group = frame.auras[key]
        local button = not group.dirty and shownButton(group, id)
        if not button and group.hasUnknownIDs then group.dirty = true end
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

function Auras.Update(frame, event, _, info)
    if testing() then
        showSamples(frame)
        return
    end
    if event == "UNIT_AURA" and not frame.auraSamples and applyEvent(frame, info) then return end
    local now = GetTime()
    if event == ns.Single.POLL then
        if frame.auraPolled and now - frame.auraPolled < Auras.POLL_SECONDS then return end
    end
    frame.auraPolled = now
    readAll(frame, event == "UNIT_AURA")
end

-- After combat every shown frame reads again: reads refused in combat left
-- icons out of date.
ns.On("PLAYER_REGEN_ENABLED", function()
    for frame in pairs(built) do
        if frame.unit and frame:IsShown() and UnitExists(frame.unit) then Auras.Update(frame) end
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
