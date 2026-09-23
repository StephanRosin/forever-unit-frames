-- Minimal WoW API mock for offline tests. Lua 5.1 like the client.
local M = {}

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
    -- else is addon data and must be nil, as in the game.
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local f = function() end
    rawset(t, k, f)
    return f
end

local function newWidget(kind, name, parent)
    local w = setmetatable({
        _kind = kind, _name = name, _parent = parent, _scripts = {},
        _events = {}, _attr = {}, _points = {}, _w = 0, _h = 0, _shown = true,
    }, widget)
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
    function w:SetAttribute(k, v) self._attr[k] = v end
    function w:GetAttribute(k) return self._attr[k] end
    function w:RegisterForClicks(...) self._clicks = { ... } end
    function w:SetSize(a, b) self._w, self._h = a, b end
    function w:SetWidth(v) self._w = v end
    function w:SetHeight(v) self._h = v end
    function w:GetWidth() return self._w end
    function w:GetHeight() return self._h end
    function w:ClearAllPoints() self._points = {} end
    function w:SetPoint(...) table.insert(self._points, { ... }) end
    function w:GetPoint(i) local p = self._points[i or 1]; if p then return unpack(p) end end
    function w:GetCenter() return self._cx or 0, self._cy or 0 end
    -- OnShow/OnHide fire on a real change of the frame's own state (the
    -- mock does not propagate them to children).
    function w:SetShown(v)
        v = not not v
        if v == self._shown then return end
        self._shown = v
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
    function w:EnableMouse(v) self._mouse = v end
    function w:IsProtected() return self._protected or false end
    function w:SetFrameStrata(v) self._strata = v end
    function w:GetFrameStrata() return self._strata end
    function w:GetEffectiveScale() return 1 end
    -- StatusBar
    function w:SetMinMaxValues(a, b) self._min, self._max = a, b end
    function w:GetMinMaxValues() return self._min, self._max end
    function w:SetValue(v) self._value = v end
    function w:GetValue() return self._value end
    function w:SetStatusBarTexture(t) self._texture = t end
    function w:SetStatusBarColor(r, g, b, a) self._color = { r, g, b, a } end
    function w:GetStatusBarTexture() return self._barTex end
    -- Texture
    function w:SetTexture(t) self._texture = t end
    function w:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
    function w:SetVertexColor(r, g, b, a) self._color = { r, g, b, a } end
    function w:SetAllPoints(p) self._allPoints = p or true end
    -- FontString / EditBox. An EditBox without a font cannot take text in
    -- the client, so the mock refuses it too.
    function w:SetFont(path, size, flags) self._font = { path, size, flags }; return true end
    function w:SetFontObject(o) self._fontObject = o end
    function w:SetText(t)
        if self._kind == "EditBox" then
            assert(self._font or self._fontObject, "EditBox:SetText(): Font not set")
        end
        self._text = t
    end
    function w:SetTextColor(r, g, b, a) self._color = { r, g, b, a } end
    function w:GetText() return self._text end
    function w:SetFormattedText(fmt, ...) self._fmt = fmt; self._args = { ... } end
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
    function w:CreateTexture(n) return newWidget("Texture", n, self) end
    function w:CreateFontString(n) return newWidget("FontString", n, self) end
    -- Movable
    function w:SetMovable(v) self._movable = v end
    function w:RegisterForDrag(...) self._drag = { ... } end
    function w:StartMoving() end
    function w:StopMovingOrSizing() end
    function w:SetClampedToScreen() end
    return w
end
M.newWidget = newWidget

