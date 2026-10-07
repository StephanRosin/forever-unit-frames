-- The unit frames' window: a note above a tab's sections (Options/Schema
-- .lua: tab.note) says once what concerns the whole tab: what the Info
-- text shows (Text), that the raid window's click-casting may act on the
-- party frames (Group), how a point on the frame and an own point place
-- an icon (Status). The texts' rows carry no repeated Info hint; the
-- menu review's hints exist in every language.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local O, L = ns.Options, ns.L

local function width(text, size)
    local fs = M.newWidget("FontString")
    fs:SetFont("x", size, "")
    fs:SetText(text)
    return fs:GetStringWidth()
end

local function rowFor(key)
    for _, row in ipairs(O.rows) do
        if row.key == key then return row end
    end
end

O.Open()
for _, case in ipairs({ { "party", "group", "partyClickCast" }, { "player", "text", "texts" },
    { "target", "text", "texts" }, { "player", "status", "points" }, { "pet", "status", "points" } }) do
    local scope, tab, note = case[1], case[2], case[3]
    O.Select(scope)
    O.SelectTab(tab)
    local first = O.rows[1]
    H.checkTrue(scope .. " " .. tab .. ": a note first", first and first.isNote)
    H.check(scope .. " " .. tab .. ": its words", first and first.text:GetText(), L["NOTE_" .. note])
end
O.Select("general")
O.SelectTab("status")
H.checkTrue("General: no note", not O.rows[1].isNote)

-- Every note fits two lines of the page, in every language.
for _, tab in ipairs(ns.Schema.FRAME) do
    if tab.note then
        for code, t in pairs(ns.Locales) do
            local text = t["NOTE_" .. tab.note]
            H.checkTrue(code .. " note " .. tab.note, type(text) == "string" and text ~= "")
            H.checkTrue(code .. " note fits " .. tab.note, width(text or "", 11) <= 2 * O.NOTE_W)
        end
    end
end

-- Info is explained once: the texts' rows have no hint of it.
O.Select("player")
O.SelectTab("text")
for _, key in ipairs({ "titleText", "titleTextRight", "textHealthLeft", "textHealthRight", "textPowerLeft",
    "textPowerRight" }) do
    H.checkTrue("no Info hint: " .. key, rowFor(key).hintText == nil)
end
H.checkTrue("the centre texts keep theirs", rowFor("textHealthCenter").hintText ~= nil)

-- The review's hints, in every language.
for code, t in pairs(ns.Locales) do
    for _, key in ipairs({ "HINT_healthColorMode", "HINT_titleColorMode", "HINT_castbarPosition",
        "HINT_playerFadeAlpha", "HINT_threatBarRole", "HINT_rangeAlpha", "RAID_HINT_rangeFade",
        "RAID_HINT_dispelFilter", "RAID_HINT_indicatorTime", "RAID_HINT_indicatorOwn", "RAID_HINT_combatText",
        "RAID_HINT_panelBorder", "RAID_HINT_blockTitles", "RAID_HINT_buffWatchOnlyMissing" }) do
        H.checkTrue(code .. " " .. key, type(t[key]) == "string" and t[key] ~= "")
    end
end
H.check("show yourself", ns.Locales.enUS.SETTING_partyShowPlayer, "Show yourself")
H.check("dich selbst", ns.Locales.deDE.SETTING_partyShowPlayer, "Dich selbst anzeigen")
H.check("the raid's range: measured as the unit frames'", ns.Locales.enUS.RAID_HINT_rangeFade,
    "Measured as in the unit frames: General > Status > Range")

-- The wiki says the notes too.
local fh = io.open(ADDONDIR .. "/docs/wiki/Settings-Group.md")
local page = fh and fh:read("*a") or ""
if fh then fh:close() end
H.checkTrue("wiki: the party's click-casting note", page:find(ns.Locales.enUS.NOTE_partyClickCast, 1, true) ~= nil)
H.check("no error", #M.errors, 0)
