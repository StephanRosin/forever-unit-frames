-- Own panels (Raid/OwnPanels.lua): Panel 2 to Panel 10, raid panels
-- (Raid/Panel.lua) built with the main one, each with the blocks of its
-- grouping it takes, in the main panel's order; its own layout, borders and title;
-- the main panel's cells of the size. None shows by default.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Own = ns.RaidConfig, ns.RaidHeader, ns.RaidOwnPanels
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

H.check("nine own panels", #Own.list, 9)
local P = Own.panels.panel2
H.check("panel 2 first", Own.list[1], P)
H.check("panel 10 last", Own.list[9].id, "panel10")
H.check("listed after the special panels", ns.RaidPanel.list[#ns.RaidPanel.list], Own.panels.panel10)
H.check("not built before the main panel", P.anchor, nil)
-- A panel that is off is not laid out: no placing, nothing told.
local placed = {}
ns.Listen("RAID_PANEL_PLACED", function(panel) placed[panel.id] = (placed[panel.id] or 0) + 1 end)
Header.Create()
H.check("off: not placed", placed.panel2, nil)
H.checkTrue("the main panel placed", (placed.main or 0) > 0)
H.check("anchor", P.anchor:GetName(), "ForeverUnitFramesRaidPanel2")
H.check("off: no block", #P.blocks, 0)
H.check("off: no header made", #P.headers, 0)
H.check("off: hidden", P.panel:IsShown(), false)

local function member(name, subgroup, class, role)
    return { name = name, class = class or "WARRIOR", subgroup = subgroup, assignedRole = role }
end
local function point(frame, anchor)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    local name = rel == UIParent and "UIParent" or rel == anchor and "anchor" or "?"
    return table.concat({ p, name, relPoint, x, y }, " ")
end
local roster = { member("A", 1, "WARRIOR", "TANK"), member("B", 1, "PRIEST", "HEALER"), member("C", 1, "MAGE"),
    member("D", 2, "DRUID", "HEALER"), member("E", 2, "ROGUE", "DAMAGER"), member("F", 2, "PRIEST", "HEALER") }
M.SetRaidRoster(roster)
M.RunTimers()

-- Shown with group 2: one block, the group's.
RC.Set("r10", "panel2Show", true)
RC.Set("r10", "panel2Blocks", "2")
M.RunTimers()
local h = P.headers[1]
H.check("one block", #P.blocks, 1)
H.checkTrue("on: placed", (placed.panel2 or 0) > 0)
H.checkTrue("on: its mover", P.anchor.mover ~= nil)
H.check("header", h:GetName(), "ForeverUnitFramesRaidPanel2Block1")
H.check("group 2's filter", h:GetAttribute("groupFilter"), "2")
H.check("the main panel's cells", h:GetAttribute("template"), ns.RaidCell.TEMPLATE)
H.check("three members", P.Count(1), 3)
H.check("in raid order", h:GetAttribute("child1").unit, "raid4")
H.checkTrue("shown", P.panel:IsShown() and h:IsShown())
H.check("a group keeps room for five", P.width .. "x" .. P.height, 96 .. "x" .. (5 * 44 + 4 * 2))
H.checkTrue("the gold ring", P.panel.border and P.panel.border[1]:IsShown())
H.check("at its own spot", point(P.anchor.mover), "TOPLEFT UIParent CENTER 360 300")
H.check("cells at the panel's corner", point(h, P.anchor), "TOPLEFT anchor TOPLEFT 0 0")

-- Its own grouping: the roles it takes, in the main panel's order (the
-- role order), not as stored; only the blocks of that grouping count.
RC.Set("r10", "panel2GroupBy", "ROLE")
RC.Set("r10", "panel2Blocks", "HEALER,TANK,2")
M.RunTimers()
H.check("two role blocks", #P.blocks, 2)
H.check("tanks first", P.headers[1]:GetAttribute("roleFilter"), "TANK")
H.check("then healers", P.headers[2]:GetAttribute("roleFilter"), "HEALER")
H.check("strict", P.headers[1]:GetAttribute("strictFiltering"), true)
H.check("one tank", P.Count(1), 1)
H.check("three healers", P.Count(2), 3)
H.check("by size: no group 3 at 10", (function()
    RC.Set("r10", "panel2GroupBy", "GROUP")
    RC.Set("r10", "panel2Blocks", "3,1")
    M.RunTimers()
    return #P.blocks .. ":" .. P.headers[1]:GetAttribute("groupFilter")
end)(), "1:1")
H.check("the unused header hidden", P.headers[2]:IsShown(), false)
RC.Set("r10", "panel2GroupBy", "CLASS")
RC.Set("r10", "panel2Blocks", "PRIEST")
M.RunTimers()
H.check("a class block", P.headers[1]:GetAttribute("groupFilter"), "1,2,PRIEST")
H.check("two priests", P.Count(1), 2)

-- Its own layout: cells per line and growth, blocks side by side or
-- stacked, block titles, empty blocks.
RC.Set("r10", "panel2Blocks", "PRIEST,DRUID,MAGE")
RC.Set("r10", "panel2CellGrowth", "RIGHT")
M.RunTimers()
H.check("cells in a row", P.headers[1]:GetAttribute("point"), "LEFT")
H.check("the main panel's growth kept", Header.headers[1]:GetAttribute("point"), "TOP")
H.check("three blocks side by side", P.width, (2 * 96 + 2) + 6 + 96 + 6 + 96)
RC.Set("r10", "panel2BlockDirection", "VERTICAL")
M.RunTimers()
H.check("stacked", P.width, 2 * 96 + 2)
RC.Set("r10", "panel2BlocksPerLine", 2)
M.RunTimers()
H.check("two per column", P.width, (2 * 96 + 2) + 6 + 96)
RC.Set("r10", "panel2BlockTitles", true)
M.RunTimers()
H.check("block titles", P.decor[1].title:GetText(), LOCALIZED_CLASS_NAMES_MALE.PRIEST)
H.check("none on the main panel", Header.decor[1].title:IsShown(), false)
RC.Set("r10", "panel2Blocks", "PRIEST,WARLOCK")
M.RunTimers()
H.check("an empty block hidden", P.decor[2]:IsShown(), false)
RC.Set("r10", "panel2HideEmpty", false)
M.RunTimers()
H.checkTrue("shown when asked", P.decor[2]:IsShown())

-- Its own borders: the panel's ring, each block's.
RC.Set("r10", "panel2PanelBorder", false)
RC.Set("r10", "panel2BlockBorder", true)
M.RunTimers()
H.check("no ring around the panel", P.panel.border[1]:IsShown(), false)
H.checkTrue("the main panel's ring kept", Header.panel.border[1]:IsShown())
H.checkTrue("a ring around each block", P.decor[1].border and P.decor[1].border[1]:IsShown())
H.check("none around the main panel's blocks", Header.decor[1].border == nil or not Header.decor[1].border[1]:IsShown(),
    true)

-- A title above the panel: a row of its own, the blocks below it.
RC.Set("r10", "panel2BlockTitles", false)
RC.Set("r10", "panel2Blocks", "PRIEST")
RC.Set("r10", "panel2HideEmpty", true)
M.RunTimers()
local plain = P.height
RC.Set("r10", "panel2Title", "Healers")
M.RunTimers()
H.check("title", P.title:GetText(), "Healers")
H.checkTrue("title shown", P.title:IsShown())
H.check("a row for it", P.height, plain + 14)
H.check("the block below it", point(P.headers[1], P.anchor), "TOPLEFT anchor TOPLEFT 0 -14")
H.check("named on the mover", P.anchor.mover.label:GetText(), "Healers 10")
-- A title longer than the panel is cut short (the client's ellipsis): it
-- spans the panel's width on one line; the panel keeps its width.
local titledWidth = P.width
RC.Set("r10", "panel2Title", ("W"):rep(ns.Raid.OWN_TITLE_LETTERS))
M.RunTimers()
local function titlePoints()
    local list = {}
    for i = 1, 2 do
        local p, rel, relPoint = P.title:GetPoint(i)
        list[i] = table.concat({ p, rel == P.panel and "panel" or "?", relPoint }, " ")
    end
    return table.concat(list, ", ")
end
H.check("long title: the panel's width kept", P.width, titledWidth)
H.check("long title: edge to edge", titlePoints(), "TOPLEFT panel TOPLEFT, TOPRIGHT panel TOPRIGHT")
H.check("long title: one line", P.title:GetWordWrap(), false)
RC.Set("r10", "panel2Title", "Healers")
M.RunTimers()
RC.Set("r10", "panel2Title", "")
M.RunTimers()
H.check("no title: hidden", P.title:IsShown(), false)
H.check("no title: no row", P.height, plain)
H.check("mover: the panel's number", P.anchor.mover.label:GetText(), "Panel 2 10")

-- Per size: 40 does not show it.
RC.Set("general", "sizeMode", "40")
M.RunTimers()
H.check("40: off", P.panel:IsShown(), false)
H.check("40: no block", #P.blocks, 0)
H.check("40: its header hidden", P.headers[1]:IsShown(), false)
RC.Set("general", "sizeMode", "AUTO")
M.RunTimers()
H.checkTrue("10 again", P.panel:IsShown())

-- In combat a change waits; nothing protected is touched.
M.combat = true
RC.Set("r10", "panel2Blocks", "PRIEST,DRUID")
H.check("combat: not yet", #P.blocks, 1)
H.check("combat: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
M.RunTimers()
H.check("after combat", #P.blocks, 2)

-- Off again: hidden, headers too.
RC.Set("r10", "panel2Show", false)
M.RunTimers()
H.check("off: panel hidden", P.panel:IsShown(), false)
H.check("off: headers hidden", P.headers[1]:IsShown() or P.headers[2]:IsShown(), false)
H.check("no error", #M.errors, 0)
