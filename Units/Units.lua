local _, ns = ...

-- Which frames exist and which game events make them refresh completely.
ns.Units = {}
ns.Units.List = {
    { key = "player", unit = "player", events = { "PLAYER_ENTERING_WORLD" } },
    { key = "target", unit = "target", events = { "PLAYER_TARGET_CHANGED" } },
}

ns.Elements = {}
function ns.RegisterElement(element)
    ns.Elements[#ns.Elements + 1] = element
end
