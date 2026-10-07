-- An own panel's mover (Raid/OwnPanels.lua, Core/Movers.lua): in the raid
-- group, shown while the panel is, its top-left corner per raid size,
-- dragged and typed positions kept inside the screen for its size; only
-- it moves.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Movers = ns.RaidConfig, ns.RaidHeader, ns.Movers
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
Header.Create()
local P = ns.RaidOwnPanels.panels.panel4
local mover = P.anchor.mover

H.check("combat-queue id", mover.spec.id, "raid:panel4")
H.check("the raid window's movers", mover.spec.group, "raid")
H.check("its position settings", ns.RaidPanel.ByPositionKey("panel4Y"), P)
H.check("its axis", select(2, ns.RaidPanel.ByPositionKey("panel4X")), "x")

-- Off: no handle when unlocked; on: there.
Movers.Unlock("raid")
H.check("off: no handle", mover:IsShown(), false)
RC.Set("r10", "panel4Show", true)
H.checkTrue("on: handle", mover:IsShown())
local p, rel, relPoint, x, y = mover:GetPoint(1)
H.check("at its own spot", table.concat({ p, rel == UIParent and "UIParent" or "?", relPoint, x, y }, " "),
    "TOPLEFT UIParent CENTER 580 300")
H.check("empty: a cell's size", mover:GetWidth() .. "x" .. mover:GetHeight(), "96x44")

-- Dragged: the shown size's corner, snapped; the main panel stays.
local w, h = mover:GetWidth(), mover:GetHeight()
mover._cx, mover._cy = 97 + w / 2, -47 - h / 2
Movers.OnDragStop(mover)
H.check("x stored", RC.Get("r10", "panel4X"), 96)
H.check("y stored", RC.Get("r10", "panel4Y"), -48)
H.check("other sizes keep theirs", RC.Get("r20", "panel4X"), 580)
H.check("the main panel stays", RC.Get("r10", "x"), -600)
H.check("anchor follows", select(4, P.anchor.mover:GetPoint(1)), 96)

-- Dragged past the edge: kept inside the screen for its size.
UIParent._w, UIParent._h = 1000, 600
mover._cx, mover._cy = 2000, 0
Movers.OnDragStop(mover)
H.check("x: the right edge", RC.Get("r10", "panel4X"), 500 - w)
H.check("typed beyond: the edge", P.Reachable("y", 4000, true), 300)

-- Changing its position moves it alone, without a relayout.
local styled = 0
local style = ns.RaidCell.Style
ns.RaidCell.Style = function(...) styled = styled + 1; return style(...) end
RC.Set("r10", "panel4X", -100)
ns.RaidCell.Style = style
H.check("moved", select(4, mover:GetPoint(1)), -100)
H.check("no relayout", styled, 0)

-- Off again: the handle goes.
RC.Set("r10", "panel4Show", false)
H.check("off: handle hidden", mover:IsShown(), false)
Movers.Lock("raid")
H.check("no error", #M.errors, 0)
