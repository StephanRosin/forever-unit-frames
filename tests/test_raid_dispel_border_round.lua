-- The debuff border on rounded cells (cellCornerRadius > 0): the ring
-- follows the cell's rounding. Corner pieces show the outer arc
-- (Corners.TEXTURE) as large as the cell's radius, cut by one inner-arc
-- mask, so ring and cell stay concentric; never more than one mask on any
-- texture (the client allows three and raises beyond).
local M = H.M
local ns = H.LoadAddon()
local RC, Header = ns.RaidConfig, ns.RaidHeader
local Pixel, Corners = ns.Pixel, ns.Corners

M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "DAMAGER" } })
M.RunTimers()
local cell = Header.headers[1]:GetAttribute("child1")
local c = cell.raidAuras.container

RC.Set("r10", "cellCornerRadius", 6)
RC.Set("r10", "dispelBorderSize", 2)
RC.Set("r10", "dispelBorder", true)
local b = c._slots.border.frame
local pieces = ns.Border.InnerRingPieces(b.ring)
local R, px = ns.Shape.Radius(cell), Pixel.Snap(2, nil, 1)
H.check("the cell is rounded", R, 6)
for i = 5, 8 do
    local corner = pieces[i]
    H.check("corner " .. i .. ": as large as the cell's radius", corner:GetWidth() .. "x" .. corner:GetHeight(),
        R .. "x" .. R)
    H.check("corner " .. i .. ": the outer arc", corner._texture, Corners.TEXTURE)
    H.check("corner " .. i .. ": one mask", corner:GetNumMaskTextures(), 1)
    local mask = b.ring.inner[i - 4]
    H.check("corner " .. i .. ": the inner arc", mask._texture, Corners.INVERSE[i - 4])
    H.check("corner " .. i .. ": inner arc size", mask:GetWidth(), R - px)
    local p, rel, rp, x, y = mask:GetPoint(1)
    local out = { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }
    H.check("corner " .. i .. ": inner arc a border in", table.concat({ p, rp, x, y }, " "),
        table.concat({ Corners.POINTS[i - 4], Corners.POINTS[i - 4], -out[i - 4][1] * px, -out[i - 4][2] * px }, " "))
    H.check("corner " .. i .. ": on its piece", rel, corner)
end
local p, _, _, x = pieces[1]:GetPoint(1)
H.check("top edge between the arcs", p .. " " .. x, "TOPLEFT " .. R)
H.check("edges unmasked", pieces[1]:GetNumMaskTextures(), 0)

-- A border thicker than the radius: the arc as large as the border, no
-- inner cut (the corner is all border).
RC.Set("r10", "cellCornerRadius", 1)
RC.Set("r10", "dispelBorderSize", 4)
local px4 = Pixel.Snap(4, nil, 1)
H.check("thick: corner as large as the border", pieces[5]:GetWidth(), px4)
H.check("thick: still the arc", pieces[5]._texture, Corners.TEXTURE)
H.check("thick: no inner cut", pieces[5]:GetNumMaskTextures(), 0)
H.check("thick: inner mask hidden", b.ring.inner[1]:IsShown(), false)

-- Back to square cells: plain squares, masks off.
RC.Set("r10", "cellCornerRadius", 0)
H.check("square: corner the border's size", pieces[5]:GetWidth(), px4)
H.check("square: no arc", pieces[5]:GetNumMaskTextures(), 0)
H.check("square: inner mask hidden", b.ring.inner[1]:IsShown(), false)

-- Every radius and size: at most one mask per texture, no error.
local function mostMasks()
    local most = 0
    for _, w in ipairs(M.widgets) do
        local n = w._masks and #w._masks or 0
        if n > most then most = n end
    end
    return most
end
local ok, err = pcall(function()
    for size = 1, 6 do
        RC.Set("r10", "dispelBorderSize", size)
        for radius = 0, 12 do
            RC.Set("r10", "cellCornerRadius", radius)
            H.check("size " .. size .. ", radius " .. radius .. ": at most one mask", mostMasks() <= 1, true)
        end
    end
end)
H.check("sweep without errors", ok and "ok" or tostring(err), "ok")
RC.ResetScope("r10")
H.check("no errors", #M.errors, 0)
