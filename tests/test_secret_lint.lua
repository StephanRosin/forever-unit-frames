-- Values the client may hand out as secrets must never be tested or
-- compared in Lua (`if v`, `v == x`, `not v`, `v and a or b`, arithmetic):
-- in the client that is an error, in the mock a secret is a table and so
-- simply true. This looks at the addon's source for the plain cases: such
-- a call right in a condition or comparison, and a local holding its
-- result that one of the next lines tests. Going through Secrets.* or
-- issecretvalue is fine. A heuristic over the text, not a parser: it
-- guards against the common slip, not every one.

-- Functions with secret returns (Blizzard_APIDocumentationGenerated:
-- SecretReturns / SecretWhen...) that the addon reads.
local APIS = { "UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax", "UnitPowerPercent",
    "UnitHealthPercent", "UnitInRange", "UnitIsUnit", "UnitDetailedThreatSituation", "UnitThreatSituation",
    "UnitName", "UnitGetTotalAbsorbs", "UnitGetIncomingHeals", "UnitIsConnected", "UnitIsDeadOrGhost",
    "UnitGroupRolesAssigned" }

local function esc(s) return (s:gsub("%p", "%%%0")) end

local function guarded(line) return line:find("Secrets", 1, true) or line:lower():find("issecret", 1, true) end

-- The places in `text` (a file's source) that test a secret; each
-- "line: text".
local function findings(text)
    local lines, out = {}, {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
    local function tests(line, name)
        local n = esc(name)
        for _, p in ipairs({ "%f[%w_]if%s+" .. n .. "%f[^%w_]", "%f[%w_]if%s+not%s+" .. n .. "%f[^%w_]",
            "%f[%w_]not%s+" .. n .. "%f[^%w_]", "%f[%w_]" .. n .. "%s*[=~<>]=?", "%f[%w_]" .. n .. "%s*[%+%-%*/]",
            "%f[%w_]" .. n .. "%s+and%f[^%w_]", "%f[%w_]" .. n .. "%s+or%f[^%w_]",
            "%f[%w_]and%s+" .. n .. "%f[^%w_]", "%f[%w_]or%s+" .. n .. "%f[^%w_]" }) do
            if line:find(p) then
                -- "x = " is an assignment, not a comparison.
                if not line:find("%f[%w_]" .. n .. "%s*=[^=]") or line:find(n .. "%s*[=~<>]=") then return true end
                if not p:find("[=~<>]", 1, true) then return true end
            end
        end
        return false
    end
    for i, line in ipairs(lines) do
        if not guarded(line) and not line:match("^%s*%-%-") then
            for _, api in ipairs(APIS) do
                -- Right in a condition: if / not / and / or / a comparison.
                local call = esc(api) .. "%("
                if line:find("%f[%w_]if%s+" .. call) or line:find("%f[%w_]not%s+" .. call)
                    or line:find("%f[%w_]and%s+" .. call) or line:find("%f[%w_]or%s+" .. call)
                    or line:find("[=~<>]=%s*" .. call) or line:find("[<>]%s*" .. call) then
                    out[#out + 1] = i .. ": " .. line
                end
                -- local x = Api(...), tested on one of the next lines.
                local names = line:match("^%s*local%s+([%w_, ]+)=%s*" .. call)
                if names then
                    for name in names:gmatch("[%w_]+") do
                        for j = i + 1, math.min(i + 12, #lines) do
                            local next = lines[j]
                            if next:match("^%s*local%s+function") or next:match("^end") then break end
                            if not guarded(next) and not next:match("^%s*%-%-") and tests(next, name) then
                                out[#out + 1] = j .. ": " .. next
                            end
                        end
                    end
                end
            end
        end
    end
    return out
end

-- It finds what it should, and leaves alone what is fine.
local bad = table.concat({
    "if UnitIsUnit(unit, \"target\") then end",
    "local hp = UnitHealth(unit)",
    "if hp > 0 then end",
    "local inRange = UnitInRange(unit)",
    "local alpha = inRange and 1 or 0.5",
}, "\n")
H.check("finds the slips", #findings(bad), 3)
local fine = table.concat({
    "local hp = UnitHealth(unit)",
    "bar:SetValue(hp)",
    "local n = Secrets.Number(UnitPower(unit))",
    "if n and n > 0 then end",
    "local is = UnitIsUnit(unit, \"target\")",
    "if Secrets.IsSecret(is) then end",
}, "\n")
H.check("leaves the right ways alone", #findings(fine), 0)

-- The addon.
for _, file in ipairs(H.TocFiles()) do
    if file:match("%.lua$") and not file:match("^Locales/") then
        local found = findings(H.ReadFile(file))
        H.check(file .. ": no secret tested", #found, 0, table.concat(found, " | "))
    end
end
