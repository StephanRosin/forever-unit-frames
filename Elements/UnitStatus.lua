local _, ns = ...

-- Dead, ghost and offline units. The frame greys out: health and power
-- bars take a grey colour, a 2D portrait loses its colour (as Blizzard's
-- party frames: SetDesaturated, PartyMemberFrameMixin:UpdateOnlineStatus),
-- and the health bar says "Dead", "Ghost" or "Offline" instead of its
-- values. An offline member's bar is full, as Blizzard's.
--
-- UnitIsConnected, UnitIsGhost and UnitIsDeadOrGhost are not documented
-- as secret; they are still read through Secrets.Bool, and a secret or
-- refused answer counts as alive and online. Only players can be offline.
--
-- Health (Elements/Health.lua), Power and Texts ask UnitStatus.Of when
-- they draw. This element is registered after them, so on the events they
-- share it runs last; on the events only it listens to, it redraws them
-- itself when the state changed.
local UnitStatus = { name = "UnitStatus", unitEvents = { "UNIT_HEALTH", "UNIT_CONNECTION" } }
ns.UnitStatus = UnitStatus

local Secrets = ns.Secrets

UnitStatus.GREY = { 0.5, 0.5, 0.5 }
-- Test mode: pretend party member 2 is dead, 3 offline.
UnitStatus.PARTY_SAMPLES = { [2] = "DEAD", [3] = "OFFLINE" }

-- "OFFLINE", "GHOST", "DEAD" or nil. In test mode the frame's sample.
function UnitStatus.Of(frame)
    local sample = frame.statusSample
    if sample ~= nil then return sample or nil end
    local unit = frame.unit
    if not unit then return nil end
    if Secrets.Bool(UnitIsConnected, unit) == false and Secrets.Bool(UnitIsPlayer, unit) then return "OFFLINE" end
    if Secrets.Bool(UnitIsGhost, unit) then return "GHOST" end
    if Secrets.Bool(UnitIsDeadOrGhost, unit) then return "DEAD" end
    return nil
end

-- The word for a status ("Dead", ...), or nil.
function UnitStatus.Word(status)
    if not status then return nil end
    return ns.L["STATUS_" .. status]
end

function UnitStatus.Build() end

function UnitStatus.Style(frame)
    if frame.portrait2D then frame.portrait2D:SetDesaturated(frame.unitStatus ~= nil) end
end

local function redraw(frame, status)
    frame.unitStatus = status
    if frame.portrait2D then frame.portrait2D:SetDesaturated(status ~= nil) end
    if not (frame.unit and UnitExists(frame.unit)) then return end
    ns.Health.Update(frame)
    if frame.power then ns.Power.Update(frame) end
    ns.Texts.Update(frame)
end

function UnitStatus.Update(frame)
    local status = UnitStatus.Of(frame)
    if status == frame.unitStatus then return end
    redraw(frame, status)
end

-- In test mode statusSample holds the frame's sample, false for none.
function UnitStatus.Preview(frame, on)
    if on then
        frame.statusSample = frame.sampleIndex and UnitStatus.PARTY_SAMPLES[frame.sampleIndex] or false
    else
        frame.statusSample = nil
    end
    redraw(frame, UnitStatus.Of(frame))
end

-- The player's own death, release and return: every frame looks again
-- (the player may show on several).
local function updateAll(event) ns.Units.UpdateElement(UnitStatus, event) end
ns.On("PLAYER_DEAD", updateAll)
ns.On("PLAYER_ALIVE", updateAll)
ns.On("PLAYER_UNGHOST", updateAll)

ns.RegisterElement(UnitStatus)
