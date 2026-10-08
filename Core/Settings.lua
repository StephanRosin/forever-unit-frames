local _, ns = ...

-- The one list of every unit-frame setting. Config, Codec, the options
-- window and the tests all read from here. A setting's `code` is written
-- into saved and exported strings: once released it must never change or
-- be reused. The registry itself is Core/Registry.lua.
local Settings = ns.NewRegistry(
    { "general", "player", "target", "targettarget", "pet", "focus", "party" },
    { general = "g", player = "p", target = "t", targettarget = "o", pet = "e", focus = "f", party = "y" })
ns.Settings = Settings

-- Definitions -----------------------------------------------------------------
-- Order here is the order of the options pages; codes are permanent.

-- Stored by index: new tags go at the end. INFO: level, class and race
-- ("60 Mage Gnome"); creatures: level and type ("60 Humanoid").
local TEXT_TAGS = { "NONE", "NAME", "NAME_LEVEL", "LEVEL", "CURRENT", "CURRENT_MAX", "PERCENT", "DEFICIT", "INFO" }
Settings.TEXT_TAGS = TEXT_TAGS
-- The anchor points a placed icon or group chooses from.
Settings.POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

-- General appearance (inherited by every frame, overridable per frame)
-- The font settings, in the order the options page lists them.
Settings.FONT_KEYS = { "fontFace", "fontSize", "fontOutline", "fontShadow" }
-- What "Apply to all frames" hands back to General: the font settings of
-- the section the button sits in (the display options have their own).
Settings.TEXT_STYLE_KEYS = { "fontFace", "fontSize", "valueFontSize", "fontOutline", "fontShadow" }
Settings.Define({ key = "fontFace", code = "FF", scope = "inherit", type = "media", mediaKind = "font", default = "Friz Quadrata" })
Settings.Define({ key = "fontSize", code = "FS", scope = "inherit", type = "int", min = 6, max = 32, default = 12 })
Settings.Define({ key = "fontOutline", code = "FO", scope = "inherit", type = "enum",
    values = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "SOFT" }, default = "SOFT" })
Settings.Define({ key = "fontShadow", code = "FH", scope = "inherit", type = "bool", default = false })
-- Secondary name (surname) next to the first name, like Blizzard's frames.
Settings.Define({ key = "showSurname", code = "SN", scope = "inherit", type = "bool", default = true })
-- Blizzard's AFK or DND icon (as in the friends list) right after the name
-- in the title text.
Settings.Define({ key = "awayBadge", code = "AK", scope = "inherit", type = "bool", default = true })
-- Class icon at the right end of the title row (players only).
-- Only players have a class: no class icon settings for the pet frame.
local CLASS_UNITS = { player = true, target = true, targettarget = true, focus = true, party = true }
Settings.Define({ key = "titleClassIcon", only = CLASS_UNITS, code = "CL", scope = "inherit", type = "bool", default = true })
-- The icon is a round badge on the frame's top right corner: its size and
-- the offset of its centre from that corner. The defaults put it slightly
-- inside horizontally and mostly above the top edge.
Settings.Define({ key = "classIconSize", only = CLASS_UNITS, code = "KS", scope = "inherit", type = "int", min = 10, max = 48, default = 28 })
Settings.Define({ key = "classIconX", only = CLASS_UNITS, code = "KX", scope = "inherit", type = "int", min = -64, max = 64, default = -6 })
Settings.Define({ key = "classIconY", only = CLASS_UNITS, code = "KY", scope = "inherit", type = "int", min = -64, max = 64, default = 2 })
-- The badge's own round ring, independent of the frame border: thickness
-- (0 turns it off, the icon then fills the badge) and colour.
Settings.Define({ key = "classIconRing", only = CLASS_UNITS, code = "KR", scope = "inherit", type = "int", min = 0, max = 4, default = 2 })
Settings.Define({ key = "classIconRingColor", only = CLASS_UNITS, code = "KC", scope = "inherit", type = "color",
    default = { 0.78, 0.78, 0.8, 1 } })
Settings.Define({ key = "barTexture", code = "BT", scope = "inherit", type = "media", mediaKind = "statusbar", default = "Flat" })
Settings.Define({ key = "backgroundColor", code = "BC", scope = "inherit", type = "color", default = { 0, 0, 0, 0.6 } })
-- The title row (name, level) takes the background colour too; off, it is
-- clear and only the bars keep a background (their empty part stays seen).
Settings.Define({ key = "titleBackground", code = "NB", scope = "inherit", type = "bool", default = true })
-- Outer border (Core/Border.lua): one ring around the unit, a docked
-- castbar included. Hidden keeps size and padding for later. Styles are
-- stored by index: append only.
Settings.Define({ key = "borderShow", code = "BV", scope = "inherit", type = "bool", default = true })
Settings.Define({ key = "borderStyle", code = "BY", scope = "inherit", type = "enum",
    values = { "FLAT", "GOLD" }, default = "FLAT" })
-- From 1: no border is borderShow's job; a 0 of an earlier version
-- loads as borderShow off (Registry: Upgrade).
Settings.Define({ key = "borderSize", code = "BS", scope = "inherit", type = "int", min = 1, max = 8, default = 1,
    offBelowMin = "borderShow" })
Settings.Define({ key = "borderColor", code = "BO", scope = "inherit", type = "color", default = { 0, 0, 0, 1 } })
Settings.Define({ key = "borderPadding", code = "BP", scope = "inherit", type = "int", min = 0, max = 8, default = 0 })
-- Soft drop shadow around the ring: strength in percent, size in pixels.
Settings.Define({ key = "shadowEnabled", code = "SE", scope = "inherit", type = "bool", default = false })
Settings.Define({ key = "shadowAlpha", code = "SA", scope = "inherit", type = "int", min = 0, max = 100, default = 50 })
Settings.Define({ key = "shadowSize", code = "SZ", scope = "inherit", type = "int", min = 1, max = 16, default = 4 })
Settings.Define({ key = "cornerRadius", code = "CR", scope = "inherit", type = "int", min = 0, max = 12, default = 0 })

-- Colors
Settings.Define({ key = "healthColorMode", code = "HM", scope = "inherit", type = "enum",
    values = { "CLASS", "REACTION", "STATIC", "GRADIENT" }, default = "STATIC" })
Settings.Define({ key = "healthColor", code = "HC", scope = "inherit", type = "color", default = { 0.2, 0.75, 0.3, 1 } })
-- The reaction colours (health bar and title "by reaction").
Settings.Define({ key = "reactionFriendlyColor", code = "RG", scope = "inherit", type = "color",
    default = { 0.2, 0.75, 0.3, 1 } })
Settings.Define({ key = "reactionNeutralColor", code = "RN", scope = "inherit", type = "color",
    default = { 0.9, 0.8, 0.25, 1 } })
Settings.Define({ key = "reactionHostileColor", code = "RH", scope = "inherit", type = "color",
    default = { 0.85, 0.2, 0.2, 1 } })
