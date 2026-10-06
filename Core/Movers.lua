local _, ns = ...

-- Drag handles. Secure frames are anchored to their mover and never moved
-- themselves; moving happens only out of combat.
--
-- Anything can have a mover: a unit frame, the party block, a detached
-- castbar, the raid panel. A spec says which settings hold the position
-- and how big the handle is:
--   scope          settings scope ("player", "party", ...), or a function
--                  returning it (the raid panel: the active size's)
--   config         the settings it is in (default ns.Config; the raid
--                  panel: ns.RaidConfig)
--   xKey, yKey     position settings, offsets of the handle's centre from
--                  the screen centre (default "x" / "y")
--   origin         "TOPLEFT": xKey / yKey hold the handle's top-left
--                  corner instead of its centre (the raid panel, whose
--                  size changes with the group)
--   size()         -> width, height of the handle
--   point          anchor point shared by target and handle (default
--                  "CENTER"); the party block hangs from "TOPLEFT"
--   anchor         false: Attach does not anchor the target (its own
--                  Style decides, e.g. a castbar that may also be docked)
--   active()       optional: false keeps the handle hidden when unlocked
--   label          text on the handle, or a function returning it (asked
--                  again when the language changes)
--   id             combat-queue key suffix (default scope; required when
--                  scope is a function)
--   group          "units" (default) or "raid": which windows' unlock
--                  shows the handle
--   clamp(axis, v) optional: a dragged position ("x" / "y", snapped)
--                  moved to where the target can be (the raid panel:
--                  inside the screen)
--
-- Each group is unlocked on its own: the unit frames' (the unit window,
-- /fuf unlock, the minimap button) and the raid panel's (the raid
-- window). Locking all (/fuf lock, the start of combat) locks both.
local Movers = {}
ns.Movers = Movers

local GRID = 8
-- Drags snap to it; the raid window's position steps by it with Shift.
Movers.GRID = GRID
Movers.GROUPS = { "units", "raid" }
local unlocked = { units = false, raid = false }
local L = ns.L
-- Every target that has a mover, in attach order.
local targets = {}

function Movers.Snap(v)
    local sign = v < 0 and -1 or 1
    return sign * math.floor(math.abs(v) / GRID + 0.5) * GRID
end

-- The spec of an ordinary unit frame.
function Movers.FrameSpec(frame)
    local key = frame.key
    return {
        scope = key, label = function() return L["FRAME_" .. key] end,
        size = function() return ns.Config.Get(key, "width"), ns.Config.Get(key, "height") end,
    }
end

local function labelOf(spec)
    if type(spec.label) == "function" then return spec.label() end
    return spec.label
end

local function complete(spec)
    spec.config = spec.config or ns.Config
    spec.xKey = spec.xKey or "x"
    spec.yKey = spec.yKey or "y"
    spec.point = spec.point or "CENTER"
    spec.origin = spec.origin or "CENTER"
    -- The id keys the mover's queued work ("attach:" .. id); a scope that
    -- is a function cannot stand in for it.
    assert(spec.id ~= nil or type(spec.scope) ~= "function", "mover spec: a function scope needs an id")
    assert(type(spec.id) ~= "function", "mover spec: id must not be a function")
    spec.id = spec.id or spec.scope
    spec.group = spec.group or "units"
    assert(unlocked[spec.group] ~= nil, "mover spec: unknown group")
    return spec
end

local function scopeOf(spec)
    if type(spec.scope) == "function" then return spec.scope() end
    return spec.scope
end

-- Sizes and positions the mover from config alone, never from the
-- target's own current size: inside a queued combat restyle the target may
-- not have been resized yet, and a value read off it would be stale. No-op
-- if the target has no mover.
function Movers.Sync(target)
    local mover = target.mover
    if not mover then return end
    local spec = mover.spec
    local Pixel = ns.Pixel
    local w, h = spec.size()
    w, h = Pixel.Snap(w), Pixel.Snap(h)
    mover:SetSize(w, h)
    mover:ClearAllPoints()
    -- On the pixel grid: the handle's edges, and so its target's, land on
    -- whole pixels.
    local scope = scopeOf(spec)
    local x, y = spec.config.Get(scope, spec.xKey), spec.config.Get(scope, spec.yKey)
    if spec.origin == "TOPLEFT" then
        mover:SetPoint("TOPLEFT", UIParent, "CENTER", Pixel.Snap(x), Pixel.Snap(y))
    else
        mover:SetPoint("CENTER", UIParent, "CENTER", Pixel.Centre(x, w), Pixel.Centre(y, h))
    end
    mover.label:SetText(labelOf(spec))
end

function Movers.OnDragStop(mover)
    mover.dragging = false
    mover:StopMovingOrSizing()
    local mx, my = mover:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local spec = mover.spec
    local x, y = mx - ux, my - uy
    if spec.origin == "TOPLEFT" then x, y = x - mover:GetWidth() / 2, y + mover:GetHeight() / 2 end
    x, y = Movers.Snap(x), Movers.Snap(y)
    if spec.clamp then x, y = spec.clamp("x", x), spec.clamp("y", y) end
    local scope = scopeOf(spec)
    spec.config.Set(scope, spec.xKey, x)
    spec.config.Set(scope, spec.yKey, y)
