local _, ns = ...

-- Aura blocklists: auras hidden by spell ID. One list for the whole
-- account (General), one per unit frame, one per raid size; an aura is
-- hidden where it is on the account list or on that frame's or size's
-- list. A list is stored as validated text, "1234, 5678", at most MAX IDs.
-- The containers apply it through candidateFilters.excludeSpellIDs
-- (Elements/AuraContainers.lua, Raid/CellAuras.lua), where the client
-- allows filtering by spell (Blizzard_AuraContainerUtil.lua,
-- CanApplyIdentityCandidateFilters): spells it flags never-secret
-- everywhere; buffs on you, your group and pets, and on other units you
-- can assist; debuffs only on units you cannot assist. Mark tells the
-- options which case an entry falls into.
local Blocklist = {}
ns.AuraBlocklist = Blocklist

local Secrets = ns.Secrets

Blocklist.MAX = 100
-- MAX IDs of up to eight digits with their separators.
Blocklist.LETTERS = 1000
Blocklist.SEPARATOR = ", "

-- Stored text: the IDs in order; nil when anything else is in it (a name,
-- a sign, a fraction, an ID twice) or there are more than MAX.
function Blocklist.Parse(text)
    if type(text) ~= "string" then return nil end
    local ids, seen = {}, {}
    for token in text:gmatch("[^,%s]+") do
        if not token:match("^%d+$") then return nil end
        local id = tonumber(token)
        if id < 1 or seen[id] then return nil end
        seen[id] = true
        ids[#ids + 1] = id
        if #ids > Blocklist.MAX then return nil end
    end
    return ids
end

-- The setting's check (Core/Registry.lua).
function Blocklist.Check(text) return Blocklist.Parse(text) ~= nil end

function Blocklist.Text(ids) return table.concat(ids, Blocklist.SEPARATOR) end

-- The set a container takes, spell ID -> true (it looks up
-- excludeSpellIDs[spellId]); nil for an empty or unreadable list.
function Blocklist.Set(text)
    local ids = Blocklist.Parse(text or "")
    if not ids or #ids == 0 then return nil end
    local set = {}
    for _, id in ipairs(ids) do set[id] = true end
    return set
end

-- Two sets as one; either may be nil. One alone is returned as it is.
function Blocklist.Merge(a, b)
    if not a then return b end
    if not b then return a end
    local set = {}
    for id in pairs(a) do set[id] = true end
    for id in pairs(b) do set[id] = true end
    return set
end

-- The spell's name from the client's spell data; nil when it knows none.
function Blocklist.Name(id)
    local name = Secrets.Plain(Secrets.Call(C_Spell.GetSpellName, id), "string")
    if name == "" then return nil end
    return name
end

-- Every ID of a spell name: the ranks in the spell book, and the one the
-- client's spell data gives for the name (food and campfire buffs are in
-- no spell book). Empty when there is none.
function Blocklist.IDsOfName(name)
    local ids, seen = {}, {}
    local function add(id)
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    for _, id in ipairs(ns.RaidSpellbook.IDs(name)) do add(id) end
    local id = Secrets.Plain(Secrets.Call(C_Spell.GetSpellIDForSpellIdentifier, name), "number")
    -- The client's answer must really be of that name (case ignored).
    local known = id and Blocklist.Name(id)
    if known and known:lower() == name:lower() then add(id) end
    -- Every other ID of that name the spell data ties to the same spell
    -- would need a lookup the client does not offer: the spell book's
    -- ranks and the client's own pick are what a name can mean here.
    table.sort(ids)
    return ids
end

