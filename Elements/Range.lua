local _, ns = ...

-- Range fading: party members (and their pets), the target, the focus and
-- the pet are drawn at a lower opacity while out of range.
--
-- Where the range comes from, first answer wins:
-- 1. Yourself: always in range.
-- 2. A spell's own range (C_Spell.IsSpellInRange with the unit): a hostile
--    spell for units you can attack (UnitCanAttack), a friendly one for
--    friends (UnitIsFriend). Each class has its picks (CLASS_SPELLS below);
--    the General settings rangeFriendlySpell / rangeHostileSpell replace
--    them with any spell, by name or ID. Documented without SecretReturns
--    (SpellDocumentation.lua): true, false, or nil when the check is invalid
--    (unknown spell, invalid target). Only a plain true or false counts;
--    nil, a secret, an error or a spell the player does not know goes on to
--    the next source. Should the client refuse or block the call (an error
--    is only skipped; ADDON_ACTION_BLOCKED / _FORBIDDEN naming it), it is
--    not asked again this session.
-- 3. Group members (party tokens, or a target or focus in the group):
--    UnitInRange, as Blizzard's raid frames (CompactUnitFrame_UpdateInRange:
--    out of range = checked and not in range). Both answers are documented
--    with SecretReturns. A secret "in range" goes untouched to
--    SetAlphaFromBoolean, which takes secret booleans from tainted code
--    (SimpleFrameAPIDocumentation.lua: AllowedWhenTainted); nothing is
--    compared. "Not checked", or a secret "checked", means unknown.
-- 4. Everyone else (an enemy target, your pet): CheckInteractDistance(unit,
--    4), the follow distance (about 28 yards). Not documented as secret or
--    restricted; only a plain true or false counts. Refused or blocked
--    calls are not repeated, as for the spell.
-- Nothing known: full opacity.
--
-- The opacity is the unit frame's own alpha. SetAlpha and
-- SetAlphaFromBoolean are not protected functions (unlike SetShown), so
-- the secure frames may fade in combat; aura containers and the other
-- children fade with them, as Blizzard's raid frames do.
--
-- The client sends UNIT_IN_RANGE_UPDATE, but only for group members; one
-- light timer (POLL seconds) checks every shown frame that fades instead,
-- and a whole-frame update (a new target, a party slot) checks at once.
-- The timer only runs while some frame has fading switched on.
local Range = { name = "Range" }
ns.Range = Range

local Config, Secrets, Settings, L = ns.Config, ns.Secrets, ns.Settings, ns.L

Range.POLL = 0.2
-- CheckInteractDistance's follow distance.
Range.INTERACT_INDEX = 4
-- Test mode: pretend party member 4 is out of range.
Range.PARTY_SAMPLES = { [4] = true }

-- Frames that may fade: the setting's frames, and the party pets, whose
-- derived scope follows the party's.
local function applies(frame)
    return Settings.AppliesTo(Settings.Get("rangeFade"), frame.key) or frame.key == ns.Party.PET_KEY
end

local function enabled(frame)
    return applies(frame) and Config.Get(frame.key, "rangeFade")
end

local function outAlpha(frame)
    return Config.Get(frame.key, "rangeAlpha") / 100
end

local function groupToken(unit)
    return unit:match("^party%d$") ~= nil or unit:match("^partypet%d$") ~= nil or unit:match("^raid") ~= nil
end

-- A plain or secret boolean ("in range"), or nil when unknown.
local function groupRange(unit)
    local ok, inRange, checked = pcall(UnitInRange, unit)
    if not ok or Secrets.IsSecret(checked) or checked ~= true then return nil end
    return inRange
end

-- Set once CheckInteractDistance was refused or blocked.
local interactBroken = false

-- A plain boolean, or nil when unknown.
local function interactRange(unit)
    if interactBroken then return nil end
    local ok, near = pcall(CheckInteractDistance, unit, Range.INTERACT_INDEX)
    if not ok then
        interactBroken = true
        return nil
    end
    if Secrets.IsSecret(near) or type(near) ~= "boolean" then return nil end
    return near
