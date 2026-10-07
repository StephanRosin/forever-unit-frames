-- The raid frames' own minimap button (Raid/MinimapButton.lua): its own
-- icon, angle and switch in the raid profile's General settings, dragged
-- around the minimap like the unit frames' button; a left click opens or
-- closes the raid options window. Blizzard's addon compartment gets an
-- entry for the raid window as well.
local M = H.M

local function boot()
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local function close(a, b) return math.abs(a - b) < 1e-6 end

-- Settings: the character's own, on the General tab.
do
    local ns = H.LoadAddon()
    local RS = ns.RaidSettings
    for key, code in pairs({ minimapShow = "MS", minimapAngle = "MA" }) do
        local def = RS.Get(key)
        H.check("code of " .. key, def.code, code)
        H.checkTrue(key .. " character-wide", RS.AppliesTo(def, "general"))
        H.check(key .. " not per size", RS.AppliesTo(def, "r10"), false)
    end
    H.check("shown by default", RS.Default(RS.Get("minimapShow"), "general"), true)
    H.check("default angle: below the unit frames' button", RS.Default(RS.Get("minimapAngle"), "general"), 260)
    H.check("angle range", RS.Get("minimapAngle").min .. "-" .. RS.Get("minimapAngle").max, "0-359")
    local general = ns.RaidSchema.TABS[1]
    H.check("minimap section", general.sections[2].id, "minimap")
    H.check("section keys", table.concat(general.sections[2].keys, ","), "minimapShow,minimapAngle")
    H.check("section title", ns.RaidSchema.SectionTitle("minimap"), "Minimap button")
end

