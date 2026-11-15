local _, ns = ...

-- Group icons on the player and party frames, in Blizzard's own art except
-- where that is too small to stay sharp (leader and role: our own, Media.Icon):
-- * leader: a crown as on the Mainline party and player frames
--   (PartyFrameTemplates.xml / PlayerFrame.xml, LeaderIcon), the guide
--   icon instead while group finder restrictions apply (GuideIcon,
--   PartyMemberFrameMixin:UpdateLeader); an assistant gets its own icon
--   as in the raid roster (Blizzard_RaidUI.lua).
-- * ready check: the raid frames' marks (CompactUnitFrameReadyCheckMixin,
--   READY_CHECK_*_TEXTURE_RAID in ReadyCheck.lua). After the check the
--   result stays CUF_READY_CHECK_DECAY_TIME seconds; no answer counts as
--   not ready (CompactUnitFrame_FinishReadyCheck).
-- * incoming resurrection: the raid frames' centre icon
--   (CompactUnitFrame.lua, "IncomingResurrection").
-- * incoming summon and another phase: the raid frames' centre icons
--   (CompactUnitFrame.lua, "IncomingSummon*", "InOtherPhase"), the phase only
--   within DISTANCE_THRESHOLD_SQUARED of you, as there.
-- * role (off by default): the assigned role as a round badge, the raid
--   cells' too (Raid/CellRole.lua).
--   With groupRolePortrait it leaves the row for a corner of the
--   portrait while the frame shows one (placeRole), with its own size,
--   point and offset there.
--   UnitGroupRolesAssigned is secret while the unit's identity is
--   restricted (SecretWhenUnitIdentityRestricted): then none.
-- Master looter: the client has the loot method (C_PartyInfo.GetLootMethod,
-- Enum.LootMethod.Masterlooter) but no art for it anywhere in its UI, so
-- the unit frames do not show it; raid cells show our own
-- (Media/MasterLooter.tga, tools/make_master_looter.py).
--
-- Raid cells (Raid/Cell.lua) place each icon on its own:
-- frame.iconPoint(frame, name) gives icon `name` ("leader", "looter",
-- "ready") its point on the cell and offsets, nil while it is off.
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
local GroupIcons = { name = "GroupIcons", unitEvents = { "INCOMING_RESURRECT_CHANGED", "INCOMING_SUMMON_CHANGED", "UNIT_PHASE" } }
ns.GroupIcons = GroupIcons

local Config, Pixel, Layout, Secrets, Settings = ns.Config, ns.Pixel, ns.Layout, ns.Secrets, ns.Settings

GroupIcons.LEADER = { leader = ns.Media.Icon("Leader"), guide = ns.Media.Icon("Guide"),
    assistant = ns.Media.Icon("Assistant") }
GroupIcons.READY = { ready = "UI-LFG-ReadyMark-Raid", notready = "UI-LFG-DeclineMark-Raid",
    waiting = "UI-LFG-PendingMark-Raid" }
GroupIcons.REZ_ATLAS = "RaidFrame-Icon-Rez"
GroupIcons.SUMMON = { pending = "RaidFrame-Icon-SummonPending", accepted = "RaidFrame-Icon-SummonAccepted",
    declined = "RaidFrame-Icon-SummonDeclined" }
GroupIcons.PHASE_ATLAS = "RaidFrame-Icon-Phasing"
-- DISTANCE_THRESHOLD_SQUARED (CompactUnitFrame.lua).
GroupIcons.PHASE_DISTANCE_SQUARED = 250 * 250
GroupIcons.ROLE_TEXTURE = { TANK = ns.Media.Icon("RoleTank"), HEALER = ns.Media.Icon("RoleHealer"),
    DAMAGER = ns.Media.Icon("RoleDamage") }
GroupIcons.LOOTER_TEXTURE = "Interface\\AddOns\\ForeverUnitFrames\\Media\\MasterLooter.tga"
-- The icons a raid cell places on their own.
GroupIcons.OWN_POINTS = { "leader", "looter", "ready", "summon", "phase" }
-- CUF_READY_CHECK_DECAY_TIME (CompactUnitFrame.lua).
GroupIcons.READY_DECAY = 11
-- Above the text overlay (+10) and the aura holders (+12), below the class
-- badge (+20), like the raid marker.
GroupIcons.LEVELS = 18
-- Gap between two slots, in pixels.
local GAP = 2
-- The role on the portrait: in from its edges by this many pixels.
local ROLE_INSET = 2

