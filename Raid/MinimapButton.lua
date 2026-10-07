local _, ns = ...

-- The raid frames' own minimap button: a left click opens or closes the
-- raid options window (the same as /fuf raid, with its rules), a right
-- click folds the raid tools bar out or in (as /fuf tools), dragging
-- moves it around the minimap's edge. Built like the unit frames' button
-- (Options/MinimapButton.lua), with its own icon (tools/
-- make_raid_minimap_icon.py) and its own switch and angle in the raid
-- profile's General settings. A plain button, not secure.
--
-- Blizzard's addon compartment lists the TOC's entry (the unit frames'
-- window); the raid window gets an entry of its own there
-- (AddonCompartmentFrame:RegisterAddon, Blizzard_Minimap/Mainline/
-- AddonCompartment.lua). Its text is set once, in the language of the
-- login.
local RaidMinimapButton = {}
ns.RaidMinimapButton = RaidMinimapButton

local L = ns.L

RaidMinimapButton.ICON = "Interface\\AddOns\\ForeverUnitFrames\\Media\\RaidMinimapIcon.tga"

local function onClick(_, mouseButton)
    if mouseButton == "RightButton" then
        if ns.Commands.IsReady() then ns.RaidTools.Fold() end
    else
        ns.Commands.ToggleRaidOptions()
    end
end

-- The compartment's entry only opens the window; the button folds the
-- tools too.
local function tooltipLines(tooltip)
    tooltip:AddLine(L.RAID_MINIMAP_LEFT_CLICK, 1, 1, 1)
end

local function buttonTooltipLines(tooltip)
    tooltipLines(tooltip)
    tooltip:AddLine(L.RAID_MINIMAP_RIGHT_CLICK, 1, 1, 1)
end

local function registerCompartment()
    local compartment = AddonCompartmentFrame
    if not (compartment and compartment.RegisterAddon) then return end
    compartment:RegisterAddon({
        text = L.RAID_COMPARTMENT, icon = RaidMinimapButton.ICON, func = function() onClick() end,
        funcOnEnter = function(menuButton)
            GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
            GameTooltip:SetText(L.RAID_COMPARTMENT)
            tooltipLines(GameTooltip)
            GameTooltip:Show()
        end,
        funcOnLeave = function(menuButton)
            if GameTooltip:IsOwned(menuButton) then GameTooltip:Hide() end
        end,
    })
end

-- Once, after the raid profile is attached (Core/Boot.lua).
function RaidMinimapButton.Create()
    if RaidMinimapButton.button or not Minimap then return end
    RaidMinimapButton.button = ns.MinimapButton.New({
        name = "ForeverUnitFramesRaidMinimapButton", icon = RaidMinimapButton.ICON,
        clicks = { "LeftButtonUp", "RightButtonUp" }, onClick = onClick, title = L.RAID_COMPARTMENT,
        lines = buttonTooltipLines,
        config = ns.RaidConfig, show = "minimapShow", angle = "minimapAngle",
    })
    registerCompartment()
end

ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if not RaidMinimapButton.button then return end
    if scope == nil or (scope == "general" and (key == nil or key == "minimapAngle" or key == "minimapShow")) then
        RaidMinimapButton.button.place()
    end
end)
