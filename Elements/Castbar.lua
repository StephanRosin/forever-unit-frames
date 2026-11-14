local _, ns = ...

-- Castbar of a unit frame: docked below or above it, or (single frames)
-- detached with a mover of its own, or over the frame's portrait (seen only
-- while casting, unless "Always show").
--
-- Another unit's cast can arrive as secret values: name, icon, start and
-- end time. They are only ever handed to widgets: the bar's range is the
-- raw start and end (milliseconds), its value the clock, which is ours.
-- Whether anything is being cast is asked with type(), never by truth: a
-- secret cannot be tested. A stop event ends the bar only after asking
-- the client what the unit is doing now, so a late stop for an earlier
-- cast cannot wipe a new one; castGUIDs are compared only when the client
-- allows it.
local Castbar = {
    name = "Castbar",
    unitEvents = {
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
        "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
        "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    },
}
ns.Castbar = Castbar

local Config, Secrets, Settings = ns.Config, ns.Secrets, ns.Settings

-- The player's interrupts, per class: every rank of each spell, lowest first.
-- Classic IDs, as Range.CLASS_SPELLS; the spell book decides which rank counts.
Castbar.INTERRUPTS = {
    WARRIOR = { { 6552, 6554 }, { 72, 1671, 1672 } },        -- Pummel, Shield Bash
    ROGUE = { { 1766, 1767, 1768, 1769 } },                  -- Kick
    MAGE = { { 2139 } },                                     -- Counterspell
    PRIEST = { { 15487 } },                                  -- Silence
    SHAMAN = { { 8042, 8044, 8045, 8046, 10412, 10413, 10414 } }, -- Earth Shock
}
Castbar.INTERRUPT_COLOR = { 0.2, 1, 0.3, 1 }
-- Height of the strip along the bar's bottom edge.
Castbar.INTERRUPT_HEIGHT = 2

Castbar.CAST_COLOR = { 1.0, 0.7, 0.0 }
Castbar.CHANNEL_COLOR = { 0.3, 0.8, 0.3 }
-- Blizzard's own pet bar uses it (PET_WAIT_TEXTURE), so the file exists.
Castbar.PREVIEW_ICON = "Interface\\Icons\\Spell_Nature_TimeStop"
Castbar.LATENCY_COLOR = { 1, 0, 0, 0.55 }
-- Test mode: the share of the bar the sample's latency zone takes.
Castbar.PREVIEW_LATENCY = 0.15

local STOP_EVENTS = {
    UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
}

function Castbar.Applies(scope)
    return Settings.AppliesTo(Settings.Get("castbarEnabled"), scope)
end

-- Castbar height on the pixel grid.
local function barHeight(scope)
    return ns.Pixel.Snap(Config.Get(scope, "castbarHeight"))
end
Castbar.Height = barHeight

local function now() return GetTime() * 1000 end

local function read(unit, channel)
    if channel then return { UnitChannelInfo(unit) } end
    return { UnitCastingInfo(unit) }
end

-- The duration object of the running cast, when the client has one.
local function durationOf(unit, channel)
    local fn = channel and UnitChannelDuration or UnitCastingDuration
    if not fn then return nil end
    local ok, duration = pcall(fn, unit)
    if ok then return duration end
    return nil
end

local function showRemaining(fontString, duration)
    fontString:SetFormattedText("%.1f", duration:GetRemainingDuration())
end

-- Seconds left: computed when the end time is readable, otherwise asked
-- of the duration object (guarded), otherwise left empty. A duration
-- object that refused once is dropped: it is not asked every frame.
function Castbar.UpdateTime(bar, nowMs)
    local cast = bar.cast
    if not cast or not bar.time:IsShown() then return end
    local endMs = Secrets.Number(cast.endMs)
    if endMs then
        bar.time:SetFormattedText("%.1f", math.max(0, (endMs - (nowMs or now())) / 1000))
        return
    end
    if type(cast.duration) ~= "nil" and pcall(showRemaining, bar.time, cast.duration) then return end
    cast.duration = nil
    bar.time:SetText("")
end

-- The value is always the clock, so the fill grows. A cast shows that
-- growth in the cast colour. A channel must drain: its fill (growing from
-- the right) is invisible, and bar.remain paints the rest, from the bar's
-- left edge to the fill's left edge, in the channel colour. The background
-- keeps its own colour either way, translucency included. No arithmetic
-- on cast values: the fill texture does the measuring.
local function latencyOn(scope)
    return Settings.AppliesTo(Settings.Get("castbarLatency"), scope) and Config.Get(scope, "castbarLatency")
end

-- The share of the bar your latency takes, nil without a readable cast.
local function latencyShare(bar)
    if bar.preview then return Castbar.PREVIEW_LATENCY end
    local cast = bar.cast
    if not cast then return nil end
    local startMs, endMs = Secrets.Number(cast.startMs), Secrets.Number(cast.endMs)
    if not startMs or not endMs or endMs <= startMs then return nil end
    local _, _, home, world = GetNetStats()
    local latency = Secrets.Number(world) or Secrets.Number(home) or 0
    return math.min(1, latency / (endMs - startMs))
end

-- The zone runs the bar's full height, from the chosen side plus its offset.
local function paintLatency(bar)
    local scope, lag = bar.scope, bar.lag
    local share = latencyOn(scope) and latencyShare(bar)
    local width = share and ns.Pixel.Snap(bar:GetWidth() * share) or 0
    if width < 1 then
        lag:Hide()
        return
    end
    local side = Config.Get(scope, "castbarLatencyPoint")
    if side == "END" then side = bar.cast and bar.cast.channel and "LEFT" or "RIGHT" end
    local x = ns.Pixel.Snap(Config.Get(scope, "castbarLatencyX"))
    lag:ClearAllPoints()
    lag:SetPoint("TOP" .. side, bar, "TOP" .. side, x, 0)
    lag:SetPoint("BOTTOM" .. side, bar, "BOTTOM" .. side, x, 0)
    lag:SetWidth(width)
    lag:Show()
end

-- isActive and isOnGCD are documented NeverSecret, IsSpellUsable without secret
-- returns. Usable also covers stance and rage. The global cooldown alone does
-- not count as a wait: it is over before an interrupt could be pressed anyway.
local function spellReady(id)
    if Secrets.Call(C_Spell.IsSpellUsable, id) ~= true then return false end
    local cooldown = Secrets.Call(C_Spell.GetSpellCooldown, id)
    return type(cooldown) == "table" and (not cooldown.isActive or cooldown.isOnGCD == true)
end

local function interruptReady()
    local _, class = UnitClass("player")
    for _, ranks in ipairs(Castbar.INTERRUPTS[Secrets.Plain(class, "string") or ""] or {}) do
        for i = #ranks, 1, -1 do
            if ns.RaidSpellbook.InBook(ranks[i]) then
                if spellReady(ranks[i]) then return true end
                break
            end
        end
    end
    return false
end

local function interruptOn(scope)
    return Settings.AppliesTo(Settings.Get("castbarInterrupt"), scope) and Config.Get(scope, "castbarInterrupt")
end

-- The strip: your interrupt is ready and this cast can be interrupted. A cast's
-- notInterruptible may be secret, so the client sets the opacity from it.
local function paintInterrupt(bar)
    local marker, cast = bar.interrupt, bar.cast
    local on = interruptOn(bar.scope) and (bar.preview or (cast and interruptReady()))
    marker:SetShown(on or false)
    if not on then return end
    if not cast or type(cast.notInterruptible) == "nil" then
        marker:SetAlpha(1)
    else
        marker:SetAlphaFromBoolean(cast.notInterruptible, 0, 1)
    end
end

local function paint(bar)
    paintLatency(bar)
    paintInterrupt(bar)
    local bg = Config.Get(bar.scope, "backgroundColor")
    bar.bg:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    bar.iconBg:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
    if bar.cast and bar.cast.channel then
        local c = Castbar.CHANNEL_COLOR
        bar:SetStatusBarColor(c[1], c[2], c[3], 0)
        local remain = bar.remain
        remain:ClearAllPoints()
        remain:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        remain:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "BOTTOMLEFT", 0, 0)
        remain:SetVertexColor(c[1], c[2], c[3])
        remain:Show()
    else
        local c = Castbar.CAST_COLOR
        bar:SetStatusBarColor(c[1], c[2], c[3], 1)
        bar.remain:Hide()
    end
