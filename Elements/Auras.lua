local _, ns = ...

-- Buffs and debuffs of a unit frame: two groups, each a plain holder frame
-- with a pool of icons (Elements/AuraButton.lua). The holder hangs from a
-- region of the frame (or from the other group) and is as big as the
-- icons it shows, so a group hanging from it follows as it grows.
-- Nothing here is secure: holders and icons may change in combat.
local Auras = { name = "Auras", unitEvents = { "UNIT_AURA" } }
ns.Auras = Auras

local Config, Layout, Pixel, AuraButton = ns.Config, ns.Layout, ns.Pixel, ns.AuraButton

-- Holders sit this many levels above the unit frame: over its bars.
Auras.LEVELS = 5

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
        frame.auras[key] = { key = key, isDebuff = GROUPS[key].isDebuff, holder = CreateFrame("Frame", nil, frame),
            buttons = {}, count = 0 }
    end
    built[frame] = true
end

-- The region a group hangs from.
function Auras.AnchorRegion(frame, key)
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
        return frame.auras[GROUPS[key].other].holder
    end
    return frame
end

local function place(group, i)
    local button = group.buttons[i]
    button:ClearAllPoints()
    button:SetPoint(group.corner, group.holder, group.corner,
        Layout.AuraOffset(i, group.perRow, group.size + group.spacing, group.primary, group.row))
end

-- The pool grows up to the group's maximum and never shrinks.
local function acquire(frame, group, i)
    local button = group.buttons[i]
    if not button then
        button = AuraButton.Create(group.holder, group.isDebuff)
        group.buttons[i] = button
        AuraButton.Style(button, frame.key, group.size, group.showTime)
        place(group, i)
    end
    return button
end

-- As big as the shown icons; one pixel when there are none.
local function fit(group)
    local w, h = Layout.AuraExtent(group.count, group.perRow, group.size, group.spacing, group.primary)
    local one = Pixel.One()
    group.holder:SetSize(math.max(w, one), math.max(h, one))
end

-- Shows the first `count` icons of the group, hides the rest.
local function settle(group, count)
    group.count = count
    for i = count + 1, #group.buttons do AuraButton.Clear(group.buttons[i]) end
    fit(group)
end

local function readSettings(frame, group)
    local filter = GROUPS[group.key].filter
    if get(frame, group, "OnlyMine") then filter = filter .. "|PLAYER" end
    if group.isDebuff and get(frame, group, "Dispellable") then filter = filter .. "|RAID" end
    group.filter = filter
    group.enabled = get(frame, group, "Enabled")
    group.max = get(frame, group, "Max")
    group.perRow = get(frame, group, "PerRow")
    group.size = Pixel.Snap(get(frame, group, "Size"), nil, 1)
    group.spacing = Pixel.Snap(get(frame, group, "Spacing"))
    group.primary = get(frame, group, "Growth")
    group.row = Layout.AuraRowDirection(group.primary, get(frame, group, "RowGrowth"))
    group.corner = Layout.AuraCorner(group.primary, group.row)
    group.showTime = get(frame, group, "ShowTime")
end

function Auras.Style(frame)
    for _, key in ipairs(ORDER) do
        local group = frame.auras[key]
        readSettings(frame, group)
        group.holder:SetFrameLevel(frame:GetFrameLevel() + Auras.LEVELS)
        for i, button in ipairs(group.buttons) do
            AuraButton.Style(button, frame.key, group.size, group.showTime)
            place(group, i)
        end
        settle(group, group.enabled and math.min(group.count, group.max) or 0)
    end
    -- Anchors last: a group may hang from the other one.
    for _, key in ipairs(ORDER) do
        local group = frame.auras[key]
        group.holder:ClearAllPoints()
        group.holder:SetPoint(get(frame, group, "Point"), Auras.AnchorRegion(frame, key), get(frame, group, "FramePoint"),
            Pixel.Snap(get(frame, group, "X")), Pixel.Snap(get(frame, group, "Y")))
    end
end

local function showSamples(frame)
    sampleStart = sampleStart or GetTime()
    for _, key in ipairs(ORDER) do
        local group, samples = frame.auras[key], Auras.SAMPLES[key]
        local count = group.enabled and group.max or 0
        for i = 1, count do
            AuraButton.ShowSample(acquire(frame, group, i), samples[(i - 1) % #samples + 1], sampleStart)
        end
        settle(group, count)
    end
    frame.auraSamples = true
end

local function clear(frame)
    for _, key in ipairs(ORDER) do settle(frame.auras[key], 0) end
    frame.auraSamples = nil
end

local function testing()
    return ns.TestMode ~= nil and ns.TestMode.IsOn()
end

function Auras.Update(frame)
    if testing() then
        showSamples(frame)
        return
    end
    clear(frame)
end

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
