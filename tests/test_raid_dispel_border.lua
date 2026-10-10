-- The debuff-coloured border of raid cells (Raid/CellAuras.lua): a slot
-- of the centre icon's filter whose button carries a ring of textures
-- inside the cell, each coloured by the client through the dispel colour
-- curve at full opacity. Nothing reads the dispel type; made and resized
-- out of combat only.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, CellAuras, RS = ns.RaidConfig, ns.RaidHeader, ns.RaidAuras, ns.RaidSettings
local Pixel = ns.Pixel

local on = RS.Get("dispelBorder")
H.checkTrue("switch exists", on)
H.check("switch: per size, behaviour, off", on.scope .. " " .. on.class .. " " .. on.type .. " "
    .. tostring(RS.Default(on, "r10")), "frame behaviour bool false")
local size = RS.Get("dispelBorderSize")
H.checkTrue("size exists", size)
H.check("size: per size, layout, 1-6, 2", size.scope .. " " .. size.class .. " " .. size.type .. " " .. size.min .. "-"
    .. size.max .. " " .. RS.Default(size, "r10"), "frame layout int 1-6 2")

M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "DAMAGER" } })
M.RunTimers()

local cell = Header.headers[1]:GetAttribute("child1")
local c = cell.raidAuras.container
RC.Set("r10", "cellCornerRadius", 0)
H.check("off: no slot made", c._slots.border, nil)

RC.Set("r10", "dispelBorder", true)
local slot = c._slots.border
H.checkTrue("on: a slot", slot)
H.check("the centre icon's filter", slot.filter, c._slots.dispel.filter)
H.check("enabled", slot.enabled, true)
local b = slot.frame
H.check("no clicks", b._clickEnabled, false)
H.check("no mouse over", b._motionEnabled, false)
H.check("above the tint", b:GetFrameLevel(), cell:GetFrameLevel() + CellAuras.BORDER_LEVELS)
H.checkTrue("above the bars and the tint", CellAuras.BORDER_LEVELS > CellAuras.TINT_LEVELS)
H.checkTrue("under the icons", CellAuras.BORDER_LEVELS < CellAuras.LEVELS)

local pieces = ns.Border.InnerRingPieces(b.ring)
H.check("eight pieces: four edges, four corners", #pieces, 8)
H.check("each registered", #b._dispelTextures, 8)
local curve = ns.AuraButton.DispelCurve()
for i, entry in ipairs(b._dispelTextures) do
    H.check("piece " .. i .. ": a ring piece", entry.texture, pieces[i])
    H.check("piece " .. i .. ": keeps its art", entry.options.style,
        Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset)
    H.check("piece " .. i .. ": full colours", entry.options.customDispelColorCurve, curve)
    H.check("piece " .. i .. ": hidden until a debuff", entry.texture:IsShown(), false)
    H.check("piece " .. i .. ": on the button", entry.texture:GetParent(), b)
end
H.check("magic at full opacity", curve.points[2][2].a, 1)

-- Inside the cell, pixel-snapped: corner squares at the cell's corners,
-- edges between them.
local function checkPlaced(label, px)
    local top, bottom, left, right = pieces[1], pieces[2], pieces[3], pieces[4]
    H.check(label .. ": top thickness", top:GetHeight(), px)
    H.check(label .. ": bottom thickness", bottom:GetHeight(), px)
    H.check(label .. ": left thickness", left:GetWidth(), px)
    H.check(label .. ": right thickness", right:GetWidth(), px)
    local p, rel, rp, x, y = top:GetPoint(1)
    H.check(label .. ": top along the cell's top", table.concat({ p, rp, x, y }, " "), "TOPLEFT TOPLEFT " .. px .. " 0")
    H.check(label .. ": top inside the cell", rel, cell)
    p, rel, rp, x, y = left:GetPoint(1)
    H.check(label .. ": left between the corners", table.concat({ p, rp, x, y }, " "), "TOPLEFT TOPLEFT 0 " .. -px)
    for i = 5, 8 do
        local corner = pieces[i]
        p, rel, rp, x, y = corner:GetPoint(1)
        H.check(label .. ": corner " .. i .. " in the cell's corner", p == rp and rel == cell and x == 0 and y == 0, true)
        H.check(label .. ": corner " .. i .. " size", corner:GetWidth() .. "x" .. corner:GetHeight(), px .. "x" .. px)
        H.check(label .. ": corner " .. i .. " square", corner:GetNumMaskTextures(), 0)
    end
end
checkPlaced("default", Pixel.Snap(2, nil, 1))
RC.Set("r10", "dispelBorderSize", 5)
checkPlaced("size 5", Pixel.Snap(5, nil, 1))

-- With the tint: both.
RC.Set("r10", "dispelTint", true)
H.check("tint and border together", tostring(c._slots.tint.enabled) .. " " .. tostring(slot.enabled), "true true")
-- The filter follows.
RC.Set("r10", "dispelFilter", "ALL")
H.check("filter follows", slot.filter, "HARMFUL|DISPELLABLE")
-- Without the icon too.
RC.Set("r10", "dispelIcon", false)
H.check("without the icon", slot.enabled, true)

-- In combat: resizing waits.
M.combat = true
RC.Set("r10", "dispelBorderSize", 3)
H.check("combat: kept", rawget(pieces[1], "_h"), Pixel.Snap(5, nil, 1))
M.SetCombat(false)
H.check("after combat: resized", pieces[1]:GetHeight(), Pixel.Snap(3, nil, 1))

RC.Set("r10", "dispelBorder", false)
H.check("off: disabled", slot.enabled, false)
RC.ResetScope("r10")
H.check("nothing blocked", #M.blocked, 0)
H.check("no errors", #M.errors, 0)
