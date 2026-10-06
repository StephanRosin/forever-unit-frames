-- The mock's aura slots (Blizzard_CustomAuraContainer.lua AddAuraSlot,
-- Blizzard_AuraContainerSlots.lua): one frame per slot, made at once and
-- handed to initializeFrame, locked like a group's buttons afterwards;
-- the source's argument checks; no part in the layout.
local M = H.M
H.LoadAddon()

local c = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
local seen
local frame = c:AddAuraSlot("dispel", "HARMFUL|RAID", {
    candidateFilters = { includeSpellIDs = { [139] = true, [6074] = true } },
    initializeFrame = function(b) seen = b end,
})
H.checkTrue("a frame back", frame)
H.check("initialised once with it", seen, frame)
H.check("found by key", c:GetAuraSlotFrame("dispel"), frame)
H.check("unknown key: none", c:GetAuraSlotFrame("other"), nil)
H.check("has it", c:HasAuraSlot("dispel"), true)
H.check("a custom aura button", frame._template, "CustomAuraButtonTemplate")
H.check("hidden until an aura comes", frame:IsShown(), false)
H.check("on the container", frame:GetParent(), c)
H.check("enabled", c:IsAuraSlotEnabled("dispel"), true)
H.check("filter", c._slots.dispel.filter, "HARMFUL|RAID")
H.checkTrue("small spell IDs are fine", c._slots.dispel.candidateFilters.includeSpellIDs[139])
local callerFilters = { includeSpellIDs = { [774] = true } }
c:SetAuraSlotCandidateFilters("dispel", callerFilters)
callerFilters.includeSpellIDs[8936] = true
H.check("filters copied: later edits of the caller's table do nothing",
    c._slots.dispel.candidateFilters.includeSpellIDs[8936], nil)
H.check("slots do not lock anchoring to the container", rawget(c, "_layoutForbidden"), nil)
-- Anchoring the slot's frame is the addon's business.
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
H.check("anchored", (frame:GetPoint(1)), "CENTER")

c:SetAuraSlotEnabled("dispel", false)
H.check("disabled", c:IsAuraSlotEnabled("dispel"), false)
c:SetAuraSlotFilterString("dispel", "HARMFUL|DISPELLABLE")
H.check("filter changed", c._slots.dispel.filter, "HARMFUL|DISPELLABLE")
c:SetAuraSlotCandidateFilters("dispel", nil)
H.check("filters cleared", c._slots.dispel.candidateFilters, nil)
c:SetAuraSlotSortMethod("dispel", AuraContainerSortMethod.Expiration, AuraContainerSortDirection.Normal)
H.check("sort", c._slots.dispel.sortMethod, AuraContainerSortMethod.Expiration)

-- The source's checks.
H.checkError("empty key", function() c:AddAuraSlot("", "HARMFUL") end)
H.checkError("bad filter", function() c:AddAuraSlot("x", "HARMFUL|NOPE") end)
H.checkError("same key twice", function() c:AddAuraSlot("dispel", "HARMFUL") end)
H.checkError("unknown option", function() c:AddAuraSlot("y", "HARMFUL", { layout = {} }) end)
H.checkError("a list of spell IDs", function()
    c:AddAuraSlot("z", "HELPFUL", { candidateFilters = { includeSpellIDs = { 139, 774 } } })
end)
H.checkError("unknown slot", function() c:SetAuraSlotEnabled("none", true) end)
H.checkError("enabled must be a boolean", function() c:SetAuraSlotEnabled("dispel", 1) end)
H.checkError("bad sort", function() c:SetAuraSlotSortMethod("dispel", 99, 0) end)
H.checkError("sort: no direction", function()
    c:SetAuraSlotSortMethod("dispel", AuraContainerSortMethod.Expiration)
end)
H.checkError("sort: no method", function()
    c:SetAuraSlotSortMethod("dispel", nil, AuraContainerSortDirection.Normal)
end)
H.checkError("templateNames of strings only", function()
    c:AddAuraSlot("t", "HARMFUL", { templateNames = { 1 } })
end)
H.checkError("a list for a group too", function()
    c:AddAuraGroup("g", "HARMFUL", { candidateFilters = { excludeSpellIDs = { 139 } } })
end)

-- The frame's duration displays: registered below it, cleared again.
local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
local text = frame:CreateFontString(nil, "OVERLAY")
frame:SetDurationCooldown(cooldown)
frame:SetDurationText(text)
H.check("swipe registered", frame._durationCooldown, cooldown)
H.check("number registered", frame._durationText, text)
frame:ClearDurationCooldown()
frame:ClearDurationText()
H.check("swipe cleared", frame._durationCooldown, nil)
H.check("number cleared", frame._durationText, nil)
H.checkError("a text that is not below it", function() frame:SetDurationText(UIParent:CreateFontString()) end)

-- Locked while auras are secret, like a group's buttons.
M.aurasSecret = true
H.checkError("locked while secret", function() frame:SetSize(10, 10) end)
H.checkError("its regions too", function() text:SetText("1") end)
M.aurasSecret = false
frame:SetSize(10, 10)
H.check("open again", frame:GetWidth(), 10)
-- Made while secret: initializeFrame still runs on the open frame.
M.combat = true
local ran = false
c:AddAuraSlot("hot", "HELPFUL|PLAYER", { initializeFrame = function(b)
    b:SetSize(6, 6)
    ran = true
end })
H.check("made in combat: initialised", ran, true)
H.checkError("made in combat: locked after", function() c:GetAuraSlotFrame("hot"):SetSize(7, 7) end)
M.combat = false
