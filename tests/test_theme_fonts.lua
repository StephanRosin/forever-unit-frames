-- The theme's font beyond the frames (Core/BlizzardFonts.lua,
-- Core/PlatynatorFonts.lua): both options off by default and doing
-- nothing then; on, Blizzard's texts and Platynator's designs follow the
-- theme; Classic or the option off puts the originals back.
local M = H.M
local ns = H.LoadAddon()

local FRIZ = "Fonts\\FRIZQT__.TTF"
local ARIALN = "Fonts\\ARIALN.TTF"
local function fontString(file, size, flags)
    local fs = CreateFrame("Frame"):CreateFontString()
    fs:SetFont(file, size, flags)
    fs._object = { name = "GameFontNormal" }
    function fs:GetFontObject() return self._object end
    function fs:SetFontObject(o) self._object = o end
    return fs
end
local function font(fs) return (fs:GetFont()) end
local function size(fs) return select(2, fs:GetFont()) end

-- Blizzard's frames, before login.
local hooks, callbacks = {}, {}
_G.PlayerCastingBarFrame = { Text = fontString(FRIZ, 12, ""), CastTimeText = fontString(FRIZ, 16, ""),
    HookScript = function(_, script, fn) hooks[script] = fn end }
_G.BuffFrame = { auraFrames = { { Duration = fontString(FRIZ, 10, ""), Count = fontString(ARIALN, 14, "OUTLINE") },
    { Duration = {} } } } -- a private aura's anchor: Duration is a frame
_G.DebuffFrame = { auraFrames = { { Duration = fontString(FRIZ, 10, ""), Count = fontString(FRIZ, 14, "OUTLINE") } } }
local countdown = fontString(FRIZ, 20, "OUTLINE")
local essentialItem = { Cooldown = { GetCountdownFontString = function() return countdown end },
    ChargeCount = { Current = fontString(FRIZ, 14, "OUTLINE") } }
_G.EssentialCooldownViewer = { GetChildren = function() return essentialItem end }
-- As in the game: the error line is its own font object, setting it back throws.
local errors = fontString(FRIZ, 16, "")
function errors:SetFontObject() error("Can't create a font object loop") end
function errors:GetObjectType() return "MessageFrame" end
_G.UIErrorsFrame = errors
_G.EventRegistry = { RegisterCallback = function(_, event, fn) callbacks[event] = fn end }
_G.DAMAGE_TEXT_FONT = FRIZ

-- Platynator with LibSharedMedia.
local registered = {}
_G.LibStub = function(name)
    if name == "LibSharedMedia-3.0" then
        return { LOCALE_BIT_western = 128, Register = function(_, _, key, path) registered[key] = path end }
    end
end
local function design(asset) return { font = { asset = asset, outline = true, shadow = false } } end
_G.PLATYNATOR_CONFIG = { Profiles = {
    DEFAULT = { designs = { DPS = design("Friz Quadrata TT"), Heal = design("Lato"), Broken = { font = 3 } } },
    Other = { designs = { DPS = design("Lato") } } } }
_G.PLATYNATOR_CURRENT_PROFILE = "DEFAULT"
_G.Platynator = {}
local designs = PLATYNATOR_CONFIG.Profiles.DEFAULT.designs

