local _, ns = ...

-- HoTs cast by the local player. Native UnitGetIncomingHeals excludes HoT
-- ticks on Forever. In combat, aura amounts and healing-meter values may be
-- secret; never inspect or calculate with those values. This estimate is a
-- separate, deliberately approximate overlay, not a replacement for the
-- client's direct-heal prediction.
local Estimate = {}
ns.HoTEstimate = Estimate

local S = ns.Secrets
local active = {}  -- normalized recipient name -> localized HoT name -> record
local pending = {} -- cast GUID -> recipient, rank ID, HoT data
local elapsed, ticksOn = 0, false
local ticker = CreateFrame("Frame")
local combatTally, inCombat, combatSequence = {}, false, 0
local lastDiagnostic = "No completed calibration samples."
local lastSampleDetails = {}

-- Root IDs only identify localized names. Rank-specific numbers are always
-- obtained from the actual spell ID passed by the cast or aura event.
-- Wild Growth has uneven ticks; its fallback remains a linear estimate.
-- Regrowth/Riptide have direct components, and Lifebloom has a bloom: none
-- of those spells is eligible for healing-meter calibration.
local HOTS = {
    { root = 774,   interval = 3, learn = true },  -- Rejuvenation
    { root = 8936,  interval = 3 },                 -- Regrowth
    { root = 33763, interval = 1 },                 -- Lifebloom
    { root = 48438, interval = 1, variable = true },-- Wild Growth
    { root = 139,   interval = 3, learn = true },  -- Renew
    { root = 61295, interval = 3 },                 -- Riptide
}
local hotNames = {}

local function plain(v, kind) return S.Plain(v, kind) end
local function nameKey(v)
    local name = plain(v, "string")
    if not name or name == "" then return nil end
    return name:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function spellName(id)
    if not C_Spell or not C_Spell.GetSpellName then return nil end
    return plain(C_Spell.GetSpellName(id), "string")
end

local function isHot(id)
    local name = spellName(id)
    if not name then return nil end
    -- Retry unresolved root names, e.g. when spellbook data was not loaded.
    for _, spec in ipairs(HOTS) do
        if not spec.name then
            spec.name = spellName(spec.root)
            if spec.name then hotNames[spec.name] = spec end
        end
    end
    return hotNames[name] and name or nil, hotNames[name]
end

-- The addon currently recognizes English tooltip text. In particular we
-- capture the amount immediately before "over" so a direct component at
-- the beginning of a Regrowth description is not counted as periodic heal.
-- Returns: periodic total, seconds, tick interval if stated in the tooltip.
function Estimate.ParseTooltip(data)
    if not data or type(data.lines) ~= "table" then return nil end
    for _, line in ipairs(data.lines) do
        local str = plain(line.leftText, "string")
        if str then
            local t = str:lower():gsub(",", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if t:find("heal", 1, true) or t:find("restor", 1, true) then
                local interval = tonumber(t:match("every%s+(%d+)%s*s[e]?[c]?"))
                local amt, duration = t:match("(%d+)%s+over%s+(%d+)%s*s[e]?[c]?")
                if not amt then
                    local single
                    single, interval, duration = t:match("(%d+)%s+.-every%s+(%d+)%s*s[e]?[c]?.-for%s+(%d+)%s*s[e]?[c]?")
                    if single then
                        single, interval, duration = tonumber(single), tonumber(interval), tonumber(duration)
                        if interval and interval > 0 then amt = single * math.floor(duration / interval + 0.5) end
                    end
                end
                amt, duration = tonumber(amt), tonumber(duration)
                if amt and amt > 0 and duration and duration >= 3 and duration <= 120 then
                    return amt, duration, tonumber(interval)
                end
            end
        end
    end
end

local function spellHealing(id)
    if not (C_TooltipInfo and C_TooltipInfo.GetSpellByID) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetSpellByID, id)
    if not ok or S.IsSecret(data) then return nil end
    local parsed, amount, duration, interval = pcall(Estimate.ParseTooltip, data)
    if parsed then return amount, duration, interval end
end

local function calibrationEnabled()
    return ns.Config and ns.Config.Profile and ns.Config.Profile()
        and ns.Config.Get("general", "healHotCalibration") or false
end

