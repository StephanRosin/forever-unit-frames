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
