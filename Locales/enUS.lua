local _, ns = ...

-- Missing keys fall back to the key itself, so an untranslated string is
-- visible in-game instead of raising an error.
ns.L = setmetatable({}, { __index = function(_, key) return key end })
local L = ns.L

L.ADDON_NAME = "Forever Unit Frames"

L.SETTING_fontFace = "Font"
L.SETTING_fontSize = "Font size"
L.SETTING_fontOutline = "Font style"
L.SETTING_fontShadow = "Font shadow"
L.SETTING_barTexture = "Bar texture"
L.SETTING_backgroundColor = "Background color"
L.SETTING_borderSize = "Border size"
L.SETTING_borderColor = "Border color"
L.SETTING_healthColorMode = "Health color"
L.SETTING_healthColor = "Static health color"
L.SETTING_enabled = "Enabled"
L.SETTING_width = "Width"
L.SETTING_height = "Height"
L.SETTING_healthPercent = "Health bar height (%)"
L.SETTING_powerPercent = "Power bar height (%)"
L.SETTING_powerEnabled = "Show power bar"
L.SETTING_x = "Position X"
L.SETTING_y = "Position Y"
L.SETTING_textHealthLeft = "Health bar, left text"
L.SETTING_textHealthRight = "Health bar, right text"
L.SETTING_textPowerLeft = "Power bar, left text"
L.SETTING_textPowerRight = "Power bar, right text"

L.MACRO_FULL = "Macro backup skipped: no free character macro slot."
L.MACRO_FOREIGN = "Macro backup skipped: a macro slot is used by another macro."
L.MACRO_COMBAT = "Macro backup skipped: cannot edit macros in combat."
L.MACRO_FRAME_OPEN = "Macro backup skipped: close the macro window first."
L.MACRO_TOO_LONG = "Macro backup skipped: profile too large to fit in macros."
