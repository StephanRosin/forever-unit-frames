-- Heals, shields and combat numbers on a raid cell (Raid/Settings.lua,
-- Raid/Cell.lua): incoming heals (on), the overheal lane (off), absorb
-- shields (on) and the damage and heal numbers (off), per raid size. The
-- party frame's switches do not count; heals past the cell's edge stay
-- off (the next cell sits there).
local M = H.M
local ns = H.LoadAddon()
local RC, C, RS, Header = ns.RaidConfig, ns.Config, ns.RaidSettings, ns.RaidHeader
C.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

local KEYS = { healPrediction = true, overheal = false, absorbs = true, combatText = false }
local codes = {}
for i, key in ipairs({ "healPrediction", "overheal", "absorbs", "combatText" }) do
    H.check("default " .. key, RS.Default(RS.Get(key), "r10"), KEYS[key])
    codes[i] = RS.Get(key).code
end
H.check("codes", table.concat(codes, " "), "IH OV AS CT")

-- The cell asks the raid profile.
H.check("cell heals", C.Get("raid", "healPrediction"), true)
H.check("cell overheal lane", C.Get("raid", "healOverflow"), false)
H.check("cell shields", C.Get("raid", "absorbEnabled"), true)
H.check("cell numbers", C.Get("raid", "combatFeedback"), false)
H.check("never past the edge", C.Get("raid", "healBeyond"), false)
C.Set("party", "healPrediction", false)
C.Set("party", "absorbEnabled", false)
C.Set("party", "combatFeedback", true)
H.check("not the party frame's heals", C.Get("raid", "healPrediction"), true)
H.check("not the party frame's shields", C.Get("raid", "absorbEnabled"), true)
H.check("not the party frame's numbers", C.Get("raid", "combatFeedback"), false)

-- On a cell in a raid.
local function member(name, subgroup)
    return { name = name, class = "MAGE", subgroup = subgroup, unit = { health = 60, healthMax = 100, powerType = 0 } }
end
Header.Create()
M.SetRaidRoster({ member("Ann", 1), member("Bob", 1) })
local cell = Header.headers[1]:GetAttribute("child1")
H.check("heals shown", cell.healClip:IsShown(), true)
H.check("shield shown", cell.absorbClip:IsShown(), true)
RC.Set("r10", "healPrediction", false)
RC.Set("r10", "absorbs", false)
RC.Set("r10", "overheal", true)
RC.Set("r10", "combatText", true)
H.check("heals off", cell.healClip:IsShown(), false)
H.check("shield off", cell.absorbClip:IsShown(), false)
H.check("overheal lane on", C.Get("raid", "healOverflow"), true)
H.check("numbers on", C.Get("raid", "combatFeedback"), true)
H.check("other sizes keep theirs", RC.Get("r20", "healPrediction"), true)

-- In the window: a section of their own on the Cell tab.
local cellTab
for _, t in ipairs(ns.RaidSchema.TABS) do
    if t.id == "cell" then cellTab = t end
end
H.check("heals section", cellTab.sections[4].id, "heals")
H.check("heals section keys", table.concat(cellTab.sections[4].keys, ","),
    "healPrediction,overheal,absorbs,combatText")
H.check("section title", ns.RaidSchema.SectionTitle("heals"), "Heals and shields")
H.check("label", ns.RaidSchema.Label("overheal"), "Overheal lane")
H.check("nothing blocked", #M.blocked, 0)
