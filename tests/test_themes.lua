local M = H.M

-- A profile with an own layout: the player's size, the target smaller,
-- frame overrides of looks a theme takes over.
local ns = H.LoadAddon()
local db = { profiles = { Default = {
    general = { borderStyle = "BRONZE", fontSize = 12 },
    player = { width = 300, height = 67, x = -200, cornerRadius = 10, shieldsBarX = 5 },
    target = { width = 200, height = 50, x = 200 },
} } }
ns.Config.Use(ns.Storage.Load(db))
ns.Storage.Attach(db)
local Themes, Config = ns.Themes, ns.Config

H.check("starts classic", Themes.Current(), "CLASSIC")
H.check("nothing stored yet", #Themes.Stored(), 0)

-- A theme the first time: the classic layout with the theme's look.
H.checkTrue("switch to wood", Themes.Switch("WOOD"))
H.check("wood: current", Themes.Current(), "WOOD")
H.check("wood: keeps the position", Config.Get("player", "x"), -200)
H.check("wood: keeps an element's place", Config.Get("player", "shieldsBarX"), 5)
H.check("wood: its border", Config.Get("player", "borderStyle"), "BRONZE")
H.check("wood: its bar", Config.Get("player", "barTexture"), "FUF Wood")
H.check("wood: frame override gone, General's look", Config.Get("player", "cornerRadius"), 3)
H.check("wood: its font", Config.Get("player", "fontFace"), "Cinzel")
H.check("wood: target as wide as the player", Config.Get("target", "width"), 300)
H.check("wood: target as high as the player", Config.Get("target", "height"), 67)
H.check("wood: classic stored", db.themeSets.Default.CLASSIC.player.width, 300)
H.check("wood: the live set is not stored twice", db.themeSets.Default.WOOD, nil)
H.check("wood: saved as the profile", db.profiles.Default.general.theme, "WOOD")

-- Changes stay with their theme.
Config.Set("player", "x", -150)
H.checkTrue("switch to pixel", Themes.Switch("PIXEL"))
H.check("pixel: from classic, not from wood", Config.Get("player", "x"), -200)
H.check("pixel: font larger", Config.Get("general", "fontSize"), 16)
H.check("pixel: two to copy from", #Themes.Stored(), 2)

-- Positions from another theme.
local undo = Themes.CopyPlacement("WOOD")
H.checkTrue("copy: done", undo)
H.check("copy: position taken", Config.Get("player", "x"), -150)
H.check("copy: look kept", Config.Get("player", "barTexture"), "FUF Pixel")
H.check("copy: sizes are no positions", Config.Get("target", "width"), 300)
H.checkTrue("copy: undo", Themes.Restore(undo))
H.check("copy: undone", Config.Get("player", "x"), -200)

-- Back to classic: everything as it was.
H.checkTrue("back to classic", Themes.Switch("CLASSIC"))
H.check("classic: own look", Config.Get("player", "cornerRadius"), 10)
H.check("classic: own target", Config.Get("target", "width"), 200)
H.check("classic: own bar", Config.Get("player", "barTexture"), "Flat")
H.checkTrue("wood again", Themes.Switch("WOOD"))
H.check("wood again: its own change came back", Config.Get("player", "x"), -150)

-- Reset: the theme anew from classic.
H.checkTrue("reset", Themes.Reset())
H.check("reset: from classic", Config.Get("player", "x"), -200)
Themes.Switch("CLASSIC")
H.check("reset: not classic", select(2, Themes.Reset()), "CLASSIC")

-- Refused.
M.combat = true
H.check("combat", select(2, Themes.Switch("TECH")), "COMBAT")
M.combat = false
H.check("unknown", select(2, Themes.Switch("NOPE")), "UNKNOWN")
H.check("copy from a theme never used", select(2, Themes.CopyPlacement("FROST")), "GONE")

-- The sets follow the profile.
Themes.Switch("WOOD")
H.checkTrue("save as", ns.UnitProfiles.SaveAs("Second"))
H.checkTrue("save as: sets copied", db.themeSets.Second.CLASSIC ~= nil)
H.checkTrue("rename", ns.UnitProfiles.Rename("Third"))
H.checkTrue("rename: sets moved", db.themeSets.Third ~= nil and db.themeSets.Second == nil)
H.checkTrue("delete", ns.UnitProfiles.Delete())
H.check("delete: sets gone", db.themeSets.Third, nil)

-- Placement keys come from the options schema.
local keys = {}
for _, key in ipairs(Themes.PlacementKeys()) do keys[key] = true end
H.checkTrue("placement: frame position", keys.x and keys.y)
H.checkTrue("placement: a section's rows", keys.shieldsBarX and keys.manaWarnY)
H.checkTrue("placement: no sizes", not keys.width)

-- Raid cells: the unit frames' theme unless overridden.
Themes.Switch("WOOD")
local Cell = ns.RaidCell
ns.RaidConfig.Use({})
H.check("cells follow the unit frames", Cell.Theme(), "WOOD")
H.check("cells: theme bar", Config.Get(Cell.KEY, "barTexture"), "FUF Wood")
H.check("cells: slim ring", Config.Get(Cell.KEY, "borderSize"), 2)
ns.RaidConfig.Set("general", "cellTheme", "OWN")
H.check("cells: own look", Cell.Theme(), "CLASSIC")
H.check("cells: own bar", Config.Get(Cell.KEY, "barTexture"), ns.RaidConfig.Get("r10", "barTexture"))
ns.RaidConfig.Set("general", "cellTheme", "FROST")
H.check("cells: a theme of their own", Config.Get(Cell.KEY, "barTexture"), "FUF Frost")

-- A font the client refuses at first use is tried again; until it takes,
-- the soft outline's black copies stay hidden (the text would show black).
local fs = UIParent:CreateFontString()
local setFont, refusals = fs.SetFont, 1
fs.SetFont = function(self, path, ...)
    if refusals > 0 and path == "Fonts\\new.ttf" then refusals = refusals - 1; self._font = nil; return false end
    return setFont(self, path, ...)
end
fs:Show()
ns.Texts.SetFont(fs, "Fonts\\new.ttf", 12, "SOFT")
H.check("refused: no outline under an empty text", fs.softCopies[1]:IsShown(), false)
M.RunTimers()
H.check("tried again: taken", (fs:GetFont()), "Fonts\\new.ttf")
H.check("tried again: outline back", fs.softCopies[1]:IsShown(), true)

-- A theme stored under an older revision is made anew; Classic stays.
ns = H.LoadAddon()
db = { profiles = { Default = { general = { theme = "WOOD", borderPadding = 0 }, player = { width = 280, x = 10 } } },
    themeSets = { Default = { CLASSIC = { player = { width = 280, x = 10 } },
        TECH = { general = { theme = "TECH" }, player = { x = 99 } } } } }
ns.Config.Use(ns.Storage.Load(db))
ns.Storage.Attach(db)
ns.Themes.Upgrade()
H.check("upgrade: the theme in use made anew", ns.Config.Get("general", "borderPadding"), 4)
H.check("upgrade: from classic", ns.Config.Get("player", "x"), 10)
H.check("upgrade: stale set dropped", db.themeSets.Default.TECH, nil)
H.check("upgrade: classic kept", db.themeSets.Default.CLASSIC.player.width, 280)
H.check("upgrade: revision noted", db.themeSets.Default.revision, ns.Themes.REVISION)
ns.Config.Set("general", "borderPadding", 2)
ns.Themes.Upgrade()
H.check("upgrade: once only", ns.Config.Get("general", "borderPadding"), 2)
