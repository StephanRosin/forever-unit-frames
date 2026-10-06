-- The What's New window (Options/News.lua) and the news it shows
-- (Core/News.lua): one line per entry, in the style of the options
-- windows; the entry's action button and Close; ESC; the language.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local News, NW, L = ns.News, ns.NewsWindow, ns.L
local chatBefore = #M.chat

local function click(button) button:GetScript("OnClick")(button) end
local function shownLines()
    local n = 0
    for _, item in ipairs(NW.lines) do if item.text:IsShown() then n = n + 1 end end
    return n
end

-- The version is the TOC's.
H.check("the mock's version", News.Current(), "0.1.0")
M.addonVersion = "0.22.0"
H.check("the TOC's version", News.Current(), "0.22.0")
H.checkTrue("0.22.0 has news", News.Entry("0.22.0"))
H.check("a version without news", News.Entry("0.1.0"), nil)
H.check("no version", News.Entry(nil), nil)

-- Every line and action names an English text (test_locale.lua holds the
-- other languages to the same keys).
for version, entry in pairs(News.ENTRIES) do
    for _, key in ipairs(entry.lines) do
        H.check(version .. ": " .. key, type(rawget(ns.Locales.enUS, key)), "string")
    end
    if entry.action then
        H.check(version .. ": action text", type(rawget(ns.Locales.enUS, entry.action.text)), "string")
        H.check(version .. ": action", type(entry.action.run), "function")
    end
end

-- A version without news opens nothing.
H.check("no news: refused", NW.Open("0.1.0"), false)
H.check("no news: no window", NW.IsOpen(), false)

-- The news of 0.22.0, in the style of the options windows.
H.check("opens", NW.Open("0.22.0"), true)
H.checkTrue("open", NW.IsOpen())
local f = NW.frame
H.check("title", f.titleBar.title:GetText(), "What's new in 0.22.0")
H.check("addon name", f.titleBar.addon:GetText(), "Forever Unit Frames")
H.check("strata of the options windows", f:GetFrameStrata(), "HIGH")
H.check("bordered like them", f.edges[1]._color[1], ns.Style.COLORS.border[1])
H.check("not protected", f:IsProtected(), false)
local escCount = 0
for _, name in ipairs(UISpecialFrames) do if name == "ForeverUnitFramesNews" then escCount = escCount + 1 end end
H.check("ESC closes it", escCount, 1)
H.check("seven lines", shownLines(), 7)
H.check("raid frames first", NW.lines[1].text:GetText(), L.NEWS_0_22_0_RAID)
H.check("the last line", NW.lines[7].text:GetText(), L.NEWS_0_22_0_BLIZZARD)
H.check("a bullet each", NW.lines[3].bullet:GetText(), "•")
local _, below = NW.lines[2].text:GetPoint(1)
H.check("one below the other", below, NW.lines[1].text)
H.check("lines wrap", NW.lines[1].text:GetWordWrap(), true)
H.check("action button", NW.actionButton.text:GetText(), "Open raid options")
H.checkTrue("action shown", NW.actionButton:IsShown())
H.check("close button", NW.closeButton.text:GetText(), "Close")

-- Close, the cross and opening again.
click(NW.closeButton)
H.check("Close closes", NW.IsOpen(), false)
NW.Open("0.22.0")
click(f.titleBar.close)
H.check("the cross closes", NW.IsOpen(), false)
H.check("the same window again", (NW.Open("0.22.0") and NW.frame), f)
escCount = 0
for _, name in ipairs(UISpecialFrames) do if name == "ForeverUnitFramesNews" then escCount = escCount + 1 end end
H.check("ESC entry not doubled", escCount, 1)

-- Open raid options: the raid window opens, the news closes.
click(NW.actionButton)
H.check("action closes the news", NW.IsOpen(), false)
H.checkTrue("raid options open", ns.RaidOptions.IsOpen())
ns.RaidOptions.Close()

