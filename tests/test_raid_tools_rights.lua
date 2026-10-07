-- The raid tools bar shows a tool only to whom may use it (Raid/Tools.lua):
-- the raid target icons to everyone in a party, in a raid to the leader,
-- the assistants and everyone while everyone is an assistant (as
-- Blizzard's raid manager, Blizzard_CompactRaidFrameManager.lua,
-- CompactRaidFrameManager_UpdateOptionsFlowContainer). Everyone an
-- assistant counts as an assistant for the other leading tools too.
-- A secret answer counts as no; test mode shows everything. A change of
-- rights refreshes the bar (PARTY_LEADER_CHANGED, GROUP_ROSTER_UPDATE).
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1, isPlayer = true }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, Tools = ns.RaidConfig, ns.RaidTools
RC.Set("general", "toolsMode", "FREE")
local rows = {}
for _, row in ipairs(Tools.rows) do rows[row.id] = row.frame end
local targets, ready, markers, group = rows.targets, rows.ready, rows.markers, rows.group
local b = group.buttons

-- A party, not leading: the icons (anyone may mark), nothing else that leads.
M.units.party1 = { name = "Ann", class = "PRIEST", isPlayer = true }
M.SetGroup({ "party1" })
H.checkTrue("party: the icons", targets:IsShown())
H.check("party: no ready check start", ready.start:IsShown(), false)
H.check("party: no world markers", markers:IsShown(), false)

-- A raid, neither leader nor assistant: no icons.
local function member(name, subgroup)
    return { name = name, class = "PRIEST", subgroup = subgroup, unit = { health = 100, healthMax = 100, powerType = 0 } }
end
M.SetGroup({})
M.SetRaidRoster({ member("Me", 1), member("Ann", 1), member("Bob", 2) })
M.units.player = M.units.raid1
M.FireEvent("PARTY_LEADER_CHANGED")
H.check("raid, no rights: no icons", targets:IsShown(), false)
H.check("raid, no rights: no markers", markers:IsShown(), false)
H.checkTrue("raid, no rights: the ready result still", ready:IsShown())
H.check("raid, no rights: no start", ready.start:IsShown(), false)

-- Made an assistant: the icons come (PARTY_LEADER_CHANGED).
M.units.raid1.assistant = true
M.FireEvent("PARTY_LEADER_CHANGED")
H.checkTrue("assistant: the icons", targets:IsShown())
-- ... and go again with the roster's next word (GROUP_ROSTER_UPDATE).
M.units.raid1.assistant = false
M.FireEvent("GROUP_ROSTER_UPDATE")
H.check("demoted: no icons", targets:IsShown(), false)
M.units.raid1.leader = true
M.FireEvent("PARTY_LEADER_CHANGED")
H.checkTrue("leader: the icons", targets:IsShown())
M.units.raid1.leader = false
M.FireEvent("PARTY_LEADER_CHANGED")

-- Everyone an assistant: the icons and the assistants' tools, not the leader's.
M.everyoneAssistant = true
M.FireEvent("GROUP_ROSTER_UPDATE")
H.checkTrue("everyone assists: the icons", targets:IsShown())
H.checkTrue("everyone assists: world markers", markers:IsShown())
H.checkTrue("everyone assists: ready check start", ready.start:IsShown())
H.checkTrue("everyone assists: role poll", b.rolePoll:IsShown())
H.check("everyone assists: no leader tools", b.assist:IsShown() or b.convert:IsShown() or b.loot:IsShown(), false)
-- Secret answers count as no.
local realEveryone = IsEveryoneAssistant
_G.IsEveryoneAssistant = function() return M.Secret(true) end
M.FireEvent("GROUP_ROSTER_UPDATE")
H.check("everyone assists, secret: no icons", targets:IsShown(), false)
_G.IsEveryoneAssistant = realEveryone
M.everyoneAssistant = false
M.units.raid1.assistant = true
M.groupSecret = true
M.FireEvent("PARTY_LEADER_CHANGED")
H.check("assistant, secret: no icons", targets:IsShown(), false)
M.groupSecret = false

-- In combat a change waits for its end (the row holds secure buttons).
M.FireEvent("PARTY_LEADER_CHANGED")
H.checkTrue("assistant again: the icons", targets:IsShown())
M.combat = true
M.units.raid1.assistant = false
M.FireEvent("PARTY_LEADER_CHANGED")
H.checkTrue("combat: unchanged", targets:IsShown())
M.SetCombat(false)
H.check("after combat: no icons", targets:IsShown(), false)

-- Test mode: everything, so it can be placed.
ns.RaidTestMode.Set(true)
H.checkTrue("test mode: the icons", targets:IsShown())
H.checkTrue("test mode: markers", markers:IsShown())
ns.RaidTestMode.Set(false)
H.check("test mode off: no icons", targets:IsShown(), false)
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)

-- The wiki's Tools page: which tool needs which rights.
local dir = os.tmpname()
os.remove(dir)
os.execute("mkdir -p '" .. dir .. "'")
_G.WIKI_OUT = dir
local ok, err = pcall(dofile, ADDONDIR .. "/tools/make_wiki.lua")
_G.WIKI_OUT = nil
H.checkTrue("generator runs", ok, err)
local fh = io.open(dir .. "/Raid-Tools.md")
local page = fh and fh:read("*a") or ""
if fh then fh:close() end
os.execute("rm -rf '" .. dir .. "'")
H.checkTrue("rights: a section", page:find("## Who may use which tool", 1, true))
H.checkTrue("rights: the icons", page:find("<tr><td><b>Raid target icons</b></td><td>Everyone</td><td>Leader, assistants</td></tr>", 1, true))
H.checkTrue("rights: everyone an assistant", page:find("everyone counts as an assistant", 1, true))
H.check("the note", ns.L.RAID_NOTE_tools, "A tool shows only to those who may use it (in test mode to everyone).")
