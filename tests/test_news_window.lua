-- The What's New window (Options/News.lua) and the news it shows
-- (Core/News.lua): one line per entry, in the style of the options
-- windows; the entry's action button and Close; ESC; the language; the
-- list scrolling when it is taller than the window; the bug report
-- address.
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
H.check("addon name", f.titleBar.sub:GetText(), "Forever Unit Frames")
H.check("strata of the options windows", f:GetFrameStrata(), "HIGH")
H.check("bordered like them", f.edges[1]._color[1], ns.Style.COLORS.border[1])
H.check("not protected", f:IsProtected(), false)
local escCount = 0
for _, name in ipairs(UISpecialFrames) do if name == "ForeverUnitFramesNews" then escCount = escCount + 1 end end
H.check("ESC closes it", escCount, 1)
local LINES = #News.Entry("0.22.0").lines
H.check("sixteen lines", shownLines(), 16)
H.check("raid frames first", NW.lines[1].text:GetText(), L.NEWS_0_22_0_RAID)
H.check("the raid's last line", NW.lines[12].text:GetText(), L.NEWS_0_22_0_BLIZZARD)
H.check("then the unit frames", NW.lines[13].text:GetText(), L.NEWS_0_22_0_UNITS)
H.check("the raid frames' emergency switch", NW.lines[15].text:GetText(), L.NEWS_0_22_0_RAID_OFF)
H.checkTrue("it names /fuf raid off", L.NEWS_0_22_0_RAID_OFF:find("/fuf raid off", 1, true))
-- The shipped look's changes (decision 70), last.
H.check("the last line: the unit frames' look", NW.lines[LINES].text:GetText(), L.NEWS_0_22_0_LOOK)
-- The top bar of the raid window as it reads now.
H.checkTrue("the window line names the top bar", L.NEWS_0_22_0_WINDOW:find("General | 10 | 20 | 40 | Profiles", 1, true))
for _, code in ipairs({ "deDE", "frFR", "esES" }) do
    local tr = ns.Locales[code]
    H.checkTrue(code .. ": the window line names the top bar",
        tr.NEWS_0_22_0_WINDOW:find(tr.RAID_TAB_general .. " | 10 | 20 | 40 | " .. tr.RAID_PROFILES_TAB, 1, true))
end
H.checkTrue("it names the faded opacity", L.NEWS_0_22_0_LOOK:find("25", 1, true))
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
H.check("all lines again", shownLines(), LINES)
H.checkTrue("action button again", NW.actionButton:IsShown())
News.ENTRIES["9.9.9"] = nil
NW.Close()

-- The action button fits its label: at least the wide button, wider for a
-- longer label, never into the footer hint's least width (140).
local enUS = ns.Locales.enUS
local function labelFits()
    local b = NW.actionButton
    return b:GetWidth() >= b.text:GetStringWidth() and b:GetWidth() >= 160
        and b:GetWidth() <= 560 - 12 - NW.closeButton:GetWidth() - 8 - 8 - 140 - 16
end
NW.Open("0.22.0")
H.check("English label: wide button", NW.actionButton:GetWidth(), 160)
for _, code in ipairs({ "deDE", "frFR", "esES" }) do
    ns.Config.Set("general", "language", code)
    H.checkTrue(code .. " label fits", labelFits())
end
ns.Config.Set("general", "language", "AUTO")
local openRaid = enUS.NEWS_OPEN_RAID
enUS.NEWS_OPEN_RAID = "Open the raid frame options now"
NW.Open("0.22.0")
H.checkTrue("a longer label: wider", NW.actionButton:GetWidth() > 160)
H.checkTrue("a longer label fits", labelFits())
-- However long the label, the footer hint keeps room left of the button.
enUS.NEWS_OPEN_RAID = string.rep("Open the raid frame options window ", 6)
NW.Open("0.22.0")
local hintRoom = 560 - 12 - NW.closeButton:GetWidth() - 8 - NW.actionButton:GetWidth() - 8 - 16
H.checkTrue("a very long label: the hint keeps room", hintRoom >= 140)
enUS.NEWS_OPEN_RAID = openRaid
NW.Open("0.22.0")
H.check("the wide button again", NW.actionButton:GetWidth(), 160)

-- The window grows with its list, between 440 and 600; a longer list
-- scrolls: the view is what the window leaves between the title bar and
-- the bug report area, the rest is the scroll range.
local FIXED = 32 + 16 + 16 + 52 + 40
local function listHeight(count)
    local h = 0
    for i = 1, count do h = h + NW.lines[i].text:GetStringHeight() end
    return h + (count - 1) * 8
