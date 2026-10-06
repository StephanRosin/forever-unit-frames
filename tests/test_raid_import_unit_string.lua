-- A unit frames' export pasted into the raid import (Raid/Profiles.lua)
-- is refused: it holds no raid size, and nothing of the raid profile
-- changes, not even the character-wide settings whose codes the two
-- registries share.
local ns = H.LoadAddon()
local C, RC, P = ns.Config, ns.RaidConfig, ns.RaidProfiles
C.Use({})
P.Attach({})

C.Set("general", "minimapShow", false)
C.Set("general", "fontSize", 14)
C.Set("party", "width", 200)
C.Set("player", "height", 60)
local unit = ns.Codec.Encode(C.Profile())
H.check("a real unit frames' export", unit, "1;gFS14;gMS0;pH60;yW200")
RC.Set("r10", "cellWidth", 120)
local ok, err = P.Import(unit, 10)
H.check("refused", ok, nil)
H.check("no raid size in it", err, "RAID_NO_SIZE")
H.check("the size kept", RC.Get("r10", "cellWidth"), 120)
H.check("the raid button kept", RC.Get("general", "minimapShow"), true)
H.check("the message", ns.L["IMPORT_" .. err], "This text holds no raid size.")
