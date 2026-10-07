-- The raid tools bar (Raid/Tools.lua): shown in a group while the raid
-- frames are on; free, at its own position with its own mover (docked:
-- tests/test_raid_tools_docked.lua); the raid target icons are secure
-- buttons whose action is the client's. Built, shown and moved out of
-- combat only. The raid window's Tools tab.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1, isPlayer = true }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, RS, Tools = ns.RaidConfig, ns.RaidSettings, ns.RaidTools

-- The settings: per character.
local CODES = { toolsShow = "IO", toolsX = "IX", toolsY = "IY", toolsTargets = "IT" }
for key, code in pairs(CODES) do
    local def = RS.Get(key)
    H.check(key .. " code", def and def.code, code)
    H.check(key .. " per character", def and RS.AppliesTo(def, "general"), true)
end
H.check("shown", RC.Get("general", "toolsShow"), true)
H.check("position", RC.Get("general", "toolsX") .. "," .. RC.Get("general", "toolsY"), "-60,370")
H.check("raid target icons", RC.Get("general", "toolsTargets"), true)
RC.Set("general", "toolsMode", "FREE")
-- Folded out (folded in, only its handle shows: tests/test_raid_tools_fold.lua).
RC.Set("general", "toolsOpen", true)
-- The raid target icons alone: every other row off (they have tests of
-- their own).
for _, row in ipairs(Tools.rows) do
    if row.key ~= "toolsTargets" then RC.Set("general", row.key, false) end
end

