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
M.units.target = { name = "Ann", isPlayer = true, health = 5, healthMax = 10,
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

-- Over the debuffs: the debuffs.
buffs._mouseOver = false
t.auraContainers.debuffs.container._mouseOver = true
list = ours(rightClick())
H.check("debuffs", #list, 2)
H.check("the debuff", list[2].text, L.AURA_BLOCK_MENU_ENTRY:format("Cozy Fire", FIRE))
t.auraContainers.debuffs.container._mouseOver = false
buffs._mouseOver = true

-- A secret spell ID or name is left out; no error.
table.insert(M.units.target.auras, aura(4, SECRET, true))
M.units.target.auras[4].spellId = M.Secret(SECRET)
list = ours(rightClick())
H.check("secret: left out", #list, 3)
-- Reads refused: nothing offered, no error.
M.auraError = true
H.check("refused: nothing", #ours(rightClick()), 0)
M.auraError = false

-- Party pets (a derived scope) get no menu.
H.check("no list of their own", ns.AuraBlockMenu.Open({ auras = {}, key = ns.Party.PET_KEY, unit = "partypet1" }),
    false)

-- In combat: nothing (settings rebuild containers out of combat).
M.SetCombat(true)
H.check("combat: nothing", #ours(rightClick()), 0)
M.SetCombat(false)
H.check("no errors", #M.errors, 0)
M.shiftDown = false
