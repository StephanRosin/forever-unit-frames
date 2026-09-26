-- Group icons on the player and party frames (Elements/GroupIcons.lua):
-- leader / guide / assistant, ready check and incoming resurrection.
-- Settings, Blizzard's art, events, secrets, the ready check's decay,
-- layout, test mode and the shipped look.
local M = H.M

local function boot(files)
    local ns = H.LoadAddon(files)
    M.units.player = { name = "Me", class = "WARRIOR", className = "WARRIOR", isPlayer = true, health = 1,
        healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

local LEADER, GUIDE = "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "UI-HUD-UnitFrame-Player-Group-GuideIcon"
local ASSISTANT = "Interface\\GroupFrame\\UI-Group-AssistantIcon"
local READY, NOT_READY, WAITING = "UI-LFG-ReadyMark-Raid", "UI-LFG-DeclineMark-Raid", "UI-LFG-PendingMark-Raid"
local REZ = "RaidFrame-Icon-Rez"

-- Settings -----------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local S = ns.Settings
    local CODES = { groupLeader = "LL", groupReadyCheck = "LR", groupResurrect = "LZ", groupIconSize = "LS",
        groupIconFramePoint = "LF", groupIconPoint = "LO", groupIconX = "LX", groupIconY = "LY" }
    for key, code in pairs(CODES) do
        local def = S.Get(key)
        H.checkTrue("setting " .. key, def)
        H.check("code of " .. key, def and def.code, code)
        H.checkTrue(key .. " on the player", S.AppliesTo(def, "player"))
        H.checkTrue(key .. " on the party", S.AppliesTo(def, "party"))
        for _, scope in ipairs({ "general", "target", "targettarget", "pet", "focus" }) do
            H.check(key .. " not on " .. scope, S.AppliesTo(def, scope), false)
        end
        H.checkTrue(key .. " label", ns.L["SETTING_" .. key] ~= "SETTING_" .. key)
    end
    for _, key in ipairs({ "groupLeader", "groupReadyCheck", "groupResurrect" }) do
        H.check(key .. " on by default", S.Default(S.Get(key), "party"), true)
    end
    H.check("default size", S.Default(S.Get("groupIconSize"), "party"), 16)
    H.check("default: the frame's top left corner", S.Default(S.Get("groupIconFramePoint"), "party"), "TOPLEFT")
    H.check("default: the row's left side", S.Default(S.Get("groupIconPoint"), "party"), "LEFT")
    H.check("default x", S.Default(S.Get("groupIconX"), "party"), 2)
    H.check("default y", S.Default(S.Get("groupIconY"), "party"), 0)

    -- Options: a "Group icons" section on the Status tab of player and party.
    for _, scope in ipairs({ "player", "party" }) do
        local found
        for _, tab in ipairs(ns.Schema.Tabs(scope)) do
            for _, sec in ipairs(tab.sections or {}) do
                if sec.id == "groupIcons" then found = tab.id end
            end
        end
        H.check("group icons on the status tab of " .. scope, found, "status")
    end
    H.check("section label", ns.L.SECTION_groupIcons, "Group icons")
end

-- Defaults add nothing to a saved profile.
do
    local ns = boot()
    local C = ns.Config
    C.Set("party", "groupLeader", true)
    C.Set("party", "groupIconSize", 16)
    C.Set("player", "groupIconFramePoint", "TOPLEFT")
    for scope, values in pairs(C.Profile()) do
        for key in pairs(values) do
            H.checkTrue("no group icon key stored for defaults: " .. scope .. "." .. key, not key:match("^group"))
        end
    end
    H.checkTrue("export without group icon codes", not ns.Codec.Encode(C.Profile()):find("L[LRZSFOXY]"))
end

-- Build, art and layout -------------------------------------------------------------
do
    local ns = boot()
    local f = ns.Frames.player
    local g = f.groupIcons
    H.checkTrue("player has group icons", g)
    for _, key in ipairs({ "target", "targettarget", "pet", "focus" }) do
        H.check("none on " .. key, ns.Frames[key].groupIcons, nil)
    end
    H.check("a plain holder", g.holder._kind, "Frame")
    H.check("child of the frame", g.holder:GetParent(), f)
    H.check("room for three", g.holder:GetWidth(), 16 * 3 + 2 * 2)
    H.check("one icon high", g.holder:GetHeight(), 16)
    local p = point(g.holder, "LEFT")
    H.check("on the frame", p[2], f)
    H.check("top left corner", p[3], "TOPLEFT")
    H.check("x", p[4], 2)
    H.check("y", p[5], 0)
    H.checkTrue("above the text overlay", g.holder:GetFrameLevel() > f.overlay:GetFrameLevel())
    H.checkTrue("below the class badge", g.holder:GetFrameLevel() < f.classBadge:GetFrameLevel())
    H.check("idle: no leader", g.leader:IsShown(), false)
    H.check("idle: no ready check", g.ready:IsShown(), false)
    H.check("idle: no resurrection", g.rez:IsShown(), false)

    -- One group switched off: the row shrinks.
    local C = ns.Config
    C.Set("player", "groupResurrect", false)
    H.check("two slots", g.holder:GetWidth(), 16 * 2 + 2)
    C.Set("player", "groupLeader", false)
    C.Set("player", "groupReadyCheck", false)
    H.check("all off: hidden", g.holder:IsShown(), false)
    C.Set("player", "groupLeader", true)
    C.Set("player", "groupReadyCheck", true)
    C.Set("player", "groupResurrect", true)
    C.Set("player", "groupIconSize", 20)
    C.Set("player", "groupIconFramePoint", "BOTTOMRIGHT")
    C.Set("player", "groupIconPoint", "RIGHT")
    C.Set("player", "groupIconX", -3)
    C.Set("player", "groupIconY", 4)
    p = point(g.holder, "RIGHT")
    H.check("moved: point", p[3], "BOTTOMRIGHT")
    H.check("moved: x", p[4], -3)
    H.check("moved: y", p[5], 4)
    H.check("resized", g.holder:GetHeight(), 20)
end

-- Leader, guide and assistant ------------------------------------------------------
do
    local ns = boot()
    local g = ns.Frames.player.groupIcons
    M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
    M.units.party2 = { name = "Bob", health = 5, healthMax = 10 }
    M.units.player.leader = true
    M.SetGroup({ "party1", "party2" })
    H.check("player leads: icon", g.leader:IsShown(), true)
    H.check("leader art", g.leader._atlas, LEADER)
    local a, b = ns.Party.buttons[1], ns.Party.buttons[2]
    H.check("member 1 not leader", a.groupIcons.leader:IsShown(), false)
    -- Leadership passes on.
    M.units.player.leader = false
    M.units.party1.leader = true
    M.FireEvent("PARTY_LEADER_CHANGED")
    H.check("player no longer leads", g.leader:IsShown(), false)
    H.check("member 1 leads", a.groupIcons.leader:IsShown(), true)
    -- A guide (group finder restrictions) instead of the crown.
    M.lfgRestricted = true
    M.FireEvent("PARTY_LEADER_CHANGED")
    H.check("guide art", a.groupIcons.leader._atlas, GUIDE)
    M.lfgRestricted = false
    -- Assistants: Blizzard's raid roster icon.
    M.units.party2.assistant = true
    M.FireEvent("GROUP_ROSTER_UPDATE")
    H.check("assistant shown", b.groupIcons.leader:IsShown(), true)
    H.check("assistant art", b.groupIcons.leader._texture, ASSISTANT)
    -- The icon takes the first slot; packed to the left.
    H.check("leader in the first slot", point(a.groupIcons.leader, "TOPLEFT")[4], 0)

    -- Secret answers (identity restricted): no icon, no error.
    M.groupSecret = true
    local ok, err = pcall(M.FireEvent, "PARTY_LEADER_CHANGED")
    H.check("secret: no error", ok and "ok" or tostring(err), "ok")
    H.check("secret: no icon", a.groupIcons.leader:IsShown(), false)
    M.groupSecret = false

    ns.Config.Set("party", "groupLeader", false)
    M.FireEvent("PARTY_LEADER_CHANGED")
    H.check("off: not shown", a.groupIcons.leader:IsShown(), false)
end

-- Ready check ----------------------------------------------------------------------
do
    local ns = boot()
    local g = ns.Frames.player.groupIcons
    M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
    M.SetGroup({ "party1" })
    local a = ns.Party.buttons[1].groupIcons
    M.units.player.readyCheck = "ready"
    M.units.party1.readyCheck = "waiting"
    M.FireEvent("READY_CHECK", "Me", 30)
    H.check("player ready", g.ready:IsShown() and g.ready._atlas, READY)
    H.check("member waiting", a.ready:IsShown() and a.ready._atlas, WAITING)
    M.units.party1.readyCheck = "notready"
    M.FireEvent("READY_CHECK_CONFIRM", "party1", false)
    H.check("member not ready", a.ready._atlas, NOT_READY)
    -- Offline members show none, as Blizzard's party frames.
    M.units.party1.readyCheck = "waiting"
    M.units.party1.offline = true
    M.FireEvent("READY_CHECK_CONFIRM", "party1", false)
    H.check("offline: none", a.ready:IsShown(), false)
    M.units.party1.offline = nil
    M.FireEvent("READY_CHECK_CONFIRM", "party1", false)
    H.check("back: waiting", a.ready._atlas, WAITING)

    -- Finished: the icons stay a while (CUF_READY_CHECK_DECAY_TIME);
    -- whoever did not answer is not ready.
    M.units.player.readyCheck = nil
    M.units.party1.readyCheck = nil
    M.FireEvent("READY_CHECK_FINISHED", false)
    H.check("finished: player still shown", g.ready:IsShown() and g.ready._atlas, READY)
    H.check("finished: no answer is not ready", a.ready:IsShown() and a.ready._atlas, NOT_READY)
    local decay
    for _, t in ipairs(M.timers) do if t.sec == ns.GroupIcons.READY_DECAY then decay = t end end
    H.check("decay time as Blizzard's", ns.GroupIcons.READY_DECAY, 11)
    H.checkTrue("decay timer", decay)
    M.FireEvent("PARTY_LEADER_CHANGED")
    H.check("other updates keep the result", a.ready._atlas, NOT_READY)
    M.RunTimers()
    H.check("decayed: player", g.ready:IsShown(), false)
    H.check("decayed: member", a.ready:IsShown(), false)

    -- A new check during the decay starts over.
    M.units.party1.readyCheck = "waiting"
    M.FireEvent("READY_CHECK", "Me", 30)
    M.units.party1.readyCheck = nil
    M.FireEvent("READY_CHECK_FINISHED", false)
    M.units.party1.readyCheck = "ready"
    M.FireEvent("READY_CHECK", "Me", 30)
    H.check("new check: live again", a.ready._atlas, READY)
    M.RunTimers()
    H.check("old decay does not end the new check", a.ready:IsShown(), true)

    -- A status that is not a known one, or secret: none.
    M.units.party1.readyCheck = M.Secret("ready")
    M.FireEvent("READY_CHECK_CONFIRM", "party1", true)
    H.check("secret status: none", a.ready:IsShown(), false)
    ns.Config.Set("party", "groupReadyCheck", false)
    M.units.party1.readyCheck = "ready"
    M.FireEvent("READY_CHECK_CONFIRM", "party1", true)
    H.check("off: none", a.ready:IsShown(), false)
end

-- Incoming resurrection --------------------------------------------------------------
do
    local ns = boot()
    M.units.party1 = { name = "Ann", health = 0, healthMax = 10 }
    M.SetGroup({ "party1" })
    local a = ns.Party.buttons[1].groupIcons
    H.check("no resurrection", a.rez:IsShown(), false)
    M.units.party1.incomingRez = true
    M.FireEvent("INCOMING_RESURRECT_CHANGED", "party1")
    H.check("resurrection coming", a.rez:IsShown(), true)
    H.check("Blizzard's raid frame art", a.rez._atlas, REZ)
    M.units.party1.incomingRez = M.Secret(true)
    local ok = pcall(M.FireEvent, "INCOMING_RESURRECT_CHANGED", "party1")
    H.check("secret: no error", ok, true)
    H.check("secret: none", a.rez:IsShown(), false)
    M.units.party1.incomingRez = false
    M.FireEvent("INCOMING_RESURRECT_CHANGED", "party1")
    H.check("done", a.rez:IsShown(), false)
end

-- In combat nothing protected is touched.
do
    local ns = boot()
    M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
    M.SetGroup({ "party1" })
    M.combat = true
    M.units.party1.leader = true
    M.units.party1.readyCheck = "ready"
    local ok, err = pcall(function()
        M.FireEvent("PARTY_LEADER_CHANGED")
        M.FireEvent("READY_CHECK", "Ann", 30)
        ns.Config.Set("party", "groupIconSize", 18)
    end)
    H.check("combat: no error", ok and "ok" or tostring(err), "ok")
    H.check("combat: nothing blocked", #M.blocked, 0)
    H.check("combat: leader shown", ns.Party.buttons[1].groupIcons.leader:IsShown(), true)
    M.SetCombat(false)
end

-- Test mode --------------------------------------------------------------------------
do
    local ns = boot()
    H.checkTrue("test mode on", ns.TestMode.Set(true))
    local g = ns.Frames.player.groupIcons
    H.check("player sample: leader", g.leader:IsShown() and g.leader._atlas, LEADER)
    H.check("player sample: ready", g.ready:IsShown() and g.ready._atlas, READY)
    local fakes = ns.Party.fakes
    H.check("member 1: ready", fakes[1].groupIcons.ready._atlas, READY)
    H.check("member 2: not ready", fakes[2].groupIcons.ready._atlas, NOT_READY)
    H.check("member 2: resurrection coming", fakes[2].groupIcons.rez:IsShown(), true)
    H.check("member 3: nothing", fakes[3].groupIcons.ready:IsShown(), false)
    H.check("member 4: waiting", fakes[4].groupIcons.ready._atlas, WAITING)
    M.FireEvent("READY_CHECK_FINISHED", false)
    M.RunTimers()
    H.check("real events leave the samples alone", fakes[4].groupIcons.ready:IsShown(), true)
    ns.TestMode.Set(false)
    H.check("off: player sample gone", g.leader:IsShown(), false)
    H.check("off: member sample gone", fakes[2].groupIcons.rez:IsShown(), false)
end

-- The shipped look: top left, clear of the raid marker and the class badge.
do
    local ns = H.LoadShipped()
    M.units.player = { name = "Me", class = "WARRIOR", className = "WARRIOR", isPlayer = true, health = 1,
        healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    local C = ns.Config
    for _, scope in ipairs({ "player", "party" }) do
        local w = ns.Single.Size(scope)
        local size = C.Get(scope, "groupIconSize")
        local rowRight = C.Get(scope, "groupIconX") + 3 * size + 2 * 2
        local markerLeft = w / 2 - C.Get(scope, "raidMarkerSize") / 2
        H.checkTrue("shipped " .. scope .. ": left of the raid marker", rowRight < markerLeft)
    end
end
