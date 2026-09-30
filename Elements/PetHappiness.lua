local _, ns = ...

-- The hunter pet's happiness (content, unhappy, happy) as an icon on the
-- pet frame, the way Blizzard's pet frame shows it
-- (Blizzard_FrameXML/PetHappiness.lua): the atlases UI-PetHappiness,
-- UI-PetNeutral and UI-PetMad, the answer of C_PetInfo.GetPetHappiness,
-- and only for hunters: the player must be one (test mode included), and
-- HasPetUI must call the pet a hunter's. Demons, other pets and every
-- other class: no icon.
--
-- GetPetHappiness is not documented with SecretReturns; an answer that is
-- secret all the same is not compared and hides the icon.
--
-- Hovering the icon shows Blizzard's tooltip: the mood, the damage the pet
-- deals at it, whether it gains or loses loyalty, and its diet. Clicks go
-- through to the unit button below. A plain holder frame: shown, hidden
-- and redrawn in combat too.
local PetHappiness = { name = "PetHappiness", unitEvents = { "UNIT_HAPPINESS" } }
ns.PetHappiness = PetHappiness

local Config, Pixel, Secrets, Settings = ns.Config, ns.Pixel, ns.Secrets, ns.Settings

PetHappiness.HAPPY = 3
-- By level (1 unhappy, 2 content, 3 happy): the atlas, the older texture's
-- cell where the client lacks the atlas (Interface\PetPaperDollFrame\
-- UI-PetHappiness, three cells side by side), and the client's name for it
-- with our own as fallback.
PetHappiness.LEVELS = {
    { atlas = "UI-PetMad", coords = { 0.375, 0.5625, 0, 0.359375 }, text = "PET_HAPPINESS1" },
    { atlas = "UI-PetNeutral", coords = { 0.1875, 0.375, 0, 0.359375 }, text = "PET_HAPPINESS2" },
    { atlas = "UI-PetHappiness", coords = { 0, 0.1875, 0, 0.359375 }, text = "PET_HAPPINESS3" },
}
PetHappiness.TEXTURE = "Interface\\PetPaperDollFrame\\UI-PetHappiness"
-- With the unit icons, above the elite marker (+16).
PetHappiness.FRAME_LEVELS = 18
-- Test mode shows a content pet, so the icon is seen even with
-- "Only when not happy" on.
PetHappiness.SAMPLE = 2

local function hasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function applies(frame)
    return Settings.AppliesTo(Settings.Get("petHappiness"), frame.key)
end

-- Whether the player is a hunter. An unreadable class counts as one: the
-- pet check still decides.
function PetHappiness.IsHunter()
    local ok, _, class = pcall(UnitClass, "player")
    if not ok or Secrets.IsSecret(class) or class == nil then return true end
    return class == "HUNTER"
end

local function wanted(frame)
    return applies(frame) and Config.Get(frame.key, "petHappiness") == true and PetHappiness.IsHunter()
end

