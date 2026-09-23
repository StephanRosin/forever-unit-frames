local _, ns = ...

-- One aura icon: a plain frame (never secure) with the icon, a border, a
-- cooldown swipe with the client's countdown numbers, and a stack count.
-- Buttons are made once per frame and reused; Elements/Auras.lua owns them.
--
-- Aura data may be secret. Fields are only handed to widgets (SetTexture,
-- SetText, SetCooldown...) or read through ns.Secrets. What cannot be
-- shown from a secret field is asked of the client by aura instance ID,
-- which returns display values: a count string, a duration object for the
-- swipe, a dispel colour. Every such call is guarded; what the client
-- refuses is left empty. A secret instance ID is never passed back.
local AuraButton = {}
ns.AuraButton = AuraButton

local Config, Secrets, Pixel = ns.Config, ns.Secrets, ns.Pixel

-- Debuff borders by dispel type; everything else (no type, enrage, ...)
-- gets NONE.
AuraButton.DISPEL_COLORS = {
    Magic = { 0.2, 0.6, 1.0 },
    Curse = { 0.6, 0.0, 1.0 },
    Disease = { 0.6, 0.4, 0.0 },
    Poison = { 0.0, 0.6, 0.0 },
    NONE = { 0.8, 0.0, 0.0 },
}
-- The client's dispel type numbers, for the colour curve (x = number).
-- Not documented in this build: the numbers of the spell data. Points
-- are listed in rising order; the curve snaps, and 5 (the first number
-- past these) and above get NONE again.
local DISPEL_POINTS = { { 0, "NONE" }, { 1, "Magic" }, { 2, "Curse" }, { 3, "Disease" }, { 4, "Poison" },
    { 5, "NONE" } }

-- Icons are cropped a little: their own edge art would show inside ours.
local CROP = 0.08

-- The client's aura tooltip. Nothing when there is no aura behind the
-- icon (a sample, a secret ID) or the client refuses.
local function onEnter(self)
    if not self.auraID then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    local method = self.isDebuff and GameTooltip.SetUnitDebuffByAuraInstanceID
        or GameTooltip.SetUnitBuffByAuraInstanceID
    if not pcall(method, GameTooltip, self.unit, self.auraID, self.filter) then GameTooltip:Hide() end
end

local function onLeave(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

function AuraButton.Create(parent, isDebuff)
    local button = CreateFrame("Frame", nil, parent)
    button.isDebuff = isDebuff
    button.border = button:CreateTexture(nil, "BACKGROUND")
    button.border:SetAllPoints(button)
    button.border:SetColorTexture(1, 1, 1, 1)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.cooldown:SetReverse(true)
    button.cooldown:SetDrawEdge(false)
    -- The count sits on its own frame so the swipe never covers it.
    button.cover = CreateFrame("Frame", nil, button)
    button.cover:SetAllPoints(button)
    button.cover:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)
    button.count = button.cover:CreateFontString(nil, "OVERLAY")
    button:EnableMouse(true)
    button:SetMouseClickEnabled(false)
    button:SetScript("OnEnter", onEnter)
    button:SetScript("OnLeave", onLeave)
    button:Hide()
    return button
end

local function paintBorder(button, c)
    button.border:SetVertexColor(c[1], c[2], c[3], 1)
end

local dispelCurve
local function getDispelCurve()
    if dispelCurve then return dispelCurve end
    dispelCurve = C_CurveUtil.CreateColorCurve()
    if Enum and Enum.LuaCurveType then dispelCurve:SetType(Enum.LuaCurveType.Step) end
    for _, point in ipairs(DISPEL_POINTS) do
        local c = AuraButton.DISPEL_COLORS[point[2]]
        dispelCurve:AddPoint(point[1], CreateColor(c[1], c[2], c[3], 1))
    end
    return dispelCurve
end

