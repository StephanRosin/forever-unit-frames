-- Hidden-auras lists travel with their profile: a frame's with that frame
-- (copy, export, import), a raid size's with that size (copy between sizes,
-- a size's export and import, every size's), the account's with the unit
-- frames' profile and never in a raid size's string.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, RC, P = ns.Config, ns.RaidConfig, ns.RaidProfiles

C.Set("general", "auraBlockAccount", "7353")
C.Set("target", "auraBlock", "19705, 1459")
-- Copy between frames.
C.CopyScope("target", "focus")
H.check("copy: the frame's list", C.Get("focus", "auraBlock"), "19705, 1459")
-- Export and import of the unit frames' profile.
local str = ns.Codec.Encode(C.Profile())
local decoded = ns.Codec.Decode(str)
H.check("export: the frame's", decoded.target.auraBlock, "19705, 1459")
H.check("export: the account's", decoded.general.auraBlockAccount, "7353")
C.ResetAll()
H.check("reset: gone", C.Get("target", "auraBlock"), "")
C.Import(decoded)
H.check("import: the frame's back", C.Get("target", "auraBlock"), "19705, 1459")
H.check("import: the account's back", C.Get("general", "auraBlockAccount"), "7353")
-- A hand-edited string with a bad list: refused, counted.
local _, _, rejected = ns.Codec.Decode("1;tBL'Cozy Fire;tBL'12")
H.check("bad list counted", rejected, 1)

-- Raid sizes.
RC.Set("r10", "auraBlock", "19705")
local sizeStr = P.Export(10)
H.check("size export: the list", sizeStr:find("aXL'19705", 1, true) ~= nil, true)
H.check("size export: no account list", sizeStr:find("7353", 1, true), nil)
H.check("size import", P.Import(sizeStr, 40), true)
H.check("size import: the list", RC.Get("r40", "auraBlock"), "19705")
H.check("copy between sizes (behaviour)", P.CopySizeMode(10, 20, "BEHAVIOUR"), true)
H.check("copy: the list", RC.Get("r20", "auraBlock"), "19705")
RC.Set("r20", "auraBlock", "")
local all = P.ExportAll()
RC.Set("r10", "auraBlock", "")
H.check("every size: import", (P.ImportAll(all)), true)
H.check("every size: the list back", RC.Get("r10", "auraBlock"), "19705")
H.check("every size: no account list", all:find("7353", 1, true), nil)
