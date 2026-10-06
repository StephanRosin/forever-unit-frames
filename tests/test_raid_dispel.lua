-- The centre debuff icon and the tint of raid cells (Raid/CellAuras.lua):
-- a cell makes one aura container when it first shows a unit and adds
-- aura slots to it, out of combat only; the client fills them. The addon
-- reads no aura itself.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell, CellAuras = ns.RaidConfig, ns.RaidHeader, ns.RaidCell, ns.RaidAuras
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

local function member(name, class, subgroup)
    return { name = name, class = class, subgroup = subgroup, assignedRole = "DAMAGER" }
end
M.SetRaidRoster({ member("Ann", "PRIEST", 1), member("Bob", "MAGE", 1) })
M.RunTimers()

-- A container per cell with a unit.
local header = Header.headers[1]
H.check("header: no container template", header:GetAttribute("auraContainerTemplate"), nil)
local cell = header:GetAttribute("child1")
local c = cell.raidAuras.container
H.checkTrue("cell: container", c)
H.check("container on the cell", c:GetParent(), cell)
H.check("a custom aura container", c._template, "CustomAuraContainerTemplate")
H.check("the second block's empty cell: none", Header.headers[2]:GetAttribute("child1").raidAuras.container, nil)
H.check("container: the cell's unit", c:GetUnit(), "raid1")
H.check("container: no edit mode samples", c:IsEditModePreviewEnabled(), false)
H.check("container: above the texts", c:GetFrameLevel(), cell:GetFrameLevel() + CellAuras.LEVELS)
H.check("no aura groups", #c._groupOrder, 0)

-- The centre icon: one slot, debuffs you can dispel.
H.check("one slot", table.concat(c._slotOrder, ","), "dispel")
local slot = c._slots.dispel
H.check("dispellable by me", slot.filter, "HARMFUL|RAID")
H.check("enabled", slot.enabled, true)
local icon = slot.frame
H.check("icon size: 10 profile", icon:GetWidth(), 20)
local p, rel, relPoint = icon:GetPoint(1)
H.checkTrue("icon centred on the health bar", p == "CENTER" and rel == cell.health and relPoint == "CENTER")
H.check("icon registered", icon._icon, icon.icon)
H.check("swipe registered", icon._durationCooldown, icon.cooldown)
H.check("count registered", icon._applicationCount, icon.count)
local border = icon._dispelTextures[1]
H.check("border by dispel type", border.texture, icon.border)
H.check("border colours: our curve", border.options.customDispelColorCurve, ns.AuraButton.DispelCurve())
H.check("no countdown numbers", icon.cooldown._hideNumbers, true)
H.check("clicks go to the cell", icon._clickEnabled, false)

-- Settings of the active size.
RC.Set("r10", "dispelFilter", "ALL")
H.check("all dispellable", slot.filter, "HARMFUL|DISPELLABLE")
RC.Set("r10", "dispelIconSize", 26)
H.check("icon resized", icon:GetWidth(), 26)
RC.Set("r20", "dispelIconSize", 30)
H.check("another size's profile: unchanged", icon:GetWidth(), 26)
RC.Set("r10", "dispelIcon", false)
H.check("icon off: slot disabled", slot.enabled, false)
RC.Set("r10", "dispelIcon", true)
H.check("icon on again", slot.enabled, true)

-- The tint: a slot of its own, made when first switched on.
RC.Set("r10", "dispelTint", true)
local tint = c._slots.tint
H.checkTrue("tint slot made", tint)
H.check("tint: same filter", tint.filter, "HARMFUL|DISPELLABLE")
local tintTexture = tint.frame.tint
local entry = tint.frame._dispelTextures[1]
H.check("tint texture registered", entry.texture, tintTexture)
H.check("tint: lighter colours", entry.options.customDispelColorCurve, ns.AuraButton.DispelCurve(CellAuras.TINT_ALPHA))
H.check("tint curve: magic at the tint opacity", entry.options.customDispelColorCurve.points[2][2].a, 0.35)
H.check("border curve stays opaque", ns.AuraButton.DispelCurve().points[2][2].a, 1)
H.check("tint over the health bar", tintTexture._allPoints, cell.health)
H.check("tint under the texts", tint.frame:GetFrameLevel(), cell:GetFrameLevel() + CellAuras.TINT_LEVELS)
H.check("tint: no mouse", tint.frame._motionEnabled, false)
RC.Set("r10", "dispelTint", false)
H.check("tint off: disabled", tint.enabled, false)
RC.ResetScope("r10")
H.check("reset: mine again", slot.filter, "HARMFUL|RAID")

-- A roster change that keeps the unit: the container looks again.
local updates = c._updates
M.SetRaidRoster({ member("Cid", "PRIEST", 1), member("Bob", "MAGE", 1) })
H.checkTrue("same unit, someone else: updated", c._updates > updates)

-- In combat: settings wait, and a cell made now gets its slots after it.
M.combat = true
RC.Set("r10", "dispelFilter", "ALL")
H.check("combat: filter unchanged", slot.filter, "HARMFUL|RAID")
M.SetRaidRoster({ member("Cid", "PRIEST", 1), member("Bob", "MAGE", 1), member("Dan", "ROGUE", 1) })
local late = header:GetAttribute("child3")
H.check("combat join: no container yet", late.raidAuras.container, nil)
M.SetCombat(false)
H.check("after combat: filter", slot.filter, "HARMFUL|DISPELLABLE")
local lateContainer = late.raidAuras.container
H.check("after combat: the new cell's slot", lateContainer._slots.dispel.filter, "HARMFUL|DISPELLABLE")
H.check("after combat: its unit", lateContainer:GetUnit(), "raid3")
H.check("nothing blocked", #M.blocked, 0)

-- Auras secret out of combat (an instance): a resize is refused and tried
-- again after the next combat.
M.aurasSecret = true
RC.Set("r10", "dispelIconSize", 24)
M.aurasSecret = false
H.check("secret: icon kept its size", icon:GetWidth(), 20)
M.combat = true
M.SetCombat(false)
H.check("after combat: resized", icon:GetWidth(), 24)
RC.ResetScope("r10")
H.check("no errors", #M.errors, 0)

-- Test mode's pretend cells have no container.
ns.TestMode.Set(true)
H.check("pretend cell: no container", Cell.fakes[1].raidAuras.container, nil)
H.check("pretend cell: nothing built", Cell.fakes[1].raidAuras.built, nil)
ns.TestMode.Set(false)

-- Unit frames build nothing of it.
H.check("player frame: nothing", ns.Frames.player.raidAuras, nil)

-- A client without aura containers: cells without auras, no error.
ns = H.LoadAddon()
M.auraContainerMissing = true
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ member("Ann", "PRIEST", 1) })
H.check("no containers: the cell has none", ns.RaidHeader.headers[1]:GetAttribute("child1").raidAuras.container, nil)
H.check("no containers: no error", #M.errors, 0)
