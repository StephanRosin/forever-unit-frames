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

local Lib = LibForeverThemes
Themes.CLASSIC = Lib.CLASSIC

-- Each theme's identity (backdrop, tint, ornaments, rule, title strip and
-- wedge, ring colour, font, fontSizeAdd) is LibForeverThemes'; here only
-- the unit frames' part on top (Lib.Specs). The HD themes (`true`) take
-- their base theme's part, over a finer backdrop of their own.
-- look: settings the theme sets in General (every frame follows General
-- for these, see seed). font: the theme's one font for every text (the
-- library's title face, but the body face where the theme has a readable
-- one of its own: Swiss, Console, Pitwall); bar: its bar texture.
-- art (Elements/ThemeArt.lua), on top of the library's: ornamentSize,
-- ornamentInset = how far in from the border's outer corner (negative:
-- further out), ornamentHeight = its height when not square, hardShadow =
-- offset of a solid shadow, accent = what the theme's colour paints
-- (Themes.Accent).
-- borderPadding shows the backdrop round the bars.
-- fontOutline: the client's OUTLINE, never SOFT. With the theme fonts
-- SOFT (Elements/Texts.lua) showed black text in game; why is not known
-- (the text has its font by GetFont, its black copies draw on top).
-- Frost alone has none: a 1 px drop shadow (fontShadow, black) keeps its
-- texts readable, white values on a priest's white health bar too.
Themes.SPECS = Lib.Specs({
    -- Oak boards round the bars, a gold rim (as in every Forever addon), brass rivets.
    WOOD = {
        bar = "FUF Wood",
        look = { borderShow = true, borderStyle = "GOLD", borderSize = 3, borderPadding = 4, cornerRadius = 3,
            backgroundColor = { 0.1, 0.06, 0.02, 0 }, titleBackground = false,
            shadowEnabled = true, shadowAlpha = 60, shadowSize = 6, fontOutline = "OUTLINE" },
        art = { ornamentSize = 11, ornamentInset = 1 },
    },
    -- Dark navy with a faint grid, a thin cyan line.
    TECH = {
        bar = "FUF Tech",
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.TECH.rim,
            borderPadding = 3, cornerRadius = 0, backgroundColor = { 0.02, 0.05, 0.08, 0 },
            titleBackground = false, shadowEnabled = false, fontOutline = "OUTLINE" },
    },
    -- Parchment round the bars, a brown ink line, a wax seal.
    PARCHMENT = {
        bar = "FUF Parchment",
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 2, borderColor = Lib.THEMES.PARCHMENT.rim,
            borderPadding = 4, cornerRadius = 2, backgroundColor = { 0.22, 0.15, 0.07, 0 }, titleBackground = false,
            shadowEnabled = true, shadowAlpha = 45, shadowSize = 5, fontOutline = "OUTLINE" },
        art = { ornamentSize = 22, ornamentInset = -6 },
    },
    -- Grey granite, a dark chiselled edge, glowing runes.
    RUNESTONE = {
        bar = "FUF Stone",
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 2, borderColor = Lib.THEMES.RUNESTONE.rim,
            borderPadding = 5, cornerRadius = 0, backgroundColor = { 0.04, 0.05, 0.06, 0 },
            titleBackground = false, shadowEnabled = true, shadowAlpha = 70, shadowSize = 6, fontOutline = "OUTLINE" },
        art = { ornamentSize = 14, ornamentInset = 2 },
    },
    -- A mosaic of coloured glass round the bars, dark lead.
    GLASS = {
        bar = "FUF Glass",
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 3, borderColor = Lib.THEMES.GLASS.rim,
            borderPadding = 6, cornerRadius = 0, backgroundColor = { 0.05, 0.04, 0.06, 0.9 },
            titleBackground = true, shadowEnabled = true, shadowAlpha = 55, shadowSize = 6, fontOutline = "OUTLINE" },
    },
    -- Thick ink line, halftone paper, a solid shadow.
    COMIC = {
        bar = "FUF Comic",
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 3, borderColor = Lib.THEMES.COMIC.rim,
            borderPadding = 0, cornerRadius = 0, backgroundColor = { 0, 0, 0, 0 }, titleBackground = false,
            shadowEnabled = false, fontOutline = "THICKOUTLINE" },
        art = { hardShadow = 5 },
    },
    -- Translucent ice, a pale rim, rounded.
    FROST = {
        bar = "FUF Frost",
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.FROST.rim,
            borderPadding = 2, cornerRadius = 6, backgroundColor = { 0.02, 0.07, 0.15, 0.45 },
            titleBackground = false, shadowEnabled = true, shadowAlpha = 55, shadowSize = 8, fontOutline = "NONE",
            fontShadow = true },
    },
    -- A light pixel frame, scan lines, a solid shadow.
    PIXEL = {
        bar = "FUF Pixel",
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 3, borderColor = Lib.THEMES.PIXEL.rim,
            borderPadding = 0, cornerRadius = 0, backgroundColor = { 0, 0, 0, 0 }, titleBackground = false,
            shadowEnabled = false, fontOutline = "OUTLINE" },
        art = { hardShadow = 4 },
    },
    -- Swiss: flat black, a white rule along the top, one red accent on it
    -- (a short bar at the top left, which the theme's colour paints).
    SWISS = {
        font = "Inter Tight", bar = "FUF Swiss",
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.SWISS.rim,
            borderPadding = 3, cornerRadius = 0, backgroundColor = { 0.039, 0.039, 0.039, 1 },
            titleBackground = false, shadowEnabled = false, fontOutline = "OUTLINE" },
        art = { ornament = "SwissBar", corners = { 1 }, ornamentSize = 12, ornamentHeight = 3,
            ornamentColor = { 1, 0.176, 0.125, 1 }, accent = "ornament" },
    },
    -- A terminal: near black with scan lines, a mint ring, solid bars
    -- (dashed ones looked broken on health and power).
    CONSOLE = {
        font = "IBM Plex Mono", bar = "FUF Swiss",
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.CONSOLE.rim,
            borderPadding = 3, cornerRadius = 0, backgroundColor = { 0.306, 0.929, 0.69, 0 },
            titleBackground = false, shadowEnabled = false, fontOutline = "OUTLINE" },
        art = { accent = "ring" },
    },
    -- A timing screen: calm and black (the carbon weave read as stripes at
    -- frame size), the name row a black strip with the red wedge at its
    -- start, solid bars (LED segments looked broken) on a black track,
    -- health in the player's own colour. The ring is the
    -- carbon's own colour: none to see, but it keeps the auras clear of
    -- the padding (Border.Extent).
    PITWALL = {
        -- The older name of the library's "Titillium Web SemiBold" (the same
        -- file): theme sets and Platynator designs hold it.
        font = "Titillium Web", bar = "FUF Swiss",
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.PITWALL.rim,
            borderPadding = 3, cornerRadius = 0, backgroundColor = { 0.039, 0.039, 0.039, 1 },
            titleBackground = true, shadowEnabled = false, fontOutline = "OUTLINE" },
        art = { accent = "wedge" },
    },
    -- A window of the game's own world: light parchment in a walnut frame
    -- (outside the gold ring), gold corners on the frame. No banner: a unit
    -- frame has no title bar. The bars' texts stay light and outlined;
    -- texts on the parchment itself (title and footer rows) are dark ink
    -- without an outline (ink, Themes.Ink).
    AZEROTH = {
        font = "Alegreya", bar = "FUF Parchment", ink = { 0.14, 0.08, 0.04 },
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 2, borderColor = Lib.THEMES.AZEROTH.rim,
            borderPadding = 3, cornerRadius = 0, backgroundColor = { 0, 0, 0, 0 }, titleBackground = false,
            shadowEnabled = true, shadowAlpha = 60, shadowSize = 8, fontOutline = "OUTLINE" },
        art = { ornamentSize = 14, ornamentInset = 0, frameSize = 5 },
    },
    -- A goblin workshop: sooty sheet metal in a copper frame with rivets
    -- (its warning stripes only on a window with a title, Raid/BuffWatchWindow.lua).
    GOBLIN = {
        font = "Rubik Medium", bar = "FUF Tech",
        look = { borderShow = true, borderStyle = "FLAT", borderSize = 2, borderColor = Lib.THEMES.GOBLIN.rim,
            borderPadding = 3, cornerRadius = 0, backgroundColor = { 0, 0, 0, 0 }, titleBackground = false,
            shadowEnabled = true, shadowAlpha = 60, shadowSize = 8, fontOutline = "OUTLINE" },
        art = { ornamentSize = 9, ornamentInset = 0, frameSize = 5 },
    },
}, true)
-- Glass HD is there to show its glass: the dark fill over it at 60 % (Glass: 90 %).
Themes.SPECS.GLASS_HD.look.backgroundColor[4] = 0.6

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
    if key == "fontFace" then return Lib.LatinClient() and spec.font or nil end
    if key == "fontSize" or key == "valueFontSize" then
        local add = spec.fontSizeAdd or 0
        if add == 0 then return nil end
        local size = own()
        return size > 0 and size + add or size
    end
    if key == "borderSize" then return math.min(look.borderSize, CELL_BORDER_MAX) end
    if key == "borderColor" then return Themes.Rim(id) or look.borderColor end
    if key == "cornerRadius" then return math.min(look.cornerRadius, CELL_RADIUS_MAX) end
    return look[key]
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

