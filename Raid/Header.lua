local _, ns = ...

-- The raid panel. Each block (Raid/Layout.lua) is a SecureGroupHeader
-- with a filter that makes its cells (Raid/Cell.lua) and assigns their
-- units by itself, in combat too. Everything else is ours, out of combat
-- only: the headers' attributes, where each block goes, the cells' size.
--
-- Three kinds of frames, so that nothing protected ever has to move in
-- combat:
-- * the anchor: a plain frame at the panel's position (the raid profile's
--   x / y: its top-left corner from the screen centre); the headers hang
--   from it and it never moves in combat;
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
local Header = {}
ns.RaidHeader = Header

local Layout, Cell, Pixel, Border = ns.RaidLayout, ns.RaidCell, ns.Pixel, ns.Border

Header.NAME = "ForeverUnitFramesRaid"
-- Header i is named NAME .. "Block" .. i; block i of the current grouping.
Header.headers = {}
Header.blocks = {}
-- The plain frame of each block: title and border.
Header.decor = {}
Header.PANEL_SCOPE = "raidpanel"
Header.BLOCK_SCOPE = "raidblock"
-- Block titles: font size and the row they take above the cells.
Header.TITLE_SIZE = 11
Header.TITLE_HEIGHT = 14
Header.TITLE_COLOR = { 1, 0.82, 0 }

local function get(key) return ns.RaidConfig.Get(ns.Raid.Scope(Cell.Size()), key) end
local function general(key) return ns.RaidConfig.Get("general", key) end

-- The rings around the panel and around each block: the unit frames' gold
-- border (Core/Border.lua) in derived scopes of their own, square and
-- without shadow, shown while switched on in the raid profile; the rest
-- as a cell answers it, never as the party frame is set.
local PANEL_RING = { borderStyle = "GOLD", borderSize = 3, borderPadding = 3, cornerRadius = 0, shadowEnabled = false }
local BLOCK_RING = { borderStyle = "GOLD", borderSize = 2, borderPadding = 1, cornerRadius = 0, shadowEnabled = false }
ns.Config.Derive(Header.PANEL_SCOPE, Cell.KEY, function(key)
    if key == "borderShow" then return get("panelBorder") end
    return PANEL_RING[key]
end)
ns.Config.Derive(Header.BLOCK_SCOPE, Cell.KEY, function(key)
    if key == "borderShow" then return get("blockBorder") end
    return BLOCK_RING[key]
end)

-- Switched on, with a raid profile attached.
function Header.Enabled()
    return ns.RaidConfig.Profile() ~= nil and general("enabled") == true
end

-- The raid view in party: a 5-player group shows here, the party frames
-- hide (Units/Party.lua asks).
function Header.ReplacesParty()
    return Header.Enabled() and general("showInParty") == true
end

-- Whether the panel shows now: in a raid, or in a party with the raid
-- view in party on.
function Header.Active()
    if not Header.Enabled() then return false end
    return IsInRaid() or (IsInGroup() and general("showInParty") == true)
end

-- The numbers Raid/Layout.lua works with, on the pixel grid. A cell's
-- border reaches out between the cells and from the block's edge, a
-- block's border between the blocks.
function Header.Shape()
    local w, h = ns.Single.Size(Cell.KEY)
    local cellExtent = Border.Extent(Cell.KEY)
    return {
        cellWidth = w, cellHeight = h,
        cellGap = Pixel.Snap(get("cellSpacing")) + 2 * cellExtent,
        cellsPerLine = get("cellsPerLine"), cellGrowth = get("cellGrowth"),
        inset = cellExtent,
        titleHeight = get("blockTitles") and Pixel.Snap(Header.TITLE_HEIGHT) or 0,
        blockGap = Pixel.Snap(get("blockSpacing")) + 2 * Border.Extent(Header.BLOCK_SCOPE),
        blocksPerLine = get("blocksPerLine"), blockDirection = get("blockDirection"),
    }
end

-- Header attributes are set in one go; one relayout follows (Show). The
-- filter keys a block does not use are cleared.
local function setAttributes(header, attributes, filter)
    header:SetAttribute("_ignore", "attributeChanges")
    for name, value in pairs(attributes) do header:SetAttribute(name, value) end
    for _, name in ipairs(Layout.FILTER_KEYS) do header:SetAttribute(name, filter[name]) end
    header:SetAttribute("_ignore", nil)
end

