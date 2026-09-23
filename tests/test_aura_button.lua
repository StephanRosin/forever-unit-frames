local M = H.M
local ns = H.LoadAddon()
local C, AuraButton = ns.Config, ns.AuraButton
C.Use({})

local parent = CreateFrame("Frame", nil, UIParent)
local buff = AuraButton.Create(parent, false)
local debuff = AuraButton.Create(parent, true)

-- Built once: icon, border, cooldown swipe, stack count above the swipe.
H.check("plain frame", buff:GetObjectType(), "Frame")
H.check("not protected", buff:IsProtected(), false)
H.check("cooldown", buff.cooldown:GetObjectType(), "Cooldown")
H.check("cooldown template", buff.cooldown._template, "CooldownFrameTemplate")
H.checkTrue("count above the swipe", buff.cover:GetFrameLevel() > buff.cooldown:GetFrameLevel())
H.check("hidden until used", buff:IsShown(), false)
-- Tooltips on hover, clicks go through to the unit frame below.
H.check("mouse on", buff._mouse, true)
H.check("clicks pass through", buff._clickEnabled, false)

-- Style: size, one-pixel border, fonts, countdown numbers.
AuraButton.Style(buff, "target", 20, true)
H.check("size", buff:GetWidth(), 20)
H.check("icon inset", select(4, buff.icon:GetPoint(1)), 1)
H.checkTrue("count has a font", buff.count:GetFont())
H.check("count size", select(2, buff.count:GetFont()), 10)
H.check("time shown", buff.cooldown._hideNumbers, false)
H.check("countdown font", select(2, buff.cooldown:GetCountdownFontString():GetFont()), 10)
AuraButton.Style(buff, "target", 20, false)
H.check("time hidden", buff.cooldown._hideNumbers, true)
AuraButton.Style(debuff, "target", 20, true)
AuraButton.Style(buff, "target", 20, true)

-- A readable buff.
local aura = { auraInstanceID = 7, icon = 136000, applications = 3, duration = 30, expirationTime = 1020,
    isHelpful = true }
H.check("shown", AuraButton.Show(buff, "target", aura, "HELPFUL"), true)
H.checkTrue("button shown", buff:IsShown())
H.check("icon", buff.icon._texture, 136000)
H.check("stacks", buff.count:GetText(), "3")
H.check("cooldown start", buff.cooldown._cooldown[1], 990)
H.check("cooldown duration", buff.cooldown._cooldown[2], 30)
H.check("buff border: the border colour", buff.border._color[1], 0)
H.check("remembers the aura", buff.auraID, 7)
H.check("remembers the unit", buff.unit, "target")
H.check("remembers the filter", buff.filter, "HELPFUL")

-- One stack shows no number; a permanent aura shows no swipe.
aura.applications, aura.duration, aura.expirationTime = 1, 0, 0
AuraButton.Show(buff, "target", aura, "HELPFUL")
H.check("single stack: no number", buff.count:GetText(), "")
H.check("permanent: no swipe", buff.cooldown._cooldown, nil)

-- Debuff borders follow the dispel type.
local function border(name)
    AuraButton.Show(debuff, "target", { auraInstanceID = 9, icon = 1, applications = 0, duration = 0,
        expirationTime = 0, dispelName = name }, "HARMFUL")
    local c = debuff.border._color
    return ("%.1f,%.1f,%.1f"):format(c[1], c[2], c[3])
end
H.check("magic", border("Magic"), "0.2,0.6,1.0")
H.check("curse", border("Curse"), "0.6,0.0,1.0")
H.check("poison", border("Poison"), "0.0,0.6,0.0")
H.check("disease", border("Disease"), "0.6,0.4,0.0")
H.check("none", border(nil), "0.8,0.0,0.0")
H.check("unknown type", border("Enrage"), "0.8,0.0,0.0")

-- Secret fields are passed to widgets or left out, never inspected.
local secret = { auraInstanceID = M.Secret(11), icon = M.Secret(136001), applications = M.Secret(4),
    duration = M.Secret(20), expirationTime = M.Secret(1030), dispelName = M.Secret("Magic") }
H.check("secret aura shown", AuraButton.Show(debuff, "target", secret, "HARMFUL"), true)
H.checkTrue("secret icon passed through", M.IsSecret(debuff.icon._texture))
H.check("no id kept", debuff.auraID, nil)

-- Test mode: a sample, no aura behind it.
AuraButton.ShowSample(debuff, { icon = "Interface\\Icons\\Spell_Shadow_Teleport", count = 2, duration = 600,
    dispel = "Curse" }, 1000)
H.check("sample icon", debuff.icon._texture, "Interface\\Icons\\Spell_Shadow_Teleport")
H.check("sample count", debuff.count:GetText(), "2")
H.check("sample swipe", debuff.cooldown._cooldown[2], 600)
H.check("sample border", ("%.1f"):format(debuff.border._color[3]), "1.0")
H.check("sample has no aura", debuff.auraID, nil)

AuraButton.Clear(debuff)
H.check("cleared", debuff:IsShown(), false)
H.check("cleared id", debuff.auraID, nil)
