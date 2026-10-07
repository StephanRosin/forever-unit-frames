local _, ns = ...

-- A raid panel: one or more blocks (Raid/Layout.lua), each a
-- SecureGroupHeader with a filter that makes its cells (Raid/Cell.lua)
-- and assigns their units by itself, in combat too. Everything else is
-- ours, out of combat only: the headers' attributes, where each block
-- goes, the cells' size. The main panel (Raid/Header.lua) is the first
-- panel; the special panels (main tanks, ...) are further panels of the
-- same kind, each with its own mover and position per raid size.
--
-- Three kinds of frames per panel, so that nothing protected ever has to
-- move in combat:
-- * the anchor: a plain frame at the panel's position (its x / y in the
--   raid profile: its top-left corner from the screen centre); the
--   headers hang from it and it never moves in combat;
-- * the headers, children of UIParent, each anchored to the anchor at its
--   block's place;
-- * the panel: a plain frame over the occupied area with the panel border,
--   and one plain frame per block with its title and border. Nothing
--   secure hangs from them, so they show and hide in combat as the group
--   changes.
--
-- Blocks are placed by how many cells each holds, counted out of combat a
-- moment after the headers changed their cells (RAID_CELLS_CHANGED). In
-- combat a joining member makes a block grow in place; the next layout
-- after combat tidies up. A group block keeps room for five, so a group
-- never runs into the next block.
--
-- A panel is made from a spec:
--   id             "main", "mainTanks", ...: combat-queue keys and the mover
--   name           the anchor's global name; header i is name .. "Block" .. i
--   template       the headers' template (default SecureGroupHeaderTemplate)
--   cellKey        the cells' unit-frame scope (default Raid/Cell.lua's KEY)
--   blocks(size)   the blocks for a raid size: { kind, id, capacity, filter }
--   shape(P)       the numbers Raid/Layout.lua works with
--   attributes(a, size)  optional: adds to a header's attributes
--   maxUnits       optional: the size a header's columns are counted for
--                  (default: the raid size shown)
--   enabled()      whether the panel shows at all
--   xKey, yKey     the settings of its position (per raid size)
--   label()        the mover's text
--   hideEmpty()    whether a block without members takes no room
--   blockRing      false: no ring around its block (a single block)
--   rings          optional: { panel(), block() } switch its rings, in
--                  ring scopes of its own (P.panelScope, P.blockScope);
--                  else the main panel's settings do
--   title()        optional: a title row above the blocks ("": none)
--   showTest(p), hideTest(p)  optional: test mode's pretend cells
local Panel = {}
ns.RaidPanel = Panel

local Layout, Cell, Pixel, Border = ns.RaidLayout, ns.RaidCell, ns.Pixel, ns.Border

-- Every panel, in the order they were made: the main panel first.
Panel.list = {}
Panel.PANEL_SCOPE = "raidpanel"
Panel.BLOCK_SCOPE = "raidblock"
-- Block titles: font size and the row they take above the cells.
Panel.TITLE_SIZE = 11
Panel.TITLE_HEIGHT = 14
Panel.TITLE_COLOR = { 1, 0.82, 0 }

-- A setting of the raid profile the cells show.
local function get(key) return ns.RaidConfig.Get(ns.Raid.Scope(Cell.Size()), key) end
local function general(key) return ns.RaidConfig.Get("general", key) end

-- The rings around a panel and around each block: the unit frames' gold
-- border (Core/Border.lua) in derived scopes of their own, square and
-- without shadow, shown while switched on in the raid profile; the rest
-- as a cell answers it, never as the party frame is set.
-- A panel with switches of its own (spec.rings) has scopes of its own.
local PANEL_RING = { borderStyle = "GOLD", borderSize = 3, borderPadding = 3, cornerRadius = 0, shadowEnabled = false }
local BLOCK_RING = { borderStyle = "GOLD", borderSize = 2, borderPadding = 1, cornerRadius = 0, shadowEnabled = false }
local function deriveRing(scope, ring, shown)
    ns.Config.Derive(scope, Cell.KEY, function(key)
        if key == "borderShow" then return shown() end
        return ring[key]
    end)
