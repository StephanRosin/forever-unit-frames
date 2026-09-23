local M = H.M

-- Stand-ins for the Blizzard frames of build 69977. TargetFrameToT is a
-- secure child of TargetFrame, PetFrame a secure button, FocusFrame a
-- secure TargetFrameTemplate, PartyFrame a plain frame whose pooled
-- member buttons are secure, PlayerCastingBarFrame a plain StatusBar.
local function blizzardFrames()
    local frames = {}
    for _, name in ipairs({ "PlayerFrame", "TargetFrame", "TargetFrameToT", "PetFrame", "FocusFrame",
        "PlayerCastingBarFrame", "PartyFrame", "CompactPartyFrame" }) do
        frames[name] = M.newWidget("Frame", name)
        _G[name] = frames[name]
    end
    for _, name in ipairs({ "TargetFrameToT", "PetFrame", "FocusFrame" }) do frames[name]._protected = true end
    local member = M.newWidget("Button", "PartyMember1")
    member._protected = true
    frames.member = member
    local active = { [member] = true }
    frames.PartyFrame.PartyMemberFramePool = { EnumerateActive = function() return pairs(active) end }
    frames.active = active
    return frames
end

local ns = H.LoadAddon()
local B = blizzardFrames()
ns.Config.Use({})
-- Blizzard's focus frame goes only when ours exists (the focus unit may
-- be unavailable, and then ours is never built).
ns.Blizzard.HideDefaults()
H.check("no focus frame of ours: focus kept", B.FocusFrame:GetAlpha(), 1)
ns.Frames.focus = M.newWidget("Button", "ForeverUnitFramesFocus")
ns.Blizzard.HideDefaults()
H.check("tot: invisible", B.TargetFrameToT:GetAlpha(), 0)
H.check("tot: hidden", B.TargetFrameToT:IsShown(), false)
H.check("pet: invisible", B.PetFrame:GetAlpha(), 0)
H.check("focus: invisible", B.FocusFrame:GetAlpha(), 0)
H.check("party: hidden", B.PartyFrame:IsShown(), false)
H.check("party member: invisible", B.member:GetAlpha(), 0)
H.check("party member: mouse off", B.member._mouse, false)
H.check("compact party: hidden", B.CompactPartyFrame:IsShown(), false)
H.check("player castbar kept while ours is off", B.PlayerCastingBarFrame:IsShown(), true)

-- Switching our player castbar on alone leaves Blizzard's untouched: the
-- user wants to keep it unless they ask to hide it.
ns.Config.Set("player", "castbarEnabled", true)
H.check("player castbar untouched by castbarEnabled alone", B.PlayerCastingBarFrame:IsShown(), true)

-- hideBlizzardCastbar conceals it at once.
ns.Config.Set("player", "hideBlizzardCastbar", true)
H.check("player castbar: hidden", B.PlayerCastingBarFrame:IsShown(), false)
H.checkTrue("player castbar: reparented", B.PlayerCastingBarFrame:GetParent() ~= nil)

-- Members Blizzard acquires later are hidden on the roster update.
local late = M.newWidget("Button", "PartyMember2")
late._protected = true
B.active[late] = true
M.SetGroup({ "party1" })
H.check("late member: invisible", late:GetAlpha(), 0)
M.SetGroup({})

-- Disabled frames keep Blizzard's.
ns = H.LoadAddon()
B = blizzardFrames()
ns.Config.Use({ targettarget = { enabled = false }, pet = { enabled = false }, focus = { enabled = false },
    party = { enabled = false } })
ns.Blizzard.HideDefaults()
H.check("tot kept", B.TargetFrameToT:GetAlpha(), 1)
H.check("pet kept", B.PetFrame:GetAlpha(), 1)
H.check("focus kept", B.FocusFrame:GetAlpha(), 1)
H.checkTrue("party kept", B.PartyFrame:IsShown())
H.check("party member kept", B.member:GetAlpha(), 1)
local late2 = M.newWidget("Button", "PartyMember3")
B.active[late2] = true
M.SetGroup({ "party1" })
H.check("roster update leaves a kept party alone", late2:GetAlpha(), 1)
M.SetGroup({})
-- Enabling one later hides Blizzard's without a reload.
ns.Config.Set("pet", "enabled", true)
H.check("pet enabled later: invisible", B.PetFrame:GetAlpha(), 0)

-- Missing frames (FocusFrame may not exist for this game type) are fine.
ns = H.LoadAddon()
ns.Config.Use({})
for _, name in ipairs({ "PlayerFrame", "TargetFrame", "TargetFrameToT", "PetFrame", "FocusFrame",
    "PlayerCastingBarFrame", "PartyFrame", "CompactPartyFrame", "ComboFrame" }) do _G[name] = nil end
H.checkTrue("no error without Blizzard frames", pcall(ns.Blizzard.HideDefaults))

-- A macro backup that switches frames off asks for a /reload.
ns = H.LoadAddon()
H.checkTrue("setup: backup", ns.MacroBackup.Write("1;eE0"))
local backup = M.macros
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.macros = backup
M.chat = {}
M.FireEvent("UPDATE_MACROS")
H.check("restored", ns.Storage.Source(), "MacroBackup")
H.checkTrue("reload hint", table.concat(M.chat, "\n"):find(ns.L.RELOAD_FOR_BLIZZARD, 1, true))

ns = H.LoadAddon()
H.checkTrue("setup: harmless backup", ns.MacroBackup.Write("1;pW300"))
backup = M.macros
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.macros = backup
M.chat = {}
M.FireEvent("UPDATE_MACROS")
H.check("restored width", ns.Config.Get("player", "width"), 300)
H.check("no reload hint", table.concat(M.chat, "\n"):find(ns.L.RELOAD_FOR_BLIZZARD, 1, true), nil)

-- A backup that turns hideBlizzardCastbar back off also asks for a
-- /reload: Blizzard's own castbar was already hidden (in response to it
-- being switched on before the backup arrived) and does not come back on
-- its own. hideBlizzardCastbar defaults to false for the player, so a
-- backup that leaves it unset is enough.
ns = H.LoadAddon()
H.checkTrue("setup: castbar-off backup", ns.MacroBackup.Write("1;pW300"))
backup = M.macros
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
ns.Config.Set("player", "hideBlizzardCastbar", true)
M.macros = backup
M.chat = {}
M.FireEvent("UPDATE_MACROS")
H.check("restored width (castbar case)", ns.Config.Get("player", "width"), 300)
H.check("hide turned back off", ns.Config.Get("player", "hideBlizzardCastbar"), false)
H.checkTrue("reload hint for castbar", table.concat(M.chat, "\n"):find(ns.L.RELOAD_FOR_BLIZZARD, 1, true))
