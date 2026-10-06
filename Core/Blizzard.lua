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
        -- Reparenting a protected frame is refused only in combat, and
        -- Conceal runs out of combat (ns.AfterCombat). These frames still
        -- keep their parent: they are made invisible and inert instead
        -- (alpha 0, no mouse), so a later Show from Blizzard's code shows
        -- nothing and takes no clicks. Only the raid container, whose own
        -- secure children stayed clickable that way, moves under the
        -- hidden parent (concealContainer below).
        frame:SetAlpha(0)
        frame:EnableMouse(false)
        hide(frame)
    else
        hide(frame)
        frame:SetParent(hiddenParent)
    end
end

-- Blizzard's party: the member buttons live in a pool on PartyFrame; the
-- raid-style CompactPartyFrame is created on demand as its child. Each
-- member carries a secure pet button (PetFrame, PartyMemberPetFrameTemplate)
-- that PartyMemberFrame shows on its own when the pet exists.
local function concealParty()
    local party = _G.PartyFrame
    if party then
        local pool = party.PartyMemberFramePool
        if pool then
            for member in pool:EnumerateActive() do
                Blizzard.Conceal(member)
                -- A parentKey child: a plain field of the member.
                Blizzard.Conceal(rawget(member, "PetFrame"))
            end
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
            if ns.Config.Get("player", "hideBlizzardCastbar") then Blizzard.Conceal(_G.PlayerCastingBarFrame) end
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
    if key == nil or key == "enabled" or key == "hideBlizzardCastbar" then Blizzard.HideDefaults() end
end)

-- Blizzard's party code acquires member frames and creates the compact
-- party frame when the roster changes; those are hidden as they come.
ns.On("GROUP_ROSTER_UPDATE", function()
    if ns.Config.Profile() and enabled("party") then
        ns.AfterCombat("hideBlizzardParty", concealParty)
    end
end)

-- Blizzard's raid frames (Blizzard_CompactRaidFrames): the container of
-- compact unit frames and the manager panel at the screen's left edge.
-- Both go while our raid frames are on and set to hide them; getting them
-- back needs a /reload, as for the unit frames. Taking their events is not
-- enough: Blizzard's global roster handler (UpdateRaidAndPartyFrames ->
-- CompactRaidFrameManager_UpdateShown -> ..._UpdateContainerVisibility),
-- Edit Mode and the raid profile's "shown" option show both again, also in
-- combat. So both move under our hidden parent, where a Show no longer
-- makes them, or the compact unit buttons inside the container, visible
-- or clickable. The container holds secure buttons, so that move is made
-- out of combat; no Blizzard code reparents it again. Its state ("enabled",
-- the "IsShown" setting) is left alone: written by addon code it would
-- taint Blizzard's roster handler, whose Show/Hide of the container in
-- combat would then be blocked.
local function raidHidden()
    local RC = ns.RaidConfig
    return RC.Profile() ~= nil and RC.Get("general", "enabled") and RC.Get("general", "hideBlizzard")
end

-- Out of combat only: the container is protected through its children.
local function concealContainer(container)
    if not container then return end
    container:UnregisterAllEvents()
    hide(container)
    container:SetParent(hiddenParent)
end

local function concealRaid()
    Blizzard.Conceal(_G.CompactRaidFrameManager)
    concealContainer(_G.CompactRaidFrameContainer)
end

function Blizzard.HideRaid()
    if raidHidden() then ns.AfterCombat("hideBlizzardRaid", concealRaid) end
end

ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if scope == nil or (scope == "general" and (key == nil or key == "enabled" or key == "hideBlizzard")) then
        Blizzard.HideRaid()
    end
end)
ns.On("GROUP_ROSTER_UPDATE", Blizzard.HideRaid)
