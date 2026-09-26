local _, ns = ...

-- Group icons on the player and party frames, in Blizzard's own art:
-- * leader: the crown of the Mainline party and player frames
--   (PartyFrameTemplates.xml / PlayerFrame.xml, LeaderIcon), the guide
--   icon instead while group finder restrictions apply (GuideIcon,
--   PartyMemberFrameMixin:UpdateLeader); an assistant gets the raid
--   roster's icon (Blizzard_RaidUI.lua, UI-Group-AssistantIcon).
-- * ready check: the raid frames' marks (CompactUnitFrameReadyCheckMixin,
--   READY_CHECK_*_TEXTURE_RAID in ReadyCheck.lua). After the check the
--   result stays CUF_READY_CHECK_DECAY_TIME seconds; no answer counts as
--   not ready (CompactUnitFrame_FinishReadyCheck).
-- * incoming resurrection: the raid frames' centre icon
--   (CompactUnitFrame.lua, "IncomingResurrection").
-- Master looter: the client has the loot method (C_PartyInfo.GetLootMethod,
-- Enum.LootMethod.Masterlooter) but no art for it anywhere in its UI, so
-- it is not shown.
--
-- UnitIsGroupLeader / UnitIsGroupAssistant are secret for units that are
-- not player-controlled or in the group (SecretWhenUnitIdentityRestricted);
-- GetReadyCheckStatus and UnitHasIncomingResurrection are undocumented.
-- Everything is read through Secrets: a secret or refused answer shows
-- nothing.
--
-- One row on a plain holder like the player's status icons: a slot for
-- each group switched on, the icons that show packed towards the anchor
-- point's side. Textures of a plain frame: they may change in combat.
local GroupIcons = { name = "GroupIcons", unitEvents = { "INCOMING_RESURRECT_CHANGED" } }
ns.GroupIcons = GroupIcons

local Config, Pixel, Layout, Secrets, Settings = ns.Config, ns.Pixel, ns.Layout, ns.Secrets, ns.Settings

GroupIcons.LEADER = { leader = { atlas = "UI-HUD-UnitFrame-Player-Group-LeaderIcon" },
    guide = { atlas = "UI-HUD-UnitFrame-Player-Group-GuideIcon" },
    assistant = { file = "Interface\\GroupFrame\\UI-Group-AssistantIcon" } }
GroupIcons.READY = { ready = "UI-LFG-ReadyMark-Raid", notready = "UI-LFG-DeclineMark-Raid",
    waiting = "UI-LFG-PendingMark-Raid" }
GroupIcons.REZ_ATLAS = "RaidFrame-Icon-Rez"
-- CUF_READY_CHECK_DECAY_TIME (CompactUnitFrame.lua).
GroupIcons.READY_DECAY = 11
-- Above the text overlay (+10) and the aura holders (+12), below the class
-- badge (+20), like the raid marker.
GroupIcons.LEVELS = 18
-- Gap between two slots, in pixels.
local GAP = 2

-- Test mode: the player leads and is ready; the pretend party answers
-- the check (member 2 not ready, dead, with a resurrection coming).
GroupIcons.SAMPLES = { player = { leader = "leader", ready = "ready" } }
GroupIcons.PARTY_SAMPLES = {
    [1] = { ready = "ready" },
    [2] = { ready = "notready", rez = true },
    [4] = { ready = "waiting" },
}

-- Set from READY_CHECK_FINISHED until the result has decayed: a table
-- per finished check, so an older timer cannot end a newer check.
local decay

function GroupIcons.Applies(scope)
    return Settings.AppliesTo(Settings.Get("groupLeader"), scope)
end

function GroupIcons.Build(frame)
    if not GroupIcons.Applies(frame.key) then return end
    local holder = CreateFrame("Frame", nil, frame)
    local g = { holder = holder }
    for _, name in ipairs({ "leader", "ready", "rez" }) do
        g[name] = holder:CreateTexture(nil, "OVERLAY")
        g[name]:Hide()
    end
    g.rez:SetAtlas(GroupIcons.REZ_ATLAS)
    frame.groupIcons = g
end

local function want(frame, key) return Config.Get(frame.key, key) end

