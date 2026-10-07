local ns = H.LoadAddon()
local S, Settings, L = ns.Schema, ns.Settings, ns.L

-- What a page shows, key -> how often (Schema.SectionKeys: a key of
-- section.with only where its named key applies too).
local function keysOf(tabs, scope)
    local seen = {}
    for _, tab in ipairs(tabs) do
        for _, sec in ipairs(tab.sections or {}) do
            for _, key in ipairs(sec.keys) do H.checkTrue("known key " .. key, Settings.Get(key)) end
            for _, key in ipairs(S.SectionKeys(sec, scope)) do seen[key] = (seen[key] or 0) + 1 end
            H.checkTrue("section label " .. sec.id, L["SECTION_" .. sec.id] ~= "SECTION_" .. sec.id)
        end
        H.checkTrue("tab label " .. tab.id, L["TAB_" .. tab.id] ~= "TAB_" .. tab.id)
    end
    return seen
end

local general = keysOf(S.GENERAL, "general")
local FRAMES = { "player", "target", "targettarget", "pet", "focus", "party" }
local frame = {}
for _, scope in ipairs(FRAMES) do frame[scope] = keysOf(S.FRAME, scope) end
for _, def in ipairs(Settings.All()) do
    if Settings.AppliesTo(def, "general") and not def.inNav then
        H.check("general shows " .. def.key .. " once", general[def.key], 1)
    end
    for _, scope in ipairs(FRAMES) do
        if Settings.AppliesTo(def, scope) then
            H.check(scope .. " page shows " .. def.key .. " once", frame[scope][def.key], 1)
        end
    end
    if def.type == "enum" then
        for _, v in ipairs(def.values) do
            local text = S.EnumText(def, v)
            H.checkTrue("enum label " .. def.key .. "." .. v, not text:match("^ENUM_"))
        end
    end
end

H.check("general has a status tab for the range spells", S.Tabs("general")[4].id, "status")
H.check("general has profile tab", S.Tabs("general")[5].id, "profile")
H.check("frame tab count", #S.Tabs("player"), 6)
H.check("status tab before the castbar tab", S.Tabs("player")[5].id, "status")
H.check("castbar tab on frames with a castbar", S.Tabs("player")[6].id, "castbar")
H.check("no castbar tab for the pet", #S.Tabs("pet"), 5)
H.check("key-specific enum text wins", S.EnumText(Settings.Get("buffsAnchor"), "OTHER"), "Debuffs")
H.check("the same NONE for every text", S.EnumText(Settings.Get("textHealthLeft"), "NONE"), "None")
