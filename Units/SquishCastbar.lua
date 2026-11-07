local _, ns = ...

-- SQUISH placement: while a cast is active, reserve a bottom cast row.
-- Only health and the main power row shrink, maintaining their original
-- height ratio (rounded to physical pixels). Title, footer, and future
-- XP/reputation and combo-point rows keep their original heights.
-- The secure parent frame does not move or resize, including in combat.
local Squish = {}
ns.SquishCastbar = Squish

local Config, Pixel, Castbar = ns.Config, ns.Pixel, ns.Castbar
local suppress = 0

local function enabled(scope)
    return Config.Get(scope, "castbarEnabled") and Castbar.Placement(scope) == "SQUISH"
end

local function pixel() return Pixel.One() end
local function toPixels(size)
    return math.max(0, math.floor((size or 0) / pixel() + 0.5))
end

-- Plain numeric layout calculation; no unit or spell data is read here.
-- Returns heights in real UI units in order: health, power, castbar.
function Squish.Allocate(healthHeight, powerHeight, castHeight)
    local health, power = toPixels(healthHeight), toPixels(powerHeight)
    local total = health + power
    local minHealth = health > 0 and 1 or 0
    local minPower = power > 0 and 1 or 0
    local capacity = math.max(0, total - minHealth - minPower)
    local cast = math.max(0, math.min(toPixels(castHeight), capacity))
    local remaining = total - cast
    local newHealth, newPower = 0, 0
    if health == 0 then
        newPower = remaining
    elseif power == 0 then
        newHealth = remaining
    else
        -- One common scale factor, then assign the rounding remainder to
        -- power so health+power+cast is exactly the original total.
        newHealth = math.floor(remaining * health / total + 0.5)
        newHealth = math.max(1, math.min(newHealth, remaining - 1))
        newPower = remaining - newHealth
    end
    return newHealth * pixel(), newPower * pixel(), cast * pixel()
end

-- Registered by future optional bar elements. These rows occupy their
-- normal heights between power and castbar and never participate in
-- Squish.Allocate. They still need to be allocated space in Single's
-- baseline layout when those features are implemented.
local extraPriority = { xp = 1, reputation = 1, combo = 2 }
function Squish.RegisterExtraRow(frame, name, widget, avoidKey)
    frame.squishExtraRows = frame.squishExtraRows or {}
    for _, row in ipairs(frame.squishExtraRows) do
        if row.name == name then
            row.widget, row.avoidKey = widget, avoidKey
            return
        end
    end
    frame.squishExtraRows[#frame.squishExtraRows + 1] = {
        name = name, widget = widget, avoidKey = avoidKey,
    }
    table.sort(frame.squishExtraRows, function(a, b)
        return (extraPriority[a.name] or 10) < (extraPriority[b.name] or 10)
    end)
end