end

-- Spells ------------------------------------------------------------------------
-- Classic spells whose range suits fading, by class and reaction. A family
-- lists one spell's ranks by ID, rank 1 first; ranks share their range.
-- The highest rank the player knows is asked (IsSpellInRange takes any
-- spell identifier; a known ID is unambiguous); a family none of whose IDs
-- is known is looked up once more by the spell's name, so a rank missing
-- here still counts. Several families: the first that answers wins
-- (Fireball before Frostbolt). petOnly: only measures your own pet.
--
-- Left out on purpose (the fallbacks measure instead): melee reach
-- (Sinister Strike, Heroic Strike, Judgement, Hammer of Justice: 5 to 10
-- yards would fade every enemy not in melee), Charge (8 to 25 yards, so
-- false up close) and Throw (needs a thrown weapon, and reaches barely
-- further than the follow distance).
Range.CLASS_SPELLS = {
    PRIEST = {
        friendly = {
            { 2050, 2052, 2053 },                                        -- Lesser Heal, 40 yd
            { 2054, 2055, 6063, 6064 },                                  -- Heal, 40 yd
        },
        hostile = { { 585, 591, 598, 984, 1004, 6060, 10933, 10934 } },  -- Smite, 30 yd
    },
    DRUID = {
        friendly = { { 5185, 5186, 5187, 5188, 5189, 6778, 8903, 9758, 9888, 9889, 25297 } }, -- Healing Touch, 40 yd
        hostile = { { 5176, 5177, 5178, 5179, 5180, 6780, 8905, 9912 } },                     -- Wrath, 30 yd
    },
    SHAMAN = {
        friendly = { { 331, 332, 547, 913, 939, 959, 8005, 10395, 10396, 25357 } },           -- Healing Wave, 40 yd
        hostile = { { 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208 } },          -- Lightning Bolt, 30 yd
    },
    PALADIN = {
        friendly = { { 635, 639, 647, 1026, 1042, 3472, 10328, 10329, 25292 } },              -- Holy Light, 40 yd
        hostile = {},
    },
    MAGE = {
        friendly = { { 1459, 1460, 1461, 10156, 10157 } },                                    -- Arcane Intellect, 30 yd
        hostile = {
            { 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306 },     -- Fireball, 35 yd
            { 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304 },            -- Frostbolt, 30 yd
        },
    },
    WARLOCK = {
        friendly = { { 5697 } },                                                              -- Unending Breath, 30 yd
        hostile = { { 686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661, 25307 } },        -- Shadow Bolt, 30 yd
    },
    HUNTER = {
        friendly = { { 136, 3111, 3661, 3662, 13542, 13543, 13544, petOnly = true } },        -- Mend Pet, pet only
        hostile = { { 75 } },                                                                 -- Auto Shot, 8-35 yd
    },
    ROGUE = { friendly = {}, hostile = {} },
    WARRIOR = { friendly = {}, hostile = {} },
}

local OVERRIDE = { friendly = "rangeFriendlySpell", hostile = "rangeHostileSpell" }

local function playerClass()
    local ok, _, class = pcall(UnitClass, "player")
    if not ok or Secrets.IsSecret(class) or type(class) ~= "string" then return nil end
    return class
end

local function classFamilies(reaction)
    local entry = Range.CLASS_SPELLS[playerClass() or ""]
    return entry and entry[reaction] or {}
end

-- Whether the player's class has a spell for this reaction (the target's
-- and focus's range fading default).
function Range.HasClassSpell(reaction)
    return #classFamilies(reaction) > 0
end