-- Test mode: the player leads, tanks and is ready; the pretend party
-- answers the check (member 2 not ready, dead, with a resurrection
-- coming); member 1 heals, the others deal damage.
GroupIcons.SAMPLES = { player = { leader = "leader", ready = "ready", role = "TANK" } }
GroupIcons.PARTY_SAMPLES = {
    [1] = { ready = "ready", role = "HEALER" },
    [2] = { ready = "notready", rez = true, role = "DAMAGER" },
    [3] = { role = "DAMAGER", summon = "pending" },
    [4] = { ready = "waiting", role = "DAMAGER", phase = true },
}

-- Set from READY_CHECK_FINISHED until the result has decayed: a table
-- per finished check, so an older timer cannot end a newer check.
local decay

function GroupIcons.Applies(scope)
    return Settings.AppliesTo(Settings.Get("groupLeader"), scope)
end

function GroupIcons.Build(frame)
    if not (GroupIcons.Applies(frame.key) or frame.iconPoint) then return end
    local holder = CreateFrame("Frame", nil, frame)
    local g = { holder = holder }
    for _, name in ipairs({ "leader", "ready", "rez", "summon", "phase", "role" }) do
        g[name] = holder:CreateTexture(nil, "OVERLAY")
        g[name]:Hide()
    end
    g.rez:SetAtlas(GroupIcons.REZ_ATLAS)
    g.phase:SetAtlas(GroupIcons.PHASE_ATLAS)
    if frame.iconPoint then
        g.looter = holder:CreateTexture(nil, "OVERLAY")
        g.looter:SetTexture(GroupIcons.LOOTER_TEXTURE)
        g.looter:Hide()
    end
    frame.groupIcons = g
end

local function want(frame, key) return Config.Get(frame.key, key) end

-- The role on the portrait instead of in the row (groupRolePortrait).
local function roleOnPortrait(frame)
    return want(frame, "groupRolePortrait") and want(frame, "portraitMode") ~= "OFF"
end

