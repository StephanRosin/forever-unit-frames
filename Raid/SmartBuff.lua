local _, ns = ...

-- The smart buff key: one hidden secure action button whose type, spell
-- and unit are set out of combat to the buff watch's next cast
-- (Raid/BuffWatch.lua: BuffWatch.Next), clicked by an override binding on
-- the key the player chose (buffKey), as the click-casting keys are
-- (Raid/ClickKeys.lua). Attributes cannot change in combat and a snippet
-- cannot read the buff watch: the button is emptied and the key
-- let go as combat starts (PLAYER_REGEN_DISABLED fires before lockdown);
-- after combat the next scan sets them again. After a roster change it
-- casts nothing until the next scan (BuffWatch.armed: the unit tokens may
-- name other members). The key is bound only while there is a cast (raid
-- frames on, in a group or alone with buffSolo, a buff watched and someone
-- needing it in range); otherwise it does what it did before, such as an
-- action bar's spell. Bindings change out of combat only.
local SmartBuff = {}
ns.SmartBuff = SmartBuff

local Secrets = ns.Secrets

SmartBuff.BUTTON_NAME = "ForeverUnitFramesSmartBuff"
local owner, boundKey = nil, ""
-- A refusal counts for the cast of a click this long ago, at most.
SmartBuff.ERROR_WINDOW = 1
local lastCast, lastClick = nil, 0

local function general(key) return ns.RaidConfig.Get("general", key) end

-- Out of combat: a cast's attributes on a secure action button (the
-- watch window's rows take them too), or none.
function SmartBuff.Set(button, cast)
    button.cast = cast
    if cast then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", cast.spell)
        button:SetAttribute("unit", cast.unit)
    else
        button:SetAttribute("type", nil)
        button:SetAttribute("spell", nil)
        button:SetAttribute("unit", nil)
    end
end

-- A secure button's PostClick: which cast a refusal would be about.
function SmartBuff.NoteClick(button)
    if button.cast then lastCast, lastClick = button.cast, GetTime() end
end

-- Out of combat, once. Keys act on key down or up as the
-- ActionButtonUseKeyDown option says, so it takes both; never under the
-- mouse, never hidden (a binding's click must reach it).
local function create()
    local b = CreateFrame("Button", SmartBuff.BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:EnableMouse(false)
    b:SetScript("PostClick", SmartBuff.NoteClick)
    SmartBuff.button = b
    return b
end

-- Whether the key is bound.
function SmartBuff.Wanted()
    if not (ns.RaidPanel.Enabled() and ns.RaidBuffWatch.Active()) then return false end
    return #ns.RaidBuffWatch.Watched() > 0
end

-- Priority: Bartender4 sets its own override on the same key at every
-- UPDATE_BINDINGS, and between equals either could win.
local function bind(key)
    if key == boundKey then return end
    owner = owner or CreateFrame("Frame", nil, UIParent)
    ClearOverrideBindings(owner)
    if key ~= "" then SetOverrideBindingClick(owner, true, key, SmartBuff.BUTTON_NAME, "LeftButton") end
    boundKey = key
end

-- Out of combat only: the next cast on the button, the key bound to it.
function SmartBuff.Update()
    if InCombatLockdown() or not ns.RaidConfig.Profile() then return end
    -- The raid frames off: no key, nothing made (a button made before
    -- casts nothing).
    if not ns.RaidPanel.Enabled() then
        if SmartBuff.button then SmartBuff.Set(SmartBuff.button, nil) end
        bind("")
        return
    end
    local button = SmartBuff.button or create()
    local cast = SmartBuff.Wanted() and ns.RaidBuffWatch.Next() or nil
    SmartBuff.Set(button, cast)
    bind(cast and general("buffKey") or "")
end

-- A member's name, or the unit token while the name is secret.
local function nameOf(unit)
    return Secrets.Plain(Secrets.Call(UnitName, unit), "string") or unit
end

local function groupText(group)
    if type(group) == "number" then
        return type(GROUP_NUMBER) == "string" and GROUP_NUMBER:format(group) or tostring(group)
    end
    local names = rawget(_G, "LOCALIZED_CLASS_NAMES_MALE")
    return type(names) == "table" and type(names[group]) == "string" and names[group] or tostring(group)
end

-- What a cast does, in words ("Power Word: Fortitude: Ann", "Prayer of
-- Fortitude: Group 2"), or nil for none.
function SmartBuff.Describe(cast)
    if not cast then return nil end
    local who = cast.groupForm and groupText(cast.group) or nameOf(cast.unit)
    return ns.L.RAID_BUFF_CAST:format(cast.name, who)
end

local function queue() ns.AfterCombat("smartBuff", SmartBuff.Update) end
SmartBuff.Queue = queue

-- Combat starts: the button no longer casts, the key is free (before lockdown).
ns.On("PLAYER_REGEN_DISABLED", function()
    if SmartBuff.button and not InCombatLockdown() then
        SmartBuff.Set(SmartBuff.button, nil)
        bind("")
    end
end)
-- The client refused the cast: a stronger buff is on that member.
ns.On("UI_ERROR_MESSAGE", function(_, _, message)
    local bounced = rawget(_G, "SPELL_FAILED_AURA_BOUNCED")
    if not (bounced and lastCast and GetTime() - lastClick <= SmartBuff.ERROR_WINDOW) then return end
    if Secrets.Plain(message, "string") ~= bounced then return end
    ns.RaidBuffWatch.Bounced(lastCast)
    lastCast = nil
end)
ns.Listen("RAID_BUFFS_CHANGED", queue)
ns.On("GROUP_ROSTER_UPDATE", queue)
local KEYS = { buffKey = true, buffSolo = true, enabled = true }
ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if scope == nil or key == nil or KEYS[key] then queue() end
end)
