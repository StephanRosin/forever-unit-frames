local _, ns = ...

-- The player's weapon enchants (poisons, stones, Rockbiter Weapon ...) as
-- icons before the buffs, like Blizzard's own buff frame.
--
-- They are not auras. Forever reports them only through
-- C_Item.GetWeaponEnchantInfo(slot), a list of enchants per weapon slot;
-- the older GetWeaponEnchantInfo() and C_PaperDollInfo.
-- GetTemporaryEnchantmentInfo() said "none" with Rockbiter Weapon on
-- (checked in game), and so did the aura container's item enchantments,
-- which ask the latter. Older clients without C_Item.GetWeaponEnchantInfo
-- fall back to GetWeaponEnchantInfo().
--
-- Plain buttons (Elements/AuraButton.lua), at the buffs' anchor, size and
-- look; the buff container moves on by as many icons
-- (AuraContainers.Lead). Nothing here is protected, so it all works in
-- combat. Tooltip: the weapon's own, which lists the enchant.
local WeaponEnchants = {}
ns.WeaponEnchants = WeaponEnchants

local Config = ns.Config

-- Enum.WeaponSlot -> inventory slot (main hand, off hand, ranged).
WeaponEnchants.INVENTORY_SLOT = { [0] = 16, [1] = 17, [2] = 18 }
-- How often the icons are checked: an enchant can run out.
WeaponEnchants.INTERVAL = 1

local function now() return GetTime() end

-- The active enchants, in slot order: { slot, invSlot, icon, charges,
-- expires (GetTime seconds or nil), id }.
function WeaponEnchants.Read()
    local list = {}
    if C_Item and C_Item.GetWeaponEnchantInfo then
        for slot = 0, 2 do
            local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, slot)
            if ok and type(enchants) == "table" then
                for _, e in ipairs(enchants) do
                    if e.hasEnchant then
                        local invSlot = WeaponEnchants.INVENTORY_SLOT[slot]
                        local left = tonumber(e.timeLeft) or 0
                        local icon = e.enchantIconID
                        if not icon or icon == 0 then icon = GetInventoryItemTexture("player", invSlot) end
                        list[#list + 1] = {
                            slot = slot, invSlot = invSlot, icon = icon, charges = e.charges or 0,
                            expires = left > 0 and now() + left / 1000 or nil, id = e.enchantID,
                        }
                    end
                end
            end
        end
        return list
    end
    if not GetWeaponEnchantInfo then return list end
    local ok, hasMain, mainMs, mainCharges, mainID, hasOff, offMs, offCharges, offID, hasRanged, rangedMs,
        rangedCharges, rangedID = pcall(GetWeaponEnchantInfo)
    if not ok then return list end
    local old = {
        { hasMain, mainMs, mainCharges, mainID }, { hasOff, offMs, offCharges, offID },
        { hasRanged, rangedMs, rangedCharges, rangedID },
    }
    for slot = 0, 2 do
        local e = old[slot + 1]
        if e[1] then
            local invSlot = WeaponEnchants.INVENTORY_SLOT[slot]
            local left = tonumber(e[2]) or 0
            list[#list + 1] = {
                slot = slot, invSlot = invSlot, icon = GetInventoryItemTexture("player", invSlot),
                charges = e[3] or 0, expires = left > 0 and now() + left / 1000 or nil, id = e[4],
            }
        end
    end
    return list
end

-- Shown on this frame at all?
function WeaponEnchants.Wanted(frame)
    if frame.key ~= "player" or frame.pretend then return false end
    local group = frame.auras and frame.auras.buffs
    return group ~= nil and group.enabled and Config.Get("player", "weaponEnchants") == true
        and frame.auraContainers ~= nil
end

-- The tooltip belongs to the screen and follows the cursor: the icons carry
-- their holder's untrusted-layout aspect, and the client refuses them as
-- owners (the tooltip, anchored to one, would inherit it).
local tooltipFrom

local function onEnter(self)
    if not self.invSlot then return end
    GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
    tooltipFrom = self
    if not pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", self.invSlot) then GameTooltip:Hide() end
end

local function onLeave(self)
    if tooltipFrom == self then
        tooltipFrom = nil
        if GameTooltip:IsOwned(UIParent) then GameTooltip:Hide() end
    end
end

