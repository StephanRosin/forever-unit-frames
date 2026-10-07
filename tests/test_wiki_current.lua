-- The wiki's settings reference in docs/wiki is generated from the options
-- (tools/make_wiki). This checks the committed pages are current: after a
-- change to an option, run tools/make_wiki and commit the pages with it.
local dir = os.tmpname()
os.remove(dir)
os.execute("mkdir -p '" .. dir .. "'")
_G.WIKI_OUT = dir
local ok, err = pcall(dofile, ADDONDIR .. "/tools/make_wiki.lua")
_G.WIKI_OUT = nil
H.checkTrue("generator runs", ok, err)
local function read(path)
    local fh = io.open(path)
    if not fh then return nil end
    local text = fh:read("*a")
    fh:close()
    return text
end
H.checkTrue("the generator lists its pages", type(WIKI_PAGES) == "table" and #WIKI_PAGES > 0)
local names = { "_Sidebar.md" }
for _, page in ipairs(WIKI_PAGES or {}) do names[#names + 1] = page[1] .. ".md" end
for _, name in ipairs(names) do
    H.check("docs/wiki/" .. name .. " is current (run tools/make_wiki)",
        read(ADDONDIR .. "/docs/wiki/" .. name) == read(dir .. "/" .. name), true)
end
os.execute("rm -rf '" .. dir .. "'")
