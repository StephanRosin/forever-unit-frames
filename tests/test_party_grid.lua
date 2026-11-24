-- The party in several lines (partyPerLine) with what hangs beside or
-- under its members: the pet list wraps like the rows and stays within
-- the block; party targets and pets beside their member get room between
-- two columns (targets above or below: between two rows).
local M = H.M
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, P, Pets, Targets = ns.Config, ns.Party, ns.PartyPets, ns.PartyTargets
local pets = Pets.header
C.Set("party", "castbarEnabled", false)
C.Set("party", "partySpacing", 4)
local w, h = ns.Single.Size("party")

-- One line: the gap is the spacing, nothing else counts.
C.Set("party", "partyTargets", true)
H.check("one line: no line gap in the block", select(2, P.BlockSize()), 4 * h + 3 * 4)
C.Set("party", "partyTargets", false)

-- Rows of two: the pet row wraps after two, every pet inside the block.
C.Set("party", "partyOrientation", "HORIZONTAL")
C.Set("party", "partyPerLine", 2)
C.Set("party", "partyShowPets", true)
H.check("pet row: two per row", pets:GetAttribute("unitsPerColumn"), 2)
H.check("pet row: two rows", pets:GetAttribute("maxColumns"), 2)
H.check("pet row: next row below", pets:GetAttribute("columnAnchorPoint"), "TOP")
local blockW = P.BlockSize()
for i = 1, P.Slots() do
    local x = Pets.SlotOffset(i)
    H.checkTrue("pet " .. i .. " inside the block", x >= 0 and x + ns.Single.Size("partypet") <= blockW)
end
local x3, y3 = Pets.SlotOffset(3)
H.check("pet 3 starts row 2", x3, 0)
local _, ph = ns.Single.Size("partypet")
H.check("pet 3 one row down", y3, -(ph + P.PetStep()))
C.Set("party", "partyGrowReverse", true)
x3 = Pets.SlotOffset(3)
H.check("from the right: pet 3 at the right edge", x3, blockW - ns.Single.Size("partypet"))
C.Set("party", "partyGrowReverse", false)

-- Targets below each member: room between two rows, not between members
-- of a row.
C.Set("party", "partyTargets", true)
C.Set("party", "partyTargetSide", "BELOW")
local side, room = Targets.Room()
H.check("below: side", side, "BELOW")
H.checkTrue("below: room for the target", room > 0)
H.check("rows: room below", P.LineGap(), 4 + room)
C.Set("party", "partyTargetSide", "RIGHT")
H.check("rows: a target beside takes none", P.LineGap(), 4)

-- Columns of two: targets and pets beside their member keep column 2 clear.
C.Set("party", "partyOrientation", "VERTICAL")
side, room = Targets.Room()
H.check("right: side", side, "RIGHT")
H.check("right: gap, target, borders", room,
    select(3, Targets.Anchor()) + ns.Single.Size("partytarget") + ns.Border.Extent("partytarget") + ns.Border.Extent("party"))
H.check("columns: room for the target", P.LineGap(), 4 + room)
C.Set("party", "partyPetLayout", "BESIDE")
H.check("columns: and for the pet", P.LineGap(), 4 + room + Pets.BesideRoom())
H.check("columns: the header's column gap", ns.Party.header:GetAttribute("columnSpacing"), P.LineGap())
H.check("columns: the block", P.BlockSize(), 2 * w + P.LineGap())
local sx = P.SlotOffset(3)
H.check("columns: slot 3 past the room", sx, w + P.LineGap())
C.Set("party", "partyTargets", false)
C.Set("party", "partyPetLayout", "LIST")
H.check("columns: nothing beside, the spacing", P.LineGap(), 4)
H.check("column pets: one column", pets:GetAttribute("maxColumns"), 1)
