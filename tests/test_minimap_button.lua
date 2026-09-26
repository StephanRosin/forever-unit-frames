-- The minimap button (Options/MinimapButton.lua): settings, clicks,
-- tooltip, dragging around round and square minimaps, the optional
-- LibDataBroker launcher and the combat rules.
local M = H.M

local function boot()
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", health = 1, healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local function close(a, b) return math.abs(a - b) < 1e-6 end

-- Settings -----------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local S = ns.Settings
    for key, code in pairs({ minimapShow = "MS", minimapAngle = "MA" }) do
        local def = S.Get(key)
        H.checkTrue("setting " .. key, def)
        H.check("code of " .. key, def and def.code, code)
        H.checkTrue(key .. " on General", S.AppliesTo(def, "general"))
        H.check(key .. " not on a frame", S.AppliesTo(def, "player"), false)
        H.checkTrue(key .. " label", ns.L["SETTING_" .. key] ~= "SETTING_" .. key)
    end
    H.check("shown by default", S.Default(S.Get("minimapShow"), "general"), true)
    H.check("default angle: bottom left, as LibDBIcon", S.Default(S.Get("minimapAngle"), "general"), 225)
    H.check("angle range", S.Get("minimapAngle").min .. "-" .. S.Get("minimapAngle").max, "0-359")
    local found, tab
    for _, t in ipairs(ns.Schema.Tabs("general")) do
        for _, sec in ipairs(t.sections or {}) do
            if sec.id == "minimap" then found, tab = sec, t.id end
        end
    end
    H.checkTrue("minimap section", found)
    H.check("in Appearance", tab, "appearance")
    H.check("section keys", found and table.concat(found.keys, ","), "minimapShow,minimapAngle")
    H.check("section title", ns.L.SECTION_minimap, "Minimap")
end