function M.Reset()
    M.eventFrames = {}
    M.frames = {}
    M.chat = {}
    M.combat = false
    M.units = {}
    M.cvars = {}
    M.macros = {}          -- list of { name=, icon=, body=, perChar= }
    M.macroFrameShown = false
    M.errors = {}          -- whatever reached the global error handler
    M.timers = {}          -- queued C_Timer.After callbacks
    M.now = 1000           -- GetTime(), advanced by M.Tick

    _G.UIParent = newWidget("Frame", "UIParent")
    _G.UIParent._w, _G.UIParent._h = 1920, 1080
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg)
        assert(type(msg) == "string", "chat message must be a plain string")
        table.insert(M.chat, msg)
    end }
    _G.CreateFrame = function(kind, name, parent, template)
        local w = newWidget(kind, name, parent)
        w._template = template
        if template and template:find("Secure") then w._protected = true end
        if kind == "StatusBar" then w._barTex = newWidget("Texture", nil, w) end
        if name then _G[name] = w end
        table.insert(M.frames, w)
        return w
    end
    _G.InCombatLockdown = function() return M.combat end
    _G.GetTime = function() return M.now end
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
    _G.Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 30 } }
    _G.MacroFrame = M.NewMacroFrame()
    _G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGB = function(c) return c.r, c.g, c.b end } end
    _G.ForeverUnitFrames = nil
    _G.ForeverUnitFramesDB = nil

    -- Unit API: data comes from M.units[unit]; fields may hold secret proxies.
    local function u(unit) return M.units[unit] end
    _G.UnitExists = function(unit) return u(unit) ~= nil end
    _G.UnitName = function(unit) local d = u(unit); return d and d.name end
    _G.UnitLevel = function(unit) local d = u(unit); return d and d.level or 0 end
    _G.UnitClass = function(unit) local d = u(unit); if d then return d.className, d.class end end
    _G.UnitIsPlayer = function(unit) local d = u(unit); return d and d.isPlayer or false end
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
    _G.C_StringUtil = { TruncateWhenZero = function(n) return n end }
    _G.UnitPowerMissing = function(unit) local d = u(unit); return d and d.powerMissing or 0 end

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
            function c:AddPoint(x, color) table.insert(self.points, { x, color }) end
            function c:Evaluate() return { GetRGB = function() return 1, 1, 1 end } end
            return c
        end,
    }

    -- CVars
    _G.C_CVar = {
        RegisterCVar = function(name, default) if M.cvars[name] == nil then M.cvars[name] = default or "" end end,
        GetCVar = function(name) return M.cvars[name] end,
        SetCVar = function(name, v) M.cvars[name] = v; return true end,
    }

    -- Macros (character macros live at indices MAX_ACCOUNT_MACROS + 1 ...)
    _G.GetNumMacros = function()
        local n = 0
        for _, m in ipairs(M.macros) do if m.perChar then n = n + 1 end end
        return 0, n
    end
    _G.GetMacroIndexByName = function(name)
        for i, m in ipairs(M.macros) do if m.name == name then return 120 + i end end
        return 0
    end
    _G.GetMacroBody = function(index) local m = M.macros[index - 120]; return m and m.body end
    -- Like the client, creating or editing a macro re-sorts the list by
    -- name, so an index taken before the call may point elsewhere after it.
    local function sortMacros()
        table.sort(M.macros, function(a, b) return a.name < b.name end)
    end
    _G.CreateMacro = function(name, icon, body, perChar)
        assert(#body <= 255, "macro body over 255 characters")
        table.insert(M.macros, { name = name, icon = icon, body = body, perChar = perChar })
        sortMacros()
        return GetMacroIndexByName(name)
    end
    _G.EditMacro = function(index, name, icon, body)
        assert(#body <= 255, "macro body over 255 characters")
        local m = M.macros[index - 120]
        m.name, m.icon, m.body = name, icon, body
        sortMacros()
        return GetMacroIndexByName(name)
    end
    _G.DeleteMacro = function(index) table.remove(M.macros, index - 120) end

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

-- Blizzard's macro window (load-on-demand in the client). Shown state is
-- driven by M.macroFrameShown; tests call its OnHide script to close it.
function M.NewMacroFrame()
    local f = newWidget("Frame", "MacroFrame")
    function f:IsShown() return M.macroFrameShown end
    return f
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
