-- Weapon enchants (poisons, stones, Rockbiter Weapon): Forever reports them
-- only through C_Item.GetWeaponEnchantInfo. Icons of their own, before the
-- player's buffs; the buff container moves on by as many icons.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C, AC, W = ns.Settings, ns.Config, ns.AuraContainers, ns.WeaponEnchants
C.Use({})

H.check("code", S.Get("weaponEnchants").code, "WE")
H.check("on by default", C.Get("player", "weaponEnchants"), true)
H.check("player only", S.AppliesTo(S.Get("weaponEnchants"), "target"), false)
local found
for _, tab in ipairs(ns.Schema.Tabs("player")) do
    for _, sec in ipairs(tab.sections or {}) do
        for _, key in ipairs(sec.keys or {}) do if key == "weaponEnchants" then found = sec.id end end
    end
end
H.check("in the buffs section", found, "buffs")

-- Reading: a list per slot, the first entry may be empty (as in game).
M.weaponEnchants[0] = {
    { hasEnchant = false, timeLeft = 0, charges = 0, enchantIconID = 0, enchantID = 0 },
    { hasEnchant = true, timeLeft = 3312540, charges = 0, enchantIconID = 136086, enchantID = 29 },
}
local list = W.Read()
H.check("one active enchant", #list, 1)
H.check("main hand", list[1].invSlot, 16)
H.check("its icon", list[1].icon, 136086)
H.checkTrue("its expiry", list[1].expires and list[1].expires > GetTime() + 3300)

-- Player buffs on (off by default: Blizzard's buff frame shows them then).
M.units.player = M.units.player or { name = "Me", health = 5, healthMax = 10 }
local p = ns.Frames.player
C.Set("player", "buffsEnabled", true)
AC.Ensure(p)
W.Update(p)
local b = p.enchantButtons and p.enchantButtons[1]
H.checkTrue("an icon", b)
H.checkTrue("shown", b:IsShown())
H.check("the enchant's icon", b.icon._texture, 136086)
H.check("buff size", b:GetWidth(), p.auras.buffs.size)
H.check("the buffs make room for one", p.enchantLead, 1)
local step = p.auras.buffs.size + p.auras.buffs.spacing
local _, _, _, bx = b:GetPoint(1)
local _, _, _, cx = p.auraContainers.buffs.container:GetPoint(1)
H.check("buffs moved on by one icon", cx - bx, step)

-- A second one (off hand): two icons, the buffs two steps on.
M.weaponEnchants[1] = { { hasEnchant = true, timeLeft = 60000, charges = 5, enchantIconID = 1234, enchantID = 7 } }
W.Update(p)
local b2 = p.enchantButtons[2]
H.checkTrue("second icon", b2:IsShown())
H.check("charges as count", b2.count:GetText(), "5")
_, _, _, cx = p.auraContainers.buffs.container:GetPoint(1)
H.check("buffs moved on by two", cx - bx, 2 * step)
local _, _, _, b2x = b2:GetPoint(1)
H.check("second right of the first", b2x - bx, step)

-- The weapon's tooltip, which lists the enchant. Owned by the screen, at
-- the cursor: the icon carries the untrusted-layout aspect (its holder's),
-- and the client refuses it as a tooltip owner.
local owned
GameTooltip.SetInventoryItem = function(_, unit, slot) owned = unit .. slot end
H.checkTrue("the icon has the aspect", M.HasLayoutAspect(b))
local ok, err = pcall(b:GetScript("OnEnter"), b)
H.checkTrue("tooltip opens without error", ok, err)
H.check("tooltip: the weapon", owned, "player16")
H.check("tooltip owner: the screen", GameTooltip._owner, UIParent)
H.check("tooltip at the cursor", GameTooltip._anchor, "ANCHOR_CURSOR")
b:GetScript("OnLeave")(b)
H.check("leaving hides it", GameTooltip:IsShown(), false)

-- Gone: the icons hide and the buffs move back.
M.weaponEnchants = {}
W.Update(p)
H.check("hidden when gone", b:IsShown(), false)
H.check("no room kept", p.enchantLead, 0)
local _, _, _, back = p.auraContainers.buffs.container:GetPoint(1)
H.check("buffs back at the anchor", back, bx)

-- Switched off, or buffs off: nothing.
M.weaponEnchants[0] = { { hasEnchant = true, timeLeft = 60000, charges = 0, enchantIconID = 1, enchantID = 1 } }
W.Update(p)
H.check("an oil on: room for one", p.enchantLead, 1)
-- Switching the option off (reported: an empty slot stayed until the
-- buffs changed). The setting's own restyle must give the room back.
C.Set("player", "weaponEnchants", false)
local _, _, _, afterOff = p.auraContainers.buffs.container:GetPoint(1)
H.check("setting off: buffs back at the anchor at once", afterOff, bx)
H.check("setting off: no room kept", p.enchantLead, 0)
W.Update(p)
H.check("setting off: no icon", b:IsShown(), false)
C.Set("player", "weaponEnchants", true)
W.Update(p)
H.checkTrue("setting on: icon again", b:IsShown())
C.Set("player", "buffsEnabled", false)
W.Update(p)
H.check("buffs off: no icon", b:IsShown(), false)

-- In combat too: nothing here is protected.
C.Set("player", "buffsEnabled", true)
M.SetCombat(true)
M.weaponEnchants[1] = { { hasEnchant = true, timeLeft = 60000, charges = 0, enchantIconID = 2, enchantID = 2 } }
W.Update(p)
H.check("in combat: two", p.enchantLead, 2)
M.SetCombat(false)
