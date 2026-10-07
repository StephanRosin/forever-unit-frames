local _, ns = ...

-- The buff watch: which of your class's group buffs (Raid/BuffData.lua)
-- the members of your raid or party miss or have running out, read out
-- of combat only and at most every THROTTLE seconds after a change (an
-- aura, the roster, the bags, the spell book, a setting), and every
-- RESCAN seconds anyway (a buff runs out without an event). In combat the
-- last state stays. Every value read from the client is checked with
-- Secrets.IsSecret before it is compared or used; while the client keeps
-- auras secret (C_Secrets.ShouldAurasBeSecret, or a watched spell's aura
-- ShouldSpellAuraBeSecret) a buff is "unknown", never guessed.
--
-- The state (BuffWatch.state): entries, one per watched buff, each with
-- missing and expiring counts, unknown, and needs: who needs it, the
-- missing first, then the least time left; missingUnits: unit -> true
-- for every member missing a watched buff. After each scan
-- RAID_BUFFS_CHANGED fires (the watch window, the smart buff key, the
-- cells).
local BuffWatch = {}
ns.RaidBuffWatch = BuffWatch

local Data, Secrets = ns.RaidBuffData, ns.Secrets

BuffWatch.THROTTLE = 0.5
BuffWatch.RESCAN = 5
BuffWatch.state = { entries = {}, missingUnits = {} }
BuffWatch.scans = 0
-- The filter the buffs are looked up with.
BuffWatch.FILTER = "HELPFUL"

local function general(key) return ns.RaidConfig.Get("general", key) end

