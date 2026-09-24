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

ns.Elements = {}
function ns.RegisterElement(element)
    ns.Elements[#ns.Elements + 1] = element
end
