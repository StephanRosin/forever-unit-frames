local _, ns = ...

-- One raid cell: a unit button the block headers (Raid/Header.lua) make
-- from the template in Raid/Cell.xml, running the unit-frame elements
-- (ns.Elements) like a party member does. Its settings come through a
-- derived unit-frame scope, "raid", that answers every unit-frame setting
-- itself: the cell's look from the raid profile of the active size,
-- everything a cell never shows switched off, and the unit frames'
-- shipped defaults for the rest, so nothing set for the party frame and
-- no unit-frame look setting reaches a cell (the language and the range
-- mode in General still apply). Name and second line stand centred in the
-- health bar (Elements/Texts.lua, frame.centerTexts); the power strip
-- follows its own rule per unit (frame.showsPower).
--
-- No initialConfigFunction: secure snippets do not run on this client.
-- The XML gives a cell its starting size and clicks; Lua sizes it when
-- it is made out of combat, else after combat (Raid/Header.lua).
local Cell = {}
ns.RaidCell = Cell

local Config, Secrets = ns.Config, ns.Secrets

Cell.KEY = "raid"
-- The pets panel's cells (Raid/SpecialPanels.lua): a raid cell with a
-- height of its own.
Cell.PET_KEY = "raidpet"
Cell.TEMPLATE = "ForeverUnitFramesRaidButtonTemplate"
-- Every cell a header made, in creation order.
Cell.buttons = {}
-- Test mode's pretend cells (Raid/TestMode.lua): the main panel's, and
-- the special panels' (each panel keeps its own as well).
Cell.fakes = {}
Cell.panelFakes = {}

-- The size whose profile the cells show: the active one, 10 until it is
-- known; in test mode the one the raid options window edits.
function Cell.Size()
    local test = ns.RaidTestMode
    return test and test.PreviewSize() or ns.RaidSize.Current() or 10
end

-- A setting of the raid profile the cells show.
function Cell.Get(key)
    return ns.RaidConfig.Get(ns.Raid.Scope(Cell.Size()), key)
end
local get = Cell.Get

-- What a cell never shows: no title row, portrait, castbar, the unit
-- frames' aura icons (a cell's are its own, Raid/CellAuras.lua) or threat
-- glow, no heals past the edge (the next cell sits there), no shadow (it
-- would lie on the neighbours), no power texts, a ring right around the
-- cell (the cell spacing keeps them apart). The rows: a thin power strip
-- under the health bar.
local FIXED = {
    titlePercent = 0, portraitMode = "OFF", castbarEnabled = false,
    buffsEnabled = false, debuffsEnabled = false, threatGlow = false,
    titleClassIcon = false, healBeyond = false, shadowEnabled = false, groupResurrect = false,
    textHealthLeft = "NAME", textPowerLeft = "NONE", textPowerRight = "NONE",
    healthPercent = 90, powerPercent = 10, borderPadding = 0,
}

-- An icon at one of the cell's points sits just inside it: a pixel in
-- from each edge the point touches.
function Cell.Inset(point)
    local x = point:find("LEFT") and 1 or (point:find("RIGHT") and -1 or 0)
    local y = point:find("TOP") and -1 or (point:find("BOTTOM") and 1 or 0)
    return x, y
end

-- The icons a cell places on their own (Elements/GroupIcons.lua asks):
-- point and offsets, nil while the icon is off.
Cell.ICON_KEYS = { leader = "leaderIcon", looter = "looterIcon", ready = "readyCheckIcon", role = "roleIcon" }
function Cell.IconPoint(_, name)
    local key = Cell.ICON_KEYS[name]
    if not key or not get(key) then return nil end
    local point = get(key .. "Point")
    local x, y = Cell.Inset(point)
    return point, x, y
end

local function insetX(key) return function() return (Cell.Inset(get(key))) end end
local function insetY(key) return function() return select(2, Cell.Inset(get(key))) end end

