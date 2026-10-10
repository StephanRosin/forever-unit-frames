-- The dispellable debuff as a small square in a corner of a raid cell
-- (Raid/CellAuras.lua): a slot of its own with the centre icon's filter,
-- whose only region is a texture the client colours by dispel type
-- through our colour curve; its corner and size (from one pixel) per raid
-- size. A corner indicator in the same corner pushes it inwards. The tint
-- stays a switch of its own. Test mode draws it from the pretend members.
local M = H.M
local ns = H.LoadAddon()
local RC, RS, Header, CellAuras, Cell = ns.RaidConfig, ns.RaidSettings, ns.RaidHeader, ns.RaidAuras, ns.RaidCell
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

-- The settings.
H.check("style", RS.Default(RS.Get("dispelStyle"), "r10"), "ICON")
H.check("styles", table.concat(RS.Get("dispelStyle").values, ","), "ICON,SQUARE")
H.check("corner", RS.Default(RS.Get("dispelSquarePoint"), "r10"), "TOPRIGHT")
H.check("corners", table.concat(RS.Get("dispelSquarePoint").values, ","), "TOPLEFT,TOPRIGHT,BOTTOMLEFT,BOTTOMRIGHT")
H.check("size", RS.Default(RS.Get("dispelSquareSize"), "r10"), 6)
H.check("from one pixel", RS.Get("dispelSquareSize").min, 1)
H.check("codes", RS.Get("dispelStyle").code .. " " .. RS.Get("dispelSquarePoint").code .. " "
    .. RS.Get("dispelSquareSize").code, "DM DP DQ")

local function member(name, class, subgroup)
    return { name = name, class = class, subgroup = subgroup, assignedRole = "DAMAGER" }
end
M.SetRaidRoster({ member("Ann", "PRIEST", 1), member("Bob", "MAGE", 1) })
M.RunTimers()
local cell = Header.headers[1]:GetAttribute("child1")
local c = cell.raidAuras.container

-- Off by default: no slot for it.
H.check("no square slot", c._slots.square, nil)

-- The square instead of the icon.
RC.Set("r10", "dispelStyle", "SQUARE")
local slot = c._slots.square
H.checkTrue("square slot made", slot)
H.check("same filter as the icon", slot.filter, "HARMFUL|RAID")
H.check("square on", slot.enabled, true)
H.check("icon off", c._slots.dispel.enabled, false)
local square = slot.frame
local function place(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    return table.concat({ p, rel == cell and "cell" or "?", relPoint, x, y }, " ")
end
H.check("square size", square:GetWidth() .. "x" .. square:GetHeight(), "6x6")
H.check("in its corner, a pixel in", place(square), "TOPRIGHT cell TOPRIGHT -1 -1")
local entry = square._dispelTextures[1]
H.check("its texture coloured by the client", entry.texture, square.square)
H.check("the borders' curve: opaque", entry.options.customDispelColorCurve, ns.AuraButton.DispelCurve())
H.check("texture fills the square", square.square._allPoints, square)
H.check("no mouse", square._clickEnabled, false)
H.check("above the texts", square:GetFrameLevel() >= cell:GetFrameLevel() + CellAuras.LEVELS, true)

-- Corner and size; a two-pixel square.
RC.Set("r10", "dispelSquareSize", 2)
RC.Set("r10", "dispelSquarePoint", "BOTTOMLEFT")
H.check("2 x 2", square:GetWidth() .. "x" .. square:GetHeight(), "2x2")
H.check("bottom left", place(square), "BOTTOMLEFT cell BOTTOMLEFT 1 1")
RC.Set("r10", "dispelFilter", "ALL")
H.check("filter follows", slot.filter, "HARMFUL|DISPELLABLE")

-- A corner indicator in the same corner: the square moves in beside it.
RC.Set("r10", "indicatorBottomLeftSpells", "774")
H.check("beside the indicator", place(square), "BOTTOMLEFT cell BOTTOMLEFT 10 1")
RC.Set("r10", "indicatorBottomLeftSize", 12)
H.check("beside a bigger one", place(square), "BOTTOMLEFT cell BOTTOMLEFT 14 1")
RC.Set("r10", "dispelSquarePoint", "TOPRIGHT")
H.check("another corner: back in the corner", place(square), "TOPRIGHT cell TOPRIGHT -1 -1")
RC.Set("r10", "indicatorTopRightSpells", "139")
H.check("moves in from the right", place(square), "TOPRIGHT cell TOPRIGHT -10 -1")
RC.Set("r10", "indicatorTopRightSpells", "")
H.check("indicator gone: back", place(square), "TOPRIGHT cell TOPRIGHT -1 -1")

-- The tint stays its own switch; off hides both.
RC.Set("r10", "dispelTint", true)
H.check("tint with the square", c._slots.tint.enabled, true)
H.check("square still on", slot.enabled, true)
RC.Set("r10", "dispelIcon", false)
H.check("debuff off: no square", slot.enabled, false)
H.check("debuff off: no icon", c._slots.dispel.enabled, false)
RC.Set("r10", "dispelIcon", true)
RC.Set("r10", "dispelStyle", "ICON")
H.check("icon again", c._slots.dispel.enabled, true)
H.check("square off", slot.enabled, false)

-- In combat nothing is touched; the change lands after combat.
M.SetCombat(true)
RC.Set("r10", "dispelStyle", "SQUARE")
H.check("combat: unchanged", slot.enabled, false)
M.SetCombat(false)
H.check("after combat", slot.enabled, true)
RC.ResetScope("r10")

-- Test mode: the pretend member's first debuff with a type, in its colour.
RC.Set("r10", "dispelStyle", "SQUARE")
ns.RaidTestMode.Set(true)
local s2 = Cell.fakes[2].raidAuras.samples
H.checkTrue("sample square shown", s2.square:IsShown())
H.check("sample: magic's colour", s2.square.texture._color[3], 1.0)
H.check("sample: no icon", s2.icon:IsShown(), false)
H.check("sample size", s2.square:GetWidth(), 6)
H.check("member 1: none", Cell.fakes[1].raidAuras.samples.square:IsShown(), false)
RC.Set("r10", "dispelStyle", "ICON")
H.check("sample: icon again", s2.icon:IsShown(), true)
H.check("sample: square hidden", s2.square:IsShown(), false)
ns.RaidTestMode.Set(false)

-- In the window: the Debuffs tab, sizes as sliders.
local tab
for _, t in ipairs(ns.RaidSchema.TABS) do
    if t.id == "debuffs" then tab = t end
end
H.check("dispel section", table.concat(tab.sections[1].keys, ","),
    "dispelIcon,dispelFilter,dispelStyle,dispelIconSize,dispelSquarePoint,dispelSquareSize,dispelTint,dispelBorder,"
    .. "dispelBorderSize")
H.check("row section", table.concat(tab.sections[2].keys, ","), "debuffRow,debuffCount,debuffSize")
ns.RaidOptions.Open(10, "debuffs")
local sliders = {}
for _, row in ipairs(ns.RaidOptions.rows) do
    if row.slider then sliders[#sliders + 1] = row.key end
end
H.check("sliders", table.concat(sliders, ","), "dispelIconSize,dispelSquareSize,dispelBorderSize,debuffCount,debuffSize")
ns.RaidOptions.Close()
H.check("square word", ns.RaidSchema.EnumText(RS.Get("dispelStyle"), "SQUARE"), "Square in a corner")
H.check("nothing blocked", #M.blocked, 0)
