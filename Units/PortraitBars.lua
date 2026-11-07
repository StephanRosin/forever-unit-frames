local _, ns = ...

-- Side portraits and each row's width are independent. The portrait
-- occupies the largest contiguous run of rows that reserve room for it.
-- If no row reserves room, it moves immediately above the frame.
-- Nothing here changes secure frame geometry or game API values.
local PortraitBars = {}
ns.PortraitBars = PortraitBars

local Config, Pixel, Layout = ns.Config, ns.Pixel, ns.Layout
local avoidKey = {
    title = "portraitAvoidTitle",
    health = "portraitAvoidHealth",
    power = "portraitAvoidPower",
    footer = "portraitAvoidFooter",
}

local function move(region, frame, top, bottom, left, right)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
    region:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, -top)
    region:SetHeight(bottom - top)
end

local function portraitWindow(rows)
    local bestStart, bestLength = nil, 0
    local runStart, runLength
    for _, row in ipairs(rows) do
        if row.avoid and row.height > 0 then
            if not runStart then runStart, runLength = row.top, 0 end
            runLength = runLength + row.height
        else
            if runStart and runLength > bestLength then
                bestStart, bestLength = runStart, runLength
            end
            runStart, runLength = nil, nil
        end
    end
    if runStart and runLength > bestLength then
        bestStart, bestLength = runStart, runLength
    end
    return bestStart, bestLength
end

