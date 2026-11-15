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
H.check("wood: its border", Config.Get("player", "borderStyle"), "GOLD")
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
-- the text and its soft outline show Blizzard's font (never black copies
-- under an empty text).
local fs = UIParent:CreateFontString()
local setFont, refusals = fs.SetFont, 1
fs.SetFont = function(self, path, ...)
    if refusals > 0 and path == "Fonts\\new.ttf" then refusals = refusals - 1; self._font = nil; return false end
    return setFont(self, path, ...)
end
fs:Show()
ns.Texts.SetFont(fs, "Fonts\\new.ttf", 12, "SOFT")
H.check("refused: Blizzard's font meanwhile", (fs:GetFont()), "Fonts\\FRIZQT__.TTF")
H.check("refused: the outline in that font", (fs.softCopies[1]:GetFont()), "Fonts\\FRIZQT__.TTF")
M.RunTimers()
H.check("tried again: taken", (fs:GetFont()), "Fonts\\new.ttf")
H.check("tried again: outline back", fs.softCopies[1]:IsShown(), true)

-- A fresh font is set again a little later, through another font, with
-- its text written anew: a first use can leave the text blank in game.
do
    local t = UIParent:CreateFontString()
    t:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    t:SetText("Ayla")
    local seen, plain = {}, t.SetFont
    t.SetFont = function(self, path, ...) seen[#seen + 1] = path; return plain(self, path, ...) end
    ns.Texts.SetFont(t, "Fonts\\fresh.ttf", 12, "OUTLINE")
    seen = {}
    M.RunTimers()
    H.check("redraw: through another font", seen[1], "Fonts\\FRIZQT__.TTF")
    H.check("redraw: back to its own", (t:GetFont()), "Fonts\\fresh.ttf")
    H.check("redraw: text kept", t:GetText(), "Ayla")
    seen = {}
    ns.Texts.SetFont(t, "Fonts\\fresh.ttf", 12, "OUTLINE")
    M.RunTimers()
    H.check("redraw: once per font", #seen, 1)
end

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

-- Sets stored by the last release (revision 13, no seedRevision) are current:
-- the move to Lib.NeedsReseed reseeds nothing.
ns = H.LoadAddon()
db = { profiles = { Default = { general = { theme = "WOOD", borderPadding = 2 } } },
    themeSets = { Default = { revision = 13, CLASSIC = { player = { width = 280 } },
        TECH = { general = { theme = "TECH" }, player = { x = 99 } } } } }
ns.Config.Use(ns.Storage.Load(db))
ns.Storage.Attach(db)
ns.Themes.Upgrade()
H.check("last release: the theme in use kept", ns.Config.Get("general", "borderPadding"), 2)
H.check("last release: stored set kept", #ns.Themes.Stored(), 2)
H.check("last release: TECH's set untouched", db.themeSets.Default.TECH.player.x, 99)

-- Ornaments and the solid shadow sit at the ring's corners: around the
-- frame, or around the frame and its docked castbar.
do
    local art = ns.ThemeArt
    local frame = M.newWidget("Frame", nil, UIParent)
    frame.key = "player"
    frame.unitBox = M.newWidget("Frame", nil, frame)
    art.Build(frame)
    frame.themeOrnamentsOn, frame.themeShadowOn = { [1] = true, [4] = true }, true
    art.Refresh(frame, false)
    H.check("alone: frame ornament", frame.themeOrnaments[4]:IsShown(), true)
    H.check("alone: no block ornament", frame.themeBlockOrnaments[4]:IsShown(), false)
    H.check("alone: unwanted corner", frame.themeOrnaments[2]:IsShown(), false)
    art.Refresh(frame, true)
    H.check("docked: block ornament", frame.themeBlockOrnaments[4]:IsShown(), true)
    H.check("docked: frame ornament hidden", frame.themeOrnaments[4]:IsShown(), false)
    H.check("docked: block shadow", frame.themeBlockShadow:IsShown(), true)
    -- The backdrop goes round the castbar's slot too: else the shadow showed through it.
    frame.themeBackOn = true
    art.Refresh(frame, true)
    H.check("docked: block backdrop", frame.themeBlockBack:IsShown(), true)
    H.check("docked: frame backdrop hidden", frame.themeBack:IsShown(), false)
    art.Refresh(frame, false)
    H.check("alone: frame backdrop", frame.themeBack:IsShown(), true)
end
H.check("comic: solid shadow on the unit frames", ns.Themes.SPECS.COMIC.art.hardShadow, 5)

-- The entry for other addons' theme pickers.
do
    local entry = _G.ForeverThemes and _G.ForeverThemes.ForeverUnitFrames
    H.checkTrue("registry: entry", entry)
    H.checkTrue("registry: switch", entry.Switch("FROST"))
    H.check("registry: current", entry.Current(), "FROST")
end

-- Round 3: Tech without corner pieces; Comic's paper as in every Forever addon.
H.check("tech: no corner pieces", ns.Themes.SPECS.TECH.art.ornament, nil)
H.check("comic: paper at 0.7", ns.Themes.SPECS.COMIC.art.tint[1], 0.7)
H.check("comic: no fill over the paper", ns.Themes.SPECS.COMIC.look.backgroundColor[4], 0)

-- Every theme's colours: the backdrop only (no accent here), kept apart
-- from the theme sets; unit frames, raid cells and Smart Buffs alike.
do
    ns.RaidProfiles.Attach(db)   -- as at login: the cells' theme is asked too
    local entry = _G.ForeverThemes.ForeverUnitFrames
    local texture = CreateFrame("Frame"):CreateTexture()
    local PATH = "Interface\\AddOns\\ForeverUnitFrames\\Libs\\LibForeverThemes\\Media\\Themes\\"
    local function rgb(t) return table.concat({ t[1], t[2], t[3], t[4] }, ",") end
    local function paint(id)
        ns.ThemeArt.Paint(texture, ns.Themes.SPECS[id])
        return texture._texture .. " " .. table.concat(texture._color, ",")
    end
    ns.Themes.Switch("CLASSIC")
    H.check("colours: none under classic", #entry.Colors(), 0)
    H.check("colours: classic has no colour", entry.Color(), nil)
    H.check("colours: comic list", table.concat(entry.Colors("COMIC"), ","), "GREY,DARKGREY,BLACK,WHITE,YELLOW,BLUE,RED,GREEN,PURPLE")
    for _, id in ipairs(LibForeverThemes.SpecIds(ns.Themes.SPECS)) do
        local art = ns.Themes.SPECS[id].art
        if art then
            local colours = entry.Colors(id)
            H.check(id .. ": the first colour by default", entry.Color(id), colours[1])
            H.check(id .. ": default as today", paint(id), PATH .. art.back .. " " .. rgb(art.tint or { 1, 1, 1, 1 }))
            for _, c in ipairs(colours) do
                H.checkTrue(id .. " " .. c .. ": named", ns.L["THEME_COLOR_" .. id .. "_" .. c] ~= "THEME_COLOR_" .. id .. "_" .. c)
            end
        end
    end
    H.checkTrue("colours: to pixel", ns.Themes.Switch("PIXEL"))
    H.checkTrue("pixel plum: set", entry.SetColor("PLUM"))
    H.check("pixel plum: grey texture tinted target / mean", paint("PIXEL"),
        PATH .. "PixelBackGrey " .. rgb({ 0.23 / 0.8, 0.08 / 0.8, 0.16 / 0.8, 1 }))
    H.checkTrue("frost deep: set for a theme not in use", entry.SetColor("DEEP", "FROST"))
    H.check("frost deep: keeps the alpha", paint("FROST"),
        PATH .. "FrostBackGrey " .. rgb({ 0.1 / 0.796, 0.18 / 0.796, 0.32 / 0.796, 0.85 }))
    H.check("colours: each theme its own", entry.Color() .. " " .. entry.Color("FROST"), "PLUM DEEP")
    H.check("colour: unknown refused", select(2, ns.Themes.SetColor("NOPE")), "UNKNOWN")
    H.check("colour: another theme's id refused", select(2, ns.Themes.SetColor("OAK")), "UNKNOWN")
    M.combat = true
    H.check("colour: combat refused for the theme in use", select(2, ns.Themes.SetColor("NAVY")), "COMBAT")
    H.checkTrue("colour: a theme not shown in combat", ns.Themes.SetColor("ICE", "FROST"))
    M.combat = false
    H.check("colour: in no profile", ns.Config.Profile().general.themeColors, nil)
    H.checkTrue("pixel navy: back", ns.Themes.SetColor("NAVY"))
    H.check("pixel navy: nothing stored", db.themeColors.PIXEL, nil)
    -- The comic as built: its paper.
    H.checkTrue("comic: to comic", ns.Themes.Switch("COMIC"))
    H.checkTrue("comic blue: set", entry.SetColor("BLUE"))
    H.check("comic blue: paper", paint("COMIC"), PATH .. "ComicBack 0.45,0.6,0.86,1")
    H.checkTrue("comic black: set", ns.Themes.SetColor("BLACK"))
    H.check("comic black: paper", paint("COMIC"), PATH .. "ComicBack 0.16,0.16,0.16,1")
    db.themeColors.COMIC = "NOPE"
    H.check("colour: unknown stored reads the first", ns.Themes.Color(), "GREY")
    -- The comic colour of before moves in once.
    db.themeColors.COMIC = nil
    db.comicColor = "RED"
    H.check("migration: comic colour moved", entry.Color("COMIC") .. " " .. tostring(db.comicColor), "RED nil")
    db.comicColor = "BLUE"
    H.check("migration: a colour already set wins", entry.Color("COMIC"), "RED")
    ns.Themes.SetColor("GREY")
    H.check("comic grey: paper as today", paint("COMIC"), PATH .. "ComicBack 0.7,0.7,0.7,1")
    ns.Themes.Switch("CLASSIC")
end


-- Every theme's ring in the family's colour (ForeverQuestLog's Themes.lua);
-- Pitwall has none there: its ring is the carbon's own colour.
do
    local FAMILY = {
        WOOD = "GOLD",
        TECH = "0.25,0.88,0.94,0.9", PARCHMENT = "0.29,0.2,0.12,1", RUNESTONE = "0.1,0.1,0.12,1",
        GLASS = "0.07,0.06,0.05,1", COMIC = "0.07,0.07,0.07,1", FROST = "0.86,0.96,1,0.8",
        PIXEL = "1,0.95,0.91,1", SWISS = "0.165,0.165,0.165,1", CONSOLE = "0.306,0.929,0.69,1",
        PITWALL = "0.043,0.047,0.055,1",
    }
    for _, id in ipairs(LibForeverThemes.SpecIds(ns.Themes.SPECS)) do
        local look = ns.Themes.SPECS[id].look
        if look then
            local ring = look.borderStyle == "FLAT" and table.concat(look.borderColor, ",") or look.borderStyle
            H.check(id .. ": ring in the family's colour", ring, FAMILY[id])
            local cell = ns.Themes.CellLook(id, "borderStyle") == "FLAT"
                and table.concat(ns.Themes.CellLook(id, "borderColor"), ",") or ns.Themes.CellLook(id, "borderStyle")
            H.check(id .. ": cell ring the same", cell, FAMILY[id])
        end
    end
end

-- The ring under every theme and every colour, as drawn, the same in every
-- Forever addon: the theme's own, but Console's accent and Pixel's Handheld.
do
    local function rgb(c) return string.format("%.3f,%.3f,%.3f,%.3f", c[1], c[2], c[3], c[4] or 1) end
    local OVERRIDE = {
        CONSOLE = { MINT = "0.306,0.929,0.690,1.000", AMBER = "1.000,0.690,0.000,1.000",
            PHOSPHOR = "0.224,1.000,0.078,1.000", VIOLET = "0.627,0.471,1.000,1.000" },
        PIXEL = { HANDHELD = "0.784,0.941,0.439,1.000" },
    }
    _G.ForeverUnitFramesDB = nil
    H.M.FireEvent("PLAYER_LOGIN")
    H.M.RunTimers()
    local f = ns.Frames.player
    for _, id in ipairs(LibForeverThemes.SpecIds(ns.Themes.SPECS)) do
        local look = ns.Themes.SPECS[id].look
        if look then
            ns.Themes.Switch(id)
            for _, colourId in ipairs(ns.Themes.Colors(id)) do
                ns.Themes.SetColor(colourId)
                H.M.RunTimers()
                ns.Single.StyleAll(f)
                local want = (OVERRIDE[id] or {})[colourId]
                    or (look.borderStyle == "FLAT" and rgb(look.borderColor) or look.borderStyle)
                local drawn = look.borderStyle == "FLAT" and rgb(f.frameRing.border[1]._color)
                    or ns.Config.Get("player", "borderStyle")
                H.check(id .. " " .. colourId .. ": ring", drawn, want)
                local cellStyle = ns.Themes.CellLook(id, "borderStyle")
                H.check(id .. " " .. colourId .. ": cell ring", cellStyle == "FLAT"
                    and rgb(ns.Themes.CellLook(id, "borderColor")) or cellStyle, want)
            end
            ns.Themes.SetColor(ns.Themes.Colors(id)[1])
        end
    end
    ns.Themes.Switch("CLASSIC")
end
