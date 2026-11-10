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
-- True while a drain is spread over several frames.
local draining = false

-- mode == "last" moves an already-queued key to the end of the queue
-- instead of leaving it at its first position, so a job that must run after
-- everything else queued so far (and everything queued after it, right up
-- to combat ending) stays last no matter how many more keys get queued.
function ns.AfterCombat(key, fn, mode)
    if not InCombatLockdown() and not draining then
        fn()
        return
    end
    if mode == "last" and pending[key] then
        for i = 1, #order do
            if order[i] == key then
                table.remove(order, i)
                break
            end
        end
        order[#order + 1] = key
    elseif not pending[key] then
        order[#order + 1] = key
    end
    pending[key] = fn
end

function ns.PendingCombatWork()
    return #order
end

-- Jobs run in queue order, each protected: a throwing job is reported but
-- never strands the jobs after it or blocks its key from being queued again.
-- The drain stops after DRAIN_BUDGET ms and continues next frame, because
-- one long run trips the client's "script ran too long"; meanwhile new jobs
-- queue behind the old ones, and a new fight leaves the rest queued for its end.
local DRAIN_BUDGET = 25

local function drain()
    local clock = debugprofilestop
    local start = clock and clock()
    local handler = geterrorhandler and geterrorhandler() or print
    while #order > 0 do
        if InCombatLockdown() then
            draining = false
            return
        end
        local key = table.remove(order, 1)
        local fn = pending[key]
        pending[key] = nil
        xpcall(fn, handler)
        if clock and #order > 0 and clock() - start > DRAIN_BUDGET then
            C_Timer.After(0, drain)
            return
        end
    end
    draining = false
end

ns.On("PLAYER_REGEN_ENABLED", function()
    if draining then return end
    draining = true
    drain()
end)

-- Chat output ----------------------------------------------------------------

-- Only ever pass plain strings here, never values from unit APIs: printing a
-- secret value corrupts the chat history on this client.
function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7" .. ns.L.ADDON_NAME .. ":|r " .. msg)
end
