local _, ns = ...

-- Stores the encoded profile in character macros. Needed while the client
-- does not load SavedVariables back. A macro body holds 255 characters; the
-- first line marks the macro so players know not to delete it.
local MacroBackup = {}
ns.MacroBackup = MacroBackup

local PREFIX = "FUF Save "
local MAX_MACROS = 2
local BODY_LIMIT = 255
local ICON = "INV_MISC_QUESTIONMARK"

local function header(i, n)
    return ("#Forever Unit Frames backup %d/%d - keep\n"):format(i, n)
end

local function indexOf(i)
    local idx = GetMacroIndexByName(PREFIX .. i)
    if idx and idx > 0 then return idx end
    return nil
end

function MacroBackup.Read()
    local chunks = {}
    for i = 1, MAX_MACROS do
        local idx = indexOf(i)
        if not idx then break end
        local body = GetMacroBody(idx) or ""
        local chunk = body:match("^#[^\n]*\n(.*)$")
        if not chunk or chunk == "" then break end
        chunks[#chunks + 1] = chunk
    end
    if #chunks == 0 then return nil end
    return table.concat(chunks)
end

local function split(str)
    local chunks = {}
    local pos = 1
    while pos <= #str do
        local i = #chunks + 1
        local room = BODY_LIMIT - #header(i, MAX_MACROS)
        chunks[i] = str:sub(pos, pos + room - 1)
        pos = pos + room
    end
    return chunks
end

function MacroBackup.Write(str)
    if InCombatLockdown() then return false end
    if MacroFrame and MacroFrame.IsShown and MacroFrame:IsShown() then return false end
    local chunks = split(str)
    if #chunks > MAX_MACROS then return false end

    local maxChar = Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_CHARACTER_MACROS or 18
    for i = 1, MAX_MACROS do
        local idx = indexOf(i)
        local chunk = chunks[i]
        if chunk then
            local body = header(i, #chunks) .. chunk
            if idx then
                EditMacro(idx, PREFIX .. i, ICON, body)
            else
                local _, numChar = GetNumMacros()
                if numChar >= maxChar then return false end
                CreateMacro(PREFIX .. i, ICON, body, true)
            end
        elseif idx then
            -- Fewer chunks than before: blank the leftover macro so Read stops.
            EditMacro(idx, PREFIX .. i, ICON, header(i, #chunks))
        end
    end
    return true
end