end

-- Shows or hides the bar and tells the unit's shape: a docked castbar
-- joins the frame's block while shown (Elements/Shape.lua). Told here, not
-- from OnShow / OnHide: those do not fire while the frame is hidden.
local function setShown(bar, shown)
    bar:SetShown(shown)
    local frame = bar:GetParent()
    if frame.unitBox then ns.Shape.Refresh(frame) end
end

-- The client animates the bar itself from the cast's duration object
-- (StatusBar:SetTimerDuration), smoothly and with secret times too. Setting
-- the value from Lua every frame looked jagged on other units' casts (a
-- report: party, target, focus). Without a duration object, or on a client
-- without timer bars, OnUpdate sets the value as before.
local function startTimer(bar, cast)
    if type(cast.duration) == "nil" or not bar.SetTimerDuration then return false end
    local interpolation = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
    local direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime
    return (pcall(bar.SetTimerDuration, bar, cast.duration, interpolation, direction))
end

-- Ends a running timer: an empty duration, then a plain range.
local function stopTimer(bar)
    if not bar.timing then return end
    bar.timing = nil
    if C_DurationUtil and C_DurationUtil.CreateDuration then
        pcall(bar.SetTimerDuration, bar, C_DurationUtil.CreateDuration())
    end
end

-- Idle: hidden, or with "Always show" an empty bar that holds its place.
-- A docked castbar holds it too while a threat bar sits below or beside it
-- (Elements/ThreatBar.lua): nothing may move in combat.
local function holdsPlace(scope)
    if Config.Get(scope, "castbarAlwaysShow") then return true end
    return ns.ThreatBar and ns.ThreatBar.Active(scope) and Castbar.Docked(scope) or false
