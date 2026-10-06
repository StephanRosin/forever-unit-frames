-- ns.NewCodec (Core/Codec.lua): a codec per registry, and encoding only
-- some scopes (one raid size for an export).
local ns = H.LoadAddon()

local R = ns.NewRegistry({ "general", "a", "b" }, { general = "g", a = "a", b = "b" })
R.Define({ key = "mode", code = "M", scope = "general", type = "bool", default = false })
R.Define({ key = "width", code = "W", scope = "frame", type = "int", min = 1, max = 500, default = 60 })

local Codec = ns.NewCodec(R)
local profile = { general = { mode = true }, a = { width = 90 }, b = { width = 120 } }
H.check("whole profile", Codec.Encode(profile), "1;gM1;aW90;bW120")
H.check("only scope b", Codec.Encode(profile, { "b" }), "1;bW120")
H.check("version", Codec.VERSION, 1)

local back = assert(Codec.Decode("1;gM1;bW120"))
H.check("decode general", back.general.mode, true)
H.check("decode b", back.b.width, 120)
H.checkTrue("decode: every scope present", type(back.a) == "table")
-- A unit-frame string means nothing here: its scopes and codes are not ours.
local foreign = assert(Codec.Decode("1;pW250;yW90"))
H.check("foreign scope ignored", foreign.a.width, nil)

-- The unit-frame codec is unchanged.
H.check("unit frames", ns.Codec.Encode({ player = { width = 250 } }), "1;pW250")
H.check("unit frames decode", ns.Codec.Decode("1;pW250").player.width, 250)
