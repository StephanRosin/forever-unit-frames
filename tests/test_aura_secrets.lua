local M = H.M
local ns = H.LoadAddon()
local C, AuraButton = ns.Config, ns.AuraButton
C.Use({})

local parent = CreateFrame("Frame", nil, UIParent)
local buff = AuraButton.Create(parent, false)
local debuff = AuraButton.Create(parent, true)
AuraButton.Style(buff, "target", 20, true)
AuraButton.Style(debuff, "target", 20, true)

-- In combat the client may hand out aura data only as secrets. With a
-- readable aura instance ID the client still gives display values for it:
-- a count string, a duration object for the swipe, a dispel colour.
local aura = { auraInstanceID = 21, icon = M.Secret(136002), applications = M.Secret(5),
    duration = M.Secret(40), expirationTime = M.Secret(1030), dispelName = M.Secret("Curse"),
    dispelType = M.Secret(2) }
M.units.target = { auras = { aura } }

H.check("shown", AuraButton.Show(debuff, "target", aura, "HARMFUL"), true)
H.check("id kept", debuff.auraID, 21)
H.checkTrue("count string from the client", M.IsSecret(debuff.count:GetText()))
H.check("count string content", M.Reveal(debuff.count:GetText()), "5")
H.checkTrue("swipe from a duration object", debuff.cooldown._cooldown.object)
H.check("duration object of this aura", M.Reveal(debuff.cooldown._cooldown.object._duration), 40)
H.checkTrue("border colour passed through", M.IsSecret(debuff.border._color[1]))
H.check("border colour: curse", M.Reveal(debuff.border._color[3]), 1)
H.check("border colour: curse red part", M.Reveal(debuff.border._color[1]), 0.6)

-- The dispel curve snaps (no blending between types); types the curve
-- does not name get the "none" colour.
aura.dispelType = M.Secret(11)
AuraButton.Show(debuff, "target", aura, "HARMFUL")
H.check("bleed: none colour", M.Reveal(debuff.border._color[1]), 0.8)
aura.dispelType = M.Secret(4)
AuraButton.Show(debuff, "target", aura, "HARMFUL")
H.check("poison", M.Reveal(debuff.border._color[2]), 0.6)

-- A readable aura still uses its plain numbers (no extra client calls).
local plain = { auraInstanceID = 22, icon = 1, applications = 2, duration = 10, expirationTime = 1005 }
M.units.target.auras[2] = plain
AuraButton.Show(buff, "target", plain, "HELPFUL")
H.check("plain count", buff.count:GetText(), "2")
H.check("plain swipe", buff.cooldown._cooldown[1], 995)

-- The client refuses (auras locked for addons): the icon still shows,
-- everything the client refused is left empty.
M.auraError = true
H.check("refused: still shown", AuraButton.Show(debuff, "target", aura, "HARMFUL"), true)
H.check("refused: no count", debuff.count:GetText(), "")
H.check("refused: no swipe", debuff.cooldown._cooldown, nil)
H.check("refused: none colour", debuff.border._color[1], 0.8)
M.auraError = false

-- A secret aura instance ID is never handed back to the client.
local hidden = { auraInstanceID = M.Secret(23), icon = M.Secret(1), applications = M.Secret(3),
    duration = M.Secret(10), expirationTime = M.Secret(1005), dispelName = M.Secret("Magic") }
H.check("secret id: shown", AuraButton.Show(debuff, "target", hidden, "HARMFUL"), true)
H.check("secret id: no count", debuff.count:GetText(), "")
H.check("secret id: no swipe", debuff.cooldown._cooldown, nil)

-- Tooltips: the client's own aura tooltip, by instance ID and filter.
AuraButton.Show(debuff, "target", aura, "HARMFUL|PLAYER")
debuff:GetScript("OnEnter")(debuff)
H.check("tooltip owner", GameTooltip._owner, debuff)
H.check("debuff tooltip", M.tooltipAura.method, "SetUnitDebuffByAuraInstanceID")
H.check("tooltip unit", M.tooltipAura.unit, "target")
H.check("tooltip id", M.tooltipAura.id, 21)
H.check("tooltip filter", M.tooltipAura.filter, "HARMFUL|PLAYER")
H.checkTrue("tooltip shown", GameTooltip:IsShown())
debuff:GetScript("OnLeave")(debuff)
H.check("tooltip hidden", GameTooltip:IsShown(), false)

buff:GetScript("OnEnter")(buff)
H.check("buff tooltip", M.tooltipAura.method, "SetUnitBuffByAuraInstanceID")
buff:GetScript("OnLeave")(buff)

-- Refused in combat: no tooltip, no error.
M.auraError = true
M.tooltipAura = nil
buff:GetScript("OnEnter")(buff)
H.check("refused tooltip hidden", GameTooltip:IsShown(), false)
M.auraError = false

-- No aura behind the icon (sample, secret id): nothing to show.
AuraButton.ShowSample(buff, { icon = 1, duration = 60 }, 1000)
M.tooltipAura = nil
buff:GetScript("OnEnter")(buff)
H.check("sample: no tooltip", M.tooltipAura, nil)
H.check("sample: tooltip stays hidden", GameTooltip:IsShown(), false)

-- Leaving a button another frame owns the tooltip of changes nothing.
GameTooltip:SetOwner(parent, "ANCHOR_NONE")
GameTooltip:Show()
buff:GetScript("OnLeave")(buff)
H.checkTrue("foreign tooltip kept", GameTooltip:IsShown())
