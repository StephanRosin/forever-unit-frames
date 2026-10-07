local _, ns = ...

-- Test mode for the raid panels: a pretend raid where the blocks are,
-- laid out exactly like the real ones (Raid/Layout.lua), and in each
-- special panel that is switched on its own pretend members (main tanks,
-- main assists, your tanks and favourites, pets). On with the unit
-- frames' test mode (Options/TestMode.lua fires TEST_MODE) or with the
-- raid options window's own switch (Test.Set). While the raid window is
-- open it shows the size the window edits, at that size's position
-- (Test.Preview; Raid/Cell.lua asks Test.PreviewSize); otherwise the
-- active size. The pretend cells are secure
-- buttons on the player, so clicks target you, each with a sample of its
-- own (Elements/Health.lua: Health.Sample): a class (name and colour; the
-- name is Blizzard's class name), health, a role, and one dead, one
-- offline member. Made once, out of combat, and reused. Entering combat
-- ends test mode (Options/TestMode.lua); the cells go with the next
-- layout, after combat if it had already begun (the panel then hides at
-- once).
local Test = {}
ns.RaidTestMode = Test

local Cell, Layout, Header = ns.RaidCell, ns.RaidLayout, ns.RaidHeader

-- Ten members, repeated: five to a group, a tank and a healer in most.
Test.SAMPLES = {
    { "WARRIOR", "TANK" }, { "PRIEST", "HEALER" }, { "MAGE", "DAMAGER" }, { "ROGUE", "DAMAGER" },
    { "HUNTER", "DAMAGER" }, { "PALADIN", "HEALER" }, { "DRUID", "HEALER" }, { "WARLOCK", "DAMAGER" },
    { "SHAMAN", "HEALER" }, { "WARRIOR", "DAMAGER" },
}
Test.HEALTH = { 1, 0.85, 0.6, 0.35, 0.15, 0.95, 0.7, 0.5 }
-- Member 3 is dead, member 7 offline: both in every size.
Test.STATUS = { [3] = "DEAD", [7] = "OFFLINE" }
-- Debuffs by place in the ten (indices into Raid/CellAuras.lua's
-- samples): a magic one and a curse, a poison, a disease, one without a
-- type and magic again.
Test.DEBUFFS = { [2] = { 1, 2 }, [5] = { 3 }, [9] = { 4, 5, 1 } }
-- Out of range by place in the ten: the rogue.
Test.OUT_OF_RANGE = { [4] = true }
-- The first tank has aggro; member 2 is your target.
Test.AGGRO = { [1] = true }
Test.TARGET = 2
-- Raid target markers by raid index: a skull on the first tank, a star.
Test.MARKERS = { [1] = 8, [6] = 1 }
-- Group icons by raid index: you lead and loot, member 2 assists; a ready
-- check under way.
Test.GROUP_ICONS = {
    [1] = { leader = "leader", looter = true, ready = "ready" }, [2] = { leader = "assistant", ready = "ready" },
    [4] = { ready = "notready" }, [5] = { ready = "waiting" },
}

local on = false     -- the unit frames' test mode
local own = false    -- the raid window's switch
local preview        -- the size the raid window edits, while it is open

function Test.IsOn()
    return (on or own) and Header.Enabled()
end

-- The raid window's switch is on.
function Test.IsOwnOn()
    return own
end

-- The size test mode shows instead of the active one: the raid window's,
-- while test mode is on; else nil.
function Test.PreviewSize()
    if preview and Test.IsOn() then return preview end
    return nil
end

-- The panels follow a change of test mode: their plain frames at once in
-- combat, the cells with the next layout, after combat if it had already
-- begun.
local function relayout()
    if not Header.anchor then return end
    if InCombatLockdown() then
        for _, P in ipairs(ns.RaidPanel.list) do P.UpdateVisibility() end
    end
    ns.AfterCombat("raidLayout", ns.RaidPanel.RefreshAll)
end

-- The raid window's switch (RAID_TEST_MODE tells the window). Turning it
-- on is refused in combat; off always works.
function Test.Set(state)
    state = state and true or false
    if state and InCombatLockdown() then
        ns.Print(ns.L.TEST_MODE_COMBAT)
        return false
    end
    if state == own then return true end
    own = state
    relayout()
    ns.Fire("RAID_TEST_MODE", own)
    return true
end

-- The raid window opened on a size or switched to another (nil: closed).
function Test.Preview(size)
    if size == preview then return end
    preview = size
    if Test.IsOn() then relayout() end
end

-- The special panels' pretend members, by place in the raid: two main
-- tanks (the first tank and the last warrior), a main assist (the
-- paladin), your tanks (the warriors, the last one first), your
-- favourites (the priest and the druid). Every hunter and warlock has a
-- pet, named by the words below.
Test.PANELS = { mainTanks = { 1, 10 }, mainAssists = { 6 }, myTanks = { 10, 1 }, favourites = { 2, 7 } }
Test.PETS = { HUNTER = "RAID_TEST_PET_HUNTER", WARLOCK = "RAID_TEST_PET_WARLOCK" }

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
-- health, status, role, debuffs, marker, groupIcons, outOfRange, aggro,
-- target } per member, in raid order.
function Test.Members(size)
    local list = {}
    for i = 1, size do
        local s = Test.SAMPLES[(i - 1) % #Test.SAMPLES + 1]
        local names = LOCALIZED_CLASS_NAMES_MALE
        list[i] = {
            subgroup = math.floor((i - 1) / Layout.GROUP_SIZE) + 1, class = s[1], assignedRole = s[2], role = s[2],
            name = type(names) == "table" and names[s[1]] or s[1],
            health = Test.HEALTH[(i - 1) % #Test.HEALTH + 1], status = Test.STATUS[i] or false,
            debuffs = Test.DEBUFFS[(i - 1) % #Test.SAMPLES + 1] or {}, marker = Test.MARKERS[i],
            groupIcons = Test.GROUP_ICONS[i] or {},
            outOfRange = Test.OUT_OF_RANGE[(i - 1) % #Test.SAMPLES + 1] == true,
            aggro = Test.AGGRO[i] == true, target = i == Test.TARGET,
        }
    end
    return list
end

-- A special panel's pretend members, in its order; the pets: one per
-- hunter and warlock, in raid order, alive and well, coloured as their
-- owner; no role.
function Test.PanelMembers(id, size)
    local all, list = Test.Members(size), {}
    if id == "pets" then
        for _, m in ipairs(all) do
            local word = Test.PETS[m.class]
            if word then
                list[#list + 1] = { subgroup = m.subgroup, class = m.class, name = ns.L[word], health = m.health,
                    role = "NONE", assignedRole = "NONE",
                    status = false, debuffs = {}, groupIcons = {}, outOfRange = false, aggro = false, target = false }
            end
        end
        return list
    end
    for _, i in ipairs(Test.PANELS[id] or {}) do
        if all[i] then list[#list + 1] = all[i] end
    end
    return list
end

-- What a block's header groups its members by (its filter's groupBy),
-- as a rank: the group, or the place of the assigned role (a role not in
-- the order ranks with no role); 0 without.
local ROLE_RANK, rank = {}, 0
for role in Layout.ROLE_ORDER:gmatch("[^,]+") do
    rank = rank + 1
    ROLE_RANK[role] = rank
end
local function groupRank(block, member)
    local by = block.filter.groupBy
    if by == "GROUP" then return member.subgroup end
    if by == "ASSIGNEDROLE" then return ROLE_RANK[member.assignedRole or "NONE"] or ROLE_RANK.NONE end
    return 0
end

-- Members into blocks, as the headers would sort them (sortBy: the
-- setting): grouped as the block's header groups them, then by name or
-- raid order.
function Test.Distribute(blocks, members, size, sortBy)
    local lists = {}
    for b, block in ipairs(blocks) do
        local list = {}
        for i, m in ipairs(members) do
            if Layout.Matches(block, m, size) then list[#list + 1] = { index = i, member = m } end
        end
        table.sort(list, function(x, y)
            local rx, ry = groupRank(block, x.member), groupRank(block, y.member)
            if rx ~= ry then return rx < ry end
            if sortBy == "NAME" and x.member.name ~= y.member.name then return x.member.name < y.member.name end
            return x.index < y.index
        end)
        lists[b] = list
    end
    return lists
end

-- The pretend cells of a panel: the main panel's are Raid/Cell.lua's
-- fakes; a special panel's are its own (P.fakes), every one of them also
-- in Cell.panelFakes, so the elements reach them (Units/Units.lua).
local function pool(P)
    if P == Header then return Cell.fakes end
    P.fakes = P.fakes or {}
    return P.fakes
end

local function fakeButton(P, i)
    local list = pool(P)
    local button = list[i]
    if button then return button end
    local name = P == Header and "ForeverUnitFramesRaidTest" or (P.spec.name .. "Test")
    button = CreateFrame("Button", name .. i, UIParent, "SecureUnitButtonTemplate")
    -- Shows samples only; never gets live aura containers.
    button.pretend = true
    -- A pet's cell when the panel makes those.
    if P.cellKey ~= Cell.KEY then button.key = P.cellKey end
    Cell.Setup(button)
    button:SetAttribute("*type1", "target")
    button:SetAttribute("*type2", "togglemenu")
    button:RegisterForClicks("AnyUp")
    list[i] = button
    if P ~= Header then Cell.panelFakes[#Cell.panelFakes + 1] = button end
    return button
end

-- Hidden and quiet, its sample gone: nothing reads a stale one later.
local function release(button)
    ns.Party.ReleaseFake(button)
    button.sample = nil
end

-- Out of combat (Raid/Panel.lua's layout): the pretend raid in place of
-- a panel's headers' cells, the main panel's without one. A special
-- panel shows its own pretend members (Test.PanelMembers), in their
-- order, while it is switched on.
function Test.Show(P)
    P = P or Header
    local size = Cell.Size()
    local members, sortBy
    if P == Header then
        members, sortBy = Test.Members(size), ns.RaidConfig.Get(ns.Raid.Scope(size), "sortBy")
    else
        members = P.Enabled() and Test.PanelMembers(P.id, size) or {}
    end
    local lists = Test.Distribute(P.blocks, members, size, sortBy)
    local counts = {}
    for b, list in ipairs(lists) do counts[b] = #list end
    local positions, s = P.Place(counts)
    local hx, hy = Layout.HeaderOffset(s)
    local used = 0
    for b, list in ipairs(lists) do
        local pos = positions[b]
        for slot, entry in ipairs(list) do
            used = used + 1
            local button = fakeButton(P, used)
            button.sample = entry.member
            ns.Single.SetUnit(button, "player")
            local x, y = Layout.CellOffset(s, slot)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", P.anchor, "TOPLEFT", pos.x + hx + x, pos.y + hy + y)
            Cell.Style(button)
            ns.Single.Preview(button, true)
            button:Show()
        end
    end
    local list = pool(P)
    for i = used + 1, #list do release(list[i]) end
end

-- Out of combat: every pretend cell of a panel (the main one without)
-- hidden and quiet.
function Test.Hide(P)
    for _, button in ipairs(pool(P or Header)) do
        if button.unit or button:IsShown() or button.sample then release(button) end
    end
end

ns.Listen("TEST_MODE", function(state)
    on = state and true or false
    relayout()
end)

-- Entering combat ends the raid window's test mode, as the unit frames'
-- does its own.
ns.On("PLAYER_REGEN_DISABLED", function()
    if own then Test.Set(false) end
end)
