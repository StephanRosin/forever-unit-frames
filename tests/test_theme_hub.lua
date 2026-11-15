-- The hub "Forever Themes" (LibForeverThemes §2.12, a fake one here).
-- Following it, the theme and colour rows grey, a line and a button to its
-- window show, "Apply to all" hides. With the hub there at all, the theme
-- font beyond the frames is its job: those two switches grey (values
-- kept), Core/BlizzardFonts.lua and Core/PlatynatorFonts.lua put back what
-- they changed and write nothing more. Own theme or no hub: as before.
local M = H.M
local ns = H.LoadAddon()
local FRIZ = "Fonts\\FRIZQT__.TTF"
local fs = CreateFrame("Frame"):CreateFontString()
fs:SetFont(FRIZ, 16, "")
function fs:GetObjectType() return "MessageFrame" end
function fs:GetFontObject() return nil end
_G.UIErrorsFrame = fs
local function design(asset) return { font = { asset = asset } } end
_G.PLATYNATOR_CONFIG = { Profiles = { DEFAULT = { designs = { DPS = design("Lato") } } } }
local dps = PLATYNATOR_CONFIG.Profiles.DEFAULT.designs.DPS

_G.ForeverUnitFramesDB = nil
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local printed = {}
ns.Print = function(text) printed[#printed + 1] = text end
local O, Themes, Config, L = ns.Options, ns.Themes, ns.Config, ns.L
_G.ForeverThemes.FakeOther = { title = "Fake", Current = function() return "CLASSIC" end,
    Switch = function() return true end, Colors = function() return {} end, SetColor = function() return true end }

Themes.Switch("PIXEL")
Config.Set("general", "themeBlizzardFonts", true)
Config.Set("general", "themePlatynatorFont", true)
local JULIUS = ns.Media.Font(Themes.Font())
H.check("own: error line in the theme font", (fs:GetFont()), JULIUS)
H.check("own: damage font stored", ForeverUnitFramesDB.damageFont, Themes.Font())
H.check("own: design themed", dps.font.asset, Themes.Font())

local function rowFor(key)
    for _, row in ipairs(O.rows) do
        if row.key == key then return row end
    end
end
local function look(label, follow, hub)
    O.Open("general")
    O.SelectTab("frames")
    H.check(label .. ": theme row", rowFor("theme").enabledState, not follow)
    H.check(label .. ": colour row", rowFor("themeColor").enabledState, not follow)
    H.check(label .. ": follow line", O.hubBlocks.follows:IsShown(), follow)
    H.check(label .. ": apply to all", O.actionButtons.themeApplyAll:GetParent():IsShown(), not follow)
    H.check(label .. ": fonts line", O.hubBlocks.fonts:IsShown(), hub)
    H.check(label .. ": download line", O.hubBlocks.missing:IsShown(), not hub)
    H.check(label .. ": Blizzard switch", rowFor("themeBlizzardFonts").enabledState, not hub)
    H.check(label .. ": Platynator switch", rowFor("themePlatynatorFont").enabledState, not hub)
    O.Close()
end

look("no hub", false, false)
H.check("download text", O.hubBlocks.missing.text:GetText(), LibForeverThemes.Text("HUB_MISSING"))
H.check("download button", O.hubBlocks.missing.button.text:GetText(), LibForeverThemes.Text("HUB_LINK"))
O.hubBlocks.missing.button:GetScript("OnClick")()
H.check("download: the link popup", M.popups[1], "LIBFOREVERTHEMES_HUB_LINK")
H.check("download: its text", StaticPopupDialogs.LIBFOREVERTHEMES_HUB_LINK.text, LibForeverThemes.Text("HUB_COPY"))
local shown = {}
StaticPopupDialogs.LIBFOREVERTHEMES_HUB_LINK.OnShow({ GetEditBox = function() return {
    SetText = function(_, t) shown.text = t end, HighlightText = function() end, SetFocus = function() end } end })
H.check("download: the address", shown.text, "https://www.curseforge.com/wow/addons/forever-themes")

local follows, opened = true, 0
LibForeverThemes.SetHub({ Follows = function(folder) return follows and folder == "ForeverUnitFrames" end,
    OpenOptions = function() opened = opened + 1 end })
look("following", true, true)
H.check("line text", O.hubBlocks.follows.text:GetText(), LibForeverThemes.Text("HUB_FOLLOWS"))
H.check("fonts text", O.hubBlocks.fonts.text:GetText(), L.HUB_fonts)
H.check("button text", O.hubBlocks.follows.button.text:GetText(), LibForeverThemes.Text("HUB_OPEN"))
O.hubBlocks.fonts.button:GetScript("OnClick")()
H.check("button opens the hub", opened, 1)
follows = false
look("own theme in the hub", false, true)

-- The fonts stand down at the next refresh, values kept; the hub tells
-- about the reload, not we.
local printedBefore = #printed
M.FireEvent("PLAYER_ENTERING_WORLD")
H.check("hub: error line back", (fs:GetFont()), FRIZ)
H.check("hub: no damage font stored", ForeverUnitFramesDB.damageFont, nil)
Config.Set("general", "fontSize", 13)
H.check("hub: design back to the user's", dps.font.asset, "Lato")
H.check("hub: snapshot dropped", ForeverUnitFramesDB.platynator.snapshot, nil)
H.check("hub: no /reload line of ours", #printed, printedBefore)
H.check("hub: Blizzard value kept", Config.Get("general", "themeBlizzardFonts"), true)
H.check("hub: Platynator value kept", Config.Get("general", "themePlatynatorFont"), true)
Themes.Switch("WOOD")
H.check("hub: a theme switch writes nothing", (fs:GetFont()) .. "|" .. dps.font.asset, FRIZ .. "|Lato")

-- The hub gone: back to the option.
LibForeverThemes.SetHub(nil)
M.FireEvent("PLAYER_ENTERING_WORLD")
H.check("no hub again: error line themed", (fs:GetFont()), ns.Media.Font(Themes.Font()))

local synced = 0
LibForeverThemes.SetHub({ Follows = function() return true end, Sync = function() synced = synced + 1 end })
-- A profile switch, reset or import replaced the theme: the hub puts its own back.
ns.UnitProfiles.SaveAs("Second")
H.check("save as: no sync", synced, 0)
ns.UnitProfiles.Switch(ns.UnitProfiles.DEFAULT)
H.check("profile switch: hub synced", synced, 1)
ns.UnitProfiles.Switch("Second")
ns.UnitProfiles.Delete()
H.check("profile delete: hub synced", synced, 3)
O.Open("profiles")
O.resetAllButton:GetScript("OnClick")(O.resetAllButton)
O.resetAllButton:GetScript("OnClick")(O.resetAllButton)
O.Close()
H.check("reset all: hub synced", synced, 4)
LibForeverThemes.SetHub(nil)

_G.ForeverThemes.FakeOther = nil
_G.UIErrorsFrame, _G.PLATYNATOR_CONFIG, _G.ForeverUnitFramesDB = nil, nil, nil
H.check("no errors", #M.errors, 0)
