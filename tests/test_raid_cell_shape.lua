-- One cell-shape helper (Raid/Panel.lua Panel.CellShape) for the main
-- panel, the own panels and the special panels: the cells' size, border
-- and spacing from the main panel, cells per line, growth and title row
-- as the panel has them; the block part from each panel.
local ns = H.LoadAddon()
local RC, Panel, Raid = ns.RaidConfig, ns.RaidPanel, ns.Raid
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
ns.RaidHeader.Create()
local scope = Raid.Scope(ns.RaidCell.Size())

local read = { cellsPerLine = 3, cellGrowth = "RIGHT", blockTitles = false }
local cells = Panel.CellShape(function(key) return read[key] end)
local w, h = ns.Single.Size(ns.RaidCell.KEY)
H.check("cell size: the main panel's", cells.cellWidth .. "x" .. cells.cellHeight, w .. "x" .. h)
H.check("per line from read", cells.cellsPerLine, 3)
H.check("growth from read", cells.cellGrowth, "RIGHT")
H.check("no title row", cells.titleHeight, 0)
H.check("no block part", cells.blockGap, nil)
read.blockTitles = true
H.check("title row", Panel.CellShape(function(key) return read[key] end).titleHeight, ns.Pixel.Snap(Panel.TITLE_HEIGHT))
local _, ph = ns.Single.Size(ns.RaidCell.PET_KEY)
H.check("another cell key", Panel.CellShape(function(key) return read[key] end, ns.RaidCell.PET_KEY).cellHeight, ph)

-- The main panel: its own settings, blocks too.
local main = ns.RaidHeader.Shape and ns.RaidHeader.Shape() or Panel.Shape(function(key) return RC.Get(scope, key) end,
    Panel.BLOCK_SCOPE)
H.check("main: cells per line", main.cellsPerLine, RC.Get(scope, "cellsPerLine"))
H.check("main: blocks per line", main.blocksPerLine, RC.Get(scope, "blocksPerLine"))
H.checkTrue("main: a gap between blocks", main.blockGap >= 0)
-- A special panel: its own per line, growth, title; one block.
local tanks = ns.RaidSpecialPanels.panels.mainTanks.Shape()
H.check("special: per line", tanks.cellsPerLine, RC.Get(scope, "mainTanksPerLine"))
H.check("special: growth", tanks.cellGrowth, RC.Get(scope, "mainTanksGrowth"))
H.check("special: the main cells", tanks.cellWidth, w)
H.check("special: same gap", tanks.cellGap, main.cellGap)
H.check("special: one block", tanks.blockGap .. "," .. tanks.blocksPerLine .. "," .. tanks.blockDirection, "0,1,HORIZONTAL")
local pets = ns.RaidSpecialPanels.panels.pets.Shape()
H.check("pets: their own height", pets.cellHeight, ph)
H.check("pets: as wide as the main cells", pets.cellWidth, w)