-- Colour of the shield's stripes; the shield darkens the bar under them.
Settings.Define({ key = "absorbColor", code = "AC", scope = "inherit", type = "color", default = { 1, 1, 1, 0.65 } })
Settings.Define({ key = "healMyColor", code = "MC", scope = "inherit", type = "color", default = { 0.3, 0.95, 0.45, 0.65 } })
Settings.Define({ key = "healOtherColor", code = "OC", scope = "inherit", type = "color", default = { 0.15, 0.65, 0.3, 0.55 } })
-- Where the shield shows: after the health fill (only where health is
-- missing, the client's own look), or from the bar's right end over the
-- health, so it also shows at full health.
Settings.Define({ key = "absorbMode", code = "AP", scope = "inherit", type = "enum", values = { "AFTER", "END" },
    default = "AFTER" })
-- Power bar colours per power type (Elements/Power.lua).
Settings.Define({ key = "powerColorMana", code = "UM", scope = "inherit", type = "color", default = { 0.25, 0.5, 1, 1 } })
Settings.Define({ key = "powerColorRage", code = "UG", scope = "inherit", type = "color", default = { 0.85, 0.2, 0.2, 1 } })
Settings.Define({ key = "powerColorFocus", code = "UF", scope = "inherit", type = "color", default = { 1, 0.5, 0.25, 1 } })
Settings.Define({ key = "powerColorEnergy", code = "UE", scope = "inherit", type = "color", default = { 1, 0.85, 0.2, 1 } })

-- The master switch "Use unit frames": off, every unit frame counts as
-- switched off (ns.FrameEnabled), each frame's own "enabled" kept as it
-- is, so switching it back on restores them. The raid frames do not
-- depend on it.
Settings.Define({ key = "unitFrames", code = "UU", scope = "general", type = "bool", default = true })
-- Click-casting on the unit frames (decision 76): the raid window's
-- bindings (Raid/ClickCast.lua) on the player, pet, target, target of
-- target, focus and party member buttons. One switch on General, each
-- frame may override it. With the default bindings nothing changes.
Settings.Define({ key = "clickCast", code = "CK", scope = "inherit", type = "bool", default = true })

-- Frame layout
Settings.Define({ key = "enabled", code = "E", scope = "frame", type = "bool", default = true })
Settings.Define({ key = "width", code = "W", scope = "frame", type = "int", min = 40, max = 600,
    default = { player = 220, target = 220, focus = 160, party = 160, _ = 120 } })
Settings.Define({ key = "height", code = "H", scope = "frame", type = "int", min = 8, max = 200,
    default = { player = 46, target = 46, focus = 36, party = 46, _ = 28 } })
-- Rows, top to bottom: title, health, power; each a share of the frame
-- height, and together they fill it (Layout.Rows). A title of 0 is the
-- two-row layout.
Settings.Define({ key = "titlePercent", code = "TP", scope = "frame", type = "int", min = 0, max = 60,
    default = { player = 30, target = 30, focus = 30, party = 30, _ = 0 } })
Settings.Define({ key = "healthPercent", code = "HP", scope = "frame", type = "int", min = 10, max = 100,
    default = { player = 45, target = 45, focus = 45, party = 45, _ = 75 } })
Settings.Define({ key = "powerPercent", code = "PP", scope = "frame", type = "int", min = 0, max = 90, default = 25 })
-- The cost of the spell being cast, faded over the end of the player's
-- power bar (Elements/PowerCost.lua), on by default as on Blizzard's
-- player frame. The colour lies over the bar's own: a light veil.
local POWER_COST = { player = true }
Settings.Define({ key = "powerCostPrediction", code = "PC", scope = "frame", only = POWER_COST, type = "bool",
    default = true })
Settings.Define({ key = "powerCostColor", code = "PQ", scope = "frame", only = POWER_COST, type = "color",
    default = { 1, 1, 1, 0.45 } })
Settings.Define({ key = "powerEnabled", code = "PE", scope = "frame", type = "bool", default = true })
-- NPCs without any power (most beasts) show no empty power bar: the health
-- bar takes its row. Players always have power, so it only ever acts on NPCs.
-- Off by default: the look stays as it was until switched on.
Settings.Define({ key = "powerHideEmpty", code = "PN", scope = "frame",
    only = { target = true, targettarget = true, focus = true }, type = "bool", default = false })
Settings.Define({ key = "absorbEnabled", code = "AB", scope = "frame", type = "bool", default = true })
-- Incoming heals; the overheal lane gives the end of the health row to
-- heals past full health.
Settings.Define({ key = "healPrediction", code = "IH", scope = "frame", type = "bool", default = true })
Settings.Define({ key = "healOverflow", code = "OV", scope = "frame", type = "bool", default = false })
-- Incoming heals drawn in full, past the frame's right edge when they
-- overheal (up to one more bar width).
Settings.Define({ key = "healBeyond", code = "OB", scope = "frame", type = "bool", default = false })
-- With the overheal lane: the power bar ends where the health bar ends.
Settings.Define({ key = "powerMatchesHealth", code = "OM", scope = "frame", type = "bool", default = false })
Settings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000,
    default = { player = -300, target = 300, targettarget = 480, pet = -352, focus = -300, party = -760, _ = 0 } })
Settings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000,
    default = { player = -220, target = -220, targettarget = -220, pet = -272, focus = -120, party = 120, _ = 0 } })

-- Portrait
Settings.Define({ key = "portraitMode", code = "PM", scope = "frame", type = "enum",
    values = { "OFF", "LEFT", "RIGHT" }, default = "OFF" })
Settings.Define({ key = "portraitStyle", code = "PS", scope = "frame", type = "enum",
    values = { "2D", "3D" }, default = "2D" })

-- Elite / rare marker: frames that show units other than you, your pet and
-- your party (players are never elite).
Settings.Define({ key = "eliteMarker", code = "EM", scope = "frame",
    only = { target = true, targettarget = true, focus = true }, type = "bool", default = true })
-- How: the marker (badge on the portrait, or a word), or a thin ring
-- around the frame, gold for elites and bosses, silver for rares.
-- Grey health bar while a creature is tapped by someone else (you get
-- no experience or loot from it), as Blizzard's target frame shows it.
Settings.Define({ key = "tapDenied", code = "TD", scope = "frame",
    only = { target = true, targettarget = true, focus = true }, type = "bool", default = true })
Settings.Define({ key = "eliteMarkerStyle", code = "EZ", scope = "frame",
    only = { target = true, targettarget = true, focus = true }, type = "enum", values = { "MARKER", "BORDER" },
    default = "MARKER" })
Settings.Define({ key = "eliteBorderSize", code = "EU", scope = "frame",
    only = { target = true, targettarget = true, focus = true }, type = "int", min = 1, max = 6, default = 2 })
