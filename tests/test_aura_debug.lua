local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})

-- Client calls the mock does not have; the debug command must also work
-- without them (checked first).
local function run()
    M.chat = {}
    local ok, err = pcall(SlashCmdList.FOREVERUNITFRAMES, "auradebug")
    return ok, err, table.concat(M.chat, "\n")
end

local ok, err, out = run()
H.check("runs without the optional calls", ok, true)
if not ok then print("  " .. tostring(err)) end
H.checkTrue("says they are missing", out:find("ShouldAurasBeSecret=missing", 1, true))
H.checkTrue("absent unit", out:find("party1: no unit", 1, true))

M.secretAuras = false
_G.C_Secrets = { ShouldAurasBeSecret = function() return M.secretAuras end }
_G.Enum.AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 }
_G.C_RestrictedActions = { IsAddOnRestrictionActive = function(t) return t == 0 and M.combat end }
C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter)
    return C_UnitAuras.GetUnitAuras(unit, filter)[i]
end

-- Readable.
M.units.party1 = { auras = { { auraInstanceID = 5, icon = 1, duration = 10, expirationTime = 1010, isHelpful = true } } }
M.SetGroup({ "party1" })
M.FireEvent("UNIT_AURA", "party1", { addedAuras = { M.units.party1.auras[1] } })
ok, err, out = run()
H.check("readable: runs", ok, true)
if not ok then print("  " .. tostring(err)) end
H.checkTrue("readable: list", out:find("party1: GetUnitAuras ok, 1 entries; first: auraInstanceID=plain icon=plain duration=plain", 1, true))
H.checkTrue("readable: by index", out:find("party1: GetAuraDataByIndex ok, auraInstanceID=plain", 1, true))
H.checkTrue("readable: event counted", out:find("party1: UNIT_AURA 1 (info secret 0, with added aura 1", 1, true))
H.checkTrue("restrictions listed", out:find("Combat=no", 1, true))

-- Secret fields, secret event payload, in combat.
M.combat = true
M.secretAuras = true
M.units.party1.auras = { { auraInstanceID = M.Secret(6), icon = M.Secret(2), duration = M.Secret(10),
    expirationTime = M.Secret(1010), isHelpful = true } }
M.FireEvent("UNIT_AURA", "party1", M.Secret({ addedAuras = {} }))
M.FireEvent("UNIT_AURA", "party1", { addedAuras = { M.units.party1.auras[1] } })
M.FireEvent("UNIT_AURA", "party1", { addedAuras = M.Secret({}) })
ok, err, out = run()
H.check("secret: runs", ok, true)
if not ok then print("  " .. tostring(err)) end
H.checkTrue("secret: combat", out:find("combat=yes", 1, true))
H.checkTrue("secret: fields", out:find("first: auraInstanceID=secret icon=secret duration=secret", 1, true))
H.checkTrue("secret: events", out:find("UNIT_AURA 3 (info secret 1, with added aura 2, last added: list secret)", 1, true))
H.checkTrue("counters reset", select(3, run()):find("party1: UNIT_AURA 0 ", 1, true))

-- Refused.
M.auraError = true
ok, err, out = run()
H.check("refused: runs", ok, true)
if not ok then print("  " .. tostring(err)) end
H.checkTrue("refused: error text", out:find("party1: GetUnitAuras error: ", 1, true))
H.checkTrue("refused: by index", out:find("party1: GetAuraDataByIndex error: ", 1, true))
M.auraError = false

-- Other commands still reach the regular handler.
M.chat = {}
SlashCmdList.FOREVERUNITFRAMES("help")
H.check("help still works", M.chat[1] and M.chat[1]:find(ns.L.HELP, 1, true) ~= nil, true)