-- The button.
do
    local ns = boot()
    local RC, RO = ns.RaidConfig, ns.RaidOptions
    local button = ns.RaidMinimapButton.button
    H.checkTrue("button built", button)
    H.check("its name", button:GetName(), "ForeverUnitFramesRaidMinimapButton")
    H.check("on the minimap", button:GetParent(), Minimap)
    H.check("not the unit frames' button", button ~= ns.MinimapButton.button, true)
    H.check("not secure", button._template, nil)
    H.checkTrue("shown", button:IsShown())
    H.check("its own icon", button.icon._texture, "Interface\\AddOns\\ForeverUnitFrames\\Media\\RaidMinimapIcon.tga")
    H.check("tracking border", button.border._texture, "Interface\\Minimap\\MiniMap-TrackingBorder")
    H.check("left clicks only", table.concat(button._clicks, ","), "LeftButtonUp")

    -- On the circle at its own angle; a square minimap squares it off.
    local r = 70 + 5
    local p = { button:GetPoint(1) }
    H.check("centred on the minimap", p[1] .. p[2]:GetName() .. p[3], "CENTERMinimapCENTER")
    H.checkTrue("round: x", close(p[4], math.cos(math.rad(260)) * r))
    H.checkTrue("round: y", close(p[5], math.sin(math.rad(260)) * r))
    _G.GetMinimapShape = function() return "SQUARE" end
    RC.Set("general", "minimapAngle", 180)
    p = { button:GetPoint(1) }
    H.checkTrue("square, left: x", close(p[4], -r))
    _G.GetMinimapShape = nil
    Minimap:SetSize(200, 200)
    p = { button:GetPoint(1) }
    H.checkTrue("resized minimap: on the new edge", close(p[4], -(100 + 5)))
    Minimap:SetSize(140, 140)

    -- Dragging saves its own angle; the unit frames' stays.
    button:GetScript("OnDragStart")(button)
    M.cursor = { 1700, 900 + 50 }
    button:GetScript("OnUpdate")(button, 0.01)
    button:GetScript("OnDragStop")(button)
    H.check("its angle saved", RC.Get("general", "minimapAngle"), 90)
    H.check("in the raid profile", RC.Profile().general.minimapAngle, 90)
    H.check("the unit frames' button keeps its angle", ns.Config.Get("general", "minimapAngle"), 225)

    -- Left-click: the raid window opens and closes; in combat it opens, locked.
    button:GetScript("OnClick")(button, "LeftButton")
    H.checkTrue("opens the raid window", RO.IsOpen())
    H.check("not the unit window", ns.Options.IsOpen(), false)
    button:GetScript("OnClick")(button, "LeftButton")
    H.check("again: closed", RO.IsOpen(), false)
    M.combat = true
    M.FireEvent("PLAYER_REGEN_DISABLED")
    button:GetScript("OnClick")(button, "LeftButton")
    H.checkTrue("combat: opens", RO.IsOpen())
    H.checkTrue("combat: locked", RO.combatNotice:IsShown())
    RO.Close()
    M.SetCombat(false)

    -- Tooltip.
    button:GetScript("OnEnter")(button)
    H.check("tooltip lines", table.concat(M.tooltipLines, "|"),
        "Forever Unit Frames: raid frames|Left-click: raid frame options|Drag: move button")
    button:GetScript("OnLeave")(button)
    H.check("tooltip hidden", GameTooltip._owner, nil)

    -- Hidden in the raid settings; the unit frames' button stays.
    RC.Set("general", "minimapShow", false)
    H.check("hidden", button:IsShown(), false)
    H.checkTrue("unit frames' button still shown", ns.MinimapButton.button:IsShown())
    RC.Set("general", "minimapShow", true)
    H.check("shown again", button:IsShown(), true)

    -- The addon compartment: an entry of its own for the raid window.
    local entries = AddonCompartmentFrame.registeredAddons
    H.check("one entry", #entries, 1)
    local entry = entries[1]
    H.check("entry text", entry.text, "Forever Unit Frames: raid frames")
    H.check("entry icon", entry.icon, "Interface\\AddOns\\ForeverUnitFrames\\Media\\RaidMinimapIcon.tga")
    entry.func()
    H.checkTrue("entry opens the raid window", RO.IsOpen())
    entry.func()
    H.check("entry again: closed", RO.IsOpen(), false)
    local row = CreateFrame("Button", nil, UIParent)
    entry.funcOnEnter(row)
    H.check("entry tooltip", table.concat(M.tooltipLines, "|"), "Forever Unit Frames: raid frames|Left-click: raid frame options")
    entry.funcOnLeave(row)
    H.check("entry tooltip hidden", GameTooltip._owner, nil)

    -- /fuf raid takes the same way.
    ns.Commands.ToggleRaidOptions()
    H.checkTrue("toggle opens", RO.IsOpen())
    ns.Commands.ToggleRaidOptions()
    H.check("toggle closes", RO.IsOpen(), false)
    H.check("nothing blocked", #M.blocked, 0)
end

-- Without the compartment (another client) nothing fails.
do
    local ns = H.LoadAddon()
    _G.AddonCompartmentFrame = nil
    M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    local ok = pcall(M.FireEvent, "PLAYER_LOGIN")
    H.check("no compartment: fine", ok, true)
    H.checkTrue("button anyway", ns.RaidMinimapButton.button)
end

-- The icon file: 64 x 64 TGA, round (transparent corners).
do
    local fh = assert(io.open(ADDONDIR .. "/Media/RaidMinimapIcon.tga", "rb"))
    local d = fh:read("*a")
    fh:close()
    H.check("icon size", #d, 18 + 64 * 64 * 4)
    H.check("icon width", d:byte(13), 64)
    H.check("icon corner transparent", d:byte(18 + 4), 0)
    H.checkTrue("icon centre opaque", d:byte(18 + (32 * 64 + 32) * 4 + 4) > 200)
    local toc = H.ReadFile("ForeverUnitFrames.toc")
    H.checkTrue("toc lists the raid button after the raid window",
        toc:find("Raid\\Options\\Window.lua\nRaid\\MinimapButton.lua", 1, true))
end
