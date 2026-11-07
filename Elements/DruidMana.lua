local _, ns = ...

-- Druid mana in Cat/Bear Form. Split mode places an independently filled
-- mana bar beside the primary Energy/Rage bar INSIDE the existing power
-- row (never beside XP or reputation). Strip mode preserves the older thin
-- secondary bar. No secure unit button is resized/reparented in combat.
local DruidMana = { name = "DruidMana", unitEvents = { "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" } }
ns.DruidMana = DruidMana
local Config, Pixel, Secrets = ns.Config, ns.Pixel, ns.Secrets
local SCOPE = "player"
local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local GAP_PIXELS = 1
DruidMana.SAMPLE = 0.6

local function get(key) return Config.Get(SCOPE, key) end
local function druid()
    local ok, _, token = pcall(UnitClass, "player")
    return ok and not Secrets.IsSecret(token) and token == "DRUID"
end
local function wanted(frame)
    return get("druidMana") and get("powerEnabled") and frame.power:IsShown() and druid()
end
local function inForm(frame)
    local kind = Secrets.Number(UnitPowerType("player"))
    return wanted(frame) and (frame.druidMana.preview or (kind ~= nil and kind ~= MANA))
end
local function splitMode() return get("druidManaLayout") == "SPLIT" end

-- Remember the unsplit power row geometry. Every layout owner (Single,
-- PortraitBars, SquishCastbar) establishes a full-width power row before
-- calling Layout(frame, true). A power-type change calls Layout(false),
-- reusing this record rather than treating a 65% split as the full width.
local function record(frame)
    local bar = frame.druidMana
    local a, af, ar, ax, ay = frame.power:GetPoint(1)
    local b, bf, br, bx, by = frame.power:GetPoint(2)
    if not a or not b then return false end
    -- Other row layout modules may have just restored BOTH full-width
    -- anchors without resetting frame.powerWidth (still the last split's
    -- width). Read the anchors against the outer frame instead, avoiding
    -- compounding width loss on XP/combo/squish relayouts.
    local width
    if af == frame and bf == frame then
        local outer = ns.Single and ns.Single.LayoutSize and ns.Single.LayoutSize(frame)
            or frame:GetWidth()
        width = outer - (ax or 0) + (bx or 0)
    else
        width = frame.power:GetWidth()
    end
    if not width or width <= 0 then return false end
    bar.base = { a, af, ar, ax, ay, b, bf, br, bx, by,
        width = width, height = frame.power:GetHeight() }
    return true
end

-- Given a full power-row width, find two pixel-grid widths. Primary and
-- mana always add up to that width minus one separator pixel.
function DruidMana.Widths(total, percent, gap)
    local one = Pixel.One()
    local pixels = math.max(2, math.floor(total / one + 0.5))
    local sep = pixels >= 4 and (gap or GAP_PIXELS) or 0
    local available = pixels - sep
    local mana = math.floor(available * percent / 100 + 0.5)
    mana = math.max(1, math.min(available - 1, mana))
    return (available - mana) * one, mana * one, sep * one
end

function DruidMana.Build(frame)
    if frame.key ~= SCOPE or not frame.power then return end
    -- Keep the secondary bar outside the primary's status-bar children:
    -- it is a full-height neighbour in split mode, not a primary overlay.
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.text:SetJustifyH("CENTER")
    bar.text:SetWordWrap(false)
    bar:EnableMouse(false) -- preserve clicks on the secure unit button
    bar:Hide()
    frame.druidMana = bar
    ns.Corners.Add(frame, bar.bg)
    ns.Corners.Add(frame, function() return bar:GetStatusBarTexture() end)
end

local function restorePower(frame, base)
    local power = frame.power
    power:ClearAllPoints()
    power:SetPoint(base[1], base[2], base[3], base[4], base[5])
    power:SetPoint(base[6], base[7], base[8], base[9], base[10])
    power:SetHeight(base.height)
    frame.powerWidth = base.width
end

local function styleText(frame)
    local bar = frame.druidMana
    local font = ns.Media.Font(get("fontFace"))
    local available = bar:GetHeight()
    local size = math.max(7, math.min(get("fontSize"), available - 2))
    if get("druidManaText") == "CURRENT_MAX" then
        -- The narrowest 20% split may not fit two values at full font size.
        -- Limit only the local mana label, not the other resource text.
        local width = bar.spanWidth or bar:GetWidth()
        size = math.min(size, math.max(7, math.floor(width / 8)))
    end
    local outline = get("fontOutline")
    ns.Texts.SetFont(bar.text, font, size, outline)
    bar.text:SetWidth(math.max(Pixel.One(), (bar.spanWidth or bar:GetWidth()) - Pixel.Snap(3)))
    bar.text:SetShown(bar.isSplit and available >= 8)
end

