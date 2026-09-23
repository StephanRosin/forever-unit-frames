local M = H.M
local ns = H.LoadAddon()
local W = ns.Widgets
local parent = CreateFrame("Frame", nil, UIParent)

-- Slider + edit box
local value = 100
local sl = W.Slider(parent, { label = "Width", min = 40, max = 600, step = 1,
    get = function() return value end, set = function(v) value = v; return true end })
sl:Refresh()
H.check("slider shows value", sl.slider:GetValue(), 100)
H.check("edit box shows value", sl.edit:GetText(), "100")
sl.slider:GetScript("OnValueChanged")(sl.slider, 250.4, true)
H.check("drag sets rounded value", value, 250)
sl.edit:SetText("333")
sl.edit:GetScript("OnEnterPressed")(sl.edit)
H.check("edit box commits", value, 333)
sl.edit:SetText("abc")
sl.edit:GetScript("OnEnterPressed")(sl.edit)
H.check("invalid text keeps value", value, 333)
H.check("invalid text reverts box", sl.edit:GetText(), "333")
sl.edit:SetText("9999")
sl.edit:GetScript("OnEnterPressed")(sl.edit)
H.check("out of range keeps value", value, 333)
sl:SetEnabled(false)
H.check("disabled slider", sl.slider._enabled, false)

-- Checkbox
local on = true
local cb = W.Checkbox(parent, { label = "Enabled", get = function() return on end, set = function(v) on = v; return true end })
cb:Refresh()
cb.box:GetScript("OnClick")(cb.box)
H.check("checkbox toggles", on, false)

-- Dropdown
local pick = "OUTLINE"
local dd = W.Dropdown(parent, { label = "Style",
    items = function() return { { value = "NONE", text = "None" }, { value = "OUTLINE", text = "Outline" } } end,
    get = function() return pick end, set = function(v) pick = v; return true end })
dd:Refresh()
H.check("dropdown shows current text", dd.button.text:GetText(), "Outline")
dd.button:GetScript("OnClick")(dd.button)
H.checkTrue("list opened", dd.list:IsShown())
dd.list.rows[1]:GetScript("OnClick")(dd.list.rows[1])
H.check("dropdown selects", pick, "NONE")
H.check("list closed after select", dd.list:IsShown(), false)

-- Color
local col = { 1, 0, 0, 1 }
local cw = W.Color(parent, { label = "Colour", get = function() return col end, set = function(v) col = v; return true end })
cw:Refresh()
cw.swatch:GetScript("OnClick")(cw.swatch)
H.check("picker opened with r", M.colorPicker.r, 1)
M.pickRGB, M.pickA = { 0, 0.5, 1 }, 0.4
M.colorPicker.swatchFunc()
H.check("picked g", col[2], 0.5)
H.check("picked alpha", col[4], 0.4)
M.colorPicker.cancelFunc()
H.check("cancel restores", col[1], 1)

-- Inherit marker
local over = false
local cleared = false
local inh = W.Slider(parent, { label = "Font size", min = 6, max = 32, step = 1,
    get = function() return 12 end, set = function() return true end,
    inherit = { isOverridden = function() return over end, clear = function() cleared = true end } })
inh:Refresh()
H.checkTrue("inherited marker shown", inh.inherited:IsShown())
H.check("reset hidden", inh.reset:IsShown(), false)
over = true; inh:Refresh()
H.checkTrue("reset shown when overridden", inh.reset:IsShown())
inh.reset:GetScript("OnClick")(inh.reset)
H.checkTrue("reset clears", cleared)

-- Slider details ------------------------------------------------------------
H.checkTrue("slider has a thumb texture (draggable)", sl.slider:GetThumbTexture())
local calls = 0
local quiet = W.Slider(parent, { label = "Quiet", min = 0, max = 10, step = 1,
    get = function() return 5 end, set = function() calls = calls + 1; return true end })
quiet:Refresh()
quiet.slider:GetScript("OnValueChanged")(quiet.slider, 5.2, true)
H.check("drag to the same rounded value does not set", calls, 0)
quiet.slider:GetScript("OnValueChanged")(quiet.slider, 7, false)
H.check("programmatic value change does not set", calls, 0)

local wheelValue = 10
local wheel = W.Slider(parent, { label = "Wheel", min = 0, max = 10, step = 2,
    get = function() return wheelValue end, set = function(v) wheelValue = v; return true end })
wheel:Refresh()
wheel.slider:GetScript("OnMouseWheel")(wheel.slider, -1)
H.check("wheel down steps by step", wheelValue, 8)
wheel.slider:GetScript("OnMouseWheel")(wheel.slider, 1)
wheel.slider:GetScript("OnMouseWheel")(wheel.slider, 1)
H.check("wheel clamps to max", wheelValue, 10)
local rejectWheel = W.Slider(parent, { label = "Reject", min = 0, max = 10, step = 1,
    get = function() return 3 end, set = function() return false end })
