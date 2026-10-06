local _, ns = ...

-- The raid tools bar: what Blizzard's raid manager offered (hidden with
-- Blizzard's raid frames, Core/Blizzard.lua), in rows, each switched on
-- its own: the raid target icons for your target, ... It shows in a raid
-- and in a party while the raid frames are on, hidden when solo, and
-- while test mode is on, so it can be placed. It has its own mover (the
-- raid window's lock); its top-left corner is in the raid profile's
-- General settings, the same for every size.
--
-- Secure buttons (the raid target icons: SECURE_ACTIONS.raidtarget,
-- Blizzard_FrameXML/SecureTemplates.lua) make the bar protected: it is
-- built, shown, hidden, sized and moved only out of combat
-- (ns.AfterCombat); a change of the group in combat waits for its end.
-- No secure snippets: a secure button's action is the client's own
-- (it calls SetRaidTarget in secure code); the addon never calls a
-- restricted function itself.
local Tools = {}
ns.RaidTools = Tools

local L, Style, Panel = ns.L, ns.Style, ns.RaidPanel

Tools.NAME = "ForeverUnitFramesRaidTools"
-- An icon button's size, the room between buttons and rows, the bar's
-- inner edge.
Tools.ICON, Tools.GAP, Tools.PADDING = 18, 2, 4
-- The mover's size while no row shows.
Tools.EMPTY_SIZE = 40
Tools.MARKERS = 8
Tools.POSITION_KEYS = { toolsX = "x", toolsY = "y" }
-- The bar's own settings: the panels do not follow them.
Tools.KEYS = { "toolsShow", "toolsX", "toolsY", "toolsTargets" }
for _, key in ipairs(Tools.KEYS) do Panel.UNRELATED_KEYS[key] = true end
-- Its position shows in the raid window like a panel's.
Panel.others[#Panel.others + 1] = Tools

-- The rows, top to bottom: { id, key (its switch), build(bar) -> a plain
-- frame of its size, visible() (optional: whether it shows now) }.
Tools.rows = {}
function Tools.AddRow(row)
    Tools.rows[#Tools.rows + 1] = row
    return row
end

local function general(key) return ns.RaidConfig.Get("general", key) end
local function testing() return ns.RaidTestMode ~= nil and ns.RaidTestMode.IsOn() end

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

-- Its handle shows with the raid window's lock while the bar shows.
function Tools.Movable()
    return Tools.Shown()
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

-- The bar ---------------------------------------------------------------------------

-- Its own mover holds it; before the mover is there, its position.
local function place()
    local bar = Tools.bar
    bar:ClearAllPoints()
    if bar.mover then
        ns.Movers.Sync(bar)
        bar:SetPoint("TOPLEFT", bar.mover, "TOPLEFT", 0, 0)
    else
        bar:SetPoint("TOPLEFT", UIParent, "CENTER", ns.Pixel.Snap(general("toolsX")), ns.Pixel.Snap(general("toolsY")))
    end
end

-- Out of combat: the rows that show, one below the other, the bar around
-- them with the panel's ring, where it belongs; shown or hidden.
function Tools.Refresh()
    local bar = Tools.bar
    if not bar then return end
    local y, width, any = Tools.PADDING, 0, false
    for _, row in ipairs(Tools.rows) do
        local f = row.frame
        local on = general(row.key) == true and (not row.visible or row.visible())
        f:SetShown(on)
        if on then
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
    bar:SetShown(any and Tools.Shown())
end

-- Built once, out of combat, after the raid profile is attached.
function Tools.Create()
    if Tools.bar then return Tools.bar end
    local bar = CreateFrame("Frame", Tools.NAME, UIParent)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0, 0, 0, 0.6)
    Tools.bar = bar
    for _, row in ipairs(Tools.rows) do row.frame = row.build(bar) end
    ns.Movers.Attach(bar, Tools.MoverSpec())
    Tools.Refresh()
    return bar
end

local function update()
    if Tools.bar then ns.AfterCombat("raidTools", Tools.Refresh) end
end

ns.On("GROUP_ROSTER_UPDATE", update)
ns.Listen("RAID_CONFIG_CHANGED", update)
ns.Listen("RAID_TEST_MODE", update)
ns.Listen("TEST_MODE", update)
