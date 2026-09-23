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
    function w:Show() self._shown = true end
    function w:Hide() self._shown = false end
    function w:IsShown() return self._shown end
    function w:SetShown(v) self._shown = not not v end
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
    -- FontString
    function w:SetFont(path, size, flags) self._font = { path, size, flags }; return true end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end
    function w:SetFormattedText(fmt, ...) self._fmt = fmt; self._args = { ... } end
    function w:SetShadowOffset(x, y) self._shadow = { x, y } end
    function w:SetJustifyH(v) self._justifyH = v end
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
function M.RunTimers()
    while #M.timers > 0 do
        local timers = M.timers
        M.timers = {}
        for _, t in ipairs(timers) do t.fn() end
    end
end

function M.FireEvent(event, ...)
    for f in pairs(M.eventFrames) do
        if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
    end
end

return M
