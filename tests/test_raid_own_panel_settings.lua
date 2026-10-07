-- Own panels' settings (Raid/Settings.lua, Raid.OWN_PANELS): nine slots,
-- "Panel 2" to "Panel 10", each per raid size: shown, its grouping, the
-- blocks it takes, a title, its own layout and its position. Permanent
-- codes, unique in the raid registry; none by default.
local ns = H.LoadAddon()
local Raid, RS, RC = ns.Raid, ns.RaidSettings, ns.RaidConfig
RC.Use({})

H.check("nine slots", #Raid.OWN_PANELS, 9)
H.check("the first is panel 2", Raid.OWN_PANELS[1].id .. Raid.OWN_PANELS[1].number, "panel22")
H.check("the last is panel 10", Raid.OWN_PANELS[9].id, "panel10")
H.check("by id", Raid.OwnPanel("panel5").number, 5)
H.check("unknown id", Raid.OwnPanel("panel11"), nil)

local PARTS = "Show,GroupBy,Blocks,Title,BlockDirection,BlocksPerLine,CellGrowth,CellsPerLine,BlockTitles,"
    .. "HideEmpty,PanelBorder,BlockBorder,X,Y"
local keys = {}
for i, key in ipairs(Raid.OWN_PANELS[1].keys) do keys[i] = key:gsub("^panel2", "") end
local parts = {}
for i, entry in ipairs(Raid.OWN_PANEL_PARTS) do parts[i] = entry.part end
H.check("the parts listed", table.concat(parts, ","), PARTS)
H.check("like the main panel", Raid.OWN_PANEL_PARTS[5].like, "blockDirection")
H.check("a slot's settings in order", table.concat(keys, ","), PARTS)

-- Codes: the slot's letter, then the setting's.
local SLOT_LETTERS = { "A", "F", "L", "N", "P", "M", "J", "K", "U" }
local PART_LETTERS = { Show = "E", GroupBy = "G", Blocks = "K", Title = "T", BlockDirection = "D", BlocksPerLine = "L",
    CellGrowth = "R", CellsPerLine = "N", BlockTitles = "U", HideEmpty = "Q", PanelBorder = "W", BlockBorder = "V",
    X = "X", Y = "Y" }
for i, p in ipairs(Raid.OWN_PANELS) do
    for part, letter in pairs(PART_LETTERS) do
        local def = RS.Get(p.id .. part)
        H.check(p.id .. part .. " code", def and def.code, SLOT_LETTERS[i] .. letter)
        H.check(p.id .. part .. " per size", def and RS.AppliesTo(def, "r20"), true)
        H.check(p.id .. part .. " not character-wide", def and RS.AppliesTo(def, "general"), false)
    end
end
local seen = {}
for _, def in ipairs(RS.All()) do
    H.check("unique code " .. def.code, seen[def.code], nil)
    seen[def.code] = true
end

-- Defaults: off, by group, no blocks, no title; the main panel's layout.
local DEFAULTS = { Show = false, GroupBy = "GROUP", Blocks = "", Title = "", BlockDirection = "HORIZONTAL",
    BlocksPerLine = 8, CellGrowth = "DOWN", CellsPerLine = 5, BlockTitles = false, HideEmpty = true,
    PanelBorder = true, BlockBorder = false }
for part, want in pairs(DEFAULTS) do
    for _, size in ipairs(Raid.SIZES) do
        H.check("panel7" .. part .. " default at " .. size, RC.Get(Raid.Scope(size), "panel7" .. part), want)
    end
end
H.check("grouping choices", table.concat(RS.Get("panel3GroupBy").values, ","), "GROUP,CLASS,ROLE")
H.check("direction: the main panel's list", RS.Get("panel3BlockDirection").values, RS.Get("blockDirection").values)
H.check("growth: the main panel's list", RS.Get("panel3CellGrowth").values, RS.Get("cellGrowth").values)
H.check("cells per line: the main panel's range", RS.Get("panel3CellsPerLine").max, RS.Get("cellsPerLine").max)
H.check("blocks per line: the main panel's range", RS.Get("panel3BlocksPerLine").max, RS.Get("blocksPerLine").max)
-- Each slot a spot of its own, so two new panels never lie on each other.
local spots = {}
for _, p in ipairs(Raid.OWN_PANELS) do
    local spot = RC.Get("r10", p.id .. "X") .. "," .. RC.Get("r10", p.id .. "Y")
    H.check("own spot " .. p.id, spots[spot], nil)
    spots[spot] = true
end

-- The blocks: group numbers, class tokens or roles, comma-separated, each
-- once; stored as written.
local function stored(text)
    RC.Set("r10", "panel2Blocks", "")
    RC.Set("r10", "panel2Blocks", text)
    return RC.Get("r10", "panel2Blocks")
end
H.check("groups", stored("1,2"), "1,2")
H.check("a role", stored("HEALER"), "HEALER")
H.check("classes", stored("PRIEST,DRUID"), "PRIEST,DRUID")
H.check("group 8", stored("8"), "8")
H.check("no group 9", stored("9"), "")
H.check("no group 0", stored("0"), "")
H.check("no unknown token", stored("MONK"), "")
H.check("no lower case", stored("healer"), "")
H.check("none twice", stored("1,1"), "")
H.check("no rest of the raid", stored("NONE"), "")
H.check("parsed", table.concat(Raid.ParseBlockList("3, TANK ,MAGE"), "|"), "3|TANK|MAGE")
H.check("empty: none", #Raid.ParseBlockList(""), 0)
H.check("refused: nil", Raid.ParseBlockList("X"), nil)

-- A title is free text, at most Raid.OWN_TITLE_LETTERS long.
RC.Set("r10", "panel2Title", "Healers")
H.check("title", RC.Get("r10", "panel2Title"), "Healers")
RC.Set("r10", "panel2Title", ("x"):rep(Raid.OWN_TITLE_LETTERS + 1))
H.check("too long refused", RC.Get("r10", "panel2Title"), "Healers")

-- Per size: another size keeps its own.
RC.Set("r20", "panel2Show", true)
H.check("20 shows it", RC.Get("r20", "panel2Show"), true)
H.check("10 does not", RC.Get("r10", "panel2Show"), false)

-- A size exports and imports with its panels.
RC.Set("r20", "panel2Blocks", "3,4")
local text = ns.RaidCodec.Encode(RC.Profile(), { "r20" })
H.checkTrue("exported: shown", text:find("bAE1", 1, true))
H.checkTrue("exported: blocks", text:find("bAK'3,4", 1, true))
local decoded = ns.RaidCodec.Decode(text)
H.check("read back", decoded.r20.panel2Blocks, "3,4")
