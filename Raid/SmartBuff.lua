local _, ns = ...

-- The smart buff key: one hidden secure action button whose type, spell
-- and unit are set out of combat to the buff watch's next cast
-- (Raid/BuffWatch.lua: BuffWatch.Next), clicked by an override binding on
-- the key the player chose (buffKey), as the click-casting keys are
-- (Raid/ClickKeys.lua). No secure snippet runs on this client and
-- attributes cannot change in combat: the button is emptied as combat
-- starts (PLAYER_REGEN_DISABLED fires before lockdown), so in combat the
-- key does nothing; after combat the next scan sets it again. The key is
-- bound while the raid frames are on, you are in a group and a buff is
-- watched; bindings change out of combat only.
local SmartBuff = {}
ns.SmartBuff = SmartBuff

local Secrets = ns.Secrets

SmartBuff.BUTTON_NAME = "ForeverUnitFramesSmartBuff"
local owner, boundKey = nil, ""

local function general(key) return ns.RaidConfig.Get("general", key) end

-- Out of combat: a cast's attributes on a secure action button (the
-- watch window's rows take them too), or none.
function SmartBuff.Set(button, cast)
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

-- Out of combat, once. Keys act on key down or up as the
-- ActionButtonUseKeyDown option says, so it takes both; never under the
-- mouse, never hidden (a binding's click must reach it).
local function create()
    local b = CreateFrame("Button", SmartBuff.BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:EnableMouse(false)
    SmartBuff.button = b
    return b
end

-- Whether the key is bound.
function SmartBuff.Wanted()
    if not (ns.RaidPanel.Enabled() and IsInGroup()) then return false end
    return #ns.RaidBuffWatch.Watched() > 0
end

-- Out of combat only: the next cast on the button, the key bound or not.
function SmartBuff.Update()
    if InCombatLockdown() or not ns.RaidConfig.Profile() then return end
    local button = SmartBuff.button or create()
    local wanted = SmartBuff.Wanted()
    SmartBuff.Set(button, wanted and ns.RaidBuffWatch.Next() or nil)
    local key = wanted and general("buffKey") or ""
    if key == boundKey then return end
    owner = owner or CreateFrame("Frame", nil, UIParent)
    ClearOverrideBindings(owner)
    if key ~= "" then SetOverrideBindingClick(owner, false, key, SmartBuff.BUTTON_NAME, "LeftButton") end
    boundKey = key
end

-- A member's name, or the unit token while the name is secret.
local function nameOf(unit)
    local ok, name = pcall(UnitName, unit)
    if ok and not Secrets.IsSecret(name) and type(name) == "string" then return name end
    return unit
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

-- Combat starts: the button no longer casts (before lockdown).
ns.On("PLAYER_REGEN_DISABLED", function()
    if SmartBuff.button and not InCombatLockdown() then SmartBuff.Set(SmartBuff.button, nil) end
end)
ns.Listen("RAID_BUFFS_CHANGED", queue)
ns.On("GROUP_ROSTER_UPDATE", queue)
local KEYS = { buffKey = true, enabled = true }
ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if scope == nil or key == nil or KEYS[key] then queue() end
end)
