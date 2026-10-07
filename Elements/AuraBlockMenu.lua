local _, ns = ...

-- Hiding an aura from the frame (Core/AuraBlocklist.lua): Shift +
-- right-click on a frame's auras opens a menu of that row's auras whose
-- spell ID and name can be read; each entry puts the spell on the frame's
-- list (Shift + Ctrl: the account's). The icons take no clicks (a
-- container's buttons never run addon code, ours pass the click on), so
-- the click is the unit frame's: its secure click does nothing with Shift
-- (no click binding, SecureUnitButton_OnClick), and our hook on its
-- OnMouseUp, plain code that touches nothing protected, opens the menu
-- when the mouse is over a row of auras. Out of combat only: a list change
-- rebuilds the containers' filters, and the auras are read here. The
-- client gives an addon no way to tell which container icon is under the
-- mouse, so the menu offers the row.

local BlockMenu = { name = "AuraBlockMenu" }
ns.AuraBlockMenu = BlockMenu

local Secrets, Blocklist = ns.Secrets, ns.AuraBlocklist

-- At most this many auras in the menu.
BlockMenu.MAX = 20

local function mouseOver(region)
    return region ~= nil and Secrets.Call(region.IsMouseOver, region) == true
end

-- The aura group under the mouse: its container's area, or the holder of
-- the icons the addon draws itself.
local function groupUnderMouse(frame)
    for _, key in ipairs(ns.Settings.AURA_GROUPS) do
        local group = frame.auras[key]
        local entry = frame.auraContainers and frame.auraContainers[key]
        if group and group.enabled and (mouseOver(entry and entry.container) or mouseOver(group.holder)) then
            return group
        end
    end
end

-- A unit frame of ours whose list can take the spell (not a raid cell,
-- not a derived scope).
local function ours(frame)
    if type(frame) ~= "table" or type(frame.auras) ~= "table" or frame.pretend then return false end
    for _, scope in ipairs(ns.Settings.SCOPES) do
        if scope ~= "general" and scope == frame.key then return true end
    end
    return false
end

-- The group's auras as { id, name }, readable ones only, each spell once,
-- none already on the list.
function BlockMenu.Candidates(frame, group, listed)
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, frame.unit, group.filter, BlockMenu.MAX)
    if not ok or Secrets.IsSecret(list) or type(list) ~= "table" then return {} end
    local out, seen = {}, {}
    for _, aura in ipairs(list) do
        if not Secrets.IsSecret(aura) and type(aura) == "table" then
            local id, name = Secrets.Plain(aura.spellId, "number"), Secrets.Plain(aura.name, "string")
            if id and name and not seen[id] and not (listed and listed[id]) then
                seen[id] = true
                out[#out + 1] = { id = id, name = name }
            end
        end
    end
    return out
end

-- The menu for the row under the mouse; false when there is none (no
-- row, nothing readable, in combat).
function BlockMenu.Open(frame)
    if not ours(frame) or not frame.unit or InCombatLockdown() then return false end
    local group = groupUnderMouse(frame)
    if not group then return false end
    local scope = IsControlKeyDown() and "general" or frame.key
    local key = scope == "general" and "auraBlockAccount" or "auraBlock"
    local auras = BlockMenu.Candidates(frame, group, Blocklist.Set(ns.Config.Get(scope, key)))
    if #auras == 0 then return false end
    local L = ns.L
    MenuUtil.CreateContextMenu(frame, function(_, root)
        root:CreateTitle(scope == "general" and L.AURA_BLOCK_MENU_ACCOUNT
            or L.AURA_BLOCK_MENU_FRAME:format(L["FRAME_" .. scope]))
        for _, aura in ipairs(auras) do
            root:CreateButton(L.AURA_BLOCK_MENU_ENTRY:format(aura.name, aura.id), function()
                if InCombatLockdown() then return end
                Blocklist.Hide(scope, aura.id)
            end)
        end
    end)
    return true
end

local function onMouseUp(frame, button)
    if button == "RightButton" and IsShiftKeyDown() then BlockMenu.Open(frame) end
end

-- Element: the hook on every unit frame with auras (not the raid cells,
-- whose clicks belong to click-casting).
function BlockMenu.Build(frame)
    if frame.auras and not (ns.RaidCell and ns.RaidCell.Is(frame)) then frame:HookScript("OnMouseUp", onMouseUp) end
end
function BlockMenu.Style() end
function BlockMenu.Update() end

ns.RegisterElement(BlockMenu)
