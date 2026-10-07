-- The buff watch's settings (Raid/Settings.lua), per character: which of
-- your class's buffs are watched, the blessing for each class, when a buff
-- runs out, when the group form is cast, the smart buff key, the watch
-- window and the cells' icon. Codes permanent; the Buffs tab holds them.
local ns = H.LoadAddon()
local RS, Raid, Schema = ns.RaidSettings, ns.Raid, ns.RaidSchema

local function def(key)
    local d = RS.Get(key)
    H.checkTrue("defined: " .. key, d)
    return d or {}
end
local CODES = {
    buffFortitude = "BF", buffSpirit = "BR", buffShadowProtection = "BH", buffIntellect = "BA", buffWild = "BC",
    buffThorns = "BQ", buffBlessings = "BO", buffExpiring = "BE", buffGroupMin = "BN", buffKey = "BK",
    buffWatchShow = "BW", buffWatchOnlyMissing = "BM", buffWatchX = "BX", buffWatchY = "BY", buffCellIcon = "BI",
    buffCellIconPoint = "BP",
    blessingWARRIOR = "ZW", blessingPALADIN = "ZP", blessingPRIEST = "ZR", blessingSHAMAN = "ZC", blessingDRUID = "ZD",
    blessingROGUE = "ZU", blessingMAGE = "ZM", blessingWARLOCK = "ZK", blessingHUNTER = "ZH",
}
for key, code in pairs(CODES) do
    local d = def(key)
    H.check("code of " .. key, d.code, code)
    H.check("per character: " .. key, d.scope, "general")
end
-- Every buff of the table has its switch.
for _, b in ipairs(ns.RaidBuffData.BUFFS) do H.checkTrue("switch of " .. b.id, RS.Get(b.key)) end

H.check("fortitude watched", def("buffFortitude").default, true)
H.check("thorns not (tanks only, on request)", def("buffThorns").default, false)
H.check("shadow protection not", def("buffShadowProtection").default, false)
H.check("blessings watched", def("buffBlessings").default, true)
H.check("warriors: might", def("blessingWARRIOR").default, "MIGHT")
H.check("priests: wisdom", def("blessingPRIEST").default, "WISDOM")
H.check("blessings: the table's list", def("blessingMAGE").values, ns.RaidBuffData.BLESSINGS)
H.check("expiring: 5 minutes", def("buffExpiring").default, 5)
H.check("group form from 3", def("buffGroupMin").default, 3)
H.check("group form: at most a group", def("buffGroupMin").max, 5)
H.check("no key", def("buffKey").default, "")
H.check("a key: stored as the client names it", RS.Validate(def("buffKey"), "CTRL-B"), "CTRL-B")
H.check("a key: not normalised refused", RS.Validate(def("buffKey"), "ctrl-b"), nil)
H.check("watch window on", def("buffWatchShow").default, true)
H.check("only while something is missing: on", def("buffWatchOnlyMissing").default, true)
H.check("the group form's hint: missing or expiring count", ns.L.RAID_HINT_buffGroupMin,
    "Members of one group (blessings: a class) missing it or running out")
H.check("cell icon off", def("buffCellIcon").default, false)
H.check("cell icon point: one of the nine", def("buffCellIconPoint").values, ns.Settings.POINTS)

-- The Buffs tab, before Profile.
local tab, index
for i, t in ipairs(Schema.TABS) do if t.id == "buffs" then tab, index = t, i end end
H.checkTrue("a Buffs tab", tab)
H.check("before Profile", Schema.TABS[index + 1].id, "profile")
local secs = {}
for i, s in ipairs(tab.sections) do secs[i] = s.id end
H.check("its sections", table.concat(secs, ","), "buffsWatched,blessings,buffRules,buffWindow,buffCell")
H.check("tab word", Schema.TabTitle("buffs"), "Buffs")
-- A blessing's row: the client's class name.
H.check("blessing label: the class", Schema.Label("blessingWARLOCK"), "Warlock")
H.check("blessing choice", Schema.EnumText(RS.Get("blessingWARLOCK"), "KINGS"), "Blessing of Kings")
H.check("position words", Schema.Label("buffWatchX"), "Position X")
