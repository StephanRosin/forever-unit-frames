-- /fuf news (Core/Commands.lua): the news of this version again, any
-- time, without touching what was recorded; the help and the window's
-- footer name it.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.addonVersion = "0.22.0"
_G.ForeverUnitFramesDB = { profile = {}, newsSeen = "0.22.0" }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local run, NW, L = SlashCmdList.FOREVERUNITFRAMES, ns.NewsWindow, ns.L

H.check("seen: not shown at login", NW.IsOpen(), false)
run("news")
H.checkTrue("/fuf news opens it", NW.IsOpen())
H.check("the news of this version", NW.frame.titleBar.title:GetText(), "What's new in 0.22.0")
H.check("the footer names the command", NW.hint:GetText(), "/fuf news shows this again.")
H.check("newsSeen untouched", ForeverUnitFramesDB.newsSeen, "0.22.0")
run("NEWS")
H.checkTrue("any case, open again", NW.IsOpen())
NW.Close()

-- In combat too: a plain window.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
run("news")
H.checkTrue("in combat too", NW.IsOpen())
M.SetCombat(false)
NW.Close()

-- A version without news says so.
M.addonVersion = "0.22.1"
local chatBefore = #M.chat
run("news")
H.check("no news: no window", NW.IsOpen(), false)
H.check("no news: one line", #M.chat, chatBefore + 1)
H.check("no news: says so", M.chat[#M.chat]:find(L.NEWS_NONE, 1, true) ~= nil, true)
H.check("no news: newsSeen untouched", ForeverUnitFramesDB.newsSeen, "0.22.0")

-- The help names it, in every language.
run("help")
H.checkTrue("help names /fuf news", M.chat[#M.chat]:find("/fuf news", 1, true))
for _, code in ipairs({ "deDE", "esES", "frFR" }) do
    H.checkTrue(code .. ": help names /fuf news", ns.Locales[code].HELP:find("/fuf news", 1, true))
    H.checkTrue(code .. ": hint names /fuf news", ns.Locales[code].NEWS_AGAIN:find("/fuf news", 1, true))
end
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
