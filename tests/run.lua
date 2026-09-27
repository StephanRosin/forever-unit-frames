package.path = "./?.lua;" .. package.path
local H = dofile("harness.lua")
_G.H = H

local names = {}
-- tests/run [pattern]: only the test files whose name contains pattern.
local only = arg and arg[1]
for f in io.popen('ls test_*.lua'):lines() do
    if not only or f:find(only, 1, true) then names[#names + 1] = f end
end
table.sort(names)
for _, f in ipairs(names) do
    print(f)
    local ok, err = pcall(dofile, f)
    if not ok then H.fail = H.fail + 1; print("  ERROR " .. tostring(err)) end
end
print(("%d passed, %d failed"):format(H.pass, H.fail))
os.exit(H.fail == 0 and 0 or 1)
