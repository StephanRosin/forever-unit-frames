-- Character macros come back from the server with a line break after the
-- body, and the client's macro cache uses CRLF line endings (measured in
-- the client: an exact body of 45 characters reads back as 46, last byte
-- 10). Every session used to lose the last entry of the backup and then
-- save the shortened profile over SavedVariables and the macro. The last
-- setting must survive the round trip, and a backup we cannot read in full
-- must never be overwritten.
local M = H.M
local HEADER = "#Forever Unit Frames backup 1/1 - keep\n"

local function chatCount(text)
    local n = 0
    for _, line in ipairs(M.chat) do
        if line:find(text, 1, true) then n = n + 1 end
    end
    return n
end

local function countWrites()
    local writes = { macro = 0 }
    local create, edit = CreateMacro, EditMacro
    _G.CreateMacro = function(...) writes.macro = writes.macro + 1; return create(...) end
    _G.EditMacro = function(...) writes.macro = writes.macro + 1; return edit(...) end
    return writes
end

-- One session: SavedVariables are not handed back, only the macros.
-- `late`: the macros arrive after PLAYER_LOGIN (a full restart).
-- Returns the addon and its count of macro writes.
local function login(macros, late)
    local ns = H.LoadAddon()
    local writes = countWrites()
    _G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
    _G.ForeverUnitFramesDB = nil
    M.macros = late and {} or macros
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    if late then M.macros = macros end
    M.FireEvent("UPDATE_MACROS")
    M.RunTimers()
    return ns, writes
end

local function macroWith(body)
    return { { name = "FUF Save 1", icon = "INV_MISC_QUESTIONMARK", perChar = true, body = body } }
end

-- The reported sessions, with the body exactly as the client returned it.
local ns = login(macroWith(HEADER .. "1;pW260\n"))
H.check("roundtrip reload: from backup", ns.Storage.Source(), "MacroBackup")
H.check("roundtrip reload: last entry kept", ns.Config.Get("player", "width"), 260)
M.FireEvent("PLAYER_LOGOUT")
H.check("roundtrip reload: SV not emptied",
    ForeverUnitFramesDB.profile and ForeverUnitFramesDB.profile.player.width, 260)
H.check("roundtrip reload: backup not shortened",
    (ns.MacroBackup.Read() or ""):find("pW260", 1, true) ~= nil, true)

ns = login(macroWith(HEADER .. "1;pW260;tHM4\n"), true)
H.check("roundtrip restart: from backup", ns.Storage.Source(), "MacroBackup")
H.check("roundtrip restart: last entry kept", ns.Config.Get("target", "healthColorMode"), "GRADIENT")
M.FireEvent("PLAYER_LOGOUT")
H.check("roundtrip restart: backup keeps last entry",
    (ns.MacroBackup.Read() or ""):find("tHM4", 1, true) ~= nil, true)

-- Read normalises CRLF (header too) and trailing whitespace per chunk.
ns = H.LoadAddon()
M.macros = macroWith("#Forever Unit Frames backup 1/1 - keep\r\n1;pW260;tHM4\r\n")
H.check("read: CRLF body", ns.MacroBackup.Read(), "1;pW260;tHM4")
M.macros = macroWith("#Forever Unit Frames backup 1/1 - keep\r1;pW260 \t\r\n\n")
H.check("read: lone CR and mixed whitespace", ns.MacroBackup.Read(), "1;pW260")

-- Trailing whitespace is stripped per chunk, so Write never lets a chunk
-- end on a space (here one inside a media name at the chunk boundary).
ns = H.LoadAddon()
local spaced = "1;gFF'" .. string.rep("a", 209) .. " b;pW260"
H.check("setup: space at the boundary", spaced:sub(216, 216), " ")
H.checkTrue("boundary: written", ns.MacroBackup.Write(spaced))
H.check("boundary: read back", ns.MacroBackup.Read(), spaced)
M.RoundTripMacros("\r\n", true)
H.check("boundary: read back after a reload", ns.MacroBackup.Read(), spaced)

-- A profile long enough for two macros.
local function bigProfile(n)
    n.Config.Set("player", "width", 260)
    n.Config.Set("target", "healthColorMode", "GRADIENT")
    n.Config.Set("general", "fontFace", "Friz Quadrata TT")
    for _, scope in ipairs({ "player", "target", "targettarget", "pet", "focus", "party" }) do
        n.Config.Set(scope, "height", 41)
        n.Config.Set(scope, "x", -1234)
        n.Config.Set(scope, "y", 1234)
        n.Config.Set(scope, "healthColor", { 1, 0, 0.5, 1 })
    end
    n.Config.Set("party", "partySpacing", 7)
