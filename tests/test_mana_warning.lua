-- Asked for on CurseForge: a low mana warning (Elements/ManaWarning.lua)
-- with its own mover, an icon from the macro icons and / or a text, only
-- in a group if wished, and a line to the group's chat.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "PRIEST", isPlayer = true, health = 1, healthMax = 1,
    power = 1000, powerMax = 1000 }
_G.ForeverUnitFramesDB = nil
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, S, L = ns.Config, ns.Settings, ns.L
local MW = ns.ManaWarning

H.check("player only", S.AppliesTo(S.Get("manaWarn"), "target"), false)
H.check("off by default", S.Default(S.Get("manaWarn"), "player"), false)
H.check("line at 20 %", S.Default(S.Get("manaWarnBelow"), "player"), 20)

local f = ns.Frames.player
local mw = f.manaWarning
local function mana(v)
    M.units.player.power = v
    M.FireEvent("UNIT_POWER_FREQUENT", "player", "MANA")
end
mana(100)
H.check("off: hidden however low", mw.holder:IsShown(), false)

C.Set("player", "manaWarn", true)
-- Fading: on by default, 0.3 s; it delays hiding, so the checks below
-- run without it until its own part at the end.
H.check("fade on by default", C.Get("player", "manaWarnFade"), true)
C.Set("player", "manaWarnFade", false)
-- In combat only by default; out of combat as an option.
mana(150)
H.check("out of combat: hidden", mw.holder:IsShown(), false)
C.Set("player", "manaWarnOutOfCombat", true)
H.check("out of combat on: shown", mw.holder:IsShown(), true)
C.Set("player", "manaWarnOutOfCombat", false)
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat starts: shown", mw.holder:IsShown(), true)
M.combat = false
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("combat ends: hidden", mw.holder:IsShown(), false)
C.Set("player", "manaWarnOutOfCombat", true)
mana(500)
H.check("on, 50 %: hidden", mw.holder:IsShown(), false)
mana(150)
H.check("15 %: shown", mw.holder:IsShown(), true)
H.check("text", mw.text:GetText(), L.MANA_WARN_TEXT)
H.check("shipped icon", mw.icon._texture, MW.ICON)
H.checkTrue("pulses", mw.icon.fufPulse and mw.icon.fufPulse:IsPlaying())
mana(250)
H.check("25 %: hidden again", mw.holder:IsShown(), false)
C.Set("player", "manaWarnBelow", 30)
H.check("line moved to 30 %: shown", mw.holder:IsShown(), true)

-- Icon or text alone.
C.Set("player", "manaWarnShow", "ICON")
H.check("icon only: no text", mw.text:IsShown(), false)
C.Set("player", "manaWarnShow", "TEXT")
H.check("text only: no icon", mw.icon:IsShown(), false)
C.Set("player", "manaWarnShow", "ICON_TEXT")
C.Set("player", "manaWarnIcon", 100005)
H.check("picked icon", mw.icon._texture, 100005)

-- Only in a group.
C.Set("player", "manaWarnGroupOnly", true)
H.check("group only, solo: hidden", mw.holder:IsShown(), false)
M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
M.SetGroup({ "party1" })
H.check("group only, in a party: shown", mw.holder:IsShown(), true)

