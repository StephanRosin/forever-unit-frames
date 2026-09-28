local _, ns = ...

-- Two indicator icons for units other than you (the player frame has its
-- own combat icon, Elements/StatusIcons.lua):
-- * combat: the crossed swords while the unit is in combat (target,
--   target of target, focus, party). Handy to see a pull without line of
--   sight.
-- * pvp: the faction crest (or the free-for-all one) while a player is
--   flagged for PvP (player, target, target of target, focus, party).
--   Never on NPCs: flagged guards may be elite, and the elite marker
--   shares the top left corner.
--
-- UnitAffectingCombat and UnitIsPVP may be secret (UnitDocumentation.lua):
-- such an answer is never compared, it sets the icon's opacity
-- (SetAlphaFromBoolean). The faction picks the art, so a secret faction
-- hides the crest. Plain frames: shown, hidden and redrawn in combat too.
local UnitIcons = { name = "UnitIcons", unitEvents = { "UNIT_FLAGS", "UNIT_FACTION" } }
ns.UnitIcons = UnitIcons

local Config, Pixel, Secrets, Settings = ns.Config, ns.Pixel, ns.Secrets, ns.Settings

UnitIcons.KINDS = { "combatIcon", "pvpIcon" }
UnitIcons.COMBAT_ATLAS = "UI-HUD-UnitFrame-Player-CombatIcon"
UnitIcons.PVP_ATLAS = {
    Alliance = "UI-HUD-UnitFrame-Player-PVP-AllianceIcon",
    Horde = "UI-HUD-UnitFrame-Player-PVP-HordeIcon",
    FFA = "UI-HUD-UnitFrame-Player-PVP-FFAIcon",
}
-- Older art, where the client lacks the atlases.
UnitIcons.PVP_TEXTURE = {
    Alliance = "Interface\\TargetingFrame\\UI-PVP-Alliance",
    Horde = "Interface\\TargetingFrame\\UI-PVP-Horde",
    FFA = "Interface\\TargetingFrame\\UI-PVP-FFA",
}
-- Above the elite marker (+16), with the raid marker (+18).
UnitIcons.LEVELS = 18
-- Test mode: what the samples show. The player shows its own faction's
-- crest (PLAYER_FACTION); frames without a sample show their live state.
UnitIcons.SAMPLES = { target = { combatIcon = true, pvpIcon = "Horde" }, player = { pvpIcon = "PLAYER_FACTION" } }
UnitIcons.PARTY_SAMPLES = { [2] = { combatIcon = true, pvpIcon = "Alliance" } }

local function hasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- Whether a kind applies to the frame at all (not the party's pets and
-- targets, which derive their settings from the party).
local function applies(frame, kind)
    return Settings.AppliesTo(Settings.Get(kind), frame.key)
end

local function wanted(frame, kind)
    return applies(frame, kind) and Config.Get(frame.key, kind) == true
end

function UnitIcons.Build(frame)
    local icons = {}
    for _, kind in ipairs(UnitIcons.KINDS) do
        if applies(frame, kind) then
            local holder = CreateFrame("Frame", nil, frame)
            local tex = holder:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints(holder)
            if kind == "combatIcon" then tex:SetAtlas(UnitIcons.COMBAT_ATLAS) end
            holder:Hide()
            icons[kind] = { holder = holder, tex = tex }
        end
    end
    if next(icons) then frame.unitIcons = icons end
end

function UnitIcons.Style(frame)
    local icons = frame.unitIcons
    if not icons then return end
    local scope = frame.key
    for kind, icon in pairs(icons) do
        local size = Pixel.Snap(Config.Get(scope, kind .. "Size"), nil, 1)
        icon.holder:SetFrameLevel(frame:GetFrameLevel() + UnitIcons.LEVELS)
        icon.holder:SetSize(size, size)
        icon.holder:ClearAllPoints()
        icon.holder:SetPoint(Config.Get(scope, kind .. "Point"), frame, Config.Get(scope, kind .. "FramePoint"),
            Pixel.Snap(Config.Get(scope, kind .. "X")), Pixel.Snap(Config.Get(scope, kind .. "Y")))
    end
    if frame.unitIconsPreview then UnitIcons.Preview(frame, true) else UnitIcons.Update(frame) end
end

