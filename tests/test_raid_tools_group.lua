-- The raid tools bar's group row (Raid/Tools.lua): a role poll for the
-- leader and assistants; everyone an assistant (in a raid), party to raid
-- and back, the loot method for the leader. Plain buttons calling what
-- Blizzard's raid manager calls; the row follows who leads after combat
-- and the language at once.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1, isPlayer = true }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, RS, Tools = ns.RaidConfig, ns.RaidSettings, ns.RaidTools

local CODES = { toolsRolePoll = "IP", toolsAssist = "IA", toolsConvert = "IC", toolsLoot = "IL" }
for key, code in pairs(CODES) do
    H.check(key .. " code", RS.Get(key).code, code)
    H.check(key .. " on", RC.Get("general", key), true)
end
RC.Set("general", "toolsMode", "FREE")
local row = Tools.rows[4]
H.check("the fourth row", row.id, "group")
local f = row.frame
local b = f.buttons
local function click(button) button:GetScript("OnClick")(button) end
local function last() return M.partyCalls[#M.partyCalls] end

-- A party, not leading: no row.
M.units.party1 = { name = "Ann", class = "PRIEST", isPlayer = true }
M.SetGroup({ "party1" })
H.check("not leading: no row", f:IsShown(), false)
-- An assistant (a raid): the role poll alone.
local function member(name, subgroup)
    return { name = name, class = "PRIEST", subgroup = subgroup, unit = { health = 100, healthMax = 100, powerType = 0 } }
end
M.SetGroup({})
M.SetRaidRoster({ member("Me", 1), member("Ann", 1), member("Bob", 2) })
M.units.player = M.units.raid1
M.units.raid1.assistant = true
M.FireEvent("PARTY_LEADER_CHANGED")
H.checkTrue("assistant: the row", f:IsShown())
H.checkTrue("assistant: role poll", b.rolePoll:IsShown())
H.check("assistant: no leader tools", b.assist:IsShown() or b.convert:IsShown() or b.loot:IsShown(), false)
click(b.rolePoll)
H.check("role poll", last()[1], "InitiateRolePoll")

-- The leader: every tool.
M.units.raid1.assistant, M.units.raid1.leader = false, true
M.FireEvent("PARTY_LEADER_CHANGED")
H.checkTrue("leader: all four", b.rolePoll:IsShown() and b.assist:IsShown() and b.convert:IsShown() and b.loot:IsShown())
H.check("words", b.rolePoll.text:GetText() .. "|" .. b.assist.text:GetText() .. "|" .. b.convert.text:GetText()
    .. "|" .. b.loot.text:GetText(), "Role poll|All assist|To party|Loot")
local _, rel = b.assist:GetPoint(1)
H.check("in a row", rel, f)
H.check("the row's width", f:GetWidth(), b.rolePoll:GetWidth() + b.assist:GetWidth() + b.convert:GetWidth()
    + b.loot:GetWidth() + 3 * 2)

-- Everyone an assistant: outlined while on.
H.check("not outlined", b.assist.edges[1]._color[1], ns.Style.COLORS.border[1])
click(b.assist)
H.check("asks for everyone", last()[1] .. tostring(last()[2]), "SetEveryoneIsAssistanttrue")
M.everyoneAssistant = true
M.FireEvent("PARTY_LEADER_CHANGED")
H.check("outlined", b.assist.edges[1]._color[1], ns.Style.COLORS.accent[1])
b.assist:GetScript("OnEnter")(b.assist)
b.assist:GetScript("OnLeave")(b.assist)
H.check("still outlined after a hover", b.assist.edges[1]._color[1], ns.Style.COLORS.accent[1])
click(b.assist)
H.check("off again", tostring(last()[2]), "false")

-- Raid to party (five or fewer).
click(b.convert)
H.check("to party", last()[1], "ConvertToParty")
local six = {}
for i = 1, 6 do six[i] = member("M" .. i, 1 + math.floor((i - 1) / 5)) end
M.SetRaidRoster(six)
M.units.player = M.units.raid1
M.units.raid1.leader = true
M.FireEvent("PARTY_LEADER_CHANGED")
H.check("six: no way back to a party", b.convert:IsShown(), false)

-- The loot method: a menu of the methods, the current one marked.
M.lootMethod = Enum.LootMethod.Group
click(b.loot)
H.check("loot menu", M.menu.tag, "context")
H.check("its owner", M.menu.contextData.ownerFrame, b.loot)
local names = {}
for _, e in ipairs(M.menu.elements) do names[#names + 1] = e.text end
H.check("the methods", table.concat(names, "|"),
    "Loot|Free for all|Round robin|Master looter|Group loot|Need before greed|Personal loot")
H.check("group loot marked", M.MenuSelected(M.menu.elements[5]), true)
H.check("others not", M.MenuSelected(M.menu.elements[2]), false)
M.ClickMenu(M.menu.elements[4])
H.check("master looter: you", last()[1] .. "," .. last()[2] .. "," .. last()[3], "SetLootMethod,2,M1")
M.ClickMenu(M.menu.elements[2])
H.check("free for all: no looter", last()[2] .. "," .. tostring(last()[3]), "0,nil")
M.ClickMenu(M.menu.elements[7])
H.check("personal loot", last()[2] .. "," .. tostring(last()[3]), "5,nil")
M.lootMethod = Enum.LootMethod.Personal
click(b.loot)
H.check("personal loot marked", M.MenuSelected(M.menu.elements[7]), true)
-- The hints: who the role poll asks, who the master looter is.
H.check("role poll hint", ns.L.RAID_HINT_toolsRolePoll, "Asks everyone to confirm their role")
H.check("loot hint", ns.L.RAID_HINT_toolsLoot, "Master looter: yourself")

-- A party, leading: to raid; no everyone-assistant.
M.SetRaidRoster({})
M.units.player = { name = "Me", class = "MAGE", isPlayer = true, leader = true }
M.SetGroup({ "party1" })
H.check("party: to raid", b.convert.text:GetText(), "To raid")
H.check("party: no everyone-assistant", b.assist:IsShown(), false)
click(b.convert)
H.check("converted", last()[1], "ConvertToRaid")

-- Switched off one by one.
RC.Set("general", "toolsLoot", false)
H.check("loot off", b.loot:IsShown(), false)
RC.Set("general", "toolsRolePoll", false)
RC.Set("general", "toolsConvert", false)
H.check("all off: no row", f:IsShown(), false)
RC.Set("general", "toolsConvert", true)

-- Another language: the words, the buttons as wide as they need.
ns.Config.Set("general", "language", "deDE")
H.check("German", b.convert.text:GetText(), "Zu Schlachtzug")
H.checkTrue("wide enough", b.convert:GetWidth() > b.convert.text:GetStringWidth())
ns.Config.Set("general", "language", "AUTO")

-- Who leads changes in combat: after combat.
M.combat = true
M.units.player.leader = false
M.FireEvent("PARTY_LEADER_CHANGED")
H.checkTrue("combat: kept", f:IsShown())
H.check("combat: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
H.check("after combat: gone", f:IsShown(), false)
H.check("no error", #M.errors, 0)
