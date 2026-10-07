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

local function get(key) return ns.RaidConfig.Get(Raid.Scope(Cell.Size()), key) end

-- A part of a slot's settings (Raid.OWN_PANEL_PARTS) as the shown size has it.
local function setting(slot, part) return get(slot.id .. part) end

-- The part of a slot that stands for each main panel setting it is like.
local PART_LIKE = {}
for _, entry in ipairs(Raid.OWN_PANEL_PARTS) do
    if entry.like then PART_LIKE[entry.like] = entry.part end
end

local function shown(slot)
    return Panel.Enabled() and setting(slot, "Show") == true
end

-- A panel's word: its title, else "Panel N".
function Own.Name(slot, title)
    if title ~= nil and title ~= "" then return title end
    return ns.L.RAID_OWN_PANEL:format(slot.number)
end

-- The blocks a slot takes at a size, of its grouping, in its order (the
-- shown size's settings); none while it is not shown.
local function blocks(slot, size)
    if not shown(slot) then return {} end
    local tokens = Raid.ParseBlockList(setting(slot, "Blocks")) or {}
    return Layout.Chosen(Layout.Blocks(setting(slot, "GroupBy"), size, get("sortBy"), get("classOrder")), tokens)
end

-- The tokens of the blocks of a grouping the shown own panels take (a
-- set): the main panel leaves them out when it groups the same way.
function Own.Taken(groupBy)
    local taken = {}
    for _, slot in ipairs(Raid.OWN_PANELS) do
        if shown(slot) and setting(slot, "GroupBy") == groupBy then
            for _, token in ipairs(Raid.ParseBlockList(setting(slot, "Blocks")) or {}) do taken[token] = true end
        end
    end
    return taken
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
