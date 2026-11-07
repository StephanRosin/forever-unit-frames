local _, ns = ...

-- One optional fixed-height row beneath power, above footer and Squish.
-- AUTO (shown as Both) draws XP and watched reputation in two half-height
-- sub-bars; when just one is available, it occupies the whole row.
-- XP and watched reputation are user data (not values from an enemy unit).
local XPRep = { name = "XPRepBar" }
ns.XPRepBar = XPRep
local Config, Secrets, Pixel = ns.Config, ns.Secrets, ns.Pixel
local SCOPE = "player"
local XP_COLOR = { 0.63, 0.43, 0.88, 1 }
local REST_COLOR = { 0.27, 0.58, 0.98, 0.8 }
local REP_COLOR = { 0.45, 0.7, 0.35, 1 }

-- XP/reputation remains stacked vertically, with both child bars spanning
-- the entire parent width. The combat option collapses the parent row,
-- never divides it horizontally with other resources.
local function displayWanted()
    return Config.Get(SCOPE, "xpRepEnabled") and
        (not Config.Get(SCOPE, "xpRepHideCombat") or not InCombatLockdown())
end

local function number(fn, ...)
    if not fn then return nil end
    local ok, val = pcall(fn, ...)
    return ok and Secrets.Number(val) or nil
end

local function xpData()
    local value, max = number(UnitXP, "player"), number(UnitXPMax, "player")
    local level = number(UnitLevel, "player")
    local cap = number(GetMaxLevelForPlayerExpansion)
    local disabled = IsXPUserDisabled and Secrets.Bool(IsXPUserDisabled) == true
    if not value or not max or max <= 0 or disabled or (cap and level and level >= cap) then return nil end
    value = math.max(0, math.min(value, max))
    return { kind = "xp", name = level and ("Level " .. tostring(level) .. " XP") or "Experience",
        value = value, max = max, rested = math.max(0, number(GetXPExhaustion) or 0) }
end

local function repData()
    if not C_Reputation or not C_Reputation.GetWatchedFactionData then return nil end
    local ok, data = pcall(C_Reputation.GetWatchedFactionData)
    if not ok or type(data) ~= "table" or Secrets.IsSecret(data) then return nil end
    local low = Secrets.Number(data.currentReactionThreshold)
    local high = Secrets.Number(data.nextReactionThreshold)
    local value = Secrets.Number(data.currentStanding)
    if not low or not high or not value then return nil end
    local maximum = math.max(1, high-low)
    local progress = math.max(0, math.min(maximum, value-low))
    local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[Secrets.Number(data.reaction) or -1]
    return { kind="rep", name=data.name, value=progress, max=maximum,
        color=color and {color.r, color.g, color.b, 1} or REP_COLOR,
        reaction=Secrets.Number(data.reaction) }
end

-- Share the same level-cap, disabled-XP and watched-faction interpretation
-- with custom text tags. Readers work even when the row itself is disabled.
XPRep.ReadXP = xpData
XPRep.ReadReputation = repData

local function progress(d)
    return ("%d / %d (%.1f%%)"):format(d.value, d.max, 100 * d.value / d.max)
end

