local _, ns = ...

-- Hides Blizzard's own unit frames without hooking any of their methods
-- (hooking mixin methods breaks Blizzard code on this client).
local Blizzard = {}
ns.Blizzard = Blizzard

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

-- Edit Mode frames carry the original C Hide as a plain field "HideBase";
-- calling their overridden Hide would write into the Edit Mode manager.
local function hide(frame)
    local hideBase = rawget(frame, "HideBase")
    if hideBase then hideBase(frame) else frame:Hide() end
end

function Blizzard.Conceal(frame)
    if not frame then return end
    frame:UnregisterAllEvents()
    if frame:IsProtected() then
        -- Protected frames may not be reparented; make them invisible and
        -- inert instead.
        frame:SetAlpha(0)
        frame:EnableMouse(false)
        hide(frame)
    else
        hide(frame)
        frame:SetParent(hiddenParent)
    end
end

function Blizzard.HideDefaults()
    ns.AfterCombat("hideBlizzard", function()
        if ns.Config.Get("player", "enabled") then Blizzard.Conceal(_G.PlayerFrame) end
        if ns.Config.Get("target", "enabled") then
            Blizzard.Conceal(_G.TargetFrame)
            Blizzard.Conceal(_G.ComboFrame)
        end
    end)
end
