-- The raid tools bar's world markers (Raid/Tools.lua): secure buttons
-- whose action is the client's (worldmarker), for everyone in a party and
-- the leader and assistants in a raid (Raid/Tools.lua Tools.Marks), each
-- drawn with the raid target icon of its sign; the last one takes them
-- all away. Not where the client has no world markers.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1, isPlayer = true }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, RS, Tools = ns.RaidConfig, ns.RaidSettings, ns.RaidTools

H.check("code", RS.Get("toolsMarkers").code, "IW")
H.check("on", RC.Get("general", "toolsMarkers"), true)
RC.Set("general", "toolsMode", "FREE")
-- Folded out (folded in, only its handle shows: tests/test_raid_tools_fold.lua).
RC.Set("general", "toolsOpen", true)
local row = Tools.rows[3]
H.check("the third row", row.id, "markers")
local f = row.frame
H.check("eight and a clear button", #f.buttons, 9)
local blue = f.buttons[1]
H.checkTrue("secure", blue:IsProtected())
H.check("type", blue:GetAttribute("*type1"), "worldmarker")
H.check("its marker", blue:GetAttribute("marker"), 1)
H.check("toggles", blue:GetAttribute("action"), "toggle")
H.check("no unit", blue:GetAttribute("unit"), nil)
H.check("the square's sign", blue.icon._spriteCell[1], 6)
H.check("the skull's sign", f.buttons[8].icon._spriteCell[1], 8)
H.check("clear all", f.clear:GetAttribute("action") .. tostring(f.clear:GetAttribute("marker")), "clearnil")

M.units.party1 = { name = "Ann", class = "PRIEST", isPlayer = true }
M.SetGroup({ "party1" })
H.checkTrue("a party, not leading: shown", f:IsShown())
M.units.player.leader = true
M.FireEvent("PARTY_LEADER_CHANGED")
H.checkTrue("leading: shown", f:IsShown())
H.check("the action", M.SecureClick(blue, "LeftButton"), "worldmarker")
H.check("placed", M.worldMarkers[1], true)
M.SecureClick(f.buttons[4], "LeftButton")
H.check("the red cross too", M.worldMarkers[4], true)
M.SecureClick(blue, "LeftButton")
H.check("again: taken away", M.worldMarkers[1], nil)
M.SecureClick(f.clear, "LeftButton")
H.check("cleared: none left", next(M.worldMarkers), nil)
H.check("both strokes", table.concat(blue._clicks, ","), "AnyUp,AnyDown")
H.check("right button: nothing", M.SecureClick(blue, "RightButton"), nil)
H.check("right button: not placed", M.worldMarkers[1], nil)

-- A client without world markers: no row.
M.worldMarkerSystem = false
RC.Set("general", "toolsMarkers", false)
RC.Set("general", "toolsMarkers", true)
H.check("no world markers: hidden", f:IsShown(), false)
M.worldMarkerSystem = true
RC.Set("general", "toolsMarkers", false)
H.check("off: hidden", f:IsShown(), false)
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
