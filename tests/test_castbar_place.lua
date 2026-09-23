local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

H.checkTrue("position on single frames", S.AppliesTo(S.Get("castbarPosition"), "focus"))
H.check("no detached party castbars", S.AppliesTo(S.Get("castbarPosition"), "party"), false)
H.checkTrue("party docks", S.AppliesTo(S.Get("castbarDock"), "party"))
H.check("dock is party only", S.AppliesTo(S.Get("castbarDock"), "target"), false)
H.check("detached X not on party", S.AppliesTo(S.Get("castbarX"), "party"), false)

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
local t = ns.Frames.target
local bar = t.castbar

-- Above the frame.
C.Set("target", "castbarPosition", "ABOVE")
local point, rel, relPoint, x, y = bar:GetPoint(1)
H.check("above: bar bottom", point, "BOTTOMLEFT")
H.check("above: to the frame top", relPoint, "TOPLEFT")
H.check("above: to the frame", rel, t)
H.check("above: icon inset", x, 16)
H.check("above: flush like the rows", y, 0)

-- Detached: anchored to its own mover, which X / Y place.
H.checkTrue("detachable castbar has a mover", bar.mover)
C.Set("target", "castbarPosition", "DETACHED")
point, rel = bar:GetPoint(1)
H.check("detached: to its mover", rel, bar.mover)
H.check("detached: icon inset kept", select(4, bar:GetPoint(1)), 16)
local _, _, _, mx, my = bar.mover:GetPoint(1)
H.check("detached: default x", mx, 300)
H.check("detached: default y", my, -300)
H.check("mover width = frame width", bar.mover:GetWidth(), 220)
H.check("mover height = castbar height", bar.mover:GetHeight(), 16)
C.Set("target", "castbarX", 120)
C.Set("target", "castbarY", -40)
_, _, _, mx, my = bar.mover:GetPoint(1)
H.check("numeric x", mx, 120)
H.check("numeric y", my, -40)

-- Unlocked: a detached castbar's handle shows, a docked one's does not.
local playerBar = ns.Frames.player.castbar
ns.Movers.Unlock()
H.checkTrue("detached castbar handle shown", bar.mover:IsShown())
H.check("player castbar handle hidden (off, docked)", playerBar.mover:IsShown(), false)
H.check("handle label", bar.mover.label:GetText(), "Target castbar")
bar.mover._cx, bar.mover._cy = 960 + 40, 540 - 64
UIParent._cx, UIParent._cy = 960, 540
ns.Movers.OnDragStop(bar.mover)
H.check("drag writes castbar x", C.Get("target", "castbarX"), 40)
H.check("drag writes castbar y", C.Get("target", "castbarY"), -64)
H.check("frame position untouched by the castbar drag", C.Get("target", "x"), 300)
C.Set("target", "castbarPosition", "BELOW")
H.check("docked again: handle hidden while unlocked", bar.mover:IsShown(), false)
H.check("docked again: to the frame", select(2, bar:GetPoint(1)), t)
ns.Movers.Lock()

-- Party castbars dock above or below each member.
M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
M.SetGroup({ "party1" })
local member = ns.Party.header:GetAttribute("child1")
H.check("party: below by default", member.castbar:GetPoint(1), "TOPLEFT")
C.Set("party", "castbarDock", "ABOVE")
H.check("party: above", member.castbar:GetPoint(1), "BOTTOMLEFT")
H.check("party: no mover", member.castbar.mover, nil)

-- A docked party castbar never overlaps the next member: in a vertical
-- block the step between members makes room for castbar, gap and border.
local header = ns.Party.header
M.units.party2 = { name = "Bob", health = 1, healthMax = 1 }
M.SetGroup({ "party1", "party2" })
local second = header:GetAttribute("child2")
local spacing, border = C.Get("party", "partySpacing"), C.Get("party", "borderSize")
local castbarDepth = C.Get("party", "castbarHeight") + ns.Castbar.Gap("party") + border
local _, below, _, _, offset = second:GetPoint(1)
H.check("member 2 follows member 1", below, member)
H.check("member 2 clears member 1's castbar", -offset, castbarDepth + spacing)
H.checkTrue("member 2's top is below member 1's castbar border", -offset >= castbarDepth)
C.Set("party", "castbarDock", "BELOW")
H.check("docked below: same room", header:GetAttribute("yOffset"), -(castbarDepth + spacing))
local _, bh = ns.Party.BlockSize()
H.check("block height counts the castbars", bh, 4 * 46 + 3 * (castbarDepth + spacing))
H.check("slot offset counts the castbars", select(2, ns.Party.SlotOffset(2)), -(46 + castbarDepth + spacing))
C.Set("party", "castbarHeight", 20)
H.check("taller castbar: more room", header:GetAttribute("yOffset"),
    -(20 + ns.Castbar.Gap("party") + border + spacing))
C.Set("party", "castbarEnabled", false)
H.check("castbar off: plain spacing", header:GetAttribute("yOffset"), -spacing)
C.Set("party", "castbarEnabled", true)
C.Set("party", "partyOrientation", "HORIZONTAL")
H.check("horizontal: castbars do not widen the step", header:GetAttribute("xOffset"), spacing)
