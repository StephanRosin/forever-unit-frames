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
