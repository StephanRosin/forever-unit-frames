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
local FRAMES = { "player", "target", "targettarget", "pet", "focus", "party" }
for _, def in ipairs(Settings.All()) do
    if Settings.AppliesTo(def, "general") and not def.inNav then
        H.check("general shows " .. def.key .. " once", general[def.key], 1)
    end
    for _, scope in ipairs(FRAMES) do
        if Settings.AppliesTo(def, scope) then
            H.check(scope .. " page shows " .. def.key .. " once", frame[def.key], 1)
        end
    end
    if def.type == "enum" then
        for _, v in ipairs(def.values) do
            local text = S.EnumText(def, v)
            H.checkTrue("enum label " .. def.key .. "." .. v, not text:match("^ENUM_"))
        end
    end
end

H.check("general has profile tab", S.Tabs("general")[3].id, "profile")
H.check("frame tab count", #S.Tabs("player"), 6)
H.check("status tab before the castbar tab", S.Tabs("player")[5].id, "status")
H.check("castbar tab on frames with a castbar", S.Tabs("player")[6].id, "castbar")
H.check("no castbar tab for the pet", #S.Tabs("pet"), 5)
H.check("key-specific enum text wins", S.EnumText(Settings.Get("textHealthLeft"), "NONE"), "Empty")
