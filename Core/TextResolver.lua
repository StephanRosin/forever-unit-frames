local _, ns = ...

-- Compact, opt-in expression resolver for the unit-frame text slots.
-- Expressions are parsed on style changes. Rendering passes any secret API
-- values straight to FontString:SetFormattedText; it never concatenates,
-- formats or compares secret values in Lua.
local Resolver = {}
ns.TextResolver = Resolver
local Secrets = ns.Secrets
local unpack = unpack or table.unpack

-- Every expression remains data, never executable Lua. Names of older tags and
-- their default number formatting are stable for existing saved profiles.
local TAGS = {
    name = true, firstname = true, forename = true, surname = true, lastname = true,
    shortname = true, initials = true, firstinitial = true, lastinitial = true,
    level = true, class = true, race = true, guild = true, faction = true,
    creaturetype = true, classification = true,
    curhp = true, maxhp = true, perhp = true, missinghp = true,
    curpp = true, maxpp = true, perpp = true, missingpp = true,
    curhpraw = true, maxhpraw = true, missinghpraw = true,
    curppraw = true, maxppraw = true, missingppraw = true,
    threatpct = true, threatraw = true, threatstatus = true,
    combo = true, maxcombo = true, combopct = true,
    curxp = true, maxxp = true, perxp = true, restedxp = true, remainingxp = true,
    currep = true, maxrep = true, perrep = true, repname = true, repstanding = true,
    status = true, afk = true, dnd = true, dead = true, ghost = true,
    offline = true, combat = true, pvp = true,
}
Resolver.TAGS = TAGS

local HEALTH = { curhp = true, maxhp = true, perhp = true, missinghp = true,
    curhpraw = true, maxhpraw = true, missinghpraw = true }
local POWER = { curpp = true, maxpp = true, perpp = true, missingpp = true,
    curppraw = true, maxppraw = true, missingppraw = true }
local NAMES = { name = true, firstname = true, forename = true, surname = true, lastname = true,
    shortname = true, initials = true, firstinitial = true, lastinitial = true }
local PROGRESS = { curxp = true, maxxp = true, perxp = true, restedxp = true, remainingxp = true,
    currep = true, maxrep = true, perrep = true, repname = true, repstanding = true }
local COMBO = { combo = true, maxcombo = true, combopct = true }
local THREAT = { threatpct = true, threatraw = true, threatstatus = true }
local STATE = { afk = true, dnd = true, dead = true, ghost = true,
    offline = true, combat = true, pvp = true, status = true }
local PERCENT = { perhp = true, perpp = true, combopct = true,
    perxp = true, perrep = true, threatpct = true, threatraw = true }
local NUMBERS = { curhp = true, maxhp = true, perhp = true, missinghp = true,
    curpp = true, maxpp = true, perpp = true, missingpp = true,
    curhpraw = true, maxhpraw = true, missinghpraw = true,
    curppraw = true, maxppraw = true, missingppraw = true,
    combo = true, maxcombo = true, combopct = true,
    curxp = true, maxxp = true, perxp = true, restedxp = true, remainingxp = true,
    currep = true, maxrep = true, perrep = true,
    threatpct = true, threatraw = true }

-- Syntax: [tag], [tag|fallback], [percenttag:0/1/2], or both modifiers.
-- Unknown simple tags are errors; other bracketed prose is left literal.
local function parse(content)
    if content:sub(1, 1) == "?" then
        local name, yes, no = content:match('^%?([%a][%w_]*)|([^|]*)|(.*)$')
        if not name then return nil, nil, nil, true end
        name = name:lower()
        if not TAGS[name] then return nil, nil, nil, true end
        return name, nil, nil, true, yes, no
    end
    local head, fallback = content:match('^([^|]*)|(.*)$')
    if not head then head = content end
    local name, precision = head:match('^([%a][%w_]*):([^%s:]+)$')
    if not name then name = head:match('^([%a][%w_]*)$') end
    if not name then return nil, nil, nil, false end
    name = name:lower()
    if not TAGS[name] or (precision and
        (not PERCENT[name] or (precision ~= '0' and precision ~= '1' and precision ~= '2')))
        then return nil, nil, nil, true end
    return name, precision and tonumber(precision), fallback, true
end

