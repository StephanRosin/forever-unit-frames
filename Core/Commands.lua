local _, ns = ...

local L = ns.L

local function parseValue(def, raw)
    if not def or not raw then return nil end
    if def.type == "int" then
        local n = tonumber(raw)
        -- tonumber("nan") can yield NaN; reject NaN and infinities too.
        if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
        return n
    end
    if def.type == "bool" then
        if raw == "on" or raw == "true" or raw == "1" then return true end
        if raw == "off" or raw == "false" or raw == "0" then return false end
        return nil
    end
    if def.type == "enum" then return raw:upper() end
    if def.type == "media" then
        for _, name in ipairs(ns.Media.List(def.mediaKind)) do
            if name == raw then return raw end
        end
        return nil
    end
    return nil   -- colors are set in the options window
end

local function status()
    local version, build, _, interface = GetBuildInfo()
    ns.Print(L.STATUS_BUILD:format(version, build, interface))
    ns.Print(L.STATUS_PROJECT:format(WOW_PROJECT_ID or 0))
    local src, isProvider = ns.Storage.Source()
    ns.Print(L.STATUS_SOURCE:format(isProvider and src or L["SOURCE_" .. src]))
    ns.Print(L.STATUS_FOCUS:format(ns.Units.FocusAvailable() and L.FOCUS_AVAILABLE or L.FOCUS_MISSING))
    local macroError = ns.Storage.MacroError()
    if macroError then ns.Print(L[macroError]) end
end

SLASH_FOREVERUNITFRAMES1 = "/fuf"
SlashCmdList.FOREVERUNITFRAMES = function(msg)
    if ns.Config.Profile() == nil then
        ns.Print(L.NOT_READY)
        return
    end
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "" then
        ns.Options.Toggle()
    elseif cmd == "help" then
        ns.Print(L.HELP)
    elseif cmd == "unlock" then
        ns.Movers.Unlock()
    elseif cmd == "lock" then
        ns.Movers.Lock()
    elseif cmd == "status" then
        status()
    elseif cmd == "reset" then
        if rest == "all" then
            ns.Storage.AllowMacroOverwrite()
            ns.Config.ResetAll()
        elseif ns.Config.Profile()[rest] then
            ns.Config.ResetScope(rest)
        else
            ns.Print(L.UNKNOWN_FRAME)
            return
        end
        ns.Print(L.RESET_DONE)
    elseif cmd == "set" then
        local scope, key, raw = rest:match("^(%S+)%s+(%S+)%s+(.+)$")
        local def = key and ns.Settings.Get(key)
        local value = parseValue(def, raw)
        if value == nil or not ns.Config.Set(scope, key, value) then
            ns.Print(L.INVALID_VALUE)
        end
    else
        ns.Print(L.HELP)
    end
end
