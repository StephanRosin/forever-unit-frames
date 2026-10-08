-- Raid panels (Raid/Panel.lua): the main panel (Raid/Header.lua) is the
-- first panel; another panel made from a spec gets its own anchor,
-- headers, mover and plain frames, is built and laid out with the main
-- one, and waits for the end of combat like it.
local M = H.M
local ns = H.LoadAddon()
local RC, Panel, Header, Cell = ns.RaidConfig, ns.RaidPanel, ns.RaidHeader, ns.RaidCell
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

H.check("the main panel first", Panel.list[1], Header)
H.check("the main panel's id", Header.id, "main")
H.check("its position keys", Header.POSITION_KEYS.x .. Header.POSITION_KEYS.y, "xy")

-- A panel of group 2 alone, at the main panel's position.
local P = Panel.New({
    id = "test", name = "TestRaidPanel", xKey = "x", yKey = "y",
    blocks = function() return { { kind = "GROUP", id = 2, capacity = 5, filter = { groupFilter = "2" } } } end,
    shape = Header.Shape, enabled = Panel.Enabled, hideEmpty = function() return true end,
    label = function() return "Test" end, blockRing = false,
})
H.check("listed after the main panel", Panel.list[#Panel.list], P)
H.check("not built yet", P.anchor, nil)

Header.Create()
H.check("built with the main panel", P.anchor:GetName(), "TestRaidPanel")
local h = P.headers[1]
H.check("its header", h:GetName(), "TestRaidPanelBlock1")
H.check("a group header", h._template, "SecureGroupHeaderTemplate")
H.check("its filter", h:GetAttribute("groupFilter"), "2")
H.check("its cells' scope", h.cellKey, Cell.KEY)
H.check("the main panel's cells' scope", Header.headers[1].cellKey, Cell.KEY)
H.check("a mover of its own", P.anchor.mover.spec.id, "raid:test")
H.check("moved with the raid window", P.anchor.mover.spec.group, "raid")
H.check("the main panel's mover", Header.anchor.mover.spec.id, "raid")
H.check("hidden solo", P.panel:IsShown(), false)

local function member(name, class, subgroup)
    return { name = name, class = class, subgroup = subgroup, unit = { health = 100, healthMax = 100, powerType = 0 } }
end
local list = {}
for i = 1, 8 do list[i] = member("M" .. i, "MAGE", i <= 5 and 1 or 2) end
M.SetRaidRoster(list)
M.RunTimers()
H.checkTrue("shown in a raid", P.panel:IsShown())
H.check("group 2 here", P.Count(1), 3)
H.check("and in the main panel too", Header.Count(2), 3)
-- A group block's five cells are made ahead of time (Units/Units.lua).
H.check("its cells", #P.Cells(), 5)
H.check("the main panel's cells", #Header.Cells(), 10)
H.check("room for a group", P.width .. "x" .. P.height, "96x228")
H.checkTrue("its ring", P.panel.border and P.panel.border[1]:IsShown())
RC.Set("r10", "blockBorder", true)
H.check("no ring around its single block", P.decor[1].border == nil or not P.decor[1].border[1]:IsShown(), true)
H.checkTrue("the main panel's blocks have theirs", Header.decor[1].border[1]:IsShown())
RC.Set("r10", "blockBorder", false)

-- Settings reach every panel; in combat after combat.
RC.Set("r10", "cellSpacing", 4)
H.check("spacing here", h:GetAttribute("yOffset"), -4)
H.check("spacing there", Header.headers[1]:GetAttribute("yOffset"), -4)
M.combat = true
RC.Set("r10", "cellSpacing", 2)
H.check("combat: waits here", h:GetAttribute("yOffset"), -4)
H.check("combat: waits there", Header.headers[1]:GetAttribute("yOffset"), -4)
M.SetCombat(false)
H.check("after combat here", h:GetAttribute("yOffset"), -2)
H.check("after combat there", Header.headers[1]:GetAttribute("yOffset"), -2)

-- Test mode: a panel without pretend members of its own stays empty.
ns.RaidTestMode.Set(true)
H.check("test mode: its header hidden", h:IsShown(), false)
H.check("test mode: no room", P.width, 0)
ns.RaidTestMode.Set(false)
H.check("back to the raid", P.Count(1), 3)
H.check("its header again", h:IsShown(), true)

-- The raid frames off: every panel hides.
RC.Set("general", "enabled", false)
H.check("off: its header hidden", h:IsShown(), false)
H.check("off: its panel hidden", P.panel:IsShown(), false)
RC.Set("general", "enabled", true)
H.checkTrue("on again", h:IsShown() and P.panel:IsShown())
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
