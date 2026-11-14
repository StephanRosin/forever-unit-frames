local _, ns = ...

-- Themes: a look for the unit frames, and a whole set of settings each.
-- The setting `theme` (General) names the one in use; the profile in use
-- holds its settings. The others wait in UnitProfiles.ThemeSets(), one
-- copy per theme, the profile's own. CLASSIC is the player's own layout
-- as it was before themes: it is never changed by another theme, so
-- going back to it restores every setting.
--
-- A theme chosen the first time starts from the CLASSIC set (positions,
-- sizes, auras: everything the player arranged) with the theme's look on
-- top (SPECS[id].look) and the target as large as the player. Its art
-- beyond settings (backdrop, ornaments, hard shadow) is
-- Elements/ThemeArt.lua's.
local Themes = {}
ns.Themes = Themes

Themes.CLASSIC = "CLASSIC"
Themes.IDS = ns.Settings.THEMES

-- The theme fonts have Latin letters only: on a client whose names are
-- written otherwise the frames keep their font.
local LATIN_CLIENTS = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true,
    ptBR = true }

-- look: settings the theme sets in General (every frame follows General
-- for these, see seed). font, bar: the theme's font and bar texture;
-- fontSizeAdd: how much larger its font must be to read like the others.
-- art (Elements/ThemeArt.lua): back = backdrop file in Media/Themes,
-- tint = its colour, ornament = corner piece, corners = which ones
-- (Corners.POINTS order: 1 top left, 2 top right, 3 bottom left, 4
-- bottom right), ornamentInset = how far in from the border's outer
-- corner (negative: further out), hardShadow = offset of a solid shadow.
-- borderPadding shows the backdrop round the bars.
-- fontOutline: the client's OUTLINE, never SOFT. With the theme fonts
-- SOFT (Elements/Texts.lua) showed black text in game; why is not known
-- (the text has its font by GetFont, its black copies draw on top).
Themes.SPECS = {
    CLASSIC = {},
    -- Oak boards round the bars, a brass rim, brass rivets.
    WOOD = {
        font = "Cinzel", bar = "FUF Wood",
        look = { borderShow = true, borderStyle = "BRONZE", borderSize = 3, borderPadding = 4, cornerRadius = 3,
            backgroundColor = { 0.1, 0.06, 0.02, 0.85 }, titleBackground = false,
            shadowEnabled = true, shadowAlpha = 60, shadowSize = 6, fontOutline = "OUTLINE" },
        art = { back = "WoodBack", ornament = "Rivet", corners = { 1, 2, 3, 4 }, ornamentSize = 11, ornamentInset = 1 },
    },
    -- Dark navy with a faint grid, a thin cyan line.
    TECH = {
        font = "Space Grotesk", bar = "FUF Tech",
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 1, borderColor = { 0.25, 0.88, 0.94, 0.9 },
            borderPadding = 3, cornerRadius = 0, backgroundColor = { 0.02, 0.05, 0.08, 0.92 },
            titleBackground = false, shadowEnabled = false, fontOutline = "OUTLINE" },
        art = { back = "TechBack" },
    },
    -- Parchment round the bars, a brown ink line, a wax seal.
    PARCHMENT = {
        font = "IM Fell English SC", bar = "FUF Parchment", fontSizeAdd = 1,
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 2, borderColor = { 0.29, 0.2, 0.12, 1 },
            borderPadding = 4, cornerRadius = 2, backgroundColor = { 0.22, 0.15, 0.07, 0.6 }, titleBackground = false,
            shadowEnabled = true, shadowAlpha = 45, shadowSize = 5, fontOutline = "OUTLINE" },
        art = { back = "ParchmentBack", ornament = "Seal", corners = { 3 }, ornamentSize = 22, ornamentInset = -6 },
    },
    -- Grey granite, a dark chiselled edge, glowing runes.
    RUNESTONE = {
        font = "Marcellus", bar = "FUF Stone", fontSizeAdd = 1,
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 2, borderColor = { 0.1, 0.1, 0.12, 1 },
            borderPadding = 5, cornerRadius = 0, backgroundColor = { 0.04, 0.05, 0.06, 0.92 },
            titleBackground = false, shadowEnabled = true, shadowAlpha = 70, shadowSize = 6, fontOutline = "OUTLINE" },
        art = { back = "StoneBack", ornament = "Rune", corners = { 1, 2 }, ornamentSize = 14, ornamentInset = 2,
            ornamentColor = { 0.35, 0.95, 0.85, 1 } },
    },
    -- A mosaic of coloured glass round the bars, dark lead.
    GLASS = {
        font = "Morpheus", bar = "FUF Glass", fontSizeAdd = 1,
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 3, borderColor = { 0.07, 0.06, 0.05, 1 },
            borderPadding = 6, cornerRadius = 0, backgroundColor = { 0.05, 0.04, 0.06, 0.9 },
            titleBackground = true, shadowEnabled = true, shadowAlpha = 55, shadowSize = 6, fontOutline = "OUTLINE" },
        art = { back = "GlassBack" },
    },
    -- Thick ink line, halftone paper, a solid shadow.
    COMIC = {
        font = "Bangers", bar = "FUF Comic", fontSizeAdd = 2,
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 3, borderColor = { 0.07, 0.07, 0.07, 1 },
            borderPadding = 0, cornerRadius = 0, backgroundColor = { 0, 0, 0, 0 }, titleBackground = false,
            shadowEnabled = false, fontOutline = "THICKOUTLINE" },
        -- The same paper in every Forever addon: ComicBack at 0.7.
        art = { back = "ComicBack", tint = { 0.7, 0.7, 0.7, 1 }, hardShadow = 5 },
    },
    -- Translucent ice, a pale rim, rounded.
    FROST = {
        font = "Cormorant SC", bar = "FUF Frost", fontSizeAdd = 2,
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 1, borderColor = { 0.86, 0.96, 1, 0.8 },
            borderPadding = 2, cornerRadius = 6, backgroundColor = { 0.04, 0.12, 0.22, 0.6 },
            titleBackground = false, shadowEnabled = true, shadowAlpha = 55, shadowSize = 8, fontOutline = "OUTLINE" },
        art = { back = "FrostBack", tint = { 1, 1, 1, 0.75 } },
    },
    -- A light pixel frame, scan lines, a solid shadow.
    PIXEL = {
        font = "VT323", bar = "FUF Pixel", fontSizeAdd = 4,
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 3, borderColor = { 1, 0.95, 0.91, 1 },
            borderPadding = 0, cornerRadius = 0, backgroundColor = { 0, 0, 0, 1 }, titleBackground = false,
            shadowEnabled = false, fontOutline = "OUTLINE" },
        art = { back = "PixelBack", hardShadow = 4 },
    },
}

