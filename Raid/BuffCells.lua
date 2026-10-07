local _, ns = ...

-- The missing-buff icon on the raid cells (optional, off by default): a
-- cell whose member misses a watched buff (Raid/BuffWatch.lua: the state's
-- missingGUIDs, else missingUnits; the first such buff in the watch's
-- order) shows that buff's icon at the chosen point, just inside the
-- cell, at the profile's icon size. A buff whose state is unknown marks
-- nobody. Every cell's icon is made and placed out of combat (the cells
-- are secure frames); in combat, when cells change hands, an icon only
-- shows or hides by its new member in the last state (by GUID; one whose
-- GUID the client does not give plainly, after the roster changed, hides:
-- what it showed may be another member's). Test mode's pretend cells show
-- none.
local Cells = {}
ns.RaidBuffCells = Cells

local Cell, Pixel, Watch = ns.RaidCell, ns.Pixel, ns.RaidBuffWatch

-- Above the bars and texts, beside the cell's other icons (+18).
Cells.LEVELS = 19

local function general(key) return ns.RaidConfig.Get("general", key) end

-- Out of combat: the cell's icon, made once, placed anew.
local function place(cell)
    local holder = cell.buffIcon
    if not holder then
        holder = CreateFrame("Frame", nil, cell)
        holder:SetAllPoints(cell)
        holder.icon = holder:CreateTexture(nil, "OVERLAY")
        holder.icon:Hide()
        cell.buffIcon = holder
    end
    holder:SetFrameLevel(cell:GetFrameLevel() + Cells.LEVELS)
    local point = general("buffCellIconPoint")
    local x, y = Cell.Inset(point)
    local size = Pixel.Snap(Cell.Get("iconSize"), nil, 1)
    local icon = holder.icon
    icon:ClearAllPoints()
    icon:SetPoint(point, cell, point, Pixel.Snap(x), Pixel.Snap(y))
    icon:SetSize(size, size)
    return holder
end

-- The watched buff the cell's member misses, by GUID; else by unit while
-- the state is current (after a roster change the units may name other
-- members). nil: none, or not known.
local function missingOf(cell)
    if not cell.unit then return nil end
    local state = Watch.state
    local guid = Watch.GUID(cell.unit)
    if guid then return state.missingGUIDs[guid] end
    if Watch.armed then return state.missingUnits[cell.unit] end
    return nil
end

-- The icon of a placed cell shown or hidden (allowed in combat). Not
-- known: hidden (what it showed may be another member's).
local function paint(cell, on)
    local holder = cell.buffIcon
    if not holder then return end
    local entry = on and missingOf(cell)
    if entry then
        holder.icon:SetTexture(entry.single.icon)
        holder.icon:Show()
    else
        holder.icon:Hide()
    end
end

-- Every cell's icon anew: placed out of combat, in combat only shown or
-- hidden.
function Cells.Refresh()
    if not ns.RaidConfig.Profile() then return end
    local on = general("buffCellIcon") == true
    local combat = InCombatLockdown()
    for _, cell in ipairs(Cell.buttons) do
        if on and not combat then place(cell) end
        paint(cell, on)
    end
end

local KEYS = { buffCellIcon = true, buffCellIconPoint = true, iconSize = true }
ns.Listen("RAID_BUFFS_CHANGED", Cells.Refresh)
ns.Listen("RAID_CELLS_CHANGED", Cells.Refresh)
ns.Listen("RAID_SIZE_CHANGED", Cells.Refresh)
-- A cell can keep its unit while another member takes it.
ns.On("GROUP_ROSTER_UPDATE", Cells.Refresh)
ns.Listen("RAID_CONFIG_CHANGED", function(_, key)
    if key == nil or KEYS[key] then Cells.Refresh() end
end)
