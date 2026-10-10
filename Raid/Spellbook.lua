local _, ns = ...

-- Corner indicator spells by name: the options window turns a name into
-- the IDs of every rank of it in the player's spell book (each rank is an
-- item there; Blizzard's spell book window only hides the low ones), so a
-- heal-over-time shows whichever rank was cast. Read only when the player
-- types a name, never in combat paths. Nothing read from the spell book
-- is compared or changed while secret (it is not documented as secret;
-- guarded anyway).
local Spellbook = {}
ns.RaidSpellbook = Spellbook

local Secrets = ns.Secrets

local function plain(v, kind)
    return not Secrets.IsSecret(v) and type(v) == kind
end

-- The items of one skill line of the player's bank, as fn(item).
local function forEachItem(book, line, fn)
    local info = book.GetSpellBookSkillLineInfo(line)
    if type(info) ~= "table" then return end
    if not (plain(info.itemIndexOffset, "number") and plain(info.numSpellBookItems, "number")) then return end
    local bank = Enum.SpellBookSpellBank.Player
    for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
        local item = book.GetSpellBookItemInfo(slot, bank)
        if type(item) == "table" then fn(item) end
    end
end

-- The spell IDs of every learned rank of a spell name (case ignored), in
-- spell book order; empty when there is none or no spell book to read.
function Spellbook.IDs(name)
    local book, ids = C_SpellBook, {}
    if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo
        and book.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank) then
        return ids
    end
    local wanted, spell, seen = name:lower(), Enum.SpellBookItemType.Spell, {}
    local lines = book.GetNumSpellBookSkillLines()
    if not plain(lines, "number") then return ids end
    for line = 1, lines do
        forEachItem(book, line, function(item)
            local id = item.spellID
            if plain(item.itemType, "number") and item.itemType == spell and plain(item.name, "string")
                and plain(id, "number") and item.name:lower() == wanted and not seen[id] then
                seen[id] = true
                ids[#ids + 1] = id
            end
        end)
    end
    return ids
end

-- A typed spell list as the options window stores it: IDs (separated by
-- commas or spaces) and spell names (separated by commas; a name may hold
-- spaces), each ID once, comma-separated. nil and the piece in question
-- when a name is not in the spell book or an ID is not a positive number.
function Spellbook.Resolve(text)
    local ids, seen = {}, {}
    local function add(id)
        if not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    for piece in text:gmatch("[^,]+") do
        local word = piece:match("^%s*(.-)%s*$")
        if word:match("^[%d%s]+$") then
            for digits in word:gmatch("%d+") do
                local id = tonumber(digits)
                if id < 1 then return nil, word end
                add(id)
            end
        elseif word ~= "" then
            local found = Spellbook.IDs(word)
            if #found == 0 then return nil, word end
            for _, id in ipairs(found) do add(id) end
        end
    end
    return table.concat(ids, ",")
end

-- Whether a spell is cast on someone else: helpful (the client's
-- IsSpellHelpful: the player or a friendly target) and with a range
-- (GetSpellInfo's maxRange is 0 for self-only and self-centred spells).
-- A secret, missing or raising answer is a no.
local function onOthers(id)
    local spell = C_Spell
    if not (spell and spell.IsSpellHelpful and spell.GetSpellInfo) then return false end
    if Secrets.Bool(spell.IsSpellHelpful, id) ~= true then return false end
    local ok, info = pcall(spell.GetSpellInfo, id)
    if not ok or type(info) ~= "table" then return false end
    local range = Secrets.Plain(info.maxRange, "number")
    return range ~= nil and range > 0
end

-- A learned spell of the book (not passive) as { id, name, subName }, or
-- nil when it is none or anything about it is secret.
local function learnedSpell(item, spellType)
    if not (plain(item.itemType, "number") and item.itemType == spellType) then return nil end
    if not (plain(item.isPassive, "boolean") and item.isPassive == false) then return nil end
    if not (plain(item.spellID, "number") and plain(item.name, "string") and plain(item.subName, "string")) then
        return nil
    end
    return { id = item.spellID, name = item.name, subName = item.subName }
end

local function byName(a, b)
    local compare = rawget(_G, "strcmputf8i")
    if compare then return compare(a.name, b.name) < 0 end
    return a.name:lower() < b.name:lower()
end

-- Whether a spell ID is a learned spell of the player's book (every rank
-- is an item there, a lower one too: C_SpellBook.IsSpellKnown is not
-- documented to say so for a rank a higher one supersedes).
function Spellbook.InBook(id)
    local book = C_SpellBook
    if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo
        and book.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank) then
        return false
    end
    local lines = book.GetNumSpellBookSkillLines()
    if not plain(lines, "number") then return false end
    local spellType, found = Enum.SpellBookItemType.Spell, false
    for line = 1, lines do
        forEachItem(book, line, function(item)
            if not found and plain(item.itemType, "number") and item.itemType == spellType
                and plain(item.spellID, "number") and item.spellID == id then
                found = true
            end
        end)
        if found then return true end
    end
    return false
