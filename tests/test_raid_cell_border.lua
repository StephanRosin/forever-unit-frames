-- The raid cell's border and corners (Raid/Settings.lua, Raid/Cell.lua):
-- the ring around each cell (switched on the Cell tab now) in its own
-- style, thickness and colour, and the cell's corner radius, per raid
-- size. The party frame's border does not count. The radius starts
-- small, smaller as the raid grows.
local M = H.M
local ns = H.LoadAddon()
local RC, C, RS, Header = ns.RaidConfig, ns.Config, ns.RaidSettings, ns.RaidHeader
C.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

-- The settings, per size, at today's look.
local function default(key)
    local v = RS.Default(RS.Get(key), "r10")
    if type(v) == "table" then return table.concat(v, " ") end
    return v
end
H.check("style", default("cellBorderStyle"), "GOLD")
H.check("style choices: the unit frames'", table.concat(RS.Get("cellBorderStyle").values, ","), "FLAT,GOLD")
H.check("thickness", default("cellBorderSize"), 1)
H.check("colour", default("cellBorderColor"), "0 0 0 1")
H.check("corner radius", default("cellCornerRadius"), 4)
H.check("corner radius, 20", RS.Default(RS.Get("cellCornerRadius"), "r20"), 3)
H.check("corner radius, 40", RS.Default(RS.Get("cellCornerRadius"), "r40"), 2)
local codes = {}
for i, key in ipairs({ "cellBorderStyle", "cellBorderSize", "cellBorderColor", "cellCornerRadius" }) do
    codes[i] = RS.Get(key).code
end
H.check("codes", table.concat(codes, " "), "CY CZ CK CR")

-- The cell asks the raid profile; the ring hugs the cell.
H.check("cell style", C.Get("raid", "borderStyle"), "GOLD")
H.check("cell thickness", C.Get("raid", "borderSize"), 1)
H.check("cell radius", C.Get("raid", "cornerRadius"), 4)
H.check("no padding", C.Get("raid", "borderPadding"), 0)
C.Set("party", "borderStyle", "FLAT")
C.Set("party", "cornerRadius", 6)
C.Set("party", "borderPadding", 4)
H.check("not the party frame's style", C.Get("raid", "borderStyle"), "GOLD")
C.Set("party", "cornerRadius", 3)
H.check("not the party frame's radius", C.Get("raid", "cornerRadius"), 4)
H.check("not the party frame's padding", C.Get("raid", "borderPadding"), 0)
RC.Set("r10", "cellBorderStyle", "FLAT")
RC.Set("r10", "cellBorderSize", 3)
RC.Set("r10", "cellBorderColor", { 0.5, 0, 0, 1 })
RC.Set("r10", "cellCornerRadius", 4)
H.check("style follows", C.Get("raid", "borderStyle"), "FLAT")
H.check("thickness follows", C.Get("raid", "borderSize"), 3)
H.check("colour follows", C.Get("raid", "borderColor")[1], 0.5)
H.check("radius follows", C.Get("raid", "cornerRadius"), 4)
RC.ResetScope("r10")

-- Cells in a raid: the ring's thickness sets them apart.
local function member(name, subgroup)
    return { name = name, class = "MAGE", subgroup = subgroup, unit = { health = 60, healthMax = 100, powerType = 0 } }
end
Header.Create()
M.SetRaidRoster({ member("Ann", 1), member("Bob", 1) })
RC.Set("r10", "cellBorder", true)
H.check("thin ring: cells apart", Header.headers[1]:GetAttribute("yOffset"), -4)
RC.Set("r10", "cellBorderSize", 2)
H.check("thicker ring: further apart", Header.headers[1]:GetAttribute("yOffset"), -6)
RC.Set("r10", "cellBorderStyle", "FLAT")
RC.Set("r10", "cellBorderColor", { 0.5, 0, 0, 1 })
local cell = Header.headers[1]:GetAttribute("child1")
H.check("ring in its colour", cell.frameRing.border[1]._color[1], 0.5)

-- The rounding drawn: on at the default radius, off at 0.
H.check("rounded by default", cell.clip.radius, 4)
H.check("rounding mask on", cell.clip.mask:IsShown(), true)
RC.Set("r10", "cellCornerRadius", 0)
H.check("square: no radius", cell.clip.radius, 0)
H.check("square: mask off", cell.clip.mask:IsShown(), false)

-- In the window: the switch with the ring's look on the Cell tab.
local function tab(id)
    for _, t in ipairs(ns.RaidSchema.TABS) do
        if t.id == id then return t end
    end
end
H.check("cell section", tab("cell").sections[3].id, "cellShape")
H.check("cell section keys", table.concat(tab("cell").sections[3].keys, ","),
    "cellBorder,cellBorderStyle,cellBorderSize,cellBorderColor,cellCornerRadius")
H.check("layout borders", table.concat(tab("layout").sections[4].keys, ","), "panelBorder,blockBorder")
H.check("section title", ns.RaidSchema.SectionTitle("cellShape"), "Border and corners")
H.check("switch label", ns.RaidSchema.Label("cellBorder"), "Border around the cell")
H.check("style word", ns.RaidSchema.EnumText(RS.Get("cellBorderStyle"), "GOLD"), "Gold")
H.check("nothing blocked", #M.blocked, 0)
