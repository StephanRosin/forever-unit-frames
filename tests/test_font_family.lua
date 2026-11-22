-- Names in other alphabets: every text gets a font family around the
-- chosen file (Media.Family), so Cyrillic, Hangul and Hanzi come from the
-- client's files while Latin keeps the chosen font. Without families
-- (older clients) the file alone, as before.
local M = H.M
local made = {}
_G.CreateFontFamily = function(name, members)
    local family = { name = name, members = members }
    made[#made + 1] = family
    return family
end
local ns = H.LoadAddon()
M.units.player = { name = "Тест", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Media, C = ns.Media, ns.Config

local function byAlphabet(family)
    local out = {}
    for _, m in ipairs(family.members) do out[m.alphabet] = m end
    return out
end

-- Cyrillic per file: Blizzard's own _CYR twin, the file itself where it
-- has Cyrillic, else Friz Quadrata's.
H.check("Friz: its _CYR twin", Media.CyrillicFor("Fonts\\FRIZQT__.TTF"), "Fonts\\FRIZQT___CYR.TTF")
H.check("Morpheus: its twin", Media.CyrillicFor("Fonts\\MORPHEUS.ttf"), "Fonts\\MORPHEUS_CYR.TTF")
H.check("Arial Narrow has Cyrillic", Media.CyrillicFor("Fonts\\ARIALN.TTF"), "Fonts\\ARIALN.TTF")
H.check("any other font: Friz's", Media.CyrillicFor("Interface\\AddOns\\SharedMedia\\fonts\\bignoodle.ttf"),
    "Fonts\\FRIZQT___CYR.TTF")

local text = ns.Frames.player.texts.titleLeft or ns.Frames.player.texts.healthLeft
local family = text._fontObject
H.checkTrue("a text has a family", family ~= nil and family.members ~= nil)
local m = byAlphabet(family)
H.check("Latin: the chosen file", m.roman.file, text._font[1])
H.check("Cyrillic: the twin", m.russian.file, Media.CyrillicFor(text._font[1]))
H.check("Korean too", m.korean.file, "Fonts\\2002.TTF")
H.check("same size", m.russian.height, text._font[2])
H.check("same flags", m.russian.flags, text._font[3])

-- One family per file, size and flags: restyles reuse it.
local count = #made
C.Set("player", "width", 251)
H.check("restyle: no new families", #made, count)
H.checkTrue("same family again", Media.Family(text._font[1], text._font[2], text._font[3]) == family)
C.Set("player", "fontSize", 19)
H.checkTrue("a new size: a new family", text._fontObject ~= family and text._fontObject.members[1].height == 19)

-- Only the family, never the file first: a file set with SetFont wins
-- over any font object for good (in game).
local fs = ns.Frames.player:CreateFontString()
local filed = 0
local raw = fs.SetFont
fs.SetFont = function(self, ...) filed = filed + 1; return raw(self, ...) end
ns.Texts.SetFont(fs, "Fonts\\FRIZQT__.TTF", 15, "NONE")
M.RunTimers()
H.check("no SetFont on the text", filed, 0)
H.checkTrue("its family", fs._fontObject and fs._fontObject.members[1].file == "Fonts\\FRIZQT__.TTF")

-- A Cyrillic text: the client reports the _CYR file; that counts as taken.
H.check("the twin counts", Media.InFamily("Fonts\\FRIZQT__.TTF", "Fonts\\FRIZQT___CYR.TTF"), true)
H.check("Korean too", Media.InFamily("Fonts\\FRIZQT__.TTF", "fonts/2002.ttf"), true)
H.check("another file does not", Media.InFamily("Fonts\\FRIZQT__.TTF", "Fonts\\ARIALN.TTF"), false)

-- The shadow survives the redraw a little after a new font (CurseForge
-- 22.11.2026: after a relog the shadow was gone, though ticked): a font
-- object brings its own shadow, none.
C.Set("player", "fontShadow", true)
C.Set("player", "fontFace", "Arial Narrow")
M.RunTimers()
local shadowed = ns.Frames.player.texts.healthLeft
H.check("shadow kept after the redraw", select(1, shadowed:GetShadowOffset()), 1)
H.check("shadow kept: below", select(2, shadowed:GetShadowOffset()), -1)

-- A client without families: the file alone.
_G.CreateFontFamily = nil
H.check("no families: nil", Media.Family("Fonts\\ARIALN.TTF", 30, ""), nil)

-- Texts first given a plain file at creation (damage numbers)
-- kept that file and its size for good: the family set later did nothing
-- (CurseForge: tiny combat numbers since 0.73.0).
local f = ns.Frames.player
H.check("combat numbers: the size asked for", f.feedbackText._font[2], ns.CombatFeedback.Size("player"))
