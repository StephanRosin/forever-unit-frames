-- Click-casting addons (Clique): every live unit button is entered in the
-- shared global ClickCastFrames; test mode's pretend buttons are not.
local M = H.M
_G.ClickCastFrames = nil
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.units.player = M.units.player or { name = "Me", health = 1, healthMax = 1 }
local CCF = _G.ClickCastFrames
H.checkTrue("the shared table exists", type(CCF) == "table")
for _, key in ipairs({ "player", "target", "targettarget", "focus", "pet" }) do
    H.checkTrue(key .. " registered", CCF[ns.Frames[key]])
end
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.SetGroup({ "party1" })
local m1 = ns.Party.header:GetAttribute("child1")
H.checkTrue("party member registered", CCF[m1])
H.checkTrue("its target registered", CCF[m1.targetButton])
H.checkTrue("its pet (beside) registered", CCF[m1.petButton])
ns.Config.Set("party", "partyShowPets", true)
for _, b in ipairs(ns.PartyPets.buttons) do H.checkTrue("listed pet registered", CCF[b]) end
M.SetGroup({})
ns.TestMode.Set(true)
H.check("pretend member not registered", CCF[ns.Party.fakes[1]], nil)
ns.TestMode.Set(false)

-- A table Clique already made (it loaded first) is used, not replaced.
local ns2
local theirs = setmetatable({}, { __newindex = function(t, k, v) rawset(t, k, v); t.seen = (t.seen or 0) + 1 end })
_G.ClickCastFrames = theirs
ns2 = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.check("their table kept", _G.ClickCastFrames, theirs)
H.checkTrue("entries went through their table", (theirs.seen or 0) > 0)
