-- Can this client make aura containers for addons? Asked once, with one
-- hidden container; a client that refuses keeps the addon's own reads.
local M = H.M

local ns = H.LoadAddon()
local AC = ns.AuraContainers
H.check("nothing asked at load", #M.auraContainers, 0)
H.check("supported", AC.Supported(), true)
H.check("one test container", #M.auraContainers, 1)
local probe = M.auraContainers[1]
H.check("test container template", probe._template, "CustomAuraContainerTemplate")
H.check("test container on UIParent", probe:GetParent(), UIParent)
H.check("test container hidden", probe:IsShown(), false)
H.check("test container unused", #probe._groupOrder, 0)
H.check("asked once", AC.Supported(), true)
H.check("still one test container", #M.auraContainers, 1)

-- A client without the frame type: CreateFrame raises, the answer is no.
ns = H.LoadAddon()
M.auraContainerMissing = true
H.check("missing type", ns.AuraContainers.Supported(), false)
H.check("no container made", #M.auraContainers, 0)
M.auraContainerMissing = false
H.check("answer kept for the session", ns.AuraContainers.Supported(), false)

-- A container without one of the calls the addon makes is not used.
ns = H.LoadAddon()
local real = M.NewAuraContainer
M.NewAuraContainer = function(w, template)
    real(w, template)
    w.SetAuraGroupLayout = nil
end
H.check("incomplete container", ns.AuraContainers.Supported(), false)
M.NewAuraContainer = real

-- /fuf status names the path.
local function status(missing)
    ns = H.LoadAddon()
    M.auraContainerMissing = missing
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    SlashCmdList.FOREVERUNITFRAMES("status")
    return table.concat(M.chat, "\n")
end
H.checkTrue("status: containers", status(false):find("Auras: drawn by the client", 1, true))
H.checkTrue("status: read path", status(true):find("Auras: read by the addon", 1, true))
