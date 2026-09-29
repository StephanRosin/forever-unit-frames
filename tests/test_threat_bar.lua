-- The threat bar (Elements/ThreatBar.lua): a row below the player frame and
-- its docked castbar, inside the unit's border. Settings, placement and
-- shape, what it shows for tanks and everyone else, secrets and test mode.
local M = H.M

local function boot()
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "WARRIOR", className = "WARRIOR", isPlayer = true, health = 1,
        healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local function close(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

-- Settings -----------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local S = ns.Settings
    for key, code in pairs({ threatBar = "TB", threatBarHeight = "TZ", threatBarWarn = "TW",
        threatBarSolo = "TS", threatBarRole = "TO" }) do
        local def = S.Get(key)
        H.checkTrue("setting " .. key, def)
        H.check("code of " .. key, def and def.code, code)
        H.checkTrue(key .. " on the player frame", S.AppliesTo(def, "player"))
        H.check(key .. " not on the target frame", S.AppliesTo(def, "target"), false)
        H.checkTrue(key .. " label", ns.L["SETTING_" .. key] ~= "SETTING_" .. key)
    end
    H.check("off by default", S.Default(S.Get("threatBar"), "player"), false)
    H.check("warn default", S.Default(S.Get("threatBarWarn"), "player"), 80)
    local found
    for _, tab in ipairs(ns.Schema.Tabs("player")) do
        for _, sec in ipairs(tab.sections or {}) do
            if sec.id == "threatBar" then found = tab.id end
        end
    end
    H.check("in the castbar tab", found, "castbar")
end

-- Off: no row, nothing changes ---------------------------------------------------
do
    local ns = boot()
    local frame = ns.Frames.player
    H.checkTrue("bar built for the player", frame.threatBar)
    H.check("no bar on the target frame", ns.Frames.target.threatBar, nil)
    H.check("off: hidden", frame.threatBar:IsShown(), false)
    H.check("off: no height", ns.ThreatBar.Height("player"), 0)
end

-- On: placement, shape, castbar ---------------------------------------------------
do
    local ns = boot()
    local C = ns.Config
    local frame = ns.Frames.player
    local bar = frame.threatBar
    C.Set("player", "castbarEnabled", false)
    C.Set("player", "cornerRadius", 6)
    C.Set("player", "threatBarSolo", true)
    C.Set("player", "threatBar", true)
    H.checkTrue("on: shown", bar:IsShown())
    local point, rel, relPoint, x, y = bar:GetPoint(1)
    H.check("directly below the frame", point .. relPoint, "TOPLEFTBOTTOMLEFT")
    H.check("to the frame", rel, frame)
    H.check("flush", y, 0)
    H.check("height", bar:GetHeight(), 12)
    -- The unit box reaches down over the row, and the frame joins it.
    local _, _, _, _, boxBottom = frame.unitBox:GetPoint(2)
    H.check("unit box includes the row", boxBottom, -12)
    H.checkTrue("block ring shows", frame.blockRing:IsShown())
    H.check("frame ring hidden", frame.frameRing:IsShown(), false)
    H.check("frame keeps only its top corners round", frame.clip.shape, "TOP")

    -- With a castbar docked below: the row goes below the castbar, and the
    -- castbar keeps its place while idle.
    C.Set("player", "castbarEnabled", true)
    C.Set("player", "castbarAlwaysShow", false)
    local castHeight = C.Get("player", "castbarHeight")
    _, _, _, _, y = bar:GetPoint(1)
    H.check("below the docked castbar", y, -castHeight)
    _, _, _, _, boxBottom = frame.unitBox:GetPoint(2)
    H.check("unit box: castbar and row", boxBottom, -(castHeight + 12))
    H.checkTrue("idle castbar keeps its place", frame.castbar:IsShown())
    C.Set("player", "threatBar", false)
    H.check("without the row the idle castbar hides again", frame.castbar:IsShown(), false)
    C.Set("player", "threatBar", true)

    -- Castbar above, row below: no round corner on the frame at all.
    C.Set("player", "castbarPosition", "ABOVE")
    _, _, _, _, y = bar:GetPoint(1)
    H.check("castbar above: row right below the frame", y, 0)
    H.check("joined on both sides: square", frame.clip.shape, "NONE")
    H.check("square mask file", frame.clip.mask._texture, ns.Corners.SQUARE)
    C.Set("player", "castbarPosition", "BELOW")

    -- The radius never exceeds the row's height.
    C.Set("player", "cornerRadius", 12)
    C.Set("player", "threatBarHeight", 8)
    H.checkTrue("radius held to the row", ns.Shape.Radius(frame) <= 8)
    C.Set("player", "threatBarHeight", 12)
end

-- What it shows --------------------------------------------------------------------
do
    local ns = boot()
    local C = ns.Config
    local T = ns.ThreatBar
    local frame = ns.Frames.player
    local bar = frame.threatBar
    C.Set("player", "threatBar", true)
    C.Set("player", "threatBarSolo", true)

    H.check("no target: nothing", T.Evaluate(), nil)
    frame.threatBar:SetValue(50)
    T.Refresh(frame)
    H.check("no target: empty bar", bar:GetValue(), 0)

    M.units.target = { name = "Ogre", hostile = true, health = 1, healthMax = 1, detailed = {} }
    M.units.party1 = { name = "Rogue", health = 1, healthMax = 1 }
    M.units.party2 = { name = "Bear", health = 1, healthMax = 1, role = "TANK" }
    M.SetGroup({ "party1", "party2" })
    local d = M.units.target.detailed

    -- Damage: my share of the pull, the gap to the tank.
    d.player = { false, 1, 62, 55, 3100 }
    d.party2 = { true, 3, 100, 100, 5000 }
    local shown = T.Evaluate()
    H.check("dps: green below the warning", shown.color, "green")
    H.check("dps: fill = scaled share", shown.fill, 62)
    H.check("dps: left", shown.left, "62%")
    H.check("dps: gap to the tank", shown.right, "-1.9k Bear")
    d.player = { false, 1, 85, 80, 4200 }
    H.check("dps: yellow from the warning", T.Evaluate().color, "yellow")
    d.player = { true, 3, 100, 100, 5200 }
    d.party2 = { false, 1, 96, 90, 5000 }
    shown = T.Evaluate()
    H.check("dps with aggro: red", shown.color, "red")
    H.check("dps with aggro: word", shown.left, ns.L.THREAT_AGGRO)
    H.check("dps with aggro: lead", shown.right, "+200 Bear")

    -- Tank: my lead, how close the next one is.
    C.Set("player", "threatBarRole", "TANK")
    d.player = { true, 3, 100, 100, 9000 }
    d.party1 = { false, 1, 40, 36, 3600 }
    d.party2 = nil
    shown = T.Evaluate()
    H.check("tank: green while the next is far", shown.color, "green")
    H.check("tank: fill = room left", shown.fill, 60)
    H.check("tank: my threat", shown.left, "9.0k")
    H.check("tank: my lead", shown.right, "+5.4k Rogue")
    d.party1 = { false, 2, 92, 84, 8300 }
    H.check("tank: yellow when someone closes in", T.Evaluate().color, "yellow")
    d.player = { false, 2, 90, 80, 7000 }
    d.party1 = { true, 3, 100, 100, 7400 }
    shown = T.Evaluate()
    H.check("tank overtaken: red", shown.color, "red")
    H.check("tank overtaken: the gap", shown.right, "-400 Rogue")
    d.party1 = nil
    d.party2 = { true, 3, 100, 100, 7400 }
    H.check("taken by another tank: purple", T.Evaluate().color, "purple")

    -- The role on its own: a tank form.
    C.Set("player", "threatBarRole", "AUTO")
    M.form = 18
    H.check("defensive stance: tank", T.Role(), "tank")
    M.form = nil
    M.units.player.role = "HEALER"
    H.check("assigned healer: not a tank", T.Role(), "dps")
    M.units.player.role = nil

    -- A healer with a friendly target reads the target's target.
    M.units.target = { name = "Bear", health = 1, healthMax = 1 }
    M.units.targettarget = { name = "Ogre", hostile = true, health = 1, healthMax = 1,
        detailed = { player = { false, 0, 10, 9, 100 } } }
    H.check("healer: the target's target", T.Mob(), "targettarget")
    H.check("healer: shown", T.Evaluate().left, "10%")

    -- Solo off: nothing without a group.
    M.SetGroup({})
    C.Set("player", "threatBarSolo", false)
    H.check("solo off: nothing alone", T.Evaluate(), nil)
    C.Set("player", "threatBarSolo", true)

    -- The bar itself takes the values.
    M.units.target = { name = "Ogre", hostile = true, health = 1, healthMax = 1,
        detailed = { player = { false, 1, 70, 60, 700 } } }
    T.Refresh(frame)
    H.check("bar value", bar:GetValue(), 70)
    H.check("bar left text", bar.left:GetText(), "70%")
    H.check("bar colour", bar._color[1], T.COLORS.green[1])

    -- Secret numbers: the status colour through a curve.
    M.units.target.detailed.player = { M.Secret(false), M.Secret(2), M.Secret(90), M.Secret(80), M.Secret(900) }
    M.units.target.threatOf = { player = M.Secret(2) }
    shown = T.Evaluate()
    H.check("secret: a curve colour", type(shown.color), "table")
    H.check("secret: status 2 for a damage dealer is red", shown.color[1], T.COLORS.red[1])
    H.check("secret: no numbers", shown.left, "")
    M.units.target.threatOf = { player = 3 }
    H.check("readable status only: its colour", T.Evaluate().color, "red")

    -- Test mode.
    ns.ThreatBar.Preview(frame, true)
    H.check("preview: sample", bar.left:GetText(), T.SAMPLE.left)
    ns.ThreatBar.Preview(frame, false)
end

-- Numbers ----------------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local short = ns.ThreatBar.Short
    H.check("short: small", short(640), "640")
    H.check("short: thousands", short(1234), "1.2k")
    H.check("short: ten thousands", short(12345), "12k")
    H.check("short: negative uses the size", short(-1500), "1.5k")
end

-- Reported: alone, with "also without a group" off, the row stayed (empty).
-- Without company it is gone; a group or a pet brings it back, laid out
-- out of combat only.
do
    local ns = boot()
    local C = ns.Config
    local frame = ns.Frames.player
    local bar = frame.threatBar
    C.Set("player", "threatBarSolo", false)
    C.Set("player", "threatBar", true)
    H.check("alone: no row", bar:IsShown(), false)
    H.check("alone: no height", ns.ThreatBar.Height("player"), 0)
    M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
    M.SetGroup({ "party1" })
    H.checkTrue("a group: the row", bar:IsShown())
    M.SetGroup({})
    H.check("alone again: gone", bar:IsShown(), false)
    M.units.pet = { name = "Imp", health = 1, healthMax = 1 }
    M.FireEvent("UNIT_PET", "player")
    H.checkTrue("a pet out: the row", bar:IsShown())
    -- Changes in combat wait for its end.
    M.SetCombat(true)
    M.units.pet = nil
    M.FireEvent("UNIT_PET", "player")
    H.checkTrue("in combat: unchanged", bar:IsShown())
    M.SetCombat(false)
    H.check("after combat: gone", bar:IsShown(), false)
    C.Set("player", "threatBarSolo", true)
    H.checkTrue("also without a group: the row alone", bar:IsShown())
end
