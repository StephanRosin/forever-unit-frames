local _, ns = ...

-- Hides Blizzard's own unit frames without hooking any of their methods
-- (hooking mixin methods breaks Blizzard code on this client).
local Blizzard = {}
ns.Blizzard = Blizzard

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

-- Edit Mode frames carry the original C Hide as a plain field "HideBase";
-- calling their overridden Hide would write into the Edit Mode manager.
local function hide(frame)
    local hideBase = rawget(frame, "HideBase")
    if hideBase then hideBase(frame) else frame:Hide() end
end

function Blizzard.Conceal(frame)
    if not frame then return end
    frame:UnregisterAllEvents()
    -- IsProtected may return a secret or fail; unknown counts as protected.
    if ns.Secrets.Bool(frame.IsProtected, frame) ~= false then
        -- Protected frames may not be reparented; make them invisible and
        -- inert instead.
        frame:SetAlpha(0)
        frame:EnableMouse(false)
        hide(frame)
    else
        hide(frame)
        frame:SetParent(hiddenParent)
    end
end

-- Blizzard's party: the member buttons live in a pool on PartyFrame; the
-- raid-style CompactPartyFrame is created on demand as its child.
local function concealParty()
    local party = _G.PartyFrame
    if party then
        local pool = party.PartyMemberFramePool
        if pool then
            for member in pool:EnumerateActive() do Blizzard.Conceal(member) end
        end
        Blizzard.Conceal(party)
    end
    Blizzard.Conceal(_G.CompactPartyFrame)
end

local function enabled(scope) return ns.Config.Get(scope, "enabled") end

-- Only frames we replace are hidden. Running again is harmless, so newly
-- enabled frames are covered at once; getting a Blizzard frame back needs
-- a /reload.
function Blizzard.HideDefaults()
    ns.AfterCombat("hideBlizzard", function()
        if enabled("player") then
            Blizzard.Conceal(_G.PlayerFrame)
            if ns.Config.Get("player", "castbarEnabled") then Blizzard.Conceal(_G.PlayerCastingBarFrame) end
        end
        if enabled("target") then
            Blizzard.Conceal(_G.TargetFrame)
            Blizzard.Conceal(_G.ComboFrame)
        end
        if enabled("targettarget") then Blizzard.Conceal(_G.TargetFrameToT) end
        if enabled("pet") then Blizzard.Conceal(_G.PetFrame) end
        -- Ours exists only when the focus unit is available on this client.
        if enabled("focus") and ns.Frames.focus then Blizzard.Conceal(_G.FocusFrame) end
        if enabled("party") then concealParty() end
    end)
end

ns.Listen("CONFIG_CHANGED", function(_, key)
    if key == nil or key == "enabled" or key == "castbarEnabled" then Blizzard.HideDefaults() end
end)

-- Blizzard's party code acquires member frames and creates the compact
-- party frame when the roster changes; those are hidden as they come.
ns.On("GROUP_ROSTER_UPDATE", function()
    if ns.Config.Profile() and enabled("party") then
        ns.AfterCombat("hideBlizzardParty", concealParty)
    end
end)