local function tooltip(bar)
    GameTooltip:SetOwner(bar, "ANCHOR_BOTTOMRIGHT")
    local xp, rep = bar.xpData, bar.repData
    if not xp and not rep then
        GameTooltip:AddLine("No experience or watched faction")
    else
        if xp then
            GameTooltip:AddLine((type(xp.name) == "nil" and "Experience" or xp.name))
            GameTooltip:AddDoubleLine("XP", progress(xp), 1, 1, 1, 1, 1, 1)
            if xp.rested and xp.rested > 0 then
                GameTooltip:AddDoubleLine("Rested XP", tostring(math.floor(xp.rested)),
                    0.5, 0.8, 1, 1, 1, 1)
            end
        end
        if rep then
            if xp then GameTooltip:AddLine(" ") end
            GameTooltip:AddLine((type(rep.name) == "nil" and "Watched reputation" or rep.name))
            local standing = rep.reaction and GetText and
                GetText("FACTION_STANDING_LABEL" .. tostring(rep.reaction), UnitSex("player"))
            GameTooltip:AddDoubleLine(standing or "Reputation", progress(rep), 1, 1, 1, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

function XPRep.Build(frame)
    if frame.key ~= SCOPE then return end
    -- The original statusbar remains the row/tooltip owner. Its own fill
    -- is transparent; the two child bars own the visible fill regions.
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.xp = CreateFrame("StatusBar", nil, bar)
    bar.rep = CreateFrame("StatusBar", nil, bar)
    bar.rested = CreateFrame("StatusBar", nil, bar)
    for _, child in ipairs({ bar.xp, bar.rep, bar.rested }) do
        child:SetMinMaxValues(0, 1)
        child:SetValue(0)
        child:EnableMouse(false)
        child:Hide()
    end
    -- Rested shading sits below the XP progress texture.
    bar.rested:SetAllPoints(bar.xp)
    bar.label = bar.xp:CreateFontString(nil, "OVERLAY")
    bar.amount = bar.xp:CreateFontString(nil, "OVERLAY")
    bar.repLabel = bar.rep:CreateFontString(nil, "OVERLAY")
    bar.repAmount = bar.rep:CreateFontString(nil, "OVERLAY")
    bar:EnableMouse(true)
    pcall(bar.SetMouseClickEnabled, bar, false)
    bar:SetScript("OnEnter", tooltip)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.xpRep = bar
    ns.Corners.Add(frame, bar.bg)
    ns.Corners.Add(frame, function() return bar.xp:GetStatusBarTexture() end)
    ns.Corners.Add(frame, function() return bar.rep:GetStatusBarTexture() end)
    ns.Corners.Add(frame, function() return bar.rested:GetStatusBarTexture() end)
    if ns.SquishCastbar and ns.SquishCastbar.RegisterExtraRow then
        ns.SquishCastbar.RegisterExtraRow(frame, "xp", bar, "portraitAvoidXPRep")
    end
    bar:Hide()
end

local function placeText(label, amount, parent)
    label:ClearAllPoints()
    label:SetPoint("LEFT", parent, "LEFT", Pixel.Snap(4), 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    amount:ClearAllPoints()
    amount:SetPoint("RIGHT", parent, "RIGHT", -Pixel.Snap(4), 0)
    amount:SetPoint("LEFT", label, "RIGHT", Pixel.Snap(4), 0)
    amount:SetJustifyH("RIGHT")
    amount:SetWordWrap(false)
end

-- Reposition only the child bars, never the outer row. The latter reserves
-- the same fixed height in the SquishCastbar layout in all three modes.
local function placeParts(bar, xp, rep)
    local both = xp ~= nil and rep ~= nil
    local height = Pixel.Snap(Config.Get(SCOPE, "xpRepHeight"), nil, 1)
    local half = math.floor(height / 2)
    -- Default is reputation above experience, preserving the original
    -- Both layout. Changing the order never affects the outer row height.
    local xpOnTop = Config.Get(SCOPE, "xpRepTop") == "XP"
    local xpHeight = both and (xpOnTop and half or height - half) or height
    local repHeight = both and (xpOnTop and height - half or half) or height
    local xpSide = xpOnTop and "TOP" or "BOTTOM"
    local repSide = xpOnTop and "BOTTOM" or "TOP"
    bar.xp:ClearAllPoints()
    bar.xp:SetPoint(xpSide .. "LEFT", bar, xpSide .. "LEFT", 0, 0)
    bar.xp:SetPoint(xpSide .. "RIGHT", bar, xpSide .. "RIGHT", 0, 0)
    bar.xp:SetHeight(xpHeight)
    bar.rep:ClearAllPoints()
    bar.rep:SetPoint(repSide .. "LEFT", bar, repSide .. "LEFT", 0, 0)
    bar.rep:SetPoint(repSide .. "RIGHT", bar, repSide .. "RIGHT", 0, 0)
    bar.rep:SetHeight(repHeight)
    bar.xp:SetShown(xp ~= nil)
    bar.rep:SetShown(rep ~= nil)
    -- Very short half-bars cannot fit legible text; the shared tooltip
    -- continues to show both exact values regardless of text visibility.
    local labelOn = Config.Get(SCOPE, "xpRepLabel")
    local valueOn = Config.Get(SCOPE, "xpRepText") ~= "NONE"
    bar.label:SetShown(xp ~= nil and labelOn and xpHeight >= 9)
    bar.amount:SetShown(xp ~= nil and valueOn and xpHeight >= 9)
    bar.repLabel:SetShown(rep ~= nil and labelOn and repHeight >= 9)
    bar.repAmount:SetShown(rep ~= nil and valueOn and repHeight >= 9)
    local fontSize = math.max(6, math.min(Config.Get(SCOPE, "fontSize"),
        (both and math.min(xpHeight, repHeight) or height) - 2))
    if fontSize ~= bar.partsFontSize then
        bar.partsFontSize = fontSize
        local font = ns.Media.Font(Config.Get(SCOPE, "fontFace"))
        local outline = Config.Get(SCOPE, "fontOutline")
        for _, fs in ipairs({ bar.label, bar.amount, bar.repLabel, bar.repAmount }) do
            ns.Texts.SetFont(fs, font, fontSize, outline)
        end
    end
end

function XPRep.Style(frame)
    local bar = frame.xpRep
    if not bar then return end
    local tex = ns.Media.StatusBar(Config.Get(SCOPE, "barTexture"))
    bar:SetStatusBarTexture(tex)
    bar:SetStatusBarColor(0, 0, 0, 0)
    bar.bg:SetTexture(tex)
    local bg = Config.Get(SCOPE, "backgroundColor")
    bar.bg:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    for _, part in ipairs({ bar.xp, bar.rep, bar.rested }) do part:SetStatusBarTexture(tex) end
    bar.xp:SetStatusBarColor(XP_COLOR[1], XP_COLOR[2], XP_COLOR[3], XP_COLOR[4])
    bar.rested:SetStatusBarColor(REST_COLOR[1], REST_COLOR[2], REST_COLOR[3], REST_COLOR[4])
    bar.rested:SetFrameLevel(bar:GetFrameLevel() + 1)
    bar.xp:SetFrameLevel(bar:GetFrameLevel() + 2)
    bar.rep:SetFrameLevel(bar:GetFrameLevel() + 2)
    bar.partsFontSize = nil
    placeText(bar.label, bar.amount, bar.xp)
    placeText(bar.repLabel, bar.repAmount, bar.rep)
    bar:SetShown(displayWanted())
    bar:SetHeight(Pixel.Snap(Config.Get(SCOPE, "xpRepHeight"), nil, 1))
    if bar.preview then
        XPRep.Preview(frame, true)
    else
        XPRep.Update(frame)
    end
end

-- Called after Single's baseline bar layout, but before Squish captures
-- it. Allocate XP from health/power, never from the title or footer.
function XPRep.Layout(frame)
    local bar=frame.xpRep
    if not bar or not bar:IsShown() then return end
    local health=frame.health:GetHeight()
    local power=frame.power and frame.power:IsShown() and frame.power:GetHeight() or 0
    local newHealth,newPower,xpHeight=ns.SquishCastbar.Allocate(health,power,
        Pixel.Snap(Config.Get(SCOPE,"xpRepHeight"),nil,1))
    local footer=frame.footerHeight or 0
    local top=(frame.titleHeight or 0)+(frame.portraitStrip or 0)
    frame.health:SetHeight(newHealth)
    if frame.power and newPower>0 then
        frame.power:ClearAllPoints()
        frame.power:SetPoint("TOPLEFT",frame,"TOPLEFT",0,-(top+newHealth))
        local powerLane = Config.Get(SCOPE, "powerMatchesHealth") and (frame.overhealLane or 0) or 0
        frame.power:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-powerLane,-(top+newHealth))
        frame.power:SetHeight(newPower)
    end
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,footer)
    bar:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,footer)
    bar:SetHeight(xpHeight)
    -- PortraitBars recalculates each row's own width and side inset.
    local mode=Config.Get(SCOPE,"portraitMode")
    if (mode == "LEFT" or mode == "RIGHT") and ns.PortraitBars then
        ns.PortraitBars.Apply(frame,true)
    else
        ns.HealPrediction.Style(frame)
        ns.Texts.Style(frame)
    end
