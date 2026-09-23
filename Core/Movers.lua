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

local function position(frame)
    local mover = frame.mover
    mover:SetSize(frame:GetWidth(), frame:GetHeight())
    mover:ClearAllPoints()
    mover:SetPoint("CENTER", UIParent, "CENTER", ns.Config.Get(frame.key, "x"), ns.Config.Get(frame.key, "y"))
end

function Movers.OnDragStop(mover)
    mover:StopMovingOrSizing()
    local mx, my = mover:GetCenter()
    local ux, uy = UIParent:GetCenter()
    ns.Config.Set(mover.frameKey, "x", Movers.Snap(mx - ux))
    ns.Config.Set(mover.frameKey, "y", Movers.Snap(my - uy))
end

function Movers.Attach(frame)
    if frame.mover then return end
    local mover = CreateFrame("Frame", nil, UIParent)
    mover.frameKey = frame.key
    mover:SetMovable(true)
    mover:SetClampedToScreen(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mover:SetScript("OnDragStop", Movers.OnDragStop)
    mover.overlay = mover:CreateTexture(nil, "OVERLAY")
    mover.overlay:SetAllPoints(mover)
    mover.overlay:SetColorTexture(0.3, 0.76, 0.97, 0.35)
    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetFont(ns.Media.Font("Friz Quadrata"), 11, "OUTLINE")
    mover.label:SetPoint("CENTER", mover, "CENTER", 0, 0)
    mover.label:SetText(L["FRAME_" .. frame.key])
    frame.mover = mover
    position(frame)
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
        frame.mover:EnableMouse(true)
        frame.mover:Show()
    end
    ns.Print(L.UNLOCKED)
    return true
end

function Movers.Lock()
    unlocked = false
    for _, frame in pairs(ns.Frames) do
        frame.mover:EnableMouse(false)
        frame.mover:Hide()
    end
    ns.Print(L.LOCKED)
end

-- Keep movers in step with size/position changes.
ns.Listen("CONFIG_CHANGED", function()
    ns.AfterCombat("movers", function()
        for _, frame in pairs(ns.Frames) do
            if frame.mover then position(frame) end
        end
    end)
end)
