local _, ns = ...

-- Hiding an aura from the frame (Core/AuraBlocklist.lua): Shift +
-- right-click on a frame's auras opens a menu of that row's auras whose
-- spell ID and name can be read; each entry puts the spell on the frame's
-- list (Shift + Ctrl: the account's). The icons take no clicks (a
-- container's buttons never run addon code, ours pass the click on), so
-- the click goes to what lies below; on the unit frame its secure click does nothing with Shift
-- (no click binding, SecureUnitButton_OnClick), and the client's
-- GLOBAL_MOUSE_UP, plain code that touches nothing protected, opens the
-- menu when the mouse is over a row of auras, on the frame or beside it. Out of combat only: a list change
-- rebuilds the containers' filters, and the auras are read here. The
-- client gives an addon no way to tell which container icon is under the
-- mouse, so the menu offers the row: only the auras the client lets an
-- addon leave out on that unit. A Shift + right-click bound to
-- click-casting (Ctrl + Shift for the account's list) is the binding's:
-- no menu.

local BlockMenu = { name = "AuraBlockMenu" }
ns.AuraBlockMenu = BlockMenu

local Secrets, Blocklist = ns.Secrets, ns.AuraBlocklist

-- At most this many auras in the menu.
BlockMenu.MAX = 20

local function mouseOver(region)
    return region ~= nil and Secrets.Call(region.IsMouseOver, region) == true
end

-- How many of the unit's auras through filter a row shows: readable ones
-- not on the group's list, at most max (0 when the client refuses).
local function shown(frame, group, filter, max)
    if not filter or max <= 0 then return 0 end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, frame.unit, filter, max)
    if not ok or Secrets.IsSecret(list) or type(list) ~= "table" then return 0 end
    local n = 0
    for _, aura in ipairs(list) do
        local id = not Secrets.IsSecret(aura) and type(aura) == "table" and Secrets.Plain(aura.spellId, "number")
        if not (id and group.blockSet and group.blockSet[id]) then n = n + 1 end
    end
    return n
end

-- A container answers where it is and IsMouseOver only as secrets, so a
-- plain frame of ours per group takes its place for the question: the same
-- point, as big as the icons it shows (a container is as big as they are).
-- A group hung from the other hangs from the other's stand-in.
BlockMenu.probes = {}

local function probe(key)
    local p = BlockMenu.probes[key]
    if not p then
        p = CreateFrame("Frame", nil, UIParent)
        BlockMenu.probes[key] = p
    end
    p:ClearAllPoints()
    return p
end

local function put(p, point, region, relative, x, y, w, h)
    p:SetPoint(point, region, relative, x, y)
    p:SetSize(math.max(w, 0), math.max(h, 0))
    return p
end

-- The stand-in of the container's row: icons of the group's size, yours
-- first at theirs.
local function rowProbe(frame, key)
    local Config, scope = ns.Config, frame.key
    local group, entry = frame.auras[key], frame.auraContainers[key]
    local split, apart = group.split, entry.apart
    local own = split and not apart and shown(frame, group, group.ownFilter, group.max) or 0
    local rest = split and group.otherFilter or (not split and group.filter)
    local n = own + shown(frame, group, rest, group.max - own)
    local w, h = ns.Layout.AuraBlock(group, own, n)
    local region = ns.Auras.AnchorRegion(frame, key, true)
    for other, e in pairs(frame.auraContainers) do
        if other ~= key and region == e.container then region = rowProbe(frame, other) end
    end
    local x, y = ns.Auras.AnchorOffset(frame, key, region)
    local _, dx, dy = ns.AuraContainers.Lead(frame, key)
    return put(probe(key), Config.Get(scope, key .. "Point"), region, Config.Get(scope, key .. "FramePoint"),
        x + dx, y + dy, w, h)
end

local function overRow(frame, key)
    local p = rowProbe(frame, key)
    return p:GetWidth() > 0 and p:GetHeight() > 0 and mouseOver(p)
end

-- Yours placed freely, in their own container.
local function overOwn(frame, key, group)
    local Config, scope = ns.Config, frame.key
    local n = shown(frame, group, group.ownFilter, group.max)
    local w, h = ns.Layout.AuraBlock(group.free, 0, n)
    local region = frame.unitBox or frame
    local x, y = ns.Auras.AnchorOffset(frame, key, region, "Own")
    local p = put(probe(key .. "Own"), Config.Get(scope, key .. "OwnPoint"), region,
        Config.Get(scope, key .. "OwnFramePoint"), x, y, w, h)
    return w > 0 and h > 0 and mouseOver(p)
end

-- The aura group under the mouse: its container's row, or the holder of
-- the icons the addon draws itself; for yours placed freely, their own
-- container or block.
local function groupUnderMouse(frame)
    for _, key in ipairs(ns.Settings.AURA_GROUPS) do
        local group = frame.auras[key]
        local entry = frame.auraContainers and frame.auraContainers[key]
        if group and group.enabled then
            if entry and (overRow(frame, key) or (entry.apart and overOwn(frame, key, group))) then
                return group
            end
            if mouseOver(group.holder) or (group.ownFree and mouseOver(group.free.holder)) then
                return group
            end
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

-- The group's auras as { id, name }, and how many readable ones the
-- client would keep showing; readable ones only, each spell once,
-- none already on the list, and only those the client would leave out on
-- this unit (Core/AuraBlocklist.lua, RowApplies: a debuff on a unit you can
-- assist stays shown unless its spell is never-secret).
function BlockMenu.Candidates(frame, group, listed)
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, frame.unit, group.filter, BlockMenu.MAX)
    if not ok or Secrets.IsSecret(list) or type(list) ~= "table" then return {}, 0 end
    local rowApplies = Blocklist.RowApplies(frame.unit, not group.isDebuff)
    local out, seen, refused = {}, {}, 0
    for _, aura in ipairs(list) do
        if not Secrets.IsSecret(aura) and type(aura) == "table" then
            local id, name = Secrets.Plain(aura.spellId, "number"), Secrets.Plain(aura.name, "string")
            if id and name and not seen[id] and not (listed and listed[id]) then
                seen[id] = true
                if rowApplies or Blocklist.NeverSecret(id) then
                    out[#out + 1] = { id = id, name = name }
                else
                    refused = refused + 1
                end
            end
        end
    end
    return out, refused
end

-- The click's own click-casting binding (Raid/ClickCast.lua writes it as
-- the client's attribute): Shift + right, or Ctrl + Shift + right.
local function boundClick(frame, account)
    local value = Secrets.Call(frame.GetAttribute, frame, account and "ctrl-shift-type2" or "shift-type2")
    return value ~= nil
end

-- The menu for the row under the mouse; false when there is none (no
-- row, nothing readable, in combat, the click bound to click-casting).
-- When the row's readable auras are all ones the client keeps showing on
-- this unit, the chat says so.
-- group: the row under the mouse when the button went down (the default:
-- under it now).
function BlockMenu.Open(frame, group)
    if not ours(frame) or not frame.unit or InCombatLockdown() then return false end
    local account = IsControlKeyDown()
    if boundClick(frame, account) then return false end
    group = group or groupUnderMouse(frame)
    if not group then return false end
    local scope = account and "general" or frame.key
    local key = scope == "general" and "auraBlockAccount" or "auraBlock"
    local auras, refused = BlockMenu.Candidates(frame, group, Blocklist.Set(ns.Config.Get(scope, key)))
    local L = ns.L
    if #auras == 0 then
        if refused > 0 then ns.Print(group.isDebuff and L.AURA_BLOCK_MENU_NO_DEBUFFS or L.AURA_BLOCK_MENU_NO_BUFFS) end
        return false
    end
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

-- The frames built with the menu, for the click.
BlockMenu.frames = {}

-- The click is the client's GLOBAL_MOUSE_DOWN and _UP: rows outside the
-- frame lie over the world, so the frame never sees it. The row is taken
-- on the way down: a right button held over the world turns the camera,
-- and until it is let go no region counts the mouse as over it.
local pressed  -- { frame, group }

local function shiftRight(button)
    return button == "RightButton" and IsShiftKeyDown() and not InCombatLockdown()
end

ns.On("GLOBAL_MOUSE_DOWN", function(_, button)
    pressed = nil
    if not shiftRight(button) then return end
    for _, frame in ipairs(BlockMenu.frames) do
        local group = frame:IsVisible() and groupUnderMouse(frame)
        if group then
            pressed = { frame = frame, group = group }
            return
        end
    end
end)

ns.On("GLOBAL_MOUSE_UP", function(_, button)
    local was = pressed
    pressed = nil
    if was and shiftRight(button) then BlockMenu.Open(was.frame, was.group) end
end)

-- Element: every unit frame with auras (not the raid cells, whose clicks
-- belong to click-casting).
function BlockMenu.Build(frame)
    if frame.auras and not (ns.RaidCell and ns.RaidCell.Is(frame)) then
        BlockMenu.frames[#BlockMenu.frames + 1] = frame
    end
end
function BlockMenu.Style() end
function BlockMenu.Update() end

ns.RegisterElement(BlockMenu)
