-- The raid panel's mover (Core/Movers.lua with a raid spec): its handle
-- covers the panel, holds the top-left corner of the active size's
-- profile (raid profile, not the unit-frame one) and shows while the raid
-- frames are on.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Movers = ns.RaidConfig, ns.RaidHeader, ns.Movers
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
Header.Create()
local mover = Header.anchor.mover
H.checkTrue("mover made", mover)
H.check("combat-queue id", mover.spec.id, "raid")
local p, rel, relPoint, x, y = mover:GetPoint(1)
H.check("handle at the top-left corner", table.concat({ p, rel == UIParent and "UIParent" or "?", relPoint, x, y }, " "),
    "TOPLEFT UIParent CENTER -600 150")
p, rel = Header.anchor:GetPoint(1)
H.checkTrue("panel follows the handle", p == "TOPLEFT" and rel == mover)
H.check("empty panel: a cell's size", mover:GetWidth() .. "x" .. mover:GetHeight(), "96x44")
H.check("label", mover.label:GetText(), "Raid 10")

-- Dragged: the raid profile of the active size takes the corner, snapped
-- to the movers' grid; the unit frames' profile is not touched.
Movers.Unlock()
H.checkTrue("shown when unlocked", mover:IsShown())
local w, h = mover:GetWidth(), mover:GetHeight()
mover._cx, mover._cy = 97 + w / 2, -47 - h / 2
Movers.OnDragStop(mover)
H.check("x stored", RC.Get("r10", "x"), 96)
H.check("y stored", RC.Get("r10", "y"), -48)
H.check("unit frames untouched", ns.Config.IsOverridden("party", "x"), false)
H.check("handle follows", select(4, mover:GetPoint(1)) .. "," .. select(5, mover:GetPoint(1)), "96,-48")

-- A raid: the handle covers the blocks.
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 }, { name = "Bob", class = "MAGE", subgroup = 2 } })
M.RunTimers()
H.check("handle covers the panel", mover:GetWidth() .. "x" .. mover:GetHeight(), "198x228")

-- Another size: its own corner, its own label.
RC.Set("r20", "x", 200)
RC.Set("general", "sizeMode", "20")
H.check("20: own corner", select(4, mover:GetPoint(1)), 200)
H.check("20: label", mover.label:GetText(), "Raid 20")

-- Switched off: no handle.
RC.Set("general", "enabled", false)
H.check("off: handle hidden", mover:IsShown(), false)
RC.Set("general", "enabled", true)
H.checkTrue("on: handle back", mover:IsShown())
Movers.Lock()
H.check("locked: hidden", mover:IsShown(), false)
