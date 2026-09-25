local _, ns = ...

-- Totem icons of the player frame: one per totem slot (MAX_TOTEMS), in a
-- row that hangs from the player's block like an aura group.
--
-- Our own icons, not Blizzard's totem frame: that frame is a managed frame
-- of the concealed PlayerFrame, and every time it shows (a totem dropped
-- in combat included) Blizzard's frame manager re-parents it into the
-- PlayerFrame's container and clears its anchors. Keeping it elsewhere
-- would take an addon-written field in Blizzard's code path, which taints
-- that path.
--
-- Each slot has two parts at the same place:
-- * art: a plain aura-style icon (Elements/AuraButton.lua) with the swipe
--   and the client's countdown numbers. Plain, so it follows the totems
--   at any time, combat included.
-- * click: an invisible SecureActionButtonTemplate button whose right
--   click runs the secure "destroytotem" action for its "totem-slot"
--   (SecureTemplates.lua); DestroyTotem is protected. Secure buttons can
--   only be shown, hidden, moved or sized out of combat: out of combat a
--   click area shows while its slot holds a totem. A shaman drops totems
--   in combat, so as combat begins (before lockdown) all four slots become
--   clickable; after combat they follow the totems again.
--
-- Totem data may be secret (SecretWhenTotemSlotSecret: combat, encounter,
-- challenge mode or PvP restrictions). Secrets are only handed to widgets:
-- the icon to SetTexture, "has a totem" to SetAlphaFromBoolean, the time
-- through the slot's duration object (GetTotemDuration). Slots are shown
-- in a fixed order (Blizzard's priorities), so nothing moves in combat.
local Totems = { name = "Totems" }
ns.Totems = Totems

local Config, Secrets, Pixel, AuraButton = ns.Config, ns.Secrets, ns.Pixel, ns.AuraButton

Totems.SCOPE = "player"

-- Test mode samples, one per slot: totem icons Blizzard's own files have.
Totems.SAMPLES = {
    { icon = "Interface\\Icons\\Spell_Nature_StoneSkinTotem", duration = 120 },
    { icon = "Interface\\Icons\\Spell_Fire_SearingTotem", duration = 60 },
    { icon = "Interface\\Icons\\INV_Spear_04", duration = 300 },
    { icon = "Interface\\Icons\\Spell_Nature_Windfury", duration = 180 },
}

-- Out of combat or in combat (between PLAYER_REGEN_DISABLED and
-- PLAYER_REGEN_ENABLED): click areas are only changed out of it.
local fighting = false

local function playerClass()
    local _, class = UnitClass("player")
    if Secrets.IsSecret(class) then return nil end
    return class
end

-- The slots in the order Blizzard's totem frame shows them: a shaman's
-- earth, fire, water, air; everyone else's by number.
function Totems.Order(class)
    local count = MAX_TOTEMS or 4
    local priorities = (class == "SHAMAN" and SHAMAN_TOTEM_PRIORITIES) or STANDARD_TOTEM_PRIORITIES or {}
    local order = {}
    for i = 1, count do order[i] = priorities[i] or i end
    return order
end

-- A slot known to be empty (active == false) gets no tooltip; an unknown
-- (secret) one gets the client's.
local function showTooltip(self)
    if self.sample or self.totemInfo.active == false then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    if not pcall(GameTooltip.SetTotem, GameTooltip, self.totemSlot) then GameTooltip:Hide() end
end

local function hideTooltip(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

-- Every mouse button but the right one goes through a click area to the
-- world below. Allowed for addons out of combat (IsProtectedFunction and
-- HasRestrictions in SimpleScriptRegionAPIDocumentation.lua, like Show);
-- a client that refuses leaves the area catching every button.
Totems.PASS_THROUGH = { "LeftButton", "MiddleButton", "Button4", "Button5" }

local function newSlot(holder, slot)
    local info = { slot = slot }
    local art = AuraButton.Create(holder, false)
    art.totemSlot, art.totemInfo = slot, info
    art:SetScript("OnEnter", showTooltip)
    art:SetScript("OnLeave", hideTooltip)
    local click = CreateFrame("Button", nil, holder, "SecureActionButtonTemplate")
    click.totemSlot, click.totemInfo = slot, info
    pcall(click.SetPassThroughButtons, click, unpack(Totems.PASS_THROUGH))
    -- Secure mouse presses act on the up stroke (SecureActionButton_OnClick).
    click:RegisterForClicks("RightButtonUp")
    click:SetAttribute("*type2", "destroytotem")
    click:SetAttribute("*totem-slot*", slot)
    click:HookScript("OnEnter", showTooltip)
    click:HookScript("OnLeave", hideTooltip)
    click:Hide()
    info.art, info.click = art, click
    return info
end

-- Built with the frame, out of combat. Other frames get nothing.
function Totems.Build(frame)
    if frame.key ~= Totems.SCOPE then return end
    local class = playerClass()
    local holder = CreateFrame("Frame", nil, frame)
    -- Only a shaman's class uses totems: unknown (secret) slots are armed
    -- for it alone.
    local t = { holder = holder, slots = {}, shaman = class == "SHAMAN" }
    for i, slot in ipairs(Totems.Order(class)) do t.slots[i] = newSlot(holder, slot) end
    frame.totems = t
end

local function enabled() return Config.Get(Totems.SCOPE, "totemsEnabled") end

-- Out of combat only: the click areas follow the slots. A slot whose state
-- is unknown (secret) stays clickable for a shaman. In test mode none is:
-- a real totem's area would sit over a sample icon.
local function syncClicks(t)
    if fighting or InCombatLockdown() then return end
    local on = enabled() and not t.preview
    for _, s in ipairs(t.slots) do
        s.click:SetShown(on and (s.active == true or (s.active == nil and t.shaman)))
    end
end

-- Secure parts: size, anchors and visibility of the row and the click
-- areas. Out of combat only.
local function layout(frame)
    local t, scope = frame.totems, frame.key
    local size = Pixel.Snap(Config.Get(scope, "totemsSize"))
    local spacing = Pixel.Snap(Config.Get(scope, "totemsSpacing"))
    local holder, n = t.holder, #t.slots
    holder:SetSize(n * size + (n - 1) * spacing, size)
    holder:SetFrameLevel(frame:GetFrameLevel() + ns.Auras.LEVELS)
    local region = frame.unitBox or frame
    local x, y = ns.Auras.AnchorOffset(frame, "totems", region)
    holder:ClearAllPoints()
    holder:SetPoint(Config.Get(scope, "totemsPoint"), region, Config.Get(scope, "totemsFramePoint"), x, y)
    for i, s in ipairs(t.slots) do
        local offset = (i - 1) * (size + spacing)
        AuraButton.Style(s.art, scope, size, true)
        s.art:ClearAllPoints()
        s.art:SetPoint("TOPLEFT", holder, "TOPLEFT", offset, 0)
        s.click:ClearAllPoints()
        s.click:SetPoint("TOPLEFT", holder, "TOPLEFT", offset, 0)
        s.click:SetSize(size, size)
        -- Above the icon, its swipe and its count cover.
        s.click:SetFrameLevel(s.art:GetFrameLevel() + 3)
    end
    holder:SetShown(enabled())
    syncClicks(t)
end

-- The swipe: readable times, else the slot's duration object (guarded),
-- else none.
local function durationObject(art, slot)
    art.cooldown:SetCooldownFromDurationObject(GetTotemDuration(slot), true)
end

local function showDuration(art, slot, start, duration)
    local s, d = Secrets.Number(start), Secrets.Number(duration)
    if s and d then
        art.cooldown:SetCooldown(s, d)
    elseif not pcall(durationObject, art, slot) then
        art.cooldown:Clear()
    end
end

-- One slot from the client's data. Returns true (a totem), false (none)
-- or nil (unknown: the values are secret).
local function showSlot(s)
    local art, slot = s.art, s.slot
    art.sample = nil
    local ok, have, _, start, duration, icon = pcall(GetTotemInfo, slot)
    if ok and Secrets.IsSecret(have) then
        art.icon:SetTexture(icon)
        showDuration(art, slot, start, duration)
        art:Show()
        -- An empty slot is transparent; without the call it stays visible.
        if not pcall(art.SetAlphaFromBoolean, art, have, 1, 0) then art:SetAlpha(1) end
        return nil
    end
    -- Blizzard's totem frame shows no totem without a duration.
    local d = Secrets.Number(duration)
    if not ok or have ~= true or (d ~= nil and d <= 0) then
        AuraButton.Clear(art)
        return false
    end
    art.icon:SetTexture(icon)
    showDuration(art, slot, start, duration)
    art:SetAlpha(1)
    art:Show()
    return true
end

-- When the samples of this test mode session started.
local sampleStart

local function showSample(s, i)
    AuraButton.ShowSample(s.art, Totems.SAMPLES[(i - 1) % #Totems.SAMPLES + 1], sampleStart)
    s.art:SetAlpha(1)
    s.art.sample = true
end

-- Any time, combat included: the icons follow the totems (or the samples).
function Totems.Refresh(frame)
    local t = frame.totems
    if not t then return end
    for i, s in ipairs(t.slots) do
        if t.preview then
            showSample(s, i)
        else
            s.active = showSlot(s)
        end
    end
    syncClicks(t)
end

function Totems.Style(frame)
    if not frame.totems then return end
    ns.AfterCombat("totemsLayout", function() layout(frame) end)
    Totems.Refresh(frame)
end

function Totems.Update(frame)
    Totems.Refresh(frame)
end

-- Test mode: sample totems for every class (so anyone can set the row
-- up; turning totems off hides them), released when it ends.
function Totems.Preview(frame, on)
    local t = frame.totems
    if not t then return end
    if on then sampleStart = sampleStart or GetTime() else sampleStart = nil end
    t.preview = on or nil
    Totems.Refresh(frame)
end

local function playerTotems()
    local frame = ns.Frames.player
    return frame, frame and frame.totems
end

ns.On("PLAYER_TOTEM_UPDATE", function()
    local frame = playerTotems()
    if frame then Totems.Refresh(frame) end
end)

-- Usually fires before lockdown takes effect (Options/TestMode.lua relies
-- on the same): the last moment a shaman's empty slots can be made
-- clickable for the fight.
ns.On("PLAYER_REGEN_DISABLED", function()
    fighting = true
    local _, t = playerTotems()
    if not t or not t.shaman or not enabled() or InCombatLockdown() then return end
    for _, s in ipairs(t.slots) do s.click:Show() end
end)

-- Combat is over: the totems are read again (data that was secret may be
-- readable now, without a totem event), and once more a frame later in
-- case the client still hands out secrets at this moment.
local function afterCombat()
    local frame = playerTotems()
    if frame then Totems.Refresh(frame) end
end

ns.On("PLAYER_REGEN_ENABLED", function()
    fighting = false
    afterCombat()
    C_Timer.After(0, afterCombat)
end)

ns.RegisterElement(Totems)
