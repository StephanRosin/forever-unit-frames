local ns = H.LoadAddon()
local S, C, Codec, L, Schema = ns.Settings, ns.Config, ns.Codec, ns.L, ns.Schema
C.Use({})

local FRAMES = { "player", "target", "targettarget", "pet", "focus", "party" }
local SUFFIXES = { "Enabled", "OnlyMine", "ShowTime", "Anchor", "FramePoint", "Point", "X", "Y", "Growth",
    "RowGrowth", "Size", "Spacing", "PerRow", "Max" }

-- The permanent codes: J = buffs, D = debuffs, the second letter the setting.
local CODES = { Enabled = "E", OnlyMine = "M", ShowTime = "T", Anchor = "A", FramePoint = "F", Point = "O",
    X = "X", Y = "Y", Growth = "G", RowGrowth = "R", Size = "S", Spacing = "D", PerRow = "N", Max = "C" }
for _, group in ipairs({ { "buffs", "J" }, { "debuffs", "D" } }) do
    for _, suffix in ipairs(SUFFIXES) do
        local def = S.Get(group[1] .. suffix)
        H.checkTrue("defined " .. group[1] .. suffix, def)
        if def then
            H.check("code " .. def.key, def.code, group[2] .. CODES[suffix])
            H.check("frame scope " .. def.key, def.scope, "frame")
            for _, scope in ipairs(FRAMES) do
                H.checkTrue(def.key .. " applies to " .. scope, S.AppliesTo(def, scope))
            end
            H.check(def.key .. " not general", S.AppliesTo(def, "general"), false)
        end
    end
end
H.check("dispellable code", S.Get("debuffsDispellable").code, "DV")
H.check("no dispellable for buffs", S.Get("buffsDispellable"), nil)

-- Enum orders are permanent.
H.check("points", table.concat(S.Get("buffsPoint").values, ","),
    "TOPLEFT,TOP,TOPRIGHT,LEFT,CENTER,RIGHT,BOTTOMLEFT,BOTTOM,BOTTOMRIGHT")
H.check("anchors", table.concat(S.Get("debuffsAnchor").values, ","), "FRAME,HEALTH,POWER,CASTBAR,OTHER")
H.check("directions", table.concat(S.Get("buffsGrowth").values, ","), "RIGHT,LEFT,UP,DOWN")
H.check("row directions", table.concat(S.Get("buffsRowGrowth").values, ","), "RIGHT,LEFT,UP,DOWN")

-- Defaults: debuffs above the frame, buffs above the debuffs; party
-- auras to the right of each member; player buffs off (Blizzard's buff
-- frame shows them).
H.check("player buffs off", C.Get("player", "buffsEnabled"), false)
H.check("player debuffs on", C.Get("player", "debuffsEnabled"), true)
H.check("target buffs on", C.Get("target", "buffsEnabled"), true)
H.check("tot debuffs off", C.Get("targettarget", "debuffsEnabled"), false)
H.check("party buffs only mine", C.Get("party", "buffsOnlyMine"), true)
H.check("target debuffs anchor", C.Get("target", "debuffsAnchor"), "FRAME")
H.check("target debuffs frame point", C.Get("target", "debuffsFramePoint"), "TOPLEFT")
H.check("target debuffs point", C.Get("target", "debuffsPoint"), "BOTTOMLEFT")
H.check("target buffs on debuffs", C.Get("target", "buffsAnchor"), "OTHER")
H.check("target rows up", C.Get("target", "debuffsRowGrowth"), "UP")
H.check("party debuffs right", C.Get("party", "debuffsFramePoint"), "TOPRIGHT")
H.check("party rows down", C.Get("party", "buffsRowGrowth"), "DOWN")
H.check("party icon size", C.Get("party", "debuffsSize"), 18)
H.check("target icon size", C.Get("target", "buffsSize"), 20)
H.check("focus per row: Auto", C.Get("focus", "debuffsPerRow"), 0)
H.check("dispellable off", C.Get("target", "debuffsDispellable"), false)

-- Ranges.
H.check("size clamp", S.Validate(S.Get("buffsSize"), 100), 64)
H.check("max clamp", S.Validate(S.Get("debuffsMax"), 0), 1)
H.check("offset clamp", S.Validate(S.Get("buffsX"), -999), -200)

-- Codec: aura overrides round-trip and stay compact.
C.Set("target", "buffsPoint", "TOPRIGHT")
C.Set("target", "debuffsY", -12)
C.Set("party", "debuffsDispellable", true)
local s = Codec.Encode(C.Profile())
H.check("encoded", s, "1;tDY-12;tJO3;yDV1")
local back = Codec.Decode(s)
H.check("decoded point", back.target.buffsPoint, "TOPRIGHT")
H.check("decoded dispellable", back.party.debuffsDispellable, true)

-- Budget: every aura setting of two frames changed.
C.ResetAll()
for _, scope in ipairs({ "target", "party" }) do
    for _, g in ipairs({ "buffs", "debuffs" }) do
        C.Set(scope, g .. "Enabled", not C.Get(scope, g .. "Enabled"))
        C.Set(scope, g .. "OnlyMine", not C.Get(scope, g .. "OnlyMine"))
        C.Set(scope, g .. "ShowTime", false)
        C.Set(scope, g .. "Anchor", "HEALTH")
        C.Set(scope, g .. "FramePoint", "BOTTOMRIGHT")
        C.Set(scope, g .. "Point", "CENTER")
        C.Set(scope, g .. "X", -123); C.Set(scope, g .. "Y", 45)
        C.Set(scope, g .. "Growth", "LEFT"); C.Set(scope, g .. "RowGrowth", "RIGHT")
        C.Set(scope, g .. "Size", 33); C.Set(scope, g .. "Spacing", 5)
        C.Set(scope, g .. "PerRow", 12); C.Set(scope, g .. "Max", 24)
    end
    C.Set(scope, "debuffsDispellable", true)
end
local size = #Codec.Encode(C.Profile())
H.checkTrue("all aura settings of two frames under 400 chars (" .. size .. ")", size < 400)

-- Options: an Auras tab between Text and Castbar, Buffs and Debuffs sections.
local tabs = Schema.Tabs("target")
H.check("auras tab", tabs[4].id, "auras")
H.check("auras sections", tabs[4].sections[1].id .. "," .. tabs[4].sections[2].id, "buffs,debuffs")
H.check("pet has auras", Schema.Tabs("pet")[4].id, "auras")
H.check("tab label", L.TAB_auras, "Auras")
H.check("other group label (buffs)", Schema.EnumText(S.Get("buffsAnchor"), "OTHER"), "Debuffs")
H.check("other group label (debuffs)", Schema.EnumText(S.Get("debuffsAnchor"), "OTHER"), "Buffs")
H.check("point label", Schema.EnumText(S.Get("buffsPoint"), "BOTTOMRIGHT"), "Bottom right")