end

function Castbar.Stop(bar)
    bar.cast = nil
    stopTimer(bar)
    local scope = bar.scope
    if not (Config.Get(scope, "castbarEnabled") and holdsPlace(scope)) then
        setShown(bar, false)
        return
    end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetReverseFill(false)
    paint(bar)
    bar.text:SetText("")
    bar.time:SetText("")
    bar.icon:SetTexture(nil)
    setShown(bar, true)
end

-- Puts the unit's current cast (or channel) on the bar. Returns false
-- when the unit is not casting (channelling) at all.

function Castbar.Begin(bar, unit, channel, castGUID)
    local info = read(unit, channel)
    if type(info[1]) == "nil" then return false end
    stopTimer(bar)
    bar.cast = { startMs = info[4], endMs = info[5], channel = channel, guid = castGUID,
        duration = durationOf(unit, channel),
        -- A channel has no castID, so the flag comes one earlier.
        notInterruptible = info[channel and 7 or 8] }
    bar:SetMinMaxValues(info[4], info[5])
    bar:SetReverseFill(channel)
    paint(bar)
    bar.text:SetText(info[1])
    bar.icon:SetTexture(info[3])
    bar:SetValue(now())
    if startTimer(bar, bar.cast) then bar.timing = true end
    Castbar.UpdateTime(bar)
    setShown(bar, true)
    return true
end

-- Whatever the unit is doing now: a cast, a channel, or nothing.
function Castbar.Refresh(bar, unit)
    if not Castbar.Begin(bar, unit, false) and not Castbar.Begin(bar, unit, true) then
        Castbar.Stop(bar)
    end
end

-- True only when the stop provably belongs to another cast. Comparing may
-- be refused (secret GUIDs); then nothing is known and the caller asks the
-- client instead.
function Castbar.IsOtherCast(bar, castGUID)
    local cast = bar.cast
    if not cast or type(castGUID) == "nil" or type(cast.guid) == "nil" then return false end
    -- Secrets.Bool: a refused or secret comparison gives nil, not a guess.
    return Secrets.Bool(function() return castGUID == cast.guid end) == false
