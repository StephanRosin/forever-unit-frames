local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

SlashCmdList.FOREVERUNITFRAMES("")
H.checkTrue("slash opens window", ns.Options.IsOpen())
local found = false
for _, name in ipairs(UISpecialFrames) do if name == "ForeverUnitFramesOptions" then found = true end end
H.checkTrue("ESC closes window", found)

-- General page, Appearance tab shows font settings
ns.Options.Select("general")
ns.Options.SelectTab("appearance")
local keys = {}
for _, row in ipairs(ns.Options.rows) do if row.key then keys[#keys + 1] = row.key end end
H.check("first general row", keys[1], "fontFace")

-- Frame page, Layout tab; slider edits config
ns.Options.Select("player")
ns.Options.SelectTab("layout")
local widthRow
for _, row in ipairs(ns.Options.rows) do if row.key == "width" then widthRow = row end end
H.checkTrue("width row exists", widthRow)
widthRow.edit:SetText("310")
widthRow.edit:GetScript("OnEnterPressed")(widthRow.edit)
H.check("width set through window", ns.Config.Get("player", "width"), 310)

-- Inherited font on frame page
ns.Options.SelectTab("text")
local sizeRow
for _, row in ipairs(ns.Options.rows) do if row.key == "fontSize" then sizeRow = row end end
H.checkTrue("font size inherited marker", sizeRow.inherited:IsShown())

-- Tab kept when switching frames
ns.Options.Select("target")
H.check("tab kept", ns.Options.currentTab, "text")

-- Live refresh from outside
ns.Options.SelectTab("layout")
SlashCmdList.FOREVERUNITFRAMES("set target width 280")
for _, row in ipairs(ns.Options.rows) do
    if row.key == "width" then H.check("row refreshed", row.edit:GetText(), "280") end
end

-- Combat lock
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
local wr
for _, row in ipairs(ns.Options.rows) do if row.key == "width" then wr = row end end
H.check("slider disabled in combat", wr.slider._enabled, false)
H.check("edit box disabled in combat", wr.edit._enabled, false)
H.checkTrue("combat notice shown", ns.Options.combatNotice:IsShown())
M.SetCombat(false)
H.check("slider enabled after combat", wr.slider._enabled, true)
H.check("combat notice hidden", ns.Options.combatNotice:IsShown(), false)

-- Export / import
ns.Options.Select("general")
ns.Options.SelectTab("profile")
H.checkTrue("export filled", ns.Options.exportArea:GetText():match("^1;"))
ns.Options.importArea:SetText("1;pW222")
ns.Options.importButton:GetScript("OnClick")(ns.Options.importButton)
H.check("import applied", ns.Config.Get("player", "width"), 222)
ns.Options.importArea:SetText("9;xx")
ns.Options.importButton:GetScript("OnClick")(ns.Options.importButton)
H.check("bad import keeps settings", ns.Config.Get("player", "width"), 222)

-- Position saved
local f = ns.Options.frame
f._points = { { "TOPLEFT", UIParent, "TOPLEFT", 100, -200 } }
f.titleBar:GetScript("OnDragStop")(f.titleBar)
H.check("window x saved", ForeverUnitFramesDB.window.x, 100)

SlashCmdList.FOREVERUNITFRAMES("")
H.check("slash toggles closed", ns.Options.IsOpen(), false)
SlashCmdList.FOREVERUNITFRAMES("help")
H.checkTrue("help printed", M.chat[#M.chat]:find("/fuf"))

-- Additional behaviour ------------------------------------------------------

local O, L = ns.Options, ns.L
local function click(button) button:GetScript("OnClick")(button) end
local function rowFor(key)
    for _, row in ipairs(O.rows) do if row.key == key then return row end end
end
local function hasAccentBorder(button)
    local c = button.edges[1]._color
    return c[1] == ns.Style.COLORS.accent[1] and c[3] == ns.Style.COLORS.accent[3]
end

-- Messages under the import button
O.Open("general", "profile")
O.importArea:SetText("1;pW230")
click(O.importButton)
H.check("import success message", O.importMessage:GetText(), L.IMPORT_DONE)
O.importArea:SetText("9;xx")
click(O.importButton)
H.check("import error message", O.importMessage:GetText(), L.IMPORT_CODEC_VERSION)
H.check("import error in red", O.importMessage._color[1], ns.Style.COLORS.error[1])
O.importArea:SetText("")
click(O.importButton)
H.check("empty import message", O.importMessage:GetText(), L.IMPORT_CODEC_EMPTY)

-- Open(scope, tab) and navigation highlight
O.Open("target", "bars")
H.check("open selects scope", O.currentScope, "target")
H.check("open selects tab", O.currentTab, "bars")
H.check("nav entry in accent", O.navButtons.target.text._color[1], ns.Style.COLORS.accent[1])
H.checkTrue("nav bar shown on selected", O.navButtons.target.bar:IsShown())
H.check("nav bar hidden on others", O.navButtons.general.bar:IsShown(), false)
H.checkTrue("selected tab underline", O.tabButtons[2].underline:IsShown())
H.check("other tab no underline", O.tabButtons[1].underline:IsShown(), false)

-- Tab falls back to the first one when the new scope lacks it
O.Select("general")
H.check("tab falls back", O.currentTab, "appearance")

-- Frame-only footer buttons
H.check("copy hidden on general", O.copyRow:IsShown(), false)
H.check("reset frame hidden on general", O.resetFrameButton:IsShown(), false)

-- Copy from
O.Select("target")
H.checkTrue("copy shown on frame page", O.copyRow:IsShown())
ns.Config.Set("player", "height", 60)
click(O.copyRow.button)
local list = ns.Widgets.list
H.checkTrue("copy list open", list:IsShown())
H.check("copy list offers other frames only", #list.items, #ns.Units.List - 1)
H.check("copy item is player", list.items[1].value, "player")
H.check("copy button keeps its label", O.copyRow.button.text:GetText(), L.COPY_FROM)
click(list.rows[1])
H.check("copy applied", ns.Config.Get("target", "height"), 60)
H.check("copy keeps position", ns.Config.Get("target", "x"), 300)
H.check("copy label after select", O.copyRow.button.text:GetText(), L.COPY_FROM)

-- Reset frame: two clicks
ns.Config.Set("target", "width", 333)
click(O.resetFrameButton)
H.check("reset frame asks to confirm", O.resetFrameButton.text:GetText(), L.CONFIRM)
H.check("first click does not reset", ns.Config.Get("target", "width"), 333)
click(O.resetFrameButton)
H.check("second click resets frame", ns.Config.Get("target", "width"), 220)
H.check("reset frame label restored", O.resetFrameButton.text:GetText(), L.RESET_FRAME)
ns.Config.Set("target", "width", 333)
click(O.resetFrameButton)
M.RunTimers()
H.check("confirm expires", O.resetFrameButton.text:GetText(), L.RESET_FRAME)
click(O.resetFrameButton)
H.check("click after expiry only arms", ns.Config.Get("target", "width"), 333)
O.Select("player")
H.check("switching frames disarms", O.resetFrameButton.text:GetText(), L.RESET_FRAME)
click(O.resetFrameButton)
H.check("player reset only armed", ns.Config.Get("target", "width"), 333)
M.RunTimers()

-- Reset all: two clicks
O.Open("general", "profile")
click(O.resetAllButton)
H.check("reset all asks to confirm", O.resetAllButton.text:GetText(), L.CONFIRM)
H.check("reset all waits", ns.Config.Get("target", "width"), 333)
click(O.resetAllButton)
H.check("reset all applied", ns.Config.Get("target", "width"), 220)
H.check("reset all label restored", O.resetAllButton.text:GetText(), L.RESET_ALL)

-- Test mode button
click(O.testButton)
H.checkTrue("test mode on from button", ns.TestMode.IsOn())
H.checkTrue("test button accent border", hasAccentBorder(O.testButton))
O.testButton:GetScript("OnLeave")(O.testButton)
H.checkTrue("accent border survives hover leave", hasAccentBorder(O.testButton))
click(O.testButton)
H.check("test mode off from button", ns.TestMode.IsOn(), false)
H.check("test button normal border", hasAccentBorder(O.testButton), false)

-- Unlock / lock button
H.check("unlock label", O.unlockButton.text:GetText(), L.UNLOCK_FRAMES)
click(O.unlockButton)
H.checkTrue("frames unlocked", ns.Movers.IsUnlocked())
H.check("lock label", O.unlockButton.text:GetText(), L.LOCK_FRAMES)
SlashCmdList.FOREVERUNITFRAMES("lock")
H.check("label follows /fuf lock", O.unlockButton.text:GetText(), L.UNLOCK_FRAMES)
click(O.unlockButton)
click(O.unlockButton)
H.check("button locks again", ns.Movers.IsUnlocked(), false)

-- Frame highlight
O.Select("player")
local hl = ns.Frames.player.optionsHighlight
H.checkTrue("highlight created", hl)
H.check("highlight visible", hl[1]:GetAlpha(), 1)
H.check("highlight accent", hl[1]._color[3], ns.Style.COLORS.accent[3])
M.RunTimers()
H.check("highlight faded out", hl[1]:GetAlpha(), 0)

-- List closes when the window hides
O.Open("general", "appearance")
local fontRow = rowFor("fontFace")
click(fontRow.button)
H.checkTrue("font list open", list:IsShown())
O.Close()
H.check("list closed with window", list:IsShown(), false)

-- Unknown subcommand prints help
SlashCmdList.FOREVERUNITFRAMES("bogus")
H.check("unknown prints help", M.chat[#M.chat]:find(L.HELP, 1, true) ~= nil, true)

-- Opening in combat shows the window locked; footer buttons too
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
O.Open("player", "layout")
H.checkTrue("notice when opened in combat", O.combatNotice:IsShown())
H.check("row locked when opened in combat", rowFor("width").slider._enabled, false)
H.check("footer locked in combat", O.testButton:IsEnabled(), false)
O.SelectTab("bars")
H.check("new page locked in combat", rowFor("cornerRadius").slider._enabled, false)
M.SetCombat(false)
H.checkTrue("footer unlocked after combat", O.testButton:IsEnabled())
O.Close()

-- Position: first open uses the default, a saved one is restored
ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
ns.Options.Open()
local p, rel, relP, x, y = ns.Options.frame:GetPoint(1)
H.check("default point", p, "TOPLEFT")
H.check("default x", x, 60)
H.check("default y", y, -120)
H.check("default relative", rel, UIParent)

ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
ForeverUnitFramesDB.window = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 10, y = 20 }
ns.Options.Open()
p, rel, relP, x, y = ns.Options.frame:GetPoint(1)
H.check("restored point", p, "BOTTOMLEFT")
H.check("restored relative point", relP, "BOTTOMLEFT")
H.check("restored x", x, 10)
H.check("restored y", y, 20)
H.check("window strata", ns.Options.frame:GetFrameStrata(), "HIGH")

-- Every header on the profile page is translated.
O = ns.Options
O.Open("general", "profile")
local headers = {}
for _, f in ipairs(M.frames) do
    if f.label and f.line and f.label:GetText() then headers[f.label:GetText()] = true end
end
H.checkTrue("profile reset header translated", headers[ns.L.RESET] and ns.L.RESET == "Reset")
H.check("no raw RESET key shown", headers.RESET, nil)
