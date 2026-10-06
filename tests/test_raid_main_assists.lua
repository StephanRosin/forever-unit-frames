-- The main assists panel (Raid/SpecialPanels.lua): like the main tanks
-- panel, with the raid's main assist assignment; off by default; both
-- panels side by side, each at its own position.
local M = H.M
local ns = H.LoadAddon()
local RC, RS, Header, Special = ns.RaidConfig, ns.RaidSettings, ns.RaidHeader, ns.RaidSpecialPanels
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

local CODES = { mainAssistsShow = "WS", mainAssistsTitle = "WT", mainAssistsPerLine = "WL",
    mainAssistsGrowth = "WG", mainAssistsX = "WX", mainAssistsY = "WY" }
for key, code in pairs(CODES) do
    local def = RS.Get(key)
    H.check(key .. " code", def and def.code, code)
end
local DEFAULTS = { mainAssistsShow = false, mainAssistsTitle = true, mainAssistsPerLine = 5,
    mainAssistsGrowth = "RIGHT", mainAssistsX = -600, mainAssistsY = 340 }
for key, want in pairs(DEFAULTS) do H.check(key .. " default", RC.Get("r20", key), want) end
H.check("the second panel", ns.Raid.PANELS[2].id, "mainAssists")

Header.Create()
local P, T = Special.panels.mainAssists, Special.panels.mainTanks
local h = P.headers[1]
H.check("anchor", P.anchor:GetName(), "ForeverUnitFramesRaidMainAssists")
H.check("the assignment", h:GetAttribute("roleFilter"), "MAINASSIST")
H.check("off: header hidden", h:IsShown(), false)

local function member(name, subgroup, role)
    return { name = name, class = "PRIEST", subgroup = subgroup, role = role,
        unit = { health = 100, healthMax = 100, powerType = 0 } }
end
M.SetRaidRoster({ member("Tank", 1, "MAINTANK"), member("Assist", 1, "MAINASSIST"), member("Other", 2),
    member("Second", 2, "MAINASSIST") })
M.RunTimers()
H.check("off: nothing shown", P.panel:IsShown(), false)
H.check("off: no cells made", P.Count(1), 0)
RC.Set("r10", "mainAssistsShow", true)
M.RunTimers()
H.checkTrue("on: shown", P.panel:IsShown() and h:IsShown())
H.check("the main assists", h:GetAttribute("child1").unit .. "," .. h:GetAttribute("child2").unit, "raid2,raid4")
H.check("the main tank in his panel", T.Count(1), 1)
H.check("title", P.decor[1].title:GetText(), "Main assists")
H.check("its own position", select(5, P.anchor.mover:GetPoint(1)), 340)
H.check("the main tanks' position", select(5, T.anchor.mover:GetPoint(1)), 260)
H.check("mover label", P.anchor.mover.label:GetText(), "Main assists 10")
RC.Set("r10", "mainAssistsY", 300)
H.check("moved", select(5, P.anchor.mover:GetPoint(1)), 300)
H.check("the main tanks stay", select(5, T.anchor.mover:GetPoint(1)), 260)

-- The Panels tab: main tanks, then main assists.
local tab = ns.RaidSchema.TABS[3]
H.check("its section", tab.sections[2].id, "mainAssists")
H.check("its keys", table.concat(tab.sections[2].keys, ","),
    "mainAssistsShow,mainAssistsTitle,mainAssistsPerLine,mainAssistsGrowth,mainAssistsX,mainAssistsY")
H.check("section title", ns.RaidSchema.SectionTitle("mainAssists"), "Main assists")
H.check("shared words", ns.RaidSchema.Label("mainAssistsTitle"), "Title above it")
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
