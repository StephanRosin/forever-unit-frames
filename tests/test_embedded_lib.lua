-- Embedded LibForeverThemes: the copy in Libs/ is the library's own
-- (ForeverThemes, tools/sync there), checked when that repository sits
-- next to this one (not in CI); it is the copy that loaded; the theme
-- setting's list is the library's; older font names still resolve.
local ns = H.LoadAddon()
local Lib = LibForeverThemes

local LIBREPO = ADDONDIR .. "/../ForeverThemes"
if io.open(LIBREPO .. "/LibForeverThemes.lua") then
    local diff = io.popen("diff -rq '" .. LIBREPO .. "/LibForeverThemes.lua' '" .. ADDONDIR
        .. "/Libs/LibForeverThemes/LibForeverThemes.lua' && diff -rq '" .. LIBREPO .. "/Media' '" .. ADDONDIR
        .. "/Libs/LibForeverThemes/Media' 2>&1"):read("*a")
    H.check("copy equals ForeverThemes (run its tools/sync)", diff, "")
else
    print("  (skipped: ForeverThemes not next to this addon)")
end
H.check("library loaded from our copy", Lib.FOLDER, "ForeverUnitFrames")
H.check("first file in the TOC", H.TocFiles()[1], "Libs/LibForeverThemes/LibForeverThemes.lua")
-- The setting stores the theme by index: its list must stay the library's.
H.check("theme ids as the library's", table.concat(ns.Settings.THEMES, ","), table.concat(Lib.IDS, ","))
H.check("theme ids as the specs'", table.concat(ns.Settings.THEMES, ","), table.concat(Lib.SpecIds(ns.Themes.SPECS), ","))
H.check("switch: a library theme without a spec refused", select(2, ns.Themes.Switch("NOT_OURS")), "UNKNOWN")

-- Fonts and bars from the library's media; Pitwall's older font name finds
-- the same file and is no longer listed under it.
H.check("pitwall's font by its older name", ns.Media.Font("Titillium Web"), Lib.FontPath("Titillium Web SemiBold"))
H.check("a theme bar", ns.Media.StatusBar("FUF Wood"), Lib.Texture("WoodBar"))
local listed = {}
for _, name in ipairs(ns.Media.List("font")) do listed[name] = true end
H.check("every library font listed", (function()
    for _, f in ipairs(Lib.FONTS) do if not listed[f.name] then return f.name end end
    return "all"
end)(), "all")
H.check("the older name not listed", listed["Titillium Web"], nil)
