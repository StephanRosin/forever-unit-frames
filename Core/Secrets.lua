local _, ns = ...

-- Values from unit APIs can be "secret" on this client: they may be handed
-- to widgets but not inspected by Lua. Everything here follows one rule:
-- never calculate, pass through.
local Secrets = {}
ns.Secrets = Secrets

local issecret = issecretvalue or function() return false end

function Secrets.IsSecret(v)
    return issecret(v) == true
end

-- A plain number, or nil when the value is secret or not a number.
function Secrets.Number(v)
    if Secrets.IsSecret(v) then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

-- Call fn(...) and return a plain boolean. Secret results and errors give
-- nil so callers can pick their own fallback.
function Secrets.Bool(fn, ...)
    local ok, v = pcall(fn, ...)
    if not ok or Secrets.IsSecret(v) then return nil end
    return v and true or false
end

-- "12.3k" style text for readable numbers; secret values are returned
-- untouched so SetText/SetFormattedText can still display them in full.
function Secrets.Abbreviate(v)
    local n = Secrets.Number(v)
    if not n then return v end
    if n >= 1000000 then return ("%.1fm"):format(n / 1000000) end
    if n >= 10000 then return ("%.1fk"):format(n / 1000) end
    return ("%d"):format(n)
end

local percentCurve
function Secrets.PercentCurve()
    if not percentCurve then
        percentCurve = C_CurveUtil.CreateCurve()
        percentCurve:AddPoint(0, 0)
        percentCurve:AddPoint(1, 100)
    end
    return percentCurve
end
