-- The debuff border in the raid window and in test mode: its size greys
-- while it is off, the filter counts it; pretend members with a
-- dispellable debuff show it in their type's colour at full opacity.
local M = H.M
local ns = H.LoadAddon()
local RC, Cell, Test, CellAuras = ns.RaidConfig, ns.RaidCell, ns.RaidTestMode, ns.RaidAuras
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100, healthMissing = 0, power = 50, powerMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

-- Greying, at the edited size.
local ACTIVE = ns.RaidOptions.ROW_ACTIVE
local edited = ns.Raid.Scope(ns.RaidOptions.Size())
H.check("size greyed while off", ACTIVE.dispelBorderSize(), false)
RC.Set(edited, "dispelBorder", true)
H.checkTrue("size active while on", ACTIVE.dispelBorderSize())
RC.Set(edited, "dispelIcon", false)
H.checkTrue("filter: the border alone uses it", ACTIVE.dispelFilter())
RC.Set(edited, "dispelBorder", false)
H.check("filter: nothing uses it", ACTIVE.dispelFilter(), false)
RC.Set(edited, "dispelTint", true)
H.checkTrue("filter: the tint alone uses it", ACTIVE.dispelFilter())
H.checkTrue("the border row itself never greys", ACTIVE.dispelBorder == nil or ACTIVE.dispelBorder())
RC.ResetScope(edited)

-- Test mode.
Test.Set(true)
local f1, f2, f9 = Cell.fakes[1], Cell.fakes[2], Cell.fakes[9]
local s2 = f2.raidAuras.samples
H.checkTrue("a sample border", s2.border)
H.check("off by default", s2.border:IsShown(), false)
RC.Set("r10", "dispelBorder", true)
H.checkTrue("member 2 (magic): shown", s2.border:IsShown())
H.check("member 1 (no debuff): hidden", f1.raidAuras.samples.border:IsShown(), false)
H.check("above the tint", s2.border:GetFrameLevel(), f2:GetFrameLevel() + CellAuras.BORDER_LEVELS)
local pieces = ns.Border.InnerRingPieces(s2.border.ring)
H.check("eight pieces", #pieces, 8)
local magic = ns.AuraButton.DISPEL_COLORS.Magic
for i, piece in ipairs(pieces) do
    H.check("piece " .. i .. ": magic, opaque", table.concat(piece._color, ","),
        table.concat({ magic[1], magic[2], magic[3], 1 }, ","))
end
local disease = ns.AuraButton.DISPEL_COLORS.Disease
H.check("member 9: disease", f9.raidAuras.samples.border.ring[1]._color[1], disease[1])
RC.Set("r10", "dispelBorderSize", 4)
H.check("size follows", pieces[1]:GetHeight(), ns.Pixel.Snap(4, nil, 1))
RC.Set("r10", "cellCornerRadius", 8)
H.check("rounded like the live border", pieces[5]:GetNumMaskTextures(), 1)
RC.Set("r10", "dispelTint", true)
H.check("tint and border", tostring(s2.tint:IsShown()) .. " " .. tostring(s2.border:IsShown()), "true true")
RC.Set("r10", "dispelBorder", false)
H.check("off again", s2.border:IsShown(), false)
RC.ResetScope("r10")
Test.Set(false)
H.check("test mode off: hidden", s2.border:IsShown(), false)
H.check("no errors", #M.errors, 0)
