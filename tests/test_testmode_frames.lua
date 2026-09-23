local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, P = ns.Config, ns.Party
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10 }

H.checkTrue("test mode on", ns.TestMode.Set(true))

-- Every single frame shows the player.
for _, key in ipairs({ "player", "target", "targettarget", "pet", "focus" }) do
    local f = ns.Frames[key]
    H.check(key .. ": player data", f:GetAttribute("unit"), "player")
    H.checkTrue(key .. ": shown", f:IsShown())
    H.check(key .. ": no unit watch", f._unitWatch, nil)
end
H.check("pet health from the player", ns.Frames.pet.health:GetValue(), 5)

-- Sample casts on enabled castbars only (the player's is off by default).
local tbar = ns.Frames.target.castbar
H.checkTrue("target: sample cast", tbar:IsShown())
H.check("sample cast name", tbar.text:GetText(), ns.L.TEST_CAST)
-- A spell icon Blizzard's own UI uses (PET_WAIT_TEXTURE), so it exists.
H.check("sample icon constant", ns.Castbar.PREVIEW_ICON, "Interface\\Icons\\Spell_Nature_TimeStop")
H.check("sample icon shown", tbar.icon._texture, ns.Castbar.PREVIEW_ICON)
H.check("player castbar off: no sample", ns.Frames.player.castbar:IsShown(), false)
C.Set("player", "castbarEnabled", true)
H.checkTrue("switched on during test mode: sample", ns.Frames.player.castbar:IsShown())
M.units.player.cast = nil
M.FireEvent("UNIT_SPELLCAST_STOP", "player", "x", 1)
H.checkTrue("real events leave the sample alone", ns.Frames.player.castbar:IsShown())
M.Tick(0.25)
H.checkTrue("timer leaves the tot sample alone", ns.Frames.targettarget.castbar:IsShown())

-- The party block becomes a pretend party of four on the player.
H.check("real header hidden", P.header:IsShown(), false)
H.checkTrue("test block shown", P.testBlock:IsShown())
H.check("four pretend members", #P.fakes, 4)
for i, b in ipairs(P.fakes) do
    H.check("fake " .. i .. " unit", b:GetAttribute("unit"), "player")
    H.check("fake " .. i .. " secure", b._template, "SecureUnitButtonTemplate")
    H.check("fake " .. i .. " clicks target", b:GetAttribute("*type1"), "target")
    H.checkTrue("fake " .. i .. " shown", b:IsShown())
    H.check("fake " .. i .. " width", b:GetWidth(), 160)
end
-- Vertically the docked party castbar sits between members (Party.Spacing).
H.check("fake 2 below fake 1", select(5, P.fakes[2]:GetPoint(1)),
    -(36 + 12 + ns.Castbar.DockedDepth("party")))
H.check("fake health", P.fakes[3].health:GetValue(), 5)
H.checkTrue("fake sample cast", P.fakes[1].castbar:IsShown())
H.check("fakes are not header buttons", #P.buttons, 1)

-- Party settings apply to the pretend party at once.
C.Set("party", "partyOrientation", "HORIZONTAL")
H.check("horizontal: fake 2 to the right", select(4, P.fakes[2]:GetPoint(1)), 160 + 12)
C.Set("party", "partyShowPlayer", true)
H.check("with the player: five", #P.fakes, 5)
H.checkTrue("fifth shown", P.fakes[5]:IsShown())
C.Set("party", "partyShowPlayer", false)
H.check("without the player: fifth hidden", P.fakes[5]:IsShown(), false)
C.Set("party", "enabled", false)
H.check("disabled party: block hidden", P.testBlock:IsShown(), false)
C.Set("party", "enabled", true)
H.checkTrue("enabled again: block shown", P.testBlock:IsShown())

-- The options window outlines the pretend party while testing.
ns.Options.Open("party")
H.check("highlight on the test block", P.HighlightTarget(), P.testBlock)
M.RunTimers()

-- Off: real header back, pretend party gone, castbars back to real casts.
ns.TestMode.Set(false)
H.checkTrue("header back", P.header:IsShown())
H.check("test block hidden", P.testBlock:IsShown(), false)
H.check("fakes hidden", P.fakes[1]:IsShown(), false)
H.check("target back on target", ns.Frames.target:GetAttribute("unit"), "target")
H.check("sample cast gone", tbar:IsShown(), false)
H.check("preview flag cleared", tbar.preview, nil)
H.check("highlight on the block again", P.HighlightTarget(), P.highlightBlock)

-- Released, not just hidden: no events, no sample cast; reused next time.
local firstFake = P.fakes[1]
for i, b in ipairs(P.fakes) do
    H.check("off: fake " .. i .. " unbound", next(b.eventListener._events), nil)
    H.check("off: fake " .. i .. " preview cleared", b.castbar.preview, nil)
end
ns.TestMode.Set(true)
H.check("on again: same buttons", P.fakes[1], firstFake)
H.check("on again: no new buttons", #P.fakes, 5)
H.check("on again: fake bound to the player", P.fakes[1].unit, "player")
H.checkTrue("on again: fake sample cast", P.fakes[1].castbar:IsShown())
ns.TestMode.Set(false)

-- Combat ends test mode for the party too.
ns.TestMode.Set(true)
M.FireEvent("PLAYER_REGEN_DISABLED")
H.checkTrue("combat: header back", P.header:IsShown())
H.check("combat: fakes hidden", P.fakes[1]:IsShown(), false)

-- Lockdown already started: the party is handed back after combat.
ns.TestMode.Set(true)
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.checkTrue("late combat: fakes still up in combat", P.fakes[1]:IsShown())
M.SetCombat(false)
H.check("late combat: fakes hidden after combat", P.fakes[1]:IsShown(), false)
H.checkTrue("late combat: header back after combat", P.header:IsShown())
