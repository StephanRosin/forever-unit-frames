-- Raid test mode (Raid/TestMode.lua): with test mode on, a pretend raid
-- of the active size where the blocks are, laid out like the real ones;
-- secure buttons on the player with samples of their own. Off, or on
-- entering combat, the real headers come back.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell, Test = ns.RaidConfig, ns.RaidHeader, ns.RaidCell, ns.RaidTestMode
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100, healthMissing = 0, power = 50, powerMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

local function point(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    return table.concat({ p, rel == Header.anchor and "anchor" or "?", relPoint, x, y }, " ")
end

-- The pretend members.
local members = Test.Members(40)
H.check("forty", #members, 40)
H.check("member 1", members[1].class .. " " .. members[1].assignedRole .. " " .. members[1].subgroup, "WARRIOR TANK 1")
H.check("member 6: second group", members[6].subgroup, 2)
H.check("name: Blizzard's class name", members[2].name, "Priest")
H.check("member 3 dead", members[3].status, "DEAD")
H.check("member 7 offline", members[7].status, "OFFLINE")
H.check("others alive", members[4].status, false)

-- On: ten pretend cells for the 10-player profile, in groups 1 and 2.
ns.TestMode.Set(true)
H.checkTrue("panel shown solo", Header.panel:IsShown())
H.check("headers hidden", Header.headers[1]:IsShown(), false)
local shown = 0
for _, f in ipairs(Cell.fakes) do if f:IsShown() then shown = shown + 1 end end
H.check("ten pretend cells", shown, 10)
local f1, f6 = Cell.fakes[1], Cell.fakes[6]
H.check("first cell: block 1", point(f1), "TOPLEFT anchor TOPLEFT 0 0")
H.check("second cell below", point(Cell.fakes[2]), "TOPLEFT anchor TOPLEFT 0 -46")
H.check("sixth cell: block 2", point(f6), "TOPLEFT anchor TOPLEFT 102 0")
H.check("cell size", f1:GetWidth() .. "x" .. f1:GetHeight(), "96x44")
H.check("panel as with a full raid", Header.panel:GetWidth() .. "x" .. Header.panel:GetHeight(), "198x228")
H.check("on the player", f1:GetAttribute("unit"), "player")
H.check("left click targets", M.SecureClick(f1, "LeftButton"), "target")
H.check("not for click-casting", (ClickCastFrames or {})[f1], nil)
H.check("sample name", f1.texts.healthLeft:GetText(), "Warrior")
H.check("sample health", Cell.fakes[4].health:GetValue(), 0.35)
H.check("sample class colour", f1.health._color[1], 0.78)
H.check("dead", Cell.fakes[3].texts.healthRight:GetText(), ns.L.STATUS_DEAD)
H.check("offline", Cell.fakes[7].texts.healthRight:GetText(), ns.L.STATUS_OFFLINE)
H.check("warrior: no mana strip", f1.power:IsShown(), false)
H.checkTrue("priest: mana strip", Cell.fakes[2].power:IsShown())
local seen = {}
ns.Units.ForEachFrame(function(frame) seen[frame] = true end)
H.checkTrue("every-frame loop reaches them", seen[f1])

-- The player AFK: the pretend cells keep their samples (they sit on the
-- player, but never show its live state).
local sampleSecond = Cell.fakes[4].texts.healthRight:GetText()
M.units.player.afk = true
M.FireEvent("PLAYER_FLAGS_CHANGED", "player")
H.check("player AFK: sample's second line kept", Cell.fakes[4].texts.healthRight:GetText(), sampleSecond)
H.checkTrue("player AFK: not the AFK word", Cell.fakes[4].texts.healthRight:GetText() ~= "AFK")
H.check("player AFK: dead sample still dead", Cell.fakes[3].texts.healthRight:GetText(), ns.L.STATUS_DEAD)
M.units.player.afk = nil
M.FireEvent("PLAYER_FLAGS_CHANGED", "player")

-- By class: the pretend members go to their class blocks, packed.
RC.Set("r10", "groupBy", "CLASS")
H.check("warriors first", point(Cell.fakes[1]), "TOPLEFT anchor TOPLEFT 0 0")
H.check("both warriors in the warrior block", point(Cell.fakes[2]), "TOPLEFT anchor TOPLEFT 0 -46")
H.check("second warrior's sample", Cell.fakes[2].texts.healthLeft:GetText(), "Warrior")
H.check("paladin block next", point(Cell.fakes[3]), "TOPLEFT anchor TOPLEFT 102 0")
-- By name within one block.
RC.Set("r10", "groupBy", "NONE")
RC.Set("r10", "sortBy", "NAME")
H.check("one block: group 1 first, by name", Cell.fakes[1].texts.healthLeft:GetText(), "Hunter")
RC.ResetScope("r10")

-- The 40-player profile: forty cells.
RC.Set("general", "sizeMode", "40")
shown = 0
for _, f in ipairs(Cell.fakes) do if f:IsShown() then shown = shown + 1 end end
H.check("forty pretend cells", shown, 40)
H.check("cells of the 40 profile", Cell.fakes[1]:GetWidth(), 80)
RC.Set("general", "sizeMode", "AUTO")

-- Raid frames off: no pretend raid.
RC.Set("general", "enabled", false)
H.check("off: pretend cells hidden", Cell.fakes[1]:IsShown(), false)
H.check("off: panel hidden", Header.panel:IsShown(), false)
RC.Set("general", "enabled", true)
H.checkTrue("on: back", Cell.fakes[1]:IsShown())

-- Off out of combat: the pretend cells go, samples and all; the real
-- headers come back.
ns.TestMode.Set(false)
H.check("off: test mode off", ns.TestMode.IsOn(), false)
local stale = 0
for _, f in ipairs(Cell.fakes) do
    if f:IsShown() or f.sample ~= nil or f.unit ~= nil then stale = stale + 1 end
end
H.check("off: pretend cells hidden, samples cleared", stale, 0)
H.checkTrue("off: headers back", Header.headers[1]:IsShown())
H.check("off: panel hidden solo", Header.panel:IsShown(), false)
ns.TestMode.Set(true)
H.checkTrue("on again: pretend cells back", Cell.fakes[1]:IsShown())
H.check("on again: samples back", Cell.fakes[1].texts.healthLeft:GetText(), "Warrior")

-- Entering combat ends test mode; the real headers come back.
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: test mode off", ns.TestMode.IsOn(), false)
H.check("combat: pretend cells hidden", Cell.fakes[1]:IsShown(), false)
H.checkTrue("combat: headers back", Header.headers[1]:IsShown())
H.check("combat: samples cleared", Cell.fakes[1].sample, nil)
H.check("combat: panel hidden solo", Header.panel:IsShown(), false)
H.check("nothing blocked", #M.blocked, 0)

-- Combat lockdown had already begun: the panel's border goes at once (a
-- plain frame), the pretend cells wait for the end of combat.
ns.TestMode.Set(true)
H.checkTrue("lockdown: panel shown in test mode", Header.panel:IsShown())
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("lockdown: test mode off", ns.TestMode.IsOn(), false)
H.check("lockdown: panel hidden at once", Header.panel:IsShown(), false)
H.checkTrue("lockdown: pretend cells wait", Cell.fakes[1]:IsShown())
H.check("lockdown: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
H.check("after combat: pretend cells hidden", Cell.fakes[1]:IsShown(), false)
H.checkTrue("after combat: headers back", Header.headers[1]:IsShown())
H.check("after combat: panel hidden solo", Header.panel:IsShown(), false)
H.check("after combat: nothing blocked", #M.blocked, 0)
