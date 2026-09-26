-- Combat and resting indicators on the player frame
-- (Elements/StatusIcons.lua): settings, Blizzard's art, events, layout,
-- the shipped placement, test mode and combat rules.
local M = H.M

local function boot(files)
    local ns = H.LoadAddon(files)
    M.units.player = { name = "Me", class = "WARRIOR", className = "WARRIOR", isPlayer = true, health = 1,
        healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

-- Settings -----------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local S = ns.Settings
    local CODES = { statusCombat = "ZC", statusResting = "ZR", statusSize = "ZS", statusFramePoint = "ZF",
        statusPoint = "ZO", statusX = "ZX", statusY = "ZY" }
    for key, code in pairs(CODES) do
        local def = S.Get(key)
        H.checkTrue("setting " .. key, def)
        H.check("code of " .. key, def and def.code, code)
        H.checkTrue(key .. " on the player", S.AppliesTo(def, "player"))
        for _, scope in ipairs({ "general", "target", "targettarget", "pet", "focus", "party" }) do
            H.check(key .. " not on " .. scope, S.AppliesTo(def, scope), false)
        end
        H.checkTrue(key .. " label", ns.L["SETTING_" .. key] ~= nil)
    end
    H.check("combat icon on by default", S.Default(S.Get("statusCombat"), "player"), true)
    H.check("resting icon on by default", S.Default(S.Get("statusResting"), "player"), true)
    H.check("default size", S.Default(S.Get("statusSize"), "player"), 22)
    H.check("default: centre of the health bar", S.Default(S.Get("statusFramePoint"), "player"), "CENTER")
    H.check("default: icons' centre", S.Default(S.Get("statusPoint"), "player"), "CENTER")
    H.check("default x", S.Default(S.Get("statusX"), "player"), 0)
    H.check("default y", S.Default(S.Get("statusY"), "player"), 0)

    -- Options: a "Status icons" section on the player's Layout tab only.
    local function section(scope)
        for _, tab in ipairs(ns.Schema.Tabs(scope)) do
            for _, sec in ipairs(tab.sections or {}) do
                if sec.id == "statusIcons" then return sec, tab.id end
            end
        end
    end
    local sec, tab = section("player")
    H.checkTrue("status icons section", sec)
    H.check("on the layout tab", tab, "layout")
    H.check("section keys", sec and table.concat(sec.keys, ","),
        "statusCombat,statusResting,statusSize,statusFramePoint,statusPoint,statusX,statusY")
    H.check("section title", ns.L.SECTION_statusIcons, "Status icons")
    H.check("combat label", ns.L.SETTING_statusCombat, "Show combat icon")
    H.check("resting label", ns.L.SETTING_statusResting, "Show resting icon")
    H.checkTrue("resting hint", ns.L.HINT_statusResting)

    -- Codes round trip.
    local C = ns.Config
    C.Use({})
    C.Set("player", "statusCombat", false)
    C.Set("player", "statusSize", 24)
    local back = assert(ns.Codec.Decode(ns.Codec.Encode(C.Profile())))
    H.check("decoded combat icon", back.player.statusCombat, false)
    H.check("decoded size", back.player.statusSize, 24)
end

-- Build and art ----------------------------------------------------------------------
do
    local ns = boot()
    local s = ns.Frames.player.statusIcons
    H.checkTrue("player frame has status icons", s)
    for _, key in ipairs({ "target", "targettarget", "pet", "focus" }) do
        H.check("none on " .. key, ns.Frames[key].statusIcons, nil)
    end
    -- Blizzard's PlayerFrame art (Blizzard_UnitFrame/Mainline/PlayerFrame.xml).
    H.check("combat atlas", s.combat._atlas, "UI-HUD-UnitFrame-Player-CombatIcon")
    H.check("resting atlas", s.resting._atlas, "UI-HUD-UnitFrame-Player-Rest-Flipbook")
    local anim = s.restAnim._anims[1]
    H.check("resting flipbook", anim._kind, "FlipBook")
    H.check("flipbook rows", anim._rows, 7)
    H.check("flipbook columns", anim._columns, 6)
    H.check("flipbook frames", anim._frames, 42)
    H.check("flipbook duration", anim._duration, 1.5)
    H.check("loops", s.restAnim._looping, "REPEAT")
    H.check("holder a plain child of the frame", s.holder:GetParent(), ns.Frames.player)
    H.check("holder a plain frame", s.holder._kind, "Frame")

    -- Idle: nothing shows.
    H.check("idle: no combat icon", s.combat:IsShown(), false)
    H.check("idle: no resting icon", s.resting:IsShown(), false)
    H.check("idle: not animating", s.restAnim:IsPlaying(), false)

    -- Layout: room for both, centred on the health bar, above its texts.
    local C, f = ns.Config, ns.Frames.player
    H.check("holder width", s.holder:GetWidth(), 22 + 2 + 22)
    H.check("holder height", s.holder:GetHeight(), 22)
    local p = point(s.holder, "CENTER")
    H.check("holder on the health bar", p[2], f.health)
    H.check("on its centre", p[3], "CENTER")
    H.check("x", p[4], 0)
    H.check("y", p[5], 0)
    H.checkTrue("above the bar's texts", s.holder:GetFrameLevel() > f.overlay:GetFrameLevel())

    -- Both show: side by side, combat on the left.
    ns.StatusIcons.Preview(f, true)
    H.check("both: combat in the first slot", point(s.combat, "TOPLEFT")[4], 0)
    H.check("combat size", s.combat:GetWidth(), 22)
    H.check("both: resting centred on the second slot", point(s.resting, "CENTER")[4], 24 + 11)
    H.check("resting art like Blizzard's (30 in 20)", s.resting:GetWidth(), 33)
    ns.StatusIcons.Preview(f, false)
    -- One shows: centred in the row.
    M.resting = true
    M.FireEvent("PLAYER_UPDATE_RESTING")
    H.check("alone: resting centred", point(s.resting, "CENTER")[4], 12 + 11)
    M.resting = false
    M.FireEvent("PLAYER_UPDATE_RESTING")

    C.Set("player", "statusSize", 24)
    C.Set("player", "statusFramePoint", "LEFT")
    C.Set("player", "statusPoint", "LEFT")
    C.Set("player", "statusX", 3)
    C.Set("player", "statusY", -4)
    H.check("size", s.holder:GetHeight(), 24)
    p = point(s.holder, "LEFT")
    H.check("point", p[3], "LEFT")
    H.check("x", p[4], 3)
    H.check("y", p[5], -4)
    -- Packed towards a side anchor: a lone icon in the first slot.
    M.combat = true
    M.FireEvent("PLAYER_REGEN_DISABLED")
    H.check("left anchor: combat at the left", point(s.combat, "TOPLEFT")[4], 0)
    M.SetCombat(false)
    -- One icon off: the row shrinks to one slot.
    C.Set("player", "statusCombat", false)
    H.check("one slot", s.holder:GetWidth(), 24)
    C.Set("player", "statusResting", false)
    H.check("both off: holder hidden", s.holder:IsShown(), false)
end

-- Events ----------------------------------------------------------------------------
do
    local ns = boot()
    local s = ns.Frames.player.statusIcons
    local C = ns.Config
    M.combat = true
    M.FireEvent("PLAYER_REGEN_DISABLED")
    H.check("combat: icon shows", s.combat:IsShown(), true)
    M.SetCombat(false)
    H.check("combat over: icon hides", s.combat:IsShown(), false)

    M.resting = true
    M.FireEvent("PLAYER_UPDATE_RESTING")
    H.check("resting: icon shows", s.resting:IsShown(), true)
    H.check("resting: animates", s.restAnim:IsPlaying(), true)
    M.resting = false
    M.FireEvent("PLAYER_UPDATE_RESTING")
    H.check("rested: icon hides", s.resting:IsShown(), false)
    H.check("rested: animation stops", s.restAnim:IsPlaying(), false)

    -- Loading into the world while resting (an inn, a /reload).
    M.resting = true
    M.FireEvent("PLAYER_ENTERING_WORLD")
    H.check("entering the world resting", s.resting:IsShown(), true)

    -- Off in the settings: never shown.
    C.Set("player", "statusResting", false)
    H.check("resting icon off", s.resting:IsShown(), false)
    H.check("resting icon off: no animation", s.restAnim:IsPlaying(), false)
    C.Set("player", "statusCombat", false)
    M.combat = true
    M.FireEvent("PLAYER_REGEN_DISABLED")
    H.check("combat icon off", s.combat:IsShown(), false)
    M.SetCombat(false)
    C.Set("player", "statusCombat", true)
    C.Set("player", "statusResting", true)

    -- In combat the holder is not anchored or sized (the icons, textures
    -- of the plain holder, may move within it).
    for _, region in ipairs({ s.holder }) do
        for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetAllPoints", "SetSize" }) do
            local original = region[method]
            region[method] = function(self, ...)
                assert(not M.combat, "re-anchored in combat")
                return original(self, ...)
            end
        end
    end
    local ok, err = pcall(function()
        M.combat = true
        M.FireEvent("PLAYER_REGEN_DISABLED")
        M.resting = false
        M.FireEvent("PLAYER_UPDATE_RESTING")
    end)
    H.check("combat: holder stays put", ok and "ok" or tostring(err), "ok")
    H.check("combat: shown", s.combat:IsShown(), true)
    M.SetCombat(false)
end

-- Test mode ----------------------------------------------------------------------------
do
    local ns = boot()
    local s = ns.Frames.player.statusIcons
    M.resting = false
    H.checkTrue("test mode on", ns.TestMode.Set(true))
    H.check("test mode: combat icon", s.combat:IsShown(), true)
    H.check("test mode: resting icon", s.resting:IsShown(), true)
    H.check("test mode: animates", s.restAnim:IsPlaying(), true)
    ns.Config.Set("player", "statusCombat", false)
    H.check("test mode: off stays off", s.combat:IsShown(), false)
    ns.Config.Set("player", "statusCombat", true)
    ns.TestMode.Set(false)
    H.check("test mode off: combat icon follows the game", s.combat:IsShown(), false)
    H.check("test mode off: resting icon follows the game", s.resting:IsShown(), false)
end

-- The shipped look: centred on the health bar, clear of its texts.
do
    local ns = H.LoadShipped()
    M.units.player = { name = "Me", class = "SHAMAN", className = "SHAMAN", isPlayer = true, health = 1,
        healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    local C, f = ns.Config, ns.Frames.player
    local s = f.statusIcons
    local p = point(s.holder, "CENTER")
    H.check("shipped: on the health bar", p[2], f.health)
    H.check("shipped: centred", p[3] .. p[4] .. p[5], "CENTER00")
    -- The health texts sit at the bar's ends; the row stays in its middle
    -- third on the shipped 300 px frame.
    H.checkTrue("shipped: row narrower than a third of the bar", s.holder:GetWidth() < f.healthWidth / 3)
    H.check("shipped: left and right health texts", C.Get("player", "textHealthLeft") .. "," ..
        C.Get("player", "textHealthRight"), "CURRENT_MAX,PERCENT")
end
