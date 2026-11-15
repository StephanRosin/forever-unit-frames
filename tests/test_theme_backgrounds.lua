-- One background per theme in every Forever addon, as the rings: the
-- backdrop (file, tint, alpha) and the colour laid over it behind the
-- content (unit frames: the bars' background; Quest Log and InfoPanel:
-- the shade) are the family's, and the theme colours shared. The
-- colours' grey textures take the tint's alpha, so equal here means equal
-- in every colour. Sibling addons next to this one are checked too;
-- missing ones are skipped (CI has only this repository).
-- The family's backdrop tint and alpha (Quest Log's darkening), and the
-- body colour (nil: the backdrop alone; Glass: the unit frames').
local CANON = {
    WOOD = { tint = "0.5,0.5,0.5,1" }, TECH = { tint = "1,1,1,1" }, PARCHMENT = { tint = "0.45,0.45,0.45,1" },
    RUNESTONE = { tint = "0.55,0.55,0.55,1" }, GLASS = { tint = "1,1,1,1", body = "0.05,0.04,0.06,0.9" },
    COMIC = { tint = "0.7,0.7,0.7,1" }, FROST = { tint = "0.55,0.55,0.55,0.85", body = "0.02,0.07,0.15,0.45" },
    PIXEL = { tint = "1,1,1,1" }, SWISS = { tint = "1,1,1,1" }, CONSOLE = { tint = "1,1,1,1" },
    PITWALL = { tint = "1,1,1,1" },
}
-- Swiss and Pitwall: an opaque #0a0a0a over SwissBack is that backdrop's own black.
local SWISS_BLACK = "0.039,0.039,0.039,1"
-- Exceptions, each for a reason: the minimap has no body (the map); the
-- Group Finder's comic list keeps its dark body (unoutlined text on paper);
-- the InfoPanel's Pitwall shade is its cards.
local NO_BODY = { FSM = true, FGF = { COMIC = true }, FIP = { PITWALL = true } }

local function stub()
    return setmetatable({}, { __index = function(t, k) local s = stub(); rawset(t, k, s); return s end,
        __call = function() return stub() end })
end
local function load(path, ns)
    local chunk = loadfile(path)
    if not chunk then return nil end
    setfenv(chunk, setmetatable({ GetLocale = function() return "enUS" end }, { __index = function(_, k)
        local g = _G[k]; if g ~= nil then return g end; return stub() end }))
    chunk("X", ns)
    return ns
end
-- An addon on the embedded LibForeverThemes loads its copy first (next to
-- Themes.lua or one folder up).
local LIB = "/Libs/LibForeverThemes/LibForeverThemes.lua"
local function addon(themes, media)
    local ns = stub()
    ns.Settings.THEMES, ns.Settings.DEFAULTS = {}, {}
    local dir = themes:match("^(.*)/[^/]+$")
    for _, lib in ipairs({ dir .. LIB, dir .. "/.." .. LIB }) do
        if io.open(lib) then load(lib, ns) break end
    end
    if media and not load(media, ns) then return nil end
    return load(themes, ns)
end
local function str(c, a)
    local t = {}
    for i = 1, 3 do t[i] = tostring(c[i]) end
    t[4] = tostring(a or c[4] or 1)
    return table.concat(t, ",")
end

local ROOT = ADDONDIR .. "/../"
-- name, Themes.lua, Media.lua (when the tint lives there), the layers it draws: tint and body.
local ADDONS = {
    { "FUF", ADDONDIR .. "/Core/Themes.lua", nil, function(s)
        return s.art.tint, s.look.backgroundColor end },
    { "FQL", ROOT .. "ForeverQuestLog/Themes.lua", ROOT .. "ForeverQuestLog/Media.lua", nil, "shade" },
    { "FCM", ROOT .. "ForeverCombatMeter/Themes.lua", nil, function(s)
        return s.art.tint, s.look.bgColor and { s.look.bgColor[1], s.look.bgColor[2], s.look.bgColor[3], s.look.bgAlpha / 100 } end },
    { "FDB", ROOT .. "ForeverDataBar/Themes.lua", nil, function(s)
        local c = s.look.dataBarBgColor
        return s.art.tint, { c[1], c[2], c[3], s.look.dataBarAlpha / 100 } end },
    { "FGF", ROOT .. "ForeverGroupFinder/Themes.lua", nil, function(s)
        return s.art.tint, { s.look.bgColor[1], s.look.bgColor[2], s.look.bgColor[3], s.look.bgAlpha / 100 } end },
    { "FSM", ROOT .. "ForeverSquareMinimap/Themes.lua", nil, function(s) return s.art.tint end },
    { "FIP", ROOT .. "ForeverInfoPanel/InfoPanel/Themes.lua", ROOT .. "ForeverInfoPanel/InfoPanel/Media.lua", nil,
        "contentShade" },
}

for _, a in ipairs(ADDONS) do
    local name, layers = a[1], a[4]
    local ns = addon(a[2], a[3])
    if not ns then
        print("  (skipped " .. name .. ": not next to this addon)")
    else
        local Themes = ns.Themes
        for id, want in pairs(CANON) do
            local s = Themes.SPECS[id]
            local tint, body
            if layers then
                tint, body = layers(s)
                tint = str(tint or { 1, 1, 1, 1 })
            else -- Quest Log and InfoPanel: a texture setting, darkened in Media.lua, at bgAlpha.
                local d = ns.Media.Tint(s.look.bgTexture)
                tint, body = str({ d, d, d }, s.look.bgAlpha / 100), (s.art or {})[a[5]]
            end
            body = body and body[4] > 0 and str(body) or nil
            if id == "SWISS" or id == "PITWALL" then body = body ~= SWISS_BLACK and body or nil end
            H.check(name .. " " .. id .. ": backdrop tint", tint, want.tint)
            local skip = NO_BODY[name] == true or (NO_BODY[name] and NO_BODY[name][id])
            if not skip then H.check(name .. " " .. id .. ": body over it", body, want.body) end
            for _, c in ipairs(LibForeverThemes.COLORS[id]) do
                local own
                for _, o in ipairs((Themes.COLORS or LibForeverThemes.COLORS)[id] or {}) do if o.id == c.id then own = o end end
                H.check(name .. " " .. id .. " " .. c.id .. ": its backdrop colour",
                    own and own.back and str(own.back) or (own and "none"), c.back and str(c.back) or "none")
            end
        end
    end
end
