local M = H.M

-- The secret proxy must refuse everything real secrets refuse.
local s = M.Secret(50)
H.checkError("secret + 1", function() return s + 1 end)
H.checkError("secret < 1", function() return s < 1 end)
H.checkError("secret .. ''", function() return s .. "" end)
H.checkError("tostring(secret)", function() return tostring(s) end)
H.checkError("format %d secret", function() return ("%d"):format(s) end)
H.checkTrue("IsSecret", M.IsSecret(s))

-- Loading the addon creates the namespace and public table.
local ns = H.LoadAddon()
H.checkTrue("ns.L exists", ns.L)
H.check("unknown locale key falls back", ns.L.SOME_KEY, "SOME_KEY")
H.checkTrue("public API table", ForeverUnitFrames == ns.api)

-- AfterCombat runs now out of combat, later (once, collapsed) in combat.
local runs = 0
ns.AfterCombat("a", function() runs = runs + 1 end)
H.check("runs immediately out of combat", runs, 1)
M.SetCombat(true)
ns.AfterCombat("a", function() runs = runs + 1 end)
ns.AfterCombat("a", function() runs = runs + 1 end)
H.check("deferred in combat", runs, 1)
H.check("one pending job", ns.PendingCombatWork(), 1)
M.SetCombat(false)
H.check("ran once after combat", runs, 2)

-- Chat output accepts plain strings only.
ns.Print("hello")
H.checkTrue("printed", M.chat[1]:find("hello"))
