-- The raid tools bar's ready check (Raid/Tools.lua): the last result for
-- everyone, counted from the readable answers; starting one only for the
-- leader and assistants (all tools in test mode). Who leads changes the
-- row after combat.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1, isPlayer = true }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, RS, Tools = ns.RaidConfig, ns.RaidSettings, ns.RaidTools

H.check("code", RS.Get("toolsReady").code, "IR")
H.check("on", RC.Get("general", "toolsReady"), true)
RC.Set("general", "toolsMode", "FREE")
local row = Tools.rows[2]
H.check("the second row", row.id, "ready")
local f = row.frame

local function member(name, subgroup)
    return { name = name, class = "PRIEST", subgroup = subgroup, unit = { health = 100, healthMax = 100, powerType = 0 } }
end
M.SetRaidRoster({ member("Me", 1), member("Ann", 1), member("Bob", 1), member("Cid", 2) })
M.units.player = M.units.raid1
M.RunTimers()

-- Not leading: the result's place, no button; nothing before a check.
H.checkTrue("row shown", f:IsShown())
H.check("no start button", f.start:IsShown(), false)
H.check("no result yet", f.counts.ready.icon:IsShown(), false)
H.check("no count", f.counts.ready.text:GetText(), "")
H.check("ready mark", f.counts.ready.icon._atlas, "UI-LFG-ReadyMark-Raid")
H.check("the row: the result alone", f:GetWidth(), 3 * (18 + 22))

-- Leading: the button starts a check.
M.units.raid1.leader = true
M.FireEvent("PARTY_LEADER_CHANGED")
H.checkTrue("leader: start button", f.start:IsShown())
H.check("its words", f.start.text:GetText(), "Ready check")
H.check("the row: button and result", f:GetWidth(), 90 + 4 + 3 * (18 + 22))
f.start:GetScript("OnClick")(f.start)
H.check("started", M.partyCalls[#M.partyCalls][1], "DoReadyCheck")
-- Refused by the client: a line in the chat, no Lua error.
M.partyRefused.DoReadyCheck = true
local calls, lines = #M.partyCalls, #M.chat
H.checkTrue("refused: no error", pcall(f.start:GetScript("OnClick"), f.start))
H.check("refused: nothing asked", #M.partyCalls, calls)
H.check("refused: said", M.chat[lines + 1], "|cff4fc3f7Forever Unit Frames:|r Ready check: not allowed right now.")
M.partyRefused.DoReadyCheck = nil

-- The answers come in.
M.units.raid1.readyCheck = "ready"
for i = 2, 4 do M.units["raid" .. i].readyCheck = "waiting" end
M.FireEvent("READY_CHECK", "Me", 30)
H.checkTrue("result shown", f.counts.ready.icon:IsShown())
H.check("ready", f.counts.ready.text:GetText(), "1")
H.check("waiting", f.counts.waiting.text:GetText(), "3")
M.units.raid2.readyCheck = "ready"
M.units.raid3.readyCheck = "notready"
M.FireEvent("READY_CHECK_CONFIRM", "raid2", true)
M.FireEvent("READY_CHECK_CONFIRM", "raid3", false)
H.check("two ready", f.counts.ready.text:GetText(), "2")
H.check("one not", f.counts.notready.text:GetText(), "1")
H.check("one waiting", f.counts.waiting.text:GetText(), "1")
-- Over: whoever did not answer is not ready; the result stays. The
-- client no longer reports the answers then (the mock clears them): the
-- counts come from the last ones read.
M.FireEvent("READY_CHECK_FINISHED", false)
H.check("finished: no answer readable", GetReadyCheckStatus("raid2"), nil)
H.check("finished: still two ready", f.counts.ready.text:GetText(), "2")
H.check("finished: two not ready", f.counts.notready.text:GetText(), "2")
H.check("finished: none waiting", f.counts.waiting.text:GetText(), "0")
M.Tick(20)
M.RunTimers()
H.check("the last result stays", f.counts.ready.text:GetText(), "2")

-- An answer that cannot be read is left out.
M.units.raid1.readyCheck = "ready"
M.units.raid2.readyCheck = M.Secret("ready")
M.FireEvent("READY_CHECK", "Me", 30)
H.check("secret: not counted", f.counts.ready.text:GetText(), "1")
M.units.raid2.readyCheck = nil

-- Leading changes in combat: the row follows after combat.
M.combat = true
M.units.raid1.leader = false
M.FireEvent("PARTY_LEADER_CHANGED")
H.checkTrue("combat: button kept", f.start:IsShown())
H.check("combat: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
H.check("after combat: gone", f.start:IsShown(), false)
M.units.raid1.assistant = true
M.FireEvent("PARTY_LEADER_CHANGED")
H.checkTrue("an assistant: the button", f.start:IsShown())
M.units.raid1.assistant = false
M.groupSecret = true
M.FireEvent("PARTY_LEADER_CHANGED")
H.check("unreadable: not leading", f.start:IsShown(), false)
M.groupSecret = false

-- Test mode: every tool.
ns.RaidTestMode.Set(true)
H.checkTrue("test mode: the button", f.start:IsShown())
ns.RaidTestMode.Set(false)

-- Switched off.
RC.Set("general", "toolsReady", false)
H.check("off: no row", f:IsShown(), false)
H.check("the tab's note", ns.RaidSchema.Note("tools"), ns.L.RAID_NOTE_tools)
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
