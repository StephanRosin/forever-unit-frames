local ns = H.LoadAddon()
local S, Settings, L = ns.Schema, ns.Settings, ns.L

local function keysOf(tabs)
    local seen = {}
    for _, tab in ipairs(tabs) do
        for _, sec in ipairs(tab.sections or {}) do
            for _, key in ipairs(sec.keys) do
                H.checkTrue("known key " .. key, Settings.Get(key))
                seen[key] = (seen[key] or 0) + 1
            end
            H.checkTrue("section label " .. sec.id, L["SECTION_" .. sec.id] ~= "SECTION_" .. sec.id)
        end
        H.checkTrue("tab label " .. tab.id, L["TAB_" .. tab.id] ~= "TAB_" .. tab.id)
    end
    return seen
end

local general, frame = keysOf(S.GENERAL), keysOf(S.FRAME)
for _, def in ipairs(Settings.All()) do
    if Settings.AppliesTo(def, "general") then
        H.check("general shows " .. def.key .. " once", general[def.key], 1)
    end
    if Settings.AppliesTo(def, "player") then
        H.check("frame shows " .. def.key .. " once", frame[def.key], 1)
    end
    if def.type == "enum" then
        for _, v in ipairs(def.values) do
            local text = S.EnumText(def, v)
            H.checkTrue("enum label " .. def.key .. "." .. v, not text:match("^ENUM_"))
        end
    end
end

H.check("general has profile tab", S.Tabs("general")[3].id, "profile")
H.check("frame tab count", #S.Tabs("player"), 4)
H.check("castbar tab on frames with a castbar", S.Tabs("player")[4].id, "castbar")
H.check("no castbar tab for the pet", #S.Tabs("pet"), 3)
H.check("key-specific enum text wins", S.EnumText(Settings.Get("textHealthLeft"), "NONE"), "Empty")
