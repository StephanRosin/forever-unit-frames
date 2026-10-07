-- Click-casting and Clique (Raid/ClickCast.lua): with Clique loaded our
-- click-casting is off by default (AUTO) and leaves the frames alone; it
-- can still be switched on.
local M = H.M
local ns = H.LoadAddon()
local RC, CC = ns.RaidConfig, ns.ClickCast
ns.Config.Use({})
ns.RaidProfiles.Attach({})
H.check("no Clique: on", CC.On(), true)
H.check("no Clique", CC.Clique(), false)
M.loadedAddons.Clique = true
H.check("Clique by name", CC.Clique(), true)
H.check("automatic: off", CC.On(), false)
RC.Set("general", "clickCast", "ON")
H.check("switched on anyway", CC.On(), true)
RC.Set("general", "clickCast", "OFF")
H.check("switched off", CC.On(), false)
M.loadedAddons.Clique = nil
H.check("off without Clique too", CC.On(), false)
RC.Set("general", "clickCast", "AUTO")
-- Clique's header frame alone counts too.
_G.ClickCastHeader = CreateFrame("Frame", nil, UIParent)
H.check("Clique's header", CC.Clique(), true)
_G.ClickCastHeader = nil

-- With Clique, a frame we never wrote keeps what Clique set.
M.loadedAddons.Clique = true
ns.RaidSize.Update()
ns.RaidHeader.Create()
M.SetRaidRoster({ { name = "A", class = "PRIEST", subgroup = 1, unit = { health = 1, healthMax = 1 } } })
M.RunTimers()
local cell = ns.RaidCell.buttons[1]
H.checkTrue("a cell", cell)
cell:SetAttribute("shift-type1", "spell")
RC.Set("general", "click1Ctrl", "focus")
H.check("ours not written", cell:GetAttribute("ctrl-type1"), nil)
H.check("Clique's kept", cell:GetAttribute("shift-type1"), "spell")