-- Size, fonts and countdown numbers; out of combat or on plain frames
-- only, like every Style.
function AuraButton.Style(button, scope, size, showTime)
    button:SetSize(size, size)
    local inset = Pixel.Snap(1, button, 1)
    button.icon:ClearAllPoints()
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
    local font = ns.Media.Font(Config.Get(scope, "fontFace"))
    local outline = Config.Get(scope, "fontOutline")
    local fontSize = math.max(6, math.floor(size * 0.5 + 0.5))
    ns.Texts.SetFont(button.count, font, fontSize, outline)
    button.count:ClearAllPoints()
    button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button.count:SetJustifyH("RIGHT")
    -- The client writes the countdown itself: a soft outline cannot follow
    -- it, so it gets the plain outline.
    local numbers = button.cooldown:GetCountdownFontString()
    if numbers then
        local flags = (outline == "SOFT" or outline == "NONE") and "OUTLINE" or outline
        numbers:SetFont(font, fontSize, flags)
    end
    button.cooldown:SetHideCountdownNumbers(not showTime)
    button.plainBorder = Config.Get(scope, "borderColor")
    if not button.isDebuff then paintBorder(button, button.plainBorder) end
end

local function forget(button)
    button.unit, button.auraID, button.filter = nil, nil, nil
end

local function clientCount(button)
    button.count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount(button.unit, button.auraID, 2))
end

-- Stack count: a readable number, else the client's count string.
local function showCount(button, aura)
    local n = Secrets.Number(aura.applications)
    if n then
        button.count:SetText(n > 1 and ("%d"):format(n) or "")
        return
    end
    if not (button.auraID and pcall(clientCount, button)) then button.count:SetText("") end
end

local function clientDuration(button)
    button.cooldown:SetCooldownFromDurationObject(C_UnitAuras.GetAuraDuration(button.unit, button.auraID), true)
end

-- Swipe and countdown: readable times, else the client's duration object.
local function showDuration(button, aura)
    local duration, expires = Secrets.Number(aura.duration), Secrets.Number(aura.expirationTime)
    if duration and expires then
        if duration > 0 then
            button.cooldown:SetCooldown(expires - duration, duration)
        else
            button.cooldown:Clear()
        end
        return
    end
    if not (button.auraID and pcall(clientDuration, button)) then button.cooldown:Clear() end
end

local function clientBorder(button)
    local color = C_UnitAuras.GetAuraDispelTypeColor(button.unit, button.auraID, getDispelCurve())
    button.border:SetVertexColor(color:GetRGBA())
end

-- Debuff border: the colour of a readable dispel type, else the client's
-- colour from the curve, else NONE.
local function showBorder(button, aura)
    if not button.isDebuff then return end
    local name = aura.dispelName
    if not Secrets.IsSecret(name) then
        paintBorder(button, type(name) == "string" and AuraButton.DISPEL_COLORS[name] or AuraButton.DISPEL_COLORS.NONE)
        return
    end
    if not (button.auraID and pcall(clientBorder, button)) then paintBorder(button, AuraButton.DISPEL_COLORS.NONE) end
end

local function apply(button, unit, aura, filter)
    forget(button)
    local id = aura.auraInstanceID
    if not Secrets.IsSecret(id) and type(id) == "number" then
        button.unit, button.auraID, button.filter = unit, id, filter
    end
    button.icon:SetTexture(aura.icon)
    showCount(button, aura)
    showDuration(button, aura)
    showBorder(button, aura)
    button:Show()
end

-- Shows one aura (an AuraData table). Returns false, with the button
-- hidden, when the client refused part of it.
function AuraButton.Show(button, unit, aura, filter)
    if pcall(apply, button, unit, aura, filter) then return true end
    AuraButton.Clear(button)
    return false
end

-- Test mode: sample = { icon, count, duration, dispel }, started at start.
function AuraButton.ShowSample(button, sample, start)
    forget(button)
    button.icon:SetTexture(sample.icon)
    button.count:SetText((sample.count or 0) > 1 and ("%d"):format(sample.count) or "")
    button.cooldown:SetCooldown(start, sample.duration)
    if button.isDebuff then paintBorder(button, AuraButton.DISPEL_COLORS[sample.dispel or "NONE"]) end
    button:Show()
end

function AuraButton.Clear(button)
    forget(button)
    button.cooldown:Clear()
    button:Hide()
end