end

function Castbar.OnUpdate(bar)
    local cast = bar.cast
    if not cast or bar.preview then return end
    local nowMs = now()
    if not bar.timing then bar:SetValue(nowMs) end
    paintInterrupt(bar)
    local endMs = Secrets.Number(cast.endMs)
    if endMs and nowMs >= endMs then
        -- The stop event went missing; a readable end time is proof enough.
        Castbar.Stop(bar)
        return
    end
    Castbar.UpdateTime(bar, nowMs)
end

function Castbar.Build(frame)
    if not Castbar.Applies(frame.key) then return end
    local bar = CreateFrame("StatusBar", nil, frame)
    bar.scope = frame.key
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.remain = bar:CreateTexture(nil, "BORDER")
    bar.remain:Hide()
    -- Above the fill, below the texts.
    bar.lag = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    local lagColor = Castbar.LATENCY_COLOR
    bar.lag:SetColorTexture(lagColor[1], lagColor[2], lagColor[3], lagColor[4])
    bar.lag:Hide()
    bar.interrupt = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    local ready = Castbar.INTERRUPT_COLOR
    bar.interrupt:SetColorTexture(ready[1], ready[2], ready[3], ready[4])
    bar.interrupt:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    bar.interrupt:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    bar.interrupt:Hide()
    -- Fills the icon slot while no spell icon is shown.
    bar.iconBg = bar:CreateTexture(nil, "BACKGROUND")
    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.time = bar:CreateFontString(nil, "OVERLAY")
    -- The castbar's whole rectangle, icon included: a detached castbar's
    -- corners are rounded and its border goes around it.
    bar.box = CreateFrame("Frame", nil, bar)
    for _, texture in ipairs({ bar.bg, bar.remain, bar.lag, bar.interrupt, bar.iconBg, bar.icon }) do
        ns.Corners.Add(bar, texture)
    end
    ns.Corners.Add(bar, function() return bar:GetStatusBarTexture() end)
    bar.clip = ns.Corners.Clipper(bar)
    bar:SetScript("OnUpdate", Castbar.OnUpdate)
    bar:Hide()
    frame.castbar = bar
end

-- BELOW, ABOVE, DETACHED or PORTRAIT; PORTRAIT without a portrait is
-- BELOW. Party castbars only dock.
function Castbar.Placement(scope)
    if Settings.AppliesTo(Settings.Get("castbarPosition"), scope) then
        local placement = Config.Get(scope, "castbarPosition")
        if placement == "PORTRAIT" and Config.Get(scope, "portraitMode") == "OFF" then return "BELOW" end
        return placement
    end
    return Config.Get(scope, "castbarDock")
end

-- Docked: a row of its own outside the frame, below or above it.
function Castbar.Docked(scope)
    local placement = Castbar.Placement(scope)
    return placement == "BELOW" or placement == "ABOVE"
end

-- Room a docked castbar takes next to its frame: the bar and the unit's
-- outer border beyond it. Zero when the castbar is off or not docked.
function Castbar.DockedDepth(scope)
    if not Castbar.Applies(scope) or not Config.Get(scope, "castbarEnabled") or not Castbar.Docked(scope) then
        return 0
    end
    return barHeight(scope) + ns.Border.Extent(scope)
end

-- Whole castbar size, icon included: the frame's width.
local function size(scope)
    return ns.Pixel.Snap(Config.Get(scope, "width")), barHeight(scope)
end

