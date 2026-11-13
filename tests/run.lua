package.path = "./?.lua;" .. package.path
local H = dofile("harness.lua")
_G.H = H

local names = {}
-- tests/run [pattern]: only the test files whose name contains pattern.
-- FUF_PART=i/n (tests/run -j): every n-th file from the i-th, so that n
-- processes share the list.
local only = arg and arg[1]
if only == "" then only = nil end
local part, parts = (os.getenv("FUF_PART") or "1/1"):match("^(%d+)/(%d+)$")
part, parts = tonumber(part) or 1, tonumber(parts) or 1
local all = {}
for f in io.popen('ls test_*.lua'):lines() do
    if not only or f:find(only, 1, true) then all[#all + 1] = f end
end
table.sort(all)
for i, f in ipairs(all) do
    if (i - 1) % parts == part - 1 then names[#names + 1] = f end
end
local started = os.time()
for _, f in ipairs(names) do
    print(f)
    local ok, err = pcall(dofile, f)
    if not ok then H.fail = H.fail + 1; print("  ERROR " .. tostring(err)) end
end
print(("%d passed, %d failed (%d files, %d s)"):format(H.pass, H.fail, #names, os.time() - started))
os.exit(H.fail == 0 and 0 or 1)