-- Reposition the secondary bar, and restore or shrink only the *width* of
-- the main power status bar. Never change its height: that is allocated by
-- the existing health/power/XP/combo/castbar geometry.
function DruidMana.Layout(frame, fresh)
    local bar = frame and frame.druidMana
    if not bar then return end
    if fresh and not record(frame) then return end
    local base = bar.base
    if not base then return end
    local split = inForm(frame) and splitMode()
    local changed = bar.isSplit ~= split
    -- A cached layout may already contain the side-by-side anchors. Only
    -- restore from the saved unsplit geometry, never from current width.
    restorePower(frame, base)
    bar.isSplit = split
    if split then
        local main, mana, gap = DruidMana.Widths(base.width, get("druidManaWidth"))
        local rightX = base[9]
        frame.power:ClearAllPoints()
        frame.power:SetPoint(base[1], base[2], base[3], base[4], base[5])
        frame.power:SetPoint(base[6], base[7], base[8], rightX - mana - gap, base[10])
        frame.power:SetHeight(base.height)
        bar:ClearAllPoints()
        bar:SetPoint(base[1], base[2], base[3], base[4] + main + gap, base[5])
        bar:SetPoint(base[6], base[7], base[8], rightX, base[10])
        bar:SetHeight(base.height)
        frame.powerWidth = main
        bar.spanWidth = mana
        bar:SetShown(true)
    elseif inForm(frame) then
        -- Legacy strip: PortraitBars owns its independent side-portrait
        -- anchors. Otherwise keep it at the bottom of the full power row.
        local side = get("portraitMode") == "LEFT" or get("portraitMode") == "RIGHT"
        if not side then
            bar:ClearAllPoints()
            bar:SetPoint("BOTTOMLEFT", frame.power, "BOTTOMLEFT", 0, 0)
            bar:SetPoint("BOTTOMRIGHT", frame.power, "BOTTOMRIGHT", 0, 0)
        end
        bar:SetHeight(math.min(base.height, Pixel.Snap(get("druidManaHeight"), nil, 1)))
        bar:SetShown(true)
    else
        bar:Hide()
    end
    local c = get("powerColorMana")
    bar:SetStatusBarColor(c[1], c[2], c[3])
    bar.text:SetShown(split and base.height >= 8)
    if split then styleText(frame) end
    -- Text placements, cost prediction and FSR use frame.powerWidth.
    -- Update them after a genuine split/unsplit transition, not on every
    -- mana tick. When a full relayout is in progress, final styling runs
    -- afterward and handles these as well.
    if changed or fresh then
        if ns.Texts then ns.Texts.Style(frame) end
        if ns.PowerCost and frame.powerCost then ns.PowerCost.Style(frame) end
        if ns.FiveSecondRule and frame.fsr then ns.FiveSecondRule.Style(frame) end
    end
end

function DruidMana.Style(frame)
    local bar = frame.druidMana
    if not bar then return end
    local texture = ns.Media.StatusBar(get("barTexture"))
    bar:SetStatusBarTexture(texture)
    bar.bg:SetTexture(texture)
    local c = get("backgroundColor")
    bar.bg:SetVertexColor(c[1], c[2], c[3], c[4])
    bar:SetFrameLevel(frame.power:GetFrameLevel() + 2)
    DruidMana.Layout(frame, true)
    if bar.preview then DruidMana.Preview(frame, true) else DruidMana.Update(frame) end
end

function DruidMana.Update(frame)
    local bar = frame.druidMana
    if not bar or bar.preview then return end
    local show = inForm(frame)
    -- Form transitions change which bar gets the width. Out of form,
    -- primary mana automatically reclaims the entire power row.
    if bar.isSplit ~= (show and splitMode()) then DruidMana.Layout(frame, false) end
    if not show then bar:Hide(); return end
    bar:SetMinMaxValues(0, UnitPowerMax("player", MANA))
    local amount = UnitPower("player", MANA)
    bar:SetValue(amount)
    if bar.isSplit then
        -- Spell resources can be secret during combat. Hand raw values to
        -- FontString:SetFormattedText instead of doing Lua arithmetic on
        -- them; percent comes directly from the dedicated client API.
        local mode = get("druidManaText")
        if mode == "CURRENT_MAX" then
            bar.text:SetFormattedText("%s/%s", Secrets.Abbreviate(amount),
                Secrets.Abbreviate(UnitPowerMax("player", MANA)))
        elseif mode == "PERCENT" then
            local ok, percent = pcall(UnitPowerPercent, "player", MANA, false, Secrets.PercentCurve())
            if ok then
                bar.text:SetFormattedText("%.0f%%", percent)
            else
                -- If the client lacks this API, use only plain, nonsecret
                -- quantities; never try to divide protected combat data.
                local current = Secrets.Number(amount)
                local maximum = Secrets.Number(UnitPowerMax("player", MANA))
                if current and maximum and maximum > 0 then
                    bar.text:SetFormattedText("%.0f%%", current / maximum * 100)
                else
                    bar.text:SetText("")
                end
            end
        else
            bar.text:SetFormattedText("%s", Secrets.Abbreviate(amount))
        end
    end
    bar:Show()
end

function DruidMana.Preview(frame, on)
    local bar = frame.druidMana
    if not bar then return end
    bar.preview = on or nil
    if not on then
        DruidMana.Layout(frame, false)
        return DruidMana.Update(frame)
    end
    -- Preview the split even if the test was opened in caster form.
    if not wanted(frame) then return bar:Hide() end
    DruidMana.Layout(frame, false)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(DruidMana.SAMPLE)
    if bar.isSplit then
        local mode = get("druidManaText")
        if mode == "CURRENT_MAX" then
            bar.text:SetText("2.4k/4k")
        elseif mode == "PERCENT" then
            bar.text:SetText("60%")
        else
            bar.text:SetText("2.4k")
        end
    end
    bar:Show()
end

ns.RegisterElement(DruidMana)
