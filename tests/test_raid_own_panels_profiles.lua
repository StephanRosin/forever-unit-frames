-- A size's own panels go with it (Raid/Profiles.lua): copied from another
-- size or character, reset, exported and imported; the panels follow.
local M = H.M
local ns = H.LoadAddon()
local RC, Profiles, Own = ns.RaidConfig, ns.RaidProfiles, ns.RaidOwnPanels
ns.Config.Use({})
local db = { raid = { ["Other-Realm"] = { r40 = { panel5Show = true, panel5Blocks = "7,8", panel5Title = "Back" } } } }
M.units.player = { name = "Me", class = "MAGE" }
Profiles.Attach(db)
ns.RaidSize.Update()
ns.RaidHeader.Create()

local function describe(size)
    local parts = {}
    for _, column in ipairs(Own.Columns(size)) do
        local tokens = {}
        for i, block in ipairs(column.blocks) do tokens[i] = tostring(block.id) end
        parts[#parts + 1] = column.id .. ":" .. table.concat(tokens, ",")
    end
    return table.concat(parts, " ")
end

RC.Set("r20", "panel2Show", true)
RC.Set("r20", "panel2Blocks", "3,4")
RC.Set("r20", "panel2Title", "Ranged; back")
RC.Set("r20", "panel2CellsPerLine", 2)
RC.Set("r20", "panel2X", 480)

-- Copied from another size: the panels, their blocks, title and layout.
Profiles.CopySize(20, 10)
H.check("10: panel 2 shown", RC.Get("r10", "panel2Show"), true)
H.check("10: its blocks", RC.Get("r10", "panel2Blocks"), "3,4")
H.check("10: its title", RC.Get("r10", "panel2Title"), "Ranged; back")
H.check("10: its layout", RC.Get("r10", "panel2CellsPerLine"), 2)
H.check("10: its position", RC.Get("r10", "panel2X"), 480)
H.check("10: groups 3 and 4 do not exist there", describe(10), "main:1,2 panel2:")
M.RunTimers()
H.check("the panel follows", #Own.panels.panel2.blocks, 0)
H.checkTrue("on at 10", Own.panels.panel2.Enabled())

-- From another character's size.
H.checkTrue("copied from a character", Profiles.CopyFromCharacter("Other-Realm", 40, 40))
H.check("40: panel 5", describe(40), "main:1,2,3,4,5,6 panel5:7,8")
H.check("40: its title", RC.Get("r40", "panel5Title"), "Back")

-- Exported and imported: onto another size, everything it had replaced.
local text = Profiles.Export(20)
H.checkTrue("the title escaped", text:find("bAT'Ranged%3B back", 1, true))
Profiles.ResetSize(40)
H.check("reset: no own panel", describe(40), "main:1,2,3,4,5,6,7,8")
H.check("reset: its title gone", RC.Get("r40", "panel5Title"), "")
RC.Set("r40", "panel6Show", true)
local ok, rejected = Profiles.Import(text, 40)
H.checkTrue("imported", ok)
H.check("nothing rejected", rejected, 0)
H.check("40: as 20 was", describe(40), "main:1,2,5,6,7,8 panel2:3,4")
H.check("40: the title read back", RC.Get("r40", "panel2Title"), "Ranged; back")
H.check("40: panel 6 replaced", RC.Get("r40", "panel6Show"), false)
H.check("no error", #M.errors, 0)