-- Where the marker (MARKER style) sits: AUTO, the default, is the place it
-- always had (Elements/Classification.lua); X and Y then move it from
-- there. A point on the frame instead puts the marker's own point there.
-- Stored by index: append only.
local ELITE = { target = true, targettarget = true, focus = true }
local ELITE_POINTS = { "AUTO" }
for _, point in ipairs(Settings.POINTS) do ELITE_POINTS[#ELITE_POINTS + 1] = point end
Settings.Define({ key = "eliteMarkerFramePoint", code = "MF", scope = "frame", only = ELITE, type = "enum",
    values = ELITE_POINTS, default = "AUTO" })
Settings.Define({ key = "eliteMarkerPoint", code = "MO", scope = "frame", only = ELITE, type = "enum",
    values = Settings.POINTS, default = "CENTER" })
Settings.Define({ key = "eliteMarkerX", code = "MX", scope = "frame", only = ELITE, type = "int", min = -200, max = 200,
    default = 0 })
Settings.Define({ key = "eliteMarkerY", code = "MY", scope = "frame", only = ELITE, type = "int", min = -200, max = 200,
    default = 0 })
-- Its size: the badge's, or the word's font size. 0, Automatic, is the
-- size it always had (Elements/Classification.lua).
Settings.Define({ key = "eliteMarkerSize", code = "MZ", scope = "frame", only = ELITE, type = "int", min = 0, lowest = 8,
    max = 64, default = 0, zeroText = "AUTO" })
-- Damage and heal numbers inside the frame (Blizzard shows them on the
-- player and pet frames).
Settings.Define({ key = "combatFeedback", code = "CF", scope = "frame", type = "bool",
    default = { player = true, pet = true, _ = false } })
-- Their place on the frame: CENTER is where they always were (over the
-- portrait when there is one, else mid health bar); LEFT and RIGHT are the
-- health bar's edges. Plus an offset.
Settings.Define({ key = "combatFeedbackPoint", code = "CG", scope = "frame", type = "enum",
    values = { "LEFT", "CENTER", "RIGHT" }, default = "CENTER" })
Settings.Define({ key = "combatFeedbackX", code = "CJ", scope = "frame", type = "int", min = -200, max = 200,
    default = 0 })
Settings.Define({ key = "combatFeedbackY", code = "CM", scope = "frame", type = "int", min = -200, max = 200,
    default = 0 })
-- Their font: empty is the frame's font (fontFace).
Settings.Define({ key = "combatFeedbackFont", code = "CO", scope = "frame", type = "media", mediaKind = "font",
    emptyText = "FONT_OF_FRAME", default = "" })
-- The size of a plain number; a critical one is half again as big. 0,
-- Automatic, is the size it always had: half again the frame's font size.
Settings.Define({ key = "combatFeedbackSize", code = "CS", scope = "frame", type = "int", min = 0, lowest = 6,
    max = 48, default = 0, zeroText = "AUTO" })
-- FRAME: the frame's outline (fontOutline).
Settings.Define({ key = "combatFeedbackOutline", code = "CU", scope = "frame", type = "enum",
    values = { "FRAME", "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "SOFT" }, default = "FRAME" })

-- Party block (party only)
local PARTY = { party = true }
Settings.Define({ key = "partyOrientation", code = "OR", scope = "frame", only = PARTY, type = "enum",
    values = { "VERTICAL", "HORIZONTAL" }, default = "VERTICAL" })
Settings.Define({ key = "partySpacing", code = "GS", scope = "frame", only = PARTY, type = "int", min = 0, max = 60, default = 12 })
Settings.Define({ key = "partyShowPlayer", code = "SP", scope = "frame", only = PARTY, type = "bool", default = false })
Settings.Define({ key = "partyShowSolo", code = "SO", scope = "frame", only = PARTY, type = "bool", default = false })
-- Hidden while in a raid group (a visibility driver on the headers).
Settings.Define({ key = "partyHideInRaid", code = "HR", scope = "frame", only = PARTY, type = "bool", default = true })
-- Party pets (Units/PartyPets.lua): one small frame under each member
-- whose pet exists. Height in pixels; the width is the member's.
Settings.Define({ key = "partyShowPets", code = "PT", scope = "frame", only = PARTY, type = "bool", default = false })
Settings.Define({ key = "partyPetHeight", code = "PH", scope = "frame", only = PARTY, type = "int", min = 10, max = 60,
    default = 20 })
-- How the pets stand: LIST, their own packed list below the block; BESIDE,
-- each one next to its owner (a child of the member's button, like the
-- party targets), on the side partyPetSide.
Settings.Define({ key = "partyPetLayout", code = "PL", scope = "frame", only = PARTY, type = "enum",
    values = { "LIST", "BESIDE" }, default = "LIST" })
Settings.Define({ key = "partyPetSide", code = "PB", scope = "frame", only = PARTY, type = "enum",
    values = { "RIGHT", "LEFT" }, default = "RIGHT" })
-- Width of a pet frame; 0: the members' width.
Settings.Define({ key = "partyPetWidth", code = "PW", scope = "frame", only = PARTY, type = "int", min = 0, max = 300,
    default = 0, zeroText = "AUTO" })
-- Room between two pets in the list, and between the block and the list
-- or a member and its pet (ring to ring).
Settings.Define({ key = "partyPetGap", code = "PG", scope = "frame", only = PARTY, type = "int", min = 0, max = 40,
    default = 2 })
-- Moves the whole pet list from its place below the block (positive:
-- right, up), e.g. past buffs that hang below the members.
Settings.Define({ key = "partyPetsX", code = "PJ", scope = "frame", only = PARTY, type = "int", min = -400, max = 400,
    default = 0 })
Settings.Define({ key = "partyPetsY", code = "PK", scope = "frame", only = PARTY, type = "int", min = -400, max = 400,
    default = 0 })
-- Buffs and debuffs on the pet frames: one row beside the pet, centred on
-- it, debuffs first (Units/PartyPets.lua). The members' layout does not
-- fit a frame this low: their groups landed on top of each other. Size,
-- side and offset (positive: right, up) of their own; filters and the
-- maximum are the party's.
Settings.Define({ key = "partyPetAuras", code = "PA", scope = "frame", only = PARTY, type = "bool", default = false })
Settings.Define({ key = "partyPetAuraSize", code = "PU", scope = "frame", only = PARTY, type = "int", min = 8, max = 40,
    default = 14 })
-- How many buffs and how many debuffs a pet shows; 0: as the party.
Settings.Define({ key = "partyPetAuraMax", code = "PZ", scope = "frame", only = PARTY, type = "int", min = 0, max = 16,
    default = 0, zeroText = "AUTO" })
Settings.Define({ key = "partyPetAuraSide", code = "PV", scope = "frame", only = PARTY, type = "enum",
    values = { "RIGHT", "LEFT" }, default = "RIGHT" })
Settings.Define({ key = "partyPetAuraX", code = "PX", scope = "frame", only = PARTY, type = "int", min = -200, max = 200,
    default = 2 })
Settings.Define({ key = "partyPetAuraY", code = "PY", scope = "frame", only = PARTY, type = "int", min = -200, max = 200,
    default = 0 })

-- Party targets (Units/PartyTargets.lua): what each member has targeted, a
-- small frame beside the member. Off by default (it clutters). Side: where
-- it sits, border to border; X / Y move it from there.
Settings.Define({ key = "partyTargets", code = "YA", scope = "frame", only = PARTY, type = "bool", default = false })
Settings.Define({ key = "partyTargetWidth", code = "YW", scope = "frame", only = PARTY, type = "int", min = 40, max = 300,
    default = 100 })
Settings.Define({ key = "partyTargetHeight", code = "YH", scope = "frame", only = PARTY, type = "int", min = 10, max = 60,
    default = 24 })
Settings.Define({ key = "partyTargetSide", code = "YS", scope = "frame", only = PARTY, type = "enum",
    values = { "RIGHT", "LEFT", "ABOVE", "BELOW" }, default = "RIGHT" })
-- Offset from where the side puts it, border to border (positive: right,
-- up); a small gap to the right by default.
Settings.Define({ key = "partyTargetX", code = "YX", scope = "frame", only = PARTY, type = "int", min = -200, max = 200,
    default = 4 })
Settings.Define({ key = "partyTargetY", code = "YY", scope = "frame", only = PARTY, type = "int", min = -200, max = 200,
    default = 0 })

-- Castbar (not on the pet frame; off by default on the player frame)
local CASTBAR = { player = true, target = true, targettarget = true, focus = true, party = true }
Settings.Define({ key = "castbarEnabled", code = "CE", scope = "frame", only = CASTBAR, type = "bool",
    default = { player = false, _ = true } })
-- Player only: conceals Blizzard's PlayerCastingBarFrame. Independent of
-- castbarEnabled -- some players want both cast bars shown at once.
Settings.Define({ key = "hideBlizzardCastbar", code = "CB", scope = "frame", only = { player = true },
    type = "bool", default = false })
-- Single frames may detach their castbar (own mover); party castbars
-- dock above or below each member.
local CASTBAR_SINGLE = { player = true, target = true, targettarget = true, focus = true }
Settings.Define({ key = "castbarPosition", code = "CP", scope = "frame", only = CASTBAR_SINGLE, type = "enum",
    values = { "BELOW", "ABOVE", "DETACHED" }, default = "BELOW" })
Settings.Define({ key = "castbarDock", code = "CD", scope = "frame", only = PARTY, type = "enum",
    values = { "BELOW", "ABOVE" }, default = "BELOW" })
Settings.Define({ key = "castbarX", code = "CX", scope = "frame", only = CASTBAR_SINGLE, type = "int", min = -4000, max = 4000,
    default = { target = 300, targettarget = 480, focus = -300, _ = 0 } })
Settings.Define({ key = "castbarY", code = "CY", scope = "frame", only = CASTBAR_SINGLE, type = "int", min = -4000, max = 4000,
    default = { player = -160, focus = -170, _ = -300 } })
Settings.Define({ key = "castbarHeight", code = "CH", scope = "frame", only = CASTBAR, type = "int", min = 4, max = 60,
    default = { player = 18, target = 16, focus = 16, _ = 12 } })
Settings.Define({ key = "castbarIcon", code = "CI", scope = "frame", only = CASTBAR, type = "bool", default = true })
Settings.Define({ key = "castbarName", code = "CN", scope = "frame", only = CASTBAR, type = "bool", default = true })
Settings.Define({ key = "castbarTime", code = "CT", scope = "frame", only = CASTBAR, type = "bool", default = true })
-- Keeps an empty bar in place while nothing is cast, so what is anchored
-- below it does not jump.
Settings.Define({ key = "castbarAlwaysShow", code = "CA", scope = "frame", only = CASTBAR, type = "bool", default = false })

-- Texts. With a title row the name moves up there and the health bar
-- shows values.
Settings.Define({ key = "titleText", code = "NT", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "NAME_LEVEL", target = "NAME_LEVEL", party = "NAME_LEVEL", _ = "NAME" } })
-- A second title text at the row's right end (the left one ends where it
-- begins), like the left and right texts on the bars.
Settings.Define({ key = "titleTextRight", code = "NR", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = "NONE" })
Settings.Define({ key = "titleColorMode", code = "NC", scope = "frame", type = "enum",
    values = { "CLASS", "REACTION", "WHITE" }, default = "CLASS" })
-- The level number: the text's colour, or by difficulty (red, orange,
-- yellow, green, grey against your level), whatever colour the line has.
Settings.Define({ key = "levelColorMode", code = "LV", scope = "frame", type = "enum",
    values = { "TEXT", "DIFFICULTY" }, default = "TEXT" })
-- "1234/1234" instead of "1234 / 1234".
Settings.Define({ key = "textCompact", code = "TC", scope = "inherit", type = "bool", default = false })
-- Size of the value texts (health and power numbers, percent, deficit);
-- 0: the font size. Names, level, class and race keep the font size.
Settings.Define({ key = "valueFontSize", code = "TV", scope = "inherit", type = "int", min = 0, max = 32, default = 0,
    zeroText = "AUTO" })
-- In "Level, class and race" the class (players) or creature type in the
-- class colour or the reaction colour; race and the rest keep theirs.
Settings.Define({ key = "infoClassColor", code = "NK", scope = "inherit", type = "bool", default = false })
-- Colour of names on the health and power bars (the name tags and INFO);
-- value texts stay white.
Settings.Define({ key = "barNameColorMode", code = "NY", scope = "frame", type = "enum",
    values = { "WHITE", "CLASS", "REACTION" }, default = "WHITE" })
Settings.Define({ key = "textHealthLeft", code = "TL", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "CURRENT_MAX", target = "CURRENT_MAX", focus = "NONE", party = "NONE", _ = "NAME" } })
Settings.Define({ key = "textHealthRight", code = "TR", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "PERCENT", target = "PERCENT", focus = "PERCENT", party = "PERCENT", _ = "NONE" } })
Settings.Define({ key = "textPowerLeft", code = "UL", scope = "frame", type = "enum", values = TEXT_TAGS, default = "NONE" })
Settings.Define({ key = "textPowerRight", code = "UR", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "CURRENT", _ = "NONE" } })
-- A centre text on each row (Elements/Texts.lua), empty by default: while
-- one is set, the left and right texts of its row keep to their third.
Settings.Define({ key = "titleTextCenter", code = "NM", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = "NONE" })
Settings.Define({ key = "textHealthCenter", code = "TM", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = "NONE" })
Settings.Define({ key = "textPowerCenter", code = "UC", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = "NONE" })

