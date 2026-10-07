-- Secrets.Call and Secrets.Plain (Core/Secrets.lua): the one secret check
-- the raid code and the group icons share.
local M = H.M
local ns = H.LoadAddon()
local S = ns.Secrets

H.check("Call: the first result", S.Call(function(a, b) return a + b, "second" end, 2, 3), 5)
H.check("Call: arguments passed", S.Call(string.upper, "x"), "X")
H.check("Call: false kept", S.Call(function() return false end), false)
H.check("Call: nil", S.Call(function() return nil end), nil)
H.check("Call: secret -> nil", S.Call(function() return M.Secret("TANK") end), nil)
H.check("Call: error -> nil", S.Call(function() error("refused") end), nil)
H.check("Call: not a function -> nil", S.Call(nil, "player"), nil)
H.check("Call: a secret second result does not matter", S.Call(function() return 1, M.Secret(2) end), 1)

H.check("Plain: string", S.Plain("HEALER", "string"), "HEALER")
H.check("Plain: empty string kept", S.Plain("", "string"), "")
H.check("Plain: number", S.Plain(3, "number"), 3)
H.check("Plain: other type -> nil", S.Plain(3, "string"), nil)
H.check("Plain: nil -> nil", S.Plain(nil, "string"), nil)
H.check("Plain: secret -> nil", S.Plain(M.Secret("TANK"), "string"), nil)
H.check("Plain: secret number -> nil", S.Plain(M.Secret(1), "number"), nil)
H.check("Plain: boolean", S.Plain(false, "boolean"), false)
