local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config

-- Which frames have a castbar, and the player's is off by default.
for _, scope in ipairs({ "player", "target", "targettarget", "focus", "party" }) do
    H.checkTrue("castbar on " .. scope, S.AppliesTo(S.Get("castbarEnabled"), scope))
end
H.check("no castbar on the pet", S.AppliesTo(S.Get("castbarEnabled"), "pet"), false)
C.Use({})
H.check("player castbar off by default", C.Get("player", "castbarEnabled"), false)
H.checkTrue("target castbar on by default", C.Get("target", "castbarEnabled"))

ns.Single.CreateAll()
local t = ns.Frames.target
local bar = t.castbar
H.checkTrue("target has a castbar", bar)
H.check("pet has none", ns.Frames.pet.castbar, nil)
H.check("hidden while idle", bar:IsShown(), false)
H.check("parented to the frame", bar:GetParent(), t)

-- Docked below the frame, the icon to its left, room for both borders.
local point, rel, relPoint, x, y = bar:GetPoint(1)
H.check("docked below: point", point, "TOPLEFT")
H.check("docked below: to the frame", rel, t)
H.check("docked below: frame bottom", relPoint, "BOTTOMLEFT")
H.check("icon inset", x, 16)
H.check("gap", y, -4)
H.check("height", bar:GetHeight(), 16)
H.check("icon size", bar.icon:GetWidth(), 16)
C.Set("target", "castbarIcon", false)
H.check("no icon: no inset", select(4, bar:GetPoint(1)), 0)
H.check("icon hidden", bar.icon:IsShown(), false)
C.Set("target", "castbarIcon", true)

-- A readable cast.
M.units.target = { name = "Foe", health = 1, healthMax = 1,
    cast = { name = "Fireball", texture = 135812, startMs = 1000000, endMs = 1002500 } }
M.FireEvent("UNIT_SPELLCAST_START", "target", "cast-1", 133)
H.checkTrue("shown on start", bar:IsShown())
local lo, hi = bar:GetMinMaxValues()
H.check("range start", lo, 1000000)
H.check("range end", hi, 1002500)
H.check("value is the clock", bar:GetValue(), 1000000)
H.check("name", bar.text:GetText(), "Fireball")
H.check("icon", bar.icon._texture, 135812)
H.check("cast colour", bar._color[1], ns.Castbar.CAST_COLOR[1])
H.check("cast: background keeps the background colour", bar.bg._color[4], C.Get("target", "backgroundColor")[4])
H.check("cast: no remaining part", bar.remain:IsShown(), false)
H.check("fills left to right", bar._reverse, false)
H.check("time text", bar.time._args[1], 2.5)
M.Tick(1)
H.check("value follows the clock", bar:GetValue(), 1001000)
H.check("time counts down", bar.time._args[1], 1.5)

-- A late stop for an earlier cast leaves the new one alone.
M.FireEvent("UNIT_SPELLCAST_STOP", "target", "cast-0", 133)
H.checkTrue("other cast's stop ignored", bar:IsShown())
-- Its own stop, with the cast over: hidden.
M.units.target.cast = nil
M.FireEvent("UNIT_SPELLCAST_STOP", "target", "cast-1", 133)
H.check("own stop hides", bar:IsShown(), false)

-- Secret cast: everything passes straight through, nothing is computed.
local name, startMs, endMs = M.Secret("Shadow Bolt"), M.Secret(2000000), M.Secret(2003000)
M.units.target.cast = { name = name, texture = M.Secret(136197), startMs = startMs, endMs = endMs }
M.FireEvent("UNIT_SPELLCAST_START", "target", M.Secret("guid-a"), 686)
H.checkTrue("secret cast shown", bar:IsShown())
lo, hi = bar:GetMinMaxValues()
H.check("secret start passed through", lo, startMs)
H.check("secret end passed through", hi, endMs)
H.check("secret name passed through", bar.text:GetText(), name)
M.Tick(0.5)
H.check("secret: time left empty without a duration", bar.time:GetText(), "")
H.checkTrue("secret: still shown after ticks", bar:IsShown())
-- Secret GUIDs cannot be compared: the client is asked instead.
M.FireEvent("UNIT_SPELLCAST_STOP", "target", M.Secret("guid-a"), 686)
H.checkTrue("uncomparable stop, still casting: kept", bar:IsShown())
M.units.target.cast = nil
M.FireEvent("UNIT_SPELLCAST_STOP", "target", M.Secret("guid-a"), 686)
H.check("uncomparable stop, cast over: hidden", bar:IsShown(), false)