end

local function setValues(part, d, label, amount)
    if not d then
        part:SetMinMaxValues(0, 1)
        part:SetValue(0)
        label:SetText("")
        amount:SetText("")
        return
    end
    part:SetMinMaxValues(0, d.max)
    part:SetValue(d.value)
    local color = d.color or XP_COLOR
    part:SetStatusBarColor(color[1], color[2], color[3], color[4])
    label:SetText((type(d.name) == "nil" and "Progress" or d.name))
    local display = Config.Get(SCOPE, "xpRepText")
    if display == "PERCENT" then
        amount:SetFormattedText("%.1f%%", 100 * d.value / d.max)
    elseif display == "VALUES" then
        amount:SetFormattedText("%d / %d", d.value, d.max)
    else
        amount:SetText("")
    end
end

function XPRep.Update(frame, event)
    local bar = frame.xpRep
    if not bar or not bar:IsShown() or bar.preview then return end
    if event and event:sub(1, 5) == "UNIT_" then return end
    local mode = Config.Get(SCOPE, "xpRepMode")
    local xp = mode ~= "REP" and xpData() or nil
    local rep = mode ~= "XP" and repData() or nil
    bar.xpData, bar.repData = xp, rep
    bar.data = xp or rep -- retained for existing addon references
    placeParts(bar, xp, rep)
    setValues(bar.xp, xp, bar.label, bar.amount)
    setValues(bar.rep, rep, bar.repLabel, bar.repAmount)
    if xp and Config.Get(SCOPE, "xpRepRested") and xp.rested > 0 then
        bar.rested:SetMinMaxValues(0, xp.max)
        bar.rested:SetValue(math.min(xp.max, xp.value + xp.rested))
        bar.rested:Show()
    else
        bar.rested:Hide()
    end
