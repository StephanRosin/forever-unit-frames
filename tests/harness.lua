local H = { pass = 0, fail = 0 }
local M = dofile("mock.lua")
H.M = M

local function show(v)
    if M.IsSecret(v) then return "<secret>" end
    return tostring(v)
end

function H.check(label, got, want)
    if got == want then
        H.pass = H.pass + 1
    else
        H.fail = H.fail + 1
        print(("  FAIL %s -> %s (want %s)"):format(label, show(got), show(want)))
    end
end
function H.checkTrue(label, v) H.check(label, not not v, true) end
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

-- Fresh mock + fresh namespace, every file loaded like the client does:
-- chunk(addonName, ns). `files` defaults to the whole TOC.
function H.LoadAddon(files)
    M.Reset()
    local ns = {}
    for _, f in ipairs(files or H.TocFiles()) do
        local chunk = assert(loadfile(ADDONDIR .. "/" .. f))
        chunk("ForeverUnitFrames", ns)
    end
    return ns
end

return H