-- Saved independently from the unit-frame profile because these are
-- character-specific observations (gear, talents, ranks). All stored fields
-- are ordinary numbers obtained only out of combat.
local characterCalibration
local function saved()
    if characterCalibration then return characterCalibration end
    -- UnitGUID can become unreadable in combat. Resolve the character's
    -- SavedVariables table before the first cast and reuse it afterward.
    if InCombatLockdown() or type(ForeverUnitFramesDB) ~= "table" then return nil end
    ForeverUnitFramesDB.hotCalibration = ForeverUnitFramesDB.hotCalibration or { characters = {} }
    local all = ForeverUnitFramesDB.hotCalibration.characters
    if type(all) ~= "table" then return nil end
    local guid = plain(UnitGUID("player"), "string")
    if not guid then return nil end
    if type(all[guid]) ~= "table" then all[guid] = {} end
    characterCalibration = all[guid]
    return characterCalibration
end

local function scaleFor(id, spec)
    if not spec or not spec.learn or not calibrationEnabled() then return 1 end
    local db = saved()
    local row = db and db[id]
    if type(row) ~= "table" then return 1 end
    local n = plain(row.scale, "number")
    if n and n >= 1 and n <= 1.45 then return n end
    return 1
end

local function tickCount(record, now)
    if now >= record.finish then return 0 end
    if not record.interval or record.interval <= 0 or record.variable then return nil end
    local count = math.ceil((record.finish - now - 0.02) / record.interval)
    return math.max(0, math.min(record.totalTicks, count))
end

-- How many tick slots have elapsed since an application. Used only to count
-- candidate post-combat samples; a scheduled tick is NOT proof that healing
-- happened, so the meter learner uses strict ratio/consistency safeguards.
local function elapsedTicks(record, now)
    local through = math.min(record.finish, now) - record.started
    if through <= 0 then return 0 end
    return math.max(0, math.min(record.totalTicks,
        math.floor((through + 0.02) / record.interval)))
end

local function refreshFrames()
    if not ns.HealPrediction then return end
    local function update(frame)
        if frame.healHot and frame.unit and frame.IsVisible and frame:IsVisible()
            and S.Bool(UnitExists, frame.unit) then ns.HealPrediction.Update(frame) end
    end
    for _, frame in pairs(ns.Frames or {}) do update(frame) end
    for _, frame in ipairs(ns.Party and ns.Party.buttons or {}) do update(frame) end
    for _, frame in ipairs(ns.RaidCell and ns.RaidCell.buttons or {}) do update(frame) end
end

local function tallyScheduled(now)
    if not (inCombat and calibrationEnabled()) then return end
    for _, list in pairs(active) do
        for _, rec in pairs(list) do
            if rec.learn and rec.id and not rec.variable and rec.source == "CAST" then
                local already = rec.counted or 0
                local count = elapsedTicks(rec, now)
                if count > already then
                    local t = combatTally[rec.id]
                    if not t then
                        t = { ticks = 0, expected = 0 }
                        combatTally[rec.id] = t
                    end
                    local delta = count - already
                    t.ticks = t.ticks + delta
                    t.expected = t.expected + delta * (rec.total / rec.totalTicks)
                    rec.counted = count
                end
            end
        end
    end
end

