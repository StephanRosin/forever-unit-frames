local _, ns = ...

-- Which frames exist and which game events make them refresh completely.
-- eventUnit limits an event to one unit (registered with RegisterUnitEvent).
-- poll (seconds) refreshes a shown frame on a timer: "targettarget" gets
-- no unit events of its own.
ns.Units = {}
ns.Units.List = {
    { key = "player", unit = "player", events = { "PLAYER_ENTERING_WORLD" } },
    { key = "target", unit = "target", events = { "PLAYER_TARGET_CHANGED" } },
    { key = "targettarget", unit = "targettarget", events = { "PLAYER_TARGET_CHANGED", "UNIT_TARGET" },
      eventUnit = { UNIT_TARGET = "target" }, poll = 0.2 },
    { key = "pet", unit = "pet", events = { "PLAYER_ENTERING_WORLD", "UNIT_PET" },
      eventUnit = { UNIT_PET = "player" } },
}

ns.Elements = {}
function ns.RegisterElement(element)
    ns.Elements[#ns.Elements + 1] = element
end
