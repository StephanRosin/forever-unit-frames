-- The raid cell's bar texture and colours (Raid/Settings.lua,
-- Raid/Cell.lua, Elements/Texts.lua): the texture, the fixed health
-- colour, the background, the name's colour (or its class colour) and
-- the second line's, per raid size. The party frame's do not count.
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
H.check("texture", default("barTexture"), "Raid")
H.check("fixed health colour", default("healthColor"), "0.2 0.75 0.3 1")
H.check("background", default("backgroundColor"), "0 0 0 0.6")
H.check("name colour", default("nameColor"), "1 1 1 1")
H.check("second line colour", default("secondLineColor"), "1 1 1 1")
local codes = {}
for i, key in ipairs({ "barTexture", "healthColor", "backgroundColor", "nameColor", "secondLineColor" }) do
    codes[i] = RS.Get(key).code
end
H.check("codes", table.concat(codes, " "), "TX HC BG NA SC")

-- The cell asks the raid profile.
H.check("cell texture", C.Get("raid", "barTexture"), "Raid")
RC.Set("r10", "healthColor", { 0.1, 0.2, 0.3, 1 })
H.check("cell health colour", C.Get("raid", "healthColor")[3], 0.3)
H.check("cell background", C.Get("raid", "backgroundColor")[4], 0.6)
C.Set("party", "barTexture", "Flat")
C.Set("party", "healthColor", { 1, 0, 0, 1 })
H.check("not the party frame's texture", C.Get("raid", "barTexture"), "Raid")
H.check("not the party frame's colour", C.Get("raid", "healthColor")[1], 0.1)

-- A cell in a raid.
local function member(name, class, subgroup)
    return { name = name, class = class, subgroup = subgroup, unit = { health = 60, healthMax = 100,
        healthMissing = 40, powerType = 0 } }
end
Header.Create()
M.SetRaidRoster({ member("Ann", "MAGE", 1), member("Bob", "PRIEST", 1) })
local cell = Header.headers[1]:GetAttribute("child1")
local function color(c) return table.concat({ c[1], c[2], c[3], c[4] }, " ") end
H.check("health texture", cell.health._texture, "Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
H.check("background colour", color(cell.healthBg._color), "0 0 0 0.6")
H.check("name white", color(cell.texts.healthLeft._color), "1 1 1 1")
H.check("second line white", color(cell.texts.healthRight._color), "1 1 1 1")

RC.Set("r10", "healthColorMode", "STATIC")
RC.Set("r10", "barTexture", "Flat")
RC.Set("r10", "backgroundColor", { 0.1, 0.1, 0.1, 0.8 })
RC.Set("r10", "nameColor", { 1, 0.8, 0, 1 })
RC.Set("r10", "secondLineColor", { 0.6, 0.6, 0.6, 1 })
H.check("health in the fixed colour", table.concat(cell.health._color, " ", 1, 3), "0.1 0.2 0.3")
H.check("texture follows", cell.health._texture, "Interface\\Buttons\\WHITE8X8")
H.check("background follows", color(cell.healthBg._color), "0.1 0.1 0.1 0.8")
H.check("name colour", color(cell.texts.healthLeft._color), "1 0.8 0 1")
H.check("second line colour", color(cell.texts.healthRight._color), "0.6 0.6 0.6 1")
RC.Set("r10", "nameClassColor", true)
local r, g, b = ns.Health.UnitColor(cell.unit, "CLASS")
H.check("a mage's blue", r < 1, true)
H.check("class colour wins", color(cell.texts.healthLeft._color), table.concat({ r, g, b, 1 }, " "))
H.check("second line keeps its colour", color(cell.texts.healthRight._color), "0.6 0.6 0.6 1")

-- A unit frame keeps white texts.
local party = CreateFrame("Button", nil, UIParent, "SecureUnitButtonTemplate")
party.key = "party"
for _, el in ipairs(ns.Elements) do el.Build(party) end
ns.Single.StyleContent(party)
M.units.player = { name = "Me", class = "MAGE", isPlayer = true, health = 50, healthMax = 100, healthMissing = 50 }
ns.Single.SetUnit(party, "player")
ns.Single.UpdateAll(party)
H.check("unit frame: value text white", color(party.texts.healthRight._color), "1 1 1 1")

-- In the window.
local function tab(id)
    for _, t in ipairs(ns.RaidSchema.TABS) do
        if t.id == id then return t end
    end
end
H.check("bars section", table.concat(tab("cell").sections[2].keys, ","),
    "healthColorMode,healthColor,barTexture,backgroundColor,powerStrip,powerStripHeight")
H.check("texts section", table.concat(tab("texts").sections[1].keys, ","),
    "nameClassColor,nameColor,secondLine,secondLineColor")
H.check("fixed colour choice", ns.RaidSchema.EnumText(RS.Get("healthColorMode"), "STATIC"), "Fixed color")
H.check("label", ns.RaidSchema.Label("nameColor"), "Name color")
H.check("the cell's note", ns.RaidSchema.Note("cell"), "Heals, shields and the power strip keep the unit frames' standard colors.")
H.check("nothing blocked", #M.blocked, 0)