-- A duration object shows the time even when the end is secret.
local remaining = M.Secret(1.2)
M.units.target.cast = { name = name, startMs = startMs, endMs = endMs }
M.units.target.castDuration = { GetRemainingDuration = function() return remaining end }
M.FireEvent("UNIT_SPELLCAST_START", "target", "guid-b", 686)
H.check("duration: secret seconds passed through", bar.time._args[1], remaining)
-- A secret duration object refuses to be asked: empty, no error.
M.units.target.castDuration = M.Secret({})
M.FireEvent("UNIT_SPELLCAST_START", "target", "guid-c", 686)
H.check("secret duration object: empty", bar.time:GetText(), "")
-- A duration object that fails once is not asked again on later frames.
local asked = 0
M.units.target.castDuration = { GetRemainingDuration = function() asked = asked + 1; error("refused") end }
M.FireEvent("UNIT_SPELLCAST_START", "target", "guid-d", 686)
H.check("failing duration: asked once", asked, 1)
H.check("failing duration: dropped", bar.cast.duration, nil)
H.check("failing duration: empty", bar.time:GetText(), "")
M.Tick(0.1)
M.Tick(0.1)
H.check("failing duration: not asked again", asked, 1)
H.check("failing duration: still empty", bar.time:GetText(), "")
M.units.target.cast, M.units.target.castDuration = nil, nil
M.FireEvent("UNIT_SPELLCAST_FAILED", "target", "guid-d", 686)
H.check("failed: hidden", bar:IsShown(), false)

-- Channels drain from the right and end on their own stop.
M.units.target.channel = { name = "Drain Life", texture = 1, startMs = 1001000, endMs = 1006000 }
M.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "target", "c-1", 689)
H.checkTrue("channel shown", bar:IsShown())
-- The coloured part drains: the fill (which grows with the clock from the
-- right) is invisible, and an extra texture in the channel colour covers
-- the rest, from the bar's left edge to the fill's left edge. The
-- background keeps its own (possibly translucent) colour.
local bgColor = C.Get("target", "backgroundColor")
H.check("channel: fill invisible", bar._color[4], 0)
H.check("channel: background keeps the background colour", bar.bg._color[4], bgColor[4])
H.check("channel: background keeps the background red", bar.bg._color[1], bgColor[1])
local remain = bar.remain
H.checkTrue("channel: remaining part shown", remain:IsShown())
H.check("channel: remaining part is channel red", remain._color[1], ns.Castbar.CHANNEL_COLOR[1])
H.check("channel: remaining part is channel green", remain._color[2], ns.Castbar.CHANNEL_COLOR[2])
local function pointOf(tex, name)
    for i = 1, #tex._points do
        local p = { tex:GetPoint(i) }
        if p[1] == name then return p end
    end
end
local tl, br = pointOf(remain, "TOPLEFT"), pointOf(remain, "BOTTOMRIGHT")
H.check("remaining: starts at the bar", tl[2], bar)
H.check("remaining: bar's top left", tl[3], "TOPLEFT")
H.check("remaining: ends at the fill", br[2], bar:GetStatusBarTexture())
H.check("remaining: fill's bottom left", br[3], "BOTTOMLEFT")
ns.Castbar.Style(t)
H.check("restyled mid-channel: fill stays invisible", bar._color[4], 0)
H.checkTrue("restyled mid-channel: remaining part stays", remain:IsShown())
H.check("channel fills from the right", bar._reverse, true)
M.FireEvent("UNIT_SPELLCAST_STOP", "target", "x", 1)
H.checkTrue("a cast stop does not end a running channel", bar:IsShown())
M.units.target.channel = nil
M.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target", "c-1", 689)
H.check("channel stop hides", bar:IsShown(), false)