-- Settings a theme takes over on every frame: frames that had their own
-- value follow General again, where the theme puts its look.
local THEMED = { "fontFace", "fontOutline", "barTexture" }
for _, spec in pairs(Themes.SPECS) do
    for key in pairs(spec.look or {}) do THEMED[#THEMED + 1] = key end
end

-- A raid cell is small and sits among others: its ring and corners stay
-- slim, and it gets no ornaments or solid shadow (Elements/ThemeArt.lua).
local CELL_BORDER_MAX, CELL_RADIUS_MAX = 2, 4

-- What a raid cell shows for a unit-frame look setting under theme id;
-- nil for CLASSIC or a setting the theme leaves alone. own(): the
-- cell's own value (font sizes grow from it).
function Themes.CellLook(id, key, own)
    local spec = Themes.SPECS[id]
    if not spec or id == Themes.CLASSIC then return nil end
    local look = spec.look
    if key == "barTexture" then return spec.bar end
    if key == "fontFace" then return LATIN_CLIENTS[GetLocale()] and spec.font or nil end
    if key == "fontSize" or key == "valueFontSize" then
        local add = spec.fontSizeAdd or 0
        if add == 0 then return nil end
        local size = own()
        return size > 0 and size + add or size
    end
    if key == "borderSize" then return math.min(look.borderSize, CELL_BORDER_MAX) end
    if key == "cornerRadius" then return math.min(look.cornerRadius, CELL_RADIUS_MAX) end
    return look[key]
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

local function scopesOf(p)
    for _, scope in ipairs(ns.Settings.SCOPES) do
        if type(p[scope]) ~= "table" then p[scope] = {} end
    end
end

-- Raised whenever SPECS change a look: theme sets made before are made
-- anew from CLASSIC (Themes.Upgrade), so a changed theme shows as it is
-- now. CLASSIC is never touched.
Themes.REVISION = 4

-- The active profile's stored theme sets; stale ones (an older
-- REVISION) dropped.
local function storedSets()
    local sets = ns.UnitProfiles.ThemeSets()
    if sets.revision ~= Themes.REVISION then
        for _, id in ipairs(Themes.IDS) do
            if id ~= Themes.CLASSIC then sets[id] = nil end
        end
        sets.revision = Themes.REVISION
    end
    return sets
end

function Themes.Current()
    return ns.Config.Get("general", "theme")
end

function Themes.Spec(id)
    return Themes.SPECS[id] or Themes.SPECS.CLASSIC
end

-- The font sizes one larger by add, in General and wherever a frame has
-- its own.
local function growFonts(p, add)
    if add == 0 then return end
    local Config = ns.Config
    for _, scope in ipairs(ns.Settings.SCOPES) do
        for _, key in ipairs({ "fontSize", "valueFontSize" }) do
            local own = p[scope][key]
            if scope == "general" or own ~= nil then
                local size = Config.ValueIn(p, scope, key)
                if key == "fontSize" or size > 0 then p[scope][key] = size + add end
            end
        end
    end
end

