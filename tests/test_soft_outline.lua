local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config

-- Enum values are encoded by index: SOFT is appended, nothing moves.
local values = S.Get("fontOutline").values
H.check("enum: NONE first", values[1], "NONE")
H.check("enum: OUTLINE second", values[2], "OUTLINE")
H.check("enum: THICKOUTLINE third", values[3], "THICKOUTLINE")
H.check("enum: MONOCHROME fourth", values[4], "MONOCHROME")
H.check("enum: SOFT appended", values[5], "SOFT")
H.check("enum: five values", #values, 5)
H.check("SOFT is the default", S.Get("fontOutline").default, "SOFT")
H.check("SOFT label", ns.L.ENUM_SOFT, "Soft outline")
H.check("SOFT label via schema", ns.Schema.EnumText(S.Get("fontOutline"), "SOFT"), "Soft outline")

C.Use({})
M.units.player = { name = "Tester", level = 60, class = "PRIEST", className = "Priest", isPlayer = true,
    health = M.Secret(900), healthMax = M.Secret(1000), healthPercent = M.Secret(0.9), healthMissing = M.Secret(100),
    power = M.Secret(400), powerMax = M.Secret(500), powerPercent = M.Secret(0.8), powerType = 0 }
M.units.target = { name = "Foe", health = 1, healthMax = 1 }
ns.Single.CreateAll()
local f = ns.Frames.player
local OFFSETS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function checkCopies(label, fs)
    local copies = fs.softCopies
    H.checkTrue(label .. ": has copies", copies)
    if not copies then return end
    H.check(label .. ": four copies", #copies, 4)
    H.check(label .. ": no outline flag", fs._font[3], "")
    local layer, sublevel = fs:GetDrawLayer()
    for i, c in ipairs(copies) do
        local l = label .. " copy " .. i
        H.check(l .. ": parent", c:GetParent(), fs:GetParent())
        H.check(l .. ": font", c._font[1], fs._font[1])
        H.check(l .. ": size", c._font[2], fs._font[2])
        H.check(l .. ": flags", c._font[3], "")
        H.check(l .. ": black", c._color[1] + c._color[2] + c._color[3], 0)
        H.check(l .. ": opaque", c._color[4], 1)
        local cl, cs = c:GetDrawLayer()
        H.check(l .. ": same layer", cl, layer)
        H.checkTrue(l .. ": behind the text", cs < sublevel)
        H.check(l .. ": justify", c._justifyH, fs._justifyH)
        H.check(l .. ": word wrap", c:GetWordWrap(), fs:GetWordWrap())
        H.check(l .. ": shown with the text", c:IsShown(), fs:IsShown())
        -- The copy covers the text's own rectangle, shifted: same anchors
        -- and width constraints as the text.
        local p1 = { c:GetPoint(1) }
        local p2 = { c:GetPoint(2) }
        H.check(l .. ": top left", p1[1], "TOPLEFT")
        H.check(l .. ": follows the text", p1[2], fs)
        H.check(l .. ": x", p1[4], OFFSETS[i][1])
        H.check(l .. ": y", p1[5], OFFSETS[i][2])
        H.check(l .. ": bottom right", p2[1], "BOTTOMRIGHT")
        H.check(l .. ": follows the text (2)", p2[2], fs)
        H.check(l .. ": x (2)", p2[4], OFFSETS[i][1])
        H.check(l .. ": y (2)", p2[5], OFFSETS[i][2])
    end
end

for _, field in ipairs({ "healthLeft", "healthRight", "powerLeft", "powerRight" }) do
    checkCopies(field, f.texts[field])
end
H.check("left text keeps no word wrap on copies", f.texts.healthLeft.softCopies[1]:GetWordWrap(), false)

-- Every write reaches the copies, secrets passed through untouched.
local hl, hr, pr = f.texts.healthLeft, f.texts.healthRight, f.texts.powerRight
H.check("formatted text mirrored", hl.softCopies[3]._fmt, "%s %s")
H.check("formatted args mirrored", hl.softCopies[3]._args[2], "Tester")
H.check("secret formatted arg mirrored", hr.softCopies[2]._args[1], M.units.player.health)
H.check("secret text mirrored", pr.softCopies[4]._text, M.units.player.power)
hl:SetText("plain")
for i = 1, 4 do H.check("SetText mirrored " .. i, hl.softCopies[i]._text, "plain") end
local secret = M.Secret("hidden")
hl:SetFormattedText("%s", secret)
for i = 1, 4 do H.check("secret SetFormattedText mirrored " .. i, hl.softCopies[i]._args[1], secret) end

-- Other styles: the copies hide, the client's own flag is used; no new
-- copies are made when switching back and forth.
local first = hl.softCopies
local firstCopy = first[1]
C.Set("general", "fontOutline", "OUTLINE")
H.check("outline flag back", hl._font[3], "OUTLINE")
for i = 1, 4 do H.check("copy hidden for OUTLINE " .. i, hl.softCopies[i]:IsShown(), false) end
C.Set("general", "fontOutline", "NONE")
H.check("none flag", hl._font[3], "")
H.check("copies hidden for NONE", hl.softCopies[1]:IsShown(), false)
hl:SetText("while hidden")
H.check("hidden copies still mirror", hl.softCopies[1]._text, "while hidden")
C.Set("general", "fontOutline", "SOFT")
H.check("same copies table", hl.softCopies, first)
H.check("same copy", hl.softCopies[1], firstCopy)
H.check("still four", #hl.softCopies, 4)
H.checkTrue("copies shown again", hl.softCopies[1]:IsShown())
H.check("font size follows on restyle", (function()
    C.Set("general", "fontSize", 15)
    return hl.softCopies[2]._font[2]
end)(), 15)

-- A frame that never used SOFT makes no copies.
do
    local ns2 = H.LoadAddon()
    ns2.Config.Use({ general = { fontOutline = "THICKOUTLINE" } })
    M.units.player = { name = "P", level = 1, health = 1, healthMax = 1, power = 1, powerMax = 1, powerType = 0 }
    ns2.Single.CreateAll()
    H.check("no copies without SOFT", ns2.Frames.player.texts.healthLeft.softCopies, nil)
    H.check("thick outline flag", ns2.Frames.player.texts.healthLeft._font[3], "THICKOUTLINE")
end

-- Castbar name and time.
do
    local ns3 = H.LoadAddon()
    ns3.Config.Use({})
    M.units.target = { name = "Foe", health = 1, healthMax = 1,
        cast = { name = M.Secret("Fireball"), texture = 135812, startMs = 1000000, endMs = 1002500 } }
    ns3.Single.CreateAll()
    local bar = ns3.Frames.target.castbar
    checkCopies("castbar name", bar.text)
    checkCopies("castbar time", bar.time)
    M.FireEvent("UNIT_SPELLCAST_START", "target", "c-1", 133)
    H.check("castbar name mirrored (secret)", bar.text.softCopies[1]._text, M.units.target.cast.name)
    H.check("castbar time mirrored", bar.time.softCopies[1]._fmt, "%.1f")
    H.check("castbar time args mirrored", bar.time.softCopies[1]._args[1], 2.5)
    ns3.Config.Set("target", "castbarTime", false)
    H.check("hidden time hides its copies", bar.time.softCopies[1]:IsShown(), false)
    H.check("shown name keeps its copies", bar.text.softCopies[1]:IsShown(), true)
    ns3.Config.Set("target", "castbarTime", true)
    H.check("time copies back", bar.time.softCopies[1]:IsShown(), true)
    ns3.Config.Set("target", "castbarName", false)
    H.check("hidden name hides its copies", bar.text.softCopies[2]:IsShown(), false)
    ns3.Config.Set("target", "fontOutline", "THICKOUTLINE")
    H.check("castbar thick outline", bar.text._font[3], "THICKOUTLINE")
    H.check("castbar copies hidden", bar.time.softCopies[1]:IsShown(), false)
end

-- Stored as the fifth value; an explicit OUTLINE (no longer the default)
-- is stored and survives a round trip.
do
    local ns4 = H.LoadAddon()
    ns4.Config.Use({})
    ns4.Config.Set("player", "fontOutline", "OUTLINE")
    ns4.Config.Set("target", "fontOutline", "NONE")
    ns4.Config.Set("general", "fontOutline", "SOFT")
    H.check("default SOFT is not stored", ns4.Config.IsOverridden("general", "fontOutline"), false)
    local back = assert(ns4.Codec.Decode(ns4.Codec.Encode(ns4.Config.Profile())))
    H.check("OUTLINE round trip", back.player.fontOutline, "OUTLINE")
    H.check("NONE round trip", back.target.fontOutline, "NONE")
    ns4.Config.Use({ focus = { fontOutline = "SOFT" } })
    back = assert(ns4.Codec.Decode(ns4.Codec.Encode(ns4.Config.Profile())))
    H.check("SOFT round trip", back.focus.fontOutline, "SOFT")
end
