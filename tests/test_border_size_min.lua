-- The border's size starts at 1 (decision 69): no border is the show
-- switch's job. A size 0 saved or exported by an earlier version meant
-- "no border": loading or importing it switches the border off in that
-- scope; General gives the size its default, a frame none of its own;
-- the other scopes stay as they are (one with a size of its own over a
-- general 0 had its border, and keeps it: its switch on). A frame that
-- stored its switch on without a size over a general 0 was borderless:
-- it stays so (its switch off).
local M = H.M

local function boot(profile)
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
    _G.ForeverUnitFramesDB = { profile = profile }
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local ns = boot({ general = { borderSize = 0 }, target = { borderSize = 0, borderShow = true },
    player = { borderSize = 3 }, focus = { borderShow = false }, pet = { borderShow = true } })
local S, C, L = ns.Settings, ns.Config, ns.L
local def = S.Get("borderSize")
H.check("min 1", def.min, 1)
H.check("0 is not a size any more", S.Validate(def, 0), 1)
H.check("code kept", def.code, "BS")

local function stored(scope, key) return C.Profile()[scope][key] end
H.check("general: border off", stored("general", "borderShow"), false)
H.check("general: size default", stored("general", "borderSize"), S.Default(def, "general"))
H.check("target: border off (over a stored on)", stored("target", "borderShow"), false)
H.check("target: no size of its own (follows General)", stored("target", "borderSize"), nil)
H.check("player: a real size kept", stored("player", "borderSize"), 3)
H.check("player: its border kept on over the general's off", stored("player", "borderShow"), true)
H.check("focus: untouched", stored("focus", "borderShow"), false)
H.check("focus: no size made up", stored("focus", "borderSize"), nil)
H.check("party: nothing stored", stored("party", "borderShow"), nil)
H.check("pet: its stored on over a general 0 turns off", stored("pet", "borderShow"), false)
H.check("pet: no size made up", stored("pet", "borderSize"), nil)
H.check("no border drawn on the pet", ns.Border.Size("pet"), 0)
H.check("no border drawn on the target", ns.Border.Size("target"), 0)
H.check("the player's as before", ns.Border.Size("player"), 3)
-- Saved so: the next load finds nothing to change.
ns.Storage.Save()
H.check("saved: off", ForeverUnitFramesDB.profile.general.borderShow, false)
H.check("saved: the size", ForeverUnitFramesDB.profile.general.borderSize, S.Default(def, "general"))

-- An import of 0 likewise; a size of 2 stays.
local profile = ns.Codec.Decode("1;gBS0;pBS2;tBS0;tBV1")
H.check("import: general off", profile.general.borderShow, false)
H.check("import: general size default", profile.general.borderSize, S.Default(def, "general"))
H.check("import: target off", profile.target.borderShow, false)
H.check("import: target no size of its own", profile.target.borderSize, nil)
H.check("import: player's 2 kept", profile.player.borderSize, 2)
H.check("import: player's border kept on", profile.player.borderShow, true)
local switched = ns.Codec.Decode("1;gBS0;fBV1")
H.check("import: focus' on without a size over a general 0 turns off", switched.focus.borderShow, false)
H.check("import: focus no size made up", switched.focus.borderSize, nil)
local alone = ns.Codec.Decode("1;pBS2")
H.check("import without a general 0: nothing added", alone.player.borderShow, nil)
ns.Options.Open("general", "profile")
ns.Options.importArea:SetText("1;fBS0")
ns.Options.importButton:GetScript("OnClick")(ns.Options.importButton)
H.check("import button: focus off", C.Get("focus", "borderShow"), false)
H.check("import button: focus size", C.Get("focus", "borderSize"), S.Default(def, "focus"))
ns.Options.Close()

-- The hint "0 = no border" is gone in every language.
for code, t in pairs(ns.Locales) do H.check(code .. ": no 0 hint", t.HINT_borderSize, nil) end
H.check("no error", #M.errors, 0)
