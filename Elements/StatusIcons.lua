local _, ns = ...

-- Status icons of the player frame, as Blizzard's PlayerFrame has them: a
-- combat icon while you are in combat and a resting icon while you rest
-- in an inn or a city. Blizzard's own art (Blizzard_UnitFrame/Mainline/
-- PlayerFrame.xml): the crossed swords atlas, and the resting "Zzz" as a
-- flipbook animated like Blizzard's (its art is drawn half again as big
-- as its slot, as there).
--
-- A row on a plain holder frame that hangs from the player's block like
-- the totems: a slot per icon switched on in the settings. Anchors and
-- sizes change out of combat only; in combat the icons only show and
-- hide. Combat comes from PLAYER_REGEN_DISABLED/ENABLED (the unit frames
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

-- The slots switched on, left to right.
local function slots(s)
    local list = {}
    if wanted("statusCombat") then list[#list + 1] = s.combat end
    if wanted("statusResting") then list[#list + 1] = s.resting end
    return list
end

local function placeIcon(s, icon, offset, size)
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

-- Anchors and sizes of the row. Out of combat only.
local function layout(frame)
    local s, scope = frame.statusIcons, frame.key
    local size = Pixel.Snap(Config.Get(scope, "statusSize"))
    local gap = Pixel.Snap(GAP)
    local shown = slots(s)
    local n = #shown
    s.holder:SetSize(math.max(1, n * size + (n - 1) * gap), size)
    s.holder:SetFrameLevel(frame:GetFrameLevel() + ns.Auras.LEVELS)
    local region = frame.unitBox or frame
    local x, y = ns.Auras.AnchorOffset(frame, "status", region)
    s.holder:ClearAllPoints()
    s.holder:SetPoint(Config.Get(scope, "statusPoint"), region, Config.Get(scope, "statusFramePoint"), x, y)
    for i, icon in ipairs(shown) do placeIcon(s, icon, (i - 1) * (size + gap), size) end
    s.holder:SetShown(n > 0)
end

-- Any time, combat included: which icons show. Test mode shows both.
function StatusIcons.Refresh(frame)
    local s = frame.statusIcons
    if not s then return end
    s.combat:SetShown(wanted("statusCombat") and (s.preview or fighting))
    local resting = wanted("statusResting") and (s.preview or ns.Secrets.Bool(IsResting) == true)
    s.resting:SetShown(resting)
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
