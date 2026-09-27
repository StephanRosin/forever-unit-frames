-- Weapon enchants (poisons, stones, Rockbiter Weapon): not auras, so the
-- player's buff container shows them as item enchantments, one frame per
-- weapon slot, before the buffs and at their size.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C, AC = ns.Settings, ns.Config, ns.AuraContainers
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

M.units.player = M.units.player or { name = "Me", health = 5, healthMax = 10 }
local p = ns.Frames.player
-- Player buffs are off by default (Blizzard's buff frame shows them, weapon
-- enchants included); with them off the enchants are off too.
C.Set("player", "buffsEnabled", true)
H.checkTrue("player: containers", AC.Ensure(p))
local bc = p.auraContainers.buffs.container
local slots = AuraContainerItemEnchantmentSlot
H.checkTrue("main hand", bc._enchants and bc._enchants[slots.MainHand])
H.checkTrue("off hand", bc._enchants[slots.OffHand])
H.checkTrue("ranged", bc._enchants[slots.Ranged])
H.check("enabled", bc._enchants[slots.MainHand].enabled, true)

-- The frames look like the buff buttons and are resized with them.
local frame = bc._enchants[slots.MainHand].frame
H.checkTrue("styled like a buff button", frame._icon ~= nil)
local layout = bc._enchantLayout
H.check("before the buffs", layout.placement, CustomAuraContainerItemEnchantmentPlacement.BeforeAuraGroups)
H.check("at the buffs' size", layout.elementWidth, p.auras.buffs.size)
C.Set("player", "buffsSize", 30)
H.check("resized with the buffs", bc._enchantLayout.elementWidth, 30)

-- Off: the slots are disabled; buffs off turns them off too.
C.Set("player", "weaponEnchants", false)
H.check("off: disabled", bc._enchants[slots.MainHand].enabled, false)
C.Set("player", "weaponEnchants", true)
C.Set("player", "buffsEnabled", false)
H.check("buffs off: enchants off", bc._enchants[slots.Ranged].enabled, false)
C.Set("player", "buffsEnabled", true)
H.check("buffs on again", bc._enchants[slots.Ranged].enabled, true)

-- Other frames and the debuff container get none.
H.check("no enchants on the player's debuffs", p.auraContainers.debuffs.container._enchants, nil)
M.units.target = { name = "Foe", health = 5, healthMax = 10 }
local t = ns.Frames.target
AC.Ensure(t)
H.check("none on the target", t.auraContainers.buffs.container._enchants, nil)
