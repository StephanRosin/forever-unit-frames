-- Own auras first and bigger; "per row" Auto (wrap by frame size).
local M = H.M
local ns = H.LoadAddon()
-- The addon's own reads: the fallback for clients without aura containers.
M.auraContainerMissing = true
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C, Codec, L, Layout, Schema, Auras = ns.Settings, ns.Config, ns.Codec, ns.L, ns.Layout, ns.Schema, ns.Auras

-- Settings ---------------------------------------------------------------------
local FRAMES = { "player", "target", "targettarget", "pet", "focus", "party" }
for _, group in ipairs({ { "buffs", "J" }, { "debuffs", "D" } }) do
    local g, letter = group[1], group[2]
    local hl, own = S.Get(g .. "HighlightOwn"), S.Get(g .. "OwnSize")
    H.checkTrue(g .. "HighlightOwn defined", hl)
    H.checkTrue(g .. "OwnSize defined", own)
    if hl and own then
        H.check(g .. " highlight code", hl.code, letter .. "H")
        H.check(g .. " own size code", own.code, letter .. "B")
        H.check(g .. " highlight type", hl.type, "bool")
        H.check(g .. " own size range", own.min .. "-" .. own.max, "10-64")
        for _, scope in ipairs(FRAMES) do
            H.checkTrue(hl.key .. " applies to " .. scope, S.AppliesTo(hl, scope))
            H.checkTrue(own.key .. " applies to " .. scope, S.AppliesTo(own, scope))
            -- 1.3 x the icon size, rounded.
            H.check(own.key .. " default on " .. scope, C.Get(scope, own.key),
                math.floor(C.Get(scope, g .. "Size") * 1.3 + 0.5))
            -- Per row: Auto (0) everywhere by default.
            H.check(g .. "PerRow auto on " .. scope, C.Get(scope, g .. "PerRow"), 0)
        end
    end
    H.check(g .. "PerRow code kept", S.Get(g .. "PerRow").code, letter .. "N")
    H.check(g .. "PerRow range starts at 0 (Auto)", S.Get(g .. "PerRow").min, 0)
    H.check(g .. "PerRow max", S.Get(g .. "PerRow").max, 40)
end
H.check("target own debuffs highlighted", C.Get("target", "debuffsHighlightOwn"), true)
H.check("focus own debuffs highlighted", C.Get("focus", "debuffsHighlightOwn"), true)
H.check("target buffs not", C.Get("target", "buffsHighlightOwn"), false)
H.check("player debuffs not", C.Get("player", "debuffsHighlightOwn"), false)
H.check("party debuffs not", C.Get("party", "debuffsHighlightOwn"), false)
H.check("target own size", C.Get("target", "debuffsOwnSize"), 26)
H.check("party own size", C.Get("party", "debuffsOwnSize"), 23)
H.check("pet own size", C.Get("pet", "debuffsOwnSize"), 21)
H.check("own size clamp", S.Validate(S.Get("debuffsOwnSize"), 5), 10)
H.check("per row 0 stays", S.Validate(S.Get("debuffsPerRow"), 0), 0)
H.check("per row negative -> 0", S.Validate(S.Get("debuffsPerRow"), -3), 0)

-- Codec: compact, round trip.
C.Set("target", "debuffsHighlightOwn", false)
C.Set("party", "buffsHighlightOwn", true)
C.Set("target", "debuffsOwnSize", 40)
C.Set("focus", "debuffsPerRow", 5)
local s = Codec.Encode(C.Profile())
H.check("encoded", s, "1;tDB40;tDH0;fDN5;yJH1")
local back = Codec.Decode(s)
H.check("decoded highlight off", back.target.debuffsHighlightOwn, false)
H.check("decoded own size", back.target.debuffsOwnSize, 40)
H.check("decoded party buffs highlight", back.party.buffsHighlightOwn, true)
H.check("decoded fixed per row", back.focus.debuffsPerRow, 5)
C.ResetAll()

-- Options: two rows in each aura section, per row shows Auto for 0.
local tab = Schema.Tabs("target")[4]
local function hasKey(section, key)
    for _, k in ipairs(section.keys) do if k == key then return true end end
    return false
