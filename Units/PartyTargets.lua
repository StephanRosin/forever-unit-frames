local _, ns = ...

-- Party targets: beside each member a small frame with what that member
-- has targeted (party1target ...). Off by default.
--
-- The button is a child in the member's XML template (Units/Party.xml):
-- useparent-unit and unitsuffix "target" let the secure code resolve its
-- unit from the member's (SecureButton_GetUnit), for clicks and for the
-- unit watch that shows and hides it, in combat too, when the header hands
-- members new units. Lua only keeps its own copy of the unit for drawing.
--
-- These units get no events of their own (health, power ...): shown
-- buttons are refreshed on a timer, like the target of target, and at
-- once when a member changes target (UNIT_TARGET).
--
-- Settings: the party's look through a derived scope, without what a small
-- frame cannot hold (auras, castbar, portrait, power, title row); size,
-- side and offset are party settings.
local Targets = {}
ns.PartyTargets = Targets

local Config, Single, Pixel = ns.Config, ns.Single, ns.Pixel
local Party = ns.Party

Targets.KEY = "partytarget"
Targets.POLL = 0.2
Targets.buttons = {}
Targets.fakes = {}

local function get(key) return Config.Get(Party.KEY, key) end

local FIXED = {
    titlePercent = 0, powerEnabled = false, castbarEnabled = false, titleClassIcon = false,
    portraitMode = "OFF", eliteMarker = false, combatFeedback = false, textHealthLeft = "NAME",
    textHealthRight = "PERCENT", buffsEnabled = false, debuffsEnabled = false, threatGlow = false,
    dispelHighlight = false, groupLeader = false, groupReadyCheck = false, groupResurrect = false,
}

local function resolve(key)
    local fixed = FIXED[key]
    if fixed ~= nil then return fixed end
    if key == "width" then return get("partyTargetWidth") end
    if key == "height" then return get("partyTargetHeight") end
    -- A marker no taller than the frame.
    if key == "raidMarkerSize" then return math.min(get("raidMarkerSize"), get("partyTargetHeight")) end
    return nil
end
Config.Derive(Targets.KEY, Party.KEY, resolve)

function Targets.Enabled()
    return ns.FrameEnabled(Party.KEY) and get("partyTargets")
end

-- Where the target sits next to its member: points and offset, border to
-- border (both borders' room); above or below, a castbar docked on that
-- side is passed too. X / Y (place) move it from there.
function Targets.Anchor()
    local side = get("partyTargetSide")
    local gap = ns.Border.Extent(Party.KEY) + ns.Border.Extent(Targets.KEY)
    local depth = ns.Castbar.DockedDepth(Party.KEY)
    local dock = depth > 0 and ns.Castbar.Placement(Party.KEY) or nil
    if side == "LEFT" then return "TOPRIGHT", "TOPLEFT", -gap, 0 end
    if side == "ABOVE" then
        return "BOTTOMLEFT", "TOPLEFT", 0, gap + (dock == "ABOVE" and depth - ns.Border.Extent(Party.KEY) or 0)
    end
    if side == "BELOW" then
        return "TOPLEFT", "BOTTOMLEFT", 0, -(gap + (dock == "BELOW" and depth - ns.Border.Extent(Party.KEY) or 0))
    end
    return "TOPLEFT", "TOPRIGHT", gap, 0
end

-- Out of combat: size and place (protected on a secure button).
local function place(button, member)
    local point, relPoint, x, y = Targets.Anchor()
    x, y = x + Pixel.Snap(get("partyTargetX")), y + Pixel.Snap(get("partyTargetY"))
    button:SetSize(Single.Size(Targets.KEY))
    button:ClearAllPoints()
    button:SetPoint(point, member, relPoint, x, y)
end

local function style(button)
    Single.StyleContent(button)
    Single.UpdateAll(button)
end

-- The member's unit changed (header, in or out of combat): the target's
-- unit for drawing. The secure side resolves it by itself.
function Targets.OnMemberUnit(member, unit)
    local button = member.targetButton
    if not button then return end
    if unit == "player" then
        button.unit = unit and "target"
    else
        button.unit = unit and (unit .. "target") or nil
    end
    if button.unit then Single.UpdateAll(button) end
end

-- XML OnLoad of the child, before its member's.
function Targets.InitButton(button)
    button.key = Targets.KEY
    for _, el in ipairs(ns.Elements) do el.Build(button) end
    Targets.buttons[#Targets.buttons + 1] = button
    ns.Units.EnableTooltip(button)
    ns.Units.EnableClickCast(button)
    Single.StyleContent(button)
    -- Made in combat (someone joined): placed and watched after combat.
    if InCombatLockdown() then ns.AfterCombat("partyStyle", Party.StyleAll) end
end

-- Shown or not: the unit watch shows it while the unit exists. Out of
-- combat only.
local function watch(button, on)
    if on then
        RegisterUnitWatch(button)
    else
        UnregisterUnitWatch(button)
        button:Hide()
    end
end

-- A pretend target beside a pretend member (test mode): a secure button on
-- the player, made once, out of combat.
local function fakeButton(i, member)
    local button = Targets.fakes[i]
    if not button then
        button = CreateFrame("Button", "ForeverUnitFramesPartyTargetTest" .. i, member, "SecureUnitButtonTemplate")
        ns.Units.EnableTooltip(button)
        button.key = Targets.KEY
        button.pretend = true
        button:SetAttribute("*type1", "target")
        button:SetAttribute("*type2", "togglemenu")
        button:RegisterForClicks("AnyUp")
        for _, el in ipairs(ns.Elements) do el.Build(button) end
        Targets.fakes[i] = button
    end
    return button
end

local function showFakes(on)
    for i, member in ipairs(Party.fakes) do
        local shown = on and member:IsShown()
        local button = (shown or Targets.fakes[i]) and fakeButton(i, member)
        if button then
            if shown then
                Single.SetUnit(button, "player")
                place(button, member)
                style(button)
                Single.Preview(button, true)
                button:Show()
            else
                button:Hide()
                Single.Preview(button, false)
            end
        end
    end
end

-- Out of combat only (Party.StyleAll): place, size, style and watch.
function Targets.StyleAll(testing)
    local on = Targets.Enabled()
    for _, button in ipairs(Targets.buttons) do
        local member = button:GetParent()
        place(button, member)
        style(button)
        watch(button, on and not testing)
    end
    showFakes(on and testing)
end

-- Shown buttons refresh on a timer; a member's new target at once.
function Targets.Tick()
    for _, button in ipairs(Targets.buttons) do
        if button:IsShown() then Single.UpdateAll(button, Single.POLL) end
    end
end

local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < Targets.POLL then return end
    elapsed = 0
    Targets.Tick()
end)
driver:RegisterEvent("UNIT_TARGET")
driver:SetScript("OnEvent", function(_, event, unit)
    for _, button in ipairs(Targets.buttons) do
        local member = button:GetParent()
        if member.unit == unit and button:IsShown() then Single.UpdateAll(button, event) end
    end
end)

-- Called from Units/Party.xml; not part of the public API.
ns.api.PartyTargetOnLoad = Targets.InitButton
