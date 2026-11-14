-- General > Frames & addon > Theme: "Apply to all Forever addons", shown
-- only with another addon in _G.ForeverThemes; puts it on this theme and
-- colour, skips it when it lacks the theme.
local M = H.M
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local O, Themes = ns.Options, ns.Themes

O.Open("general")
O.SelectTab("frames")
local button = O.actionButtons.themeApplyAll
local block = button:GetParent()
H.check("label", button.text:GetText(), ns.L.ACTION_themeApplyAll)
H.check("hidden alone", block:IsShown(), false)

local pick = Themes.Colors("PIXEL")[2]
local other, known = { theme = "CLASSIC" }, { CLASSIC = {}, PIXEL = { "NAVY", pick } }
_G.ForeverThemes.FakeOther = {
    title = "Fake", Current = function() return other.theme end,
    Switch = function(id)
        if not known[id] then return nil, "UNKNOWN" end
        other.theme = id
        return true
    end,
    Colors = function(theme) return known[theme] end,
    SetColor = function(id) other.color = id; return true end,
}
O.page.Restack()
H.check("shown with another", block:IsShown(), true)

Themes.Switch("PIXEL")
Themes.SetColor(pick)
M.chat = {}
local click = button:GetScript("OnClick")
click(button)
click(button)
H.check("theme and colour", other.theme .. " " .. tostring(other.color), "PIXEL " .. pick)
H.checkTrue("says how many", (M.chat[#M.chat] or ""):find("1 other", 1, true))
Themes.Switch("WOOD")
H.check("unknown theme skipped", Themes.ApplyToAll() .. " " .. other.theme, "0 PIXEL")
_G.ForeverThemes.FakeOther = nil
H.check("no errors", #M.errors, 0)