-- The pet's happiness, damage percentage and loyalty rate; nil when it
-- has none (no pet, not a hunter's, or an unreadable answer).
function PetHappiness.Read()
    if not (C_PetInfo and C_PetInfo.GetPetHappiness) then return nil end
    if HasPetUI then
        local ok, _, isHunterPet = pcall(HasPetUI)
        if ok and isHunterPet ~= true then return nil end
    end
    local ok, level, damage, loyalty = pcall(C_PetInfo.GetPetHappiness)
    level = ok and Secrets.Number(level)
    if not level or not PetHappiness.LEVELS[level] then return nil end
    return level, Secrets.Number(damage), Secrets.Number(loyalty)
end

local function levelText(level)
    local key = PetHappiness.LEVELS[level].text
    return _G[key] or ns.L[key]
end

local function showTooltip(holder)
    local shown = holder.shown
    if not shown then return end
    GameTooltip:SetOwner(holder, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(levelText(shown.level))
    if shown.damage and PET_DAMAGE_PERCENTAGE then
        GameTooltip:AddLine(PET_DAMAGE_PERCENTAGE:format(shown.damage), 1, 0.82, 0)
    end
    if shown.loyalty and shown.loyalty < 0 and LOSING_LOYALTY then
        GameTooltip:AddLine(LOSING_LOYALTY, 1, 0.82, 0)
    elseif shown.loyalty and shown.loyalty > 0 and GAINING_LOYALTY then
        GameTooltip:AddLine(GAINING_LOYALTY, 1, 0.82, 0)
    end
    local ok, diet = pcall(C_PetInfo.GetPetFoodTypes)
    if ok and type(diet) == "table" and #diet > 0 and PET_DIET_TEMPLATE then
        GameTooltip:AddLine(PET_DIET_TEMPLATE:format(table.concat(diet, PET_FOOD_DELIMIT or ", ")), 1, 0.82, 0)
    end
    GameTooltip:Show()
end

local function hideTooltip(holder)
    if GameTooltip:IsOwned(holder) then GameTooltip:Hide() end
end

function PetHappiness.Build(frame)
    if not applies(frame) then return end
    local holder = CreateFrame("Frame", nil, frame)
    local tex = holder:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(holder)
    -- Tooltip on hover, clicks through to the unit button below.
    holder:EnableMouse(true)
    pcall(holder.SetMouseClickEnabled, holder, false)
    holder:SetScript("OnEnter", showTooltip)
    holder:SetScript("OnLeave", hideTooltip)
    holder:Hide()
    frame.petHappiness = { holder = holder, tex = tex }
end

-- Draws a level with its readings (the tooltip's), or hides the icon.
local function show(frame, level, damage, loyalty)
    local p = frame.petHappiness
    local hideHappy = Config.Get(frame.key, "petHappinessHideHappy") == true
    if not wanted(frame) or not level or (hideHappy and level == PetHappiness.HAPPY) then
        p.holder.shown = nil
        hideTooltip(p.holder)
        return p.holder:Hide()
    end
    local art = PetHappiness.LEVELS[level]
    if hasAtlas(art.atlas) then
        p.tex:SetTexCoord(0, 1, 0, 1)
        p.tex:SetAtlas(art.atlas)
    else
        p.tex:SetTexture(PetHappiness.TEXTURE)
        p.tex:SetTexCoord(unpack(art.coords))
    end
    p.holder.shown = { level = level, damage = damage, loyalty = loyalty }
    p.holder:Show()
end

function PetHappiness.Style(frame)
    local p = frame.petHappiness
    if not p then return end
    local scope = frame.key
    local size = Pixel.Snap(Config.Get(scope, "petHappinessSize"), nil, 1)
    p.holder:SetFrameLevel(frame:GetFrameLevel() + PetHappiness.FRAME_LEVELS)
    p.holder:SetSize(size, size)
    p.holder:ClearAllPoints()
    p.holder:SetPoint(Config.Get(scope, "petHappinessPoint"), frame, Config.Get(scope, "petHappinessFramePoint"),
        Pixel.Snap(Config.Get(scope, "petHappinessX")), Pixel.Snap(Config.Get(scope, "petHappinessY")))
    if p.preview then PetHappiness.Preview(frame, true) else PetHappiness.Update(frame) end
end

function PetHappiness.Update(frame)
    local p = frame.petHappiness
    if not p or p.preview then return end
    if not frame.unit or not UnitExists(frame.unit) then return show(frame, nil) end
    show(frame, PetHappiness.Read())
end

function PetHappiness.Preview(frame, on)
    local p = frame.petHappiness
    if not p then return end
    p.preview = on or nil
    if on then
        show(frame, PetHappiness.SAMPLE)
    else
        PetHappiness.Update(frame)
    end
end

-- Taming, dismissing or stabling changes whose happiness it is.
ns.On("PET_UI_UPDATE", function(event) ns.Units.UpdateElement(PetHappiness, event) end)

ns.RegisterElement(PetHappiness)
