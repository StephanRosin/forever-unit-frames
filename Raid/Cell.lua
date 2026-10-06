local _, ns = ...

-- One raid cell: a unit button the block headers (Raid/Header.lua) make
-- from the template in Raid/Cell.xml, running the unit-frame elements
-- (ns.Elements) like a party member does. Its settings come through a
-- derived unit-frame scope, "raid": the party frame's look (fonts, bar
-- texture, colours, border style), with everything a cell never shows
-- switched off and the cell's own look taken from the raid profile of the
-- active size. Name and second line stand centred in the health bar
-- (Elements/Texts.lua, frame.centerTexts); the power strip follows its
-- own rule per unit (frame.showsPower).
--
-- No initialConfigFunction: secure snippets do not run on this client.
-- The XML gives a cell its starting size and clicks; Lua sizes it when
-- it is made out of combat, else after combat (Raid/Header.lua).
local Cell = {}
ns.RaidCell = Cell

local Config, Secrets = ns.Config, ns.Secrets

Cell.KEY = "raid"
Cell.TEMPLATE = "ForeverUnitFramesRaidButtonTemplate"
-- Every cell a header made, in creation order.
Cell.buttons = {}
-- Test mode's pretend cells (Raid/TestMode.lua).
Cell.fakes = {}

-- The size whose profile the cells show; 10 until the size is known.
function Cell.Size()
    return ns.RaidSize.Current() or 10
end

-- A setting of the raid profile the cells show.
function Cell.Get(key)
    return ns.RaidConfig.Get(ns.Raid.Scope(Cell.Size()), key)
end
local get = Cell.Get

-- What a cell never shows, whatever the party frame does: no title row,
-- portrait, castbar, the unit frames' aura icons (a cell's are its own,
-- Raid/CellAuras.lua), combat numbers or threat glow, no overheal lane or
-- heals past the edge (the next cell sits there), no shadow (it would lie
-- on the neighbours), no power texts. The rows: a thin power strip under
-- the health bar.
local FIXED = {
    titlePercent = 0, portraitMode = "OFF", castbarEnabled = false, combatFeedback = false,
    buffsEnabled = false, debuffsEnabled = false, threatGlow = false,
    titleClassIcon = false, healOverflow = false, healBeyond = false, shadowEnabled = false,
    textHealthLeft = "NAME", textPowerLeft = "NONE", textPowerRight = "NONE",
    healthPercent = 90, powerPercent = 10, fontSize = 11, valueFontSize = 10,
}

-- An icon at one of the cell's points sits just inside it: a pixel in
-- from each edge the point touches.
function Cell.Inset(point)
    local x = point:find("LEFT") and 1 or (point:find("RIGHT") and -1 or 0)
    local y = point:find("TOP") and -1 or (point:find("BOTTOM") and 1 or 0)
    return x, y
end

local function insetX(key) return function() return (Cell.Inset(get(key))) end end
local function insetY(key) return function() return select(2, Cell.Inset(get(key))) end end

-- The raid profile's look, in unit-frame settings. The second line's
-- values are the text tags of the same name. The raid marker
-- (Elements/RaidMarker.lua) at its point, centred on it.
local MAPPED = {
    width = function() return get("cellWidth") end,
    height = function() return get("cellHeight") end,
    healthColorMode = function() return get("healthColorMode") end,
    powerEnabled = function() return get("powerStrip") ~= "OFF" end,
    textHealthRight = function() return get("secondLine") end,
    barNameColorMode = function() return get("nameClassColor") and "CLASS" or "WHITE" end,
    borderShow = function() return get("cellBorder") end,
    raidMarker = function() return get("raidMarker") end,
    raidMarkerSize = function() return get("iconSize") end,
    raidMarkerFramePoint = function() return get("raidMarkerPoint") end,
    raidMarkerPoint = function() return get("raidMarkerPoint") end,
    raidMarkerX = insetX("raidMarkerPoint"),
    raidMarkerY = insetY("raidMarkerPoint"),
}

