local _, ns = ...

-- SUF-style combo-point segments in the PLAYER frame, below XP/rep and
-- above the castbar. Separate from the original target-frame combo pips.
-- The row remains fixed-height during casts, but can relinquish its
-- entire height at zero points when Hide at zero is enabled.
-- GetComboPoints can return a secret: pass that value directly to status
-- bars, never compare it in Lua unless Secrets.Number says it is readable.
local ComboBar = { name = "ComboBar", unitEvents = { "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER" } }
ns.ComboBar = ComboBar
local Config, Pixel, Secrets = ns.Config, ns.Pixel, ns.Secrets
local SCOPE = "player"
local POWER_COMBO = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
local POOL, FALLBACK_MAX = 10, 5

local function get(key) return Config.Get(SCOPE, key) end

function ComboBar.Max()
    local ok, maximum = pcall(UnitPowerMax, "player", POWER_COMBO)
    local max = ok and Secrets.Number(maximum) or nil
    if not max or max <= 0 then max = FALLBACK_MAX end
    return math.max(1, math.min(POOL, math.floor(max)))
end

function ComboBar.Build(frame)
    if frame.key ~= SCOPE then return end
    local holder = CreateFrame("Frame", nil, frame)
    holder:EnableMouse(true)
    local segments = {}
    for i = 1, POOL do
        local bar = CreateFrame("StatusBar", nil, holder)
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(bar)
        bar.bg = bg
        bar:SetMinMaxValues(i - 1, i)
        bar:SetValue(0)
        segments[i] = bar
        -- Keep the bar's background and fill within the unit border.
        ns.Corners.Add(frame, bg)
        ns.Corners.Add(frame, function() return bar:GetStatusBarTexture() end)
    end
    frame.comboBar = holder
    holder.segments = segments
    holder.count = 0
    holder:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine("Combo points")
        if self.readablePoints then
            GameTooltip:AddDoubleLine("Current", ("%d / %d"):format(self.readablePoints, self.count))
        else
            GameTooltip:AddLine("Current target")
        end
        GameTooltip:Show()
    end)
    holder:SetScript("OnLeave", function() if GameTooltip:IsOwned(holder) then GameTooltip:Hide() end end)
    holder:Hide()
    ns.SquishCastbar.RegisterExtraRow(frame, "combo", holder, "portraitAvoidComboBar")
end

local function styleSegments(holder)
    local n = ComboBar.Max()
    local spacing = Pixel.Snap(get("comboBarSpacing"))
    local tex = ns.Media.StatusBar(get("barTexture"))
    local c = get("comboBarColor")
    local background = get("backgroundColor")
    local gap = math.max(0, (n - 1) * spacing)
    local reverse = get("comboBarGrowth") == "LEFT"
    holder.count = n
    holder.spacing = spacing
    holder.reverse = reverse
    -- The icons' WIDTH is computed from the actual holder width on size
    -- changes (portrait, Edit Mode, UI scale, layout). We avoid a high
    -- frequency OnUpdate: only size/layout changes need to reflow.
    local width = holder:GetWidth()
    if width <= 0 then width = 1 end
    local segmentWidth = math.max(Pixel.One(), (width - gap) / n)
    for i, bar in ipairs(holder.segments) do
        bar:SetShown(i <= n)
        if i <= n then
            bar:SetStatusBarTexture(tex)
            bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
            bar.bg:SetTexture(tex)
            bar.bg:SetVertexColor(background[1], background[2], background[3],
                get("comboBarBackground") and background[4] or 0)
            bar:ClearAllPoints()
            local edge = reverse and "TOPRIGHT" or "TOPLEFT"
            local x = (i - 1) * (segmentWidth + spacing)
            bar:SetPoint(edge, holder, edge, reverse and -x or x, 0)
            bar:SetSize(segmentWidth, holder:GetHeight())
        end
    end
end

function ComboBar.Reflow(frame)
    local holder = frame and frame.comboBar
    if not holder or not holder:IsShown() then return end
    styleSegments(holder)
end

-- A change in *row visibility* must rebuild the baseline, not merely
-- repaint the segments: XP/rep is allocated first, then combo, and only
-- afterward is a temporary squish castbar allowed to consume health/power.
-- LayoutBars starts from the full unsquished split, so no rounding/height
-- is accumulated over repeated gain/spend cycles. It is already the path
-- used when the power bar appears or disappears in combat.
local function setRowVisible(frame, visible)
    local holder = frame.comboBar
    if holder:IsShown() == visible then return end
    holder:SetShown(visible)
    -- During StyleContent the squish wrapper has cleared its baseline and
    -- will allocate every enabled row itself when the style pass finishes.
    if frame.squishBaseRows and ns.Single and ns.Single.LayoutBars then
        ns.Single.LayoutBars(frame)
    end
