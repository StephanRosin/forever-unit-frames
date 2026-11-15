local ADDON, ns = ...

-- "Theme font for Blizzard texts" (General: themeBlizzardFonts): some of
-- Blizzard's texts take the theme's font (Themes.Font), each keeping its
-- size and outline. Only these, one FontString each (their font objects,
-- GameFontNormalSmall or NumberFontNormal, also carry tooltips, quest and
-- chat text): the player's cast bar (Text, CastTimeText), the duration and
-- count of the buff and debuff icons, the Cooldown Manager's numbers
-- (countdown, charges, stacks, the buff bars' duration) and the red error
-- line (UIErrorsFrame). The first change remembers each text's font for
-- the session; Classic or the option off puts it back.
--
-- No hooksecurefunc on a frame (in Forever it breaks Blizzard's own
-- code): the cast bar sets its font again in SetLook, hence
-- HookScript("OnShow"); the Cooldown Manager builds new icons, hence
-- Blizzard's EventRegistry message "CooldownViewerSettings.OnDataChanged";
-- and every loading screen. The client reads the damage numbers' font
-- (DAMAGE_TEXT_FONT) at login only: ForeverUnitFramesDB.damageFont keeps
-- the font for the next one, set at ADDON_LOADED.
local BlizzardFonts = {}
ns.BlizzardFonts = BlizzardFonts
-- Other Forever addons with these two bridges leave them to us.
ns.api.themeFonts = true

local COOLDOWN_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer",
    "BuffBarCooldownViewer" }
local AURA_FRAMES = { "BuffFrame", "DebuffFrame" }

-- FontString (or MessageFrame) -> its font before the first change.
local originals = setmetatable({}, { __mode = "k" })

local function add(list, fs)
    if type(fs) == "table" and fs.GetFont and fs.SetFont then list[#list + 1] = fs end
end

local function castBarTexts(list)
    local bar = _G.PlayerCastingBarFrame
    if bar then add(list, bar.Text); add(list, bar.CastTimeText) end
end

-- Every text there is right now.
function BlizzardFonts.Targets()
    local list = {}
    castBarTexts(list)
    for _, name in ipairs(AURA_FRAMES) do
        local frame = _G[name]
        for _, button in ipairs(frame and frame.auraFrames or {}) do
            add(list, button.Duration)
            add(list, button.Count)
        end
    end
    for _, name in ipairs(COOLDOWN_VIEWERS) do
        local viewer = _G[name]
        for _, item in ipairs(viewer and { viewer:GetChildren() } or {}) do
            local cd = item.Cooldown
            if cd and cd.GetCountdownFontString then add(list, cd:GetCountdownFontString()) end
            add(list, item.ChargeCount and item.ChargeCount.Current)
            add(list, item.Applications and item.Applications.Applications)
            add(list, item.Icon and item.Icon.Applications)
            add(list, item.Bar and item.Bar.Duration)
        end
    end
    add(list, _G.UIErrorsFrame)
    return list
end

local function setFont(list, path)
    for _, fs in ipairs(list) do
        local file, size, flags = fs:GetFont()
        if file ~= path and size then
            originals[fs] = originals[fs] or { object = fs:GetFontObject(), file = file, size = size, flags = flags }
            fs:SetFont(path, size, flags)
        end
    end
end

local function restoreAll()
    for fs, o in pairs(originals) do
        fs:SetFont(o.file, o.size, o.flags)
        -- Only a FontString: the error line, a MessageFrame, errors on any
        -- SetFontObject back ("font object loop"); SetFont restored it.
        if o.object and fs:GetObjectType() == "FontString" then fs:SetFontObject(o.object) end
        originals[fs] = nil
    end
end

-- The theme font's name while the option is on, else nil.
local function wanted()
    return ns.Config.Get("general", "themeBlizzardFonts") and ns.Themes.Font() or nil
end

-- After a settings change, a theme switch, a loading screen.
function BlizzardFonts.Refresh()
    local font = wanted()
    ForeverUnitFramesDB.damageFont = font
    if font then setFont(BlizzardFonts.Targets(), ns.Media.Font(font)) else restoreAll() end
end

local function hookCastBar()
    local bar = _G.PlayerCastingBarFrame
    if not bar or not bar.HookScript then return end
    bar:HookScript("OnShow", function()
        local font = wanted()
        if font then
            local list = {}
            castBarTexts(list)
            setFont(list, ns.Media.Font(font))
        end
    end)
end

ns.On("ADDON_LOADED", function(_, name)
    local font = name == ADDON and ForeverUnitFramesDB and ForeverUnitFramesDB.damageFont
    if font then _G.DAMAGE_TEXT_FONT = ns.Media.Font(font) end
end)

-- After Core/Boot.lua's PLAYER_LOGIN: the settings are there.
ns.On("PLAYER_LOGIN", function()
    hookCastBar()
    if _G.EventRegistry then
        -- A moment later: the Cooldown Manager builds its icons first.
        EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
            C_Timer.After(0, BlizzardFonts.Refresh)
        end, BlizzardFonts)
    end
    BlizzardFonts.Refresh()
    local font = wanted()
    if font then _G.DAMAGE_TEXT_FONT = ns.Media.Font(font) end
    ns.Listen("CONFIG_CHANGED", BlizzardFonts.Refresh)
end)
-- A hidden text does not load a new font file (LibForeverThemes loads ours
-- while the addon loads); each loading screen also brings new buttons.
ns.On("PLAYER_ENTERING_WORLD", function()
    if ns.booted then BlizzardFonts.Refresh() end
end)
