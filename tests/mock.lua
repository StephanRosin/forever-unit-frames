-- Minimal WoW API mock for offline tests. Lua 5.1 like the client.
local M = {}
-- Mask textures one texture can carry in the client.
M.MAX_MASKS = 3
M.widgets = {}

-- Secret values ------------------------------------------------------------
-- Real secret values refuse arithmetic, comparison, concatenation and
-- tostring. The proxy below does the same, so any forbidden use fails in a
-- test instead of in combat. Equality against a number cannot be trapped in
-- Lua 5.1 (it is simply false), so code must not rely on it either way.
local secretMeta = {}
local function refuse() error("secret value used in Lua arithmetic/comparison", 2) end
for _, mm in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow",
                      "__unm", "__lt", "__le", "__concat", "__len", "__call" }) do
    secretMeta[mm] = refuse
end
secretMeta.__tostring = refuse
-- Comparing two secrets throws in the client too (a secret and a plain
-- value compare without metamethod in Lua 5.1 and are simply unequal).
secretMeta.__eq = refuse
secretMeta.__index = function() refuse() end

function M.Secret(v)
    return setmetatable({ __secret = v }, secretMeta)
end
function M.IsSecret(v)
    return type(v) == "table" and getmetatable(v) == secretMeta
end
function M.Reveal(v)
    if M.IsSecret(v) then return rawget(v, "__secret") end
    return v
end

-- Widgets ------------------------------------------------------------------
local widget = {}
widget.__index = function(t, k)
    -- Unknown CamelCase keys are widget methods that do nothing; anything
    -- else is addon data and must be nil, as in the game. Strict objects
    -- (Blizzard aura containers and their buttons) have only the methods
    -- the mock gives them. Under an aura button, even a no-op method
    -- refuses while auras are secret.
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    if rawget(t, "_strict") then error("mock: " .. tostring(rawget(t, "_kind")) .. " has no method " .. k, 2) end
    local f = function(self)
        if M.AurasSecret() and M.IsAuraRestricted(self) then error("aura button: tainted access while auras are secret", 2) end
    end
    rawset(t, k, f)
    return f
end

-- XML templates of the addon, mirrored in Lua (the tests cannot load XML).
-- test_party.lua checks that Units/Party.xml declares the same.
M.templates = {
    ForeverUnitFramesPartyButtonTemplate = function(w)
        w._w, w._h = 160, 46
        w._clicks = { "AnyUp" }
        w._attr["*type1"] = "target"
        w._attr["*type2"] = "togglemenu"
        -- The target child: loaded (OnLoad) before its parent, as in XML.
        local t = M.newWidget("Button", nil, w)
        t._template = "SecureUnitButtonTemplate"
        t._protected = true
        t._w, t._h = 100, 24
        t._clicks = { "AnyUp" }
        t._shown = false
        t._attr["useparent-unit"] = true
        t._attr["unitsuffix"] = "target"
        t._attr["*type1"] = "target"
        t._attr["*type2"] = "togglemenu"
        w.targetButton = t
        ForeverUnitFrames.PartyTargetOnLoad(t)
        -- The pet child (layout BESIDE), likewise.
        local pb = M.newWidget("Button", nil, w)
        pb._template = "SecureUnitButtonTemplate"
        pb._protected = true
        pb._w, pb._h = 160, 20
        pb._clicks = { "AnyUp" }
        pb._shown = false
        pb._attr["useparent-unit"] = true
        pb._attr["unitsuffix"] = "pet"
        pb._attr["*type1"] = "target"
        pb._attr["*type2"] = "togglemenu"
        w.petButton = pb
        ForeverUnitFrames.PartyPetBesideOnLoad(pb)
        w._scripts.OnAttributeChanged = function(self, name, value)
            ForeverUnitFrames.PartyButtonOnAttributeChanged(self, name, value)
        end
        ForeverUnitFrames.PartyButtonOnLoad(w)
    end,
    -- Raid/Cell.xml
    ForeverUnitFramesRaidButtonTemplate = function(w)
        w._w, w._h = 80, 38
        w._clicks = { "AnyUp" }
        w._attr["*type1"] = "target"
        w._attr["*type2"] = "togglemenu"
        w._scripts.OnAttributeChanged = function(self, name, value)
            ForeverUnitFrames.RaidButtonOnAttributeChanged(self, name, value)
        end
        ForeverUnitFrames.RaidButtonOnLoad(w)
    end,
    -- Units/PartyPets.xml
    ForeverUnitFramesPartyPetButtonTemplate = function(w)
        w._w, w._h = 160, 20
        w._clicks = { "AnyUp" }
        w._attr["*type1"] = "target"
        w._attr["*type2"] = "togglemenu"
        w._scripts.OnAttributeChanged = function(self, name, value)
            ForeverUnitFrames.PartyPetButtonOnAttributeChanged(self, name, value)
        end
        ForeverUnitFrames.PartyPetButtonOnLoad(w)
    end,
}

-- SecureGroupHeaderTemplate and SecureGroupPetHeaderTemplate
-- (Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua), ported
-- from the client source: which units a header shows (GetGroupHeaderType:
-- a raid with showRaid, a party with showParty, else showSolo; showPlayer),
-- the filters groupFilter, roleFilter and strictFiltering, or a nameList
-- (only without either filter), groupBy with groupingOrder, sortMethod
-- INDEX, NAME or NAMELIST, sortDir, startingIndex, the columns
-- (unitsPerColumn, maxColumns, columnSpacing, columnAnchorPoint), child
-- creation from the template attribute, unit assignment through
-- SetAttribute("unit"), the header's own size, and updates on show,
-- attribute change and roster change while visible. Party members are
-- M.group's tokens in order; raid members M.raid (M.SetRaidRoster), read
-- through GetRaidRosterInfo as the client does; a party member's name is
-- UnitName's two values joined by "-" when the second is not empty. The
-- pet header (SecureGroupPetHeader_Update) lists the pets that exist of
-- the members its groupFilter or nameList picks (no roleFilter; strict:
-- group and class), groupBy GROUP, CLASS or ROLE, sortMethod NAME; with
-- useOwnerUnit the owner's unit, with filterOnPet the pet's name.
-- Stricter than the client: an initialConfigFunction or refreshUnitChange
-- snippet raises (snippets do not run on this client).
-- Like the client, shown buttons are only SetPoint'ed (never cleared): a
-- button keeps an anchor from an earlier layout on another point. Only
-- unused buttons lose their anchors. The header sizes itself from child1
-- as it is at layout time.
local function relativePoint(point)
    point = point:upper()
    if point == "TOP" then return "BOTTOM", 0, -1 end
    if point == "BOTTOM" then return "TOP", 0, 1 end
    if point == "LEFT" then return "RIGHT", 1, 0 end
    if point == "RIGHT" then return "LEFT", -1, 0 end
    if point == "TOPLEFT" then return "BOTTOMRIGHT", 1, -1 end
    if point == "TOPRIGHT" then return "BOTTOMLEFT", -1, -1 end
    if point == "BOTTOMLEFT" then return "TOPRIGHT", 1, 1 end
    if point == "BOTTOMRIGHT" then return "TOPLEFT", -1, 1 end
    return "CENTER", 0, 0
end

local function headerKind(a)
    if IsInRaid() and a.showRaid then return "RAID", 1, GetNumGroupMembers() end
    if IsInGroup() and a.showParty then return "PARTY", a.showPlayer and 1 or 2, #M.group + 1 end
    if a.showSolo then return "SOLO", 1, #M.group + 1 end
end

