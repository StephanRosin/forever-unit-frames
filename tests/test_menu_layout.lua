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
