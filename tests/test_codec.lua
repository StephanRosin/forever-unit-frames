local ns = H.LoadAddon()
local Codec, C = ns.Codec, ns.Config

local function deepEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then
        if type(a) == "number" then return math.abs(a - b) < 0.003 end
        return a == b
    end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

C.Use({})
H.check("empty profile", Codec.Encode(C.Profile()), "1")

C.Set("player", "width", 250)
C.Set("player", "enabled", false)
C.Set("target", "textHealthRight", "CURRENT_MAX")
C.Set("general", "healthColor", { 1, 0.5, 0, 1 })
C.Set("general", "fontFace", "My;Font%")
C.Set("target", "x", -120)
local s = Codec.Encode(C.Profile())
H.check("encoded form", s, "1;gFF'My%3BFont%25;gHC#ff8000ff;pE0;pW250;tTR6;tX-120")

local back = assert(Codec.Decode(s))
H.checkTrue("round trip", deepEqual(back, C.Profile()))

-- Robustness
H.check("unknown code skipped", Codec.Decode("1;pZZ5;pW250").player.width, 250)
H.check("unknown scope skipped", Codec.Decode("1;qW250;pW260").player.width, 260)
H.check("invalid value skipped", Codec.Decode("1;pWabc").player.width, nil)
H.check("enum index out of range skipped", Codec.Decode("1;tTR99").target.textHealthRight, nil)
local p, err = Codec.Decode("2;pW250")
H.check("future version rejected", p, nil)
H.check("version error key", err, "CODEC_VERSION")
local _, err2 = Codec.Decode("")
H.check("empty rejected", err2, "CODEC_EMPTY")
local _, err3 = Codec.Decode("hello")
H.check("garbage rejected", err3, "CODEC_FORMAT")

-- Budget: a heavily customised profile stays small.
C.ResetAll()
for _, scope in ipairs({ "player", "target" }) do
    C.Set(scope, "width", 333); C.Set(scope, "height", 55); C.Set(scope, "x", -1234); C.Set(scope, "y", 456)
    C.Set(scope, "healthPercent", 70); C.Set(scope, "powerPercent", 20)
    C.Set(scope, "textHealthLeft", "NAME"); C.Set(scope, "textHealthRight", "PERCENT")
    C.Set(scope, "fontSize", 11); C.Set(scope, "barTexture", "Smooth")
end
C.Set("general", "fontFace", "Arial Narrow"); C.Set("general", "backgroundColor", { 0.1, 0.1, 0.1, 0.8 })
local size = #Codec.Encode(C.Profile())
H.checkTrue("two heavily customised frames under 250 chars (" .. size .. ")", size < 250)
