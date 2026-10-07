-- Options that are off by default leave the unit frames exactly as they
-- were: every frame's texts, group icons (the role icon's texture too),
-- elite marker, totems, opacity and 3D portrait opacity after a default boot, live, with a portrait, faded and in test
-- mode, against the record in default_look.lua (tests/look.lua).
local Look = dofile("look.lua")
local want = dofile("default_look.lua")

for _, scene in ipairs({ "live", "portrait", "faded", "test" }) do
    local got = Look.Record(Look.SCENES[scene])
    H.check(scene .. ": as many lines", #got, #want[scene])
    for i = 1, math.max(#got, #want[scene]) do
        H.check(scene .. " line " .. i, got[i], want[scene][i])
    end
end
