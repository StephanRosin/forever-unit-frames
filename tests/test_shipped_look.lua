-- The shipped look (Core/Preset.lua), every scene, against its records
-- (tests/look.lua, written by tools/look-record.lua): a fresh install has
-- the revised look of 0.23.0; a profile saved before keeps 0.22.0's
-- (Core/PresetUpgrade.lua).
local Look = dofile("look.lua")

local function copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = copy(v) end
    return c
end

-- opts.db: the SavedVariables every scene starts from (a copy each).
local function compare(label, want, opts)
    for _, scene in ipairs(Look.ORDER) do
        local o = { shipped = true }
        for k, v in pairs(Look.SCENES[scene]) do o[k] = v end
        for k, v in pairs(opts or {}) do o[k] = copy(v) end
        local got = Look.Record(o)
        H.check(label .. " " .. scene .. ": as many lines", #got, #want[scene])
        for i = 1, math.max(#got, #want[scene]) do
            H.check(label .. " " .. scene .. " line " .. i, got[i], want[scene][i])
        end
    end
end

compare("fresh install", dofile("shipped_look.lua"))
-- A 0.22.0 profile that kept every default (its SavedVariables as 0.22.0
-- wrote them), and one from before the format had a version.
compare("saved by 0.22.0", dofile("shipped_look_0_22.lua"), { db = { version = 1, profile = {} } })
compare("older SavedVariables", dofile("shipped_look_0_22.lua"), { db = { profile = {} } })
