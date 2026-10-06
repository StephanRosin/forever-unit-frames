-- Raid debuff and corner indicator settings (Raid/Settings.lua): one value
-- per raid size, permanent codes, enums stored by index. An indicator's
-- spells are a text of spell IDs, checked when it is set.
local ns = H.LoadAddon()
local Raid, RS, RC = ns.Raid, ns.RaidSettings, ns.RaidConfig

local CODES = {
    dispelIcon = "DI", dispelFilter = "DF", dispelIconSize = "DZ", dispelTint = "DT",
    debuffRow = "DR", debuffCount = "DC", debuffSize = "DS",
}
for _, ind in ipairs(Raid.INDICATORS) do
    local key = "indicator" .. ind.name
    CODES[key .. "Spells"] = ind.letter .. "S"
    CODES[key .. "Color"] = ind.letter .. "C"
    CODES[key .. "Size"] = ind.letter .. "Z"
    CODES[key .. "Own"] = ind.letter .. "O"
    CODES[key .. "Time"] = ind.letter .. "M"
end
for key, code in pairs(CODES) do
    local def = RS.Get(key)
    H.checkTrue(key .. " defined", def)
    if def then
        H.check(key .. " code", def.code, code)
        H.check(key .. " per size", RS.AppliesTo(def, "r20"), true)
        H.check(key .. " not character-wide", RS.AppliesTo(def, "general"), false)
    end
end

-- Five positions: the four corners and the top centre.
local points = {}
for _, ind in ipairs(Raid.INDICATORS) do points[#points + 1] = ind.point end
H.check("positions", table.concat(points, ","), "TOPLEFT,TOPRIGHT,BOTTOMLEFT,BOTTOMRIGHT,TOP")
H.check("names", Raid.INDICATORS[1].name .. Raid.INDICATORS[5].name, "TopLeftTop")

local function values(key) return table.concat(RS.Get(key).values, ",") end
H.check("dispel filter values", values("dispelFilter"), "MINE,ALL")
H.check("time values", values("indicatorTopLeftTime"), "SWIPE,NUMBER,NONE")

RC.Use({})
local DEFAULTS = {
    dispelIcon = true, dispelFilter = "MINE", dispelTint = false, debuffRow = false, debuffCount = 3,
    indicatorTopLeftSpells = "", indicatorTopLeftSize = 8, indicatorTopLeftOwn = true,
    indicatorTopLeftTime = "SWIPE", indicatorTopSpells = "",
}
for key, want in pairs(DEFAULTS) do
    H.check(key .. " default", RC.Get("r40", key), want)
end
H.check("dispel icon 10", RC.Get("r10", "dispelIconSize"), 20)
H.check("dispel icon 20", RC.Get("r20", "dispelIconSize"), 18)
H.check("dispel icon 40", RC.Get("r40", "dispelIconSize"), 16)
H.check("debuff size 10", RC.Get("r10", "debuffSize"), 14)
H.check("debuff size 40", RC.Get("r40", "debuffSize"), 12)
H.check("top left green", RC.Get("r40", "indicatorTopLeftColor")[2], 0.9)
H.check("bottom right red", RC.Get("r40", "indicatorBottomRightColor")[1], 1)

-- Spell lists: IDs separated by commas or spaces.
H.check("list", table.concat(Raid.SpellList("139, 6074 6075,,10927"), " "), "139 6074 6075 10927")
H.check("empty list", #Raid.SpellList("  "), 0)
H.check("a name is not a list", Raid.SpellList("Renew"), nil)
H.check("zero is no spell", Raid.SpellList("0"), nil)
H.check("no fractions", Raid.SpellList("139.5"), nil)
H.check("no signs", Raid.SpellList("-139"), nil)
H.checkTrue("stored", RC.Set("r40", "indicatorTopLeftSpells", " 139, 6074 "))
H.check("stored trimmed", RC.Get("r40", "indicatorTopLeftSpells"), "139, 6074")
H.check("a name is refused", RC.Set("r40", "indicatorTopLeftSpells", "Renew"), false)
H.check("refused: kept", RC.Get("r40", "indicatorTopLeftSpells"), "139, 6074")
local long = string.rep("12345,", 33)
H.check("room for many ranks", RC.Set("r40", "indicatorTopSpells", long:sub(1, -2)), true)
H.check("but not without end", RC.Set("r40", "indicatorTopSpells", long .. long), false)
-- The unit frames' free texts are not checked.
H.check("unit-frame text: no check", ns.Settings.Get("rangeFriendlySpell").check, nil)
H.check("unit-frame text: names stay", ns.Settings.Validate(ns.Settings.Get("rangeFriendlySpell"), "Renew"), "Renew")

-- Codes are unique within the raid registry; a size exports its lists.
local seen = {}
for _, def in ipairs(RS.All()) do
    H.check("unique code " .. def.code, seen[def.code], nil)
    seen[def.code] = true
end
RC.Set("r10", "indicatorTopRightSpells", "774,1058")
RC.Set("r10", "dispelFilter", "ALL")
H.check("export", ns.RaidProfiles.Export(10), "1;aDF2;aKS'774,1058")
local decoded = ns.RaidCodec.Decode(ns.RaidProfiles.Export(10))
H.check("decoded", decoded.r10.indicatorTopRightSpells, "774,1058")
