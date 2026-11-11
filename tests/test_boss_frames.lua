-- The boss frames: five frames (boss1 .. boss5) under one set of settings,
-- in a column that hangs from boss1, one mover for the column, Blizzard's
-- boss container hidden while ours are on.
local M = H.M

local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "PRIEST", isPlayer = true, health = 1, healthMax = 1 }
local container = CreateFrame("Frame", "BossTargetFrameContainer", UIParent)
local blizzard1 = CreateFrame("Button", "Boss1TargetFrame", container)
blizzard1:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C, Single = ns.Settings, ns.Config, ns.Single
local function same(label, got, want)
    for i = 1, #want do H.check(label .. " [" .. i .. "]", got[i], want[i]) end
end

H.check("one scope", S.AppliesTo(S.Get("bossSpacing"), "boss"), true)
H.check("on by default", S.Default(S.Get("enabled"), "boss"), true)
H.checkTrue("named", ns.L.FRAME_boss ~= "FRAME_boss")
H.check("no ns.Frames.boss", ns.Frames.boss, nil)
for i = 1, 5 do
    local frame = ns.Frames["boss" .. i]
    H.checkTrue("boss" .. i .. " made", frame)
    H.check("boss" .. i .. " unit", frame.unit, "boss" .. i)
    H.check("boss" .. i .. " attribute", frame:GetAttribute("unit"), "boss" .. i)
    H.check("boss" .. i .. " scope", frame.key, "boss")
    H.checkTrue("boss" .. i .. " watched", frame._unitWatch)
end

-- The column: boss2 .. boss5 each under the one before, the gap between.
local gap = Single.ColumnGap("boss")
H.check("gap without a docked castbar: the spacing", gap,
    ns.Pixel.Snap(C.Get("boss", "bossSpacing")) + ns.Castbar.DockedDepth("boss"))
for i = 2, 5 do
    local point, rel, relPoint, x, y = ns.Frames["boss" .. i]:GetPoint(1)
    same("boss" .. i .. " hangs below boss" .. (i - 1), { point, rel, relPoint, x, y },
        { "TOP", ns.Frames["boss" .. (i - 1)], "BOTTOM", 0, -gap })
end

-- One mover, boss1's, as tall as the column; boss1 hangs from its top.
local first = ns.Frames.boss1
H.checkTrue("boss1 has the mover", first.mover)
for i = 2, 5 do H.check("boss" .. i .. " has none", ns.Frames["boss" .. i].mover, nil) end
local w, h = Single.Size("boss")
local _, columnH = Single.ColumnSize("boss", 5)
H.check("column height", columnH, 5 * h + 4 * gap)
H.check("mover height", first.mover:GetHeight(), ns.Pixel.Snap(columnH))
H.check("mover width", first.mover:GetWidth(), ns.Pixel.Snap(w))
local point, rel, relPoint = first:GetPoint(1)
same("boss1 at the mover's top", { point, rel, relPoint }, { "TOP", first.mover, "TOP" })

-- A wider spacing moves the column apart.
C.Set("boss", "bossSpacing", 30)
local _, _, _, _, y2 = ns.Frames.boss2:GetPoint(1)
H.check("spacing follows", y2, -Single.ColumnGap("boss"))
H.check("spacing in the gap", Single.ColumnGap("boss") >= 30, true)

-- Blizzard's boss frames: their container under the hidden parent, their
-- events gone.
H.checkTrue("Blizzard's container hidden", not container:IsVisible())
H.check("Blizzard's container moved", container:GetParent() ~= UIParent, true)
H.check("Blizzard's boss frame silent", next(blizzard1._events), nil)

-- A boss engaged: its frame shows its health.
M.units.boss1 = { name = "Boss", health = 7, healthMax = 10 }
first:Show()
M.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
H.check("boss1 health", first.health:GetValue(), 7)

-- Off: not watched, hidden.
C.Set("boss", "enabled", false)
for i = 1, 5 do H.check("off: boss" .. i .. " unwatched", ns.Frames["boss" .. i]._unitWatch, nil) end

-- Test mode shows all five.
C.Set("boss", "enabled", true)
H.checkTrue("test mode on", ns.TestMode.Set(true))
for i = 1, 5 do H.checkTrue("test mode: boss" .. i .. " shown", ns.Frames["boss" .. i]:IsShown()) end
ns.TestMode.Set(false)
H.check("test mode off: boss2's unit back", ns.Frames.boss2.unit, "boss2")
H.check("no errors", #M.errors, 0)