-- C_SpellBook.IsSpellKnown (the player's spell bank); the old globals only
-- exist with Blizzard's deprecation fallbacks loaded.
local function isKnown(id)
    local book = C_SpellBook
    local fn = (book and book.IsSpellKnown) or IsPlayerSpell or IsSpellKnown
    if not fn then return false end
    local ok, known = pcall(fn, id)
    return ok and not Secrets.IsSecret(known) and known == true
end

local function spellInfo(identifier)
    if not (C_Spell and C_Spell.GetSpellInfo) then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, identifier)
    if ok and type(info) == "table" and not Secrets.IsSecret(info.spellID) and type(info.spellID) == "number" then
        return info
    end
    return nil
end

-- The spell ID the player knows for a name or an ID, or nil.
local function knownSpell(identifier)
    if type(identifier) == "number" and isKnown(identifier) then return identifier end
    local info = spellInfo(identifier)
    if not info then return nil end
    if isKnown(info.spellID) then return info.spellID end
    -- An ID of a rank not learned: the rank the player has, by name.
    if type(identifier) == "number" and type(info.name) == "string" and not Secrets.IsSecret(info.name) then
        local byName = spellInfo(info.name)
        if byName and isKnown(byName.spellID) then return byName.spellID end
    end
    return nil
end

local function familySpell(family)
    for i = #family, 1, -1 do
        if isKnown(family[i]) then return family[i] end
    end
    return knownSpell(family[1])
end

local function describe(id, petOnly)
    local info = spellInfo(id)
    local minRange = info and Secrets.Number(info.minRange) or 0
    local name = info and not Secrets.IsSecret(info.name) and info.name or tostring(id)
    return { id = id, name = name, minRange = minRange, petOnly = petOnly == true }
end

-- The user's spell for a reaction; "" is the class's own.
local function override(reaction)
    if not Config.Profile() then return "" end
    return Config.Get("general", OVERRIDE[reaction])
end