-- A plain value of a client call, or nil (secret, an error).
local function plain(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or Secrets.IsSecret(v) then return nil end
    return v
end

local function playerClass()
    local ok, _, token = pcall(UnitClass, "player")
    if ok and not Secrets.IsSecret(token) and type(token) == "string" then return token end
    return nil
end

-- What is watched ------------------------------------------------------------------

-- An entry: id, single and group form (Data.Form; group nil when there
-- is none), the reagents, who it is for, and how its group form groups:
-- by raid group (GROUP) or by class (CLASS, the blessings, for the
-- classes in entry.classes).
local function entryOf(id, spells, who)
    local single = Data.Form(spells.single)
    if not (single and single.id) then return nil end
    return { id = id, single = single, group = Data.Form(spells.group), reagents = spells.reagents, who = who,
        by = "GROUP" }
end

-- Your class's buffs that the spell book knows and that are switched on,
-- in the table's order; a paladin's: one per blessing chosen for some
-- class.
function BuffWatch.Watched()
    local list, class = {}, playerClass()
    if not class or not ns.RaidConfig.Profile() then return list end
    for _, buff in ipairs(Data.BUFFS) do
        if buff.class == class and general(buff.key) == true then
            list[#list + 1] = entryOf(buff.id, buff, buff.who)
        end
    end
    if class == "PALADIN" and general(Data.BLESSINGS_KEY) == true then
        for _, blessing in ipairs(Data.BLESSINGS) do
            local spells, classes = Data.BLESSING[blessing], {}
            local any = false
            for _, c in ipairs(Data.CLASSES) do
                if general("blessing" .. c) == blessing then classes[c], any = true, true end
            end
            local entry = spells and any and entryOf("blessing" .. blessing, spells, "CLASSES")
            if entry then
                entry.by, entry.classes = "CLASS", classes
                list[#list + 1] = entry
            end
        end
    end
    return list
end

-- The members -------------------------------------------------------------------------

local function token(v)
    if Secrets.IsSecret(v) or type(v) ~= "string" or v == "" then return nil end
    return v
end

local function isTank(unit, rosterRole)
    if rosterRole == "MAINTANK" then return true end
    if token(plain(UnitGroupRolesAssigned, unit)) == "TANK" then return true end
    return plain(GetPartyAssignment, "MAINTANK", unit) == true
end

-- The members: { unit, group (raid group; 1 in a party), class (token,
-- nil while unknown), tank }; empty when solo.
function BuffWatch.Members()
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local ok, _, _, subgroup, _, _, class, _, _, _, role = pcall(GetRaidRosterInfo, i)
            if ok and UnitExists(unit) then
                local group = not Secrets.IsSecret(subgroup) and type(subgroup) == "number" and subgroup or nil
                list[#list + 1] = { unit = unit, group = group, class = token(class),
                    tank = isTank(unit, token(role)) }
            end
        end
    elseif IsInGroup() then
        local units = { "player" }
        for i = 1, GetNumGroupMembers() - 1 do units[#units + 1] = "party" .. i end
        for _, unit in ipairs(units) do
            if UnitExists(unit) then
                local ok, _, class = pcall(UnitClass, unit)
                list[#list + 1] = { unit = unit, group = 1, class = ok and token(class) or nil,
                    tank = isTank(unit) }
            end
        end
    end
    return list
end

-- Whether a buff is for the member.
local function applies(entry, member)
    if entry.who == "MANA" then return member.class == nil or not Data.NO_MANA[member.class] end
    if entry.who == "TANK" then return member.tank end
    if entry.who == "CLASSES" then return member.class ~= nil and entry.classes[member.class] == true end
    return true
end

-- Dead (or a ghost) or offline: no buff for them now. Unknown: there.
local function absent(unit)
    return plain(UnitIsDeadOrGhost, unit) == true or plain(UnitIsConnected, unit) == false
end

-- Reading -------------------------------------------------------------------------------

local function aurasSecret()
    local secrets = C_Secrets
    if not (secrets and secrets.ShouldAurasBeSecret) then return false end
    return plain(secrets.ShouldAurasBeSecret) ~= false
end

-- Whether the client hides a form's auras (its first rank stands for all).
local function formSecret(spells)
    local secrets = C_Secrets
    if not (secrets and secrets.ShouldSpellAuraBeSecret) or #spells == 0 then return false end
    return plain(secrets.ShouldSpellAuraBeSecret, spells[1]) ~= false
end

local function spellsOf(entry)
    if entry.classes then return Data.BLESSING[entry.id:match("^blessing(%u+)$")] end
    for _, buff in ipairs(Data.BUFFS) do
        if buff.id == entry.id then return buff end
    end
end

-- One form on a unit: present, and the seconds left (math.huge without
-- an end, nil when unknown); error when the client refuses.
local function readForm(unit, form)
    if not form then return false end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, form.name, BuffWatch.FILTER)
    if not ok then error("refused", 0) end
    if aura == nil then return false end
    if Secrets.IsSecret(aura) or type(aura) ~= "table" then return true, nil end
    local expires = aura.expirationTime
    if Secrets.IsSecret(expires) or type(expires) ~= "number" then return true, nil end
    if expires == 0 then return true, math.huge end
    return true, expires - GetTime()
end

-- The longer of two times left (nil: unknown wins, it is there).
local function longer(a, b)
    if a == nil or b == nil then return nil end
    return math.max(a, b)
end

-- A watched buff on every member it is for.
local function scanEntry(entry, members, secret, threshold, missingUnits)
    local st = { entry = entry, missing = 0, expiring = 0, needs = {}, unknown = secret }
    if not secret then
        local spells = spellsOf(entry)
        st.unknown = formSecret(spells.single) or formSecret(spells.group)
    end
    if st.unknown then return st end
    local ok = pcall(function()
        for _, member in ipairs(members) do
            if applies(entry, member) and not absent(member.unit) then
                local hasSingle, leftSingle = readForm(member.unit, entry.single)
                local hasGroup, leftGroup = readForm(member.unit, entry.group)
                local left
                if hasSingle and hasGroup then left = longer(leftSingle, leftGroup)
                elseif hasSingle then left = leftSingle
                elseif hasGroup then left = leftGroup end
                if not (hasSingle or hasGroup) then
                    st.missing = st.missing + 1
                    st.needs[#st.needs + 1] = { unit = member.unit, member = member, left = -1 }
                elseif left ~= nil and left < threshold then
                    st.expiring = st.expiring + 1
                    st.needs[#st.needs + 1] = { unit = member.unit, member = member, left = left }
                end
            end
        end
    end)
    if not ok then
        return { entry = entry, missing = 0, expiring = 0, needs = {}, unknown = true }
    end
    table.sort(st.needs, function(a, b) return a.left < b.left end)
    for _, need in ipairs(st.needs) do
        if need.left < 0 then missingUnits[need.unit] = true end
    end
    return st
end

-- Out of combat: the state anew; in combat nothing (the last one stays).
function BuffWatch.Scan()
    if InCombatLockdown() then return end
    local members, secret = BuffWatch.Members(), aurasSecret()
    local threshold = (general("buffExpiring") or 5) * 60
    local state = { entries = {}, missingUnits = {} }
    for _, entry in ipairs(BuffWatch.Watched()) do
        state.entries[#state.entries + 1] = scanEntry(entry, members, secret, threshold, state.missingUnits)
    end
    BuffWatch.state = state
    BuffWatch.scans = BuffWatch.scans + 1
    BuffWatch.dirty, BuffWatch.since = false, 0
    ns.Fire("RAID_BUFFS_CHANGED")
end

-- Throttle ----------------------------------------------------------------------------

BuffWatch.dirty, BuffWatch.since = true, 0

-- Something changed: a scan on the next update after the throttle.
function BuffWatch.Mark() BuffWatch.dirty = true end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    BuffWatch.since = BuffWatch.since + elapsed
    if InCombatLockdown() or not ns.RaidConfig.Profile() then return end
    if (BuffWatch.dirty and BuffWatch.since >= BuffWatch.THROTTLE) or BuffWatch.since >= BuffWatch.RESCAN then
        BuffWatch.Scan()
    end
end)

-- The group's units: you, your party, the raid.
local function groupUnit(unit)
    return type(unit) == "string" and (unit == "player" or unit:match("^party%d$") ~= nil
        or unit:match("^raid%d+$") ~= nil)
end

ns.On("UNIT_AURA", function(_, unit)
    if groupUnit(unit) then BuffWatch.Mark() end
end)
ns.On("GROUP_ROSTER_UPDATE", BuffWatch.Mark)
ns.On("BAG_UPDATE_DELAYED", BuffWatch.Mark)
ns.On("SPELLS_CHANGED", BuffWatch.Mark)
ns.On("PLAYER_REGEN_ENABLED", BuffWatch.Mark)

-- The buff watch's settings: no panel of the raid frames follows them.
BuffWatch.KEYS = { buffExpiring = true, buffGroupMin = true, buffKey = true, buffWatchShow = true,
    buffWatchOnlyMissing = true, buffWatchX = true, buffWatchY = true, buffCellIcon = true,
    buffCellIconPoint = true, [Data.BLESSINGS_KEY] = true }
for _, buff in ipairs(Data.BUFFS) do BuffWatch.KEYS[buff.key] = true end
for _, c in ipairs(Data.CLASSES) do BuffWatch.KEYS["blessing" .. c] = true end
for key in pairs(BuffWatch.KEYS) do ns.RaidPanel.UNRELATED_KEYS[key] = true end

ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if scope == nil or key == nil or BuffWatch.KEYS[key] then BuffWatch.Mark() end
end)