_G.ForeverUnitFramesDB = nil
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local hints = {}
ns.Print = function(msg) hints[#hints + 1] = msg end
local Themes, Config, Media = ns.Themes, ns.Config, ns.Media
local JULIUS, CINZEL = Media.Font("Julius Sans One"), Media.Font("Cinzel")

H.check("public marker", ForeverUnitFrames.themeFonts, true)
H.check("Julius at LibSharedMedia", registered["Julius Sans One"], JULIUS)
H.check("Cinzel at LibSharedMedia", registered["Cinzel"], CINZEL)

-- Off by default: a theme changes nothing beyond the frames.
H.check("blizzard option off", Config.Get("general", "themeBlizzardFonts"), false)
H.check("platynator option off", Config.Get("general", "themePlatynatorFont"), false)
H.checkTrue("frost", Themes.Switch("FROST"))
M.FireEvent("PLAYER_ENTERING_WORLD")
H.check("off: cast bar untouched", font(PlayerCastingBarFrame.Text), FRIZ)
H.check("off: error line untouched", font(UIErrorsFrame), FRIZ)
H.check("off: designs untouched", designs.DPS.font.asset, "Friz Quadrata TT")
H.check("off: no snapshot", ForeverUnitFramesDB.platynator, nil)
H.check("off: no hint", #hints, 0)
H.check("off: no damage font stored", ForeverUnitFramesDB.damageFont, nil)

-- Blizzard texts.
Config.Set("general", "themeBlizzardFonts", true)
H.check("cast bar: Julius", font(PlayerCastingBarFrame.Text), JULIUS)
H.check("cast bar: size kept", size(PlayerCastingBarFrame.CastTimeText), 16)
H.check("buff duration: Julius", font(BuffFrame.auraFrames[1].Duration), JULIUS)
H.check("buff count: size and outline kept",
    size(BuffFrame.auraFrames[1].Count) .. select(3, BuffFrame.auraFrames[1].Count:GetFont()), "14OUTLINE")
H.check("debuff count: Julius", font(DebuffFrame.auraFrames[1].Count), JULIUS)
H.check("cooldown countdown: Julius", font(countdown), JULIUS)
H.check("cooldown charges: Julius", font(essentialItem.ChargeCount.Current), JULIUS)
H.check("error line: Julius", font(UIErrorsFrame), JULIUS)
H.check("damage numbers wait for the next login", DAMAGE_TEXT_FONT, FRIZ)
H.check("damage font stored for the next login", ForeverUnitFramesDB.damageFont, "Julius Sans One")

-- Blizzard sets the cast bar's font again in SetLook; showing it catches up.
PlayerCastingBarFrame.Text:SetFont(FRIZ, 11, "")
hooks.OnShow()
H.check("cast bar after SetLook: Julius, new size",
    font(PlayerCastingBarFrame.Text) .. size(PlayerCastingBarFrame.Text), JULIUS .. "11")
-- A new Cooldown Manager icon: a moment after the message.
local newItem = { ChargeCount = { Current = fontString(FRIZ, 14, "OUTLINE") } }
EssentialCooldownViewer.GetChildren = function() return essentialItem, newItem end
callbacks["CooldownViewerSettings.OnDataChanged"]()
M.RunTimers()
H.check("new cooldown icon: Julius", font(newItem.ChargeCount.Current), JULIUS)

-- A theme switch follows.
H.checkTrue("wood", Themes.Switch("WOOD"))
H.check("wood: Cinzel", font(UIErrorsFrame), CINZEL)
H.check("wood: option kept by the theme's set", Config.Get("general", "themeBlizzardFonts"), true)
H.checkTrue("classic", Themes.Switch("CLASSIC"))
H.check("classic: buff count back", font(BuffFrame.auraFrames[1].Count), ARIALN)
H.check("classic: size back", size(countdown), 20)
H.check("classic: font object back", PlayerCastingBarFrame.Text:GetFontObject().name, "GameFontNormal")
H.check("classic: error line back without a font object loop", font(UIErrorsFrame), FRIZ)
hooks.OnShow()
H.check("classic: showing changes nothing", font(PlayerCastingBarFrame.Text), FRIZ)
H.check("classic: no damage font", ForeverUnitFramesDB.damageFont, nil)
H.checkTrue("frost again", Themes.Switch("FROST"))
H.check("frost again: Julius", font(UIErrorsFrame), JULIUS)
-- Off puts the originals back at once.
Config.Set("general", "themeBlizzardFonts", false)
H.check("option off: error line back", font(UIErrorsFrame), FRIZ)
H.check("option off: cast bar back", font(PlayerCastingBarFrame.CastTimeText), FRIZ)
Config.Set("general", "themeBlizzardFonts", true)
M.locale = "koKR"
Config.Set("general", "themeBlizzardFonts", false)
Config.Set("general", "themeBlizzardFonts", true)
H.check("non-Latin client: nothing changed", font(UIErrorsFrame), FRIZ)
M.locale = "enUS"
Config.Set("general", "themeBlizzardFonts", false)

-- Platynator, under Frost.
Config.Set("general", "themePlatynatorFont", true)
H.check("frost: Julius in every design", designs.DPS.font.asset .. "|" .. designs.Heal.font.asset,
    "Julius Sans One|Julius Sans One")
H.check("hint to /reload", #hints == 1 and hints[1]:find("/reload", 1, true) ~= nil, true)
Config.Set("general", "fontSize", 13)
H.check("same font: no second hint", #hints, 1)
H.check("outline kept", designs.DPS.font.outline, true)
H.check("shadow kept", designs.DPS.font.shadow, false)
H.check("other profile untouched", PLATYNATOR_CONFIG.Profiles.Other.designs.DPS.font.asset, "Lato")
H.checkTrue("tech", Themes.Switch("TECH"))
H.check("tech: Space Grotesk", designs.DPS.font.asset, "Space Grotesk")
H.checkTrue("glass", Themes.Switch("GLASS"))
H.check("glass: Morpheus", designs.Heal.font.asset, "Morpheus")
H.check("original remembered", ForeverUnitFramesDB.platynator.snapshot.DEFAULT.DPS, "Friz Quadrata TT")
-- New designs at Platynator's next load: one copied from a themed design
-- (or themed by another Forever addon) goes to Platynator's own font later.
designs.Copy = design("Cinzel")
designs.New = design("Poppins SemiBold")
M.FireEvent("ADDON_LOADED", "Platynator")
H.check("load: new design gets the font", designs.New.font.asset, "Morpheus")
H.checkTrue("classic", Themes.Switch("CLASSIC"))
H.check("classic: originals back",
    designs.DPS.font.asset .. "|" .. designs.Heal.font.asset .. "|" .. designs.New.font.asset,
    "Friz Quadrata TT|Lato|Poppins SemiBold")
H.check("classic: the copy in Platynator's font", designs.Copy.font.asset, "Roboto Condensed Bold")
H.check("snapshot forgotten", ForeverUnitFramesDB.platynator.snapshot, nil)
H.checkTrue("frost", Themes.Switch("FROST"))
H.check("frost: Julius", designs.DPS.font.asset, "Julius Sans One")
-- Another Platynator profile themed meanwhile; a design in a library
-- font's older name (another Forever addon's) counts as themed.
local other = PLATYNATOR_CONFIG.Profiles.Other.designs
designs.Alias = design("Titillium Web")
_G.PLATYNATOR_CURRENT_PROFILE = "Other"
H.checkTrue("tech", Themes.Switch("TECH"))
H.check("tech: the other profile themed", other.DPS.font.asset, "Space Grotesk")
_G.PLATYNATOR_CURRENT_PROFILE = "DEFAULT"
H.checkTrue("frost again", Themes.Switch("FROST"))
H.check("an older alias: Platynator's own later", ForeverUnitFramesDB.platynator.snapshot.DEFAULT.Alias,
    "Roboto Condensed Bold")
local before = #hints
Config.Set("general", "themePlatynatorFont", false)
H.check("option off: originals back", designs.DPS.font.asset, "Friz Quadrata TT")
H.check("option off: the other profile back too", other.DPS.font.asset, "Lato")
H.check("option off: the alias design in Platynator's font", designs.Alias.font.asset, "Roboto Condensed Bold")
designs.Alias = nil
H.check("option off: hint to /reload", #hints, before + 1)

-- Without Platynator: harmless, nothing recorded.
_G.PLATYNATOR_CONFIG = { Profiles = { DEFAULT = { designs = "broken" } } }
Config.Set("general", "themePlatynatorFont", true)
H.check("foreign structure: no font recorded", ForeverUnitFramesDB.platynator.font, nil)
_G.PLATYNATOR_CONFIG, _G.Platynator = nil, nil
Config.Set("general", "themePlatynatorFont", false)
H.check("without Platynator: no hint", #hints, before + 1)

-- The next login: the damage numbers' font set before the client reads it.
Config.Set("general", "themeBlizzardFonts", true)
local saved = ForeverUnitFramesDB
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = saved
_G.DAMAGE_TEXT_FONT = FRIZ
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
H.check("login: damage numbers in Julius", DAMAGE_TEXT_FONT, JULIUS)
_G.PlayerCastingBarFrame, _G.BuffFrame, _G.DebuffFrame, _G.EssentialCooldownViewer, _G.UIErrorsFrame = nil, nil, nil, nil, nil
_G.EventRegistry, _G.LibStub, _G.PLATYNATOR_CURRENT_PROFILE, _G.ForeverUnitFramesDB = nil, nil, nil, nil