-- Whether a and b hold the same settings; the theme ids (general.theme,
-- and the library's own field on a merged set) do not count.
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if k ~= "theme" and not same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if k ~= "theme" and a[k] == nil then return false end
    end
    return true
end

local function scopesOf(p)
    for _, scope in ipairs(ns.Settings.SCOPES) do
        if type(p[scope]) ~= "table" then p[scope] = {} end
    end
end

-- Raised whenever SPECS change a look: theme sets made before are made
-- anew from CLASSIC (Themes.Upgrade), so a changed theme shows as it is
-- now. CLASSIC is never touched. The library's part counts too: a change
-- there to what seeding copies (fonts, sizes, ring colour) raises it.
local OWN_REVISION = 13
Themes.REVISION = OWN_REVISION   -- tools/theme-presets-from-sv.lua reads it

-- The active profile's stored theme sets; stale ones (Lib.NeedsReseed)
-- dropped.
local function storedSets()
    local sets = ns.UnitProfiles.ThemeSets()
    if Lib.NeedsReseed(sets, OWN_REVISION) then
        for _, id in ipairs(Lib.SpecIds(Themes.SPECS)) do
            if id ~= Themes.CLASSIC then sets[id] = nil end
        end
        Lib.MarkSeeded(sets, OWN_REVISION)
    end
    return sets
end

function Themes.Current()
    return ns.Config.Get("general", "theme")
end

function Themes.Spec(id)
    return Themes.SPECS[id] or Themes.SPECS.CLASSIC
end

-- The theme's font for texts beyond the frames (Core/BlizzardFonts.lua,
-- Core/PlatynatorFonts.lua): nil under Classic and where its letters
-- are missing.
function Themes.Font()
    return Lib.LatinClient() and Themes.Spec(Themes.Current()).font or nil
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

