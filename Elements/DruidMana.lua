local _, ns = ...

-- A druid's mana while shapeshifted (bear: rage, cat: energy), as
-- Blizzard's alternate mana bar shows it: a thin strip along the bottom of
-- the player's power bar, only while the power bar shows something other
-- than mana. Values may be secret: they go to the status bar as they are.
-- A plain frame, so it follows forms in combat too.
local DruidMana = { name = "DruidMana", unitEvents = { "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" } }
ns.DruidMana = DruidMana

local Config, Pixel, Secrets = ns.Config, ns.Pixel, ns.Secrets

DruidMana.SCOPE = "player"
local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
-- Test mode: a druid's strip at 60 %.
DruidMana.SAMPLE = 0.6
-- Above the power bar and its texts' layer, below the overlay (+10).
DruidMana.LEVELS = 2

local function isDruid()
    local ok, _, token = pcall(UnitClass, "player")
    return ok and not Secrets.IsSecret(token) and token == "DRUID"
end

function DruidMana.Build(frame)
    if frame.key ~= DruidMana.SCOPE or not frame.power then return end
    local bar = CreateFrame("StatusBar", nil, frame.power)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar:Hide()
    frame.druidMana = bar
end

local function wanted(frame)
    return Config.Get(DruidMana.SCOPE, "druidMana") and Config.Get(DruidMana.SCOPE, "powerEnabled") and isDruid()
end

function DruidMana.Style(frame)
    local bar = frame.druidMana
    if not bar then return end
    local tex = ns.Media.StatusBar(Config.Get(DruidMana.SCOPE, "barTexture"))
    bar:SetStatusBarTexture(tex)
    local c = Config.Get(DruidMana.SCOPE, "powerColorMana")
    bar:SetStatusBarColor(c[1], c[2], c[3])
    bar.bg:SetColorTexture(0, 0, 0, 0.6)
    bar:SetFrameLevel(frame.power:GetFrameLevel() + DruidMana.LEVELS)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", frame.power, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", frame.power, "BOTTOMRIGHT", 0, 0)
    bar:SetHeight(Pixel.Snap(Config.Get(DruidMana.SCOPE, "druidManaHeight"), nil, 1))
    if bar.preview then DruidMana.Preview(frame, true) else DruidMana.Update(frame) end
end

-- Shown while the power bar shows another power than mana; a secret or
-- unreadable power type hides it.
function DruidMana.Update(frame)
    local bar = frame.druidMana
    if not bar or bar.preview then return end
    local powerType = Secrets.Number(UnitPowerType("player"))
    if not wanted(frame) or powerType == nil or powerType == MANA then
        bar:Hide()
        return
    end
    bar:SetMinMaxValues(0, UnitPowerMax("player", MANA))
    bar:SetValue(UnitPower("player", MANA))
    bar:Show()
end

function DruidMana.Preview(frame, on)
    local bar = frame.druidMana
    if not bar then return end
    bar.preview = on or nil
    if not on then return DruidMana.Update(frame) end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(DruidMana.SAMPLE)
    bar:SetShown(wanted(frame))
end

ns.RegisterElement(DruidMana)
