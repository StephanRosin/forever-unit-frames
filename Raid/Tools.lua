local _, ns = ...

-- The raid tools bar: what Blizzard's raid manager offered (hidden with
-- Blizzard's raid frames, Core/Blizzard.lua), in rows, each switched on
-- its own: the raid target icons for your target; the ready check (the
-- last result for everyone, starting one for the leader and assistants:
-- tools only they may use show for them only, and while test mode is on);
-- the world markers (leader and assistants).
-- It shows in a raid
-- and in a party while the raid frames are on, hidden when solo, and
-- while test mode is on, so it can be placed. Docked, it hangs on the
-- main panel's right edge behind a handle that folds it out and in (out
-- of combat; the panel's anchor never moves in combat) and follows the
-- panel; free, it has its own mover (the raid window's lock) and its
-- top-left corner in the raid profile's General settings, the same for
-- every size.
--
-- Secure buttons (the raid target icons and the world markers:
-- SECURE_ACTIONS.raidtarget and .worldmarker,
-- Blizzard_FrameXML/SecureTemplates.lua) make the bar protected: it is
-- built, shown, hidden, sized and moved only out of combat
-- (ns.AfterCombat); a change of the group in combat waits for its end.
-- No secure snippets: a secure button's action is the client's own
-- (it calls SetRaidTarget, PlaceRaidMarker or ClearRaidMarker in secure
-- code); the addon never calls a restricted function itself.
local Tools = {}
ns.RaidTools = Tools

local L, Style, Panel = ns.L, ns.Style, ns.RaidPanel

Tools.NAME = "ForeverUnitFramesRaidTools"
-- An icon button's size, the room between buttons and rows, the bar's
-- inner edge.
Tools.ICON, Tools.GAP, Tools.PADDING = 18, 2, 4
-- The mover's size while no row shows.
Tools.EMPTY_SIZE = 40
-- Docked: the handle's size, and the room between the panel, the handle
-- and the bar.
Tools.HANDLE_W, Tools.HANDLE_H, Tools.DOCK_GAP = 12, 32, 4
Tools.MARKERS = 8
Tools.POSITION_KEYS = { toolsX = "x", toolsY = "y" }
-- The bar's own settings: the panels do not follow them.
Tools.KEYS = { "toolsShow", "toolsMode", "toolsOpen", "toolsX", "toolsY", "toolsTargets", "toolsReady",
    "toolsMarkers" }
for _, key in ipairs(Tools.KEYS) do Panel.UNRELATED_KEYS[key] = true end
-- Its position shows in the raid window like a panel's.
Panel.others[#Panel.others + 1] = Tools

-- The rows, top to bottom: { id, key (its switch), build(bar) -> a plain
-- frame of its size, visible() (optional: whether it shows now),
-- layout(frame) (optional: out of combat, its buttons for who you are and
-- its size) }.
Tools.rows = {}
function Tools.AddRow(row)
    Tools.rows[#Tools.rows + 1] = row
    return row
end

local function general(key) return ns.RaidConfig.Get("general", key) end
local function testing() return ns.RaidTestMode ~= nil and ns.RaidTestMode.IsOn() end
local function docked() return general("toolsMode") == "DOCKED" end

-- Whether the bar shows now (with at least one row).
function Tools.Shown()
    if not (Panel.Enabled() and general("toolsShow")) then return false end
    return IsInGroup() or testing()
end

-- The bar's size, or a small handle's while it is empty.
function Tools.Size()
    if (Tools.width or 0) > 0 then return Tools.width, Tools.height end
    return Tools.EMPTY_SIZE, Tools.ICON + 2 * Tools.PADDING
end

-- A position value moved to where the bar stays inside the screen.
function Tools.Reachable(axis, v)
    local w, h = Tools.Size()
    return Panel.Reach(w, h, axis, v)
end

-- Its mover shows with the raid window's lock while the bar shows free.
function Tools.Movable()
    return Tools.Shown() and not docked()
end

function Tools.MoverSpec()
    return {
        scope = "general", config = ns.RaidConfig, xKey = "toolsX", yKey = "toolsY", id = "raidTools",
        group = "raid", point = "TOPLEFT", origin = "TOPLEFT", anchor = false, size = Tools.Size,
        active = Tools.Movable, clamp = Tools.Reachable, label = function() return L.RAID_TOOLS_TITLE end,
    }
end

-- Buttons ---------------------------------------------------------------------------

local function tooltip(button, textKey)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L[textKey], 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end

-- A secure button that acts on a mouse button's release (the client runs
-- its type's action).
local function secureButton(parent, attributes)
    local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    b:SetSize(Tools.ICON, Tools.ICON)
    b:RegisterForClicks("AnyUp")
    for name, value in pairs(attributes) do b:SetAttribute(name, value) end
    return b
end

-- The × of a "clear" button, drawn from two lines (the glyph is not in
-- every game font).
local function cross(button)
    for _, angle in ipairs({ math.pi / 4, -math.pi / 4 }) do
        local t = button:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(unpack(Style.COLORS.text))
        t:SetSize(Tools.ICON - 4, 2)
        t:SetPoint("CENTER")
        t:SetRotation(angle)
    end
end

-- Lays buttons out in a row; the row's size follows them.
local function lineUp(row, buttons)
    local x = 0
    for _, b in ipairs(buttons) do
        b:SetPoint("LEFT", row, "LEFT", x, 0)
        x = x + b:GetWidth() + Tools.GAP
    end
    row:SetSize(math.max(x - Tools.GAP, 1), Tools.ICON)
end

-- The raid target icons, as Blizzard's TargetFrame draws them
-- (Elements/RaidMarker.lua's sheet): a click puts the icon on your
-- target or takes it off again (action "toggle"); the last button takes
-- your target's icon off.
Tools.AddRow({ id = "targets", key = "toolsTargets", build = function(bar)
    local row = CreateFrame("Frame", nil, bar)
    local buttons = {}
    for i = 1, Tools.MARKERS do
        local b = secureButton(row, { type = "raidtarget", unit = "target", marker = i, action = "toggle" })
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints(b)
        b.icon:SetTexture(ns.RaidMarker.TEXTURE)
        b.icon:SetSpriteSheetCell(i, ns.RaidMarker.ROWS, ns.RaidMarker.COLUMNS)
        buttons[i] = b
    end
    local clear = secureButton(row, { type = "raidtarget", unit = "target", action = "clear" })
    cross(clear)
    tooltip(clear, "RAID_TOOLS_CLEAR_TARGET")
    buttons[#buttons + 1] = clear
    lineUp(row, buttons)
    row.buttons, row.clear = buttons, clear
    return row
end })

-- Ready check -----------------------------------------------------------------------

-- Whether you lead the group or assist (secret while your identity is
-- restricted: then not); in test mode yes, so every tool shows.
function Tools.Leads()
    if testing() then return true end
    local Secrets = ns.Secrets
    return Secrets.Bool(UnitIsGroupLeader, "player") == true or Secrets.Bool(UnitIsGroupAssistant, "player") == true
end

Tools.READY_W, Tools.COUNT_W = 90, 22
-- The answers, as Blizzard's raid frames mark them (Elements/GroupIcons.lua).
Tools.READY_ORDER = { "ready", "notready", "waiting" }
-- The last ready check's answers counted per status; nil before the first.
Tools.readyCounts = nil

-- The group's units: the raid's, or you and your party.
local function groupUnits()
    local list, n = {}, GetNumGroupMembers()
    if IsInRaid() then
        for i = 1, n do list[i] = "raid" .. i end
    elseif n > 0 then
        list[1] = "player"
        for i = 1, n - 1 do list[#list + 1] = "party" .. i end
    end
    return list
end

-- Counts every readable answer (a secret one is left out); when the
-- check is over, whoever did not answer is not ready (as Blizzard's raid
-- frames, CompactUnitFrame_FinishReadyCheck).
local function countReady(finished)
    local counts = { ready = 0, notready = 0, waiting = 0 }
    for _, unit in ipairs(groupUnits()) do
        local ok, status = pcall(GetReadyCheckStatus, unit)
        if ok and not ns.Secrets.IsSecret(status) and type(status) == "string" and counts[status] then
            if finished and status == "waiting" then status = "notready" end
            counts[status] = counts[status] + 1
        end
    end
    Tools.readyCounts = counts
end

local readyRow

-- Any time: the counts, or nothing before the first check.
local function renderReady()
    if not readyRow then return end
    local counts = Tools.readyCounts
    for _, status in ipairs(Tools.READY_ORDER) do
        local c = readyRow.counts[status]
        c.icon:SetShown(counts ~= nil)
        c.text:SetText(counts and tostring(counts[status]) or "")
    end
end

Tools.AddRow({ id = "ready", key = "toolsReady", build = function(bar)
    local row = CreateFrame("Frame", nil, bar)
    row.start = ns.Widgets.Button(row, { text = L.RAID_TOOLS_READY_CHECK, width = Tools.READY_W,
        onClick = function() C_PartyInfo.DoReadyCheck() end })
    row.start:SetHeight(Tools.ICON)
    row.counts = {}
    for _, status in ipairs(Tools.READY_ORDER) do
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(Tools.ICON - 4, Tools.ICON - 4)
        icon:SetAtlas(ns.GroupIcons.READY[status])
        local text = Style.Text(row, 11, "text")
        text:SetPoint("LEFT", icon, "RIGHT", 1, 0)
        row.counts[status] = { icon = icon, text = text }
    end
    readyRow = row
    renderReady()
    return row
end, layout = function(row)
    local leads = Tools.Leads()
    row.start:SetShown(leads)
    row.start:ClearAllPoints()
    row.start:SetPoint("LEFT", row, "LEFT", 0, 0)
    local x = leads and (Tools.READY_W + 2 * Tools.GAP) or 0
    for _, status in ipairs(Tools.READY_ORDER) do
        local icon = row.counts[status].icon
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", row, "LEFT", x, 0)
        x = x + Tools.ICON + Tools.COUNT_W
    end
    row:SetSize(x, Tools.ICON)
end })

ns.On("READY_CHECK", function()
    countReady(false)
    renderReady()
end)
ns.On("READY_CHECK_CONFIRM", function()
    countReady(false)
    renderReady()
end)
ns.On("READY_CHECK_FINISHED", function()
    countReady(true)
    renderReady()
end)

-- World markers ---------------------------------------------------------------------

-- The world markers by index (1 blue square, 2 green triangle, 3 purple
-- diamond, 4 red cross, 5 yellow star, 6 orange circle, 7 silver moon,
-- 8 white skull) drawn with the raid target icon of the same sign.
Tools.WORLD_MARKER_ICONS = { 6, 4, 3, 7, 1, 2, 5, 8 }

-- Whether this client places world markers at all.
local function worldMarkers()
    if type(IsRaidMarkerSystemEnabled) ~= "function" then return true end
    local ok, on = pcall(IsRaidMarkerSystemEnabled)
    return not ok or ns.Secrets.IsSecret(on) or on == true
end

-- A click places the marker (the client's PlaceRaidMarker) or takes it
-- away again (action "toggle"); the last button takes every world marker
-- away (action "clear" without a marker). On a light square, so they do
-- not pass for the raid target icons.
Tools.AddRow({ id = "markers", key = "toolsMarkers", visible = function() return Tools.Leads() and worldMarkers() end,
    build = function(bar)
        local row = CreateFrame("Frame", nil, bar)
        local buttons = {}
        for i, icon in ipairs(Tools.WORLD_MARKER_ICONS) do
            local b = secureButton(row, { type = "worldmarker", marker = i, action = "toggle" })
            local bg = b:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(b)
            bg:SetColorTexture(1, 1, 1, 0.15)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
            b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
            b.icon:SetTexture(ns.RaidMarker.TEXTURE)
            b.icon:SetSpriteSheetCell(icon, ns.RaidMarker.ROWS, ns.RaidMarker.COLUMNS)
            tooltip(b, "RAID_TOOLS_WORLD_MARKER")
            buttons[i] = b
        end
        local clear = secureButton(row, { type = "worldmarker", action = "clear" })
        cross(clear)
        tooltip(clear, "RAID_TOOLS_CLEAR_MARKERS")
        buttons[#buttons + 1] = clear
        lineUp(row, buttons)
        row.buttons, row.clear = buttons, clear
        return row
    end })

-- The bar ---------------------------------------------------------------------------

-- Docked: the handle beside the main panel, the bar beyond it, both
-- hanging from the panel's anchor (out of combat: the bar is protected).
-- Free: its own mover holds it; before the mover is there, its position.
local function place()
    local bar = Tools.bar
    bar:ClearAllPoints()
    if docked() then
        local anchor = ns.RaidHeader.anchor or UIParent
        local x = (ns.RaidHeader.width or 0) + Tools.DOCK_GAP
        Tools.handle:ClearAllPoints()
        Tools.handle:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, 0)
        bar:SetPoint("TOPLEFT", anchor, "TOPLEFT", x + Tools.HANDLE_W + Tools.DOCK_GAP, 0)
    elseif bar.mover then
        ns.Movers.Sync(bar)
        bar:SetPoint("TOPLEFT", bar.mover, "TOPLEFT", 0, 0)
    else
        bar:SetPoint("TOPLEFT", UIParent, "CENTER", ns.Pixel.Snap(general("toolsX")), ns.Pixel.Snap(general("toolsY")))
    end
end

-- The handle points the way the bar folds.
local function paintHandle()
    Tools.handle.text:SetText(general("toolsOpen") and "<" or ">")
end

-- Out of combat: the rows that show, one below the other, the bar around
-- them with the panel's ring, where it belongs; shown or hidden (docked,
-- while folded out), the handle while docked.
function Tools.Refresh()
    local bar = Tools.bar
    if not bar then return end
    local y, width, any = Tools.PADDING, 0, false
    for _, row in ipairs(Tools.rows) do
        local f = row.frame
        local on = general(row.key) == true and (not row.visible or row.visible())
        f:SetShown(on)
        if on then
            if row.layout then row.layout(f) end
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", bar, "TOPLEFT", Tools.PADDING, -y)
            y = y + f:GetHeight() + Tools.GAP
            width = math.max(width, f:GetWidth())
            any = true
        end
    end
    if any then
        Tools.width, Tools.height = width + 2 * Tools.PADDING, y - Tools.GAP + Tools.PADDING
    else
        Tools.width, Tools.height = 0, 0
    end
    bar:SetSize(Tools.Size())
    place()
    ns.Border.Draw(bar, Panel.PANEL_SCOPE, bar, 0)
    local shown = any and Tools.Shown()
    bar:SetShown(shown and (not docked() or general("toolsOpen")))
    Tools.handle:SetShown(shown and docked())
    paintHandle()
end

-- The handle's click: folds the bar out or in; refused in combat.
function Tools.Fold()
    if InCombatLockdown() then
        ns.Print(L.RAID_TOOLS_COMBAT)
        return false
    end
    return ns.RaidConfig.Set("general", "toolsOpen", not general("toolsOpen"))
end

local function createHandle()
    local handle = CreateFrame("Button", Tools.NAME .. "Handle", UIParent)
    handle:SetSize(Tools.HANDLE_W, Tools.HANDLE_H)
    local bg = handle:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(handle)
    bg:SetColorTexture(0, 0, 0, 0.6)
    handle.text = Style.Text(handle, 12, "text")
    handle.text:SetPoint("CENTER")
    handle:SetScript("OnClick", function() Tools.Fold() end)
    tooltip(handle, "RAID_TOOLS_TITLE")
    handle:Hide()
    return handle
end

-- Built once, out of combat, after the raid profile is attached.
function Tools.Create()
    if Tools.bar then return Tools.bar end
    local bar = CreateFrame("Frame", Tools.NAME, UIParent)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0, 0, 0, 0.6)
    Tools.bar = bar
    Tools.handle = createHandle()
    for _, row in ipairs(Tools.rows) do row.frame = row.build(bar) end
    ns.Movers.Attach(bar, Tools.MoverSpec())
    Tools.Refresh()
    return bar
end

local function update()
    if Tools.bar then ns.AfterCombat("raidTools", Tools.Refresh) end
end

ns.On("GROUP_ROSTER_UPDATE", update)
-- Who leads changes which tools show.
ns.On("PARTY_LEADER_CHANGED", update)
ns.Listen("RAID_CONFIG_CHANGED", update)
ns.Listen("RAID_TEST_MODE", update)
ns.Listen("TEST_MODE", update)
-- Docked, it follows the main panel's size (placed out of combat).
ns.Listen("RAID_PANEL_PLACED", function(P)
    if P == ns.RaidHeader and Tools.bar and docked() then place() end
end)
