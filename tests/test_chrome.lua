-- The windows' shared parts (Options/Chrome.lua): title bar, close cross,
-- footer, hover paint and the two-click confirm button.
local M = H.M
local ns = H.LoadAddon()
local Chrome, COLORS, L = ns.Chrome, ns.Style.COLORS, ns.L

local function kids(w) return rawget(w, "_children") or {} end

-- Title bar: across the top, 32 tall, a fill and a line under it, the
-- title 16 px in from the left; the sub-title muted, 11, right of it.
local frame = CreateFrame("Frame", nil, UIParent)
local closed = 0
local bar = Chrome.TitleBar(frame, { title = "Title", sub = "Sub", onClose = function() closed = closed + 1 end })
H.check("bar height", bar:GetHeight(), Chrome.TITLE_H)
H.check("bar point 1", bar:GetPoint(1), "TOPLEFT")
H.check("bar point 2", bar:GetPoint(2), "TOPRIGHT")
H.check("fill, line, title, sub, cross", #kids(bar), 5)
H.check("line under it", kids(bar)[2]:GetPoint(1), "BOTTOMLEFT")
H.check("title", bar.title:GetText(), "Title")
H.check("title size", select(2, bar.title:GetFont()), 16)
H.check("sub", bar.sub:GetText(), "Sub")
H.check("sub size", select(2, bar.sub:GetFont()), 11)
H.check("sub colour", bar.sub._color[1], COLORS.muted[1])
local _, rel, relPoint, x, y = bar.sub:GetPoint(1)
H.check("sub beside the title", rel == bar.title and relPoint .. " " .. x .. " " .. y, "BOTTOMRIGHT 8 1")
-- The close cross: two crossed lines, 32 square at the bar's right end.
local cross = bar.close
H.check("cross size", cross:GetWidth() .. "x" .. cross:GetHeight(), "32x32")
H.check("cross at the right", select(3, cross:GetPoint(1)), "RIGHT")
H.check("two lines", #cross.lines, 2)
H.check("crossed", cross.lines[1]._rotation, -cross.lines[2]._rotation)
cross:GetScript("OnClick")(cross)
H.check("cross calls onClose", closed, 1)

-- Dragging moves the frame; onDragStop runs after the move.
local order = {}
frame.StartMoving = function() order[#order + 1] = "start" end
frame.StopMovingOrSizing = function() order[#order + 1] = "stop" end
local saved = Chrome.TitleBar(frame, { onDragStop = function() order[#order + 1] = "saved" end })
saved:GetScript("OnDragStart")(saved)
saved:GetScript("OnDragStop")(saved)
H.check("drag order", table.concat(order, ","), "start,stop,saved")

-- Without options: no sub-title, no cross; line = false: no line;
-- titleSize.
local plain = Chrome.TitleBar(frame, { line = false, titleSize = 14 })
H.check("plain: fill and title only", #kids(plain), 2)
H.check("plain: no sub", plain.sub, nil)
H.check("plain: no cross", plain.close, nil)
H.check("plain: title size", select(2, plain.title:GetFont()), 14)
H.check("plain: no text", plain.title:GetText(), nil)
local later = Chrome.TitleBar(frame, { sub = true })
H.check("sub = true: made, no text yet", later.sub ~= nil and later.sub:GetText(), nil)

-- Footer: along the bottom, 40 tall, a line on top unless line = false.
local footer = Chrome.Footer(frame)
H.check("footer height", footer:GetHeight(), Chrome.FOOTER_H)
H.check("footer point", footer:GetPoint(1), "BOTTOMLEFT")
H.check("footer: fill and line", #kids(footer), 2)
H.check("footer line on top", kids(footer)[2]:GetPoint(1), "TOPLEFT")
H.check("footer without line", #kids(Chrome.Footer(frame, { line = false })), 1)

-- Hover paint.
local b = CreateFrame("Button", nil, frame)
b.text = ns.Style.Text(b, 12, "muted")
Chrome.Hoverable(b, "muted")
b:GetScript("OnEnter")(b)
H.check("hover: text colour", b.text._color[1], COLORS.text[1])
b:GetScript("OnLeave")(b)
H.check("leave: idle colour", b.text._color[1], COLORS.muted[1])
b.selected = true
ns.Style.Paint(b.text, "accent")
b:GetScript("OnEnter")(b)
H.check("selected: kept on hover", b.text._color[1], COLORS.accent[1])
b.hover = frame:CreateTexture()
b.hover:Hide()
b:GetScript("OnEnter")(b)
H.check("hover fill shown", b.hover:IsShown(), true)
b:GetScript("OnLeave")(b)
H.check("hover fill hidden", b.hover:IsShown(), false)

-- Confirm button: the first click arms (L.CONFIRM, error colour), the
-- second runs; unused, it disarms after 3 s and onDisarm runs.
local runs, disarms = 0, 0
local confirm = Chrome.ConfirmButton(frame, "Reset", function() runs = runs + 1 end, nil, nil,
    function() disarms = disarms + 1 end)
H.check("confirm width", confirm:GetWidth(), 160)
local function click() confirm:GetScript("OnClick")(confirm) end
click()
H.check("armed text", confirm.text:GetText(), L.CONFIRM)
H.check("armed colour", confirm.text._color[1], COLORS.error[1])
H.check("not run yet", runs, 0)
click()
H.check("second click runs", runs, 1)
H.check("text back", confirm.text:GetText(), "Reset")
H.check("ran: no onDisarm", disarms, 0)
click()
M.RunTimers()
H.check("timed out: disarmed", confirm.text:GetText(), "Reset")
H.check("timed out: onDisarm", disarms, 1)
H.check("timed out: not run", runs, 1)
click()
confirm.Disarm()
H.check("Disarm: onDisarm", disarms, 2)
confirm.Disarm()
H.check("Disarm unarmed: nothing", disarms, 2)
-- armedText; needed() false runs at once.
local quick = Chrome.ConfirmButton(frame, "Go", function() runs = runs + 1 end, "Sure?", function() return false end)
quick:GetScript("OnClick")(quick)
H.check("not needed: runs at once", runs, 2)
local worded = Chrome.ConfirmButton(frame, "Go", function() end, "Sure?")
worded:GetScript("OnClick")(worded)
H.check("armed text given", worded.text:GetText(), "Sure?")