-- Chat: AUTO says it once when it comes up, in the party's chat.
C.Set("player", "manaWarnChat", true)
mana(900)
mana(100)
H.check("auto: one line", #M.sent, 1)
H.check("auto: the text", M.sent[1][1], L.MANA_WARN_CHAT:format(10))
H.check("auto: party chat", M.sent[1][2], "PARTY")
mana(90)
H.check("still low: no second line", #M.sent, 1)
mana(900)
mana(100)
H.check("up and down within 30 s: quiet", #M.sent, 1)
M.Tick(31)
mana(900)
mana(100)
H.check("after 30 s: again", #M.sent, 2)
M.chatLockdown = true
M.Tick(31)
mana(900)
mana(100)
H.check("chat lockdown: nothing", #M.sent, 2)
M.chatLockdown = false

-- A click on it: the chat line, with the key held (Shift by default).
C.Set("player", "manaWarnChat", false)
C.Set("player", "manaWarnClick", "CHAT")
H.checkTrue("chat click: mouse on", mw.holder._mouse)
M.Tick(31)
mw.holder:GetScript("OnClick")(mw.holder)
H.check("chat click without Shift: nothing", #M.sent, 2)
M.shiftDown = true
mw.holder:GetScript("OnClick")(mw.holder)
H.check("chat click with Shift: a line", #M.sent, 3)
M.shiftDown = false
H.check("chat: no secure button", mw.click:IsShown(), false)

-- Item, spell, macro: the secure button over the block, under the key.
C.Set("player", "manaWarnClick", "ITEM")
H.check("item, nothing named: no button", mw.click:IsShown(), false)
C.Set("player", "manaWarnClickWhat", "13444")
H.check("item: button shown", mw.click:IsShown(), true)
H.check("block: no mouse of its own", mw.holder._mouse, false)
H.check("item without Shift: nothing", M.SecureClick(mw.click, "LeftButton"), nil)
M.shiftDown = true
H.check("item with Shift: used", M.SecureClick(mw.click, "LeftButton"), "item")
H.check("item by its number", M.secureUsed[#M.secureUsed][2], "item:13444")
C.Set("player", "manaWarnClick", "SPELL")
C.Set("player", "manaWarnClickWhat", "Innervate")
local casts = #M.casts
H.check("spell with Shift: cast", M.SecureClick(mw.click, "LeftButton"), "spell")
H.check("spell by name", #M.casts, casts + 1)
C.Set("player", "manaWarnClick", "MACRO")
C.Set("player", "manaWarnClickWhat", "/use Major Mana Potion")
M.SecureClick(mw.click, "LeftButton")
H.check("macro text", M.secureUsed[#M.secureUsed][2], "/use Major Mana Potion")
M.shiftDown = false
C.Set("player", "manaWarnClickKey", "NONE")
H.check("no key: a plain click", M.SecureClick(mw.click, "LeftButton"), "macro")
C.Set("player", "manaWarnClickKey", "SHIFT")
H.check("key back: plain click does nothing", M.SecureClick(mw.click, "LeftButton"), nil)
C.Set("player", "manaWarn", false)
H.check("warning off: button gone", mw.click:IsShown(), false)
C.Set("player", "manaWarn", true)
C.Set("player", "manaWarnClick", "NONE")
H.check("nothing: button gone", mw.click:IsShown(), false)
H.check("nothing: block no mouse", mw.holder._mouse, false)

-- A class without mana never sees it.
M.units.player.powerMax = 0
mana(0)
H.check("no mana: hidden", mw.holder:IsShown(), false)
M.units.player.powerMax = 1000

-- Secret mana: shown with the opacity of a step curve, no chat.
C.Set("player", "manaWarnChat", true)
M.Tick(31)
local sent = #M.sent
M.units.player.power = M.Secret(100)
M.units.player.powerPercent = 0.1
M.FireEvent("UNIT_POWER_FREQUENT", "player", "MANA")
H.check("secret: block shown", mw.holder:IsShown(), true)
H.check("secret: opaque below the line", M.Reveal(mw.holder:GetAlpha()), 1)
H.check("secret: no chat", #M.sent, sent)
M.units.player.powerPercent = 0.8
M.FireEvent("UNIT_POWER_FREQUENT", "player", "MANA")
H.check("secret: clear above the line", M.Reveal(mw.holder:GetAlpha()), 0)
M.units.player.power = 1000

-- Test mode: shown, no chat.
mana(1000)
ns.TestMode.Set(not ns.TestMode.IsOn())
H.check("test mode: shown", mw.holder:IsShown(), true)
ns.TestMode.Set(not ns.TestMode.IsOn())

-- The options: a section on the player's Extras tab, the icon row a picker.
local found
for _, tab in ipairs(ns.Schema.Tabs("player")) do
    for _, sec in ipairs(tab.sections or {}) do
        if sec.id == "manaWarn" then found = tab.id end
    end
end
H.check("on the extras tab", found, "extras")
ns.Options.Open("player", "extras")
local row
for _, r in ipairs(ns.Options.rows) do if r.key == "manaWarnIcon" then row = r end end
H.checkTrue("icon row", row and row.swatch)
row.swatch:GetScript("OnClick")(row.swatch)
local grid = ns.Widgets.iconGrid
H.checkTrue("grid open", grid:IsShown())
H.check("first cell: the shipped icon", grid.cells[1].value, 0)
H.check("then the macro icons", grid.cells[2].value, 100001)
grid.cells[3]:GetScript("OnClick")(grid.cells[3])
H.check("picked", C.Get("player", "manaWarnIcon"), 100002)
H.check("grid closed", grid:IsShown(), false)

-- Fading in and out.
C.Set("player", "manaWarnClick", "NONE")
C.Set("player", "manaWarnFade", true)
C.Set("player", "manaWarnFadeTime", 5)
mana(1000)
H.check("fade: hidden at full mana", mw.holder:IsShown(), false)
mana(100)
H.check("fade in: shown at once", mw.holder:IsShown(), true)
H.check("fade in: playing", mw.fadeIn:IsPlaying(), true)
H.check("fade in: over half a second", mw.fadeIn.alpha._duration, 0.5)
mana(1000)
H.check("fade out: still shown while it fades", mw.holder:IsShown(), true)
H.check("fade out: playing", mw.fadeOut:IsPlaying(), true)
M.RunTimers(0.6)
H.check("fade out: hidden when done", mw.holder:IsShown(), false)
mana(100)
mana(1000)
mana(100)
M.RunTimers(0.6)
H.check("back before the fade ended: stays", mw.holder:IsShown(), true)
H.check("back: fading in", mw.fadeIn:IsPlaying(), true)