rejectWheel:Refresh()
rejectWheel.slider:GetScript("OnMouseWheel")(rejectWheel.slider, 1)
H.check("wheel shows the stored value when set is rejected", rejectWheel.edit:GetText(), "3")
wheel:SetEnabled(false)
wheel.slider:GetScript("OnMouseWheel")(wheel.slider, -1)
H.check("wheel does nothing while disabled", wheelValue, 10)

M.timers = {}
sl:SetEnabled(true)
sl.edit:SetText("abc")
sl.edit:GetScript("OnEnterPressed")(sl.edit)
local red = ns.Style.COLORS.error
H.check("invalid entry flashes border red", sl.edit.edges[1]._color[1], red[1])
H.check("red flash lasts 0.6 s", M.timers[1] and M.timers[1].sec, 0.6)
M.RunTimers()
H.check("border back to normal after flash", sl.edit.edges[1]._color[1], ns.Style.COLORS.border[1])
sl.edit:SetText("abc")
sl.edit:GetScript("OnEnterPressed")(sl.edit)
local firstFlashEnds = table.remove(M.timers, 1).fn
sl.edit:SetText("abc")
sl.edit:GetScript("OnEnterPressed")(sl.edit)
firstFlashEnds()
H.check("older flash timer does not end a newer flash", sl.edit.edges[1]._color[1], red[1])
M.RunTimers()
H.check("newer flash ends on its own timer", sl.edit.edges[1]._color[1], ns.Style.COLORS.border[1])
sl.edit:SetText("50")
sl.edit:GetScript("OnEditFocusLost")(sl.edit)
H.check("focus loss commits", value, 50)
H.check("enabled slider", sl.slider._enabled, true)
H.check("disabled edit box", (function() sl:SetEnabled(false); return sl.edit._enabled end)(), false)

-- Checkbox details ----------------------------------------------------------
H.check("checkbox is a CheckButton", cb.box:GetObjectType(), "CheckButton")
cb:Refresh()
H.check("checkbox shows state", cb.box:GetChecked(), false)
on = true; cb:Refresh()
H.check("checkbox follows get()", cb.box:GetChecked(), true)
cb.labelButton:GetScript("OnClick")(cb.labelButton)
H.check("label click toggles", on, false)
cb:SetEnabled(false)
H.check("disabled checkbox", cb.box._enabled, false)
cb.labelButton:GetScript("OnClick")(cb.labelButton)
H.check("disabled label click does nothing", on, false)

-- Dropdown details ----------------------------------------------------------
local many = {}
for i = 1, 20 do many[i] = { value = i, text = "Item " .. i } end
many[15].font = "Morpheus"
local chosen = 15
local big = W.Dropdown(parent, { label = "Many", items = function() return many end,
    get = function() return chosen end, set = function(v) chosen = v; return true end })
