-- The wiki's hand-written pages (docs/wiki/Home.md, FAQ.md): Home links
-- every raid page the generator writes (tools/make_wiki.lua), and tells
-- of the special panels and the raid tools bar; the FAQ answers where
-- Blizzard's raid manager went.
local dir = os.tmpname()
os.remove(dir)
os.execute("mkdir -p '" .. dir .. "'")
_G.WIKI_OUT = dir
local ok = pcall(dofile, ADDONDIR .. "/tools/make_wiki.lua")
_G.WIKI_OUT = nil
os.execute("rm -rf '" .. dir .. "'")
H.checkTrue("generator runs", ok)
local home = H.ReadFile("docs/wiki/Home.md")
H.checkTrue("the generator lists its pages", type(WIKI_PAGES) == "table" and #WIKI_PAGES > 0)
for _, page in ipairs(WIKI_PAGES or {}) do
    if page[1]:match("^Raid%-") then
        H.checkTrue("Home links " .. page[1], home:find("[[" .. page[2] .. "|" .. page[1] .. "]]", 1, true))
    end
end
H.checkTrue("Home: the special panels", home:find("**Special panels**", 1, true))
H.checkTrue("Home: the raid tools bar", home:find("**raid tools bar**", 1, true))
local faq = H.ReadFile("docs/wiki/FAQ.md")
H.checkTrue("FAQ: Blizzard's raid manager", faq:find("### Where is Blizzard's raid manager?", 1, true))
H.checkTrue("FAQ: a list in combat", faq:find("### A player I put on my tanks or favorites does not show", 1, true))
-- Section names as the window shows them; American spelling like the UI;
-- the elite marker lives on Status; the Profiles tab starts with templates.
H.checkTrue("FAQ: the Text tab's Presentation section", faq:find("[[Text|Settings-Text]] > *Presentation*", 1, true))
H.checkTrue("Presentation is the section's name",
    H.ReadFile("Locales/enUS.lua"):find('L.SECTION_display = "Presentation"', 1, true))
for _, word in ipairs({ "favourite", "centre", "colour" }) do
    H.checkTrue("Home: American spelling, no " .. word, not home:find(word, 1, true))
    H.checkTrue("FAQ: American spelling, no " .. word, not faq:find(word, 1, true))
end
H.checkTrue("Home: the elite marker under Status", home:find("[[Status|Settings-Status]] – combat, PvP and status icons, raid markers, the elite marker", 1, true))
H.checkTrue("Home: the Profiles tab starts with templates",
    home:find("The **Profiles** tab (beside the sizes) starts with the role templates", 1, true))
-- Where to report a bug, and the raid frames' emergency switch.
H.checkTrue("FAQ: a Lua error in a raid", faq:find("### Lua error in a raid?", 1, true)
    and faq:find("`/fuf raid off` and then `/reload`", 1, true))
H.checkTrue("FAQ: reporting bugs", faq:find("**Reporting bugs:**", 1, true) and faq:find("foreverwowui@gmail.com", 1, true))
H.checkTrue("Home: reporting bugs", home:find("**Reporting bugs:**", 1, true) and home:find("foreverwowui@gmail.com", 1, true))
H.checkTrue("Home: the switch in the commands", home:find("| `/fuf raid off`, `/fuf raid on` |", 1, true))
local description = H.ReadFile("docs/curseforge/description.md")
H.checkTrue("description: feedback", description:find("## Feedback", 1, true) and description:find("foreverwowui@gmail.com", 1, true))
H.checkTrue("description: the switch", description:find("`/fuf raid off`", 1, true))
