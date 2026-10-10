-- Click-casting spells stored before the dropdowns (Raid/ClickCast.lua):
-- once per character, when the spell book is read after login and out of
-- combat, every spell binding (mouse slots and keys) is written as the
-- list has it: a name as the spell book spells it (Max), a spell ID of a
-- learned rank as that ID, the highest rank's ID as the name (Max);
-- anything else stays as typed. Copying another character's bindings
-- does the same.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
for _, id in ipairs({ 139, 6074, 2061, 585, 588 }) do M.known[id] = true end
local me = ns.RaidProfiles.CharKey()
ForeverUnitFramesDB = { raid = {
    [me] = { general = {
        click1Shift = "spell:renew",           -- another case
        click1Ctrl = "spell:Flash Heal",       -- as the book writes it
        click1Alt = "spell:6074",              -- the highest rank's ID
        click2Shift = "spell:139",             -- a lower rank's ID
        click2Ctrl = "spell:Mind Blast",       -- not learned
        click2Alt = "spell:Smite",             -- not helpful
        click3 = "spell:585",                  -- not helpful, by ID
        click4 = "spell:Inner Fire",           -- self only
        click5 = "macro:/cast Renew",          -- no spell binding
        clickKey1Bind = "spell:RENEW",         -- a key's
        clickKey2Bind = "spell:99999",         -- an unknown ID
    } },
    ["Alt-Realm"] = { general = { click1 = "spell:139", click2 = "spell:renew", click3 = "spell:6074" } },
} }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC = ns.RaidConfig
local function get(key) return RC.Get("general", key) end

H.check("not before the spell book is read", get("click1Shift"), "spell:renew")
-- The book read in combat: after it.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.check("not in combat", get("click1Shift"), "spell:renew")
M.SetCombat(false)
M.RunTimers()
H.check("a name in another case: the book's", get("click1Shift"), "spell:Renew")
H.check("a name as written stays", get("click1Ctrl"), "spell:Flash Heal")
H.check("the highest rank's ID: the name", get("click1Alt"), "spell:Renew")
H.check("a lower rank's ID: kept (a fixed rank)", get("click2Shift"), "spell:139")
H.check("not learned: as typed", get("click2Ctrl"), "spell:Mind Blast")
H.check("not helpful: as typed", get("click2Alt"), "spell:Smite")
H.check("not helpful by ID: as typed", get("click3"), "spell:585")
H.check("self only: as typed", get("click4"), "spell:Inner Fire")
H.check("a macro untouched", get("click5"), "macro:/cast Renew")
H.check("a key's spell", get("clickKey1Bind"), "spell:Renew")
H.check("an unknown ID: as typed", get("clickKey2Bind"), "spell:99999")
H.checkTrue("remembered for the character", ForeverUnitFramesDB.raidClickSpellsNormalised[me])

-- Once only: a value set later in another case stays as it is.
RC.Set("general", "click1Shift", "spell:renew")
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.check("once only", get("click1Shift"), "spell:renew")

-- Copy from another character: the same normalisation.
ns.RaidProfiles.CopyClickCast("Alt-Realm")
H.check("copied: a lower rank kept", get("click1"), "spell:139")
H.check("copied: a name in the book's case", get("click2"), "spell:Renew")
H.check("copied: the highest rank by name", get("click3"), "spell:Renew")
H.check("nothing blocked", #M.blocked, 0)

-- Another character whose spell book reads empty at first: nothing
-- normalised and nothing remembered until it has spells.
local ns2 = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.known = {}
ForeverUnitFramesDB = { raid = { [me] = { general = { click1Shift = "spell:renew" } } } }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.check("empty book: not remembered", (ForeverUnitFramesDB.raidClickSpellsNormalised or {})[me], nil)
M.known[139], M.known[6074] = true, true
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.check("then normalised", ns2.RaidConfig.Get("general", "click1Shift"), "spell:Renew")
