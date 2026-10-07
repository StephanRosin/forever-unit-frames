local _, ns = ...

-- The raid panel's layout as plain numbers: which blocks a grouping makes
-- for a raid size, the filters and attributes of their group headers
-- (Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua, plain
-- attributes only, no snippets), and where blocks and cells go. No frames
-- here: Raid/Header.lua applies it, test mode places its pretend cells
-- with the same numbers.
local Layout = {}
ns.RaidLayout = Layout

Layout.ROLES = { "TANK", "HEALER", "DAMAGER" }
-- Sorted by role within a block: the assigned roles in this order, those
-- without one last.
Layout.ROLE_ORDER = "TANK,HEALER,DAMAGER,NONE"
-- Every filter attribute a block may set; the others are cleared. A
-- nameList counts only without a group or role filter (the special
-- panels' lists).
Layout.FILTER_KEYS = { "groupFilter", "roleFilter", "strictFiltering", "groupBy", "groupingOrder", "nameList" }
-- A group never holds more than five.
Layout.GROUP_SIZE = 5

-- The raid groups a size shows: 10 -> 1-2, 20 -> 1-4, 40 -> 1-8.
function Layout.Groups(size)
    local list = {}
    for g = 1, size / Layout.GROUP_SIZE do list[g] = g end
    return list
end

local function joined(list) return table.concat(list, ",") end

-- Blizzard's class order for this game type (Raid/Settings.lua).
local function classes() return ns.Raid.Classes() end

-- The class blocks' order: the classes a class order (the setting, as
-- stored) names, then the others in Blizzard's order.
function Layout.Classes(order)
    local list, named = {}, {}
    for token in (order or ""):gmatch("[^,%s]+") do
        list[#list + 1] = token
        named[token] = true
    end
    for _, token in ipairs(classes()) do
        if not named[token] then list[#list + 1] = token end
    end
    return list
end

-- Sorted by role: the header groups its members by assigned role. A tank
-- or healer block holds one role already; the damage block holds damage
-- and the members without a role, damage first. In the single block this
-- replaces the order by group.
local function sortByRole(blocks)
    for _, block in ipairs(blocks) do
        if block.kind ~= "ROLE" or block.id == "DAMAGER" then
            block.filter.groupBy, block.filter.groupingOrder = "ASSIGNEDROLE", Layout.ROLE_ORDER
        end
    end
end

-- The blocks of a grouping: { kind, id, capacity (groups only), filter }.
-- Each block keeps to the size's groups. A class or role block filters
-- strictly: group and class (and role) must all match. Members without
-- an assigned role count as damage. sortBy (the setting, optional):
-- ROLE sorts by role within each block; classOrder (the setting,
-- optional): the class blocks' order.
function Layout.Blocks(groupBy, size, sortBy, classOrder)
    local groups = joined(Layout.Groups(size))
    local blocks = {}
    if groupBy == "GROUP" then
        for g = 1, size / Layout.GROUP_SIZE do
            blocks[g] = { kind = "GROUP", id = g, capacity = Layout.GROUP_SIZE, filter = { groupFilter = tostring(g) } }
        end
    elseif groupBy == "CLASS" then
        for i, token in ipairs(Layout.Classes(classOrder)) do
            blocks[i] = { kind = "CLASS", id = token,
                filter = { groupFilter = groups .. "," .. token, strictFiltering = true } }
        end
    elseif groupBy == "ROLE" then
        local everyClass = groups .. "," .. joined(classes())
        -- The damage block takes the members without a role as well, so
        -- nobody is left out of the role blocks.
        for i, role in ipairs(Layout.ROLES) do
            blocks[i] = { kind = "ROLE", id = role, filter = { groupFilter = everyClass,
                roleFilter = role == "DAMAGER" and "DAMAGER,NONE" or role, strictFiltering = true } }
        end
    else
        blocks[1] = { kind = "NONE", id = "ALL",
            filter = { groupFilter = groups, groupBy = "GROUP", groupingOrder = groups } }
    end
    if sortBy == "ROLE" then sortByRole(blocks) end
    return blocks
end

-- A block's token as an own panel stores it (Raid.ParseBlockList): the
-- group number, class token or role.
function Layout.Token(block)
    return tostring(block.id)
end

-- The blocks an own panel takes: those of blocks the tokens name, in the
-- order of blocks (the main panel's: group number, class order, role
-- order), not the tokens'; a token naming none of them is passed over.
function Layout.Chosen(blocks, tokens)
    local named, list = {}, {}
    for _, token in ipairs(tokens) do named[token] = true end
    for _, block in ipairs(blocks) do
        if named[Layout.Token(block)] then list[#list + 1] = block end
    end
    return list
end

-- The blocks left when those whose token is in taken (a set) are gone.
function Layout.Without(blocks, taken)
    local list = {}
    for _, block in ipairs(blocks) do
        if not taken[Layout.Token(block)] then list[#list + 1] = block end
    end
    return list
end

-- Whether a member { subgroup, class, assignedRole } belongs to a block,
-- as its filter decides (test mode's pretend members).
function Layout.Matches(block, member, size)
    -- A special panel's pretend members are chosen for it already.
    if block.kind == "PANEL" then return true end
    local inGroups = member.subgroup >= 1 and member.subgroup <= size / Layout.GROUP_SIZE
    if block.kind == "GROUP" then return member.subgroup == block.id end
    if not inGroups then return false end
    if block.kind == "CLASS" then return member.class == block.id end
    if block.kind == "ROLE" then
        local role = member.assignedRole or "NONE"
        if block.id == "DAMAGER" then return role == "DAMAGER" or role == "NONE" end
        return role == block.id
    end
    return true
end

-- A block's title in Blizzard's own words (GROUP_NUMBER, the localised
-- class names, the role names, RAID); the token where the client has none.
-- A special panel's block (kind PANEL) is titled with the panel's word.
local function global(name)
    local v = _G[name]
    if type(v) == "string" then return v end
    return nil
end

function Layout.Title(block)
    if block.kind == "GROUP" then
        local format = global("GROUP_NUMBER")
        return format and format:format(block.id) or tostring(block.id)
    elseif block.kind == "CLASS" then
        local names = LOCALIZED_CLASS_NAMES_MALE
        return type(names) == "table" and names[block.id] or block.id
    elseif block.kind == "ROLE" then
        return global(block.id) or block.id
    elseif block.kind == "PANEL" then
        return ns.L["RAID_SECTION_" .. block.id]
    end
    return global("RAID") or ""
end

-- Geometry. s holds, on the pixel grid: cellWidth, cellHeight, cellGap
-- (spacing plus both cells' borders), cellsPerLine, cellGrowth (DOWN or
-- RIGHT), inset (how far the cells sit inside their block: a cell
-- border's reach), titleHeight (0 without titles); for arranging blocks:
-- blockGap, blocksPerLine, blockDirection.

-- The cell layout of a group header: a column growing down with new
-- columns to the right, or a row growing right with new rows below; as
-- many columns (rows) as the size can fill.
function Layout.HeaderAttributes(s, size)
    local down = s.cellGrowth == "DOWN"
    return {
        point = down and "TOP" or "LEFT",
        xOffset = down and 0 or s.cellGap,
        yOffset = down and -s.cellGap or 0,
        unitsPerColumn = s.cellsPerLine,
        maxColumns = math.ceil(size / s.cellsPerLine),
        columnSpacing = s.cellGap,
        columnAnchorPoint = down and "LEFT" or "TOP",
    }
end

-- Cell i (1-based) from its header's top-left corner, as the header
-- places it.
function Layout.CellOffset(s, i)
    local line, pos = math.floor((i - 1) / s.cellsPerLine), (i - 1) % s.cellsPerLine
    local stepX, stepY = s.cellWidth + s.cellGap, s.cellHeight + s.cellGap
    if s.cellGrowth == "DOWN" then return line * stepX, -pos * stepY end
    return pos * stepX, -line * stepY
end

-- Width and height of a block with room for n cells: the cells, their
-- borders' reach on every side, and the title row.
function Layout.BlockSize(s, n)
    local lines, across = math.ceil(n / s.cellsPerLine), math.min(n, s.cellsPerLine)
    local cols, rows = lines, across
    if s.cellGrowth ~= "DOWN" then cols, rows = across, lines end
    local w = cols * s.cellWidth + (cols - 1) * s.cellGap + 2 * s.inset
    local h = rows * s.cellHeight + (rows - 1) * s.cellGap + 2 * s.inset + s.titleHeight
    return w, h
end

-- The header's top-left corner inside its block: below the title, inside
-- the cell borders.
function Layout.HeaderOffset(s)
    return s.inset, -(s.titleHeight + s.inset)
end

-- How many cells a block makes room for, or nil: no room at all. A group
-- keeps room for a full group, so members joining in combat (when blocks
-- cannot move) never overlap the next block; other blocks hold who is
-- there. An empty block takes no room when empty blocks are hidden, else
-- one cell.
function Layout.Room(block, count, hideEmpty)
    if count == 0 and hideEmpty then return nil end
    if block.capacity then return block.capacity end
    return math.max(count, 1)
end

-- Places blocks of the given sizes ({ w, h }, or false for a block
-- without room): in a row (HORIZONTAL) or a column (VERTICAL), a new one
-- after blocksPerLine blocks, past the tallest (widest) block of the line
-- before. Returns each block's top-left corner from the panel's ({ x, y },
-- nil for blocks without room) and the panel's width and height.
function Layout.Arrange(s, sizes)
    local positions = {}
    local horizontal = s.blockDirection == "HORIZONTAL"
    local along, lineStart, lineDepth, inLine = 0, 0, 0, 0
    local width, height = 0, 0
    for i, size in ipairs(sizes) do
        if size then
            if inLine == s.blocksPerLine then
                lineStart = lineStart + lineDepth + s.blockGap
                along, lineDepth, inLine = 0, 0, 0
            end
            local w, h = size[1], size[2]
            local x, y
            if horizontal then
                x, y = along, 0 - lineStart
                along = along + w + s.blockGap
                lineDepth = math.max(lineDepth, h)
            else
                x, y = lineStart, 0 - along
                along = along + h + s.blockGap
                lineDepth = math.max(lineDepth, w)
            end
            inLine = inLine + 1
            positions[i] = { x = x, y = y }
            width = math.max(width, x + w)
            height = math.max(height, -y + h)
        end
    end
    return positions, width, height
end
