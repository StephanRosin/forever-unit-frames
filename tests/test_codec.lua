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
C.Set("player", "hideBlizzardCastbar", true)
local s = Codec.Encode(C.Profile())
H.check("encoded form", s, "1;gFF'My%3BFont%25;gHC#ff8000ff;pCB1;pE0;pW250;tTR6;tX-120")

local back = assert(Codec.Decode(s))
H.checkTrue("round trip", deepEqual(back, C.Profile()))

-- Trailing whitespace of a media value is escaped: a reader that trims
-- line endings can never shorten it.
C.Set("general", "fontFace", "Trail %;\t ")
local trailing = Codec.Encode(C.Profile())
H.checkTrue("trailing whitespace escaped", trailing:find("gFF'Trail %25%3B%09%20;", 1, true))
H.check("trailing whitespace round trip", Codec.Decode(trailing).general.fontFace, "Trail %;\t ")
H.check("inner space not escaped", Codec.Decode("1;gFF'A B").general.fontFace, "A B")
C.Set("general", "fontFace", "My;Font%")

-- Robustness
H.check("unknown code skipped", Codec.Decode("1;pZZ5;pW250").player.width, 250)
H.check("unknown scope skipped", Codec.Decode("1;qW250;pW260").player.width, 260)
H.check("invalid value skipped", Codec.Decode("1;pWabc").player.width, nil)
H.check("enum index out of range skipped", Codec.Decode("1;tTR99").target.textHealthRight, nil)
-- Rejected entries (third return value). A known code whose value does
-- not parse is lost data; an unknown code or scope, or an enum index this
-- version does not know, may come from a newer version and is skipped
-- without counting.
local function rejected(str) return select(3, Codec.Decode(str)) end
H.check("clean: nothing rejected", rejected("1;pW250;tHM4"), 0)
H.check("version only: nothing rejected", rejected("1"), 0)
H.check("unknown code not rejected", rejected("1;pZZ5;pW250"), 0)
H.check("unknown one-letter code not rejected", rejected("1;pQ5"), 0)
H.check("unknown scope not rejected", rejected("1;qW250;pW260"), 0)
H.check("enum out of range not rejected", rejected("1;tTR99"), 0)
H.check("setting of another scope not rejected", rejected("1;pGS7"), 0)
H.check("bad int rejected", rejected("1;pWabc"), 1)
H.check("trailing newline rejected", rejected("1;pW250;tHM4\n"), 1)
H.check("bad bool rejected", rejected("1;pE2"), 1)
H.check("bad color rejected", rejected("1;pHC#ff00"), 1)
H.check("bad enum rejected", rejected("1;tHMx"), 1)
H.check("empty media rejected", rejected("1;gFF'"), 1)
H.check("malformed entry rejected", rejected("1;pW250;;w"), 1)
H.check("empty entries not rejected", rejected("1;pW250;;"), 0)
H.check("text glued to the version rejected", rejected("1x;pW250"), 1)
H.check("rest still decoded", Codec.Decode("1;pWabc;pH40").player.height, 40)
local p, err = Codec.Decode("2;pW250")
H.check("future version rejected", p, nil)
H.check("version error key", err, "CODEC_VERSION")
local _, err2 = Codec.Decode("")
H.check("empty rejected", err2, "CODEC_EMPTY")
local _, err3 = Codec.Decode("hello")
H.check("garbage rejected", err3, "CODEC_FORMAT")
