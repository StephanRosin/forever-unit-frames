local _, ns = ...

-- Drag handles. Secure frames are anchored to their mover and never moved
-- themselves; moving happens only out of combat.
--
-- Anything can have a mover: a unit frame, the party block, a detached
-- castbar. A spec says which settings hold the position and how big the
-- handle is:
--   scope          settings scope ("player", "party", ...)
--   xKey, yKey     position settings, offsets of the handle's centre from
--                  the screen centre (default "x" / "y")
--   size()         -> width, height of the handle
--   point          anchor point shared by target and handle (default
--                  "CENTER"); the party block hangs from "TOPLEFT"
--   anchor         false: Attach does not anchor the target (its own
--                  Style decides, e.g. a castbar that may also be docked)
--   active()       optional: false keeps the handle hidden when unlocked
--   label          text on the handle
--   id             combat-queue key suffix (default scope)
local Movers = {}
ns.Movers = Movers

local GRID = 8
local unlocked = false
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
        scope = key, label = L["FRAME_" .. key],
        size = function() return ns.Config.Get(key, "width"), ns.Config.Get(key, "height") end,
    }
end

local function complete(spec)
    spec.xKey = spec.xKey or "x"
    spec.yKey = spec.yKey or "y"
    spec.point = spec.point or "CENTER"
    spec.id = spec.id or spec.scope
    return spec
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
    mover:SetPoint("CENTER", UIParent, "CENTER",
        Pixel.Centre(ns.Config.Get(spec.scope, spec.xKey), w), Pixel.Centre(ns.Config.Get(spec.scope, spec.yKey), h))
end

function Movers.OnDragStop(mover)
    mover.dragging = false
    mover:StopMovingOrSizing()
    local mx, my = mover:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local spec = mover.spec
    ns.Config.Set(spec.scope, spec.xKey, Movers.Snap(mx - ux))
    ns.Config.Set(spec.scope, spec.yKey, Movers.Snap(my - uy))
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
    mover.label:SetText(spec.label)
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

function Movers.IsUnlocked() return unlocked end

-- Shows the handles that are active right now (a castbar's only while it
-- is detached). Also run when settings change while unlocked.
local function showActive()
    for _, target in ipairs(targets) do
        local mover = target.mover
        local on = isActive(mover)
        mover:EnableMouse(on)
        mover:SetShown(on)
    end
end

function Movers.Unlock()
    if InCombatLockdown() then
        ns.Print(L.LOCKED_IN_COMBAT)
        return false
    end
    unlocked = true
    showActive()
    ns.Print(L.UNLOCKED)
    return true
end

-- A drag in progress is stopped at once. In combat only the flag is
-- cleared; hiding and disabling the movers waits until combat ends.
function Movers.Lock()
    unlocked = false
    for _, target in ipairs(targets) do
        local mover = target.mover
        if mover.dragging then
            Movers.OnDragStop(mover)
        else
            mover:StopMovingOrSizing()
        end
    end
    ns.AfterCombat("lockMovers", function()
        if unlocked then return end
        for _, target in ipairs(targets) do
            target.mover:EnableMouse(false)
            target.mover:Hide()
        end
    end)
    ns.Print(L.LOCKED)
end

-- Combat is about to start: lock down before secure lockdown begins.
-- PLAYER_REGEN_DISABLED fires just before lockdown takes effect, so hiding
-- and disabling the (unprotected) movers here is still allowed.
ns.On("PLAYER_REGEN_DISABLED", function()
    if unlocked then Movers.Lock() end
end)

-- A castbar switched to detached (or back) while unlocked gains or loses
-- its handle at once. Unlocked implies out of combat.
ns.Listen("CONFIG_CHANGED", function()
    if unlocked then showActive() end
end)
