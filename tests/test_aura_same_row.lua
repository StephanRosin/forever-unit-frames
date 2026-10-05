-- "Mine in the same rows" (buffsOwnSameRow / debuffsOwnSameRow): yours
-- first, then the rest in the same rows, as Shadowed Unit Frames shows
-- them -- asked for on CurseForge. Off by default (yours keep rows of
-- their own).
local M = H.M
local ns = H.LoadAddon()
local S, C, Layout, AC = ns.Settings, ns.Config, ns.Layout, ns.AuraContainers
C.Use({})

-- Settings ---------------------------------------------------------------------
for g, letter in pairs({ buffs = "J", debuffs = "D" }) do
    local def = S.Get(g .. "OwnSameRow")
    H.checkTrue(g .. "OwnSameRow defined", def)
    H.check(g .. " code", def.code, letter .. "Z")
    H.check(g .. " off by default", C.Get("target", g .. "OwnSameRow"), false)
    H.checkTrue(g .. " labelled", ns.L["SETTING_" .. g .. "OwnSameRow"] ~= "SETTING_" .. g .. "OwnSameRow")
end
H.check("no such setting for the dispels", S.Get("dispelsOwnSameRow"), nil)

-- Container: the rest no longer starts a new line ---------------------------------
local function group(over)
    local g = { enabled = true, filter = "HARMFUL", ownFilter = "HARMFUL|PLAYER", otherFilter = "HARMFUL|!PLAYER",
        size = 20, ownSize = 26, spacing = 2, max = 16, highlightOwn = true }
    for k, v in pairs(over or {}) do g[k] = v end
    return g
end
H.check("own rows: new line", AC.Part(group(), "other").layout.forceNewLine, true)
local other = AC.Part(group({ ownSameRow = true }), "other")
H.check("same rows: no new line", other.layout.forceNewLine, false)
H.check("same rows: the usual gap between yours and the rest", other.layout.groupSpacing, 2)
H.check("same rows: yours still on", AC.Part(group({ ownSameRow = true }), "own").enabled, true)

-- Own layout (test mode, clients without containers) ------------------------------
-- 3 of yours at 26, then 20s, growing right, rows up, 110 wide, Auto.
local shape = { primary = "RIGHT", row = "UP", size = 20, ownSize = 26, spacing = 2, perRowSetting = 0,
    length = 110, ownSameRow = true, perRow = 4, ownPerRow = 3 }
local function at(i) return table.concat({ Layout.AuraPlace(shape, i, 3) }, ",") end
H.check("1st: mine", at(1), "0,0,26")
H.check("3rd: mine", at(3), "56,0,26")
H.check("4th: the rest, same row", at(4), "84,0,20")
-- 106 + 20 = 126 > 110: the 5th wraps, above the row's biggest icon.
H.check("5th: next row, past the tallest", at(5), "0,28,20")
local w, h = Layout.AuraBlock(shape, 3, 5)
H.check("block", w .. "x" .. h, "104x48")
-- A fixed number per row counts icons, whatever their size.
shape.perRowSetting = 2
H.check("2 per row: 3rd wraps", at(3), "0,28,26")
H.check("2 per row: 4th beside it", at(4), "28,28,20")
shape.perRowSetting = 0
-- Off: yours in rows of their own, as before.
shape.ownSameRow = false
H.check("off: the rest on its own row", at(4), "0,28,20")

-- In the frame: the setting reaches the group --------------------------------------
M.units.target = { name = "Ogre", hostile = true, health = 5, healthMax = 10 }
ns.Single.CreateAll()
local t = ns.Frames.target
H.check("target: own rows by default", t.auras.debuffs.ownSameRow, false)
C.Set("target", "debuffsOwnSameRow", true)
H.check("target: same rows when on", t.auras.debuffs.ownSameRow, true)
C.Set("target", "debuffsHighlightOwn", false)
H.check("without 'mine first': nothing to share", t.auras.debuffs.ownSameRow, false)
