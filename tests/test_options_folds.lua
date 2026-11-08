-- The tidier options (plan 2026-11-08): placement rows fold under one row
-- per section, closed until clicked; the search opens a fold; the party
-- page names its tabs its own way; the click-casting switch sits on top of
-- the click-casting tab; the profiles page says profiles are shared.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.RaidProfiles.Attach({})
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Options, L = ns.Options, ns.L

local function rowFor(key)
    for _, row in ipairs(Options.page.rows) do
        if row.key == key then return row end
    end
end
local function folds()
    local list = {}
    for _, row in ipairs(Options.page.rows) do
        if row.isFold then list[#list + 1] = row end
    end
    return list
end
local function click(b) b:GetScript("OnClick")(b) end

-- Every placement key belongs to its section.
for _, scope in ipairs({ "general", "player", "target", "party" }) do
    for _, tab in ipairs(ns.Schema.Tabs(scope)) do
        for _, sec in ipairs(tab.sections or {}) do
            local inSection = {}
            for _, key in ipairs(sec.keys or {}) do inSection[key] = true end
            for _, key in ipairs(sec.placement or {}) do
                H.checkTrue(sec.id .. ": " .. key .. " is the section's", inSection[key])
            end
        end
    end
end

-- Closed at first: the switch shows, the placement rows do not.
Options.Open("player", "auras")
local before = Options.page.height
H.checkTrue("folds on the auras tab", #folds() >= 4)
H.check("the fold's word", folds()[1].label:GetText(), "+ " .. L.FOLD_PLACEMENT)
H.check("switch shown", rowFor("buffsEnabled"):IsShown(), true)
H.check("anchor folded away", rowFor("buffsAnchor"):IsShown(), false)
H.check("offset folded away", rowFor("buffsX"):IsShown(), false)
H.check("size not folded", rowFor("buffsSize"):IsShown(), true)

-- A click opens it: the rows show, the page grows.
local fold = rowFor("buffsAnchor").fold
click(fold.button)
H.check("open: anchor shown", rowFor("buffsAnchor"):IsShown(), true)
H.check("open: the fold's word", fold.label:GetText(), "- " .. L.FOLD_PLACEMENT)
H.checkTrue("open: the page grows", Options.page.height > before)
H.check("the other folds stay closed", rowFor("debuffsAnchor"):IsShown(), false)
click(fold.button)
H.check("closed again", rowFor("buffsAnchor"):IsShown(), false)
H.check("height back", Options.page.height, before)

-- The search opens the fold of the row it shows.
local box = Options.searchBox
box:SetText(L.SETTING_debuffsGrowth)
local picked
for _, row in ipairs(box.list.rows) do
    if row:IsShown() and row.entry.key == "debuffsGrowth" and row.entry.scope == "player" then picked = row end
end
H.checkTrue("found by the search", picked)
if picked then click(picked) end
H.check("search: the fold opened", rowFor("debuffsGrowth"):IsShown(), true)
box:SetText("")

-- Party: its own tab names.
Options.Open("party", "layout")
local words = {}
for _, b in ipairs(Options.tabButtons) do
    if b:IsShown() then words[b.tabId] = b.text:GetText() end
end
H.check("party: Layout is Frame", words.layout, L.TAB_layout_party)
H.check("party: Group layout", words.group, L.TAB_group)
Options.Open("player", "layout")
for _, b in ipairs(Options.tabButtons) do
    if b:IsShown() and b.tabId == "layout" then H.check("player keeps Layout", b.text:GetText(), L.TAB_layout) end
end

-- Click-casting: the unit frames' switch first, above the editor.
Options.Open("general", "clickCast")
local first
for _, row in ipairs(Options.page.rows) do
    if row.key and not first then first = row end
end
H.check("click-casting: the switch first", first and first.key, "clickCast")
H.check("click-casting: the unit frames' own", first and first.clickCastRow, nil)

-- Profiles: shared by every character.
Options.Open("profiles")
local note
for _, row in ipairs(Options.page.rows) do
    if row.isNote then note = row.text:GetText() end
end
H.check("profiles: the note", note, L.PROFILES_NOTE)

-- Every language names the new sections and the fold.
for code, t in pairs(ns.Locales) do
    for _, key in ipairs({ "SECTION_visibility", "SECTION_threat", "SECTION_buffsOwn", "SECTION_debuffsOwn",
        "TAB_layout_party", "FOLD_PLACEMENT", "PROFILES_NOTE", "HINT_portraitStyle" }) do
        H.checkTrue(code .. " " .. key, type(t[key]) == "string" and t[key] ~= "")
    end
end