local function apply(frame, refreshStyle)
    local scope = frame.key
    local mode = Config.Get(scope, "portraitMode")
    if mode ~= "LEFT" and mode ~= "RIGHT" then return end
    local w = ns.Single.LayoutSize(frame)
    -- SquishCastbar owns the vertical geometry. Without its placement,
    -- use the original bar positions and sizes unchanged.
    local geometry = frame.squishRows
    local titleH = geometry and geometry.title.height or (frame.titleHeight or 0)
    local healthH = geometry and geometry.health.height or frame.health:GetHeight()
    local powerH = geometry and geometry.power.height
        or (frame.power and frame.power:IsShown() and frame.power:GetHeight() or 0)
    local strip = frame.portraitStrip or 0
    local footerH = geometry and geometry.footer.height or (frame.footerHeight or 0)
    local healthTop = geometry and geometry.health.top or titleH + strip
    local powerTop = geometry and geometry.power.top or healthTop + healthH
    local xpH = (frame.xpRep and frame.xpRep:IsShown()) and frame.xpRep:GetHeight() or 0
    local xpTop = powerTop + powerH
    local comboH = (frame.comboBar and frame.comboBar:IsShown()) and frame.comboBar:GetHeight() or 0
    local comboTop = xpTop + xpH
    local footerTop = geometry and geometry.footer.top or comboTop + comboH
    local rows
    if geometry then
        rows = {}
        for _, row in ipairs(geometry.order) do
            if row.height > 0 then
                local key = avoidKey[row.name]
                if row.name == "cast" then key = "portraitAvoidCastbar" end
                if not key then key = row.avoidKey end
                rows[#rows + 1] = { top = row.top, height = row.height,
                    avoid = key and Config.Get(scope, key) or false }
            end
        end
    else
        rows = {
            { top = 0, height = titleH, avoid = Config.Get(scope, avoidKey.title) },
            { top = healthTop, height = healthH, avoid = Config.Get(scope, avoidKey.health) },
            { top = powerTop, height = powerH, avoid = Config.Get(scope, avoidKey.power) },
            { top = xpTop, height = xpH, avoid = xpH > 0 and Config.Get(scope, "portraitAvoidXPRep") },
            { top = comboTop, height = comboH, avoid = comboH > 0 and Config.Get(scope, "portraitAvoidComboBar") },
            { top = footerTop, height = footerH, avoid = Config.Get(scope, avoidKey.footer) },
        }
    end
    local start, size = portraitWindow(rows)
    local outside = start == nil
    if outside then
        size = frame.layoutHeight or healthH
        start = -size
    end
    -- A one-pixel-wide status bar must remain possible even if the frame
    -- has been configured narrower than the portrait's desired square.
    local one = Pixel.One and Pixel.One() or Pixel.Snap(1, nil, 1)
    size = math.max(one, math.min(size, w - one))
    frame.portraitAwareSize, frame.portraitAwareTop = size, start
    frame.portraitAwareOutside = outside

    local function insets(name)
        if not Config.Get(scope, avoidKey[name]) then return 0, 0 end
        if mode == "LEFT" then return size, 0 end
        return 0, size
    end
    local l, r = insets("title")
    local title = frame.title
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", l, 0)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -r, 0)
    if geometry then title:SetHeight(math.max(one, titleH)) end
    frame.titleLeft, frame.titleRight = l, r
    frame.titleWidth = w - l - r

    l, r = insets("health")
    local available = math.max(one, w - l - r)
    local lane = 0
    if Config.Get(scope, "healPrediction") and Config.Get(scope, "healOverflow") then
        lane = math.min(available - one, Pixel.Snap(Layout.OverhealLane(available)))
        lane = math.max(0, lane)
    end
    frame.overhealLane = lane
    frame.healthWidth = available - lane
    move(frame.health, frame, healthTop, healthTop + healthH, l, r + lane)

    if frame.power then
        l, r = insets("power")
        local powerLane = Config.Get(scope, "powerMatchesHealth") and lane or 0
        frame.power:ClearAllPoints()
        if (geometry or xpH > 0 or comboH > 0) and powerH > 0 then
            frame.power:SetPoint("TOPLEFT", frame, "TOPLEFT", l, -powerTop)
            frame.power:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(r + powerLane), -powerTop)
            frame.power:SetHeight(powerH)
        else
            frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", l, footerH)
            frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(r + powerLane), footerH)
        end
        frame.powerWidth = w - l - r - powerLane
    end

    if not geometry and frame.xpRep and xpH > 0 then
        local el = frame.xpRep
        local inLeft, inRight = 0, 0
        if Config.Get(scope, "portraitAvoidXPRep") then
            if mode == "LEFT" then inLeft = size else inRight = size end
        end
        move(el, frame, xpTop, xpTop + xpH, inLeft, inRight)
    end

    if not geometry and frame.comboBar and comboH > 0 then
        local leftCombo, rightCombo = 0, 0
        if Config.Get(scope, "portraitAvoidComboBar") then
            if mode == "LEFT" then leftCombo = size else rightCombo = size end
        end
        move(frame.comboBar, frame, comboTop, comboTop + comboH, leftCombo, rightCombo)
        if ns.ComboBar then ns.ComboBar.Reflow(frame) end
    end

    l, r = insets("footer")
    frame.footer:ClearAllPoints()
    if geometry and footerH > 0 then
        frame.footer:SetPoint("TOPLEFT", frame, "TOPLEFT", l, -footerTop)
        frame.footer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -r, -footerTop)
        frame.footer:SetHeight(footerH)
    else
        frame.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", l, 0)
        frame.footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -r, 0)
    end
    frame.footerWidth = w - l - r
    if geometry then
        for _, extra in ipairs(geometry.extra) do
            local el = extra.widget
            if el and extra.height > 0 then
                local inLeft, inRight = 0, 0
                if extra.avoidKey and Config.Get(scope, extra.avoidKey) then
                    if mode == "LEFT" then inLeft = size else inRight = size end
                end
                move(el, frame, extra.top, extra.top + extra.height, inLeft, inRight)
                if extra.name == "combo" and ns.ComboBar then ns.ComboBar.Reflow(frame) end
            end
        end
    end

    local bg = frame.portraitBg
    if bg then
        bg:ClearAllPoints()
        local point = mode == "LEFT" and "TOPLEFT" or "TOPRIGHT"
        bg:SetPoint(point, frame, point, 0, -start)
        bg:SetSize(size, size)
        -- When every bar is full-width, the portrait sits above the frame;
        -- its original frame-shaped mask must not cut it away.
        local clip = frame.clip and frame.clip.mask
        if clip and ns.Corners then
            ns.Corners.SetMasked(bg, clip, not outside)
            ns.Corners.SetMasked(frame.portrait2D, clip, not outside)
        end
    end

    -- The druid's thin mana strip is an independent bar. Keep its Y position
    -- aligned to power, but let its width reserve or ignore the portrait.
    if frame.druidMana and Config.Get(scope, "druidManaLayout") == "STRIP" then
        -- An explicit independent choice must work even if the power row
        -- has the opposite setting.
        if Config.Get(scope, "portraitAvoidDruidMana") then
            l, r = mode == "LEFT" and size or 0, mode == "RIGHT" and size or 0
        else
            l, r = 0, 0
        end
        local powerLane = Config.Get(scope, "powerMatchesHealth") and lane or 0
        local bar = frame.druidMana
        bar:ClearAllPoints()
        local manaHeight = Pixel.Snap(Config.Get(scope, "druidManaHeight"), nil, 1)
        manaHeight = geometry and math.min(manaHeight, powerH) or manaHeight
        bar:SetHeight(math.max(one, manaHeight))
        if (geometry or xpH > 0 or comboH > 0) and powerH > 0 then
            local top = powerTop + powerH - bar:GetHeight()
            bar:SetPoint("TOPLEFT", frame, "TOPLEFT", l, -top)
            bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(r + powerLane), -top)
        else
            bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", l, footerH)
            bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(r + powerLane), footerH)
        end
    end
    if frame.druidMana and ns.DruidMana then ns.DruidMana.Layout(frame, true) end
    if refreshStyle then
        -- These elements cache the health bar's width and the title end
        -- geometry. All other status bar textures follow their bars.
        if ns.HealPrediction then ns.HealPrediction.Style(frame) end
        if ns.Texts then ns.Texts.Style(frame) end
    end
end

PortraitBars.Apply = apply

-- StyleContent calls every element's Style once, then the portrait-aware
-- geometry is adjusted; only the two width-caching elements are restyled.
-- The original full styling path is preserved for all settings and bars.
local normalStyle = ns.Single.StyleContent
ns.Single.StyleContent = function(frame)
    normalStyle(frame)
    apply(frame, true)
end

-- Power.IsEmpty can change the health/power split mid-combat. Single's
-- exported layout function is the only entrypoint for that layout-only
-- refresh, so the portrait and row widths follow immediately as well.
local normalLayoutBars = ns.Single.LayoutBars
ns.Single.LayoutBars = function(frame)
    normalLayoutBars(frame)
    apply(frame, true)
end
