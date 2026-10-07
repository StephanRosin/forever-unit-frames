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
    if def.type == "text" then return raw end
    return nil   -- colors are set in the options window
end

local function status()
    local version, build, _, interface = GetBuildInfo()
    ns.Print(L.STATUS_BUILD:format(version, build, interface))
    ns.Print(L.STATUS_PROJECT:format(WOW_PROJECT_ID or 0))
    local src, isProvider = ns.Storage.Source()
    ns.Print(L.STATUS_SOURCE:format(isProvider and src or L["SOURCE_" .. src]))
    ns.Print(L.STATUS_FOCUS:format(ns.Units.FocusAvailable() and L.FOCUS_AVAILABLE or L.FOCUS_MISSING))
    ns.Print(L.STATUS_AURAS:format(ns.AuraContainers.Supported() and L.AURAS_CONTAINERS or L.AURAS_READ))
    local blocker = ns.CombatFade.Blocker()
    local frame = ns.Frames.player
    -- The opacity may be secret (the client set it from the health curve).
    local alpha = frame and ns.Secrets.Number(frame:GetAlpha())
    ns.Print(L.STATUS_FADE:format(blocker and L["FADE_" .. blocker] or L.FADE_FADED,
        alpha and tostring(math.floor(alpha * 100 + 0.5)) .. "%" or "?"))
end

-- What the slash command, the minimap button and a LibDataBroker
-- launcher share.
local Commands = {}
ns.Commands = Commands

-- Settings are loaded; says so in chat when not.
function Commands.IsReady()
    if ns.Config.Profile() ~= nil then return true end
    ns.Print(L.NOT_READY)
    return false
end

function Commands.ToggleOptions()
    if Commands.IsReady() then ns.Options.Toggle() end
end

-- The raid frames' window: /fuf raid, the raid minimap button and its
-- addon compartment entry.
function Commands.ToggleRaidOptions()
    if Commands.IsReady() then ns.RaidOptions.Toggle() end
end

-- /fuf raid off | on: the raid frames' switch, set without the window
-- (when the raid side raises, this still turns it off). The setting is
-- stored before its listeners run: one that raises is printed, and the
-- chat line follows when the value is in.
function Commands.SetRaid(on)
    local ok, err = pcall(ns.RaidConfig.Set, "general", "enabled", on)
    if not ok then ns.Print(tostring(err)) end
    local read, value = pcall(ns.RaidConfig.Get, "general", "enabled")
    if read and value == on then ns.Print(on and L.RAID_SWITCH_ON or L.RAID_SWITCH_OFF) end
end

-- /fuf news: the news of this version again (Options/News.lua), or why
-- not. What was recorded at login stays as it is.
function Commands.ShowNews()
    if not ns.NewsWindow.Open(ns.News.Current()) then ns.Print(L.NEWS_NONE) end
end

-- Unlocking is refused in combat (Movers.Unlock says so).
function Commands.ToggleLock()
    if not Commands.IsReady() then return end
    if ns.Movers.IsUnlocked() then ns.Movers.Lock() else ns.Movers.Unlock() end
end

SLASH_FOREVERUNITFRAMES1 = "/fuf"
SlashCmdList.FOREVERUNITFRAMES = function(msg)
    if not Commands.IsReady() then return end
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "" then
        ns.Options.Toggle()
    elseif cmd == "help" then
        ns.Print(L.HELP)
    elseif cmd == "raid" then
        local arg = rest:lower()
        if arg == "off" or arg == "on" then
            Commands.SetRaid(arg == "on")
        else
            Commands.ToggleRaidOptions()
        end
    elseif cmd == "tools" then
        -- The raid tools bar folded out or in (Raid/Tools.lua).
        ns.RaidTools.Fold()
    elseif cmd == "news" then
        Commands.ShowNews()
    elseif cmd == "auras" and rest:lower() == "undo" then
        -- The last aura hidden from a frame's menu (Core/AuraBlocklist.lua).
        ns.AuraBlocklist.Undo()
    elseif cmd == "unlock" then
        ns.Movers.Unlock()
    elseif cmd == "lock" then
        ns.Movers.LockAll()
    elseif cmd == "status" then
        status()
    elseif cmd == "reset" then
        if rest == "all" then
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
