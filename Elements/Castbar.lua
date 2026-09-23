local _, ns = ...

-- Castbar of a unit frame, docked below it.
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
    },
}
ns.Castbar = Castbar

local Config, Secrets, Settings = ns.Config, ns.Secrets, ns.Settings

Castbar.CAST_COLOR = { 1.0, 0.7, 0.0 }
Castbar.CHANNEL_COLOR = { 0.3, 0.8, 0.3 }

local STOP_EVENTS = {
    UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
}

function Castbar.Applies(scope)
    return Settings.AppliesTo(Settings.Get("castbarEnabled"), scope)
end

-- Gap between frame and castbar: room for both borders.
function Castbar.Gap(scope)
    return 2 * Config.Get(scope, "borderSize") + 2
end

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
-- of the duration object (guarded), otherwise left empty.
function Castbar.UpdateTime(bar, nowMs)
    local cast = bar.cast
    if not cast or not bar.time:IsShown() then return end
    local endMs = Secrets.Number(cast.endMs)
    if endMs then
        bar.time:SetFormattedText("%.1f", math.max(0, (endMs - (nowMs or now())) / 1000))
    elseif not (type(cast.duration) ~= "nil" and pcall(showRemaining, bar.time, cast.duration)) then
        bar.time:SetText("")
    end
end

function Castbar.Stop(bar)
    bar.cast = nil
    bar:Hide()
end

-- Puts the unit's current cast (or channel) on the bar. Returns false
-- when the unit is not casting (channelling) at all.
function Castbar.Begin(bar, unit, channel, castGUID)
    local info = read(unit, channel)
    if type(info[1]) == "nil" then return false end
    bar.cast = { startMs = info[4], endMs = info[5], channel = channel, guid = castGUID,
        duration = durationOf(unit, channel) }
    bar:SetMinMaxValues(info[4], info[5])
    bar:SetReverseFill(channel)
    local c = channel and Castbar.CHANNEL_COLOR or Castbar.CAST_COLOR
    bar:SetStatusBarColor(c[1], c[2], c[3])
    bar.text:SetText(info[1])
    bar.icon:SetTexture(info[3])
    bar:SetValue(now())
    Castbar.UpdateTime(bar)
    bar:Show()
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
    if not cast then return end
    local nowMs = now()
    bar:SetValue(nowMs)
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
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.time = bar:CreateFontString(nil, "OVERLAY")
    bar:SetScript("OnUpdate", Castbar.OnUpdate)
    bar:Hide()
    frame.castbar = bar
end

-- The icon sits left of the bar, inside the castbar's own rectangle.
local function anchor(bar, frame, scope, inset)
    local gap = Castbar.Gap(scope)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", inset, -gap)
    bar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -gap)
end

function Castbar.Style(frame)
    local bar = frame.castbar
    if not bar then return end
    local scope = frame.key
    local height = Config.Get(scope, "castbarHeight")
    local showIcon = Config.Get(scope, "castbarIcon")
    anchor(bar, frame, scope, showIcon and height or 0)
    bar:SetHeight(height)
    local tex = ns.Media.StatusBar(Config.Get(scope, "barTexture"))
    bar:SetStatusBarTexture(tex)
    bar.bg:SetTexture(tex)
    local bg = Config.Get(scope, "backgroundColor")
    bar.bg:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    ns.Single.DrawBorder(bar, scope)
    bar.icon:ClearAllPoints()
    bar.icon:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
    bar.icon:SetSize(height, height)
    bar.icon:SetShown(showIcon)
    local font = ns.Media.Font(Config.Get(scope, "fontFace"))
    local outline = Config.Get(scope, "fontOutline")
    local flags = (outline == "NONE") and "" or outline
    local fontSize = math.min(Config.Get(scope, "fontSize"), height)
    for _, fs in ipairs({ bar.text, bar.time }) do fs:SetFont(font, fontSize, flags) end
    bar.text:ClearAllPoints()
    bar.text:SetPoint("LEFT", bar, "LEFT", 4, 0)
    bar.text:SetJustifyH("LEFT")
    bar.text:SetShown(Config.Get(scope, "castbarName"))
    bar.time:ClearAllPoints()
    bar.time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.time:SetJustifyH("RIGHT")
    bar.time:SetShown(Config.Get(scope, "castbarTime"))
    if not Config.Get(scope, "castbarEnabled") then Castbar.Stop(bar) end
end

function Castbar.Update(frame, event, _, castGUID)
    local bar = frame.castbar
    if not bar then return end
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
        -- The unit itself changed (new target, timer): start over.
        Castbar.Refresh(bar, unit)
    end
end

ns.RegisterElement(Castbar)
