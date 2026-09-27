-- Dispellable debuffs on the party (group "dispels"): their own size and
-- place; while shown, the debuffs group leaves them out ("!RAID"), so none
-- is drawn twice. Party only, off by default.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C, L = ns.Settings, ns.Config, ns.L

-- Settings -----------------------------------------------------------------------
for suffix, code in pairs({ Enabled = "IE", ShowTime = "IT", Anchor = "IA", FramePoint = "IF", Point = "IO",
    X = "IX", Y = "IY", Growth = "IG", RowGrowth = "IR", Size = "IS", Spacing = "ID", PerRow = "IN", Max = "IC" }) do
    local def = S.Get("dispels" .. suffix)
    H.checkTrue("setting dispels" .. suffix, def)
    H.check("code of dispels" .. suffix, def and def.code, code)
    H.checkTrue("dispels" .. suffix .. " on the party", S.AppliesTo(def, "party"))
    H.check("dispels" .. suffix .. " not on the player", S.AppliesTo(def, "player"), false)
    H.check("dispels" .. suffix .. " not on the pets", S.AppliesTo(def, "partypet"), false)
    H.checkTrue("dispels" .. suffix .. " label", L["SETTING_dispels" .. suffix] ~= "SETTING_dispels" .. suffix)
end
for _, suffix in ipairs({ "OnlyMine", "Dispellable", "HidePermanent", "HighlightOwn", "OwnSize" }) do
    H.check("no dispels" .. suffix, S.Get("dispels" .. suffix), nil)
end
C.Use({})
H.check("off by default", C.Get("party", "dispelsEnabled"), false)

-- Options: its own section after the debuffs, on the party page only.
local function sectionIds(scope)
    for _, tab in ipairs(ns.Schema.Tabs(scope)) do
        if tab.id == "auras" then
            local ids = {}
            for _, sec in ipairs(tab.sections) do ids[#ids + 1] = sec.id end
            return table.concat(ids, ",")
        end
    end
end
H.check("party aura sections", sectionIds("party"):match("^[^,]*,[^,]*,[^,]*,[^,]*"), "auraIcons,buffs,debuffs,dispels")

-- Containers ---------------------------------------------------------------------
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.SetGroup({ "party1" })
local b = ns.Party.buttons[1]
H.checkTrue("party: containers", ns.AuraContainers.Ensure(b))
local dc = b.auraContainers.debuffs.container
local xc = b.auraContainers.dispels and b.auraContainers.dispels.container
H.checkTrue("party: a dispels container", xc)
H.check("player: none", ns.Frames.player.auraContainers and ns.Frames.player.auraContainers.dispels, nil)

-- Off: the debuffs show everything, the dispels container is hidden.
H.check("off: debuffs unfiltered", dc._groups.other.filter, "HARMFUL")
H.check("off: hidden", xc:IsShown(), false)

-- On: the dispellable ones move out.
C.Set("party", "dispelsEnabled", true)
H.check("on: debuffs leave them out", dc._groups.other.filter, "HARMFUL|!RAID")
H.check("on: the dispels group has them", xc._groups.other.filter, "HARMFUL|RAID")
H.checkTrue("on: shown", xc:IsShown())
H.check("on: nothing of yours apart", xc._groups.own.enabled, false)
H.checkTrue("on: debuffs still shown", dc:IsShown())

-- Own size and place.
C.Set("party", "dispelsSize", 30)
H.check("own size", xc._groups.other.layout.elementWidth, 30)
H.check("debuffs keep theirs", dc._groups.other.layout.elementWidth, C.Get("party", "debuffsSize"))
local point, rel, relPoint = xc:GetPoint(1)
H.check("centred on the member", point .. relPoint, "CENTERCENTER")
H.check("on the member's block", rel, b.unitBox or b)
C.Set("party", "dispelsAnchor", "OTHER")
_, rel = xc:GetPoint(1)
H.check("OTHER: beside the debuffs", rel, dc)

-- Only dispellable debuffs, and those moved out: the debuffs row is empty.
C.Set("party", "debuffsDispellable", true)
H.check("both: debuffs off", b.auras.debuffs.enabled, false)
H.check("both: container hidden", dc:IsShown(), false)
C.Set("party", "debuffsDispellable", false)

-- Pets and targets derive from the party: no dispels group there.
local pet = { key = "partypet", auras = { dispels = { key = "dispels" } } }
H.check("not on the pets", ns.Auras.DispelsShown(pet), false)
H.check("not on the targets", ns.Auras.DispelsShown({ key = "partytarget" }), false)

C.Set("party", "dispelsEnabled", false)
H.check("off again: debuffs whole", dc._groups.other.filter, "HARMFUL")

-- Test mode: samples on the pretend party while on.
C.Set("party", "dispelsEnabled", true)
M.SetGroup({})
M.units.player = M.units.player or { name = "Me", class = "PRIEST", isPlayer = true, health = 1, healthMax = 1 }
ns.TestMode.Set(true)
M.RunTimers()
local fake = ns.Party.fakes[1]
H.checkTrue("sample icons", fake.auras.dispels.count > 0)
H.check("up to the maximum", fake.auras.dispels.count, C.Get("party", "dispelsMax"))
ns.TestMode.Set(false)
C.Set("party", "dispelsEnabled", false)