function Cell.Resolve(key)
    local fixed = FIXED[key]
    if fixed ~= nil then return fixed end
    local mapped = MAPPED[key]
    if mapped then return mapped() end
    return nil
end
Config.Derive(Cell.KEY, ns.Party.KEY, Cell.Resolve)

-- Classes that use mana (this game type's classes).
Cell.MANA_CLASSES = { PALADIN = true, PRIEST = true, SHAMAN = true, DRUID = true, MAGE = true, WARLOCK = true,
    HUNTER = true }

-- The class token and the assigned role of a cell's unit (a test cell's:
-- its sample's), or nil: both are secret while the unit's identity is
-- restricted.
local function readable(ok, v)
    if not ok or Secrets.IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

local function classOf(frame)
    if frame.sample then return frame.sample.class end
    local ok, _, token = pcall(UnitClass, frame.unit)
    return readable(ok, token)
end

local function roleOf(frame)
    if frame.sample then return frame.sample.role end
    return readable(pcall(UnitGroupRolesAssigned, frame.unit))
end

-- The power strip's rule (powerStrip; OFF switches the bar off
-- altogether): everyone, mana users by class, or healers by assigned
-- role. A unit that cannot be told keeps its strip, as a power bar does
-- whenever nothing can be told (Elements/Power.lua).
function Cell.ShowsPower(frame)
    local strip = get("powerStrip")
    if strip == "MANA" then
        local class = classOf(frame)
        if class then return Cell.MANA_CLASSES[class] == true end
    elseif strip == "HEALERS" then
        local role = roleOf(frame)
        if role then return role == "HEALER" end
    end
    return true
end

-- What every cell is, real or pretend.
function Cell.Setup(button)
    button.key = Cell.KEY
    button.centerTexts = true
    button.showsPower = Cell.ShowsPower
    -- No aura groups at all: no aura containers are made for a cell
    -- (Elements/AuraContainers.lua).
    button.auraGroupKeys = {}
    for _, el in ipairs(ns.Elements) do el.Build(button) end
    ns.Units.EnableTooltip(button)
end

-- XML OnLoad: the cell exists, its unit is not known yet.
function Cell.InitButton(button)
    Cell.Setup(button)
    Cell.buttons[#Cell.buttons + 1] = button
    ns.Units.EnableClickCast(button)
    -- Made in combat it keeps the XML size until the relayout after combat.
    if not InCombatLockdown() then button:SetSize(ns.Single.Size(Cell.KEY)) end
    ns.Single.StyleContent(button)
end

-- The header assigns or clears a unit, in or out of combat. The panel
-- hears of it (RAID_CELLS_CHANGED): blocks may have grown or emptied.
-- The header sets every cell's unit on each roster update; a cell that
-- keeps its unit keeps its events and the panel its layout, but the
-- person behind the same raid unit may have changed, so it shows anew.
function Cell.OnUnitChanged(button, unit)
    if button.unit == unit then
        if unit then ns.Single.UpdateAll(button) end
        return
    end
    button.unit = unit
    ns.UnitEvents.Bind(button)
    ns.Fire("RAID_CELLS_CHANGED")
    if unit then ns.Single.UpdateAll(button) end
end

-- Size, contents and data of one cell; its size out of combat only.
function Cell.Style(button)
    if not InCombatLockdown() then button:SetSize(ns.Single.Size(Cell.KEY)) end
    ns.Single.StyleContent(button)
    ns.Single.UpdateAll(button)
end

-- Called from Raid/Cell.xml; not part of the public API.
ns.api.RaidButtonOnLoad = Cell.InitButton
function ns.api.RaidButtonOnAttributeChanged(button, name, value)
    if name == "unit" then Cell.OnUnitChanged(button, value) end
end

-- Roles changed: the healers' power strips follow.
ns.On("PLAYER_ROLES_ASSIGNED", function(event)
    for _, button in ipairs(Cell.buttons) do
        if button.unit and UnitExists(button.unit) then ns.Power.Update(button, event) end
    end
end)