end
H.checkTrue("buffs section: highlight own", hasKey(tab.sections[1], "buffsHighlightOwn"))
H.checkTrue("buffs section: own size", hasKey(tab.sections[1], "buffsOwnSize"))
H.checkTrue("debuffs section: highlight own", hasKey(tab.sections[2], "debuffsHighlightOwn"))
H.checkTrue("debuffs section: own size", hasKey(tab.sections[2], "debuffsOwnSize"))
H.check("label highlight", L.SETTING_debuffsHighlightOwn, "Mine first")
H.check("label own size", L.SETTING_buffsOwnSize, "Size of mine")
H.check("auto label", L.AUTO, "Auto")
H.check("per row says Auto at 0", S.Get("buffsPerRow").zeroText, "AUTO")

local W = ns.Widgets
local perRow = 0
local row = W.Slider(CreateFrame("Frame", nil, UIParent), { label = "x", min = 0, max = 40, step = 1,
    zeroText = L.AUTO, get = function() return perRow end, set = function(v) perRow = v; return true end })
row:Refresh()
H.check("slider box shows Auto", row.edit:GetText(), "Auto")
row.edit:SetText("6")
row.edit:GetScript("OnEnterPressed")(row.edit)
H.check("typed a number", perRow, 6)
H.check("box shows the number", row.edit:GetText(), "6")
row.edit:SetText("auto")
row.edit:GetScript("OnEnterPressed")(row.edit)
H.check("typed auto", perRow, 0)
H.check("box shows Auto again", row.edit:GetText(), "Auto")
row.slider:GetScript("OnValueChanged")(row.slider, 3, true)
H.check("dragged", perRow, 3)
row.slider:GetScript("OnValueChanged")(row.slider, 0.2, true)
H.check("dragged to 0", perRow, 0)
H.check("drag to 0 shows Auto", row.edit:GetText(), "Auto")
-- Focus lost with "Auto" in the box: nothing to commit, nothing flashes.
local sets = 0
local quiet = W.Slider(CreateFrame("Frame", nil, UIParent), { label = "q", min = 0, max = 40, step = 1,
    zeroText = L.AUTO, get = function() return 0 end, set = function() sets = sets + 1; return true end })
quiet:Refresh()
quiet.edit:GetScript("OnEditFocusLost")(quiet.edit)
H.check("focus lost on Auto: no set", sets, 0)

-- Layout maths ----------------------------------------------------------------
H.check("fixed per row", Layout.AuraPerRow(4, 220, 20, 2), 4)
H.check("auto: 220 wide, 20 + 2", Layout.AuraPerRow(0, 220, 20, 2), 10)
H.check("auto: 217 wide", Layout.AuraPerRow(0, 217, 20, 2), 9)
H.check("auto: own size 26", Layout.AuraPerRow(0, 220, 26, 2), 7)
H.check("auto: 160 wide, 18 + 0", Layout.AuraPerRow(0, 160, 18, 0), 8)
H.check("auto: 160 wide, 18 + 4", Layout.AuraPerRow(0, 160, 18, 4), 7)
H.check("auto: narrower than one icon", Layout.AuraPerRow(0, 10, 20, 2), 1)

-- shape: own icons 26, per row 3; others 20, per row 4; spacing 2.
local shape = { size = 20, ownSize = 26, spacing = 2, perRow = 4, ownPerRow = 3 }
local function at(i, own, primary, row)
    shape.primary, shape.row = primary, row
    local x, y, size = Layout.AuraPlace(shape, i, own)
    return x .. "," .. y .. " " .. size
end
local function block(own, count, primary, row)
    shape.primary, shape.row = primary, row
    local w, h = Layout.AuraBlock(shape, own, count)
    return w .. "x" .. h
end
-- Without own icons: exactly the plain layout.
for _, dirs in ipairs({ { "RIGHT", "DOWN" }, { "LEFT", "UP" }, { "UP", "RIGHT" }, { "DOWN", "LEFT" } }) do
    for i = 1, 9 do
        local x, y = Layout.AuraOffset(i, 4, 22, dirs[1], dirs[2])
        H.check("no own " .. dirs[1] .. "/" .. dirs[2] .. " #" .. i, at(i, 0, dirs[1], dirs[2]), x .. "," .. y .. " 20")
    end
    local w, h = Layout.AuraExtent(9, 4, 20, 2, dirs[1])
    H.check("no own block " .. dirs[1], block(0, 9, dirs[1], dirs[2]), w .. "x" .. h)