-- answer: true/false, a secret boolean, or nil (unknown: hidden).
local function showFrom(icon, answer)
    if Secrets.IsSecret(answer) then
        icon.holder:Show()
        icon.holder:SetAlphaFromBoolean(answer, 1, 0)
        return
    end
    icon.holder:SetAlpha(1)
    icon.holder:SetShown(answer == true)
end

-- The crest for a faction ("Alliance", "Horde", "FFA"); false if none.
local function drawCrest(tex, faction)
    local atlas = UnitIcons.PVP_ATLAS[faction]
    if not atlas then return false end
    if hasAtlas(atlas) then
        tex:SetAtlas(atlas)
    else
        tex:SetTexture(UnitIcons.PVP_TEXTURE[faction])
    end
    return true
end

local function ask(fn, unit)
    local ok, answer = pcall(fn, unit)
    if ok then return answer end
    return nil
end

local function updateCombat(frame, icon)
    if not wanted(frame, "combatIcon") or not frame.unit then return icon.holder:Hide() end
    showFrom(icon, ask(UnitAffectingCombat, frame.unit))
end

local function updatePvp(frame, icon)
    local unit = frame.unit
    if not wanted(frame, "pvpIcon") or not unit then return icon.holder:Hide() end
    -- Players only: flagged NPCs (city guards) can be elite, and the elite
    -- marker sits in the same corner. Unknown (secret) counts as a player.
    if Secrets.Bool(UnitIsPlayer, unit) == false then return icon.holder:Hide() end
    -- Free for all first: it has its own crest.
    local ffa = ask(UnitIsPVPFreeForAll, unit)
    if ffa == true and drawCrest(icon.tex, "FFA") then return showFrom(icon, true) end
    local faction = ask(UnitFactionGroup, unit)
    if Secrets.IsSecret(faction) or not drawCrest(icon.tex, faction) then return icon.holder:Hide() end
    showFrom(icon, ask(UnitIsPVP, unit))
end

function UnitIcons.Update(frame)
    local icons = frame.unitIcons
    if not icons or frame.unitIconsPreview then return end
    if icons.combatIcon then updateCombat(frame, icons.combatIcon) end
    if icons.pvpIcon then updatePvp(frame, icons.pvpIcon) end
end

local function sample(frame)
    if frame.sampleIndex then return UnitIcons.PARTY_SAMPLES[frame.sampleIndex] end
    return UnitIcons.SAMPLES[frame.key]
end

-- The player's own faction for its sample; Alliance when unreadable.
local function ownFaction()
    local faction = ask(UnitFactionGroup, "player")
    if Secrets.IsSecret(faction) or not UnitIcons.PVP_ATLAS[faction] then return "Alliance" end
    return faction
end

function UnitIcons.Preview(frame, on)
    local icons = frame.unitIcons
    if not icons then return end
    frame.unitIconsPreview = on or nil
    if not on then
        if frame.unit and UnitExists(frame.unit) then
            UnitIcons.Update(frame)
        else
            for _, icon in pairs(icons) do icon.holder:Hide() end
        end
        return
    end
    local s = sample(frame)
    if not s then
        -- No sample: what the unit really shows.
        frame.unitIconsPreview = nil
        if frame.unit and UnitExists(frame.unit) then UnitIcons.Update(frame) end
        frame.unitIconsPreview = true
        return
    end
    if icons.combatIcon then
        showFrom(icons.combatIcon, wanted(frame, "combatIcon") and s.combatIcon == true)
    end
    if icons.pvpIcon then
        local faction = s.pvpIcon == "PLAYER_FACTION" and ownFaction() or s.pvpIcon
        local shown = wanted(frame, "pvpIcon") and faction ~= nil and drawCrest(icons.pvpIcon.tex, faction)
        showFrom(icons.pvpIcon, shown == true)
    end
end

-- Combat starts and ends without a unit event for everyone else; a frame
-- showing a unit looks again then.
local function refreshAll(event) ns.Units.UpdateElement(UnitIcons, event) end
ns.On("PLAYER_REGEN_DISABLED", refreshAll)
ns.On("PLAYER_REGEN_ENABLED", refreshAll)
ns.On("PLAYER_FLAGS_CHANGED", refreshAll)

ns.RegisterElement(UnitIcons)
