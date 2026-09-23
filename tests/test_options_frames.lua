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
local function rowIndex(key)
    for i, row in ipairs(O.rows) do if row.key == key then return i end end
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
H.check("player tabs", tabIds("player"), "layout,bars,text,auras,castbar")
H.check("pet tabs", tabIds("pet"), "layout,bars,text,auras")
H.check("party tabs", tabIds("party"), "layout,bars,text,auras,castbar")

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

-- Selecting Party outlines the whole block, not the raw header: solo
-- without "show when solo" the header is a sliver of a pixel tall.
O.Select("party")
local target = ns.Party.HighlightTarget()
H.checkTrue("party highlight: not the header", target ~= ns.Party.header)
local bw, bh = ns.Party.BlockSize()
H.check("party highlight: block width", target:GetWidth(), bw)
H.check("party highlight: block height", target:GetHeight(), bh)
local point, rel, relPoint = target:GetPoint(1)
H.check("party highlight: hangs from", point, "TOPLEFT")
H.check("party highlight: the block mover", rel, ns.Party.header.mover)
H.check("party highlight: its top left", relPoint, "TOPLEFT")
H.check("party highlight: plain frame", target:IsProtected(), false)
local hl = target.optionsHighlight
H.checkTrue("party highlight created", hl)
H.check("party highlight visible", hl[1]:GetAlpha(), 1)
M.RunTimers()
ns.Config.Set("party", "partySpacing", 30)
O.Select("party")
H.check("party highlight follows the block size", target:GetHeight(), select(2, ns.Party.BlockSize()))
M.RunTimers()

-- hideBlizzardCastbar only shows on the player page, below "Show
-- castbar"; switching it off brings Blizzard's back only after a
-- /reload, so the row says so there.
O.Select("player")
O.SelectTab("castbar")
rows = rowKeys()
H.checkTrue("player castbar: hide-Blizzard row", rows.hideBlizzardCastbar)
H.checkTrue("player castbar: hide row below enabled", rowIndex("hideBlizzardCastbar") > rowIndex("castbarEnabled"))
H.check("player castbar: reload hint",
    rows.hideBlizzardCastbar.hintText and rows.hideBlizzardCastbar.hintText:GetText(),
    L.HINT_hideBlizzardCastbar)
H.check("reload hint text", L.HINT_hideBlizzardCastbar, "Needs /reload to show it again")
H.check("castbarEnabled no longer hints", rows.castbarEnabled.hintText, nil)
H.checkTrue("reload hint fits",
    rows.hideBlizzardCastbar.hintText.GetStringWidth({ _text = L.HINT_hideBlizzardCastbar, _font = { nil, 10 } })
        <= ns.Widgets.LABEL_MAX_W)
for _, scope in ipairs({ "target", "party" }) do
    O.Select(scope)
    O.SelectTab("castbar")
    H.check(scope .. " castbar: no hide-Blizzard row", rowKeys().hideBlizzardCastbar, nil)
end

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
