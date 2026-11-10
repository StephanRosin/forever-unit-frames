-- The ping key over one of our frames pings its unit, as over Blizzard's:
-- the ping manager (Blizzard_PingUI/Blizzard_PingManager.lua) takes frames
-- with the ping-receiver attribute and asks their PingableType mixin for the
-- unit's GUID.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()

M.units.target = { exists = true, guid = "Creature-0-1-2-3-4075-5" }
for key, f in pairs(ns.Frames) do
    if f.key == key then
        H.check(key .. " is a ping receiver", f:GetAttribute("ping-receiver"), true)
        H.check(key .. " pings its unit", f:GetTargetInfo().guid, UnitGUID(f.unit))
    end
end
H.check("target frame pings the target", ns.Frames.target:GetTargetInfo().guid, "Creature-0-1-2-3-4075-5")

-- The buttons the secure headers make inherit the ping template in XML.
for file, count in pairs({ ["Units/Party.xml"] = 3, ["Units/PartyPets.xml"] = 1, ["Raid/Cell.xml"] = 1 }) do
    local _, n = H.ReadFile(file):gsub('inherits="SecureUnitButtonTemplate, PingableUnitFrameTemplate"', "")
    H.check(file .. " buttons are pingable", n, count)
end

-- A secret GUID would make the ping system's securecopy throw: the frame is
-- then not pingable and hands on no GUID.
local t = ns.Frames.target
M.units.target.guid = M.Secret("Creature-0-1-2-3-4075-5")
H.check("secret GUID: not pingable", t:GetIsPingable(), false)
H.check("secret GUID: none handed on", t:GetTargetInfo().guid, nil)
M.units.target.guid = "Creature-0-1-2-3-4075-5"
H.check("plain GUID: pingable", t:GetIsPingable(), true)

-- The header-made buttons get the same at load (their OnLoad).
for file, count in pairs({ ["Units/Party.lua"] = 1, ["Units/PartyPets.lua"] = 2, ["Units/PartyTargets.lua"] = 1,
    ["Raid/Cell.lua"] = 1 }) do
    local _, n = H.ReadFile(file):gsub("ns%.Units%.EnablePing%(button%)", "")
    H.check(file .. " buttons use our ping info", n, count)
end
