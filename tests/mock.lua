-- Minimal WoW API mock for offline tests. Lua 5.1 like the client.
local M = {}
-- Mask textures one texture can carry in the client.
M.MAX_MASKS = 3
M.widgets = {}

-- Secret values ------------------------------------------------------------
-- Real secret values refuse arithmetic, comparison, concatenation and
-- tostring. The proxy below does the same, so any forbidden use fails in a
-- test instead of in combat. Equality against a number cannot be trapped in
-- Lua 5.1 (it is simply false), so code must not rely on it either way.
local secretMeta = {}
local function refuse() error("secret value used in Lua arithmetic/comparison", 2) end
for _, mm in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow",
                      "__unm", "__lt", "__le", "__concat", "__len", "__call" }) do
    secretMeta[mm] = refuse
end
secretMeta.__tostring = refuse
-- Comparing two secrets throws in the client too (a secret and a plain
-- value compare without metamethod in Lua 5.1 and are simply unequal).
secretMeta.__eq = refuse
secretMeta.__index = function() refuse() end

function M.Secret(v)
    return setmetatable({ __secret = v }, secretMeta)
end
function M.IsSecret(v)
    return type(v) == "table" and getmetatable(v) == secretMeta
end
function M.Reveal(v)
    if M.IsSecret(v) then return rawget(v, "__secret") end
    return v
end

-- Widgets ------------------------------------------------------------------
local widget = {}
widget.__index = function(t, k)
    -- Unknown CamelCase keys are widget methods that do nothing; anything
    -- else is addon data and must be nil, as in the game. Strict objects
    -- (Blizzard aura containers and their buttons) have only the methods
    -- the mock gives them. Under an aura button, even a no-op method
    -- refuses while auras are secret.
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    if rawget(t, "_strict") then error("mock: " .. tostring(rawget(t, "_kind")) .. " has no method " .. k, 2) end
    local f = function(self)
        if M.AurasSecret() and M.IsAuraRestricted(self) then error("aura button: tainted access while auras are secret", 2) end
    end
    rawset(t, k, f)
    return f
end

-- XML templates of the addon, mirrored in Lua (the tests cannot load XML).
-- test_party.lua checks that Units/Party.xml declares the same.
M.templates = {
    ForeverUnitFramesPartyButtonTemplate = function(w)
        w._w, w._h = 160, 46
        w._clicks = { "AnyUp" }
        w._attr["*type1"] = "target"
        w._attr["*type2"] = "togglemenu"
        w._scripts.OnAttributeChanged = function(self, name, value)
            ForeverUnitFrames.PartyButtonOnAttributeChanged(self, name, value)
        end
        ForeverUnitFrames.PartyButtonOnLoad(w)
    end,
    -- Units/PartyPets.xml
    ForeverUnitFramesPartyPetButtonTemplate = function(w)
        w._w, w._h = 160, 20
        w._clicks = { "AnyUp" }
        w._attr["*type1"] = "target"
        w._attr["*type2"] = "togglemenu"
        w._scripts.OnAttributeChanged = function(self, name, value)
            ForeverUnitFrames.PartyPetButtonOnAttributeChanged(self, name, value)
        end
        ForeverUnitFrames.PartyPetButtonOnLoad(w)
    end,
}

-- SecureGroupHeaderTemplate, reduced to what the addon relies on: party
-- or solo detection, showPlayer/showSolo/showParty, point and offsets,
-- child creation from the template attribute, unit assignment through
-- SetAttribute("unit"), and updates on show, attribute change and roster
-- change while shown.
-- Like the client, shown buttons are only SetPoint'ed (never cleared): a
-- button keeps an anchor from an earlier layout on another point. Only
-- unused buttons lose their anchors. The header sizes itself from child1
-- as it is at layout time.
local OPPOSITE = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT" }
local MULTIPLIER = { TOP = { 0, -1 }, BOTTOM = { 0, 1 }, LEFT = { 1, 0 }, RIGHT = { -1, 0 } }