end
deriveRing(Panel.PANEL_SCOPE, PANEL_RING, function() return get("panelBorder") end)
deriveRing(Panel.BLOCK_SCOPE, BLOCK_RING, function() return get("blockBorder") end)

-- Switched on, with a raid profile attached.
function Panel.Enabled()
    return ns.RaidConfig.Profile() ~= nil and general("enabled") == true
end

-- Whether the raid frames show now: in a raid, or in a party with the
-- raid view in party on.
function Panel.Active()
    if not Panel.Enabled() then return false end
    return IsInRaid() or (IsInGroup() and general("showInParty") == true)
end

local function testing()
    return ns.RaidTestMode ~= nil and ns.RaidTestMode.IsOn()
end

-- A top-left corner (axis "x" or "y", from the screen centre) moved to
-- where something of size w x h stays inside the screen.
function Panel.Reach(w, h, axis, v)
    local lo, hi
    if axis == "x" then
        local half = UIParent:GetWidth() / 2
        lo, hi = math.ceil(-half), math.floor(half - w)
    else
        local half = UIParent:GetHeight() / 2
        lo, hi = math.ceil(-half + h), math.floor(half)
    end
    return math.max(lo, math.min(hi, v))
end

-- Header attributes are set in one go; one relayout follows (Show). The
-- filter keys a block does not use are cleared.
local function setAttributes(header, attributes, filter)
    header:SetAttribute("_ignore", "attributeChanges")
    for name, value in pairs(attributes) do header:SetAttribute(name, value) end
    for _, name in ipairs(Layout.FILTER_KEYS) do header:SetAttribute(name, filter[name]) end
    header:SetAttribute("_ignore", nil)
end

-- A title row across the top of frame: the cells' font, gold, centred.
local function styleTitle(title, frame, height, text)
    local C = ns.Config
    ns.Texts.SetFont(title, ns.Media.Font(C.Get(Cell.KEY, "fontFace")), Panel.TITLE_SIZE,
        C.Get(Cell.KEY, "fontOutline"))
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    title:SetHeight(height)
    title:SetJustifyH("CENTER")
    title:SetWordWrap(false)
    local c = Panel.TITLE_COLOR
    title:SetTextColor(c[1], c[2], c[3], 1)
    title:SetText(text)
    title:Show()
end

local function styleBlockTitle(d, block, s)
    if s.titleHeight == 0 then
        d.title:Hide()
        return
    end
    styleTitle(d.title, d, s.titleHeight, Layout.Title(block))
end

-- The numbers Raid/Layout.lua works with, on the pixel grid, from a
-- panel's settings: read(key) answers the main panel's setting of that
-- name as the panel has it. A cell's border reaches out between the
-- cells and from the block's edge, a block's border (blockScope) between
-- the blocks. The cells are the main panel's.
function Panel.Shape(read, blockScope)
    local w, h = ns.Single.Size(Cell.KEY)
    local cellExtent = Border.Extent(Cell.KEY)
    return {
        cellWidth = w, cellHeight = h,
        cellGap = Pixel.Snap(get("cellSpacing")) + 2 * cellExtent,
        cellsPerLine = read("cellsPerLine"), cellGrowth = read("cellGrowth"),
        inset = cellExtent,
        titleHeight = read("blockTitles") and Pixel.Snap(Panel.TITLE_HEIGHT) or 0,
        blockGap = Pixel.Snap(get("blockSpacing")) + 2 * Border.Extent(blockScope),
        blocksPerLine = read("blocksPerLine"), blockDirection = read("blockDirection"),
    }
end

