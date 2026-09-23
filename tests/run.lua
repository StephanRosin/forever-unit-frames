package.path = "./?.lua;" .. package.path
local H = dofile("harness.lua")
_G.H = H

local names = {}
for f in io.popen('ls test_*.lua'):lines() do names[#names + 1] = f end
table.sort(names)
for _, f in ipairs(names) do
    print(f)
    local ok, err = pcall(dofile, f)
    if not ok then H.fail = H.fail + 1; print("  ERROR " .. tostring(err)) end
end
print(("%d passed, %d failed"):format(H.pass, H.fail))
os.exit(H.fail == 0 and 0 or 1)
