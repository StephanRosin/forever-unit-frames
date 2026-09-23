local _, ns = ...

-- Drag handles. Secure frames are anchored to their mover and never moved
-- themselves; moving happens only out of combat.
local Movers = {}
ns.Movers = Movers

local GRID = 8
local unlocked = false
local L = ns.L

function Movers.Snap(v)
    local sign = v < 0 and -1 or 1
    return sign * math.floor(math.abs(v) / GRID + 0.5) * GRID
end

-- Sizes and positions the mover from config alone, never from the frame's
-- own current size: inside a queued combat restyle the frame may not have
-- been resized yet, and a value read off it would be stale. No-op if the
-- frame has no mover.
function Movers.Sync(frame)
    local mover = frame.mover
    if not mover then return end
    local scope = frame.key
    mover:SetSize(ns.Config.Get(scope, "width"), ns.Config.Get(scope, "height"))
    mover:ClearAllPoints()
    mover:SetPoint("CENTER", UIParent, "CENTER", ns.Config.Get(scope, "x"), ns.Config.Get(scope, "y"))
end

function Movers.OnDragStop(mover)
    mover.dragging = false
    mover:StopMovingOrSizing()
    local mx, my = mover:GetCenter()
    local ux, uy = UIParent:GetCenter()
    ns.Config.Set(mover.frameKey, "x", Movers.Snap(mx - ux))
    ns.Config.Set(mover.frameKey, "y", Movers.Snap(my - uy))
end

function Movers.Attach(frame)
    if frame.mover then return end
    if InCombatLockdown() then
        ns.AfterCombat("attach:" .. frame.key, function() Movers.Attach(frame) end)
        return
    end
    local mover = CreateFrame("Frame", nil, UIParent)
    mover.frameKey = frame.key
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
    mover.label:SetText(L["FRAME_" .. frame.key])
    frame.mover = mover
    Movers.Sync(frame)
    mover:EnableMouse(false)
    mover:Hide()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", mover, "CENTER", 0, 0)
end

function Movers.IsUnlocked() return unlocked end

function Movers.Unlock()
    if InCombatLockdown() then
        ns.Print(L.LOCKED_IN_COMBAT)
        return false
    end
    unlocked = true
    for _, frame in pairs(ns.Frames) do
        if frame.mover then
            frame.mover:EnableMouse(true)
            frame.mover:Show()
        end
    end
    ns.Print(L.UNLOCKED)
    return true
end

-- A drag in progress is stopped at once. In combat only the flag is
-- cleared; hiding and disabling the movers waits until combat ends.
function Movers.Lock()
    unlocked = false
    for _, frame in pairs(ns.Frames) do
        local mover = frame.mover
        if mover then
            if mover.dragging then
                Movers.OnDragStop(mover)
            else
                mover:StopMovingOrSizing()
            end
        end
    end
    ns.AfterCombat("lockMovers", function()
        if unlocked then return end
        for _, frame in pairs(ns.Frames) do
            if frame.mover then
                frame.mover:EnableMouse(false)
                frame.mover:Hide()
            end
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
