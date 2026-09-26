-- The client allows at most three mask textures per texture and raises
-- beyond that (a CurseForge report: moving the corner radius slider). The
-- rounding keeps every texture at one mask at most, so Blizzard or other
-- code still has room for theirs. Swept over the whole radius range on
-- every frame type, castbar docked and detached, rings and shadow on.
local M = H.M

-- Most masks any texture carries right now, and which one.
local function mostMasks()
    local most, where = 0, nil
    for _, w in ipairs(M.widgets) do
        local n = w._masks and #w._masks or 0
        if n > most then most, where = n, w end
    end
    return most, where
end

-- Sets the radius; inCombat: moved in combat, applied when it ends.
local function setRadius(ns, radius, inCombat)
    if inCombat then M.SetCombat(true) end
    ns.Config.Set("general", "cornerRadius", radius)
    if inCombat then M.SetCombat(false) end
end

local function sweep(label, ns, inCombat)
    local max = ns.Settings.Get("cornerRadius").max
    local ok, err = pcall(function()
        for radius = 0, max do
            setRadius(ns, radius, inCombat)
            local most = mostMasks()
            H.check(label .. ": radius " .. radius .. " at most one mask per texture", most <= 1, true)
            local rounded = ns.Frames.target.healthBg:GetNumMaskTextures()
            H.check(label .. ": radius " .. radius .. " rounds the frame", rounded, radius > 0 and 1 or 0)
        end
        for radius = max, 0, -1 do setRadius(ns, radius, inCombat) end
    end)
    H.check(label .. ": sweep without errors", ok and "ok" or tostring(err), "ok")
end

local function boot(shipped)
    local ns = shipped and H.LoadShipped() or H.LoadAddon()
    M.units.player = { name = "Me", level = 60, class = "SHAMAN", className = "SHAMAN", isPlayer = true,
        health = 5, healthMax = 10 }
    M.units.pet = { name = "Wolf", health = 3, healthMax = 4 }
    M.units.party1 = { name = "Ann", health = 1, healthMax = 2 }
    M.units.partypet1 = { name = "Imp", health = 1, healthMax = 2 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    M.SetGroup({ "party1" })
    local C = ns.Config
    C.Set("party", "partyShowPets", true)
    for _, key in ipairs({ "player", "target", "targettarget", "pet", "focus", "party" }) do
        C.Set(key, "castbarEnabled", true)
    end
    return ns
end

-- Every look: rings (flat and gold with its inner line), shadow, castbar
-- docked below, above and detached, test mode (sample casts, totems, the
-- pretend party) on and off.
local LOOKS = {
    { "flat ring", {} },
    { "gold ring with shadow", { borderStyle = "GOLD", borderSize = 4, borderPadding = 2, shadowEnabled = true } },
    { "no ring", { borderShow = false, shadowEnabled = true } },
}
local PLACEMENTS = { "BELOW", "ABOVE", "DETACHED" }

for _, shipped in ipairs({ false, true }) do
    for _, look in ipairs(LOOKS) do
        for _, placement in ipairs(PLACEMENTS) do
            local ns = boot(shipped)
            local C = ns.Config
            for key, value in pairs(look[2]) do C.Set("general", key, value) end
            C.Set("player", "castbarPosition", placement)
            C.Set("target", "castbarPosition", placement)
            C.Set("focus", "castbarPosition", placement)
            local label = (shipped and "shipped, " or "plain, ") .. look[1] .. ", castbar " .. placement
            sweep(label, ns)
            ns.TestMode.Set(true)
            sweep(label .. ", test mode", ns)
            sweep(label .. ", test mode, slider moved in combat", ns, true)
            ns.TestMode.Set(false)
        end
    end
end
