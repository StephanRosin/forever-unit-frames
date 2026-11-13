local H = { pass = 0, fail = 0 }
local M = dofile("mock.lua")
H.M = M

local function show(v)
    if M.IsSecret(v) then return "<secret>" end
    return tostring(v)
end

-- The line of the test file that made the check (the first caller
-- outside this file).
local function callerLine()
    for level = 3, 12 do
        local info = debug.getinfo(level, "Sl")
        if not info then return "?" end
        if info.what ~= "C" and not info.short_src:find("harness%.lua$") then return info.currentline end
    end
    return "?"
end

-- note (optional): shown with a failure, e.g. the error of a pcall.
function H.check(label, got, want, note)
    if got == want then
        H.pass = H.pass + 1
    else
        H.fail = H.fail + 1
        print(("  FAIL %s (line %s) -> %s (want %s)%s"):format(label, callerLine(), show(got), show(want),
            note ~= nil and ("  " .. show(note)) or ""))
    end
end
function H.checkTrue(label, v, note) H.check(label, not not v, true, note) end
function H.checkError(label, fn)
    local ok = pcall(fn)
    H.check(label .. " raises", ok, false)
end

-- Files of the addon in TOC order (ignores comments and blank lines).
function H.TocFiles()
    local files = {}
    for line in io.lines(ADDONDIR .. "/ForeverUnitFrames.toc") do
        line = line:gsub("\r", "")
        if not line:match("^%s*#") and line:match("%S") then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    return files
end

-- The shipped look. Tests run against the plain defaults so they do not
-- change with the look; test_preset.lua loads it with H.LoadShipped.
H.PRESET = "Core/Preset.lua"

local function withoutPreset(files)
    local out = {}
    for _, f in ipairs(files) do
        if f ~= H.PRESET then out[#out + 1] = f end
    end
    return out
end

-- Fresh mock + fresh namespace, every file loaded like the client does:
-- chunk(addonName, ns). `files` defaults to the whole TOC without the
-- preset. XML files are not loaded; the mock mirrors their templates (see
-- M.templates).
function H.LoadAddon(files)
    -- The shared ClickCastFrames table (Units/Units.lua) outlives a boot and
    -- holds every unit button of the previous one, and through them that
    -- whole addon: thousands of boots ran the suite out of memory. A table
    -- with buttons in it is left over; a table a test put there for Clique
    -- is still empty and stays.
    -- The same for the addon's named frames: a frame the next boot does not
    -- make again (a test cell, the minimap button) keeps the old boot alive.
    local ccf = rawget(_G, "ClickCastFrames")
    if type(ccf) == "table" and next(ccf) ~= nil then _G.ClickCastFrames = nil end
    -- Any global widget, not only ours: a test that stands in for a
    -- Blizzard frame (PlayerFrame, TargetFrame ...) kept every later boot
    -- alive through it (hooks added per boot). M.Reset makes UIParent and
    -- the client's frames again.
    local stale = {}
    for k, v in pairs(_G) do
        if type(v) == "table" and rawget(v, "_kind") ~= nil then stale[#stale + 1] = k end
    end
    for _, k in ipairs(stale) do _G[k] = nil end
    M.Reset()
    local ns = {}
    for _, f in ipairs(files or withoutPreset(H.TocFiles())) do
        if not f:match("%.xml$") then
            local chunk = assert(loadfile(ADDONDIR .. "/" .. f))
            chunk("ForeverUnitFrames", ns)
        end
    end
    return ns
end

-- The addon exactly as shipped, preset included.
function H.LoadShipped()
    return H.LoadAddon(H.TocFiles())
end

-- Whole file as a string (for checks on XML the tests cannot load).
function H.ReadFile(path)
    local fh = assert(io.open(ADDONDIR .. "/" .. path))
    local text = fh:read("*a")
    fh:close()
    return text
end

return H