-- The border around every aura icon (plain colour on buffs, the dispel
-- colour on debuffs). General, overridable per frame.
Settings.Define({ key = "auraBorder", code = "AZ", scope = "inherit", type = "bool", default = true })
-- Its thickness in pixels.
Settings.Define({ key = "auraBorderSize", code = "AW", scope = "inherit", type = "int", min = 1, max = 6, default = 1 })

-- Auras. Buffs and debuffs are two groups with the same settings, each
-- configured on its own. Codes: J + letter for buffs, D + letter for
-- debuffs (the letter is the same for both groups). Anchor OTHER is the
-- other group.
-- A third group on the party frames, "dispels" (codes I + letter): the
-- debuffs you can dispel, with their own size and place; while it is on,
-- the debuffs group leaves them out. Its OTHER is the debuffs.
Settings.AURA_GROUPS = { "buffs", "debuffs", "dispels" }
-- Tracking and sensing spells (Classic IDs): profession finds, hunter,
-- druid, paladin and warlock tracking. Left out by "Hide tracking".
Settings.TRACKING_SPELLS = {
    2383, 2580, 2481, -- Find Herbs, Find Minerals, Find Treasure
    1494, 19878, 19879, 19880, 19882, 19883, 19884, 19885, -- hunter: Track ...
    5225, -- druid: Track Humanoids
    5502, -- paladin: Sense Undead
    5500, -- warlock: Sense Demons
}
local AURA_ANCHORS = { "FRAME", "HEALTH", "POWER", "CASTBAR", "OTHER" }
local DIRECTIONS = { "RIGHT", "LEFT", "UP", "DOWN" }
local AURA_SIZE = { party = 18, targettarget = 16, pet = 16, _ = 20 }
-- Own auras (cast by you, your pet or vehicle) are drawn this much bigger
-- by default.
local function ownSizes(sizes)
    local out = {}
    for scope, size in pairs(sizes) do out[scope] = math.floor(size * 1.3 + 0.5) end
    return out
end

-- suffix, code letter, definition without key, code and default.
local AURA_SETTINGS = {
    { "Enabled", "E", { type = "bool" } },
    { "OnlyMine", "M", { type = "bool" } },
    { "Dispellable", "V", { type = "bool" } },
    -- Leave out auras without a duration (tracking, stances, auras).
    { "HidePermanent", "P", { type = "bool" } },
    -- Leave out tracking and sensing spells (Settings.TRACKING_SPELLS).
    { "HideTracking", "K", { type = "bool" } },
    -- Leave out buffs lasting longer than this many minutes in all (hour
    -- potions, food, hour-long class buffs); 0 = off. The client then
    -- leaves out auras without a duration too.
    { "HideLonger", "L", { type = "int", min = 0, max = 120, zeroText = "ENUM_OFF" } },
    { "ShowTime", "T", { type = "bool" } },
    { "Anchor", "A", { type = "enum", values = AURA_ANCHORS } },
    { "FramePoint", "F", { type = "enum", values = Settings.POINTS } },
    { "Point", "O", { type = "enum", values = Settings.POINTS } },
    { "X", "X", { type = "int", min = -200, max = 200 } },
    { "Y", "Y", { type = "int", min = -200, max = 200 } },
    { "Growth", "G", { type = "enum", values = DIRECTIONS } },
    { "RowGrowth", "R", { type = "enum", values = DIRECTIONS } },
    { "Size", "S", { type = "int", min = 8, max = 64 } },
    { "Spacing", "D", { type = "int", min = 0, max = 20 } },
    -- 0 = Auto: as many as fit the frame's width (height when growing
    -- up or down).
    { "PerRow", "N", { type = "int", min = 0, max = 40, zeroText = "AUTO" } },
    { "Max", "C", { type = "int", min = 1, max = 40 } },
    -- Own auras first, in their own rows, at their own size.
    { "HighlightOwn", "H", { type = "bool" } },
    { "OwnSize", "B", { type = "int", min = 10, max = 64 } },
    -- Yours first, but in the same rows as the rest (as Shadowed Unit
    -- Frames shows them), not in rows of their own.
    { "OwnSameRow", "Z", { type = "bool" } },
    -- Where yours go with "mine first": WITH the rest (their own rows
    -- before them, or the same rows), or FREE: a block of their own,
    -- anchored to the frame by its own points and offsets, with its own
    -- growth and icons per row (same choices as the group's). The rest
    -- keep the group's place. Codes: the group's own-block letter (O for
    -- buffs, Z for debuffs) + a letter; stored by index: append only.
    { "OwnPlacement", "P", { type = "enum", values = { "WITH", "FREE" } }, true },
    { "OwnFramePoint", "E", { type = "enum", values = Settings.POINTS }, true },
    { "OwnPoint", "T", { type = "enum", values = Settings.POINTS }, true },
    { "OwnX", "H", { type = "int", min = -200, max = 200 }, true },
    { "OwnY", "U", { type = "int", min = -200, max = 200 }, true },
    { "OwnGrowth", "G", { type = "enum", values = DIRECTIONS }, true },
    { "OwnRowGrowth", "W", { type = "enum", values = DIRECTIONS }, true },
    { "OwnPerRow", "N", { type = "int", min = 0, max = 40, zeroText = "AUTO" }, true },
}

