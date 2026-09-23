local ADDON, ns = ...

ns.name = ADDON

-- Public API for other addons (storage providers etc.). Filled by later files.
ForeverUnitFrames = ForeverUnitFrames or {}
ns.api = ForeverUnitFrames

-- Event hub ----------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do list[i](event, ...) end
end)

-- Register fn for a game event. Several handlers per event are allowed and
-- run in registration order.
function ns.On(event, fn)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        eventFrame:RegisterEvent(event)
    end
    list[#list + 1] = fn
end

-- Internal (addon-only) events, e.g. "CONFIG_CHANGED". Never registered
-- with the client.
local internal = {}

function ns.Listen(name, fn)
    internal[name] = internal[name] or {}
    table.insert(internal[name], fn)
end

function ns.Fire(name, ...)
    local list = internal[name]
    if not list then return end
    for i = 1, #list do list[i](...) end
end

-- Combat queue ---------------------------------------------------------------

-- Work that touches secure frames must wait until combat ends. Keyed, so
-- repeated requests for the same work collapse into one run.
local pending, order = {}, {}

function ns.AfterCombat(key, fn)
    if not InCombatLockdown() then
        fn()
        return
    end
    if not pending[key] then order[#order + 1] = key end
    pending[key] = fn
end

function ns.PendingCombatWork()
    return #order
end

-- The queue is emptied completely before any job runs, and each job runs
-- protected: a throwing job is reported but never strands the jobs after it
-- or blocks its key from being queued again.
ns.On("PLAYER_REGEN_ENABLED", function()
    local keys, jobs = order, pending
    order, pending = {}, {}
    local handler = geterrorhandler and geterrorhandler() or print
    for i = 1, #keys do
        local fn = jobs[keys[i]]
        if fn then xpcall(fn, handler) end
    end
end)

-- Chat output ----------------------------------------------------------------

-- Only ever pass plain strings here, never values from unit APIs: printing a
-- secret value corrupts the chat history on this client.
function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7" .. ns.L.ADDON_NAME .. ":|r " .. msg)
end