-- Readable expressions only. No arbitrary Lua, evaluation or functions.
-- Brackets not describing a supported tag are treated as literal text.
-- The options' validator disallows unknown [word] tags to flag typos.
function Resolver.Check(text)
    if type(text) ~= "string" then return false end
    for content in text:gmatch("%[([^%[%]]+)%]") do
        local _, _, _, recognized = parse(content)
        if recognized then
            local name = parse(content)
            if not name then return false end
        end
    end
    return true
end

local function literal(s)
    return (s:gsub("%%", "%%%%"))
end

function Resolver.Compile(expression)
    if not Resolver.Check(expression) then return nil end
    local tokens, plain, withSurname = {}, {}, {}
    local deps = { health = false, power = false, name = false, progress = false,
        combo = false, threat = false, state = false, guild = false }
    local from, count, onlyNumbers, plainSeparators = 1, 0, true, true
    local function addLiteral(s)
        if s == "" then return end
        if s:find("[%a_]") then plainSeparators = false end
        tokens[#tokens + 1] = { literal = s }
        plain[#plain + 1], withSurname[#withSurname + 1] = literal(s), literal(s)
    end
    while true do
        local a, b, content = expression:find("%[([^%[%]]+)%]", from)
        if not a then addLiteral(expression:sub(from)); break end
        local tag, precision, fallback, _, whenTrue, whenFalse = parse(content)
        if not tag then
            -- An ordinary bracketed aside is literal, not a Lua program.
            addLiteral(expression:sub(from, b))
        else
            addLiteral(expression:sub(from, a - 1))
            local spec = PERCENT[tag] and ("%." .. (precision or 0) .. "f") or "%s"
            tokens[#tokens + 1] = { tag = tag, precision = precision, fallback = fallback, spec = spec,
                whenTrue = whenTrue, whenFalse = whenFalse }
            count = count + 1
            onlyNumbers = onlyNumbers and NUMBERS[tag] == true and fallback == nil and whenTrue == nil
            if HEALTH[tag] then deps.health = true end
            if POWER[tag] then deps.power = true end
            if NAMES[tag] then deps.name = true end
            if PROGRESS[tag] then deps.progress = true end
            if COMBO[tag] then deps.combo = true end
            if THREAT[tag] then deps.threat = true end
            if STATE[tag] then deps.state = true end
            if tag == "guild" then deps.guild = true end
            plain[#plain + 1] = whenTrue ~= nil and "%s" or spec
            withSurname[#withSurname + 1] = tag == "name" and whenTrue == nil and "%s %s"
                or (whenTrue ~= nil and "%s" or spec)
        end
        from = b + 1
    end
    return {
        expression = expression, tokens = tokens, format = table.concat(plain),
        surnameFormat = table.concat(withSurname), depends = deps,
        numericOnly = count > 0 and onlyNumbers and plainSeparators,
        values = {},
    }
end

local function mayContainPlayerSurname(unit)
    if ns.Texts.MayHoldSurname(unit) then return true end
    return UnitIsPlayer and Secrets.Bool(UnitIsPlayer, unit) == true
end

local function combinedSurname(unit, first, second)
    -- WoW Forever may return a surname as UnitName's second result, or
    -- combine it with the first value on regional-unique-name realms.
    if type(second) ~= "nil" then return second end
    if not mayContainPlayerSurname(unit) then return "" end
    if Secrets.IsSecret(first) or type(first) ~= "string" then return "" end
    local sep = ns.Texts.Separator()
    local at = first:find(sep, 1, true)
    if at then return first:sub(at + #sep) end
    return ""
end

local function plainFirst(unit, first, second)
    if type(second) ~= "nil" then return first end
    if mayContainPlayerSurname(unit) then return ns.Texts.FirstName(first) end
    return first
end

local function hCurrent(unit, sample)
    return sample and sample.current or UnitHealth(unit)
end
local function hMax(unit, sample)
    return sample and sample.max or UnitHealthMax(unit)
end
local function hPercent(unit, sample)
    return sample and sample.percent or UnitHealthPercent(unit, true, Secrets.PercentCurve())
end
local function hMissing(unit, sample)
    if sample then return sample.missing end
    return UnitHealthMissing(unit)
end

-- A UTF-8 first character, never bytes from the middle of a code point.
-- If the client gives a secret name, retain it unshortened; it must not be
-- inspected via sub/match, or concatenated into an abbreviation.
local function initial(name)
    if Secrets.IsSecret(name) then return name end
    if type(name) ~= "string" then return "" end
    if name == "" then return "" end
    local b = name:byte(1)
    if not b then return "" end
    local count = b < 0x80 and 1 or b < 0xe0 and 2 or b < 0xf0 and 3 or 4
    return name:sub(1, count) .. "."
end

local function namesForInitials(unit, first, last, opts)
    if Secrets.IsSecret(first) or Secrets.IsSecret(last) then return first, nil end
    local given = plainFirst(unit, first, last)
    local family = combinedSurname(unit, first, last)
    -- Test Mode samples are plain display text, not units returned by the
    -- client. Split their surname even on realms without unique names.
    if opts.sampleName and type(first) == "string" and type(last) == "nil" then
        local sep = ns.Texts.Separator()
        local at = first:find(sep, 1, true)
        if at then
            given, family = first:sub(1, at - 1), first:sub(at + #sep)
        end
    end
    return given, family
end

local function safeNumber(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    return ok and Secrets.Number(value) or nil
end

local function valueOrBlank(n, compact)
    if type(n) == "nil" then return "" end
    return compact and Secrets.Abbreviate(n) or n
end

local function progressData(kind, opts)
    if opts.frame and opts.frame.xpRep and opts.frame.xpRep.preview then
        local bar = opts.frame.xpRep
        if kind == "xp" then return bar.xpData end
        return bar.repData
    end
    local provider = ns.XPRepBar
    if not provider then return nil end
    if kind == "xp" and provider.ReadXP then return provider.ReadXP() end
    if kind == "rep" and provider.ReadReputation then return provider.ReadReputation() end
    return nil
end

local function comboData(unit, opts)
    -- Combo points belong to the player against their target; party pets
    -- and arbitrary non-target units must not display this global value.
    if unit ~= "player" and unit ~= "target" then return nil, nil end
    local max = safeNumber(UnitPowerMax, "player", (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4)
    if not max or max <= 0 then return nil, nil end
    local frame = opts.frame
    if frame and frame.comboBar and frame.comboBar.preview then
        return 3, max
    end
    local points = safeNumber(GetComboPoints, "player", "target")
    return points, max
end

local function threatData(unit)
    local victim, actor = unit, "player"
    if unit == "player" or unit == "pet" or unit:match("^party%d") then
        victim, actor = "target", unit
    end
    if type(UnitDetailedThreatSituation) ~= "function" then return nil end
    local ok, tanking, status, scaled, raw = pcall(UnitDetailedThreatSituation, actor, victim)
    if not ok then return nil end
    return Secrets.Number(scaled), Secrets.Number(raw), Secrets.Number(status)
end

local CLASSIFICATION = {
    rare = "Rare", rareelite = "Rare Elite", elite = "Elite", worldboss = "Boss",
    trivial = "", normal = "", minus = "",
}
local THREAT_STATUS = { [0] = "Low", [1] = "Medium", [2] = "High", [3] = "Aggro" }

-- The compiled expression holds a reusable argument list, so rapid
-- UNIT_HEALTH / UNIT_POWER_FREQUENT events don't allocate an array each time.
-- The only dynamic formatting choice is whether UnitName provided a separate
-- surname for [name]; all other formatting strings are precompiled.
function Resolver.Render(fs, plan, unit, showSurname, sample, opts)
    if not plan then fs:SetText(""); return end
    opts = opts or {}
    local first, last
    if plan.depends.name then
        if opts.sampleName then
            first = opts.sampleName
        else
            first, last = UnitName(unit)
        end
    end
    local separate = showSurname and type(last) ~= "nil"
    local initialFirst, initialLast
    local xp, rep, cp, cpMax, threatScaled, threatRaw, threatState
    local progressFetched, comboFetched, threatFetched = false, false, false
    local args, n = plan.values, 0
    for _, entry in ipairs(plan.tokens) do
        local tag = entry.tag
        if tag then
            local value = ""
            if NAMES[tag] and tag ~= "name" and tag ~= "firstname" and tag ~= "forename"
                and tag ~= "surname" and tag ~= "lastname" then
                if initialFirst == nil then
                    initialFirst, initialLast = namesForInitials(unit, first, last, opts)
                    if initialFirst == nil then initialFirst = "" end
                end
            end
            if tag == "name" then
                if type(first) ~= "nil" then value = first end
                if not separate and not showSurname then value = plainFirst(unit, first, last) end
            elseif tag == "firstname" or tag == "forename" then
                if opts.sampleName then
                    value = namesForInitials(unit, first, last, opts)
                else
                    value = plainFirst(unit, first, last)
                end
            elseif tag == "surname" or tag == "lastname" then
                if opts.sampleName then
                    local _, family = namesForInitials(unit, first, last, opts)
                    value = family
                else
                    value = combinedSurname(unit, first, last)
                end
            elseif tag == "firstinitial" then
                value = initial(initialFirst)
            elseif tag == "lastinitial" then
                value = initial(initialLast)
            elseif tag == "shortname" or tag == "initials" then
                local one, two = initial(initialFirst), initial(initialLast)
                if Secrets.IsSecret(one) or Secrets.IsSecret(two) then
                    -- Do not construct a string from protected name values.
                    value = first or ""
                else
                    value = one
                    if type(two) == "string" and two ~= "" then value = one .. " " .. two end
                end
            elseif tag == "level" then
                value = ns.Texts.LevelText(unit, opts.levelColored)
            elseif tag == "class" then
                -- On this client UnitClass(non-player) can return the NPC's
                -- unit name instead of a class. Only players have a class;
                -- if UnitIsPlayer is unavailable/secret, omit the tag rather
                -- than repeat or misidentify a creature name.
                if Secrets.Bool(UnitIsPlayer, unit) == true then
                    value = UnitClass(unit)
                end
            elseif tag == "race" then
                value = UnitRace(unit)
            elseif tag == "guild" then
                if GetGuildInfo then value = GetGuildInfo(unit) end
            elseif tag == "faction" then
                if UnitFactionGroup then value = UnitFactionGroup(unit) end
            elseif tag == "creaturetype" then
                if UnitCreatureType then value = UnitCreatureType(unit) end
            elseif tag == "classification" then
                local kind = UnitClassification and UnitClassification(unit)
                if Secrets.IsSecret(kind) then value = kind
                else value = CLASSIFICATION[kind] or "" end
            elseif tag == "curhp" or tag == "curhpraw" then
                value = valueOrBlank(hCurrent(unit, sample), tag == "curhp")
            elseif tag == "maxhp" or tag == "maxhpraw" then
                value = valueOrBlank(hMax(unit, sample), tag == "maxhp")
            elseif tag == "perhp" then
                value = hPercent(unit, sample)
            elseif tag == "missinghp" or tag == "missinghpraw" then
                value = valueOrBlank(hMissing(unit, sample), tag == "missinghp")
            elseif tag == "curpp" or tag == "curppraw" then
                value = valueOrBlank(UnitPower(unit), tag == "curpp")
            elseif tag == "maxpp" or tag == "maxppraw" then
                value = valueOrBlank(UnitPowerMax(unit), tag == "maxpp")
            elseif tag == "perpp" then
                value = UnitPowerPercent(unit, nil, false, Secrets.PercentCurve())
            elseif tag == "missingpp" or tag == "missingppraw" then
                value = valueOrBlank(UnitPowerMissing(unit), tag == "missingpp")
            elseif COMBO[tag] then
                if not comboFetched then
                    cp, cpMax = comboData(unit, opts)
                    comboFetched = true
                end
                if tag == "combo" then value = valueOrBlank(cp, false)
                elseif tag == "maxcombo" then value = valueOrBlank(cpMax, false)
                elseif cp and cpMax and cpMax > 0 then value = cp * 100 / cpMax end
            elseif PROGRESS[tag] then
                if not progressFetched then
                    if unit == "player" then
                        xp, rep = progressData("xp", opts), progressData("rep", opts)
                    end
                    progressFetched = true
                end
                if tag == "curxp" then value = xp and Secrets.Abbreviate(xp.value) or ""
                elseif tag == "maxxp" then value = xp and Secrets.Abbreviate(xp.max) or ""
                elseif tag == "perxp" then value = xp and xp.value * 100 / xp.max or ""
                elseif tag == "restedxp" then value = xp and Secrets.Abbreviate(xp.rested) or ""
                elseif tag == "remainingxp" then value = xp and Secrets.Abbreviate(xp.max - xp.value) or ""
                elseif tag == "currep" then value = rep and Secrets.Abbreviate(rep.value) or ""
                elseif tag == "maxrep" then value = rep and Secrets.Abbreviate(rep.max) or ""
                elseif tag == "perrep" then value = rep and rep.value * 100 / rep.max or ""
                elseif tag == "repname" then value = rep and rep.name or ""
                elseif tag == "repstanding" and rep and rep.reaction and GetText then
                    value = GetText("FACTION_STANDING_LABEL" .. rep.reaction, UnitSex("player"))
                end
            elseif THREAT[tag] then
                if not threatFetched then
                    threatScaled, threatRaw, threatState = threatData(unit)
                    threatFetched = true
                end
                if tag == "threatpct" then value = threatScaled or ""
                elseif tag == "threatraw" then value = threatRaw or ""
                else value = THREAT_STATUS[threatState] or "" end
            elseif tag == "status" then
                value = opts.statusWord or ""
            elseif tag == "dead" or tag == "ghost" or tag == "offline" then
                value = opts.statusState == tag:upper() and tag:gsub("^%l", string.upper) or ""
            elseif tag == "afk" or tag == "dnd" then
                value = opts.awayState == tag:upper() and tag:upper() or ""
            elseif tag == "combat" then
                value = Secrets.Bool(UnitAffectingCombat, unit) and "Combat" or ""
            elseif tag == "pvp" then
                value = Secrets.Bool(UnitIsPVP, unit) and "PvP" or ""
            end
            if entry.whenTrue ~= nil then
                if Secrets.IsSecret(value) then
                    -- A protected value has no inspectable truthiness. Never
                    -- branch on it or leak a misleading true/false answer.
                    value = ""
                elseif type(value) == "nil" or value == "" or value == false then
                    value = entry.whenFalse
                else
                    value = entry.whenTrue
                end
            elseif not Secrets.IsSecret(value) and (type(value) == "nil" or value == "")
                and entry.fallback ~= nil then value = entry.fallback end
            -- Any public percentage is rounded here, so mixed secret and
            -- nonsecret expressions can use a native %s for the latter.
            if PERCENT[tag] and not Secrets.IsSecret(value) and type(value) == "number" then
                value = entry.spec:format(value)
            end
            n = n + 1
            -- Pass protected data through as native FontString arguments.
            args[n] = type(value) == "nil" and "" or value
            if tag == "name" and separate and entry.whenTrue == nil then
                n = n + 1
                args[n] = last
            end
        end
    end
    for i = n + 1, #args do args[i] = nil end
    if n == 0 then
        fs:SetText(plan.expression)
        return
    end
    if #plan.tokens == 1 and plan.tokens[1].tag and not separate
        and not Secrets.IsSecret(args[1]) then
        fs:SetText(args[1])
        return
    end

    local readable = true
    for i = 1, n do
        if Secrets.IsSecret(args[i]) then readable = false; break end
    end
    if readable then
        local out = plan.output or {}
        plan.output = out
        local k, at = 0, 0
        for _, entry in ipairs(plan.tokens) do
            k = k + 1
            if entry.literal then
                out[k] = entry.literal
            else
                at = at + 1
                local value = args[at]
                out[k] = tostring(value)
                if entry.tag == "name" and separate and entry.whenTrue == nil then
                    at = at + 1
                    k = k + 1
                    out[k] = " "
                    k = k + 1
                    out[k] = tostring(args[at])
                end
            end
        end
        for i = k + 1, #out do out[i] = nil end
        fs:SetText(table.concat(out))
        return
    end
    -- When at least one value is protected, build the format without ever
    -- inspecting that value. Protected percentages keep the native %f;
    -- all public values (including missing percentages) use %s.
    local parts, k, at = plan.secretFormatParts or {}, 0, 0
    plan.secretFormatParts = parts
    for _, entry in ipairs(plan.tokens) do
        k = k + 1
        if entry.literal then
            parts[k] = literal(entry.literal)
        else
            at = at + 1
            parts[k] = entry.whenTrue == nil and PERCENT[entry.tag]
                and Secrets.IsSecret(args[at]) and entry.spec or "%s"
            if entry.tag == "name" and separate then
                at = at + 1
                k = k + 1
                parts[k] = " %s"
            end
        end
    end
    for i = k + 1, #parts do parts[i] = nil end
    fs:SetFormattedText(table.concat(parts), unpack(args, 1, n))
end