end

-- Whether the player's book is read: a learned spell in a skill line
-- after the first (the first is General: racials and the like; the
-- class's lines follow). Answers nothing about the rank texts.
function Spellbook.Ready()
    local book = C_SpellBook
    if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo
        and book.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank) then
        return false
    end
    local lines = book.GetNumSpellBookSkillLines()
    if not plain(lines, "number") then return false end
    local spellType, found = Enum.SpellBookItemType.Spell, false
    for line = 2, lines do
        forEachItem(book, line, function(item)
            if plain(item.itemType, "number") and item.itemType == spellType then found = true end
        end)
        if found then return true end
    end
    return false
end

-- The spells click-casting offers: every learned spell of the book that
-- is no passive and is cast on someone else (heals, dispels, buffs,
-- resurrections), each name once as { name, ranks = { { id, subName },
-- ... } } with its learned ranks in spell book order (the highest last),
-- sorted by name in the client's language. Read only while the raid
-- window shows it, never in combat paths.
function Spellbook.FriendlySpells()
    local book, list = C_SpellBook, {}
    if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo
        and book.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank) then
        return list
    end
    local lines = book.GetNumSpellBookSkillLines()
    if not plain(lines, "number") then return list end
    local spellType, byNames, seen = Enum.SpellBookItemType.Spell, {}, {}
    for line = 1, lines do
        forEachItem(book, line, function(item)
            local s = learnedSpell(item, spellType)
            if not s or seen[s.id] or not onOthers(s.id) then return end
            seen[s.id] = true
            local entry = byNames[s.name]
            if not entry then
                entry = { name = s.name, ranks = {} }
                byNames[s.name] = entry
                list[#list + 1] = entry
            end
            entry.ranks[#entry.ranks + 1] = { id = s.id, subName = s.subName }
        end)
    end
    table.sort(list, byName)
    return list
end

-- A spell of FriendlySpells by its name (case ignored), or nil. list:
-- the spells (read anew when nil).
function Spellbook.FriendlySpell(name, list)
    local wanted = name:lower()
    for _, spell in ipairs(list or Spellbook.FriendlySpells()) do
        if spell.name:lower() == wanted then return spell end
    end
    return nil
end

-- The spell of FriendlySpells one of whose ranks has the ID, and that
-- rank; nil when it is no such rank. list: as above.
function Spellbook.FriendlyRank(id, list)
    for _, spell in ipairs(list or Spellbook.FriendlySpells()) do
        for _, rank in ipairs(spell.ranks) do
            if rank.id == id then return spell, rank end
        end
    end
    return nil
end

-- The rank of a spell (FriendlySpells) its name casts: the client's
-- CastSpellByName takes the highest rank known, which is what
-- C_Spell.GetSpellInfo resolves the name to (the book's order is not
-- the ranks', nor are the IDs). nil when that cannot be read (missing,
-- raising, secret) or is none of the spell's ranks.
function Spellbook.HighestRank(spell)
    if not (C_Spell and C_Spell.GetSpellInfo) then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, spell.name)
    if not ok or type(info) ~= "table" then return nil end
    local id = Secrets.Plain(info.spellID, "number")
    for _, rank in ipairs(spell.ranks) do
        if rank.id == id then return rank end
    end
    return nil
end

-- A rank's text (FriendlySpells), "" for a spell of one rank without
-- one, nil while it is not loaded: the client hands "" for a spell whose
-- data is not loaded yet and sends SPELL_TEXT_UPDATE when it is, so an
-- empty text of a spell with several ranks is not read as "no rank".
function Spellbook.RankText(spell, rank)
    if rank.subName ~= "" then return rank.subName end
    if #spell.ranks > 1 then return nil end
    return ""
end

-- SPELL_TEXT_UPDATE (SpellDocumentation.lua) fires once per spell whose
-- text arrives, many at a time after login: fn runs once, 0.2 s after
-- the first of a burst (the texts of the later ones are loaded by then;
-- their events in that time are let go). Registered guarded (an unknown
-- event raises): Spellbook.textEventRegistered says whether it took,
-- nothing is printed (the keys' retries, Raid/ClickKeys.lua, cover it).
function Spellbook.OnTextUpdate(fn)
    local queued = false
    local ok = pcall(ns.On, "SPELL_TEXT_UPDATE", function()
        if queued then return end
        queued = true
        C_Timer.After(0.2, function()
            queued = false
            fn()
        end)
    end)
    Spellbook.textEventRegistered = ok and Spellbook.textEventRegistered ~= false
    return ok
end
