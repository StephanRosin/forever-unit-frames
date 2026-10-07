-- Where the options live (menu review, 0.16.2): the text display options
-- in their own section, the tapped grey with the health colours, the pet
-- auras apart from the pet layout, the font section only fonts.
local ns = H.LoadAddon()
local function where(scope, key)
    for _, tab in ipairs(ns.Schema.Tabs(scope)) do
        for _, sec in ipairs(tab.sections or {}) do
            for _, k in ipairs(sec.keys or {}) do if k == key then return tab.id .. ":" .. sec.id end end
        end
    end
end
for _, key in ipairs({ "levelColorMode", "barNameColorMode", "infoClassColor", "textCompact", "showSurname" }) do
    H.check(key .. " in Text > Display", where("target", key), "text:display")
end
for _, key in ipairs({ "showSurname", "textCompact", "infoClassColor" }) do
    H.check(key .. " in General > Appearance > Display", where("general", key), "appearance:display")
end
for _, key in ipairs({ "fontFace", "fontSize", "valueFontSize", "fontOutline", "fontShadow" }) do
    H.check(key .. " in Text > Font", where("target", key), "text:font")
end
H.check("tapped grey with the health colours", where("target", "tapDenied"), "bars:health")
H.check("pet layout", where("party", "partyPetWidth"), "group:pets")
H.check("pet auras apart", where("party", "partyPetAuraMax"), "group:petAuras")
H.check("apply-font keys: fonts only", table.concat(ns.Settings.TEXT_STYLE_KEYS, ","),
    "fontFace,fontSize,valueFontSize,fontOutline,fontShadow")

-- The menu review (part 6): General's Display in the frame page's order;
-- the shield's place beside its color; the highlight color with Status.
local function keysOf(scope, tabId, secId)
    for _, tab in ipairs(ns.Schema.Tabs(scope)) do
        for _, sec in ipairs(tab.sections or {}) do
            if tab.id == tabId and sec.id == secId then return table.concat(sec.keys, ",") end
        end
    end
end
H.check("General > Display in the frame page's order", keysOf("general", "appearance", "display"),
    "infoClassColor,textCompact,showSurname")
H.check("General: shield place beside its color", keysOf("general", "bars", "absorbs"), "absorbMode,absorbColor")
H.check("General: highlight color in Status", where("general", "targetHighlightColor"), "status:highlights")

-- The restructure (decision 65): General like a frame's page. The
-- switches first (master and per frame), the look, the bars (Colors
-- folded in, with the textures), the status, the profile with the
-- minimap button.
local function tabIds(scope)
    local ids = {}
    for _, tab in ipairs(ns.Schema.Tabs(scope)) do ids[#ids + 1] = tab.id end
    return table.concat(ids, ",")
end
H.check("General tabs", tabIds("general"), "frames,appearance,bars,status,profile")
H.check("General: master switch in Frames", where("general", "unitFrames"), "frames:frames")
H.check("General: textures on Bars", keysOf("general", "bars", "textures"), "barTexture,backgroundColor,titleBackground")
H.check("General: Bars in a frame page's order", (function()
    for _, tab in ipairs(ns.Schema.Tabs("general")) do
        if tab.id == "bars" then
            local ids = {}
            for _, sec in ipairs(tab.sections) do ids[#ids + 1] = sec.id end
            return table.concat(ids, ",")
        end
    end
end)(), "health,textures,absorbs,healPrediction,powerColors")
H.check("General: health colors on Bars", where("general", "healthColorMode"), "bars:health")
H.check("General: minimap button with the profile", where("general", "minimapShow"), "profile:minimap")
H.check("General: no textures left in Appearance", keysOf("general", "appearance", "bars"), nil)

-- The restructure (decision 66) on the frame pages: the elite marker
-- with the raid marker on Status; the combat numbers on Text; the
-- corners in the border's section; the one-row highlights together; the
-- player's swords animation right after its status icon's combat switch
-- (the target's page keeps it with its combat icon).
local function sectionIds(scope, tabId)
    for _, tab in ipairs(ns.Schema.Tabs(scope)) do
        if tab.id == tabId then
            local ids = {}
            for _, sec in ipairs(tab.sections) do
                if #ns.Schema.SectionKeys(sec, scope) > 0 then ids[#ids + 1] = sec.id end
            end
            return table.concat(ids, ",")
        end
    end
end
local function shown(scope, tabId, secId)
    for _, tab in ipairs(ns.Schema.Tabs(scope)) do
        for _, sec in ipairs(tab.sections) do
            if tab.id == tabId and sec.id == secId then return table.concat(ns.Schema.SectionKeys(sec, scope), ",") end
        end
    end
end
H.check("target Layout", sectionIds("target", "layout"), "frame,size,position,barHeights,portrait,border,shadow")
H.check("elite marker after the raid marker", sectionIds("target", "status"):match("raidMarker,eliteMarker") ~= nil, true)
H.check("elite marker rows", shown("target", "status", "eliteMarker"),
    "eliteMarker,eliteMarkerStyle,eliteBorderSize,eliteMarkerFramePoint,eliteMarkerPoint,eliteMarkerX,eliteMarkerY")
H.check("combat numbers on Text", where("player", "combatFeedback"), "text:combatFeedback")
H.check("corners with the border", shown("target", "layout", "border"),
    "borderShow,borderStyle,borderSize,borderPadding,borderColor,cornerRadius")
H.check("General: corners with the border", keysOf("general", "appearance", "border"),
    "borderShow,borderStyle,borderSize,borderPadding,borderColor,cornerRadius")
H.check("party highlights", shown("party", "status", "highlights"),
    "threatGlow,targetHighlight,targetHighlightColor,targetHighlightSize,dispelHighlight")
H.check("player highlights", shown("player", "status", "highlights"), "threatGlow,dispelHighlight")
H.check("player: swords after the combat switch", shown("player", "status", "statusIcons"),
    "statusCombat,combatAnimation,statusResting,statusSize,statusFramePoint,statusPoint,statusX,statusY")
H.check("player: no combat icon section", shown("player", "status", "combatIcon"), "")
H.check("target: swords with the combat icon", shown("target", "status", "combatIcon"),
    "combatIcon,combatAnimation,combatIconSize,combatIconFramePoint,combatIconPoint,combatIconX,combatIconY")
H.check("target: status icons not there", shown("target", "status", "statusIcons"), "")
-- One "Display" in English: the Text tab's section reads apart from the
-- Layout tab's switch section.
H.checkTrue("two names", ns.L.SECTION_display ~= ns.L.SECTION_frame)
for code, t in pairs(ns.Locales) do
    H.checkTrue(code .. ": Text's section named apart from Layout's", t.SECTION_display ~= t.SECTION_frame)
end
