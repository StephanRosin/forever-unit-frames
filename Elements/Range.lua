local _, ns = ...

-- Range fading: party members (and their pets), the target, the focus and
-- the pet are drawn at a lower opacity while out of range.
--
-- Where the range comes from, first answer wins:
-- 1. Yourself: always in range.
-- 2. The General settings, per reaction (UnitCanAttack: hostile,
--    UnitIsFriend: friendly; neither goes straight to 3 and 4). Mode AUTO
--    is the spell, or yards when there is none; SPELL; YARDS; OFF: that
--    reaction never fades (in range, nothing is asked).
--    * Spell: C_Spell.IsSpellInRange with the unit. Each class has its
--      picks (CLASS_SPELLS below); rangeFriendlySpell / rangeHostileSpell
--      replace them by name or ID. Documented without SecretReturns
--      (SpellDocumentation.lua): true, false, or nil when the check is
--      invalid. A spell the player does not know gives no answer.
--    * Yards: UnitDistanceSquared when the client checked it (group
--      members), compared as a plain number; else an item probe
--      (C_Item.IsItemInRange, ITEMS below, the largest range at or below
--      the setting, friendly ones out of combat only); else, outside the
--      group, CheckInteractDistance at the threshold nearest the setting.
--    Only a plain true or false counts; nil, a secret or an error goes on
--    to the next source. A spell blocked by the client (ADDON_ACTION_
--    BLOCKED / _FORBIDDEN naming IsSpellInRange) is not asked again this
--    session.
-- 3. Group members (party tokens, or a target or focus in the group):
--    UnitInRange, as Blizzard's raid frames (CompactUnitFrame_UpdateInRange:
--    out of range = checked and not in range). Both answers are documented
--    with SecretReturns. A secret "in range" goes untouched to
--    SetAlphaFromBoolean, which takes secret booleans from tainted code
--    (SimpleFrameAPIDocumentation.lua: AllowedWhenTainted); nothing is
--    compared. "Not checked", or a secret "checked", means unknown.
-- 4. Everyone else (an enemy target, your pet): CheckInteractDistance(unit,
--    4), the follow distance (about 28 yards). Not documented as secret or
--    restricted; only a plain true or false counts. Units you cannot
--    attack are not measured with it in combat (restricted on retail). A
--    refused or blocked call is not repeated this session.
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

local function attackable(unit)
    return Secrets.Bool(UnitCanAttack, "player", unit) == true
end

-- A plain boolean, or nil when unknown. index: CheckInteractDistance's
-- (INTERACT_YARDS). Units you cannot attack are not measured in combat:
-- the retail client restricts it there (LibRangeCheck does the same), and
-- one refusal would stop it for the session.
local function interactRange(unit, index)
    if interactBroken then return nil end
    if InCombatLockdown() and not attackable(unit) then return nil end
    local ok, near = pcall(CheckInteractDistance, unit, index or Range.INTERACT_INDEX)
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
    if attackable(unit) then return "hostile" end
    if Secrets.Bool(UnitIsFriend, "player", unit) then return "friendly" end
    return nil
end

-- A plain boolean, or nil when no spell answers.
local function spellRange(unit, reaction)
    if spellBroken or not (C_Spell and C_Spell.IsSpellInRange) then return nil end
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

-- Yards ---------------------------------------------------------------------------
-- Items whose use range is known, as probes for a range in yards
-- (C_Item.IsItemInRange works with an item ID once the item's data is
-- cached, without the item in the bags). Classic items, by the units they
-- are used on; ranges ascending. The probe used is the largest range at
-- or below the setting whose data is cached.
Range.ITEMS = {
    friendly = {
        { range = 5, 1970, 8149 },      -- Restoring Balm, Voodoo Charm
        { range = 10, 21267, 17626 },   -- Toasting Goblet, Frostwolf Muzzle
        { range = 15, 1251 },           -- Linen Bandage
        { range = 20, 21519 },          -- Mistletoe
        { range = 30, 1180, 954 },      -- Scroll of Stamina, Scroll of Strength
        { range = 35, 18904 },          -- Zorbin's Ultra-Shrinker
        { range = 40, 18662, 11562 },   -- Heavy Leather Ball, Crystal Restore
    },
    hostile = {
        { range = 5, 8149 },            -- Voodoo Charm
        { range = 10, 17626 },          -- Frostwolf Muzzle
        { range = 20, 10645, 1191 },    -- Gnomish Death Ray, Bag of Marbles
        { range = 25, 13289 },          -- Egan's Blaster
        { range = 30, 835, 7734, 4941 }, -- Large Rope Net, Six Demon Bag, Really Sticky Glue
        { range = 35, 18904 },          -- Zorbin's Ultra-Shrinker
        { range = 40, 4945 },           -- Faintly Glowing Skull
    },
}
-- CheckInteractDistance's indexes by their yards, the last resort.
Range.INTERACT_YARDS = { { yards = 10, index = 3 }, { yards = 11, index = 2 }, { yards = 28, index = 4 } }

local MODE = { friendly = "rangeFriendlyMode", hostile = "rangeHostileMode" }
local YARDS = { friendly = "rangeFriendlyYards", hostile = "rangeHostileYards" }

local function setting(key, fallback)
    if not Config.Profile() then return fallback end
    return Config.Get("general", key)
