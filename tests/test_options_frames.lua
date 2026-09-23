local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local O, L = ns.Options, ns.L

local function rowKeys()
    local keys = {}
    for _, row in ipairs(O.rows) do if row.key then keys[row.key] = row end end
    return keys
end
local function tabIds(scope)
    local ids = {}
    for _, tab in ipairs(ns.Schema.Tabs(scope)) do ids[#ids + 1] = tab.id end
    return table.concat(ids, ",")
end

O.Open()
-- Navigation lists every frame.
for _, key in ipairs({ "player", "target", "targettarget", "pet", "focus", "party" }) do
    H.checkTrue("nav entry " .. key, O.navButtons[key])
    H.check("nav label " .. key, O.navButtons[key].text:GetText(), L["FRAME_" .. key])
end

-- Tabs per frame: no castbar for the pet.
H.check("player tabs", tabIds("player"), "layout,bars,text,castbar")
H.check("pet tabs", tabIds("pet"), "layout,bars,text")
H.check("party tabs", tabIds("party"), "layout,bars,text,castbar")

-- Party layout only on the party page; portrait everywhere.
O.Select("party")
O.SelectTab("layout")
local rows = rowKeys()
H.checkTrue("party: orientation row", rows.partyOrientation)
H.checkTrue("party: spacing row", rows.partySpacing)
H.checkTrue("party: show player row", rows.partyShowPlayer)
H.checkTrue("party: show solo row", rows.partyShowSolo)
H.checkTrue("party: block X", rows.x)
H.checkTrue("party: portrait", rows.portraitMode)
rows.partySpacing.edit:SetText("20")
rows.partySpacing.edit:GetScript("OnEnterPressed")(rows.partySpacing.edit)
H.check("spacing set through the window", ns.Config.Get("party", "partySpacing"), 20)
-- Party's own spacing plus room for its docked castbar (on by default).
H.check("header follows", ns.Party.header:GetAttribute("yOffset"), -(20 + ns.Castbar.DockedDepth("party")))

O.Select("player")
O.SelectTab("layout")
rows = rowKeys()
H.check("player: no party rows", rows.partySpacing, nil)
H.checkTrue("player: portrait style", rows.portraitStyle)

-- Castbar tab: detached position for single frames, dock for party.
O.SelectTab("castbar")
rows = rowKeys()
H.checkTrue("player castbar: position", rows.castbarPosition)
H.checkTrue("player castbar: detached X", rows.castbarX)
H.check("player castbar: no dock", rows.castbarDock, nil)
H.check("player castbar: off by default", rows.castbarEnabled.box:GetChecked(), false)
O.Select("party")
H.check("tab kept on party", O.currentTab, "castbar")
rows = rowKeys()
H.checkTrue("party castbar: dock", rows.castbarDock)
H.check("party castbar: no detached X", rows.castbarX, nil)
H.check("party castbar: no position", rows.castbarPosition, nil)
O.Select("pet")
H.check("pet falls back to its first tab", O.currentTab, "layout")

-- Selecting Party outlines the party block.
O.Select("party")
local hl = ns.Party.header.optionsHighlight
H.checkTrue("party highlight created", hl)
H.check("party highlight visible", hl[1]:GetAlpha(), 1)
M.RunTimers()

-- Every setting label fits the label column (mock: half the font size per
-- character at 12 px).
for _, def in ipairs(ns.Settings.All()) do
    local fs = M.newWidget("FontString")
    fs:SetFont("x", 12, "")
    fs:SetText(L["SETTING_" .. def.key])
    H.checkTrue("label fits: " .. def.key, fs:GetStringWidth() <= ns.Widgets.LABEL_MAX_W)
end

-- A label whose text changes is fitted again.
local row = ns.Widgets.Slider(CreateFrame("Frame", nil, UIParent), { label = "x", min = 0, max = 1, step = 1,
    get = function() return 0 end, set = function() return true end })
row:SetLabel(string.rep("W", 60))
H.check("long label limited", row.label:GetWidth(), ns.Widgets.LABEL_MAX_W)
row:SetLabel("Short")
H.check("short label back to its natural width", row.label:GetWidth(), 0)
