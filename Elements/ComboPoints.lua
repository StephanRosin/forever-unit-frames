local _, ns = ...

-- Combo points on the target frame: a row of pips, one per point the
-- player can hold. Blizzard's ComboFrame hangs from its TargetFrame, which
-- this addon conceals (Core/Blizzard.lua), so it draws its own.
--
-- GetComboPoints("player", "target") is SecretWhenUnitPowerRestricted
-- (UnitDocumentation.lua): the count may be secret. It is never compared:
-- each pip is a status bar running from i - 1 to i, and the count goes
-- straight to SetValue, so pip i is full from i points on. Only a readable
-- count of 0 can hide the row ("hide when empty").
--
-- Plain frames: nothing here is protected, it all works in combat.
local ComboPoints = { name = "ComboPoints" }
ns.ComboPoints = ComboPoints

local Config, Pixel, Secrets = ns.Config, ns.Pixel, ns.Secrets

ComboPoints.SCOPE = "target"
-- The most pips made; the player's maximum picks how many show.
ComboPoints.POOL = 10
-- When the maximum cannot be read.
ComboPoints.DEFAULT_MAX = 5
ComboPoints.TEXTURE = "Interface\\Buttons\\WHITE8X8"
ComboPoints.EMPTY = { 0, 0, 0, 0.55 }
-- Above the bars and the aura holders (+12), below the class badge (+20).
ComboPoints.LEVELS = 14
-- Test mode: three of five.
ComboPoints.SAMPLE = 3
-- Round pips: Blizzard's circular portrait mask over fill and background.
ComboPoints.CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local POWER_COMBO = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4

function ComboPoints.Build(frame)
    if frame.key ~= ComboPoints.SCOPE then return end
    local holder = CreateFrame("Frame", nil, frame)
    local pips = {}
    for i = 1, ComboPoints.POOL do
        local pip = CreateFrame("StatusBar", nil, holder)
        pip:SetStatusBarTexture(ComboPoints.TEXTURE)
        pip:SetMinMaxValues(i - 1, i)
        pip:SetValue(0)
        local bg = pip:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(pip)
        bg:SetColorTexture(ComboPoints.EMPTY[1], ComboPoints.EMPTY[2], ComboPoints.EMPTY[3], ComboPoints.EMPTY[4])
        pip.bg = bg
        local mask = pip:CreateMaskTexture()
        mask:SetTexture(ComboPoints.CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(pip)
        pip.mask = mask
        pips[i] = pip
    end
    holder:Hide()
    frame.combo = { holder = holder, pips = pips }
end

local function get(key) return Config.Get(ComboPoints.SCOPE, key) end

-- How many pips: the player's readable maximum, else five.
function ComboPoints.Max()
    local max = Secrets.Number(UnitPowerMax("player", POWER_COMBO))
    if not max or max <= 0 then max = ComboPoints.DEFAULT_MAX end
    return math.min(max, ComboPoints.POOL)
end

-- Round or square: the mask on the pip's fill and background, added or
-- taken off once per change.
local function setRound(pip, round)
    if pip.round == round then return end
    pip.round = round
    for _, tex in ipairs({ pip:GetStatusBarTexture(), pip.bg }) do
        if round then tex:AddMaskTexture(pip.mask) else tex:RemoveMaskTexture(pip.mask) end
    end
end

function ComboPoints.Style(frame)
    local c = frame.combo
    if not c then return end
    local size = Pixel.Snap(get("comboSize"), nil, 1)
    local spacing = Pixel.Snap(get("comboSpacing"))
    local n = ComboPoints.Max()
    c.count = n
    c.holder:SetFrameLevel(frame:GetFrameLevel() + ComboPoints.LEVELS)
    c.holder:SetSize(n * size + (n - 1) * spacing, size)
    -- Hangs from the unit's block (a docked castbar included), pushed out
    -- by the ring like an aura group.
    local region = frame.unitBox or frame
    local x, y = ns.Auras.AnchorOffset(frame, "combo", region)
    c.holder:ClearAllPoints()
    c.holder:SetPoint(get("comboPoint"), region, get("comboFramePoint"), x, y)
    local color = get("comboColor")
    local round = get("comboShape") == "ROUND"
    for i, pip in ipairs(c.pips) do
        setRound(pip, round)
        pip:SetSize(size, size)
        pip:ClearAllPoints()
        pip:SetPoint("LEFT", c.holder, "LEFT", (i - 1) * (size + spacing), 0)
        pip:SetStatusBarColor(color[1], color[2], color[3], color[4])
        pip:SetShown(i <= n)
    end
    if c.preview then ComboPoints.Preview(frame, true) else ComboPoints.Update(frame) end
end

-- Shows count (plain or secret) on the pips.
local function show(c, count)
    for _, pip in ipairs(c.pips) do pip:SetValue(count) end
end

function ComboPoints.Update(frame)
    local c = frame.combo
    if not c or c.preview then return end
    local ok, count = pcall(GetComboPoints, "player", "target")
    if not ok or type(count) == "nil" then count = 0 end
    show(c, count)
    local readable = Secrets.Number(count)
    local empty = readable ~= nil and readable <= 0
    c.holder:SetShown(get("comboPoints") and UnitExists("target") and not (empty and get("comboHideEmpty")))
end

function ComboPoints.Preview(frame, on)
    local c = frame.combo
    if not c then return end
    c.preview = on or nil
    if on then
        show(c, ComboPoints.SAMPLE)
        c.holder:SetShown(get("comboPoints"))
    else
        ComboPoints.Update(frame)
    end
end

local function refresh()
    local frame = ns.Frames and ns.Frames[ComboPoints.SCOPE]
    if frame then ComboPoints.Update(frame) end
end

ns.On("UNIT_POWER_FREQUENT", function(_, unit) if unit == "player" then refresh() end end)
ns.On("UNIT_MAXPOWER", function(_, unit)
    if unit ~= "player" then return end
    local frame = ns.Frames and ns.Frames[ComboPoints.SCOPE]
    if frame and frame.combo and frame.combo.count ~= ComboPoints.Max() then ComboPoints.Style(frame) end
end)
ns.On("PLAYER_TARGET_CHANGED", refresh)

ns.RegisterElement(ComboPoints)
