-- Totem icons on the player frame (Elements/Totems.lua): settings, layout,
-- live and secret totem data, secure right-click destroy, combat rules and
-- the test mode preview.
local M = H.M

local function boot(class, files)
    local ns = H.LoadAddon(files)
    M.units.player = { name = "Me", class = class, className = class, isPlayer = true, health = 1, healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

-- Settings -----------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local S = ns.Settings
    local CODES = { totemsEnabled = "QE", totemsSize = "QS", totemsSpacing = "QD", totemsFramePoint = "QF",
        totemsPoint = "QO", totemsX = "QX", totemsY = "QY" }
    for key, code in pairs(CODES) do
        local def = S.Get(key)
        H.checkTrue("setting " .. key, def)
        H.check("code of " .. key, def and def.code, code)
        H.checkTrue(key .. " on the player", S.AppliesTo(def, "player"))
        for _, scope in ipairs({ "general", "target", "targettarget", "pet", "focus", "party" }) do
            H.check(key .. " not on " .. scope, S.AppliesTo(def, scope), false)
        end
    end
    H.check("enabled by default", S.Default(S.Get("totemsEnabled"), "player"), true)
    H.check("default size", S.Default(S.Get("totemsSize"), "player"), 24)
    H.check("default: right of the block", S.Default(S.Get("totemsFramePoint"), "player"), "RIGHT")
    H.check("default: icons' left side", S.Default(S.Get("totemsPoint"), "player"), "LEFT")
    H.check("default x", S.Default(S.Get("totemsX"), "player"), 6)
    H.check("default y", S.Default(S.Get("totemsY"), "player"), 0)

    -- The options page: one "Totems" section, on the player page only.
    local found
    for _, tab in ipairs(ns.Schema.Tabs("player")) do
        for _, sec in ipairs(tab.sections or {}) do
            if sec.id == "totems" then found = sec end
        end
    end
    H.checkTrue("player page has a Totems section", found)
    H.check("section label", ns.L.SECTION_totems, "Totems")
    for key in pairs(CODES) do
        H.checkTrue("label for " .. key, ns.L["SETTING_" .. key] ~= "SETTING_" .. key)
    end
end

-- Defaults add nothing to a saved profile.
do
    local ns = boot("WARRIOR")
    local C = ns.Config
    C.Set("player", "totemsEnabled", true)
    C.Set("player", "totemsSize", 24)
    C.Set("player", "totemsFramePoint", "RIGHT")
    for key in pairs(C.Profile().player) do
        H.checkTrue("no totem key stored for defaults: " .. key, not key:match("^totems"))
    end
    local exported = ns.Codec.Encode(C.Profile())
    H.checkTrue("export without totem codes", not exported:find("pQ"))
    C.Set("player", "totemsSize", 30)
    H.checkTrue("a changed size is exported", ns.Codec.Encode(C.Profile()):find("pQS30"))
end

-- Build and layout ---------------------------------------------------------------
do
    local ns = boot("WARRIOR")
    local player = ns.Frames.player
    local t = player.totems
    H.checkTrue("player frame has totems", t)
    H.check("no totems on the target frame", ns.Frames.target.totems, nil)
    H.check("one icon per totem slot", #t.slots, MAX_TOTEMS)
    for i, s in ipairs(t.slots) do
        H.check("standard order " .. i, s.slot, i)
        local click = s.click
        H.check("secure button " .. i, click._template, "SecureActionButtonTemplate")
        H.check("right-click destroys " .. i, click:GetAttribute("*type2"), "destroytotem")
        H.check("its slot " .. i, click:GetAttribute("*totem-slot*"), s.slot)
        H.check("mouse up only " .. i, click._clicks[1], "RightButtonUp")
        H.check("nothing to click without a totem " .. i, click:IsShown(), false)
        H.check("no icon without a totem " .. i, s.art:IsShown(), false)
        H.checkTrue("click area above the icon " .. i, click:GetFrameLevel() > s.art.cooldown:GetFrameLevel())
    end

    -- Hangs from the player's block, right of it, pushed out by the ring.
    local holder = t.holder
    local point, rel, relPoint, x, y = holder:GetPoint(1)
    H.check("icons' left side", point, "LEFT")
    H.check("to the block", rel, player.unitBox)
    H.check("block's right side", relPoint, "RIGHT")
    H.check("x: offset plus border", x, 6 + ns.Border.Extent("player"))
    H.check("y", y, 0)
    H.check("row width", holder:GetWidth(), 4 * 24 + 3 * 3)
    H.check("row height", holder:GetHeight(), 24)
    local _, _, _, x2 = t.slots[2].art:GetPoint(1)
    H.check("second icon one step along", x2, 27)
    H.check("click area on its icon", select(4, t.slots[2].click:GetPoint(1)), 27)
    H.check("click area size", t.slots[2].click:GetWidth(), 24)
    H.check("icon size", t.slots[2].art:GetWidth(), 24)

    -- Settings move and size it (out of combat).
    local C = ns.Config
    C.Set("player", "totemsSize", 30)
    C.Set("player", "totemsSpacing", 0)
    C.Set("player", "totemsFramePoint", "BOTTOMLEFT")
    C.Set("player", "totemsPoint", "TOPLEFT")
    C.Set("player", "totemsX", 2)
    C.Set("player", "totemsY", -4)
    point, rel, relPoint, x, y = holder:GetPoint(1)
    H.check("moved: point", point, "TOPLEFT")
    H.check("moved: frame point", relPoint, "BOTTOMLEFT")
    H.check("moved: x (no push along the edge)", x, 2)
    H.check("moved: y pushed below the ring", y, -4 - ns.Border.Extent("player"))
    H.check("resized row", holder:GetWidth(), 120)
    H.check("resized click area", t.slots[4].click:GetHeight(), 30)
    C.Set("player", "totemsEnabled", false)
    H.check("off: row hidden", holder:IsShown(), false)
    C.Set("player", "totemsEnabled", true)
    H.check("on again", holder:IsShown(), true)
end

-- A shaman's slots in Blizzard's order: earth, fire, water, air.
do
    local ns = boot("SHAMAN")
    local t = ns.Frames.player.totems
    local want = { 2, 1, 3, 4 }
    for i, s in ipairs(t.slots) do H.check("shaman order " .. i, s.slot, want[i]) end
end

-- Live totems ----------------------------------------------------------------------
do
    local ns = boot("SHAMAN")
    local t = ns.Frames.player.totems
    local fire, earth = t.slots[2], t.slots[1]
    M.totems[1] = { name = "Searing Totem", start = 990, duration = 60, icon = 135825 }
    M.FireEvent("PLAYER_TOTEM_UPDATE", 1)
    H.check("fire icon shown", fire.art:IsShown(), true)
    H.check("fire icon texture", fire.art.icon._texture, 135825)
    H.check("fire swipe start", fire.art.cooldown._cooldown[1], 990)
    H.check("fire swipe duration", fire.art.cooldown._cooldown[2], 60)
    H.check("fire time left numbers on", fire.art.cooldown._hideNumbers, false)
    H.check("fire fully visible", fire.art:GetAlpha(), 1)
    H.check("earth still empty", earth.art:IsShown(), false)
    H.check("fire clickable", fire.click:IsShown(), true)
    H.check("earth not clickable out of combat", earth.click:IsShown(), false)

    -- Tooltip over a totem: the client's totem tooltip for its slot.
    fire.click._scripts.OnEnter(fire.click)
    H.check("totem tooltip", M.tooltipTotem, 1)
    H.check("tooltip owner", GameTooltip._owner, fire.click)
    fire.click._scripts.OnLeave(fire.click)
    H.check("tooltip hidden on leave", GameTooltip._shown, false)

    -- Right-click destroys through the secure action; the client then
    -- reports the empty slot.
    H.check("right-click action", M.SecureClick(fire.click, "RightButton"), "destroytotem")
    H.check("destroyed the fire slot", M.destroyedTotems[1], 1)
    H.check("left-click does nothing", M.SecureClick(fire.click, "LeftButton"), nil)
    H.check("only one destroy", #M.destroyedTotems, 1)
    M.FireEvent("PLAYER_TOTEM_UPDATE", 1)
    H.check("fire gone", fire.art:IsShown(), false)
    H.check("swipe cleared", fire.art.cooldown._cooldown, nil)
    H.check("fire no longer clickable", fire.click:IsShown(), false)

    -- Blizzard's TotemFrame hides a totem whose duration is 0.
    M.totems[2] = { name = "Odd", start = 990, duration = 0, icon = 1 }
    M.FireEvent("PLAYER_TOTEM_UPDATE", 2)
    H.check("zero duration: no icon", earth.art:IsShown(), false)

    -- Test mode samples do not replace... (see below); a whole-frame
    -- refresh reads the totems too.
    M.totems[2] = { name = "Stoneskin", start = 995, duration = 120, icon = 136098 }
    M.FireEvent("PLAYER_ENTERING_WORLD")
    H.check("entering world reads totems", earth.art:IsShown(), true)
end

-- Combat ------------------------------------------------------------------------------
do
    local ns = boot("SHAMAN")
    local t = ns.Frames.player.totems
    local earth, fire, water = t.slots[1], t.slots[2], t.slots[3]
    M.totems[2] = { name = "Stoneskin", start = 995, duration = 120, icon = 136098 }
    M.FireEvent("PLAYER_TOTEM_UPDATE", 2)
    H.check("earth clickable before combat", earth.click:IsShown(), true)

    -- Combat begins: before lockdown takes effect a shaman's four slots
    -- become clickable, since click areas cannot be shown in combat.
    M.FireEvent("PLAYER_REGEN_DISABLED")
    for i, s in ipairs(t.slots) do H.check("armed for combat " .. i, s.click:IsShown(), true) end
    M.combat = true

    -- In combat the client hands out secrets; icons still follow them.
    M.totemsSecret = true
    M.totems[1] = { name = "Searing Totem", start = 1000, duration = 60, icon = 135825 }
    M.FireEvent("PLAYER_TOTEM_UPDATE", 1)
    H.check("no blocked calls in combat", #M.blocked, 0)
    H.check("fire icon shown", fire.art:IsShown(), true)
    H.check("fire alpha from the secret", fire.art:GetAlpha(), 1)
    H.checkTrue("alpha carries the secret", fire.art._alphaSecret)
    H.checkTrue("secret icon passed through", M.IsSecret(fire.art.icon._texture))
    H.check("secret texture is the icon", M.Reveal(fire.art.icon._texture), 135825)
    H.check("swipe from the duration object", fire.art.cooldown._cooldown.object._duration, 60)
    H.check("empty water slot invisible", water.art:GetAlpha(), 0)
    H.check("click areas untouched in combat", water.click:IsShown(), true)

    -- Expired in combat: the icon goes, the click area waits.
    M.totemsSecret = false
    M.totems[2] = nil
    M.FireEvent("PLAYER_TOTEM_UPDATE", 2)
    H.check("earth icon gone", earth.art:IsShown(), false)
    H.check("earth click area kept in combat", earth.click:IsShown(), true)
    H.check("still nothing blocked", #M.blocked, 0)

    -- Settings changed in combat wait for its end.
    ns.Config.Set("player", "totemsSize", 30)
    H.check("no resize in combat", t.slots[1].click:GetWidth(), 24)
    H.check("nothing blocked by the settings change", #M.blocked, 0)

    -- After combat the click areas follow the totems again.
    M.SetCombat(false)
    H.check("earth click area released", earth.click:IsShown(), false)
    H.check("fire click area kept", fire.click:IsShown(), true)
    H.check("water released", water.click:IsShown(), false)
    H.check("resized after combat", t.slots[1].click:GetWidth(), 30)
end

-- Other classes: no click areas armed for combat.
do
    local ns = boot("WARRIOR")
    local t = ns.Frames.player.totems
    M.FireEvent("PLAYER_REGEN_DISABLED")
    for i, s in ipairs(t.slots) do H.check("not armed " .. i, s.click:IsShown(), false) end
    M.combat = true
    M.totems[3] = { name = "Guardian", start = 1000, duration = 30, icon = 5 }
    M.FireEvent("PLAYER_TOTEM_UPDATE", 3)
    H.check("icon shown in combat", t.slots[3].art:IsShown(), true)
    H.check("click area waits for combat's end", t.slots[3].click:IsShown(), false)
    M.SetCombat(false)
    H.check("clickable after combat", t.slots[3].click:IsShown(), true)
    H.check("nothing blocked", #M.blocked, 0)
end

-- Secret values out of combat (encounter restrictions): an unknown slot
-- stays clickable for a shaman.
do
    local ns = boot("SHAMAN")
    local t = ns.Frames.player.totems
    M.totemsSecret = true
    M.FireEvent("PLAYER_TOTEM_UPDATE", 1)
    for i, s in ipairs(t.slots) do
        H.check("secret: icon frame shown " .. i, s.art:IsShown(), true)
        H.check("secret: empty slot invisible " .. i, s.art:GetAlpha(), 0)
        H.check("secret: clickable " .. i, s.click:IsShown(), true)
    end
end

-- A client without SetAlphaFromBoolean or GetTotemDuration still works.
do
    local ns = boot("SHAMAN")
    local t = ns.Frames.player.totems
    _G.GetTotemDuration = nil
    t.slots[1].art.SetAlphaFromBoolean = function() error("unknown method") end
    M.totemsSecret = true
    M.totems[2] = { name = "Stoneskin", start = 995, duration = 120, icon = 136098 }
    M.FireEvent("PLAYER_TOTEM_UPDATE", 2)
    H.check("fallback: shown", t.slots[1].art:IsShown(), true)
    H.check("fallback: visible", t.slots[1].art:GetAlpha(), 1)
    H.check("fallback: no swipe", t.slots[1].art.cooldown._cooldown, nil)
    H.check("fallback: no error", #M.errors, 0)
end

-- Test mode ----------------------------------------------------------------------------
do
    local ns = boot("WARRIOR")
    local t = ns.Frames.player.totems
    ns.TestMode.Set(true)
    for i, s in ipairs(t.slots) do
        H.check("sample shown " .. i, s.art:IsShown(), true)
        H.check("sample icon " .. i, s.art.icon._texture, ns.Totems.SAMPLES[i].icon)
        H.check("sample timer " .. i, s.art.cooldown._cooldown[2], ns.Totems.SAMPLES[i].duration)
        H.check("sample fully visible " .. i, s.art:GetAlpha(), 1)
        H.check("samples are not clickable " .. i, s.click:IsShown(), false)
    end
    -- A real update does not wipe the preview.
    M.FireEvent("PLAYER_TOTEM_UPDATE", 1)
    H.check("preview kept", t.slots[1].art:IsShown(), true)
    -- Settings changes restyle the preview.
    ns.Config.Set("player", "totemsSize", 20)
    H.check("preview restyled", t.slots[1].art:GetWidth(), 20)
    H.check("preview still shown", t.slots[4].art:IsShown(), true)
    -- Hovering a sample shows no tooltip.
    M.tooltipTotem = nil
    t.slots[1].art._scripts.OnEnter(t.slots[1].art)
    H.check("no tooltip for a sample", M.tooltipTotem, nil)
    ns.TestMode.Set(false)
    for i, s in ipairs(t.slots) do
        H.check("released " .. i, s.art:IsShown(), false)
        H.check("released swipe " .. i, s.art.cooldown._cooldown, nil)
    end
end

-- Test mode ends as combat starts; a shaman's slots stay armed.
do
    local ns = boot("SHAMAN")
    local t = ns.Frames.player.totems
    ns.TestMode.Set(true)
    M.FireEvent("PLAYER_REGEN_DISABLED")
    H.check("test mode off", ns.TestMode.IsOn(), false)
    for i, s in ipairs(t.slots) do
        H.check("samples released " .. i, s.art:IsShown(), false)
        H.check("still armed " .. i, s.click:IsShown(), true)
    end
    M.combat = true
    M.SetCombat(false)
    for i, s in ipairs(t.slots) do H.check("disarmed after combat " .. i, s.click:IsShown(), false) end
end

-- Blizzard's own TotemFrame is left alone: it lives on the concealed
-- PlayerFrame and is never touched.
do
    local src = H.ReadFile("Elements/Totems.lua")
    H.check("TotemFrame not used", src:find("TotemFrame[:%.%[]") == nil, true)
    H.check("no hooksecurefunc", src:find("hooksecurefunc") == nil, true)
end

-- The shipped look: the row sits right of the player's block, vertically
-- centred, clear of the buffs (above the frame, from its left) and the
-- debuffs (below the docked castbar); the class badge sits on the top
-- right corner, above the row.
do
    local ns = boot("SHAMAN", H.TocFiles())
    local C, player = ns.Config, ns.Frames.player
    H.check("shipped: castbar docked", C.Get("player", "castbarEnabled"), true)
    H.check("shipped: debuffs below the castbar", C.Get("player", "debuffsAnchor"), "CASTBAR")
    H.check("shipped: buffs above the frame", C.Get("player", "buffsPoint"), "BOTTOMLEFT")
    local point, rel, relPoint, x, y = player.totems.holder:GetPoint(1)
    H.check("shipped: right of the block", relPoint, "RIGHT")
    H.check("shipped: from the block", rel, player.unitBox)
    H.check("shipped: row's left side", point, "LEFT")
    H.check("shipped: centred", y, 0)
    H.check("shipped: clear of the ring", x, 6 + ns.Border.Extent("player"))
    -- Half the block is taller than half the row plus the badge's reach
    -- below the top edge, so the badge never meets the row.
    local blockHalf = (C.Get("player", "height") + C.Get("player", "castbarHeight")) / 2
    local badgeReach = C.Get("player", "classIconSize") / 2 - C.Get("player", "classIconY")
    H.checkTrue("shipped: badge above the row", blockHalf - 24 / 2 > badgeReach)
end

-- Fix round 1 ---------------------------------------------------------------------

-- Click areas let every button but the right one through to the world.
do
    local ns = boot("SHAMAN")
    for i, s in ipairs(ns.Frames.player.totems.slots) do
        local through = table.concat(s.click._passThrough or {}, ",")
        H.check("pass-through buttons " .. i, through, "LeftButton,MiddleButton,Button4,Button5")
    end
end

-- A client that refuses SetPassThroughButtons still builds the row.
do
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "SHAMAN", className = "SHAMAN", isPlayer = true, health = 1, healthMax = 1 }
    local create = CreateFrame
    _G.CreateFrame = function(...)
        local f = create(...)
        if select(4, ...) == "SecureActionButtonTemplate" then
            f.SetPassThroughButtons = function() error("not allowed") end
        end
        return f
    end
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    H.checkTrue("row built without pass-through", ns.Frames.player.totems and #ns.Frames.player.totems.slots == 4)
end

-- Secret data through the end of combat: the totems are read again when
-- combat ends and once more a frame later.
do
    local ns = boot("SHAMAN")
    local t = ns.Frames.player.totems
    local earth, fire = t.slots[1], t.slots[2]
    M.FireEvent("PLAYER_REGEN_DISABLED")
    M.combat = true
    M.totemsSecret = true
    M.totems[1] = { name = "Searing Totem", start = 1000, duration = 60, icon = 135825 }
    M.FireEvent("PLAYER_TOTEM_UPDATE", 1)
    -- Still secret as combat ends: unknown, a shaman's slots stay armed.
    M.SetCombat(false)
    H.check("secret at combat end: earth still armed", earth.click:IsShown(), true)
    -- A frame later the data is readable: only the fire slot stays.
    M.totemsSecret = false
    M.RunTimers(0)
    H.check("next frame: earth released", earth.click:IsShown(), false)
    H.check("next frame: fire kept", fire.click:IsShown(), true)
    H.check("next frame: earth icon hidden", earth.art:IsShown(), false)
    H.check("nothing blocked", #M.blocked, 0)
end

-- Readable again when combat ends, without any totem event: released at once.
do
    local ns = boot("SHAMAN")
    local t = ns.Frames.player.totems
    M.FireEvent("PLAYER_REGEN_DISABLED")
    M.combat = true
    M.totemsSecret = true
    M.FireEvent("PLAYER_TOTEM_UPDATE", 1)
    M.totemsSecret = false
    M.SetCombat(false)
    for i, s in ipairs(t.slots) do H.check("re-read at combat end " .. i, s.click:IsShown(), false) end
end

-- Unknown data out of combat (restricted content) arms only classes that
-- use totems.
do
    local ns = boot("WARRIOR")
    M.totemsSecret = true
    M.FireEvent("PLAYER_TOTEM_UPDATE", 1)
    for i, s in ipairs(ns.Frames.player.totems.slots) do
        H.check("warrior, unknown: not armed " .. i, s.click:IsShown(), false)
    end
end

-- Test mode disarms real totems' click areas: a right-click on a sample
-- must not destroy a real totem.
do
    local ns = boot("SHAMAN")
    local t = ns.Frames.player.totems
    local fire = t.slots[2]
    M.totems[1] = { name = "Searing Totem", start = 990, duration = 60, icon = 135825 }
    M.FireEvent("PLAYER_TOTEM_UPDATE", 1)
    H.check("real totem clickable", fire.click:IsShown(), true)
    ns.TestMode.Set(true)
    H.check("test mode: disarmed", fire.click:IsShown(), false)
    H.check("test mode: right-click does nothing", M.SecureClick(fire.click, "RightButton"), nil)
    H.check("test mode: nothing destroyed", #M.destroyedTotems, 0)
    ns.TestMode.Set(false)
    H.check("after test mode: armed again", fire.click:IsShown(), true)
end

-- Tooltips: none for a slot known to be empty, the client's for an
-- unknown one.
do
    local ns = boot("SHAMAN")
    local t = ns.Frames.player.totems
    local earth = t.slots[1]
    M.tooltipTotem = nil
    earth.art._scripts.OnEnter(earth.art)
    H.check("empty slot: no totem tooltip", M.tooltipTotem, nil)
    M.totemsSecret = true
    M.FireEvent("PLAYER_TOTEM_UPDATE", 2)
    earth.click._scripts.OnEnter(earth.click)
    H.check("unknown slot: totem tooltip", M.tooltipTotem, 2)
end
