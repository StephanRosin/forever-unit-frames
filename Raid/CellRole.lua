local _, ns = ...

-- The assigned role on a raid cell, in our round role badges
-- (Elements/GroupIcons.lua: ROLE_TEXTURE, shared with the unit
-- frames' role icon): tank and healer, damage too when asked
-- (roleIconDamager). At its own point (Raid/Cell.lua: Cell.IconPoint),
-- the profile's icon size. UnitGroupRolesAssigned is secret while the
-- unit's identity is restricted: nothing shows then. A texture on a
-- plain holder, so it may change in combat; test mode's pretend members
-- show their own role.
local Role = { name = "RaidRole" }
ns.RaidRole = Role

local Cell, Pixel = ns.RaidCell, ns.Pixel
local get = Cell.Get

Role.TEXTURE = ns.GroupIcons.ROLE_TEXTURE
-- With the other icons (Elements/GroupIcons.lua).
Role.LEVELS = 18

function Role.Build(frame)
    if not Cell.Is(frame) then return end
    local holder = CreateFrame("Frame", nil, frame)
    local icon = holder:CreateTexture(nil, "OVERLAY")
    icon:Hide()
    frame.raidRole = { holder = holder, icon = icon }
end

-- Any time: the icon for r.role, or none.
local function refresh(frame)
    local r = frame.raidRole
    local texture = Role.TEXTURE[r.role or ""]
    local shown = texture ~= nil and Cell.IconPoint(frame, "role") ~= nil
        and (r.role ~= "DAMAGER" or get("roleIconDamager") == true)
    if shown then r.icon:SetTexture(texture) end
    r.icon:SetShown(shown)
end

function Role.Style(frame)
    local r = frame.raidRole
    if not r then return end
    r.holder:SetFrameLevel(frame:GetFrameLevel() + Role.LEVELS)
    r.holder:ClearAllPoints()
    r.holder:SetAllPoints(frame)
    local point, x, y = Cell.IconPoint(frame, "role")
    if point then
        local size = Pixel.Snap(get("iconSize"), nil, 1)
        r.icon:ClearAllPoints()
        r.icon:SetPoint(point, frame, point, Pixel.Snap(x), Pixel.Snap(y))
        r.icon:SetSize(size, size)
    end
    refresh(frame)
end

function Role.Update(frame)
    local r = frame.raidRole
    if not r or r.preview then return end
    r.role = Cell.Role(frame)
    refresh(frame)
end

function Role.Preview(frame, on)
    local r = frame.raidRole
    if not r then return end
    r.preview = on or nil
    r.role = Cell.Role(frame)
    refresh(frame)
end

ns.On("PLAYER_ROLES_ASSIGNED", function(event) ns.Units.UpdateElement(Role, event) end)

ns.RegisterElement(Role)