-- Debuffs sit above the frame, buffs above the debuffs; party auras to
-- the right of each member. Player buffs are off: Blizzard's buff frame
-- shows them.
local AURA_DEFAULTS = {
    buffs = {
        letter = "J",
        Enabled = { target = true, focus = true, party = true, _ = false },
        OnlyMine = { party = true, _ = false },
        HidePermanent = false,
        HideTracking = false,
        HideLonger = 0,
        ShowTime = true,
        Anchor = "OTHER",
        FramePoint = { party = "TOPRIGHT", _ = "TOPLEFT" },
        Point = { party = "TOPLEFT", _ = "BOTTOMLEFT" },
        X = { party = 2, _ = 0 },
        Y = { party = 0, _ = 2 },
        Growth = "RIGHT",
        RowGrowth = { party = "DOWN", _ = "UP" },
        Size = AURA_SIZE, Spacing = 2, PerRow = 0,
        Max = { party = 4, targettarget = 6, pet = 6, _ = 16 },
        HighlightOwn = false, OwnSize = ownSizes(AURA_SIZE), OwnSameRow = false,
        -- Free, beside the frame's bottom edge (rows up): right of it, on
        -- the party left (the rest sits right of the members).
        ownLetter = "O",
        OwnPlacement = "WITH",
        OwnFramePoint = { party = "BOTTOMLEFT", _ = "BOTTOMRIGHT" },
        OwnPoint = { party = "BOTTOMRIGHT", _ = "BOTTOMLEFT" },
        OwnX = { party = -4, _ = 4 }, OwnY = 0,
        OwnGrowth = { party = "LEFT", _ = "RIGHT" }, OwnRowGrowth = "UP", OwnPerRow = 0,
    },
    debuffs = {
        letter = "D",
        Enabled = { targettarget = false, _ = true },
        OnlyMine = false,
        Dispellable = false,
        HidePermanent = false,
        ShowTime = true,
        Anchor = "FRAME",
        FramePoint = { party = "TOPRIGHT", _ = "TOPLEFT" },
        Point = { party = "TOPLEFT", _ = "BOTTOMLEFT" },
        X = { party = 8, _ = 0 },
        Y = { party = 0, _ = 2 },
        Growth = "RIGHT",
        RowGrowth = { party = "DOWN", _ = "UP" },
        Size = AURA_SIZE, Spacing = 2, PerRow = 0,
        Max = { party = 6, targettarget = 6, pet = 6, _ = 16 },
        HighlightOwn = { target = true, focus = true, _ = false }, OwnSize = ownSizes(AURA_SIZE),
        OwnSameRow = false,
        -- Free, beside the frame's top edge (rows down).
        ownLetter = "Z",
        OwnPlacement = "WITH",
        OwnFramePoint = { party = "TOPLEFT", _ = "TOPRIGHT" },
        OwnPoint = { party = "TOPRIGHT", _ = "TOPLEFT" },
        OwnX = { party = -4, _ = 4 }, OwnY = 0,
        OwnGrowth = { party = "LEFT", _ = "RIGHT" }, OwnRowGrowth = "DOWN", OwnPerRow = 0,
    },
    -- Off by default; when on, centred on the member.
    dispels = {
        letter = "I",
        only = { party = true },
        Enabled = false,
        ShowTime = true,
        Anchor = "FRAME",
        FramePoint = "CENTER",
        Point = "CENTER",
        X = 0,
        Y = 0,
        Growth = "RIGHT",
        RowGrowth = "DOWN",
        Size = 24, Spacing = 2, PerRow = 0,
        Max = 3,
    },
}

for _, group in ipairs(Settings.AURA_GROUPS) do
    local defaults = AURA_DEFAULTS[group]
    for _, entry in ipairs(AURA_SETTINGS) do
        local suffix, letter, template = entry[1], entry[2], entry[3]
        local prefix = entry[4] and defaults.ownLetter or defaults.letter
        -- A setting a group has no default for does not exist for it
        -- (only debuffs can be limited to dispellable ones).
        if defaults[suffix] ~= nil then
            local def = { key = group .. suffix, code = prefix .. letter, scope = "frame",
                only = defaults.only, default = defaults[suffix] }
            for k, v in pairs(template) do def[k] = v end
            Settings.Define(def)
        end
    end
end

