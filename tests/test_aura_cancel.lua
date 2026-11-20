-- cancelBuffs: right-click on the player's buffs cancels them (the
-- client's secure click); off, and everywhere else, clicks pass through.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local AC, C = ns.AuraContainers, ns.Config
local p, t = ns.Frames.player, ns.Frames.target

local function button(frame, key, isDebuff)
    local c = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
    local entry = { frame = frame, key = key, isDebuff = isDebuff, buttons = {} }
    c:AddAuraGroup("other", "HELPFUL", { initializeFrame = function(b) AC.InitButton(entry, false, b) end })
    return entry.buttons[1].button
end

H.check("off by default", C.Get("player", "cancelBuffs"), false)
local b = button(p, "buffs", false)
H.check("off: clicks pass through", b._clickEnabled, false)
H.check("off: no cancel click", b._cancelButtons, nil)

C.Set("player", "cancelBuffs", true)
b = button(p, "buffs", false)
H.check("on: buttons take the click", b._clickEnabled, true)
H.check("on: right-click cancels", b._cancelButtons, "RightButtonUp")
H.check("on: debuffs pass through", button(p, "debuffs", true)._clickEnabled, false)
H.check("on: target's buffs pass through", button(t, "buffs", false)._cancelButtons, nil)

-- Switched off again: buttons made before follow (applied by Clicks on restyle).
C.Set("player", "cancelBuffs", false)
AC.Clicks(b, p, false)
H.check("off again: no cancel click", b._cancelButtons, nil)
H.check("off again: clicks pass through", b._clickEnabled, false)
H.check("only on the player", ns.Settings.Get("cancelBuffs").only.player, true)