-- A new theme's settings: the base set (CLASSIC) with the theme's look
-- and the shipped look of that theme on top (ns.THEME_PRESETS, Core/Preset.lua:
-- the author's own sets, nothing that places a frame).
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
    if spec.font and Lib.LatinClient() then p.general.fontFace = spec.font end
    growFonts(p, spec.fontSizeAdd or 0)
    -- The target as large as the player: the two sit side by side.
    for _, key in ipairs({ "width", "height" }) do
        p.target[key] = ns.Config.ValueIn(p, "player", key)
    end
    -- An HD theme without a preset of its own takes its base theme's.
    local presets = ns.THEME_PRESETS or {}
    for scope, values in pairs(presets[id] or presets[Lib.BaseTheme(id)] or {}) do
        for key, value in pairs(values) do p[scope][key] = copy(value) end
    end
    p.general.theme = id
    return p
end
-- For tools/theme-presets-from-sv.lua.
Themes.Seed = seed

local function refuse()
    if InCombatLockdown() then return "COMBAT" end
    if ns.Storage.IsWaiting() then return "WAITING" end
    return nil
end

local function use(p)
    ns.Config.Import(ns.Settings.Sanitise(copy(p)))
    ns.Storage.Save()
end

-- A theme's colour ids in order (themeId defaults to the current theme;
-- CLASSIC has none).
function Themes.Colors(themeId)
    return Lib.Colors(themeId or Themes.Current())
end

-- A theme's colour chosen; an unknown one stored reads as its first.
function Themes.Color(themeId)
    themeId = themeId or Themes.Current()
    return Lib.ValidColor(themeId, ns.UnitProfiles.ThemeColors()[themeId])
end

-- spec's theme id: raid cells and Smart Buffs pass their own theme's spec.
local function idOf(spec)
    for id, s in pairs(Themes.SPECS) do
        if s == spec then return id end
    end
    return nil
end