-- The slots switched on, left to right.
local function slots(frame)
    local g, list = frame.groupIcons, {}
    if want(frame, "groupLeader") then list[#list + 1] = g.leader end
    if want(frame, "groupReadyCheck") then list[#list + 1] = g.ready end
    if want(frame, "groupResurrect") then list[#list + 1] = g.rez end
    return list
end

-- The icons that show, side by side in the holder.
local function arrange(g, shown)
    if not g.size then return end
    local free = g.holder:GetWidth() - Layout.IconRowWidth(#shown, g.size, g.gap)
    local start = Pixel.Snap(free * Layout.IconRowJustify(g.point))
    for i, icon in ipairs(shown) do
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", g.holder, "TOPLEFT", start + (i - 1) * (g.size + g.gap), 0)
        icon:SetSize(g.size, g.size)
    end
end

local function drawLeader(icon, kind)
    local art = GroupIcons.LEADER[kind]
    if art.atlas then icon:SetAtlas(art.atlas) else icon:SetTexture(art.file) end
end

-- Any time, combat included: which icons show, from what the frame knows
-- (g.leaderKind, g.readyStatus, g.hasRez) or its test mode sample.
function GroupIcons.Refresh(frame)
    local g = frame.groupIcons
    if not g then return end
    local live = { leader = g.leaderKind, ready = g.readyStatus, rez = g.hasRez }
    local data = g.preview or live
    local kind = want(frame, "groupLeader") and data.leader or nil
    local status = want(frame, "groupReadyCheck") and data.ready or nil
    local rez = want(frame, "groupResurrect") and data.rez == true
    if kind then drawLeader(g.leader, kind) end
    if status then g.ready:SetAtlas(GroupIcons.READY[status]) end
    g.leader:SetShown(kind ~= nil)
    g.ready:SetShown(status ~= nil)
    g.rez:SetShown(rez)
    local shown = {}
    for _, icon in ipairs({ g.leader, g.ready, g.rez }) do
        if icon:IsShown() then shown[#shown + 1] = icon end
    end
    arrange(g, shown)
end

-- Plain frames only: allowed in combat (party buttons restyle then too).
function GroupIcons.Style(frame)
    local g, scope = frame.groupIcons, frame.key
    if not g then return end
    local size = Pixel.Snap(Config.Get(scope, "groupIconSize"), nil, 1)
    g.size, g.gap, g.point = size, Pixel.Snap(GAP), Config.Get(scope, "groupIconPoint")
    local n = #slots(frame)
    g.holder:SetFrameLevel(frame:GetFrameLevel() + GroupIcons.LEVELS)
    g.holder:SetSize(math.max(1, Layout.IconRowWidth(n, size, g.gap)), size)
    g.holder:ClearAllPoints()
    g.holder:SetPoint(g.point, frame, Config.Get(scope, "groupIconFramePoint"),
        Pixel.Snap(Config.Get(scope, "groupIconX")), Pixel.Snap(Config.Get(scope, "groupIconY")))
    g.holder:SetShown(n > 0)
    GroupIcons.Refresh(frame)
end

-- "leader", "guide", "assistant" or nil.
local function leaderKind(unit)
    if Secrets.Bool(UnitIsGroupLeader, unit) then
        if type(HasLFGRestrictions) == "function" and Secrets.Bool(HasLFGRestrictions) then return "guide" end
        return "leader"
    end
    if Secrets.Bool(UnitIsGroupAssistant, unit) then return "assistant" end
    return nil
end

-- "ready", "notready", "waiting" or nil. Offline members show none, as
-- Blizzard's party frames (PartyMemberFrameMixin:UpdateReadyCheck).
local function readyStatus(unit)
    if Secrets.Bool(UnitIsConnected, unit) == false then return nil end
    local ok, status = pcall(GetReadyCheckStatus, unit)
    if not ok or Secrets.IsSecret(status) or type(status) ~= "string" then return nil end
    if GroupIcons.READY[status] then return status end
    return nil
end

function GroupIcons.Update(frame)
    local g = frame.groupIcons
    if not g or g.preview then return end
    local unit = frame.unit
    g.leaderKind = leaderKind(unit)
    -- While a finished check decays its result stays as it was.
    if not decay then g.readyStatus = readyStatus(unit) end
    g.hasRez = Secrets.Bool(UnitHasIncomingResurrection, unit) == true
    GroupIcons.Refresh(frame)
end

local function sample(frame)
    if frame.sampleIndex then return GroupIcons.PARTY_SAMPLES[frame.sampleIndex] end
    return GroupIcons.SAMPLES[frame.key]
end

function GroupIcons.Preview(frame, on)
    local g = frame.groupIcons
    if not g then return end
    g.preview = on and (sample(frame) or {}) or nil
    if not on and frame.unit and UnitExists(frame.unit) then
        GroupIcons.Update(frame)
    else
        GroupIcons.Refresh(frame)
    end
end

local function updateAll(event) ns.Units.UpdateElement(GroupIcons, event) end

ns.On("PARTY_LEADER_CHANGED", updateAll)
ns.On("GROUP_ROSTER_UPDATE", updateAll)
-- The confirming unit may be named by another token than the frame's
-- (a raid token): every frame looks again.
ns.On("READY_CHECK_CONFIRM", updateAll)

ns.On("READY_CHECK", function(event)
    decay = nil
    updateAll(event)
end)

-- The result stays a while; whoever did not answer is not ready.
ns.On("READY_CHECK_FINISHED", function()
    local token = {}
    decay = token
    ns.Units.ForEachFrame(function(frame)
        local g = frame.groupIcons
        if not g or g.preview then return end
        if g.readyStatus == "waiting" then g.readyStatus = "notready" end
        GroupIcons.Refresh(frame)
    end)
    C_Timer.After(GroupIcons.READY_DECAY, function()
        if decay ~= token then return end
        decay = nil
        ns.Units.ForEachFrame(function(frame)
            local g = frame.groupIcons
            if not g or g.preview then return end
            g.readyStatus = nil
            GroupIcons.Refresh(frame)
        end)
        updateAll("READY_CHECK_FINISHED")
    end)
end)

ns.RegisterElement(GroupIcons)