local function groupHeaderLayout(header)
    local a = header._attr
    local kind
    if #M.group > 0 and a.showParty then kind = "PARTY" elseif a.showSolo then kind = "SOLO" end
    local units = {}
    if kind == "SOLO" or (kind == "PARTY" and a.showPlayer) then units[1] = "player" end
    if kind == "PARTY" then
        for _, u in ipairs(M.group) do units[#units + 1] = u end
    end
    -- SecureGroupPetHeaderTemplate: the owners' pets that exist, packed.
    if header._pets then
        local pets = {}
        for _, u in ipairs(units) do
            local pet = u == "player" and "pet" or u:gsub("^party", "partypet")
            if M.units[pet] then pets[#pets + 1] = pet end
        end
        units = pets
    end
    for i = 1, math.max(1, #units) do
        if not a["child" .. i] then
            local child = CreateFrame(a.templateType or "Button", header:GetName() .. "UnitButton" .. i, header, a.template)
            header[i] = child
            a["child" .. i] = child
        end
    end
    local point = a.point or "TOP"
    local previous
    for i, unit in ipairs(units) do
        local child = a["child" .. i]
        if previous then
            child:SetPoint(point, previous, OPPOSITE[point], a.xOffset or 0, a.yOffset or 0)
        else
            child:SetPoint(point, header, point, 0, 0)
        end
        child:SetAttribute("unit", unit)
        child:Show()
        previous = child
    end
    local i = #units + 1
    while a["child" .. i] do
        local child = a["child" .. i]
        child:Hide()
        child:ClearAllPoints()
        child:SetAttribute("unit", nil)
        i = i + 1
    end
    local xm, ym = MULTIPLIER[point][1], MULTIPLIER[point][2]
    local bw, bh = a.child1:GetWidth(), a.child1:GetHeight()
    local n = #units
    if n > 0 then
        header:SetWidth(math.abs(xm) * (n - 1) * bw + (n - 1) * (a.xOffset or 0) * xm + bw)
        header:SetHeight(math.abs(ym) * (n - 1) * bh + (n - 1) * (a.yOffset or 0) * ym + bh)
    else
        header:SetWidth(math.max(math.abs(ym) * bw, 0.1))
        header:SetHeight(math.max(math.abs(xm) * bh, 0.1))
    end
    M.headerUpdates = M.headerUpdates + 1
end

-- The header's own (secure) code may move its protected children in
-- combat.
local function groupHeaderUpdate(header)
    M.secureDepth = M.secureDepth + 1
    local ok, err = pcall(groupHeaderLayout, header)
    M.secureDepth = M.secureDepth - 1
    if not ok then error(err, 0) end
end

local function makeGroupHeader(w, pets)
    w._shown = false   -- the template is hidden="true"
    w._pets = pets
    w:RegisterEvent("GROUP_ROSTER_UPDATE")
    if pets then w:RegisterEvent("UNIT_PET") end
    w._scripts.OnEvent = function(self) if self:IsShown() then groupHeaderUpdate(self) end end
    w._scripts.OnShow = groupHeaderUpdate
    w._scripts.OnAttributeChanged = function(self, name)
        if name == "_ignore" or self._attr._ignore then return end
        if self:IsShown() then groupHeaderUpdate(self) end
    end
end

-- Blizzard_AuraContainer's CustomAuraContainerTemplate: the inbound calls
-- an addon can make (Blizzard_AuraContainer.lua, Blizzard_CustomAuraContainer.lua,
-- Blizzard_AuraContainerFlowLayout.lua, Blizzard_CustomAuraButton.lua,
-- Blizzard_AuraButton.lua), with the source's argument checks. It shows no
-- auras: it records what it is told, and tests read the records
-- (_unit, _updates, _groups[key], _flow). Stricter than the client where
-- the client would silently accept a mistake: unknown option keys and
-- unknown methods raise.
-- Buttons: AddAuraGroup makes one batch (FrameCreationBatchSize) with
-- CustomAuraButtonTemplate and hands each to initializeFrame; after that
-- a button and everything under it refuse tainted access while auras are
-- secret (DenyTaintedAccessWhenAurasAreSecret; in the mock: in combat, or
-- while M.aurasSecret is set, as in an instance out of combat).
-- Once it has a group, only frames with the UntrustedLayoutScriptExecution
-- aspect may anchor to the container.
M.AURA_BATCH = 10
local AURA_FILTERS = { HELPFUL = true, HARMFUL = true, PLAYER = true, RAID = true, CANCELABLE = true,
    INCLUDE_NAME_PLATE_ONLY = true, MAW = true, EXTERNAL_DEFENSIVE = true, CROWD_CONTROL = true,
    RAID_IN_COMBAT = true, RAID_PLAYER_DISPELLABLE = true, BIG_DEFENSIVE = true, IMPORTANT = true,
    DISPELLABLE = true }
local LAYOUT_KEYS = { elementSpacing = "number", lineSpacing = "number", groupSpacing = "number",
    groupLineSpacing = "number", forceNewLine = "boolean", elementWidth = "size", elementHeight = "size",
    layoutIndex = "number" }
local LAYOUT_DEFAULTS = { elementSpacing = 0, lineSpacing = 0, groupSpacing = 0, groupLineSpacing = 0,
    forceNewLine = false }
local GROUP_KEYS = { maxFrameCount = true, templateNames = true, initializeFrame = true, candidateFilters = true,
    sortMethod = true, sortDirection = true, layout = true }
local TOOLTIP_ANCHORS = { ANCHOR_LEFT = true, ANCHOR_RIGHT = true, ANCHOR_BOTTOMLEFT = true, ANCHOR_BOTTOM = true,
    ANCHOR_BOTTOMRIGHT = true, ANCHOR_TOPLEFT = true, ANCHOR_TOP = true, ANCHOR_TOPRIGHT = true,
    ANCHOR_CURSOR = true, ANCHOR_NONE = true, ANCHOR_PRESERVE = true, ANCHOR_CURSOR_LEFT = true,
    ANCHOR_CURSOR_RIGHT = true }
local DISPEL_TEXTURE_KEYS = { showAlways = true, showWhenHarmful = true, showWhenHelpful = true,
    showWithoutDispelType = true, stealableFilter = true, style = true, customDispelAssetMap = true,
    customDispelColorMap = true, customDispelColorCurve = true }

local function validFilter(filter)
    if type(filter) ~= "string" then return false end
    for part in filter:gmatch("[^| ]+") do
        local negated = part:sub(1, 1) == "!"
        if negated then part = part:sub(2) end
        if part == "" or not AURA_FILTERS[part] then return false end
    end
    return true
end

local function isEnumValue(enum, v)
    for _, value in pairs(enum) do
        if value == v then return true end
    end
    return false
end

local function copyLayout(layout)
    assert(layout == nil or type(layout) == "table", "layout must be a table or nil.")
    local out = {}
    for k, v in pairs(LAYOUT_DEFAULTS) do out[k] = v end
    for k, v in pairs(layout or {}) do
        local kind = LAYOUT_KEYS[k]
        assert(kind, "mock: unknown layout key " .. tostring(k))
        if kind == "size" then
            assert(type(v) == "number" and v >= 0, k .. " must be a non-negative number.")
        else
            assert(type(v) == kind, k .. " must be a " .. kind .. ".")
        end
        out[k] = v
    end
    return out
end

local function validMax(n)
    return n == math.huge or (type(n) == "number" and n >= 0 and n == math.floor(n))
end

local function restricted(obj)
    while type(obj) == "table" do
        if rawget(obj, "_auraRestricted") then return true end
        obj = rawget(obj, "_parent")
    end
    return false
end
M.IsAuraRestricted = restricted

function M.AurasSecret() return M.combat or M.aurasSecret end

function M.HasLayoutAspect(obj)
    while type(obj) == "table" do
        if rawget(obj, "_layoutForbidden") then return true end
        obj = rawget(obj, "_parent")
    end
    return false
end

-- Every method of obj and its descendants refuses while auras are secret.
local function guardTree(obj)
    for k, v in pairs(obj) do
        if type(k) == "string" and k:match("^%u") and type(v) == "function" then
            obj[k] = function(...)
                if M.AurasSecret() and restricted(obj) then
                    error("aura button: tainted access while auras are secret", 2)
                end
                return v(...)
            end
        end
    end
    for _, child in ipairs(rawget(obj, "_children") or {}) do guardTree(child) end
end

local function isDescendant(obj, owner)
    local p = type(obj) == "table" and rawget(obj, "_parent")
    while type(p) == "table" do
        if p == owner then return true end
        p = rawget(p, "_parent")
    end
    return false
end

-- AuraContainerUtil.ValidateInboundScriptObject: the right object type,
-- below the button.
local function inbound(button, obj, kind)
    assert(type(obj) == "table" and rawget(obj, "_kind") == kind,
        "bad object in function call (expected object type '" .. kind .. "')")
    assert(isDescendant(obj, button), "bad object in function call (must be a descendant of owner)")
end

local function newAuraButton(container, group)
    local b = M.newWidget("Button", nil, container)
    b._template = "CustomAuraButtonTemplate"
    b._strict = true
    b._layoutForbidden = true
    b._dispelTextures = {}
    b._tooltipAnchor = { "ANCHOR_BOTTOMLEFT", 0, 0 }
    b._shown = false
    function b:SetIcon(texture) inbound(self, texture, "Texture"); self._icon = texture end
    function b:SetDurationCooldown(cooldown) inbound(self, cooldown, "Cooldown"); self._durationCooldown = cooldown end
    function b:SetApplicationCount(fontString, options)
        inbound(self, fontString, "FontString")
        for k in pairs(options or {}) do assert(k == "formatter", "mock: unknown count option " .. tostring(k)) end
        self._applicationCount = fontString
        -- UpdateAuraDisplay writes the (empty) count at once.
        fontString:SetText("")
    end
    function b:SetDurationText(fontString) inbound(self, fontString, "FontString"); self._durationText = fontString end
    function b:AddDispelTypeTexture(texture, options)
        inbound(self, texture, "Texture")
        for _, entry in ipairs(self._dispelTextures) do
            assert(entry.texture ~= texture, "Display element has already been added.")
        end
        for k in pairs(options or {}) do assert(DISPEL_TEXTURE_KEYS[k], "mock: unknown dispel option " .. tostring(k)) end
        if options and options.style ~= nil then
            assert(isEnumValue(Enum.CustomAuraButtonDispelTypeTextureStyle, options.style), "invalid style")
        end
        table.insert(self._dispelTextures, { texture = texture, options = options })
    end
    function b:SetTooltipAnchorPoint(point, x, y)
        assert(TOOLTIP_ANCHORS[point], "point must be a valid tooltip anchor point name")
        assert(x == nil or type(x) == "number", "offsetX must be a number or nil")
        assert(y == nil or type(y) == "number", "offsetY must be a number or nil")
        self._tooltipAnchor = { point, x or 0, y or 0 }
    end
    function b:SetHideTooltipInCombat(v) self._tooltipHideInCombat = v == true end
    -- UntrustedScriptExecution: scripts an addon sets would never run.
    function b:SetScript() error("mock: an aura button runs no addon scripts", 2) end
    function b:HookScript() error("mock: an aura button runs no addon scripts", 2) end
    if group.initializeFrame then
        -- securecallfunction: an error is reported, not raised.
        xpcall(function() group.initializeFrame(b) end, geterrorhandler())
    end
    b._auraRestricted = true
    guardTree(b)
    table.insert(group.frames, b)
    return b
end

-- One more batch for a group, as when it shows more auras than it has
-- buttons (this can happen in combat).
function M.GrowAuraGroup(container, key)
    local group = assert(container._groups[key], "no such group")
    for _ = 1, M.AURA_BATCH do newAuraButton(container, group) end
end

function M.NewAuraContainer(w, template)
    assert(template == "CustomAuraContainerTemplate", "mock: only CustomAuraContainerTemplate is modelled")
    w._strict = true
    w._unit = "none"
    w._enabled = true
    w._updates = 0
    w._groups = {}
    w._groupOrder = {}
    w._flow = { axis = AnchorUtil.FlowLayoutAxis.Horizontal, anchor = "TOPLEFT",
        horizontal = AnchorUtil.FlowDirection.Right, vertical = AnchorUtil.FlowDirection.Down,
        padding = { 0, 0, 0, 0 }, lineSize = math.huge }
    local function required(self, key)
        return assert(self._groups[key], "aura group '" .. tostring(key) .. "' was not found with this key.")
    end
    function w:GetUnit() return self._unit end
    function w:SetUnit(unit)
        assert(type(unit) == "string")
        if self._unit ~= unit then
            self._unit = unit
            self._updates = self._updates + 1
        end
    end
    function w:IsEnabled() return self._enabled end
    function w:SetEnabled(v) self._enabled = v end
    function w:UpdateAllAuras() self._updates = self._updates + 1 end
    function w:SetEditModePreviewEnabled(v) self._editModePreview = (v == true) end
    function w:IsEditModePreviewEnabled() return self._editModePreview ~= false end
    function w:AddAuraGroup(key, filter, options)
        assert(type(key) == "string" and key ~= "", "groupKey must be a non-empty string.")
        assert(validFilter(filter), "invalid filter string")
        assert(not self._groups[key], "aura group '" .. key .. "' already exists with this key.")
        options = options or {}
        for k in pairs(options) do assert(GROUP_KEYS[k], "mock: unknown group option " .. tostring(k)) end
        assert(options.initializeFrame == nil or type(options.initializeFrame) == "function",
            "initializeFrame must be a function or nil.")
        assert(options.templateNames == nil or type(options.templateNames) == "table",
            "templateNames must be a table or nil.")
        assert(options.candidateFilters == nil or type(options.candidateFilters) == "table",
            "candidateFilters must be a table or nil.")
        assert(options.sortMethod == nil or isEnumValue(AuraContainerSortMethod, options.sortMethod),
            "sortMethod must be a valid AuraContainerSortMethod.")
        assert(options.sortDirection == nil or isEnumValue(AuraContainerSortDirection, options.sortDirection),
            "sortDirection must be a valid AuraContainerSortDirection.")
        local max = options.maxFrameCount
        if max == nil then max = math.huge end
        assert(validMax(max), "maxFrameCount must be a non-negative integer or infinity.")
        local group = { key = key, filter = filter, max = max, enabled = true, layout = copyLayout(options.layout),
            initializeFrame = options.initializeFrame, frames = {} }
        self._groups[key] = group
        table.insert(self._groupOrder, key)
        for _ = 1, M.AURA_BATCH do newAuraButton(self, group) end
        self._layoutForbidden = true
        self._updates = self._updates + 1
    end
    function w:HasAuraGroup(key) return self._groups[key] ~= nil end
    function w:IsAuraGroupEnabled(key) return required(self, key).enabled end
    function w:SetAuraGroupEnabled(key, enabled)
        assert(type(enabled) == "boolean", "enabled must be a boolean.")
        required(self, key).enabled = enabled
    end
    function w:SetAuraGroupFilterString(key, filter)
        local group = required(self, key)
        assert(validFilter(filter), "invalid filter string")
        group.filter = filter
    end
    function w:SetAuraGroupMaxFrameCount(key, max)
        local group = required(self, key)
        assert(validMax(max), "maxFrameCount must be a non-negative integer or infinity.")
        group.max = max
    end
    -- Replaces the whole layout (merged with the defaults), like the source.
    function w:SetAuraGroupLayout(key, layout) required(self, key).layout = copyLayout(layout) end
    function w:GetAuraGroupFrameCount(key)
        local group = self._groups[key]
        return group and #group.frames or 0
    end
    function w:GetAuraGroupFrame(key, index)
        local group = self._groups[key]
        return group and group.frames[index]
    end
    function w:SetFlowLayoutAxis(axis)
        assert(isEnumValue(AnchorUtil.FlowLayoutAxis, axis), "layoutAxis must be valid.")
        self._flow.axis = axis
    end
    function w:SetFlowLayoutAnchorPoint(point)
        assert(type(point) == "string", "anchorPoint must be a string.")
        self._flow.anchor = point
    end
    function w:SetFlowLayoutGrowthDirection(h, v)
        assert(isEnumValue(AnchorUtil.FlowDirection, h), "horizontalDirection must be valid.")
        assert(isEnumValue(AnchorUtil.FlowDirection, v), "verticalDirection must be valid.")
        self._flow.horizontal, self._flow.vertical = h, v
    end
    function w:SetFlowLayoutPadding(l, r, t, b)
        for _, v in ipairs({ l, r, t, b }) do assert(type(v) == "number", "padding must be numbers.") end
        self._flow.padding = { l, r, t, b }
    end
    function w:SetFlowLayoutMaximumLineSize(size)
        assert(size == nil or type(size) == "number", "maximumLineSize must be a number or nil.")
        self._flow.lineSize = size or math.huge
    end
    M.auraContainers[#M.auraContainers + 1] = w
end

-- A frame counts as protected when it or any descendant is (the client
-- protects the parents of protected frames too).
function M.IsProtectedTree(obj)
    if rawget(obj, "_protected") then return true end
    for _, child in ipairs(rawget(obj, "_children") or {}) do
        if M.IsProtectedTree(child) then return true end
    end
    return false
end

local function newWidget(kind, name, parent)
    local w = setmetatable({
        _kind = kind, _name = name, _parent = parent, _scripts = {},
        _events = {}, _attr = {}, _points = {}, _w = 0, _h = 0, _shown = true,
    }, widget)
    M.widgets[#M.widgets + 1] = w
    -- Children in creation order (an aura button's are guarded with it).
    if type(parent) == "table" then
        local kids = rawget(parent, "_children") or {}
        rawset(parent, "_children", kids)
        kids[#kids + 1] = w
    end
    -- A frame starts one level above its parent, as in the client.
    local parentLevel = type(parent) == "table" and rawget(parent, "_level")
    w._level = parentLevel and parentLevel + 1 or 0
    function w:SetFrameLevel(level)
        assert(type(level) == "number" and level >= 0 and level <= 10000, "SetFrameLevel: level out of range")
        self._level = level
    end
    function w:GetFrameLevel() return self._level end
    function w:GetName() return self._name end
    function w:GetObjectType() return self._kind end
    function w:SetScript(s, fn) self._scripts[s] = fn end
    function w:GetScript(s) return self._scripts[s] end
    function w:HookScript(s, fn)
        local old = self._scripts[s]
        self._scripts[s] = function(...) if old then old(...) end fn(...) end
    end
    function w:RegisterEvent(e) self._events[e] = true; M.eventFrames[self] = true end
    -- Unit events: delivered only when the event's first argument is one of
    -- the registered units, like the client's RegisterUnitEvent.
    function w:RegisterUnitEvent(e, ...)
        self._events[e] = { ... }
        M.eventFrames[self] = true
        return true
    end
    function w:UnregisterEvent(e) self._events[e] = nil end
    function w:UnregisterAllEvents() self._events = {} end
    function w:SetAttribute(k, v)
        self._attr[k] = v
        local script = self._scripts.OnAttributeChanged
        if script then script(self, k, v) end
    end
    function w:GetAttribute(k) return self._attr[k] end
    function w:RegisterForClicks(...) self._clicks = { ... } end
    function w:SetSize(a, b) self._w, self._h = a, b end
    function w:SetWidth(v) self._w = v end
    function w:SetHeight(v) self._h = v end
    function w:GetWidth() return self._w end
    function w:GetHeight() return self._h end
    function w:ClearAllPoints() self._points = {} end
    -- Setting a point that is already anchored replaces that anchor.
    -- Anchoring to an aura container that has groups needs the
    -- UntrustedLayoutScriptExecution aspect (Blizzard_CustomAuraContainer.lua);
    -- children have their parent's (ForbiddenAspectConstantsDocumentation.lua).
    function w:SetPoint(point, ...)
        local relativeTo = ...
        if type(relativeTo) == "table" and rawget(relativeTo, "_layoutForbidden")
            and not M.HasLayoutAspect(self) then
            error("mock: anchoring to an aura container needs DisableUntrustedLayoutScriptsTemplate", 2)
        end
        for i, p in ipairs(self._points) do
            if p[1] == point then
                self._points[i] = { point, ... }
                return
            end
        end
        table.insert(self._points, { point, ... })
    end
    function w:GetPoint(i) local p = self._points[i or 1]; if p then return unpack(p) end end
    function w:GetCenter() return self._cx or 0, self._cy or 0 end
    -- Shown, and every parent shown too.
    function w:IsVisible()
        if not self._shown then return false end
        local parent = self._parent
        if type(parent) ~= "table" or not parent.IsVisible then return true end
        return parent:IsVisible()
    end
    -- OnShow/OnHide fire only when the frame's effective visibility
    -- changes, as in the client: hiding a frame whose parent is hidden
    -- fires nothing. (The mock does not propagate them to children.)
    function w:SetShown(v)
        v = not not v
        if v == self._shown then return end
        local wasVisible = self:IsVisible()
        self._shown = v
        if self:IsVisible() == wasVisible then return end
        local script = self._scripts[v and "OnShow" or "OnHide"]
        if script then script(self) end
    end
    function w:Show() self:SetShown(true) end
    function w:Hide() self:SetShown(false) end
    function w:IsShown() return self._shown end
    function w:SetParent(p) self._parent = p end
    function w:GetParent() return self._parent end
    function w:SetAlpha(a) self._alpha = a end
    function w:GetAlpha() return self._alpha or 1 end
    -- SimpleFrameAPI / SimpleRegionAPI: takes a secret boolean
    -- (AllowedWhenTainted); the alpha then carries the secret aspect.
    function w:SetAlphaFromBoolean(value, alphaIfTrue, alphaIfFalse)
        assert(type(M.Reveal(value)) == "boolean", "SetAlphaFromBoolean: value must be a boolean")
        self._alpha = M.Reveal(value) and alphaIfTrue or alphaIfFalse
        self._alphaSecret = M.IsSecret(value)
    end
    function w:EnableMouse(v) self._mouse = v end
    function w:IsProtected() return self._protected or false end
    function w:SetFrameStrata(v) self._strata = v end
    function w:SetFixedFrameStrata(v) self._fixedStrata = v end
    function w:SetHighlightTexture(t, blend) self._highlight = { t, blend } end
    function w:GetFrameStrata() return self._strata end
    function w:SetClipsChildren(v) self._clips = v end
    function w:GetEffectiveScale() return M.scale end
    function w:SetScale(v)
        assert(type(v) == "number" and v > 0, "SetScale: scale must be a positive number")
        self._scale = v
    end
    function w:GetScale() return self._scale or 1 end
    -- StatusBar
    function w:SetMinMaxValues(a, b) self._min, self._max = a, b end
    function w:GetMinMaxValues() return self._min, self._max end
    function w:SetValue(v) self._value = v end
    function w:GetValue() return self._value end
    function w:SetStatusBarTexture(t) self._texture = t end
    function w:SetStatusBarColor(r, g, b, a) self._color = { r, g, b, a } end
    function w:GetStatusBarTexture() return self._barTex end
    function w:SetReverseFill(v) self._reverse = v end
    -- Texture
    -- A texture shows either a file or an atlas; setting one replaces the
    -- other.
    function w:SetTexture(t, wrapH, wrapV) self._texture = t; self._atlas = nil; self._wrap = { wrapH, wrapV } end
    function w:SetHorizTile(v) self._horizTile = v end
    function w:SetBlendMode(mode)
        assert(({ DISABLE = 1, BLEND = 1, ALPHAKEY = 1, ADD = 1, MOD = 1 })[mode], "SetBlendMode: bad mode")
        self._blend = mode
    end
    function w:SetVertTile(v) self._vertTile = v end
    -- Masks (SimpleTextureAPI): only mask textures can be added, and at
    -- most M.MAX_MASKS per texture (the client raises beyond that).
    function w:AddMaskTexture(mask)
        assert(type(mask) == "table" and mask._kind == "MaskTexture", "AddMaskTexture: not a mask texture")
        self._masks = self._masks or {}
        if #self._masks >= M.MAX_MASKS then
            error(("Texture:AddMaskTexture(): Texture already has the maximum number of mask textures (%d)")
                :format(M.MAX_MASKS), 2)
        end
        table.insert(self._masks, mask)
    end
    function w:RemoveMaskTexture(mask)
        assert(type(mask) == "table" and mask._kind == "MaskTexture", "RemoveMaskTexture: not a mask texture")
        for i, m in ipairs(self._masks or {}) do
            if m == mask then table.remove(self._masks, i) return end
        end
    end
    function w:GetNumMaskTextures() return self._masks and #self._masks or 0 end
    function w:SetAtlas(atlas)
        assert(type(atlas) == "string", "SetAtlas: atlas must be a string")
        self._atlas = atlas; self._texture = nil
    end
    function w:SetTexCoord(...) self._texCoord = { ... } end
    -- Takes a secret boolean (AllowedWhenTainted).
    function w:SetDesaturated(v)
        assert(type(M.Reveal(v)) == "boolean", "SetDesaturated: value must be a boolean")
        self._desaturated = M.Reveal(v)
    end
    -- SimpleTextureBaseAPI: the cell may be secret (AllowedWhenTainted),
    -- rows and columns never are.
    function w:SetSpriteSheetCell(cell, rows, columns)
        assert(type(M.Reveal(cell)) == "number", "SetSpriteSheetCell: cell must be a number")
        assert(not M.IsSecret(rows) and not M.IsSecret(columns), "SetSpriteSheetCell: rows/columns never secret")
        self._spriteCell = { M.Reveal(cell), rows, columns }
        self._spriteSecret = M.IsSecret(cell)
    end
    -- Shader nine-slice (SimpleTextureBaseAPI, masks included).
    function w:SetTextureSliceMargins(left, top, right, bottom)
        for _, v in ipairs({ left, top, right, bottom }) do
            assert(type(v) == "number", "SetTextureSliceMargins: margins must be numbers")
        end
        self._slice = { left, top, right, bottom }
    end
    function w:GetTextureSliceMargins()
        local s = self._slice or { 0, 0, 0, 0 }
        return s[1], s[2], s[3], s[4]
    end
    function w:SetTextureSliceMode(mode)
        assert(mode == 0 or mode == 1, "SetTextureSliceMode: bad mode")
        self._sliceMode = mode
    end
    function w:ClearTextureSlice() self._slice, self._sliceMode = nil, nil end
    -- _color is the last colour given either way; _texColor keeps the
    -- colour texture's own.
    function w:SetColorTexture(r, g, b, a)
        self._color = { r, g, b, a }; self._texColor = self._color
        self._texture, self._atlas = nil, nil
    end
    -- One vertex colour replaces a gradient's per-vertex colours.
    function w:SetVertexColor(r, g, b, a) self._color = { r, g, b, a }; self._gradient = nil end
    -- SetGradient(orientation, minColor, maxColor): colours are ColorMixin
    -- objects (SimpleTextureBaseAPIDocumentation.lua).
    function w:SetGradient(orientation, minColor, maxColor)
        assert(orientation == "HORIZONTAL" or orientation == "VERTICAL", "SetGradient: bad orientation")
        for _, c in ipairs({ minColor, maxColor }) do
            assert(type(c) == "table" and type(c.r) == "number", "SetGradient: colours must be ColorMixin objects")
        end
        self._gradient = { orientation, minColor, maxColor }
    end
    function w:SetAllPoints(p) self._allPoints = p or true end
    -- Region draw layer; sublevel -8..7 like the client.
    function w:SetDrawLayer(layer, sublevel)
        sublevel = sublevel or 0
        assert(sublevel >= -8 and sublevel <= 7, "SetDrawLayer: sublevel out of range")
        self._layer, self._sublevel = layer, sublevel
    end
    function w:GetDrawLayer() return self._layer, self._sublevel or 0 end
    -- FontString / EditBox. An EditBox without a font cannot take text in
    -- the client, so the mock refuses it too.
    function w:SetFont(path, size, flags) self._font = { path, size, flags }; return true end
    function w:GetFont()
        if not self._font then return nil end
        return self._font[1], self._font[2], self._font[3]
    end
    function w:SetFontObject(o) self._fontObject = o end
    function w:SetText(t)
        if self._kind == "EditBox" or self._kind == "FontString" then
            assert(self._font or self._fontObject, self._kind .. ":SetText(): Font not set")
        end
        self._text = t
        self._fmt, self._args = nil, nil
    end
    function w:SetTextColor(r, g, b, a) self._color = { r, g, b, a } end
    function w:GetText() return self._text end
    function w:SetFormattedText(fmt, ...)
        if self._kind == "EditBox" or self._kind == "FontString" then
            assert(self._font or self._fontObject, self._kind .. ":SetFormattedText(): Font not set")
        end
        self._fmt = fmt; self._args = { ... }
        self._text = nil
    end
    function w:SetShadowOffset(x, y) self._shadow = { x, y } end
    function w:SetJustifyH(v) self._justifyH = v end
    function w:SetWordWrap(v) self._wordWrap = not not v end
    function w:GetWordWrap() return self._wordWrap ~= false end
    -- Rough text width: half the font size per character.
    function w:GetStringWidth()
        local size = self._font and self._font[2] or 12
        return #(self._text or "") * size / 2
    end
    -- Enable state (Button, CheckButton, EditBox, Slider)
    function w:SetEnabled(v) self._enabled = not not v end
    function w:IsEnabled() return self._enabled ~= false end
    function w:Enable() self._enabled = true end
    function w:Disable() self._enabled = false end
    function w:EnableMouseWheel(v) self._mouseWheel = v end
    function w:IsMouseOver() return self._mouseOver or false end
    function w:EnableKeyboard(v) self._keyboard = v end
    function w:SetPropagateKeyboardInput(v)
        assert(not M.combat, "SetPropagateKeyboardInput is restricted in combat")
        self._propagate = v
    end
    -- Slider
    function w:SetOrientation(v) self._orientation = v end
    function w:SetValueStep(v) self._step = v end
    function w:SetObeyStepOnDrag(v) self._obeyStep = v end
    function w:SetThumbTexture(asset)
        self._thumb = self._thumb or newWidget("Texture", nil, self)
        self._thumb._texture = asset
    end
    function w:GetThumbTexture() return self._thumb end
    -- CheckButton
    function w:SetChecked(v) self._checked = not not v end
    function w:GetChecked() return self._checked or false end
    function w:SetCheckedTexture(asset)
        self._checkedTex = self._checkedTex or newWidget("Texture", nil, self)
        self._checkedTex._texture = asset
    end
    function w:GetCheckedTexture() return self._checkedTex end
    -- EditBox
    function w:SetAutoFocus(v) self._autoFocus = v end
    function w:SetFocus() self._focus = true end
    function w:ClearFocus() self._focus = false end
    function w:HasFocus() return self._focus or false end
    function w:SetCursorPosition(p) self._cursor = p end
    function w:HighlightText(a, b) self._highlighted = { a, b } end
    function w:SetMaxLetters(n) self._maxLetters = n end
    function w:SetMultiLine(v) self._multiLine = v end
    -- ScrollFrame
    function w:SetScrollChild(c) self._scrollChild = c end
    function w:GetScrollChild() return self._scrollChild end
    function w:SetVerticalScroll(v) self._vscroll = v end
    function w:GetVerticalScroll() return self._vscroll or 0 end
    function w:GetVerticalScrollRange() return self._vrange or 0 end
    -- Creation
    function w:CreateTexture(n, layer, _, sublevel)
        local t = newWidget("Texture", n, self)
        t._layer, t._sublevel = layer, sublevel
        return t
    end
    function w:CreateMaskTexture(n, layer, _, sublevel)
        local t = newWidget("MaskTexture", n, self)
        t._layer, t._sublevel = layer, sublevel
        -- In the client a mask ignores texture coordinates: a mirrored mask
        -- drew unmirrored in game (ring corners came out concave). No
        -- Blizzard mask uses them either. Mask files carry their own shape.
        function t:SetTexCoord()
            error("MaskTexture:SetTexCoord: masks ignore texture coordinates in the client", 2)
        end
        -- Nor does a mask's own scale change a sliced mask's corners (in
        -- game a scaled mask kept its full margin as corner size).
        function t:SetScale()
            error("MaskTexture:SetScale: the client ignores a mask's scale for its slices", 2)
        end
        return t
    end
    function w:CreateFontString(n, layer)
        local fs = newWidget("FontString", n, self)
        fs._layer, fs._sublevel = layer or "ARTWORK", 0
        return fs
    end
    -- Animation groups: Play marks the group playing; M.FinishAnimations
    -- ends every playing group like the client would when it is done.
    function w:CreateAnimationGroup()
        local group = newWidget("AnimationGroup", nil, self)
        group._anims = {}
        function group:CreateAnimation(kind)
            local anim = newWidget(kind, nil, self)
            function anim:SetFromAlpha(v) self._from = v end
            function anim:SetToAlpha(v) self._to = v end
            function anim:SetDuration(v) self._duration = v end
            function anim:SetStartDelay(v) self._delay = v end
            function anim:SetOrder(v) self._order = v end
            -- FlipBook (SimpleAnimFlipBookAPI)
            function anim:SetFlipBookRows(v) self._rows = v end
            function anim:SetFlipBookColumns(v) self._columns = v end
            function anim:SetFlipBookFrames(v) self._frames = v end
            function anim:SetFlipBookFrameWidth(v) self._frameWidth = v end
            function anim:SetFlipBookFrameHeight(v) self._frameHeight = v end
            table.insert(self._anims, anim)
            return anim
        end
        function group:SetToFinalAlpha(v) self._toFinal = v end
        function group:SetLooping(v)
            assert(v == "NONE" or v == "REPEAT" or v == "BOUNCE", "SetLooping: bad loop type")
            self._looping = v
        end
        function group:Play() self._playing = true; M.playing[self] = true end
        function group:Stop() self._playing = false; M.playing[self] = nil end
        function group:IsPlaying() return self._playing or false end
        return group
    end
    -- Cooldown. _cooldown holds { start, duration } or { object = duration
    -- object }; nil when cleared.
    function w:SetCooldown(start, duration) self._cooldown = { start, duration } end
    function w:SetCooldownFromDurationObject(duration) self._cooldown = { object = duration } end
    function w:Clear() self._cooldown = nil end
    function w:SetHideCountdownNumbers(v) self._hideNumbers = v end
    function w:GetCountdownFontString()
        self._countdown = self._countdown or newWidget("FontString", nil, self)
        return self._countdown
    end
    -- Mouse: motion (tooltips) and clicks can be switched separately.
    function w:SetMouseClickEnabled(v) self._clickEnabled = v end
    function w:SetMouseMotionEnabled(v) self._motionEnabled = v end
    -- Mouse buttons that go through the frame to what lies below it
    -- (SimpleScriptRegionAPI; protected on protected frames in combat).
    function w:SetPassThroughButtons(...) self._passThrough = { ... } end
    -- PlayerModel
    function w:SetUnit(unit) self._modelUnit = unit; return true end
    function w:ClearModel() self._modelUnit = nil; self._cleared = true end
    function w:SetPortraitZoom(z) self._zoom = z end
    -- Movable
    function w:SetMovable(v) self._movable = v end
    function w:RegisterForDrag(...) self._drag = { ... } end
    function w:StartMoving() end
    function w:StopMovingOrSizing() end
    function w:SetClampedToScreen() end
    -- Protected frames: explicitly protected ones (secure templates) and
    -- every frame with a protected descendant. In combat, tainted code may
    -- not show, hide, move, size, reparent or re-attribute them
    -- (ADDON_ACTION_BLOCKED in the client).
    for _, method in ipairs({ "SetShown", "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight",
                              "SetAttribute", "SetParent", "EnableMouse", "SetAllPoints",
                              "SetPassThroughButtons" }) do
        local original = w[method]
        if original then
            w[method] = function(self, ...)
                if M.combat and M.secureDepth == 0 and M.IsProtectedTree(self) then
                    M.blocked[#M.blocked + 1] = method
                    error("mock: " .. method .. " on a protected frame in combat", 2)
                end
                return original(self, ...)
            end
        end
    end
    -- Made under an aura button after it was restricted: restricted too.
    if restricted(w) then guardTree(w) end
    return w
end
M.newWidget = newWidget

function M.Reset()
    M.eventFrames = {}
    M.frames = {}
    M.widgets = {}         -- every widget created, in creation order
    M.chat = {}
    M.combat = false
    M.blocked = {}         -- protected-frame calls refused in combat
    M.secureDepth = 0      -- > 0 while mock secure code runs
    M.units = {}
    -- RegionalUniqueNamesEnabled() answer; the client's default is unknown.
    M.regionalUniqueNames = false
    M.cvars = {}
    M.macros = {}          -- list of { name=, icon=, body=, perChar= }
    M.macroFrameShown = false
    M.macroWrites = 0      -- CreateMacro/EditMacro calls (must stay 0)
    M.macroDeletes = 0     -- DeleteMacro calls
    M.errors = {}          -- whatever reached the global error handler
    M.timers = {}          -- queued C_Timer.After callbacks
    M.now = 1000           -- GetTime(), advanced by M.Tick
    M.group = {}           -- party unit tokens ("party1", ...) while grouped
    M.headerUpdates = 0    -- how often a group header laid out its buttons
    M.playing = {}         -- animation groups that are playing
    -- Aura containers: every one made, in order; M.auraContainerMissing
    -- makes CreateFrame refuse the type (a client without it).
    M.auraContainers = {}
    M.auraContainerMissing = false
    M.aurasSecret = false
    -- Blizzard_SharedXMLBase/AnchorUtil.lua and Blizzard_AuraContainerShared.lua.
    _G.AnchorUtil = { FlowLayoutAxis = { Horizontal = 0, Vertical = 1 },
        FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }
    _G.AuraContainerSortMethod = { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2, ImportantOnly = 3,
        Expiration = 4, ExpirationOnly = 5, Name = 6, NameOnly = 7, AuraInstanceIDOnly = 8 }
    _G.AuraContainerSortDirection = { Normal = 0, Reverse = 1 }

    -- Pixel grid. By default one physical pixel is one UI unit (768 pixels
    -- high, scale 1), so layout numbers stay whole; tests change these.
    M.scale = 1
    M.screenW, M.screenH = 1024, 768
    _G.GetPhysicalScreenSize = function() return M.screenW, M.screenH end
    -- Round is math.round in the client (MathUtil.lua): half away from zero.
    _G.Round = function(v) if v < 0 then return -math.floor(-v + 0.5) end return math.floor(v + 0.5) end
    -- Blizzard_SharedXML/PixelUtil.lua, the functions the addon uses.
    _G.PixelUtil = {}
    function PixelUtil.GetPixelToUIUnitFactor()
        local _, physicalHeight = GetPhysicalScreenSize()
        return 768.0 / physicalHeight
    end
    function PixelUtil.GetNearestPixelSize(uiUnitSize, layoutScale, minPixels)
        if uiUnitSize == 0 and (not minPixels or minPixels == 0) then return 0 end
        local uiUnitFactor = PixelUtil.GetPixelToUIUnitFactor()
        local numPixels = Round((uiUnitSize * layoutScale) / uiUnitFactor)
        if minPixels then
            if uiUnitSize < 0.0 then
                if numPixels > -minPixels then numPixels = -minPixels end
            else
                if numPixels < minPixels then numPixels = minPixels end
            end
        end
        return numPixels * uiUnitFactor / layoutScale
    end

    _G.UIParent = newWidget("Frame", "UIParent")
    _G.UIParent._w, _G.UIParent._h = 1920, 1080
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg)
        assert(type(msg) == "string", "chat message must be a plain string")
        table.insert(M.chat, msg)
    end }
    _G.CreateFrame = function(kind, name, parent, template)
        if kind == "AuraContainer" and M.auraContainerMissing then
            error("CreateFrame: Unknown frame type 'AuraContainer'", 2)
        end
        local w = newWidget(kind, name, parent)
        w._template = template
        if template and template:find("DisableUntrustedLayoutScriptsTemplate") then w._layoutForbidden = true end
        if kind == "AuraContainer" then M.NewAuraContainer(w, template) end
        if template and template:find("Secure") then w._protected = true end
        if kind == "StatusBar" then w._barTex = newWidget("Texture", nil, w) end
        if name then _G[name] = w end
        table.insert(M.frames, w)
        if template == "SecureGroupHeaderTemplate" then makeGroupHeader(w) end
        if template == "SecureGroupPetHeaderTemplate" then makeGroupHeader(w, true) end
        if M.templates[template] then M.templates[template](w) end
        return w
    end
    _G.InCombatLockdown = function() return M.combat end
    -- In an inn or a city (PLAYER_UPDATE_RESTING when it changes).
    M.resting = false
    _G.IsResting = function() return M.resting end
    _G.GetTime = function() return M.now end
    _G.IsInGroup = function() return #M.group > 0 end
    _G.geterrorhandler = function()
        return function(err) table.insert(M.errors, err) end
    end
    _G.WOW_PROJECT_MAINLINE = 1
    _G.WOW_PROJECT_ID = 1
    _G.GetBuildInfo = function() return "1.60.1", "69977", "Sep 22 2026", 16001 end
    _G.issecretvalue = M.IsSecret
    _G.RegisterUnitWatch = function(f) f._unitWatch = true end
    _G.UnregisterUnitWatch = function(f) f._unitWatch = nil end
    _G.RAID_CLASS_COLORS = {
        WARLOCK = { r = 0.53, g = 0.53, b = 0.93, GetRGB = function(c) return c.r, c.g, c.b end },
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43, GetRGB = function(c) return c.r, c.g, c.b end },
    }
    -- Class icons (Blizzard_SharedXML/SharedConstants.lua); atlases the
    -- client knows are listed in M.atlases, GetAtlasInfo gives nothing for
    -- any other name.
    _G.CLASS_ICON_TCOORDS = {
        WARRIOR = { 0, 0.25, 0, 0.25 },
        WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
    }
    M.atlases = { ["classicon-warrior"] = true, ["classicon-warlock"] = true,
        -- Classification badges (Blizzard_NamePlateClassificationFrame.lua).
        ["nameplates-icon-elite-gold"] = true, ["nameplates-icon-elite-silver"] = true,
        ["UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star"] = true,
        -- The target frame's high-level (boss) icon (Blizzard_UnitFrame/Mainline/TargetFrame.xml).
        ["UI-HUD-UnitFrame-Target-HighLevelTarget_Icon"] = true,
        -- Group icons (PartyFrameTemplates.xml, ReadyCheck.lua, CompactUnitFrame.lua).
        ["UI-HUD-UnitFrame-Player-Group-LeaderIcon"] = true, ["UI-HUD-UnitFrame-Player-Group-GuideIcon"] = true,
        ["UI-LFG-ReadyMark-Raid"] = true, ["UI-LFG-DeclineMark-Raid"] = true, ["UI-LFG-PendingMark-Raid"] = true,
        ["RaidFrame-Icon-Rez"] = true }
    _G.C_Texture = {
        GetAtlasInfo = function(atlas)
            if M.atlases[atlas] then return { file = atlas, width = 64, height = 64 } end
        end,
    }
    _G.Constants = {}
    _G.MacroFrame = M.NewMacroFrame()
    _G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGB = function(c) return c.r, c.g, c.b end } end
    _G.ForeverUnitFrames = nil
    _G.ForeverUnitFramesDB = nil

    -- Unit API: data comes from M.units[unit]; fields may hold secret proxies.
    local function u(unit) return M.units[unit] end
    _G.UnitExists = function(unit) return u(unit) ~= nil end
    -- name, surname (nil when the unit has none).
    _G.RegionalUniqueNamesEnabled = function() return M.regionalUniqueNames == true end
    _G.UnitName = function(unit) local d = u(unit); if d then return d.name, d.surname end end
    _G.UnitLevel = function(unit) local d = u(unit); return d and d.level or 0 end
    _G.UnitClass = function(unit) local d = u(unit); if d then return d.className, d.class end end
    -- Takes secret class tokens (SecretArguments = AllowedWhenTainted); a
    -- secret token gives a colour of secret components.
    _G.C_ClassColor = {
        GetClassColor = function(token)
            local c = RAID_CLASS_COLORS[M.Reveal(token)]
            assert(c, "GetClassColor: unknown class")
            if not M.IsSecret(token) then return { r = c.r, g = c.g, b = c.b } end
            return { r = M.Secret(c.r), g = M.Secret(c.g), b = M.Secret(c.b) }
        end,
    }
    _G.UnitIsPlayer = function(unit) local d = u(unit); return d and d.isPlayer or false end
    _G.UnitIsVisible = function(unit) local d = u(unit); return d ~= nil and d.visible ~= false end
    -- Records the last unit drawn into each texture.
    _G.SetPortraitTexture = function(texture, unit) texture._portraitUnit = unit end
    _G.UnitIsFriend = function(_, unit) local d = u(unit); return d and d.friend or false end
    _G.UnitReaction = function(unit) local d = u(unit); return d and d.reaction end
    _G.UnitHealth = function(unit) local d = u(unit); return d and d.health or 0 end
    _G.UnitHealthMax = function(unit) local d = u(unit); return d and d.healthMax or 0 end
    _G.UnitHealthMissing = function(unit) local d = u(unit); return d and d.healthMissing or 0 end
    _G.UnitHealthPercent = function(unit, _, curve)
        local d = u(unit); local p = d and d.healthPercent or 0
        if curve then return curve:Evaluate(p) end
        return p
    end
    _G.UnitPower = function(unit) local d = u(unit); return d and d.power or 0 end
    _G.UnitPowerMax = function(unit) local d = u(unit); return d and d.powerMax or 0 end
    _G.UnitPowerType = function(unit) local d = u(unit); return d and d.powerType or 0, d and d.powerToken or "MANA" end
    _G.UnitPowerPercent = function(unit, _, _, curve)
        local d = u(unit); local p = d and d.powerPercent or 0
        if curve then return curve:Evaluate(p) end
        return p
    end
    -- Casts: d.cast / d.channel hold the values UnitCastingInfo /
    -- UnitChannelInfo return, in the client's order; d.castDuration the
    -- object UnitCastingDuration / UnitChannelDuration return.
    _G.UnitCastingInfo = function(unit)
        local d = u(unit); local c = d and d.cast
        if c then return c.name, c.name, c.texture, c.startMs, c.endMs, false, c.castID, c.notInterruptible, 1 end
    end
    _G.UnitChannelInfo = function(unit)
        local d = u(unit); local c = d and d.channel
        if c then return c.name, c.name, c.texture, c.startMs, c.endMs, false, c.notInterruptible, 1 end
    end
    _G.UnitCastingDuration = function(unit) local d = u(unit); return d and d.castDuration end
    _G.UnitChannelDuration = function(unit) local d = u(unit); return d and d.castDuration end
    _G.C_StringUtil = { TruncateWhenZero = function(n) return n end }
    _G.UnitPowerMissing = function(unit) local d = u(unit); return d and d.powerMissing or 0 end
    -- Shields and heals (UnitDocumentation.lua): the total absorb is never
    -- nil; incoming heals are nil when nothing is known. d.absorbs;
    -- d.healsAll / d.healsMine.
    -- What a unit is (UnitDocumentation.lua): d.classification (default
    -- "normal", never nil) and d.bossMob.
    _G.UnitClassification = function(unit) local d = u(unit); return d and d.classification or "normal" end
    _G.UnitIsBossMob = function(unit) local d = u(unit); return d and d.bossMob or false end
    -- The group (UnitDocumentation.lua: leader and assistant are
    -- SecretWhenUnitIdentityRestricted). d.leader, d.assistant;
    -- M.groupSecret hands both back secret. Ready checks and incoming
    -- resurrections are undocumented globals Blizzard's Mainline frames
    -- call: d.readyCheck ("ready", "notready", "waiting" or nil),
    -- d.incomingRez. M.lfgRestricted: HasLFGRestrictions (a guide leads).
    M.groupSecret = false
    M.lfgRestricted = false
    local function groupFlag(v)
        v = v or false
        if M.groupSecret then return M.Secret(v) end
        return v
    end
    _G.UnitIsGroupLeader = function(unit) local d = u(unit); return groupFlag(d and d.leader) end
    _G.UnitIsGroupAssistant = function(unit) local d = u(unit); return groupFlag(d and d.assistant) end
    -- d.offline: the unit's player is disconnected. d.dead / d.ghost:
    -- dead, or a ghost (UnitIsDeadOrGhost is true for both). Any of them
    -- may be a secret proxy.
    _G.UnitIsConnected = function(unit)
        local d = u(unit)
        if d and M.IsSecret(d.offline) then return d.offline end
        return d ~= nil and not d.offline
    end
    _G.UnitIsGhost = function(unit) local d = u(unit); return d and d.ghost or false end
    _G.UnitIsDeadOrGhost = function(unit)
        local d = u(unit)
        if not d then return false end
        if M.IsSecret(d.dead) then return d.dead end
        return (d.dead or d.ghost) and true or false
    end
    -- Range (UnitDocumentation.lua: UnitInRange has SecretReturns).
    -- d.inRange (default true); d.rangeChecked (default: only group
    -- members are checked); M.rangeSecret hands both answers back secret.
    -- CheckInteractDistance: d.near (default true); M.interactError makes
    -- it raise. M.rangeQueries counts UnitInRange calls.
    M.rangeSecret = false
    M.interactError = false
    M.rangeQueries = 0
    local function groupToken(unit) return unit:match("^party%d$") or unit:match("^partypet%d$") end
    -- Threat (UnitDocumentation.lua, ThreatDocumentation.lua): one unit,
    -- d.threat (its highest status, 0..3 or nil); unit and mob,
    -- M.units[mob].threatOf[unit]. Either may be a secret proxy.
    _G.UnitThreatSituation = function(unit, mob)
        if mob then
            local m = u(mob)
            return m and m.threatOf and m.threatOf[unit]
        end
        local d = u(unit)
        return d and d.threat
    end
    M.threatColors = { [0] = { 0.69, 0.69, 0.69 }, { 1, 1, 0.47 }, { 1, 0.6, 0 }, { 1, 0, 0 } }
    _G.GetThreatStatusColor = function(status)
        assert(not M.IsSecret(status), "GetThreatStatusColor: secret status from tainted code")
        local c = assert(M.threatColors[status], "GetThreatStatusColor: bad status")
        return c[1], c[2], c[3]
    end
    -- Two tokens name the same unit when they share its data table.
    _G.UnitIsUnit = function(a, b) return M.units[a] ~= nil and M.units[a] == M.units[b] end
    _G.UnitInParty = function(unit)
        local d = u(unit)
        return d ~= nil and (d.inParty or groupToken(unit) ~= nil) or false
    end
    _G.UnitInRange = function(unit)
        M.rangeQueries = M.rangeQueries + 1
        local d = u(unit)
        local inRange, checked = false, false
        if d then
            inRange = d.inRange ~= false
            checked = d.rangeChecked
            if checked == nil then checked = groupToken(unit) ~= nil or d.inParty == true end
        end
        if M.rangeSecret == "inRange" then return M.Secret(inRange), checked end
        if M.rangeSecret then return M.Secret(inRange), M.Secret(checked) end
        return inRange, checked
    end
    -- d.near: true, false, or "nil" for no answer. M.interactQueries
    -- counts the calls.
    M.interactQueries = 0
    _G.CheckInteractDistance = function(unit, index)
        assert(type(index) == "number" and index >= 1 and index <= 5, "CheckInteractDistance: bad index")
        M.interactQueries = M.interactQueries + 1
        if M.interactError then error("CheckInteractDistance refused") end
        local d = u(unit)
        if d and d.near == "nil" then return nil end
        return d ~= nil and d.near ~= false
    end
    _G.GetReadyCheckStatus = function(unit) local d = u(unit); return d and d.readyCheck end
    _G.UnitHasIncomingResurrection = function(unit) local d = u(unit); return d and d.incomingRez or false end
    _G.HasLFGRestrictions = function() return M.lfgRestricted end
    -- Raid target markers (RaidMarkersDocumentation.lua: SecretReturns):
    -- d.raidTarget (1..8 or nil); M.raidTargetsSecret hands a set index
    -- back secret.
    M.raidTargetsSecret = false
    _G.GetRaidTargetIndex = function(unit)
        local d = u(unit)
        local index = d and d.raidTarget
        if index ~= nil and M.raidTargetsSecret then return M.Secret(index) end
        return index
    end
    _G.UnitGetTotalAbsorbs = function(unit) local d = u(unit); return d and d.absorbs or 0 end
    _G.UnitGetIncomingHeals = function(unit, healer)
        local d = u(unit)
        if not d then return nil end
        if healer == "player" then return d.healsMine end
        return d.healsAll
    end

    _G.C_Timer = { After = function(sec, fn) table.insert(M.timers, { sec = sec, fn = fn }) end }

    -- Curves: Evaluate passes secrets through as secrets.
    _G.C_CurveUtil = {
        CreateCurve = function()
            local c = { points = {} }
            function c:AddPoint(x, y) table.insert(self.points, { x, y }) end
            function c:Evaluate(x)
                if M.IsSecret(x) then return M.Secret(M.Reveal(x) * 100) end
                return x * 100
            end
            return c
        end,
        CreateColorCurve = function()
            local c = { points = {} }
            function c:SetType(t) self.type = t end
            function c:AddPoint(x, color) table.insert(self.points, { x, color }) end
            function c:Evaluate() return { GetRGB = function() return 1, 1, 1 end } end
            return c
        end,
    }

    _G.Enum = {
        UITextureSliceMode = { Stretched = 0, Tiled = 1 },
        LuaCurveType = { Linear = 0, Step = 1, Cosine = 2, Cubic = 3 },
        UnitAuraSortRule = { Unsorted = 0, Default = 1, BigDefensive = 2, Expiration = 3, ExpirationOnly = 4,
            Name = 5, NameOnly = 6 },
        CustomAuraButtonDispelTypeTextureStyle = { Border = 0, BorderWithIcon = 1, Icon = 2, PreserveAsset = 3,
            CustomAsset = 4 },
    }

    -- Auras: M.units[unit].auras lists { auraInstanceID, icon, applications,
    -- dispelName, dispelType (the client's number), duration,
    -- expirationTime, isHelpful, mine, dispellable }; any field may be a
    -- secret. M.auraError makes every aura query raise, as the client does
    -- when auras are locked for addons. A secret aura instance ID handed
    -- back to the client raises too (tainted callers may not pass secrets).
    M.auraError = false
    local function refuseAuras()
        if M.auraError then error("Auras cannot be accessed when secret while tainted", 3) end
    end
    local function auraByID(unit, id)
        assert(not M.IsSecret(id), "secret aura instance ID passed back to the client")
        local d = u(unit)
        for _, a in ipairs(d and d.auras or {}) do
            if M.Reveal(a.auraInstanceID) == id then return a end
        end
    end
    -- The value comes back secret when the field it is made from is.
    local function like(field, v)
        if M.IsSecret(field) then return M.Secret(v) end
        return v
    end
    -- Filter strings as the client reads them: "HELPFUL|PLAYER" and so on;
    -- a leading "!" negates a token ("!PLAYER": not cast by the player,
    -- AuraUtil.AuraFilterNegationPrefix). An unknown token raises.
    local FILTER_TOKENS = { HELPFUL = true, HARMFUL = true, PLAYER = true, RAID = true }
    local function auraMatches(a, filter)
        local want = {}
        for token in filter:gmatch("[^|]+") do
            local negated = token:sub(1, 1) == "!"
            if negated then token = token:sub(2) end
            if not FILTER_TOKENS[token] then error("Unknown aura filter component: " .. token, 3) end
            want[token] = not negated
        end
        local helpful = M.Reveal(a.isHelpful) == true
        local has = { HELPFUL = helpful, HARMFUL = not helpful, PLAYER = M.Reveal(a.mine) == true,
            RAID = M.Reveal(a.dispellable) == true }
        for token, on in pairs(want) do
            if has[token] ~= on then return false end
        end
        return true
    end
    M.auraQueries = 0      -- GetUnitAuras calls
    M.lastAuraQuery = nil  -- { unit, filter, maxCount, sortRule } of the last one
    M.auraQueryLog = {}    -- the filter of every GetUnitAuras call, in order
    M.auraLookups = 0      -- GetAuraDataByAuraInstanceID calls
    _G.C_UnitAuras = {
        GetAuraDataByAuraInstanceID = function(unit, id)
            refuseAuras()
            M.auraLookups = M.auraLookups + 1
            return auraByID(unit, id)
        end,
        IsAuraFilteredOutByInstanceID = function(unit, id, filter)
            refuseAuras()
            local a = auraByID(unit, id)
            return not (a and auraMatches(a, filter))
        end,
        GetUnitAuras = function(unit, filter, maxCount, sortRule)
            refuseAuras()
            M.auraQueries = M.auraQueries + 1
            M.lastAuraQuery = { unit = unit, filter = filter, maxCount = maxCount, sortRule = sortRule }
            M.auraQueryLog[#M.auraQueryLog + 1] = filter
            local d, list = u(unit), {}
            for _, a in ipairs(d and d.auras or {}) do
                if auraMatches(a, filter) and (not maxCount or #list < maxCount) then list[#list + 1] = a end
            end
            return list
        end,
        GetAuraDuration = function(unit, id)
            refuseAuras()
            local a = auraByID(unit, id)
            if a then return { _duration = a.duration, _expires = a.expirationTime } end
        end,
        GetAuraApplicationDisplayCount = function(unit, id, minCount)
            refuseAuras()
            local a = auraByID(unit, id)
            if not a then return end
            local n = M.Reveal(a.applications) or 0
            return like(a.applications, n >= (minCount or 2) and tostring(n) or "")
        end,
        -- The colour of the curve point at the aura's dispel type (step
        -- curves: the last point at or below it).
        GetAuraDispelTypeColor = function(unit, id, curve)
            refuseAuras()
            local a = auraByID(unit, id)
            local x = M.Reveal(a.dispelType) or 0
            local color
            for _, p in ipairs(curve.points) do
                if p[1] <= x then color = p[2] end
            end
            local r, g, b, alpha = color.r, color.g, color.b, color.a or 1
            return { GetRGBA = function()
                return like(a.dispelType, r), like(a.dispelType, g), like(a.dispelType, b), like(a.dispelType, alpha)
            end }
        end,
    }

    -- Tooltip: M.tooltipAura records the last aura tooltip asked for.
    M.tooltipAura = nil
    _G.GameTooltip = newWidget("GameTooltip", "GameTooltip")
    GameTooltip._shown = false
    function GameTooltip:SetOwner(owner, anchor) self._owner, self._anchor = owner, anchor end
    function GameTooltip:IsOwned(f) return self._owner == f end
    function GameTooltip:Hide() self._shown = false; self._owner = nil end
    -- Unit tooltips (M.tooltipUnit: the last unit asked for).
    M.tooltipUnit = nil
    function GameTooltip:SetUnit(unit)
        M.tooltipUnit = unit
        self._shown = true
        return true
    end
    function GameTooltip:Show() self._shown = true end
    -- Totem tooltips (M.tooltipTotem: the last slot asked for).
    M.tooltipTotem = nil
    function GameTooltip:SetTotem(slot)
        assert(not M.IsSecret(slot), "secret totem slot passed to the tooltip")
        M.tooltipTotem = slot
        self._shown = true
    end
    function GameTooltip:FadeOut() self._shown = false end
    -- Text lines of the tooltip since the last SetOwner.
    M.tooltipLines = {}
    local setOwner = GameTooltip.SetOwner
    function GameTooltip:SetOwner(owner, anchor)
        M.tooltipLines = {}
        setOwner(self, owner, anchor)
    end
    function GameTooltip:SetText(text) M.tooltipLines = { text } end
    function GameTooltip:AddLine(text) M.tooltipLines[#M.tooltipLines + 1] = text end

    -- The minimap: 140 x 140 around (1700, 900) at scale 1. GetMinimapShape
    -- exists only when a minimap addon defines it (M.minimapShape).
    _G.Minimap = newWidget("Frame", "Minimap")
    Minimap._w, Minimap._h, Minimap._cx, Minimap._cy = 140, 140, 1700, 900
    M.minimapShape = nil
    _G.GetMinimapShape = nil
    -- The cursor in physical coordinates (GetCursorPosition).
    M.cursor = { 0, 0 }
    _G.GetCursorPosition = function() return M.cursor[1], M.cursor[2] end
    _G.LibStub = nil
    local function auraTooltip(method)
        GameTooltip[method] = function(self, unit, id, filter)
            refuseAuras()
            assert(not M.IsSecret(id), "secret aura instance ID passed to the tooltip")
            M.tooltipAura = { method = method, unit = unit, id = id, filter = filter }
            self._shown = true
        end
    end
    auraTooltip("SetUnitBuffByAuraInstanceID")
    auraTooltip("SetUnitDebuffByAuraInstanceID")

    -- Totems (Blizzard_FrameXMLBase/Constants.lua, TotemDocumentation.lua).
    -- M.totems[slot] = { name, start, duration, icon, spellID } for a slot
    -- that holds a totem. M.totemsSecret: every GetTotemInfo value comes
    -- back secret (SecretWhenTotemSlotSecret: combat, encounter, challenge
    -- mode or PvP match restrictions). GetTotemDuration's duration object
    -- is never secret itself. DestroyTotem is only reached through secure
    -- code (M.SecureClick); M.destroyedTotems lists the slots.
    M.totems = {}
    M.totemsSecret = false
    M.destroyedTotems = {}
    _G.MAX_TOTEMS = 4
    _G.FIRE_TOTEM_SLOT, _G.EARTH_TOTEM_SLOT, _G.WATER_TOTEM_SLOT, _G.AIR_TOTEM_SLOT = 1, 2, 3, 4
    _G.STANDARD_TOTEM_PRIORITIES = { 1, 2, 3, 4 }
    _G.SHAMAN_TOTEM_PRIORITIES = { EARTH_TOTEM_SLOT, FIRE_TOTEM_SLOT, WATER_TOTEM_SLOT, AIR_TOTEM_SLOT }
    local function validSlot(slot)
        assert(not M.IsSecret(slot), "secret totem slot passed back to the client")
        return type(slot) == "number" and slot >= 1 and slot <= MAX_TOTEMS
    end
    -- haveTotem, totemName, startTime, duration, icon, modRate, spellID;
    -- nothing for a slot that does not exist (MayReturnNothing).
    _G.GetTotemInfo = function(slot)
        if not validSlot(slot) then return end
        local t = M.totems[slot]
        local r
        if t then
            r = { true, t.name or "Totem", t.start or 0, t.duration or 0, t.icon or 0, 1, t.spellID or 0 }
        else
            r = { false, "", 0, 0, 0, 1, 0 }
        end
        if M.totemsSecret then
            for i = 1, #r do r[i] = M.Secret(r[i]) end
        end
        return unpack(r)
    end
    _G.GetTotemDuration = function(slot)
        assert(validSlot(slot), "GetTotemDuration: bad slot")
        local t = M.totems[slot]
        return { _start = t and t.start or 0, _duration = t and t.duration or 0 }
    end
    _G.DestroyTotem = function(slot)
        assert(M.secureDepth > 0, "DestroyTotem is protected: only secure code may call it")
        assert(validSlot(slot), "DestroyTotem: bad slot")
        M.destroyedTotems[#M.destroyedTotems + 1] = slot
        M.totems[slot] = nil
    end

    -- CVars
    _G.C_CVar = {
        RegisterCVar = function(name, default) if M.cvars[name] == nil then M.cvars[name] = default or "" end end,
        GetCVar = function(name) return M.cvars[name] end,
        SetCVar = function(name, v) M.cvars[name] = v; return true end,
    }

    -- Macros (character macros live at indices MAX_ACCOUNT_MACROS + 1 ...)
    _G.GetMacroIndexByName = function(name)
        for i, m in ipairs(M.macros) do if m.name == name then return 120 + i end end
        return 0
    end
    -- A body that went through the server comes back from a later session
    -- with a line break appended, and the macro cache uses CRLF line endings
    -- (measured in the client); the client may then cut the body to 255
    -- characters. M.RoundTripMacros simulates that.
    _G.GetMacroBody = function(index)
        local m = M.macros[index - 120]
        if not m then return nil end
        local body = m.body
        if m.crlf then body = body:gsub("\n", "\r\n") end
        body = body .. (m.trailer or "")
        -- What comes back from the server may be cut to the body limit
        -- after the line break was appended.
        if m.trailer or m.crlf then body = body:sub(1, 255) end
        return body
    end
    -- The addon never writes macros: any attempt is counted and fails.
    _G.CreateMacro = function()
        M.macroWrites = M.macroWrites + 1
        error("the addon must not create macros")
    end
    _G.EditMacro = function()
        M.macroWrites = M.macroWrites + 1
        error("the addon must not edit macros")
    end
    -- Deleting shifts the indices of every macro after it, as in the client.
    _G.DeleteMacro = function(index)
        assert(not M.combat, "DeleteMacro in combat")
        assert(M.macros[index - 120], "DeleteMacro: no macro at " .. tostring(index))
        M.macroDeletes = M.macroDeletes + 1
        table.remove(M.macros, index - 120)
    end

    _G.SlashCmdList = {}
    _G.UISpecialFrames = {}
    _G.C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end }
    -- Post-hook: the original runs first, then fn with the same arguments.
    _G.hooksecurefunc = function(tbl, name, fn)
        if type(tbl) == "string" then tbl, name, fn = _G, tbl, name end
        local original = tbl[name]
        tbl[name] = function(...)
            local r = { original(...) }
            fn(...)
            return unpack(r)
        end
    end

    -- Key bindings: only ESC is bound (to the game menu).
    _G.GetBindingFromClick = function(key)
        if key == "ESCAPE" then return "TOGGLEGAMEMENU" end
    end

    -- Colour picker. Like the client, opening it sets the wheel colour, which
    -- fires OnColorSelect -> swatchFunc/opacityFunc before the alpha is set.
    M.colorPicker = nil
    M.pickRGB, M.pickA = { 1, 1, 1 }, 1
    _G.ColorPickerFrame = newWidget("Frame", "ColorPickerFrame")
    _G.ColorPickerFrame._shown = false
    function ColorPickerFrame:SetupColorPickerAndShow(info)
        M.colorPicker = info
        self.swatchFunc, self.opacityFunc, self.cancelFunc = info.swatchFunc, info.opacityFunc, info.cancelFunc
        info.previousValues = { r = info.r, g = info.g, b = info.b, a = info.opacity }
        M.pickRGB = { info.r, info.g, info.b }
        if info.swatchFunc then info.swatchFunc() end
        if info.opacityFunc then info.opacityFunc() end
        self:Show()
    end
    function ColorPickerFrame:GetColorRGB() return M.pickRGB[1], M.pickRGB[2], M.pickRGB[3] end
    function ColorPickerFrame:GetColorAlpha() return M.pickA end
    function ColorPickerFrame:GetPreviousValues()
        local p = M.colorPicker.previousValues
        return p.r, p.g, p.b, p.a
    end
end

-- Presses a key: the frame gets OnKeyDown only while it takes keyboard
-- input. Returns whether the key went on to the game (propagated).
function M.PressKey(frame, key)
    if not frame._keyboard or not frame:IsShown() then return true end
    local handler = frame._scripts.OnKeyDown
    if handler then handler(frame, key) end
    return frame._propagate or false
end

-- The macros as a later session reads them: every body gets `trailer`
-- appended (and CRLF line endings if `crlf`).
function M.RoundTripMacros(trailer, crlf)
    for _, m in ipairs(M.macros) do
        m.trailer = (m.trailer or "") .. (trailer or "")
        m.crlf = m.crlf or crlf or nil
    end
end

-- An old settings backup as versions up to 0.2.x left it: character macros
-- "FUF Save 1".."FUF Save n", each "#Forever Unit Frames backup i/n - keep"
-- plus one chunk of the encoded profile. `chunks` is a string (one macro)
-- or a list of strings. Returns a new macro list.
function M.BackupMacros(chunks)
    if type(chunks) == "string" then chunks = { chunks } end
    local list = {}
    for i, chunk in ipairs(chunks) do
        list[i] = { name = "FUF Save " .. i, icon = "INV_MISC_QUESTIONMARK", perChar = true,
            body = ("#Forever Unit Frames backup %d/%d - keep\n"):format(i, #chunks) .. chunk }
    end
    return list
end

-- Blizzard's macro window (load-on-demand in the client). Shown state is
-- driven by M.macroFrameShown; tests call its OnHide script to close it.
function M.NewMacroFrame()
    local f = newWidget("Frame", "MacroFrame")
    function f:IsShown() return M.macroFrameShown end
    return f
end

-- Joins or leaves a party: M.SetGroup({ "party1", "party2" }) or M.SetGroup({}).
function M.SetGroup(units)
    M.group = units
    M.FireEvent("GROUP_ROSTER_UPDATE")
end

-- Every playing animation group runs to its end: the animated frame takes
-- the last alpha (SetToFinalAlpha), then OnFinished runs.
function M.FinishAnimations()
    local groups = M.playing
    M.playing = {}
    for group in pairs(groups) do
        group._playing = false
        local last = group._anims[#group._anims]
        if group._toFinal and last then group:GetParent():SetAlpha(last._to) end
        local done = group:GetScript("OnFinished")
        if done then done(group) end
    end
end

-- A mouse click on a SecureActionButtonTemplate button, reduced to what
-- the addon uses (Blizzard_FrameXML/SecureTemplates.lua): a mouse press
-- acts on the up stroke, and only when the button registered it; the
-- action is the modified attribute "type" for the mouse button (looked up
-- as name..suffix, *name..suffix, name*, *name*, name; no modifier held),
-- run as secure code. Returns the action type, or nil.
local BUTTON_SUFFIX = { LeftButton = "1", RightButton = "2", MiddleButton = "3" }
local SECURE_ACTIONS = {
    destroytotem = function(button, attr) DestroyTotem(attr("totem-slot")) end,
}
function M.SecureClick(button, mouseButton)
    local registered = false
    for _, c in ipairs(button._clicks or {}) do
        if c == "AnyUp" or c == mouseButton .. "Up" then registered = true end
    end
    if not registered or not button:IsVisible() or button._mouse == false then return nil end
    local suffix = BUTTON_SUFFIX[mouseButton] or ""
    local function attr(name)
        for _, k in ipairs({ name .. suffix, "*" .. name .. suffix, name .. "*", "*" .. name .. "*", name }) do
            local v = button._attr[k]
            if v ~= nil then return v end
        end
    end
    local kind = attr("type")
    local action = kind and SECURE_ACTIONS[kind]
    if action then
        M.secureDepth = M.secureDepth + 1
        local ok, err = pcall(action, button, attr)
        M.secureDepth = M.secureDepth - 1
        if not ok then error(err, 0) end
    end
    return kind
end

function M.SetCombat(v)
    M.combat = v
    if not v then M.FireEvent("PLAYER_REGEN_ENABLED") end
end

-- Runs and clears every queued C_Timer.After callback. Timers a callback
-- itself queues are appended and run too, so this drains to empty.
-- With maxSeconds, only timers of at most that delay run; longer ones stay
-- queued (e.g. run a 0.5 s save but not a 15 s timeout).
function M.RunTimers(maxSeconds)
    while true do
        local due, later = {}, {}
        for _, t in ipairs(M.timers) do
            if maxSeconds == nil or t.sec <= maxSeconds then
                due[#due + 1] = t
            else
                later[#later + 1] = t
            end
        end
        if #due == 0 then return end
        M.timers = later
        for _, t in ipairs(due) do t.fn() end
    end
end

local function wants(registration, unit)
    if registration == true then return true end
    for _, u in ipairs(registration) do
        if u == unit then return true end
    end
    return false
end

function M.FireEvent(event, ...)
    local unit = ...
    for f in pairs(M.eventFrames) do
        local registration = f._events[event]
        if registration and f._scripts.OnEvent and wants(registration, unit) then
            f._scripts.OnEvent(f, event, ...)
        end
    end
end

-- Advances the clock and runs OnUpdate of every shown created frame once.
function M.Tick(seconds)
    M.now = M.now + seconds
    for _, f in ipairs(M.frames) do
        local script = f._scripts.OnUpdate
        if script and f:IsShown() then script(f, seconds) end
    end
end

return M