-- The button ---------------------------------------------------------------------------
do
    local ns = boot()
    local B = ns.MinimapButton
    local button = B.button
    H.checkTrue("button built", button)
    H.check("on the minimap", button:GetParent(), Minimap)
    H.check("not secure", button._template, nil)
    H.checkTrue("shown", button:IsShown())
    H.check("icon file", button.icon._texture, "Interface\\AddOns\\ForeverUnitFrames\\Media\\MinimapIcon.tga")
    H.check("tracking border like other minimap buttons", button.border._texture,
        "Interface\\Minimap\\MiniMap-TrackingBorder")
    H.check("clicks", table.concat(button._clicks, ","), "LeftButtonUp,RightButtonUp")
    H.check("dragged with the left button", button._drag[1], "LeftButton")

    -- Round minimap (no GetMinimapShape): on the circle, radius half the
    -- minimap plus 5 (LibDBIcon's), at 225 degrees.
    local p = { button:GetPoint(1) }
    H.check("centred on the minimap's centre", p[1] .. p[2]:GetName() .. p[3], "CENTERMinimapCENTER")
    local r = 70 + 5
    H.checkTrue("round: x", close(p[4], math.cos(math.rad(225)) * r))
    H.checkTrue("round: y", close(p[5], math.sin(math.rad(225)) * r))

    -- Square minimap: out towards the corner on a larger circle (the
    -- diagonal less 10, LibDBIcon's), clamped to the square's edges.
    _G.GetMinimapShape = function() return "SQUARE" end
    B.Place()
    p = { button:GetPoint(1) }
    local diagonal = math.sqrt(2 * r * r) - 10
    H.checkTrue("square: x towards the corner", close(p[4], math.cos(math.rad(225)) * diagonal))
    H.checkTrue("square: y towards the corner", close(p[5], math.sin(math.rad(225)) * diagonal))
    H.checkTrue("square: beyond the circle", p[4] < math.cos(math.rad(225)) * r)
    ns.Config.Set("general", "minimapAngle", 180)
    p = { button:GetPoint(1) }
    H.checkTrue("square, left: x", close(p[4], -r))
    H.checkTrue("square, left: y", close(p[5], 0))
    _G.GetMinimapShape = nil

    -- Dragging: the angle follows the cursor around the centre and is
    -- saved; the cursor is in physical pixels (scale).
    M.scale = 0.8
    button:GetScript("OnDragStart")(button)
    M.cursor = { 1700 * 0.8, (900 + 50) * 0.8 } -- straight above the centre
    button:GetScript("OnUpdate")(button, 0.01)
    p = { button:GetPoint(1) }
    H.checkTrue("moved to the top", close(p[4], 0) and close(p[5], r))
    H.check("not saved while dragging", ns.Config.Get("general", "minimapAngle"), 180)
    button:GetScript("OnDragStop")(button)
    H.check("stops following", button:GetScript("OnUpdate"), nil)
    H.check("saved on release", ns.Config.Get("general", "minimapAngle"), 90)
    M.scale = 1

    -- Left-click: options open and close.
    button:GetScript("OnClick")(button, "LeftButton")
    H.check("left-click opens the options", ns.Options.IsOpen(), true)
    button:GetScript("OnClick")(button, "LeftButton")
    H.check("again: closed", ns.Options.IsOpen(), false)

    -- Right-click: unlock, lock.
    button:GetScript("OnClick")(button, "RightButton")
    H.check("right-click unlocks", ns.Movers.IsUnlocked(), true)
    button:GetScript("OnClick")(button, "RightButton")
    H.check("again: locked", ns.Movers.IsUnlocked(), false)
    -- In combat unlocking is refused, as /fuf unlock.
    M.combat = true
    button:GetScript("OnClick")(button, "RightButton")
    H.check("combat: stays locked", ns.Movers.IsUnlocked(), false)
    H.check("combat: told why", M.chat[#M.chat]:find(ns.L.LOCKED_IN_COMBAT, 1, true) ~= nil, true)
    -- Options open in combat as with /fuf.
    button:GetScript("OnClick")(button, "LeftButton")
    H.check("combat: options open", ns.Options.IsOpen(), true)
    ns.Options.Close()
    M.SetCombat(false)

    -- Tooltip.
    button:GetScript("OnEnter")(button)
    H.check("tooltip owner", GameTooltip._owner, button)
    H.check("tooltip lines", table.concat(M.tooltipLines, "|"),
        "Forever Unit Frames|Left-click: options|Right-click: unlock/lock frames|Drag: move button")
    button:GetScript("OnLeave")(button)
    H.check("tooltip hidden", GameTooltip._owner, nil)

    -- Hidden in the settings.
    ns.Config.Set("general", "minimapShow", false)
    H.check("hidden", button:IsShown(), false)
    ns.Config.Set("general", "minimapShow", true)
    H.check("shown again", button:IsShown(), true)
end

-- LibDataBroker, when another addon provides it -----------------------------------------
do
    local objects = {}
    local ldb = { NewDataObject = function(_, name, obj) objects[name] = obj; return obj end }
    local function install()
        _G.LibStub = setmetatable({}, { __call = function(_, lib, silent)
            if lib == "LibDataBroker-1.1" then return ldb end
            if not silent then error("no " .. lib) end
        end })
    end
    local ns = H.LoadAddon()
    install()
    M.units.player = { name = "Me", health = 1, healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    local obj = objects["ForeverUnitFrames"]
    H.checkTrue("LDB launcher registered", obj)
    H.check("launcher type", obj and obj.type, "launcher")
    H.check("launcher icon", obj and obj.icon, "Interface\\AddOns\\ForeverUnitFrames\\Media\\MinimapIcon.tga")
    obj.OnClick(nil, "LeftButton")
    H.check("LDB left-click opens the options", ns.Options.IsOpen(), true)
    obj.OnClick(nil, "LeftButton")
    obj.OnClick(nil, "RightButton")
    H.check("LDB right-click unlocks", ns.Movers.IsUnlocked(), true)
    obj.OnClick(nil, "RightButton")
    local lines = {}
    obj.OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = text end })
    H.check("LDB tooltip", table.concat(lines, "|"),
        "Forever Unit Frames|Left-click: options|Right-click: unlock/lock frames")

    -- Without LibStub (the mock's default) nothing is registered and
    -- nothing fails.
    ns = H.LoadAddon()
    M.units.player = { name = "Me", health = 1, healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    local ok = pcall(M.FireEvent, "PLAYER_LOGIN")
    H.check("no LibStub: fine", ok, true)
end

-- The icon file: 64 x 64 TGA, round (transparent corners).
do
    local fh = assert(io.open(ADDONDIR .. "/Media/MinimapIcon.tga", "rb"))
    local d = fh:read("*a")
    fh:close()
    H.check("icon size", #d, 18 + 64 * 64 * 4)
    H.check("icon width", d:byte(13), 64)
    H.check("icon corner transparent", d:byte(18 + 4), 0)
    H.checkTrue("icon centre opaque", d:byte(18 + (32 * 64 + 32) * 4 + 4) > 200)
end
