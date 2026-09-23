local M = H.M
local ns = H.LoadAddon()
local S = ns.Secrets

H.checkTrue("IsSecret on proxy", S.IsSecret(M.Secret(1)))
H.check("IsSecret on number", S.IsSecret(5), false)

H.check("Number readable", S.Number(42), 42)
H.check("Number secret -> nil", S.Number(M.Secret(42)), nil)
H.check("Number of string -> nil", S.Number("x"), nil)

H.check("Bool plain true", S.Bool(function() return true end), true)
H.check("Bool plain nil -> false", S.Bool(function() return nil end), false)
H.check("Bool secret -> nil", S.Bool(function() return M.Secret(true) end), nil)
H.check("Bool error -> nil", S.Bool(function() error("x") end), nil)

H.check("Abbreviate small", S.Abbreviate(9876), "9876")
H.check("Abbreviate thousands", S.Abbreviate(12345), "12.3k")
H.check("Abbreviate millions", S.Abbreviate(2500000), "2.5m")
local sec = M.Secret(12345)
H.check("Abbreviate secret passes through", S.Abbreviate(sec), sec)

local c = S.PercentCurve()
H.check("curve cached", S.PercentCurve(), c)
H.check("curve has two points", #c.points, 2)
