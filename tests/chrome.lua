-- A record of the four windows' chrome: the title bar, the close cross and
-- the footer of the unit frames' window, the raid window, the What's New
-- window and the raid setup wizard, every region under them with its
-- points, size, layer, colour, font, text, mouse, drag and scripts; and the
-- points of the window's other parts anchored to them. test_window_chrome.lua
-- compares it with window_chrome.lua, written before the windows shared
-- Options/Chrome.lua: the shared parts must not change any of it.
local M = H.M
local Chrome = {}

local function num(v) return ("%.3f"):format(v) end

local function value(v, paths)
    local kind = type(v)
    if kind == "number" then return num(v) end
    if kind == "table" then
        if v.GetObjectType then return paths[v] or ("?" .. tostring(rawget(v, "_kind"))) end
        local out = {}
        for i = 1, #v do out[i] = value(v[i], paths) end
        return "{" .. table.concat(out, ",") .. "}"
    end
    return tostring(v)
end

-- The mock's own bookkeeping, and what changes with use rather than build.
local SKIP = { _parent = true, _children = true, _scripts = true, _events = true, _points = true, _kind = true,
    _name = true }

local function sortedKeys(t, filter)
    local keys = {}
    for k, v in pairs(t) do
        if type(k) == "string" and filter(k, v) then keys[#keys + 1] = k end
    end
    table.sort(keys)
    return keys
end

local function describe(w, path, paths)
    local parts = { path, rawget(w, "_kind") }
    local pts = {}
    for i, p in ipairs(rawget(w, "_points")) do
        local args = {}
        for j = 1, table.maxn(p) do args[j] = value(p[j], paths) end
        pts[i] = table.concat(args, ":")
    end
    parts[#parts + 1] = "pts=" .. table.concat(pts, " ")
    for _, k in ipairs(sortedKeys(w, function(key, v) return key:sub(1, 1) == "_" and not SKIP[key]
        and type(v) ~= "function" end)) do
        parts[#parts + 1] = k .. "=" .. value(rawget(w, k), paths)
    end
    -- Fields the addon keeps on it that are regions (bar.title, b.lines…).
    for _, k in ipairs(sortedKeys(w, function(key, v) return key:sub(1, 1) ~= "_" and type(v) == "table" end)) do
        parts[#parts + 1] = k .. "=" .. value(rawget(w, k), paths)
    end
    parts[#parts + 1] = "scripts=" .. table.concat(sortedKeys(rawget(w, "_scripts"), function() return true end), ",")
    return table.concat(parts, " ")
end

-- parts: { { name, region }, … } under window. Lines in creation order.
function Chrome.Record(window, parts)
    local paths = { [window] = "window", [UIParent] = "UIParent" }
    local order = {}
    local function walk(w, path)
        paths[w] = path
        order[#order + 1] = { w, path }
        for i, child in ipairs(rawget(w, "_children") or {}) do walk(child, path .. "." .. i) end
    end
    for _, part in ipairs(parts) do walk(part[2], part[1]) end
    -- The window's other children: named by their place, points only.
    local others = {}
    for i, child in ipairs(rawget(window, "_children")) do
        if not paths[child] then
            paths[child] = "window." .. i
            others[#others + 1] = child
        end
    end
    local lines = {}
    for _, entry in ipairs(order) do lines[#lines + 1] = describe(entry[1], entry[2], paths) end
    for _, child in ipairs(others) do
        local pts = {}
        for i, p in ipairs(rawget(child, "_points")) do
            local args = {}
            for j = 1, table.maxn(p) do args[j] = value(p[j], paths) end
            pts[i] = table.concat(args, ":")
        end
        if #pts > 0 then lines[#lines + 1] = paths[child] .. " pts=" .. table.concat(pts, " ") end
    end
    return lines
end

-- The four windows, opened after a default boot.
function Chrome.Windows()
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    M.addonVersion = "0.22.0"
    ns.Options.Open("player")
    ns.RaidOptions.Open()
    ns.NewsWindow.Open("0.22.0")
    ns.RaidWizard.Open()
    local O, RO, NW, W = ns.Options, ns.RaidOptions, ns.NewsWindow, ns.RaidWizard
    return ns, {
        unit = { O.frame, { { "titleBar", O.frame.titleBar }, { "footer", O.unlockButton:GetParent() } } },
        raid = { RO.frame, { { "titleBar", RO.frame.titleBar }, { "footer", RO.frame.footer } } },
        news = { NW.frame, { { "titleBar", NW.frame.titleBar }, { "footer", NW.frame.footer } } },
        -- The wizard's title bar: what its heading hangs from.
        wizard = { W.frame, { { "titleBar", select(2, W.frame.heading:GetPoint(1)) },
            { "footer", W.cancelButton:GetParent() } } },
    }
end

Chrome.NAMES = { "unit", "raid", "news", "wizard" }

return Chrome
