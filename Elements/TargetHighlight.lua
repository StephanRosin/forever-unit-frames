local _, ns = ...

-- Target highlight: a bright band around the party member (or party pet)
-- you have targeted. The band is the threat glow's (Border.DrawGlow), a
-- step inside it and above it, in the frame and block ring holders.
-- UnitIsUnit may answer with a secret: then the band's opacity takes the
-- answer as it is (SetAlphaFromBoolean), with no comparison here.
local TargetHighlight = { name = "TargetHighlight", unitEvents = {} }
ns.TargetHighlight = TargetHighlight

local Config, Secrets, Pixel, Border = ns.Config, ns.Secrets, ns.Pixel, ns.Border

-- Test mode: pretend party member 1 is your target.
TargetHighlight.PARTY_SAMPLE = 1

local function applies(frame)
    return frame.key == ns.Party.KEY or frame.key == ns.Party.PET_KEY
end

local function setting(frame)
    return Config.Get(ns.Party.KEY, "targetHighlight")
end

function TargetHighlight.Build(frame)
    if not applies(frame) or not frame.frameRing then return end
    local holders = {}
    for name, ring in pairs({ frame = frame.frameRing, block = frame.blockRing }) do
        local holder = CreateFrame("Frame", nil, ring)
        holder:SetAllPoints(ring)
        holder:Hide()
        holders[name] = holder
    end
    frame.targetHighlight = holders
end

function TargetHighlight.Style(frame)
    local h = frame.targetHighlight
    if not h then return end
    local size = Pixel.Snap(Config.Get(ns.Party.KEY, "targetHighlightSize"), nil, 1)
    local c = Config.Get(ns.Party.KEY, "targetHighlightColor")
    for _, holder in pairs({ h.frame, h.block }) do
        -- Above the threat glow in the same ring.
        if frame.threat then holder:SetFrameLevel(frame.threat.frame:GetFrameLevel() + 1) end
        Border.DrawGlow(holder, frame.key, holder, frame.shapeRadius, size)
        Border.PaintGlow(holder, c[1], c[2], c[3], c[4])
    end
    TargetHighlight.Update(frame)
end

local function show(h, shown, answer)
    for _, holder in pairs({ h.frame, h.block }) do
        holder:SetShown(shown)
        if shown then
            if answer == nil then
                holder:SetAlpha(1)
            else
                holder:SetAlphaFromBoolean(answer, 1, 0)
            end
        end
    end
end

function TargetHighlight.Update(frame)
    local h = frame.targetHighlight
    if not h then return end
    if h.sample ~= nil then
        show(h, h.sample and setting(frame) or false)
        return
    end
    if not setting(frame) or not frame.unit then
        show(h, false)
        return
    end
    local ok, answer = pcall(UnitIsUnit, frame.unit, "target")
    if not ok then
        show(h, false)
    elseif Secrets.IsSecret(answer) then
        show(h, true, answer)
    else
        show(h, answer == true)
    end
end

function TargetHighlight.Preview(frame, on)
    local h = frame.targetHighlight
    if not h then return end
    if on then
        h.sample = frame.sampleIndex == TargetHighlight.PARTY_SAMPLE
    else
        h.sample = nil
    end
    TargetHighlight.Update(frame)
end

-- A new target: every party frame looks again.
local function updateAll()
    for _, list in ipairs({ ns.Party.buttons, ns.Party.fakes, ns.PartyPets and ns.PartyPets.buttons or {} }) do
        for _, frame in ipairs(list) do TargetHighlight.Update(frame) end
    end
end
ns.On("PLAYER_TARGET_CHANGED", updateAll)
ns.On("GROUP_ROSTER_UPDATE", updateAll)

ns.RegisterElement(TargetHighlight)
