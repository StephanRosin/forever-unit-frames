local M = H.M

-- Every language against English --------------------------------------------

local ns = H.LoadAddon()
local base = ns.Locales.enUS
local LANGUAGES = { "deDE", "esES", "frFR" }

-- The % specifiers of a string in order, "%%" left out.
local function specifiers(s)
    local list = {}
    for spec in s:gsub("%%%%", ""):gmatch("%%[%-%+ #0]*%d*%.?%d*[a-zA-Z]") do list[#list + 1] = spec end
    return table.concat(list, " ")
end

for _, code in ipairs(LANGUAGES) do
    local t = ns.Locales[code]
    H.checkTrue(code .. " loaded", type(t) == "table")
    t = t or {}
    for key, english in pairs(base) do
        local v = t[key]
        H.checkTrue(code .. " has " .. key, type(v) == "string" and v ~= "")
        if type(v) == "string" then
            H.check(code .. " placeholders of " .. key, specifiers(v), specifiers(english))
        end
    end
    for key in pairs(t) do
        H.checkTrue(code .. " key " .. key .. " exists in English", base[key] ~= nil)
    end
    -- Language names are shown in their own language everywhere.
    for _, name in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
        H.check(code .. " names " .. name .. " in itself", t["ENUM_language_" .. name], base["ENUM_language_" .. name])
    end
end
-- Labels fit the label column like the English ones (mock: half the font
-- size per character, test_options_frames.lua); a hint is no longer than
-- the longest English hint.
local function width(text, size)
    local fs = M.newWidget("FontString")
    fs:SetFont("x", size, "")
    fs:SetText(text)
    return fs:GetStringWidth()
end
local longestHint = 0
for key, v in pairs(base) do
    if key:match("^HINT_") then longestHint = math.max(longestHint, width(v, 10)) end
end
for _, code in ipairs(LANGUAGES) do
    for key, v in pairs(ns.Locales[code] or {}) do
        if key:match("^SETTING_") then
            H.checkTrue(code .. " label fits: " .. key, width(v, 12) <= ns.Widgets.LABEL_MAX_W)
        elseif key:match("^HINT_") then
            H.checkTrue(code .. " hint fits: " .. key, width(v, 10) <= longestHint)
        end
    end
end

H.check("placeholder scan", specifiers("Client %s (build %s), interface %d, %.1f%%"), "%s %s %d %.1f")

-- Every language the setting offers has a table (AUTO aside).
for _, v in ipairs(ns.Settings.Get("language").values) do
    if v ~= "AUTO" then H.checkTrue("table for " .. v, ns.Locales[v]) end
end

-- AUTO mapping ------------------------------------------------------------------

local Locale = ns.Locale
H.check("AUTO on deDE", Locale.Resolve("AUTO", "deDE"), "deDE")
H.check("AUTO on esES", Locale.Resolve("AUTO", "esES"), "esES")
H.check("AUTO on esMX", Locale.Resolve("AUTO", "esMX"), "esES")
H.check("AUTO on frFR", Locale.Resolve("AUTO", "frFR"), "frFR")
H.check("AUTO on enUS", Locale.Resolve("AUTO", "enUS"), "enUS")
H.check("AUTO on enGB", Locale.Resolve("AUTO", "enGB"), "enUS")
H.check("AUTO on ruRU", Locale.Resolve("AUTO", "ruRU"), "enUS")
H.check("AUTO on nil", Locale.Resolve("AUTO", nil), "enUS")
H.check("explicit wins over the game", Locale.Resolve("frFR", "deDE"), "frFR")
H.check("explicit English on a German client", Locale.Resolve("enUS", "deDE"), "enUS")
H.check("unknown value follows the game", Locale.Resolve("xxXX", "deDE"), "deDE")

-- Tests run in English by default.
H.check("default language", Locale.Current(), "enUS")
H.check("default text", ns.L.STATUS_DEAD, "Dead")

-- Switching and fallback ----------------------------------------------------------

M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local L, C = ns.L, ns.Config
local changes = {}
ns.Listen("LANGUAGE_CHANGED", function(code) changes[#changes + 1] = code end)

C.Set("general", "language", "deDE")
H.check("switched", Locale.Current(), "deDE")
H.check("event fired once", #changes, 1)
H.check("event names the language", changes[1], "deDE")
H.check("German text", L.STATUS_DEAD, "Tot")
H.check("German frame name", L.FRAME_targettarget, "Ziel des Ziels")
H.check("status word follows", ns.UnitStatus.Word("OFFLINE"), "Offline")

C.Set("general", "width", 1) -- no-op for general, other keys never switch
C.Set("player", "width", 250)
H.check("other settings fire no language change", #changes, 1)

-- A string missing from a translation shows the English one.
local saved = ns.Locales.deDE.STATUS_GHOST
ns.Locales.deDE.STATUS_GHOST = nil
H.check("fallback to English", L.STATUS_GHOST, "Ghost")
ns.Locales.deDE.STATUS_GHOST = saved
H.check("unknown key shows the key", L.NO_SUCH_KEY, "NO_SUCH_KEY")
H.checkError("ns.L is read-only", function() L.NEW = "x" end)

C.Set("general", "language", "esES")
H.check("Spanish", L.FRAME_pet, "Mascota")
C.Set("general", "language", "frFR")
H.check("French", L.FRAME_target, "Cible")
C.Set("general", "language", "enUS")
H.check("English", L.FRAME_target, "Target")

-- AUTO follows the game's language.
M.locale = "esMX"
C.Set("general", "language", "AUTO")
H.check("AUTO on esMX speaks Spanish", L.STATUS_DEAD, "Muerto")
C.ResetAll()
H.check("reset keeps AUTO", Locale.Current(), "esES")
M.locale = "enUS"
C.Set("general", "language", "enUS")
C.ResetAll()
H.check("reset back to AUTO (English client)", L.STATUS_DEAD, "Dead")

-- Import keeps the reader's own language.
C.Set("general", "language", "frFR")
C.Import(assert(ns.Codec.Decode("1;gLN3;pW260")))
H.check("import keeps own language", C.Get("general", "language"), "frFR")
H.check("import applies the rest", C.Get("player", "width"), 260)
C.Set("general", "language", "AUTO")
C.Import(assert(ns.Codec.Decode("1;gLN3")))
H.check("import keeps own AUTO", C.Get("general", "language"), "AUTO")
H.check("still English", Locale.Current(), "enUS")

-- Codec -----------------------------------------------------------------------------

local def = ns.Settings.Get("language")
H.check("code", def.code, "LN")
H.check("default", def.default, "AUTO")
H.check("general only", ns.Settings.AppliesTo(def, "player"), false)
for i, v in ipairs(def.values) do
    local p = ns.Codec.Decode("1")
    p.general.language = v
    local s = ns.Codec.Encode(p)
    H.check("encode " .. v, s, "1;gLN" .. i)
    H.check("round trip " .. v, ns.Codec.Decode(s).general.language, v)
end
H.check("append-only order", table.concat(def.values, ","), "AUTO,enUS,deDE,esES,frFR")

-- Boot: the saved choice, applied before anything is built -------------------------

ns = H.LoadAddon()
ForeverUnitFramesDB = { profile = { general = { language = "deDE" } } }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.check("saved choice applied at login", ns.Locale.Current(), "deDE")
H.check("mover label built in German", ns.Frames.target.mover.label:GetText(), "Ziel")
H.check("party mover in German", ns.Party.header.mover.label:GetText(), "Gruppe")
H.check("castbar mover in German", ns.Frames.target.castbar.mover.label:GetText(), "Zauberleiste: Ziel")
ns.Config.Set("general", "language", "frFR")
M.FireEvent("PLAYER_LOGOUT")
H.check("choice saved", ForeverUnitFramesDB.profile.general.language, "frFR")
H.check("movers relabelled", ns.Frames.target.mover.label:GetText(), "Cible")
H.check("castbar mover relabelled", ns.Frames.target.castbar.mover.label:GetText(), "Barre d'incantation : Cible")

-- After /reload.
local db = ForeverUnitFramesDB
ns = H.LoadAddon()
ForeverUnitFramesDB = db
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.check("choice survives reload", ns.Locale.Current(), "frFR")

-- AUTO on a German client, nothing saved yet.
ns = H.LoadAddon()
M.locale = "deDE"
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.check("AUTO at login on a German client", ns.Locale.Current(), "deDE")
H.check("player mover in German", ns.Frames.player.mover.label:GetText(), "Spieler")

-- Options window: the dropdown in the navigation ------------------------------------

ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local O = ns.Options
O.Open("player", "castbar")
local oldFrame = O.frame
local row = O.languageRow
H.checkTrue("language dropdown exists", row)
H.checkTrue("it sits in the navigation", row:GetParent() == O.navButtons.general:GetParent())
H.check("anchored to the bottom", (row:GetPoint(1)), "BOTTOMLEFT")
H.check("label", row.label:GetText(), "Language")
H.check("shows the game language", row.button.text:GetText(), "Game language")
row.button:GetScript("OnClick")(row.button)
local list = row.list
H.checkTrue("list open", list:IsShown())
H.check("list opens upwards", (list:GetPoint(1)), "BOTTOMLEFT")
local names = {}
for _, r in ipairs(list.rows) do if r:IsShown() then names[#names + 1] = r.text:GetText() end end
H.check("choices in their own language", table.concat(names, ","), "Game language,English,Deutsch,Español,Français")
list.rows[3]:GetScript("OnClick")(list.rows[3])
H.check("picked German", ns.Config.Get("general", "language"), "deDE")
H.checkTrue("window rebuilt", O.frame ~= oldFrame)
H.check("old window hidden", oldFrame:IsShown(), false)
H.checkTrue("new window open", O.IsOpen())
H.check("page kept", O.currentScope, "player")
H.check("tab kept", O.currentTab, "castbar")
H.check("nav in German", O.navButtons.general.text:GetText(), "Allgemein")
H.check("frame nav in German", O.navButtons.targettarget.text:GetText(), "Ziel des Ziels")
H.check("tab in German", O.tabButtons[1].text:GetText(), "Anordnung")
H.check("footer in German", O.unlockButton.text:GetText(), "Rahmen entsperren")
H.check("new dropdown label", O.languageRow.label:GetText(), "Sprache")
H.check("new dropdown value", O.languageRow.button.text:GetText(), "Deutsch")
local rowLabel
for _, r in ipairs(O.rows) do if r.key == "castbarEnabled" then rowLabel = r.label:GetText() end end
H.check("setting row in German", rowLabel, "Zauberleiste anzeigen")
local count = 0
for _, name in ipairs(UISpecialFrames) do if name == "ForeverUnitFramesOptions" then count = count + 1 end end
H.check("ESC entry not doubled", count, 1)

-- The dropdown follows a change from elsewhere, and locks in combat.
ns.Config.Set("general", "language", "AUTO")
H.check("back to English", O.navButtons.general.text:GetText(), "General")
H.check("dropdown shows AUTO", O.languageRow.button.text:GetText(), "Game language")
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("locked in combat", O.languageRow.button:IsEnabled(), false)
M.SetCombat(false)
H.check("unlocked after combat", O.languageRow.button:IsEnabled(), true)

-- A closed window is rebuilt closed.
O.Close()
local closedFrame = O.frame
ns.Config.Set("general", "language", "frFR")
H.check("stays closed", O.IsOpen(), false)
O.Open()
H.checkTrue("reopened window is new", O.frame ~= closedFrame)
H.check("reopened in French", O.navButtons.general.text:GetText(), "Général")
