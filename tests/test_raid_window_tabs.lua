-- The raid window's tabs (Raid/Options/Window.lua): the window stays at
-- most 900 wide (a 960-wide screen keeps a margin); when the tabs do not
-- fit one row they wrap into two, each row fitting, the page below them,
-- in every language. Few tabs: one row.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO = ns.RaidOptions
local TAB_H = 30

RO.Open()
H.checkTrue("at most 900 wide", RO.frame:GetWidth() <= 900)
H.checkTrue("a 960-wide screen keeps a margin", 960 - RO.frame:GetWidth() >= 60)

local function rowsOf()
    local rows = {}
    for _, b in ipairs(RO.tabButtons) do
        local _, rel, _, _, y = b:GetPoint(1)
        if rel == RO.frame.tabRow then rows[#rows + 1] = { y = y, buttons = {} } end
        table.insert(rows[#rows].buttons, b)
    end
    return rows
end

for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    ns.Config.Set("general", "language", code)
    RO.Open()
    local rows = rowsOf()
    H.check(code .. ": two rows", #rows, 2)
    H.check(code .. ": the tab row holds both", RO.frame.tabRow:GetHeight(), 2 * TAB_H)
    for i, row in ipairs(rows) do
        H.check(code .. ": row " .. i .. " from the top", row.y, -(i - 1) * TAB_H)
        local right = 8
        for _, b in ipairs(row.buttons) do
            right = right + b:GetWidth()
            H.checkTrue(code .. ": word fits its tab " .. b.tabId, b.text:GetStringWidth() < b:GetWidth())
            H.check(code .. ": tab height", b:GetHeight(), TAB_H)
        end
        H.checkTrue(code .. ": row " .. i .. " fits", right <= RO.frame:GetWidth() - 8)
    end
    H.check(code .. ": every tab", #rows[1].buttons + #rows[2].buttons, #ns.RaidSchema.TABS)
    H.checkTrue(code .. ": the rows about even", math.abs(#rows[1].buttons - #rows[2].buttons) <= 1)
    -- The page starts below the tab rows.
    local _, rel = RO.frame.scroll:GetPoint(1)
    H.check(code .. ": the page below the tabs", rel, RO.frame.tabRow)
    RO.Close()
end
ns.Config.Set("general", "language", "AUTO")

-- Few tabs: one row, as before.
ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
RO = ns.RaidOptions
local all = ns.RaidSchema.TABS
ns.RaidSchema.TABS = { all[1], all[2], all[3], all[#all] }
RO.Open()
local rows = rowsOf()
H.check("few tabs: one row", #rows, 1)
H.check("few tabs: the row's height", RO.frame.tabRow:GetHeight(), TAB_H)
H.check("few tabs: at the top", rows[1].y, 0)
for _, b in ipairs(RO.tabButtons) do
    H.check("few tabs: " .. b.tabId .. " unsqueezed", b:GetWidth(), math.max(70, b.text:GetStringWidth() + 28))
end
RO.Close()
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