-- The slots switched on, left to right.
local function slots(frame)
    local g, list = frame.groupIcons, {}
    if want(frame, "groupLeader") then list[#list + 1] = g.leader end
    if want(frame, "groupReadyCheck") then list[#list + 1] = g.ready end
    if want(frame, "groupResurrect") then list[#list + 1] = g.rez end
    if want(frame, "groupSummon") then list[#list + 1] = g.summon end
    if want(frame, "groupPhase") then list[#list + 1] = g.phase end
    if want(frame, "groupRole") and not roleOnPortrait(frame) then list[#list + 1] = g.role end
    return list
end

-- The icons that show, side by side in the holder.
local function arrange(g, shown)
    if not g.size then return end
    local free = g.holder:GetWidth() - Layout.IconRowWidth(#shown, g.size, g.gap)
    local start = Pixel.Snap(free * Layout.IconRowJustify(g.point))
    for i = 1, #shown do
        local icon = shown[i]
        if icon then -- false: a kept empty slot
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", g.holder, "TOPLEFT", start + (i - 1) * (g.size + g.gap), 0)
            icon:SetSize(g.size, g.size)
        end
    end
end

-- Any time, combat included: which icons show, from what the frame knows
-- (g.leaderKind, g.readyStatus, g.hasRez, g.isLooter, g.role) or its test mode
-- sample. A raid cell's icons keep their own places.
function GroupIcons.Refresh(frame)
    local g = frame.groupIcons
    if not g then return end
    local live = { leader = g.leaderKind, ready = g.readyStatus, rez = g.hasRez, looter = g.isLooter,
        role = g.roleKind, summon = g.summonKind, phase = g.inOtherPhase }
    local data = g.preview or live
    local kind = want(frame, "groupLeader") and data.leader or nil
    local status = want(frame, "groupReadyCheck") and data.ready or nil
    local rez = want(frame, "groupResurrect") and data.rez == true
    local summon = want(frame, "groupSummon") and GroupIcons.SUMMON[data.summon or ""] or nil
    local phase = want(frame, "groupPhase") and data.phase == true
    local role = want(frame, "groupRole") and GroupIcons.ROLE_TEXTURE[data.role or ""] or nil
    if kind then g.leader:SetTexture(GroupIcons.LEADER[kind]) end
    if role then g.role:SetTexture(role) end
    g.role:SetShown(role ~= nil)
    if status then g.ready:SetAtlas(GroupIcons.READY[status]) end
    g.leader:SetShown(kind ~= nil)
    g.ready:SetShown(status ~= nil)
    g.rez:SetShown(rez)
    if summon then g.summon:SetAtlas(summon) end
    g.summon:SetShown(summon ~= nil)
    g.phase:SetShown(phase)
    if g.looter then g.looter:SetShown(data.looter == true and frame.iconPoint(frame, "looter") ~= nil) end
    if frame.iconPoint then return end
    -- Crown, then role, at the anchor's end; with a role the crown's slot is
    -- kept even when empty, so members' roles stay in one column.
    local roleLast = Layout.IconRowJustify(g.point or "LEFT") == 1
    local rowRole = g.role:IsShown() and not roleOnPortrait(frame)
    local head = {}
    if g.leader:IsShown() then head[1] = g.leader elseif rowRole and want(frame, "groupLeader") then head[1] = false end
    if rowRole then head[#head + 1] = g.role end
    local rest = {}
    for _, icon in ipairs({ g.ready, g.rez, g.summon, g.phase }) do
        if icon:IsShown() then rest[#rest + 1] = icon end
    end
    local shown = {}
    local first, second = roleLast and rest or head, roleLast and head or rest
    if roleLast then head[1], head[#head] = head[#head], head[1] end
    for i = 1, #first do shown[#shown + 1] = first[i] end
    for i = 1, #second do shown[#shown + 1] = second[i] end
    arrange(g, shown)
end

-- A raid cell: each icon at its own point on the cell.
local function placeOwn(frame, g)
    for _, name in ipairs(GroupIcons.OWN_POINTS) do
        local icon = g[name]
        local point, x, y = frame.iconPoint(frame, name)
        if icon and point then
            icon:ClearAllPoints()
            icon:SetPoint(point, frame, point, Pixel.Snap(x), Pixel.Snap(y))
            icon:SetSize(g.size, g.size)
        end
    end
end

-- The role's point on the portrait for AUTO: the strip's left end, or the
-- square's bottom corner towards the bars; clear of the portrait aura
-- (centre) and the elite and class badges (top corners).
GroupIcons.ROLE_AUTO_POINT = { TOP = "LEFT", LEFT = "BOTTOMRIGHT", RIGHT = "BOTTOMLEFT" }

-- Its point on the portrait, ROLE_INSET in from the edges that point
-- touches, plus the own offset. Above a 3D model: the holder's level is.
local function placeRole(frame, g)
    local point = want(frame, "groupRolePortraitPoint")
    if point == "AUTO" then point = GroupIcons.ROLE_AUTO_POINT[want(frame, "portraitMode")] end
    local inset = Pixel.Snap(ROLE_INSET)
    local x = point:find("LEFT") and inset or point:find("RIGHT") and -inset or 0
    local y = point:find("BOTTOM") and inset or point:find("TOP") and -inset or 0
    local size = want(frame, "groupRoleSize")
    size = size > 0 and Pixel.Snap(size, nil, 1) or g.size
    g.role:ClearAllPoints()
    g.role:SetPoint(point, frame.portraitBg, point, x + Pixel.Snap(want(frame, "groupRoleX")),
        y + Pixel.Snap(want(frame, "groupRoleY")))
    g.role:SetSize(size, size)
end

-- Plain frames only: allowed in combat (party buttons restyle then too).
function GroupIcons.Style(frame)
    local g, scope = frame.groupIcons, frame.key
    if not g then return end
    local size = Pixel.Snap(Config.Get(scope, "groupIconSize"), nil, 1)
    g.size, g.gap, g.point = size, Pixel.Snap(GAP), Config.Get(scope, "groupIconPoint")
    if frame.iconPoint then
        g.holder:SetFrameLevel(frame:GetFrameLevel() + GroupIcons.LEVELS)
        g.holder:ClearAllPoints()
        g.holder:SetAllPoints(frame)
        g.holder:Show()
        placeOwn(frame, g)
        GroupIcons.Refresh(frame)
        return
    end
    local n = #slots(frame)
    g.holder:SetFrameLevel(frame:GetFrameLevel() + GroupIcons.LEVELS)
    g.holder:SetSize(math.max(1, Layout.IconRowWidth(n, size, g.gap)), size)
    g.holder:ClearAllPoints()
    g.holder:SetPoint(g.point, frame, Config.Get(scope, "groupIconFramePoint"),
        Pixel.Snap(Config.Get(scope, "groupIconX")), Pixel.Snap(Config.Get(scope, "groupIconY")))
    local portraitRole = want(frame, "groupRole") and roleOnPortrait(frame)
    if portraitRole then placeRole(frame, g) end
    g.holder:SetShown(n > 0 or portraitRole)
    GroupIcons.Refresh(frame)
end

-- The assigned role ("TANK", "HEALER", "DAMAGER", "NONE"), or nil when it
-- cannot be read (secret, refused). Raid cells ask too (Raid/Cell.lua).
function GroupIcons.UnitRole(unit)
    return Secrets.Plain(Secrets.Call(UnitGroupRolesAssigned, unit), "string")
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

-- Whether unit is the master looter. C_PartyInfo.GetLootMethod (not
-- secret) names them by raid index in a raid, by party index in a party
-- (0: you, as the old GetLootMethod did; not documented in this build).
local function isLooter(unit)
    local info = C_PartyInfo
    if not (info and info.GetLootMethod and Enum.LootMethod) then return false end
    local ok, method, partyID, raidID = pcall(info.GetLootMethod)
    if not ok or method ~= Enum.LootMethod.Masterlooter then return false end
    local token
    if IsInRaid() then
        token = type(raidID) == "number" and ("raid" .. raidID) or nil
    elseif type(partyID) == "number" then
        token = partyID == 0 and "player" or ("party" .. partyID)
    end
    return token ~= nil and Secrets.Bool(UnitIsUnit, unit, token) == true
end

-- "ready", "notready", "waiting" or nil. Offline members show none, as
-- Blizzard's party frames (PartyMemberFrameMixin:UpdateReadyCheck).
local function readyStatus(unit)
    if Secrets.Bool(UnitIsConnected, unit) == false then return nil end
    local status = Secrets.Plain(Secrets.Call(GetReadyCheckStatus, unit), "string")
    if status and GroupIcons.READY[status] then return status end
    return nil
end

-- "pending", "accepted", "declined" or nil.
local function summonKind(unit)
    if not (C_IncomingSummon and Enum.SummonStatus) then return nil end
    local status = Secrets.Plain(Secrets.Call(C_IncomingSummon.IncomingSummonStatus, unit), "number")
    local kinds = Enum.SummonStatus
    if status == kinds.Pending then return "pending" end
    if status == kinds.Accepted then return "accepted" end
    if status == kinds.Declined then return "declined" end
    return nil
end

-- Any phase reason counts; a member far away shows none, as Blizzard's.
local function inOtherPhase(unit)
    if Secrets.Call(UnitPhaseReason, unit) == nil then return false end
    local distance = Secrets.Number(Secrets.Call(UnitDistanceSquared, unit))
    return not distance or distance < GroupIcons.PHASE_DISTANCE_SQUARED
end

function GroupIcons.Update(frame)
    local g = frame.groupIcons
    if not g or g.preview then return end
    local unit = frame.unit
    -- Another unit: its ready check result is not this one's.
    if unit ~= g.unit then
        g.unit, g.readyStatus = unit, nil
    end
    g.leaderKind = leaderKind(unit)
    -- While a finished check decays its result stays as it was.
    if not decay then g.readyStatus = readyStatus(unit) end
    g.hasRez = Secrets.Bool(UnitHasIncomingResurrection, unit) == true
    if g.looter then g.isLooter = isLooter(unit) end
    g.roleKind = GroupIcons.UnitRole(unit)
    g.summonKind = summonKind(unit)
    g.inOtherPhase = inOtherPhase(unit)
    GroupIcons.Refresh(frame)
end

-- A raid test cell's own (frame.sample.groupIcons), the pretend party's,
-- or the frame's.
local function sample(frame)
    if frame.sample then return frame.sample.groupIcons end
    if frame.sampleIndex then return GroupIcons.PARTY_SAMPLES[frame.sampleIndex] end
    return GroupIcons.SAMPLES[frame.key]
end

-- Test mode's role of frame, or nil (Elements/Texts.lua's role tag).
function GroupIcons.SampleRole(frame)
    local s = sample(frame)
    return s and s.role
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
ns.On("PARTY_LOOT_METHOD_CHANGED", updateAll)
ns.On("PLAYER_ROLES_ASSIGNED", updateAll)
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
