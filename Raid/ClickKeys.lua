local _, ns = ...

-- Keys that cast on the group member under the mouse (Raid/Settings.lua:
-- Raid.CLICK_KEYS): a secure action button per key, never shown on screen
-- and never under the mouse, that runs a macro acting on @mouseover. The
-- keys are bound only while the mouse is over one of our frames that take
-- the click bindings (ClickCast.Takes: raid cells, party, the unit frames
-- with their clickCast on): secure snippets wrapped around each frame's
-- OnEnter bind them to the buttons (SetBindingClick, override bindings
-- owned by one secure header), OnLeave and OnHide let them go
-- (ClearBindings). The client skips a leave without mouse motion (a menu
-- opening under the mouse, CurseForge 21.11.2026), so a state driver lets
-- them go too once no unit is under the mouse. Snippets run in combat
-- too; elsewhere a key keeps its own job (the wheel zooms). The keys' list sits in the frame's attributes, written
-- out of combat; a frame made in combat gets it after combat.
local ClickKeys = {}
ns.ClickKeys = ClickKeys

local Raid = ns.Raid

ClickKeys.BUTTON_NAME = "ForeverUnitFramesClickKey"
ClickKeys.buttons = {}

-- A spell as /cast takes it (ClickCast.CastValue): a name as stored (the
-- highest rank known); a known spell ID (a fixed rank) as "Name(Rank 3)"
-- with the spell book's rank text, the name alone when the spell has one
-- rank without text or is not in the click-casting list; an ID no longer
-- known as its name (Max, as the cells); nil for an ID the client does
-- not know. While the rank's text is not loaded: nil (never the name, that
-- would cast Max) and "pending", or with bare (the wait given up) the name
-- and "pending". list: the click-casting list (Spellbook.FriendlySpells;
-- read when nil).
local function castName(value, list, bare)
    local cast = ns.ClickCast.CastValue(value)
    if not cast or not cast:match("^%d+$") then return cast end
    local id = tonumber(cast)
    local Spellbook = ns.RaidSpellbook
    local spell, rank = Spellbook.FriendlyRank(id, list)
    if not spell then return ns.ClickCast.SpellName(id) end
    local text = Spellbook.RankText(spell, rank)
    if text == nil then return bare and spell.name or nil, "pending" end
    if text == "" then return spell.name end
    return spell.name .. "(" .. text .. ")"
end

-- The macro a key runs for a binding (Raid.ParseBinding), or nil when it
-- does nothing: a spell or an item on the friendly, living unit under
-- the mouse; a macro text as written. Also "pending" while a rank's text
-- is not loaded. list, bare: as castName's.
local MACRO = { spell = "/cast [@mouseover,help,nodead] %s", item = "/use [@mouseover,help,nodead] %s" }
function ClickKeys.MacroText(binding, list, bare)
    local kind, value = Raid.ParseBinding(binding or "")
    if not value or value == "" then return nil end
    if kind == "macro" then return value end
    if kind == "item" and value:match("^%d+$") then value = "item:" .. value end
    local pending
    if kind == "spell" then value, pending = castName(value, list, bare) end
    return value and MACRO[kind] and MACRO[kind]:format(value), pending
end

-- A rank's text that does not come (SPELL_TEXT_UPDATE not sent, or not
-- registered; two spells of one name without rank texts): the keys try
-- again TEXT_TRIES times, TEXT_WAIT seconds apart (out of combat, as
-- every update), then cast the bare name rather than stay unbound until
-- the next change. A text arriving later is taken at the next update.
-- The tries count per key and value (tries["clickKey1Bind=spell:139"]):
-- one key that never gets its text does not cut another's wait short,
-- and a key given another value waits afresh.
local TEXT_WAIT, TEXT_TRIES = 2, 5
local tries, retryQueued = {}, false

