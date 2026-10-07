-- Both options windows have the same footer on the left: [Unlock/Lock
-- frames] [Test mode] [the other window…], 120 wide, 8 apart, from 12 px;
-- on the right [Copy from…] [Reset …]. Each window's lock and test
-- buttons act on its own frames: the unit window on the unit frames, the
-- raid window on the raid panel (tests/test_movers_groups.lua).
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local O, RO, L, Movers = ns.Options, ns.RaidOptions, ns.L, ns.Movers

local function click(button) button:GetScript("OnClick")(button) end
local function place(widget)
    local p, rel, relPoint, x, y = widget:GetPoint(1)
    local names = { [O.unlockButton] = "unlock", [O.testButton] = "test", [RO.unlockButton] = "unlock",
        [RO.testButton] = "test", [O.resetFrameButton] = "reset", [RO.resetButton] = "reset" }
    local relName = names[rel] or (rel == widget:GetParent() and "footer") or "?"
    return table.concat({ p, relName, relPoint, x, y }, " ") .. " w" .. widget:GetWidth()
end

-- One builder makes the left group of both (the same layout by
-- construction).
local built = {}
local footerLeft = O.FooterLeft
O.FooterLeft = function(footer, spec)
    built[#built + 1] = spec.other.text
    return footerLeft(footer, spec)
end
O.Open("player")
RO.Open()
O.FooterLeft = footerLeft
H.check("both windows' left group from the shared builder", table.concat(built, ","),
    L.RAID_FRAMES_BUTTON .. "," .. L.UNIT_FRAMES_BUTTON)
local footer = O.unlockButton:GetParent()
local raidFooter = RO.unlockButton:GetParent()
H.check("raid window: footer", raidFooter, RO.frame.footer)
-- The raid window is wider: its eleven tabs need the room.
H.check("unit window's width", O.frame:GetWidth(), 780)
H.check("raid window's width", RO.frame:GetWidth(), 880)

-- Left: the same three places in both.
local LEFT = { "LEFT footer LEFT 12 0 w120", "LEFT unlock RIGHT 8 0 w120", "LEFT test RIGHT 8 0 w120" }
for i, pair in ipairs({ { O.unlockButton, RO.unlockButton }, { O.testButton, RO.testButton },
    { O.raidButton, RO.unitButton } }) do
    H.check("unit window left " .. i, place(pair[1]), LEFT[i])
    H.check("raid window left " .. i, place(pair[2]), LEFT[i])
end
H.check("unit: 3rd is the raid button", O.raidButton:GetParent(), footer)
H.check("raid: 3rd is the unit button", RO.unitButton:GetParent(), raidFooter)
-- The left group ends at 12 + 3 * 120 + 2 * 8 = 388.
-- Right: Reset at 12 from the right, Copy from… 8 left of it, both 160.
H.check("unit reset", place(O.resetFrameButton), "RIGHT footer RIGHT -12 0 w160")
H.check("raid reset", place(RO.resetButton), "RIGHT footer RIGHT -12 0 w160")
H.check("unit copy", place(O.copyRow), "RIGHT reset LEFT -8 0 w160")
H.check("raid copy", place(RO.copyRow), "RIGHT reset LEFT -8 0 w160")
-- 780 - 12 - 160 - 8 - 160 = 440: 52 px clear of the left group.

-- The labels.
H.check("raid lock label", RO.unlockButton.text:GetText(), L.UNLOCK_FRAMES)
H.check("raid test label", RO.testButton.text:GetText(), L.TEST_MODE_ON)

-- The raid window's lock button: the raid panel only.
click(RO.unlockButton)
H.checkTrue("raid unlocked", Movers.IsUnlocked("raid"))
H.check("unit frames stay locked", Movers.IsUnlocked("units"), false)
H.checkTrue("raid handle shown", ns.RaidHeader.anchor.mover:IsShown())
H.check("unit handle hidden", ns.Frames.player.mover:IsShown(), false)
H.check("raid label: lock", RO.unlockButton.text:GetText(), L.LOCK_FRAMES)
H.check("unit label unchanged", O.unlockButton.text:GetText(), L.UNLOCK_FRAMES)

-- The unit window's: the unit frames only.
click(O.unlockButton)
H.checkTrue("units unlocked", Movers.IsUnlocked("units"))
H.check("unit label: lock", O.unlockButton.text:GetText(), L.LOCK_FRAMES)
click(RO.unlockButton)
H.check("raid locked again", Movers.IsUnlocked("raid"), false)
H.check("raid label: unlock", RO.unlockButton.text:GetText(), L.UNLOCK_FRAMES)
H.checkTrue("units stay unlocked", Movers.IsUnlocked("units"))
H.check("unit label stays", O.unlockButton.text:GetText(), L.LOCK_FRAMES)
click(O.unlockButton)

-- /fuf lock locks both; both labels follow.
click(O.unlockButton)
click(RO.unlockButton)
SlashCmdList.FOREVERUNITFRAMES("lock")
H.check("/fuf lock: unit label", O.unlockButton.text:GetText(), L.UNLOCK_FRAMES)
H.check("/fuf lock: raid label", RO.unlockButton.text:GetText(), L.UNLOCK_FRAMES)

-- Test mode: the raid window's button the pretend raid only.
click(RO.testButton)
H.checkTrue("raid test on", ns.RaidTestMode.IsOwnOn())
H.check("unit test mode off", ns.TestMode.IsOn(), false)
click(RO.testButton)

-- Combat: like the unit window's, the lock button locks; the way across
-- stays open. Combat start locks the raid panel and the label follows.
click(RO.unlockButton)
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: raid lock button disabled", RO.unlockButton:IsEnabled(), false)
H.check("combat: unit lock button disabled", O.unlockButton:IsEnabled(), false)
H.check("combat: raid locked", Movers.IsUnlocked("raid"), false)
H.check("combat: raid label", RO.unlockButton.text:GetText(), L.UNLOCK_FRAMES)
H.checkTrue("combat: unit button usable", RO.unitButton:IsEnabled())
H.checkTrue("combat: raid button usable", O.raidButton:IsEnabled())
M.SetCombat(false)
H.checkTrue("after combat: raid lock button back", RO.unlockButton:IsEnabled())

-- A new language: the raid window rebuilt keeps its lock label.
click(RO.unlockButton)
ns.Config.Set("general", "language", "deDE")
H.check("deDE: raid lock label", RO.unlockButton.text:GetText(), "Rahmen sperren")
H.check("deDE: the raid button fits", O.raidButton.text:GetText(), "Schlachtzug…")
SlashCmdList.FOREVERUNITFRAMES("lock")
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
