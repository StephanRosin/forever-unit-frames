local _, ns = ...

-- The own panels: Panel 2 to Panel 10, further raid panels (Raid/Panel.lua)
-- beside the main one, built with it and moved with the raid window's
-- movers. Per raid size (Raid/Settings.lua, Raid.OWN_PANELS) each is
-- shown or not and has its grouping (group, class or role), the blocks of
-- that grouping it takes, in their order, a title above it and a layout
-- of its own; the cells are the main panel's of the size, so are the
-- spacing, the order within a block and the class order. A block it
-- takes in the main panel's grouping leaves the main panel
-- (Raid/Header.lua asks Own.Taken); one of another grouping shows its
-- players again. The raid window's Arrangement tab
-- (Raid/Options/Arrangement.lua) makes and fills them.
local Own = {}
ns.RaidOwnPanels = Own

local Panel, Layout, Cell, Raid = ns.RaidPanel, ns.RaidLayout, ns.RaidCell, ns.Raid

-- Every own panel, in slot order, and by id.
Own.list = {}
Own.panels = {}

local RaidConfig = ns.RaidConfig

local function shownScope() return Raid.Scope(Cell.Size()) end
local function get(key) return RaidConfig.Get(shownScope(), key) end

-- A part of a slot's settings (Raid.OWN_PANEL_PARTS) in a scope (default:
-- the shown size's).
local function setting(slot, part, scope) return RaidConfig.Get(scope or shownScope(), slot.id .. part) end

-- The tokens of the blocks a slot takes, as stored.
local function tokensOf(slot, scope) return Raid.ParseBlockList(setting(slot, "Blocks", scope)) or {} end

-- The part of a slot that stands for each main panel setting it is like.
local PART_LIKE = {}
for _, entry in ipairs(Raid.OWN_PANEL_PARTS) do
    if entry.like then PART_LIKE[entry.like] = entry.part end
end

local function shown(slot)
    return Panel.Enabled() and setting(slot, "Show") == true
end

