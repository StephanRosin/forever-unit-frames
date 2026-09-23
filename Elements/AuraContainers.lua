local _, ns = ...

-- Live auras through Blizzard's CustomAuraContainerTemplate
-- (Blizzard_AuraContainer). The client reads the auras and fills the icons
-- from secure code, in combat too; the addon only configures a container
-- (unit, filters, layout) and gives its buttons their look. Our own read
-- path (Elements/Auras.lua) stays for test mode samples and for clients
-- where a container cannot be made.
local AuraContainers = {}
ns.AuraContainers = AuraContainers

AuraContainers.TEMPLATE = "CustomAuraContainerTemplate"
-- The inbound calls this addon makes; a container without them is not
-- used.
AuraContainers.METHODS = { "SetUnit", "GetUnit", "UpdateAllAuras", "AddAuraGroup", "SetAuraGroupEnabled",
    "SetAuraGroupFilterString", "SetAuraGroupMaxFrameCount", "SetAuraGroupLayout", "SetFlowLayoutAxis",
    "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection", "SetFlowLayoutMaximumLineSize" }

-- nil until asked; then true or false for the session.
local supported

local function complete(container)
    for _, method in ipairs(AuraContainers.METHODS) do
        if type(container[method]) ~= "function" then return false end
    end
    return true
end

local function probe()
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, UIParent, AuraContainers.TEMPLATE)
    if not ok or type(container) ~= "table" then return false end
    container:Hide()
    local asked, answer = pcall(complete, container)
    return asked and answer
end

-- Whether this client can make aura containers for addons. Asked once,
-- with one hidden test container that is never used again.
function AuraContainers.Supported()
    if supported == nil then supported = probe() end
    return supported
end
