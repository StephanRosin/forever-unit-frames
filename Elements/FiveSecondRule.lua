local _, ns = ...

-- The five-second rule on the player's mana bar: after a spell that costs
-- mana, mana regenerates fully again only five seconds later. While that
-- runs, a white spark crosses the power bar (left to right or right to
-- left), and optionally a countdown text shows and the bar's fill is
-- dimmed. Only while the power bar shows mana (a druid's strip in forms is
-- out of scope).
--
-- It starts on UNIT_SPELLCAST_SUCCEEDED when C_Spell.GetSpellPowerCost
-- lists a mana entry for the spell (the payload's ID goes to the client as
-- it comes, secret or not). The amount is never looked at; a secret answer
-- starts nothing rather than a guess. A new spell restarts the five
-- seconds.
--
-- No Lua counts time for the spark: a Translation animation moves it in
-- five seconds and its OnFinished ends the rule. The spark's frame shows
-- (its texture hidden) even with the spark switched off, because an
-- animation only runs on a shown frame and the end comes from it. Only the
-- countdown text uses a light ticker while the rule runs. Plain frames:
-- shown and hidden in combat too.
local FiveSecondRule = { name = "FiveSecondRule", unitEvents = { "UNIT_SPELLCAST_SUCCEEDED", "UNIT_DISPLAYPOWER" } }
ns.FiveSecondRule = FiveSecondRule

local Config, Secrets = ns.Config, ns.Secrets

FiveSecondRule.SCOPE = "player"
FiveSecondRule.DURATION = 5
FiveSecondRule.TICK = 0.1
-- Above the power bar's fill and the spell cost (PowerCost.LEVELS), below
-- the power texts (Texts.POWER_TEXT_LEVELS); the countdown level with them.
FiveSecondRule.SPARK_LEVELS = 3
-- The countdown's distance from the bar's edge when placed left or right.
FiveSecondRule.TEXT_INSET = 2
-- Test mode: the countdown's sample.
FiveSecondRule.SAMPLE = 3
local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local SPARK_COLOR = { 1, 1, 1, 1 }

local function setting(key) return Config.Get(FiveSecondRule.SCOPE, key) end

local function showsMana()
    return Secrets.Number(UnitPowerType("player")) == MANA
end

local function enabled()
    return setting("fsrEnabled") == true and setting("powerEnabled") == true
end

-- Whether the spell has a mana entry among its costs, as far as readable.
function FiveSecondRule.CostsMana(spellID)
    if type(spellID) == "nil" or not (C_Spell and C_Spell.GetSpellPowerCost) then return false end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
    if not ok or Secrets.IsSecret(costs) or type(costs) ~= "table" then return false end
    for _, info in ipairs(costs) do
        if not Secrets.IsSecret(info) and type(info) == "table" and Secrets.Number(info.type) == MANA then
            return true
        end
    end
    return false
end

function FiveSecondRule.Build(frame)
    if frame.key ~= FiveSecondRule.SCOPE or not frame.power then return end
    local spark = CreateFrame("Frame", nil, frame.power)
    local sparkTexture = spark:CreateTexture(nil, "OVERLAY")
    sparkTexture:SetAllPoints(spark)
    sparkTexture:SetColorTexture(SPARK_COLOR[1], SPARK_COLOR[2], SPARK_COLOR[3], SPARK_COLOR[4])
    spark:Hide()
    local run = spark:CreateAnimationGroup()
    local move = run:CreateAnimation("Translation")
    move:SetDuration(FiveSecondRule.DURATION)
    run:SetLooping("NONE")
    run:SetScript("OnFinished", function() FiveSecondRule.Stop(frame) end)
    local textLayer = CreateFrame("Frame", nil, frame.power)
    textLayer:SetAllPoints(frame.power)
    local text = textLayer:CreateFontString(nil, "OVERLAY")
    text:Hide()
    frame.fsr = { spark = spark, sparkTexture = sparkTexture, run = run, move = move, textLayer = textLayer,
        text = text }
    -- A hidden frame pauses its animation: the rule ends with it.
    frame:HookScript("OnHide", function() if not frame.fsr.preview then FiveSecondRule.Stop(frame) end end)
end

local function placeSpark(frame)
    local fsr, width = frame.fsr, setting("fsrSparkWidth")
    local barWidth = math.max(frame.powerWidth or frame.power:GetWidth() or 0, width)
    local leftToRight = setting("fsrSparkDirection") == "LEFT_TO_RIGHT"
    local side = leftToRight and "LEFT" or "RIGHT"
    fsr.spark:ClearAllPoints()
    fsr.spark:SetPoint("TOP" .. side, frame.power, "TOP" .. side, 0, 0)
    fsr.spark:SetPoint("BOTTOM" .. side, frame.power, "BOTTOM" .. side, 0, 0)
    fsr.spark:SetWidth(width)
    local distance = barWidth - width
    fsr.move:SetOffset(leftToRight and distance or -distance, 0)
