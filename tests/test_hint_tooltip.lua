-- A hint cut off at the column's end is shown in full in a tooltip when
-- the row is hovered; short hints need none.
local M = H.M
local ns = H.LoadAddon()
local W = ns.Widgets
local parent = CreateFrame("Frame", nil, UIParent)
local on = true
local function box(hint)
    return W.Checkbox(parent, { label = "Option", hint = hint,
        get = function() return on end, set = function(v) on = v; return true end })
end

local long = string.rep("A long description of what this option does. ", 4)
local row = box(long)
H.checkTrue("long hint is cut", row.hintText:IsTruncated())
GameTooltip._shown = false
row:GetScript("OnEnter")(row)
H.checkTrue("hover: tooltip shown", GameTooltip._shown)
H.check("tooltip title is the label", M.tooltipLines[1], "Option")
H.check("tooltip shows the full hint", M.tooltipLines[2], long)
row:GetScript("OnLeave")(row)
H.check("leave: tooltip hidden", GameTooltip._shown, false)

local short = box("Short")
H.check("short hint fits", short.hintText:IsTruncated(), false)
GameTooltip._shown = false
short:GetScript("OnEnter")(short)
H.check("short hint: no tooltip", GameTooltip._shown, false)
