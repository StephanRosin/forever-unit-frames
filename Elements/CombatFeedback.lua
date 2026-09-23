local _, ns = ...

-- Damage and heal numbers inside the frame, like Blizzard's hit indicator
-- on the player and pet frames (CombatFeedback.lua): damage red, heals
-- green, misses and the like as a word, with Blizzard's size steps and
-- timings. The amount may be secret: it goes to the font string untouched
-- (SetFormattedText) and is never measured or compared; readable amounts
-- are abbreviated like the health texts. The fade is an animation group
-- on a holder frame, so no Lua counts time.
local CombatFeedback = { name = "CombatFeedback", unitEvents = { "UNIT_COMBAT" } }
ns.CombatFeedback = CombatFeedback

local Config, Secrets, L = ns.Config, ns.Secrets, ns.L

CombatFeedback.DAMAGE = { 1, 0.25, 0.25 }
CombatFeedback.HEAL = { 0.3, 1, 0.4 }
CombatFeedback.WORD = { 1, 1, 1 }
-- Blizzard's timings: fade in, hold, fade out (seconds).
CombatFeedback.FADE_IN, CombatFeedback.HOLD, CombatFeedback.FADE_OUT = 0.2, 0.7, 0.3
-- Test mode shows this as damage.
CombatFeedback.SAMPLE = 1234

-- Events without a number that Blizzard names with a word.
local WORDS = {
    IMMUNE = true, BLOCK = true, DODGE = true, PARRY = true, MISS = true, RESIST = true,
    EVADE = true, DEFLECT = true, ABSORB = true, REFLECT = true, INTERRUPT = true,
}
-- A WOUND of readable zero: the flag says what happened, else a miss.
local ZERO_WOUND = { ABSORB = true, BLOCK = true, RESIST = true }
local CRITICAL = { CRITICAL = true, CRUSHING = true }

-- A plain string, or nil when secret or not a string.
local function plain(v)
    if Secrets.IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

local function alphaStep(group, from, to, duration, order)
    local anim = group:CreateAnimation("Alpha")
    anim:SetFromAlpha(from)
    anim:SetToAlpha(to)
    anim:SetDuration(duration)
    anim:SetOrder(order)
end

function CombatFeedback.Build(frame)
    local holder = CreateFrame("Frame", nil, frame.overlay)
    holder:SetAllPoints(frame.overlay)
    holder:Hide()
    local text = holder:CreateFontString(nil, "OVERLAY")
    text:SetFont(ns.Media.Font(nil), 12, "")
    local fade = holder:CreateAnimationGroup()
    alphaStep(fade, 0, 1, CombatFeedback.FADE_IN, 1)
    alphaStep(fade, 1, 1, CombatFeedback.HOLD, 2)
    alphaStep(fade, 1, 0, CombatFeedback.FADE_OUT, 3)
    fade:SetToFinalAlpha(true)
    fade:SetScript("OnFinished", function() holder:Hide() end)
    frame.feedback, frame.feedbackText, frame.feedbackFade = holder, text, fade
    -- A hidden frame drops its number: a paused fade must not resume
    -- later, perhaps on another unit.
    frame:HookScript("OnHide", function() CombatFeedback.Clear(frame) end)
end

-- Stops and hides a live number (a test mode sample stays).
function CombatFeedback.Clear(frame)
    if frame.feedback.preview then return end
    frame.feedbackFade:Stop()
    frame.feedback:Hide()
end

-- Font size of the numbers: half again the frame's font size.
function CombatFeedback.Size(scope)
    return math.floor(Config.Get(scope, "fontSize") * 1.5 + 0.5)
end

local function setFont(frame, size)
    local scope = frame.key
    ns.Texts.SetFont(frame.feedbackText, ns.Media.Font(Config.Get(scope, "fontFace")), size,
        Config.Get(scope, "fontOutline"))
end

local function paint(text, color)
    text:SetTextColor(color[1], color[2], color[3], 1)
end

function CombatFeedback.Style(frame)
    local scope, text = frame.key, frame.feedbackText
    setFont(frame, CombatFeedback.Size(scope))
    text:ClearAllPoints()
    -- Over the portrait when there is one, like Blizzard's; else mid bar.
    local anchor = Config.Get(scope, "portraitMode") == "OFF" and frame.health or frame.portraitBg
    text:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    local shadow = Config.Get(scope, "fontShadow")
    text:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
    local on = Config.Get(scope, "combatFeedback")
    if frame.feedback.preview then
        frame.feedback:SetShown(on)
    elseif not on then
        CombatFeedback.Clear(frame)
    end
end

local function play(frame)
    local holder = frame.feedback
    frame.feedbackFade:Stop()
    holder:SetAlpha(0)
    holder:Show()
    frame.feedbackFade:Play()
end

-- UNIT_COMBAT: unit, action, flags, amount, school. Other events are
-- whole frame refreshes: the unit may have changed (target, party slot),
-- so an old number goes; a timer refresh (target of target) is none.
function CombatFeedback.Update(frame, event, _, action, flags, amount)
    if event ~= "UNIT_COMBAT" then
        if event ~= ns.Single.POLL then CombatFeedback.Clear(frame) end
        return
    end
    if frame.feedback.preview then return end
    local scope = frame.key
    if not Config.Get(scope, "combatFeedback") then return end
    local kind, flag = plain(action), plain(flags)
    local text, size = frame.feedbackText, CombatFeedback.Size(scope)
    if kind == "WOUND" and Secrets.Number(amount) == 0 then
        kind = ZERO_WOUND[flag] and flag or "MISS"
    end
    if kind == "WOUND" or kind == "HEAL" then
        if CRITICAL[flag] then size = math.floor(size * 1.5 + 0.5) end
        setFont(frame, size)
        text:SetFormattedText("%s", Secrets.Abbreviate(amount))
        paint(text, kind == "WOUND" and CombatFeedback.DAMAGE or CombatFeedback.HEAL)
    elseif WORDS[kind] then
        setFont(frame, size)
        text:SetText(L["FEEDBACK_" .. kind])
        paint(text, CombatFeedback.WORD)
    else
        return
    end
    play(frame)
end

function CombatFeedback.Preview(frame, on)
    local holder = frame.feedback
    holder.preview = on or nil
    frame.feedbackFade:Stop()
    if not on then
        holder:Hide()
        return
    end
    setFont(frame, CombatFeedback.Size(frame.key))
    frame.feedbackText:SetFormattedText("%s", Secrets.Abbreviate(CombatFeedback.SAMPLE))
    paint(frame.feedbackText, CombatFeedback.DAMAGE)
    holder:SetAlpha(1)
    holder:SetShown(Config.Get(frame.key, "combatFeedback"))
end

ns.RegisterElement(CombatFeedback)
