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

-- On: switched on, or automatic while no Clique is loaded.
function ClickCast.On()
    if not ns.RaidConfig.Profile() then return false end
    local mode = ns.RaidConfig.Get("general", "clickCast")
    return mode == "ON" or (mode == "AUTO" and not ClickCast.Clique())
end

-- Whether a frame takes the bindings: a raid cell a header made, a party
-- member while the party switch is on.
local function takes(frame)
    if ns.RaidCell.Is(frame) then return true end
    return frame.key == ns.Party.KEY and ns.RaidConfig.Get("general", "clickCastParty") == true
end

local function write(frame, plan)
    for _, attr in ipairs(plan) do frame:SetAttribute(attr[1], attr[2]) end
end

-- Out of combat only. A frame that takes them gets the bindings; one
-- that no longer does (off, the party switched off) gets the XML's
-- attributes back, but only if it had ours: Clique's are left alone.
local function apply(frame, plan, defaultPlan)
    if ClickCast.On() and takes(frame) then
        write(frame, plan)
        frame.clickCastWritten = true
    elseif frame.clickCastWritten then
        write(frame, defaultPlan)
        frame.clickCastWritten = nil
    end
end

-- Every frame that may take bindings: the cells the headers made (never
-- test mode's) and the party members.
local function frames()
    local list = {}
    for _, b in ipairs(ns.RaidCell.buttons) do list[#list + 1] = b end
    for _, b in ipairs(ns.Party.buttons or {}) do list[#list + 1] = b end
    return list
end

function ClickCast.ApplyAll()
    if InCombatLockdown() or not ns.RaidConfig.Profile() then return end
    local plan, defaultPlan = ClickCast.Plan(ClickCast.Values()), ClickCast.Plan(ClickCast.DefaultValues())
    for _, frame in ipairs(frames()) do apply(frame, plan, defaultPlan) end
end

local function applyAfterCombat() ns.AfterCombat("clickCast", ClickCast.ApplyAll) end

-- A header (or the party's) made a frame: its bindings now, or after
-- combat (it keeps the XML's until then).
function ClickCast.Added(frame)
    if InCombatLockdown() then
        applyAfterCombat()
        return
    end
    if not ns.RaidConfig.Profile() then return end
    apply(frame, ClickCast.Plan(ClickCast.Values()), ClickCast.Plan(ClickCast.DefaultValues()))
end

-- The settings that change the attributes; the panels have nothing to
-- lay out for them (Raid/Panel.lua).
ClickCast.KEYS = { clickCast = true, clickCastParty = true }
for _, slot in ipairs(Raid.CLICK_SLOTS) do ClickCast.KEYS[slot.key] = true end
for key in pairs(ClickCast.KEYS) do ns.RaidPanel.UNRELATED_KEYS[key] = true end

ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if scope ~= nil and scope ~= "general" then return end
    if key == nil or ClickCast.KEYS[key] then applyAfterCombat() end
end)
