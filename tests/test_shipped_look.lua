-- The shipped look (Core/Preset.lua) after a fresh install, every scene,
-- against its record (tests/look.lua, written by tools/look-record.lua).
local Look = dofile("look.lua")

local function compare(label, want, opts)
    for _, scene in ipairs(Look.ORDER) do
        local o = { shipped = true }
        for k, v in pairs(Look.SCENES[scene]) do o[k] = v end
        for k, v in pairs(opts or {}) do o[k] = v end
        local got = Look.Record(o)
        H.check(label .. " " .. scene .. ": as many lines", #got, #want[scene])
        for i = 1, math.max(#got, #want[scene]) do
            H.check(label .. " " .. scene .. " line " .. i, got[i], want[scene][i])
        end
    end
end

compare("fresh install", dofile("shipped_look_0_22.lua"))
