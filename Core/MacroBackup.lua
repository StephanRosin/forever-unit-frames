local _, ns = ...

-- Stores the encoded profile in character macros. Needed while the client
-- does not load SavedVariables back. A macro body holds 255 characters; the
-- first line marks the macro so players know not to delete it. A body read
-- back in a later session carries an extra line break, and the macro cache
-- turns every line break into CRLF (header line + appended one: 3 extra
-- characters), so chunks leave that much slack below the client's limit.
-- Up to six macros ("FUF Save 1" to "FUF Save 6"), only as many as the
-- profile needs; the header "i/n" keeps one digit each, so its length and
-- the slack stay the same for every macro.
local MacroBackup = {}
ns.MacroBackup = MacroBackup

local PREFIX = "FUF Save "
local MAX_MACROS = 6
local BODY_LIMIT = 252
local ICON = "INV_MISC_QUESTIONMARK"
local MARK = "#Forever Unit Frames backup"

local lastError

function MacroBackup.LastError()
    return lastError
end

local function header(i, n)
    return ("%s %d/%d - keep\n"):format(MARK, i, n)
end
-- For the tests: the header stays one length up to the last macro.
MacroBackup.MAX_MACROS = MAX_MACROS
MacroBackup.Header = header

-- We only ever touch a macro that we made ourselves: empty, or already
-- carrying our marker. Anything else belongs to the player.
local function isOwned(body)
    return body == "" or body:find(MARK, 1, true) == 1
end

local function indexOf(i)
    local idx = GetMacroIndexByName(PREFIX .. i)
    if idx and idx > 0 then return idx end
    return nil
end

-- Forever's client value first, then whatever the global constant says,
-- then a conservative guess.
local function maxCharMacros()
    if Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_CHARACTER_MACROS then
        return Constants.MacroConsts.MAX_CHARACTER_MACROS
    end
    if MAX_CHARACTER_MACROS then return MAX_CHARACTER_MACROS end
    return 18
end

local HEADER_PATTERN = "^#Forever Unit Frames backup (%d+)/(%d+) %- keep\r?\n(.*)$"

-- A body that went through the server comes back with a line break
-- appended, and the client's macro cache uses CRLF line endings. The codec
-- never writes whitespace, and Write never ends a chunk on whitespace, so
-- trailing whitespace is stripped from every chunk: with several macros
-- the extra line break of each but the last would otherwise sit inside
-- the profile.
local function parseHeader(body)
    body = (body or ""):gsub("\r\n?", "\n")
    local i, n, chunk = body:match(HEADER_PATTERN)
    if not i then return nil end
    return tonumber(i), tonumber(n), (chunk:gsub("%s+$", ""))
end

-- An incomplete backup (a missing chunk, a foreign macro in the middle) is
-- worthless, so it counts as no backup at all rather than a corrupt one.
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

local function split(str)
    local chunks = {}
    local pos = 1
    while pos <= #str do
        local i = #chunks + 1
        local room = BODY_LIMIT - #header(i, MAX_MACROS)
        -- Read strips trailing whitespace, so a chunk must not end in it
        -- (a media name with a space may straddle the boundary).
        while room > 1 and str:sub(pos + room - 1, pos + room - 1):match("%s")
            and pos + room - 1 < #str do
            room = room - 1
        end
        chunks[i] = str:sub(pos, pos + room - 1)
        pos = pos + room
    end
    return chunks
end

-- All checks happen before any Create/EditMacro call: either the whole
-- backup lands, or nothing is touched.
-- overwriteUnreadable: the player asked to replace everything (reset all,
-- profile import), so a backup we cannot read in full may go. A backup from
-- a newer version is kept regardless.
function MacroBackup.Write(str, overwriteUnreadable)
    lastError = nil
    if InCombatLockdown() then lastError = "MACRO_COMBAT"; return false end
    if MacroFrame and MacroFrame.IsShown and MacroFrame:IsShown() then
        lastError = "MACRO_FRAME_OPEN"
        return false
    end
    local chunks = split(str)
    if #chunks > MAX_MACROS then lastError = "MACRO_TOO_LONG"; return false end
    -- A backup in a format we cannot read was written by a newer version:
    -- it is kept, never replaced by what this version knows. Neither is one
    -- with entries we should understand but cannot parse: overwriting it
    -- would make the loss permanent.
    local existing = MacroBackup.Read()
    if existing then
        local _, err, rejected = ns.Codec.Decode(existing)
        if err == "CODEC_VERSION" then lastError = "MACRO_NEWER"; return false end
        if rejected and rejected > 0 and not overwriteUnreadable then lastError = "MACRO_UNREADABLE"; return false end
    end

    -- Pass 1: look, never touch. Reject a foreign macro anywhere we would
    -- write or blank, and count how many brand new macros we would need.
    local idx, newNeeded = {}, 0
    for i = 1, MAX_MACROS do
        idx[i] = indexOf(i)
        if idx[i] then
            if not isOwned(GetMacroBody(idx[i]) or "") then
                lastError = "MACRO_FOREIGN"
                return false
            end
        elseif chunks[i] then
            newNeeded = newNeeded + 1
        end
    end

    local _, numChar = GetNumMacros()
    if numChar + newNeeded > maxCharMacros() then
        lastError = "MACRO_FULL"
        return false
    end

    -- Pass 2: everything checked out, now write. CreateMacro and EditMacro
    -- re-sort the macro list, so every index is looked up by name right
    -- before it is used; the pass-1 indices are never reused here.
    for i = 1, MAX_MACROS do
        local chunk = chunks[i]
        local index = indexOf(i)
        if chunk then
            local body = header(i, #chunks) .. chunk
            if index then
                EditMacro(index, PREFIX .. i, ICON, body)
            else
                CreateMacro(PREFIX .. i, ICON, body, true)
            end
        elseif index then
            -- Fewer chunks than before: blank the leftover macro so Read stops.
            EditMacro(index, PREFIX .. i, ICON, header(i, #chunks))
        end
    end
    return true
end
