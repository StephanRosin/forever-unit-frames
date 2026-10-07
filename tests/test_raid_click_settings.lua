-- Click-casting's settings (Raid/Settings.lua): per character, 40 mouse
-- slots (five buttons, eight modifier sets) and 16 key slots, each a
-- binding as text; the defaults keep left = target, right = menu.
local ns = H.LoadAddon()
local Raid, RS = ns.Raid, ns.RaidSettings

H.check("five buttons", #Raid.CLICK_BUTTONS, 5)
H.check("eight modifier sets", #Raid.CLICK_MODIFIERS, 8)
H.check("forty slots", #Raid.CLICK_SLOTS, 40)
H.check("sixteen keys", #Raid.CLICK_KEYS, 16)

-- The client's prefixes (SecureTemplates.lua: alt- before ctrl- before
-- shift-), the plain click as the wildcard.
local prefixes = {}
for _, m in ipairs(Raid.CLICK_MODIFIERS) do prefixes[#prefixes + 1] = m.prefix end
H.check("prefixes", table.concat(prefixes, " "),
    "* shift- ctrl- alt- ctrl-shift- alt-shift- alt-ctrl- alt-ctrl-shift-")

local first, last = Raid.CLICK_SLOTS[1], Raid.CLICK_SLOTS[40]
H.check("first slot", first.key, "click1")
H.check("first slot's button", first.button, 1)
H.check("first slot's prefix", first.prefix, "*")
H.check("last slot", last.key, "click5ShiftCtrlAlt")
H.check("last slot's prefix", last.prefix, "alt-ctrl-shift-")
H.check("shift-right", Raid.CLICK_SLOTS[10].key, "click2Shift")

-- Per character, text; the defaults.
for _, slot in ipairs(Raid.CLICK_SLOTS) do
    local def = RS.Get(slot.key)
    H.check(slot.key .. " per character", def.scope, "general")
    H.check(slot.key .. " text", def.type, "text")
end
H.check("left: target", RS.Get("click1").default, "target")
H.check("right: menu", RS.Get("click2").default, "menu")
H.check("shift-left: nothing", RS.Get("click1Shift").default, "")
H.check("middle: nothing", RS.Get("click3").default, "")
for i, slot in ipairs(Raid.CLICK_KEYS) do
    H.check("key " .. i, slot.key, "clickKey" .. i)
    H.check("key " .. i .. " binding", slot.bind, "clickKey" .. i .. "Bind")
    H.check("key " .. i .. " per character", RS.Get(slot.key).scope .. RS.Get(slot.bind).scope, "generalgeneral")
    H.check("key " .. i .. " empty", RS.Get(slot.key).default .. RS.Get(slot.bind).default, "")
end
H.check("mode", table.concat(RS.Get("clickCast").values, ","), "AUTO,ON,OFF")
H.check("mode default", RS.Get("clickCast").default, "AUTO")
H.check("party frames too", RS.Get("clickCastParty").default, true)
H.check("party per character", RS.Get("clickCastParty").scope, "general")

-- Permanent codes.
H.check("code: left", RS.Get("click1").code, "HD")
H.check("code: shift-ctrl-alt button 5", RS.Get("click5ShiftCtrlAlt").code, "WU")
H.check("code: ctrl-right", RS.Get("click2Ctrl").code, "VI")
H.check("code: key 1", RS.Get("clickKey1").code, "TA")
H.check("code: key 16", RS.Get("clickKey16").code, "TU")
H.check("code: key 1 binding", RS.Get("clickKey1Bind").code, "OA")
H.check("code: key 16 binding", RS.Get("clickKey16Bind").code, "OU")
H.check("code: mode", RS.Get("clickCast").code, "HA")
H.check("code: party", RS.Get("clickCastParty").code, "HP")

-- A binding as stored.
local function parsed(text)
    local kind, value = Raid.ParseBinding(text)
    if kind == nil then return "nil" end
    return kind .. "|" .. tostring(value)
end
H.check("nothing", parsed(""), "|nil")
H.check("target", parsed("target"), "target|nil")
H.check("focus", parsed("focus"), "focus|nil")
H.check("assist", parsed("assist"), "assist|nil")
H.check("menu", parsed("menu"), "menu|nil")
H.check("spell", parsed("spell:Flash Heal"), "spell|Flash Heal")
H.check("spell, empty", parsed("spell:"), "spell|")
H.check("item by name", parsed("item:Major Healing Potion"), "item|Major Healing Potion")
H.check("item by ID", parsed("item:13446"), "item|13446")
H.check("macro keeps colons", parsed("macro:/cast [@mouseover] Renew"), "macro|/cast [@mouseover] Renew")
H.check("unknown kind", parsed("dance"), "nil")
H.check("unknown kind with a value", parsed("dance:now"), "nil")
H.check("target takes no value", parsed("target:x"), "nil")
-- What the settings refuse.
local def = RS.Get("click3")
H.check("stores a spell", RS.Validate(def, "spell:Renew"), "spell:Renew")
H.check("refuses nonsense", RS.Validate(def, "dance"), nil)
H.check("a macro up to 255 letters", RS.Validate(def, "macro:" .. ("x"):rep(255)), "macro:" .. ("x"):rep(255))
H.check("not longer", RS.Validate(def, "macro:" .. ("x"):rep(256)), nil)
-- A key's binding: a spell, an item or a macro (the mouse-over macro acts
-- on the hovered unit; target, focus, assist and the menu are clicks).
local keyDef = RS.Get("clickKey1Bind")
H.check("key: spell", RS.Validate(keyDef, "spell:Renew"), "spell:Renew")
H.check("key: item", RS.Validate(keyDef, "item:13446"), "item:13446")
H.check("key: macro", RS.Validate(keyDef, "macro:/say hi"), "macro:/say hi")
H.check("key: nothing", RS.Validate(keyDef, ""), "")
H.check("key: no target", RS.Validate(keyDef, "target"), nil)
H.check("key: no menu", RS.Validate(keyDef, "menu"), nil)

-- A key as stored: upper case, modifiers in the client's order (ALT-,
-- CTRL-, SHIFT-). The mouse's left and right buttons and Escape are never
-- taken (they would stop the game's own clicks and menu).
H.check("a letter", Raid.ParseKey("f"), "F")
H.check("a function key", Raid.ParseKey("F5"), "F5")
H.check("modifiers ordered", Raid.ParseKey("shift-ctrl-q"), "CTRL-SHIFT-Q")
H.check("all three", Raid.ParseKey("Shift-Alt-Ctrl-1"), "ALT-CTRL-SHIFT-1")
H.check("a mouse button", Raid.ParseKey("button4"), "BUTTON4")
H.check("the wheel", Raid.ParseKey("ctrl-mousewheelup"), "CTRL-MOUSEWHEELUP")
H.check("spaces trimmed", Raid.ParseKey("  g "), "G")
H.check("empty", Raid.ParseKey(""), "")
H.check("left button refused", Raid.ParseKey("BUTTON1"), nil)
H.check("right button refused", Raid.ParseKey("shift-button2"), nil)
H.check("escape refused", Raid.ParseKey("escape"), nil)
H.check("a modifier alone", Raid.ParseKey("SHIFT"), nil)
H.check("a modifier twice", Raid.ParseKey("SHIFT-SHIFT-F"), nil)
H.check("two keys", Raid.ParseKey("F G"), nil)
H.check("a sign", Raid.ParseKey("ctrl-,"), "CTRL-,")
-- Only the client's key names (no list of them in the client's source:
-- letters, digits, signs, F1-F24, NUMPAD0-9 and its signs, BUTTON3-31,
-- the wheel and the named keys). Every key the source's own default
-- bindings use is one.
for _, k in ipairs({ ",", "-", ".", "/", "=", "[", "\\", "]", "0", "9", "C", "CAPSLOCK", "F1", "F12", "F24",
    "MOUSEWHEELDOWN", "MOUSEWHEELUP", "SPACE", "TAB", "NUMPAD0", "NUMPADPLUS", "NUMPADDIVIDE", "BUTTON3", "BUTTON31",
    "PAGEUP", "INSERT", "ENTER", "BACKSPACE", "UP" }) do
    H.check("a key name: " .. k, Raid.ParseKey("ctrl-" .. k:lower()), "CTRL-" .. k)
end
for _, k in ipairs({ "FOO", "F25", "F0", "BUTTON32", "NUMPAD10", "MOUSEWHEEL", "SHIFTX", "AB" }) do
    H.check("no key name: " .. k, Raid.ParseKey(k), nil)
end
-- Gamepad keys (Blizzard_SharedXML/Shared/GamepadConstants.lua): the PAD
-- family.
for _, k in ipairs({ "PAD1", "PAD4", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PADLSHOULDER", "PADRSHOULDER",
    "PADLTRIGGER", "PADRTRIGGER", "PADLSTICK", "PADRSTICK", "PADBACK", "PADFORWARD" }) do
    H.check("a gamepad key: " .. k, Raid.ParseKey("shift-" .. k:lower()), "SHIFT-" .. k)
end
H.check("no key name: PAD alone", Raid.ParseKey("PAD"), nil)
H.checkTrue("the refusal names examples", ns.L.RAID_TYPED_KEY_INVALID:find("MOUSEWHEELUP", 1, true))
H.check("stored key checked", RS.Validate(RS.Get("clickKey1"), "CTRL-SHIFT-Q"), "CTRL-SHIFT-Q")
H.check("stored key: not normalised", RS.Validate(RS.Get("clickKey1"), "shift-ctrl-q"), nil)

-- The raid window's tab (Raid/Options/Schema.lua): the switches, a section
-- per button, the keys; the slots' words by their modifiers.
local Schema = ns.RaidSchema
local tab
for _, t in ipairs(Schema.TABS) do if t.id == "clickCast" then tab = t end end
H.checkTrue("a click-casting tab", tab)
local secs = {}
for i, sec in ipairs(tab.sections) do secs[i] = sec.id .. ":" .. #sec.keys end
H.check("its sections", table.concat(secs, ","),
    "clickCastGeneral:1,clickLeft:8,clickRight:8,clickMiddle:8,clickButton4:8,clickButton5:8,clickKeys:32")
H.check("tab word", Schema.TabTitle("clickCast"), "Click-casting")
H.check("section word", Schema.SectionTitle("clickRight"), "Right button")
H.check("plain click", Schema.Label("click3"), "Click")
H.check("shift-right", Schema.Label("click2Shift"), "Shift-click")
H.check("all three", Schema.Label("click5ShiftCtrlAlt"), "Shift-Ctrl-Alt-click")
H.check("a key", Schema.Label("clickKey7"), "Key")
H.check("its binding", Schema.Label("clickKey7Bind"), "Casts")
H.check("mode words", Schema.EnumText(RS.Get("clickCast"), "AUTO"), "Automatic")
H.check("binding words", Schema.BindingText("spell:Renew"), "Cast a spell: Renew")
H.check("binding words: nothing", Schema.BindingText(""), "Nothing")
H.check("binding words: menu", Schema.BindingText("menu"), "Open the menu")
H.check("binding words: no value yet", Schema.BindingText("item:"), "Use an item")
H.check("binding words: none", Schema.BindingText("dance"), nil)
-- An empty modified slot does what the plain click does (the client's
-- fallback): its word says so. A plain click's or a key's empty slot does
-- nothing.
H.check("empty shift-left", Schema.KindText("", "click1Shift"), "Like the plain click")
H.check("empty ctrl-alt-button 5", Schema.BindingText("", "click5CtrlAlt"), "Like the plain click")
H.check("empty plain middle", Schema.KindText("", "click3"), "Nothing")
H.check("empty key", Schema.KindText("", "clickKey1Bind"), "Nothing")
H.check("no slot", Schema.KindText(""), "Nothing")
H.check("other kinds unchanged", Schema.KindText("focus", "click1Shift"), "Focus")
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    H.checkTrue(code .. " has the fallback word", type(ns.Locales[code].RAID_CLICK_LIKE_PLAIN) == "string")
end
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    for _, kind in ipairs(Raid.CLICK_KINDS) do
        local name = kind == "" and "RAID_CLICK_NOTHING" or ("RAID_CLICK_" .. kind)
        H.checkTrue(code .. " has " .. name, type(ns.Locales[code][name]) == "string")
    end
end
H.check("German tab", ns.Locales.deDE.RAID_TAB_clickCast, "Klickzauber")