-- Out of combat: key i's button, made once. Keys act on key down or up
-- as the ActionButtonUseKeyDown option says, so it takes both.
local function button(i)
    local b = ClickKeys.buttons[i]
    if b then return b end
    b = CreateFrame("Button", ClickKeys.BUTTON_NAME .. i, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:EnableMouse(false)
    b:SetAttribute("type", "macro")
    ClickKeys.buttons[i] = b
    return b
end

-- Whether the keys apply at all: click-casting on.
function ClickKeys.Wanted()
    return ns.ClickCast.On()
end

-- The wrapped frames' snippets (RestrictedFrames.lua: HANDLE:SetBindingClick
-- takes the button's name).
ClickKeys.ENTER = [[
    owner:ClearBindings()
    owner:SetAttribute("fufhovered", self)
    local n = self:GetAttribute("fufkeys") or 0
    for i = 1, n do
        owner:SetBindingClick(true, self:GetAttribute("fufkey" .. i), self:GetAttribute("fufkeybutton" .. i),
            "LeftButton")
    end
]]
-- Only the frame that bound them lets them go (another may hide meanwhile).
ClickKeys.LEAVE = [[
    if owner:GetAttribute("fufhovered") == self then
        owner:SetAttribute("fufhovered", nil)
        owner:ClearBindings()
    end
]]
ClickKeys.UNHOVER = [[
    if newstate == "off" then
        self:SetAttribute("fufhovered", nil)
        self:ClearBindings()
    end
]]
-- The keys as bound now: { key, button name } pairs (ClickKeys.Update).
ClickKeys.active = {}
local wrapper

-- Out of combat: a frame's keys (none when it does not take the click
-- bindings), wrapped once.
function ClickKeys.Apply(frame)
    if InCombatLockdown() then return end
    local list = (ClickKeys.Wanted() and ns.ClickCast.Takes(frame)) and ClickKeys.active or {}
    if not frame.fufKeysWrapped then
        if #list == 0 then return end
        if not wrapper then
            wrapper = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
            wrapper:SetAttribute("_onstate-fufmouseover", ClickKeys.UNHOVER)
            RegisterStateDriver(wrapper, "fufmouseover", "[@mouseover,exists] on; off")
            ClickKeys.wrapper = wrapper
        end
        wrapper:WrapScript(frame, "OnEnter", ClickKeys.ENTER)
        wrapper:WrapScript(frame, "OnLeave", ClickKeys.LEAVE)
        wrapper:WrapScript(frame, "OnHide", ClickKeys.LEAVE)
        frame.fufKeysWrapped = true
    end
    for i, pair in ipairs(list) do
        frame:SetAttribute("fufkey" .. i, pair[1])
        frame:SetAttribute("fufkeybutton" .. i, pair[2])
    end
    frame:SetAttribute("fufkeys", #list)
end

function ClickKeys.ApplyAll()
    if InCombatLockdown() then return end
    for _, frame in ipairs(ns.ClickCast.Frames()) do ClickKeys.Apply(frame) end
end

local update
-- Out of combat only: the bindings anew.
function ClickKeys.Update()
    if InCombatLockdown() or not ns.RaidConfig.Profile() then return end
    local active = {}
    ClickKeys.active = active
    -- The old keys go; the new ones bind on the next enter (bound here,
    -- only a wrapped enter would let them go again: _wrapentered).
    if wrapper then
        ClearOverrideBindings(wrapper)
        wrapper:SetAttribute("fufhovered", nil)
    end
    if not ClickKeys.Wanted() then
        ClickKeys.ApplyAll()
        return
    end
    -- The spell list once for every key with a fixed rank.
    local list
    for _, slot in ipairs(Raid.CLICK_KEYS) do
        if ns.ClickCast.HoldsRank(ns.RaidConfig.Get("general", slot.bind)) then
            list = ns.RaidSpellbook.FriendlySpells()
            break
        end
    end
    local waiting, stillWaiting = {}, false
    for i, slot in ipairs(Raid.CLICK_KEYS) do
        local key, binding = ns.RaidConfig.Get("general", slot.key), ns.RaidConfig.Get("general", slot.bind)
        local id = slot.bind .. "=" .. binding
        local done = tries[id] or 0
        local text, pending = ClickKeys.MacroText(binding, list, done >= TEXT_TRIES)
        if key ~= "" and pending then
            waiting[id] = done
            if done < TEXT_TRIES then stillWaiting = true end
        end
        if key ~= "" and text then
            local b = button(i)
            b:SetAttribute("macrotext", text)
            active[#active + 1] = { key, b:GetName() }
        end
    end
    ClickKeys.ApplyAll()
    -- Only the keys waiting now keep their count.
    tries = waiting
    if stillWaiting and not retryQueued then
        retryQueued = true
        C_Timer.After(TEXT_WAIT, function()
            retryQueued = false
            for id, done in pairs(tries) do tries[id] = done + 1 end
            update()
        end)
    end
end

-- The key without its modifiers (Raid.ParseKey's spelling).
local function bareKey(key)
    local rest = key
    while true do
        local after = rest:match("^ALT%-(.+)$") or rest:match("^CTRL%-(.+)$") or rest:match("^SHIFT%-(.+)$")
        if not after then return rest end
        rest = after
    end
end

local function bound(key)
    local action = GetBindingAction(key)
    if type(action) ~= "string" or action == "" then return nil end
    return action
end

-- What the player has bound the key to otherwise (the raid window warns:
-- the key does that no longer while the mouse is over our frames), or nil. A
-- chord bound to nothing does what its key alone does (the client falls
-- back), so that is what it takes.
function ClickKeys.Taken(key)
    if key == "" then return nil end
    return bound(key) or bound(bareKey(key))
end

update = function() ns.AfterCombat("clickKeys", ClickKeys.Update) end
ClickKeys.Queue = update

-- The settings that change the keys: the keys, click-casting itself and
-- the raid frames' switch (the cells take them only while it is on).
local KEYS = { clickCast = true, enabled = true }
for _, slot in ipairs(Raid.CLICK_KEYS) do
    KEYS[slot.key], KEYS[slot.bind] = true, true
    ns.RaidPanel.UNRELATED_KEYS[slot.key], ns.RaidPanel.UNRELATED_KEYS[slot.bind] = true, true
end

ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if scope ~= nil and scope ~= "general" then return end
    if key == nil or KEYS[key] then update() end
end)
-- A key's fixed rank is written by its rank text, read from the spell
-- book: set again once the book is read or changes.
ns.On("SPELLS_CHANGED", update)
ns.RaidSpellbook.OnTextUpdate(update)
-- The party's clickCast (decision 76; General's or the party's own).
ns.Listen("CONFIG_CHANGED", function(_, key)
    if key == nil or key == "clickCast" or key == "enabled" or key == "unitFrames" then update() end
end)
