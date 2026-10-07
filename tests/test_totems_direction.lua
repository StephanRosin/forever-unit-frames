-- Totems in a row or a column (totemsDirection, decision 62): the holder
-- and the slots follow, the secure click areas with them, and only out of
-- combat (they are secure buttons).
local M = H.M

local function boot()
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "SHAMAN", className = "SHAMAN", isPlayer = true, health = 1,
        healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local ns = boot()
local S, C = ns.Settings, ns.Config
local def = S.Get("totemsDirection")
H.checkTrue("setting", def)
H.check("code", def and def.code, "QG")
H.check("choices", def and table.concat(def.values, ","), "HORIZONTAL,VERTICAL")
H.check("a row by default", def and S.Default(def, "player"), "HORIZONTAL")
H.check("player only", def and S.AppliesTo(def, "party"), false)
H.checkTrue("label", ns.L.SETTING_totemsDirection ~= "SETTING_totemsDirection")
local keys
for _, tab in ipairs(ns.Schema.Tabs("player")) do
    for _, sec in ipairs(tab.sections or {}) do
        if sec.id == "totems" then keys = table.concat(sec.keys, ",") end
    end
end
H.checkTrue("in the totems section after the spacing", keys and keys:find("totemsSpacing,totemsDirection", 1, true))

local t = ns.Frames.player.totems
local function at(region)
    local _, _, _, x, y = region:GetPoint(1)
    return x .. "," .. y
end
H.check("row: second slot to the right", at(t.slots[2].art), "27,0")

C.Set("player", "totemsDirection", "VERTICAL")
H.check("column: holder width", t.holder:GetWidth(), 24)
H.check("column: holder height", t.holder:GetHeight(), 4 * 24 + 3 * 3)
for i, s in ipairs(t.slots) do
    local step = (i - 1) * 27
    H.check("column: icon " .. i .. " below the last", at(s.art), "0," .. -step)
    H.check("column: click area " .. i .. " on its icon", at(s.click), "0," .. -step)
    H.check("column: click area " .. i .. " size", s.click:GetHeight(), 24)
end
-- The holder still hangs from the block where the points say.
local point, rel = t.holder:GetPoint(1)
H.check("column: holder's point", point, "LEFT")
H.check("column: from the block", rel, ns.Frames.player.unitBox)

-- In combat: nothing moves until it ends.
M.SetCombat(true)
M.FireEvent("PLAYER_REGEN_DISABLED")
C.Set("player", "totemsDirection", "HORIZONTAL")
H.check("combat: still a column", at(t.slots[2].click), "0,-27")
H.check("combat: holder unchanged", t.holder:GetHeight(), 4 * 24 + 3 * 3)
H.check("combat: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("after combat: a row", at(t.slots[2].click), "27,0")
H.check("after combat: holder a row", t.holder:GetWidth(), 4 * 24 + 3 * 3)
H.check("after combat: holder height", t.holder:GetHeight(), 24)
