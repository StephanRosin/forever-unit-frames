-- Folding the raid tools bar (Raid/Tools.lua) without the options: the
-- free bar has the docked bar's handle too, on its left edge (folded in:
-- only the handle); /fuf tools and a right-click on the raid minimap
-- button fold it out and in, docked or free; nothing while the bar does
-- not show. In combat the fold waits for its end (the bar is protected)
-- and the chat says so. The fold is a state of the screen (uiState).
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1, isPlayer = true }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, RS, Tools, L = ns.RaidConfig, ns.RaidSettings, ns.RaidTools, ns.L
local bar, handle = Tools.bar, Tools.handle

local function point(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    local name = rel == bar.mover and "mover" or rel == bar and "bar" or rel == UIParent and "UIParent" or "?"
    return table.concat({ p, name, relPoint, x, y }, " ")
end
local function slash(msg) SlashCmdList.FOREVERUNITFRAMES(msg) end
local function open() return RC.Get("general", "toolsOpen") end

H.checkTrue("the fold is a state of the screen", RS.Get("toolsOpen").uiState)

-- Solo, nothing shows: /fuf tools does nothing and says nothing.
local chat = #M.chat
slash("tools")
H.check("not shown: unchanged", open(), false)
H.check("not shown: nothing in chat", #M.chat, chat)

-- Free, in a party: the handle on the bar's left edge, the bar folded in.
RC.Set("general", "toolsMode", "FREE")
M.units.party1 = { name = "Ann", class = "PRIEST", isPlayer = true }
M.SetGroup({ "party1" })
M.RunTimers()
H.checkTrue("free: handle shown", handle:IsShown())
H.check("free: folded in", bar:IsShown(), false)
H.check("free: the handle left of the bar", point(handle), "TOPRIGHT mover TOPLEFT -" .. Tools.DOCK_GAP .. " 0")
H.check("free: points out", handle.text:GetText(), ">")
H.check("free: not protected", handle:IsProtected(), false)
handle:GetScript("OnClick")(handle)
H.check("free: the handle folds out", open(), true)
H.checkTrue("free: bar shown", bar:IsShown())
H.check("free: the bar at its mover", point(bar), "TOPLEFT mover TOPLEFT 0 0")
H.check("free: points back", handle.text:GetText(), "<")

-- /fuf tools, free: in and out again, silently.
chat = #M.chat
slash("tools")
H.check("/fuf tools: folded in", open(), false)
H.check("/fuf tools: bar hidden", bar:IsShown(), false)
H.checkTrue("/fuf tools: handle stays", handle:IsShown())
slash("TOOLS")
H.check("/fuf tools again: out", open(), true)
H.check("/fuf tools: nothing in chat", #M.chat, chat)

-- Docked (a raid): /fuf tools folds the docked bar too.
RC.Set("general", "toolsMode", "DOCKED")
local list = {}
for i = 1, 6 do list[i] = { name = "M" .. i, class = "WARRIOR", subgroup = 1 } end
M.SetRaidRoster(list)
M.RunTimers()
H.checkTrue("docked: bar shown (out)", bar:IsShown())
slash("tools")
H.check("docked: /fuf tools folds in", bar:IsShown(), false)
H.checkTrue("docked: handle stays", handle:IsShown())

-- The raid minimap button: right-click folds, left-click still opens the
-- raid window.
local button = ns.RaidMinimapButton.button
H.check("left and right clicks", table.concat(button._clicks, ","), "LeftButtonUp,RightButtonUp")
button:GetScript("OnClick")(button, "RightButton")
H.check("right-click: out", open(), true)
H.check("right-click: the raid window stays shut", ns.RaidOptions.IsOpen(), false)
button:GetScript("OnClick")(button, "RightButton")
H.check("right-click again: in", open(), false)
button:GetScript("OnClick")(button, "LeftButton")
H.checkTrue("left-click: the raid window", ns.RaidOptions.IsOpen())
ns.RaidOptions.Close()
button:GetScript("OnEnter")(button)
H.check("tooltip names the right-click", table.concat(M.tooltipLines, "|"),
    "Forever Unit Frames: raid frames|Left-click: raid frame options|Right-click: fold the raid tools out or in"
        .. "|Drag: move button")
button:GetScript("OnLeave")(button)

-- In combat: the fold waits for the end of combat, and the chat says so;
-- nothing protected is touched. Twice in combat: back where it was.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
chat = #M.chat
slash("tools")
H.check("combat: still folded in", open(), false)
H.check("combat: the bar still hidden", bar:IsShown(), false)
H.checkTrue("combat: the chat says so", M.chat[chat + 1] and M.chat[chat + 1]:find(L.RAID_TOOLS_COMBAT, 1, true))
H.check("combat: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
H.check("after combat: folded out", open(), true)
H.checkTrue("after combat: bar shown", bar:IsShown())
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
handle:GetScript("OnClick")(handle)
button:GetScript("OnClick")(button, "RightButton")
M.SetCombat(false)
H.check("twice in combat: still out", open(), true)
H.check("after combat: nothing blocked", #M.blocked, 0)

-- Words in every language: the tooltip line, the combat line, the help.
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    for _, key in ipairs({ "RAID_MINIMAP_RIGHT_CLICK", "RAID_TOOLS_COMBAT", "NEWS_0_23_0_TOOLS" }) do
        H.check(code .. " " .. key, type(rawget(ns.Locales[code], key)), "string")
    end
    H.checkTrue(code .. " help names /fuf tools", ns.Locales[code].HELP:find("/fuf tools", 1, true))
end
H.check("no errors", #M.errors, 0)