-- The raid profile's look, in unit-frame settings. The second line's
-- values are the text tags of the same name. The raid marker
-- (Elements/RaidMarker.lua) at its point, just inside the cell; the group
-- icons (Elements/GroupIcons.lua) switched and sized from the profile;
-- range fading (Elements/Range.lua) from the profile.
local MAPPED = {
    width = function() return get("cellWidth") end,
    height = function() return get("cellHeight") end,
    healthColorMode = function() return get("healthColorMode") end,
    healthColor = function() return get("healthColor") end,
    barTexture = function() return get("barTexture") end,
    backgroundColor = function() return get("backgroundColor") end,
    powerEnabled = function() return get("powerStrip") ~= "OFF" end,
    healPrediction = function() return get("healPrediction") end,
    healOverflow = function() return get("overheal") end,
    absorbEnabled = function() return get("absorbs") end,
    combatFeedback = function() return get("combatText") end,
    textHealthRight = function() return get("secondLine") end,
    barNameColorMode = function() return get("nameClassColor") and "CLASS" or "WHITE" end,
    fontFace = function() return get("fontFace") end,
    fontSize = function() return get("nameFontSize") end,
    valueFontSize = function() return get("secondFontSize") end,
    fontOutline = function() return get("fontOutline") end,
    fontShadow = function() return get("fontShadow") end,
    borderShow = function() return get("cellBorder") end,
    borderStyle = function() return get("cellBorderStyle") end,
    borderSize = function() return get("cellBorderSize") end,
    borderColor = function() return get("cellBorderColor") end,
    cornerRadius = function() return get("cellCornerRadius") end,
    raidMarker = function() return get("raidMarker") end,
    raidMarkerSize = function() return get("iconSize") end,
    raidMarkerFramePoint = function() return get("raidMarkerPoint") end,
    raidMarkerPoint = function() return get("raidMarkerPoint") end,
    raidMarkerX = insetX("raidMarkerPoint"),
    raidMarkerY = insetY("raidMarkerPoint"),
    groupLeader = function() return get("leaderIcon") end,
    groupReadyCheck = function() return get("readyCheckIcon") end,
    groupIconSize = function() return get("iconSize") end,
    rangeFade = function() return get("rangeFade") end,
    rangeAlpha = function() return get("rangeAlpha") end,
}

-- Everything else is the unit frames' shipped default for a party frame
-- (Core/Settings.lua with the look of Core/Preset.lua), whatever the party
-- frame or General is set to: the heal, shield and power colours, the
-- aura icons' border, and what a cell has no use for (title texts, the
-- party's aura groups, castbar details ...). The party frame is the
-- derived scope's base only in name: every key is answered here.
local function shipped(key)
    return ns.Settings.Default(ns.Settings.Get(key), ns.Party.KEY)
end

function Cell.Resolve(key)
    local fixed = FIXED[key]
    if fixed ~= nil then return fixed end
    local mapped = MAPPED[key]
    if mapped then return mapped() end
    return shipped(key)
end
Config.Derive(Cell.KEY, ns.Party.KEY, Cell.Resolve)
Config.Derive(Cell.PET_KEY, Cell.KEY, function(key)
    if key == "height" then return get("petsCellHeight") end
    return nil
end)

-- A raid cell of any panel, a pet's too.
function Cell.Is(frame)
    return frame.key == Cell.KEY or frame.key == Cell.PET_KEY
end

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

function Cell.Role(frame)
    if frame.sample then return frame.sample.role end
    return readable(pcall(UnitGroupRolesAssigned, frame.unit))
end
local roleOf = Cell.Role

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

-- The colours of the name and of the second line (Elements/Texts.lua
-- asks): the name's gives way to the class colour when that is on.
function Cell.TextColors()
    return get("nameColor"), get("secondLineColor")
end

-- What every cell is, real or pretend: a raid cell, unless it was made
-- a pet's (button.key set before).
function Cell.Setup(button)
    button.key = button.key or Cell.KEY
    button.centerTexts = true
    button.textColors = Cell.TextColors
    button.showsPower = Cell.ShowsPower
    button.iconPoint = Cell.IconPoint
    button.fadesOutOfRange = true
    -- None of the unit frames' aura groups (Elements/AuraContainers.lua
    -- makes no container for them); a cell's own auras are one container
    -- of its own (Raid/CellAuras.lua).
    button.auraGroupKeys = {}
    for _, el in ipairs(ns.Elements) do el.Build(button) end
    ns.Units.EnableTooltip(button)
end

-- XML OnLoad: the cell exists, its unit is not known yet. Its header
-- says which cells it makes (Raid/Panel.lua: cellKey).
function Cell.InitButton(button)
    local header = button:GetParent()
    button.key = header and header.cellKey or Cell.KEY
    Cell.Setup(button)
    Cell.buttons[#Cell.buttons + 1] = button
    ns.Units.EnableClickCast(button)
    -- Made in combat it keeps the XML size until the relayout after combat.
    if not InCombatLockdown() then button:SetSize(ns.Single.Size(button.key)) end
    ns.Single.StyleContent(button)
    -- Our click-casting (Raid/ClickCast.lua), now or after combat.
    ns.ClickCast.Added(button)
end

-- The header assigns or clears a unit, in or out of combat. The panel
-- hears of it (RAID_CELLS_CHANGED): blocks may have grown or emptied.
-- The header sets every cell's unit on each roster update; a cell that
-- keeps its unit keeps its events and the panel its layout, but the
-- person behind the same raid unit may have changed, so it shows anew.
-- A cleared cell's aura container looks at no unit any more.
function Cell.OnUnitChanged(button, unit)
    if button.unit == unit then
        if unit then ns.Single.UpdateAll(button) end
        return
    end
    button.unit = unit
    ns.UnitEvents.Bind(button)
    ns.Fire("RAID_CELLS_CHANGED")
    if unit then
        ns.Single.UpdateAll(button)
    else
        ns.RaidAuras.Release(button)
    end
end

-- Size, contents and data of one cell; its size out of combat only.
function Cell.Style(button)
    if not InCombatLockdown() then button:SetSize(ns.Single.Size(button.key)) end
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
