local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

for _, key in ipairs({ "partyOrientation", "partySpacing", "partyShowPlayer", "partyShowSolo" }) do
    H.checkTrue(key .. " applies to party", S.AppliesTo(S.Get(key), "party"))
    H.check(key .. " not on player", S.AppliesTo(S.Get(key), "player"), false)
end

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local P, C = ns.Party, ns.Config
local header = P.header
-- Plain spacing here; room for docked castbars: test_castbar_place.lua.
C.Set("party", "castbarEnabled", false)

-- Vertical by default: the header stacks downwards with the spacing.
H.check("point", header:GetAttribute("point"), "TOP")
H.check("x offset", header:GetAttribute("xOffset"), 0)
H.check("y offset", header:GetAttribute("yOffset"), -12)
H.check("player hidden by default", header:GetAttribute("showPlayer"), false)
H.check("solo hidden by default", header:GetAttribute("showSolo"), false)
local w, h = P.BlockSize()
H.check("block width", w, 160)
H.check("block height", h, 4 * 46 + 3 * 12)

C.Set("party", "partySpacing", 4)
H.check("spacing -> y offset", header:GetAttribute("yOffset"), -4)
C.Set("party", "partyOrientation", "HORIZONTAL")
H.check("horizontal point", header:GetAttribute("point"), "LEFT")
H.check("horizontal x offset", header:GetAttribute("xOffset"), 4)
H.check("horizontal y offset", header:GetAttribute("yOffset"), 0)
w, h = P.BlockSize()
H.check("horizontal block width", w, 4 * 160 + 3 * 4)
H.check("horizontal block height", h, 46)
local sx, sy = P.SlotOffset(3)
H.check("slot 3 x", sx, 2 * (160 + 4))
H.check("slot 3 y", sy, 0)
C.Set("party", "partyOrientation", "VERTICAL")
sx, sy = P.SlotOffset(3)
H.check("vertical slot 3 x", sx, 0)
H.check("vertical slot 3 y", sy, -2 * (46 + 4))

-- Show player / show when solo go straight to the header.
C.Set("party", "partyShowPlayer", true)
H.checkTrue("show player", header:GetAttribute("showPlayer"))
H.check("five slots with the player", P.Slots(), 5)
C.Set("party", "partyShowSolo", true)
H.checkTrue("show solo", header:GetAttribute("showSolo"))
H.check("solo: player shown", header:GetAttribute("child1"):GetAttribute("unit"), "player")
H.checkTrue("solo: button visible", header:GetAttribute("child1"):IsShown())
M.units.party1 = { name = "Ann", health = 1, healthMax = 2 }
M.SetGroup({ "party1" })
H.check("party with player first", header:GetAttribute("child1"):GetAttribute("unit"), "player")
H.check("then the member", header:GetAttribute("child2"):GetAttribute("unit"), "party1")
C.Set("party", "partyShowPlayer", false)
H.check("without player", header:GetAttribute("child1"):GetAttribute("unit"), "party1")

-- The whole block has one mover; X / Y are the block's centre.
local mover = header.mover
H.checkTrue("block mover", mover)
local point, rel, relPoint = header:GetPoint(1)
H.check("header hangs from the mover", rel, mover)
H.check("top-left to top-left", point, "TOPLEFT")
H.check("mover width = block", mover:GetWidth(), 160)
H.check("mover height = block", mover:GetHeight(), 4 * 46 + 3 * 4)
local _, _, _, mx, my = mover:GetPoint(1)
H.check("mover x", mx, -760)
H.check("mover y", my, 120)
C.Set("party", "x", -700)
_, _, _, mx = mover:GetPoint(1)
H.check("numeric X moves the block", mx, -700)
ns.Movers.Unlock()
H.checkTrue("block mover shown when unlocked", mover:IsShown())
mover._cx, mover._cy = 960 - 500, 540 + 100
UIParent._cx, UIParent._cy = 960, 540
ns.Movers.OnDragStop(mover)
H.check("drag writes party x", C.Get("party", "x"), -504)
H.check("drag writes party y", C.Get("party", "y"), 104)
-- No handle for a party block that is switched off.
C.Set("party", "enabled", false)
H.check("disabled party: no block mover", mover:IsShown(), false)
C.Set("party", "enabled", true)
H.checkTrue("enabled party: block mover back", mover:IsShown())
ns.Movers.Lock()

-- Generic movers: own position keys, no anchoring, shown only when active.
local target = CreateFrame("Frame", nil, UIParent)
local active = false
C.Set("player", "width", 200)
ns.Movers.Attach(target, { scope = "player", xKey = "height", yKey = "healthPercent", anchor = false,
    size = function() return 50, 10 end, label = "Probe", id = "probe", active = function() return active end })
H.check("no anchoring when anchor = false", target._points[1], nil)
H.check("custom size", target.mover:GetWidth(), 50)
local _, _, _, px, py = target.mover:GetPoint(1)
H.check("custom x key", px, C.Get("player", "height"))
H.check("custom y key", py, C.Get("player", "healthPercent"))
ns.Movers.Unlock()
H.check("inactive mover stays hidden", target.mover:IsShown(), false)
active = true
C.Set("player", "width", 210)   -- any change re-evaluates while unlocked
H.checkTrue("active mover appears", target.mover:IsShown())
ns.Movers.Lock()
H.check("locked: hidden", target.mover:IsShown(), false)
