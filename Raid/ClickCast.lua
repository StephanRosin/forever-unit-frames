local _, ns = ...

-- Click-casting on the raid cells of every panel (while the raid frames
-- are on) and on the unit frames whose clickCast is on (player, pet,
-- target, target of target, focus, party members; decision 76): the
-- bindings of the raid profile's character-wide scope (Raid/Settings.lua: Raid.CLICK_SLOTS) written as
-- the secure attributes the client reads on a click (SecureTemplates.lua:
-- SecureButton_GetModifiedAttribute): "*type1" for the plain left click,
-- "shift-type1" for Shift and left, with "spell1", "item1", "macrotext1"
-- beside them. Static attributes only (no snippets on this client), and
-- out of combat only: a cell a header makes in combat gets them after
-- combat and does what the XML says until then (left target, right menu).
-- Test mode's pretend cells, party pets and party targets are never
-- touched.
local ClickCast = {}
ns.ClickCast = ClickCast

local Raid, L = ns.Raid, ns.L

-- The attributes a slot may set, beside its type.
local VALUE_ATTRIBUTE = { spell = "spell", item = "item", macro = "macrotext" }
local ATTRIBUTES = { "type", "spell", "item", "macrotext" }
-- The client's action types (SECURE_ACTIONS) per kind.
local ACTION_TYPE = { target = "target", focus = "focus", assist = "assist", menu = "togglemenu", spell = "spell",
    item = "item", macro = "macro" }
-- The client's longest macro.
ClickCast.MACRO_LETTERS = 255

-- A spell ID's name, or nil (C_Spell may be missing; a lookup that
-- raises is no name, as the other spell lookups).
local function spellName(id)
    if not (C_Spell and C_Spell.GetSpellInfo) then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, id)
    return ok and type(info) == "table" and type(info.name) == "string" and info.name or nil
end
ClickCast.SpellName = spellName

-- What a typed value of a kind is stored as, or nil and why (for the
-- chat). A spell by its name as the spell book writes it (the client casts
-- the highest rank it knows; a rank learned later is cast without
-- choosing again); a spell ID becomes that name. An item by its name or
-- ID; a macro text as typed. Empty is kept: the binding does nothing yet.
function ClickCast.TypedValue(kind, text)
    local value = text:match("^%s*(.-)%s*$")
    if value == "" then return "" end
    if kind == "spell" then
        local name = value
        if value:match("^%d+$") then name = spellName(tonumber(value)) end
        local ids = name and ns.RaidSpellbook.IDs(name) or {}
        if #ids == 0 then return nil, L.RAID_TYPED_SPELL_UNKNOWN:format(value) end
        return spellName(ids[1]) or name
    end
    if kind == "macro" and #value > ClickCast.MACRO_LETTERS then
        return nil, L.RAID_TYPED_MACRO_TOO_LONG:format(ClickCast.MACRO_LETTERS)
    end
    return value
end

-- A stored spell (the value of "spell:<value>") as the click-casting
-- tab's list has it (Spellbook.FriendlySpells; list: those spells, read
-- anew when nil): a name (any case) as the spell book spells it, for the
-- highest rank known; a spell ID of a learned rank as it is (that rank),
-- the highest one's as the name. Anything else (not learned, not cast on
-- others, unknown, empty) as it is; so is an ID when the rank the name
-- casts cannot be read (Spellbook.HighestRank). Also whether the list
-- has it.
function ClickCast.NormaliseSpell(value, list)
    local Spellbook = ns.RaidSpellbook
    list = list or Spellbook.FriendlySpells()
    if value:match("^%d+$") then
        local spell, rank = Spellbook.FriendlyRank(tonumber(value), list)
        if not spell then return value, false end
        if rank == Spellbook.HighestRank(spell) then return spell.name, true end
        return value, true
    end
    local spell = value ~= "" and Spellbook.FriendlySpell(value, list)
    if not spell then return value, false end
    return spell.name, true
end

