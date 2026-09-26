local _, ns = ...

-- Range fading: party members (and their pets), the target, the focus and
-- the pet are drawn at a lower opacity while out of range.
--
-- Where the range comes from:
-- * Group members (party tokens, or a target or focus in the group):
--   UnitInRange, as Blizzard's raid frames (CompactUnitFrame_UpdateInRange:
--   out of range = checked and not in range). Both answers are documented
--   with SecretReturns. A secret "in range" goes untouched to
--   SetAlphaFromBoolean, which takes secret booleans from tainted code
--   (SimpleFrameAPIDocumentation.lua: AllowedWhenTainted); nothing is
--   compared. "Not checked", or a secret "checked", means unknown: full
--   opacity.
-- * Everyone else (an enemy target, your pet): CheckInteractDistance(unit,
--   4), the follow distance (about 28 yards), which is why fading is off by
--   default on the target and focus. Not documented as secret or
--   restricted; only a plain true or false counts, anything else is full
--   opacity. Should the client ever refuse or block the call (an error, or
--   ADDON_ACTION_BLOCKED / _FORBIDDEN naming it), it is not asked again
--   this session.
-- * Yourself: always in range.
--
-- The opacity is the unit frame's own alpha. SetAlpha and
-- SetAlphaFromBoolean are not protected functions (unlike SetShown), so
-- the secure frames may fade in combat; aura containers and the other
-- children fade with them, as Blizzard's raid frames do.
--
-- The client sends UNIT_IN_RANGE_UPDATE, but only for group members; one
-- light timer (POLL seconds) checks every shown frame that fades instead,
-- and a whole-frame update (a new target, a party slot) checks at once.
-- The timer only runs while some frame has fading switched on.
local Range = { name = "Range" }
ns.Range = Range

local Config, Secrets, Settings = ns.Config, ns.Secrets, ns.Settings

Range.POLL = 0.2
-- CheckInteractDistance's follow distance.
Range.INTERACT_INDEX = 4
-- Test mode: pretend party member 4 is out of range.
Range.PARTY_SAMPLES = { [4] = true }

-- Frames that may fade: the setting's frames, and the party pets, whose
-- derived scope follows the party's.
local function applies(frame)
    return Settings.AppliesTo(Settings.Get("rangeFade"), frame.key) or frame.key == ns.Party.PET_KEY
end

local function enabled(frame)
    return applies(frame) and Config.Get(frame.key, "rangeFade")
end

local function outAlpha(frame)
    return Config.Get(frame.key, "rangeAlpha") / 100
end

local function groupToken(unit)
    return unit:match("^party%d$") ~= nil or unit:match("^partypet%d$") ~= nil or unit:match("^raid") ~= nil
end

-- A plain or secret boolean ("in range"), or nil when unknown.
local function groupRange(unit)
    local ok, inRange, checked = pcall(UnitInRange, unit)
    if not ok or Secrets.IsSecret(checked) or checked ~= true then return nil end
    return inRange
end

-- Set once CheckInteractDistance was refused or blocked.
local interactBroken = false

-- A plain boolean, or nil when unknown.
local function interactRange(unit)
    if interactBroken then return nil end
    local ok, near = pcall(CheckInteractDistance, unit, Range.INTERACT_INDEX)
    if not ok then
        interactBroken = true
        return nil
    end
    if Secrets.IsSecret(near) or type(near) ~= "boolean" then return nil end
    return near
end

-- A plain or secret boolean, or nil when unknown.
function Range.InRange(unit)
    if unit == "player" or Secrets.Bool(UnitIsUnit, unit, "player") then return true end
    if groupToken(unit) or Secrets.Bool(UnitInParty, unit) then return groupRange(unit) end
    return interactRange(unit)
end

local function blocked(_, addon, fn)
    if addon == ns.name and type(fn) == "string" and fn:find("CheckInteractDistance", 1, true) then
        interactBroken = true
    end
end
ns.On("ADDON_ACTION_BLOCKED", blocked)
ns.On("ADDON_ACTION_FORBIDDEN", blocked)

-- Opacity from a plain or secret boolean; nil is full opacity.
local function apply(frame, inRange)
    if type(inRange) == "nil" then
        frame:SetAlpha(1)
        return
    end
    if pcall(frame.SetAlphaFromBoolean, frame, inRange, 1, outAlpha(frame)) then return end
    -- A client without it: only a plain answer can be used.
    if Secrets.IsSecret(inRange) then frame:SetAlpha(1) else frame:SetAlpha(inRange and 1 or outAlpha(frame)) end
end

local function check(frame)
    if frame.rangeSample ~= nil then
        apply(frame, not frame.rangeSample)
        return
    end
    if not enabled(frame) or not (frame.unit and UnitExists(frame.unit)) then
        frame:SetAlpha(1)
        return
    end
    apply(frame, Range.InRange(frame.unit))
end

function Range.Build() end

-- Whether any frame has fading on (the party's setting covers its pets).
local SCOPES = { "party", "target", "focus", "pet" }
local function anyEnabled()
    for _, scope in ipairs(SCOPES) do
        if Config.Get(scope, "rangeFade") then return true end
    end
    return false
end

-- The timer runs only while it has something to do.
local function syncDriver()
    Range.driver:SetShown(anyEnabled())
end

function Range.Style(frame)
    syncDriver()
    if applies(frame) then check(frame) end
end

function Range.Update(frame)
    if applies(frame) then check(frame) end
end

-- In test mode rangeSample is true for a member shown out of range,
-- false for the others; nil outside test mode.
function Range.Preview(frame, on)
    if not applies(frame) then return end
    if on then
        frame.rangeSample = (frame.sampleIndex and Range.PARTY_SAMPLES[frame.sampleIndex]) and true or false
        check(frame)
        return
    end
    frame.rangeSample = nil
    check(frame)
end

-- The poll: every shown frame that fades and shows a live unit.
local function poll()
    ns.Units.ForEachFrame(function(frame)
        if frame.rangeSample == nil and frame:IsShown() and enabled(frame) and frame.unit
            and UnitExists(frame.unit) then
            check(frame)
        end
    end)
end

local driver, elapsed = CreateFrame("Frame"), 0
Range.driver = driver
driver:Hide()
driver:SetScript("OnUpdate", function(_, seconds)
    elapsed = elapsed + seconds
    if elapsed < Range.POLL then return end
    elapsed = 0
    poll()
end)

ns.RegisterElement(Range)
