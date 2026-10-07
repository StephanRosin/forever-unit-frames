-- Your own auras placed freely (buffs and debuffs with "mine first"):
-- OwnPlacement WITH (default: yours in rows before the rest, as before)
-- or FREE: yours in a block of their own, anchored to the frame by their
-- own points, offsets, growth and icons per row; the rest keep the group's
-- place and no longer leave room for them. The client still tells yours
-- apart (filters PLAYER / !PLAYER).
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C, Codec = ns.Settings, ns.Config, ns.Codec

-- Settings ---------------------------------------------------------------------
local PARTS = { "OwnPlacement", "OwnFramePoint", "OwnPoint", "OwnX", "OwnY", "OwnGrowth", "OwnRowGrowth",
    "OwnPerRow" }
local CODES = {
    buffs = { "OP", "OE", "OT", "OH", "OU", "OG", "OW", "ON" },
    debuffs = { "ZP", "ZE", "ZT", "ZH", "ZU", "ZG", "ZW", "ZN" },
}
-- Same choices and ranges as the group's own placement.
local LIKE = { OwnFramePoint = "FramePoint", OwnPoint = "Point", OwnX = "X", OwnY = "Y", OwnGrowth = "Growth",
    OwnRowGrowth = "RowGrowth", OwnPerRow = "PerRow" }
local function same(a, b)
    if a.type ~= b.type or a.min ~= b.min or a.max ~= b.max or a.zeroText ~= b.zeroText then return false end
    return table.concat(a.values or {}, ",") == table.concat(b.values or {}, ",")
end
for _, g in ipairs({ "buffs", "debuffs" }) do
    for i, part in ipairs(PARTS) do
        local def = S.Get(g .. part)
        H.checkTrue(g .. part .. " defined", def)
        if def then
            H.check(g .. part .. " code", def.code, CODES[g][i])
            H.check(g .. part .. " per frame", def.scope, "frame")
            if LIKE[part] then H.checkTrue(g .. part .. " like " .. LIKE[part], same(def, S.Get(g .. LIKE[part]))) end
            H.checkTrue(g .. part .. " labelled", ns.L["SETTING_" .. g .. part] ~= "SETTING_" .. g .. part)
        end
    end
    local placement = S.Get(g .. "OwnPlacement")
    H.check(g .. " placement choices", table.concat(placement.values, ","), "WITH,FREE")
    for _, scope in ipairs({ "player", "target", "targettarget", "pet", "focus", "party" }) do
        H.check(g .. " with the others on " .. scope, C.Get(scope, g .. "OwnPlacement"), "WITH")
    end
    H.checkTrue(g .. " choice labels", ns.L["ENUM_" .. g .. "OwnPlacement_FREE"] ~= nil
        and ns.L["ENUM_" .. g .. "OwnPlacement_WITH"] ~= nil)
end
for _, part in ipairs(PARTS) do H.check("no dispels " .. part, S.Get("dispels" .. part), nil) end
-- Defaults beside the frame: the debuffs at its top, the buffs at its
-- bottom; right of it, on the party left (the rest sits right of the
-- members).
H.check("target debuffs: right, top", C.Get("target", "debuffsOwnFramePoint") .. ">" .. C.Get("target",
    "debuffsOwnPoint"), "TOPRIGHT>TOPLEFT")
H.check("target buffs: right, bottom", C.Get("target", "buffsOwnFramePoint") .. ">" .. C.Get("target",
    "buffsOwnPoint"), "BOTTOMRIGHT>BOTTOMLEFT")
H.check("party debuffs: left, top", C.Get("party", "debuffsOwnFramePoint") .. ">" .. C.Get("party",
    "debuffsOwnPoint"), "TOPLEFT>TOPRIGHT")
H.check("party grows left", C.Get("party", "debuffsOwnGrowth"), "LEFT")
H.check("target grows right", C.Get("target", "debuffsOwnGrowth"), "RIGHT")
H.check("buffs' rows up", C.Get("target", "buffsOwnRowGrowth"), "UP")
H.check("debuffs' rows down", C.Get("target", "debuffsOwnRowGrowth"), "DOWN")
H.check("x", C.Get("target", "debuffsOwnX") .. "," .. C.Get("party", "debuffsOwnX"), "4,-4")
H.check("per row Auto", C.Get("target", "debuffsOwnPerRow"), 0)

-- Codec: round trip, nothing written while at the defaults.
H.check("defaults: nothing written", Codec.Encode(C.Profile()), "1")
C.Set("party", "debuffsOwnPlacement", "FREE")
C.Set("party", "debuffsOwnX", -10)
C.Set("target", "buffsOwnPerRow", 3)
local back = Codec.Decode(Codec.Encode(C.Profile()))
H.check("decoded placement", back.party.debuffsOwnPlacement, "FREE")
H.check("decoded x", back.party.debuffsOwnX, -10)
H.check("decoded per row", back.target.buffsOwnPerRow, 3)
C.ResetAll()

-- Options: the rows follow "mine in the same rows" in each aura section;
-- greyed unless "mine first" is on and the place is Free; "mine in the
-- same rows" greys while Free.
local tab = ns.Schema.Tabs("target")[4]
for n, g in ipairs({ "buffs", "debuffs" }) do
    local keys = table.concat(tab.sections[n + 1].keys, ",")
    local want = {}
    for i, part in ipairs(PARTS) do want[i] = g .. part end
    H.checkTrue(g .. ": rows after 'same rows'", keys:find(g .. "OwnSameRow," .. table.concat(want, ","), 1, true))
end
local ACTIVE = ns.Options.ROW_ACTIVE
local function active(key) return ACTIVE[key]("party") end
C.Set("party", "debuffsHighlightOwn", false)
H.check("mine first off: place greyed", active("debuffsOwnPlacement"), false)
H.check("mine first off: x greyed", active("debuffsOwnX"), false)
C.Set("party", "debuffsHighlightOwn", true)
H.check("with the rest: place active", active("debuffsOwnPlacement"), true)
H.check("with the rest: x greyed", active("debuffsOwnX"), false)
H.check("with the rest: same rows active", active("debuffsOwnSameRow"), true)
C.Set("party", "debuffsOwnPlacement", "FREE")
for _, part in ipairs(PARTS) do H.check("free: " .. part .. " active", active("debuffs" .. part), true) end
H.check("free: same rows greyed", active("debuffsOwnSameRow"), false)
H.check("free: the buffs' rows untouched", active("buffsOwnX"), false)
C.Set("party", "debuffsHighlightOwn", false)
H.check("free, mine first off: x greyed", active("debuffsOwnX"), false)
C.ResetAll()
H.check("no error", #M.errors, 0)