end
-- 4 own (two rows of 3 + 1), then 5 others (rows of 4), for every growth
-- and row direction. Own step 28, own rows 26 + 2 + 26 = 54, others start
-- 56 across; others step 22.
local CASES = {
    { "RIGHT", "DOWN", { "0,0", "28,0", "56,0", "0,-28", "0,-56", "22,-56", "66,-56", "0,-78" }, "86x98" },
    { "RIGHT", "UP", { "0,0", "28,0", "56,0", "0,28", "0,56", "22,56", "66,56", "0,78" }, "86x98" },
    { "LEFT", "DOWN", { "0,0", "-28,0", "-56,0", "0,-28", "0,-56", "-22,-56", "-66,-56", "0,-78" }, "86x98" },
    { "LEFT", "UP", { "0,0", "-28,0", "-56,0", "0,28", "0,56", "-22,56", "-66,56", "0,78" }, "86x98" },
    { "UP", "RIGHT", { "0,0", "0,28", "0,56", "28,0", "56,0", "56,22", "56,66", "78,0" }, "98x86" },
    { "UP", "LEFT", { "0,0", "0,28", "0,56", "-28,0", "-56,0", "-56,22", "-56,66", "-78,0" }, "98x86" },
    { "DOWN", "RIGHT", { "0,0", "0,-28", "0,-56", "28,0", "56,0", "56,-22", "56,-66", "78,0" }, "98x86" },
    { "DOWN", "LEFT", { "0,0", "0,-28", "0,-56", "-28,0", "-56,0", "-56,-22", "-56,-66", "-78,0" }, "98x86" },
}
local INDEX = { 1, 2, 3, 4, 5, 6, 8, 9 }
for _, case in ipairs(CASES) do
    local label = case[1] .. "/" .. case[2]
    for n, i in ipairs(INDEX) do
        H.check(label .. " #" .. i, at(i, 4, case[1], case[2]), case[3][n] .. (i <= 4 and " 26" or " 20"))
    end
    H.check(label .. " block", block(4, 9, case[1], case[2]), case[4])
end
H.check("bad row direction falls back", at(5, 4, "RIGHT", "LEFT"), "0,-56 20")
H.check("only own icons", block(4, 4, "RIGHT", "DOWN"), "82x54")
H.check("one own icon", block(1, 1, "RIGHT", "DOWN"), "26x26")
H.check("one own, one other", block(1, 2, "RIGHT", "DOWN"), "26x48")
H.check("own row narrower than others", block(1, 5, "RIGHT", "DOWN"), "86x48")
H.check("nothing", block(0, 0, "RIGHT", "DOWN"), "0x0")
-- Per-row limits hold per size class.
shape.ownPerRow, shape.perRow = 1, 2
H.check("own per row 1: second own below", at(2, 2, "RIGHT", "DOWN"), "0,-28 26")
H.check("others per row 2: third other wraps", at(5, 2, "RIGHT", "DOWN"), "0,-78 20")
H.check("limits: block", block(2, 5, "RIGHT", "DOWN"), "42x98")

-- On the frames ----------------------------------------------------------------
local function aura(id, fields)
    local a = { auraInstanceID = id, icon = 100 + id, applications = 0, duration = 0, expirationTime = 0 }
    for k, v in pairs(fields or {}) do a[k] = v end
    return a
end
local list = {
    aura(1, { dispelName = "Magic" }),
    aura(2, { mine = true }),
    aura(3, { dispelName = "Curse" }),
    aura(4, { mine = true }),
    -- The client knows it is not mine; the field is secret to us.
    aura(5, { isFromPlayerOrPlayerPet = M.Secret(true) }),
    aura(6, { isHelpful = true, mine = true }),
}
M.units.player = { name = "Me", health = 5, healthMax = 10 }
M.units.target = { name = "Foe", health = 5, healthMax = 10, auras = list }
local t = ns.Frames.target
local debuffs, buffs = t.auras.debuffs, t.auras.buffs
local function offset(b)
    local p, _, rp, bx, by = b:GetPoint(1)
    return p .. ">" .. rp .. " " .. bx .. "," .. by
end
local function icons(group)
    local out = {}
    for i = 1, group.count do out[i] = tostring(group.buttons[i].icon._texture) end
    return table.concat(out, ",")
end
local function counted(fn)
    local q, l = M.auraQueries, M.auraLookups
    fn()
    return (M.auraQueries - q) .. " lists, " .. (M.auraLookups - l) .. " lookups"
end

