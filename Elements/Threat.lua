local _, ns = ...

-- Threat glow: a soft band in the threat colour around the unit, as
-- Blizzard's threat indicator (UnitFrame_UpdateThreatIndicator,
-- Blizzard_UnitFrame/Mainline/UnitFrame.lua): shown for a status above 0,
-- coloured by GetThreatStatusColor, hidden while the unit is dead.
-- * Player, party members and pets: the unit's own situation,
--   UnitThreatSituation(unit) (someone has it on their threat list).
-- * Target, focus, target of target: your threat on it,
--   UnitThreatSituation("player", unit) (Blizzard's feedback unit).
-- UnitThreatSituation is SecretWhenUnitThreatStateRestricted; per its
-- documentation, one token or the player against another unit is
-- generally not secret. A secret status cannot be compared or coloured
-- (GetThreatStatusColor takes secrets only from untainted code): no glow.
--
-- The band is the drop shadow's (Border.DrawGlow), around the frame and
-- around the unit box with a docked castbar; each lies in the matching
-- ring holder (Elements/Shape.lua), whose own switch shows one of them.
-- Plain textures on plain frames: colour and visibility change in combat.
local Threat = { name = "Threat", unitEvents = { "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE" } }
ns.Threat = Threat

local Config, Secrets, Pixel, Border = ns.Config, ns.Secrets, ns.Pixel, ns.Border

-- The band's width.
Threat.SIZE = 6
-- Frames that show your threat on their unit; the rest show the unit's own.
Threat.ON_UNIT = { target = true, focus = true, targettarget = true }
-- Blizzard's default threat colours, for a client without
-- GetThreatStatusColor.
Threat.COLORS = { { 1, 1, 0.47 }, { 1, 0.6, 0 }, { 1, 0, 0 } }
-- Test mode: pretend party member 4 has aggro.
Threat.PARTY_SAMPLES = { [4] = 3 }

function Threat.Build(frame)
    local holders = {}
    for name, ring in pairs({ frame = frame.frameRing, block = frame.blockRing }) do
        local holder = CreateFrame("Frame", nil, ring)
        holder:SetAllPoints(ring)
        holder:Hide()
        holders[name] = holder
    end
    frame.threat = holders
end

function Threat.Style(frame)
    local t, scope = frame.threat, frame.key
    local size = Pixel.Snap(Threat.SIZE, nil, 1)
    for _, holder in pairs({ t.frame, t.block }) do
        Border.DrawGlow(holder, scope, holder, frame.shapeRadius, size)
    end
    Threat.Refresh(frame)
end

-- The status to show (1..3), or nil.
local function read(frame)
    local unit = frame.unit
    local ok, status
    if Threat.ON_UNIT[frame.key] then
        ok, status = pcall(UnitThreatSituation, "player", unit)
    else
        ok, status = pcall(UnitThreatSituation, unit)
    end
    status = ok and Secrets.Number(status) or nil
    if not status or status <= 0 then return nil end
    if Secrets.Bool(UnitIsDeadOrGhost, unit) then return nil end
    return status
end

local function colorOf(status)
    local ok, r, g, b = pcall(GetThreatStatusColor, status)
    if ok and type(r) == "number" then return r, g, b end
    local c = Threat.COLORS[math.min(status, #Threat.COLORS)]
    return c[1], c[2], c[3]
end

-- Shows t.status (or the test mode sample) in the frame's setting.
function Threat.Refresh(frame)
    local t = frame.threat
    local status = t.sample
    if status == nil then status = t.status end
    local on = status and Config.Get(frame.key, "threatGlow") or false
    if on then
        local r, g, b = colorOf(status)
        Border.PaintGlow(t.frame, r, g, b, 1)
        Border.PaintGlow(t.block, r, g, b, 1)
    end
    t.frame:SetShown(on)
    t.block:SetShown(on)
end

function Threat.Update(frame)
    local t = frame.threat
    if not t or t.sample ~= nil then return end
    t.status = read(frame)
    Threat.Refresh(frame)
end

-- In test mode t.sample holds the frame's sample status, false for none.
function Threat.Preview(frame, on)
    local t = frame.threat
    if not t then return end
    if on then
        t.sample = frame.sampleIndex and Threat.PARTY_SAMPLES[frame.sampleIndex] or false
    else
        t.sample = nil
        t.status = frame.unit and UnitExists(frame.unit) and read(frame) or nil
    end
    Threat.Refresh(frame)
end

-- The frames showing your threat on their unit follow your own
-- situation; after combat every frame looks again.
local function updateOnUnit(event)
    for key in pairs(Threat.ON_UNIT) do
        local frame = ns.Frames[key]
        if frame and frame.unit and UnitExists(frame.unit) then Threat.Update(frame, event) end
    end
end
local listener = CreateFrame("Frame")
listener:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
listener:SetScript("OnEvent", function(_, event) updateOnUnit(event) end)

ns.On("PLAYER_REGEN_ENABLED", function(event) ns.Units.UpdateElement(Threat, event) end)

ns.RegisterElement(Threat)
