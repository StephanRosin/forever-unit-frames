-- A container's button gets our look and hands its regions to the client.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local AC, AuraButton, C = ns.AuraContainers, ns.AuraButton, ns.Config
local t = ns.Frames.target

local c = CreateFrame("AuraContainer", nil, t, "CustomAuraContainerTemplate")
local entry = { frame = t, key = "debuffs", isDebuff = true, buttons = {} }
c:AddAuraGroup("own", "HARMFUL|PLAYER", { initializeFrame = function(b) AC.InitButton(entry, true, b) end })
c:AddAuraGroup("other", "HARMFUL|!PLAYER", { initializeFrame = function(b) AC.InitButton(entry, false, b) end })
H.check("every button recorded", #entry.buttons, 2 * M.AURA_BATCH)
local own, other = entry.buttons[1], entry.buttons[M.AURA_BATCH + 1]
H.check("own recorded as own", own.own, true)
H.check("other recorded as other", other.own, false)
local b = other.button
H.check("record holds the button", b, c:GetAuraGroupFrame("other", 1))

-- Our regions, registered with the client.
H.check("icon registered", b._icon, b.icon)
H.check("swipe registered", b._durationCooldown, b.cooldown)
H.check("count registered", b._applicationCount, b.count)
H.check("count above the swipe", b.cover:GetFrameLevel() > b.cooldown:GetFrameLevel(), true)
H.check("icon cropped", b.icon._texCoord[1], 0.08)
H.check("one dispel texture", #b._dispelTextures, 1)
local dispel = b._dispelTextures[1]
H.check("border is the dispel texture", dispel.texture, b.border)
H.check("keeps our texture", dispel.options.style, Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset)
H.check("no type: NONE colour", dispel.options.showWithoutDispelType, true)
H.check("our colour curve", dispel.options.customDispelColorCurve, AuraButton.DispelCurve())
H.check("tooltip below right", b._tooltipAnchor[1], "ANCHOR_BOTTOMRIGHT")
H.check("clicks pass through", b._clickEnabled, false)

-- Look: sizes per group, fonts, time left.
H.check("other size", b:GetWidth(), C.Get("target", "debuffsSize"))
H.check("own size", own.button:GetWidth(), C.Get("target", "debuffsOwnSize"))
H.checkTrue("count font", b.count:GetFont())
H.check("time left shown", b.cooldown._hideNumbers, false)

-- Buffs: no dispel texture, the plain border colour.
local buffEntry = { frame = t, key = "buffs", isDebuff = false, buttons = {} }
c:AddAuraGroup("buffs", "HELPFUL", { initializeFrame = function(button) AC.InitButton(buffEntry, false, button) end })
local buff = buffEntry.buttons[1].button
H.check("buff: no dispel texture", #buff._dispelTextures, 0)
H.check("buff border colour", buff.border._color[1], C.Get("target", "borderColor")[1])

-- Soft outline: the count the client writes gets the plain outline.
C.Set("general", "fontOutline", "SOFT")
local soft = { frame = t, key = "debuffs", isDebuff = true, buttons = {} }
c:AddAuraGroup("soft", "HARMFUL", { initializeFrame = function(button) AC.InitButton(soft, false, button) end })
local sb = soft.buttons[1].button
H.check("plain outline", select(3, sb.count:GetFont()), "OUTLINE")
H.check("no copies of the count", sb.count.softCopies, nil)
-- Our own icons keep the soft outline.
local plainButton = AuraButton.Create(UIParent, false)
AuraButton.Style(plainButton, "target", 20, true)
H.checkTrue("own icons: soft copies", plainButton.count.softCopies)
C.ResetAll()

-- A batch made in combat is set up the same way (before it is locked).
M.combat = true
M.GrowAuraGroup(c, "other")
M.combat = false
H.check("combat batch recorded", #entry.buttons, 3 * M.AURA_BATCH)
H.check("combat batch registered", entry.buttons[#entry.buttons].button._icon, entry.buttons[#entry.buttons].button.icon)
