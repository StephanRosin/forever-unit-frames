local _, ns = ...

-- Keys that cast on the raid member under the mouse (Raid/Settings.lua:
-- Raid.CLICK_KEYS): a secure action button per key, never shown on screen
-- and never under the mouse, that runs a macro acting on @mouseover; the
-- key clicks it through an override binding (SetOverrideBindingClick).
-- Override bindings may not change in combat and no secure snippet runs on
-- this client, so a key cannot be bound only while a cell is hovered:
-- the keys are bound for as long as the raid frames show (and, with the
-- party switch, while in a party), and the macro's condition makes them
-- act only on a friendly unit under the mouse. Set and cleared out of
-- combat only; in combat the bindings stay as they were.
local ClickKeys = {}
ns.ClickKeys = ClickKeys

local Raid = ns.Raid

ClickKeys.BUTTON_NAME = "ForeverUnitFramesClickKey"
ClickKeys.buttons = {}
local owner

-- The macro a key runs for a binding (Raid.ParseBinding), or nil when it
-- does nothing: a spell or an item on the friendly, living unit under
-- the mouse; a macro text as written.
local MACRO = { spell = "/cast [@mouseover,help,nodead] %s", item = "/use [@mouseover,help,nodead] %s" }
function ClickKeys.MacroText(binding)
    local kind, value = Raid.ParseBinding(binding or "")
    if not value or value == "" then return nil end
    if kind == "macro" then return value end
    if kind == "item" and value:match("^%d+$") then value = "item:" .. value end
    return MACRO[kind] and MACRO[kind]:format(value)
end

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

-- Whether the keys are bound: click-casting on, and the raid frames
-- showing, or in a party whose frames take the bindings.
function ClickKeys.Wanted()
    if not ns.ClickCast.On() then return false end
    if ns.RaidPanel.Active() then return true end
    return IsInGroup() and ns.RaidConfig.Get("general", "clickCastParty") == true
end

-- Out of combat only: the bindings anew.
function ClickKeys.Update()
    if InCombatLockdown() or not ns.RaidConfig.Profile() then return end
    owner = owner or CreateFrame("Frame", nil, UIParent)
    ClearOverrideBindings(owner)
    if not ClickKeys.Wanted() then return end
    for i, slot in ipairs(Raid.CLICK_KEYS) do
        local key = ns.RaidConfig.Get("general", slot.key)
        local text = ClickKeys.MacroText(ns.RaidConfig.Get("general", slot.bind))
        if key ~= "" and text then
            local b = button(i)
            b:SetAttribute("macrotext", text)
            SetOverrideBindingClick(owner, false, key, b:GetName(), "LeftButton")
        end
    end
end

-- What the player has bound the key to otherwise (the raid window warns:
-- the key does that no longer while the raid frames show), or nil.
function ClickKeys.Taken(key)
    if key == "" then return nil end
    local action = GetBindingAction(key)
    if type(action) ~= "string" or action == "" then return nil end
    return action
end

local function update() ns.AfterCombat("clickKeys", ClickKeys.Update) end
ClickKeys.Queue = update

-- The settings that change the bindings: the keys, and what decides
-- whether the raid frames show.
local KEYS = { clickCast = true, clickCastParty = true, enabled = true, showInParty = true }
for _, slot in ipairs(Raid.CLICK_KEYS) do
    KEYS[slot.key], KEYS[slot.bind] = true, true
    ns.RaidPanel.UNRELATED_KEYS[slot.key], ns.RaidPanel.UNRELATED_KEYS[slot.bind] = true, true
end

ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if scope ~= nil and scope ~= "general" then return end
    if key == nil or KEYS[key] then update() end
end)
ns.On("GROUP_ROSTER_UPDATE", update)
