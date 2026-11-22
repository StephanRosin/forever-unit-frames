local _, ns = ...

-- Fonts and bar textures. Settings store the *name*, never the path, so a
-- profile survives when files move. LibSharedMedia is used if another addon
-- loaded it; we do not ship it.
local Media = {}
ns.Media = Media

local ADDON = "Interface\\AddOns\\ForeverUnitFrames\\Media\\"
local builtin = {
    font = {
        -- The client's own standard font: FRIZQT__ on western clients, a font
        -- with Hangul/Hanzi/Cyrillic elsewhere (Blizzard_Fonts_Shared GameFonts.xml).
        ["Friz Quadrata"] = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
        ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
        ["Skurri"] = "Fonts\\skurri.ttf",
        ["Morpheus"] = "Fonts\\MORPHEUS.ttf",
    },
    statusbar = {
        ["Flat"] = "Interface\\Buttons\\WHITE8X8",
        ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
        ["Raid"] = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    },
}
-- The themes' fonts (Latin letters only) and bar textures come with the
-- embedded LibForeverThemes, which also loads its fonts early. Paths are
-- asked at use: a newer copy of the library loading after us has its own.
local Lib = LibForeverThemes
-- Console and Pitwall use Swiss's bar: their dashed and LED bars looked broken here.
local THEME_BARS = {}
for _, name in ipairs({ "Wood", "Tech", "Parchment", "Stone", "Glass", "Comic", "Frost", "Pixel", "Swiss" }) do
    THEME_BARS["FUF " .. name] = name .. "Bar"
end
local function themed(kind, name)
    if kind == "font" then return Lib.FontPath(name) end
    return THEME_BARS[name] and Lib.Texture(THEME_BARS[name])
end
local function themedNames(kind)
    local names = {}
    if kind == "font" then
        for _, f in ipairs(Lib.FONTS) do names[#names + 1] = f.name end
    elseif kind == "statusbar" then
        for name in pairs(THEME_BARS) do names[#names + 1] = name end
    end
    return names
end
local fallback = { font = "Friz Quadrata", statusbar = "Flat" }

local function lsm()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

local function fetch(kind, name)
    local path = builtin[kind][name] or themed(kind, name)
    if path then return path end
    local lib = lsm()
    if lib and name and lib:IsValid(kind, name) then return lib:Fetch(kind, name) end
    return builtin[kind][fallback[kind]]
end

function Media.Font(name) return fetch("font", name) end

-- A font file draws only its own letters: Friz Quadrata and most others
-- have no Cyrillic, Hangul or Hanzi, so such names became squares
-- (CurseForge). Blizzard's own fonts are families: one file per alphabet
-- (Blizzard_Fonts_Shared Fonts.xml). Media.Family makes one around the
-- chosen file, which keeps the Latin letters; the rest come from the
-- client's files for those alphabets. The _CYR files draw Latin letters
-- a little differently, so they are not used for Latin. nil where the
-- client cannot make families.
local CYRILLIC = {
    ["fonts\\frizqt__.ttf"] = "Fonts\\FRIZQT___CYR.TTF",
    ["fonts\\morpheus.ttf"] = "Fonts\\MORPHEUS_CYR.TTF",
    ["fonts\\skurri.ttf"] = "Fonts\\SKURRI_CYR.TTF",
}
-- Files that have Cyrillic themselves.
local HAS_CYRILLIC = { ["fonts\\arialn.ttf"] = true, ["fonts\\frizqt___cyr.ttf"] = true,
    ["fonts\\morpheus_cyr.ttf"] = true, ["fonts\\skurri_cyr.ttf"] = true }
local OTHER_ALPHABETS = {
    { alphabet = "korean", file = "Fonts\\2002.TTF" },
    { alphabet = "simplifiedchinese", file = "Fonts\\ARKai_T.ttf" },
    { alphabet = "traditionalchinese", file = "Fonts\\blei00d.TTF" },
}
local families, familyCount = {}, 0

function Media.CyrillicFor(file)
    local plain = file:lower():gsub("/", "\\")
    if HAS_CYRILLIC[plain] then return file end
    return CYRILLIC[plain] or "Fonts\\FRIZQT___CYR.TTF"
end

-- Whether path is one of the files a family around file draws with
-- (GetFont names the one for the text's alphabet).
function Media.InFamily(file, path)
    if not next(families) then return false end
    local function plain(p) return (p:lower():gsub("/", "\\")) end
    path = plain(path)
    if path == plain(Media.CyrillicFor(file)) then return true end
    for _, other in ipairs(OTHER_ALPHABETS) do
        if path == plain(other.file) then return true end
    end
    return false
end

function Media.ForgetFamily(file, size, flags)
    local key = file .. "|" .. size .. "|" .. flags
    families[key .. "|"], families[key .. "|shadow"] = nil, nil
end

-- The shadow a family hands its texts: Blizzard's families carry it on
-- every member (Fonts.xml), CreateFontFamily takes none, and the client
-- can hand a family's own (none) to its texts again later (CurseForge
-- 23.11.2026: shadow gone after a relog although ticked).
local function shade(font, shadow)
    pcall(font.SetShadowOffset, font, shadow and 1 or 0, shadow and -1 or 0)
    pcall(font.SetShadowColor, font, 0, 0, 0, 1)
end

function Media.Family(file, size, flags, shadow)
    if type(CreateFontFamily) ~= "function" or type(file) ~= "string" then return nil end
    local key = file .. "|" .. size .. "|" .. flags .. "|" .. (shadow and "shadow" or "")
    local family = families[key]
    if family == nil then
        local members = {
            { alphabet = "roman", file = file, height = size, flags = flags },
            { alphabet = "russian", file = Media.CyrillicFor(file), height = size, flags = flags },
        }
        for _, other in ipairs(OTHER_ALPHABETS) do
            members[#members + 1] = { alphabet = other.alphabet, file = other.file, height = size, flags = flags }
        end
        familyCount = familyCount + 1
        local ok, made = pcall(CreateFontFamily, "ForeverUnitFramesFont" .. familyCount, members)
        family = ok and made or false
        if family then
            shade(family, shadow)
            for _, member in ipairs(members) do
                local ok2, font = pcall(family.GetFontObjectForAlphabet, family, member.alphabet)
                if ok2 and font then shade(font, shadow) end
            end
        end
        families[key] = family
    end
    return family or nil
end
function Media.StatusBar(name) return fetch("statusbar", name) end
-- Our own 64 px icons (tools/art/icons): Blizzard's atlases for these are
-- 11-21 px and blur when scaled; their -2x versions are not in the client.
function Media.Icon(name) return ADDON .. "Icon" .. name .. ".tga" end

function Media.List(kind)
    local names, seen = {}, {}
    for name in pairs(builtin[kind]) do names[#names + 1] = name; seen[name] = true end
    for _, name in ipairs(themedNames(kind)) do names[#names + 1] = name; seen[name] = true end
    local lib = lsm()
    if lib then
        for _, name in ipairs(lib:List(kind)) do
            if not seen[name] then names[#names + 1] = name end
        end
    end
    table.sort(names)
    return names
end