-- The blocks of a grouping at a size, in the order the main panel has
-- them (the size's class order).
local function groupingBlocks(groupBy, size)
    local scope = Raid.Scope(size)
    return Layout.Blocks(groupBy, size, RaidConfig.Get(scope, "sortBy"), RaidConfig.Get(scope, "classOrder"))
end

-- The blocks a slot takes at a size, of its grouping, in its order.
local function chosenBlocks(slot, size)
    local scope = Raid.Scope(size)
    return Layout.Chosen(groupingBlocks(setting(slot, "GroupBy", scope), size), tokensOf(slot, scope))
end

-- A panel's word: its title, else "Panel N".
function Own.Name(slot, title)
    if title ~= nil and title ~= "" then return title end
    return ns.L.RAID_OWN_PANEL:format(slot.number)
end

-- The panel's blocks at the shown size; none while it is not shown.
local function blocks(slot, size)
    if not shown(slot) then return {} end
    return chosenBlocks(slot, size)
end

-- The tokens of the blocks of a grouping the own panels shown at a size
-- take (a set): the main panel leaves them out when it groups the same
-- way.
function Own.Taken(size, groupBy)
    local scope, taken = Raid.Scope(size), {}
    for _, slot in ipairs(Raid.OWN_PANELS) do
        if setting(slot, "Show", scope) and setting(slot, "GroupBy", scope) == groupBy then
            for _, token in ipairs(tokensOf(slot, scope)) do taken[token] = true end
        end
    end
    return taken
end

-- The main panel's blocks at a size: its grouping's, but those moved out.
function Own.MainBlocks(size)
    local groupBy = RaidConfig.Get(Raid.Scope(size), "groupBy")
    return Layout.Without(groupingBlocks(groupBy, size), Own.Taken(size, groupBy))
end

-- "panel2" -> "ForeverUnitFramesRaidPanel2".
local function frameName(slot)
    return "ForeverUnitFramesRaidPanel" .. slot.number
end

local function new(slot)
    local function read(key)
        local part = PART_LIKE[key]
        if part then return setting(slot, part) end
        return get(key)
    end
    local P = Panel.New({
        id = slot.id, name = frameName(slot), xKey = slot.id .. "X", yKey = slot.id .. "Y",
        blocks = function(size) return blocks(slot, size) end,
        shape = function(P) return Panel.Shape(read, P.blockScope) end,
        attributes = ns.RaidHeader.spec.attributes,
        enabled = function() return shown(slot) end,
        hideEmpty = function() return setting(slot, "HideEmpty") end,
        rings = { panel = function() return setting(slot, "PanelBorder") end,
            block = function() return setting(slot, "BlockBorder") end },
        title = function() return setting(slot, "Title") end,
        label = function() return ("%s %d"):format(Own.Name(slot, setting(slot, "Title")), Cell.Size()) end,
        -- Test mode: the pretend raid in its blocks (Raid/TestMode.lua).
        showTest = function(P) ns.RaidTestMode.Show(P) end,
        hideTest = function(P) if ns.RaidTestMode then ns.RaidTestMode.Hide(P) end end,
    })
    P.slot = slot
    Own.panels[slot.id] = P
    Own.list[#Own.list + 1] = P
    return P
end

for _, slot in ipairs(Raid.OWN_PANELS) do new(slot) end

-- Arranging a size (the raid window's Arrangement tab) -------------------------

-- The panels of a size as columns: the main panel ("main"), then each
-- shown own panel; each { id, slot (own panels), groupBy, blocks }.
function Own.Columns(size)
    local scope = Raid.Scope(size)
    local columns = { { id = "main", groupBy = RaidConfig.Get(scope, "groupBy"), blocks = Own.MainBlocks(size) } }
    for _, slot in ipairs(Raid.OWN_PANELS) do
        if setting(slot, "Show", scope) then
            columns[#columns + 1] = { id = slot.id, slot = slot, groupBy = setting(slot, "GroupBy", scope),
                blocks = chosenBlocks(slot, size) }
        end
    end
    return columns
end

-- The blocks of its grouping a slot does not take yet, at a size.
function Own.Addable(size, slot)
    local taken = {}
    for _, token in ipairs(tokensOf(slot, Raid.Scope(size))) do taken[token] = true end
    return Layout.Without(groupingBlocks(setting(slot, "GroupBy", Raid.Scope(size)), size), taken)
end

local function storeTokens(scope, slot, tokens)
    RaidConfig.Set(scope, slot.id .. "Blocks", table.concat(tokens, ","))
end

-- A block (its grouping and token) to a panel at a size: toId an own
-- panel's id, "main" (the main panel, the block's grouping being its) or
-- nil (taken out: nowhere). It leaves every other own panel of its
-- grouping, so a block is in one place; a panel that has it keeps its
-- place.
function Own.Place(size, groupBy, token, toId)
    local scope = Raid.Scope(size)
    for _, slot in ipairs(Raid.OWN_PANELS) do
        if slot.id ~= toId and setting(slot, "GroupBy", scope) == groupBy then
            local tokens = tokensOf(slot, scope)
            local kept = {}
            for _, t in ipairs(tokens) do
                if t ~= token then kept[#kept + 1] = t end
            end
            if #kept < #tokens then storeTokens(scope, slot, kept) end
        end
    end
    local target = toId and Raid.OwnPanel(toId)
    if not target then return end
    local tokens = tokensOf(target, scope)
    for _, t in ipairs(tokens) do
        if t == token then return end
    end
    tokens[#tokens + 1] = token
    storeTokens(scope, target, tokens)
end

-- Shows the first own panel not shown at a size; returns its slot, or nil
-- when all nine are.
function Own.Add(size)
    local scope = Raid.Scope(size)
    for _, slot in ipairs(Raid.OWN_PANELS) do
        if not setting(slot, "Show", scope) then
            RaidConfig.Set(scope, slot.id .. "Show", true)
            return slot
        end
    end
    return nil
end

-- An own panel gone from a size: every setting of its slot back to the
-- default (hidden, no blocks), in one change.
function Own.Remove(size, slot)
    RaidConfig.ResetKeys(Raid.Scope(size), slot.keys)
end

-- A panel's grouping at a size; a new grouping starts without blocks
-- (the old tokens name blocks of another grouping).
function Own.SetGrouping(size, slot, groupBy)
    local scope = Raid.Scope(size)
    if setting(slot, "GroupBy", scope) == groupBy then return end
    RaidConfig.Set(scope, slot.id .. "GroupBy", groupBy)
    storeTokens(scope, slot, {})
end
