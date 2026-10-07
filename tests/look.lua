-- A record of how the unit frames look after a default boot: where their
-- texts, group icons, elite marker and totems sit, what they show, and
-- the frames' opacity. test_default_look.lua compares it with
-- default_look.lua, written from the frames before new options were
-- added: an option that is off by default must not change any of it.
local M = H.M
local Look = {}

local function num(v)
    if type(v) ~= "number" then return tostring(v) end
    return ("%.3f"):format(v)
end

-- Every region a frame keeps in a field, by the field's name.
local function names(frame)
    local map = { [UIParent] = "UIParent", [frame] = "frame" }
    local function add(t, prefix)
        for k, v in pairs(t) do
            if type(v) == "table" and type(k) == "string" and v.GetObjectType and not map[v] then
                map[v] = prefix .. k
            end
        end
    end
    add(frame, "")
    if frame.texts then add(frame.texts, "texts.") end
    if frame.groupIcons then add(frame.groupIcons, "groupIcons.") end
    if frame.totems then add(frame.totems, "totems.") end
    return map
end

local function points(region, map)
    local out = {}
    for i = 1, #(region._points or {}) do
        local p = { region:GetPoint(i) }
        local rel = p[2]
        local relName = type(rel) == "table" and (map[rel] or "?") or tostring(rel)
        out[#out + 1] = ("%s>%s.%s(%s,%s)"):format(tostring(p[1]), relName, tostring(p[3]), num(p[4]), num(p[5]))
    end
    return table.concat(out, " ")
end

local function text(fs)
    if fs._fmt then
        local args = {}
        for i, a in ipairs(fs._args or {}) do args[i] = M.IsSecret(a) and "<secret>" or tostring(a) end
        return fs._fmt .. "|" .. table.concat(args, ",")
    end
    return tostring(fs._text)
end

local function region(lines, label, r, map)
    if not r then return end
    lines[#lines + 1] = ("%s shown=%s size=%s,%s pts=%s"):format(label, tostring(r:IsShown()), num(r._w),
        num(r._h), points(r, map))
end

-- The lines of one frame.
function Look.Frame(lines, label, frame)
    local map = names(frame)
    lines[#lines + 1] = ("%s alpha=%s"):format(label, num(frame:GetAlpha()))
    -- The texts the frames had before (new ones are checked on their own).
    for _, field in ipairs({ "title", "titleRight", "healthLeft", "healthRight", "powerLeft", "powerRight" }) do
        local fs = frame.texts and frame.texts[field]
        if fs then
            region(lines, label .. ".texts." .. field, fs, map)
            lines[#lines + 1] = ("%s.texts.%s text=%s justify=%s width=%s"):format(label, field, text(fs),
                tostring(fs._justifyH), num(fs._w))
        end
    end
    local g = frame.groupIcons
    if g then
        region(lines, label .. ".groupIcons.holder", g.holder, map)
        for _, name in ipairs({ "leader", "ready", "rez" }) do region(lines, label .. ".groupIcons." .. name, g[name], map) end
    end
    region(lines, label .. ".eliteIcon", frame.eliteIcon, map)
    region(lines, label .. ".eliteText", frame.eliteText, map)
    local t = frame.totems
    if t then
        region(lines, label .. ".totems.holder", t.holder, map)
        for i, s in ipairs(t.slots) do
            region(lines, label .. ".totems.art" .. i, s.art, map)
            region(lines, label .. ".totems.click" .. i, s.click, map)
        end
    end
    -- Added after the first record: the role icon and its texture, the 3D
    -- portrait's opacity (it fades with the frame).
    if g then
        region(lines, label .. ".groupIcons.role", g.role, map)
        lines[#lines + 1] = ("%s.groupIcons.role texture=%s atlas=%s"):format(label, tostring(g.role._texture),
            tostring(g.role._atlas))
    end
    if frame.portrait3D then
        lines[#lines + 1] = ("%s.portrait3D shown=%s alpha=%s"):format(label, tostring(frame.portrait3D:IsShown()),
            num(frame.portrait3D:GetAlpha()))
    end
end

-- Boots the addon with a player, a pet, an elite target with a target of
-- its own, a focus and two party members, faded out of combat or not.
-- opts.shipped: with the shipped look (Core/Preset.lua); opts.db: the
-- SavedVariables the boot finds (default none, a fresh install).
function Look.Record(opts)
    opts = opts or {}
    local ns = opts.shipped and H.LoadShipped() or H.LoadAddon()
    M.units.player = { name = "Me", class = "SHAMAN", className = "SHAMAN", isPlayer = true, health = 100,
        healthMax = 100, power = 50, powerMax = 100, level = 60, leader = true }
    M.units.pet = { name = "Wolf", health = 40, healthMax = 50, power = 10, powerMax = 100, level = 58 }
    M.units.target = { name = "Ogre", health = 70, healthMax = 100, classification = "elite", level = 61 }
    M.units.targettarget = { name = "Me", class = "SHAMAN", className = "SHAMAN", isPlayer = true, health = 100,
        healthMax = 100 }
    M.units.focus = { name = "Rat", health = 5, healthMax = 10, classification = "rare", level = 12 }
    M.units.party1 = { name = "Ann", class = "PRIEST", className = "PRIEST", isPlayer = true, health = 5,
        healthMax = 10, role = "HEALER" }
    M.units.party2 = { name = "Bob", class = "WARRIOR", className = "WARRIOR", isPlayer = true, health = 9,
        healthMax = 10, role = "TANK" }
    _G.ForeverUnitFramesDB = opts.db
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    M.SetGroup({ "party1", "party2" })
    if opts.portrait then ns.Config.Set("target", "portraitMode", "LEFT") end
    if opts.fade then
        ns.Config.Set("player", "playerFadeOOC", true)
        ns.Config.Set("player", "playerFadeTarget", false)
    end
    M.FireEvent("PLAYER_TARGET_CHANGED")
    M.FireEvent("PLAYER_FOCUS_CHANGED")
    M.FireEvent("UNIT_PET", "player")
    M.RunTimers()
    if opts.test then ns.TestMode.Set(true) end
    local lines = {}
    for _, key in ipairs({ "player", "pet", "target", "targettarget", "focus" }) do
        Look.Frame(lines, key, ns.Frames[key])
    end
    for i = 1, 2 do
        local b = opts.test and ns.Party.fakes[i] or ns.Party.buttons[i]
        if b then Look.Frame(lines, "party" .. i, b) end
    end
    if opts.test then ns.TestMode.Set(false) end
    return lines
end

-- The record of every scene as the source of a record file (see
-- tools/look-record.lua).
function Look.Source(opts, header)
    local out = { header, "return {" }
    for _, scene in ipairs(Look.ORDER) do
        local o = {}
        for k, v in pairs(Look.SCENES[scene]) do o[k] = v end
        for k, v in pairs(opts or {}) do o[k] = v end
        out[#out + 1] = "    " .. scene .. " = {"
        for _, line in ipairs(Look.Record(o)) do out[#out + 1] = "        " .. ("%q"):format(line) .. "," end
        out[#out + 1] = "    },"
    end
    out[#out + 1] = "}"
    return table.concat(out, "\n")
end

Look.ORDER = { "live", "portrait", "faded", "test" }

Look.SCENES = {
    live = {},
    portrait = { portrait = true },
    faded = { fade = true },
    test = { test = true },
}

return Look