-- Built at login; solo it hides.
local bar = Tools.bar
H.check("built", bar:GetName(), "ForeverUnitFramesRaidTools")
H.check("solo: hidden", bar:IsShown(), false)
H.check("its mover", bar.mover.spec.id, "raidTools")
H.check("moved with the raid window", bar.mover.spec.group, "raid")
local function point(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    local name = rel == UIParent and "UIParent" or rel == bar.mover and "mover" or "?"
    return table.concat({ p, name, relPoint, x, y }, " ")
end
H.check("at its position", point(bar.mover), "TOPLEFT UIParent CENTER -60 370")
H.check("hangs from its mover", point(bar), "TOPLEFT mover TOPLEFT 0 0")

-- The raid target icons.
local row = Tools.rows[1].frame
H.check("eight icons and a clear button", #row.buttons, 9)
local skull = row.buttons[8]
H.checkTrue("secure", skull:IsProtected())
H.check("type", skull:GetAttribute("*type1"), "raidtarget")
H.check("on your target", skull:GetAttribute("unit"), "target")
H.check("its marker", skull:GetAttribute("marker"), 8)
H.check("toggles", skull:GetAttribute("action"), "toggle")
H.check("its icon: the sheet", skull.icon._texture, ns.RaidMarker.TEXTURE)
H.check("its icon: the skull's cell", table.concat(skull.icon._spriteCell, ","), "8,4,4")
H.check("clear", row.clear:GetAttribute("action"), "clear")
H.check("a row of nine", row:GetWidth() .. "x" .. row:GetHeight(), (9 * 18 + 8 * 2) .. "x18")
H.check("the bar around it", Tools.width .. "x" .. Tools.height, (9 * 18 + 8 * 2 + 8) .. "x" .. (18 + 8))

-- A party: shown; the icons act on your target.
M.units.party1 = { name = "Ann", class = "PRIEST", isPlayer = true }
M.SetGroup({ "party1" })
H.checkTrue("party: shown", bar:IsShown())
M.units.target = { name = "Boar" }
H.check("click: the action", M.SecureClick(skull, "LeftButton"), "raidtarget")
H.check("skull on the target", M.units.target.raidTarget, 8)
M.SecureClick(skull, "LeftButton")
H.check("again: off", M.units.target.raidTarget, nil)
-- Both strokes registered: the client acts on the one the player's
-- setting picks (CVar ActionButtonUseKeyDown), once.
H.check("both strokes", table.concat(skull._clicks, ","), "AnyUp,AnyDown")
H.check("right button: nothing", M.SecureClick(row.buttons[2], "RightButton"), nil)
H.check("right button: no circle", M.units.target.raidTarget, nil)
M.SecureClick(row.buttons[2], "LeftButton")
H.check("left button: a circle", M.units.target.raidTarget, 2)
M.SecureClick(row.clear, "LeftButton")
H.check("cleared", M.units.target.raidTarget, nil)
M.cvars.ActionButtonUseKeyDown = "0"
M.SecureClick(skull, "LeftButton")
H.check("on the up stroke: the skull", M.units.target.raidTarget, 8)
M.cvars.ActionButtonUseKeyDown = "1"
M.SecureClick(row.clear, "LeftButton")
H.check("set by the client's secure code, once a click", #M.raidTargetCalls, 6)
-- No target: the client does nothing.
M.units.target = nil
H.check("no target: nothing", M.SecureClick(skull, "LeftButton"), nil)
H.check("no target: no call", #M.raidTargetCalls, 6)

-- Off, or the raid frames off: hidden.
RC.Set("general", "toolsShow", false)
H.check("off: hidden", bar:IsShown(), false)
RC.Set("general", "toolsShow", true)
RC.Set("general", "enabled", false)
H.check("raid frames off: hidden", bar:IsShown(), false)
RC.Set("general", "enabled", true)
H.checkTrue("on again", bar:IsShown())
RC.Set("general", "toolsTargets", false)
H.check("no tool: hidden", bar:IsShown(), false)
H.check("no tool: a handle's size", Tools.width, 0)
RC.Set("general", "toolsTargets", true)

-- The panels do not follow the bar's settings.
local styled, original = 0, ns.RaidCell.Style
ns.RaidCell.Style = function(...) styled = styled + 1; return original(...) end
RC.Set("general", "toolsTargets", false)
RC.Set("general", "toolsTargets", true)
ns.RaidCell.Style = original
H.check("no relayout of the panels", styled, 0)

-- The raid window's lock shows its handle while it shows.
ns.Movers.Unlock("raid")
H.checkTrue("handle shown", bar.mover:IsShown())
H.check("handle label", bar.mover.label:GetText(), "Raid tools")
RC.Set("general", "toolsY", 200)
H.check("moved", point(bar.mover), "TOPLEFT UIParent CENTER -60 200")
ns.Movers.Lock("raid")

-- In combat: the group changes, the bar waits for the end of combat.
M.combat = true
M.SetGroup({})
H.checkTrue("combat: still shown", bar:IsShown())
H.check("combat: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
H.check("after combat: hidden solo", bar:IsShown(), false)

-- Test mode shows it solo, so it can be placed.
ns.RaidTestMode.Set(true)
H.checkTrue("test mode: shown", bar:IsShown())
ns.RaidTestMode.Set(false)
H.check("test mode off: hidden", bar:IsShown(), false)

-- The raid window: a Tools tab; the position as - / + numbers that stop
-- at the screen's edge for the bar's size.
local tab = ns.RaidSchema.TABS[12]
H.check("Tools tab before Profile", tab.id, "tools")
H.check("the bar's section", table.concat(tab.sections[1].keys, ","), "toolsShow,toolsMode,toolsOpen,toolsX,toolsY")
H.check("the tools: the icons first", tab.sections[2].keys[1], "toolsTargets")
H.check("its position", ns.RaidPanel.ByPositionKey("toolsX"), Tools)
local RO = ns.RaidOptions
RO.Open(10, "tools")
local x
for _, r in ipairs(RO.rows) do if r.key == "toolsX" then x = r end end
H.checkTrue("x: - and + buttons", x.minus and x.plus)
H.check("x: its label", x.label:GetText(), "Position X")
UIParent._w, UIParent._h = 1000, 600
M.Type(x.edit, "4000")
M.PressEnter(x.edit)
H.check("x: the right edge for its size", RC.Get("general", "toolsX"), 500 - Tools.Size())
UIParent._w, UIParent._h = 1920, 1080
RO.Close()
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
