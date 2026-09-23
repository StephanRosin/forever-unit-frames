-- Aura settings mapped onto a container: flow layout and the two groups.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local AC, C = ns.AuraContainers, ns.Config
local Axis, Dir = AnchorUtil.FlowLayoutAxis, AnchorUtil.FlowDirection

local function shape(fields)
    local g = { primary = "RIGHT", row = "UP", perRowSetting = 0, length = 200, size = 20, ownSize = 26, spacing = 2,
        enabled = true, highlightOwn = false, filter = "HARMFUL", ownFilter = "HARMFUL|PLAYER",
        otherFilter = "HARMFUL|!PLAYER", max = 16 }
    for k, v in pairs(fields or {}) do g[k] = v end
    return g
end

-- Flow: axis, start corner and both directions from growth + rows.
local cases = {
    { "RIGHT", "UP", Axis.Horizontal, "BOTTOMLEFT", Dir.Right, Dir.Up },
    { "RIGHT", "DOWN", Axis.Horizontal, "TOPLEFT", Dir.Right, Dir.Down },
    { "LEFT", "DOWN", Axis.Horizontal, "TOPRIGHT", Dir.Left, Dir.Down },
    { "LEFT", "UP", Axis.Horizontal, "BOTTOMRIGHT", Dir.Left, Dir.Up },
    { "DOWN", "RIGHT", Axis.Vertical, "TOPLEFT", Dir.Right, Dir.Down },
    { "UP", "LEFT", Axis.Vertical, "BOTTOMRIGHT", Dir.Left, Dir.Up },
    -- A row direction along the growth falls back like Layout.AuraRowDirection.
    { "RIGHT", "LEFT", Axis.Horizontal, "TOPLEFT", Dir.Right, Dir.Down },
    { "UP", "DOWN", Axis.Vertical, "BOTTOMLEFT", Dir.Right, Dir.Up },
}
for _, c in ipairs(cases) do
    local f = AC.Flow(shape({ primary = c[1], row = c[2] }))
    local label = c[1] .. "/" .. c[2]
    H.check(label .. " axis", f.axis, c[3])
    H.check(label .. " corner", f.anchor, c[4])
    H.check(label .. " horizontal", f.horizontal, c[5])
    H.check(label .. " vertical", f.vertical, c[6])
end

-- Row length: Auto is the frame's length; a fixed number is that many
-- normal icons with the spacing between them; never below one icon.
H.check("auto: frame length", AC.Flow(shape()).lineSize, 200)
H.check("8 per row", AC.Flow(shape({ perRowSetting = 8 })).lineSize, 8 * 20 + 7 * 2)
H.check("1 per row", AC.Flow(shape({ perRowSetting = 1 })).lineSize, 20)
H.check("tiny frame: one icon", AC.Flow(shape({ length = 5 })).lineSize, 20)

-- The container's wrap rule (AnchorUtil.ApplyFlowLayout): n icons fit a
-- line when n * size + (n - 1) * spacing <= lineSize. Auto then gives
-- exactly Layout.AuraPerRow's count.
local function fits(lineSize, size, spacing)
    local n = 1
    while (n + 1) * size + n * spacing <= lineSize do n = n + 1 end
    return n
end
for _, length in ipairs({ 20, 21, 43, 44, 160, 199, 200, 201 }) do
    H.check("auto count at " .. length, fits(AC.Flow(shape({ length = length })).lineSize, 20, 2),
        ns.Layout.AuraPerRow(0, length, 20, 2))
end
H.check("fixed 8 holds 8", fits(AC.Flow(shape({ perRowSetting = 8 })).lineSize, 20, 2), 8)

-- Parts. Yours not first: "own" off, "other" takes the group's filter.
local own, other = AC.Part(shape(), "own"), AC.Part(shape(), "other")
H.check("own off", own.enabled, false)
H.check("other on", other.enabled, true)
H.check("other: everything", other.filter, "HARMFUL")
H.check("other size", other.layout.elementWidth .. "x" .. other.layout.elementHeight, "20x20")
H.check("spacing", other.layout.elementSpacing .. "/" .. other.layout.lineSpacing, "2/2")
H.check("no new line", other.layout.forceNewLine, false)
H.check("maximum", other.max, 16)
H.check("own filter kept valid while off", own.filter, "HARMFUL|PLAYER")

-- Yours first: own at its size, the rest on a new line.
local g = shape({ highlightOwn = true })
own, other = AC.Part(g, "own"), AC.Part(g, "other")
H.check("own on", own.enabled, true)
H.check("own filter", own.filter, "HARMFUL|PLAYER")
H.check("own size", own.layout.elementWidth, 26)
H.check("own: no new line", own.layout.forceNewLine, false)
H.check("other filter", other.filter, "HARMFUL|!PLAYER")
H.check("other: new line", other.layout.forceNewLine, true)
H.check("gap to the rows before", other.layout.groupLineSpacing, 2)
H.check("each part up to the maximum", own.max .. "," .. other.max, "16,16")

-- Only yours, first: nothing else.
g = shape({ highlightOwn = true, filter = "HARMFUL|PLAYER" })
g.otherFilter = nil
H.check("only mine: other off", AC.Part(g, "other").enabled, false)
H.check("only mine: other filter valid", AC.Part(g, "other").filter, "HARMFUL|PLAYER")
-- A switched-off group: both parts off.
g = shape({ enabled = false, highlightOwn = true })
H.check("off: own", AC.Part(g, "own").enabled, false)
H.check("off: other", AC.Part(g, "other").enabled, false)

-- Auras.Style keeps the raw per-row setting and the frame length for this.
C.Set("target", "debuffsPerRow", 5)
local d = ns.Frames.target.auras.debuffs
H.check("per row setting kept", d.perRowSetting, 5)
H.check("frame length kept", d.length, C.Get("target", "width"))
C.Set("target", "debuffsGrowth", "UP")
H.check("growing up: frame height", d.length, C.Get("target", "height"))
