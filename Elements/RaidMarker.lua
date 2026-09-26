local _, ns = ...

-- Raid target markers (skull, cross, star, ...) on every unit frame,
-- drawn as Blizzard's TargetFrame draws them (Blizzard_UnitFrame/Mainline/
-- TargetFrame.xml and TargetFrame.lua): the sheet
-- Interface\TargetingFrame\UI-RaidTargetingIcons, 4 x 4 cells, the cell
-- picked with SetSpriteSheetCell.
--
-- GetRaidTargetIndex is documented with SecretReturns: the index may be
-- secret. It is then never compared or used as an index. Presence is told
-- by type() (a secret cannot be nil), and the index itself goes straight
-- to SetSpriteSheetCell, whose cell argument takes secrets from tainted
-- code (SimpleTextureBaseAPIDocumentation.lua: AllowedWhenTainted).
--
-- The icon is a texture on a plain holder frame, a child of the unit
-- frame: showing, hiding and redrawing it is allowed in combat. The holder
-- is sized and anchored with the frame's other regions (Style).
local RaidMarker = { name = "RaidMarker" }
ns.RaidMarker = RaidMarker

local Config, Pixel = ns.Config, ns.Pixel

RaidMarker.TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
-- RAID_TARGET_TEXTURE_ROWS / _COLUMNS in TargetFrame.lua.
RaidMarker.ROWS, RaidMarker.COLUMNS = 4, 4
-- The holder's layer above the unit frame: over the elite marker (+16),
-- below the class badge (+20).
RaidMarker.LEVELS = 18
-- Test mode: a skull on the target, a star on the first pretend party
-- member.
RaidMarker.SAMPLES = { target = 8 }
RaidMarker.PARTY_SAMPLES = { [1] = 1 }

function RaidMarker.Build(frame)
    local holder = CreateFrame("Frame", nil, frame)
    local icon = holder:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(RaidMarker.TEXTURE)
    icon:SetAllPoints(holder)
    icon:Hide()
    frame.raidMarker = { holder = holder, icon = icon }
end

local function wanted(frame) return Config.Get(frame.key, "raidMarker") end

function RaidMarker.Style(frame)
    local r, scope = frame.raidMarker, frame.key
    local size = Pixel.Snap(Config.Get(scope, "raidMarkerSize"), nil, 1)
    r.holder:SetFrameLevel(frame:GetFrameLevel() + RaidMarker.LEVELS)
    r.holder:SetSize(size, size)
    r.holder:ClearAllPoints()
    r.holder:SetPoint(Config.Get(scope, "raidMarkerPoint"), frame, Config.Get(scope, "raidMarkerFramePoint"),
        Pixel.Snap(Config.Get(scope, "raidMarkerX")), Pixel.Snap(Config.Get(scope, "raidMarkerY")))
    r.holder:SetShown(wanted(frame))
    if r.preview then RaidMarker.Preview(frame, true) end
end

-- The sample of test mode for this frame, or nil.
local function sample(frame)
    if frame.sampleIndex then return RaidMarker.PARTY_SAMPLES[frame.sampleIndex] end
    return RaidMarker.SAMPLES[frame.key]
end

-- Draws index (plain or secret) or hides the icon (nil).
local function show(frame, index)
    local icon = frame.raidMarker.icon
    if not wanted(frame) or type(index) == "nil"
        or not pcall(icon.SetSpriteSheetCell, icon, index, RaidMarker.ROWS, RaidMarker.COLUMNS) then
        icon:Hide()
        return
    end
    icon:Show()
end

function RaidMarker.Update(frame)
    local r = frame.raidMarker
    if not r or r.preview then return end
    -- The index may be secret: never truth-tested, only checked by type().
    local ok, index = pcall(GetRaidTargetIndex, frame.unit)
    if not ok then index = nil end
    show(frame, index)
end

function RaidMarker.Preview(frame, on)
    local r = frame.raidMarker
    if not r then return end
    r.preview = on or nil
    if on then
        show(frame, sample(frame))
    elseif frame.unit and UnitExists(frame.unit) then
        RaidMarker.Update(frame)
    else
        r.icon:Hide()
    end
end

-- The event names no unit: every frame looks again.
ns.On("RAID_TARGET_UPDATE", function(event) ns.Units.UpdateElement(RaidMarker, event) end)

ns.RegisterElement(RaidMarker)