-- A typed entry (IDs separated by commas or spaces, names separated by
-- commas) added to a stored list. Returns the new text and the IDs it
-- added; or nil, why ("UNKNOWN" with the piece, "FULL") and the piece.
-- IDs already on the list are left as they are.
function Blocklist.Resolve(typed, current)
    local ids = Blocklist.Parse(current or "") or {}
    local seen, added = {}, {}
    for _, id in ipairs(ids) do seen[id] = true end
    local function add(id)
        if seen[id] then return end
        seen[id] = true
        ids[#ids + 1] = id
        added[#added + 1] = id
    end
    for piece in (typed or ""):gmatch("[^,]+") do
        local word = piece:match("^%s*(.-)%s*$")
        if word:match("^[%d%s]+$") then
            for digits in word:gmatch("%d+") do
                local id = tonumber(digits)
                if id < 1 or not Blocklist.Name(id) then return nil, "UNKNOWN", digits end
                add(id)
            end
        elseif word ~= "" then
            local found = Blocklist.IDsOfName(word)
            if #found == 0 then return nil, "UNKNOWN", word end
            for _, id in ipairs(found) do add(id) end
        end
    end
    if #ids > Blocklist.MAX then return nil, "FULL" end
    return Blocklist.Text(ids), added
end

-- One ID onto a stored list: the new text, or nil and why (TWICE, FULL).
function Blocklist.Add(current, id)
    local ids = Blocklist.Parse(current or "") or {}
    for _, have in ipairs(ids) do
        if have == id then return nil, "TWICE" end
    end
    if #ids >= Blocklist.MAX then return nil, "FULL" end
    ids[#ids + 1] = id
    return Blocklist.Text(ids)
end

-- One ID off a stored list.
function Blocklist.Remove(current, id)
    local out = {}
    for _, have in ipairs(Blocklist.Parse(current or "") or {}) do
        if have ~= id then out[#out + 1] = have end
    end
    return Blocklist.Text(out)
end

-- Where a list is used: "group" (you, your pet, the party, the raid
-- cells: debuffs there are never filtered by spell), "mixed" (target,
-- focus, target of target: friends or enemies), "any" (the account list).
local GROUP_SCOPES = { player = true, pet = true, party = true }
function Blocklist.Context(scope)
    if scope == "general" then return "any" end
    if GROUP_SCOPES[scope] or (type(scope) == "string" and scope:match("^r%d+$")) then return "group" end
    return "mixed"
end

-- Whether the client hides the spell's aura everywhere: it flags the
-- spell never-secret.
function Blocklist.NeverSecret(id)
    local level = Secrets.Call(C_Secrets.GetSpellAuraSecrecy, id)
    return level ~= nil and level == Enum.SecrecyLevel.NeverSecret
end

-- What the options say about an entry in a context: nil when the client
-- hides it everywhere; "GROUP" (here only as a buff: debuffs on your
-- group stay); "MIXED" (buffs on friends, debuffs on enemies).
function Blocklist.Mark(id, context)
    if Blocklist.NeverSecret(id) then return nil end
    if context == "group" then return "GROUP" end
    return "MIXED"
end

-- A unit frame's (or a scope derived from one) list with the account's.
function Blocklist.ForFrame(scope)
    return Blocklist.Merge(Blocklist.Set(ns.Config.Get("general", "auraBlockAccount")),
        Blocklist.Set(ns.Config.Get(scope, "auraBlock")))
end

-- Adding from the frame ---------------------------------------------------------
-- One spell onto a list (scope "general": the account's, else that
-- frame's), with a chat line that says what is hidden where and how to
-- undo it; /fuf auras undo (Blocklist.Undo) takes the last one back.
-- False when it was refused (full, already there, a setting refused).
local last  -- { scope, key, id }

local function listKey(scope)
    return scope == "general" and "auraBlockAccount" or "auraBlock"
end

local function where(scope)
    local L = ns.L
    if scope == "general" then return L.AURA_BLOCK_EVERYWHERE end
    return L["FRAME_" .. scope]
end

local function label(id)
    return ("%s (%d)"):format(Blocklist.Name(id) or "?", id)
end

function Blocklist.Hide(scope, id)
    local L, key = ns.L, listKey(scope)
    local text, why = Blocklist.Add(ns.Config.Get(scope, key), id)
    if not text then
        if why == "FULL" then ns.Print(L.AURA_BLOCK_FULL:format(Blocklist.MAX)) end
        return false
    end
    if not ns.Config.Set(scope, key, text) then return false end
    last = { scope = scope, key = key, id = id }
    ns.Print(L.AURA_BLOCK_ADDED:format(label(id), where(scope)))
    return true
end

function Blocklist.Undo()
    local L = ns.L
    if not last then
        ns.Print(L.AURA_BLOCK_UNDO_NONE)
        return false
    end
    local entry = last
    last = nil
    ns.Config.Set(entry.scope, entry.key, Blocklist.Remove(ns.Config.Get(entry.scope, entry.key), entry.id))
    ns.Print(L.AURA_BLOCK_UNDONE:format(label(entry.id), where(entry.scope)))
    return true
end
