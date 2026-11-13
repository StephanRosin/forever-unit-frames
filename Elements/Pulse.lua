local _, ns = ...

-- A slow pulse (alpha in and out) on the dispel highlights: the unit
-- frames' ring (Elements/Dispel.lua) and the raid cells' tint and border
-- (Raid/CellAuras.lua). Only the alpha of our own textures moves, so it
-- runs in combat too.
local Pulse = {}
ns.Pulse = Pulse

Pulse.LOW, Pulse.DURATION = 0.25, 0.6

local function group(region)
    local g = region.fufPulse
    if g then return g end
    g = region:CreateAnimationGroup()
    g:SetLooping("BOUNCE")
    local fade = g:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(Pulse.LOW)
    fade:SetDuration(Pulse.DURATION)
    fade:SetSmoothing("IN_OUT")
    region.fufPulse = g
    return g
end

-- regions pulse while on. Started once, a group keeps playing while its
-- region hides and shows (Blizzard stops its own on hide only to save
-- work: AnimateWhileShownTemplate); the client's aura buttons take no
-- addon scripts, so there is no OnShow to start it again anyway.
function Pulse.Set(regions, on)
    for _, region in ipairs(regions) do
        local g = region.fufPulse
        if on then
            g = g or group(region)
            if not g:IsPlaying() then g:Play() end
        elseif g then
            g:Stop()
        end
    end
end
