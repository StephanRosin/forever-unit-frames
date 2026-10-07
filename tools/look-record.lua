-- Prints a record of the unit frames' look for tests/ (tests/look.lua):
--   cd tests && lua5.1 -e "ADDONDIR='<repo>'" ../tools/look-record.lua shipped > shipped_look.lua
-- "shipped": a fresh install with the shipped look (Core/Preset.lua);
-- "plain": the plain defaults (default_look.lua). A record is written once,
-- from the version it stands for, and only rewritten when that look is
-- meant to change: say why in the commit.
package.path = "./?.lua;" .. package.path
local H = dofile("harness.lua")
_G.H = H
local Look = dofile("look.lua")
local which = arg and arg[1] or "shipped"
assert(which == "shipped" or which == "plain", "shipped or plain")
local header = "-- Written by tools/look-record.lua " .. which .. "."
print(Look.Source({ shipped = which == "shipped" }, header))
