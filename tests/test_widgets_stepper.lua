-- A number with − / + buttons (Options/Widgets.lua Stepper): for values
-- whose range is far too wide for a slider (the raid panel's position).
-- A click moves by the step, with Shift by the big step; a typed number
-- commits on Enter or when the box loses focus; out of range or not a
-- number flashes and puts the stored value back.
local M = H.M
local ns = H.LoadAddon()
local W = ns.Widgets
local parent = CreateFrame("Frame", nil, UIParent)

local function click(button) button:GetScript("OnClick")(button) end
local value, sets = 100, 0
local row = W.Stepper(parent, { label = "Position X", hint = "From the centre", min = -50, max = 120,
    step = 1, bigStep = 8,
    get = function() return value end, set = function(v) value = v; sets = sets + 1; return true end })
row:Refresh()
H.check("shows the value", row.edit:GetText(), "100")
H.check("label", row.label:GetText(), "Position X")
H.check("hint", row.hintText:GetText(), "From the centre")
H.check("minus left", (select(1, row.minus:GetPoint(1))), "LEFT")
H.check("minus at the control column", select(4, row.minus:GetPoint(1)), W.CONTROL_X)
H.check("box after minus", (select(2, row.edit:GetPoint(1))), row.minus)
H.check("plus after the box", (select(2, row.plus:GetPoint(1))), row.edit)

click(row.plus)
H.check("+ by one", value, 101)
H.check("box follows", row.edit:GetText(), "101")
click(row.minus)
H.check("- by one", value, 100)
M.shiftDown = true
click(row.plus)
H.check("shift +: big step", value, 108)
click(row.minus); click(row.minus)
H.check("shift -: big step", value, 92)
M.shiftDown = false

-- The range holds: no set at the edge.
value = 120
row:Refresh()
sets = 0
click(row.plus)
H.check("at the top: stays", value, 120)
H.check("at the top: nothing set", sets, 0)
value = -45
M.shiftDown = true
click(row.minus)
M.shiftDown = false
H.check("big step stops at the bottom", value, -50)

-- Typed.
M.Type(row.edit, "-12")
M.PressEnter(row.edit)
H.check("typed, Enter", value, -12)
M.Type(row.edit, "33")
M.LeaveBox(row.edit)
H.check("typed, focus lost", value, 33)
M.Type(row.edit, "7.6")
M.PressEnter(row.edit)
H.check("rounded to the step", value, 8)
M.Type(row.edit, "abc")
M.PressEnter(row.edit)
H.check("not a number: kept", value, 8)
H.check("not a number: box back", row.edit:GetText(), "8")
H.check("not a number: flashed", row.edit.edges[1]._color[1], ns.Style.COLORS.error[1])
M.Type(row.edit, "500")
M.PressEnter(row.edit)
H.check("out of range: kept", value, 8)
M.Type(row.edit, "77")
M.PressEscape(row.edit)
H.check("ESC: kept", value, 8)
H.check("ESC: box back", row.edit:GetText(), "8")

-- What set stores wins (a value clamped by the caller shows as stored).
local clampRow = W.Stepper(parent, { label = "Y", min = -100, max = 100,
    get = function() return value end, set = function(v) value = math.min(v, 40); return true end })
M.Type(clampRow.edit, "90")
M.PressEnter(clampRow.edit)
H.check("stored value shown", clampRow.edit:GetText(), "40")

-- A refresh keeps what is being typed.
row.edit:SetFocus()
M.Type(row.edit, "1")
row:Refresh()
H.check("typing kept", row.edit:GetText(), "1")
row.edit:ClearFocus()

-- Disabled: buttons and box locked, row dimmed; the box loses its focus.
row.edit:SetFocus()
row:SetEnabled(false)
H.check("focus dropped", row.edit:HasFocus(), false)
H.check("minus off", row.minus:IsEnabled(), false)
H.check("plus off", row.plus:IsEnabled(), false)
H.check("box off", row.edit:IsEnabled(), false)
H.checkTrue("dimmed", row:GetAlpha() < 1)
-- (The mock as the client: a disabled box takes no focus and no typing.)
local kept = value
row.edit:SetFocus()
H.check("disabled: no focus", row.edit:HasFocus(), false)
H.check("disabled: typing refused", M.Type(row.edit, "5"), false)
H.check("disabled: Enter refused", M.PressEnter(row.edit), false)
H.check("disabled: value kept", value, kept)
row:SetEnabled(true)
H.checkTrue("back on", row.plus:IsEnabled() and row:GetAlpha() == 1)
H.check("no error", #M.errors, 0)
