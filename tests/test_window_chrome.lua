-- The four windows' chrome (title bar, close cross, footer) as it was
-- before they shared it: the record in window_chrome.lua (tests/chrome.lua),
-- the close cross's hover and click, and the title bar's drag.
local M = H.M
local Chrome = dofile("chrome.lua")
local want = dofile("window_chrome.lua")

local ns, windows = Chrome.Windows()
for _, name in ipairs(Chrome.NAMES) do
    local w = windows[name]
    local got = Chrome.Record(w[1], w[2])
    H.check(name .. ": as many lines", #got, #want[name])
    for i = 1, math.max(#got, #want[name]) do
        H.check(name .. " line " .. i, got[i], want[name][i])
    end
end

local COLORS = ns.Style.COLORS
local function lineColor(cross, i) return cross.lines[i]._color[1] end

-- The close cross: accent on hover, muted again after; a click closes its
-- window. The wizard has none (Cancel closes it).
for _, name in ipairs({ "unit", "raid", "news" }) do
    local window = windows[name][1]
    local cross = window.titleBar.close
    cross:GetScript("OnEnter")(cross)
    H.check(name .. ": cross accent on hover", lineColor(cross, 1), COLORS.accent[1])
    H.check(name .. ": both lines", lineColor(cross, 2), COLORS.accent[1])
    cross:GetScript("OnLeave")(cross)
    H.check(name .. ": cross muted after", lineColor(cross, 1), COLORS.muted[1])
    H.checkTrue(name .. ": open before the click", window:IsShown())
    cross:GetScript("OnClick")(cross)
    H.check(name .. ": closed by the cross", window:IsShown(), false)
end

-- The title bar drags its window; the options windows keep where it was
-- left (SavedVariables), the other two nothing.
local SAVED = { unit = "window", raid = "raidWindow" }
local function dbKeys()
    local keys = {}
    for k in pairs(ForeverUnitFramesDB) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    return table.concat(keys, ",")
end
ForeverUnitFramesDB.window, ForeverUnitFramesDB.raidWindow = nil, nil
local moved = {}
for _, name in ipairs(Chrome.NAMES) do
    local window = windows[name][1]
    local bar = windows[name][2][1][2]
    window.StartMoving = function() moved[name] = "moving" end
    window.StopMovingOrSizing = function() moved[name] = "stopped" end
    local before = dbKeys()
    bar:GetScript("OnDragStart")(bar)
    H.check(name .. ": drag moves the window", moved[name], "moving")
    bar:GetScript("OnDragStop")(bar)
    H.check(name .. ": drag stops", moved[name], "stopped")
    if SAVED[name] then
        H.check(name .. ": position saved", type(ForeverUnitFramesDB[SAVED[name]]), "table")
    else
        H.check(name .. ": nothing saved", dbKeys(), before)
    end
end

-- Hover paint of the menu entries: an entry not selected reads "text" under
-- the mouse (a navigation entry also shows its hover fill) and its idle
-- colour after; the selected one keeps its accent.
local O, RO = ns.Options, ns.RaidOptions
local function textColor(b) return b.text._color[1] end
local function hover(label, b, idle, fill)
    b:GetScript("OnEnter")(b)
    H.check(label .. ": hover", textColor(b), COLORS[b.selected and "accent" or "text"][1])
    if fill then H.check(label .. ": fill shown", b.hover:IsShown(), true) end
    b:GetScript("OnLeave")(b)
    H.check(label .. ": after", textColor(b), COLORS[b.selected and "accent" or idle][1])
    if fill then H.check(label .. ": fill hidden", b.hover:IsShown(), false) end
end
hover("unit nav, not selected", O.navButtons.general, "text", true)
hover("unit nav, selected", O.navButtons.player, "text", true)
H.checkTrue("unit nav selected", O.navButtons.player.selected)
hover("unit tab 1", O.tabButtons[1], "muted")
hover("unit tab 2", O.tabButtons[2], "muted")
hover("raid menu tab 1", RO.tabButtons[1], "muted")
hover("raid menu tab 2", RO.tabButtons[2], "muted")
hover("raid top bar General", RO.generalTab, "muted")
hover("raid top bar Profiles", RO.profilesTab, "muted")
