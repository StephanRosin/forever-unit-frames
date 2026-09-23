-- Class colour when the unit's identity is secret (target of target in
-- combat): the token cannot index RAID_CLASS_COLORS, the client's
-- C_ClassColor takes it as it is and the colour passes straight through.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
C.Set("targettarget", "healthColorMode", "CLASS")
local mage = RAID_CLASS_COLORS.WARLOCK

M.units.targettarget = { name = "Ally", health = 5, healthMax = 10, isPlayer = true,
    className = "Warlock", class = "WARLOCK" }
local r, g, b = ns.Health.ClassColor("targettarget")
H.check("readable class", r, mage.r)

M.units.targettarget.class = M.Secret("WARLOCK")
M.units.targettarget.className = M.Secret("Warlock")
r, g, b = ns.Health.ClassColor("targettarget")
H.checkTrue("secret class: a colour", r ~= nil)
H.check("secret class: the mage's red", M.Reveal(r), mage.r)
H.check("secret class: the mage's blue", M.Reveal(b), mage.b)

-- The bar gets it, not the reaction green.
local tot = ns.Frames.targettarget
M.Tick(0.25)
H.check("bar in class colour", M.Reveal(tot.health._color[1]), mage.r)
