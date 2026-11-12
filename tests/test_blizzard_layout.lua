-- General > Frames & addon: our frames to Blizzard's Edit Mode places
-- (top-left corner on top-left corner), and back.
local M = H.M
local ns = H.LoadAddon()
local blizzard = CreateFrame("Button", "PlayerFrame", UIParent)
function blizzard:GetLeft() return -300 end
function blizzard:GetTop() return 100 end
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, O, L, B = ns.Config, ns.Options, ns.L, ns.Blizzard

-- Concealed: under the hidden parent, where it is read from too.
local hidden = blizzard:GetParent()
H.checkTrue("concealed", hidden ~= UIParent)
local x0, y0 = C.Get("player", "x"), C.Get("player", "y")
local tx0 = C.Get("target", "x")
local w, h = ns.Single.Size("player")

O.Open("general")
O.SelectTab("frames")
local take, undo = O.actionButtons.positionsFromBlizzard, O.actionButtons.positionsUndo
H.checkTrue("take button", take)
H.checkTrue("undo button", undo)
H.check("take label", take.text:GetText(), L.ACTION_positionsFromBlizzard)
local function confirm(button)
    local click = button:GetScript("OnClick")
    click(button)
    click(button)
end

confirm(take)
H.check("player x: corner on corner", C.Get("player", "x"), math.floor(-300 + w / 2 + 0.5))
H.check("player y: corner on corner", C.Get("player", "y"), math.floor(100 - h / 2 + 0.5))
H.check("no Blizzard frame, no move", C.Get("target", "x"), tx0)
H.check("still concealed", blizzard:GetParent(), hidden)

confirm(undo)
H.check("undo x", C.Get("player", "x"), x0)
H.check("undo y", C.Get("player", "y"), y0)
H.check("nothing left to undo", B.UndoLayout(), false)

H.check("one frame moved", B.TakeLayout(), 1)
-- Off frames stay where they are.
B.UndoLayout()
C.Set("player", "enabled", false)
H.check("off: nothing moved", B.TakeLayout(), 0)
H.check("no errors", #M.errors, 0)
