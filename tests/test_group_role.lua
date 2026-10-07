-- The assigned role (tank, healer, damage) as a fourth group icon on the
-- player and party frames (decision 60): its own switch, off by default,
-- in the group icons' row after the others, in the raid cells' art.
-- UnitGroupRolesAssigned is secret while the unit's identity is
-- restricted: then nothing shows.
local M = H.M

local function boot()
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "WARRIOR", className = "WARRIOR", isPlayer = true, health = 1,
        healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

-- Settings ------------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local S = ns.Settings
    local def = S.Get("groupRole")
    H.checkTrue("setting", def)
    H.check("code", def and def.code, "LG")
    H.check("a switch", def and def.type, "bool")
    for _, scope in ipairs({ "player", "party" }) do
        H.checkTrue("on " .. scope, def and S.AppliesTo(def, scope))
        H.check("off by default on " .. scope, def and S.Default(def, scope), false)
    end
    for _, scope in ipairs({ "general", "target", "targettarget", "pet", "focus" }) do
        H.check("not on " .. scope, def and S.AppliesTo(def, scope), false)
    end
    H.check("label", ns.L.SETTING_groupRole, "Role (tank, healer, damage)")
    local keys
    for _, tab in ipairs(ns.Schema.Tabs("party")) do
        for _, sec in ipairs(tab.sections or {}) do
            if sec.id == "groupIcons" then keys = table.concat(sec.keys, ",") end
        end
    end
    H.checkTrue("in the group icons' section after the others",
        keys and keys:find("groupResurrect,groupRole,groupIconSize", 1, true))
    -- One art for both: the raid cells' role icons.
    H.check("the raid cells' art", ns.RaidRole.ATLAS, ns.GroupIcons.ROLE_ATLAS)
    H.check("healer art", ns.GroupIcons.ROLE_ATLAS.HEALER, "UI-LFG-RoleIcon-Healer-Micro-GroupFinder")
    -- Raid cells keep their own role icon.
    H.check("raid cells: never", ns.RaidCell.Resolve("groupRole"), false)
end

-- Live -------------------------------------------------------------------------
do
    local ns = boot()
    local C = ns.Config
    M.units.player.role = "TANK"
    M.units.party1 = { name = "Ann", health = 5, healthMax = 10, role = "HEALER" }
    M.units.party2 = { name = "Bob", health = 5, healthMax = 10, role = "NONE" }
    M.SetGroup({ "party1", "party2" })
    local p = ns.Frames.player.groupIcons
    local a, b = ns.Party.buttons[1].groupIcons, ns.Party.buttons[2].groupIcons
    H.check("off: no role on the player", p.role:IsShown(), false)
    H.check("off: no role on the party", a.role:IsShown(), false)

    C.Set("party", "groupRole", true)
    C.Set("player", "groupRole", true)
    H.checkTrue("healer shown", a.role:IsShown())
    H.check("healer art", a.role._atlas, "UI-LFG-RoleIcon-Healer-Micro-GroupFinder")
    H.check("player: tank", p.role._atlas, "UI-LFG-RoleIcon-Tank-Micro-GroupFinder")
    H.check("no role: none", b.role:IsShown(), false)
    -- A slot of its own: the row is four icons wide.
    local size = ns.Pixel.Snap(16, nil, 1)
    H.check("row of four", a.holder:GetWidth(), ns.Layout.IconRowWidth(4, size, ns.Pixel.Snap(2)))
    H.check("role sized like the others", a.role:GetWidth(), size)
    -- Alone in the row: packed to the anchor's side like the others.
    H.check("first slot when alone", point(a.role, "TOPLEFT")[4], 0)
    -- After the leader when both show.
    M.units.party1.leader = true
    M.FireEvent("PARTY_LEADER_CHANGED")
    H.check("after the leader", point(a.role, "TOPLEFT")[4], size + ns.Pixel.Snap(2))
    M.units.party1.leader = nil
    M.FireEvent("PARTY_LEADER_CHANGED")

    -- Roles change.
    M.units.party2.role = "DAMAGER"
    M.FireEvent("PLAYER_ROLES_ASSIGNED")
    H.checkTrue("damage shown", b.role:IsShown())
    H.check("damage art", b.role._atlas, "UI-LFG-RoleIcon-DPS-Micro-GroupFinder")

    -- Secret role: nothing, no error.
    M.units.party1.role = M.Secret("HEALER")
    local ok, err = pcall(M.FireEvent, "PLAYER_ROLES_ASSIGNED")
    H.check("secret: no error", ok and "ok" or tostring(err), "ok")
    H.check("secret: no icon", a.role:IsShown(), false)
    M.units.party1.role = "HEALER"
    M.FireEvent("GROUP_ROSTER_UPDATE")
    H.checkTrue("readable again", a.role:IsShown())

    -- Switched off: gone, the row three wide again.
    C.Set("party", "groupRole", false)
    H.check("off again", a.role:IsShown(), false)
    H.check("row of three", a.holder:GetWidth(), ns.Layout.IconRowWidth(3, size, ns.Pixel.Snap(2)))

    -- Test mode: the samples' roles.
    C.Set("party", "groupRole", true)
    ns.TestMode.Set(true)
    H.check("sample: the player tanks", p.role._atlas, "UI-LFG-RoleIcon-Tank-Micro-GroupFinder")
    H.checkTrue("sample: player shown", p.role:IsShown())
    local fake = ns.Party.fakes[1].groupIcons
    H.checkTrue("sample: member 1 shown", fake.role:IsShown())
    H.check("sample: member 1 heals", fake.role._atlas, "UI-LFG-RoleIcon-Healer-Micro-GroupFinder")
    ns.TestMode.Set(false)
    H.check("test mode off: the live role", p.role._atlas, "UI-LFG-RoleIcon-Tank-Micro-GroupFinder")
end

-- Raid cells: their own role icon only.
do
    local ns = boot()
    ns.Config.Set("party", "groupRole", true)
    M.SetRaidRoster({ { name = "Me", class = "WARRIOR", subgroup = 1, assignedRole = "TANK" },
        { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "HEALER" } })
    M.RunTimers()
    for _, cell in ipairs(ns.RaidCell.buttons) do
        if cell.groupIcons and cell.groupIcons.role then
            H.check("cell: no group role icon", cell.groupIcons.role:IsShown(), false)
        end
    end
end
