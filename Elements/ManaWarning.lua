local _, ns = ...

-- The low mana warning: an icon and / or a text that shows while your mana
-- is below a share (manaWarnBelow, in percent), in a block of its own
-- with a mover. Off by default. In combat only unless manaWarnOutOfCombat;
-- optionally only in a group or raid. A line to the group's chat when it
-- comes up (manaWarnChat). A click (manaWarnClick, with manaWarnClickKey
-- held) sends that line or uses an item, a spell or a macro text.
-- Mana counts in any form (a druid in cat form too); a class without mana
-- never sees it.
--
-- Item, spell and macro need a secure button, and the client lets no one
-- show, hide or switch the mouse of a secure button in combat (nor of its
-- parents). So it is a frame of its own on UIParent over the block, shown
-- whenever such a click is set, low mana or not: in combat a click with
-- the key held on the empty place does it too. The block itself stays an
-- ordinary frame that comes and goes.
--
-- The player's own mana is not secret today. Should it be, the share
-- cannot be compared: the block's opacity then comes from a step curve of
-- UnitPowerPercent (as the totems' from their time left), and no chat line
-- is sent (a secret must never reach the chat).
local ManaWarning = { name = "ManaWarning",
    unitEvents = { "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" } }
ns.ManaWarning = ManaWarning

local Config, Pixel, Secrets = ns.Config, ns.Pixel, ns.Secrets

ManaWarning.SCOPES = { player = true }
ManaWarning.MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
-- The shipped icon (Major Mana Potion), when none is picked.
ManaWarning.ICON = ns.Settings.Get("manaWarnIcon").icon
-- At most one chat line in this many seconds, whatever the mana does
-- around the line.
ManaWarning.CHAT_GAP = 30
-- Test mode: the share the sample shows.
ManaWarning.SAMPLE_PERCENT = 15

local function setting(scope, key) return Config.Get(scope, key) end
local setShown

local function enabled(scope)
    return ns.FrameEnabled(scope) and setting(scope, "manaWarn") == true
end

-- The secure click's type and its attribute, by manaWarnClick.
ManaWarning.SECURE = { ITEM = "item", SPELL = "spell", MACRO = "macrotext" }
ManaWarning.SECURE_TYPE = { ITEM = "item", SPELL = "spell", MACRO = "macro" }
-- The modifier prefixes of the click attributes (SecureButton_
-- GetModifiedAttribute), by manaWarnClickKey.
ManaWarning.PREFIX = { NONE = "", SHIFT = "shift-", CTRL = "ctrl-", ALT = "alt-" }

local function showsIcon(scope) return setting(scope, "manaWarnShow") ~= "TEXT" end
local function showsText(scope) return setting(scope, "manaWarnShow") ~= "ICON" end

-- The block's size: the icon and the text beside it, either or both.
function ManaWarning.Size(scope)
    local icon = showsIcon(scope) and Pixel.Snap(setting(scope, "manaWarnSize")) or 0
    local font = setting(scope, "manaWarnFontSize")
    local textW = showsText(scope) and font * 7 or 0
    local gap = (icon > 0 and textW > 0) and 4 or 0
    return math.max(icon + gap + textW, 16), math.max(icon, showsText(scope) and font + 4 or 0, 16)
end

-- Building ----------------------------------------------------------------------------

function ManaWarning.Build(frame)
    if not ManaWarning.SCOPES[frame.key] then return end
    local holder = CreateFrame("Button", nil, frame)
    holder:Hide()
    holder:EnableMouse(false)
    local mw = { holder = holder }
    mw.icon = holder:CreateTexture(nil, "ARTWORK")
    mw.icon:SetTexture(ManaWarning.ICON)
    mw.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    mw.text = holder:CreateFontString(nil, "OVERLAY")
    holder:SetScript("OnClick", function()
        if ManaWarning.KeyHeld(frame.key) then ManaWarning.Announce(frame) end
    end)
    -- Both strokes: SecureActionButton_OnClick acts on the one the player
    -- casts on (ActionButtonUseKeyDown), as Raid/Tools.lua.
    local click = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    click:RegisterForClicks("AnyUp", "AnyDown")
    click:Hide()
    mw.click = click
    frame.manaWarning = mw
end

local function clamp(scope, axis, v)
    local w, h = ManaWarning.Size(scope)
    local half = axis == "x" and (UIParent:GetWidth() - w) / 2 or (UIParent:GetHeight() - h) / 2
    if half <= 0 then return 0 end
    return math.max(-half, math.min(half, v))
end

function ManaWarning.MoverSpec(frame)
    local scope = frame.key
    return {
        id = "manaWarn:" .. scope, scope = scope, xKey = "manaWarnX", yKey = "manaWarnY", anchor = false,
        label = function() return ns.L.MOVER_MANA_WARN end,
        size = function() return ManaWarning.Size(scope) end,
        active = function() return enabled(scope) end,
        clamp = function(axis, v) return clamp(scope, axis, v) end,
    }
end

local function place(frame)
    local mw, scope = frame.manaWarning, frame.key
    local holder = mw.holder
    holder:ClearAllPoints()
    if holder.mover then
        ns.Movers.Sync(holder)
        holder:SetAllPoints(holder.mover)
    else
        local w, h = ManaWarning.Size(scope)
        holder:SetSize(w, h)
        holder:SetPoint("CENTER", UIParent, "CENTER", Pixel.Centre(setting(scope, "manaWarnX"), w),
            Pixel.Centre(setting(scope, "manaWarnY"), h))
    end
end

-- Whether the click's modifier is held (NONE: always).
function ManaWarning.KeyHeld(scope)
    local key = setting(scope, "manaWarnClickKey")
    if key == "SHIFT" then return IsShiftKeyDown() == true end
    if key == "CTRL" then return IsControlKeyDown() == true end
    if key == "ALT" then return IsAltKeyDown() == true end
    return true
end

-- An item by its number reads as "item:<number>" (SecureCmdItemParse).
local function secureValue(kind, what)
    if kind == "ITEM" and what:match("^%d+$") then return "item:" .. what end
    return what
end

-- The secure button: the left click's type and value under the chosen
-- modifier only, over the block; shown while such a click is set. Out of
-- combat.
local function configureClick(frame)
    local mw, scope = frame.manaWarning, frame.key
    local click = mw.click
    for _, prefix in pairs(ManaWarning.PREFIX) do
        click:SetAttribute(prefix .. "type1", nil)
        for _, name in pairs(ManaWarning.SECURE) do click:SetAttribute(prefix .. name .. "1", nil) end
    end
    local kind = setting(scope, "manaWarnClick")
    local what = setting(scope, "manaWarnClickWhat"):match("^%s*(.-)%s*$")
    local on = enabled(scope) and ManaWarning.SECURE[kind] ~= nil and what ~= ""
    if on then
        local prefix = ManaWarning.PREFIX[setting(scope, "manaWarnClickKey")] or ""
        click:SetAttribute(prefix .. "type1", ManaWarning.SECURE_TYPE[kind])
        click:SetAttribute(prefix .. ManaWarning.SECURE[kind] .. "1", secureValue(kind, what))
        local w, h = ManaWarning.Size(scope)
        click:ClearAllPoints()
        click:SetSize(w, h)
        click:SetPoint("CENTER", UIParent, "CENTER", Pixel.Centre(setting(scope, "manaWarnX"), w),
            Pixel.Centre(setting(scope, "manaWarnY"), h))
        click:SetFrameStrata(mw.holder:GetFrameStrata())
        click:SetFrameLevel(mw.holder:GetFrameLevel() + 2)
    end
    click:SetShown(on)
end

-- Icon on the left, the text after it; either alone in the middle.
local function layout(frame)
    local mw, scope = frame.manaWarning, frame.key
    local size = Pixel.Snap(setting(scope, "manaWarnSize"))
    mw.icon:SetSize(size, size)
    local icon = setting(scope, "manaWarnIcon")
    mw.icon:SetTexture(icon ~= 0 and icon or ManaWarning.ICON)
    mw.icon:ClearAllPoints()
    mw.text:ClearAllPoints()
    mw.icon:SetShown(showsIcon(scope))
    mw.text:SetShown(showsText(scope))
    if showsIcon(scope) and showsText(scope) then
        mw.icon:SetPoint("LEFT", mw.holder, "LEFT", 0, 0)
        mw.text:SetPoint("LEFT", mw.icon, "RIGHT", 4, 0)
    else
        mw.icon:SetPoint("CENTER", mw.holder, "CENTER", 0, 0)
        mw.text:SetPoint("CENTER", mw.holder, "CENTER", 0, 0)
    end
    ns.Texts.SetFont(mw.text, ns.Media.Font(setting(scope, "fontFace")), setting(scope, "manaWarnFontSize"),
        setting(scope, "fontOutline"))
    local c = setting(scope, "manaWarnColor")
    mw.text:SetTextColor(c[1], c[2], c[3], c[4])
    mw.text:SetText(ns.L.MANA_WARN_TEXT)
end

-- Out of combat (the unit frames restyle there).
function ManaWarning.Style(frame)
    local mw = frame.manaWarning
    if not mw then return end
    local scope = frame.key
    place(frame)
    layout(frame)
    mw.holder:SetFrameLevel(frame:GetFrameLevel() + ns.Auras.LEVELS)
    mw.holder:EnableMouse(enabled(scope) and setting(scope, "manaWarnClick") == "CHAT")
    configureClick(frame)
    mw.curve = nil
    mw.styled = true
    ManaWarning.Update(frame)
end

-- Reading -----------------------------------------------------------------------------

-- Your mana in percent (a plain number), or nil when it is secret or you
-- have none.
function ManaWarning.Percent()
    local mana = Secrets.Number(UnitPower("player", ManaWarning.MANA))
    local max = Secrets.Number(UnitPowerMax("player", ManaWarning.MANA))
    if not mana or not max or max <= 0 then return nil end
    return mana / max * 100
end

local function hasMana()
    local max = UnitPowerMax("player", ManaWarning.MANA)
    if Secrets.IsSecret(max) then return true end
    return (Secrets.Number(max) or 0) > 0
end

local function inGroup() return IsInGroup() or IsInRaid() end
-- A secret or failed answer counts as in combat.
local function inCombat() return Secrets.Bool(UnitAffectingCombat, "player") ~= false end

-- The opacity for a secret share: 1 below the line, 0 at or above it.
local function secretAlpha(mw, scope)
    if not mw.curve then
        local below = setting(scope, "manaWarnBelow") / 100
        mw.curve = C_CurveUtil.CreateCurve()
        mw.curve:SetType(Enum.LuaCurveType.Step)
        mw.curve:AddPoint(0, 1)
        mw.curve:AddPoint(below, 0)
    end
    return UnitPowerPercent("player", ManaWarning.MANA, false, mw.curve)
end

-- Chat --------------------------------------------------------------------------------

local function channel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function locked()
    return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() == true
end

-- One line to the group's chat with your share; nothing alone, nothing
-- while the client forbids addons the chat, nothing with a secret share,
-- and not twice within CHAT_GAP (a click too, against double clicks).
function ManaWarning.Announce(frame)
    local mw = frame.manaWarning
    if not mw or mw.preview then return end
    local to = channel()
    local percent = ManaWarning.Percent()
    if not to or not percent or locked() then return end
    local now = GetTime()
    if mw.saidAt and now - mw.saidAt < ManaWarning.CHAT_GAP then return end
    mw.saidAt = now
    SendChatMessage(ns.L.MANA_WARN_CHAT:format(math.floor(percent + 0.5)), to)
end

-- Showing -----------------------------------------------------------------------------

-- An alpha animation from -> to on the block; it keeps its end opacity.
local function fadeGroup(holder, from, to)
    local g = holder:CreateAnimationGroup()
    g:SetToFinalAlpha(true)
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(from)
    a:SetToAlpha(to)
    g.alpha = a
    return g
end

-- In or out, faded over manaWarnFadeTime tenths of a second (manaWarnFade)
-- or at once (instant). Fading out hides the block when done; coming back
-- meanwhile stops that.
setShown = function(mw, scope, show, instant)
    local holder = mw.holder
    if show == mw.visible and not instant then return end
    mw.visible = show
    mw.fadeToken = (mw.fadeToken or 0) + 1
    mw.fadeIn = mw.fadeIn or fadeGroup(holder, 0, 1)
    mw.fadeOut = mw.fadeOut or fadeGroup(holder, 1, 0)
    mw.fadeIn:Stop()
    mw.fadeOut:Stop()
    local seconds = setting(scope, "manaWarnFadeTime") / 10
    if instant or setting(scope, "manaWarnFade") ~= true then
        holder:SetAlpha(1)
        holder:SetShown(show)
        return
    end
    if show then
        holder:SetAlpha(0)
        holder:Show()
        mw.fadeIn.alpha:SetDuration(seconds)
        mw.fadeIn:Play()
        return
    end
    if not holder:IsShown() then return end
    mw.fadeOut.alpha:SetDuration(seconds)
    mw.fadeOut:Play()
    local token = mw.fadeToken
    C_Timer.After(seconds, function()
        if mw.fadeToken ~= token then return end
        mw.fadeOut:Stop()
        holder:Hide()
        holder:SetAlpha(1)
    end)
end

function ManaWarning.Update(frame)
    local mw = frame.manaWarning
    if not (mw and mw.styled) then return end
    local scope = frame.key
    local on = enabled(scope) and hasMana()
        and (setting(scope, "manaWarnGroupOnly") ~= true or inGroup() or mw.preview)
        and (setting(scope, "manaWarnOutOfCombat") == true or inCombat() or mw.preview)
    local low, secret = false, false
    if on and mw.preview then
        low = true
    elseif on then
        local percent = ManaWarning.Percent()
        if percent then
            low = percent < setting(scope, "manaWarnBelow")
        elseif Secrets.IsSecret(UnitPower("player", ManaWarning.MANA)) then
            low, secret = true, true
        end
    end
    -- A secret share: shown all along, its opacity the curve's (no fade).
    setShown(mw, scope, low, secret)
    if secret then mw.holder:SetAlpha(secretAlpha(mw, scope)) end
    ns.Pulse.Set({ mw.icon, mw.text }, low and setting(scope, "manaWarnPulse") == true)
    -- Once each time it comes up.
    if low and not mw.low and not mw.preview and setting(scope, "manaWarnChat") == true then
        ManaWarning.Announce(frame)
    end
    mw.low = low
end

-- Test mode: shown as if low, no chat.
function ManaWarning.Preview(frame, on)
    local mw = frame.manaWarning
    if not mw then return end
    mw.preview = on or nil
    ManaWarning.Update(frame)
end

-- The handle: made with the frames, out of combat.
function ManaWarning.AttachMover(frame)
    local mw = frame.manaWarning
    if not mw then return end
    ns.Movers.Attach(mw.holder, ManaWarning.MoverSpec(frame))
    ns.AfterCombat("manaWarnStyle:" .. frame.key, function() ManaWarning.Style(frame) end)
end

-- Joining or leaving a group, entering or leaving combat: "only in a
-- group" and "in combat only" look again.
local function updatePlayer()
    local frame = ns.Frames and ns.Frames.player
    if frame then ManaWarning.Update(frame) end
end
ns.On("GROUP_ROSTER_UPDATE", updatePlayer)
ns.On("PLAYER_REGEN_DISABLED", updatePlayer)
ns.On("PLAYER_REGEN_ENABLED", updatePlayer)

ns.RegisterElement(ManaWarning)
