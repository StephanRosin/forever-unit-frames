local _, ns = ...

-- /fuf auradebug: what the client lets this addon see of auras right now
-- (a diagnostic tool, English only). Everything the client hands out may be
-- secret, so nothing it returns is ever printed: only whether a value is
-- "secret", "plain" or "nil", counts that were checked to be plain numbers,
-- and error messages that were checked to be plain strings.
local Debug = {}
ns.Debug = Debug

Debug.UNITS = { "player", "target", "party1", "party2", "party3", "party4" }
local FIELDS = { "auraInstanceID", "icon", "duration" }
local RESTRICTIONS = { "Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map", "Chat" }

local issecret = issecretvalue or function() return false end
local function isSecret(v) return issecret(v) == true end

local function kind(v)
    if isSecret(v) then return "secret" end
    if v == nil then return "nil" end
    return "plain"
end

local function yesNo(fn, ...)
    local ok, v = pcall(fn, ...)
    if not ok then return "error" end
    if isSecret(v) then return "secret" end
    return v and "yes" or "no"
end

local function errorText(err)
    if isSecret(err) or type(err) ~= "string" then return "(unreadable error)" end
    return err
end

local function index(t, k) return t[k] end

-- "auraInstanceID=plain icon=secret duration=secret" for one aura.
local function describeAura(aura)
    if isSecret(aura) then return "entry secret" end
    if type(aura) ~= "table" then return "entry " .. (aura == nil and "nil" or type(aura)) end
    local parts = {}
    for _, field in ipairs(FIELDS) do
        local ok, v = pcall(index, aura, field)
        parts[#parts + 1] = field .. "=" .. (ok and kind(v) or "error")
    end
    return table.concat(parts, " ")
end

local function length(t) return #t end

local function probeList(unit)
    local sortRule = Enum and Enum.UnitAuraSortRule and Enum.UnitAuraSortRule.Default or 1
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL", 40, sortRule)
    if not ok then return "error: " .. errorText(list) end
    if isSecret(list) then return "ok, list secret" end
    if type(list) ~= "table" then return "ok, " .. type(list) end
    local okLen, n = pcall(length, list)
    if not okLen or isSecret(n) or type(n) ~= "number" then return "ok, length unreadable" end
    local okFirst, first = pcall(index, list, 1)
    return ("ok, %d entries; first: %s"):format(n, okFirst and describeAura(first) or "error")
end

local function probeIndex(unit)
    if not C_UnitAuras.GetAuraDataByIndex then return "missing" end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, "HELPFUL")
    if not ok then return "error: " .. errorText(aura) end
    return "ok, " .. describeAura(aura)
end

-- UNIT_AURA counters since the last /fuf auradebug, one frame per unit so
-- the (possibly secret) unit argument is never compared.
local seen = {}

local function resetSeen(unit)
    seen[unit] = { events = 0, secretInfo = 0, withAdded = 0, lastAdded = "none" }
end

local function firstAdded(info)
    local added = info.addedAuras
    if isSecret(added) then return "list secret" end
    if type(added) ~= "table" then return nil end
    local first = added[1]
    if not isSecret(first) and first == nil then return nil end
    return describeAura(first)
end

local function onAura(unit, info)
    local s = seen[unit]
    s.events = s.events + 1
    if isSecret(info) then
        s.secretInfo = s.secretInfo + 1
        return
    end
    if type(info) ~= "table" then return end
    local ok, text = pcall(firstAdded, info)
    if not ok then text = "error" end
    if text then
        s.withAdded = s.withAdded + 1
        s.lastAdded = text
    end
end

for _, unit in ipairs(Debug.UNITS) do
    resetSeen(unit)
    local watcher = CreateFrame("Frame")
    watcher:RegisterUnitEvent("UNIT_AURA", unit)
    watcher:SetScript("OnEvent", function(_, _, _, info) onAura(unit, info) end)
end

local function restrictions()
    if not (C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
        and Enum and Enum.AddOnRestrictionType) then
        return "missing"
    end
    local parts = {}
    for _, name in ipairs(RESTRICTIONS) do
        local value = Enum.AddOnRestrictionType[name]
        if value ~= nil then
            parts[#parts + 1] = name .. "=" .. yesNo(C_RestrictedActions.IsAddOnRestrictionActive, value)
        end
    end
    return table.concat(parts, " ")
end

function Debug.Auras()
    ns.Print("auradebug: combat=" .. yesNo(InCombatLockdown))
    local should = C_Secrets and C_Secrets.ShouldAurasBeSecret
    ns.Print("ShouldAurasBeSecret=" .. (should and yesNo(should) or "missing"))
    ns.Print("restrictions: " .. restrictions())
    for _, unit in ipairs(Debug.UNITS) do
        local s = seen[unit]
        local aura = ("UNIT_AURA %d (info secret %d, with added aura %d, last added: %s)")
            :format(s.events, s.secretInfo, s.withAdded, s.lastAdded)
        resetSeen(unit)
        if yesNo(UnitExists, unit) ~= "yes" then
            ns.Print(unit .. ": no unit; " .. aura)
        else
            ns.Print(unit .. ": GetUnitAuras " .. probeList(unit))
            ns.Print(unit .. ": GetAuraDataByIndex " .. probeIndex(unit))
            ns.Print(unit .. ": " .. aura)
        end
    end
end

-- Hooked in front of the regular /fuf handler so this file can go again
-- without touching the command code.
local handler = SlashCmdList.FOREVERUNITFRAMES
SlashCmdList.FOREVERUNITFRAMES = function(msg)
    if type(msg) == "string" and msg:lower():match("^%s*auradebug%s*$") then
        Debug.Auras()
        return
    end
    return handler(msg)
end
