-- Corner indicators of raid cells (Raid/Indicators.lua): an aura slot of
-- the cell's container per position with spells, the container's own
-- spell filter, the square, swipe and number as regions of the slot's
-- frame. Positions without spells make no slot.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Raid, Ind = ns.RaidConfig, ns.RaidHeader, ns.Raid, ns.RaidIndicators
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 }, { name = "Bob", class = "MAGE", subgroup = 1 } })
M.RunTimers()

local cell = Header.headers[1]:GetAttribute("child1")
local other = Header.headers[1]:GetAttribute("child2")
local c = cell.raidAuras.container
H.check("none by default", table.concat(c._slotOrder, ","), "dispel")
H.check("slot key", Ind.SlotKey(Raid.INDICATORS[1]), "indicatorTOPLEFT")
H.check("spell set", Ind.SpellSet("139, 6074")[6074], true)
H.check("empty: off", Ind.SpellSet(""), nil)

-- Renew in the top left corner.
RC.Set("r10", "indicatorTopLeftSpells", "139, 6074")
local slot = c._slots.indicatorTOPLEFT
H.checkTrue("a slot", slot)
H.check("your own buffs", slot.filter, "HELPFUL|PLAYER")
H.check("the spells, as a map", slot.candidateFilters.includeSpellIDs[139], true)
H.check("both ranks", slot.candidateFilters.includeSpellIDs[6074], true)
H.check("enabled", slot.enabled, true)
H.checkTrue("the other cell too", other.raidAuras.container._slots.indicatorTOPLEFT)
local b = slot.frame
H.check("size", b:GetWidth() .. "x" .. b:GetHeight(), "8x8")
local p, rel, relPoint, x, y = b:GetPoint(1)
H.checkTrue("in the corner", p == "TOPLEFT" and rel == cell and relPoint == "TOPLEFT")
H.check("a pixel in", x .. "," .. y, "1,-1")
H.check("green", b.color._color[2], 0.9)
H.check("dark edge", b.edge._color[1], 0)
H.check("swipe registered", b._durationCooldown, b.cooldown)
H.check("no number", b._durationText, nil)
H.check("no mouse", b._clickEnabled, false)

-- Settings of the position.
RC.Set("r10", "indicatorTopLeftOwn", false)
H.check("anyone's", slot.filter, "HELPFUL")
RC.Set("r10", "indicatorTopLeftTime", "NUMBER")
H.check("number registered", b._durationText, b.time)
H.check("swipe cleared", b._durationCooldown, nil)
RC.Set("r10", "indicatorTopLeftTime", "NONE")
H.check("no time: no number", b._durationText, nil)
H.check("no time: no swipe", b._durationCooldown, nil)
RC.Set("r10", "indicatorTopLeftSize", 12)
H.check("resized", b:GetWidth(), 12)
H.check("number font follows", select(2, b.time:GetFont()), 12)
RC.Set("r10", "indicatorTopLeftColor", { 0.5, 0, 1, 1 })
H.check("recoloured", b.color._color[1], 0.5)
RC.Set("r10", "indicatorTopLeftSpells", "774")
H.check("new spells", slot.candidateFilters.includeSpellIDs[774], true)
H.check("old ones gone", slot.candidateFilters.includeSpellIDs[139], nil)

-- The top centre.
RC.Set("r10", "indicatorTopSpells", "17")
local top = c._slots.indicatorTOP.frame
p, rel, relPoint, x, y = top:GetPoint(1)
H.checkTrue("top centre", p == "TOP" and relPoint == "TOP" and x == 0 and y == -1)
H.check("white", top.color._color[1], 1)

-- Spells removed: disabled, the frame kept.
RC.Set("r10", "indicatorTopLeftSpells", "")
H.check("off: disabled", slot.enabled, false)
H.check("off: still the same frame", c._slots.indicatorTOPLEFT.frame, b)

-- Another size: its own indicators (none).
RC.Set("general", "sizeMode", "40")
H.check("40: top centre off", c._slots.indicatorTOP.enabled, false)
RC.Set("general", "sizeMode", "AUTO")
H.check("10 again: on", c._slots.indicatorTOP.enabled, true)

-- In combat: after combat.
M.combat = true
RC.Set("r10", "indicatorBottomRightSpells", "10060")
H.check("combat: no slot yet", c._slots.indicatorBOTTOMRIGHT, nil)
M.SetCombat(false)
H.checkTrue("after combat: the slot", c._slots.indicatorBOTTOMRIGHT)
H.check("after combat: red", c._slots.indicatorBOTTOMRIGHT.frame.color._color[1], 1)
H.check("nothing blocked", #M.blocked, 0)
H.check("no errors", #M.errors, 0)
