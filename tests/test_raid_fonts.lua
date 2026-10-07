-- The raid cell's fonts (Raid/Settings.lua, Raid/Cell.lua): the face, the
-- name's size and the second line's, outline and shadow, per raid size;
-- the block titles take the face and the outline. The party frame's
-- fonts do not count.
local M = H.M
local ns = H.LoadAddon()
local RC, C, RS, Header = ns.RaidConfig, ns.Config, ns.RaidSettings, ns.RaidHeader
C.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

-- The settings, per size, at today's look.
local function default(key) return RS.Default(RS.Get(key), "r10") end
H.check("font", default("fontFace"), "Friz Quadrata")
H.check("name size", default("nameFontSize"), 11)
H.check("second line size", default("secondFontSize"), 10)
H.check("outline", default("fontOutline"), "OUTLINE")
H.check("shadow", default("fontShadow"), true)
H.check("outline choices: the unit frames'", table.concat(RS.Get("fontOutline").values, ","),
    "NONE,OUTLINE,THICKOUTLINE,MONOCHROME,SOFT")
local codes = {}
for i, key in ipairs({ "fontFace", "nameFontSize", "secondFontSize", "fontOutline", "fontShadow" }) do
    codes[i] = RS.Get(key).code
end
H.check("codes", table.concat(codes, " "), "FF NF SF FO FH")

-- The cell asks the raid profile.
H.check("cell font", C.Get("raid", "fontFace"), "Friz Quadrata")
H.check("cell name size", C.Get("raid", "fontSize"), 11)
H.check("cell value size", C.Get("raid", "valueFontSize"), 10)
H.check("cell outline", C.Get("raid", "fontOutline"), "OUTLINE")
H.check("cell shadow", C.Get("raid", "fontShadow"), true)
C.Set("party", "fontSize", 20)
H.check("not the party frame's size", C.Get("raid", "fontSize"), 11)

-- A cell in a raid, and its block's title.
local function member(name, class, subgroup)
    return { name = name, class = class, subgroup = subgroup, unit = { health = 60, healthMax = 100,
        healthMissing = 40, powerType = 0 } }
end
Header.Create()
M.SetRaidRoster({ member("Ann", "PRIEST", 1), member("Bob", "MAGE", 1) })
RC.Set("r10", "blockTitles", true)
local cell = Header.headers[1]:GetAttribute("child1")
local name, second = cell.texts.healthLeft, cell.texts.healthRight
local function font(fs) return table.concat({ fs:GetFont() }, " ") end
H.check("name font", font(name), "Fonts\\FRIZQT__.TTF 11 OUTLINE")
H.check("second line font", font(second), "Fonts\\FRIZQT__.TTF 10 OUTLINE")
H.check("shadow on", name._shadow[1], 1)
H.check("title font", font(Header.decor[1].title), "Fonts\\FRIZQT__.TTF 11 OUTLINE")

RC.Set("r10", "fontFace", "Arial Narrow")
RC.Set("r10", "nameFontSize", 13)
RC.Set("r10", "secondFontSize", 9)
RC.Set("r10", "fontOutline", "THICKOUTLINE")
RC.Set("r10", "fontShadow", false)
H.check("name font follows", font(name), "Fonts\\ARIALN.TTF 13 THICKOUTLINE")
H.check("second line font follows", font(second), "Fonts\\ARIALN.TTF 9 THICKOUTLINE")
H.check("shadow off", name._shadow[1], 0)
H.check("title font follows", font(Header.decor[1].title), "Fonts\\ARIALN.TTF 11 THICKOUTLINE")
H.check("other sizes keep theirs", RC.Get("r20", "nameFontSize"), 11)

-- In the window: their own section on the Texts tab.
local texts
for _, tab in ipairs(ns.RaidSchema.TABS) do
    if tab.id == "texts" then texts = tab end
end
H.check("fonts section", texts.sections[2].id, "fonts")
H.check("fonts section keys", table.concat(texts.sections[2].keys, ","),
    "fontFace,nameFontSize,secondFontSize,fontOutline,fontShadow")
H.check("section title", ns.RaidSchema.SectionTitle("fonts"), "Font")
H.check("label", ns.RaidSchema.Label("secondFontSize"), "Second line size")
H.check("outline word", ns.RaidSchema.EnumText(RS.Get("fontOutline"), "SOFT"), "Soft outline")
H.check("nothing blocked", #M.blocked, 0)
