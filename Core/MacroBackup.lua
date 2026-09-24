local _, ns = ...

-- The settings backup that versions up to 0.2.x kept in character macros,
-- while the client did not load SavedVariables on a full restart. The
-- addon no longer writes macros: it reads an old backup once, to migrate a
-- profile that exists nowhere else, and then deletes its own backup macros.
--
-- A backup is "FUF Save 1" to "FUF Save n" (n up to 6), each body
-- "#Forever Unit Frames backup i/n - keep" plus one chunk of the encoded
-- profile. A body read back in a later session carries an extra line
-- break, and the macro cache turns every line break into CRLF.
local MacroBackup = {}
ns.MacroBackup = MacroBackup

local PREFIX = "FUF Save "
local MAX_MACROS = 6
local HEADER_PATTERN = "^#Forever Unit Frames backup (%d+)/(%d+) %- keep\r?\n(.*)$"

local function indexOf(i)
    local idx = GetMacroIndexByName(PREFIX .. i)
    if idx and idx > 0 then return idx end
    return nil
end

-- The codec never writes whitespace, and the old writer never ended a
-- chunk on whitespace, so trailing whitespace is stripped from every
-- chunk: with several macros the extra line break of each but the last
-- would otherwise sit inside the profile.
local function parseHeader(body)
    body = (body or ""):gsub("\r\n?", "\n")
    local i, n, chunk = body:match(HEADER_PATTERN)
    if not i then return nil end
    return tonumber(i), tonumber(n), (chunk:gsub("%s+$", ""))
end

-- The encoded profile, or nil. An incomplete backup (a missing chunk, a
-- foreign macro in the middle) is worthless, so it counts as no backup at
-- all rather than a corrupt one.
function MacroBackup.Read()
    local idx1 = indexOf(1)
    if not idx1 then return nil end
    local i1, n, chunk1 = parseHeader(GetMacroBody(idx1))
    if not i1 or i1 ~= 1 or not n or n < 1 or n > MAX_MACROS then return nil end
    local chunks = { chunk1 }
    for i = 2, n do
        local idx = indexOf(i)
        if not idx then return nil end
        local ii, nn, chunk = parseHeader(GetMacroBody(idx))
        if ii ~= i or nn ~= n then return nil end
        chunks[i] = chunk
    end
    return table.concat(chunks, "", 1, n)
end

local function macroFrameOpen()
    return MacroFrame and MacroFrame.IsShown and MacroFrame:IsShown()
end

-- Deletes the backup macros. Only "FUF Save i" whose body starts with our
-- header numbered i is ours; any other macro belongs to the player and is
-- never touched. Refused in combat and while the macro window is open (its
-- list would go stale): returns nil then, else the number deleted.
function MacroBackup.Delete()
    if InCombatLockdown() or macroFrameOpen() then return nil end
    local deleted = 0
    for i = 1, MAX_MACROS do
        -- Looked up by name each time: deleting shifts the later indices.
        local idx = indexOf(i)
        if idx and parseHeader(GetMacroBody(idx)) == i then
            DeleteMacro(idx)
            deleted = deleted + 1
        end
    end
    return deleted
end
