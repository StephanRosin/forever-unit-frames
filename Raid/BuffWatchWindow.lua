local _, ns = ...

-- The buff watch window: a small panel with a row per watched buff
-- (Raid/BuffWatch.lua): its icon, its name, how many members miss it and
-- how many have it running out, or "unknown" while the client keeps auras
-- secret; above them, what the next cast of all would be (the smart buff
-- key's, Raid/SmartBuff.lua). Each row is a secure action button: a click
-- casts that buff on whoever needs it most (BuffWatch.Best), its spell and
-- unit set out of combat. It shows in a group while the raid frames are
-- on and a buff is watched (with "only when missing": while one is missing
-- or running out), and in raid test mode so it can be placed; its own
-- mover (the raid window's lock), its top-left corner in the character's
-- settings.
--
-- The rows make the window protected: it is built, shown, hidden, sized
-- and moved only out of combat (ns.AfterCombat). As combat starts
-- (PLAYER_REGEN_DISABLED, before lockdown) the rows are emptied and the
-- texts grey: in combat the window shows its last state and casts
-- nothing; the first scan after combat brings it back.
local Window = {}
ns.RaidBuffWindow = Window

local L, Style, Panel = ns.L, ns.Style, ns.RaidPanel
local Watch, SmartBuff = ns.RaidBuffWatch, ns.SmartBuff

Window.NAME = "ForeverUnitFramesBuffWatch"
Window.WIDTH, Window.ROW_H, Window.ICON, Window.PADDING, Window.LINE_H = 200, 20, 16, 4, 16
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

-- Its size: a line for the next cast, a row per watched buff.
function Window.Size()
    local rows = math.min(#Watch.state.entries, Window.MAX_ROWS)
    return Window.WIDTH, 2 * Window.PADDING + Window.LINE_H + rows * Window.ROW_H
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

-- Rows ------------------------------------------------------------------------------

-- On whom a click casts; in combat nothing (the rows cast nothing then,
-- and no range is asked).
local function tooltip(row)
    row:SetScript("OnEnter", function(self)
        local text
        if self.state and not InCombatLockdown() then text = SmartBuff.Describe(Watch.Best(self.state)) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text or L.RAID_BUFF_NOTHING, 1, 1, 1)
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
    r:SetSize(Window.WIDTH - 2 * Window.PADDING, Window.ROW_H)
    r:SetPoint("TOPLEFT", Window.frame, "TOPLEFT", Window.PADDING,
        -(Window.PADDING + Window.LINE_H + (i - 1) * Window.ROW_H))
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(Window.ICON, Window.ICON)
    r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.name = Style.Text(r, 11, "text")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
    r.count = Style.Text(r, 11, "text")
    r.count:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    tooltip(r)
    Window.rows[i] = r
    return r
end

local function paint(colorKey)
    if not Window.frame then return end
    Style.Paint(Window.next, colorKey)
    for _, r in ipairs(Window.rows) do
        Style.Paint(r.name, colorKey)
        Style.Paint(r.count, colorKey)
    end
end

-- A buff's counts in words.
local function countText(st)
    if st.unknown then return L.RAID_BUFF_UNKNOWN end
    return L.RAID_BUFF_COUNTS:format(st.missing, st.expiring)
end

-- Out of combat: the rows of the state, their casts, the next one.
local function render()
    local entries = Watch.state.entries
    for i = 1, math.max(#Window.rows, math.min(#entries, Window.MAX_ROWS)) do
        local st = i <= Window.MAX_ROWS and entries[i] or nil
        local r = st and row(i) or Window.rows[i]
        if r then
            r.state = st
            SmartBuff.Set(r, st and Watch.Best(st) or nil)
            if st then
                r.icon:SetTexture(st.entry.single.icon)
                r.name:SetText(st.entry.single.name)
                r.count:SetText(countText(st))
            end
            r:SetShown(st ~= nil)
        end
    end
    local next = Watch.Next()
    Window.next:SetText(next and L.RAID_BUFF_NEXT:format(SmartBuff.Describe(next)) or L.RAID_BUFF_NOTHING)
    paint("text")
end

-- Out of combat: its own mover holds it; before the mover is there, its
-- position.
local function place()
    local f = Window.frame
    f:ClearAllPoints()
    if f.mover then
        ns.Movers.Sync(f)
        f:SetPoint("TOPLEFT", f.mover, "TOPLEFT", 0, 0)
    else
        f:SetPoint("TOPLEFT", UIParent, "CENTER", ns.Pixel.Snap(general("buffWatchX")),
            ns.Pixel.Snap(general("buffWatchY")))
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
function Window.Create()
    if Window.frame then return Window.frame end
    local f = CreateFrame("Frame", Window.NAME, UIParent)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0, 0, 0, 0.6)
    Window.next = Style.Text(f, 11, "text")
    Window.next:SetPoint("TOPLEFT", f, "TOPLEFT", Window.PADDING, -Window.PADDING)
    Window.next:SetPoint("TOPRIGHT", f, "TOPRIGHT", -Window.PADDING, -Window.PADDING)
    Window.next:SetJustifyH("LEFT")
    Window.next:SetWordWrap(false)
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