-- Over the portrait: along its bottom edge, at most as tall as it (the
-- strip, or the square as tall as the frame's bars; Elements/Portrait.lua).
local function portraitHeight(frame, scope)
    if Config.Get(scope, "portraitMode") == "TOP" then return frame.portraitStrip or 0 end
    return frame.layoutHeight or ns.Pixel.Snap(Config.Get(scope, "height"))
end

-- The icon sits left of the bar, inside the castbar's own rectangle.
-- Docked, the bar is one more row of the frame: flush against it, inside
-- the unit's one border (Elements/Shape.lua).
local function anchor(bar, frame, scope, inset)
    local placement = Castbar.Placement(scope)
    bar:ClearAllPoints()
    if placement == "DETACHED" then
        if bar.mover then
            ns.Movers.Sync(bar)
            bar:SetPoint("TOPLEFT", bar.mover, "TOPLEFT", inset, 0)
            bar:SetPoint("BOTTOMRIGHT", bar.mover, "BOTTOMRIGHT", 0, 0)
        else
            local w, h = size(scope)
            local Pixel = ns.Pixel
            bar:SetPoint("TOPLEFT", UIParent, "CENTER",
                Pixel.Centre(Config.Get(scope, "castbarX"), w) - w / 2 + inset,
                Pixel.Centre(Config.Get(scope, "castbarY"), h) + h / 2)
            bar:SetWidth(w - inset)
        end
    elseif placement == "PORTRAIT" then
        bar:SetPoint("BOTTOMLEFT", frame.portraitBg, "BOTTOMLEFT", inset, 0)
        bar:SetPoint("BOTTOMRIGHT", frame.portraitBg, "BOTTOMRIGHT", 0, 0)
    elseif placement == "ABOVE" then
        bar:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", inset, 0)
        bar:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 0)
    else
        bar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", inset, 0)
        bar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end
end

-- Handle for a detached castbar; shown while unlocked only if detached.
function Castbar.MoverSpec(frame)
    local scope = frame.key
    return {
        id = "castbar:" .. scope, scope = scope, xKey = "castbarX", yKey = "castbarY", anchor = false,
        label = function() return ns.L.MOVER_CASTBAR:format(ns.L["FRAME_" .. scope]) end,
        size = function() return size(scope) end,
        active = function()
            return ns.FrameEnabled(scope) and Config.Get(scope, "castbarEnabled")
                and Castbar.Placement(scope) == "DETACHED"
        end,
    }
end

-- Single frames only (party castbars cannot be detached).
function Castbar.AttachMover(frame)
    local bar = frame.castbar
    if not bar or not Settings.AppliesTo(Settings.Get("castbarPosition"), frame.key) then return end
    ns.Movers.Attach(bar, Castbar.MoverSpec(frame))
    ns.AfterCombat("castbarStyle:" .. frame.key, function() Castbar.Style(frame) end)
end

-- Docked, the castbar looks part of the frame but lies outside the unit
-- button: hovering it found no unit for mouseover casts (reported on
-- CurseForge). The button's hit area grows over it; out of combat only,
-- the button is secure.
-- shortcut: the area stays clickable while no cast shows; the room is
-- the frame's anyway (DockedDepth keeps it free).
local function hitArea(frame)
    local depth, placement = Castbar.DockedDepth(frame.key), Castbar.Placement(frame.key)
    local top = placement == "ABOVE" and -depth or 0
    local bottom = placement == "BELOW" and -depth or 0
    ns.AfterCombat("castbarHit:" .. frame.key, function() frame:SetHitRectInsets(0, 0, top, bottom) end, "last")
end

