local _, ns = ...

-- Threat bar (player frame only): one more row of the unit's block, below
-- the frame and below a castbar docked there, inside the unit's border and
-- rounded with it (Elements/Shape.lua).
--
-- It shows your threat on your target (a healer without a hostile target:
-- on the target's target):
-- * Tank: your threat on the left, your lead over the next one on the
--   right; green while that one is far off, yellow once they reach the
--   warning share of your threat, red when someone else has it, purple
--   when that someone is another tank.
-- * Everyone else: your share of the threat needed to pull (the client's
--   scaled percentage, which counts the 110 % / 130 % rule) on the left,
--   the gap to whoever has aggro on the right; green, yellow from the
--   warning share on, red while you have aggro.
--
-- Only the target is asked: the client keeps the threat numbers of the
-- target readable in dungeons too, where those of other nameplates turn
-- secret. A secret answer is shown as the plain status colour through a
-- colour curve where the client has one, otherwise as an empty bar.
--
-- The row stays in place while the setting is on, empty when there is no
-- threat to show: nothing is anchored in combat. For the same reason a
-- castbar docked on this frame then keeps its place too (Castbar.Stop).
-- Without company (no group, no pet) and without "also without a group"
-- the row is not there at all; that is decided out of combat only, a
-- change during combat is laid out after it.
--
-- Role detection and the tank / non-tank split follow Forever Threat by
-- David Stratmann (MIT licence); the code here is written for this addon.
local ThreatBar = { name = "ThreatBar" }
ns.ThreatBar = ThreatBar

local Config, Secrets, L = ns.Config, ns.Secrets, ns.L

ThreatBar.COLORS = {
    green = { 0.10, 0.75, 0.15 },
    yellow = { 1.00, 0.80, 0.00 },
    red = { 0.90, 0.10, 0.10 },
    purple = { 0.62, 0.25, 0.95 },
    grey = { 0.40, 0.40, 0.40 },
}
-- Defensive Stance, Bear Form, Dire Bear Form, Righteous Fury.
ThreatBar.TANK_AURAS = { 71, 5487, 9634, 25780 }
-- GetShapeshiftFormID: Bear Form, Dire Bear Form, Defensive Stance.
ThreatBar.TANK_FORMS = { [5] = true, [8] = true, [18] = true }
-- How often a shown bar refreshes in combat, in seconds.
ThreatBar.INTERVAL = 0.2
-- Test mode.
ThreatBar.SAMPLE = { color = "yellow", fill = 88, left = "88%", right = "-240 Tank" }

function ThreatBar.Applies(scope) return scope == "player" end

-- Someone to share threat with: a group, or a pet out; or the bar is
-- wanted alone too.
local function company()
    if Config.Get("player", "threatBarSolo") then return true end
    if IsInGroup and IsInGroup() then return true end
    return Secrets.Bool(UnitExists, "pet") == true
end

-- The last answer out of combat: the row may only come or go then.
local present

-- Is the row there? Height 0 without it.
function ThreatBar.Active(scope)
    if not (ThreatBar.Applies(scope) and Config.Get(scope, "threatBar") == true) then return false end
    if present == nil or not InCombatLockdown() then present = company() end
    return present
end

-- Group, pet or combat changed: lay the player frame out again if the row
-- comes or goes, now or after combat.
local function recheck()
    if InCombatLockdown() then
        ns.AfterCombat("threatBarCompany", recheck)
        return
    end
    local before = present
    local frame = ns.Frames and ns.Frames.player
    if not frame or Config.Get("player", "threatBar") ~= true then return end
    ThreatBar.Active("player")
    if before ~= present then ns.Single.StyleAll(frame) end
end
ThreatBar.Recheck = recheck

function ThreatBar.Height(scope)
    if not ThreatBar.Active(scope) then return 0 end
    return ns.Pixel.Snap(Config.Get(scope, "threatBarHeight"))
end

-- 12345 -> "12k", 1234 -> "1.2k".
function ThreatBar.Short(n)
    local a = math.abs(n)
    if a >= 10000 then return ("%dk"):format(math.floor(a / 1000 + 0.5)) end
    if a >= 1000 then return ("%.1fk"):format(a / 1000) end
    return tostring(math.floor(a + 0.5))
end

-- ---------------------------------------------------------------------------
-- Role
-- ---------------------------------------------------------------------------

-- true, false, or nil when the client hides the aura data.
local function hasTankAura()
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
    local hidden = false
    for _, id in ipairs(ThreatBar.TANK_AURAS) do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
        if not ok or Secrets.IsSecret(aura) then
            hidden = true
        elseif aura then
            return true
        end
    end
    if hidden then return nil end
    return false
end

local lastRole = "dps"

-- "tank" or "dps": the setting, else the assigned role, a tank form or a
-- tank aura. Unknown (auras hidden in combat): the last known role.
function ThreatBar.Role()
    local setting = Config.Get("player", "threatBarRole")
    if setting == "TANK" then return "tank" end
    if setting == "DPS" then return "dps" end
    local ok, assigned = pcall(UnitGroupRolesAssigned or function() end, "player")
    if ok and assigned == "TANK" then return "tank" end
    if ok and (assigned == "HEALER" or assigned == "DAMAGER") then return "dps" end
    local okF, form = pcall(GetShapeshiftFormID or function() end)
    if okF and Secrets.Number(form) and ThreatBar.TANK_FORMS[form] then return "tank" end
    local aura = hasTankAura()
    if aura == true then lastRole = "tank" elseif aura == false then lastRole = "dps" end
    return lastRole
end

-- Is unit a tank? For purple: the one who took aggro from you.
local function isTank(unit)
    local ok, assigned = pcall(UnitGroupRolesAssigned or function() end, unit)
    if ok and assigned == "TANK" then return true end
    if GetPartyAssignment then
        local okA, main = pcall(GetPartyAssignment, "MAINTANK", unit)
        if okA and main then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Reading threat
-- ---------------------------------------------------------------------------

local function hostile(unit)
    return Secrets.Bool(UnitExists, unit) and Secrets.Bool(UnitCanAttack, "player", unit)
        and not Secrets.Bool(UnitIsDeadOrGhost, unit)
end

-- The mob whose threat is shown, or nil.
function ThreatBar.Mob()
    if hostile("target") then return "target" end
    if hostile("targettarget") then return "targettarget" end
    return nil
end

-- tanking, status, scaled, raw, value of unit on mob; "secret" when the
-- client hides them; nil when unit has no threat there.
local function detailed(unit, mob)
    local ok, tanking, status, scaled, raw, value = pcall(UnitDetailedThreatSituation, unit, mob)
    if not ok then return nil end
    for _, v in ipairs({ tanking, status, scaled, raw, value }) do
        if Secrets.IsSecret(v) then return "secret" end
    end
    if status == nil then return nil end
    return tanking and true or false, status, scaled or 0, raw or 0, value or 0
end

-- Everyone in the group but you, pets included.
local function groupUnits()
    local units = {}
    local function add(u)
        if Secrets.Bool(UnitExists, u) and not Secrets.Bool(UnitIsUnit, u, "player") then units[#units + 1] = u end
    end
    if IsInRaid and IsInRaid() then
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
            add("raid" .. i)
            add("raidpet" .. i)
        end
    else
        add("pet")
        for i = 1, 4 do
            add("party" .. i)
            add("partypet" .. i)
        end
    end
    return units
end

-- A readable name; a secret one cannot be joined to other text.
local function nameOf(unit)
    if not unit then return "?" end
    local ok, name = pcall(UnitName, unit)
    if not ok or Secrets.IsSecret(name) or type(name) ~= "string" then return "?" end
    return name
end

-- What the bar shows: { color, fill (0..100), left, right }, with color a
-- name from ThreatBar.COLORS or { r, g, b } from a colour curve; nil when
-- there is nothing to show.
function ThreatBar.Evaluate()
    local mob = ThreatBar.Mob()
    if not mob then return nil end
    if not Config.Get("player", "threatBarSolo") and not (IsInGroup and IsInGroup())
        and not Secrets.Bool(UnitExists, "pet") then
        return nil
    end
    local myTanking, _, myScaled, myRaw, myValue = detailed("player", mob)
    if myTanking == "secret" then return ThreatBar.FromStatus(mob) end

    -- The one with the most threat besides you, and the one tanking.
    local top, topValue, topScaled, tank, tankValue
    for _, u in ipairs(groupUnits()) do
        local t, _, sc, _, v = detailed(u, mob)
        if t ~= nil and t ~= "secret" then
            if t then tank, tankValue = u, v end
            if not topValue or v > topValue then top, topValue, topScaled = u, v, sc end
        end
    end
    if myTanking == nil then
        -- No threat of your own yet: an empty bar while the others fight.
        if not topValue then return nil end
        return { color = "grey", fill = 0, left = "0", right = tank and nameOf(tank) or "" }
    end

    local warn = Config.Get("player", "threatBarWarn")
    local short = ThreatBar.Short
    if ThreatBar.Role() == "tank" then
        if myTanking then
            local closest = topScaled or 0
            return {
                color = closest >= warn and "yellow" or "green",
                fill = 100 - closest,
                left = short(myValue),
                right = top and ("+" .. short(myValue - topValue) .. " " .. nameOf(top)) or "",
            }
        end
        local holder, holderValue = tank or top, tankValue or topValue
        return {
            color = holder and isTank(holder) and "purple" or "red",
            fill = myRaw,
            left = short(myValue),
            right = holderValue and ("-" .. short(holderValue - myValue) .. " " .. nameOf(holder)) or L.THREAT_LOST,
        }
    end
    if myTanking then
        return {
            color = "red", fill = 100, left = L.THREAT_AGGRO,
            right = top and ("+" .. short(myValue - topValue) .. " " .. nameOf(top)) or "",
        }
    end
    return {
        color = myScaled >= warn and "yellow" or "green",
        fill = myScaled,
        left = ("%d%%"):format(math.floor(myScaled + 0.5)),
        right = tank and ("-" .. short(tankValue - myValue) .. " " .. nameOf(tank)) or "",
    }
end

-- Status 0..3 as colours, per role: what a secret status maps to.
ThreatBar.STATUS_COLORS = {
    tank = { [0] = "red", [1] = "red", [2] = "yellow", [3] = "green" },
    dps = { [0] = "green", [1] = "yellow", [2] = "red", [3] = "red" },
}

local curves = {}
local function statusCurve(role)
    if curves[role] == nil then
        local ok, curve = pcall(function()
            local c = C_CurveUtil.CreateColorCurve()
            c:SetType(Enum.LuaCurveType.Step)
            for status = 0, 3 do
                local col = ThreatBar.COLORS[ThreatBar.STATUS_COLORS[role][status]]
                c:AddPoint(status, CreateColor(col[1], col[2], col[3], 1))
            end
            return c
        end)
        curves[role] = ok and curve or false
    end
    return curves[role] or nil
end

-- Numbers hidden: only the status, mapped to a colour by the client.
function ThreatBar.FromStatus(mob)
    local ok, status = pcall(UnitThreatSituation, "player", mob)
    if not ok or status == nil then return nil end
    local role = ThreatBar.Role()
    if not Secrets.IsSecret(status) then
        return { color = ThreatBar.STATUS_COLORS[role][status] or "grey", fill = 100, left = "", right = "" }
    end
    local curve = statusCurve(role)
    if not curve then return { color = "grey", fill = 0, left = "", right = "" } end
    local okC, r, g, b = pcall(function() return curve:Evaluate(status):GetRGB() end)
    if not okC then return { color = "grey", fill = 0, left = "", right = "" } end
    return { color = { r, g, b }, fill = 100, left = "", right = "" }
end

-- ---------------------------------------------------------------------------
-- The bar
-- ---------------------------------------------------------------------------

function ThreatBar.Build(frame)
    if not ThreatBar.Applies(frame.key) then return end
    local bar = CreateFrame("StatusBar", nil, frame)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.left = bar:CreateFontString(nil, "OVERLAY")
    bar.right = bar:CreateFontString(nil, "OVERLAY")
    bar:SetMinMaxValues(0, 100)
    ns.Corners.Add(bar, bar.bg)
    ns.Corners.Add(bar, function() return bar:GetStatusBarTexture() end)
    bar.clip = ns.Corners.Clipper(bar)
    bar:Hide()
    frame.threatBar = bar
end

local function paint(bar, shown)
    if not shown then
        bar:SetValue(0)
        bar.left:SetText("")
        bar.right:SetText("")
        return
    end
    local c = type(shown.color) == "table" and shown.color or ThreatBar.COLORS[shown.color] or ThreatBar.COLORS.grey
    pcall(bar.SetStatusBarColor, bar, c[1], c[2], c[3], 1)
    bar:SetValue(math.max(0, math.min(100, shown.fill or 0)))
    bar.left:SetText(shown.left or "")
    bar.right:SetText(shown.right or "")
end
ThreatBar.Paint = paint

function ThreatBar.Refresh(frame)
    local bar = frame.threatBar
    if not bar or not bar:IsShown() then return end
    if bar.preview then
        paint(bar, ThreatBar.SAMPLE)
        return
    end
    local ok, shown = pcall(ThreatBar.Evaluate)
    paint(bar, ok and shown or nil)
end

-- Out of combat: size, place, look. Below the frame, or below a castbar
-- docked below it.
function ThreatBar.Style(frame)
    local bar = frame.threatBar
    if not bar then return end
    local scope = frame.key
    local active = ThreatBar.Active(scope)
    bar:SetShown(active)
    if not active then return end
    local _, below = ns.Shape.CastbarBelow(frame)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -below)
    bar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -below)
    bar:SetHeight(ThreatBar.Height(scope))
    local tex = ns.Media.StatusBar(Config.Get(scope, "barTexture"))
    bar:SetStatusBarTexture(tex)
    bar.bg:SetTexture(tex)
    local bg = Config.Get(scope, "backgroundColor")
    bar.bg:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    ns.Corners.Fit(bar.clip, frame.unitBox, ns.Shape.Radius(frame))
    local font = ns.Media.Font(Config.Get(scope, "fontFace"))
    local size = math.min(Config.Get(scope, "fontSize"), Config.Get(scope, "threatBarHeight"))
    local outline = Config.Get(scope, "fontOutline")
    local pad = ns.Pixel.Snap(4)
    for _, fs in ipairs({ bar.left, bar.right }) do
        ns.Texts.SetFont(fs, font, size, outline)
        fs:SetWordWrap(false)
        fs:ClearAllPoints()
    end
    bar.left:SetPoint("LEFT", bar, "LEFT", pad, 0)
    bar.left:SetJustifyH("LEFT")
    bar.right:SetPoint("RIGHT", bar, "RIGHT", -pad, 0)
    bar.right:SetJustifyH("RIGHT")
    bar.left:SetPoint("RIGHT", bar.right, "LEFT", -pad, 0)
    ThreatBar.Refresh(frame)
end

function ThreatBar.Update(frame)
    ThreatBar.Refresh(frame)
end

function ThreatBar.Preview(frame, on)
    local bar = frame.threatBar
    if not bar then return end
    bar.preview = on or nil
    ThreatBar.Refresh(frame)
end

-- Threat changes with every hit, not only on the events: while in combat
-- a shown bar is also refreshed on a short timer.
local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < ThreatBar.INTERVAL then return end
    elapsed = 0
    local frame = ns.Frames and ns.Frames.player
    if frame and frame.threatBar and frame.threatBar:IsShown() and UnitAffectingCombat("player") then
        ThreatBar.Refresh(frame)
    end
end)
for _, event in ipairs({ "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_TARGET_CHANGED",
    "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
    pcall(driver.RegisterEvent, driver, event)
end
driver:SetScript("OnEvent", function(_, event)
    local frame = ns.Frames and ns.Frames.player
    if frame then ThreatBar.Refresh(frame) end
    if event == "GROUP_ROSTER_UPDATE" then recheck() end
end)
ns.On("UNIT_PET", function(_, unit) if unit == "player" then recheck() end end)

ns.RegisterElement(ThreatBar)