-- Theme id's colour where its art.accent is `where` ("ring": the border,
-- "ornament": the corner piece, "wedge": the title wedge); nil for its first
-- colour or another place.
function Themes.Accent(id, where)
    local art = Themes.Spec(id).art
    if not art or art.accent ~= where then return nil end
    local c = Lib.Paint(id, Themes.Color(id))
    local accent = c and (c.accent or c.wedge)
    return accent and { accent[1], accent[2], accent[3], 1 }
end

-- The ring's colour under theme id's colour, where it is not the theme's
-- own: Console's accent, Pixel's Handheld green. Nothing else tints a ring.
function Themes.Rim(id)
    local rim = Lib.Rim(id, Themes.Color(id))
    if rim then return { rim[1], rim[2], rim[3], 1 } end
    return Themes.Accent(id, "ring")
end

-- Above this alpha a title row's own background hides the parchment: its
-- texts stay light.
local INK_MAX_ROW_ALPHA = 0.5

-- The ink colour { r, g, b } for frame's title and footer rows, or nil
-- where they stay light: only a theme with ink (Azeroth's light
-- parchment), only while the rows show the backdrop.
function Themes.Ink(frame)
    local id = frame.themeOf and frame.themeOf() or Themes.Current()
    local ink = Themes.Spec(id).ink
    if not ink then return nil end
    local scope = frame.key
    local clear = not ns.Config.Get(scope, "titleBackground") or ns.Config.Get(scope, "backgroundColor")[4]
        <= INK_MAX_ROW_ALPHA
    return clear and ink or nil
end

-- A colour (class, reaction, level) in dark ink on light parchment:
-- luminance at most this, about 6:1 there (small texts: the quest log's 0.13
-- read grey here). Plain darkening turned yellow
-- olive; yellow goes amber first (as Forever Quest Log's Themes.TitleInk).
-- A secret colour (class in combat) cannot be measured: ink then.
local INK_LUMINANCE, AMBER, INK_GREY = 0.05, 0.68, 0.15
local function luminance(r, g, b)
    local function lin(v) return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end
function Themes.InkColor(r, g, b, ink)
    if ns.Secrets.IsSecret(r) then return ink[1], ink[2], ink[3] end
    -- White and grey (a priest, a neutral level) darkened read as grey: ink.
    if math.max(r, g, b) - math.min(r, g, b) < INK_GREY then return ink[1], ink[2], ink[3] end
    if r > 0.8 and g > 0.8 and b < 0.3 then g = r * AMBER end
    local lum = luminance(r, g, b)
    if lum <= INK_LUMINANCE then return r, g, b end
    local k = (INK_LUMINANCE / lum) ^ (1 / 2.2)
    return r * k, g * k, b * k
end

-- The backdrop's texture under spec: the grey one under a colour.
function Themes.Back(spec)
    local id = idOf(spec)
    return Lib.Back(spec.art, id, Themes.Color(id))
end

-- The backdrop's tint under spec: the comic's paper in its colour, or the
-- grey texture tinted to the colour at the theme's alpha (unit frames, raid
-- cells and the Smart Buffs window alike).
function Themes.Tint(spec)
    if not spec.art then return nil end
    local id = idOf(spec)
    return Lib.Tint(spec.art, id, Themes.Color(id))
end