function Castbar.Style(frame)
    local bar = frame.castbar
    if not bar then return end
    hitArea(frame)
    local scope = frame.key
    local placement = Castbar.Placement(scope)
    local height = barHeight(scope)
    if placement == "PORTRAIT" then height = math.min(height, portraitHeight(frame, scope)) end
    local showIcon = Config.Get(scope, "castbarIcon")
    anchor(bar, frame, scope, showIcon and height or 0)
    -- Above the 3D portrait (a frame of its own), laid over it or moved
    -- there detached.
    bar:SetFrameLevel(frame.portrait3D:GetFrameLevel() + 1)
    bar:SetHeight(height)
    local tex = ns.Media.StatusBar(Config.Get(scope, "barTexture"))
    bar:SetStatusBarTexture(tex)
    bar.bg:SetTexture(tex)
    bar.remain:SetTexture(tex)
    bar.interrupt:SetHeight(ns.Pixel.Snap(Castbar.INTERRUPT_HEIGHT))
    paint(bar)
    bar.icon:ClearAllPoints()
    bar.icon:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
    bar.icon:SetSize(height, height)
    bar.icon:SetShown(showIcon)
    bar.iconBg:ClearAllPoints()
    bar.iconBg:SetAllPoints(bar.icon)
    bar.iconBg:SetShown(showIcon)
    bar.box:ClearAllPoints()
    bar.box:SetPoint("TOPLEFT", bar, "TOPLEFT", showIcon and -height or 0, 0)
    bar.box:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    -- Docked, the castbar is part of the unit's block: rounded with it and
    -- inside its border (Elements/Shape.lua). Detached, it is a block of
    -- its own with its own border.
    if placement == "DETACHED" then
        local w, h = size(scope)
        local radius = ns.Corners.Clamp(ns.Corners.Radius(scope), w, h)
        ns.Corners.Fit(bar.clip, bar.box, radius)
        ns.Border.Draw(bar, scope, bar.box, radius)
    else
        ns.Corners.Fit(bar.clip, frame.unitBox, ns.Shape.Radius(frame))
        ns.Border.Hide(bar)
    end
    local font = ns.Media.Font(Config.Get(scope, "fontFace"))
    local outline = Config.Get(scope, "fontOutline")
    local fontSize = math.min(Config.Get(scope, "fontSize"), Config.Get(scope, "castbarHeight"))
    for _, fs in ipairs({ bar.text, bar.time }) do ns.Texts.SetFont(fs, font, fontSize, outline) end
    bar.text:ClearAllPoints()
    local pad = ns.Pixel.Snap(4)
    bar.text:SetPoint("LEFT", bar, "LEFT", pad, 0)
    -- The name ends where the time begins (zero wide when hidden or empty).
    bar.text:SetPoint("RIGHT", bar.time, "LEFT", -pad, 0)
    bar.text:SetWordWrap(false)
    bar.text:SetJustifyH("LEFT")
    bar.text:SetShown(Config.Get(scope, "castbarName"))
    bar.time:ClearAllPoints()
    bar.time:SetPoint("RIGHT", bar, "RIGHT", -pad, 0)
    bar.time:SetJustifyH("RIGHT")
    bar.time:SetShown(Config.Get(scope, "castbarTime"))
    -- A hidden time keeps its size; empty, it frees the room for the name.
    if not bar.time:IsShown() then bar.time:SetText("") end
    if bar.preview then
        Castbar.Preview(frame, true)
    elseif not bar.cast or not Config.Get(scope, "castbarEnabled") then
        Castbar.Stop(bar)
    end
end

-- Test mode: a still sample cast on every enabled castbar. Real casts are
-- ignored until the preview ends.
function Castbar.Preview(frame, on)
    local bar = frame.castbar
    if not bar then return end
    bar.preview = on or nil
    if not (on and Config.Get(frame.key, "castbarEnabled")) then
        Castbar.Stop(bar)
        return
    end
    bar.cast = nil
    stopTimer(bar)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.6)
    bar:SetReverseFill(false)
    paint(bar)
    bar.text:SetText(ns.L.TEST_CAST)
    bar.icon:SetTexture(Castbar.PREVIEW_ICON)
    bar.time:SetText(bar.time:IsShown() and "1.5" or "")
    setShown(bar, true)
end

function Castbar.Update(frame, event, _, castGUID)
    local bar = frame.castbar
    if not bar or bar.preview then return end
    if not Config.Get(frame.key, "castbarEnabled") then
        Castbar.Stop(bar)
        return
    end
    local unit = frame.unit
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
        if not Castbar.Begin(bar, unit, false, castGUID) then Castbar.Stop(bar) end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if not Castbar.Begin(bar, unit, true) then Castbar.Stop(bar) end
    elseif STOP_EVENTS[event] then
        if not Castbar.IsOtherCast(bar, castGUID) then Castbar.Refresh(bar, unit) end
    else
        -- The unit itself changed (new target, test mode, timer): start over.
        Castbar.Refresh(bar, unit)
    end
end

ns.RegisterElement(Castbar)