end
local function listFits(count)
    local list = listHeight(count)
    local view = NW.scroll:GetHeight()
    return f:GetHeight() == math.min(600, math.max(440, FIXED + list)) and view == f:GetHeight() - FIXED
        and NW.listChild:GetHeight() == list and NW.scrollRange == math.max(0, list - view)
end
for _, code in ipairs({ "enUS", "deDE", "frFR", "esES" }) do
    ns.Config.Set("general", "language", code == "enUS" and "AUTO" or code)
    H.checkTrue(code .. ": the list fits or scrolls", listFits(LINES))
end
ns.Config.Set("general", "language", "AUTO")
H.check("the long list: the most height", f:GetHeight(), 600)
H.checkTrue("it scrolls", NW.scrollRange > 0)
H.checkTrue("its bar shows", NW.scrollThumb:IsShown())
H.check("from the top", NW.scroll:GetVerticalScroll(), 0)
H.check("lines in the scroll child", NW.lines[1].text:GetParent(), NW.listChild)
local wheel = NW.scroll:GetScript("OnMouseWheel")
wheel(NW.scroll, -1)
H.check("the wheel scrolls down", NW.scroll:GetVerticalScroll(), 20)
wheel(NW.scroll, 1); wheel(NW.scroll, 1)
H.check("not above the top", NW.scroll:GetVerticalScroll(), 0)
for _ = 1, 200 do wheel(NW.scroll, -1) end
H.check("not below the end", NW.scroll:GetVerticalScroll(), NW.scrollRange)
NW.Open("0.22.0")
H.check("opening again: from the top", NW.scroll:GetVerticalScroll(), 0)
-- A short list: the least height, nothing to scroll.
News.ENTRIES["9.9.9"] = { lines = { "NEWS_0_22_0_RAID", "NEWS_0_22_0_ICONS" } }
NW.Open("9.9.9")
H.check("short list: the least height", f:GetHeight(), 440)
H.checkTrue("short list: it fits", listFits(2))
H.check("short list: no scrolling", NW.scrollRange, 0)
H.check("short list: no bar", NW.scrollThumb:IsShown(), false)
local raidLine = enUS.NEWS_0_22_0_RAID
enUS.NEWS_0_22_0_RAID = string.rep("A much longer line. ", 80)
NW.Open("9.9.9")
H.checkTrue("taller lines: taller window", f:GetHeight() > 440)
H.checkTrue("taller lines: the list fits", listFits(2))
enUS.NEWS_0_22_0_RAID = string.rep("A much longer line. ", 300)
NW.Open("9.9.9")
H.check("at most 600", f:GetHeight(), 600)
H.checkTrue("at most 600: it scrolls", listFits(2) and NW.scrollRange > 0)
enUS.NEWS_0_22_0_RAID = raidLine
NW.Open("9.9.9")
H.check("the least height again", f:GetHeight(), 440)
News.ENTRIES["9.9.9"] = nil

-- Where to report a bug: a hint and the address, selected in full on
-- focus and on a click so Ctrl+C copies it, put back when typed over.
NW.Open("0.22.0")
local box = NW.bugAddress
H.check("bug hint", NW.bugHint:GetText(), "Found a bug or a Lua error? Please tell us:")
H.check("the address", box:GetText(), "foreverwowui@gmail.com")
H.check("it does not take the focus by itself", box._autoFocus, false)
H.checkTrue("above the footer", select(2, f.report:GetPoint(1)) == f.footer)
box:SetFocus(); box:GetScript("OnEditFocusGained")(box)
H.check("focus selects it all", box._highlighted and #box._highlighted, 0)
box._highlighted = nil
box:GetScript("OnMouseUp")(box, "LeftButton")
H.checkTrue("a click selects it all", box._highlighted and box._highlighted[1] == nil)
M.Type(box, "foreverwowui@gmail.co")
H.check("typed over: put back", box:GetText(), "foreverwowui@gmail.com")
H.checkTrue("typed over: selected again", box._highlighted and box._highlighted[1] == nil)
H.checkTrue("Enter lets go", M.PressEnter(box) and not box:HasFocus())
box:SetFocus()
H.checkTrue("ESC lets go", M.PressEscape(box) and not box:HasFocus())
H.checkTrue("the window stays", NW.IsOpen())
M.LeaveBox(box)
H.check("leaving: nothing selected", box._highlighted[1], 0)
for _, code in ipairs({ "deDE", "frFR", "esES" }) do
    ns.Config.Set("general", "language", code)
    H.check(code .. " bug hint", NW.bugHint:GetText(), ns.Locales[code].NEWS_BUG)
    H.check(code .. ": the address stays", box:GetText(), "foreverwowui@gmail.com")
end
ns.Config.Set("general", "language", "AUTO")
NW.Close()

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
