local _, ns = ...

-- Which frames exist and which game events make them refresh completely.
-- eventUnit limits an event to one unit (registered with RegisterUnitEvent).
-- poll (seconds) refreshes a shown frame on a timer: "targettarget" gets
-- no unit events of its own.
ns.Units = {}

-- Blizzard ships no focus frame for this game type. The unit token exists
-- in the client source; whether the client accepts it is checked at run
-- time and shown by /fuf status.
function ns.Units.FocusAvailable()
    return (pcall(UnitExists, "focus"))
end

ns.Units.List = {
    { key = "player", unit = "player", events = { "PLAYER_ENTERING_WORLD" } },
    { key = "target", unit = "target", events = { "PLAYER_TARGET_CHANGED" } },
    { key = "targettarget", unit = "targettarget", events = { "PLAYER_TARGET_CHANGED", "UNIT_TARGET" },
      eventUnit = { UNIT_TARGET = "target" }, poll = 0.2 },
    { key = "pet", unit = "pet", events = { "PLAYER_ENTERING_WORLD", "UNIT_PET" },
      eventUnit = { UNIT_PET = "player" } },
    { key = "focus", unit = "focus", events = { "PLAYER_FOCUS_CHANGED" }, available = ns.Units.FocusAvailable },
    -- Built by Units/Party.lua from a group header, not as a single frame.
    { key = "party", group = true },
}

-- Hovering a unit frame shows its unit's tooltip. Blizzard's own
-- UnitFrame_OnEnter / OnLeave where the client has them (they read
-- frame.unit, as ours does); otherwise the same in short. Hooked, so the
-- secure template's own scripts stay as they are.
local function onEnter(frame)
    if UnitFrame_OnEnter then return UnitFrame_OnEnter(frame) end
    if not frame.unit then return end
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, frame)
    else
        GameTooltip:SetOwner(frame, "ANCHOR_BOTTOMRIGHT")
    end
    if GameTooltip:SetUnit(frame.unit) then GameTooltip:Show() end
end

local function onLeave(frame)
    if UnitFrame_OnLeave then return UnitFrame_OnLeave(frame) end
    GameTooltip:Hide()
end

function ns.Units.EnableTooltip(frame)
    frame:HookScript("OnEnter", onEnter)
    frame:HookScript("OnLeave", onLeave)
end

-- Click-casting addons (Clique and others) find unit frames through the
-- shared global table ClickCastFrames: frame -> true. Clique takes the
-- entries made before it loaded and watches the table afterwards,
-- queueing registrations made in combat itself. Live unit buttons only,
-- not test mode's pretend ones.
function ns.Units.EnableClickCast(frame)
    ClickCastFrames = ClickCastFrames or {}
    ClickCastFrames[frame] = true
end

ns.Elements = {}
function ns.RegisterElement(element)
    ns.Elements[#ns.Elements + 1] = element
end

-- Every unit frame that exists: the single frames, the party members and
-- pets and the raid cells the headers made, and the pretend ones of test
-- mode. For events that concern all of them at once (raid markers, the
-- group's leader, a ready check). fn(frame) runs for each, shown or not.
function ns.Units.ForEachFrame(fn)
    for _, frame in pairs(ns.Frames or {}) do fn(frame) end
    for _, list in ipairs({ ns.Party and ns.Party.buttons, ns.Party and ns.Party.fakes,
        ns.PartyPets and ns.PartyPets.buttons, ns.PartyPets and ns.PartyPets.fakes,
        ns.RaidCell and ns.RaidCell.buttons, ns.RaidCell and ns.RaidCell.fakes,
        ns.RaidCell and ns.RaidCell.panelFakes }) do
        for _, frame in ipairs(list or {}) do fn(frame) end
    end
end

-- Runs one element's Update on every frame that shows a unit.
function ns.Units.UpdateElement(element, event)
    ns.Units.ForEachFrame(function(frame)
        if frame.unit and UnitExists(frame.unit) then element.Update(frame, event) end
    end)
end

-- Buttons made ahead of time --------------------------------------------------------
-- A group header (SecureGroupHeaderTemplate) makes a button when it first
-- needs one, in combat too when someone joins then; such a button cannot
-- get its aura containers until combat ends (Elements/AuraContainers.lua).
-- So the party header and the raid blocks make theirs out of combat, and
-- each button prepares its containers as it is made (ns.Units.Prepare).
--
-- How (configureChildren in Blizzard_RestrictedAddOnEnvironment/
-- SecureGroupHeaders.lua): it makes buttons up to the number it displays,
-- numDisplayed = loopFinish - (startingIndex - 1). With startingIndex
-- 1 - n, unitsPerColumn n and maxColumns 1, loopFinish is
-- min(startingIndex - 1 + n, unitCount) = 0 whatever the roster, so it
-- displays exactly n, and every one of them at an index <= 0: no unit. The
-- header lays out once so (on show, hidden at once again: nothing is
-- drawn in between), takes its own attributes back and is shown again as
-- it was, which lays out the real members. Out of combat only; nothing
-- happens when the header has n buttons already.
ns.Units.PREBUILD_KEYS = { "startingIndex", "unitsPerColumn", "maxColumns" }

local function setQuietly(header, values)
    header:SetAttribute("_ignore", "attributeChanges")
    for _, name in ipairs(ns.Units.PREBUILD_KEYS) do header:SetAttribute(name, values[name]) end
    header:SetAttribute("_ignore", nil)
end

-- Returns whether buttons were made.
function ns.Units.PrebuildButtons(header, n)
    if not header or n < 1 or InCombatLockdown() or header:GetAttribute("child" .. n) then return false end
    local saved = {}
    for _, name in ipairs(ns.Units.PREBUILD_KEYS) do saved[name] = header:GetAttribute(name) end
    local shown = header:IsShown()
    header:Hide()
    setQuietly(header, { startingIndex = 1 - n, unitsPerColumn = n, maxColumns = 1 })
    header:Show()
    header:Hide()
    setQuietly(header, saved)
    if shown then header:Show() end
    return true
end

-- A unit button just made, out of combat: what each element would
-- otherwise make the first time it shows a unit, made now (Prepare, an
-- optional element call), so a unit handed out in combat finds it ready.
function ns.Units.Prepare(frame)
    if InCombatLockdown() then return end
    for _, el in ipairs(ns.Elements) do
        if el.Prepare then el.Prepare(frame) end
    end
end
