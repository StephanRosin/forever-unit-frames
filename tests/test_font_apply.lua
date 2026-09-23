local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, O, L, S = ns.Config, ns.Options, ns.L, ns.Settings

H.check("font keys", table.concat(S.FONT_KEYS, ","), "fontFace,fontSize,fontOutline,fontShadow")

local function overrideFonts()
    C.Set("general", "fontSize", 14)
    C.Set("player", "fontSize", 20)
    C.Set("target", "fontFace", "Morpheus")
    C.Set("party", "fontOutline", "OUTLINE")
    C.Set("focus", "fontShadow", true)
    C.Set("player", "width", 250)
end

-- Config: every frame's font overrides go, nothing else does.
overrideFonts()
local changes = 0
ns.Listen("CONFIG_CHANGED", function() changes = changes + 1 end)
C.ClearFrameOverrides(S.FONT_KEYS)
H.check("one change event", changes, 1)
for _, scope in ipairs({ "player", "target", "targettarget", "pet", "focus", "party" }) do
    for _, key in ipairs(S.FONT_KEYS) do
        H.check(scope .. " " .. key .. " inherits", C.IsOverridden(scope, key), false)
    end
end
H.check("player now uses the general size", C.Get("player", "fontSize"), 14)
H.check("general keeps its own value", C.Get("general", "fontSize"), 14)
H.check("other overrides stay", C.Get("player", "width"), 250)
H.check("frames restyled", ns.Frames.player.texts.healthLeft._font[2], 14)

-- Options: General -> Appearance has the button under the font rows.
overrideFonts()
O.Open("general")
O.SelectTab("appearance")
local button = O.actionButtons.applyFontToFrames
H.checkTrue("button exists", button)
H.check("button text", button.text:GetText(), L.ACTION_applyFontToFrames)
local shadowRow
for i, row in ipairs(O.rows) do
    if row.key == "fontShadow" then shadowRow = i end
end
H.check("block right after the last font row", O.rows[shadowRow + 1], button:GetParent())
local click = button:GetScript("OnClick")
click(button)
H.check("first click only arms", C.IsOverridden("player", "fontSize"), true)
H.check("asks to confirm", button.text:GetText(), L.CONFIRM)
click(button)
H.check("second click applies", C.IsOverridden("player", "fontSize"), false)
H.check("target font inherits", C.Get("target", "fontFace"), C.Get("general", "fontFace"))
H.check("label back", button.text:GetText(), L.ACTION_applyFontToFrames)

-- The confirmation expires; closing the window disarms it.
click(button)
M.RunTimers()
H.check("expired", button.text:GetText(), L.ACTION_applyFontToFrames)
click(button)
O.Close()
H.check("closing disarms", button.text:GetText(), L.ACTION_applyFontToFrames)

-- Locked in combat like every other control.
O.Open("general")
O.SelectTab("appearance")
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("locked in combat", button:IsEnabled(), false)
M.FireEvent("PLAYER_REGEN_ENABLED")
H.checkTrue("unlocked after combat", button:IsEnabled())

-- Only on General: frame pages have no such button.
O.Select("player")
O.SelectTab("text")
local found = false
for _, row in ipairs(O.rows) do if row == button:GetParent() then found = true end end
H.check("not on frame pages", found, false)
