-- Click-casting's binding model (Raid/ClickCast.lua): typed values become
-- stored ones (a spell by its name from the spell book, an ID turned into
-- that name), and the bindings become the secure attributes of a cell.
local M = H.M
local ns = H.LoadAddon()
local CC, RC = ns.ClickCast, ns.RaidConfig
ns.Config.Use({})
ns.RaidProfiles.Attach({})

-- Typed values.
M.known[2050], M.known[2052], M.known[2061] = true, true, true
local function typed(kind, text)
    local v, why = CC.TypedValue(kind, text)
    return v == nil and ("refused: " .. tostring(why)) or v
end
H.check("a spell name", typed("spell", "Lesser Heal"), "Lesser Heal")
H.check("the spell book's spelling", typed("spell", "  lesser heal "), "Lesser Heal")
H.check("an ID becomes the name", typed("spell", "2052"), "Lesser Heal")
H.check("an ID of another rank too", typed("spell", "2053"), "Lesser Heal")
H.check("a name not in the book", typed("spell", "Smite"), "refused: Not a spell in your spell book: Smite")
H.check("an unknown ID", typed("spell", "99999"), "refused: Not a spell in your spell book: 99999")
H.check("an empty spell", typed("spell", " "), "")
H.check("an item by name", typed("item", " Major Healing Potion "), "Major Healing Potion")
H.check("an item by ID", typed("item", "13446"), "13446")
H.check("a macro", typed("macro", "/cast [@mouseover] Renew"), "/cast [@mouseover] Renew")
H.check("a long macro", typed("macro", ("x"):rep(256)), "refused: A macro may hold 255 characters.")
-- The spell lookup raising (as the other spell lookups, through pcall):
-- an ID is not known, a name from the book stays as typed; no Lua error.
local getSpellInfo = C_Spell.GetSpellInfo
C_Spell.GetSpellInfo = function() error("lookup refused") end
local ok, v, why = pcall(CC.TypedValue, "spell", "2052")
H.checkTrue("raising lookup: no error", ok)
H.check("raising lookup: an ID refused", v == nil and why, "Not a spell in your spell book: 2052")
H.check("raising lookup: a name kept", select(2, pcall(CC.TypedValue, "spell", "Lesser Heal")), "Lesser Heal")
C_Spell.GetSpellInfo = getSpellInfo

-- Attributes: the plain click as the wildcard, modified ones by prefix.
local function attrs(values)
    local plan = CC.Plan(values)
    local out = {}
    for _, a in ipairs(plan) do if a[2] ~= nil then out[#out + 1] = a[1] .. "=" .. a[2] end end
    table.sort(out)
    return table.concat(out, " ")
end
H.check("the defaults: as the XML", attrs({}), "*type1=target *type2=togglemenu")
H.check("every slot's attributes named", #CC.Plan({}), 40 * 4)
H.check("a spell on shift-left", attrs({ click1Shift = "spell:Flash Heal" }),
    "*type1=target *type2=togglemenu shift-spell1=Flash Heal shift-type1=spell")
H.check("ctrl-shift order", attrs({ click1 = "", click1ShiftCtrl = "focus" }), "*type2=togglemenu ctrl-shift-type1=focus")
H.check("assist on middle", attrs({ click3 = "assist", click2 = "" }), "*type1=target *type3=assist")
H.check("an item by name", attrs({ click1 = "item:Bandage", click2 = "" }), "*item1=Bandage *type1=item")
H.check("an item by ID", attrs({ click1 = "item:13446", click2 = "" }), "*item1=item:13446 *type1=item")
H.check("a macro", attrs({ click1 = "", click2 = "", click4Alt = "macro:/say hi" }),
    "alt-macrotext4=/say hi alt-type4=macro")
H.check("a spell without a name: nothing", attrs({ click1 = "spell:", click2 = "" }), "")
-- Off: what the cells' XML gives.
H.check("off plan", attrs(CC.DefaultValues()), "*type1=target *type2=togglemenu")
-- Bindings as stored.
RC.Set("general", "click5Ctrl", "spell:Lesser Heal")
H.check("stored bindings", CC.Values().click5Ctrl, "spell:Lesser Heal")
H.check("stored default", CC.Values().click1, "target")