-- Capture a fresh unsquished baseline. Never reuse already-shrunk sizes.
local function capture(frame)
    local rows = {
        { name = "title", height = frame.titleHeight or 0, widget = frame.title },
        { name = "health", height = frame.health:GetHeight(), widget = frame.health },
        { name = "power", height = frame.power and frame.power:IsShown() and frame.power:GetHeight() or 0,
            widget = frame.power },
    }
    for _, extra in ipairs(frame.squishExtraRows or {}) do
        if extra.widget and extra.widget:IsShown() then
            rows[#rows + 1] = { name = extra.name, height = extra.widget:GetHeight(),
                widget = extra.widget, avoidKey = extra.avoidKey }
        end
    end
    rows[#rows + 1] = { name = "footer", height = frame.footerHeight or 0, widget = frame.footer }
    frame.squishBaseRows = rows
end

local function isCasting(frame)
    local bar = frame.castbar
    return enabled(frame.key) and bar and (bar.cast ~= nil or bar.preview == true)
end

-- Build the vertical stack, preserving all heights except health+power.
-- In the side portrait case this is also a shared geometry plan used by
-- PortraitBars.Apply to calculate its portrait window and left/right insets.
local function geometry(frame, casting)
    local rows = frame.squishBaseRows
    local hp, pp
    for _, row in ipairs(rows) do
        if row.name == "health" then hp = row.height end
        if row.name == "power" then pp = row.height end
    end
    local requested = casting and Pixel.Snap(Config.Get(frame.key, "castbarHeight")) or 0
    local newH, newP, castHeight = Squish.Allocate(hp or 0, pp or 0, requested)
    local plan = { order = {}, extra = {} }
    local top, strip = 0, frame.portraitStrip or 0
    for _, row in ipairs(rows) do
        local height = row.height
        if row.name == "health" then height = newH end
        if row.name == "power" then height = newP end
        local entry = { name = row.name, widget = row.widget, top = top, height = height,
            avoidKey = row.avoidKey }
        plan.order[#plan.order + 1] = entry
        plan[row.name] = entry
        if row.name ~= "title" and row.name ~= "health" and row.name ~= "power"
            and row.name ~= "footer" then plan.extra[#plan.extra + 1] = entry end
        top = top + height
        if row.name == "title" then top = top + strip end
    end
    plan.cast = { name = "cast", top = top, height = castHeight }
    if castHeight > 0 then plan.order[#plan.order + 1] = plan.cast end
    return plan
end

local function place(region, frame, row, left, right)
    if not region or not row or row.height <= 0 then return end
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", frame, "TOPLEFT", left or 0, -row.top)
    region:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(right or 0), -row.top)
    region:SetHeight(row.height)
end

local function fitCastbar(frame, castHeight)
    local bar, scope = frame.castbar, frame.key
    local width = ns.Single.LayoutSize(frame)
    local mode = Config.Get(scope, "portraitMode")
    local size = frame.portraitAwareSize or (frame.layoutHeight or 0)
    local left, right = 0, 0
    if Config.Get(scope, "portraitAvoidCastbar") then
        if mode == "LEFT" then left = size elseif mode == "RIGHT" then right = size end
    end
    -- The icon belongs to the castbar row, not outside the unit frame.
    local drawHeight = math.max(pixel(), castHeight)
    local showIcon = Config.Get(scope, "castbarIcon")
    local fits = showIcon and width - left - right >= drawHeight + 5
    local inset = fits and drawHeight or 0
    local castTop = frame.squishRows.cast.top
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", left + inset, -castTop)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, -castTop)
    bar:SetHeight(drawHeight)
    bar.icon:SetSize(drawHeight, drawHeight)
    bar.icon:SetShown(fits)
    bar.iconBg:SetShown(fits)
    bar.box:ClearAllPoints()
    bar.box:SetPoint("TOPLEFT", bar, "TOPLEFT", -inset, 0)
    bar.box:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    local fontSize = math.max(6, math.min(Config.Get(scope, "fontSize"), drawHeight))
    local font = ns.Media.Font(Config.Get(scope, "fontFace"))
    local outline = Config.Get(scope, "fontOutline")
    for _, text in ipairs({ bar.text, bar.time }) do ns.Texts.SetFont(text, font, fontSize, outline) end
end

function Squish.Apply(frame, force)
    local bar = frame and frame.castbar
    if not bar then return end
    if not frame.squishBaseRows then capture(frame) end
    if not enabled(frame.key) then
        frame.squishRows, frame.squishActive, frame.squishHeight = nil, false, nil
        if ns.DruidMana then ns.DruidMana.Layout(frame, true) end
        return
    end
    local casting = isCasting(frame) and true or false
    local plan = geometry(frame, casting)
    local castHeight = plan.cast.height
    if not force and frame.squishActive == casting and frame.squishHeight == castHeight then
        -- Castbar.Stop may temporarily show the idle bar for Always Show;
        -- Squish must undo that even if no row geometry changed.
        if not casting and bar:IsShown() then bar:Hide() end
        return
    end
    frame.squishRows, frame.squishActive, frame.squishHeight = plan, casting, castHeight
    frame.titleHeight = plan.title.height
    frame.footerHeight = plan.footer.height
    local mode = Config.Get(frame.key, "portraitMode")
    if mode == "LEFT" or mode == "RIGHT" then
        ns.PortraitBars.Apply(frame, true)
    else
        place(frame.title, frame, plan.title)
        place(frame.health, frame, plan.health, 0, frame.overhealLane or 0)
        place(frame.power, frame, plan.power)
        for _, row in ipairs(plan.extra) do place(row.widget, frame, row) end
        if ns.ComboBar then ns.ComboBar.Reflow(frame) end
        place(frame.footer, frame, plan.footer)
        if mode == "TOP" and ns.Portrait then ns.Portrait.Style(frame) end
        ns.HealPrediction.Style(frame)
        ns.Texts.Style(frame)
    end
    -- Split Energy/Rage + Mana only *horizontally* within the final power
    -- row. Side portraits have already applied their own full-row insets.
    if mode ~= "LEFT" and mode ~= "RIGHT" and ns.DruidMana then
        ns.DruidMana.Layout(frame, true)
    end
    fitCastbar(frame, castHeight)
    -- Always-show is ignored in Squish mode: idle borrows no height.
    bar:SetShown(casting and castHeight > 0)
end

-- Wrap the existing portrait-aware style and layout paths. Full styling
-- always captures a fresh baseline. Power-hide changes recompute it from
-- the original Single.LayoutBars, even when a cast is in progress.
local style = ns.Single.StyleContent
ns.Single.StyleContent = function(frame)
    suppress = suppress + 1
    frame.squishRows, frame.squishBaseRows = nil, nil
    frame.squishActive, frame.squishHeight = false, nil
    style(frame)
    suppress = suppress - 1
    if ns.XPRepBar then ns.XPRepBar.Layout(frame) end
    if ns.ComboBar then ns.ComboBar.Layout(frame) end
    capture(frame)
    Squish.Apply(frame, true)
end

local layout = ns.Single.LayoutBars
ns.Single.LayoutBars = function(frame)
    frame.squishRows, frame.squishBaseRows = nil, nil
    frame.squishActive, frame.squishHeight = false, nil
    layout(frame)
    if ns.XPRepBar then ns.XPRepBar.Layout(frame) end
    if ns.ComboBar then ns.ComboBar.Layout(frame) end
    capture(frame)
    if suppress == 0 then Squish.Apply(frame, true) end
end

local begin = Castbar.Begin
Castbar.Begin = function(bar, ...)
    local result = begin(bar, ...)
    if suppress == 0 then Squish.Apply(bar:GetParent()) end
    return result
end

local stop = Castbar.Stop
Castbar.Stop = function(bar, ...)
    local result = stop(bar, ...)
    if suppress == 0 then Squish.Apply(bar:GetParent()) end
    return result
end

local preview = Castbar.Preview
Castbar.Preview = function(frame, ...)
    local result = preview(frame, ...)
    if suppress == 0 then Squish.Apply(frame) end
    return result
end

local castStyle = Castbar.Style
Castbar.Style = function(frame, ...)
    suppress = suppress + 1
    local result = castStyle(frame, ...)
    suppress = suppress - 1
    if suppress == 0 and frame.squishBaseRows then Squish.Apply(frame, true) end
    return result
end