function Panel.New(spec)
    local P = { spec = spec, id = spec.id, headers = {}, blocks = {}, decor = {} }
    P.panelScope, P.blockScope = Panel.PANEL_SCOPE, Panel.BLOCK_SCOPE
    if spec.rings then
        P.panelScope, P.blockScope = Panel.PANEL_SCOPE .. ":" .. spec.id, Panel.BLOCK_SCOPE .. ":" .. spec.id
        deriveRing(P.panelScope, PANEL_RING, spec.rings.panel)
        deriveRing(P.blockScope, BLOCK_RING, spec.rings.block)
    end
    local template = spec.template or "SecureGroupHeaderTemplate"
    local cellKey = spec.cellKey or Cell.KEY
    P.cellKey = cellKey
    -- The settings that hold the panel's position, and the axis of each.
    P.POSITION_KEYS = { [spec.xKey] = "x", [spec.yKey] = "y" }

    function P.Enabled() return spec.enabled() end

    function P.Shape() return spec.shape(P) end

    local function headerAttributes(s, size)
        local a = Layout.HeaderAttributes(s, spec.maxUnits or size)
        a.template, a.templateType = Cell.TEMPLATE, "Button"
        a.showRaid, a.showParty, a.showPlayer, a.showSolo = true, general("showInParty") == true, true, false
        if spec.attributes then spec.attributes(a, size) end
        return a
    end

    local function header(i)
        local h = P.headers[i]
        if h then return h end
        h = CreateFrame("Frame", spec.name .. "Block" .. i, UIParent, template)
        h.key = Cell.KEY
        h.cellKey = cellKey
        P.headers[i] = h
        return h
    end

    local function decor(i)
        local d = P.decor[i]
        if d then return d end
        d = CreateFrame("Frame", nil, P.panel)
        d.title = d:CreateFontString(nil, "OVERLAY")
        P.decor[i] = d
        return d
    end

    -- Cells holding a unit in header i (the Lua field each cell keeps).
    function P.Count(i)
        local h, n, k = P.headers[i], 0, 1
        if not h then return 0 end
        while h:GetAttribute("child" .. k) do
            if h:GetAttribute("child" .. k).unit then n = n + 1 end
            k = k + 1
        end
        return n
    end

    function P.LiveCounts()
        local counts = {}
        for i in ipairs(P.blocks) do counts[i] = P.Count(i) end
        return counts
    end

    -- Every cell the panel's headers made.
    function P.Cells()
        local list = {}
        for _, h in ipairs(P.headers) do
            local k = 1
            while h:GetAttribute("child" .. k) do
                list[#list + 1] = h:GetAttribute("child" .. k)
                k = k + 1
            end
        end
        return list
    end

    -- Out of combat: blocks to their places for the given number of cells
    -- per block (the headers' own, or test mode's), titles and borders,
    -- the panel over the occupied area. A block without room parks its
    -- empty header below the panel, each in a spot of its own a group
    -- block wide (in a row, by block order): someone joining it in combat
    -- shows there instead of on top of another block or another parked
    -- one. Returns each block's place (nil without room) and the numbers
    -- it used (Raid/TestMode.lua).
    function P.Place(counts)
        local s = P.Shape()
        local hideEmpty = spec.hideEmpty()
        local sizes = {}
        for i, block in ipairs(P.blocks) do
            local room = Layout.Room(block, counts[i] or 0, hideEmpty)
            sizes[i] = room and { Layout.BlockSize(s, room) } or false
        end
        local positions, width, height = Layout.Arrange(s, sizes)
        height = P.PlaceTitle(positions, width, height)
        local hx, hy = Layout.HeaderOffset(s)
        local parkedY, parkedStep = -(height + s.blockGap), Layout.BlockSize(s, Layout.GROUP_SIZE) + s.blockGap
        local parked = 0
        for i, block in ipairs(P.blocks) do
            local pos, d = positions[i], decor(i)
            if pos then
                d:ClearAllPoints()
                d:SetPoint("TOPLEFT", P.panel, "TOPLEFT", pos.x, pos.y)
                d:SetSize(sizes[i][1], sizes[i][2])
                styleBlockTitle(d, block, s)
                if spec.blockRing == false then Border.Hide(d) else Border.Draw(d, P.blockScope, d, 0) end
                d:Show()
            else
                d:Hide()
            end
            local h = P.headers[i]
            local at = pos
            if not at then
                at = { x = parked * parkedStep, y = parkedY }
                parked = parked + 1
            end
            if h then
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", P.anchor, "TOPLEFT", at.x + hx, at.y + hy)
            end
        end
        for i = #P.blocks + 1, #P.decor do P.decor[i]:Hide() end
        P.width, P.height = width, height
        P.panel:SetSize(math.max(width, 1), math.max(height, 1))
        if width > 0 then
            Border.Draw(P.panel, P.panelScope, P.panel, 0)
        else
            Border.Hide(P.panel)
        end
        -- What hangs beside it follows (the raid tools bar, docked).
        ns.Fire("RAID_PANEL_PLACED", P)
        return positions, s
    end

    -- The panel's title row (spec.title) above the blocks, while any block
    -- has room: the blocks move below it. It spans the panel on one line,
    -- so a title wider than the panel is cut short with the client's
    -- ellipsis; the panel keeps the width of its blocks. Returns the
    -- panel's height.
    function P.PlaceTitle(positions, width, height)
        local text = spec.title and spec.title() or ""
        if text == "" or width == 0 then
            if P.title then P.title:Hide() end
            return height
        end
        local row = Pixel.Snap(Panel.TITLE_HEIGHT)
        for _, pos in pairs(positions) do pos.y = pos.y - row end
        P.title = P.title or P.panel:CreateFontString(nil, "OVERLAY")
        styleTitle(P.title, P.panel, row, text)
        return height + row
    end

    -- The panel's size, or a cell's while it is empty (the mover's handle).
    function P.Size()
        if (P.width or 0) > 0 then return P.width, P.height end
        return ns.Single.Size(cellKey)
    end

    -- A position value (axis "x" or "y": the panel's top-left corner from
    -- the screen centre) moved to where the panel can be: the mover is
    -- clamped to the screen, so a value beyond would be stored but not
    -- shown. With shown, the panel's size stays inside the screen too;
    -- else (a size not shown, whose panel size is not known) the corner
    -- alone.
    function P.Reachable(axis, v, shown)
        local w, h = 0, 0
        if shown then w, h = P.Size() end
        return Panel.Reach(w, h, axis, v)
    end

    -- The panel's top-left corner from the screen centre, on the pixel
    -- grid; with a mover the anchor follows the mover.
    function P.PlaceAnchor()
        local anchor = P.anchor
        anchor:SetSize(P.Size())
        if anchor.mover then
            ns.Movers.Sync(anchor)
            return
        end
        anchor:ClearAllPoints()
        anchor:SetPoint("TOPLEFT", UIParent, "CENTER", Pixel.Snap(get(spec.xKey)), Pixel.Snap(get(spec.yKey)))
    end

    -- The mover (Core/Movers.lua): it holds the active size's position in
    -- the raid profile, as the panel's top-left corner; while the raid
    -- window's test mode is on, that of the size it previews.
    function P.MoverSpec()
        return {
            scope = function() return ns.Raid.Scope(Cell.Size()) end, config = ns.RaidConfig,
            id = spec.id == "main" and "raid" or ("raid:" .. spec.id), group = "raid",
            xKey = spec.xKey, yKey = spec.yKey,
            point = "TOPLEFT", origin = "TOPLEFT", size = P.Size, active = P.Enabled,
            clamp = function(axis, v) return P.Reachable(axis, v, true) end,
            label = spec.label,
        }
    end

    -- Any time, combat included: the panel's plain frames follow the
    -- group, or show the pretend raid of test mode.
    function P.UpdateVisibility()
        if P.panel then P.panel:SetShown(P.Enabled() and (Panel.Active() or testing())) end
    end

    -- Out of combat only: the whole layout for the active size. Every
    -- header shows again (Hide + Show lays its cells out anew, OnShow);
    -- the cells it does not use lose their anchors (it only SetPoints the
    -- ones it shows). In test mode the headers stay hidden and the
    -- pretend raid takes their place.
    function P.Refresh()
        if not P.anchor then return end
        local size = Cell.Size()
        P.blocks = spec.blocks(size)
        local s = P.Shape()
        for i, block in ipairs(P.blocks) do
            setAttributes(header(i), headerAttributes(s, size), block.filter)
        end
        for _, button in ipairs(P.Cells()) do
            Cell.Style(button)
            button:ClearAllPoints()
        end
        local test = testing()
        local enabled = P.Enabled()
        local on = enabled and not test
        for i, h in ipairs(P.headers) do
            h:Hide()
            if on and i <= #P.blocks then h:Show() end
        end
        if not enabled then
            -- Off: nothing to lay out (its plain frames hide below); laid
            -- out again when switched on (a setting change refreshes).
            if spec.hideTest then spec.hideTest(P) end
        elseif test and spec.showTest then
            spec.showTest(P)
        else
            if spec.hideTest then spec.hideTest(P) end
            P.Place(test and {} or P.LiveCounts())
        end
        P.PlaceAnchor()
        P.UpdateVisibility()
    end

    -- Built once, out of combat, after the raid profile is attached
    -- (Panel.CreateAll builds every panel).
    function P.Build()
        if P.anchor then return P.anchor end
        P.anchor = CreateFrame("Frame", spec.name, UIParent)
        P.anchor.key = Cell.KEY
        P.panel = CreateFrame("Frame", nil, UIParent)
        P.panel:SetPoint("TOPLEFT", P.anchor, "TOPLEFT", 0, 0)
        P.Refresh()
        ns.Movers.Attach(P.anchor, P.MoverSpec())
        return P.anchor
    end
    P.Create = P.Build

    Panel.list[#Panel.list + 1] = P
    return P
end

-- Other things with a position the raid window shows as - / + numbers
-- (the raid tools bar, Raid/Tools.lua): POSITION_KEYS and Reachable as a
-- panel has them.
Panel.others = {}

-- The panel (or other thing) whose position a setting holds and its axis
-- ("x" or "y"), or nil.
function Panel.ByPositionKey(key)
    for _, list in ipairs({ Panel.list, Panel.others }) do
        for _, P in ipairs(list) do
            local axis = P.POSITION_KEYS[key]
            if axis then return P, axis end
        end
    end
    return nil
end

-- Out of combat: every panel built, the main one first.
function Panel.CreateAll()
    for _, P in ipairs(Panel.list) do P.Build() end
end

-- Out of combat: every built panel laid out anew.
function Panel.RefreshAll()
    for _, P in ipairs(Panel.list) do P.Refresh() end
end

local function built() return Panel.list[1] ~= nil and Panel.list[1].anchor ~= nil end

local function refresh() ns.AfterCombat("raidLayout", Panel.RefreshAll) end

-- Only a position changed: that panel's anchor moves, the headers and
-- cells hanging from it go along. Out of combat: the secure headers hang
-- from the anchor.
local function move(P)
    ns.AfterCombat(P.id == "main" and "raidAnchor" or ("raidAnchor:" .. P.id), P.PlaceAnchor)
end

-- Cells got or lost units. In combat: a cell made now needs its size and
-- the blocks their places, after combat. Out of combat: blocks are placed
-- once all headers are done, a moment later.
local placing = false
ns.Listen("RAID_CELLS_CHANGED", function()
    if not built() then return end
    if InCombatLockdown() then
        refresh()
        return
    end
    if placing then return end
    placing = true
    C_Timer.After(0, function()
        placing = false
        ns.AfterCombat("raidPlace", function()
            if testing() then return end
            for _, P in ipairs(Panel.list) do
                if P.anchor and P.Enabled() then
                    P.Place(P.LiveCounts())
                    P.PlaceAnchor()
                end
            end
        end)
    end)
end)

ns.On("GROUP_ROSTER_UPDATE", function()
    for _, P in ipairs(Panel.list) do P.UpdateVisibility() end
end)
ns.Listen("RAID_SIZE_CHANGED", function() if built() then refresh() end end)
-- Character-wide settings that change nothing on the panels: the raid
-- minimap button's (Raid/MinimapButton.lua); others add theirs (the raid
-- tools bar, Raid/Tools.lua).
Panel.UNRELATED_KEYS = { minimapAngle = true, minimapShow = true }

local function panelAt(key)
    for _, P in ipairs(Panel.list) do
        if P.POSITION_KEYS[key] then return P end
    end
    return nil
end

-- A setting of the active size or the character; another size's profile
-- does not show, nor do the unrelated ones. The shown size's x / y of a
-- panel only move that panel.
ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if not built() then return end
    local shown = scope == ns.Raid.Scope(Cell.Size())
    local moved = shown and panelAt(key)
    if moved then
        move(moved)
    elseif shown or scope == nil or (scope == "general" and not Panel.UNRELATED_KEYS[key]) then
        refresh()
    end
end)
ns.Listen("PIXEL_GRID_CHANGED", function() if built() then refresh() end end)
-- The cells' words (Dead, Offline, ...) follow the language at once.
ns.Listen("LANGUAGE_CHANGED", function() if built() then refresh() end end)
