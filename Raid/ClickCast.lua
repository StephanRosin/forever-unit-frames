local _, ns = ...

-- Click-casting on the raid cells of every panel and (switchable) the
-- unit frames' party members: the bindings of the raid profile's
-- character-wide scope (Raid/Settings.lua: Raid.CLICK_SLOTS) written as
-- the secure attributes the client reads on a click (SecureTemplates.lua:
-- SecureButton_GetModifiedAttribute): "*type1" for the plain left click,
-- "shift-type1" for Shift and left, with "spell1", "item1", "macrotext1"
-- beside them. Static attributes only (no snippets on this client), and
-- out of combat only: a cell a header makes in combat gets them after
-- combat and does what the XML says until then (left target, right menu).
-- Test mode's pretend cells are never touched.
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
        if value:match("^%d+$") then
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(tonumber(value))
            name = type(info) == "table" and type(info.name) == "string" and info.name or nil
        end
        local ids = name and ns.RaidSpellbook.IDs(name) or {}
        if #ids == 0 then return nil, L.RAID_TYPED_SPELL_UNKNOWN:format(value) end
        local info = C_Spell.GetSpellInfo(ids[1])
        return type(info) == "table" and type(info.name) == "string" and info.name or name
    end
    if kind == "macro" and #value > ClickCast.MACRO_LETTERS then
        return nil, L.RAID_TYPED_MACRO_TOO_LONG:format(ClickCast.MACRO_LETTERS)
    end
    return value
end

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

-- One slot's attribute values: { attribute = value } (nothing for a
-- binding that does nothing, a kind without its value included).
local function slotAttributes(binding)
    local kind, value = Raid.ParseBinding(binding or "")
    if not kind or kind == "" then return {} end
    local attr = VALUE_ATTRIBUTE[kind]
    if attr then
        if value == "" then return {} end
        if kind == "item" and value:match("^%d+$") then value = "item:" .. value end
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
        local set = slotAttributes(binding)
        for _, attr in ipairs(ATTRIBUTES) do
            plan[#plan + 1] = { slot.prefix .. attr .. slot.button, set[attr] }
        end
    end
    return plan
end