-- The setting keys of every binding (mouse slots and keys).
local function bindingKeys()
    local keys = {}
    for _, slot in ipairs(Raid.CLICK_SLOTS) do keys[#keys + 1] = slot.key end
    for _, slot in ipairs(Raid.CLICK_KEYS) do keys[#keys + 1] = slot.bind end
    return keys
end

-- Spells stored before the tab's dropdowns (up to 0.26) are written once
-- per character as the list has them (NormaliseSpell), so the dropdowns
-- show them: once the spell book is read (SPELLS_CHANGED, or the end of
-- the login loading screen, whichever finds it read), never in combat.
-- Done at once when no binding casts a spell (nothing to normalise); else
-- only when the book is read as a whole (Spellbook.Ready: a racial
-- alone is not the book) and the values are stored.
-- ForeverUnitFramesDB.raidClickSpellsNormalised[character] marks it done
-- (the profile itself keeps only settings, RaidSettings.Sanitise); after
-- that nothing is read again.
local function normalisedTable()
    local db = ForeverUnitFramesDB
    if type(db) ~= "table" then return nil end
    if type(db.raidClickSpellsNormalised) ~= "table" then db.raidClickSpellsNormalised = {} end
    return db.raidClickSpellsNormalised
end

-- The spell bindings with a value: { key, value } pairs.
local function spellBindings()
    local list = {}
    for _, key in ipairs(bindingKeys()) do
        local kind, value = Raid.ParseBinding(ns.RaidConfig.Get("general", key))
        if kind == "spell" and value ~= "" then list[#list + 1] = { key, value } end
    end
    return list
end

function ClickCast.NormaliseStored()
    if InCombatLockdown() or not ns.RaidConfig.Profile() then return end
    local done, me = normalisedTable(), ns.RaidProfiles.CharKey()
    if not done or done[me] then return end
    local bindings = spellBindings()
    if #bindings > 0 then
        if not ns.RaidSpellbook.Ready() then return end
        local list, values = ns.RaidSpellbook.FriendlySpells(), {}
        for _, pair in ipairs(bindings) do
            local normalised = ClickCast.NormaliseSpell(pair[2], list)
            if normalised ~= pair[2] then values[#values + 1] = { pair[1], "spell:" .. normalised } end
        end
        if #values > 0 and not ns.RaidConfig.SetKeys("general", values) then return end
    end
    done[me] = true
end

local function normaliseAfterCombat() ns.AfterCombat("clickSpells", ClickCast.NormaliseStored) end
ns.On("SPELLS_CHANGED", normaliseAfterCombat)
ns.On("LOADING_SCREEN_DISABLED", normaliseAfterCombat)

-- Every binding as stored, by setting key.
function ClickCast.Values()
    local values = {}
    for _, slot in ipairs(Raid.CLICK_SLOTS) do values[slot.key] = ns.RaidConfig.Get("general", slot.key) end
    return values
end

-- The bindings the cells' XML stands for: left target, right menu.
function ClickCast.DefaultValues()
    local values = {}
    for _, slot in ipairs(Raid.CLICK_SLOTS) do
        values[slot.key] = ns.RaidSettings.Default(ns.RaidSettings.Get(slot.key), "general")
    end
    return values
end

-- Target where Blizzard's click bindings would stop it (Raid/Settings.lua:
-- a slot's interaction): the clicked cell is the one under the mouse.
ClickCast.TARGET_MACRO = "/target [@mouseover]"

-- One slot's attribute values: { attribute = value } (nothing for a
-- binding that does nothing, a kind without its value included).
local function slotAttributes(slot, binding)
    local kind, value = Raid.ParseBinding(binding or "")
    if not kind or kind == "" then return {} end
    if kind == "target" and not slot.interaction then
        return { type = ACTION_TYPE.macro, macrotext = ClickCast.TARGET_MACRO }
    end
    local attr = VALUE_ATTRIBUTE[kind]
    if attr then
        if value == "" then return {} end
        if kind == "item" and value:match("^%d+$") then value = "item:" .. value end
        -- A spell ID (a fixed rank) stays a number's text: the client
        -- casts it with CastSpellByID, a name with CastSpellByName.
        return { type = ACTION_TYPE[kind], [attr] = value }
    end
    return { type = ACTION_TYPE[kind] }
end

-- Every attribute of every slot with its value (nil: cleared), as
-- { name, value } pairs. values: binding by setting key; a key missing
-- takes its default.
function ClickCast.Plan(values)
    local defaults = ClickCast.DefaultValues()
    local plan = {}
    for _, slot in ipairs(Raid.CLICK_SLOTS) do
        local binding = values[slot.key]
        if binding == nil then binding = defaults[slot.key] end
        local set = slotAttributes(slot, binding)
        for _, attr in ipairs(ATTRIBUTES) do
            plan[#plan + 1] = { slot.prefix .. attr .. slot.button, set[attr] }
        end
    end
    return plan
end

-- Whether Clique (or another addon that does click-casting through the
-- shared ClickCastFrames table, Units/Units.lua) is loaded: Clique's own
-- header frame, or the addon by name.
function ClickCast.Clique()
    if rawget(_G, "ClickCastHeader") ~= nil then return true end
    local addons = C_AddOns
    if addons and addons.IsAddOnLoaded then
        local ok, loaded = pcall(addons.IsAddOnLoaded, "Clique")
        return ok and loaded == true
    end
    return false
end

-- On: switched on, or automatic while no Clique is loaded. The raid
-- frames' own switch is not asked: the party (and the other unit frames)
-- take bindings while the raid frames are off (decision 74); the cells
-- follow the raid frames (takes).
function ClickCast.On()
    if not ns.RaidConfig.Profile() then return false end
    local mode = ns.RaidConfig.Get("general", "clickCast")
    return mode == "ON" or (mode == "AUTO" and not ClickCast.Clique())
end

-- The unit frames that may take them (decision 76), each by its own
-- clickCast (inherited from General). Party pets and targets never.
ClickCast.UNIT_SCOPES = { player = true, pet = true, target = true, targettarget = true, focus = true, party = true }

-- Whether a frame takes the bindings: a raid cell a header made while the
-- raid frames are on, a unit frame whose switch is on.
local function takes(frame)
    if ns.RaidCell.Is(frame) then return ns.RaidPanel.Enabled() end
    return ClickCast.UNIT_SCOPES[frame.key] == true and ns.Config.Profile() ~= nil
        and ns.Config.Get(frame.key, "clickCast") == true
end

-- The names a frame holds a value for in a plan, and their values.
local function valuesOf(plan)
    local values = {}
    for _, attr in ipairs(plan) do
        if attr[2] ~= nil then values[attr[1]] = attr[2] end
    end
    return values
end

-- Writes a plan, touching only names it sets, names the XML sets
-- (defaults) and names written before (frame.clickCastNames): an
-- attribute another addon (Clique) put on a name we never wrote stays.
-- A name we clear that the XML does not set is ours no longer: what
-- another addon writes there later stays too.
local function write(frame, values, defaults)
    local touched = frame.clickCastNames or {}
    for name in pairs(touched) do
        if values[name] == nil then
            frame:SetAttribute(name, nil)
            if defaults[name] == nil then touched[name] = nil end
        end
    end
    for name in pairs(defaults) do
        if values[name] == nil and not touched[name] then
            frame:SetAttribute(name, nil)
            touched[name] = true
        end
    end
    for name, value in pairs(values) do
        frame:SetAttribute(name, value)
        touched[name] = true
    end
    frame.clickCastNames = touched
end

-- Every name we wrote back to the XML's value (or none): nothing else.
local function reset(frame, defaults)
    for name in pairs(frame.clickCastNames) do frame:SetAttribute(name, defaults[name]) end
    frame.clickCastNames = nil
end

-- Out of combat only. A frame that takes them gets the bindings; one
-- that no longer does (click-casting off, the raid frames off for a cell,
-- the frame's clickCast off) gets the XML's
-- attributes back on the names we wrote, if it had ours at all.
local function apply(frame, values, defaults)
    if ClickCast.On() and takes(frame) then
        write(frame, values, defaults)
    elseif frame.clickCastNames then
        reset(frame, defaults)
    end
end

-- Every frame that may take bindings: the cells the headers made (never
-- test mode's), the single unit frames and the party members.
local function frames()
    local list = {}
    for _, b in ipairs(ns.RaidCell.buttons) do list[#list + 1] = b end
    for key in pairs(ClickCast.UNIT_SCOPES) do
        if ns.Frames[key] then list[#list + 1] = ns.Frames[key] end
    end
    for _, b in ipairs(ns.Party.buttons or {}) do list[#list + 1] = b end
    return list
end

-- Whether a frame holds bindings we wrote (to take back when off).
local function anyWritten()
    for _, frame in ipairs(frames()) do
        if frame.clickCastNames then return true end
    end
    return false
end

-- The bindings' and the XML's attribute values, by name.
local function planned()
    return valuesOf(ClickCast.Plan(ClickCast.Values())), valuesOf(ClickCast.Plan(ClickCast.DefaultValues()))
end

function ClickCast.ApplyAll()
    if InCombatLockdown() or not ns.RaidConfig.Profile() then return end
    if not ClickCast.On() and not anyWritten() then return end
    local values, defaults = planned()
    for _, frame in ipairs(frames()) do apply(frame, values, defaults) end
end

local function applyAfterCombat() ns.AfterCombat("clickCast", ClickCast.ApplyAll) end

-- A header (or the party's) made a frame: its bindings now, or after
-- combat (it keeps the XML's until then).
function ClickCast.Added(frame)
    if InCombatLockdown() then
        applyAfterCombat()
        return
    end
    -- Click-casting off: a new frame keeps the XML's (apply asks the rest).
    if not ClickCast.On() then return end
    apply(frame, planned())
end

-- The settings that change the attributes; the panels have nothing to
-- lay out for them (Raid/Panel.lua).
ClickCast.KEYS = { clickCast = true }
for _, slot in ipairs(Raid.CLICK_SLOTS) do ClickCast.KEYS[slot.key] = true end
for key in pairs(ClickCast.KEYS) do ns.RaidPanel.UNRELATED_KEYS[key] = true end

ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if scope ~= nil and scope ~= "general" then return end
    if key == nil or key == "enabled" or ClickCast.KEYS[key] then applyAfterCombat() end
end)
-- The unit frames' clickCast (any scope: a frame's own or General's).
ns.Listen("CONFIG_CHANGED", function(_, key)
    if key == nil or key == "clickCast" then applyAfterCombat() end
end)
