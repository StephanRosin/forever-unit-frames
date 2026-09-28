-- Reported: a creature's portrait often showed the previously selected
-- unit's, and (after clearing it) 3D showed nothing while the model
-- loaded. The client keeps a model or picture when it has none for the
-- new unit: both are emptied first, and in 3D the 2D picture stands in
-- until the model is loaded (for good, when there is none).
local M = H.M
local ns = H.LoadAddon()
local C = ns.Config
C.Use({})
M.units.player = { name = "Me", isPlayer = true, health = 1, healthMax = 1 }
M.units.target = { name = "Wolf", hostile = true, health = 5, healthMax = 10 }
ns.Single.CreateAll()
local t = ns.Frames.target
C.Set("target", "portraitMode", "LEFT")
C.Set("target", "portraitStyle", "3D")
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("3D: the wolf's model", t.portrait3D._modelUnit, "target")
H.check("model at once: no 2D stand-in", t.portrait2D:IsShown(), false)
H.check("framed as a portrait", t.portrait3D._zoom, 1)

-- A creature (reported: rats, apparitions). Measured in Forever: SetUnit
-- answers nil and loads nothing, the display ID stays 0. It is set by its
-- NPC ID from the GUID instead.
M.units.target = { name = "Rat", hostile = true, health = 5, healthMax = 10, creatureModel = true,
    guid = "Creature-0-1-2-3-4075-5", npcID = 4075 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("creature: set by NPC ID", t.portrait3D._creature, 4075)
H.check("creature: its model", t.portrait3D._modelUnit, "target")
H.check("creature: no 2D stand-in", t.portrait2D:IsShown(), false)
H.check("creature: framed", t.portrait3D._zoom, 1)
H.check("NPC ID from the GUID", ns.Portrait.CreatureID("target"), 4075)
-- A secret GUID: no ID, the 2D picture stays.
M.units.target = { name = "Rat", hostile = true, health = 5, healthMax = 10, creatureModel = true,
    guid = M.Secret("Creature-0-1-2-3-4075-5"), npcID = 4075 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("secret GUID: no model", t.portrait3D._modelUnit, nil)
H.checkTrue("secret GUID: 2D", t.portrait2D:IsShown())
-- Players are never looked up by NPC ID.
M.units.target = { name = "Ann", isPlayer = true, health = 5, healthMax = 10, guid = "Player-1-0ABC" }
H.check("a player has no NPC ID", ns.Portrait.CreatureID("target"), nil)

-- A model the client loads later: 2D first, then the model.
M.units.target = { name = "Bear", hostile = true, health = 5, healthMax = 10, modelLater = true }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("loading: no model yet", t.portrait3D._modelUnit, nil)
H.checkTrue("loading: the 2D picture", t.portrait2D:IsShown())
H.check("loading: the bear's picture", t.portrait2D._texture, "portrait:target")
M.LoadModels()
H.check("loaded: the model", t.portrait3D._modelUnit, "target")
H.check("loaded: the 2D picture goes", t.portrait2D:IsShown(), false)

-- No model at all: the 2D picture stays, never the old model.
M.units.target = { name = "Ghost", hostile = true, health = 5, healthMax = 10, noModel = true }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("3D: no leftover model", t.portrait3D._modelUnit, nil)
H.checkTrue("no model: 2D instead", t.portrait2D:IsShown())
H.check("no model: its picture", t.portrait2D._texture, "portrait:target")
-- A restyle keeps the stand-in.
C.Set("target", "height", 50)
H.checkTrue("restyle: still 2D", t.portrait2D:IsShown())

-- 2D: no leftover face either.
C.Set("target", "portraitStyle", "2D")
M.units.target = { name = "Wolf", hostile = true, health = 5, healthMax = 10 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("2D: the wolf's face", t.portrait2D._texture, "portrait:target")
M.units.target = { name = "Ghost", hostile = true, health = 5, healthMax = 10, noPortrait = true }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("2D: no leftover face", t.portrait2D._texture, nil)
