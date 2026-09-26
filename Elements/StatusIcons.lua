local _, ns = ...

-- Status icons of the player frame, as Blizzard's PlayerFrame has them: a
-- combat icon while you are in combat and a resting icon while you rest
-- in an inn or a city. Blizzard's own art (Blizzard_UnitFrame/Mainline/
-- PlayerFrame.xml): the crossed swords atlas, and the resting "Zzz" as a
-- flipbook animated like Blizzard's (its art is drawn half again as big
-- as its slot, as there).
--
-- A row on a plain holder frame anchored to the health bar (centred on it
-- by default), above the bar's texts, room for each icon switched on in
-- the settings. The holder is anchored and sized out of combat only. The
-- icons that show sit side by side, packed towards the holder's anchor
-- point (centred by default); they are textures of the plain holder, so
-- they may move in combat. Combat comes from PLAYER_REGEN_DISABLED/ENABLED (the unit frames
-- are only built out of combat), resting from IsResting on
-- PLAYER_UPDATE_RESTING (read through Secrets.Bool; it is not documented
-- as secret).
local StatusIcons = { name = "StatusIcons" }
ns.StatusIcons = StatusIcons

local Config, Pixel = ns.Config, ns.Pixel

StatusIcons.SCOPE = "player"
StatusIcons.COMBAT_ATLAS = "UI-HUD-UnitFrame-Player-CombatIcon"
StatusIcons.REST_ATLAS = "UI-HUD-UnitFrame-Player-Rest-Flipbook"
-- Blizzard's flipbook: 7 rows of 6 cells, 42 frames in 1.5 seconds.
StatusIcons.REST_FLIPBOOK = { rows = 7, columns = 6, frames = 42, duration = 1.5 }
-- The resting art's size per slot size (Blizzard: 30 in a 20 slot).
StatusIcons.REST_ART_SCALE = 1.5
-- Gap between the two slots, in pixels.
local GAP = 2

-- Between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED.
local fighting = false

local function newRestIcon(holder)
    local texture = holder:CreateTexture(nil, "ARTWORK")
    texture:SetAtlas(StatusIcons.REST_ATLAS)
    local book = StatusIcons.REST_FLIPBOOK
    local group = texture:CreateAnimationGroup()
    local anim = group:CreateAnimation("FlipBook")
    anim:SetFlipBookRows(book.rows)
    anim:SetFlipBookColumns(book.columns)
    anim:SetFlipBookFrames(book.frames)
    anim:SetFlipBookFrameWidth(0)
    anim:SetFlipBookFrameHeight(0)
    anim:SetDuration(book.duration)
    group:SetLooping("REPEAT")
    return texture, group
end

-- Built with the frame, out of combat. Other frames get nothing.
function StatusIcons.Build(frame)
    if frame.key ~= StatusIcons.SCOPE then return end
    local holder = CreateFrame("Frame", nil, frame)
    local combat = holder:CreateTexture(nil, "ARTWORK")
    combat:SetAtlas(StatusIcons.COMBAT_ATLAS)
    local resting, restAnim = newRestIcon(holder)
    frame.statusIcons = { holder = holder, combat = combat, resting = resting, restAnim = restAnim }
end

local function wanted(key) return Config.Get(StatusIcons.SCOPE, key) end

-- The icons switched on in the settings, left to right.
local function enabledIcons(s)
    local list = {}
    if wanted("statusCombat") then list[#list + 1] = s.combat end
    if wanted("statusResting") then list[#list + 1] = s.resting end
    return list
end

local rowWidth, justify = ns.Layout.IconRowWidth, ns.Layout.IconRowJustify

local function placeIcon(s, icon, offset)
    local size = s.size
    icon:ClearAllPoints()
    if icon == s.resting then
        local art = Pixel.Snap(size * StatusIcons.REST_ART_SCALE)
        icon:SetPoint("CENTER", s.holder, "LEFT", offset + size / 2, 0)
        icon:SetSize(art, art)
    else
        icon:SetPoint("TOPLEFT", s.holder, "TOPLEFT", offset, 0)
        icon:SetSize(size, size)
    end
end

-- The icons that show, side by side in the holder.
local function arrange(s, shown)
    if not s.size then return end
    local free = s.holder:GetWidth() - rowWidth(#shown, s.size, s.gap)
    local start = Pixel.Snap(free * justify(s.point))
    for i, icon in ipairs(shown) do placeIcon(s, icon, start + (i - 1) * (s.size + s.gap)) end
end

-- Anchors and sizes of the row. Out of combat only.
local function layout(frame)
    local s, scope = frame.statusIcons, frame.key
    local size = Pixel.Snap(Config.Get(scope, "statusSize"))
    local gap = Pixel.Snap(GAP)
    local n = #enabledIcons(s)
    s.size, s.gap, s.point = size, gap, Config.Get(scope, "statusPoint")
    s.holder:SetSize(math.max(1, rowWidth(n, size, gap)), size)
    -- Above the texts' overlay (Elements/Health.lua, + 10).
    s.holder:SetFrameLevel(frame:GetFrameLevel() + ns.Auras.LEVELS)
    local x, y = Pixel.Snap(Config.Get(scope, "statusX")), Pixel.Snap(Config.Get(scope, "statusY"))
    s.holder:ClearAllPoints()
    s.holder:SetPoint(Config.Get(scope, "statusPoint"), frame.health, Config.Get(scope, "statusFramePoint"), x, y)
    s.holder:SetShown(n > 0)
    StatusIcons.Refresh(frame)
end

-- Any time, combat included: which icons show. Test mode shows both.
function StatusIcons.Refresh(frame)
    local s = frame.statusIcons
    if not s then return end
    local combat = wanted("statusCombat") and (s.preview or fighting)
    local resting = wanted("statusResting") and (s.preview or ns.Secrets.Bool(IsResting) == true)
    s.combat:SetShown(combat)
    s.resting:SetShown(resting)
    local shown = {}
    if combat then shown[#shown + 1] = s.combat end
    if resting then shown[#shown + 1] = s.resting end
    arrange(s, shown)
    if resting and not s.restAnim:IsPlaying() then
        s.restAnim:Play()
    elseif not resting then
        s.restAnim:Stop()
    end
end

function StatusIcons.Style(frame)
    if not frame.statusIcons then return end
    ns.AfterCombat("statusIconsLayout", function() layout(frame) end)
    StatusIcons.Refresh(frame)
end

function StatusIcons.Update() end

function StatusIcons.Preview(frame, on)
    local s = frame.statusIcons
    if not s then return end
    s.preview = on or nil
    StatusIcons.Refresh(frame)
end

local function refreshPlayer()
    local frame = ns.Frames.player
    if frame then StatusIcons.Refresh(frame) end
end

ns.On("PLAYER_REGEN_DISABLED", function()
    fighting = true
    refreshPlayer()
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    fighting = false
    refreshPlayer()
end)

ns.On("PLAYER_UPDATE_RESTING", refreshPlayer)
ns.On("PLAYER_ENTERING_WORLD", refreshPlayer)

ns.RegisterElement(StatusIcons)
