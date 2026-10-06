local _, ns = ...

-- Which size profile is active: 10, 20 or 40. A fixed sizeMode wins.
-- AUTO: inside a raid instance its size (GetInstanceInfo's maxPlayers,
-- never secret), so a raid that is not full yet already gets its layout;
-- elsewhere the member count, and in a raid the highest occupied group
-- as well (five to a group), so nobody sits in a group the profile does
-- not show. A 5-player group is 10. RAID_SIZE_CHANGED (size) fires when
-- it changes.
local Size = {}
ns.RaidSize = Size

local function bucket(n)
    if n <= 10 then return 10 elseif n <= 20 then return 20 end
    return 40
end

-- Pure. mode: the sizeMode setting; instanceType and maxPlayers as
-- GetInstanceInfo returns them; members: GetNumGroupMembers();
-- highestGroup: the highest occupied raid group, nil when unknown.
function Size.Detect(mode, instanceType, maxPlayers, members, highestGroup)
    if mode ~= "AUTO" then return tonumber(mode) end
    if instanceType == "raid" and type(maxPlayers) == "number" and maxPlayers > 0 then
        return bucket(maxPlayers)
    end
    return bucket(math.max(members or 0, 5 * (highestGroup or 0)))
end

-- The highest raid group anyone is in, nil outside a raid or when no
-- group can be read (secret values are skipped).
function Size.HighestGroup(members)
    if not IsInRaid() then return nil end
    local highest
    for i = 1, members do
        local ok, _, _, subgroup = pcall(GetRaidRosterInfo, i)
        if ok and not ns.Secrets.IsSecret(subgroup) and type(subgroup) == "number"
            and (highest == nil or subgroup > highest) then
            highest = subgroup
        end
    end
    return highest
end

local current

-- The active size; nil before the raid profile is attached.
function Size.Current()
    return current
end

function Size.Update()
    if not ns.RaidConfig.Profile() then return nil end
    local _, instanceType, _, _, maxPlayers = GetInstanceInfo()
    local members = GetNumGroupMembers()
    local size = Size.Detect(ns.RaidConfig.Get("general", "sizeMode"), instanceType, maxPlayers, members,
        Size.HighestGroup(members))
    if size ~= current then
        current = size
        ns.Fire("RAID_SIZE_CHANGED", size)
    end
    return size
end

local EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_DIFFICULTY_CHANGED",
    "INSTANCE_GROUP_SIZE_CHANGED", "GROUP_ROSTER_UPDATE" }
for _, event in ipairs(EVENTS) do
    ns.On(event, function() Size.Update() end)
end

-- sizeMode changed, or everything at once (a reset or an import).
ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if scope == nil or (scope == "general" and (key == nil or key == "sizeMode")) then Size.Update() end
end)