local function headerAttributes(s, size)
    local a = Layout.HeaderAttributes(s, size)
    a.template, a.templateType = Cell.TEMPLATE, "Button"
    a.showRaid, a.showParty, a.showPlayer, a.showSolo = true, general("showInParty") == true, true, false
    -- By role: the blocks group by role (Raid/Layout.lua), raid order within.
    a.sortMethod = get("sortBy") == "NAME" and "NAME" or "INDEX"
    return a
end

local function header(i)
    local h = Header.headers[i]
    if h then return h end
    h = CreateFrame("Frame", Header.NAME .. "Block" .. i, UIParent, "SecureGroupHeaderTemplate")
    h.key = Cell.KEY
    Header.headers[i] = h
    return h
end

local function decor(i)
    local d = Header.decor[i]
    if d then return d end
    d = CreateFrame("Frame", nil, Header.panel)
    d.title = d:CreateFontString(nil, "OVERLAY")
    Header.decor[i] = d
    return d
end

-- Cells holding a unit in header i (the Lua field each cell keeps).
function Header.Count(i)
    local h, n, k = Header.headers[i], 0, 1
    if not h then return 0 end
    while h:GetAttribute("child" .. k) do
        if h:GetAttribute("child" .. k).unit then n = n + 1 end
        k = k + 1
    end
    return n
end

local function liveCounts()
    local counts = {}
    for i in ipairs(Header.blocks) do counts[i] = Header.Count(i) end
    return counts
end

local function styleTitle(d, block, s)
    local title = d.title
    if s.titleHeight == 0 then
        title:Hide()
        return
    end
    local C = ns.Config
    ns.Texts.SetFont(title, ns.Media.Font(C.Get(Cell.KEY, "fontFace")), Header.TITLE_SIZE,
        C.Get(Cell.KEY, "fontOutline"))
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
    title:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, 0)
    title:SetHeight(s.titleHeight)
    title:SetJustifyH("CENTER")
    title:SetWordWrap(false)
    local c = Header.TITLE_COLOR
    title:SetTextColor(c[1], c[2], c[3], 1)
    title:SetText(Layout.Title(block))
    title:Show()
end

-- Out of combat: blocks to their places for the given number of cells
-- per block (the headers' own, or test mode's), titles and borders, the
-- panel over the occupied area. A block without room parks its empty
-- header below the panel, each in a spot of its own a group block wide
-- (in a row, by block order): someone joining it in combat shows there
-- instead of on top of another block or another parked one. Returns
-- each block's place (nil without room) and the numbers it used
-- (Raid/TestMode.lua).
function Header.Place(counts)
    local s = Header.Shape()
    local hideEmpty = get("hideEmpty")
    local sizes = {}
    for i, block in ipairs(Header.blocks) do
        local room = Layout.Room(block, counts[i] or 0, hideEmpty)
        sizes[i] = room and { Layout.BlockSize(s, room) } or false
    end
    local positions, width, height = Layout.Arrange(s, sizes)
    local hx, hy = Layout.HeaderOffset(s)
    local parkedY, parkedStep = -(height + s.blockGap), Layout.BlockSize(s, Layout.GROUP_SIZE) + s.blockGap
    local parked = 0
    for i, block in ipairs(Header.blocks) do
        local pos, d = positions[i], decor(i)
        if pos then
            d:ClearAllPoints()
            d:SetPoint("TOPLEFT", Header.panel, "TOPLEFT", pos.x, pos.y)
            d:SetSize(sizes[i][1], sizes[i][2])
            styleTitle(d, block, s)
            Border.Draw(d, Header.BLOCK_SCOPE, d, 0)
            d:Show()
        else
            d:Hide()
        end
        local h = Header.headers[i]
        local at = pos
        if not at then
            at = { x = parked * parkedStep, y = parkedY }
            parked = parked + 1
        end
        if h then
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", Header.anchor, "TOPLEFT", at.x + hx, at.y + hy)
        end
    end
    for i = #Header.blocks + 1, #Header.decor do Header.decor[i]:Hide() end
    Header.width, Header.height = width, height
    Header.panel:SetSize(math.max(width, 1), math.max(height, 1))
    if width > 0 then
        Border.Draw(Header.panel, Header.PANEL_SCOPE, Header.panel, 0)
    else
        Border.Hide(Header.panel)
    end
    return positions, s
end