H.check("new target: two lists for the debuffs, one for the buffs", counted(function()
    M.FireEvent("PLAYER_TARGET_CHANGED")
end), "3 lists, 0 lookups")
H.check("mine first", icons(debuffs), "102,104,101,103,105")
H.check("own count", debuffs.own, 2)
H.check("own icon bigger", debuffs.buttons[1]:GetWidth(), 26)
H.check("second own bigger", debuffs.buttons[2]:GetWidth(), 26)
H.check("others normal", debuffs.buttons[3]:GetWidth(), 20)
H.check("secret ownership: other", debuffs.buttons[5]:GetWidth(), 20)
-- Rows up from the bottom left; auto per row: 10 of 20, 7 of 26.
H.check("perRow auto", debuffs.perRow, 10)
H.check("ownPerRow auto", debuffs.ownPerRow, 7)
H.check("first own", offset(debuffs.buttons[1]), "BOTTOMLEFT>BOTTOMLEFT 0,0")
H.check("second own", offset(debuffs.buttons[2]), "BOTTOMLEFT>BOTTOMLEFT 28,0")
H.check("others: a new row above", offset(debuffs.buttons[3]), "BOTTOMLEFT>BOTTOMLEFT 0,28")
H.check("others: step 22", offset(debuffs.buttons[4]), "BOTTOMLEFT>BOTTOMLEFT 22,28")
H.check("holder width", debuffs.holder:GetWidth(), 64)
H.check("holder height", debuffs.holder:GetHeight(), 48)
H.check("buffs not highlighted", buffs.own, 0)
H.check("buffs normal size", buffs.buttons[1]:GetWidth(), 20)
H.check("own list filter", M.auraQueryLog[#M.auraQueryLog - 1], "HARMFUL|PLAYER")
H.check("other list filter", M.auraQueryLog[#M.auraQueryLog], "HARMFUL|!PLAYER")

-- The maximum counts all icons: own ones first.
C.Set("target", "debuffsMax", 3)
H.check("max 3", icons(debuffs), "102,104,101")
C.Set("target", "debuffsMax", 1)
H.check("max 1: only one own", icons(debuffs), "102")
H.check("max 1: no list for others", M.lastAuraQuery.filter, "HARMFUL|PLAYER")
C.ResetScope("target")
H.check("back", icons(debuffs), "102,104,101,103,105")

-- Only mine and highlighted: one list, all big.
C.Set("target", "debuffsOnlyMine", true)
H.check("only mine: one list", counted(function()
    M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
end), "2 lists, 0 lookups")
H.check("only mine: own", icons(debuffs), "102,104")
H.check("only mine: all big", debuffs.buttons[2]:GetWidth(), 26)
C.ResetScope("target")

-- Highlight off: one list, one size, the client's order.
C.Set("target", "debuffsHighlightOwn", false)
H.check("off: client order", icons(debuffs), "101,102,103,104,105")
H.check("off: own 0", debuffs.own, 0)
H.check("off: same size", debuffs.buttons[1]:GetWidth(), 20)
H.check("off: laid out plainly", offset(debuffs.buttons[2]), "BOTTOMLEFT>BOTTOMLEFT 22,0")
C.ResetScope("target")
H.check("on again", debuffs.buttons[1]:GetWidth(), 26)

-- A refused list keeps the group as it was (same unit), both lists or none.
M.auraError = true
M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
H.check("refused: kept", icons(debuffs), "102,104,101,103,105")
M.auraError = false
local realGet = C_UnitAuras.GetUnitAuras
C_UnitAuras.GetUnitAuras = function(unit, filter, ...)
    if filter:find("!PLAYER", 1, true) then error("refused") end
    return realGet(unit, filter, ...)
end
list[7] = aura(7, { mine = true })
M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
H.check("second list refused: kept whole", icons(debuffs), "102,104,101,103,105")
C_UnitAuras.GetUnitAuras = realGet
table.remove(list, 7)

-- Incremental: an own aura added or removed lays the group out again.
list[7] = aura(7, { mine = true })
H.check("own added: debuffs re-read", counted(function()
    M.FireEvent("UNIT_AURA", "target", { addedAuras = { list[7] } })
end), "2 lists, 0 lookups")
H.check("own added: first", icons(debuffs), "102,104,107,101,103,105")
H.check("own added: big", debuffs.buttons[3]:GetWidth(), 26)
H.check("own added: placed in the own row", offset(debuffs.buttons[3]), "BOTTOMLEFT>BOTTOMLEFT 56,0")
H.check("others moved along", offset(debuffs.buttons[4]), "BOTTOMLEFT>BOTTOMLEFT 0,28")
H.check("others resized", debuffs.buttons[4]:GetWidth(), 20)
table.remove(list, 2)
M.FireEvent("UNIT_AURA", "target", { removedAuraInstanceIDs = { 2 } })
H.check("own removed", icons(debuffs), "104,107,101,103,105")
H.check("the third icon is an other now", debuffs.buttons[3]:GetWidth(), 20)
H.check("and sits in the others' row", offset(debuffs.buttons[3]), "BOTTOMLEFT>BOTTOMLEFT 0,28")
table.remove(list, 6)
table.remove(list, 3)
M.FireEvent("UNIT_AURA", "target", { removedAuraInstanceIDs = { 4, 7 } })
H.check("no own left", debuffs.own, 0)
H.check("others start at the corner", offset(debuffs.buttons[1]), "BOTTOMLEFT>BOTTOMLEFT 0,0")
H.check("holder: one row of others", debuffs.holder:GetHeight(), 20)
H.check("pool not rebuilt: as many as were ever shown", #debuffs.buttons, 6)
-- Relayouts reuse the pool: an own aura coming and going makes no frames.
local framesBefore = #M.frames
for _ = 1, 20 do
    list[#list + 1] = aura(8, { mine = true })
    M.FireEvent("UNIT_AURA", "target", { addedAuras = { list[#list] } })
    list[#list] = nil
    M.FireEvent("UNIT_AURA", "target", { removedAuraInstanceIDs = { 8 } })
end
H.check("own coming and going: no frames made", #M.frames, framesBefore)
H.check("and gone again", debuffs.own, 0)
-- A shown aura changed: patched in place, no list.
list[1].applications = 3
H.check("updated: one lookup", counted(function()
    M.FireEvent("UNIT_AURA", "target", { updatedAuraInstanceIDs = { 1 } })
end), "0 lists, 1 lookups")
H.check("updated: stacks", debuffs.buttons[1].count:GetText(), "3")

-- Auto per row follows the frame width (restyle) and the icon sizes.
C.Set("target", "width", 160)
H.check("160 wide: 7 of 20", debuffs.perRow, 7)
H.check("160 wide: 5 of 26", debuffs.ownPerRow, 5)
C.Set("target", "debuffsSize", 30)
H.check("30 px: 5 per row", debuffs.perRow, 5)
H.check("own size unchanged by it", debuffs.ownPerRow, 5)
C.Set("target", "debuffsOwnSize", 40)
H.check("own 40 px: 3 per row", debuffs.ownPerRow, 3)
C.Set("target", "debuffsSpacing", 0)
H.check("no spacing: 4 own per row", debuffs.ownPerRow, 4)
-- A fixed value is honoured for both size classes.
C.Set("target", "debuffsPerRow", 2)
H.check("fixed per row", debuffs.perRow, 2)
H.check("fixed own per row", debuffs.ownPerRow, 2)
C.ResetScope("target")
-- Vertical growth wraps by the frame height.
C.Set("target", "debuffsGrowth", "UP")
H.check("growing up: by height (46 + 2) / 22", debuffs.perRow, 2)
C.ResetScope("target")
-- Test mode: two own samples on the target's debuffs; party buttons wrap
-- by the member width.
H.checkTrue("test mode on", ns.TestMode.Set(true))
H.check("samples: two own", debuffs.own, 2)
H.check("sample own big", debuffs.buttons[2]:GetWidth(), 26)
H.check("sample other normal", debuffs.buttons[3]:GetWidth(), 20)
H.check("samples: others above", offset(debuffs.buttons[3]), "BOTTOMLEFT>BOTTOMLEFT 0,28")
H.check("samples: max total", debuffs.count, 16)
H.check("samples: buffs none own", buffs.own, 0)
for i, b in ipairs(ns.Party.fakes) do
    H.check("pretend member " .. i .. ": auto per row by member width", b.auras.debuffs.perRow,
        math.floor((160 + 2) / (18 + 2)))
end
C.Set("party", "width", 110)
for i, b in ipairs(ns.Party.fakes) do
    H.check("pretend member " .. i .. ": narrower", b.auras.debuffs.perRow, math.floor((110 + 2) / (18 + 2)))
end
C.ResetScope("party")
ns.TestMode.Set(false)
H.check("samples gone: the target's own auras again", icons(debuffs), "101,103,105")
H.check("samples gone: none of them yours", debuffs.own, 0)
