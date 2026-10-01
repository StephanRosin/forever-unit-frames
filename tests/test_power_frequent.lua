-- Energy and mana regenerate in many small steps. UNIT_POWER_UPDATE comes
-- throttled and at uneven moments (reported: after an ambush energy showed
-- 40, 46, 67, 87, 97, 100); UNIT_POWER_FREQUENT comes with every change,
-- as Blizzard's player frame reads it (frequentUpdates). Bar, texts and the
-- druid's mana strip follow it.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
M.units.player = { name = "Rogue", level = 60, class = "ROGUE", className = "Rogue", isPlayer = true,
    health = 1, healthMax = 1, power = 40, powerMax = 100, powerType = 3 }
ns.Single.CreateAll()
local f = ns.Frames.player

for _, el in ipairs({ ns.Power, ns.Texts, ns.DruidMana }) do
    local frequent = false
    for _, event in ipairs(el.unitEvents) do
        if event == "UNIT_POWER_FREQUENT" then frequent = true end
        H.checkTrue(el.name .. ": not the throttled event", event ~= "UNIT_POWER_UPDATE")
    end
    H.checkTrue(el.name .. " listens to UNIT_POWER_FREQUENT", frequent)
end

H.check("start", f.power:GetValue(), 40)
for _, energy in ipairs({ 42, 44, 46, 48 }) do
    M.units.player.power = energy
    M.FireEvent("UNIT_POWER_FREQUENT", "player", "ENERGY")
    H.check("bar follows every step: " .. energy, f.power:GetValue(), energy)
    H.check("text follows every step: " .. energy, f.texts.powerRight._text, tostring(energy))
end
