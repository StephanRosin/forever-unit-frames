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

-- Readiness is the book's, not the list's: a book that has only a racial
-- read (the General line) is not the character's whole book.
local function boot(general)
    local n = H.LoadAddon()
    M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
    M.known = {}
    ForeverUnitFramesDB = { raid = { [me] = { general = general } } }
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return n
end
local ns3 = boot({ click1Shift = "spell:renew" })
M.known[28880] = true
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.check("racial only: not normalised", ns3.RaidConfig.Get("general", "click1Shift"), "spell:renew")
H.check("racial only: not remembered", ForeverUnitFramesDB.raidClickSpellsNormalised[me], nil)
M.known[139], M.known[6074] = true, true
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.check("class line read: normalised", ns3.RaidConfig.Get("general", "click1Shift"), "spell:Renew")
H.checkTrue("and remembered", ForeverUnitFramesDB.raidClickSpellsNormalised[me])

-- Nothing to normalise (no spell binding, a rogue say): remembered at
-- once, and the book never read for it again.
local ns4 = boot({ click3 = "assist" })
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.checkTrue("no spell binding: remembered", ForeverUnitFramesDB.raidClickSpellsNormalised[me])
local reads = 0
local friendly = ns4.RaidSpellbook.FriendlySpells
ns4.RaidSpellbook.FriendlySpells = function(...) reads = reads + 1; return friendly(...) end
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.check("done: no rescans", reads, 0)
ns4.RaidSpellbook.FriendlySpells = friendly

-- A refused write leaves it for the next time.
local ns5 = boot({ click1Shift = "spell:renew" })
M.known[139], M.known[6074] = true, true
local setKeys = ns5.RaidConfig.SetKeys
ns5.RaidConfig.SetKeys = function() return false end
M.FireEvent("SPELLS_CHANGED")
M.RunTimers()
H.check("refused: not remembered", ForeverUnitFramesDB.raidClickSpellsNormalised[me], nil)
ns5.RaidConfig.SetKeys = setKeys

-- Also once the login loading screen is gone (the login SPELLS_CHANGED
-- may come before the profile is there).
M.FireEvent("LOADING_SCREEN_DISABLED")
M.RunTimers()
H.check("at the end of the loading screen", ns5.RaidConfig.Get("general", "click1Shift"), "spell:Renew")
H.checkTrue("remembered then", ForeverUnitFramesDB.raidClickSpellsNormalised[me])