end

local function placeText(frame)
    local text, point = frame.fsr.text, setting("fsrTextPoint")
    local inset = FiveSecondRule.TEXT_INSET
    local x = (point == "LEFT" and inset) or (point == "RIGHT" and -inset) or 0
    ns.Texts.SetFont(text, ns.Media.Font(setting("fontFace")), setting("fontSize"), setting("fontOutline"))
    text:ClearAllPoints()
    text:SetPoint(point, frame.power, point, x, 0)
end

-- The seconds left as the countdown shows them.
local function countdownText(left)
    if left < 1 and setting("fsrTextTenths") then
        return ("%.1f"):format(math.max(left, 0.1))
    end
    return ("%d"):format(math.ceil(left - 1e-6))
end

local function refreshText(frame)
    local fsr = frame.fsr
    if not fsr.startedAt then return end
    local left = FiveSecondRule.DURATION - (GetTime() - fsr.startedAt)
    fsr.text:SetText(countdownText(math.max(left, 0)))
end

local function stopTicker(fsr)
    if fsr.ticker then fsr.ticker:Cancel() end
    fsr.ticker = nil
end

-- The fill at the dimmed opacity while the rule runs and dimming is on.
local function applyDim(frame)
    local fsr = frame.fsr
    local dim = fsr.startedAt ~= nil and setting("fsrDim") == true
    local fill = frame.power:GetStatusBarTexture()
    if dim then
        fill:SetAlpha(setting("fsrDimAlpha") / 100)
        fsr.dimmed = true
    elseif fsr.dimmed then
        fill:SetAlpha(1)
        fsr.dimmed = nil
    end
end

-- The parts as the settings say, while the rule runs.
local function applyParts(frame)
    local fsr = frame.fsr
    fsr.sparkTexture:SetShown(setting("fsrSpark") == true)
    local wantsText = fsr.startedAt ~= nil and setting("fsrText") == true
    fsr.text:SetShown(wantsText)
    if wantsText and not fsr.preview and not fsr.ticker then
        fsr.ticker = C_Timer.NewTicker(FiveSecondRule.TICK, function() refreshText(frame) end)
    elseif not wantsText then
        stopTicker(fsr)
    end
    if wantsText and not fsr.preview then refreshText(frame) end
    applyDim(frame)
end

-- Starts (or restarts) the five seconds.
function FiveSecondRule.Start(frame)
    local fsr = frame.fsr
    fsr.startedAt = GetTime()
    fsr.run:Stop()
    fsr.spark:Show()
    fsr.run:Play()
    applyParts(frame)
end

-- Ends the rule: spark, text and dimming gone.
function FiveSecondRule.Stop(frame)
    local fsr = frame.fsr
    fsr.startedAt = nil
    fsr.run:Stop()
    fsr.spark:Hide()
    stopTicker(fsr)
    fsr.text:Hide()
    applyDim(frame)
end

function FiveSecondRule.Style(frame)
    local fsr = frame.fsr
    if not fsr then return end
    local level = frame.power:GetFrameLevel()
    fsr.spark:SetFrameLevel(level + FiveSecondRule.SPARK_LEVELS)
    fsr.textLayer:SetFrameLevel(level + ns.Texts.POWER_TEXT_LEVELS)
    placeSpark(frame)
    placeText(frame)
    if fsr.preview then return FiveSecondRule.Preview(frame, true) end
    if not enabled() then return FiveSecondRule.Stop(frame) end
    if fsr.startedAt then applyParts(frame) end
end

function FiveSecondRule.Update(frame, event, _, _, spellID)
    local fsr = frame.fsr
    if not fsr or fsr.preview then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if enabled() and showsMana() and FiveSecondRule.CostsMana(spellID) then FiveSecondRule.Start(frame) end
    elseif event == "UNIT_DISPLAYPOWER" and fsr.startedAt and not showsMana() then
        FiveSecondRule.Stop(frame)
    end
end

-- Test mode: a sample that keeps running, whatever the power type.
function FiveSecondRule.Preview(frame, on)
    local fsr = frame.fsr
    if not fsr then return end
    fsr.preview = on or nil
    if not (on and enabled()) then
        fsr.run:SetLooping("NONE")
        return FiveSecondRule.Stop(frame)
    end
    fsr.run:SetLooping("REPEAT")
    if not fsr.run:IsPlaying() then FiveSecondRule.Start(frame) else applyParts(frame) end
    fsr.text:SetText(countdownText(FiveSecondRule.SAMPLE))
end

ns.RegisterElement(FiveSecondRule)
