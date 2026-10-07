local _, ns = ...

-- The Arrangement tab's board (Raid/Options/Arrangement.lua): for the
-- edited size a column per panel (Raid/OwnPanels.lua: Own.Columns), five
-- to a row, each with its name, its grouping and its blocks as chips.
-- A chip is moved by drag-and-drop onto another column of its grouping,
-- or from its menu (a click): Move to … each such column, or Take out
-- when no panel of the main panel's grouping is involved. An own panel's
-- column adds a block of its grouping and removes the panel (two
-- clicks); the board adds panels, up to nine. Plain frames only: a drag
-- is the chip's own OnDragStart / OnDragStop, the column under the
-- cursor when it is let go (IsMouseOver) takes it. Every change goes
-- through ns.RaidConfig; the window refreshes the board from
-- RAID_CONFIG_CHANGED. Locked in combat like the rows.
local Board = {}
ns.RaidBoard = Board

local Widgets, Style, Schema, Layout, Own = ns.Widgets, ns.Style, ns.RaidSchema, ns.RaidLayout, ns.RaidOwnPanels
local RaidOptions, L = ns.RaidOptions, ns.L

local COLUMNS_PER_ROW, BUTTON_H, CHIP_H, CHIP_GAP, PAD, HEAD_H, TOP_H = 5, 24, 22, 4, 6, 38, 36
-- Menu values that are no panel.
local TAKE_OUT, NOTHING = "", "-"

local function editedSize() return RaidOptions.Size() end

local function columnWidth()
    local P = RaidOptions.PAGE
    return math.floor((P.width - 2 * P.inset - (COLUMNS_PER_ROW - 1) * P.gap) / COLUMNS_PER_ROW)
end

-- A column's word: the main panel's, or the own panel's title or number.
local function columnName(data)
    if not data.slot then return L.RAID_MAIN_PANEL end
    local title = ns.RaidConfig.Get(ns.Raid.Scope(editedSize()), data.slot.id .. "Title")
    return Own.Name(data.slot, title)
end

local function groupingText(groupBy)
    return ("%s: %s"):format(Schema.Label("groupBy"), Schema.EnumText(ns.RaidSettings.Get("groupBy"), groupBy))
end

