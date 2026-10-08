local _, ns = ...

-- The shield watch: one icon per active absorb shield on the player,
-- target or focus, with the absorb it has left, in a block of its own that
-- has a mover. Off by default (shieldsEnabled).
--
-- The watched shields are shipped groups of spells (all Classic ranks)
-- and the frame's own additions. The aura is looked up by name
-- (C_UnitAuras.GetAuraDataBySpellName), so every rank and every spell of
-- the same name is found; names come from the client (an ID it does not
-- know is dropped). The player's block watches the player's class's group,
-- the Priest group (a priest's shield lands on anyone) and the potions and
-- items; target and focus watch every group. "Only my shields" (target and
-- focus) asks with the filter HELPFUL|PLAYER: the client decides whose
-- shield it is.
--
-- A shield is active (a plain AuraData), absent (nil while the spell's
-- aura is not secret) or unknown (a refusal, a secret answer, or nil while
-- it may be secret). Unknown shields are not shown. The amount is the
-- aura's points[1], handed to the text as it is (secret or not). When it
-- cannot be read, the total of the unit's absorbs (UnitGetTotalAbsorbs)
-- stands in, but only while exactly one watched shield is known to be
-- active (with "only mine": exactly one from any caster); otherwise no
-- number. Nothing secret is compared, added or tested.
--
-- Icons are aura icons (Elements/AuraButton.lua): the texture, the swipe
-- (readable times or the client's duration object) and the client's
-- countdown numbers, which are the time text here. Plain frames: shown and
-- hidden in combat too; the block's place and size change out of combat
-- (Style runs there).
local ShieldWatch = { name = "ShieldWatch", unitEvents = { "UNIT_AURA", "UNIT_ABSORB_AMOUNT_CHANGED" } }
ns.ShieldWatch = ShieldWatch

local Config, Secrets, Pixel, AuraButton = ns.Config, ns.Secrets, ns.Pixel, ns.AuraButton

ShieldWatch.SCOPES = { player = true, target = true, focus = true }
ShieldWatch.FILTER = "HELPFUL"
ShieldWatch.FILTER_MINE = "HELPFUL|PLAYER"

-- The shipped shields, Classic spell IDs (every rank). class: the group
-- the player's block watches only for that class; anyone: on every
-- player's block.
ShieldWatch.GROUPS = {
    { key = "Priest", class = "PRIEST", anyone = true, spells = {
        -- Power Word: Shield, ranks 1-10.
        { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 },
    } },
    { key = "Mage", class = "MAGE", spells = {
        { 11426, 13031, 13032, 13033 },              -- Ice Barrier
        { 1463, 8494, 8495, 10191, 10192, 10193 },   -- Mana Shield
        { 543, 8457, 8458, 10223, 10225 },           -- Fire Ward
        { 6143, 8461, 8462, 10177, 28609 },          -- Frost Ward
    } },
    { key = "Warlock", class = "WARLOCK", spells = {
        { 6229, 11739, 11740, 28610 },               -- Shadow Ward
        { 7812, 19438, 19440, 19441, 19442, 19443 }, -- Sacrifice (the Voidwalker's shield)
    } },
    { key = "Items", anyone = true, spells = {
        -- The protection potions' buffs: the normal and the Greater one.
        { 7233, 17543 },                             -- Fire Protection
        { 7239, 17544 },                             -- Frost Protection
        { 7242, 17548 },                             -- Shadow Protection
        { 7254, 17546 },                             -- Nature Protection
        { 17549 },                                   -- Arcane Protection
        { 23506 },                                   -- Aura of Protection (Arena Grand Master)
        { 29506 },                                   -- The Burrower's Shell
        { 13234 },                                   -- Harm Prevention Belt
    } },
}

-- Test mode: two shields so the block can be placed.
ShieldWatch.SAMPLES = {
    { icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", amount = 1250, duration = 30 },
    { icon = "Interface\\Icons\\Spell_Ice_Lament", amount = 818, duration = 60 },
}
-- The handle's length in icons.
ShieldWatch.HANDLE_ICONS = 2
-- Automatic text size: this share of the icon size.
ShieldWatch.AUTO_TEXT = 0.4
-- Where a text placed at a side of the icon hangs from: outside it.
local OPPOSITE = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT", CENTER = "CENTER" }
-- The icons' first corner and step per growth direction.
local START = { RIGHT = "LEFT", LEFT = "RIGHT", UP = "BOTTOM", DOWN = "TOP" }
local STEP = { RIGHT = { 1, 0 }, LEFT = { -1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }

local function setting(scope, key) return Config.Get(scope, key) end

local function playerClass()
    local _, class = UnitClass("player")
    if Secrets.IsSecret(class) then return nil end
    return class
end

-- The spell's name from the client; nil when it knows none.
local function spellName(id)
    return ns.AuraBlocklist.Name(id)
end

-- Whether a group is watched on a frame: switched on, and on the player's
-- block only the player's class's and those for anyone.
function ShieldWatch.GroupWatched(scope, group)
    if setting(scope, "shields" .. group.key) ~= true then return false end
    if scope ~= "player" or group.anyone then return true end
    return group.class == playerClass()
end

-- The watched shields of a frame, in order: { name, ids } per name, the
-- IDs those the client knows (the first one names the shield). The
-- frame's additions come last.
function ShieldWatch.Watched(scope)
    local list, byName = {}, {}
    local function add(ids)
        for _, id in ipairs(ids) do
            local name = spellName(id)
            if name then
                local entry = byName[name]
                if not entry then
                    entry = { name = name, ids = {} }
                    byName[name] = entry
                    list[#list + 1] = entry
                end
                entry.ids[#entry.ids + 1] = id
            end
        end
    end
    for _, group in ipairs(ShieldWatch.GROUPS) do
        if ShieldWatch.GroupWatched(scope, group) then
            for _, ids in ipairs(group.spells) do add(ids) end
        end
    end
    add(ns.AuraBlocklist.Parse(setting(scope, "shieldsExtra")) or {})
    return list
end

-- The spell IDs the frame's buffs leave out (Elements/Auras.lua): every
-- watched ID while the watch and "hide them in the buffs" are on; nil
-- otherwise. A map, spell ID -> true, like the hidden auras.
function ShieldWatch.HiddenSet(scope)
    if not ShieldWatch.SCOPES[scope] then return nil end
    if setting(scope, "shieldsEnabled") ~= true or setting(scope, "shieldsHideInBuffs") ~= true then return nil end
    local set
    for _, entry in ipairs(ShieldWatch.Watched(scope)) do
        for _, id in ipairs(entry.ids) do
            set = set or {}
            set[id] = true
        end
    end
    return set
end

-- Reading ----------------------------------------------------------------------

-- Whether the client may hide the aura of any spell of this name right
-- now: a nil answer then does not mean absent. No C_Secrets: nothing is
-- secret.
local function mayBeSecret(entry)
    local secrets = C_Secrets
    if not (secrets and secrets.ShouldSpellAuraBeSecret) then return false end
    for _, id in ipairs(entry.ids) do
        if Secrets.Call(secrets.ShouldSpellAuraBeSecret, id) ~= false then return true end
    end
    return false
end

-- One shield on a unit: "active" with its AuraData, "absent" or "unknown".
function ShieldWatch.Read(unit, entry, filter)
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, entry.name, filter)
    if not ok or Secrets.IsSecret(aura) then return "unknown" end
    if type(aura) == "table" then return "active", aura end
    if aura == nil and not mayBeSecret(entry) then return "absent" end
    return "unknown"
end

-- The shields of a frame's unit: the active ones in watched order
-- ({ entry, aura }), and whether exactly one watched shield is known to
-- be active (the total may stand in for an unreadable amount).
function ShieldWatch.Scan(scope, unit)
    local watched = ShieldWatch.Watched(scope)
    local onlyMine = scope ~= "player" and setting(scope, "shieldsOnlyMine") == true
    local filter = onlyMine and ShieldWatch.FILTER_MINE or ShieldWatch.FILTER
    local active, unknown = {}, false
    for _, entry in ipairs(watched) do
        local state, aura = ShieldWatch.Read(unit, entry, filter)
        if state == "active" then active[#active + 1] = { entry = entry, aura = aura } end
        if state == "unknown" then unknown = true end
    end
    local single = not unknown and #active == 1
    -- Only mine: the total holds everyone's shields; it stands in only
    -- while exactly one is active from any caster.
    if single and onlyMine then
        local any = 0
        for _, entry in ipairs(watched) do
            local state = ShieldWatch.Read(unit, entry, ShieldWatch.FILTER)
            if state == "unknown" then any = math.huge break end
            if state == "active" then any = any + 1 end
        end
        single = any == 1
    end
    return active, single
end

-- The aura's remaining absorb as the client gives it (a number or a
-- secret); nil when it cannot be read.
local function pointsOf(aura)
    local points = aura.points
    if Secrets.IsSecret(points) or type(points) ~= "table" then return nil end
    local v = points[1]
    if Secrets.IsSecret(v) or type(v) == "number" then return v end
    return nil
end

function ShieldWatch.Amount(aura)
    local ok, v = pcall(pointsOf, aura)
    if ok then return v end
    return nil
end

-- Writes an amount: a plain number like the health texts (abbreviated or
-- in full), a secret one through the client (AbbreviateNumbers takes it)
-- or as it is.
function ShieldWatch.SetAmount(fs, v, abbreviate)
    if Secrets.IsSecret(v) then
        if abbreviate and AbbreviateNumbers then
            local ok, text = pcall(AbbreviateNumbers, v)
            if ok then return fs:SetText(text) end
        end
        return fs:SetText(v)
    end
    if abbreviate then return fs:SetText(Secrets.Abbreviate(v)) end
    fs:SetFormattedText("%d", v)
end

-- Building and styling -----------------------------------------------------------

local function newIcon(sw)
    local button = AuraButton.Create(sw.holder, false)
    button.amount = button.cover:CreateFontString(nil, "OVERLAY")
    sw.icons[#sw.icons + 1] = button
    return button
end

function ShieldWatch.Build(frame)
    if not ShieldWatch.SCOPES[frame.key] then return end
    local holder = CreateFrame("Frame", nil, frame)
    holder:Hide()
    frame.shields = { holder = holder, icons = {}, shown = 0 }
    -- Two icons at once in test mode: made now, out of combat.
    for _ = 1, #ShieldWatch.SAMPLES do newIcon(frame.shields) end
end

local function iconSize(scope) return Pixel.Snap(setting(scope, "shieldsSize")) end

-- The handle's (and the block's) size: HANDLE_ICONS icons in the growth
-- direction.
function ShieldWatch.Size(scope)
    local size, spacing = iconSize(scope), Pixel.Snap(setting(scope, "shieldsSpacing"))
    local n = ShieldWatch.HANDLE_ICONS
    local length = n * size + (n - 1) * spacing
    local growth = setting(scope, "shieldsGrowth")
    if growth == "UP" or growth == "DOWN" then return size, length end
    return length, size
end

local function enabled(scope)
    return ns.FrameEnabled(scope) and setting(scope, "shieldsEnabled") == true
end

-- Inside the screen: the block's centre at most half the screen minus half
-- the block from the middle.
local function clamp(scope, axis, v)
    local w, h = ShieldWatch.Size(scope)
    local half = axis == "x" and (UIParent:GetWidth() - w) / 2 or (UIParent:GetHeight() - h) / 2
    if half <= 0 then return 0 end
    return math.max(-half, math.min(half, v))
end

function ShieldWatch.MoverSpec(frame)
    local scope = frame.key
    return {
        id = "shields:" .. scope, scope = scope, xKey = "shieldsX", yKey = "shieldsY", anchor = false,
        label = function() return ns.L.MOVER_SHIELDS:format(ns.L["FRAME_" .. scope]) end,
        size = function() return ShieldWatch.Size(scope) end,
        active = function() return enabled(scope) end,
        clamp = function(axis, v) return clamp(scope, axis, v) end,
    }
end

-- The block on its handle, or (no handle yet) where the handle would be.
local function place(frame)
    local sw, scope = frame.shields, frame.key
    local holder = sw.holder
    local w, h = ShieldWatch.Size(scope)
    holder:ClearAllPoints()
    if holder.mover then
        ns.Movers.Sync(holder)
        holder:SetAllPoints(holder.mover)
    else
        holder:SetSize(w, h)
        holder:SetPoint("CENTER", UIParent, "CENTER", Pixel.Centre(setting(scope, "shieldsX"), w),
            Pixel.Centre(setting(scope, "shieldsY"), h))
    end
end

local function fontOf(scope, key)
    local face = setting(scope, key)
    if face == "" then face = setting(scope, "fontFace") end
    return ns.Media.Font(face)
end

local function textSize(scope, key)
    local own = setting(scope, key)
    if own > 0 then return own end
    return math.max(6, math.floor(setting(scope, "shieldsSize") * ShieldWatch.AUTO_TEXT + 0.5))
end

local function outlineOf(scope, key)
    local outline = setting(scope, key)
    if outline == "FRAME" then outline = setting(scope, "fontOutline") end
    return outline
end

local function placeText(fs, button, point, x, y)
    fs:ClearAllPoints()
    fs:SetPoint(OPPOSITE[point], button, point, x, y)
end

local function styleIcon(button, scope, size)
    AuraButton.Style(button, scope, size, setting(scope, "shieldsTime") == true)
    button.cooldown:SetDrawSwipe(setting(scope, "shieldsSwipe") == true)
    local amount = button.amount
    ns.Texts.SetFont(amount, fontOf(scope, "shieldsAmountFont"), textSize(scope, "shieldsAmountSize"),
        outlineOf(scope, "shieldsAmountOutline"))
    local c = setting(scope, "shieldsAmountColor")
    amount:SetTextColor(c[1], c[2], c[3], c[4])
    placeText(amount, button, setting(scope, "shieldsAmountPoint"), setting(scope, "shieldsAmountX"),
        setting(scope, "shieldsAmountY"))
    amount:SetShown(setting(scope, "shieldsAmount") == true)
    -- The time text is the client's countdown: it writes it, so a soft
    -- outline (copies we would have to write) becomes the plain one.
    local numbers = button.cooldown:GetCountdownFontString()
    if numbers then
        local outline = outlineOf(scope, "shieldsTimeOutline")
        local flags = (outline == "SOFT" or outline == "NONE") and (outline == "SOFT" and "OUTLINE" or "") or outline
        numbers:SetFont(fontOf(scope, "shieldsTimeFont"), textSize(scope, "shieldsTimeSize"), flags)
        local t = setting(scope, "shieldsTimeColor")
        numbers:SetTextColor(t[1], t[2], t[3], t[4])
        placeText(numbers, button, setting(scope, "shieldsTimePoint"), setting(scope, "shieldsTimeX"),
            setting(scope, "shieldsTimeY"))
    end
end

local function layoutIcon(frame, button, i)
    local scope, holder = frame.key, frame.shields.holder
    local size, spacing = iconSize(scope), Pixel.Snap(setting(scope, "shieldsSpacing"))
    local growth = setting(scope, "shieldsGrowth")
    local start, step = START[growth], STEP[growth]
    local offset = (i - 1) * (size + spacing)
    button:ClearAllPoints()
    button:SetPoint(start, holder, start, step[1] * offset, step[2] * offset)
end

function ShieldWatch.Style(frame)
    local sw = frame.shields
    if not sw then return end
    local scope = frame.key
    place(frame)
    sw.holder:SetFrameLevel(frame:GetFrameLevel() + ns.Auras.LEVELS)
    local size = iconSize(scope)
    for i, button in ipairs(sw.icons) do
        styleIcon(button, scope, size)
        layoutIcon(frame, button, i)
    end
    sw.styled = true
    ShieldWatch.Refresh(frame)
end

-- Showing ------------------------------------------------------------------------

-- An icon for the i-th shield: made when there is none yet (a plain
-- frame, fine in combat), styled and placed like the others.
local function iconAt(frame, i)
    local sw = frame.shields
    local button = sw.icons[i]
    if button then return button end
    button = newIcon(sw)
    styleIcon(button, frame.key, iconSize(frame.key))
    layoutIcon(frame, button, i)
    return button
end

local function hideFrom(sw, n)
    for i = n + 1, #sw.icons do
        local button = sw.icons[i]
        AuraButton.Clear(button)
        button.amount:SetText("")
    end
    sw.shown = n
end

local function showSamples(frame)
    local sw = frame.shields
    sw.sampleStart = sw.sampleStart or GetTime()
    local abbreviate = setting(frame.key, "shieldsAbbreviate") == true
    for i, sample in ipairs(ShieldWatch.SAMPLES) do
        local button = iconAt(frame, i)
        AuraButton.ShowSample(button, sample, sw.sampleStart)
        ShieldWatch.SetAmount(button.amount, sample.amount, abbreviate)
    end
    hideFrom(sw, #ShieldWatch.SAMPLES)
end

local function showActive(frame)
    local sw, scope, unit = frame.shields, frame.key, frame.unit
    local active, single = ShieldWatch.Scan(scope, unit)
    local filter = scope ~= "player" and setting(scope, "shieldsOnlyMine") == true and ShieldWatch.FILTER_MINE
        or ShieldWatch.FILTER
    local abbreviate = setting(scope, "shieldsAbbreviate") == true
    local n = 0
    for _, shield in ipairs(active) do
        local button = iconAt(frame, n + 1)
        if AuraButton.Show(button, unit, shield.aura, filter) then
            n = n + 1
            local amount = ShieldWatch.Amount(shield.aura)
            if amount == nil and single then
                local ok, total = pcall(UnitGetTotalAbsorbs, unit)
                if ok then amount = total end
            end
            if amount ~= nil then
                ShieldWatch.SetAmount(button.amount, amount, abbreviate)
            else
                button.amount:SetText("")
            end
        end
    end
    hideFrom(sw, n)
end

-- Any time, combat included: the icons follow the unit's shields (or the
-- samples in test mode).
function ShieldWatch.Refresh(frame)
    local sw = frame.shields
    if not (sw and sw.styled) then return end
    local on = enabled(frame.key)
    sw.holder:SetShown(on)
    if not on then return hideFrom(sw, 0) end
    if sw.preview then return showSamples(frame) end
    if not frame.unit or not UnitExists(frame.unit) then return hideFrom(sw, 0) end
    showActive(frame)
end

function ShieldWatch.Update(frame)
    if frame.shields then ShieldWatch.Refresh(frame) end
end

-- Test mode: the two samples on each of the three frames.
function ShieldWatch.Preview(frame, on)
    local sw = frame.shields
    if not sw then return end
    sw.preview = on or nil
    if not on then sw.sampleStart = nil end
    ShieldWatch.Refresh(frame)
end

-- The handle: made with the frames, out of combat.
function ShieldWatch.AttachMover(frame)
    local sw = frame.shields
    if not sw then return end
    ns.Movers.Attach(sw.holder, ShieldWatch.MoverSpec(frame))
    ns.AfterCombat("shieldsStyle:" .. frame.key, function() ShieldWatch.Style(frame) end)
end

-- Combat is over: data that was secret may be readable now, without an
-- aura event.
ns.On("PLAYER_REGEN_ENABLED", function()
    for scope in pairs(ShieldWatch.SCOPES) do
        local frame = ns.Frames and ns.Frames[scope]
        if frame then ShieldWatch.Refresh(frame) end
    end
end)

ns.RegisterElement(ShieldWatch)
