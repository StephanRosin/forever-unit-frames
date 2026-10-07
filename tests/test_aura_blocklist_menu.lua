-- Adding a hidden aura from the frame. The icons take no clicks (a
-- container's never run addon code; ours pass the click on), so a Shift +
-- right-click on them is the unit frame's: its secure click does nothing
-- with Shift (no click binding), its OnMouseUp opens our menu with the
-- auras of the row under the mouse, readable ones only, each a button that
-- puts the spell on that frame's list (Shift + Ctrl: the account's). Out
-- of combat only. A chat line says what was hidden and
-- how to undo it; /fuf auras undo takes it back.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, L = ns.Config, ns.L

local FOOD, FIRE, SECRET = 19705, 7353, 2222
M.spells[FOOD] = { name = "Well Fed" }
M.spells[FIRE] = { name = "Cozy Fire" }
M.spells[SECRET] = { name = "Hidden Thing" }
local function aura(id, spell, helpful)
    return { auraInstanceID = id, spellId = spell, name = M.spells[spell].name, isHelpful = helpful, icon = id,
        applications = 0, duration = 0, expirationTime = 0 }
end
M.units.player = { name = "Me", health = 5, healthMax = 10 }
M.units.target = { name = "Ann", isPlayer = true, friend = true, health = 5, healthMax = 10,
    auras = { aura(1, FOOD, true), aura(2, FIRE, true), aura(3, FIRE, false) } }
local t = ns.Frames.target
M.FireEvent("PLAYER_TARGET_CHANGED")
local buffs = t.auraContainers.buffs.container

