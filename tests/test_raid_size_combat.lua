-- The raid size changes in combat (Raid/Header.lua, Raid/Size.lua): the
-- new size's blocks wait for the end of combat, nothing protected is
-- touched meanwhile, and the layout after combat has every block.
local M = H.M
local ns = H.LoadAddon()
local Header, Cell = ns.RaidHeader, ns.RaidCell
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

local function point(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    return table.concat({ p, rel == Header.anchor and "anchor" or "?", relPoint, x, y }, " ")
end
local function raid(n)
    local list = {}
    for i = 1, n do
        list[i] = { name = "M" .. string.format("%02d", i), class = "MAGE", subgroup = math.floor((i - 1) / 5) + 1,
            unit = { health = 100, healthMax = 100, powerType = 0 } }
    end
    return list
end

Header.Create()
M.SetRaidRoster(raid(10))
M.RunTimers()
H.check("10: size", Cell.Size(), 10)
H.check("10: two blocks", #Header.blocks, 2)
local width = Header.headers[1]:GetAttribute("child1"):GetWidth()

-- The roster grows to 15 in combat: the 20-player size, laid out later.
M.combat = true
M.SetRaidRoster(raid(15))
M.RunTimers()
H.check("combat: size follows", Cell.Size(), 20)
H.check("combat: nothing blocked", #M.blocked, 0)
H.check("combat: still two blocks", #Header.blocks, 2)
H.check("combat: no header for group 3", Header.headers[3], nil)
H.check("combat: cells keep their size", Header.headers[1]:GetAttribute("child1"):GetWidth(), width)
M.SetCombat(false)
M.RunTimers()
H.check("after combat: four blocks", #Header.blocks, 4)
H.checkTrue("after combat: header for group 3", Header.headers[3] ~= nil and Header.headers[3]:IsShown())
H.check("after combat: group 3 filled", Header.Count(3), 5)
H.check("after combat: group 3 beside group 2", point(Header.headers[3]), "TOPLEFT anchor TOPLEFT 188 0")
H.check("after combat: cells of the 20 profile", Header.headers[1]:GetAttribute("child1"):GetWidth(), 88)
H.check("after combat: nothing blocked", #M.blocked, 0)

-- Entering a 40-player raid instance in combat: the same.
M.combat = true
M.instance = { type = "raid", maxPlayers = 40 }
M.FireEvent("ZONE_CHANGED_NEW_AREA")
M.RunTimers()
H.check("instance in combat: size", Cell.Size(), 40)
H.check("instance in combat: nothing blocked", #M.blocked, 0)
H.check("instance in combat: blocks wait", #Header.blocks, 4)
M.SetCombat(false)
M.RunTimers()
H.check("instance after combat: eight blocks", #Header.blocks, 8)
H.check("instance after combat: group 3 filled", Header.Count(3), 5)
H.check("instance after combat: nothing blocked", #M.blocked, 0)