-- The panel's size, or a cell's while it is empty (the mover's handle).
function Header.Size()
    if (Header.width or 0) > 0 then return Header.width, Header.height end
    return ns.Single.Size(Cell.KEY)
end

-- The panel's top-left corner from the screen centre, on the pixel grid;
-- with a mover the anchor follows the mover.
local function placeAnchor()
    local anchor = Header.anchor
    anchor:SetSize(Header.Size())
    if anchor.mover then
        ns.Movers.Sync(anchor)
        return
    end
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", UIParent, "CENTER", Pixel.Snap(get("x")), Pixel.Snap(get("y")))
end

-- The mover (Core/Movers.lua): it holds the active size's x / y in the
-- raid profile, as the panel's top-left corner. Its label is Blizzard's
-- word for a raid and the size.
function Header.MoverSpec()
    return {
        scope = function() return ns.Raid.Scope(Cell.Size()) end, config = ns.RaidConfig, id = "raid",
        point = "TOPLEFT", origin = "TOPLEFT", size = Header.Size, active = Header.Enabled,
        label = function() return ("%s %d"):format(Layout.Title({ kind = "NONE" }), Cell.Size()) end,
    }
end

local function testing()
    return ns.RaidTestMode ~= nil and ns.RaidTestMode.IsOn()
end

-- Any time, combat included: the panel's plain frames follow the group,
-- or show the pretend raid of test mode.
function Header.UpdateVisibility()
    if Header.panel then Header.panel:SetShown(Header.Active() or testing()) end
end

-- Out of combat only: the whole layout for the active size. Every header
-- shows again (Hide + Show lays its cells out anew, OnShow); the cells it
-- does not use lose their anchors (it only SetPoints the ones it shows).
-- In test mode the headers stay hidden and the pretend raid takes their
-- place.
function Header.Refresh()
    if not Header.anchor then return end
    local size = Cell.Size()
    Header.blocks = Layout.Blocks(get("groupBy"), size, get("sortBy"), get("classOrder"))
    local s = Header.Shape()
    for i, block in ipairs(Header.blocks) do
        setAttributes(header(i), headerAttributes(s, size), block.filter)
    end
    for _, button in ipairs(Cell.buttons) do
        Cell.Style(button)
        button:ClearAllPoints()
    end
    local test = testing()
    local on = Header.Enabled() and not test
    for i, h in ipairs(Header.headers) do
        h:Hide()
        if on and i <= #Header.blocks then h:Show() end
    end
    if test then
        ns.RaidTestMode.Show()
    else
        if ns.RaidTestMode then ns.RaidTestMode.Hide() end
        Header.Place(liveCounts())
    end
    placeAnchor()
    Header.UpdateVisibility()
end

-- Built once, out of combat, after the raid profile is attached.
function Header.Create()
    if Header.anchor then return Header.anchor end
    Header.anchor = CreateFrame("Frame", Header.NAME, UIParent)
    Header.anchor.key = Cell.KEY
    Header.panel = CreateFrame("Frame", nil, UIParent)
    Header.panel:SetPoint("TOPLEFT", Header.anchor, "TOPLEFT", 0, 0)
    Header.Refresh()
    ns.Movers.Attach(Header.anchor, Header.MoverSpec())
    -- The party block may have been styled before the raid profile was
    -- there to ask; only the raid view in party changes its answer.
    if Header.ReplacesParty() then ns.AfterCombat("partyStyle", ns.Party.StyleAll) end
    return Header.anchor
end

local function refresh() ns.AfterCombat("raidLayout", Header.Refresh) end

-- Cells got or lost units. In combat: a cell made now needs its size and
-- the blocks their places, after combat. Out of combat: blocks are placed
-- once all headers are done, a moment later.
local placing = false
ns.Listen("RAID_CELLS_CHANGED", function()
    if not Header.anchor then return end
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
            Header.Place(liveCounts())
            placeAnchor()
        end)
    end)
end)

ns.On("GROUP_ROSTER_UPDATE", Header.UpdateVisibility)
ns.Listen("RAID_SIZE_CHANGED", function() if Header.anchor then refresh() end end)
-- A setting of the active size or the character; another size's profile
-- does not show.
ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if not Header.anchor then return end
    if scope == nil or scope == "general" or scope == ns.Raid.Scope(Cell.Size()) then refresh() end
    -- Raid view in party switched, or the raid frames: the party block.
    if scope == nil or (scope == "general" and (key == nil or key == "enabled" or key == "showInParty")) then
        ns.AfterCombat("partyStyle", ns.Party.StyleAll)
    end
end)
ns.Listen("PIXEL_GRID_CHANGED", function() if Header.anchor then refresh() end end)
-- The cells' words (Dead, Offline, ...) follow the language at once.
ns.Listen("LANGUAGE_CHANGED", function() if Header.anchor then refresh() end end)
