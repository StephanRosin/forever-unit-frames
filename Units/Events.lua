local _, ns = ...

-- Unit events reach a frame through its own listener, registered with
-- RegisterUnitEvent for exactly the frame's unit. With party frames the
-- number of frames grows, and one shared handler looping over every frame
-- for every UNIT_* event (nameplates included) would not scale.
local UnitEvents = {}
ns.UnitEvents = UnitEvents

-- event -> elements that listen to it. Built on first use: every element
-- file has registered by then.
local byEvent

local function index()
    if byEvent then return byEvent end
    byEvent = {}
    for _, el in ipairs(ns.Elements) do
        for _, event in ipairs(el.unitEvents or {}) do
            byEvent[event] = byEvent[event] or {}
            table.insert(byEvent[event], el)
        end
    end
    return byEvent
end

local function onEvent(listener, event, ...)
    local frame = listener.owner
    if not frame.unit or not UnitExists(frame.unit) then return end
    for _, el in ipairs(byEvent[event]) do el.Update(frame, event, ...) end
end

-- (Re)registers all element events for frame.unit. Runs again whenever the
-- frame's unit changes (party slots, test mode). The listener is a plain
-- frame, so this is allowed in combat.
function UnitEvents.Bind(frame)
    local listener = frame.eventListener
    if not listener then
        listener = CreateFrame("Frame")
        listener.owner = frame
        listener:SetScript("OnEvent", onEvent)
        frame.eventListener = listener
    end
    listener:UnregisterAllEvents()
    if not frame.unit then return end
    for event in pairs(index()) do
        listener:RegisterUnitEvent(event, frame.unit)
    end
end
