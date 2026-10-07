-- Aura blocklists (Core/AuraBlocklist.lua): stored as validated text of
-- spell IDs, typed as IDs or names, at most MAX per list; where the
-- client will apply an entry.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
local B = ns.AuraBlocklist

-- Spell data the client knows beyond the spell book: food buffs (three
-- IDs of one name), a campfire, a never-secret debuff.
M.spells[19705] = { name = "Well Fed" }
M.spells[19706] = { name = "Well Fed" }
M.spells[19709] = { name = "Well Fed" }
M.spells[7353] = { name = "Cozy Fire" }
M.spells[57724] = { name = "Sated" }
M.neverSecretSpells[57724] = true

-- Stored text: IDs separated by commas or spaces, each once, positive.
H.check("parse", table.concat(B.Parse("1, 2,3 4"), ","), "1,2,3,4")
H.check("empty", #B.Parse(""), 0)
H.check("a name is not stored text", B.Parse("Well Fed"), nil)
H.check("zero", B.Parse("0"), nil)
H.check("twice", B.Parse("5, 5"), nil)
H.check("fraction", B.Parse("1.5"), nil)
local many = {}
for i = 1, B.MAX do many[i] = 100000 + i end
H.checkTrue("MAX entries", B.Parse(table.concat(many, ", ")))
many[#many + 1] = 999999
H.check("MAX + 1", B.Parse(table.concat(many, ", ")), nil)
H.checkTrue("the longest list fits the letters", #table.concat(many, ", ", 1, B.MAX) <= B.LETTERS)
H.check("text", B.Text({ 7, 8 }), "7, 8")

-- The set the container takes: spell ID -> true; nil when empty.
H.check("set of nothing", B.Set(""), nil)
local set = B.Set("7, 8")
H.check("set", set[7] and set[8] and not set[9], true)
H.check("merge", B.Merge(B.Set("1"), B.Set("2"))[2], true)
H.check("merge nil", B.Merge(nil, nil), nil)
H.check("merge one", B.Merge(nil, set), set)

-- Typing: IDs the client knows, names to every ID of that name.
local text, added = B.Resolve("19705", "")
H.check("an ID", text, "19705")
H.check("added", #added, 1)
-- A name: the client's own pick for it (no client call lists every ID of
-- a name; the spell book's ranks below).
text = B.Resolve("Well Fed", "")
H.check("a name: the client's ID for it", text, "19705")
text = B.Resolve(" Cozy Fire , 57724", "19705")
H.check("added after the list", text, "19705, 7353, 57724")
text, added = B.Resolve("19705", "19705")
H.check("already there: unchanged", text, "19705")
H.check("... nothing added", #added, 0)
local why, word
text, why, word = B.Resolve("Bogus Buff", "")
H.check("unknown name refused", text, nil)
H.check("... why", why, "UNKNOWN")
H.check("... which", word, "Bogus Buff")
text, why, word = B.Resolve("424242", "")
H.check("unknown ID refused", why, "UNKNOWN")
H.check("... which ID", word, "424242")
text, why = B.Resolve("7353", table.concat(many, ", ", 1, B.MAX))
H.check("full list refused", why, "FULL")
-- A spell book name too (ranks the client data resolves only through the book).
M.known[2050], M.known[2052] = true, true
text = B.Resolve("Lesser Heal", "")
H.checkTrue("spell book ranks", text:find("2050") and text:find("2052"))

-- Add and remove one.
H.check("add", B.Add("1", 2), "1, 2")
local same, reason = B.Add("1, 2", 2)
H.check("add twice", same, nil)
H.check("... why", reason, "TWICE")
H.check("add to a full list", select(2, B.Add(table.concat(many, ", ", 1, B.MAX), 5)), "FULL")
H.check("remove", B.Remove("1, 2, 3", 2), "1, 3")
H.check("remove the last", B.Remove("2", 2), "")

-- Names for the editor.
H.check("name", B.Name(7353), "Cozy Fire")
H.check("no name", B.Name(424242), nil)

-- Where an entry applies: never-secret spells everywhere; others with the
-- client's limits for the list's frames.
H.check("never secret", B.Mark(57724, "group"), nil)
H.check("on your group: buffs only", B.Mark(7353, "group"), "GROUP")
H.check("other frames: buffs on friends, debuffs on enemies", B.Mark(7353, "mixed"), "MIXED")
H.check("account list", B.Mark(7353, "any"), "MIXED")
H.check("context of the player", B.Context("player"), "group")
H.check("context of the party", B.Context("party"), "group")
H.check("context of the pet", B.Context("pet"), "group")
H.check("context of the target", B.Context("target"), "mixed")
H.check("context of the focus", B.Context("focus"), "mixed")
H.check("context of General", B.Context("general"), "any")
H.check("context of a raid size", B.Context("r10"), "group")

-- The settings: an account list in General, one per frame, one per raid size.
local S, RS = ns.Settings, ns.RaidSettings
H.check("account list", S.Get("auraBlockAccount").scope, "general")
H.check("frame list", S.Get("auraBlock").scope, "frame")
H.check("raid list", RS.Get("auraBlock").scope, "frame")
H.check("raid list is behaviour", RS.Get("auraBlock").class, "behaviour")
H.check("empty by default", ns.Config.Get("target", "auraBlock"), "")
H.check("valid text stored", ns.Config.Set("target", "auraBlock", "7353, 19705"), true)
H.check("a name refused by the setting", ns.Config.Set("target", "auraBlock", "Cozy Fire"), false)
H.check("raid", ns.RaidConfig.Set("r20", "auraBlock", "7353"), true)
-- Through an export and back.
local decoded = ns.Codec.Decode(ns.Codec.Encode(ns.Config.Profile()))
H.check("codec", decoded.target.auraBlock, "7353, 19705")