local function tick(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.25 then return end
    elapsed = 0
    local now = GetTime()
    tallyScheduled(now)
    local any = false
    for person, list in pairs(active) do
        for spell, rec in pairs(list) do
            if rec.finish <= now then list[spell] = nil else any = true end
        end
        if not next(list) then active[person] = nil end
    end
    refreshFrames()
    if not any then ticker:SetScript("OnUpdate", nil); ticksOn = false end
end

local function startTick()
    if ticksOn then return end
    ticker:SetScript("OnUpdate", tick)
    ticksOn = true
end

local function record(recipient, spell, id, spec, total, duration, interval, finish, source)
    if not recipient or not spell or not total or not duration or not finish then return end
    interval = interval and interval > 0 and interval or spec.interval
    local n = math.max(1, math.floor(duration / interval + 0.5))
    if n > 120 then return end
    active[recipient] = active[recipient] or {}
    local old = active[recipient][spell]
    local new = {
        total = total, duration = duration, started = finish - duration, finish = finish,
        interval = interval, totalTicks = n, variable = spec.variable,
        id = id, learn = spec.learn, source = source,
        scale = scaleFor(id, spec),
    }
    -- An aura read after a cast shouldn't replace the cast-tracked record
    -- if its expiration is almost identical: preserve tally state/phase.
    if source == "AURA" and old and old.id == id
        and math.abs(old.finish - finish) <= 0.3 then
        old.finish = finish
        old.duration = duration
        return
    end
    if inCombat then
        new.counted = elapsedTicks(new, GetTime())
        -- A refreshed cast loses any ticks not yet observed; close the old
        -- application first so projected ticks don't silently disappear.
        if old then tallyScheduled(GetTime()) end
    end
    active[recipient][spell] = new
    startTick()
    refreshFrames()
end

local function unitName(unit)
    if type(UnitFullName) == "function" then
        local a, b = UnitFullName(unit)
        a, b = plain(a, "string"), plain(b, "string")
        if a then
            if b and b ~= "" then return nameKey(a .. "-" .. b), nameKey(a) end
            return nameKey(a)
        end
    end
    if type(UnitName) == "function" then return nameKey(UnitName(unit)) end
end

-- UNIT_SPELLCAST_SENT commonly supplies a name with no realm. Canonicalize
-- it to the full name of a visible unit, or a later aura sync would create
-- a different key and hide fresh casts behind the old snapshot.
local function resolveRecipient(target)
    local key = nameKey(target)
    if not key then return nil end
    if S.Bool(UnitExists, target) then return unitName(target) or key end
    local candidates = { "player", "target", "focus", "mouseover", "pet" }
    for i = 1, 4 do candidates[#candidates + 1] = "party" .. i end
    for i = 1, 40 do candidates[#candidates + 1] = "raid" .. i end
    for _, unit in ipairs(candidates) do
        if S.Bool(UnitExists, unit) then
            local full, short = unitName(unit)
            if (full and full == key) or (short and short == key) then return full or short end
        end
    end
    return key
end

local function remaining(rec, now)
    local left = rec.finish - now
    if left <= 0 then return 0 end
    local count = tickCount(rec, now)
    if count then
        return rec.total / rec.totalTicks * count *
            (calibrationEnabled() and rec.scale or 1)
    end
    -- Wild Growth's tick weights are uneven. Do not invent a schedule.
    return rec.total * math.min(1, left / rec.duration)
end

function Estimate.Amount(unit)
    local key, short = unitName(unit)
    local list = active[key]
    local other = short and active[short]
    if not list and not other then return 0 end
    local now, sum = GetTime(), 0
    -- A short recipient name can survive when the exact realm-qualified name
    -- was secret during casting. Merge these two spell lists, preferring the
    -- most recent application of a duplicate rather than hiding either.
    for spell, rec in pairs(list or {}) do
        local fallback = other and other[spell]
        if fallback and fallback.started > rec.started then rec = fallback end
        sum = sum + remaining(rec, now)
    end
    for spell, rec in pairs(other or {}) do
        if not list or not list[spell] then sum = sum + remaining(rec, now) end
    end
    return math.floor(sum + 0.5)
end

-- Out-of-combat aura sync recovers an effect after /reload. Aura values
-- become secret during combat, so this path must never run there.
function Estimate.ReadAuras(unit)
    if InCombatLockdown() or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
    local recipient = unitName(unit)
    if not recipient then return end
    local found = {}
    local now = GetTime()
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        -- If an aura query itself is protected, retain the cast estimate;
        -- an unreadable list is not evidence the HoT was dispelled.
        if not ok or S.IsSecret(aura) then return end
        if not aura then break end
        if S.IsSecret(aura.spellId) or S.IsSecret(aura.sourceUnit)
            or S.IsSecret(aura.duration) or S.IsSecret(aura.expirationTime) then return end
        local id = plain(aura.spellId, "number")
        local source = plain(aura.sourceUnit, "string")
        local spell, spec
        if id then spell, spec = isHot(id) end
        local duration = plain(aura.duration, "number")
        local finish = plain(aura.expirationTime, "number")
        if spell and source == "player" and finish and duration and duration > 0 and finish > now then
            local total, _, interval = spellHealing(id)
            if total then
                found[spell] = { id = id, spec = spec, total = total,
                    duration = duration, interval = interval, finish = finish }
            end
        end
    end
    local old = active[recipient]
    -- A matching aura should not destroy the cast record: that would lose
    -- its rank-specific tick phase and invalidate post-combat accounting.
    -- Outside combat, however, an aura no longer present is authoritative.
    if old then
        for spell in pairs(old) do
            if not found[spell] then old[spell] = nil end
        end
        if not next(old) then active[recipient] = nil end
    end
    for spell, r in pairs(found) do
        record(recipient, spell, r.id, r.spec, r.total, r.duration, r.interval, r.finish, "AURA")
    end
end

local function anyEnabled()
    if not ns.Config or not ns.Config.Profile or not ns.Config.Profile() then return false end
    for _, key in ipairs({ "player", "target", "targettarget", "pet", "pettarget", "focus", "party" }) do
        if ns.Config.Get(key, "healPrediction") and ns.Config.Get(key, "healHotEnabled") then return true end
    end
    if ns.RaidCell and ns.RaidConfig and ns.RaidConfig.Profile and ns.RaidConfig.Profile() then
        local size = ns.RaidCell.Size()
        if ns.RaidConfig.Get(ns.Raid.Scope(size), "healPrediction") and
            ns.RaidConfig.Get(ns.Raid.Scope(size), "healHotEnabled") then return true end
    end
    return false
end

-- HealingDone=2, not 1 (which is DPS). Reading current-combat data is
-- deferred until PLAYER_REGEN_ENABLED and retried if it remains secret.
local function meterSpellsNow()
    local dm = C_DamageMeter
    if not dm or type(dm.GetCombatSessionSourceFromType) ~= "function" then
        return nil, "healing meter unavailable"
    end
    local types = Enum and Enum.DamageMeterType
    local sessions = Enum and Enum.DamageMeterSessionType
    local healing = types and types.HealingDone or 2
    local current = sessions and sessions.Current or 1
    local guid = plain(UnitGUID("player"), "string")
    if not guid then return nil, "player GUID unavailable" end
    local ok, source = pcall(dm.GetCombatSessionSourceFromType, current, healing, guid)
    if not ok or S.IsSecret(source) then return nil, "secret" end
    if type(source) ~= "table" then return nil, "no current healing session" end
    local okRows, rows = pcall(function()
        local out = {}
        if type(source.combatSpells) ~= "table" then return nil end
        for i = 1, #source.combatSpells do
            local row = source.combatSpells[i]
            if S.IsSecret(row) then return nil end
            local id = plain(row.spellID, "number")
            local total = plain(row.totalAmount, "number")
            if not id or not total then return nil end
            out[id] = (out[id] or 0) + total
        end
        return out
    end)
    if not okRows or not rows then return nil, "secret" end
    return rows
end

-- Only accept upward corrections: overhealing removes effective healing,
-- and can never be used as evidence of a smaller full-strength tick.
-- A single fight isn't enough, nor are fewer than six counted tick slots.
-- Two fights must have similar ratios before a calibrated multiplier is
-- saved. A meter row can still include critical or unrelated heals, so the
-- multiplier is capped and calibration remains opt-in and experimental.
local function learnFromMeter(spells, tally)
    -- Keep per-fight observations for /fuf hotdebug. All values here came
    -- from the out-of-combat meter or our own scheduled-tick counter.
    -- Do not treat the meter as full-strength healing: overhealing is absent.
    lastSampleDetails = {}
    if not calibrationEnabled() then return "Learning disabled" end
    local db = saved()
    if not db then return "No character calibration storage" end
    local eligible, updated, reason = 0, 0, "No eligible HoT samples"
    for id, t in pairs(tally) do
        local measured = spells[id]
        if t.ticks > 0 then
            local detail = ("Spell %d: %d scheduled ticks, estimate %.0f"):format(
                id, t.ticks, t.expected or 0)
            if type(measured) == "number" and (t.expected or 0) > 0 then
                detail = detail .. (", effective meter %.0f, ratio %.3fx"):format(
                    measured, measured / t.expected)
            else
                detail = detail .. ", no matching readable meter total"
            end
            lastSampleDetails[#lastSampleDetails + 1] = detail
        end
        if t.ticks >= 6 and t.expected > 0 and type(measured) == "number" then
            eligible = eligible + 1
            local ratio = measured / t.expected
            if ratio >= 1.08 and ratio <= 1.45 then
                local state = db[id]
                if type(state) ~= "table" then state = {}; db[id] = state end
                if type(state.pending) == "number" and math.abs(state.pending - ratio) <= 0.12 then
                    local scale = math.min(1.4, math.max(1, (state.pending + ratio) / 2))
                    state.scale = math.floor(scale * 100 + 0.5) / 100
                    state.samples = (state.samples or 0) + 1
                    state.pending = nil
                    updated = updated + 1
                else
                    state.pending = math.floor(ratio * 1000 + 0.5) / 1000
                    reason = "Upward correction candidate; awaiting a consistent second combat"
                end
            elseif ratio < 0.9 then
                reason = "Below estimate: likely overhealing, missing ticks, or incomplete attribution"
            elseif ratio < 1.08 then
                reason = "Near/below tooltip estimate: no safe upward correction indicated"
            else
                reason = "Above 1.45x: possible criticals, attribution error, or tooltip mismatch"
            end
        elseif t.ticks > 0 then
            reason = "Too few ticks, or missing meter spell data"
        end
    end
    if updated > 0 then return ("Calibrated %d spell rank(s)"):format(updated) end
    if eligible > 0 then return reason end
    return "No eligible pure-HoT rank with >=6 counted ticks"
end
Estimate.LearnFromMeter = learnFromMeter

local function finishCombat()
    tallyScheduled(GetTime())
    inCombat = false
    local tally = combatTally
    combatTally = {}
    if not calibrationEnabled() or not next(tally) then return end
    local sequence = combatSequence
    local function tryRead(tries)
        -- A new fight can begin while the meter is still protected. Its
        -- "Current" session must never be mistaken for the previous one.
        if sequence ~= combatSequence or InCombatLockdown() then return end
        local spells, why = meterSpellsNow()
        if not spells and why == "secret" and tries > 0 and C_Timer and C_Timer.After then
            C_Timer.After(0.5, function() tryRead(tries - 1) end)
            return
        end
        if not spells then
            lastDiagnostic = "Meter data unavailable: " .. (why or "unknown")
            return
        end
        lastDiagnostic = learnFromMeter(spells, tally)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function() tryRead(5) end)
    else
        tryRead(0)
    end
end

-- Safe diagnostic: all information is addon-derived, never secret combat
-- values. Useful when verifying the post-combat meter on Forever builds.
function Estimate.DebugLines()
    local lines = { "HoT calibration: " .. (calibrationEnabled() and "ON" or "OFF") }
    lines[#lines + 1] = lastDiagnostic
    for i = 1, math.min(6, #lastSampleDetails) do
        lines[#lines + 1] = lastSampleDetails[i]
    end
    local db = saved()
    if db then
        local count = 0
        for id, row in pairs(db) do
            if type(id) == "number" and type(row) == "table" then
                count = count + 1
                lines[#lines + 1] = ("Spell %d: scale %.2f, samples %d%s"):format(
                    id, row.scale or 1, row.samples or 0,
                    row.pending and (", provisional " .. string.format("%.2f", row.pending)) or "")
                if count >= 12 then break end
            end
        end
    end
    return lines
end

ns.On("UNIT_SPELLCAST_SENT", function(_, caster, target, castGUID, id)
    if caster ~= "player" or not plain(id, "number") or not anyEnabled() then return end
    local spell, spec = isHot(id)
    if not spell then return end
    local guid = plain(castGUID, "string")
    if not guid then return end
    local recipient = resolveRecipient(target)
    if not recipient then return end
    pending[guid] = { recipient = recipient, spell = spell, id = id, spec = spec }
end)

ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, caster, castGUID, id)
    if caster ~= "player" then return end
    local guid = plain(castGUID, "string")
    local rec = guid and pending[guid]
    if guid then pending[guid] = nil end
    if not rec or rec.id ~= plain(id, "number") then return end
    local total, duration, interval = spellHealing(rec.id)
    if total then
        local now = GetTime()
        record(rec.recipient, rec.spell, rec.id, rec.spec, total, duration,
            interval, now + duration, "CAST")
    end
end)

for _, event in ipairs({ "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
    ns.On(event, function(_, caster, castGUID)
        if caster == "player" and plain(castGUID, "string") then pending[castGUID] = nil end
    end)
end

ns.On("PLAYER_ENTERING_WORLD", function()
    saved()
    -- Resolve names before combat when possible; spell-name APIs may
    -- become protected while encounters are active on Forever.
    for _, spec in ipairs(HOTS) do
        if not spec.name then
            spec.name = spellName(spec.root)
            if spec.name then hotNames[spec.name] = spec end
        end
    end
    wipe(active)
    wipe(pending)
    combatTally = {}
    inCombat = false
    combatSequence = combatSequence + 1
end)

ns.On("PLAYER_REGEN_DISABLED", function()
    combatSequence = combatSequence + 1
    inCombat = true
    combatTally = {}
    local now = GetTime()
    for _, list in pairs(active) do
        for _, rec in pairs(list) do rec.counted = elapsedTicks(rec, now) end
    end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    finishCombat()
    local function sync(frame)
        if frame.unit and frame.healHot and ns.Config.Get(frame.key, "healHotEnabled") then
            Estimate.ReadAuras(frame.unit)
        end
    end
    for _, frame in pairs(ns.Frames or {}) do sync(frame) end
    for _, frame in ipairs(ns.Party and ns.Party.buttons or {}) do sync(frame) end
    for _, frame in ipairs(ns.RaidCell and ns.RaidCell.buttons or {}) do sync(frame) end
    refreshFrames()
end)