big:Refresh()
H.check("list is shared", big.list, dd.list)
big.button:GetScript("OnClick")(big.button)
H.check("list strata", big.list:GetFrameStrata(), "FULLSCREEN_DIALOG")
H.check("12 rows", #big.list.rows, 12)
local function rowWithText(t)
    for _, r in ipairs(big.list.rows) do if r:IsShown() and r.text:GetText() == t then return r end end
end
local current = rowWithText("Item 15")
H.checkTrue("current item visible when opened", current)
H.check("current item in accent", current and current.text._color[3], ns.Style.COLORS.accent[3])
H.check("font preview", current and current.text._font[1], ns.Media.Font("Morpheus"))
local plain = rowWithText("Item 14")
H.check("other items in default font", plain and plain.text._font[1], ns.Media.Font("Friz Quadrata"))
big.list:GetScript("OnMouseWheel")(big.list, 1)
big.list:GetScript("OnMouseWheel")(big.list, 1)
H.check("wheel scrolls up", big.list.rows[1].text:GetText(), "Item 7")
for _ = 1, 30 do big.list:GetScript("OnMouseWheel")(big.list, -1) end
H.check("wheel stops at the end", big.list.rows[12].text:GetText(), "Item 20")
big.button:GetScript("OnClick")(big.button)
H.check("button click again closes", big.list:IsShown(), false)

dd.button:GetScript("OnClick")(dd.button)
H.check("only as many rows as items", dd.list.rows[3]:IsShown(), false)
big.button:GetScript("OnClick")(big.button)
H.check("opening another dropdown takes over the list", big.list.owner, big)
H.checkTrue("still one list shown", big.list:IsShown())
H.check("rows re-used for the new items", big.list.rows[3]:IsShown(), true)
W.CloseList()

dd.button:GetScript("OnClick")(dd.button)
H.check("other keys go on to the game", M.PressKey(dd.list, "W"), true)
H.checkTrue("other keys leave the list open", dd.list:IsShown())
H.check("ESC is not passed on (window stays open)", M.PressKey(dd.list, "ESCAPE"), false)
H.check("ESC closes list", dd.list:IsShown(), false)
H.check("closed list takes no keyboard input", dd.list._keyboard, false)

dd.button:GetScript("OnClick")(dd.button)
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat start closes list", dd.list:IsShown(), false)
dd.button:GetScript("OnClick")(dd.button)
H.check("list does not open in combat", dd.list:IsShown(), false)
M.combat = false

dd.button:GetScript("OnClick")(dd.button)
dd:GetScript("OnHide")(dd)
H.check("owner hide closes list", dd.list:IsShown(), false)

dd.button:GetScript("OnClick")(dd.button)
big:GetScript("OnHide")(big)
H.checkTrue("hiding another row keeps list", dd.list:IsShown())
dd.button._mouseOver = true
M.FireEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
H.checkTrue("click on own button leaves toggling to OnClick", dd.list:IsShown())
dd.button._mouseOver = false
M.FireEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
H.check("click outside closes list", dd.list:IsShown(), false)

dd.button:GetScript("OnClick")(dd.button)
dd:SetEnabled(false)
H.check("disabling owner closes list", dd.list:IsShown(), false)
H.check("disabled dropdown button", dd.button._enabled, false)

-- Color details ---------------------------------------------------------------
local col2 = { 0.2, 0.4, 0.6, 0.8 }
local sets = 0
local cw2 = W.Color(parent, { label = "Colour 2", get = function() return col2 end,
    set = function(v) col2 = v; sets = sets + 1; return true end })
cw2:Refresh()
H.check("swatch shows colour", cw2.swatch.color._color[2], 0.4)
M.pickA = 0.1 -- stale alpha from an earlier use of the picker
cw2.swatch:GetScript("OnClick")(cw2.swatch)
H.check("picker opened with opacity", M.colorPicker.opacity, 0.8)
H.checkTrue("picker has opacity", M.colorPicker.hasOpacity)
H.check("opening the picker does not write settings", sets, 0)
M.pickRGB, M.pickA = { 0.9, 0.9, 0.9 }, 0.5
M.colorPicker.opacityFunc()
H.check("opacity callback sets alpha", col2[4], 0.5)
M.colorPicker.cancelFunc(M.colorPicker.previousValues)
H.check("cancel restores all channels", col2[1] .. "," .. col2[4], "0.2,0.8")
sets = 0
cw2.swatch:GetScript("OnClick")(cw2.swatch)
M.colorPicker.cancelFunc(M.colorPicker.previousValues)
H.check("cancel without a change does not write settings", sets, 0)

-- Button --------------------------------------------------------------------
local clicks = 0
local btn = W.Button(parent, { text = "Apply", width = 120, onClick = function() clicks = clicks + 1 end })
H.check("button text", btn.text:GetText(), "Apply")
H.check("button width", btn:GetWidth(), 120)
btn:GetScript("OnClick")(btn)
H.check("button click", clicks, 1)
btn:GetScript("OnEnter")(btn)
H.check("hover accent", btn.text._color[3], ns.Style.COLORS.accent[3])
btn:GetScript("OnLeave")(btn)
H.check("leave restores text", btn.text._color[3], ns.Style.COLORS.text[3])
btn:SetEnabled(false)
H.check("button disabled natively", btn._enabled, false)
H.check("disabled button muted", btn.text._color[3], ns.Style.COLORS.muted[3])
btn:SetEnabled(true)
H.check("button enabled again", btn._enabled, true)
H.check("enabled button text", btn.text._color[3], ns.Style.COLORS.text[3])

-- TextArea ------------------------------------------------------------------
local area = W.TextArea(parent, { width = 400, height = 120, readOnly = true })
area:SetText("FUF1:abc")
H.check("text area text", area:GetText(), "FUF1:abc")
area.edit:GetScript("OnEditFocusGained")(area.edit)
H.check("read-only selects all on focus (no range = whole text)",
    area.edit._highlighted and #area.edit._highlighted, 0)
area.edit:SetText("FUF1:abcX")
area.edit:GetScript("OnTextChanged")(area.edit, true)
H.check("read-only reverts typing", area:GetText(), "FUF1:abc")
local editable = W.TextArea(parent, { width = 400, height = 120 })
editable:SetText("x")
H.check("editable does not select all on focus", editable.edit:GetScript("OnEditFocusGained"), nil)
H.check("editable does not undo typing", editable.edit:GetScript("OnTextChanged"), nil)
editable.edit:SetText("typed")
H.check("editable returns typed text", editable:GetText(), "typed")

-- Header --------------------------------------------------------------------
local hd = W.Header(parent, "Font")
H.check("header text", hd.label:GetText(), "Font")
H.check("header size", hd.label._font[2], 14)
hd:Refresh(); hd:SetEnabled(false)
H.check("header line is accent", hd.line._color[3], ns.Style.COLORS.accent[3])