end

local function isActive(mover)
    return mover.spec.active == nil or mover.spec.active()
end

function Movers.Attach(target, spec)
    if target.mover then return end
    spec = complete(spec or Movers.FrameSpec(target))
    if InCombatLockdown() then
        ns.AfterCombat("attach:" .. spec.id, function() Movers.Attach(target, spec) end)
        return
    end
    local mover = CreateFrame("Frame", nil, UIParent)
    mover.spec = spec
    mover:SetMovable(true)
    -- Unit frames sit at the default MEDIUM strata with opaque bars; without
    -- this the mover's overlay/label are hidden underneath and the secure
    -- unit button (mouse enabled) steals the drag instead of the mover.
    mover:SetFrameStrata("DIALOG")
    mover:SetClampedToScreen(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self.dragging = true
        self:StartMoving()
    end)
    mover:SetScript("OnDragStop", Movers.OnDragStop)
    mover.overlay = mover:CreateTexture(nil, "OVERLAY")
    mover.overlay:SetAllPoints(mover)
    mover.overlay:SetColorTexture(0.3, 0.76, 0.97, 0.35)
    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetFont(ns.Media.Font("Friz Quadrata"), 11, "OUTLINE")
    mover.label:SetPoint("CENTER", mover, "CENTER", 0, 0)
    mover.label:SetText(labelOf(spec))
    target.mover = mover
    targets[#targets + 1] = target
    Movers.Sync(target)
    mover:EnableMouse(false)
    mover:Hide()
    if spec.anchor ~= false then
        target:ClearAllPoints()
        target:SetPoint(spec.point, mover, spec.point, 0, 0)
    end
end

-- A group name; nil is the unit frames'.
local function groupOf(group)
    group = group or "units"
    assert(unlocked[group] ~= nil, "Movers: unknown group " .. tostring(group))
    return group
end

local function anyUnlocked()
    for _, group in ipairs(Movers.GROUPS) do
        if unlocked[group] then return true end
    end
    return false
end

function Movers.IsUnlocked(group) return unlocked[groupOf(group)] end

-- Shows the handles of the unlocked groups that are active right now (a
-- castbar's only while it is detached). Also run when settings change
-- while unlocked.
local function showActive()
    for _, target in ipairs(targets) do
        local mover = target.mover
        if unlocked[mover.spec.group] then
            local on = isActive(mover)
            mover:EnableMouse(on)
            mover:SetShown(on)
        end
    end
end

function Movers.Unlock(group)
    group = groupOf(group)
    if InCombatLockdown() then
        ns.Print(L.LOCKED_IN_COMBAT)
        return false
    end
    unlocked[group] = true
    showActive()
    ns.Print(L.UNLOCKED)
    ns.Fire("MOVERS_UNLOCKED", true, group)
    return true
end

local function lockGroup(group)
    unlocked[group] = false
    ns.Fire("MOVERS_UNLOCKED", false, group)
    for _, target in ipairs(targets) do
        local mover = target.mover
        if mover.spec.group == group then
            if mover.dragging then
                Movers.OnDragStop(mover)
            else
                mover:StopMovingOrSizing()
            end
        end
    end
    ns.AfterCombat("lockMovers:" .. group, function()
        if unlocked[group] then return end
        for _, target in ipairs(targets) do
            if target.mover.spec.group == group then
                target.mover:EnableMouse(false)
                target.mover:Hide()
            end
        end
    end)
end

-- A drag in progress is stopped at once. In combat only the flag is
-- cleared; hiding and disabling the movers waits until combat ends.
function Movers.Lock(group)
    lockGroup(groupOf(group))
    ns.Print(L.LOCKED)
end

-- Every group (/fuf lock, the start of combat), with one message.
function Movers.LockAll()
    for _, group in ipairs(Movers.GROUPS) do lockGroup(group) end
    ns.Print(L.LOCKED)
end

-- Combat is about to start: lock down before secure lockdown begins.
-- PLAYER_REGEN_DISABLED fires just before lockdown takes effect, so hiding
-- and disabling the (unprotected) movers here is still allowed.
ns.On("PLAYER_REGEN_DISABLED", function()
    if anyUnlocked() then Movers.LockAll() end
end)

-- A castbar switched to detached (or back), or the raid frames switched
-- on or off, while unlocked: the handle comes or goes at once. Unlocked
-- implies out of combat.
ns.Listen("CONFIG_CHANGED", function()
    if anyUnlocked() then showActive() end
end)
ns.Listen("RAID_CONFIG_CHANGED", function()
    if anyUnlocked() then showActive() end
end)

-- Handles only hold a plain text: set it again in the new language.
ns.Listen("LANGUAGE_CHANGED", function()
    for _, target in ipairs(targets) do
        target.mover.label:SetText(labelOf(target.mover.spec))
    end
end)
