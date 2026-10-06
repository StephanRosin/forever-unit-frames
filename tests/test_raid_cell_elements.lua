-- What the elements offer a raid cell (Raid/Cell.lua), each switched by a
-- field no unit frame sets: centred name and second line with AFK as a
-- status (frame.centerTexts), a test-mode sample of its own per frame
-- (frame.sample: class, name, health share, status), and a power bar
-- that a rule of the frame hides (frame.showsPower).
local M = H.M
local ns = H.LoadAddon()
local C = ns.Config
C.Use({})
C.Set("party", "textHealthLeft", "NAME")
C.Set("party", "textHealthRight", "DEFICIT")
C.Set("party", "healthColorMode", "CLASS")
C.Set("party", "barNameColorMode", "CLASS")
M.units.player = { name = "Me", class = "WARLOCK", className = "Warlock", isPlayer = true, level = 60,
    health = 50, healthMax = 100, healthMissing = 50, power = 10, powerMax = 100 }

local function button()
    local b = CreateFrame("Button", nil, UIParent, "SecureUnitButtonTemplate")
    b.key = "party"
    for _, el in ipairs(ns.Elements) do el.Build(b) end
    return b
end

-- A unit frame: the bar's texts at its ends, as always.
local plain = button()
ns.Single.StyleContent(plain)
local p, rel, relPoint, x, y = plain.texts.healthLeft:GetPoint(1)
H.checkTrue("unit frame: name at the left end", p == "LEFT" and rel == plain.health and relPoint == "LEFT" and x == 4 and y == 0)
H.check("unit frame: name justified left", plain.texts.healthLeft._justifyH, "LEFT")
H.check("unit frame: value justified right", plain.texts.healthRight._justifyH, "RIGHT")

-- Centred: the name above the middle, the second line below, each as
-- wide as the bar less 2 on either side.
local cell = button()
cell.centerTexts = true
ns.Single.StyleContent(cell)
local name, second = cell.texts.healthLeft, cell.texts.healthRight
p, rel, relPoint, x, y = name:GetPoint(1)
H.checkTrue("centred: name from the bar's left", p == "LEFT" and rel == cell.health and relPoint == "LEFT" and x == 2)
H.check("centred: name half a value line up", y, 6)
p, rel, relPoint, x, y = name:GetPoint(2)
H.checkTrue("centred: name to the bar's right", p == "RIGHT" and rel == cell.health and relPoint == "RIGHT" and x == -2)
H.check("centred: name justified centre", name._justifyH, "CENTER")
H.check("centred: name on one line", name:GetWordWrap(), false)
p, rel, relPoint, x, y = second:GetPoint(1)
H.checkTrue("centred: second line from the bar's left", p == "LEFT" and rel == cell.health and x == 2)
H.check("centred: second line half a name line down", y, -6)
H.check("centred: second line justified centre", second._justifyH, "CENTER")
C.Set("party", "valueFontSize", 10)
ns.Single.StyleContent(cell)
H.check("value font: name moves half of it up", select(5, name:GetPoint(1)), 5)
H.check("value font: second line keeps half the name", select(5, second:GetPoint(1)), -6)

-- Live: name and missing health; AFK in the second line of a cell only;
-- dead wins over AFK.
ns.Single.SetUnit(cell, "player")
ns.Single.SetUnit(plain, "player")
ns.Single.UpdateAll(cell)
H.check("name", name:GetText(), "Me")
H.check("missing health", second:GetText(), 50)
M.units.player.afk = true
M.FireEvent("PLAYER_FLAGS_CHANGED", "player")
H.check("AFK in the second line", second:GetText(), "AFK")
H.check("unit frame: no AFK word on the bar", plain.texts.healthRight:GetText(), 50)
M.units.player.dead = true
M.FireEvent("UNIT_HEALTH", "player")
H.check("dead wins over AFK", second:GetText(), ns.L.STATUS_DEAD)
M.units.player.dead, M.units.player.afk = nil, nil
M.FireEvent("UNIT_HEALTH", "player")
H.check("back to the value", second:GetText(), 50)

-- Samples: the frame's own class, name, health and status in test mode.
cell.sample = { class = "DRUID", name = "Druid", health = 0.3, status = false }
ns.Single.Preview(cell, true)
H.check("sample health", cell.health:GetValue(), 0.3)
local c = cell.health._color
H.checkTrue("sample class colour", c[1] == 1 and c[2] == 0.49 and c[3] == 0.04)
H.check("sample name", name:GetText(), "Druid")
H.check("sample name in its class colour", name._color[2], 0.49)
H.check("sample missing health", second:GetText(), 70)
cell.sample.status = "OFFLINE"
ns.Single.Preview(cell, true)
H.check("sample status", second:GetText(), ns.L.STATUS_OFFLINE)
H.check("sample status greys the bar", cell.health._color[1], 0.5)
-- A party pretend member keeps the shared sample and the player's colour.
plain.sampleIndex = 1
ns.Single.Preview(plain, true)
H.check("unit frame sample: shared health", plain.health:GetValue(), ns.Health.SAMPLE)
H.check("unit frame sample: the player's class colour", plain.health._color[1], 0.53)
ns.Single.Preview(cell, false)
ns.Single.UpdateAll(cell)
H.check("sample over: live name", name:GetText(), "Me")
H.check("sample over: live colour", cell.health._color[1], 0.53)

-- A power rule of the frame hides the bar; the health bar takes its row.
cell.showsPower = function() return false end
ns.Power.Update(cell)
H.check("rule: power hidden", cell.power:IsShown(), false)
H.check("rule: health takes the row", cell.health:GetHeight(), 32)
cell.showsPower = function(frame) return frame == cell end
ns.Power.Update(cell)
H.checkTrue("rule: power back", cell.power:IsShown())
