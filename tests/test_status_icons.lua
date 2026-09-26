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
    H.check("default size", S.Default(S.Get("statusSize"), "player"), 18)
    H.check("default: top right of the block", S.Default(S.Get("statusFramePoint"), "player"), "TOPRIGHT")
    H.check("default: icons' bottom right", S.Default(S.Get("statusPoint"), "player"), "BOTTOMRIGHT")
    H.check("default x: left of the class badge", S.Default(S.Get("statusX"), "player"), -24)
    H.check("default y", S.Default(S.Get("statusY"), "player"), 2)

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

    -- Layout: two slots, combat on the left, from the block's top right.
    local C = ns.Config
    H.check("holder width", s.holder:GetWidth(), 18 + 2 + 18)
    H.check("holder height", s.holder:GetHeight(), 18)
    local p = point(s.holder, "BOTTOMRIGHT")
    H.check("holder on the unit box", p[2], ns.Frames.player.unitBox)
    H.check("from its top right", p[3], "TOPRIGHT")
    H.check("x", p[4], -24)
    H.check("y: outside the ring", p[5], 2 + ns.Border.Extent("player"))
    H.check("combat slot", point(s.combat, "TOPLEFT")[4], 0)
    H.check("combat size", s.combat:GetWidth(), 18)
    H.check("resting slot centred on the second slot", point(s.resting, "CENTER")[4], 20 + 9)
    H.check("resting art like Blizzard's (30 in 20)", s.resting:GetWidth(), 27)

    C.Set("player", "statusSize", 24)
    C.Set("player", "statusFramePoint", "LEFT")
    C.Set("player", "statusPoint", "RIGHT")
    C.Set("player", "statusX", -3)
    C.Set("player", "statusY", 4)
    H.check("size", s.holder:GetHeight(), 24)
    p = point(s.holder, "RIGHT")
    H.check("point", p[3], "LEFT")
    H.check("x counts from the ring", p[4], -3 - ns.Border.Extent("player"))
    H.check("y", p[5], 4)
    -- One icon off: the other takes the first slot, the row shrinks.
    C.Set("player", "statusCombat", false)
    H.check("one slot", s.holder:GetWidth(), 24)
    H.check("resting in the first slot", point(s.resting, "CENTER")[4], 12)
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

    -- In combat nothing is anchored or sized: icons only show and hide.
    for _, region in ipairs({ s.holder, s.combat, s.resting }) do
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
    H.check("combat: only shows and hides", ok and "ok" or tostring(err), "ok")
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

-- The shipped look: clear of the class badge, the buffs above the frame,
-- the portrait and the totems.
do
    local ns = H.LoadShipped()
    M.units.player = { name = "Me", class = "SHAMAN", className = "SHAMAN", isPlayer = true, health = 1,
        healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    local C, f = ns.Config, ns.Frames.player
    local s = f.statusIcons
    local width = C.Get("player", "width")
    local p = point(s.holder, "BOTTOMRIGHT")
    H.check("shipped: from the block's top right", p[3], "TOPRIGHT")
    -- The row from the frame's top right corner.
    local right, bottom = p[4], p[5]
    local left, top = right - s.holder:GetWidth(), bottom + s.holder:GetHeight()
    local badge = f.classBadgeBox
    H.checkTrue("shipped: left of the class badge", right <= badge.left)
    H.checkTrue("shipped: above the ring", bottom >= ns.Border.Extent("player"))
    -- Buffs grow right from the frame's top left: their widest row (own
    -- buffs, larger) ends here.
    local perRow, own, spacing = C.Get("player", "buffsPerRow"), C.Get("player", "buffsOwnSize"),
        C.Get("player", "buffsSpacing")
    local buffsRight = C.Get("player", "buffsX") + perRow * own + (perRow - 1) * spacing
    H.checkTrue("shipped: right of the buffs", width + left >= buffsRight)
    H.check("shipped: portrait on the left", C.Get("player", "portraitMode"), "LEFT")
    H.checkTrue("shipped: clear of the portrait (right half)", width + left > C.Get("player", "height"))
    H.check("shipped: totems right of the block", C.Get("player", "totemsFramePoint"), "RIGHT")
    H.checkTrue("shipped: left of the totems", right < C.Get("player", "totemsX"))
    H.checkTrue("shipped: not above the badge's top", top > badge.bottom or right <= badge.left)
end