end

-- "spell", "yards" or "off": how a reaction is measured.
local function method(reaction)
    local mode = setting(MODE[reaction], "AUTO")
    if mode == "AUTO" then return #Range.Spells(reaction) > 0 and "spell" or "yards" end
    if mode == "OFF" then return "off" end
    return mode == "SPELL" and "spell" or "yards"
end

-- Whether a reaction may fade at all.
function Range.ReactionOn(reaction)
    return setting(MODE[reaction], "AUTO") ~= "OFF"
end

local function isCached(id)
    local fn = C_Item and C_Item.IsItemDataCachedByID
    if not fn then return true end
    local ok, cached = pcall(fn, id)
    return ok and cached == true
end

-- The probe for a range: its range and cached item IDs, or nil.
local function probeFor(reaction, yards)
    local list = Range.ITEMS[reaction]
    for i = #list, 1, -1 do
        local probe = list[i]
        if probe.range <= yards then
            local items = {}
            for _, id in ipairs(probe) do
                if isCached(id) then items[#items + 1] = id end
            end
            if #items > 0 then return probe.range, items end
        end
    end
    return nil
end

local function interactFor(yards)
    local best
    for _, t in ipairs(Range.INTERACT_YARDS) do
        if not best or math.abs(t.yards - yards) < math.abs(best.yards - yards) then best = t end
    end
    return best
end

-- The exact distance: plain numbers only, as checked by the client.
local function distanceRange(unit, yards)
    if not UnitDistanceSquared then return nil end
    local ok, squared, checked = pcall(UnitDistanceSquared, unit)
    if not ok or Secrets.IsSecret(checked) or checked ~= true then return nil end
    squared = Secrets.Number(squared)
    if not squared then return nil end
    return squared <= yards * yards
end

local function itemInRange()
    return (C_Item and C_Item.IsItemInRange) or IsItemInRange
end

-- Friendly probes only out of combat (restricted there on retail).
local function itemRange(unit, reaction, yards)
    local fn = itemInRange()
    if not fn or (reaction == "friendly" and InCombatLockdown()) then return nil end
    local _, items = probeFor(reaction, yards)
    for _, id in ipairs(items or {}) do
        local ok, inRange = pcall(fn, id, unit)
        if ok and not Secrets.IsSecret(inRange) and type(inRange) == "boolean" then return inRange end
    end
    return nil
end

-- Group members without a distance or item answer go on to UnitInRange.
local function yardsRange(unit, reaction, group)
    local yards = setting(YARDS[reaction], 30)
    local r = distanceRange(unit, yards)
    if r ~= nil then return r end
    r = itemRange(unit, reaction, yards)
    if r ~= nil or group then return r end
    return interactRange(unit, interactFor(yards).index)
end

-- The options hint under a mode: what measures, for units outside the
-- group (group members use their exact distance when the client has it).
function Range.MethodHint(reaction)
    local how = method(reaction)
    if how == "off" then return L.RANGE_USING_OFF end
    if how == "spell" then
        local spell = Range.Spells(reaction)[1]
        if not spell then return L.RANGE_USING_STANDARD end
        return L.RANGE_USING_SPELL:format(spell.name)
    end
    local yards = setting(YARDS[reaction], 30)
    if reaction == "friendly" then return L.RANGE_USING_DISTANCE:format(yards) end
    local range = probeFor(reaction, yards)
    if range then return L.RANGE_USING_ITEM:format(range) end
    return L.RANGE_USING_INTERACT:format(interactFor(yards).yards)
end

-- Item data is loaded once, out of combat.
local function loadItems()
    local request = C_Item and C_Item.RequestLoadItemDataByID
    if not request then return end
    for _, list in pairs(Range.ITEMS) do
        for _, probe in ipairs(list) do
            for _, id in ipairs(probe) do pcall(request, id) end
        end
    end
end
ns.On("PLAYER_LOGIN", function() ns.AfterCombat("rangeItems", loadItems) end)

-- A plain or secret boolean, or nil when unknown.
function Range.InRange(unit)
    if unit == "player" or Secrets.Bool(UnitIsUnit, unit, "player") then return true end
    local group = groupToken(unit) or Secrets.Bool(UnitInParty, unit) == true
    local reaction = reactionOf(unit)
    if reaction then
        local how, r = method(reaction), nil
        if how == "off" then return true end
        if how == "spell" then r = spellRange(unit, reaction) else r = yardsRange(unit, reaction, group) end
        if r ~= nil then return r end
    end
    if group then return groupRange(unit) end
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
    if not (Range.ReactionOn("friendly") or Range.ReactionOn("hostile")) then return false end
    for _, scope in ipairs(SCOPES) do
        if Config.Get(scope, "rangeFade") then return true end
    end
    return false
end

-- The timer runs only while it has something to do.
local function syncDriver()
    Range.driver:SetShown(anyEnabled())
end

-- A mode switched off or on starts or stops the timer; the next check
-- (the poll, or the restyle) redraws the frames.
ns.Listen("CONFIG_CHANGED", function(_, key)
    if key == nil or key == MODE.friendly or key == MODE.hostile then
        syncDriver()
        ns.Units.ForEachFrame(function(frame) if applies(frame) then check(frame) end end)
    end
end)

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
