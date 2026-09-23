local M = H.M
local ns = H.LoadAddon()
local S, Codec = ns.Settings, ns.Codec

-- Setting: inherited, on by default, own permanent code.
local def = S.Get("showSurname")
H.checkTrue("setting exists", def)
H.check("code", def and def.code, "SN")
H.check("inherited", def and def.scope, "inherit")
H.check("bool", def and def.type, "bool")
H.check("on by default", def and S.Default(def, "general"), true)
H.check("label", ns.L.SETTING_showSurname, "Show secondary name")
H.check("hint", ns.L.HINT_showSurname, "Surname next to the first name")

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, O = ns.Config, ns.Options
local f = ns.Frames.player
local title, left = f.texts.title, f.texts.healthLeft

M.units.player = { name = "Aria", surname = "Brightwood", level = 60, class = "WARLOCK",
    className = "Warlock", isPlayer = true, health = 5, healthMax = 10 }
C.Set("player", "textHealthLeft", "NAME")
M.FireEvent("PLAYER_ENTERING_WORLD")

-- On: first name and surname, as two arguments (never joined in Lua).
H.check("NAME: format", left._fmt, "%s %s")
H.check("NAME: first name", left._args[1], "Aria")
H.check("NAME: surname", left._args[2], "Brightwood")
H.check("NAME_LEVEL: format", title._fmt, "%s %s %s")
H.check("NAME_LEVEL: level", title._args[1], "60")
H.check("NAME_LEVEL: first name", title._args[2], "Aria")
H.check("NAME_LEVEL: surname", title._args[3], "Brightwood")
H.check("soft copy follows", title.softCopies[1]._args[3], "Brightwood")

-- Off: the surname is dropped.
C.Set("general", "showSurname", false)
H.check("off: NAME plain", left._text, "Aria")
H.check("off: NAME_LEVEL format", title._fmt, "%s %s")
H.check("off: NAME_LEVEL name", title._args[2], "Aria")
H.check("off: soft copy follows", title.softCopies[1]._args[2], "Aria")

-- Off, with the surname inside the first value: split at the separator.
M.units.player.surname = nil
M.units.player.name = "Aria Brightwood"
M.FireEvent("UNIT_NAME_UPDATE", "player")
H.check("off: split at the separator", left._text, "Aria")
H.check("off: split in the title", title._args[2], "Aria")
_G.Constants.CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = "+" }
M.units.player.name = "Aria+Brightwood Jr"
M.FireEvent("UNIT_NAME_UPDATE", "player")
H.check("off: the client's separator", left._text, "Aria")
_G.Constants.CharacterNameSeparatorConsts = nil
M.units.player.name = "Aria Brightwood"
M.FireEvent("UNIT_NAME_UPDATE", "player")
H.check("off: space without the constant", left._text, "Aria")
M.units.player.name = "Aria"
M.FireEvent("UNIT_NAME_UPDATE", "player")
H.check("off: single name unchanged", left._text, "Aria")

-- Off, secret name: passed through whole (it cannot be split).
M.units.player.name = M.Secret("Aria Brightwood")
M.units.player.surname = M.Secret("Brightwood")
M.FireEvent("UNIT_NAME_UPDATE", "player")
H.check("off: secret name unchanged", M.Reveal(left._text), "Aria Brightwood")
H.checkTrue("off: still secret", M.IsSecret(left._text))
H.check("off: secret in the title", M.Reveal(title._args[2]), "Aria Brightwood")

-- On, secret surname: passed through.
C.Set("general", "showSurname", true)
H.check("on: secret surname passed", M.Reveal(left._args[2]), "Brightwood")
H.checkTrue("on: surname stays secret", M.IsSecret(left._args[2]))
H.check("on: secret title surname", M.Reveal(title._args[3]), "Brightwood")

-- On, no surname: the name alone.
M.units.player.name = "Aria"
M.units.player.surname = nil
M.FireEvent("UNIT_NAME_UPDATE", "player")
H.check("on: no surname", left._text, "Aria")
H.check("on: no surname title", title._fmt, "%s %s")

-- Per frame override against General.
M.units.player.surname = "Brightwood"
C.Set("general", "showSurname", false)
C.Set("player", "showSurname", true)
H.check("frame override wins", left._args[2], "Brightwood")
H.checkTrue("override stored", C.IsOverridden("player", "showSurname"))
H.check("target inherits general", C.Get("target", "showSurname"), false)

-- Apply to all frames clears it with the font overrides.
O.Open("general")
O.SelectTab("appearance")
local found
for _, row in ipairs(O.rows) do if row.key == "showSurname" then found = true end end
H.checkTrue("on General -> Appearance", found)
local button = O.actionButtons.applyFontToFrames
local click = button:GetScript("OnClick")
click(button); click(button)
H.check("apply clears the override", C.IsOverridden("player", "showSurname"), false)
H.check("frame shows the general value", left._text, "Aria")
O.Select("player")
O.SelectTab("text")
found = nil
for _, row in ipairs(O.rows) do if row.key == "showSurname" then found = true end end
H.checkTrue("on the frame's Text tab", found)
O.Close()

-- Codec round trip.
C.Set("general", "showSurname", false)
C.Set("party", "showSurname", true)
local s = Codec.Encode(C.Profile())
H.checkTrue("encoded", s:find("gSN0", 1, true))
local back = assert(Codec.Decode(s))
H.check("general back", back.general.showSurname, false)
H.check("party back", back.party.showSurname, true)
