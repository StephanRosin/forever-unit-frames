local _, ns = ...

-- The missing-buff icon on the raid cells (optional, off by default): a
-- cell whose member misses a watched buff (Raid/BuffWatch.lua:
-- state.missingUnits, the first such buff in the watch's order) shows
-- that buff's icon at the chosen point, just inside the cell, at the
-- profile's icon size. A buff whose state is unknown marks nobody. It
-- changes out of combat only (the scans run out of combat anyway); in
-- combat a cell keeps what it showed. Test mode's pretend cells show none.
local Cells = {}
ns.RaidBuffCells = Cells

local Cell, Pixel = ns.RaidCell, ns.Pixel

-- Above the bars and texts, beside the cell's other icons (+18).
Cells.LEVELS = 19

local function general(key) return ns.RaidConfig.Get("general", key) end

local function holderOf(cell)
    if cell.buffIcon then return cell.buffIcon end
    local holder = CreateFrame("Frame", nil, cell)
    holder:SetAllPoints(cell)
    holder.icon = holder:CreateTexture(nil, "OVERLAY")
    holder.icon:Hide()
    cell.buffIcon = holder
    return holder
end

local function show(cell, entry)
    local holder = holderOf(cell)
    holder:SetFrameLevel(cell:GetFrameLevel() + Cells.LEVELS)
    local point = general("buffCellIconPoint")
    local x, y = Cell.Inset(point)
    local size = Pixel.Snap(Cell.Get("iconSize"), nil, 1)
    local icon = holder.icon
    icon:ClearAllPoints()
    icon:SetPoint(point, cell, point, Pixel.Snap(x), Pixel.Snap(y))
    icon:SetSize(size, size)
    icon:SetTexture(entry.single.icon)
    icon:Show()
end

-- Out of combat: every cell's icon anew.
function Cells.Refresh()
    if InCombatLockdown() or not ns.RaidConfig.Profile() then return end
    local on = general("buffCellIcon") == true
    local missing = ns.RaidBuffWatch.state.missingUnits
    for _, cell in ipairs(Cell.buttons) do
        local entry = on and cell.unit and missing[cell.unit]
        if entry then
            show(cell, entry)
        elseif cell.buffIcon then
            cell.buffIcon.icon:Hide()
        end
    end
end

local KEYS = { buffCellIcon = true, buffCellIconPoint = true, iconSize = true }
ns.Listen("RAID_BUFFS_CHANGED", Cells.Refresh)
ns.Listen("RAID_CELLS_CHANGED", Cells.Refresh)
ns.Listen("RAID_SIZE_CHANGED", Cells.Refresh)
ns.Listen("RAID_CONFIG_CHANGED", function(_, key)
    if key == nil or KEYS[key] then Cells.Refresh() end
end)