end

function ComboBar.Style(frame)
    local holder = frame.comboBar
    if not holder then return end
    -- The style pass resets the baseline. Update below can hide this row
    -- before any height is allocated, with no re-entrant layout call.
    holder:SetShown(get("comboBarEnabled"))
    if not holder:IsShown() then return end
    holder:SetFrameLevel(frame.power:GetFrameLevel() + 1)
    holder:SetHeight(Pixel.Snap(get("comboBarHeight"), nil, 1))
    styleSegments(holder)
    if holder.preview then ComboBar.Preview(frame, true) else ComboBar.Update(frame) end
end

-- Reserve space for combo after XP/rep reserved its own space. Both rows
-- are fixed in the eventual squish geometry, never drawn out of health
-- and power at every cast event. The original parent height is unchanged.
function ComboBar.Layout(frame)
    local holder = frame.comboBar
    if not holder or not holder:IsShown() then return end
    local health, power = frame.health:GetHeight(),
        frame.power and frame.power:IsShown() and frame.power:GetHeight() or 0
    local newH, newP, size = ns.SquishCastbar.Allocate(health, power,
        Pixel.Snap(get("comboBarHeight"), nil, 1))
    if size <= 0 then holder:Hide(); return end
    frame.health:SetHeight(newH)
    local top = (frame.titleHeight or 0) + (frame.portraitStrip or 0)
    if frame.power and newP > 0 then
        frame.power:ClearAllPoints()
        frame.power:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(top + newH))
        local lane = get("powerMatchesHealth") and (frame.overhealLane or 0) or 0
        frame.power:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -lane, -(top + newH))
        frame.power:SetHeight(newP)
    end
    local footer = frame.footerHeight or 0
    holder:ClearAllPoints()
    holder:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, footer)
    holder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, footer)
    holder:SetHeight(size)
    if frame.xpRep and frame.xpRep:IsShown() then
        local xp = frame.xpRep
        xp:ClearAllPoints()
        xp:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, footer + size)
        xp:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, footer + size)
    end
    local mode = get("portraitMode")
    if (mode == "LEFT" or mode == "RIGHT") and ns.PortraitBars then
        ns.PortraitBars.Apply(frame, true)
    else
        ns.HealPrediction.Style(frame)
        ns.Texts.Style(frame)
    end
    styleSegments(holder)
end

function ComboBar.Update(frame)
    local holder = frame.comboBar
    if not holder or holder.preview or not get("comboBarEnabled") then return end
    -- Talent/vehicle changes can alter the number of usable segments.
    if holder.count ~= ComboBar.Max() then styleSegments(holder) end
    local ok, points = pcall(GetComboPoints, "player", "target")
    if not ok or type(points) == "nil" then points = 0 end
    holder.readablePoints = Secrets.Number(points)
    -- Never compare secret point counts. A secret/unknown value reserves
    -- the row conservatively, rather than trying to branch on a secret.
    for _, bar in ipairs(holder.segments) do bar:SetValue(points) end
    local empty = get("comboBarHideEmpty") and holder.readablePoints == 0
    setRowVisible(frame, not empty)
end

function ComboBar.Preview(frame, enabled)
    local holder = frame.comboBar
    if not holder then return end
    holder.preview = enabled or nil
    if enabled and get("comboBarEnabled") then
        for _, bar in ipairs(holder.segments) do bar:SetValue(3) end
        holder.readablePoints = 3
        -- Test Mode should show its three-point sample, even if the real
        -- target has no combo points. Reserving the height is intentional.
        setRowVisible(frame, true)
    else
        ComboBar.Update(frame)
    end
    -- Texts is registered earlier than ComboBar in the element list.
    -- Repaint subscribed custom slots after preview points change, so
    -- [combo] uses the same three-point sample shown by the segments.
    if frame.textKinds and frame.textKinds.combo and ns.Texts then
        ns.Texts.Update(frame, "FUF_COMBO")
    end
end

local function refresh()
    local frame = ns.Frames and ns.Frames.player
    if frame then ComboBar.Update(frame) end
end
ns.On("PLAYER_TARGET_CHANGED", refresh)
ns.RegisterElement(ComboBar)