-- A missed stop: a readable end time in the past ends the bar.
M.units.target.cast = { name = "Heal", startMs = 1001000, endMs = 1001500 }
M.FireEvent("UNIT_SPELLCAST_START", "target", "h-1", 2050)
H.check("cast after a channel: fill is cast colour", bar._color[2], ns.Castbar.CAST_COLOR[2])
H.check("cast after a channel: background colour back", bar.bg._color[2], bgColor[2])
H.check("cast after a channel: background alpha back", bar.bg._color[4], bgColor[4])
H.check("cast after a channel: fill opaque again", bar._color[4], nil)
H.check("cast after a channel: remaining part hidden", bar.remain:IsShown(), false)
M.Tick(1)
H.check("past a readable end: hidden", bar:IsShown(), false)

-- A new target that is already casting shows its cast at once.
M.units.target.cast = { name = "Frostbolt", startMs = 1001000, endMs = 1004000 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("new target mid-cast", bar:IsShown())
H.check("new target cast name", bar.text:GetText(), "Frostbolt")

-- Disabled: never shown.
C.Set("target", "castbarEnabled", false)
H.check("disabled: hidden", bar:IsShown(), false)
M.FireEvent("UNIT_SPELLCAST_START", "target", "f-2", 116)
H.check("disabled: ignores casts", bar:IsShown(), false)

-- Name and time can be switched off.
C.Set("target", "castbarEnabled", true)
C.Set("target", "castbarName", false)
C.Set("target", "castbarTime", false)
H.check("name hidden", bar.text:IsShown(), false)
H.check("time hidden", bar.time:IsShown(), false)

-- The player's own castbar once switched on.
C.Set("player", "castbarEnabled", true)
local pbar = ns.Frames.player.castbar
M.units.player = { name = "Me", health = 1, healthMax = 1,
    cast = { name = "Hearthstone", startMs = 1001000, endMs = 1011000 } }
M.FireEvent("UNIT_SPELLCAST_START", "player", "p-1", 8690)
H.checkTrue("player castbar", pbar:IsShown())
H.check("target castbar unaffected by player cast", bar:IsShown(), true)

-- Target of target has no cast events: the timer picks casts up.
local tot = ns.Frames.targettarget
M.units.targettarget = { name = "Tank", health = 1, healthMax = 1,
    cast = { name = "Taunt", startMs = 1002000, endMs = 1020000 } }
M.Tick(0.25)
H.checkTrue("tot cast found by the timer", tot.castbar:IsShown())
M.units.targettarget.cast = nil
M.Tick(0.25)
H.check("tot cast gone on the next tick", tot.castbar:IsShown(), false)

-- Party members have castbars, fed by their own unit's events.
local header = ns.Party.Create()
M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
M.SetGroup({ "party1" })
local member = header:GetAttribute("child1")
H.checkTrue("party castbar built", member.castbar)
M.units.party1.cast = { name = "Renew", startMs = 1002000, endMs = 1020000 }
M.FireEvent("UNIT_SPELLCAST_START", "party1", "r-1", 139)
H.checkTrue("party castbar shown", member.castbar:IsShown())

-- The spell name stops short of the time text on a narrow castbar.
do
    local b = ns.Frames.target.castbar
    ns.Castbar.Style(ns.Frames.target)
    local p
    for i = 1, #b.text._points do
        local q = { b.text:GetPoint(i) }
        if q[1] == "RIGHT" then p = q end
    end
    H.checkTrue("castbar name: right anchor", p)
    H.check("castbar name: to the time text", p[2], b.time)
    H.check("castbar name: its left edge", p[3], "LEFT")
    H.check("castbar name: gap", p[4], -4)
    H.check("castbar name: still starts at the bar", select(2, b.text:GetPoint(1)), b)
    H.check("castbar name: no word wrap", b.text:GetWordWrap(), false)
end
do
    local b = ns.Frames.target.castbar
    b.time:SetText("9.9")
    C.Set("target", "castbarTime", false)
    H.check("castbar time off: emptied for the name", b.time:GetText(), "")
    C.Set("target", "castbarTime", true)
end
