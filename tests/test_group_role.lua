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
        keys and keys:find("groupPhase,groupRole,groupRolePortrait,groupIconSize", 1, true))
    -- One art for both: the raid cells' role icons.
    H.check("the raid cells' art", ns.RaidRole.TEXTURE, ns.GroupIcons.ROLE_TEXTURE)
    H.check("healer art", ns.GroupIcons.ROLE_TEXTURE.HEALER, "Interface\\AddOns\\ForeverUnitFrames\\Media\\IconRoleHealer.tga")
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
    H.check("healer art", a.role._texture, "Interface\\AddOns\\ForeverUnitFrames\\Media\\IconRoleHealer.tga")
    H.check("player: tank", p.role._texture, "Interface\\AddOns\\ForeverUnitFrames\\Media\\IconRoleTank.tga")
    H.check("no role: none", b.role:IsShown(), false)
    -- A slot of its own: the row is six icons wide.
    local size = ns.Pixel.Snap(16, nil, 1)
    H.check("row of six", a.holder:GetWidth(), ns.Layout.IconRowWidth(6, size, ns.Pixel.Snap(2)))
    H.check("role sized like the others", a.role:GetWidth(), size)
    -- Alone in the row: packed to the anchor's side like the others.
    H.check("second slot, the crown's kept free", point(a.role, "TOPLEFT")[4], size + ns.Pixel.Snap(2))
    -- A crown does not move the role: it stays at the anchor's end, the crown next to it.
    M.units.party1.leader = true
    M.FireEvent("PARTY_LEADER_CHANGED")
    H.check("role stays put beside the leader", point(a.role, "TOPLEFT")[4], size + ns.Pixel.Snap(2))
    H.check("crown first", point(a.leader, "TOPLEFT")[4], 0)
    M.units.party1.leader = nil
    M.FireEvent("PARTY_LEADER_CHANGED")

    -- Roles change.
    M.units.party2.role = "DAMAGER"
    M.FireEvent("PLAYER_ROLES_ASSIGNED")
    H.checkTrue("damage shown", b.role:IsShown())
    H.check("damage art", b.role._texture, "Interface\\AddOns\\ForeverUnitFrames\\Media\\IconRoleDamage.tga")

    -- Secret role: nothing, no error.
    M.units.party1.role = M.Secret("HEALER")
    local ok, err = pcall(M.FireEvent, "PLAYER_ROLES_ASSIGNED")
    H.check("secret: no error", ok and "ok" or tostring(err), "ok")
    H.check("secret: no icon", a.role:IsShown(), false)
    M.units.party1.role = "HEALER"
    M.FireEvent("GROUP_ROSTER_UPDATE")
    H.checkTrue("readable again", a.role:IsShown())

    -- Switched off: gone, the row five wide again.
    C.Set("party", "groupRole", false)
    H.check("off again", a.role:IsShown(), false)
    H.check("row of five", a.holder:GetWidth(), ns.Layout.IconRowWidth(5, size, ns.Pixel.Snap(2)))

    -- Test mode: the samples' roles.
    C.Set("party", "groupRole", true)
    ns.TestMode.Set(true)
    H.check("sample: the player tanks", p.role._texture, "Interface\\AddOns\\ForeverUnitFrames\\Media\\IconRoleTank.tga")
    H.checkTrue("sample: player shown", p.role:IsShown())
    local fake = ns.Party.fakes[1].groupIcons
    H.checkTrue("sample: member 1 shown", fake.role:IsShown())
    H.check("sample: member 1 heals", fake.role._texture, "Interface\\AddOns\\ForeverUnitFrames\\Media\\IconRoleHealer.tga")
    ns.TestMode.Set(false)
    H.check("test mode off: the live role", p.role._texture, "Interface\\AddOns\\ForeverUnitFrames\\Media\\IconRoleTank.tga")
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

-- On the portrait (groupRolePortrait): off by default; while a portrait
-- shows, the role leaves the row (no slot kept) for a corner of it,
-- clear of its centre; without a portrait it is back in the row.
do
    local ns = boot()
    local C, S = ns.Config, ns.Settings
    local def = S.Get("groupRolePortrait")
    H.check("portrait: code", def and def.code, "LQ")
    H.check("portrait: off by default", def and S.Default(def, "party"), false)
    H.check("portrait: not on target", def and S.AppliesTo(def, "target"), false)
    H.check("portrait: label", ns.L.SETTING_groupRolePortrait, "Role on the portrait")
    H.check("portrait: greyed while the role is off", ns.Options.ROW_ACTIVE.groupRolePortrait("party"), false)
    C.Set("party", "groupRole", true)
    H.checkTrue("portrait: active with the role", ns.Options.ROW_ACTIVE.groupRolePortrait("party"))

    M.units.party1 = { name = "Ann", health = 5, healthMax = 10, role = "HEALER" }
    M.SetGroup({ "party1" })
    local f = ns.Party.buttons[1]
    local a = f.groupIcons
    local size, gap = ns.Pixel.Snap(16, nil, 1), ns.Pixel.Snap(2)
    local inset = ns.Pixel.Snap(2)
    C.Set("party", "portraitMode", "LEFT")
    H.check("switch off: role still in the row", select(2, a.role:GetPoint(1)), a.holder)

    C.Set("party", "groupRolePortrait", true)
    H.check("left: row of five, no role slot", a.holder:GetWidth(), ns.Layout.IconRowWidth(5, size, gap))
    local p = point(a.role, "BOTTOMRIGHT")
    H.checkTrue("left: on the portrait's bottom right", p and p[2] == f.portraitBg and p[3] == "BOTTOMRIGHT")
    H.check("left: inset", p and p[4], -inset)
    H.checkTrue("left: shown", a.role:IsShown())
    H.check("left: icon size", a.role:GetWidth(), size)
    -- No empty crown slot kept for a role that is not in the row.
    M.units.party1.readyCheck = "ready"
    M.FireEvent("READY_CHECK")
    H.check("left: ready check first in the row", point(a.ready, "TOPLEFT")[4], 0)

    C.Set("party", "portraitMode", "RIGHT")
    p = point(a.role, "BOTTOMLEFT")
    H.checkTrue("right: on the portrait's bottom left", p and p[2] == f.portraitBg)

    C.Set("party", "portraitMode", "TOP")
    p = point(a.role, "LEFT")
    H.checkTrue("top: the strip's left end", p and p[2] == f.portraitBg and p[3] == "LEFT")
    H.check("top: vertically centred", p and p[5], 0)

    -- Only the role on: the row is empty, the holder still shows.
    for _, key in ipairs({ "groupLeader", "groupReadyCheck", "groupResurrect", "groupSummon", "groupPhase" }) do
        C.Set("party", key, false)
    end
    H.checkTrue("alone: holder shown", a.holder:IsShown())
    H.checkTrue("alone: role shown", a.role:IsShown())
    H.checkTrue("above the 3D model", a.holder:GetFrameLevel() > f.portrait3D:GetFrameLevel())
    C.Set("party", "groupLeader", true)
    C.Set("party", "groupReadyCheck", true)

    C.Set("party", "portraitMode", "OFF")
    H.check("no portrait: back in the row", select(2, a.role:GetPoint(1)), a.holder)
    H.check("no portrait: row with the role slot", a.holder:GetWidth(), ns.Layout.IconRowWidth(3, size, gap))
end