-- A dropdown that is only its button (as the window's Copy from…), its
-- text set by text().
local function menuButton(parent, opts, text)
    local row = Widgets.Dropdown(parent, opts)
    row:EnableMouse(false)
    row.hover:SetAlpha(0)
    row.button:ClearAllPoints()
    row.button:SetAllPoints(row)
    function row:Refresh() self.button.text:SetText(text(self)) end
    return row
end

local function nothingLeft(text) return { { value = NOTHING, text = text } } end

-- Chips ---------------------------------------------------------------------------

-- The columns a chip may go to: the others of its grouping.
local function targets(board, from)
    local list = {}
    for _, data in ipairs(board.data) do
        if data ~= from and data.groupBy == from.groupBy then list[#list + 1] = data end
    end
    return list
end

local function place(chip, toId)
    if toId == NOTHING then return end
    local data = chip.column.data
    Own.Place(editedSize(), data.groupBy, Layout.Token(chip.block), toId ~= TAKE_OUT and toId or nil)
end

local function chipItems(chip)
    local board, from = chip.column.board, chip.column.data
    local items = {}
    for _, data in ipairs(targets(board, from)) do
        items[#items + 1] = { value = data.id, text = L.RAID_MOVE_TO:format(columnName(data)) }
    end
    if from.slot and board.data[1].groupBy ~= from.groupBy then
        items[#items + 1] = { value = TAKE_OUT, text = L.RAID_TAKE_OUT }
    end
    if #items == 0 then return nothingLeft(L.RAID_NOWHERE) end
    return items
end

-- The column under the cursor, among those shown.
local function columnUnderCursor(board)
    for _, column in ipairs(board.columns) do
        if column:IsShown() and column:IsMouseOver() then return column end
    end
    return nil
end

local function onDragStart(button)
    local chip = button.chip
    if not chip.column.board.enabled then return end
    Widgets.CloseList()
    chip.dragging = true
    Style.SetBorderColor(button, "accent")
end

local function endDrag(chip)
    chip.dragging = false
    Style.SetBorderColor(chip.button, "border")
end

local function onDragStop(button)
    local chip = button.chip
    if not chip.dragging then return end
    endDrag(chip)
    local target = columnUnderCursor(chip.column.board)
    if not target or target == chip.column or target.data.groupBy ~= chip.column.data.groupBy then return end
    place(chip, target.data.id)
end

local function newChip(column)
    local chip
    chip = menuButton(column, {
        items = function() return chipItems(chip) end,
        get = function() return nil end,
        set = function(value) place(chip, value) end,
    }, function(self) return Layout.Title(self.block) end)
    chip.column = column
    chip:SetSize(columnWidth() - 2 * PAD, CHIP_H)
    chip.button.chip = chip
    chip.button:RegisterForDrag("LeftButton")
    chip.button:SetScript("OnDragStart", onDragStart)
    chip.button:SetScript("OnDragStop", onDragStop)
    return chip
end

-- Columns -------------------------------------------------------------------------

local function addBlockItems(column)
    local items = {}
    for _, block in ipairs(Own.Addable(editedSize(), column.data.slot)) do
        items[#items + 1] = { value = Layout.Token(block), text = Layout.Title(block) }
    end
    if #items == 0 then return nothingLeft(L.RAID_NONE_LEFT) end
    return items
end

local function addBlock(column, token)
    if token == NOTHING then return end
    Own.Place(editedSize(), column.data.groupBy, token, column.data.id)
end

-- An own panel's controls at the column's foot: add a block, remove it.
local function ownControls(column)
    local width = columnWidth() - 2 * PAD
    column.addBlock = menuButton(column, {
        items = function() return addBlockItems(column) end,
        get = function() return nil end,
        set = function(token) addBlock(column, token) end,
    }, function() return L.RAID_ADD_BLOCK end)
    column.addBlock:SetSize(width, BUTTON_H)
    column.remove = ns.Options.ConfirmButton(column, L.RAID_REMOVE_PANEL,
        function() Own.Remove(editedSize(), column.data.slot) end)
    column.remove:SetWidth(width)
end

local function newColumn(board)
    local column = CreateFrame("Frame", nil, board)
    column.board, column.chips = board, {}
    column:SetWidth(columnWidth())
    Style.Fill(column, "panel")
    Style.Border(column)
    column.name = Style.Text(column, 12, "accent")
    column.name:SetPoint("TOPLEFT", column, "TOPLEFT", PAD, -PAD)
    column.name:SetPoint("TOPRIGHT", column, "TOPRIGHT", -PAD, -PAD)
    column.name:SetJustifyH("LEFT")
    column.name:SetWordWrap(false)
    column.grouping = Style.Text(column, 10, "muted")
    column.grouping:SetPoint("TOPLEFT", column.name, "BOTTOMLEFT", 0, -4)
    column.grouping:SetJustifyH("LEFT")
    ownControls(column)
    return column
end

local function chipAt(column, i)
    column.chips[i] = column.chips[i] or newChip(column)
    return column.chips[i]
end

-- The height a column's content needs: its head, its chips, an own
-- panel's two controls.
local function contentHeight(data)
    local h = HEAD_H + #data.blocks * (CHIP_H + CHIP_GAP)
    if data.slot then h = h + 2 * (BUTTON_H + CHIP_GAP) end
    return h + PAD
end

local function fillColumn(column, data)
    column.data = data
    column.name:SetText(columnName(data))
    column.grouping:SetText(groupingText(data.groupBy))
    for i, block in ipairs(data.blocks) do
        local chip = chipAt(column, i)
        chip.block = block
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", column, "TOPLEFT", PAD, -(HEAD_H + (i - 1) * (CHIP_H + CHIP_GAP)))
        chip:Refresh()
        chip:Show()
    end
    for i = #data.blocks + 1, #column.chips do column.chips[i]:Hide() end
    column.addBlock:SetShown(data.slot ~= nil)
    column.remove:SetShown(data.slot ~= nil)
end

-- Own panels' controls stand at the foot of the (row-high) column.
local function placeFoot(column)
    column.remove:ClearAllPoints()
    column.remove:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", PAD, PAD)
    column.addBlock:ClearAllPoints()
    column.addBlock:SetPoint("BOTTOMLEFT", column.remove, "TOPLEFT", 0, CHIP_GAP)
end

-- Board ---------------------------------------------------------------------------

local function applyEnabled(board)
    local on = board.enabled
    board.addButton:SetEnabled(on and #board.data <= #ns.Raid.OWN_PANELS)
    for _, column in ipairs(board.columns) do
        for _, chip in ipairs(column.chips) do chip:SetEnabled(on) end
        column.addBlock:SetEnabled(on)
        column.remove:SetEnabled(on)
    end
end

-- The columns for the edited size, five to a row, each as high as the
-- tallest in its row; the board as high as its rows.
local function render(board)
    board.data = Own.Columns(editedSize())
    local P, width = RaidOptions.PAGE, columnWidth()
    local y = TOP_H
    for first = 1, #board.data, COLUMNS_PER_ROW do
        local last = math.min(first + COLUMNS_PER_ROW - 1, #board.data)
        local rowHeight = 0
        for i = first, last do rowHeight = math.max(rowHeight, contentHeight(board.data[i])) end
        for i = first, last do
            board.columns[i] = board.columns[i] or newColumn(board)
            local column = board.columns[i]
            fillColumn(column, board.data[i])
            column:ClearAllPoints()
            column:SetPoint("TOPLEFT", board, "TOPLEFT", P.inset + (i - first) * (width + P.gap), -y)
            column:SetHeight(rowHeight)
            placeFoot(column)
            column:Show()
        end
        y = y + rowHeight + P.gap
    end
    for i = #board.data + 1, #board.columns do board.columns[i]:Hide() end
    board:SetHeight(y)
    applyEnabled(board)
end

-- The board as a row of its page: Refresh renders it for the edited size
-- and then calls onRendered (the page lays itself out again).
function Board.New(page, onRendered)
    local board = CreateFrame("Frame", nil, page)
    board.columns, board.data, board.enabled = {}, {}, true
    local P = RaidOptions.PAGE
    board.addButton = Widgets.Button(board, { text = L.RAID_ADD_PANEL, width = 160,
        onClick = function() Own.Add(editedSize()) end })
    board.addButton:SetPoint("TOPLEFT", board, "TOPLEFT", P.inset, -4)
    board.hint = Style.Text(board, 11, "muted")
    board.hint:SetPoint("LEFT", board.addButton, "RIGHT", P.gap, 0)
    board.hint:SetText(L.RAID_BOARD_HINT)
    function board:Refresh()
        render(self)
        onRendered()
    end
    function board:SetEnabled(on)
        self.enabled = on
        -- A drag under way when combat starts is dropped nowhere.
        if not on then
            for _, column in ipairs(self.columns) do
                for _, chip in ipairs(column.chips) do
                    if chip.dragging then endDrag(chip) end
                end
            end
        end
        applyEnabled(self)
    end
    return board
end
