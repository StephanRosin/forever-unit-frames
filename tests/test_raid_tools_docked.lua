-- The raid tools bar docked (Raid/Tools.lua): a handle on the main
-- panel's right edge folds the bar out and in, out of combat only; both
-- hang from the panel's anchor and follow the panel's size; free, the
-- handle goes and the bar has its own mover. The raid window's rows.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1, isPlayer = true }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, RS, Tools, Header = ns.RaidConfig, ns.RaidSettings, ns.RaidTools, ns.RaidHeader

H.check("mode code", RS.Get("toolsMode").code, "IM")
H.check("modes", table.concat(RS.Get("toolsMode").values, ","), "DOCKED,FREE")
H.check("docked", RC.Get("general", "toolsMode"), "DOCKED")
H.check("fold code", RS.Get("toolsOpen").code, "IE")
H.check("folded in", RC.Get("general", "toolsOpen"), false)

local bar, handle = Tools.bar, Tools.handle
local function point(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    local name = rel == Header.anchor and "anchor" or rel == bar.mover and "mover" or rel == UIParent and "UIParent"
        or "?"
    return table.concat({ p, name, relPoint, x, y }, " ")
end
local function member(name, subgroup)
    return { name = name, class = "WARRIOR", subgroup = subgroup, unit = { health = 100, healthMax = 100, powerType = 1 } }
end
local list = {}
for i = 1, 7 do list[i] = member("M" .. i, i <= 5 and 1 or 2) end
M.SetRaidRoster(list)
M.RunTimers()

-- Folded in: the handle beside the panel, the bar hidden.
H.checkTrue("handle shown", handle:IsShown())
H.check("bar folded in", bar:IsShown(), false)
local width = Header.width
H.check("handle on the panel's right edge", point(handle), "TOPLEFT anchor TOPLEFT " .. (width + 4) .. " 0")
H.check("its size", handle:GetWidth() .. "x" .. handle:GetHeight(), "12x32")
H.check("points out", handle.text:GetText(), ">")
H.check("not protected", handle:IsProtected(), false)

-- A click folds it out, and in again.
handle:GetScript("OnClick")(handle)
H.check("folded out", RC.Get("general", "toolsOpen"), true)
H.checkTrue("bar shown", bar:IsShown())
H.check("bar beyond the handle", point(bar), "TOPLEFT anchor TOPLEFT " .. (width + 4 + 12 + 4) .. " 0")
H.check("points back", handle.text:GetText(), "<")

-- The panel grows: both follow it; the panel moves: both go along.
for i = 8, 12 do list[i] = member("M" .. i, 3) end
M.SetRaidRoster(list)
M.RunTimers()
H.checkTrue("the panel grew", Header.width > width)
H.check("handle follows", point(handle), "TOPLEFT anchor TOPLEFT " .. (Header.width + 4) .. " 0")
H.check("bar follows", point(bar), "TOPLEFT anchor TOPLEFT " .. (Header.width + 20) .. " 0")
RC.Set("r20", "x", -500)
H.check("they hang from the panel's anchor", point(bar), "TOPLEFT anchor TOPLEFT " .. (Header.width + 20) .. " 0")

-- In combat the handle refuses; nothing protected is touched.
local chat = #M.chat
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
handle:GetScript("OnClick")(handle)
H.check("combat: stays out", RC.Get("general", "toolsOpen"), true)
H.checkTrue("combat: the chat says why", M.chat[chat + 1] and M.chat[chat + 1]:find("only out of combat", 1, true))
H.check("combat: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
handle:GetScript("OnClick")(handle)
H.check("after combat: folded in", bar:IsShown(), false)

-- No mover while docked; free: no handle, its own mover.
ns.Movers.Unlock("raid")
H.check("docked: no mover", bar.mover:IsShown(), false)
RC.Set("general", "toolsMode", "FREE")
H.check("free: no handle", handle:IsShown(), false)
H.checkTrue("free: shown", bar:IsShown())
H.check("free: at its mover", point(bar), "TOPLEFT mover TOPLEFT 0 0")
H.checkTrue("free: its mover", bar.mover:IsShown())
ns.Movers.Lock("raid")
RC.Set("general", "toolsMode", "DOCKED")

-- A party without the raid view in party: the main panel is hidden, so
-- the docked bar falls back to its free position (no handle); with the
-- raid view on, it docks again.
M.SetRaidRoster({})
RC.Set("general", "showInParty", false)
M.units.party1 = { name = "Ann", class = "PRIEST", isPlayer = true }
M.SetGroup({ "party1" })
M.RunTimers()
H.check("party, no raid view: the panel hidden", ns.RaidPanel.Active(), false)
H.check("party, no raid view: no handle", handle:IsShown(), false)
H.checkTrue("party, no raid view: bar shown", bar:IsShown())
H.check("party, no raid view: at its free place", point(bar), "TOPLEFT mover TOPLEFT 0 0")
ns.Movers.Unlock("raid")
H.checkTrue("party, no raid view: its mover", bar.mover:IsShown())
ns.Movers.Lock("raid")
RC.Set("general", "showInParty", true)
M.RunTimers()
H.checkTrue("raid view on: docked again", handle:IsShown())
H.check("raid view on: folded in", bar:IsShown(), false)
-- Test mode shows the panel: docked.
RC.Set("general", "showInParty", false)
ns.RaidTestMode.Set(true)
H.checkTrue("test mode: docked", handle:IsShown())
ns.RaidTestMode.Set(false)
M.SetGroup({})

-- Solo: neither.
M.SetRaidRoster({})
H.check("solo: no handle", handle:IsShown(), false)
H.check("solo: no bar", bar:IsShown(), false)

-- The raid window: the fold only while docked, the position only while
-- free.
local RO = ns.RaidOptions
RO.Open(10, "tools")
local function row(key)
    for _, r in ipairs(RO.rows) do if r.key == key then return r end end
end
H.check("where", row("toolsMode").label:GetText(), "Where")
H.check("docked words", row("toolsMode").button.text:GetText(), "Docked to the panel")
H.check("docked: fold enabled", row("toolsOpen").enabledState, true)
H.check("docked: position disabled", row("toolsX").enabledState, false)
RC.Set("general", "toolsMode", "FREE")
H.check("free: fold disabled", row("toolsOpen").enabledState, false)
H.check("free: position enabled", row("toolsY").enabledState, true)
RO.Close()
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