end

-- Three sessions in a row with SavedVariables never loaded: nothing may be
-- lost, and an unchanged backup is not rewritten because of line endings.
local function threeSessions(label, trailer, crlf, late)
    local n = login({})
    bigProfile(n)
    M.RunTimers()
    M.FireEvent("PLAYER_LOGOUT")
    local expected = n.MacroBackup.Read()
    H.check(label .. ": setup encodes the profile", expected, n.Codec.Encode(n.Config.Profile()))
    H.checkTrue(label .. ": setup ends with the last entry", expected:find(";yY1234$"))
    H.check(label .. ": setup needs two macros", #M.macros, 2)
    for session = 1, 3 do
        M.RoundTripMacros(trailer, crlf)
        local macros = M.macros
        M.chat = {}
        local writes
        n, writes = login(macros, late)
        local tag = ("%s: session %d"):format(label, session)
        H.check(tag .. " source", n.Storage.Source(), "MacroBackup")
        H.check(tag .. " profile complete", n.Codec.Encode(n.Config.Profile()), expected)
        H.check(tag .. " last entry", n.Config.Get("party", "y"), 1234)
        M.FireEvent("PLAYER_LOGOUT")
        H.check(tag .. " SV complete", n.Codec.Encode(ForeverUnitFramesDB.profile), expected)
        H.check(tag .. " backup complete", n.MacroBackup.Read(), expected)
        H.check(tag .. " no macro rewrite", writes.macro, 0)
        H.check(tag .. " no unreadable warning", chatCount(n.L.MACRO_UNREADABLE), 0)
    end
end

threeSessions("LF reload", "\n", false, false)
threeSessions("CRLF reload", "\r\n", true, false)
threeSessions("LF restart", "\n", false, true)
threeSessions("CRLF restart", "\r\n", true, true)

-- A known code whose value cannot be parsed: what can be read is loaded,
-- the macro is never overwritten this session, and the player is told once.
local function garbled(label, late)
    local body = HEADER .. "1;pH40;pW2x0;tHM4\n"
    local macros = macroWith(body)
    M.chat = {}
    local n, writes = login(macros, late)
    H.check(label .. ": source", n.Storage.Source(), "MacroBackup")
    H.check(label .. ": readable entries loaded", n.Config.Get("player", "height"), 40)
    H.check(label .. ": last entry loaded", n.Config.Get("target", "healthColorMode"), "GRADIENT")
    H.check(label .. ": garbled entry at default", n.Config.Get("player", "width"), 220)
    H.check(label .. ": told at load", chatCount(n.L.MACRO_UNREADABLE), 1)
    n.Config.Set("player", "width", 300)
    M.RunTimers()
    M.FireEvent("PLAYER_LOGOUT")
    H.check(label .. ": macro untouched", M.macros[1].body, body)
    H.check(label .. ": no macro write", writes.macro, 0)
    H.check(label .. ": SV still saved", ForeverUnitFramesDB.profile.player.width, 300)
    H.check(label .. ": reported", n.Storage.MacroError(), "MACRO_UNREADABLE")
    H.check(label .. ": message printed once", chatCount(n.L.MACRO_UNREADABLE), 1)
    H.check(label .. ": Write refuses", n.MacroBackup.Write("1;pW1"), false)
    H.check(label .. ": Write error", n.MacroBackup.LastError(), "MACRO_UNREADABLE")
    H.check(label .. ": still untouched", M.macros[1].body, body)
end

garbled("garbled reload", false)
garbled("garbled restart", true)
H.check("unreadable message text", ns.L.MACRO_UNREADABLE,
    "Macro backup kept: part of it could not be read. Please report this.")

-- An unknown code (a newer version's setting) is not a read error: the
-- rest loads and the backup is rewritten as usual.
do
    local macros = macroWith(HEADER .. "1;pW260;pZZ5\n")
    M.chat = {}
    local n = login(macros)
    H.check("unknown code: loads", n.Config.Get("player", "width"), 260)
    n.Config.Set("player", "width", 270)
    M.RunTimers()
    M.FireEvent("PLAYER_LOGOUT")
    H.check("unknown code: macro rewritten", n.MacroBackup.Read(), "1;pW270")
    H.check("unknown code: no warning", chatCount(n.L.MACRO_UNREADABLE), 0)
    H.check("unknown code: no macro error", n.Storage.MacroError(), nil)
end