-- unit, name, subgroup, class token, role (MAINTANK, MAINASSIST), assigned
-- role, as GetGroupRosterInfo. Party slot 1 is the player (the client's
-- index 0), slot n + 1 is M.group[n].
local function rosterInfo(kind, slot)
    if kind == "RAID" then
        local name, _, subgroup, _, _, className, _, _, _, role, _, assignedRole = GetRaidRosterInfo(slot)
        return "raid" .. slot, name, subgroup, className, role, assignedRole
    end
    local unit = slot > 1 and M.group[slot - 1] or "player"
    local name, className, role, assignedRole
    -- The player always exists in the client, also in a test that gave
    -- it no unit data.
    if unit == "player" and not UnitExists(unit) then return unit, "player", 1, nil, nil, "NONE" end
    if UnitExists(unit) then
        local server
        name, server = UnitName(unit)
        if server and server ~= "" then name = name .. "-" .. server end
        className = select(2, UnitClass(unit))
        if GetPartyAssignment("MAINTANK", unit) then
            role = "MAINTANK"
        elseif GetPartyAssignment("MAINASSIST", unit) then
            role = "MAINASSIST"
        end
        assignedRole = UnitGroupRolesAssigned(unit)
    end
    return unit, name, 1, className, role, assignedRole
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function split(s)
    local parts = {}
    for part in (s .. ","):gmatch("([^,]*),") do parts[#parts + 1] = part end
    return parts
end
-- fillTable: each key (a number when it reads as one) -> its position.
local function fill(t, keys)
    for i, key in ipairs(keys) do t[tonumber(key) or trim(tostring(key))] = i end
    return t
end
-- doubleFillTable: fill, then each key (trimmed, a string) at its
-- position in the array part.
local function doubleFill(t, keys)
    fill(t, keys)
    for i, key in ipairs(keys) do t[i] = trim(key) end
    return t
end

-- The client's IDs: the number in the token ("player" is -1).
local function unitId(unit) return tonumber(unit:match("%d+") or -1) end

-- The groupBy sort (sortOnGroupWithNames / sortOnGroupWithIDs): by the
-- rank of each unit's grouping, unranked ones last, then by name or ID.
local function sortByGroup(units, grouping, rank, within)
    table.sort(units, function(x, y)
        local o1, o2 = rank[grouping[x]], rank[grouping[y]]
        if o1 then
            if not o2 then return true end
            if o1 == o2 then return within(x, y) end
            return o1 < o2
        end
        if o2 then return false end
        return within(x, y)
    end)
end

-- SecureGroupHeader_Update's choice and order of units.
local function groupUnits(a, kind, start, stop)
    local units, names, grouping = {}, {}, {}
    local nameList, groupFilter, roleFilter = a.nameList, a.groupFilter, a.roleFilter
    local function byName(x, y) return names[x] < names[y] end
    if not groupFilter and not roleFilter and not nameList then groupFilter = "1,2,3,4,5,6,7,8" end
    if groupFilter or roleFilter then
        local strict = a.strictFiltering
        local tokens = {}
        if groupFilter and not roleFilter then
            fill(tokens, split(groupFilter))
            if strict then fill(tokens, { "MAINTANK", "MAINASSIST", "TANK", "HEALER", "DAMAGER", "NONE" }) end
        elseif roleFilter and not groupFilter then
            fill(tokens, split(roleFilter))
            if strict then
                local keys = { 1, 2, 3, 4, 5, 6, 7, 8 }
                for _, class in ipairs(CLASS_SORT_ORDER) do keys[#keys + 1] = class end
                fill(tokens, keys)
            end
        else
            fill(tokens, split(groupFilter))
            fill(tokens, split(roleFilter))
        end
        for slot = start, stop do
            local unit, name, subgroup, className, role, assignedRole = rosterInfo(kind, slot)
            -- As the client writes it: (name and loose) or strict.
            if (name and (not strict and (tokens[subgroup] or tokens[className] or (role and tokens[role])
                    or tokens[assignedRole])))
                or (tokens[subgroup] and tokens[className] and ((role and tokens[role]) or tokens[assignedRole])) then
                units[#units + 1] = unit
                names[unit] = name
                if a.groupBy == "GROUP" then grouping[unit] = subgroup
                elseif a.groupBy == "CLASS" then grouping[unit] = className
                elseif a.groupBy == "ROLE" then grouping[unit] = role
                elseif a.groupBy == "ASSIGNEDROLE" then grouping[unit] = assignedRole end
            end
        end
        if a.groupBy then
            -- As the client: groupingOrder is required (nil raises), and the
            -- order is built with doubleFillTable, which then also stores each
            -- key as a string in the array part. Numeric group keys collide
            -- with those: "3,1,2" sorts groups 2,3,1, and "3,1" compares a
            -- number with a string and raises.
            local rank = doubleFill({}, split(a.groupingOrder:gsub("%s+", "")))
            local within = function(x, y) return unitId(x) < unitId(y) end
            if a.sortMethod == "NAME" then within = byName end
            sortByGroup(units, grouping, rank, within)
        elseif a.sortMethod == "NAME" then
            table.sort(units, byName)
        end
    else
        -- A list of names; NAMELIST sorts in the list's order.
        local rank = doubleFill({}, split(nameList))
        for slot = start, stop do
            local unit, name = rosterInfo(kind, slot)
            if rank[name] then
                units[#units + 1] = unit
                names[unit] = name
            end
        end
        if a.sortMethod == "NAME" then
            table.sort(units, byName)
        elseif a.sortMethod == "NAMELIST" then
            table.sort(units, function(x, y) return rank[names[x]] < rank[names[y]] end)
        end
    end
    return units
end

-- GetPetUnit: a raid member's pet, a party member's, your own.
local function petUnit(kind, slot)
    if kind == "RAID" then return "raidpet" .. slot end
    if slot > 1 then return "partypet" .. (slot - 1) end
    return "pet"
end

-- SecureGroupPetHeader_Update's choice and order of units.
local function petUnits(a, kind, start, stop)
    local units, names, grouping = {}, {}, {}
    local nameList, groupFilter = a.nameList, a.groupFilter
    local function byName(x, y) return names[x] < names[y] end
    if not groupFilter and not nameList then groupFilter = "1,2,3,4,5,6,7,8" end
    if groupFilter then
        local tokens = fill({}, split(groupFilter))
        local strict = a.strictFiltering
        for slot = start, stop do
            local unit, name, subgroup, className, role = rosterInfo(kind, slot)
            local pet = petUnit(kind, slot)
            if a.filterOnPet then name = UnitName(pet) end
            if not a.useOwnerUnit then unit = pet end
            if UnitExists(pet) then
                if (name and (not strict and (tokens[subgroup] or tokens[className] or (role and tokens[role]))))
                    or (tokens[subgroup] and tokens[className]) then
                    units[#units + 1] = unit
                    names[unit] = name
                    if a.groupBy == "GROUP" then grouping[unit] = subgroup
                    elseif a.groupBy == "CLASS" then grouping[unit] = className
                    elseif a.groupBy == "ROLE" then grouping[unit] = role end
                end
            end
        end
        if a.groupBy then
            -- No whitespace removed here, unlike the member header.
            local rank = doubleFill({}, split(a.groupingOrder))
            local within = function(x, y) return unitId(x) < unitId(y) end
            if a.sortMethod == "NAME" then within = byName end
            sortByGroup(units, grouping, rank, within)
        elseif a.sortMethod == "NAME" then
            table.sort(units, byName)
        end
    else
        local rank = doubleFill({}, split(nameList))
        for slot = start, stop do
            local unit, name = rosterInfo(kind, slot)
            local pet = petUnit(kind, slot)
            if a.filterOnPet then name = UnitName(pet) end
            if not a.useOwnerUnit then unit = pet end
            if rank[name] and UnitExists(pet) then
                units[#units + 1] = unit
                names[unit] = name
            end
        end
        if a.sortMethod == "NAME" then table.sort(units, byName) end
    end
    return units
end

local function sortedUnits(header)
    local a = header._attr
    local kind, start, stop = headerKind(a)
    if not kind then return {} end
    if header._pets then return petUnits(a, kind, start, stop) end
    return groupUnits(a, kind, start, stop)
end

-- configureChildren.
local function groupHeaderLayout(header)
    local a = header._attr
    assert(not a.initialConfigFunction, "mock: secure snippets do not run on this client")
    local units = sortedUnits(header)
    local point = a.point or "TOP"
    local relPoint, xMult, yMult = relativePoint(point)
    local xMultiplier, yMultiplier = math.abs(xMult), math.abs(yMult)
    local xOffset, yOffset = a.xOffset or 0, a.yOffset or 0
    local columnSpacing = a.columnSpacing or 0
    local startingIndex = a.startingIndex or 1
    local unitCount = #units
    local numDisplayed = unitCount - (startingIndex - 1)
    local unitsPerColumn = a.unitsPerColumn
    local numColumns
    if unitsPerColumn and numDisplayed > unitsPerColumn then
        numColumns = math.min(math.ceil(numDisplayed / unitsPerColumn), a.maxColumns or 1)
    else
        unitsPerColumn = numDisplayed
        numColumns = 1
    end
    local loopStart, step = startingIndex, 1
    local loopFinish = math.min((startingIndex - 1) + unitsPerColumn * numColumns, unitCount)
    numDisplayed = loopFinish - (loopStart - 1)
    if a.sortDir == "DESC" then
        loopStart = unitCount - (startingIndex - 1)
        loopFinish = loopStart - (numDisplayed - 1)
        step = -1
    end
    for i = 1, math.max(1, numDisplayed) do
        if not a["child" .. i] then
            local child = CreateFrame(a.templateType or "Button", header:GetName() .. "UnitButton" .. i, header, a.template)
            header[i] = child
            if a.auraContainerTemplate then
                child.AuraContainer = CreateFrame("AuraContainer", nil, child, a.auraContainerTemplate)
            end
            a["child" .. i] = child
        end
    end
    local columnAnchorPoint, columnRelPoint, colxMulti, colyMulti
    if numColumns > 1 then
        columnAnchorPoint = a.columnAnchorPoint
        columnRelPoint, colxMulti, colyMulti = relativePoint(columnAnchorPoint)
    end
    local buttonNum, columnUnitCount, currentAnchor = 0, 0, header
    for i = loopStart, loopFinish, step do
        buttonNum = buttonNum + 1
        columnUnitCount = columnUnitCount + 1
        if columnUnitCount > unitsPerColumn then columnUnitCount = 1 end
        local child = a["child" .. buttonNum]
        if buttonNum == 1 then
            child:SetPoint(point, currentAnchor, point, 0, 0)
            if columnAnchorPoint then child:SetPoint(columnAnchorPoint, currentAnchor, columnAnchorPoint, 0, 0) end
        elseif columnUnitCount == 1 then
            local columnAnchor = a["child" .. (buttonNum - unitsPerColumn)]
            child:SetPoint(columnAnchorPoint, columnAnchor, columnRelPoint, colxMulti * columnSpacing, colyMulti * columnSpacing)
        else
            child:SetPoint(point, currentAnchor, relPoint, xMultiplier * xOffset, yMultiplier * yOffset)
        end
        child:SetAttribute("unit", units[i])
        assert(not child._attr.refreshUnitChange, "mock: secure snippets do not run on this client")
        if not child._attr.statehidden then child:Show() end
        currentAnchor = child
    end
    local i = buttonNum + 1
    while a["child" .. i] do
        local child = a["child" .. i]
        child:Hide()
        child:ClearAllPoints()
        child:SetAttribute("unit", nil)
        i = i + 1
    end
    local bw, bh = a.child1:GetWidth(), a.child1:GetHeight()
    if numDisplayed > 0 then
        local width = xMultiplier * (unitsPerColumn - 1) * bw + ((unitsPerColumn - 1) * (xOffset * xMult)) + bw
        local height = yMultiplier * (unitsPerColumn - 1) * bh + ((unitsPerColumn - 1) * (yOffset * yMult)) + bh
        if numColumns > 1 then
            width = width + ((numColumns - 1) * math.abs(colxMulti) * (width + columnSpacing))
            height = height + ((numColumns - 1) * math.abs(colyMulti) * (height + columnSpacing))
        end
        header:SetWidth(width)
        header:SetHeight(height)
    else
        header:SetWidth(math.max(a.minWidth or (yMultiplier * bw), 0.1))
        header:SetHeight(math.max(a.minHeight or (xMultiplier * bh), 0.1))
    end
    M.headerUpdates = M.headerUpdates + 1
end

-- The header's own (secure) code may move its protected children in
-- combat.
local function groupHeaderUpdate(header)
    M.secureDepth = M.secureDepth + 1
    local ok, err = pcall(groupHeaderLayout, header)
    M.secureDepth = M.secureDepth - 1
    if not ok then error(err, 0) end
end

local function makeGroupHeader(w, pets)
    w._shown = false   -- the template is hidden="true"
    w._pets = pets
    w:RegisterEvent("GROUP_ROSTER_UPDATE")
    w:RegisterEvent("UNIT_NAME_UPDATE")
    if pets then w:RegisterEvent("UNIT_PET") end
    w._scripts.OnEvent = function(self) if self:IsVisible() then groupHeaderUpdate(self) end end
    w._scripts.OnShow = groupHeaderUpdate
    w._scripts.OnAttributeChanged = function(self, name)
        if name == "_ignore" or self._attr._ignore then return end
        if self:IsVisible() then groupHeaderUpdate(self) end
    end
end

-- Blizzard_AuraContainer's CustomAuraContainerTemplate: the inbound calls
-- an addon can make (Blizzard_AuraContainer.lua, Blizzard_CustomAuraContainer.lua,
-- Blizzard_AuraContainerFlowLayout.lua, Blizzard_CustomAuraButton.lua,
-- Blizzard_AuraButton.lua), with the source's argument checks. It shows no
-- auras: it records what it is told, and tests read the records
-- (_unit, _updates, _groups[key], _flow). Stricter than the client where
-- the client would silently accept a mistake: unknown option keys and
-- unknown methods raise.
-- Buttons: AddAuraGroup makes one batch (FrameCreationBatchSize) with
-- CustomAuraButtonTemplate and hands each to initializeFrame; after that
-- a button and everything under it refuse tainted access while auras are
-- secret (DenyTaintedAccessWhenAurasAreSecret; in the mock: in combat, or
-- while M.aurasSecret is set, as in an instance out of combat).
-- Once it has a group, only frames with the UntrustedLayoutScriptExecution
-- aspect may anchor to the container.
-- Aura slots (AddAuraSlot, Blizzard_AuraContainerSlots.lua) hold one frame
-- each, made at once and handed to initializeFrame like a group's; they
-- take no part in the layout (anchored by the addon) and record what they
-- are told in _slots[key].
M.AURA_BATCH = 10
local AURA_FILTERS = { HELPFUL = true, HARMFUL = true, PLAYER = true, RAID = true, CANCELABLE = true,
    INCLUDE_NAME_PLATE_ONLY = true, MAW = true, EXTERNAL_DEFENSIVE = true, CROWD_CONTROL = true,
    RAID_IN_COMBAT = true, RAID_PLAYER_DISPELLABLE = true, BIG_DEFENSIVE = true, IMPORTANT = true,
    DISPELLABLE = true }
local LAYOUT_KEYS = { elementSpacing = "number", lineSpacing = "number", groupSpacing = "number",
    groupLineSpacing = "number", forceNewLine = "boolean", elementWidth = "size", elementHeight = "size",
    layoutIndex = "number" }
local LAYOUT_DEFAULTS = { elementSpacing = 0, lineSpacing = 0, groupSpacing = 0, groupLineSpacing = 0,
    forceNewLine = false }
local GROUP_KEYS = { maxFrameCount = true, templateNames = true, initializeFrame = true, candidateFilters = true,
    sortMethod = true, sortDirection = true, layout = true }
local SLOT_KEYS = { templateNames = true, initializeFrame = true, candidateFilters = true, sortMethod = true,
    sortDirection = true }
local TOOLTIP_ANCHORS = { ANCHOR_LEFT = true, ANCHOR_RIGHT = true, ANCHOR_BOTTOMLEFT = true, ANCHOR_BOTTOM = true,
    ANCHOR_BOTTOMRIGHT = true, ANCHOR_TOPLEFT = true, ANCHOR_TOP = true, ANCHOR_TOPRIGHT = true,
    ANCHOR_CURSOR = true, ANCHOR_NONE = true, ANCHOR_PRESERVE = true, ANCHOR_CURSOR_LEFT = true,
    ANCHOR_CURSOR_RIGHT = true }
local DISPEL_TEXTURE_KEYS = { showAlways = true, showWhenHarmful = true, showWhenHelpful = true,
    showWithoutDispelType = true, stealableFilter = true, style = true, customDispelAssetMap = true,
    customDispelColorMap = true, customDispelColorCurve = true }

local function validFilter(filter)
    if type(filter) ~= "string" then return false end
    for part in filter:gmatch("[^| ]+") do
        local negated = part:sub(1, 1) == "!"
        if negated then part = part:sub(2) end
        if part == "" or not AURA_FILTERS[part] then return false end
    end
    return true
end

local function isEnumValue(enum, v)
    for _, value in pairs(enum) do
        if value == v then return true end
    end
    return false
end

local function copyLayout(layout)
    assert(layout == nil or type(layout) == "table", "layout must be a table or nil.")
    local out = {}
    for k, v in pairs(LAYOUT_DEFAULTS) do out[k] = v end
    for k, v in pairs(layout or {}) do
        local kind = LAYOUT_KEYS[k]
        assert(kind, "mock: unknown layout key " .. tostring(k))
        if kind == "size" then
            assert(type(v) == "number" and v >= 0, k .. " must be a non-negative number.")
        else
            assert(type(v) == kind, k .. " must be a " .. kind .. ".")
        end
        out[k] = v
    end
    return out
end

-- candidateFilters (Blizzard_CustomAuraContainer.lua ValidateCandidateFilters):
-- a table or nil; maxDuration a non-negative number (hides permanent
-- auras). includeSpellIDs / excludeSpellIDs are maps, spell ID -> true:
-- the container looks up includeSpellIDs[aura.spellId]. A list would hold
-- the IDs as values and match nothing.
local function checkCandidateFilters(filters)
    assert(filters == nil or type(filters) == "table", "candidateFilters must be a table or nil.")
    for _, field in ipairs({ "includeSpellIDs", "excludeSpellIDs" }) do
        local ids = filters and filters[field]
        if ids ~= nil then
            assert(type(ids) == "table", field .. " must be a table or nil")
            for k, v in pairs(ids) do
                assert(type(k) == "number" and k > 0 and k == math.floor(k) and v == true,
                    field .. " must map spell IDs to true, not list them")
            end
        end
    end
    if filters and filters.maxDuration ~= nil then
        assert(type(filters.maxDuration) == "number" and filters.maxDuration >= 0,
            "maxDuration must be a non-negative number or nil.")
    end
end

-- The client stores a securecopy of the filters: later edits of the
-- caller's table have no effect. nil stays nil here (the client merges it
-- into an empty table, which filters nothing either).
local function copyCandidateFilters(filters)
    checkCandidateFilters(filters)
    local function deep(t)
        if type(t) ~= "table" then return t end
        local out = {}
        for k, v in pairs(t) do out[k] = deep(v) end
        return out
    end
    return deep(filters)
end

-- In an options table nil is allowed (the client merges the defaults in
-- first); the setters validate their raw arguments, where nil is not.
local function checkSort(options)
    assert(options.sortMethod == nil or isEnumValue(AuraContainerSortMethod, options.sortMethod),
        "sortMethod must be a valid AuraContainerSortMethod.")
    assert(options.sortDirection == nil or isEnumValue(AuraContainerSortDirection, options.sortDirection),
        "sortDirection must be a valid AuraContainerSortDirection.")
end

local function checkSortArguments(method, direction)
    assert(isEnumValue(AuraContainerSortMethod, method), "sortMethod must be a valid AuraContainerSortMethod.")
    assert(isEnumValue(AuraContainerSortDirection, direction),
        "sortDirection must be a valid AuraContainerSortDirection.")
end

-- ValidateTemplateNames: a table of strings, or nil.
local function checkTemplateNames(templateNames)
    if templateNames == nil then return end
    assert(type(templateNames) == "table", "templateNames must be a table or nil.")
    for _, name in ipairs(templateNames) do
        assert(type(name) == "string", "templateNames must contain only strings.")
    end
end

local function validMax(n)
    return n == math.huge or (type(n) == "number" and n >= 0 and n == math.floor(n))
end

local function restricted(obj)
    while type(obj) == "table" do
        if rawget(obj, "_auraRestricted") then return true end
        obj = rawget(obj, "_parent")
    end
    return false
end
M.IsAuraRestricted = restricted

function M.AurasSecret() return M.combat or M.aurasSecret end

function M.HasLayoutAspect(obj)
    while type(obj) == "table" do
        if rawget(obj, "_layoutForbidden") then return true end
        obj = rawget(obj, "_parent")
    end
    return false
end

-- Every method of obj and its descendants refuses while auras are secret.
local function guardTree(obj)
    for k, v in pairs(obj) do
        if type(k) == "string" and k:match("^%u") and type(v) == "function" then
            obj[k] = function(...)
                if M.AurasSecret() and restricted(obj) then
                    error("aura button: tainted access while auras are secret", 2)
                end
                return v(...)
            end
        end
    end
    for _, child in ipairs(rawget(obj, "_children") or {}) do guardTree(child) end
end

local function isDescendant(obj, owner)
    local p = type(obj) == "table" and rawget(obj, "_parent")
    while type(p) == "table" do
        if p == owner then return true end
        p = rawget(p, "_parent")
    end
    return false
end

-- AuraContainerUtil.ValidateInboundScriptObject: the right object type,
-- below the button.
local function inbound(button, obj, kind)
    assert(type(obj) == "table" and rawget(obj, "_kind") == kind,
        "bad object in function call (expected object type '" .. kind .. "')")
    assert(isDescendant(obj, button), "bad object in function call (must be a descendant of owner)")
end

local function newAuraButton(container, group)
    local b = M.newWidget("Button", nil, container)
    b._template = "CustomAuraButtonTemplate"
    b._strict = true
    b._layoutForbidden = true
    b._dispelTextures = {}
    b._tooltipAnchor = { "ANCHOR_BOTTOMLEFT", 0, 0 }
    b._shown = false
    function b:SetIcon(texture) inbound(self, texture, "Texture"); self._icon = texture end
    function b:SetDurationCooldown(cooldown) inbound(self, cooldown, "Cooldown"); self._durationCooldown = cooldown end
    function b:SetApplicationCount(fontString, options)
        inbound(self, fontString, "FontString")
        for k in pairs(options or {}) do assert(k == "formatter", "mock: unknown count option " .. tostring(k)) end
        self._applicationCount = fontString
        -- UpdateAuraDisplay writes the (empty) count at once.
        fontString:SetText("")
    end
    function b:SetDurationText(fontString) inbound(self, fontString, "FontString"); self._durationText = fontString end
    function b:ClearDurationCooldown() self._durationCooldown = nil end
    function b:ClearDurationText() self._durationText = nil end
    function b:AddDispelTypeTexture(texture, options)
        inbound(self, texture, "Texture")
        for _, entry in ipairs(self._dispelTextures) do
            assert(entry.texture ~= texture, "Display element has already been added.")
        end
        for k in pairs(options or {}) do assert(DISPEL_TEXTURE_KEYS[k], "mock: unknown dispel option " .. tostring(k)) end
        if options and options.style ~= nil then
            assert(isEnumValue(Enum.CustomAuraButtonDispelTypeTextureStyle, options.style), "invalid style")
        end
        table.insert(self._dispelTextures, { texture = texture, options = options })
    end
    function b:SetTooltipAnchorPoint(point, x, y)
        assert(TOOLTIP_ANCHORS[point], "point must be a valid tooltip anchor point name")
        assert(x == nil or type(x) == "number", "offsetX must be a number or nil")
        assert(y == nil or type(y) == "number", "offsetY must be a number or nil")
        self._tooltipAnchor = { point, x or 0, y or 0 }
    end
    function b:SetHideTooltipInCombat(v) self._tooltipHideInCombat = v == true end
    -- UntrustedScriptExecution: scripts an addon sets would never run.
    function b:SetScript() error("mock: an aura button runs no addon scripts", 2) end
    function b:HookScript() error("mock: an aura button runs no addon scripts", 2) end
    if group.initializeFrame then
        -- securecallfunction: an error is reported, not raised.
        xpcall(function() group.initializeFrame(b) end, geterrorhandler())
    end
    b._auraRestricted = true
    guardTree(b)
    table.insert(group.frames, b)
    return b
end

-- One more batch for a group, as when it shows more auras than it has
-- buttons (this can happen in combat).
function M.GrowAuraGroup(container, key)
    local group = assert(container._groups[key], "no such group")
    for _ = 1, M.AURA_BATCH do newAuraButton(container, group) end
end

function M.NewAuraContainer(w, template)
    assert(template == "CustomAuraContainerTemplate", "mock: only CustomAuraContainerTemplate is modelled")
    w._strict = true
    w._unit = "none"
    w._enabled = true
    w._updates = 0
    w._groups = {}
    w._groupOrder = {}
    w._slots = {}
    w._slotOrder = {}
    w._flow = { axis = AnchorUtil.FlowLayoutAxis.Horizontal, anchor = "TOPLEFT",
        horizontal = AnchorUtil.FlowDirection.Right, vertical = AnchorUtil.FlowDirection.Down,
        padding = { 0, 0, 0, 0 }, lineSize = math.huge }
    local function required(self, key)
        return assert(self._groups[key], "aura group '" .. tostring(key) .. "' was not found with this key.")
    end
    function w:GetUnit() return self._unit end
    function w:SetUnit(unit)
        assert(type(unit) == "string")
        if self._unit ~= unit then
            self._unit = unit
            self._updates = self._updates + 1
        end
    end
    function w:IsEnabled() return self._enabled end
    function w:SetEnabled(v) self._enabled = v end
    function w:UpdateAllAuras() self._updates = self._updates + 1 end
    function w:SetEditModePreviewEnabled(v) self._editModePreview = (v == true) end
    function w:IsEditModePreviewEnabled() return self._editModePreview ~= false end
    function w:AddAuraGroup(key, filter, options)
        assert(type(key) == "string" and key ~= "", "groupKey must be a non-empty string.")
        assert(validFilter(filter), "invalid filter string")
        assert(not self._groups[key], "aura group '" .. key .. "' already exists with this key.")
        options = options or {}
        for k in pairs(options) do assert(GROUP_KEYS[k], "mock: unknown group option " .. tostring(k)) end
        assert(options.initializeFrame == nil or type(options.initializeFrame) == "function",
            "initializeFrame must be a function or nil.")
        checkTemplateNames(options.templateNames)
        checkSort(options)
        local max = options.maxFrameCount
        if max == nil then max = math.huge end
        assert(validMax(max), "maxFrameCount must be a non-negative integer or infinity.")
        local group = { key = key, filter = filter, max = max, enabled = true, layout = copyLayout(options.layout),
            candidateFilters = copyCandidateFilters(options.candidateFilters),
            initializeFrame = options.initializeFrame, frames = {} }
        self._groups[key] = group
        table.insert(self._groupOrder, key)
        for _ = 1, M.AURA_BATCH do newAuraButton(self, group) end
        self._layoutForbidden = true
        self._updates = self._updates + 1
    end
    function w:HasAuraGroup(key) return self._groups[key] ~= nil end
    function w:IsAuraGroupEnabled(key) return required(self, key).enabled end
    function w:SetAuraGroupEnabled(key, enabled)
        assert(type(enabled) == "boolean", "enabled must be a boolean.")
        required(self, key).enabled = enabled
    end
    function w:SetAuraGroupFilterString(key, filter)
        local group = required(self, key)
        assert(validFilter(filter), "invalid filter string")
        group.filter = filter
    end
    function w:SetAuraGroupMaxFrameCount(key, max)
        local group = required(self, key)
        assert(validMax(max), "maxFrameCount must be a non-negative integer or infinity.")
        group.max = max
    end
    -- Replaces the whole layout (merged with the defaults), like the source.
    function w:SetAuraGroupLayout(key, layout) required(self, key).layout = copyLayout(layout) end
    function w:SetAuraGroupCandidateFilters(key, filters)
        local group = required(self, key)
        group.candidateFilters = copyCandidateFilters(filters)
    end
    -- Aura slots: one frame each, at a place the addon anchors.
    local function requiredSlot(self, key)
        return assert(self._slots[key], "aura slot '" .. tostring(key) .. "' was not found with this key.")
    end
    function w:AddAuraSlot(key, filter, options)
        assert(type(key) == "string" and key ~= "", "slotKey must be a non-empty string.")
        assert(validFilter(filter), "invalid filter string")
        assert(not self._slots[key], "aura slot '" .. key .. "' already exists with this key.")
        options = options or {}
        for k in pairs(options) do assert(SLOT_KEYS[k], "mock: unknown slot option " .. tostring(k)) end
        assert(options.initializeFrame == nil or type(options.initializeFrame) == "function",
            "initializeFrame must be a function or nil.")
        checkTemplateNames(options.templateNames)
        checkSort(options)
        -- frames and initializeFrame: newAuraButton expects a group record.
        local slot = { key = key, filter = filter, enabled = true,
            candidateFilters = copyCandidateFilters(options.candidateFilters), sortMethod = options.sortMethod, initializeFrame = options.initializeFrame, frames = {} }
        self._slots[key] = slot
        table.insert(self._slotOrder, key)
        slot.frame = newAuraButton(self, slot)
        self._updates = self._updates + 1
        return slot.frame
    end
    function w:HasAuraSlot(key) return self._slots[key] ~= nil end
    function w:GetAuraSlotFrame(key)
        local slot = self._slots[key]
        return slot and slot.frame
    end
    function w:IsAuraSlotEnabled(key) return requiredSlot(self, key).enabled end
    function w:SetAuraSlotEnabled(key, enabled)
        assert(type(enabled) == "boolean", "enabled must be a boolean.")
        requiredSlot(self, key).enabled = enabled
    end
    function w:SetAuraSlotFilterString(key, filter)
        local slot = requiredSlot(self, key)
        assert(validFilter(filter), "invalid filter string")
        slot.filter = filter
    end
    function w:SetAuraSlotCandidateFilters(key, filters)
        local slot = requiredSlot(self, key)
        slot.candidateFilters = copyCandidateFilters(filters)
    end
    function w:SetAuraSlotSortMethod(key, method, direction)
        local slot = requiredSlot(self, key)
        checkSortArguments(method, direction)
        slot.sortMethod = method
    end
    function w:GetAuraGroupFrameCount(key)
        local group = self._groups[key]
        return group and #group.frames or 0
    end
    function w:GetAuraGroupFrame(key, index)
        local group = self._groups[key]
        return group and group.frames[index]
    end
    function w:SetFlowLayoutAxis(axis)
        assert(isEnumValue(AnchorUtil.FlowLayoutAxis, axis), "layoutAxis must be valid.")
        self._flow.axis = axis
    end
    function w:SetFlowLayoutAnchorPoint(point)
        assert(type(point) == "string", "anchorPoint must be a string.")
        self._flow.anchor = point
    end
    function w:SetFlowLayoutGrowthDirection(h, v)
        assert(isEnumValue(AnchorUtil.FlowDirection, h), "horizontalDirection must be valid.")
        assert(isEnumValue(AnchorUtil.FlowDirection, v), "verticalDirection must be valid.")
        self._flow.horizontal, self._flow.vertical = h, v
    end
    function w:SetFlowLayoutPadding(l, r, t, b)
        for _, v in ipairs({ l, r, t, b }) do assert(type(v) == "number", "padding must be numbers.") end
        self._flow.padding = { l, r, t, b }
    end
    function w:SetFlowLayoutMaximumLineSize(size)
        assert(size == nil or type(size) == "number", "maximumLineSize must be a number or nil.")
        self._flow.lineSize = size or math.huge
    end
    M.auraContainers[#M.auraContainers + 1] = w
end

-- A frame counts as protected when it or any descendant is (the client
-- protects the parents of protected frames too).
function M.IsProtectedTree(obj)
    if rawget(obj, "_protected") then return true end
    for _, child in ipairs(rawget(obj, "_children") or {}) do
        if M.IsProtectedTree(child) then return true end
    end
    return false
end

local function newWidget(kind, name, parent)
    local w = setmetatable({
        _kind = kind, _name = name, _parent = parent, _scripts = {},
        _events = {}, _attr = {}, _points = {}, _w = 0, _h = 0, _shown = true,
    }, widget)
    M.widgets[#M.widgets + 1] = w
    -- Children in creation order (an aura button's are guarded with it).
    if type(parent) == "table" then
        local kids = rawget(parent, "_children") or {}
        rawset(parent, "_children", kids)
        kids[#kids + 1] = w
    end
    -- A frame starts one level above its parent, as in the client.
    local parentLevel = type(parent) == "table" and rawget(parent, "_level")
    w._level = parentLevel and parentLevel + 1 or 0
    function w:SetFrameLevel(level)
        assert(type(level) == "number" and level >= 0 and level <= 10000, "SetFrameLevel: level out of range")
        self._level = level
    end
    function w:GetFrameLevel() return self._level end
    function w:GetName() return self._name end
    function w:GetObjectType() return self._kind end
    function w:SetScript(s, fn) self._scripts[s] = fn end
    function w:GetScript(s) return self._scripts[s] end
    function w:HookScript(s, fn)
        local old = self._scripts[s]
        self._scripts[s] = function(...) if old then old(...) end fn(...) end
    end
    function w:RegisterEvent(e) self._events[e] = true; M.Listen(self) end
    -- Unit events: delivered only when the event's first argument is one of
    -- the registered units, like the client's RegisterUnitEvent.
    function w:RegisterUnitEvent(e, ...)
        self._events[e] = { ... }
        M.Listen(self)
        return true
    end
    function w:UnregisterEvent(e) self._events[e] = nil end
    function w:UnregisterAllEvents() self._events = {} end
    function w:SetAttribute(k, v)
        self._attr[k] = v
        local script = self._scripts.OnAttributeChanged
        if script then script(self, k, v) end
    end
    function w:GetAttribute(k) return self._attr[k] end
    function w:RegisterForClicks(...) self._clicks = { ... } end
    -- OnSizeChanged runs when the size really changes, as in the client.
    local function resize(self, width, height)
        if width == self._w and height == self._h then return end
        self._w, self._h = width, height
        local script = self._scripts.OnSizeChanged
        if script then script(self, width, height) end
    end
    function w:SetSize(a, b) resize(self, a, b) end
    function w:SetWidth(v) resize(self, v, self._h) end
    function w:SetHeight(v) resize(self, self._w, v) end
    function w:GetWidth() return self._w end
    function w:GetHeight() return self._h end
    function w:ClearAllPoints() self._points = {} end
    -- Setting a point that is already anchored replaces that anchor.
    -- Anchoring to an aura container that has groups needs the
    -- UntrustedLayoutScriptExecution aspect (Blizzard_CustomAuraContainer.lua);
    -- children have their parent's (ForbiddenAspectConstantsDocumentation.lua).
    function w:SetPoint(point, ...)
        local relativeTo = ...
        if type(relativeTo) == "table" and rawget(relativeTo, "_layoutForbidden")
            and not M.HasLayoutAspect(self) then
            error("mock: anchoring to an aura container needs DisableUntrustedLayoutScriptsTemplate", 2)
        end
        for i, p in ipairs(self._points) do
            if p[1] == point then
                self._points[i] = { point, ... }
                return
            end
        end
        table.insert(self._points, { point, ... })
    end
    function w:GetPoint(i) local p = self._points[i or 1]; if p then return unpack(p) end end
    function w:GetNumPoints() return #self._points end
    function w:GetCenter() return self._cx or 0, self._cy or 0 end
    -- Shown, and every parent shown too.
    function w:IsVisible()
        if not self._shown then return false end
        local parent = self._parent
        if type(parent) ~= "table" or not parent.IsVisible then return true end
        return parent:IsVisible()
    end
    -- OnShow/OnHide fire only when the frame's effective visibility
    -- changes, as in the client: hiding a frame whose parent is hidden
    -- fires nothing. (The mock does not propagate them to children.)
    function w:SetShown(v)
        v = not not v
        if v == self._shown then return end
        local wasVisible = self:IsVisible()
        self._shown = v
        if self:IsVisible() == wasVisible then return end
        local script = self._scripts[v and "OnShow" or "OnHide"]
        if script then script(self) end
    end
    function w:Show() self:SetShown(true) end
    function w:Hide() self:SetShown(false) end
    function w:IsShown() return self._shown end
    function w:SetParent(p) self._parent = p end
    function w:GetParent() return self._parent end
    -- Takes a secret number (AllowedWhenTainted); the alpha carries it.
    function w:SetAlpha(a)
        self._alphaSecret = M.IsSecret(a) or nil
        self._alpha = M.Reveal(a)
    end
    function w:GetAlpha() return self._alpha or 1 end
    -- SimpleFrameAPI / SimpleRegionAPI: takes a secret boolean
    -- (AllowedWhenTainted); the alpha then carries the secret aspect.
    function w:SetAlphaFromBoolean(value, alphaIfTrue, alphaIfFalse)
        assert(type(M.Reveal(value)) == "boolean", "SetAlphaFromBoolean: value must be a boolean")
        self._alpha = M.Reveal(value) and alphaIfTrue or alphaIfFalse
        self._alphaSecret = M.IsSecret(value)
    end
    function w:EnableMouse(v) self._mouse = v end
    function w:IsProtected() return self._protected or false end
    function w:SetFrameStrata(v) self._strata = v end
    function w:SetFixedFrameStrata(v) self._fixedStrata = v end
    function w:SetHighlightTexture(t, blend) self._highlight = { t, blend } end
    function w:GetFrameStrata() return self._strata end
    function w:SetClipsChildren(v) self._clips = v end
    function w:GetEffectiveScale() return M.scale end
    function w:SetScale(v)
        assert(type(v) == "number" and v > 0, "SetScale: scale must be a positive number")
        self._scale = v
    end
    function w:GetScale() return self._scale or 1 end
    -- StatusBar
    function w:SetMinMaxValues(a, b) self._min, self._max = a, b end
    function w:GetMinMaxValues() return self._min, self._max end
    function w:SetValue(v) self._value = v end
    function w:GetValue() return self._value end
    function w:SetStatusBarTexture(t) self._texture = t end
    function w:SetStatusBarColor(r, g, b, a) self._color = { r, g, b, a } end
    function w:GetStatusBarTexture() return self._barTex end
    function w:SetReverseFill(v) self._reverse = v end
    -- Texture
    -- A texture shows either a file or an atlas; setting one replaces the
    -- other.
    function w:SetTexture(t, wrapH, wrapV) self._texture = t; self._atlas = nil; self._wrap = { wrapH, wrapV } end
    function w:SetHorizTile(v) self._horizTile = v end
    function w:SetBlendMode(mode)
        assert(({ DISABLE = 1, BLEND = 1, ALPHAKEY = 1, ADD = 1, MOD = 1 })[mode], "SetBlendMode: bad mode")
        self._blend = mode
    end
    function w:SetVertTile(v) self._vertTile = v end
    -- Masks (SimpleTextureAPI): only mask textures can be added, and at
    -- most M.MAX_MASKS per texture (the client raises beyond that).
    function w:AddMaskTexture(mask)
        assert(type(mask) == "table" and mask._kind == "MaskTexture", "AddMaskTexture: not a mask texture")
        self._masks = self._masks or {}
        if #self._masks >= M.MAX_MASKS then
            error(("Texture:AddMaskTexture(): Texture already has the maximum number of mask textures (%d)")
                :format(M.MAX_MASKS), 2)
        end
        table.insert(self._masks, mask)
    end
    function w:RemoveMaskTexture(mask)
        assert(type(mask) == "table" and mask._kind == "MaskTexture", "RemoveMaskTexture: not a mask texture")
        for i, m in ipairs(self._masks or {}) do
            if m == mask then table.remove(self._masks, i) return end
        end
    end
    function w:GetNumMaskTextures() return self._masks and #self._masks or 0 end
    function w:SetAtlas(atlas)
        assert(type(atlas) == "string", "SetAtlas: atlas must be a string")
        self._atlas = atlas; self._texture = nil
    end
    function w:SetTexCoord(...) self._texCoord = { ... } end
    -- Takes a secret boolean (AllowedWhenTainted).
    function w:SetDesaturated(v)
        assert(type(M.Reveal(v)) == "boolean", "SetDesaturated: value must be a boolean")
        self._desaturated = M.Reveal(v)
    end
    -- SimpleTextureBaseAPI: the cell may be secret (AllowedWhenTainted),
    -- rows and columns never are.
    function w:SetSpriteSheetCell(cell, rows, columns)
        assert(type(M.Reveal(cell)) == "number", "SetSpriteSheetCell: cell must be a number")
        assert(not M.IsSecret(rows) and not M.IsSecret(columns), "SetSpriteSheetCell: rows/columns never secret")
        self._spriteCell = { M.Reveal(cell), rows, columns }
        self._spriteSecret = M.IsSecret(cell)
    end
    -- Shader nine-slice (SimpleTextureBaseAPI, masks included).
    function w:SetTextureSliceMargins(left, top, right, bottom)
        for _, v in ipairs({ left, top, right, bottom }) do
            assert(type(v) == "number", "SetTextureSliceMargins: margins must be numbers")
        end
        self._slice = { left, top, right, bottom }
    end
    function w:GetTextureSliceMargins()
        local s = self._slice or { 0, 0, 0, 0 }
        return s[1], s[2], s[3], s[4]
    end
    function w:SetTextureSliceMode(mode)
        assert(mode == 0 or mode == 1, "SetTextureSliceMode: bad mode")
        self._sliceMode = mode
    end
    function w:ClearTextureSlice() self._slice, self._sliceMode = nil, nil end
    -- _color is the last colour given either way; _texColor keeps the
    -- colour texture's own.
    function w:SetColorTexture(r, g, b, a)
        self._color = { r, g, b, a }; self._texColor = self._color
        self._texture, self._atlas = nil, nil
    end
    -- One vertex colour replaces a gradient's per-vertex colours.
    function w:SetVertexColor(r, g, b, a) self._color = { r, g, b, a }; self._gradient = nil end
    -- SetGradient(orientation, minColor, maxColor): colours are ColorMixin
    -- objects (SimpleTextureBaseAPIDocumentation.lua).
    function w:SetGradient(orientation, minColor, maxColor)
        assert(orientation == "HORIZONTAL" or orientation == "VERTICAL", "SetGradient: bad orientation")
        for _, c in ipairs({ minColor, maxColor }) do
            assert(type(c) == "table" and type(c.r) == "number", "SetGradient: colours must be ColorMixin objects")
        end
        self._gradient = { orientation, minColor, maxColor }
    end
    function w:SetAllPoints(p) self._allPoints = p or true end
    -- Region draw layer; sublevel -8..7 like the client.
    function w:SetDrawLayer(layer, sublevel)
        sublevel = sublevel or 0
        assert(sublevel >= -8 and sublevel <= 7, "SetDrawLayer: sublevel out of range")
        self._layer, self._sublevel = layer, sublevel
    end
    function w:GetDrawLayer() return self._layer, self._sublevel or 0 end
    -- FontString / EditBox. An EditBox without a font cannot take text in
    -- the client, so the mock refuses it too.
    function w:SetFont(path, size, flags) self._font = { path, size, flags }; return true end
    function w:GetFont()
        if not self._font then return nil end
        return self._font[1], self._font[2], self._font[3]
    end
    function w:SetFontObject(o) self._fontObject = o end
    function w:SetText(t)
        if self._kind == "EditBox" or self._kind == "FontString" then
            assert(self._font or self._fontObject, self._kind .. ":SetText(): Font not set")
        end
        self._text = t
        self._fmt, self._args = nil, nil
        -- An EditBox reports every new text: userInput true only for the
        -- player's typing (M.Type), false for SetText from code.
        if self._kind == "EditBox" and self._scripts and self._scripts.OnTextChanged then
            local userInput = M.typing == self
            M.typing = nil   -- a SetText in the handler is the code's own
            self._scripts.OnTextChanged(self, userInput)
        end
    end
    function w:SetTextColor(r, g, b, a) self._color = { r, g, b, a } end
    function w:GetTextColor()
        local c = self._color or { 1, 1, 1, 1 }
        return c[1], c[2], c[3], c[4] or 1
    end
    function w:GetText() return self._text end
    function w:SetFormattedText(fmt, ...)
        if self._kind == "EditBox" or self._kind == "FontString" then
            assert(self._font or self._fontObject, self._kind .. ":SetFormattedText(): Font not set")
        end
        self._fmt = fmt; self._args = { ... }
        self._text = nil
    end
    function w:SetShadowOffset(x, y) self._shadow = { x, y } end
    function w:SetJustifyH(v) self._justifyH = v end
    function w:SetJustifyV(v) self._justifyV = v end
    function w:SetWordWrap(v) self._wordWrap = not not v end
    function w:GetWordWrap() return self._wordWrap ~= false end
    -- Rough text width: half the font size per character.
    function w:GetStringWidth()
        local size = self._font and self._font[2] or 12
        return #(self._text or "") * size / 2
    end
    -- Rough text height: one font size per line; a set width wraps the
    -- text (when word wrap is on) into as many lines as it needs.
    function w:GetStringHeight()
        if (self._text or "") == "" then return 0 end
        local size = self._font and self._font[2] or 12
        local width, lines = self._w or 0, 1
        if width > 0 and self:GetWordWrap() then
            lines = math.max(1, math.ceil(self:GetStringWidth() / width))
        end
        return lines * size
    end
    -- Cut off when the natural width exceeds a set width (0 = natural).
    function w:IsTruncated()
        local width = self._w or 0
        return width > 0 and self:GetStringWidth() > width
    end
    -- Enable state (Button, CheckButton, EditBox, Slider)
    -- A disabled EditBox loses its focus and cannot take it (SetFocus).
    function w:SetEnabled(v)
        self._enabled = not not v
        if not v then self._focus = false end
    end
    function w:IsEnabled() return self._enabled ~= false end
    function w:Enable() self._enabled = true end
    function w:Disable() self._enabled = false end
    function w:EnableMouseWheel(v) self._mouseWheel = v end
    function w:IsMouseOver() return self._mouseOver or false end
    function w:EnableKeyboard(v) self._keyboard = v end
    function w:SetPropagateKeyboardInput(v)
        assert(not M.combat, "SetPropagateKeyboardInput is restricted in combat")
        self._propagate = v
    end
    -- Slider
    function w:SetOrientation(v) self._orientation = v end
    function w:SetValueStep(v) self._step = v end
    function w:SetObeyStepOnDrag(v) self._obeyStep = v end
    function w:SetThumbTexture(asset)
        self._thumb = self._thumb or newWidget("Texture", nil, self)
        self._thumb._texture = asset
    end
    function w:GetThumbTexture() return self._thumb end
    -- CheckButton
    function w:SetChecked(v) self._checked = not not v end
    function w:GetChecked() return self._checked or false end
    function w:SetCheckedTexture(asset)
        self._checkedTex = self._checkedTex or newWidget("Texture", nil, self)
        self._checkedTex._texture = asset
    end
    function w:GetCheckedTexture() return self._checkedTex end
    -- EditBox
    function w:SetAutoFocus(v) self._autoFocus = v end
    function w:SetFocus() if self._enabled ~= false then self._focus = true end end
    function w:ClearFocus() self._focus = false end
    function w:HasFocus() return self._focus or false end
    function w:SetCursorPosition(p) self._cursor = p end
    function w:HighlightText(a, b) self._highlighted = { a, b } end
    function w:SetMaxLetters(n) self._maxLetters = n end
    function w:SetMultiLine(v) self._multiLine = v end
    function w:SetTextInsets(l, r, t, b) self._insets = { l, r, t, b } end
    -- ScrollFrame
    function w:SetScrollChild(c) self._scrollChild = c end
    function w:GetScrollChild() return self._scrollChild end
    function w:SetVerticalScroll(v) self._vscroll = v end
    function w:GetVerticalScroll() return self._vscroll or 0 end
    function w:GetVerticalScrollRange() return self._vrange or 0 end
    -- The range anew from the child's height and the frame's, when both
    -- are known (the client works it out from their layout).
    function w:UpdateScrollChildRect()
        local child = self._scrollChild
        if child and child._h and self._h then self._vrange = math.max(0, child._h - self._h) end
    end
    -- Creation
    function w:CreateTexture(n, layer, _, sublevel)
        local t = newWidget("Texture", n, self)
        t._layer, t._sublevel = layer, sublevel
        return t
    end
    function w:CreateMaskTexture(n, layer, _, sublevel)
        local t = newWidget("MaskTexture", n, self)
        t._layer, t._sublevel = layer, sublevel
        -- In the client a mask ignores texture coordinates: a mirrored mask
        -- drew unmirrored in game (ring corners came out concave). No
        -- Blizzard mask uses them either. Mask files carry their own shape.
        function t:SetTexCoord()
            error("MaskTexture:SetTexCoord: masks ignore texture coordinates in the client", 2)
        end
        -- Nor does a mask's own scale change a sliced mask's corners (in
        -- game a scaled mask kept its full margin as corner size).
        function t:SetScale()
            error("MaskTexture:SetScale: the client ignores a mask's scale for its slices", 2)
        end
        return t
    end
    function w:CreateFontString(n, layer)
        local fs = newWidget("FontString", n, self)
        fs._layer, fs._sublevel = layer or "ARTWORK", 0
        return fs
    end
    -- Animation groups: Play marks the group playing; M.FinishAnimations
    -- ends every playing group like the client would when it is done.
    function w:CreateAnimationGroup()
        local group = newWidget("AnimationGroup", nil, self)
        group._anims = {}
        function group:CreateAnimation(kind)
            local anim = newWidget(kind, nil, self)
            function anim:SetFromAlpha(v) self._from = v end
            function anim:SetToAlpha(v) self._to = v end
            function anim:SetDuration(v) self._duration = v end
            function anim:SetStartDelay(v) self._delay = v end
            function anim:SetOrder(v) self._order = v end
            -- Scale (SimpleAnimScaleAPI)
            function anim:SetScaleFrom(x, y) self._scaleFrom = { x, y } end
            function anim:SetScaleTo(x, y) self._scaleTo = { x, y } end
            function anim:SetOrigin(point, x, y) self._origin = { point, x, y } end
            function anim:SetSmoothing(v)
                assert(({ NONE = 1, IN = 1, OUT = 1, IN_OUT = 1 })[v], "SetSmoothing: bad smoothing")
                self._smoothing = v
            end
            -- FlipBook (SimpleAnimFlipBookAPI)
            function anim:SetFlipBookRows(v) self._rows = v end
            function anim:SetFlipBookColumns(v) self._columns = v end
            function anim:SetFlipBookFrames(v) self._frames = v end
            function anim:SetFlipBookFrameWidth(v) self._frameWidth = v end
            function anim:SetFlipBookFrameHeight(v) self._frameHeight = v end
            table.insert(self._anims, anim)
            return anim
        end
        function group:SetToFinalAlpha(v) self._toFinal = v end
        function group:SetLooping(v)
            assert(v == "NONE" or v == "REPEAT" or v == "BOUNCE", "SetLooping: bad loop type")
            self._looping = v
        end
        function group:Play() self._playing = true; M.playing[self] = true end
        function group:Stop() self._playing = false; M.playing[self] = nil end
        function group:IsPlaying() return self._playing or false end
        return group
    end
    -- Cooldown. _cooldown holds { start, duration } or { object = duration
    -- object }; nil when cleared.
    function w:SetCooldown(start, duration) self._cooldown = { start, duration } end
    function w:SetCooldownFromDurationObject(duration) self._cooldown = { object = duration } end
    function w:Clear() self._cooldown = nil end
    function w:SetHideCountdownNumbers(v) self._hideNumbers = v end
    function w:GetCountdownFontString()
        self._countdown = self._countdown or newWidget("FontString", nil, self)
        return self._countdown
    end
    -- Mouse: motion (tooltips) and clicks can be switched separately.
    function w:SetMouseClickEnabled(v) self._clickEnabled = v end
    function w:SetMouseMotionEnabled(v) self._motionEnabled = v end
    -- Mouse buttons that go through the frame to what lies below it
    -- (SimpleScriptRegionAPI; protected on protected frames in combat).
    function w:SetPassThroughButtons(...) self._passThrough = { ... } end
    -- PlayerModel
    -- A unit without a (loaded) model (d.noModel): the client keeps what
    -- the model showed, as it does in game.
    -- d.modelLater: loaded frames later (M.LoadModels fires OnModelLoaded).
    function w:SetUnit(unit)
        local d = M.units[unit]
        if d and d.noModel then return false end
        if d and d.modelLater then
            M.pendingModels = M.pendingModels or {}
            M.pendingModels[self] = unit
            return nil
        end
        -- A creature (d.creatureModel): as measured in Forever, SetUnit
        -- loads nothing and answers nil (model empty, display 0).
        if d and d.creatureModel then return nil end
        self._modelUnit = unit
        return true
    end
    -- Players have a file; creatures (d.creatureModel) only a display ID.
    function w:GetModelFileID()
        local d = self._modelUnit and M.units[self._modelUnit]
        if not self._modelUnit or (d and d.creatureModel) then return nil end
        return 12345
    end
    function w:GetDisplayInfo() return self._modelUnit and 678 or 0 end
    -- By NPC ID: loads the creature (d.npcID must match a known unit).
    function w:SetCreature(id)
        for token, d in pairs(M.units) do
            if d.npcID == id then self._modelUnit = token; self._creature = id; return end
        end
    end
    function w:ClearModel()
        self._modelUnit = nil
        self._cleared = true
        if M.pendingModels then M.pendingModels[self] = nil end
    end
    function w:SetPortraitZoom(z) self._zoom = z end
    function w:SetCamDistanceScale(v) self._camScale = v end
    function w:SetPosition(x, y, z) self._position = { x, y, z } end
    -- Movable
    function w:SetMovable(v) self._movable = v end
    function w:RegisterForDrag(...) self._drag = { ... } end
    function w:StartMoving() end
    function w:StopMovingOrSizing() end
    function w:SetClampedToScreen() end
    -- Protected frames: explicitly protected ones (secure templates) and
    -- every frame with a protected descendant. In combat, tainted code may
    -- not show, hide, move, size, reparent or re-attribute them
    -- (ADDON_ACTION_BLOCKED in the client).
    for _, method in ipairs({ "SetShown", "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight",
                              "SetAttribute", "SetParent", "EnableMouse", "SetAllPoints",
                              "SetPassThroughButtons" }) do
        local original = w[method]
        if original then
            w[method] = function(self, ...)
                if M.combat and M.secureDepth == 0 and M.IsProtectedTree(self) then
                    M.blocked[#M.blocked + 1] = method
                    error("mock: " .. method .. " on a protected frame in combat", 2)
                end
                return original(self, ...)
            end
        end
    end
    -- Made under an aura button after it was restricted: restricted too.
    if restricted(w) then guardTree(w) end
    return w
end
M.newWidget = newWidget

function M.Reset()
    M.eventFrames = {}
    M.eventOrder = {}
    M.frames = {}
    M.widgets = {}         -- every widget created, in creation order
    M.chat = {}
    M.combat = false
    M.shiftDown, M.ctrlDown, M.altDown = false, false, false
    M.form = nil
    M.blocked = {}         -- protected-frame calls refused in combat
    M.secureDepth = 0      -- > 0 while mock secure code runs
    M.units = {}
    -- RegionalUniqueNamesEnabled() answer; the client's default is unknown.
    M.regionalUniqueNames = false
    M.cvars = { ActionButtonUseKeyDown = "1" }
    M.macros = {}          -- list of { name=, icon=, body=, perChar= }
    M.macroFrameShown = false
    M.macroWrites = 0      -- CreateMacro/EditMacro calls (must stay 0)
    M.macroDeletes = 0     -- DeleteMacro calls
    M.errors = {}          -- whatever reached the global error handler
    M.timers = {}          -- queued C_Timer.After callbacks
    M.locale = "enUS"      -- GetLocale(): the game's language
    M.now = 1000           -- GetTime(), advanced by M.Tick
    M.group = {}           -- party unit tokens ("party1", ...) while grouped
    M.headerUpdates = 0    -- how often a group header laid out its buttons
    M.playing = {}         -- animation groups that are playing
    -- Aura containers: every one made, in order; M.auraContainerMissing
    -- makes CreateFrame refuse the type (a client without it).
    M.auraContainers = {}
    M.auraContainerMissing = false
    M.aurasSecret = false
    -- Blizzard_SharedXMLBase/AnchorUtil.lua and Blizzard_AuraContainerShared.lua.
    _G.AnchorUtil = { FlowLayoutAxis = { Horizontal = 0, Vertical = 1 },
        FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }
    _G.AuraContainerSortMethod = { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2, ImportantOnly = 3,
        Expiration = 4, ExpirationOnly = 5, Name = 6, NameOnly = 7, AuraInstanceIDOnly = 8 }
    _G.AuraContainerSortDirection = { Normal = 0, Reverse = 1 }

    -- Pixel grid. By default one physical pixel is one UI unit (768 pixels
    -- high, scale 1), so layout numbers stay whole; tests change these.
    M.scale = 1
    M.screenW, M.screenH = 1024, 768
    _G.GetPhysicalScreenSize = function() return M.screenW, M.screenH end
    -- Round is math.round in the client (MathUtil.lua): half away from zero.
    _G.Round = function(v) if v < 0 then return -math.floor(-v + 0.5) end return math.floor(v + 0.5) end
    -- Blizzard_SharedXML/PixelUtil.lua, the functions the addon uses.
    _G.PixelUtil = {}
    function PixelUtil.GetPixelToUIUnitFactor()
        local _, physicalHeight = GetPhysicalScreenSize()
        return 768.0 / physicalHeight
    end
    function PixelUtil.GetNearestPixelSize(uiUnitSize, layoutScale, minPixels)
        if uiUnitSize == 0 and (not minPixels or minPixels == 0) then return 0 end
        local uiUnitFactor = PixelUtil.GetPixelToUIUnitFactor()
        local numPixels = Round((uiUnitSize * layoutScale) / uiUnitFactor)
        if minPixels then
            if uiUnitSize < 0.0 then
                if numPixels > -minPixels then numPixels = -minPixels end
            else
                if numPixels < minPixels then numPixels = minPixels end
            end
        end
        return numPixels * uiUnitFactor / layoutScale
    end

    _G.UIParent = newWidget("Frame", "UIParent")
    _G.UIParent._w, _G.UIParent._h = 1920, 1080
    -- Blizzard_UIParent/UIParent.lua: UIParent's OnShow triggers
    -- "UI.TopLevelParentShown", which Blizzard_Game/Shared/Game.lua answers
    -- with CloseAllWindows(): CloseSpecialWindows() hides every shown frame
    -- named in UISpecialFrames. (Bags and UI panels are not modelled.)
    _G.UIParent._scripts.OnShow = function()
        for _, value in pairs(UISpecialFrames) do
            local frame = _G[value]
            if frame and frame:IsShown() then frame:Hide() end
        end
    end
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg)
        assert(type(msg) == "string", "chat message must be a plain string")
        table.insert(M.chat, msg)
    end }
    _G.CreateFrame = function(kind, name, parent, template)
        if kind == "AuraContainer" and M.auraContainerMissing then
            error("CreateFrame: Unknown frame type 'AuraContainer'", 2)
        end
        local w = newWidget(kind, name, parent)
        w._template = template
        if template and template:find("DisableUntrustedLayoutScriptsTemplate") then w._layoutForbidden = true end
        if kind == "AuraContainer" then M.NewAuraContainer(w, template) end
        if template and template:find("Secure") then w._protected = true end
        if kind == "StatusBar" then
            w._barTex = newWidget("Texture", nil, w)
            -- Timer bars (SimpleStatusBarAPIDocumentation.lua): the client
            -- animates the value from a duration object. An empty duration
            -- (C_DurationUtil.CreateDuration) ends the timer.
            function w:SetTimerDuration(duration, interpolation, direction)
                assert(type(duration) ~= "nil", "duration must be a LuaDurationObject")
                if type(duration) == "table" and duration._empty then
                    self._timer = nil
                else
                    self._timer = duration
                end
                self._timerDirection = direction
            end
        end
        if name then _G[name] = w end
        table.insert(M.frames, w)
        if template == "SecureGroupHeaderTemplate" then makeGroupHeader(w) end
        if template == "SecureGroupPetHeaderTemplate" then makeGroupHeader(w, true) end
        if M.templates[template] then M.templates[template](w) end
        return w
    end
    _G.InCombatLockdown = function() return M.combat end
    -- In an inn or a city (PLAYER_UPDATE_RESTING when it changes).
    M.resting = false
    _G.IsResting = function() return M.resting end
    _G.GetTime = function() return M.now end
    -- In a group: a party (M.group) or a raid (M.inRaid).
    _G.IsInGroup = function() return #M.group > 0 or M.inRaid end
    -- Raid: M.inRaid (M.SetRaid). Visibility drivers (SecureStateDriver.lua:
    -- RegisterStateDriver(frame, "visibility", values) sets state-visibility);
    -- the mock knows the conditions the addon uses ([group] is a party or a
    -- raid) and evaluates them again when the group changes.
    M.inRaid = false
    M.drivers = setmetatable({}, { __mode = "k" })
    _G.IsInRaid = function() return M.inRaid end
    local function evaluate(frame, values)
        for clause in (values .. ";"):gmatch("%s*([^;]+);") do
            local cond, action = clause:match("^%[(.-)%]%s*(%a+)$")
            if not cond then action = clause:match("^(%a+)$") end
            local match = cond == nil or (cond == "group:raid" and M.inRaid) or (cond == "nogroup:raid" and not M.inRaid)
                or (cond == "group" and IsInGroup())
            assert(cond == nil or cond == "group:raid" or cond == "nogroup:raid" or cond == "group",
                "mock: unknown condition " .. tostring(cond))
            if match then
                -- The state driver is secure code: it may show and hide
                -- protected frames in combat.
                M.secureDepth = M.secureDepth + 1
                if action == "show" then frame:Show() else frame:Hide() end
                M.secureDepth = M.secureDepth - 1
                return
            end
        end
    end
    _G.RegisterStateDriver = function(frame, state, values)
        assert(not M.combat, "RegisterStateDriver: in combat")
        assert(state == "visibility", "mock: only the visibility state")
        M.drivers[frame] = values
        evaluate(frame, values)
    end
    _G.UnregisterStateDriver = function(frame, state)
        assert(not M.combat, "UnregisterStateDriver: in combat")
        M.drivers[frame] = nil
    end
    function M.SetRaid(on)
        M.inRaid = on
        for frame, values in pairs(M.drivers) do evaluate(frame, values) end
    end
    -- Instance and group size (Raid/Size.lua). M.instance holds what
    -- GetInstanceInfo reports as instanceType and maxPlayers; in a raid
    -- GetNumGroupMembers is M.raidMembers, in a party the party plus you.
    M.instance = { type = "none", maxPlayers = 0 }
    M.raidMembers = 0
    _G.GetInstanceInfo = function()
        return "Instance", M.instance.type, 0, "", M.instance.maxPlayers, 0, false, 0, 0, nil, false
    end
    _G.GetNumGroupMembers = function()
        if M.inRaid then return M.raidMembers end
        if #M.group > 0 then return #M.group + 1 end
        return 0
    end
    -- The raid roster (M.SetRaidRoster): member i is unit "raid"..i.
    -- GetRaidRosterInfo's values in the client's order: name, rank,
    -- subgroup, level, class (localised), class token, zone, online,
    -- dead, role (MAINTANK, MAINASSIST or nil), master looter, assigned
    -- role (TANK, HEALER, DAMAGER or NONE).
    M.raid = {}
    _G.GetRaidRosterInfo = function(index)
        local m = M.raid[index]
        if not m then return nil end
        local u = M.units["raid" .. index] or {}
        return m.name, m.rank or 0, m.subgroup, u.level or 60, u.className, m.class, "Zone", not u.offline,
            u.dead or false, m.role, false, m.assignedRole or "NONE"
    end
    -- d.assignment: "MAINTANK" or "MAINASSIST" (party members).
    _G.GetPartyAssignment = function(assignment, unit)
        local d = M.units[unit]
        return d ~= nil and d.assignment == assignment
    end
    -- Blizzard_FrameXMLBase/Camelot/Constants.lua (this game type).
    _G.CLASS_SORT_ORDER = { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER" }
    -- Blizzard's strings for raid block titles (GlobalStrings; the class
    -- names from LocalizedClassList, Blizzard_FrameXMLBase/Constants.lua).
    _G.GROUP_NUMBER = "Group %d"
    _G.RAID = "Raid"
    _G.TANK, _G.HEALER, _G.DAMAGER = "Tank", "Healer", "Damage"
    _G.LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", PALADIN = "Paladin", PRIEST = "Priest",
        SHAMAN = "Shaman", DRUID = "Druid", ROGUE = "Rogue", MAGE = "Mage", WARLOCK = "Warlock", HUNTER = "Hunter" }
    -- The player's name and realm (Raid/Profiles.lua: one raid profile per
    -- character). UnitFullName may leave the realm out early in the login.
    M.playerName, M.realm, M.fullNameRealm = "Tester", "Testrealm", true
    _G.UnitFullName = function(unit)
        if unit ~= "player" then return nil end
        return M.playerName, M.fullNameRealm and M.realm or nil
    end
    _G.GetNormalizedRealmName = function() return M.realm end
    _G.geterrorhandler = function()
        return function(err) table.insert(M.errors, err) end
    end
    _G.WOW_PROJECT_MAINLINE = 1
    _G.WOW_PROJECT_ID = 1
    _G.GetLocale = function() return M.locale end
    _G.GetBuildInfo = function() return "1.60.1", "69977", "Sep 22 2026", 16001 end
    _G.issecretvalue = M.IsSecret
    _G.RegisterUnitWatch = function(f) f._unitWatch = true end
    _G.UnregisterUnitWatch = function(f) f._unitWatch = nil end
    _G.RAID_CLASS_COLORS = {
        WARLOCK = { r = 0.53, g = 0.53, b = 0.93, GetRGB = function(c) return c.r, c.g, c.b end },
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43, GetRGB = function(c) return c.r, c.g, c.b end },
        DRUID = { r = 1, g = 0.49, b = 0.04, GetRGB = function(c) return c.r, c.g, c.b end },
    }
    -- Class icons (Blizzard_SharedXML/SharedConstants.lua); atlases the
    -- client knows are listed in M.atlases, GetAtlasInfo gives nothing for
    -- any other name.
    _G.CLASS_ICON_TCOORDS = {
        WARRIOR = { 0, 0.25, 0, 0.25 },
        WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
    }
    M.atlases = { ["classicon-warrior"] = true, ["classicon-warlock"] = true,
        -- Classification badges (Blizzard_NamePlateClassificationFrame.lua).
        ["nameplates-icon-elite-gold"] = true, ["nameplates-icon-elite-silver"] = true,
        ["UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star"] = true,
        -- The target frame's high-level (boss) icon (Blizzard_UnitFrame/Mainline/TargetFrame.xml).
        ["UI-HUD-UnitFrame-Target-HighLevelTarget_Icon"] = true,
        -- Group icons (PartyFrameTemplates.xml, ReadyCheck.lua, CompactUnitFrame.lua).
        ["UI-HUD-UnitFrame-Player-Group-LeaderIcon"] = true, ["UI-HUD-UnitFrame-Player-Group-GuideIcon"] = true,
        ["UI-LFG-ReadyMark-Raid"] = true, ["UI-LFG-DeclineMark-Raid"] = true, ["UI-LFG-PendingMark-Raid"] = true,
        ["RaidFrame-Icon-Rez"] = true }
    _G.C_Texture = {
        GetAtlasInfo = function(atlas)
            if M.atlases[atlas] then return { file = atlas, width = 64, height = 64 } end
        end,
    }
    _G.Constants = {}
    _G.MacroFrame = M.NewMacroFrame()
    _G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGB = function(c) return c.r, c.g, c.b end } end
    _G.ForeverUnitFrames = nil
    _G.ForeverUnitFramesDB = nil

    -- Unit API: data comes from M.units[unit]; fields may hold secret proxies.
    local function u(unit) return M.units[unit] end
    _G.UnitExists = function(unit) return u(unit) ~= nil end
    -- name, surname (nil when the unit has none).
    _G.RegionalUniqueNamesEnabled = function() return M.regionalUniqueNames == true end
    _G.UnitName = function(unit) local d = u(unit); if d then return d.name, d.surname end end
    _G.UnitLevel = function(unit) local d = u(unit); return d and d.level or 0 end
    _G.UnitClass = function(unit) local d = u(unit); if d then return d.className, d.class end end
    -- Localised race and creature type (units: race, creatureType).
    -- d.guid ("Creature-0-1-2-3-<npcID>-4"), may be secret.
    _G.UnitGUID = function(unit) local d = u(unit); return d and d.guid end
    -- WoW's strsplit: the parts between the (single-character) delimiter.
    _G.strsplit = function(delim, str)
        local parts = {}
        for part in (str .. delim):gmatch("(.-)" .. delim:gsub("%p", "%%%0")) do parts[#parts + 1] = part end
        return unpack(parts)
    end
    -- Modifier keys: M.shiftDown, M.ctrlDown, M.altDown.
    _G.IsShiftKeyDown = function() return M.shiftDown or false end
    _G.IsControlKeyDown = function() return M.ctrlDown or false end
    _G.IsAltKeyDown = function() return M.altDown or false end
    -- MakeModifiers (InputDocumentation.lua): the held modifiers as a
    -- number. The client's bits are its own; the mock's are Shift 1, Ctrl
    -- 2, Alt 4 (an addon must not read them).
    _G.MakeModifiers = function()
        return (M.shiftDown and 1 or 0) + (M.ctrlDown and 2 or 0) + (M.altDown and 4 or 0)
    end
    -- Blizzard's click bindings (C_ClickBindings, ClickBindingsDocumentation
    -- .lua): the player's profile, M.clickBindings = list of { button =,
    -- modifiers = (MakeModifiers' number), type = Enum.ClickBindingType,
    -- interaction = Enum.ClickBindingInteraction }. The default profile
    -- binds only the plain left click (Target) and the plain right click
    -- (OpenContextMenu). M.clickBindingRuns: the bindings the client ran
    -- itself (ExecuteBinding).
    M.clickBindings = {
        { button = "LeftButton", modifiers = 0, type = 3, interaction = 1 },
        { button = "RightButton", modifiers = 0, type = 3, interaction = 2 },
    }
    M.clickBindingRuns = {}
    local function clickBinding(button, modifiers)
        assert(type(button) == "string" and type(modifiers) == "number", "C_ClickBindings: button, modifiers")
        for _, b in ipairs(M.clickBindings) do
            if b.button == button and b.modifiers == modifiers then return b end
        end
    end
    -- GetEffectiveInteractionButton: the button the interaction stands
    -- for by default (Target the left, the menu the right).
    local INTERACTION_BUTTON = { "LeftButton", "RightButton" }
    _G.C_ClickBindings = {
        GetBindingType = function(button, modifiers)
            local b = clickBinding(button, modifiers)
            return b and b.type or 0
        end,
        GetEffectiveInteractionButton = function(button, modifiers)
            local b = clickBinding(button, modifiers)
            return b and b.interaction and INTERACTION_BUTTON[b.interaction] or button
        end,
        ExecuteBinding = function(unit, button, modifiers)
            M.clickBindingRuns[#M.clickBindingRuns + 1] = { unit = unit, button = button, modifiers = modifiers }
        end,
    }
    _G.UnitRace = function(unit) local d = u(unit); if d then return d.race, d.race end end
    _G.UnitCreatureType = function(unit) local d = u(unit); if d then return d.creatureType end end
    -- Takes secret class tokens (SecretArguments = AllowedWhenTainted); a
    -- secret token gives a colour of secret components.
    _G.C_ClassColor = {
        GetClassColor = function(token)
            local c = RAID_CLASS_COLORS[M.Reveal(token)]
            assert(c, "GetClassColor: unknown class")
            if not M.IsSecret(token) then return { r = c.r, g = c.g, b = c.b } end
            return { r = M.Secret(c.r), g = M.Secret(c.g), b = M.Secret(c.b) }
        end,
    }
    _G.UnitIsPlayer = function(unit) local d = u(unit); return d and d.isPlayer or false end
    -- d.afk, d.dnd: the away flags (true, false or a secret).
    _G.UnitIsAFK = function(unit) local d = u(unit); if d and d.afk ~= nil then return d.afk end return false end
    _G.UnitIsDND = function(unit) local d = u(unit); if d and d.dnd ~= nil then return d.dnd end return false end
    _G.UnitIsVisible = function(unit) local d = u(unit); return d ~= nil and d.visible ~= false end
    -- Records the last unit drawn into each texture.
    -- No portrait for the unit (d.noPortrait): the texture stays as it was.
    _G.SetPortraitTexture = function(texture, unit)
        local d = M.units[unit]
        if d and d.noPortrait then return end
        texture._portraitUnit = unit
        texture._texture = "portrait:" .. tostring(unit)
    end
    _G.UnitIsFriend = function(_, unit) local d = u(unit); return d and d.friend or false end
    _G.UnitReaction = function(unit) local d = u(unit); return d and d.reaction end
    _G.UnitHealth = function(unit) local d = u(unit); return d and d.health or 0 end
    _G.UnitHealthMax = function(unit) local d = u(unit); return d and d.healthMax or 0 end
    _G.UnitHealthMissing = function(unit) local d = u(unit); return d and d.healthMissing or 0 end
    _G.UnitHealthPercent = function(unit, _, curve)
        local d = u(unit); local p = d and d.healthPercent
        if p == nil and d and d.health and d.healthMax then
            -- Derived like the client, secret when either value is.
            local h, m = M.Reveal(d.health), M.Reveal(d.healthMax)
            p = m > 0 and h / m or 0
            if M.IsSecret(d.health) or M.IsSecret(d.healthMax) then p = M.Secret(p) end
        end
        p = p or 0
        if curve then return curve:Evaluate(p) end
        return p
    end
    -- Power type 0 asked for explicitly: d.mana (a druid in form), else
    -- the current power.
    _G.UnitPower = function(unit, powerType)
        local d = u(unit)
        if powerType == 0 and d and d.mana ~= nil then return d.mana end
        return d and d.power or 0
    end
    -- Power type 4 (combo points): d.comboMax; M.comboPoints is what
    -- GetComboPoints("player", "target") answers.
    _G.UnitPowerMax = function(unit, powerType)
        local d = u(unit)
        if powerType == 4 then return d and d.comboMax or 0 end
        if powerType == 0 and d and d.manaMax ~= nil then return d.manaMax end
        return d and d.powerMax or 0
    end
    _G.GetComboPoints = function(unit, target)
        assert(unit == "player" and target == "target", "GetComboPoints: player and target expected")
        return M.comboPoints or 0
    end
    -- Other units: d.inCombat. PvP: d.pvp, d.ffa, d.faction.
    _G.UnitAffectingCombat = function(unit)
        if unit == "player" then return M.combat or false end
        local d = u(unit)
        if d and d.inCombat ~= nil then return d.inCombat end
        return false
    end
    -- d.tapDenied; d.playerControlled (players are, creatures not).
    _G.UnitIsTapDenied = function(unit) local d = u(unit); return d and d.tapDenied or false end
    _G.UnitPlayerControlled = function(unit)
        local d = u(unit)
        if not d then return false end
        if d.playerControlled ~= nil then return d.playerControlled end
        return d.isPlayer or false
    end
    _G.UnitIsPVP = function(unit) local d = u(unit); if d and d.pvp ~= nil then return d.pvp end; return false end
    _G.UnitIsPVPFreeForAll = function(unit) local d = u(unit); if d and d.ffa ~= nil then return d.ffa end; return false end
    _G.UnitFactionGroup = function(unit) local d = u(unit); if d then return d.faction, d.faction end end
    _G.UnitPowerType = function(unit) local d = u(unit); return d and d.powerType or 0, d and d.powerToken or "MANA" end
    _G.UnitPowerPercent = function(unit, _, _, curve)
        local d = u(unit); local p = d and d.powerPercent or 0
        if curve then return curve:Evaluate(p) end
        return p
    end
    -- Casts: d.cast / d.channel hold the values UnitCastingInfo /
    -- UnitChannelInfo return, in the client's order; d.castDuration the
    -- object UnitCastingDuration / UnitChannelDuration return.
    _G.UnitCastingInfo = function(unit)
        local d = u(unit); local c = d and d.cast
        if c then return c.name, c.name, c.texture, c.startMs, c.endMs, false, c.castID, c.notInterruptible, 1 end
    end
    _G.UnitChannelInfo = function(unit)
        local d = u(unit); local c = d and d.channel
        if c then return c.name, c.name, c.texture, c.startMs, c.endMs, false, c.notInterruptible, 1 end
    end
    _G.C_DurationUtil = { CreateDuration = function() return { _empty = true } end }
    _G.UnitCastingDuration = function(unit) local d = u(unit); return d and d.castDuration end
    _G.UnitChannelDuration = function(unit) local d = u(unit); return d and d.castDuration end
    _G.C_StringUtil = { TruncateWhenZero = function(n) return n end }
    _G.UnitPowerMissing = function(unit) local d = u(unit); return d and d.powerMissing or 0 end
    -- Shields and heals (UnitDocumentation.lua): the total absorb is never
    -- nil; incoming heals are nil when nothing is known. d.absorbs;
    -- d.healsAll / d.healsMine.
    -- What a unit is (UnitDocumentation.lua): d.classification (default
    -- "normal", never nil) and d.bossMob.
    _G.UnitClassification = function(unit) local d = u(unit); return d and d.classification or "normal" end
    _G.UnitIsBossMob = function(unit) local d = u(unit); return d and d.bossMob or false end
    -- The group (UnitDocumentation.lua: leader and assistant are
    -- SecretWhenUnitIdentityRestricted). d.leader, d.assistant;
    -- M.groupSecret hands both back secret. Ready checks and incoming
    -- resurrections are undocumented globals Blizzard's Mainline frames
    -- call: d.readyCheck ("ready", "notready", "waiting" or nil),
    -- d.incomingRez. M.lfgRestricted: HasLFGRestrictions (a guide leads).
    M.groupSecret = false
    M.lfgRestricted = false
    local function groupFlag(v)
        v = v or false
        if M.groupSecret then return M.Secret(v) end
        return v
    end
    _G.UnitIsGroupLeader = function(unit) local d = u(unit); return groupFlag(d and d.leader) end
    _G.UnitIsGroupAssistant = function(unit) local d = u(unit); return groupFlag(d and d.assistant) end
    -- The loot method (PartyInfoDocumentation.lua, not secret): M.lootMethod
    -- (an Enum.LootMethod value), the master looter by party index
    -- (M.masterLootPartyID, 0 = you) and by raid index (M.masterLooterRaidID).
    M.lootMethod, M.masterLootPartyID, M.masterLooterRaidID = 3, nil, nil
    -- What the addon asks of the group (PartyInfoDocumentation.lua):
    -- M.partyCalls records each call as { name, arguments... }. These
    -- calls have restrictions (HasRestrictions): a name set in
    -- M.partyRefused raises instead, as a restricted call may.
    M.partyCalls, M.partyRefused = {}, {}
    local function record(name)
        return function(...)
            if M.partyRefused[name] then error(name .. ": not allowed") end
            table.insert(M.partyCalls, { name, ... })
            return true
        end
    end
    _G.C_PartyInfo = { GetLootMethod = function() return M.lootMethod, M.masterLootPartyID, M.masterLooterRaidID end,
        DoReadyCheck = record("DoReadyCheck"), SetEveryoneIsAssistant = record("SetEveryoneIsAssistant"),
        ConvertToRaid = record("ConvertToRaid"), ConvertToParty = record("ConvertToParty"),
        SetLootMethod = record("SetLootMethod") }
    _G.InitiateRolePoll = record("InitiateRolePoll")
    -- Everyone an assistant (a global Blizzard's raid manager reads,
    -- Blizzard_CompactRaidFrameManager.lua ~1402, Mainline):
    -- M.everyoneAssistant.
    M.everyoneAssistant = false
    _G.IsEveryoneAssistant = function() return M.everyoneAssistant end
    -- d.offline: the unit's player is disconnected. d.dead / d.ghost:
    -- dead, or a ghost (UnitIsDeadOrGhost is true for both). Any of them
    -- may be a secret proxy.
    _G.UnitIsConnected = function(unit)
        local d = u(unit)
        if d and M.IsSecret(d.offline) then return d.offline end
        return d ~= nil and not d.offline
    end
    _G.UnitIsGhost = function(unit) local d = u(unit); return d and d.ghost or false end
    _G.UnitIsDeadOrGhost = function(unit)
        local d = u(unit)
        if not d then return false end
        if M.IsSecret(d.dead) then return d.dead end
        return (d.dead or d.ghost) and true or false
    end
    -- Range (UnitDocumentation.lua: UnitInRange has SecretReturns).
    -- d.inRange (default true); d.rangeChecked (default: only group
    -- members are checked); M.rangeSecret hands both answers back secret.
    -- CheckInteractDistance: d.near (default true); M.interactError makes
    -- it raise. M.rangeQueries counts UnitInRange calls.
    M.rangeSecret = false
    M.interactError = false
    M.rangeQueries = 0
    local function groupToken(unit) return unit:match("^party%d$") or unit:match("^partypet%d$") end
    -- Threat (UnitDocumentation.lua, ThreatDocumentation.lua): one unit,
    -- d.threat (its highest status, 0..3 or nil); unit and mob,
    -- M.units[mob].threatOf[unit]. Either may be a secret proxy.
    _G.UnitThreatSituation = function(unit, mob)
        if mob then
            local m = u(mob)
            return m and m.threatOf and m.threatOf[unit]
        end
        local d = u(unit)
        return d and d.threat
    end
    -- Detailed threat (the threat bar): M.units[mob].detailed[unit] =
    -- { tanking, status, scaled, raw, value }; any of them may be secret.
    _G.UnitDetailedThreatSituation = function(unit, mob)
        local m = u(mob)
        local d = m and m.detailed and m.detailed[unit]
        if not d then return nil end
        return d[1], d[2], d[3], d[4], d[5]
    end
    -- Roles: d.role ("TANK", "HEALER", "DAMAGER" or nil); the shapeshift
    -- form: M.form.
    _G.UnitGroupRolesAssigned = function(unit) local d = u(unit); return d and d.role or "NONE" end
    _G.GetShapeshiftFormID = function() return M.form end
    M.threatColors = { [0] = { 0.69, 0.69, 0.69 }, { 1, 1, 0.47 }, { 1, 0.6, 0 }, { 1, 0, 0 } }
    _G.GetThreatStatusColor = function(status)
        assert(not M.IsSecret(status), "GetThreatStatusColor: secret status from tainted code")
        local c = assert(M.threatColors[status], "GetThreatStatusColor: bad status")
        return c[1], c[2], c[3]
    end
    -- Two tokens name the same unit when they share its data table.
    _G.UnitIsUnit = function(a, b) return M.units[a] ~= nil and M.units[a] == M.units[b] end
    _G.UnitInParty = function(unit)
        local d = u(unit)
        return d ~= nil and (d.inParty or groupToken(unit) ~= nil) or false
    end
    _G.UnitInRange = function(unit)
        M.rangeQueries = M.rangeQueries + 1
        local d = u(unit)
        local inRange, checked = false, false
        if d then
            inRange = d.inRange ~= false
            if d.inRange == nil and d.distance then inRange = d.distance <= 40 end
            checked = d.rangeChecked
            -- Group members are checked: party and raid tokens.
            if checked == nil then
                checked = groupToken(unit) ~= nil or unit:match("^raid%d+$") ~= nil or d.inParty == true
            end
        end
        if M.rangeSecret == "inRange" then return M.Secret(inRange), checked end
        if M.rangeSecret then return M.Secret(inRange), M.Secret(checked) end
        return inRange, checked
    end
    -- d.near: true, false, or "nil" for no answer. M.interactQueries
    -- counts the calls.
    M.interactQueries = 0
    M.INTERACT_YARDS = { 28, 11, 10, 28, 28 }
    _G.CheckInteractDistance = function(unit, index)
        assert(type(index) == "number" and index >= 1 and index <= 5, "CheckInteractDistance: bad index")
        M.interactQueries = M.interactQueries + 1
        if M.interactError then error("CheckInteractDistance refused") end
        local d = u(unit)
        if d and d.near == "nil" then return nil end
        -- With d.distance: the index's yards (3: 10, 2: 11, 1 and 4: 28).
        if d and d.near == nil and d.distance then return d.distance <= M.INTERACT_YARDS[index] end
        return d ~= nil and d.near ~= false
    end
    -- UnitDistanceSquared (UnitDocumentation.lua, no SecretReturns):
    -- distance squared and whether it was checked. Checked for group
    -- members with a d.distance unless d.distanceChecked says otherwise;
    -- M.distanceSecret hands both back secret; M.distanceQueries counts.
    M.distanceSecret = false
    M.distanceQueries = 0
    _G.UnitDistanceSquared = function(unit)
        M.distanceQueries = M.distanceQueries + 1
        local d = u(unit)
        local dist, checked = 0, false
        if d and type(d.distance) == "number" then
            dist = d.distance * d.distance
            checked = d.distanceChecked
            if checked == nil then checked = groupToken(unit) ~= nil or d.inParty == true end
        end
        if M.distanceSecret then return M.Secret(dist), M.Secret(checked) end
        return dist, checked
    end
    -- Items (ItemDocumentation.lua): C_Item.IsItemInRange gives true,
    -- false or nil, no SecretReturns. M.items[id] = { range=, friendly=,
    -- hostile= } (which units the item is used on); only items whose data
    -- is cached answer (M.itemCached, filled by RequestLoadItemDataByID
    -- unless M.itemLoadStalls). M.itemCombatRestricted: a unit you cannot
    -- attack raises in combat, as on retail. M.itemQueries counts.
    M.items = {
        [8149] = { range = 5, friendly = true, hostile = true },
        [1970] = { range = 5, friendly = true },
        [17626] = { range = 10, friendly = true, hostile = true },
        [21267] = { range = 10, friendly = true },
        [1251] = { range = 15, friendly = true },
        [10645] = { range = 20, hostile = true }, [1191] = { range = 20, hostile = true },
        [21519] = { range = 20, friendly = true },
        [13289] = { range = 25, hostile = true },
        [835] = { range = 30, hostile = true }, [7734] = { range = 30, hostile = true },
        [4941] = { range = 30, hostile = true },
        [1180] = { range = 30, friendly = true }, [954] = { range = 30, friendly = true },
        [18904] = { range = 35, friendly = true, hostile = true },
        [4945] = { range = 40, hostile = true },
        [18662] = { range = 40, friendly = true }, [11562] = { range = 40, friendly = true },
    }
    M.itemCached = {}
    M.bagItems = {}
    M.itemLoadStalls = false
    M.itemCombatRestricted = true
    M.itemQueries = 0
    M.itemLoads = 0
    -- Weapon enchants (ItemDocumentation.lua): M.weaponEnchants[slot] is the
    -- list C_Item.GetWeaponEnchantInfo returns for Enum.WeaponSlot slot.
    M.weaponEnchants = {}
    M.inventoryTextures = { [16] = "MainHandIcon", [17] = "OffHandIcon", [18] = "RangedIcon" }
    _G.GetInventoryItemTexture = function(unit, slot)
        if unit ~= "player" then return nil end
        return M.inventoryTextures[slot]
    end
    _G.C_Item = {
        GetWeaponEnchantInfo = function(slot)
            assert(slot == 0 or slot == 1 or slot == 2, "weaponSlot must be a valid WeaponSlot")
            local list = {}
            for i, e in ipairs(M.weaponEnchants[slot] or {}) do list[i] = e end
            return list
        end,
        -- ItemDocumentation.lua: the count in the bags (M.bagItems[id]).
        GetItemCount = function(item)
            assert(item ~= nil and not M.IsSecret(item), "GetItemCount: itemInfo")
            return M.bagItems[item] or 0
        end,
        IsItemDataCachedByID = function(id) return M.itemCached[id] == true end,
        RequestLoadItemDataByID = function(id)
            M.itemLoads = M.itemLoads + 1
            if not M.itemLoadStalls and M.items[id] then M.itemCached[id] = true end
        end,
        IsItemInRange = function(id, unit)
            M.itemQueries = M.itemQueries + 1
            local item, d = M.items[id], u(unit)
            if not item or not M.itemCached[id] or not d or type(d.distance) ~= "number" then return nil end
            if M.combat and M.itemCombatRestricted and d.hostile ~= true then error("IsItemInRange: restricted") end
            if not (d.hostile == true and item.hostile or d.hostile ~= true and item.friendly) then return nil end
            return d.distance <= item.range
        end,
    }
    -- Hostility (UnitDocumentation.lua: plain bool): d.hostile.
    _G.UnitCanAttack = function(_, unit) local d = u(unit); return d and d.hostile or false end
    -- Spells (SpellDocumentation.lua, SpellBookDocumentation.lua). The
    -- spell book: M.spells[id] = { name=, minRange=, maxRange=, harmful=,
    -- petOnly= } (the client's spell data), M.known[id] = true (what the
    -- player has learned). A name resolves to the highest known rank of
    -- that name, else to its lowest ID, as the client resolves names.
    M.spells = {
        -- Priest
        [2050] = { name = "Lesser Heal", maxRange = 40 }, [2052] = { name = "Lesser Heal", maxRange = 40 },
        [2053] = { name = "Lesser Heal", maxRange = 40 },
        [2054] = { name = "Heal", maxRange = 40 }, [2055] = { name = "Heal", maxRange = 40 },
        [585] = { name = "Smite", maxRange = 30, harmful = true }, [591] = { name = "Smite", maxRange = 30, harmful = true },
        [598] = { name = "Smite", maxRange = 30, harmful = true },
        -- Mage
        [133] = { name = "Fireball", maxRange = 35, harmful = true }, [143] = { name = "Fireball", maxRange = 35, harmful = true },
        [116] = { name = "Frostbolt", maxRange = 30, harmful = true },
        [1459] = { name = "Arcane Intellect", maxRange = 30 },
        -- Hunter
        [75] = { name = "Auto Shot", minRange = 8, maxRange = 35, harmful = true },
        [136] = { name = "Mend Pet", maxRange = 20, petOnly = true }, [3111] = { name = "Mend Pet", maxRange = 20, petOnly = true },
        -- Paladin
        [635] = { name = "Holy Light", maxRange = 40 },
        -- Warrior (melee reach)
        [78] = { name = "Heroic Strike", maxRange = 5, harmful = true },
        -- Group buffs (Raid/BuffData.lua): every rank, single and group form.
        [1243] = { name = "Power Word: Fortitude", maxRange = 30 }, [1244] = { name = "Power Word: Fortitude", maxRange = 30 },
        [1245] = { name = "Power Word: Fortitude", maxRange = 30 }, [2791] = { name = "Power Word: Fortitude", maxRange = 30 },
        [10937] = { name = "Power Word: Fortitude", maxRange = 30 },
        [10938] = { name = "Power Word: Fortitude", maxRange = 30 },
        [21562] = { name = "Prayer of Fortitude", maxRange = 30 }, [21564] = { name = "Prayer of Fortitude", maxRange = 30 },
        [14752] = { name = "Divine Spirit", maxRange = 30 }, [27681] = { name = "Prayer of Spirit", maxRange = 30 },
        [976] = { name = "Shadow Protection", maxRange = 30 }, [27683] = { name = "Prayer of Shadow Protection", maxRange = 30 },
        [1460] = { name = "Arcane Intellect", maxRange = 30 }, [23028] = { name = "Arcane Brilliance", maxRange = 30 },
        [1126] = { name = "Mark of the Wild", maxRange = 30 }, [5232] = { name = "Mark of the Wild", maxRange = 30 },
        [21849] = { name = "Gift of the Wild", maxRange = 30 }, [21850] = { name = "Gift of the Wild", maxRange = 30 },
        [467] = { name = "Thorns", maxRange = 30 },
        [19740] = { name = "Blessing of Might", maxRange = 30 }, [19834] = { name = "Blessing of Might", maxRange = 30 },
        [25782] = { name = "Greater Blessing of Might", maxRange = 30 },
        [19742] = { name = "Blessing of Wisdom", maxRange = 30 }, [25894] = { name = "Greater Blessing of Wisdom", maxRange = 30 },
        [20217] = { name = "Blessing of Kings", maxRange = 30 }, [25898] = { name = "Greater Blessing of Kings", maxRange = 30 },
        -- Not in any class list: a user's own pick.
        [5019] = { name = "Shoot", maxRange = 30, harmful = true },
        [2061] = { name = "Flash Heal", maxRange = 40 },
        -- Heals, heals over time and dispels the raid templates suggest
        -- (Raid/TemplateData.lua).
        [139] = { name = "Renew", maxRange = 40 }, [6074] = { name = "Renew", maxRange = 40 },
        [17] = { name = "Power Word: Shield", maxRange = 40 }, [2060] = { name = "Greater Heal", maxRange = 40 },
        [527] = { name = "Dispel Magic", maxRange = 30 }, [528] = { name = "Cure Disease", maxRange = 30 },
        [552] = { name = "Abolish Disease", maxRange = 30 },
        [774] = { name = "Rejuvenation", maxRange = 40 }, [1058] = { name = "Rejuvenation", maxRange = 40 },
        [8936] = { name = "Regrowth", maxRange = 40 }, [33763] = { name = "Lifebloom", maxRange = 40 },
        [5185] = { name = "Healing Touch", maxRange = 40 }, [2782] = { name = "Remove Curse", maxRange = 40 },
        [8946] = { name = "Cure Poison", maxRange = 40 }, [2893] = { name = "Abolish Poison", maxRange = 40 },
        [19750] = { name = "Flash of Light", maxRange = 40 }, [4987] = { name = "Cleanse", maxRange = 40 },
        [1152] = { name = "Purify", maxRange = 40 },
        [8004] = { name = "Lesser Healing Wave", maxRange = 40 }, [331] = { name = "Healing Wave", maxRange = 40 },
        [1064] = { name = "Chain Heal", maxRange = 40 }, [974] = { name = "Earth Shield", maxRange = 40 },
        [526] = { name = "Cure Poison", maxRange = 30 }, [2870] = { name = "Cure Disease", maxRange = 30 },
        [475] = { name = "Remove Lesser Curse", maxRange = 40 },
    }
    M.known = {}
    -- The player's specialization (SpecializationInfoDocumentation.lua):
    -- GetSpecialization's index (not nilable; 0 here for none), and per
    -- index { id =, name =, role =, points = } for GetSpecializationInfo
    -- (role nilable; pointsSpent, the 7th return, 0 unless given, its
    -- documented default). M.specSecret hands the role back secret
    -- (guarded anyway).
    M.specIndex, M.specs, M.specSecret = 0, {}, false
    _G.C_SpecializationInfo = {
        GetSpecialization = function() return M.specIndex end,
        GetSpecializationInfo = function(index)
            local s = M.specs[index]
            if not s then return 0 end
            local role = s.role
            if M.specSecret then role = M.Secret(role) end
            return s.id, s.name, "", 1, role, 1, s.points or 0, nil, 0, true
        end,
    }
    -- M.spellRangeError makes IsSpellInRange raise; M.spellRangeSecret
    -- hands its answer back secret (not documented, guarded anyway).
    -- M.spellQueries counts the calls.
    M.spellRangeError = false
    M.spellRangeSecret = false
    M.spellQueries = 0
    local function spellID(identifier)
        if type(identifier) == "number" then return M.spells[identifier] and identifier or nil end
        if type(identifier) ~= "string" then return nil end
        local best, lowest
        for id, s in pairs(M.spells) do
            if s.name == identifier then
                if M.known[id] and (not best or id > best) then best = id end
                if not lowest or id < lowest then lowest = id end
            end
        end
        return best or lowest
    end
    M.newSpellInfo = function(id)
        local s = M.spells[id]
        return { name = s.name, spellID = id, iconID = 1, originalIconID = 1, castTime = 0,
            minRange = s.minRange or 0, maxRange = s.maxRange or 0 }
    end
    _G.C_Spell = {
        -- MayReturnNothing: nil when the spell is not found.
        GetSpellInfo = function(identifier)
            local id = spellID(identifier)
            if id then return M.newSpellInfo(id) end
        end,
        -- SpellDocumentation.lua: the name, the icon; nothing for an ID the
        -- client does not know.
        GetSpellName = function(identifier)
            local id = spellID(identifier)
            return id and M.spells[id].name or nil
        end,
        GetSpellTexture = function(identifier)
            local id = spellID(identifier)
            if id then return 100000 + id, 100000 + id end
        end,
        -- true, false, or nil when the check is invalid: unknown spell,
        -- missing target, a target the spell cannot be cast on, a unit
        -- without a known distance (d.distance, yards).
        IsSpellInRange = function(identifier, unit)
            M.spellQueries = M.spellQueries + 1
            if M.spellRangeError then error("IsSpellInRange refused") end
            local id = spellID(identifier)
            if not id or not M.known[id] then return nil end
            local s, d = M.spells[id], unit and u(unit)
            if not d or type(d.distance) ~= "number" then return nil end
            if s.petOnly and unit ~= "pet" then return nil end
            local hostile = d.hostile == true
            if (s.harmful == true) ~= hostile then return nil end
            local inRange = d.distance >= (s.minRange or 0) and d.distance <= s.maxRange
            if M.spellRangeSecret then return M.Secret(inRange) end
            return inRange
        end,
    }
    -- The old globals come from Blizzard_DeprecatedSpellBook (only with
    -- the loadDeprecationFallbacks CVar); a test may remove either side.
    _G.C_SpellBook = { IsSpellKnown = function(id) return M.known[id] == true end }
    -- The spell book (SpellBookDocumentation.lua): skill line 1 holds the
    -- learned spells (M.known) by ID, line 2 those still to learn
    -- (M.futureSpells[id] = true) as FutureSpell items. Every rank is an
    -- item of its own: the client's spell book window only hides the low
    -- ranks. Only the player's bank is modelled; the pet's is empty.
    M.futureSpells = {}
    local function bookLines()
        local learned, future = {}, {}
        for id in pairs(M.known) do if M.spells[id] then learned[#learned + 1] = id end end
        for id in pairs(M.futureSpells) do if M.spells[id] then future[#future + 1] = id end end
        table.sort(learned)
        table.sort(future)
        return { learned, future }
    end
    C_SpellBook.GetNumSpellBookSkillLines = function() return 2 end
    C_SpellBook.GetSpellBookSkillLineInfo = function(index)
        local lines, offset = bookLines(), 0
        if not lines[index] then return nil end
        for i = 1, index - 1 do offset = offset + #lines[i] end
        return { name = index == 1 and "General" or "Class", iconID = 1, itemIndexOffset = offset,
            numSpellBookItems = #lines[index], isGuild = false, shouldHide = false }
    end
    C_SpellBook.GetSpellBookItemInfo = function(slot, bank)
        assert(type(slot) == "number" and type(bank) == "number", "GetSpellBookItemInfo(slot, bank)")
        if bank ~= Enum.SpellBookSpellBank.Player then return nil end
        for i, line in ipairs(bookLines()) do
            local id = line[slot]
            if id then
                return { actionID = id, spellID = id, name = M.spells[id].name, subName = "", iconID = 1,
                    itemType = i == 1 and Enum.SpellBookItemType.Spell or Enum.SpellBookItemType.FutureSpell,
                    isPassive = false, isOffSpec = false, skillLineIndex = i }
            end
            slot = slot - #line
        end
        return nil
    end
    _G.IsPlayerSpell = function(id) return M.known[id] == true end
    -- Casting (protected): only secure code may; M.casts records
    -- { spell, unit } of each cast.
    M.casts = {}
    _G.CastSpellByID = function(id, unit)
        assert(M.secureDepth > 0, "mock: CastSpellByID outside secure code")
        table.insert(M.casts, { id, unit })
    end
    _G.CastSpellByName = function(name, unit)
        assert(M.secureDepth > 0, "mock: CastSpellByName outside secure code")
        table.insert(M.casts, { name, unit })
    end
    _G.IsSpellKnown = function(id) return M.known[id] == true end
    _G.GetReadyCheckStatus = function(unit) local d = u(unit); return d and d.readyCheck end
    _G.UnitHasIncomingResurrection = function(unit) local d = u(unit); return d and d.incomingRez or false end
    _G.HasLFGRestrictions = function() return M.lfgRestricted end
    -- Raid target markers (RaidMarkersDocumentation.lua: SecretReturns):
    -- d.raidTarget (1..8 or nil); M.raidTargetsSecret hands a set index
    -- back secret.
    M.raidTargetsSecret = false
    _G.GetRaidTargetIndex = function(unit)
        local d = u(unit)
        local index = d and d.raidTarget
        if index ~= nil and M.raidTargetsSecret then return M.Secret(index) end
        return index
    end
    -- Setting them (HasRestrictions). Stricter than the client: only secure
    -- code (a secure button's action) may; M.raidTargetCalls records
    -- { unit, index } (index 0 takes the marker off; unit "all":
    -- RemoveRaidTargets).
    M.raidTargetCalls = {}
    _G.SetRaidTarget = function(unit, index)
        assert(M.secureDepth > 0, "mock: SetRaidTarget outside secure code")
        table.insert(M.raidTargetCalls, { unit, index })
        local d = u(unit)
        if d then d.raidTarget = index ~= 0 and index or nil end
    end
    _G.RemoveRaidTargets = function()
        assert(M.secureDepth > 0, "mock: RemoveRaidTargets outside secure code")
        table.insert(M.raidTargetCalls, { "all", 0 })
        for _, d in pairs(M.units) do d.raidTarget = nil end
    end
    -- World markers (RaidMarkersDocumentation.lua; placing and clearing
    -- HasRestrictions, and only secure code may in the mock):
    -- M.worldMarkers[index] is true while one is placed;
    -- M.worldMarkerSystem answers IsRaidMarkerSystemEnabled.
    M.worldMarkers = {}
    M.worldMarkerSystem = true
    _G.IsRaidMarkerSystemEnabled = function() return M.worldMarkerSystem end
    _G.IsRaidMarkerActive = function(index) return M.worldMarkers[index] == true end
    _G.PlaceRaidMarker = function(index)
        assert(M.secureDepth > 0, "mock: PlaceRaidMarker outside secure code")
        assert(type(index) == "number", "PlaceRaidMarker: index")
        M.worldMarkers[index] = true
    end
    _G.ClearRaidMarker = function(index)
        assert(M.secureDepth > 0, "mock: ClearRaidMarker outside secure code")
        if index == nil then M.worldMarkers = {} else M.worldMarkers[index] = nil end
    end
    _G.UnitGetTotalAbsorbs = function(unit) local d = u(unit); return d and d.absorbs or 0 end
    _G.UnitGetIncomingHeals = function(unit, healer)
        local d = u(unit)
        if not d then return nil end
        if healer == "player" then return d.healsMine end
        return d.healsAll
    end

    _G.C_Timer = { After = function(sec, fn) table.insert(M.timers, { sec = sec, fn = fn }) end }

    -- Curves: Evaluate passes secrets through as secrets.
    _G.C_CurveUtil = {
        CreateCurve = function()
            local c = { points = {} }
            function c:SetType(t) self.type = t end
            function c:AddPoint(x, y) table.insert(self.points, { x, y }) end
            function c:Evaluate(x)
                local v = M.Reveal(x)
                local out
                if self.type == Enum.LuaCurveType.Step then
                    -- The last point at or left of x (points added in order).
                    out = self.points[1] and self.points[1][2]
                    for _, p in ipairs(self.points) do if v >= p[1] then out = p[2] end end
                else
                    out = v * 100
                end
                if M.IsSecret(x) then return M.Secret(out) end
                return out
            end
            return c
        end,
        CreateColorCurve = function()
            local c = { points = {} }
            function c:SetType(t) self.type = t end
            function c:AddPoint(x, color) table.insert(self.points, { x, color }) end
            -- A step curve: the colour of the last point at or below x.
            -- Other types stay white (no interpolation in the mock).
            function c:Evaluate(x)
                if self.type ~= Enum.LuaCurveType.Step then
                    return { GetRGB = function() return 1, 1, 1 end }
                end
                local v, found = M.Reveal(x), nil
                for _, p in ipairs(self.points) do
                    if p[1] <= v then found = p[2] end
                end
                local col = found or { r = 1, g = 1, b = 1 }
                return { GetRGB = function() return col.r, col.g, col.b end }
            end
            return c
        end,
    }

    _G.Enum = {
        ClickBindingType = { None = 0, Spell = 1, Macro = 2, Interaction = 3, PetAction = 4 },
        ClickBindingInteraction = { Target = 1, OpenContextMenu = 2 },
        LootMethod = { Freeforall = 0, Roundrobin = 1, Masterlooter = 2, Group = 3, Needbeforegreed = 4, Personal = 5 },
        SpellBookSpellBank = { Player = 0, Pet = 1 },
        SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 },
        StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
        StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
        UITextureSliceMode = { Stretched = 0, Tiled = 1 },
        LuaCurveType = { Linear = 0, Step = 1, Cosine = 2, Cubic = 3 },
        UnitAuraSortRule = { Unsorted = 0, Default = 1, BigDefensive = 2, Expiration = 3, ExpirationOnly = 4,
            Name = 5, NameOnly = 6 },
        CustomAuraButtonDispelTypeTextureStyle = { Border = 0, BorderWithIcon = 1, Icon = 2, PreserveAsset = 3,
            CustomAsset = 4 },
    }

    -- Auras: M.units[unit].auras lists { auraInstanceID, icon, applications,
    -- dispelName, dispelType (the client's number), duration,
    -- expirationTime, isHelpful, mine, dispellable }; any field may be a
    -- secret. M.auraError makes every aura query raise, as the client does
    -- when auras are locked for addons. A secret aura instance ID handed
    -- back to the client raises too (tainted callers may not pass secrets).
    M.auraError = false
    local function refuseAuras()
        if M.auraError then error("Auras cannot be accessed when secret while tainted", 3) end
    end
    local function auraByID(unit, id)
        assert(not M.IsSecret(id), "secret aura instance ID passed back to the client")
        local d = u(unit)
        for _, a in ipairs(d and d.auras or {}) do
            if M.Reveal(a.auraInstanceID) == id then return a end
        end
    end
    -- The value comes back secret when the field it is made from is.
    local function like(field, v)
        if M.IsSecret(field) then return M.Secret(v) end
        return v
    end
    -- Filter strings as the client reads them: "HELPFUL|PLAYER" and so on;
    -- a leading "!" negates a token ("!PLAYER": not cast by the player,
    -- AuraUtil.AuraFilterNegationPrefix). An unknown token raises.
    local FILTER_TOKENS = { HELPFUL = true, HARMFUL = true, PLAYER = true, RAID = true }
    local function auraMatches(a, filter)
        local want = {}
        for token in filter:gmatch("[^|]+") do
            local negated = token:sub(1, 1) == "!"
            if negated then token = token:sub(2) end
            if not FILTER_TOKENS[token] then error("Unknown aura filter component: " .. token, 3) end
            want[token] = not negated
        end
        local helpful = M.Reveal(a.isHelpful) == true
        local has = { HELPFUL = helpful, HARMFUL = not helpful, PLAYER = M.Reveal(a.mine) == true,
            RAID = M.Reveal(a.dispellable) == true }
        for token, on in pairs(want) do
            if has[token] ~= on then return false end
        end
        return true
    end
    M.auraQueries = 0      -- GetUnitAuras calls
    M.lastAuraQuery = nil  -- { unit, filter, maxCount, sortRule } of the last one
    M.auraQueryLog = {}    -- the filter of every GetUnitAuras call, in order
    M.auraLookups = 0      -- GetAuraDataByAuraInstanceID calls
    M.auraNameQueries = 0  -- GetAuraDataBySpellName calls
    -- C_Secrets (SecretPredicateAPIDocumentation.lua): auras are secret in
    -- combat or while M.aurasSecret; a spell's aura while
    -- M.secretSpellAuras[id].
    M.secretSpellAuras = {}
    _G.C_Secrets = {
        ShouldAurasBeSecret = function() return M.AurasSecret() == true end,
        ShouldSpellAuraBeSecret = function(id)
            assert(type(id) == "number" or type(id) == "string", "ShouldSpellAuraBeSecret: spellIdentifier")
            return M.AurasSecret() == true or M.secretSpellAuras[id] == true
        end,
    }
    _G.C_UnitAuras = {
        GetAuraDataByAuraInstanceID = function(unit, id)
            refuseAuras()
            M.auraLookups = M.auraLookups + 1
            return auraByID(unit, id)
        end,
        IsAuraFilteredOutByInstanceID = function(unit, id, filter)
            refuseAuras()
            local a = auraByID(unit, id)
            return not (a and auraMatches(a, filter))
        end,
        GetUnitAuras = function(unit, filter, maxCount, sortRule)
            refuseAuras()
            M.auraQueries = M.auraQueries + 1
            M.lastAuraQuery = { unit = unit, filter = filter, maxCount = maxCount, sortRule = sortRule }
            M.auraQueryLog[#M.auraQueryLog + 1] = filter
            local d, list = u(unit), {}
            for _, a in ipairs(d and d.auras or {}) do
                if auraMatches(a, filter) and (not maxCount or #list < maxCount) then list[#list + 1] = a end
            end
            return list
        end,
        -- The first aura of that name (d.auras[i].name; filter as
        -- GetUnitAuras'). UnitAuraDocumentation.lua marks it
        -- SecretWhenUnitAuraRestricted and RequiresNonSecretAura without
        -- saying how either shows; the mock takes the strict reading of
        -- both: while auras are restricted (M.AurasSecret()) the answer is
        -- secret whether or not the aura is there (its presence is not
        -- told either); an aura whose spell is secret
        -- (M.secretSpellAuras[spellId]) makes the call raise.
        GetAuraDataBySpellName = function(unit, name, filter)
            refuseAuras()
            assert(type(name) == "string" and not M.IsSecret(name), "GetAuraDataBySpellName: spellName")
            M.auraNameQueries = M.auraNameQueries + 1
            local d, found = u(unit), nil
            for _, a in ipairs(d and d.auras or {}) do
                if M.Reveal(a.name) == name and auraMatches(a, filter or "HELPFUL") then
                    found = a
                    break
                end
            end
            if M.AurasSecret() then return M.Secret(found) end
            if found and M.secretSpellAuras[M.Reveal(found.spellId)] then
                error("GetAuraDataBySpellName: the aura is secret", 2)
            end
            return found
        end,
        GetAuraDuration = function(unit, id)
            refuseAuras()
            local a = auraByID(unit, id)
            if a then return { _duration = a.duration, _expires = a.expirationTime } end
        end,
        GetAuraApplicationDisplayCount = function(unit, id, minCount)
            refuseAuras()
            local a = auraByID(unit, id)
            if not a then return end
            local n = M.Reveal(a.applications) or 0
            return like(a.applications, n >= (minCount or 2) and tostring(n) or "")
        end,
        -- The colour of the curve point at the aura's dispel type (step
        -- curves: the last point at or below it).
        GetAuraDispelTypeColor = function(unit, id, curve)
            refuseAuras()
            local a = auraByID(unit, id)
            local x = M.Reveal(a.dispelType) or 0
            local color
            for _, p in ipairs(curve.points) do
                if p[1] <= x then color = p[2] end
            end
            local r, g, b, alpha = color.r, color.g, color.b, color.a or 1
            return { GetRGBA = function()
                return like(a.dispelType, r), like(a.dispelType, g), like(a.dispelType, b), like(a.dispelType, alpha)
            end }
        end,
    }

    -- Tooltip: M.tooltipAura records the last aura tooltip asked for.
    M.tooltipAura = nil
    _G.GameTooltip = newWidget("GameTooltip", "GameTooltip")
    GameTooltip._shown = false
    function GameTooltip:SetOwner(owner, anchor) self._owner, self._anchor = owner, anchor end
    function GameTooltip:IsOwned(f) return self._owner == f end
    function GameTooltip:Hide() self._shown = false; self._owner = nil end
    -- Unit tooltips (M.tooltipUnit: the last unit asked for).
    M.tooltipUnit = nil
    function GameTooltip:SetUnit(unit)
        M.tooltipUnit = unit
        self._shown = true
        return true
    end
    function GameTooltip:Show() self._shown = true end
    M.tooltipLines = {}
    function GameTooltip:SetText(text) M.tooltipLines = { text }; self._shown = true end
    function GameTooltip:AddLine(text) M.tooltipLines[#M.tooltipLines + 1] = text end
    -- Totem tooltips (M.tooltipTotem: the last slot asked for).
    M.tooltipTotem = nil
    function GameTooltip:SetTotem(slot)
        assert(not M.IsSecret(slot), "secret totem slot passed to the tooltip")
        M.tooltipTotem = slot
        self._shown = true
    end
    function GameTooltip:FadeOut() self._shown = false end
    -- Text lines of the tooltip since the last SetOwner.
    M.tooltipLines = {}
    local setOwner = GameTooltip.SetOwner
    function GameTooltip:SetOwner(owner, anchor)
        -- The client refuses an owner with the untrusted-layout aspect: the
        -- tooltip, anchored to it, would inherit it.
        if M.HasLayoutAspect(owner) then
            error("GameTooltip:SetOwner(): Anchoring disallowed as dependent object would inherit forbidden aspects: UntrustedLayoutScriptExecution", 2)
        end
        M.tooltipLines = {}
        setOwner(self, owner, anchor)
    end
    function GameTooltip:SetText(text) M.tooltipLines = { text } end
    function GameTooltip:AddLine(text) M.tooltipLines[#M.tooltipLines + 1] = text end

    -- The minimap: 140 x 140 around (1700, 900) at scale 1. GetMinimapShape
    -- exists only when a minimap addon defines it (M.minimapShape).
    _G.Minimap = newWidget("Frame", "Minimap")
    Minimap._w, Minimap._h, Minimap._cx, Minimap._cy = 140, 140, 1700, 900
    M.minimapShape = nil
    _G.GetMinimapShape = nil
    -- The cursor in physical coordinates (GetCursorPosition).
    M.cursor = { 0, 0 }
    _G.GetCursorPosition = function() return M.cursor[1], M.cursor[2] end
    _G.LibStub = nil
    -- Blizzard's addon compartment (Blizzard_Minimap/Mainline/
    -- AddonCompartment.lua, loaded on this game type too): besides the
    -- TOC's entries, addons may add their own with RegisterAddon({ text,
    -- icon, func, funcOnEnter, funcOnLeave }).
    _G.AddonCompartmentFrame = newWidget("Frame", "AddonCompartmentFrame")
    AddonCompartmentFrame.registeredAddons = {}
    function AddonCompartmentFrame:RegisterAddon(data)
        table.insert(self.registeredAddons, data)
    end
    local function auraTooltip(method)
        GameTooltip[method] = function(self, unit, id, filter)
            refuseAuras()
            assert(not M.IsSecret(id), "secret aura instance ID passed to the tooltip")
            M.tooltipAura = { method = method, unit = unit, id = id, filter = filter }
            self._shown = true
        end
    end
    auraTooltip("SetUnitBuffByAuraInstanceID")
    auraTooltip("SetUnitDebuffByAuraInstanceID")

    -- Totems (Blizzard_FrameXMLBase/Constants.lua, TotemDocumentation.lua).
    -- M.totems[slot] = { name, start, duration, icon, spellID } for a slot
    -- that holds a totem. M.totemsSecret: every GetTotemInfo value comes
    -- back secret (SecretWhenTotemSlotSecret: combat, encounter, challenge
    -- mode or PvP match restrictions). GetTotemDuration's duration object
    -- is never secret itself. DestroyTotem is only reached through secure
    -- code (M.SecureClick); M.destroyedTotems lists the slots.
    M.totems = {}
    M.totemsSecret = false
    M.destroyedTotems = {}
    _G.MAX_TOTEMS = 4
    _G.FIRE_TOTEM_SLOT, _G.EARTH_TOTEM_SLOT, _G.WATER_TOTEM_SLOT, _G.AIR_TOTEM_SLOT = 1, 2, 3, 4
    _G.STANDARD_TOTEM_PRIORITIES = { 1, 2, 3, 4 }
    _G.SHAMAN_TOTEM_PRIORITIES = { EARTH_TOTEM_SLOT, FIRE_TOTEM_SLOT, WATER_TOTEM_SLOT, AIR_TOTEM_SLOT }
    local function validSlot(slot)
        assert(not M.IsSecret(slot), "secret totem slot passed back to the client")
        return type(slot) == "number" and slot >= 1 and slot <= MAX_TOTEMS
    end
    -- haveTotem, totemName, startTime, duration, icon, modRate, spellID;
    -- nothing for a slot that does not exist (MayReturnNothing).
    _G.GetTotemInfo = function(slot)
        if not validSlot(slot) then return end
        local t = M.totems[slot]
        local r
        if t then
            r = { true, t.name or "Totem", t.start or 0, t.duration or 0, t.icon or 0, 1, t.spellID or 0 }
        else
            r = { false, "", 0, 0, 0, 1, 0 }
        end
        if M.totemsSecret then
            for i = 1, #r do r[i] = M.Secret(r[i]) end
        end
        return unpack(r)
    end
    _G.GetTotemDuration = function(slot)
        assert(validSlot(slot), "GetTotemDuration: bad slot")
        local t = M.totems[slot]
        return { _start = t and t.start or 0, _duration = t and t.duration or 0 }
    end
    _G.DestroyTotem = function(slot)
        assert(M.secureDepth > 0, "DestroyTotem is protected: only secure code may call it")
        assert(validSlot(slot), "DestroyTotem: bad slot")
        M.destroyedTotems[#M.destroyedTotems + 1] = slot
        M.totems[slot] = nil
    end

    -- CVars
    _G.C_CVar = {
        RegisterCVar = function(name, default) if M.cvars[name] == nil then M.cvars[name] = default or "" end end,
        GetCVar = function(name) return M.cvars[name] end,
        SetCVar = function(name, v) M.cvars[name] = v; return true end,
    }
    -- GetCVarBool: "1" is true. ActionButtonUseKeyDown is on by default
    -- (M.Reset).
    _G.GetCVarBool = function(name) local v = M.cvars[name]; return v == "1" or v == true end

    -- Macros (character macros live at indices MAX_ACCOUNT_MACROS + 1 ...)
    _G.GetMacroIndexByName = function(name)
        for i, m in ipairs(M.macros) do if m.name == name then return 120 + i end end
        return 0
    end
    -- A body that went through the server comes back from a later session
    -- with a line break appended, and the macro cache uses CRLF line endings
    -- (measured in the client); the client may then cut the body to 255
    -- characters. M.RoundTripMacros simulates that.
    _G.GetMacroBody = function(index)
        local m = M.macros[index - 120]
        if not m then return nil end
        local body = m.body
        if m.crlf then body = body:gsub("\n", "\r\n") end
        body = body .. (m.trailer or "")
        -- What comes back from the server may be cut to the body limit
        -- after the line break was appended.
        if m.trailer or m.crlf then body = body:sub(1, 255) end
        return body
    end
    -- The addon never writes macros: any attempt is counted and fails.
    _G.CreateMacro = function()
        M.macroWrites = M.macroWrites + 1
        error("the addon must not create macros")
    end
    _G.EditMacro = function()
        M.macroWrites = M.macroWrites + 1
        error("the addon must not edit macros")
    end
    -- Deleting shifts the indices of every macro after it, as in the client.
    _G.DeleteMacro = function(index)
        assert(not M.combat, "DeleteMacro in combat")
        assert(M.macros[index - 120], "DeleteMacro: no macro at " .. tostring(index))
        M.macroDeletes = M.macroDeletes + 1
        table.remove(M.macros, index - 120)
    end

    _G.SlashCmdList = {}
    _G.UISpecialFrames = {}
    -- C_AddOns.GetAddOnMetadata(name, field): a field of an addon's TOC.
    -- The mock knows one: this addon's ## Version (M.addonVersion; tests
    -- set another before PLAYER_LOGIN); any other field or addon is nil.
    M.addonVersion = "0.1.0"
    -- Blizzard_Menu (Menu.lua): Menu.ModifyMenu(tag, callback) adds to
    -- every menu opened with that tag; M.menuMods[tag] lists the callbacks.
    -- Not modelled: when a menu with that tag was generated before, the
    -- client calls the callback at once with the last description for it
    -- (Menu.lua ~2725-2734); the addon registers at load, before any menu.
    -- M.menu is the last unit menu opened (M.OpenUnitMenu, or a click on a
    -- button whose type is togglemenu).
    M.menuMods = {}
    M.menu = nil
    _G.Menu = {
        ModifyMenu = function(tag, callback)
            assert(type(tag) == "string", "Menu.ModifyMenu: tag must be a string")
            assert(type(callback) == "function", "Menu.ModifyMenu: callback must be a function")
            M.menuMods[tag] = M.menuMods[tag] or {}
            table.insert(M.menuMods[tag], callback)
            return {}
        end,
    }
    -- UnitInRaid: the raid index of a raid member (d.raidIndex, or the
    -- number of a raid token), else nil.
    _G.UnitInRaid = function(unit)
        local d = u(unit)
        if not d then return nil end
        if d.raidIndex then return d.raidIndex end
        local index = tonumber(tostring(unit):match("^raid(%d+)$"))
        if index and M.raid[index] then return index end
        return nil
    end
    _G.UnitIsOtherPlayersPet = function(unit) local d = u(unit); return d ~= nil and d.otherPet == true end
    _G.UnitIsOtherPlayersBattlePet = function() return false end
    -- MenuUtil.CreateContextMenu(owner, generator): a menu of the addon's
    -- own, recorded in M.menu.
    _G.MenuUtil = {
        CreateContextMenu = function(owner, generator)
            assert(type(generator) == "function", "CreateContextMenu: generator")
            local root = M.NewMenuDescription("context", { ownerFrame = owner })
            generator(owner, root)
            M.menu = root
            return root
        end,
    }
    -- C_AddOns.IsAddOnLoaded(name) -> loadedOrLoading, loaded
    -- (AddOnsDocumentation.lua): the addons in M.loadedAddons (name ->
    -- true), this one always.
    M.loadedAddons = {}
    _G.C_AddOns = { GetAddOnMetadata = function(name, field)
        assert(name ~= nil and type(field) == "string", "GetAddOnMetadata: name and field required")
        if name == "ForeverUnitFrames" and field == "Version" then return M.addonVersion end
        return nil
    end, IsAddOnLoaded = function(name)
        assert(name ~= nil, "IsAddOnLoaded: name required")
        local loaded = name == "ForeverUnitFrames" or M.loadedAddons[name] == true
        return loaded, loaded
    end }
    -- Post-hook: the original runs first, then fn with the same arguments.
    _G.hooksecurefunc = function(tbl, name, fn)
        if type(tbl) == "string" then tbl, name, fn = _G, tbl, name end
        local original = tbl[name]
        tbl[name] = function(...)
            local r = { original(...) }
            fn(...)
            return unpack(r)
        end
    end

    -- Key bindings: M.bindings (key -> action, the player's own; ESC opens
    -- the game menu, W moves forward), and the override bindings of each
    -- owner frame (M.overrides[owner][key] = "CLICK name:button"), which
    -- win over the player's. GetBindingAction(key, checkOverride): the
    -- action, "" for none. Setting or clearing an override is protected:
    -- refused in combat (ADDON_ACTION_BLOCKED), as in the client.
    M.bindings = { ESCAPE = "TOGGLEGAMEMENU", W = "MOVEFORWARD" }
    M.overrides = {}
    local function overridden(key)
        for _, keys in pairs(M.overrides) do
            if keys[key] then return keys[key] end
        end
    end
    _G.GetBindingFromClick = function(key)
        return overridden(key) or M.bindings[key]
    end
    _G.GetBindingAction = function(key, checkOverride)
        assert(type(key) == "string", "GetBindingAction: key required")
        return (checkOverride and overridden(key)) or M.bindings[key] or ""
    end
    local function protectedBinding(name)
        if M.combat and M.secureDepth == 0 then
            M.blocked[#M.blocked + 1] = name
            error("mock: " .. name .. " in combat", 3)
        end
    end
    _G.SetOverrideBindingClick = function(owner, isPriority, key, buttonName, mouseButton)
        protectedBinding("SetOverrideBindingClick")
        assert(type(owner) == "table" and type(key) == "string" and type(buttonName) == "string",
            "SetOverrideBindingClick(owner, isPriority, key, buttonName[, mouseButton])")
        M.overrides[owner] = M.overrides[owner] or {}
        M.overrides[owner][key] = "CLICK " .. buttonName .. ":" .. (mouseButton or "LeftButton")
    end
    _G.ClearOverrideBindings = function(owner)
        protectedBinding("ClearOverrideBindings")
        M.overrides[owner] = nil
    end

    -- Colour picker. Like the client, opening it sets the wheel colour, which
    -- fires OnColorSelect -> swatchFunc/opacityFunc before the alpha is set.
    M.colorPicker = nil
    M.pickRGB, M.pickA = { 1, 1, 1 }, 1
    _G.ColorPickerFrame = newWidget("Frame", "ColorPickerFrame")
    _G.ColorPickerFrame._shown = false
    function ColorPickerFrame:SetupColorPickerAndShow(info)
        M.colorPicker = info
        self.swatchFunc, self.opacityFunc, self.cancelFunc = info.swatchFunc, info.opacityFunc, info.cancelFunc
        info.previousValues = { r = info.r, g = info.g, b = info.b, a = info.opacity }
        M.pickRGB = { info.r, info.g, info.b }
        if info.swatchFunc then info.swatchFunc() end
        if info.opacityFunc then info.opacityFunc() end
        self:Show()
    end
    function ColorPickerFrame:GetColorRGB() return M.pickRGB[1], M.pickRGB[2], M.pickRGB[3] end
    function ColorPickerFrame:GetColorAlpha() return M.pickA end
    function ColorPickerFrame:GetPreviousValues()
        local p = M.colorPicker.previousValues
        return p.r, p.g, p.b, p.a
    end
end

-- Presses a key: the frame gets OnKeyDown only while it takes keyboard
-- input. Returns whether the key went on to the game (propagated).
function M.PressKey(frame, key)
    if not frame._keyboard or not frame:IsShown() then return true end
    local handler = frame._scripts.OnKeyDown
    if handler then handler(frame, key) end
    return frame._propagate or false
end

-- The macros as a later session reads them: every body gets `trailer`
-- appended (and CRLF line endings if `crlf`).
function M.RoundTripMacros(trailer, crlf)
    for _, m in ipairs(M.macros) do
        m.trailer = (m.trailer or "") .. (trailer or "")
        m.crlf = m.crlf or crlf or nil
    end
end

-- An old settings backup as versions up to 0.2.x left it: character macros
-- "FUF Save 1".."FUF Save n", each "#Forever Unit Frames backup i/n - keep"
-- plus one chunk of the encoded profile. `chunks` is a string (one macro)
-- or a list of strings. Returns a new macro list.
function M.BackupMacros(chunks)
    if type(chunks) == "string" then chunks = { chunks } end
    local list = {}
    for i, chunk in ipairs(chunks) do
        list[i] = { name = "FUF Save " .. i, icon = "INV_MISC_QUESTIONMARK", perChar = true,
            body = ("#Forever Unit Frames backup %d/%d - keep\n"):format(i, #chunks) .. chunk }
    end
    return list
end

-- Blizzard's macro window (load-on-demand in the client). Shown state is
-- driven by M.macroFrameShown; tests call its OnHide script to close it.
function M.NewMacroFrame()
    local f = newWidget("Frame", "MacroFrame")
    function f:IsShown() return M.macroFrameShown end
    return f
end

-- Joins or leaves a party: M.SetGroup({ "party1", "party2" }) or M.SetGroup({}).
-- The client always names the other members party1..n without gaps; a
-- list with a gap (a few older tests use { "party2" }) is a party the
-- client never shows, kept for those tests' own purposes.
function M.SetGroup(units)
    M.group = units
    M.SetRaid(M.inRaid)
    M.FireEvent("GROUP_ROSTER_UPDATE")
end

-- Joins a raid: members[i] = { name =, class = (token), subgroup =,
-- assignedRole = (TANK, HEALER, DAMAGER or NONE; default NONE), role =
-- (MAINTANK, MAINASSIST or nil), unit = { more unit data } } is unit
-- raid<i>, with its unit data. An empty list leaves the raid. Visibility
-- drivers follow, then GROUP_ROSTER_UPDATE fires.
function M.SetRaidRoster(members)
    M.raid = members
    for token in pairs(M.units) do
        if token:match("^raid%d+$") then M.units[token] = nil end
    end
    for i, m in ipairs(members) do
        local u = { name = m.name, class = m.class, className = m.class, isPlayer = true,
            role = m.assignedRole or "NONE", health = 100, healthMax = 100 }
        for k, v in pairs(m.unit or {}) do u[k] = v end
        M.units["raid" .. i] = u
    end
    M.raidMembers = #members
    M.SetRaid(#members > 0)
    M.FireEvent("GROUP_ROSTER_UPDATE")
end

-- Every playing animation group runs to its end: the animated frame takes
-- the last alpha (SetToFinalAlpha), then OnFinished runs.
function M.FinishAnimations()
    local groups = M.playing
    M.playing = {}
    for group in pairs(groups) do
        group._playing = false
        local last = group._anims[#group._anims]
        if group._toFinal and last then group:GetParent():SetAlpha(last._to) end
        local done = group:GetScript("OnFinished")
        if done then done(group) end
    end
end

-- A mouse click on a secure button, reduced to what the addon uses
-- (Blizzard_FrameXML/SecureTemplates.lua): a mouse press acts on the
-- stroke the button registered; the action is the modified attribute
-- "type" for the held modifiers and the mouse button (looked up as
-- prefix..name..suffix, *name..suffix, prefix..name*, *name*, name), run
-- as secure code; a unit button asks Blizzard's click bindings first
-- (SecureUnitButton_OnClick). Returns the action type, or nil.
local BUTTON_SUFFIX = { LeftButton = "1", RightButton = "2", MiddleButton = "3" }

-- A menu's root description (Blizzard_Menu): the elements added to it,
-- in order, as { kind = "button" | "title" | "divider" | "radio", text =,
-- callback =, data = } (a radio: isSelected, setSelected). Stricter than
-- the client: no other method.
local function menuDescription(tag, contextData)
    local root = { tag = tag, contextData = contextData, elements = {} }
    local methods = {
        CreateButton = function(self, text, callback, data)
            assert(type(text) == "string", "CreateButton: text")
            local e = { kind = "button", text = text, callback = callback, data = data }
            table.insert(self.elements, e)
            return e
        end,
        CreateTitle = function(self, text)
            local e = { kind = "title", text = text }
            table.insert(self.elements, e)
            return e
        end,
        CreateDivider = function(self)
            local e = { kind = "divider" }
            table.insert(self.elements, e)
            return e
        end,
        CreateRadio = function(self, text, isSelected, setSelected, data)
            assert(type(text) == "string", "CreateRadio: text")
            assert(type(isSelected) == "function" and type(setSelected) == "function", "CreateRadio: functions")
            local e = { kind = "radio", text = text, isSelected = isSelected, setSelected = setSelected, data = data }
            table.insert(self.elements, e)
            return e
        end,
    }
    return setmetatable(root, { __index = function(_, k)
        return methods[k] or error("mock: menu description has no " .. tostring(k), 2)
    end })
end

M.NewMenuDescription = menuDescription

-- UnitPopup_OpenMenu (Blizzard_UnitPopupShared/UnitPopupShared.lua): the
-- unit menu "which", tagged MENU_UNIT_<which>; the mock holds none of
-- Blizzard's own entries, only what Menu.ModifyMenu callbacks add. An
-- addon's callback is the addon's own (insecure) code, also when the menu
-- was opened from a secure click.
function M.OpenUnitMenu(which, contextData)
    local tag = "MENU_UNIT_" .. which
    local root = menuDescription(tag, contextData)
    local depth = M.secureDepth
    M.secureDepth = 0
    for _, callback in ipairs(M.menuMods[tag] or {}) do
        local ok, err = pcall(callback, contextData.ownerFrame, root, contextData)
        if not ok then
            M.secureDepth = depth
            error(err, 0)
        end
    end
    M.secureDepth = depth
    M.menu = root
    return root
end

-- A click on a menu button: its callback with its data; on a radio, its
-- setSelected.
function M.ClickMenu(element)
    assert(element and (element.kind == "button" or element.kind == "radio"), "mock: not a menu button")
    if element.kind == "radio" then return element.setSelected(element.data) end
    return element.callback(element.data)
end

-- A radio's state: its isSelected for its data.
function M.MenuSelected(element)
    return element.isSelected(element.data)
end

-- SECURE_ACTIONS.togglemenu (Blizzard_FrameXML/SecureTemplates.lua): the
-- menu for the button's unit, chosen as the client does.
local function toggleMenu(button, attr)
    local unit = attr("unit")
    if not unit then return end
    unit = unit:lower()
    local unitType = unit:match("^([a-z]+)[0-9]+$") or unit
    local which
    if unitType == "party" then which = "PARTY"
    elseif unitType == "boss" then which = "BOSS"
    elseif unitType == "focus" then which = "FOCUS"
    elseif unitType == "arenapet" or unitType == "arena" then which = "ARENAENEMY"
    elseif UnitIsUnit(unit, "player") then which = "SELF"
    elseif UnitIsUnit(unit, "vehicle") then which = "VEHICLE"
    elseif UnitIsUnit(unit, "pet") then which = "PET"
    elseif UnitIsOtherPlayersBattlePet(unit) then which = "OTHERBATTLEPET"
    elseif UnitIsOtherPlayersPet(unit) then which = "OTHERPET"
    elseif UnitIsPlayer(unit) then
        if UnitInRaid(unit) then which = "RAID_PLAYER"
        elseif UnitInParty(unit) then which = "PARTY"
        else which = "PLAYER" end
    elseif UnitIsUnit(unit, "target") then which = "TARGET" end
    if which then M.OpenUnitMenu(which, { ownerFrame = button, unit = unit }) end
end

local SECURE_ACTIONS = {
    -- SECURE_ACTIONS.spell: a number is a spell ID, else a name.
    spell = function(_, attr)
        local spell, unit = attr("spell"), attr("unit")
        local id = tonumber(spell)
        if id then
            CastSpellByID(id, unit)
        elseif spell then
            CastSpellByName(spell, unit)
        end
    end,
    destroytotem = function(button, attr) DestroyTotem(attr("totem-slot")) end,
    togglemenu = toggleMenu,
    -- SECURE_ACTIONS.raidtarget.
    raidtarget = function(_, attr)
        local marker = tonumber(attr("marker"))
        local action = attr("action") or "toggle"
        local unit = attr("unit") or "target"
        marker = marker or 1
        if action == "set" and GetRaidTargetIndex(unit) ~= marker then
            SetRaidTarget(unit, marker)
        elseif action == "set-unmarked" and GetRaidTargetIndex(unit) == nil then
            SetRaidTarget(unit, marker)
        elseif action == "clear" then
            SetRaidTarget(unit, 0)
        elseif action == "clear-all" then
            RemoveRaidTargets()
        elseif action == "toggle" then
            if GetRaidTargetIndex(unit) == marker then SetRaidTarget(unit, 0) else SetRaidTarget(unit, marker) end
        end
    end,
    -- SECURE_ACTIONS.worldmarker.
    worldmarker = function(_, attr)
        local marker = tonumber(attr("marker"))
        local action = attr("action") or "toggle"
        if action == "set" then
            PlaceRaidMarker(marker or 1)
        elseif action == "clear" then
            ClearRaidMarker(marker)
        elseif action == "toggle" then
            marker = marker or 1
            if IsRaidMarkerActive(marker) then ClearRaidMarker(marker) else PlaceRaidMarker(marker) end
        end
    end,
}
-- Whether the button takes this stroke (RegisterForClicks).
local function takesStroke(button, mouseButton, down)
    local stroke = down and "Down" or "Up"
    for _, c in ipairs(button._clicks or {}) do
        if c == "Any" .. stroke or c == mouseButton .. stroke then return true end
    end
    return false
end
-- GetCVarBool("ActionButtonUseKeyDown"), or the button's useOnKeyDown.
local function useOnKeyDown(button)
    local v = button._attr.useOnKeyDown
    if v == nil then v = GetCVarBool("ActionButtonUseKeyDown") end
    return v or button._attr.pressAndHoldAction ~= nil
end
-- SecureButton_GetModifierPrefix: the held modifiers, alt- before ctrl-
-- before shift- (the "modifiers" attribute is not modelled).
local function modifierPrefix()
    local prefix = ""
    if IsShiftKeyDown() then prefix = "shift-" .. prefix end
    if IsControlKeyDown() then prefix = "ctrl-" .. prefix end
    if IsAltKeyDown() then prefix = "alt-" .. prefix end
    return prefix
end
-- The templates that inherit SecureUnitButtonTemplate in the addon's XML
-- (test_raid_click_gate.lua checks the XML says so).
M.UNIT_BUTTON_TEMPLATES = { SecureUnitButtonTemplate = true, ForeverUnitFramesRaidButtonTemplate = true,
    ForeverUnitFramesPartyButtonTemplate = true, ForeverUnitFramesPartyPetButtonTemplate = true }
-- One stroke's OnClick: the type it ran, or nil.
local function secureStroke(button, mouseButton, down)
    local prefix = modifierPrefix()
    local suffix
    -- Frame:GetAttribute(prefix, name, suffix) as SecureButton_
    -- GetModifiedAttribute uses it.
    local function attr(name)
        for _, k in ipairs({ prefix .. name .. suffix, "*" .. name .. suffix, prefix .. name .. "*",
            "*" .. name .. "*", name }) do
            local v = button._attr[k]
            if v ~= nil then return v end
        end
        return nil
    end
    -- SecureButton_GetButtonSuffix.
    local function suffixOf(b)
        return BUTTON_SUFFIX[b] or (b:match("^Button(%d+)$")) or (b ~= "" and "-" .. b) or ""
    end
    suffix = suffixOf(mouseButton)
    if M.UNIT_BUTTON_TEMPLATES[button._template] then
        -- SecureUnitButton_OnClick: Blizzard's click bindings first. A
        -- spell, macro or pet action bound there runs instead; target and
        -- the menu need the click to be bound to an interaction (the
        -- default profile: plain left and right only), else nothing.
        local modifiers = MakeModifiers()
        local bindingType = C_ClickBindings.GetBindingType(mouseButton, modifiers)
        if bindingType == Enum.ClickBindingType.Spell or bindingType == Enum.ClickBindingType.Macro
            or bindingType == Enum.ClickBindingType.PetAction then
            C_ClickBindings.ExecuteBinding(attr("unit") or "", mouseButton, modifiers)
            return "clickbinding"
        end
        if bindingType == Enum.ClickBindingType.Interaction then
            suffix = suffixOf(C_ClickBindings.GetEffectiveInteractionButton(mouseButton, modifiers))
        end
        local kind = attr("type")
        if (kind == "target" or kind == "menu" or kind == "togglemenu")
            and bindingType == Enum.ClickBindingType.None then
            return nil
        end
    end
    if button._template == "SecureActionButtonTemplate" then
        -- SecureActionButton_OnClick: an addon's button never gets
        -- isSecureAction, so the down stroke acts while the player uses
        -- keys on the down stroke (CVar ActionButtonUseKeyDown, on by
        -- default), else the up stroke; the other one does nothing.
        if down ~= (useOnKeyDown(button) and true or false) then return nil end
        -- GetConvertedButtonUnitAndActionType: a unit that does not exist
        -- stops the click.
        local unit = attr("unit")
        if unit and unit ~= "none" and not UnitExists(unit) then return nil end
    end
    local kind = attr("type")
    local action = kind and SECURE_ACTIONS[kind]
    if action then
        M.secureDepth = M.secureDepth + 1
        local ok, err = pcall(action, button, attr)
        M.secureDepth = M.secureDepth - 1
        if not ok then error(err, 0) end
    end
    return kind
end
-- A mouse click: the down stroke, then the up stroke, each one the button
-- is registered for (RegisterForClicks). Returns the type that ran (the
-- last one, if both strokes ran one), or nil.
function M.SecureClick(button, mouseButton)
    if not button:IsVisible() or button._mouse == false then return nil end
    local ran
    for _, down in ipairs({ true, false }) do
        if takesStroke(button, mouseButton, down) then
            ran = secureStroke(button, mouseButton, down) or ran
        end
    end
    return ran
end

-- A key with an override binding "CLICK name:button" (SetOverrideBindingClick)
-- pressed and let go: the button's click, each stroke it is registered
-- for; the mouse need not be on it. Stricter than the client: the button
-- must be visible. Returns the type that ran, or nil.
function M.PressBinding(key)
    local name, mouseButton = GetBindingAction(key, true):match("^CLICK ([^:]+):(.+)$")
    local button = name and rawget(_G, name)
    if not button or not button:IsVisible() then return nil end
    local ran
    for _, down in ipairs({ true, false }) do
        if takesStroke(button, mouseButton, down) then
            ran = secureStroke(button, mouseButton, down) or ran
        end
    end
    return ran
end

-- The login loading screen: UIParent is hidden while it is up (the client
-- shows it again afterwards, which closes the UISpecialFrames, see
-- M.Reset). M.LoadingScreenEnds fires LOADING_SCREEN_DISABLED before
-- UIParent shows again: the order the addon cannot rely on either way.
function M.LoadingScreenStarts()
    UIParent:Hide()
    M.FireEvent("LOADING_SCREEN_ENABLED")
end
function M.LoadingScreenEnds()
    M.FireEvent("LOADING_SCREEN_DISABLED")
    UIParent:Show()
end

-- The player typing into an EditBox: focus, the text, then a key (or
-- clicking elsewhere). A disabled box takes none of it: each returns
-- false and changes nothing, as in the client.
function M.Type(box, text)
    if not box:IsEnabled() then return false end
    box:SetFocus()
    M.typing = box
    local ok, err = pcall(box.SetText, box, text)
    M.typing = nil
    if not ok then error(err, 0) end
    return true
end
local function key(box, script)
    if not box:IsEnabled() then return false end
    box:GetScript(script)(box)
    return true
end
function M.PressEnter(box) return key(box, "OnEnterPressed") end
function M.PressEscape(box) return key(box, "OnEscapePressed") end
-- Focus moves elsewhere (a click outside the box).
function M.LeaveBox(box)
    if not box:IsEnabled() then return false end
    box:ClearFocus()
    box:GetScript("OnEditFocusLost")(box)
    return true
end

function M.SetCombat(v)
    M.combat = v
    if not v then M.FireEvent("PLAYER_REGEN_ENABLED") end
end

-- Runs and clears every queued C_Timer.After callback. Timers a callback
-- itself queues are appended and run too, so this drains to empty.
-- With maxSeconds, only timers of at most that delay run; longer ones stay
-- queued (e.g. run a 0.5 s save but not a 15 s timeout).
-- Models that were loading (d.modelLater) arrive: OnModelLoaded fires.
function M.LoadModels()
    local list = M.pendingModels or {}
    M.pendingModels = {}
    for model, unit in pairs(list) do
        model._modelUnit = unit
        local script = model._scripts and model._scripts.OnModelLoaded
        if script then script(model) end
    end
end

function M.RunTimers(maxSeconds)
    while true do
        local due, later = {}, {}
        for _, t in ipairs(M.timers) do
            if maxSeconds == nil or t.sec <= maxSeconds then
                due[#due + 1] = t
            else
                later[#later + 1] = t
            end
        end
        if #due == 0 then return end
        M.timers = later
        for _, t in ipairs(due) do t.fn() end
    end
end

local function wants(registration, unit)
    if registration == true then return true end
    for _, u in ipairs(registration) do
        if u == unit then return true end
    end
    return false
end

-- Frames that listen to events, in the order they first registered: the
-- client dispatches in registration order (a plain table's pairs order
-- would differ from run to run).
function M.Listen(f)
    if M.eventFrames[f] then return end
    M.eventFrames[f] = true
    M.eventOrder[#M.eventOrder + 1] = f
end

function M.FireEvent(event, ...)
    local unit = ...
    -- The check is over: the client no longer reports anyone's answer
    -- (CompactUnitFrame_FinishReadyCheck works from what the frame showed).
    if event == "READY_CHECK_FINISHED" then
        for _, d in pairs(M.units) do d.readyCheck = nil end
    end
    for _, f in ipairs(M.eventOrder) do
        local registration = f._events[event]
        if registration and f._scripts.OnEvent and wants(registration, unit) then
            f._scripts.OnEvent(f, event, ...)
        end
    end
end

-- Advances the clock and runs OnUpdate of every shown created frame once.
function M.Tick(seconds)
    M.now = M.now + seconds
    for _, f in ipairs(M.frames) do
        local script = f._scripts.OnUpdate
        if script and f:IsShown() then script(f, seconds) end
    end
end

return M