-- A theme's colour (themeId defaults to the current theme). Repaints at
-- once; refused while that theme shows (unit frames or raid cells) where
-- Switch would be, since it restyles secure frames.
function Themes.SetColor(id, themeId)
    themeId = themeId or Themes.Current()
    if not Lib.Colour(themeId, id) then return nil, "UNKNOWN" end
    local shown = Themes.Current() == themeId or ns.RaidCell.Theme() == themeId
    local why = shown and refuse()
    if why then return nil, why end
    ns.UnitProfiles.ThemeColors()[themeId] = id ~= Lib.COLORS[themeId][1].id and id or nil
    ns.Fire("CONFIG_CHANGED", nil, nil)
    ns.Fire("RAID_CONFIG_CHANGED", "general", "cellTheme")
    return true
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
    -- A base and its HD theme share one set (Lib.SetKey): the settings
    -- stay, only the look keys where the two specs differ follow (Glass
    -- HD's thinner fill), unless the player changed them.
    if Lib.SetKey(id) == Lib.SetKey(current) then
        local p = copy(ns.Config.Profile())
        local oldLook = Themes.Spec(current).look or {}
        for key, value in pairs(Themes.Spec(id).look or {}) do
            if not same(oldLook[key], value) and same(p.general[key], oldLook[key]) then p.general[key] = copy(value) end
        end
        p.general.theme = id
        use(p)
        return true
    end
    local sets = storedSets()
    sets[Lib.SetKey(current)] = copy(ns.Config.Profile())
    local nextSet = sets[Lib.SetKey(id)]
    if not nextSet then
        -- CLASSIC is never made from a theme: without a stored one (a
        -- profile imported with a theme) the settings stay as they are.
        local base = sets[Themes.CLASSIC] or ns.Config.Profile()
        nextSet = id == Themes.CLASSIC and copy(base) or seed(id, base)
    end
    -- The family's set may have been stored under its other member.
    nextSet.general = nextSet.general or {}
    nextSet.general.theme = id
    -- The live set is the profile: no stale copy stays behind.
    sets[Lib.SetKey(id)] = nil
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

-- The themes with stored settings to copy from, in the library's order
-- (an HD theme's are its base's).
function Themes.Stored()
    local sets, list = storedSets(), {}
    for _, id in ipairs(Lib.MenuIds(Lib.SpecIds(Themes.SPECS))) do
        if sets[id] and id ~= Lib.SetKey(Themes.Current()) then list[#list + 1] = id end
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

-- Up to 0.65.7 a base and its HD theme had a set each: made one, once per
-- profile (Lib.MergeHD; at login and when a profile is loaded). p: the
-- active profile's settings about to be live; returns the ones to use
-- instead, or p itself. A stored HD set wins when it differs from seeding
-- that HD theme afresh from the stored CLASSIC set, or the base has none.
function Themes.MergeHD(p)
    local sets = ns.UnitProfiles.ThemeSets()
    local current = type(p.general) == "table" and p.general.theme or Themes.CLASSIC
    local merged = Lib.MergeHD(sets, current, copy(p), function(hdId, set)
        local classic = sets[Themes.CLASSIC] or (current == Themes.CLASSIC and p)
        return not (classic and same(set, ns.Settings.Sanitise(seed(hdId, classic))))
    end)
    -- The library names a set's theme in .theme; ours is general.theme.
    for _, set in pairs(sets) do
        if type(set) == "table" then set.theme = nil end
    end
    if not merged then return p end
    merged.theme = nil
    merged.general.theme = current
    return merged
end

-- At login, before any frame exists (Core/Boot.lua): a theme in use made
-- under an older REVISION is made anew from CLASSIC, quietly (no event:
-- nothing listens yet; the next save writes it).
function Themes.Upgrade()
    local profile = ns.Config.Profile()
    local merged = Themes.MergeHD(profile)
    if merged ~= profile then
        for _, scope in ipairs(ns.Settings.SCOPES) do profile[scope] = merged[scope] or {} end
    end
    local sets = ns.UnitProfiles.ThemeSets()
    if not Lib.NeedsReseed(sets, OWN_REVISION) then return end
    local current = Themes.Current()
    local base = sets[Themes.CLASSIC]
    storedSets()
    if current == Themes.CLASSIC or not base then return end
    local fresh = ns.Settings.Sanitise(seed(current, base))
    for _, scope in ipairs(ns.Settings.SCOPES) do profile[scope] = fresh[scope] or {} end
end

-- For a theme picker in another addon (one entry per Forever addon).
local ADDON = "ForeverUnitFrames"
Lib.Register(ADDON, {
    title = "Forever Unit Frames",
    Current = Themes.Current,
    Switch = Themes.Switch,
    Colors = Themes.Colors,
    Color = Themes.Color,
    SetColor = Themes.SetColor,
})

-- "Apply to all Forever addons" (the options' theme rows): the other addons
-- registered above.
function Themes.HasOthers() return #Lib.Others(ADDON) > 0 end

-- The hub addon "Forever Themes" (LibForeverThemes §2.12): nil without it.
-- While it is there it owns the theme font beyond the frames
-- (Core/BlizzardFonts.lua, Core/PlatynatorFonts.lua stand down).
function Themes.Hub() return Lib.Hub() end
-- Whether the hub sets our theme and colour now (the options grey them).
function Themes.FollowsHub() return Lib.Follows(ADDON) end

-- Every other addon onto this theme and, where that theme has it, this
-- colour. Returns how many switched.
function Themes.ApplyToAll()
    return Lib.ApplyToAll(ADDON, Themes.Current(), Themes.Color())
end