local function resolve(reaction)
    local text = override(reaction)
    if text ~= "" then
        local id = knownSpell(tonumber(text:match("^%d+$") or "") or text)
        return { spells = id and { describe(id) } or {}, custom = true }
    end
    local spells = {}
    for _, family in ipairs(classFamilies(reaction)) do
        local id = familySpell(family)
        if id then spells[#spells + 1] = describe(id, family.petOnly) end
    end
    return { spells = spells }
end

local cache = {}

-- Forget what was resolved: spells learned, a setting changed.
function Range.Invalidate()
    cache = {}
end

local function resolved(reaction)
    local r = cache[reaction]
    if not r then
        r = resolve(reaction)
        cache[reaction] = r
    end
    return r
end

-- The spells asked for a reaction: { id, name, minRange, petOnly } each.
function Range.Spells(reaction)
    return resolved(reaction).spells
end

-- The options hint under a spell field.
function Range.SpellHint(reaction)
    local r = resolved(reaction)
    local names = {}
    for _, spell in ipairs(r.spells) do names[#names + 1] = spell.name end
    if r.custom then
        if #names == 0 then return L.RANGE_SPELL_UNKNOWN end
        return L.RANGE_SPELL_IN_USE:format(names[1])
    end
    if #names == 0 then return L.RANGE_SPELL_NO_AUTO end
    return L.RANGE_SPELL_AUTO:format(table.concat(names, ", "))
end

-- Set once IsSpellInRange was blocked.
local spellBroken = false

local function isPet(unit)
    return unit == "pet" or Secrets.Bool(UnitIsUnit, unit, "pet") == true
end

local function reactionOf(unit)
    if Secrets.Bool(UnitCanAttack, "player", unit) then return "hostile" end
    if Secrets.Bool(UnitIsFriend, "player", unit) then return "friendly" end
    return nil
end

-- A plain boolean, or nil when no spell answers.
local function spellRange(unit)
    if spellBroken or not (C_Spell and C_Spell.IsSpellInRange) then return nil end
    local reaction = reactionOf(unit)
    if not reaction then return nil end
    for _, spell in ipairs(Range.Spells(reaction)) do
        if not spell.petOnly or isPet(unit) then
            local ok, inRange = pcall(C_Spell.IsSpellInRange, spell.id, unit)
            if ok and not Secrets.IsSecret(inRange) and type(inRange) == "boolean" then
                -- Closer than a spell's minimum range reads as out of
                -- range: within the follow distance it is near.
                if inRange == false and spell.minRange > 0 then
                    local near = interactRange(unit)
                    if near ~= false then return near end
                end
                return inRange
            end
        end
    end
    return nil
end

-- A plain or secret boolean, or nil when unknown.
function Range.InRange(unit)
    if unit == "player" or Secrets.Bool(UnitIsUnit, unit, "player") then return true end
    local bySpell = spellRange(unit)
    if bySpell ~= nil then return bySpell end
    if groupToken(unit) or Secrets.Bool(UnitInParty, unit) then return groupRange(unit) end
    return interactRange(unit)
end

local function blocked(_, addon, fn)
    if addon ~= ns.name or type(fn) ~= "string" then return end
    if fn:find("CheckInteractDistance", 1, true) then interactBroken = true end
    if fn:find("IsSpellInRange", 1, true) then spellBroken = true end
end
ns.On("ADDON_ACTION_BLOCKED", blocked)
ns.On("ADDON_ACTION_FORBIDDEN", blocked)

-- Spells learned or the spell settings changed: resolve again when next
-- asked. The poll picks the change up.
ns.On("SPELLS_CHANGED", Range.Invalidate)
ns.On("PLAYER_LOGIN", Range.Invalidate)
ns.Listen("CONFIG_CHANGED", function(_, key)
    if key == nil or key == OVERRIDE.friendly or key == OVERRIDE.hostile then Range.Invalidate() end
end)

-- Opacity from a plain or secret boolean; nil is full opacity.
local function apply(frame, inRange)
    if type(inRange) == "nil" then
        frame:SetAlpha(1)
        return
    end
    if pcall(frame.SetAlphaFromBoolean, frame, inRange, 1, outAlpha(frame)) then return end
    -- A client without it: only a plain answer can be used.
    if Secrets.IsSecret(inRange) then frame:SetAlpha(1) else frame:SetAlpha(inRange and 1 or outAlpha(frame)) end
end

local function check(frame)
    if frame.rangeSample ~= nil then
        apply(frame, not frame.rangeSample)
        return
    end
    if not enabled(frame) or not (frame.unit and UnitExists(frame.unit)) then
        frame:SetAlpha(1)
        return
    end
    apply(frame, Range.InRange(frame.unit))
end

function Range.Build() end

-- Whether any frame has fading on (the party's setting covers its pets).
local SCOPES = { "party", "target", "focus", "pet" }
local function anyEnabled()
    for _, scope in ipairs(SCOPES) do
        if Config.Get(scope, "rangeFade") then return true end
    end
    return false
end

-- The timer runs only while it has something to do.
local function syncDriver()
    Range.driver:SetShown(anyEnabled())
end

function Range.Style(frame)
    syncDriver()
    if applies(frame) then check(frame) end
end

function Range.Update(frame)
    if applies(frame) then check(frame) end
end

-- In test mode rangeSample is true for a member shown out of range,
-- false for the others; nil outside test mode.
function Range.Preview(frame, on)
    if not applies(frame) then return end
    if on then
        frame.rangeSample = (frame.sampleIndex and Range.PARTY_SAMPLES[frame.sampleIndex]) and true or false
        check(frame)
        return
    end
    frame.rangeSample = nil
    check(frame)
end

-- The poll: every shown frame that fades and shows a live unit.
local function poll()
    ns.Units.ForEachFrame(function(frame)
        if frame.rangeSample == nil and frame:IsShown() and enabled(frame) and frame.unit
            and UnitExists(frame.unit) then
            check(frame)
        end
    end)
end

local driver, elapsed = CreateFrame("Frame"), 0
Range.driver = driver
driver:Hide()
driver:SetScript("OnUpdate", function(_, seconds)
    elapsed = elapsed + seconds
    if elapsed < Range.POLL then return end
    elapsed = 0
    poll()
end)

ns.RegisterElement(Range)