-- Buff borders by caster: yours in one colour, everyone else's in another
-- (the container's own/other groups tell them apart). Buffs only: debuff
-- borders show the dispel type.
Settings.Define({ key = "buffsCasterBorder", code = "JW", scope = "frame", type = "bool", default = false })
Settings.Define({ key = "buffsOwnBorderColor", code = "JQ", scope = "frame", type = "color",
    default = { 0.2, 0.85, 0.2, 1 } })
Settings.Define({ key = "buffsOtherBorderColor", code = "JU", scope = "frame", type = "color",
    default = { 0.85, 0.2, 0.2, 1 } })

-- Hidden auras (Core/AuraBlocklist.lua): spell IDs, "1234, 5678". The
-- account's list in General hides an aura on every frame and raid cell,
-- each frame's own list on that frame; both apply. Not inherited: a
-- frame's list adds to the account's rather than replacing it.
local BLOCKLIST = { type = "text", maxLetters = ns.AuraBlocklist.LETTERS, check = ns.AuraBlocklist.Check,
    blocklist = true, default = "" }
local function blocklist(key, code, scope)
    local def = { key = key, code = code, scope = scope }
    for k, v in pairs(BLOCKLIST) do def[k] = v end
    Settings.Define(def)
end
blocklist("auraBlockAccount", "BA", "general")
blocklist("auraBlock", "BL", "frame")

-- Totems (player only, Elements/Totems.lua): one icon per totem slot in a
-- row that hangs from the player's block (the frame and a docked castbar)
-- like an aura group. Right of the block by default: the shipped buffs
-- sit above the frame and the debuffs below the castbar.
local TOTEMS = { player = true }
Settings.Define({ key = "totemsEnabled", code = "QE", scope = "frame", only = TOTEMS, type = "bool", default = true })
Settings.Define({ key = "totemsSize", code = "QS", scope = "frame", only = TOTEMS, type = "int", min = 12, max = 64,
    default = 24 })
Settings.Define({ key = "totemsSpacing", code = "QD", scope = "frame", only = TOTEMS, type = "int", min = 0, max = 20,
    default = 3 })
-- A row (left to right) or a column (top to bottom). Stored by index:
-- append only.
Settings.Define({ key = "totemsDirection", code = "QG", scope = "frame", only = TOTEMS, type = "enum",
    values = { "HORIZONTAL", "VERTICAL" }, default = "HORIZONTAL" })
Settings.Define({ key = "totemsFramePoint", code = "QF", scope = "frame", only = TOTEMS, type = "enum",
    values = Settings.POINTS, default = "RIGHT" })
Settings.Define({ key = "totemsPoint", code = "QO", scope = "frame", only = TOTEMS, type = "enum",
    values = Settings.POINTS, default = "LEFT" })
Settings.Define({ key = "totemsX", code = "QX", scope = "frame", only = TOTEMS, type = "int", min = -400, max = 400,
    default = 6 })
Settings.Define({ key = "totemsY", code = "QY", scope = "frame", only = TOTEMS, type = "int", min = -400, max = 400,
    default = 0 })

-- Combo points (target only, Elements/ComboPoints.lua): a row of pips
-- below the target's block, right-aligned; hidden while there are none.
local COMBO = { target = true }
Settings.Define({ key = "comboPoints", code = "XE", scope = "frame", only = COMBO, type = "bool", default = true })
Settings.Define({ key = "comboHideEmpty", code = "XH", scope = "frame", only = COMBO, type = "bool", default = true })
Settings.Define({ key = "comboShape", code = "XR", scope = "frame", only = COMBO, type = "enum",
    values = { "SQUARE", "ROUND" }, default = "SQUARE" })
Settings.Define({ key = "comboSize", code = "XS", scope = "frame", only = COMBO, type = "int", min = 4, max = 40,
    default = 10 })
Settings.Define({ key = "comboSpacing", code = "XD", scope = "frame", only = COMBO, type = "int", min = 0, max = 20,
    default = 3 })
Settings.Define({ key = "comboColor", code = "XC", scope = "frame", only = COMBO, type = "color",
    default = { 1, 0.82, 0.1, 1 } })
Settings.Define({ key = "comboFramePoint", code = "XF", scope = "frame", only = COMBO, type = "enum",
    values = Settings.POINTS, default = "BOTTOMRIGHT" })
Settings.Define({ key = "comboPoint", code = "XO", scope = "frame", only = COMBO, type = "enum",
    values = Settings.POINTS, default = "TOPRIGHT" })
Settings.Define({ key = "comboX", code = "XX", scope = "frame", only = COMBO, type = "int", min = -400, max = 400,
    default = 0 })
Settings.Define({ key = "comboY", code = "XY", scope = "frame", only = COMBO, type = "int", min = -400, max = 400,
    default = -3 })

-- The shield watch (Elements/ShieldWatch.lua): the icons of your active
-- absorb shields (a Blizzard aura container) and the exact total of all
-- your absorbs, in a block of its own with a mover, on the player frame.
-- Off by default. The watched spells come in groups (each switchable) plus
-- your own additions (spell IDs, validated like the hidden auras). Texts:
-- the total (on by default), placed at a side of the icons, and the time
-- left (the icons' own countdown, off by default), at a side of each icon;
-- each with an offset, a font (empty: the frame's), a size (0: Automatic,
-- from the icon size), a font style (FRAME: the frame's) and a colour.
local SHIELDS = { player = true }
Settings.SHIELD_GROUPS = { "Priest", "Mage", "Warlock", "Items" }
-- Where a text sits: at that side, outside (CENTER: on it).
Settings.SHIELD_TEXT_POINTS = { "TOP", "BOTTOM", "LEFT", "RIGHT", "CENTER" }
local SHIELD_OUTLINES = { "FRAME", "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "SOFT" }
local function shields(def)
    def.scope, def.only = "frame", SHIELDS
    Settings.Define(def)
end
shields({ key = "shieldsEnabled", code = "VB", type = "bool", default = false })
shields({ key = "shieldsPriest", code = "VC", type = "bool", default = true })
shields({ key = "shieldsMage", code = "VD", type = "bool", default = true })
shields({ key = "shieldsWarlock", code = "VI", type = "bool", default = true })
shields({ key = "shieldsItems", code = "VJ", type = "bool", default = true })
-- Spell IDs, "1234, 5678": more shields to watch (the hidden auras' editor).
shields({ key = "shieldsExtra", code = "VL", type = "text", maxLetters = ns.AuraBlocklist.LETTERS,
    check = ns.AuraBlocklist.Check, blocklist = true, spellList = true, default = "" })
-- The watched shields leave the frame's buffs while the watch is on.
shields({ key = "shieldsHideInBuffs", code = "VN", type = "bool", default = true })
shields({ key = "shieldsSize", code = "VO", type = "int", min = 12, max = 64, default = 32 })
shields({ key = "shieldsSpacing", code = "VP", type = "int", min = 0, max = 20, default = 4 })
-- Stored by index: append only.
shields({ key = "shieldsGrowth", code = "VQ", type = "enum", values = { "RIGHT", "LEFT", "UP", "DOWN" },
    default = "RIGHT" })
-- The block's centre, from the screen's centre (its mover).
shields({ key = "shieldsX", code = "VR", type = "int", min = -4000, max = 4000, default = -300 })
shields({ key = "shieldsY", code = "VS", type = "int", min = -4000, max = 4000, default = -140 })
-- The total: before the icons by default (they grow away from it).
shields({ key = "shieldsTotal", code = "VT", type = "bool", default = true })
shields({ key = "shieldsTotalPoint", code = "VV", type = "enum", values = Settings.SHIELD_TEXT_POINTS,
    default = "LEFT" })
shields({ key = "shieldsTotalX", code = "VW", type = "int", min = -64, max = 64, default = -3 })
shields({ key = "shieldsTotalY", code = "VX", type = "int", min = -64, max = 64, default = 0 })
shields({ key = "shieldsTotalFont", code = "ZA", type = "media", mediaKind = "font", emptyText = "FONT_OF_FRAME",
    default = "" })
shields({ key = "shieldsTotalSize", code = "ZB", type = "int", min = 0, lowest = 6, max = 48, default = 0,
    zeroText = "AUTO" })
shields({ key = "shieldsTotalOutline", code = "ZD", type = "enum", values = SHIELD_OUTLINES, default = "FRAME" })
shields({ key = "shieldsTotalColor", code = "ZI", type = "color", default = { 1, 1, 1, 1 } })
shields({ key = "shieldsSwipe", code = "ZJ", type = "bool", default = true })
shields({ key = "shieldsTime", code = "ZK", type = "bool", default = false })
shields({ key = "shieldsTimePoint", code = "ZL", type = "enum", values = Settings.SHIELD_TEXT_POINTS,
    default = "TOP" })
shields({ key = "shieldsTimeX", code = "ZM", type = "int", min = -64, max = 64, default = 0 })
shields({ key = "shieldsTimeY", code = "ZQ", type = "int", min = -64, max = 64, default = 0 })
shields({ key = "shieldsTimeFont", code = "ZV", type = "media", mediaKind = "font", emptyText = "FONT_OF_FRAME",
    default = "" })
shields({ key = "shieldsTimeSize", code = "ZZ", type = "int", min = 0, lowest = 6, max = 48, default = 0,
    zeroText = "AUTO" })
shields({ key = "shieldsTimeOutline", code = "KA", type = "enum", values = SHIELD_OUTLINES, default = "FRAME" })
shields({ key = "shieldsTimeColor", code = "KB", type = "color", default = { 1, 1, 1, 1 } })

-- Combat and PvP icons on the other frames (Elements/UnitIcons.lua), off
-- by default. The combat icon sits left of the frame, the crest on its top
-- left corner.
local COMBAT_ICON = { target = true, targettarget = true, focus = true, party = true }
-- How the combat icons move (Elements/CombatAnimation.lua), the player's
-- included: our clashing swords (the default), a burst as they appear, a
-- steady pulse, or Blizzard's still icon.
Settings.Define({ key = "combatAnimation", code = "EA", scope = "inherit", type = "enum",
    only = { player = true, target = true, targettarget = true, focus = true, party = true },
    values = { "OFF", "BURST", "PULSE", "DUEL" }, default = "DUEL" })
local PVP_ICON = { player = true, target = true, targettarget = true, focus = true, party = true }
for _, icon in ipairs({
    { key = "combatIcon", letter = "E", only = COMBAT_ICON, size = 18, framePoint = "LEFT", point = "RIGHT", x = -2, y = 0 },
    { key = "pvpIcon", letter = "H", only = PVP_ICON, size = 24, framePoint = "TOPLEFT", point = "CENTER", x = 0, y = 0 },
}) do
    local only, l = icon.only, icon.letter
    Settings.Define({ key = icon.key, code = l .. "E", scope = "frame", only = only, type = "bool", default = false })
    Settings.Define({ key = icon.key .. "Size", code = l .. "S", scope = "frame", only = only, type = "int",
        min = 8, max = 48, default = icon.size })
    Settings.Define({ key = icon.key .. "FramePoint", code = l .. "F", scope = "frame", only = only, type = "enum",
        values = Settings.POINTS, default = icon.framePoint })
    Settings.Define({ key = icon.key .. "Point", code = l .. "O", scope = "frame", only = only, type = "enum",
        values = Settings.POINTS, default = icon.point })
    Settings.Define({ key = icon.key .. "X", code = l .. "X", scope = "frame", only = only, type = "int",
        min = -200, max = 200, default = icon.x })
    Settings.Define({ key = icon.key .. "Y", code = l .. "Y", scope = "frame", only = only, type = "int",
        min = -200, max = 200, default = icon.y })
end

-- The hunter pet's happiness (pet only, Elements/PetHappiness.lua), on by
-- default as on Blizzard's pet frame: right of the frame.
local PET_HAPPINESS = { pet = true }
Settings.Define({ key = "petHappiness", code = "GE", scope = "frame", only = PET_HAPPINESS, type = "bool",
    default = true })
-- Only while the pet is not happy: the icon then asks for food.
Settings.Define({ key = "petHappinessHideHappy", code = "GN", scope = "frame", only = PET_HAPPINESS, type = "bool",
    default = false })
Settings.Define({ key = "petHappinessSize", code = "GZ", scope = "frame", only = PET_HAPPINESS, type = "int",
    min = 8, max = 48, default = 20 })
Settings.Define({ key = "petHappinessFramePoint", code = "GF", scope = "frame", only = PET_HAPPINESS, type = "enum",
    values = Settings.POINTS, default = "RIGHT" })
Settings.Define({ key = "petHappinessPoint", code = "GO", scope = "frame", only = PET_HAPPINESS, type = "enum",
    values = Settings.POINTS, default = "LEFT" })
Settings.Define({ key = "petHappinessX", code = "GX", scope = "frame", only = PET_HAPPINESS, type = "int",
    min = -200, max = 200, default = 2 })
Settings.Define({ key = "petHappinessY", code = "GY", scope = "frame", only = PET_HAPPINESS, type = "int",
    min = -200, max = 200, default = 0 })

-- The PvP crest on flagged NPCs too (city guards, faction NPCs): attacking
-- one flags you. On by default; flagged elite guards then show the crest
-- in the elite marker's corner as well (move one of them if they clash).
Settings.Define({ key = "pvpIconNPC", code = "HN", scope = "frame",
    only = { target = true, targettarget = true, focus = true }, type = "bool", default = true })

-- Status icons (player only, Elements/StatusIcons.lua): Blizzard's combat
-- and resting icons in a row on the player's health bar, centred on it by
-- default (above the bar's texts).
local STATUS = { player = true }
Settings.Define({ key = "statusCombat", code = "ZC", scope = "frame", only = STATUS, type = "bool", default = true })
Settings.Define({ key = "statusResting", code = "ZR", scope = "frame", only = STATUS, type = "bool", default = true })
Settings.Define({ key = "statusSize", code = "ZS", scope = "frame", only = STATUS, type = "int", min = 10, max = 48,
    default = 22 })
Settings.Define({ key = "statusFramePoint", code = "ZF", scope = "frame", only = STATUS, type = "enum",
    values = Settings.POINTS, default = "CENTER" })
Settings.Define({ key = "statusPoint", code = "ZO", scope = "frame", only = STATUS, type = "enum",
    values = Settings.POINTS, default = "CENTER" })
Settings.Define({ key = "statusX", code = "ZX", scope = "frame", only = STATUS, type = "int", min = -400, max = 400,
    default = 0 })
Settings.Define({ key = "statusY", code = "ZY", scope = "frame", only = STATUS, type = "int", min = -400, max = 400,
    default = 0 })

-- Raid target markers (Elements/RaidMarker.lua): on every frame, centred
-- on the frame's top edge by default, clear of the class badge on the top
-- right corner.
Settings.Define({ key = "raidMarker", code = "RE", scope = "frame", type = "bool", default = true })
Settings.Define({ key = "raidMarkerSize", code = "RS", scope = "frame", type = "int", min = 8, max = 64,
    default = { targettarget = 16, pet = 16, _ = 20 } })
Settings.Define({ key = "raidMarkerFramePoint", code = "RF", scope = "frame", type = "enum",
    values = Settings.POINTS, default = "TOP" })
Settings.Define({ key = "raidMarkerPoint", code = "RO", scope = "frame", type = "enum",
    values = Settings.POINTS, default = "CENTER" })
Settings.Define({ key = "raidMarkerX", code = "RX", scope = "frame", type = "int", min = -200, max = 200,
    default = 0 })
Settings.Define({ key = "raidMarkerY", code = "RY", scope = "frame", type = "int", min = -200, max = 200,
    default = 0 })

-- Group icons (player and party, Elements/GroupIcons.lua): leader or
-- assistant, ready check and incoming resurrection, each group on its own
-- switch, in one row at the frame's top left corner by default.
local GROUP = { player = true, party = true }
Settings.Define({ key = "groupLeader", code = "LL", scope = "frame", only = GROUP, type = "bool", default = true })
Settings.Define({ key = "groupReadyCheck", code = "LR", scope = "frame", only = GROUP, type = "bool", default = true })
Settings.Define({ key = "groupResurrect", code = "LZ", scope = "frame", only = GROUP, type = "bool", default = true })
-- The assigned role (tank, healer, damage) as a fourth icon in the row, in
-- the raid cells' art; off by default.
Settings.Define({ key = "groupRole", code = "LG", scope = "frame", only = GROUP, type = "bool", default = false })
Settings.Define({ key = "groupIconSize", code = "LS", scope = "frame", only = GROUP, type = "int", min = 8, max = 48,
    default = 16 })
Settings.Define({ key = "groupIconFramePoint", code = "LF", scope = "frame", only = GROUP, type = "enum",
    values = Settings.POINTS, default = "TOPLEFT" })
Settings.Define({ key = "groupIconPoint", code = "LO", scope = "frame", only = GROUP, type = "enum",
    values = Settings.POINTS, default = "LEFT" })
Settings.Define({ key = "groupIconX", code = "LX", scope = "frame", only = GROUP, type = "int", min = -200, max = 200,
    default = 2 })
Settings.Define({ key = "groupIconY", code = "LY", scope = "frame", only = GROUP, type = "int", min = -200, max = 200,
    default = 0 })

-- Range fading (Elements/Range.lua): party members and their pets, the
-- target, its target, the focus and the pet at a lower opacity while out
-- of range.
local RANGE = { party = true, target = true, focus = true, pet = true, targettarget = true }
-- On everywhere: every class measures enemies, by a spell or in yards.
Settings.Define({ key = "rangeFade", code = "VE", scope = "frame", only = RANGE, type = "bool", default = true })
-- The opacity: once in General for every frame, overridable per frame.
Settings.Define({ key = "rangeAlpha", code = "VA", scope = "inherit", only = RANGE, type = "int", min = 0, max = 100,
    default = 50 })
-- How range is measured, for friends and for enemies (General only):
-- AUTO is the spell, or yards when there is none; SPELL the spell only;
-- YARDS the distance in yards; OFF: units of that reaction never fade.
-- Stored by index: append only.
-- The spell fields take a name or a spell ID; empty is the class's own
-- (Range.CLASS_SPELLS).
local RANGE_MODES = { "AUTO", "SPELL", "YARDS", "OFF" }
Settings.Define({ key = "rangeFriendlyMode", code = "VG", scope = "general", type = "enum", values = RANGE_MODES,
    default = "AUTO" })
Settings.Define({ key = "rangeFriendlySpell", code = "VF", scope = "general", type = "text", default = "" })
Settings.Define({ key = "rangeFriendlyYards", code = "VY", scope = "general", type = "int", min = 5, max = 40,
    default = 40 })
Settings.Define({ key = "rangeHostileMode", code = "VK", scope = "general", type = "enum", values = RANGE_MODES,
    default = "AUTO" })
Settings.Define({ key = "rangeHostileSpell", code = "VH", scope = "general", type = "text", default = "" })
Settings.Define({ key = "rangeHostileYards", code = "VZ", scope = "general", type = "int", min = 5, max = 40,
    default = 30 })

-- Threat glow (Elements/Threat.lua): the unit's own threat on the player,
-- party and pet frames, your threat on it on the others.
Settings.Define({ key = "threatGlow", code = "TH", scope = "frame", type = "bool",
    default = { player = true, party = true, _ = false } })
-- Weapon enchants (poisons, sharpening stones, Rockbiter Weapon ...) with
-- the player's buffs: not auras, the aura container shows them as item
-- enchantments before the buffs (Elements/AuraContainers.lua).
Settings.Define({ key = "weaponEnchants", code = "WE", scope = "frame", only = { player = true }, type = "bool",
    default = true })
-- Threat bar (Elements/ThreatBar.lua): your threat on your target, as a
-- row below the player frame (and its docked castbar). Warn: the share at
-- which it turns yellow. Solo: shown without a group too.
local PLAYER = { player = true }
Settings.Define({ key = "threatBar", code = "TB", scope = "frame", only = PLAYER, type = "bool", default = false })
Settings.Define({ key = "threatBarHeight", code = "TZ", scope = "frame", only = PLAYER, type = "int", min = 6, max = 30,
    default = 12 })
Settings.Define({ key = "threatBarWarn", code = "TW", scope = "frame", only = PLAYER, type = "int", min = 50, max = 99,
    default = 80 })
Settings.Define({ key = "threatBarSolo", code = "TS", scope = "frame", only = PLAYER, type = "bool", default = false })
Settings.Define({ key = "threatBarRole", code = "TO", scope = "frame", only = PLAYER, type = "enum",
    values = { "AUTO", "TANK", "DPS" }, default = "AUTO" })
-- Target highlight (Elements/TargetHighlight.lua): the party member you
-- have targeted gets a bright band; its pets follow the party setting.
Settings.Define({ key = "targetHighlight", code = "TG", scope = "frame", only = { party = true }, type = "bool",
    default = true })
Settings.Define({ key = "targetHighlightColor", code = "TK", scope = "inherit", only = { party = true }, type = "color",
    default = { 1, 1, 1, 0.9 } })
-- The band's thickness in pixels.
Settings.Define({ key = "targetHighlightSize", code = "TJ", scope = "frame", only = { party = true }, type = "int",
    min = 1, max = 12, default = 3 })
-- Player frame out of combat (Elements/CombatFade.lua): faded to this
-- opacity while idle.
Settings.Define({ key = "playerFadeOOC", code = "WF", scope = "frame", only = { player = true }, type = "bool",
    default = false })
Settings.Define({ key = "playerFadeAlpha", code = "WA", scope = "frame", only = { player = true }, type = "int",
    min = 0, max = 100, default = 25 })
-- A druid's mana while shapeshifted: a strip along the bottom of the power
-- bar (Elements/DruidMana.lua).
Settings.Define({ key = "druidMana", code = "MD", scope = "frame", only = { player = true }, type = "bool",
    default = true })
Settings.Define({ key = "druidManaHeight", code = "MH", scope = "frame", only = { player = true }, type = "int",
    min = 2, max = 20, default = 4 })
-- The five-second rule on the player's mana bar (Elements/FiveSecondRule.lua):
-- after a spell that costs mana, a spark runs across the power bar in 5 s;
-- optional a countdown text and a dimmed fill. On with the spark by default
-- (it shows only while the rule runs).
local FSR = { player = true }
Settings.Define({ key = "fsrEnabled", code = "FE", scope = "frame", only = FSR, type = "bool", default = true })
Settings.Define({ key = "fsrSpark", code = "FK", scope = "frame", only = FSR, type = "bool", default = true })
Settings.Define({ key = "fsrSparkDirection", code = "FD", scope = "frame", only = FSR, type = "enum",
    values = { "LEFT_TO_RIGHT", "RIGHT_TO_LEFT" }, default = "LEFT_TO_RIGHT" })
Settings.Define({ key = "fsrSparkWidth", code = "FW", scope = "frame", only = FSR, type = "int", min = 2, max = 16,
    default = 3 })
-- The spark's colour (a warm glow by default).
Settings.Define({ key = "fsrSparkColor", code = "FC", scope = "frame", only = FSR, type = "color",
    default = { 1, 0.9, 0.5, 1 } })
Settings.Define({ key = "fsrText", code = "FT", scope = "frame", only = FSR, type = "bool", default = false })
Settings.Define({ key = "fsrTextPoint", code = "FP", scope = "frame", only = FSR, type = "enum",
    values = { "LEFT", "CENTER", "RIGHT" }, default = "CENTER" })
-- The last second in tenths (0.9 ... 0.1).
Settings.Define({ key = "fsrTextTenths", code = "FN", scope = "frame", only = FSR, type = "bool", default = true })
Settings.Define({ key = "fsrDim", code = "FM", scope = "frame", only = FSR, type = "bool", default = false })
-- The fill's opacity during the rule (%).
Settings.Define({ key = "fsrDimAlpha", code = "FA", scope = "frame", only = FSR, type = "int", min = 0, max = 100,
    default = 70 })
-- Back in full while you have a target: see your resources before a pull.
Settings.Define({ key = "playerFadeTarget", code = "WT", scope = "frame", only = { player = true }, type = "bool",
    default = true })
-- Never faded in a party or raid: a healer healing by mouse-over without a
-- target still sees the frame. Off by default.
Settings.Define({ key = "playerFadeGroup", code = "WG", scope = "frame", only = { player = true }, type = "bool",
    default = false })
-- The pet frame fades with it (the same opacity); off by default.
Settings.Define({ key = "playerFadePet", code = "WP", scope = "frame", only = { player = true }, type = "bool",
    default = false })

-- Dispel highlight (Elements/Dispel.lua): the border of the player and
-- party frames tints while the unit has a debuff you can dispel.
Settings.Define({ key = "dispelHighlight", code = "HD", scope = "frame", only = { player = true, party = true },
    type = "bool", default = true })

-- Minimap button (Options/MinimapButton.lua): General only. The angle
-- around the minimap in degrees, counter-clockwise from the right (225:
-- bottom left, LibDBIcon's default); set by dragging the button.
Settings.Define({ key = "minimapShow", code = "MS", scope = "general", type = "bool", default = true })
Settings.Define({ key = "minimapAngle", code = "MA", scope = "general", type = "int", min = 0, max = 359,
    default = 225 })

-- Language of every text (Core/Locale.lua): AUTO follows the game. Stored
-- by index: append only. Personal: an imported profile keeps the reader's
-- own language (Config.Import). inNav: its control sits at the bottom of
-- the options window's navigation, on no page.
Settings.Define({ key = "language", code = "LN", scope = "general", type = "enum", personal = true, inNav = true,
    values = { "AUTO", "enUS", "deDE", "esES", "frFR" }, default = "AUTO" })
