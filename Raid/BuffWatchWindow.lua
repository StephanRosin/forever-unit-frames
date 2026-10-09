local _, ns = ...

-- The buff watch window: a small panel with a header (its title, a gear
-- for the settings, the next cast of all: the smart buff key's,
-- Raid/SmartBuff.lua) and, below a rule, a block per watched buff
-- (Raid/BuffWatch.lua): a row with its icon, its name and marks counting
-- who misses it (red) and who has it running out (yellow), or "unknown"
-- while the client keeps auras secret; under the row up to two lines
-- with those members' names (Raid/BuffWatchNames.lua). Each row is a
-- secure action button: a click casts that buff on whoever needs it most
-- (BuffWatch.Best), its spell and unit set out of combat. It shows in a
-- group while the raid frames are on and a buff is watched (with "only
-- when missing": while one is missing or running out), and in raid test
-- mode so it can be placed (solo: a block per watched buff, without
-- counts or names, so it has its size in a group); its own mover (the
-- raid window's lock), its top-left corner in the character's settings;
-- lifted or moved back inside the screen when it grows beyond it (the
-- setting stays).
--
-- The rows make the window protected: it is built, shown, hidden, sized
-- and moved only out of combat (ns.AfterCombat). As combat starts
-- (PLAYER_REGEN_DISABLED, before lockdown) the rows are emptied and the
-- texts grey: in combat the window shows its last state and casts
-- nothing; the first scan after combat brings it back.
local Window = {}
ns.RaidBuffWindow = Window

local L, Style, Panel, Data = ns.L, ns.Style, ns.RaidPanel, ns.RaidBuffData
local Watch, SmartBuff, Names = ns.RaidBuffWatch, ns.SmartBuff, ns.RaidBuffNames

Window.NAME = "ForeverUnitFramesBuffWatch"
Window.WIDTH, Window.PADDING, Window.HEADER_H, Window.LINE_GAP = 260, 6, 18, 4
Window.ROW_H, Window.ICON, Window.GAP = 20, 18, 4
-- The name lines under a row: their height and size, indented under the name.
Window.NAME_LINE_H, Window.NAME_SIZE = 14, 10
Window.NAMES_INDENT = Window.ICON + Window.GAP
-- Rows made at most (a paladin's six blessings).
Window.MAX_ROWS = 6
Window.POSITION_KEYS = { buffWatchX = "x", buffWatchY = "y" }
Window.rows = {}
-- Its position shows in the raid window like a panel's.
Panel.others[#Panel.others + 1] = Window

local function general(key) return ns.RaidConfig.Get("general", key) end
local function testing() return ns.RaidTestMode ~= nil and ns.RaidTestMode.IsOn() end

-- Whether some member misses a watched buff or has it running out.
local function anyNeeded()
    for _, st in ipairs(Watch.state.entries) do
        if #st.needs > 0 then return true end
    end
    return false
end

-- Whether the window shows now.
function Window.Shown()
    if not (Panel.Enabled() and general("buffWatchShow")) then return false end
    if testing() then return true end
    if not IsInGroup() or #Watch.state.entries == 0 then return false end
    return not general("buffWatchOnlyMissing") or anyNeeded()
end

-- The rows' states: the watch's; in test mode while it has none (solo),
-- a preview per watched buff ({ entry, preview = true }).
local function states()
    local entries = Watch.state.entries
    if #entries > 0 or not testing() then return entries end
    local list = {}
    for i, entry in ipairs(Watch.Watched()) do list[i] = { entry = entry, preview = true } end
    return list
end

-- A buff's block: its row and its name lines.
function Window.BlockHeight(lineCount)
    return Window.ROW_H + lineCount * Window.NAME_LINE_H
end

-- Measures a text in the names' font; made on first use, as the mover asks
-- for the size before the window is built.
local scratch
local function measure(text)
    if not scratch then
        scratch = Style.Text(UIParent, Window.NAME_SIZE, "text")
        scratch:Hide()
    end
    scratch:SetText(text)
    return scratch:GetStringWidth()
end

-- Test mode shows two sample names, so the window has a realistic size.
-- Built per call: the language can change while the window lives.
local function sampleItems()
    return {
        { name = L.RAID_BUFF_SAMPLE_MISSING, missing = true, left = -1, reach = true },
        { name = L.RAID_BUFF_SAMPLE_EXPIRING, missing = false, left = 120, reach = true },
    }
end

-- The name lines of a state, packed to the room under the row. Size and
-- render both ask here, so the height they use always agrees.
local function linesOf(st)
    local items = st.preview and sampleItems() or Names.Of(st)
    return Names.Pack(items, Window.WIDTH - 2 * Window.PADDING - Window.NAMES_INDENT, measure)
end

-- Its size: the header, a block per watched buff.
function Window.Size()
    local entries = states()
    local h = 2 * Window.PADDING + Window.HEADER_H + Window.LINE_GAP
    for i = 1, math.min(#entries, Window.MAX_ROWS) do
        h = h + Window.BlockHeight(#linesOf(entries[i]))
    end
    return Window.WIDTH, h
end

function Window.Reachable(axis, v)
    local w, h = Window.Size()
    return Panel.Reach(w, h, axis, v)
end

function Window.MoverSpec()
    return {
        scope = "general", config = ns.RaidConfig, xKey = "buffWatchX", yKey = "buffWatchY", id = "raidBuffWatch",
        group = "raid", point = "TOPLEFT", origin = "TOPLEFT", anchor = false, size = Window.Size,
        active = Window.Shown, clamp = Window.Reachable, label = function() return L.RAID_BUFF_WATCH_TITLE end,
    }
end

-- The settings key of a state's buff (a blessing entry: the blessings').
local function keyOf(entry)
    if entry.classes then return Data.BLESSINGS_KEY end
    for _, buff in ipairs(Data.BUFFS) do
        if buff.id == entry.id then return buff.key end
    end
end

-- Out of combat: the buff is no longer watched (the options' switch).
function Window.SwitchOff(st)
    if InCombatLockdown() or not st or st.preview then return end
    local key = keyOf(st.entry)
    if key then ns.RaidConfig.Set("general", key, false) end
end

-- Rows ------------------------------------------------------------------------------

-- What no cast means: someone misses it but none is in range, or nothing
-- to buff.
local function noCast(needed)
    return needed and L.RAID_BUFF_OUT_OF_RANGE or L.RAID_BUFF_NOTHING
end

-- On whom a click casts; in combat nothing (the rows cast nothing then,
-- and no range is asked), nor on a preview row (test mode: it casts
-- nothing).
local function tooltip(row)
    row:SetScript("OnEnter", function(self)
        local st, text = self.state, nil
        local live = st and not st.preview and not InCombatLockdown()
        if live then text = SmartBuff.Describe(Watch.Best(st)) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text or noCast(live and #st.needs > 0), 1, 1, 1)
        if live then
            for _, item in ipairs(Names.Of(st)) do GameTooltip:AddLine(Names.Text(item)) end
            GameTooltip:AddLine(L.RAID_BUFF_RIGHT_CLICK, 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end

-- Out of combat: row i, made once. Both strokes, as the raid tools'
-- secure buttons (Raid/Tools.lua).
local function row(i)
    local r = Window.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, Window.frame, "SecureActionButtonTemplate")
    r:RegisterForClicks("AnyUp", "AnyDown")
    -- ATTRIBUTE_NOOP: the right button casts nothing; its click stops watching.
    r:SetAttribute("type2", "")
    -- After the secure click; only the up stroke (rows take both).
    r:SetScript("PostClick", function(self, button, down)
        if button == "RightButton" and not down then Window.SwitchOff(self.state) end
    end)
    -- Render places it (the blocks differ in height).
    r:SetSize(Window.WIDTH - 2 * Window.PADDING, Window.BlockHeight(0))
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(Window.ICON, Window.ICON)
    r.icon:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -(Window.ROW_H - Window.ICON) / 2)
    r.count = Style.Text(r, 11, "text")
    r.count:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, -(Window.ROW_H - 11) / 2)
    -- The name gives way to the counts: one line, cut where they begin.
    r.name = Style.Text(r, 11, "text")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", Window.GAP, 0)
    r.name:SetPoint("RIGHT", r.count, "LEFT", -Window.GAP, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    -- The members who need it, under the row, indented to the name.
    r.lines = {}
    for n = 1, Names.MAX_LINES do
        local line = Style.Text(r, Window.NAME_SIZE, "text")
        line:SetPoint("TOPLEFT", r, "TOPLEFT", Window.NAMES_INDENT, -(Window.ROW_H + (n - 1) * Window.NAME_LINE_H))
        line:SetPoint("RIGHT", r, "RIGHT", 0, 0)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        r.lines[n] = line
    end
    tooltip(r)
    Window.rows[i] = r
    return r
end

local function paint(colorKey)
    if not Window.frame then return end
    Style.Paint(Window.title, colorKey)
    Style.Paint(Window.next, colorKey)
    for _, r in ipairs(Window.rows) do
        Style.Paint(r.name, colorKey)
        Style.Paint(r.count, colorKey)
    end
end

-- A buff's counts as marks: who misses it (red), who has it running out
-- (yellow), a check when none; nothing on a preview. The names carry
-- their own colours, so only these numbers are coloured here.
local MARK = "|A:%s:12:12|a"
function Window.CountText(st)
    if st.preview then return "" end
    if st.unknown then return L.RAID_BUFF_UNKNOWN end
    if st.missing == 0 and st.expiring == 0 then return MARK:format("UI-LFG-ReadyMark") end
    local parts = {}
    if st.missing > 0 then parts[#parts + 1] = MARK:format("UI-LFG-DeclineMark") .. " |cffe64d4d" .. st.missing .. "|r" end
    if st.expiring > 0 then parts[#parts + 1] = MARK:format("UI-LFG-PendingMark") .. " |cffffd100" .. st.expiring .. "|r" end
    return table.concat(parts, "  ")
end

-- Out of combat: the blocks of the state, top-down, their casts, the next one.
local function render()
    local entries = states()
    local y = Window.PADDING + Window.HEADER_H + Window.LINE_GAP
    for i = 1, math.max(#Window.rows, math.min(#entries, Window.MAX_ROWS)) do
        local st = i <= Window.MAX_ROWS and entries[i] or nil
        local r = st and row(i) or Window.rows[i]
        if r then
            r.state = st
            SmartBuff.Set(r, st and not st.preview and Watch.Best(st) or nil)
            if st then
                local lines = linesOf(st)
                r.icon:SetTexture(st.entry.single.icon)
                r.name:SetText(st.entry.single.name)
                r.count:SetText(Window.CountText(st))
                for n = 1, Names.MAX_LINES do
                    r.lines[n]:SetText(lines[n] or "")
                    r.lines[n]:SetShown(lines[n] ~= nil)
                end
                r:SetHeight(Window.BlockHeight(#lines))
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", Window.frame, "TOPLEFT", Window.PADDING, -y)
                y = y + Window.BlockHeight(#lines)
            end
            r:SetShown(st ~= nil)
        end
    end
    local next = Watch.Next()
    Window.next:SetText(next and L.RAID_BUFF_NEXT:format(SmartBuff.Describe(next)) or noCast(anyNeeded()))
    paint("text")
end

-- Out of combat: its own mover holds it, the window moved back inside
-- the screen where its size would leave it (the setting stays: it fits
-- again when the window shrinks); before the mover is there, its
-- position, inside the screen as well.
local function place()
    local f = Window.frame
    local x, y = general("buffWatchX"), general("buffWatchY")
    local dx, dy = Window.Reachable("x", x) - x, Window.Reachable("y", y) - y
    f:ClearAllPoints()
    if f.mover then
        ns.Movers.Sync(f)
        f:SetPoint("TOPLEFT", f.mover, "TOPLEFT", ns.Pixel.Snap(dx), ns.Pixel.Snap(dy))
    else
        f:SetPoint("TOPLEFT", UIParent, "CENTER", ns.Pixel.Snap(x + dx), ns.Pixel.Snap(y + dy))
    end
end

-- Out of combat: everything anew.
function Window.Refresh()
    local f = Window.frame
    if not f or InCombatLockdown() then return end
    render()
    f:SetSize(Window.Size())
    place()
    ns.Border.Draw(f, Panel.PANEL_SCOPE, f, 0)
    f:SetShown(Window.Shown())
end

-- Built once, out of combat, after the raid profile is attached.
local function generalSwitch(key)
    return function() return ns.RaidConfig.Get("general", key) == true end,
        function() ns.RaidConfig.Set("general", key, not (ns.RaidConfig.Get("general", key) == true)) end
end

-- The gear's menu: every group buff of your class, as the options'
-- Buffs tab lists them; one the spell book does not know yet greyed.
function Window.OpenMenu(owner)
    if InCombatLockdown() then return end
    local class = Watch.PlayerClass()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L.RAID_BUFF_WATCH_TITLE)
        for _, buff in ipairs(Data.BUFFS) do
            if buff.class == class then
                local learned = Data.Highest(buff.single) ~= nil
                local text = L["RAID_SETTING_" .. buff.key]
                if not learned then text = text .. " (" .. L.RAID_BUFF_NOT_LEARNED .. ")" end
                local box = root:CreateCheckbox(text, generalSwitch(buff.key))
                if not learned then box:SetEnabled(false) end
            end
        end
        if class == "PALADIN" then
            local known = false
            for _, spells in pairs(Data.BLESSING) do
                if Data.Highest(spells.single) then known = true end
            end
            local box = root:CreateCheckbox(L.RAID_SETTING_buffBlessings, generalSwitch(Data.BLESSINGS_KEY))
            if not known then box:SetEnabled(false) end
        end
    end)
end

function Window.Create()
    if Window.frame then return Window.frame end
    local f = CreateFrame("Frame", Window.NAME, UIParent)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0, 0, 0, 0.6)
    Window.title = Style.Text(f, 12, "text")
    Window.title:SetPoint("TOPLEFT", f, "TOPLEFT", Window.PADDING, -Window.PADDING)
    Window.title:SetText(L.RAID_BUFF_WATCH_TITLE)
    local gear = CreateFrame("Button", nil, f)
    gear:SetSize(14, 14)
    gear:SetPoint("LEFT", Window.title, "RIGHT", Window.GAP, 0)
    gear.icon = gear:CreateTexture(nil, "ARTWORK")
    gear.icon:SetAllPoints(gear)
    gear.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetScript("OnClick", function(self) Window.OpenMenu(self) end)
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.RAID_BUFF_MENU_TIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    Window.gear = gear
    Window.next = Style.Text(f, 11, "text")
    Window.next:SetPoint("LEFT", gear, "RIGHT", Window.GAP, 0)
    Window.next:SetPoint("RIGHT", f, "TOPRIGHT", -Window.PADDING, -(Window.PADDING + Window.HEADER_H / 2))
    Window.next:SetJustifyH("RIGHT")
    Window.next:SetWordWrap(false)
    -- A rule between the header and the blocks.
    local ruleY = -(Window.PADDING + Window.HEADER_H + Window.LINE_GAP / 2)
    Window.rule = f:CreateTexture(nil, "ARTWORK")
    Window.rule:SetColorTexture(1, 1, 1, 0.15)
    Window.rule:SetHeight(1)
    Window.rule:SetPoint("TOPLEFT", f, "TOPLEFT", Window.PADDING, ruleY)
    Window.rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -Window.PADDING, ruleY)
    Window.frame = f
    f:Hide()
    ns.Movers.Attach(f, Window.MoverSpec())
    Window.Refresh()
    return f
end

local function update()
    if Window.frame then ns.AfterCombat("raidBuffWindow", Window.Refresh) end
end

-- Combat starts (before lockdown): the rows cast nothing, the texts grey.
ns.On("PLAYER_REGEN_DISABLED", function()
    if not Window.frame or InCombatLockdown() then return end
    for _, r in ipairs(Window.rows) do SmartBuff.Set(r, nil) end
    paint("muted")
end)
ns.Listen("RAID_BUFFS_CHANGED", update)
ns.On("GROUP_ROSTER_UPDATE", update)
ns.Listen("RAID_TEST_MODE", update)
ns.Listen("LANGUAGE_CHANGED", update)
ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if scope == nil or key == nil or scope == "general" then update() end
end)
