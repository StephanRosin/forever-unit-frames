local _, ns = ...

-- Test mode for the raid panel (Options/TestMode.lua fires TEST_MODE): a
-- pretend raid of the active size where the blocks are, laid out exactly
-- like the real ones (Raid/Layout.lua). The pretend cells are secure
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

local on = false

function Test.IsOn()
    return on and Header.Enabled()
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
-- health, status, role, debuffs } per member, in raid order.
function Test.Members(size)
    local list = {}
    for i = 1, size do
        local s = Test.SAMPLES[(i - 1) % #Test.SAMPLES + 1]
        local names = LOCALIZED_CLASS_NAMES_MALE
        list[i] = {
            subgroup = math.floor((i - 1) / Layout.GROUP_SIZE) + 1, class = s[1], assignedRole = s[2], role = s[2],
            name = type(names) == "table" and names[s[1]] or s[1],
            health = Test.HEALTH[(i - 1) % #Test.HEALTH + 1], status = Test.STATUS[i] or false,
            debuffs = Test.DEBUFFS[(i - 1) % #Test.SAMPLES + 1] or {},
        }
    end
    return list
end

-- Members into blocks, as the headers would sort them: by raid order or
-- by name, the single block by group first.
function Test.Distribute(blocks, members, size, byName)
    local lists = {}
    for b, block in ipairs(blocks) do
        local list = {}
        for i, m in ipairs(members) do
            if Layout.Matches(block, m, size) then list[#list + 1] = { index = i, member = m } end
        end
        table.sort(list, function(x, y)
            if block.kind == "NONE" and x.member.subgroup ~= y.member.subgroup then
                return x.member.subgroup < y.member.subgroup
            end
            if byName and x.member.name ~= y.member.name then return x.member.name < y.member.name end
            return x.index < y.index
        end)
        lists[b] = list
    end
    return lists
end

local function fakeButton(i)
    local button = Cell.fakes[i]
    if button then return button end
    button = CreateFrame("Button", "ForeverUnitFramesRaidTest" .. i, UIParent, "SecureUnitButtonTemplate")
    -- Shows samples only; never gets live aura containers.
    button.pretend = true
    Cell.Setup(button)
    button:SetAttribute("*type1", "target")
    button:SetAttribute("*type2", "togglemenu")
    button:RegisterForClicks("AnyUp")
    Cell.fakes[i] = button
    return button
end

-- Hidden and quiet, its sample gone: nothing reads a stale one later.
local function release(button)
    ns.Party.ReleaseFake(button)
    button.sample = nil
end

-- Out of combat (Raid/Header.lua's layout): the pretend raid in place of
-- the headers' cells.
function Test.Show()
    local size = Cell.Size()
    local byName = ns.RaidConfig.Get(ns.Raid.Scope(size), "sortBy") == "NAME"
    local lists = Test.Distribute(Header.blocks, Test.Members(size), size, byName)
    local counts = {}
    for b, list in ipairs(lists) do counts[b] = #list end
    local positions, s = Header.Place(counts)
    local hx, hy = Layout.HeaderOffset(s)
    local used = 0
    for b, list in ipairs(lists) do
        local pos = positions[b]
        for slot, entry in ipairs(list) do
            used = used + 1
            local button = fakeButton(used)
            button.sample = entry.member
            ns.Single.SetUnit(button, "player")
            local x, y = Layout.CellOffset(s, slot)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", Header.anchor, "TOPLEFT", pos.x + hx + x, pos.y + hy + y)
            Cell.Style(button)
            ns.Single.Preview(button, true)
            button:Show()
        end
    end
    for i = used + 1, #Cell.fakes do release(Cell.fakes[i]) end
end

-- Out of combat: every pretend cell hidden and quiet.
function Test.Hide()
    for _, button in ipairs(Cell.fakes) do
        if button.unit or button:IsShown() or button.sample then release(button) end
    end
end

ns.Listen("TEST_MODE", function(state)
    on = state and true or false
    if not Header.anchor then return end
    -- The panel is a plain frame: in combat it follows at once, the
    -- cells with the layout after combat.
    if InCombatLockdown() then Header.UpdateVisibility() end
    ns.AfterCombat("raidLayout", Header.Refresh)
end)
