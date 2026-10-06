-- Raid layout and cell settings (Raid/Settings.lua): one value per raid
-- size, permanent codes, enums stored by index, defaults that give a
-- compact 10/20/40 layout. Raid.Scope knows the three sizes only.
local ns = H.LoadAddon()
local Raid, RS, RC = ns.Raid, ns.RaidSettings, ns.RaidConfig

local CODES = {
    groupBy = "GB", sortBy = "SO", blockDirection = "BD", blocksPerLine = "BL", cellGrowth = "CG",
    cellsPerLine = "CL", cellWidth = "CW", cellHeight = "CH", cellSpacing = "CS", blockSpacing = "BS",
    blockTitles = "BT", hideEmpty = "HE", panelBorder = "PB", blockBorder = "BB", cellBorder = "CB",
    healthColorMode = "HM", powerStrip = "PS", secondLine = "SL", nameClassColor = "NC",
}
for key, code in pairs(CODES) do
    local def = RS.Get(key)
    H.checkTrue(key .. " defined", def)
    if def then
        H.check(key .. " code", def.code, code)
        H.check(key .. " per size", RS.AppliesTo(def, "r40"), true)
        H.check(key .. " not character-wide", RS.AppliesTo(def, "general"), false)
    end
end

local function values(key) return table.concat(RS.Get(key).values, ",") end
H.check("grouping values", values("groupBy"), "GROUP,CLASS,ROLE,NONE")
H.check("sort values", values("sortBy"), "INDEX,NAME")
H.check("direction values", values("blockDirection"), "HORIZONTAL,VERTICAL")
H.check("growth values", values("cellGrowth"), "DOWN,RIGHT")
H.check("health colour values", values("healthColorMode"), "CLASS,STATIC,GRADIENT")
H.check("power strip values", values("powerStrip"), "ALL,MANA,HEALERS,OFF")
H.check("second line values", values("secondLine"), "DEFICIT,PERCENT,CURRENT,NONE")

RC.Use({})
local DEFAULTS = {
    groupBy = "GROUP", sortBy = "INDEX", blockDirection = "HORIZONTAL", blocksPerLine = 8, cellGrowth = "DOWN",
    cellsPerLine = 5, cellSpacing = 2, blockSpacing = 6, blockTitles = false, hideEmpty = true,
    panelBorder = true, blockBorder = false, cellBorder = false, healthColorMode = "CLASS",
    powerStrip = "MANA", secondLine = "DEFICIT", nameClassColor = false,
}
for key, want in pairs(DEFAULTS) do
    H.check(key .. " default", RC.Get("r20", key), want)
end
-- Cells: 80 x 38 at 40, a bit larger at 20 and 10.
H.check("cell width 10", RC.Get("r10", "cellWidth"), 96)
H.check("cell height 10", RC.Get("r10", "cellHeight"), 44)
H.check("cell width 20", RC.Get("r20", "cellWidth"), 88)
H.check("cell height 20", RC.Get("r20", "cellHeight"), 40)
H.check("cell width 40", RC.Get("r40", "cellWidth"), 80)
H.check("cell height 40", RC.Get("r40", "cellHeight"), 38)
H.check("cell width clamped", RS.Validate(RS.Get("cellWidth"), 5), 30)
H.check("blocks per line at most the class count", RS.Get("blocksPerLine").max, 9)

-- Codes are unique within the raid registry and none of R1's changed.
local seen = {}
for _, def in ipairs(RS.All()) do
    H.check("unique code " .. def.code, seen[def.code], nil)
    seen[def.code] = true
end
H.check("R1 codes kept", RS.Get("sizeMode").code .. RS.Get("x").code .. RS.Get("y").code, "SMXY")

-- A size exports with its layout; enums by index.
RC.Set("r10", "groupBy", "ROLE")
RC.Set("r10", "cellWidth", 120)
H.check("export", ns.RaidProfiles.Export(10), "1;aCW120;aGB3")

-- Raid.Scope: the three sizes, nothing else.
H.check("scope 40", Raid.Scope(40), "r40")
H.checkError("scope of an unknown size", function() Raid.Scope(25) end)
H.checkError("scope of nil", function() Raid.Scope(nil) end)