local function ours(menu)
    local list = {}
    for _, e in ipairs(menu and menu.elements or {}) do
        if e.kind == "button" or e.kind == "title" then list[#list + 1] = e end
    end
    return list
end
local function rightClick()
    M.menu = nil
    M.SecureClick(t, "RightButton")
    local up = t:GetScript("OnMouseUp")
    if up then up(t, "RightButton") end
    return M.menu
end

-- A plain right-click: Blizzard's unit menu as before, not ours.
buffs._mouseOver = true
local menu = rightClick()
H.check("plain: the unit menu", menu and menu.tag, "MENU_UNIT_PLAYER")
H.check("plain: nothing of ours", #ours(menu), 0)
-- Shift alone runs no secure action (no click binding for it).
M.shiftDown = true
H.check("shift: no secure action", M.SecureClick(t, "RightButton"), nil)
M.menu = nil
-- A left click with Shift: nothing.
t:GetScript("OnMouseUp")(t, "LeftButton")
H.check("shift + left: no menu", M.menu, nil)
-- Shift, not over the auras: nothing either.
buffs._mouseOver = false
H.check("shift, not over the auras: nothing", #ours(rightClick()), 0)

-- Shift over the buffs: a title and one button per readable buff.
buffs._mouseOver = true
local list = ours(rightClick())
H.check("our own menu", M.menu and M.menu.tag, "context")
H.check("title", list[1] and list[1].text, L.AURA_BLOCK_MENU_FRAME:format(L.FRAME_target))
H.check("two buffs", #list, 3)
H.check("first", list[2] and list[2].text, L.AURA_BLOCK_MENU_ENTRY:format("Well Fed", FOOD))
M.ClickMenu(list[2])
H.check("on the target's list", C.Get("target", "auraBlock"), tostring(FOOD))
H.check("not the account's", C.Get("general", "auraBlockAccount"), "")
H.check("chat says so", M.chat[#M.chat]:find("Well Fed", 1, true) ~= nil, true)
H.check("... and how to undo", M.chat[#M.chat]:find("/fuf auras undo", 1, true) ~= nil, true)
-- A listed spell is not offered again.
list = ours(rightClick())
H.check("listed: not offered", #list, 2)

-- Undo takes the last one back.
SlashCmdList.FOREVERUNITFRAMES("auras undo")
H.check("undone", C.Get("target", "auraBlock"), "")
SlashCmdList.FOREVERUNITFRAMES("auras undo")
H.check("nothing more to undo", M.chat[#M.chat]:find(L.AURA_BLOCK_UNDO_NONE, 1, true) ~= nil, true)

-- Shift + Ctrl: the account's list.
M.ctrlDown = true
list = ours(rightClick())
H.check("account title", list[1].text, L.AURA_BLOCK_MENU_ACCOUNT)
M.ClickMenu(list[3])
H.check("on the account's list", C.Get("general", "auraBlockAccount"), tostring(FIRE))
M.ctrlDown = false
SlashCmdList.FOREVERUNITFRAMES("auras undo")
H.check("account undo", C.Get("general", "auraBlockAccount"), "")

-- Over the debuffs of a friendly target: the client keeps showing them
-- (CanApplyIdentityCandidateFilters), so none is offered; the chat says
-- why. Shift + Ctrl the same.
buffs._mouseOver = false
t.auraContainers.debuffs.container._mouseOver = true
list = ours(rightClick())
H.check("friendly debuffs: no menu", #list, 0)
H.check("friendly debuffs: chat says why", M.chat[#M.chat]:find(L.AURA_BLOCK_MENU_NO_DEBUFFS, 1, true) ~= nil, true)
M.ctrlDown = true
H.check("friendly debuffs, account: no menu", #ours(rightClick()), 0)
M.ctrlDown = false
-- A never-secret debuff is offered there (the client hides it anywhere).
M.neverSecretSpells[FIRE] = true
list = ours(rightClick())
H.check("never-secret debuff offered", #list, 2)
M.neverSecretSpells[FIRE] = nil
-- An enemy target's debuffs: offered.
M.units.target.friend, M.units.target.hostile = nil, true
list = ours(rightClick())
H.check("enemy debuffs", #list, 2)
H.check("the debuff", list[2] and list[2].text, L.AURA_BLOCK_MENU_ENTRY:format("Cozy Fire", FIRE))
-- ... and its buffs not (the client keeps showing an enemy's buffs).
t.auraContainers.debuffs.container._mouseOver = false
buffs._mouseOver = true
H.check("enemy buffs: no menu", #ours(rightClick()), 0)
H.check("enemy buffs: chat says why", M.chat[#M.chat]:find(L.AURA_BLOCK_MENU_NO_BUFFS, 1, true) ~= nil, true)
M.units.target.friend, M.units.target.hostile = true, nil

-- Your own debuffs: not offered.
M.units.player.auras = { aura(11, FIRE, false) }
M.FireEvent("UNIT_AURA", "player")
local p = ns.Frames.player
p.auraContainers.debuffs.container._mouseOver = true
H.check("player debuff: not offered", ns.AuraBlockMenu.Open(p), false)
local cands = ns.AuraBlockMenu.Candidates(p, p.auras.debuffs, {})
H.check("player debuff: no candidate", #cands, 0)
p.auraContainers.debuffs.container._mouseOver = false

-- A Shift + right-click bound to click-casting is the binding's: no menu.
ns.RaidConfig.Set("general", "click2Shift", "assist")
M.RunTimers()
H.check("shift-right bound", t:GetAttribute("shift-type2"), "assist")
H.check("bound: no menu", #ours(rightClick()), 0)
M.ctrlDown = true
H.check("bound shift only: the account's menu still", #ours(rightClick()), 3)
ns.RaidConfig.Set("general", "click2ShiftCtrl", "focus")
M.RunTimers()
H.check("ctrl-shift-right bound", t:GetAttribute("ctrl-shift-type2"), "focus")
H.check("ctrl-shift bound: no menu", #ours(rightClick()), 0)
M.ctrlDown = false
ns.RaidConfig.Set("general", "click2Shift", "")
ns.RaidConfig.Set("general", "click2ShiftCtrl", "")
M.RunTimers()
H.check("unbound again: the menu", #ours(rightClick()), 3)

-- A secret spell ID or name is left out; no error.
table.insert(M.units.target.auras, aura(4, SECRET, true))
M.units.target.auras[4].spellId = M.Secret(SECRET)
list = ours(rightClick())
H.check("secret: left out", #list, 3)
-- Reads refused: nothing offered, no error.
M.auraError = true
H.check("refused: nothing", #ours(rightClick()), 0)
M.auraError = false

-- Undo refused by the settings: no "shows again" line, the undo stays.
ns.AuraBlocklist.Hide("target", FOOD)
local realSet = C.Set
C.Set = function() return false end
local lines = #M.chat
H.check("undo refused", ns.AuraBlocklist.Undo(), false)
H.check("undo refused: no line", #M.chat, lines)
C.Set = realSet
H.check("undo again: done", ns.AuraBlocklist.Undo(), true)
H.check("undo again: removed", C.Get("target", "auraBlock"), "")

-- Party pets (a derived scope) get no menu.
H.check("no list of their own", ns.AuraBlockMenu.Open({ auras = {}, key = ns.Party.PET_KEY, unit = "partypet1" }),
    false)

-- In combat: nothing (settings rebuild containers out of combat).
M.SetCombat(true)
H.check("combat: nothing", #ours(rightClick()), 0)
M.SetCombat(false)
H.check("no errors", #M.errors, 0)
M.shiftDown = false
