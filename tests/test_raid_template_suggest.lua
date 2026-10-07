-- What the raid templates suggest (Raid/TemplateData.lua): a role
-- template from the specialization's role, else the assigned role, else
-- the class (secret answers skipped); click-casting suggestions for
-- healers and dispellers, from the spell book, set only when applied.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = {}
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local T, RC = ns.RaidTemplates, ns.RaidConfig

-- The class when nothing else says.
for class, want in pairs({ PRIEST = "healer", DRUID = "healer", PALADIN = "healer", SHAMAN = "healer",
    WARRIOR = "tank", MAGE = "dps", ROGUE = "dps", WARLOCK = "dps", HUNTER = "dps" }) do
    M.units.player.class = class
    H.check("class " .. class, T.SuggestRole(), want)
end
M.units.player.class = "PRIEST"
-- The assigned role wins over the class.
M.units.player.role = "DAMAGER"
H.check("assigned role", T.SuggestRole(), "dps")
-- The specialization's role wins over both.
M.specIndex, M.specs = 2, { [2] = { id = 258, name = "Shadow", role = "TANK" } }
H.check("spec role", T.SuggestRole(), "tank")
-- Secret answers count as none.
M.specSecret = true
H.check("secret spec role: the assigned role", T.SuggestRole(), "dps")
M.units.player.role = M.Secret("TANK")
H.check("secret assigned role: the class", T.SuggestRole(), "healer")
M.specSecret, M.specIndex, M.units.player.role = false, 0, nil
-- An unknown class: DPS.
M.units.player.class = M.Secret("PRIEST")
H.check("secret class", T.SuggestRole(), "dps")
M.units.player.class = "PRIEST"

-- Click-casting suggestions: a healer priest who knows Flash Heal, Renew
-- and Dispel Magic gets those (the rest is unknown and left out).
M.known[2061], M.known[139], M.known[6074], M.known[527] = true, true, true, true
local list = T.ClickSuggestions("healer", "PRIEST")
local function describe(l)
    local out = {}
    for i, s in ipairs(l) do out[i] = s.key .. "=" .. s.binding end
    return table.concat(out, ",")
end
H.check("healer priest", describe(list), "click1Shift=spell:Flash Heal,click1Ctrl=spell:Renew,"
    .. "click2Ctrl=spell:Dispel Magic")
-- Dispel only: plain left casts the dispel; the rest of the dispels too.
M.known[552] = true
H.check("dispel priest", describe(T.ClickSuggestions("dispel", "PRIEST")),
    "click1=spell:Dispel Magic,click2Ctrl=spell:Dispel Magic,click2Alt=spell:Abolish Disease")
-- Tanks and DPS: nothing; a class without heals or dispels: nothing.
H.check("tank: none", #T.ClickSuggestions("tank", "PRIEST"), 0)
H.check("dps: none", #T.ClickSuggestions("dps", "PRIEST"), 0)
H.check("warrior dispel: none", #T.ClickSuggestions("dispel", "WARRIOR"), 0)
-- A mage dispels a curse.
M.known[475] = true
H.check("dispel mage", describe(T.ClickSuggestions("dispel", "MAGE")),
    "click1=spell:Remove Lesser Curse,click2Ctrl=spell:Remove Lesser Curse")

-- Nothing is bound until the suggestions are applied.
H.check("not bound by suggesting", RC.Get("general", "click1Shift"), "")
local changes = T.ClickChanges(list)
H.checkTrue("applied", T.ApplyChanges(changes))
H.check("bound", RC.Get("general", "click1Shift"), "spell:Flash Heal")
H.check("left click still targets", RC.Get("general", "click1"), "target")
H.check("right click still the menu", RC.Get("general", "click2"), "menu")
T.Undo()
H.check("undone", RC.Get("general", "click1Shift"), "")
-- Every suggestion of every class and role is a binding its slot takes.
for id in pairs(M.spells) do M.known[id] = true end
for _, class in ipairs(ns.RaidBuffData.CLASSES) do
    for _, role in ipairs(T.ROLES) do
        for _, s in ipairs(T.ClickSuggestions(role.id, class)) do
            H.checkTrue(class .. " " .. role.id .. " " .. s.key, T.Valid(s.key, s.binding))
        end
    end
end
