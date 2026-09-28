local _, ns = ...

-- Animation of the combat icons (the player's, Elements/StatusIcons.lua,
-- and everyone else's, Elements/UnitIcons.lua). Blizzard's combat icon is
-- a still image; this adds the client's own animation groups:
-- * BURST: as the icon appears it springs in from bigger and flashes once
--   (an additive copy of the art fading out), then stands still.
-- * PULSE: while shown it breathes between full and faint.
-- Plain textures and animation groups: nothing protected, fine in combat.
local CombatAnimation = {}
ns.CombatAnimation = CombatAnimation

-- The burst: from this scale down to 1, while the flash fades.
CombatAnimation.BURST_SCALE = 1.8
CombatAnimation.BURST_SECONDS = 0.3
CombatAnimation.FLASH_SECONDS = 0.5
-- The pulse: down to this opacity and back, per half cycle.
CombatAnimation.PULSE_ALPHA = 0.4
CombatAnimation.PULSE_SECONDS = 0.6

-- tex: the icon; atlas: its art, for the flash. Returns the controller.
function CombatAnimation.New(tex, atlas)
    local parent = tex:GetParent()
    local flash = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    flash:SetAtlas(atlas)
    flash:SetBlendMode("ADD")
    flash:SetAllPoints(tex)
    flash:SetAlpha(0)

    local burst = tex:CreateAnimationGroup()
    local grow = burst:CreateAnimation("Scale")
    grow:SetScaleFrom(CombatAnimation.BURST_SCALE, CombatAnimation.BURST_SCALE)
    grow:SetScaleTo(1, 1)
    grow:SetOrigin("CENTER", 0, 0)
    grow:SetDuration(CombatAnimation.BURST_SECONDS)
    grow:SetSmoothing("OUT")
    local fadeIn = burst:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(CombatAnimation.BURST_SECONDS / 2)

    local shine = flash:CreateAnimationGroup()
    local fade = shine:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(CombatAnimation.FLASH_SECONDS)
    shine:SetToFinalAlpha(true)

    local pulse = tex:CreateAnimationGroup()
    local breathe = pulse:CreateAnimation("Alpha")
    breathe:SetFromAlpha(1)
    breathe:SetToAlpha(CombatAnimation.PULSE_ALPHA)
    breathe:SetDuration(CombatAnimation.PULSE_SECONDS)
    pulse:SetLooping("BOUNCE")

    return { tex = tex, flash = flash, burst = burst, shine = shine, pulse = pulse, shown = false }
end

local function stop(a)
    a.burst:Stop()
    a.shine:Stop()
    a.pulse:Stop()
    a.flash:SetAlpha(0)
end

-- The icon's state: shown or not, and the mode (OFF, BURST, PULSE). Starts
-- an animation only when the icon comes up (a burst) or keeps one running
-- (a pulse); unchanged calls do nothing.
function CombatAnimation.Set(a, shown, mode)
    if not a then return end
    local was = a.shown
    a.shown = shown
    if not shown or mode == "OFF" then
        if was or mode == "OFF" then stop(a) end
        return
    end
    if mode == "PULSE" then
        a.burst:Stop()
        if not a.pulse:IsPlaying() then a.pulse:Play() end
    elseif mode == "BURST" then
        a.pulse:Stop()
        if not was then
            a.burst:Play()
            a.shine:Play()
        end
    end
end

-- Forget the state (the icon was hidden without Set, e.g. a new unit).
function CombatAnimation.Reset(a)
    if not a then return end
    a.shown = false
    stop(a)
end