-- A new theme's settings: the base set (CLASSIC) with the theme's look.
local function seed(id, base)
    local spec = Themes.Spec(id)
    local p = copy(base)
    scopesOf(p)
    for _, scope in ipairs(ns.Settings.SCOPES) do
        if scope ~= "general" then
            for _, key in ipairs(THEMED) do p[scope][key] = nil end
        end
    end
    for key, value in pairs(spec.look or {}) do p.general[key] = copy(value) end
    p.general.barTexture = spec.bar
    if spec.font and LATIN_CLIENTS[GetLocale()] then p.general.fontFace = spec.font end
    growFonts(p, spec.fontSizeAdd or 0)
    -- The target as large as the player: the two sit side by side.
    for _, key in ipairs({ "width", "height" }) do
        p.target[key] = ns.Config.ValueIn(p, "player", key)
    end
    p.general.theme = id
    return p
end

local function refuse()
    if InCombatLockdown() then return "COMBAT" end
    if ns.Storage.IsWaiting() then return "WAITING" end
    return nil
end

local function use(p)
    ns.Config.Import(ns.Settings.Sanitise(copy(p)))
    ns.Storage.Save()
end

-- Moves to theme id: the current settings are kept for the current
-- theme, id's come back (or are made, the first time). true, or nil and
-- why not.
function Themes.Switch(id)
    if not Themes.SPECS[id] then return nil, "UNKNOWN" end
    local why = refuse()
    if why then return nil, why end
    local current = Themes.Current()
    if id == current then return true end
    local sets = storedSets()
    sets[current] = copy(ns.Config.Profile())
    local nextSet = sets[id]
    if not nextSet then
        -- CLASSIC is never made from a theme: without a stored one (a
        -- profile imported with a theme) the settings stay as they are.
        local base = sets[Themes.CLASSIC] or ns.Config.Profile()
        nextSet = id == Themes.CLASSIC and copy(base) or seed(id, base)
        nextSet.general = nextSet.general or {}
        nextSet.general.theme = id
    end
    -- The live set is the profile: no stale copy stays behind.
    sets[id] = nil
    use(nextSet)
    return true
end

-- The current theme made anew from CLASSIC (its look, the player's
-- layout). Not for CLASSIC itself.
function Themes.Reset()
    local id = Themes.Current()
    if id == Themes.CLASSIC then return nil, "CLASSIC" end
    local why = refuse()
    if why then return nil, why end
    local base = storedSets()[Themes.CLASSIC]
    if not base then return nil, "NO_CLASSIC" end
    use(seed(id, base))
    return true
end

-- The themes with stored settings to copy from, in IDS order.
function Themes.Stored()
    local sets, list = storedSets(), {}
    for _, id in ipairs(Themes.IDS) do
        if sets[id] and id ~= Themes.Current() then list[#list + 1] = id end
    end
    return list
end

-- Every setting that places something: the frames' position, and each
-- section's placement rows (anchors, points, offsets, growth) of the
-- options schema.
function Themes.PlacementKeys()
    local keys, seen = {}, {}
    local function add(key)
        if not seen[key] then seen[key] = true; keys[#keys + 1] = key end
    end
    for _, source in ipairs({ ns.Schema.GENERAL, ns.Schema.FRAME }) do
        for _, tab in ipairs(source) do
            for _, section in ipairs(tab.sections or {}) do
                if section.id == "position" then
                    for _, key in ipairs(section.keys) do add(key) end
                end
                for _, key in ipairs(section.placement or {}) do add(key) end
            end
        end
    end
    return keys
end

-- The positions of theme `from` taken over into the current one. Returns
-- what it replaced (Themes.Restore puts it back), or nil and why not.
function Themes.CopyPlacement(from)
    local why = refuse()
    if why then return nil, why end
    local source = storedSets()[from]
    if not source then return nil, "GONE" end
    local keys, undo = Themes.PlacementKeys(), {}
    for _, scope in ipairs(ns.Settings.SCOPES) do
        local own = type(source[scope]) == "table" and source[scope] or {}
        local values = {}
        for i, key in ipairs(keys) do values[i] = { key, ns.CopyValue(own[key]) } end
        undo[scope] = ns.Config.Snapshot(scope, keys)
        ns.Config.Restore(scope, values)
    end
    return undo
end

function Themes.Restore(undo)
    if refuse() then return nil end
    for scope, saved in pairs(undo) do ns.Config.Restore(scope, saved) end
    return true
end

-- At login, before any frame exists (Core/Boot.lua): a theme in use made
-- under an older REVISION is made anew from CLASSIC, quietly (no event:
-- nothing listens yet; the next save writes it).
function Themes.Upgrade()
    local sets = ns.UnitProfiles.ThemeSets()
    if sets.revision == Themes.REVISION then return end
    local current = Themes.Current()
    local base = sets[Themes.CLASSIC]
    storedSets()
    if current == Themes.CLASSIC or not base then return end
    local fresh = ns.Settings.Sanitise(seed(current, base))
    local profile = ns.Config.Profile()
    for _, scope in ipairs(ns.Settings.SCOPES) do profile[scope] = fresh[scope] or {} end
end

-- For a theme picker in another addon (one entry per Forever addon).
_G.ForeverThemes = _G.ForeverThemes or {}
_G.ForeverThemes["ForeverUnitFrames"] = {
    title = "Forever Unit Frames",
    Current = Themes.Current,
    Switch = Themes.Switch,
}