-- The icons may hang from an aura container (buffs anchored to the
-- debuffs): that needs the untrusted-layout aspect, which children take
-- from their parent. So they live on a holder with that template.
WeaponEnchants.HOLDER_TEMPLATE = "DisableUntrustedLayoutScriptsTemplate"

local function holder(frame)
    if not frame.enchantHolder then
        local ok, h = pcall(CreateFrame, "Frame", nil, frame, WeaponEnchants.HOLDER_TEMPLATE)
        if not ok then h = CreateFrame("Frame", nil, frame) end
        h:SetAllPoints(frame)
        frame.enchantHolder = h
    end
    return frame.enchantHolder
end

local function button(frame, i)
    frame.enchantButtons = frame.enchantButtons or {}
    local b = frame.enchantButtons[i]
    if b then return b end
    b = ns.AuraButton.Create(holder(frame), false)
    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", onLeave)
    frame.enchantButtons[i] = b
    return b
end

-- Size, look and place of icon i: at the buffs' anchor, one step on per
-- icon along their growth direction.
local STEP = { RIGHT = { 1, 0 }, LEFT = { -1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }

local function place(frame, b, i)
    local group = frame.auras.buffs
    local scope = frame.key
    -- As high as the buff container.
    holder(frame):SetFrameLevel(frame:GetFrameLevel() + ns.Auras.LEVELS)
    ns.AuraButton.Style(b, scope, group.size, group.showTime)
    local region = ns.Auras.AnchorRegion(frame, "buffs", true)
    local x, y = ns.Auras.AnchorOffset(frame, "buffs", region)
    local d = STEP[group.primary] or STEP.RIGHT
    local step = (i - 1) * (group.size + group.spacing)
    b:ClearAllPoints()
    b:SetPoint(Config.Get(scope, "buffsPoint"), region, Config.Get(scope, "buffsFramePoint"),
        x + d[1] * step, y + d[2] * step)
end

local function show(b, e)
    local changed = b.enchantID ~= e.id or b.invSlot ~= e.invSlot
        or (b.expires or 0) - (e.expires or 0) > 1 or (e.expires or 0) - (b.expires or 0) > 1
    b.invSlot, b.enchantID = e.invSlot, e.id
    b.icon:SetTexture(e.icon)
    b.count:SetText(e.charges > 1 and ("%d"):format(e.charges) or "")
    if changed then
        b.expires = e.expires
        if e.expires then
            -- The full length is unknown: the swipe starts full now, and the
            -- client's countdown numbers show the time left.
            b.cooldown:SetCooldown(now(), e.expires - now())
        else
            b.cooldown:Clear()
        end
    end
    b:Show()
end

-- Everything: read, show, and make the buffs move on by as many icons.
function WeaponEnchants.Update(frame)
    local list = WeaponEnchants.Wanted(frame) and WeaponEnchants.Read() or {}
    -- Styled and placed before they are filled: a new icon has no font yet.
    -- nil (Layout: the buffs were just placed again) always counts as moved,
    -- so the buffs give back room the icons no longer need.
    local moved = frame.enchantLead ~= #list
    if moved then
        frame.enchantLead = #list
        for i = 1, #list do place(frame, button(frame, i), i) end
    end
    for i, e in ipairs(list) do show(frame.enchantButtons[i], e) end
    for i = #list + 1, #(frame.enchantButtons or {}) do
        local b = frame.enchantButtons[i]
        b:Hide()
        b.invSlot, b.enchantID, b.expires = nil, nil, nil
    end
    if moved then ns.AuraContainers.Relead(frame) end
end

-- The buffs' settings changed (AuraContainers apply): new size and place.
function WeaponEnchants.Layout(frame)
    if frame.key ~= "player" then return end
    for i, b in ipairs(frame.enchantButtons or {}) do place(frame, b, i) end
    frame.enchantLead = nil
    WeaponEnchants.Update(frame)
end

local function player()
    local frame = ns.Frames and ns.Frames.player
    if frame and frame.auras then return frame end
    return nil
end

local driver = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
    "WEAPON_ENCHANT_CHANGED", "WEAPON_SLOT_CHANGED" }) do
    pcall(driver.RegisterEvent, driver, event)
end
driver:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
    local frame = player()
    if frame then WeaponEnchants.Update(frame) end
end)
local elapsed = 0
driver:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < WeaponEnchants.INTERVAL then return end
    elapsed = 0
    local frame = player()
    if frame then WeaponEnchants.Update(frame) end
end)