-- A new language while it is open.
NW.Open("0.22.0")
ns.Config.Set("general", "language", "deDE")
H.check("German title", f.titleBar.title:GetText(), "Neu in 0.22.0")
H.check("German line", NW.lines[1].text:GetText(), ns.Locales.deDE.NEWS_0_22_0_RAID)
H.check("German close", NW.closeButton.text:GetText(), "Schließen")
ns.Config.Set("general", "language", "AUTO")
H.check("English again", NW.closeButton.text:GetText(), "Close")

-- An entry with fewer lines and no action.
News.ENTRIES["9.9.9"] = { lines = { "NEWS_0_22_0_RAID", "NEWS_0_22_0_ICONS" } }
NW.Open("9.9.9")
H.check("its lines only", shownLines(), 2)
H.check("its title", f.titleBar.title:GetText(), "What's new in 9.9.9")
H.check("no action button", NW.actionButton:IsShown(), false)
NW.Open("0.22.0")
H.check("all lines again", shownLines(), 7)
H.checkTrue("action button again", NW.actionButton:IsShown())
News.ENTRIES["9.9.9"] = nil
NW.Close()

-- The action button fits its label: at least the wide button, wider for a
-- longer label, never past the Close button.
local enUS = ns.Locales.enUS
local function labelFits()
    local b = NW.actionButton
    return b:GetWidth() >= b.text:GetStringWidth() and b:GetWidth() >= 160
        and b:GetWidth() <= 560 - 2 * 12 - NW.closeButton:GetWidth() - 8
end
NW.Open("0.22.0")
H.check("English label: wide button", NW.actionButton:GetWidth(), 160)
for _, code in ipairs({ "deDE", "frFR", "esES" }) do
    ns.Config.Set("general", "language", code)
    H.checkTrue(code .. " label fits", labelFits())
end
ns.Config.Set("general", "language", "AUTO")
local openRaid = enUS.NEWS_OPEN_RAID
enUS.NEWS_OPEN_RAID = "Open the raid frame options window right now"
NW.Open("0.22.0")
H.checkTrue("a longer label: wider", NW.actionButton:GetWidth() > 160)
H.checkTrue("a longer label fits", labelFits())
enUS.NEWS_OPEN_RAID = openRaid
NW.Open("0.22.0")
H.check("the wide button again", NW.actionButton:GetWidth(), 160)

-- The window grows with its list, between 440 and 600.
local function listFits()
    local need = 32 + 16 + 16 + 40
    for i = 1, 7 do need = need + NW.lines[i].text:GetStringHeight() end
    return f:GetHeight() >= math.min(600, need + 6 * 8)
end
for _, code in ipairs({ "enUS", "deDE", "frFR", "esES" }) do
    ns.Config.Set("general", "language", code == "enUS" and "AUTO" or code)
    H.checkTrue(code .. ": the list fits", listFits())
end
ns.Config.Set("general", "language", "AUTO")
H.check("short list: the least height", f:GetHeight(), 440)
local raidLine = enUS.NEWS_0_22_0_RAID
enUS.NEWS_0_22_0_RAID = string.rep("A much longer line. ", 30)
NW.Open("0.22.0")
H.checkTrue("taller lines: taller window", f:GetHeight() > 440)
H.checkTrue("taller lines: the list fits", listFits())
enUS.NEWS_0_22_0_RAID = string.rep("A much longer line. ", 300)
NW.Open("0.22.0")
H.check("at most 600", f:GetHeight(), 600)
enUS.NEWS_0_22_0_RAID = raidLine
NW.Open("0.22.0")
H.check("the least height again", f:GetHeight(), 440)

-- An entry that vanishes while it is shown: a new language renders nothing.
News.ENTRIES["9.9.9"] = { lines = { "NEWS_0_22_0_RAID" } }
NW.Open("9.9.9")
News.ENTRIES["9.9.9"] = nil
ns.Config.Set("general", "language", "deDE")
H.check("vanished entry: title kept", f.titleBar.title:GetText(), "What's new in 9.9.9")
ns.Config.Set("general", "language", "AUTO")
NW.Close()

H.check("nothing printed", #M.chat, chatBefore)
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