end

function XPRep.Preview(frame, on)
    local bar = frame.xpRep
    if not bar then return end
    if on and bar:IsShown() then
        bar.preview = true
        local mode = Config.Get(SCOPE, "xpRepMode")
        local xp = mode ~= "REP" and
            { kind = "xp", name = "Experience", value = 62, max = 100, rested = 26 } or nil
        local rep = mode ~= "XP" and
            { kind = "rep", name = "Watched reputation", value = 1800, max = 3000, color = REP_COLOR } or nil
        bar.xpData, bar.repData = xp, rep
        placeParts(bar, xp, rep)
        setValues(bar.xp, xp, bar.label, bar.amount)
        setValues(bar.rep, rep, bar.repLabel, bar.repAmount)
        if xp and Config.Get(SCOPE, "xpRepRested") then
            bar.rested:SetMinMaxValues(0, 100)
            bar.rested:SetValue(88)
            bar.rested:Show()
        else
            bar.rested:Hide()
        end
    else
        bar.preview = nil
        XPRep.Update(frame)
    end
end

-- Combat-based row collapse must rebuild the full unsquished layout and
-- then apply combo-point and temporary squish rows afresh. The row returns
-- at the end of combat without changing the player's total frame height.
local function combatVisibility()
    local frame = ns.Frames and ns.Frames.player
    local bar = frame and frame.xpRep
    if not bar then return end
    local show = displayWanted() or (bar.preview == true and Config.Get(SCOPE, "xpRepEnabled"))
    if bar:IsShown() ~= show then
        bar:SetShown(show)
        if frame.squishBaseRows and ns.Single and ns.Single.LayoutBars then
            ns.Single.LayoutBars(frame)
        end
    end
    if show and not bar.preview then XPRep.Update(frame) end
end
ns.On("PLAYER_REGEN_DISABLED", combatVisibility)
ns.On("PLAYER_REGEN_ENABLED", combatVisibility)

-- No polling: XP and watched reputation update on the client's events.
-- WATCHED_FACTION_CHANGED is not available in WoW Forever. UPDATE_FACTION
-- also fires when the watched faction changes, so it is sufficient.
local function refreshProgress()
    local frame = ns.Frames and ns.Frames.player
    if frame and frame.xpRep and not frame.xpRep.preview then XPRep.Update(frame) end
end
for _, event in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION",
    "UPDATE_FACTION", "PLAYER_ENTERING_WORLD" }) do
    ns.On(event, refreshProgress)
end
-- Optional client events: don't let a missing event name abort addon loading.
-- Probe RegisterEvent before routing to ns.On, whose event hub assumes the
-- event exists and raises on unknown event names.
local probe = CreateFrame("Frame")
for _, event in ipairs({ "ENABLE_XP_GAIN", "DISABLE_XP_GAIN" }) do
    if pcall(probe.RegisterEvent, probe, event) then
        probe:UnregisterEvent(event)
        ns.On(event, refreshProgress)
    end
end

ns.RegisterElement(XPRep)
