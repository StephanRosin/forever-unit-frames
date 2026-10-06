# Forever Unit Frames — Raid plan R3b: icons and states

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raid cells show the assigned role, the raid target marker, the leader or an assistant, the master looter (in our own art) and the ready check, each switchable and at its own point; fade out of range with an opacity per size; show a red line along the inside while the unit has aggro and a light one on your current target; the dead and the offline stay grey — all with samples in test mode, settings per raid size, unit frames unchanged.

**Architecture:** The cell's derived scope `raid` (`Raid/Cell.lua`) maps the raid profile onto the unit-frame elements that fit: the raid marker (`Elements/RaidMarker.lua`), the group icons (`Elements/GroupIcons.lua`: leader, assistant, ready check, plus the master looter for cells) and range fading (`Elements/Range.lua`). As in R2a, those elements opt in through frame fields no unit frame sets: `frame.iconPoint` (each icon at its own point on the cell), `frame.fadesOutOfRange`, and `frame.sample` for test mode. Two small raid elements are new: `Raid/CellRole.lua` (the role icon) and `Raid/CellStates.lua` (aggro and target lines). `tools/make_master_looter.py` makes `Media/MasterLooter.tga`.

**Tech Stack:** Lua 5.1, WoW: Forever API (Interface 16001, build 1.60.1.70205), offline tests with `lua5.1` + `tests/mock.lua` (`tests/run`).

Spec: `docs/specs/2026-10-06-raid-frames-design.md` (part 1; §5 the cell: Icons, States; §9 aggro). Raid plan order: R1 Foundation, R2a Headers, layout and cell, R2b Raid view in party, Blizzard's raid frames, test mode (all done) → R3a Debuffs and corner indicators (`docs/plans/2026-10-06-plan-raid-3a-debuffs-and-indicators.md`) → **R3b Icons and states (this plan)** → R4 Options window, locales, wiki, release.

Base: the last commit of R3a ("Raid test mode: debuff and corner indicator samples"); `tests/run` there: `19837 passed, 0 failed`. Every task below was replayed in order on a scratch worktree after R3a; the totals under "Expected" are what `tests/run` printed there.

## Global Constraints

The Global Constraints of R3a hold unchanged (English, no new user-facing string, unit frames identical, no secret maths, no snippets, no `hooksecurefunc`, protected changes out of combat only, faithful mock, public repository, commit trailer, no push, one green commit per task). In addition:

- New raid settings (per size): `roleIcon` RI, `roleIconPoint` RP, `raidMarker` RM, `raidMarkerPoint` RQ, `leaderIcon` LI, `leaderIconPoint` LP, `looterIcon` MI, `looterIconPoint` MP, `readyCheckIcon` YI, `readyCheckIconPoint` YP, `roleIconDamager` RD, `iconSize` IZ, `rangeFade` RF, `rangeAlpha` RA, `aggroBorder` AB, `targetBorder` TB. Points use the unit frames' list `ns.Settings.POINTS` (stored by index, append only).
- No unit-frame `only` table changes: the raid cells' derived scope reads any setting (`Config.Get` does not check `only`), and the elements opt in by frame field. No existing test is edited.
- New game event: `PARTY_LOOT_METHOD_CHANGED` (verified below); `PLAYER_TARGET_CHANGED`, `PLAYER_ROLES_ASSIGNED`, `PLAYER_REGEN_ENABLED` and the unit event `UNIT_THREAT_SITUATION_UPDATE` are already in use. New internal listener: `RAID_CELLS_CHANGED` in `Elements/Range.lua`.
- New texture: `Media/MasterLooter.tga`, made by `tools/make_master_looter.py` (standard library only, deterministic). A new texture file loads only after a full restart of the game client, not with `/reload`.

## Client facts this plan relies on (build 1.60.1.70205)

Paths below `Interface/AddOns/`; `Doc/` = `Blizzard_APIDocumentationGenerated/`.

| Fact | Source |
|---|---|
| `UnitThreatSituation(unit) -> number?` is `SecretWhenUnitThreatStateRestricted`; 2 and 3 mean the unit is tanking (has aggro), 0 and 1 not; `GetThreatStatusColor` refuses secrets from addon code | `Doc/UnitDocumentation.lua`, `Elements/Threat.lua` (existing) |
| `StatusBar:SetValue` and `SetMinMaxValues` take secret values (`SecretArguments = "AllowedWhenTainted"`, the bar gets the `BarValue` secret aspect) | `Doc/SimpleStatusBarAPIDocumentation.lua` |
| Blizzard's raid frames show an aggro highlight for any status above 0, coloured by the status | `Blizzard_UnitFrame/Shared/CompactUnitFrame.lua` (`CompactUnitFrame_UpdateAggroHighlight`) |
| `C_PartyInfo.GetLootMethod() -> method, masterLootPartyID?, masterLooterRaidID?` (not secret); `Enum.LootMethod.Masterlooter = 2`; event `PARTY_LOOT_METHOD_CHANGED()`; no master looter art anywhere in the client's UI | `Doc/PartyInfoDocumentation.lua`, `Doc/LootConstantsDocumentation.lua`, `Elements/GroupIcons.lua` (existing note) |
| Role icons as the group finder draws them: `GetMicroIconForRole` gives the atlases `UI-LFG-RoleIcon-Tank-Micro-GroupFinder`, `UI-LFG-RoleIcon-Healer-Micro-GroupFinder`, `UI-LFG-RoleIcon-DPS-Micro-GroupFinder` | `Blizzard_SharedXMLBase/TextureUtil.lua` |
| `UnitGroupRolesAssigned` and `UnitIsGroupLeader` / `UnitIsGroupAssistant` are `SecretWhenUnitIdentityRestricted`; `GetRaidTargetIndex` has secret returns (passed to `SetSpriteSheetCell`); `UnitInRange` has secret returns (`SetAlphaFromBoolean`); `UnitIsUnit` may answer secret | `Doc/UnitDocumentation.lua`, `Elements/RaidMarker.lua`, `Elements/GroupIcons.lua`, `Elements/Range.lua`, `Elements/TargetHighlight.lua` (existing) |

## Design decisions

- **Reuse by frame field, not by `only`:** the raid marker element applies to every scope already (R2a switched it off for cells; the profile now maps it); the group icons and range fading are limited by `only` tables to unit-frame scopes. Adding `raid` there would not change the options schema or the wiki (both list the real scopes only), but the frame fields keep the unit-frame registry untouched, as R2a's hooks do.
- **Icons:** each switchable, at one of the nine points of the cell, one pixel inside it, all at one size per raid size (14/13/12). Defaults: role LEFT, raid marker RIGHT, leader or assistant TOPLEFT, master looter TOPRIGHT, ready check CENTER. Role: tank and healer, damage only when asked. The resurrection icon of the group icons stays off on cells (not in the spec).
- **Master looter:** an icon of its own (switch and point), shown with our own art (a gold coin). The raid index from `GetLootMethod` in a raid; in a party (raid view in party) the party index, 0 meaning you, as the old API did — not documented in this build: an in-game check.
- **Range:** `Elements/Range.lua` with switch and opacity (40 % by default) from the raid profile; its poll timer also runs while a cell with fading on shows a unit (`RAID_CELLS_CHANGED`). Dead and offline grey come from `Elements/UnitStatus.lua` already; R3b only checks them.
- **Aggro** (spec §9): four status bars along the inside of the cell, red, from 1 to 2, fed the threat status as it is — full at 2 and 3 (tanking), empty at 0 and 1. Deviation from the brief's idea (2 to 3, full only at 3): a unit has aggro at 2 as well (tanking, not securely). Nothing is compared or coloured by the addon; if the client does not draw a secret value this way the line just stays empty — an in-game check; if it never shows, R4 drops the setting and the wiki says why.
- **Target:** a light line (white, 90 %) two pixels inside, within the red one, not the party's target highlight: that is a glow band outside the frame, which would lie on the neighbouring cells.
- **Carry-over:** the negative checks deferred in R2a (cells never get the elements of other frames) are pinned down by a test of their own (Task 7).

---

### Task 1: Raid icon and state settings

**Files:**
- Modify: `Raid/Settings.lua`
- Test: `tests/test_raid_icon_settings.lua`

**Interfaces:**
- Consumes: `ns.RaidSettings`, `ns.RaidConfig`, `ns.RaidProfiles.Export`, `ns.Settings.POINTS`.
- Produces: the raid settings listed in the Global Constraints (scope `frame`, per size).

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_icon_settings.lua`:

```lua
-- Raid icon and state settings (Raid/Settings.lua): one value per raid
-- size, permanent codes; positions are the unit frames' nine points,
-- stored by index.
local ns = H.LoadAddon()
local RS, RC = ns.RaidSettings, ns.RaidConfig

local CODES = {
    roleIcon = "RI", roleIconPoint = "RP", roleIconDamager = "RD", raidMarker = "RM", raidMarkerPoint = "RQ",
    leaderIcon = "LI", leaderIconPoint = "LP", looterIcon = "MI", looterIconPoint = "MP",
    readyCheckIcon = "YI", readyCheckIconPoint = "YP", iconSize = "IZ",
    rangeFade = "RF", rangeAlpha = "RA", aggroBorder = "AB", targetBorder = "TB",
}
for key, code in pairs(CODES) do
    local def = RS.Get(key)
    H.checkTrue(key .. " defined", def)
    if def then
        H.check(key .. " code", def.code, code)
        H.check(key .. " per size", RS.AppliesTo(def, "r10"), true)
        H.check(key .. " not character-wide", RS.AppliesTo(def, "general"), false)
    end
end
H.check("points: the unit frames' list", RS.Get("roleIconPoint").values, ns.Settings.POINTS)

RC.Use({})
local DEFAULTS = {
    roleIcon = true, roleIconPoint = "LEFT", roleIconDamager = false, raidMarker = true, raidMarkerPoint = "RIGHT",
    leaderIcon = true, leaderIconPoint = "TOPLEFT", looterIcon = true, looterIconPoint = "TOPRIGHT",
    readyCheckIcon = true, readyCheckIconPoint = "CENTER", rangeFade = true, rangeAlpha = 40,
    aggroBorder = true, targetBorder = true,
}
for key, want in pairs(DEFAULTS) do
    H.check(key .. " default", RC.Get("r20", key), want)
end
H.check("icons 10", RC.Get("r10", "iconSize"), 14)
H.check("icons 20", RC.Get("r20", "iconSize"), 13)
H.check("icons 40", RC.Get("r40", "iconSize"), 12)

local seen = {}
for _, def in ipairs(RS.All()) do
    H.check("unique code " .. def.code, seen[def.code], nil)
    seen[def.code] = true
end
RC.Set("r40", "roleIconPoint", "BOTTOMRIGHT")
RC.Set("r40", "rangeAlpha", 25)
H.check("export", ns.RaidProfiles.Export(40), "1;cRA25;cRP9")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run test_raid_icon_settings.lua`
Expected: 16 lines `FAIL <key> defined -> false (want true)` (in no fixed order), then `ERROR test_raid_icon_settings.lua:22: attempt to index a nil value`, `0 passed, 17 failed`

- [ ] **Step 3: Add the definitions**

The definitions go at the end of the file.

In `Raid/Settings.lua`:

Replace

```lua
    RaidSettings.Define({ key = key .. "Time", code = l .. "M", scope = "frame", type = "enum",
        values = { "SWIPE", "NUMBER", "NONE" }, default = "SWIPE" })
end
```

with

```lua
    RaidSettings.Define({ key = key .. "Time", code = l .. "M", scope = "frame", type = "enum",
        values = { "SWIPE", "NUMBER", "NONE" }, default = "SWIPE" })
end

-- Icons (Raid/Cell.lua and the elements it maps them to), each switched
-- on its own and placed on one of the cell's nine points (just inside
-- it), all at one size per raid size: the assigned role (tank and
-- healer; damage too when asked), the raid target marker, the group's
-- leader or an assistant, the master looter, the ready check.
local POINTS = ns.Settings.POINTS
for _, icon in ipairs({
    { key = "roleIcon", code = "RI", pointCode = "RP", point = "LEFT" },
    { key = "raidMarker", code = "RM", pointCode = "RQ", point = "RIGHT" },
    { key = "leaderIcon", code = "LI", pointCode = "LP", point = "TOPLEFT" },
    { key = "looterIcon", code = "MI", pointCode = "MP", point = "TOPRIGHT" },
    { key = "readyCheckIcon", code = "YI", pointCode = "YP", point = "CENTER" },
}) do
    RaidSettings.Define({ key = icon.key, code = icon.code, scope = "frame", type = "bool", default = true })
    RaidSettings.Define({ key = icon.key .. "Point", code = icon.pointCode, scope = "frame", type = "enum",
        values = POINTS, default = icon.point })
end
RaidSettings.Define({ key = "roleIconDamager", code = "RD", scope = "frame", type = "bool", default = false })
RaidSettings.Define({ key = "iconSize", code = "IZ", scope = "frame", type = "int", min = 8, max = 32,
    default = { r10 = 14, r20 = 13, _ = 12 } })

-- States (Raid/CellStates.lua, Elements/Range.lua): out of range faded
-- to rangeAlpha percent; a red inner border while the unit has aggro, a
-- light one on your current target.
RaidSettings.Define({ key = "rangeFade", code = "RF", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "rangeAlpha", code = "RA", scope = "frame", type = "int", min = 0, max = 100,
    default = 40 })
RaidSettings.Define({ key = "aggroBorder", code = "AB", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "targetBorder", code = "TB", scope = "frame", type = "bool", default = true })
```

- [ ] **Step 4: Run the tests**

Run: `tests/run raid_icon_settings` → `157 passed, 0 failed`
Run: `tests/run` → Expected: `20026 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Raid/Settings.lua tests/test_raid_icon_settings.lua
git commit -m "Raid icon and state settings per size

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Raid cell: the raid target marker at its point

**Files:**
- Modify: `Raid/Cell.lua`, `Elements/RaidMarker.lua`, `Raid/TestMode.lua`
- Test: `tests/test_raid_cell_marker.lua`

**Interfaces:**
- Consumes: `ns.RaidMarker` (its settings `raidMarker`, `raidMarkerSize`, `raidMarkerFramePoint`, `raidMarkerPoint`, `raidMarkerX`, `raidMarkerY`), `raidMarker` / `raidMarkerPoint` / `iconSize` of Task 1.
- Produces: `ns.RaidCell.Inset(point)` → x, y (one pixel inward from each edge the point touches); the cell's mapping of the raid marker; `RaidMarker` takes a raid test cell's own sample (`frame.sample.marker`); `RaidTestMode.MARKERS` and `member.marker`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_cell_marker.lua`:

```lua
-- The raid target marker on raid cells: the unit frames' element
-- (Elements/RaidMarker.lua) with the raid profile's switch, point and
-- icon size (Raid/Cell.lua), just inside the cell; test mode's pretend
-- members carry their own.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell = ns.RaidConfig, ns.RaidHeader, ns.RaidCell
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1, unit = { raidTarget = 8 } },
    { name = "Bob", class = "MAGE", subgroup = 1 } })
M.RunTimers()

H.check("inset left", table.concat({ Cell.Inset("TOPLEFT") }, ","), "1,-1")
H.check("inset right", table.concat({ Cell.Inset("RIGHT") }, ","), "-1,0")
H.check("inset bottom", table.concat({ Cell.Inset("BOTTOM") }, ","), "0,1")
H.check("inset centre", table.concat({ Cell.Inset("CENTER") }, ","), "0,0")

local cell = Header.headers[1]:GetAttribute("child1")
local r = cell.raidMarker
H.checkTrue("shown", r.icon:IsShown())
H.check("skull", r.icon._spriteCell[1], 8)
H.check("the 10 profile's icon size", r.holder:GetWidth(), 14)
local p, rel, relPoint, x, y = r.holder:GetPoint(1)
H.checkTrue("at the right, inside", p == "RIGHT" and rel == cell and relPoint == "RIGHT" and x == -1 and y == 0)
H.check("Bob: none", Header.headers[1]:GetAttribute("child2").raidMarker.icon:IsShown(), false)

M.units.raid2.raidTarget = 1
M.raidTargetsSecret = true
M.FireEvent("RAID_TARGET_UPDATE")
local bob = Header.headers[1]:GetAttribute("child2").raidMarker.icon
H.checkTrue("a secret index shows", bob:IsShown())
H.check("passed on secret", bob._spriteSecret, true)
M.raidTargetsSecret = false

RC.Set("r10", "raidMarkerPoint", "TOPLEFT")
p, rel, relPoint, x, y = r.holder:GetPoint(1)
H.checkTrue("moved to the top left", p == "TOPLEFT" and relPoint == "TOPLEFT" and x == 1 and y == -1)
RC.Set("r10", "iconSize", 18)
H.check("bigger", r.holder:GetWidth(), 18)
RC.Set("r10", "raidMarker", false)
H.check("off", r.holder:IsShown(), false)
H.check("off: icon hidden", r.icon:IsShown(), false)
RC.ResetScope("r10")
H.checkTrue("on again", r.icon:IsShown())

-- Test mode: the pretend members' own markers.
H.check("member 1: skull", ns.RaidTestMode.Members(10)[1].marker, 8)
ns.TestMode.Set(true)
local f1, f2 = Cell.fakes[1], Cell.fakes[2]
H.checkTrue("pretend: skull shown", f1.raidMarker.icon:IsShown())
H.check("pretend: skull", f1.raidMarker.icon._spriteCell[1], 8)
H.check("pretend member 2: none", f2.raidMarker.icon:IsShown(), false)
H.check("pretend member 6: star", Cell.fakes[6].raidMarker.icon._spriteCell[1], 1)
ns.TestMode.Set(false)
H.check("no errors", #M.errors, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run test_raid_cell_marker.lua`
Expected: `ERROR test_raid_cell_marker.lua:17: attempt to call field 'Inset' (a nil value)`, `0 passed, 1 failed`

- [ ] **Step 3: Map the raid marker onto the cell**

In `Raid/Cell.lua`:

Replace

```lua
local get = Cell.Get

-- What a cell never shows, whatever the party frame does: no title row,
-- portrait, castbar, auras, combat numbers, threat glow or raid marker
-- (markers, dispels, range and icons come with the next raid step), no
-- overheal lane or heals past the edge (the next cell sits there), no
-- shadow (it would lie on the neighbours), no power texts. The rows: a
-- thin power strip under the health bar.
local FIXED = {
    titlePercent = 0, portraitMode = "OFF", castbarEnabled = false, combatFeedback = false,
    buffsEnabled = false, debuffsEnabled = false, threatGlow = false, raidMarker = false,
    titleClassIcon = false, healOverflow = false, healBeyond = false, shadowEnabled = false,
    textHealthLeft = "NAME", textPowerLeft = "NONE", textPowerRight = "NONE",
    healthPercent = 90, powerPercent = 10, fontSize = 11, valueFontSize = 10,
}

-- The raid profile's look, in unit-frame settings. The second line's
-- values are the text tags of the same name.
local MAPPED = {
    width = function() return get("cellWidth") end,
    height = function() return get("cellHeight") end,
```

with

```lua
local get = Cell.Get

-- What a cell never shows, whatever the party frame does: no title row,
-- portrait, castbar, the unit frames' aura icons (a cell's are its own,
-- Raid/CellAuras.lua), combat numbers or threat glow, no overheal lane or
-- heals past the edge (the next cell sits there), no shadow (it would lie
-- on the neighbours), no power texts. The rows: a thin power strip under
-- the health bar.
local FIXED = {
    titlePercent = 0, portraitMode = "OFF", castbarEnabled = false, combatFeedback = false,
    buffsEnabled = false, debuffsEnabled = false, threatGlow = false,
    titleClassIcon = false, healOverflow = false, healBeyond = false, shadowEnabled = false,
    textHealthLeft = "NAME", textPowerLeft = "NONE", textPowerRight = "NONE",
    healthPercent = 90, powerPercent = 10, fontSize = 11, valueFontSize = 10,
}

-- An icon at one of the cell's points sits just inside it: a pixel in
-- from each edge the point touches.
function Cell.Inset(point)
    local x = point:find("LEFT") and 1 or (point:find("RIGHT") and -1 or 0)
    local y = point:find("TOP") and -1 or (point:find("BOTTOM") and 1 or 0)
    return x, y
end

local function insetX(key) return function() return (Cell.Inset(get(key))) end end
local function insetY(key) return function() return select(2, Cell.Inset(get(key))) end end

-- The raid profile's look, in unit-frame settings. The second line's
-- values are the text tags of the same name. The raid marker
-- (Elements/RaidMarker.lua) at its point, centred on it.
local MAPPED = {
    width = function() return get("cellWidth") end,
    height = function() return get("cellHeight") end,
```

Replace

```lua
    textHealthRight = function() return get("secondLine") end,
    barNameColorMode = function() return get("nameClassColor") and "CLASS" or "WHITE" end,
    borderShow = function() return get("cellBorder") end,
}

function Cell.Resolve(key)
```

with

```lua
    textHealthRight = function() return get("secondLine") end,
    barNameColorMode = function() return get("nameClassColor") and "CLASS" or "WHITE" end,
    borderShow = function() return get("cellBorder") end,
    raidMarker = function() return get("raidMarker") end,
    raidMarkerSize = function() return get("iconSize") end,
    raidMarkerFramePoint = function() return get("raidMarkerPoint") end,
    raidMarkerPoint = function() return get("raidMarkerPoint") end,
    raidMarkerX = insetX("raidMarkerPoint"),
    raidMarkerY = insetY("raidMarkerPoint"),
}

function Cell.Resolve(key)
```

- [ ] **Step 4: A raid test cell's own marker**

In `Elements/RaidMarker.lua`:

Replace

```lua
    if r.preview then RaidMarker.Preview(frame, true) end
end

-- The sample of test mode for this frame, or nil.
local function sample(frame)
    if frame.sampleIndex then return RaidMarker.PARTY_SAMPLES[frame.sampleIndex] end
    return RaidMarker.SAMPLES[frame.key]
end
```

with

```lua
    if r.preview then RaidMarker.Preview(frame, true) end
end

-- The sample of test mode for this frame, or nil: a raid test cell's own
-- (frame.sample.marker), the pretend party's, or the frame's.
local function sample(frame)
    if frame.sample then return frame.sample.marker end
    if frame.sampleIndex then return RaidMarker.PARTY_SAMPLES[frame.sampleIndex] end
    return RaidMarker.SAMPLES[frame.key]
end
```

- [ ] **Step 5: The pretend members' markers**

In `Raid/TestMode.lua`:

Replace

```lua
-- samples): a magic one and a curse, a poison, a disease, one without a
-- type and magic again.
Test.DEBUFFS = { [2] = { 1, 2 }, [5] = { 3 }, [9] = { 4, 5, 1 } }

local on = false
```

with

```lua
-- samples): a magic one and a curse, a poison, a disease, one without a
-- type and magic again.
Test.DEBUFFS = { [2] = { 1, 2 }, [5] = { 3 }, [9] = { 4, 5, 1 } }
-- Raid target markers by raid index: a skull on the first tank, a star.
Test.MARKERS = { [1] = 8, [6] = 1 }

local on = false
```

Replace

```lua
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
-- health, status, role, debuffs } per member, in raid order.
function Test.Members(size)
    local list = {}
    for i = 1, size do
```

with

```lua
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
-- health, status, role, debuffs, marker } per member, in raid order.
function Test.Members(size)
    local list = {}
    for i = 1, size do
```

Replace

```lua
            subgroup = math.floor((i - 1) / Layout.GROUP_SIZE) + 1, class = s[1], assignedRole = s[2], role = s[2],
            name = type(names) == "table" and names[s[1]] or s[1],
            health = Test.HEALTH[(i - 1) % #Test.HEALTH + 1], status = Test.STATUS[i] or false,
            debuffs = Test.DEBUFFS[(i - 1) % #Test.SAMPLES + 1] or {},
        }
    end
    return list
```

with

```lua
            subgroup = math.floor((i - 1) / Layout.GROUP_SIZE) + 1, class = s[1], assignedRole = s[2], role = s[2],
            name = type(names) == "table" and names[s[1]] or s[1],
            health = Test.HEALTH[(i - 1) % #Test.HEALTH + 1], status = Test.STATUS[i] or false,
            debuffs = Test.DEBUFFS[(i - 1) % #Test.SAMPLES + 1] or {}, marker = Test.MARKERS[i],
        }
    end
    return list
```

- [ ] **Step 6: Run the tests**

Run: `tests/run raid_cell_marker` → `22 passed, 0 failed`
Run: `tests/run` → Expected: `20048 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add Elements/RaidMarker.lua Raid/Cell.lua Raid/TestMode.lua tests/test_raid_cell_marker.lua
git commit -m "Raid cell: the raid target marker at its point

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Raid cell: leader, master looter and ready check, each at its point

**Files:**
- Create: `tools/make_master_looter.py`
- Generate: `Media/MasterLooter.tga`
- Modify: `Elements/GroupIcons.lua`, `Raid/Cell.lua`, `Raid/TestMode.lua`, `tests/mock.lua`
- Test: `tests/test_raid_cell_group_icons.lua`

**Interfaces:**
- Consumes: `ns.GroupIcons` (its readers, events and ready-check decay), `ns.RaidCell.Inset` (Task 2), `leaderIcon*`, `looterIcon*`, `readyCheckIcon*`, `iconSize` of Task 1.
- Produces: frame hook `frame.iconPoint(frame, name)` → point, x, y or nil (off), names `leader`, `looter`, `ready`, `role`; `ns.RaidCell.IconPoint`, `ns.RaidCell.ICON_KEYS`; `GroupIcons.LOOTER_TEXTURE`, `GroupIcons.OWN_POINTS`, `g.looter` / `g.isLooter` on cells only; `GroupIcons` takes a raid test cell's own sample (`frame.sample.groupIcons`) and listens to `PARTY_LOOT_METHOD_CHANGED`; `RaidTestMode.GROUP_ICONS`; mock `C_PartyInfo.GetLootMethod`, `Enum.LootMethod`, `M.lootMethod` / `M.masterLootPartyID` / `M.masterLooterRaidID`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_cell_group_icons.lua`:

```lua
-- Leader, assistant, master looter and ready check on raid cells: the
-- unit frames' group icons (Elements/GroupIcons.lua), each at its own
-- point from the raid profile (Raid/Cell.lua: frame.iconPoint); the
-- master looter in our own art. Unit frames keep their row and show no
-- master looter.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell, GroupIcons = ns.RaidConfig, ns.RaidHeader, ns.RaidCell, ns.GroupIcons
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.lootMethod, M.masterLooterRaidID = Enum.LootMethod.Masterlooter, 2
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1, unit = { leader = true } },
    { name = "Bob", class = "MAGE", subgroup = 1, unit = { assistant = true } },
    { name = "Cid", class = "ROGUE", subgroup = 1 } })
M.RunTimers()

local function cell(i) return Header.headers[1]:GetAttribute("child" .. i) end
local ann, bob, cid = cell(1).groupIcons, cell(2).groupIcons, cell(3).groupIcons
H.checkTrue("cells have group icons", ann)
H.check("icon point: leader", table.concat({ Cell.IconPoint(cell(1), "leader") }, ","), "TOPLEFT,1,-1")
H.check("icon point: unknown", Cell.IconPoint(cell(1), "rez"), nil)

-- Leader and assistant, at the top left, the profile's icon size.
H.checkTrue("leader shown", ann.leader:IsShown())
H.check("crown", ann.leader._atlas, GroupIcons.LEADER.leader.atlas)
local p, rel, relPoint, x, y = ann.leader:GetPoint(1)
H.checkTrue("top left, inside", p == "TOPLEFT" and rel == cell(1) and relPoint == "TOPLEFT" and x == 1 and y == -1)
H.check("icon size", ann.leader:GetWidth(), 14)
H.check("holder over the cell", ann.holder._allPoints, cell(1))
H.checkTrue("assistant shown", bob.leader:IsShown())
H.check("assistant icon", bob.leader._texture, GroupIcons.LEADER.assistant.file)
H.check("Cid: neither", cid.leader:IsShown(), false)

-- The master looter: raid index 2.
H.checkTrue("Bob loots", bob.looter:IsShown())
H.check("our art", bob.looter._texture, "Interface\\AddOns\\ForeverUnitFrames\\Media\\MasterLooter.tga")
p, rel, relPoint, x, y = bob.looter:GetPoint(1)
H.checkTrue("top right, inside", p == "TOPRIGHT" and relPoint == "TOPRIGHT" and x == -1 and y == -1)
H.check("Ann does not", ann.looter:IsShown(), false)
M.lootMethod = Enum.LootMethod.Group
M.FireEvent("PARTY_LOOT_METHOD_CHANGED")
H.check("group loot: no looter", bob.looter:IsShown(), false)
M.lootMethod = Enum.LootMethod.Masterlooter
M.FireEvent("PARTY_LOOT_METHOD_CHANGED")
H.checkTrue("master loot again", bob.looter:IsShown())

-- A ready check, in the centre.
M.units.raid1.readyCheck = "ready"
M.units.raid3.readyCheck = "waiting"
M.FireEvent("READY_CHECK")
H.check("ready", ann.ready._atlas, GroupIcons.READY.ready)
p, rel, relPoint, x, y = ann.ready:GetPoint(1)
H.checkTrue("centred", p == "CENTER" and relPoint == "CENTER" and x == 0 and y == 0)
H.check("waiting", cid.ready._atlas, GroupIcons.READY.waiting)
H.check("no resurrection icon on cells", ann.rez:IsShown(), false)

-- Switches and points of the profile.
RC.Set("r10", "leaderIcon", false)
H.check("leader off", ann.leader:IsShown(), false)
RC.Set("r10", "looterIcon", false)
H.check("looter off", bob.looter:IsShown(), false)
RC.Set("r10", "readyCheckIconPoint", "BOTTOM")
p, rel, relPoint, x, y = ann.ready:GetPoint(1)
H.checkTrue("ready check moved", p == "BOTTOM" and relPoint == "BOTTOM" and x == 0 and y == 1)
RC.Set("r10", "iconSize", 20)
H.check("bigger", ann.ready:GetWidth(), 20)
RC.ResetScope("r10")
H.checkTrue("reset: leader back", ann.leader:IsShown())

-- Secret answers show nothing.
M.groupSecret = true
M.FireEvent("PARTY_LEADER_CHANGED")
H.check("secret: no leader", ann.leader:IsShown(), false)
M.groupSecret = false

-- Unit frames: their row as before, never a looter.
H.check("player frame: no looter icon", ns.Frames.player.groupIcons.looter, nil)
H.check("player frame: its own row", ns.Frames.player.groupIcons.holder._allPoints, nil)

-- Test mode: the pretend members' icons.
ns.TestMode.Set(true)
local f1, f2, f4 = Cell.fakes[1].groupIcons, Cell.fakes[2].groupIcons, Cell.fakes[4].groupIcons
H.checkTrue("pretend: you lead", f1.leader:IsShown())
H.checkTrue("pretend: you loot", f1.looter:IsShown())
H.check("pretend: member 2 assists", f2.leader._texture, GroupIcons.LEADER.assistant.file)
H.check("pretend: member 4 not ready", f4.ready._atlas, GroupIcons.READY.notready)
H.check("pretend: member 3 nothing", Cell.fakes[3].groupIcons.ready:IsShown(), false)
ns.TestMode.Set(false)
H.check("no errors", #M.errors, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run test_raid_cell_group_icons.lua`
Expected: `ERROR test_raid_cell_group_icons.lua:14: attempt to index field 'LootMethod' (a nil value)`, `0 passed, 1 failed`

- [ ] **Step 3: Mock: the loot method**

In `tests/mock.lua`:

Replace

```lua
    end
    _G.UnitIsGroupLeader = function(unit) local d = u(unit); return groupFlag(d and d.leader) end
    _G.UnitIsGroupAssistant = function(unit) local d = u(unit); return groupFlag(d and d.assistant) end
    -- d.offline: the unit's player is disconnected. d.dead / d.ghost:
    -- dead, or a ghost (UnitIsDeadOrGhost is true for both). Any of them
    -- may be a secret proxy.
```

with

```lua
    end
    _G.UnitIsGroupLeader = function(unit) local d = u(unit); return groupFlag(d and d.leader) end
    _G.UnitIsGroupAssistant = function(unit) local d = u(unit); return groupFlag(d and d.assistant) end
    -- The loot method (PartyInfoDocumentation.lua, not secret): M.lootMethod
    -- (an Enum.LootMethod value), the master looter by party index
    -- (M.masterLootPartyID, 0 = you) and by raid index (M.masterLooterRaidID).
    M.lootMethod, M.masterLootPartyID, M.masterLooterRaidID = 3, nil, nil
    _G.C_PartyInfo = { GetLootMethod = function() return M.lootMethod, M.masterLootPartyID, M.masterLooterRaidID end }
    -- d.offline: the unit's player is disconnected. d.dead / d.ghost:
    -- dead, or a ghost (UnitIsDeadOrGhost is true for both). Any of them
    -- may be a secret proxy.
```

Replace

```lua
    }

    _G.Enum = {
        StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
        StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
        UITextureSliceMode = { Stretched = 0, Tiled = 1 },
```

with

```lua
    }

    _G.Enum = {
        LootMethod = { Freeforall = 0, Roundrobin = 1, Masterlooter = 2, Group = 3, Needbeforegreed = 4, Personal = 5 },
        StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
        StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
        UITextureSliceMode = { Stretched = 0, Tiled = 1 },
```

- [ ] **Step 4: The master looter's art**

Create `tools/make_master_looter.py`:

```python
#!/usr/bin/env python3
"""Writes the master looter icon the raid cells show (Media/MasterLooter.tga):
the client has the loot method but no art for it anywhere in its UI.

A gold coin, 32 x 32: a dark rim, the gold face, a lighter raised centre
and a small shine at its top left, anti-aliased against transparency.
Uncompressed 32-bit TGA, rows stored bottom to top, like the other files
in Media/. No dependencies beyond the standard library.

Run from the repository root:  python3 tools/make_master_looter.py
The output is deterministic; re-running it must not change the file.
A new texture file only loads after a full restart of the game client
(a /reload is not enough).
"""
import os
import struct

SIZE = 32
SUB = 4  # sub-samples per axis for the anti-aliased edges
CENTRE = SIZE / 2
OUTER = 14.5  # the coin's radius
RIM = 2.5  # the dark rim's width
FACE = 8.5  # the raised centre's radius
SHINE = (12.0, 11.0, 3.0)  # centre x, centre y (from the top) and radius

RIM_COLOR = (0.45, 0.29, 0.05)
FACE_COLOR = (0.93, 0.70, 0.16)
RAISED_COLOR = (1.0, 0.84, 0.35)
SHINE_COLOR = (1.0, 0.97, 0.80)


def colour_at(px, py):
    """The colour at point (px, py) (x right, y down), or None outside."""
    dx, dy = px - CENTRE, py - CENTRE
    r = (dx * dx + dy * dy) ** 0.5
    if r > OUTER:
        return None
    if r > OUTER - RIM:
        return RIM_COLOR
    sx, sy = px - SHINE[0], py - SHINE[1]
    if sx * sx + sy * sy <= SHINE[2] * SHINE[2]:
        return SHINE_COLOR
    if r <= FACE:
        return RAISED_COLOR
    return FACE_COLOR


def texel(x, y):
    """Averaged colour and coverage of texel (x, y)."""
    total, rgb = 0, [0.0, 0.0, 0.0]
    for i in range(SUB):
        for j in range(SUB):
            c = colour_at(x + (i + 0.5) / SUB, y + (j + 0.5) / SUB)
            if c is not None:
                total += 1
                for k in range(3):
                    rgb[k] += c[k]
    if total == 0:
        return (0.0, 0.0, 0.0), 0.0
    return tuple(v / total for v in rgb), total / (SUB * SUB)


def write_tga(path):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    rows = []
    for y in range(SIZE - 1, -1, -1):  # bottom row first
        row = bytearray()
        for x in range(SIZE):
            (r, g, b), a = texel(x, y)
            row += bytes((int(round(b * 255)), int(round(g * 255)), int(round(r * 255)), int(round(a * 255))))
        rows.append(bytes(row))
    with open(path, "wb") as fh:
        fh.write(header)
        fh.write(b"".join(rows))


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Media")
    os.makedirs(root, exist_ok=True)
    write_tga(os.path.join(root, "MasterLooter.tga"))


if __name__ == "__main__":
    main()
```

Run: `python3 tools/make_master_looter.py` → writes `Media/MasterLooter.tga` (4114 bytes, `md5sum` `d18afc7f2b91a07708f4d74615c33b33`); running it again must not change the file.

- [ ] **Step 5: Group icons at their own points on a cell, the master looter**

In `Elements/GroupIcons.lua`:

Replace

```lua
--   (CompactUnitFrame.lua, "IncomingResurrection").
-- Master looter: the client has the loot method (C_PartyInfo.GetLootMethod,
-- Enum.LootMethod.Masterlooter) but no art for it anywhere in its UI, so
-- it is not shown.
--
-- UnitIsGroupLeader / UnitIsGroupAssistant are secret for units that are
-- not player-controlled or in the group (SecretWhenUnitIdentityRestricted);
```

with

```lua
--   (CompactUnitFrame.lua, "IncomingResurrection").
-- Master looter: the client has the loot method (C_PartyInfo.GetLootMethod,
-- Enum.LootMethod.Masterlooter) but no art for it anywhere in its UI, so
-- the unit frames do not show it; raid cells show our own
-- (Media/MasterLooter.tga, tools/make_master_looter.py).
--
-- Raid cells (Raid/Cell.lua) place each icon on its own:
-- frame.iconPoint(frame, name) gives icon `name` ("leader", "looter",
-- "ready") its point on the cell and offsets, nil while it is off.
--
-- UnitIsGroupLeader / UnitIsGroupAssistant are secret for units that are
-- not player-controlled or in the group (SecretWhenUnitIdentityRestricted);
```

Replace

```lua
GroupIcons.READY = { ready = "UI-LFG-ReadyMark-Raid", notready = "UI-LFG-DeclineMark-Raid",
    waiting = "UI-LFG-PendingMark-Raid" }
GroupIcons.REZ_ATLAS = "RaidFrame-Icon-Rez"
-- CUF_READY_CHECK_DECAY_TIME (CompactUnitFrame.lua).
GroupIcons.READY_DECAY = 11
-- Above the text overlay (+10) and the aura holders (+12), below the class
```

with

```lua
GroupIcons.READY = { ready = "UI-LFG-ReadyMark-Raid", notready = "UI-LFG-DeclineMark-Raid",
    waiting = "UI-LFG-PendingMark-Raid" }
GroupIcons.REZ_ATLAS = "RaidFrame-Icon-Rez"
GroupIcons.LOOTER_TEXTURE = "Interface\\AddOns\\ForeverUnitFrames\\Media\\MasterLooter.tga"
-- The icons a raid cell places on their own.
GroupIcons.OWN_POINTS = { "leader", "looter", "ready" }
-- CUF_READY_CHECK_DECAY_TIME (CompactUnitFrame.lua).
GroupIcons.READY_DECAY = 11
-- Above the text overlay (+10) and the aura holders (+12), below the class
```

Replace

```lua
end

function GroupIcons.Build(frame)
    if not GroupIcons.Applies(frame.key) then return end
    local holder = CreateFrame("Frame", nil, frame)
    local g = { holder = holder }
    for _, name in ipairs({ "leader", "ready", "rez" }) do
```

with

```lua
end

function GroupIcons.Build(frame)
    if not (GroupIcons.Applies(frame.key) or frame.iconPoint) then return end
    local holder = CreateFrame("Frame", nil, frame)
    local g = { holder = holder }
    for _, name in ipairs({ "leader", "ready", "rez" }) do
```

Replace

```lua
        g[name]:Hide()
    end
    g.rez:SetAtlas(GroupIcons.REZ_ATLAS)
    frame.groupIcons = g
end
```

with

```lua
        g[name]:Hide()
    end
    g.rez:SetAtlas(GroupIcons.REZ_ATLAS)
    if frame.iconPoint then
        g.looter = holder:CreateTexture(nil, "OVERLAY")
        g.looter:SetTexture(GroupIcons.LOOTER_TEXTURE)
        g.looter:Hide()
    end
    frame.groupIcons = g
end
```

Replace

```lua
end

-- Any time, combat included: which icons show, from what the frame knows
-- (g.leaderKind, g.readyStatus, g.hasRez) or its test mode sample.
function GroupIcons.Refresh(frame)
    local g = frame.groupIcons
    if not g then return end
    local live = { leader = g.leaderKind, ready = g.readyStatus, rez = g.hasRez }
    local data = g.preview or live
    local kind = want(frame, "groupLeader") and data.leader or nil
    local status = want(frame, "groupReadyCheck") and data.ready or nil
```

with

```lua
end

-- Any time, combat included: which icons show, from what the frame knows
-- (g.leaderKind, g.readyStatus, g.hasRez, g.isLooter) or its test mode
-- sample. A raid cell's icons keep their own places.
function GroupIcons.Refresh(frame)
    local g = frame.groupIcons
    if not g then return end
    local live = { leader = g.leaderKind, ready = g.readyStatus, rez = g.hasRez, looter = g.isLooter }
    local data = g.preview or live
    local kind = want(frame, "groupLeader") and data.leader or nil
    local status = want(frame, "groupReadyCheck") and data.ready or nil
```

Replace

```lua
    g.leader:SetShown(kind ~= nil)
    g.ready:SetShown(status ~= nil)
    g.rez:SetShown(rez)
    local shown = {}
    for _, icon in ipairs({ g.leader, g.ready, g.rez }) do
        if icon:IsShown() then shown[#shown + 1] = icon end
```

with

```lua
    g.leader:SetShown(kind ~= nil)
    g.ready:SetShown(status ~= nil)
    g.rez:SetShown(rez)
    if g.looter then g.looter:SetShown(data.looter == true and frame.iconPoint(frame, "looter") ~= nil) end
    if frame.iconPoint then return end
    local shown = {}
    for _, icon in ipairs({ g.leader, g.ready, g.rez }) do
        if icon:IsShown() then shown[#shown + 1] = icon end
```

Replace

```lua
    arrange(g, shown)
end

-- Plain frames only: allowed in combat (party buttons restyle then too).
function GroupIcons.Style(frame)
    local g, scope = frame.groupIcons, frame.key
    if not g then return end
    local size = Pixel.Snap(Config.Get(scope, "groupIconSize"), nil, 1)
    g.size, g.gap, g.point = size, Pixel.Snap(GAP), Config.Get(scope, "groupIconPoint")
    local n = #slots(frame)
    g.holder:SetFrameLevel(frame:GetFrameLevel() + GroupIcons.LEVELS)
    g.holder:SetSize(math.max(1, Layout.IconRowWidth(n, size, g.gap)), size)
```

with

```lua
    arrange(g, shown)
end

-- A raid cell: each icon at its own point on the cell.
local function placeOwn(frame, g)
    for _, name in ipairs(GroupIcons.OWN_POINTS) do
        local icon = g[name]
        local point, x, y = frame.iconPoint(frame, name)
        if icon and point then
            icon:ClearAllPoints()
            icon:SetPoint(point, frame, point, Pixel.Snap(x), Pixel.Snap(y))
            icon:SetSize(g.size, g.size)
        end
    end
end

-- Plain frames only: allowed in combat (party buttons restyle then too).
function GroupIcons.Style(frame)
    local g, scope = frame.groupIcons, frame.key
    if not g then return end
    local size = Pixel.Snap(Config.Get(scope, "groupIconSize"), nil, 1)
    g.size, g.gap, g.point = size, Pixel.Snap(GAP), Config.Get(scope, "groupIconPoint")
    if frame.iconPoint then
        g.holder:SetFrameLevel(frame:GetFrameLevel() + GroupIcons.LEVELS)
        g.holder:ClearAllPoints()
        g.holder:SetAllPoints(frame)
        g.holder:Show()
        placeOwn(frame, g)
        GroupIcons.Refresh(frame)
        return
    end
    local n = #slots(frame)
    g.holder:SetFrameLevel(frame:GetFrameLevel() + GroupIcons.LEVELS)
    g.holder:SetSize(math.max(1, Layout.IconRowWidth(n, size, g.gap)), size)
```

Replace

```lua
    return nil
end

-- "ready", "notready", "waiting" or nil. Offline members show none, as
-- Blizzard's party frames (PartyMemberFrameMixin:UpdateReadyCheck).
local function readyStatus(unit)
```

with

```lua
    return nil
end

-- Whether unit is the master looter. C_PartyInfo.GetLootMethod (not
-- secret) names them by raid index in a raid, by party index in a party
-- (0: you, as the old GetLootMethod did; not documented in this build).
local function isLooter(unit)
    local info = C_PartyInfo
    if not (info and info.GetLootMethod and Enum.LootMethod) then return false end
    local ok, method, partyID, raidID = pcall(info.GetLootMethod)
    if not ok or method ~= Enum.LootMethod.Masterlooter then return false end
    local token
    if IsInRaid() then
        token = type(raidID) == "number" and ("raid" .. raidID) or nil
    elseif type(partyID) == "number" then
        token = partyID == 0 and "player" or ("party" .. partyID)
    end
    return token ~= nil and Secrets.Bool(UnitIsUnit, unit, token) == true
end

-- "ready", "notready", "waiting" or nil. Offline members show none, as
-- Blizzard's party frames (PartyMemberFrameMixin:UpdateReadyCheck).
local function readyStatus(unit)
```

Replace

```lua
    -- While a finished check decays its result stays as it was.
    if not decay then g.readyStatus = readyStatus(unit) end
    g.hasRez = Secrets.Bool(UnitHasIncomingResurrection, unit) == true
    GroupIcons.Refresh(frame)
end

local function sample(frame)
    if frame.sampleIndex then return GroupIcons.PARTY_SAMPLES[frame.sampleIndex] end
    return GroupIcons.SAMPLES[frame.key]
end
```

with

```lua
    -- While a finished check decays its result stays as it was.
    if not decay then g.readyStatus = readyStatus(unit) end
    g.hasRez = Secrets.Bool(UnitHasIncomingResurrection, unit) == true
    if g.looter then g.isLooter = isLooter(unit) end
    GroupIcons.Refresh(frame)
end

-- A raid test cell's own (frame.sample.groupIcons), the pretend party's,
-- or the frame's.
local function sample(frame)
    if frame.sample then return frame.sample.groupIcons end
    if frame.sampleIndex then return GroupIcons.PARTY_SAMPLES[frame.sampleIndex] end
    return GroupIcons.SAMPLES[frame.key]
end
```

Replace

```lua

ns.On("PARTY_LEADER_CHANGED", updateAll)
ns.On("GROUP_ROSTER_UPDATE", updateAll)
-- The confirming unit may be named by another token than the frame's
-- (a raid token): every frame looks again.
ns.On("READY_CHECK_CONFIRM", updateAll)
```

with

```lua

ns.On("PARTY_LEADER_CHANGED", updateAll)
ns.On("GROUP_ROSTER_UPDATE", updateAll)
ns.On("PARTY_LOOT_METHOD_CHANGED", updateAll)
-- The confirming unit may be named by another token than the frame's
-- (a raid token): every frame looks again.
ns.On("READY_CHECK_CONFIRM", updateAll)
```

- [ ] **Step 6: The cell places its icons**

In `Raid/Cell.lua`:

Replace

```lua
local FIXED = {
    titlePercent = 0, portraitMode = "OFF", castbarEnabled = false, combatFeedback = false,
    buffsEnabled = false, debuffsEnabled = false, threatGlow = false,
    titleClassIcon = false, healOverflow = false, healBeyond = false, shadowEnabled = false,
    textHealthLeft = "NAME", textPowerLeft = "NONE", textPowerRight = "NONE",
    healthPercent = 90, powerPercent = 10, fontSize = 11, valueFontSize = 10,
}
```

with

```lua
local FIXED = {
    titlePercent = 0, portraitMode = "OFF", castbarEnabled = false, combatFeedback = false,
    buffsEnabled = false, debuffsEnabled = false, threatGlow = false,
    titleClassIcon = false, healOverflow = false, healBeyond = false, shadowEnabled = false, groupResurrect = false,
    textHealthLeft = "NAME", textPowerLeft = "NONE", textPowerRight = "NONE",
    healthPercent = 90, powerPercent = 10, fontSize = 11, valueFontSize = 10,
}
```

Replace

```lua
    return x, y
end

local function insetX(key) return function() return (Cell.Inset(get(key))) end end
local function insetY(key) return function() return select(2, Cell.Inset(get(key))) end end

-- The raid profile's look, in unit-frame settings. The second line's
-- values are the text tags of the same name. The raid marker
-- (Elements/RaidMarker.lua) at its point, centred on it.
local MAPPED = {
    width = function() return get("cellWidth") end,
    height = function() return get("cellHeight") end,
```

with

```lua
    return x, y
end

-- The icons a cell places on their own (Elements/GroupIcons.lua asks):
-- point and offsets, nil while the icon is off.
Cell.ICON_KEYS = { leader = "leaderIcon", looter = "looterIcon", ready = "readyCheckIcon", role = "roleIcon" }
function Cell.IconPoint(_, name)
    local key = Cell.ICON_KEYS[name]
    if not key or not get(key) then return nil end
    local point = get(key .. "Point")
    local x, y = Cell.Inset(point)
    return point, x, y
end

local function insetX(key) return function() return (Cell.Inset(get(key))) end end
local function insetY(key) return function() return select(2, Cell.Inset(get(key))) end end

-- The raid profile's look, in unit-frame settings. The second line's
-- values are the text tags of the same name. The raid marker
-- (Elements/RaidMarker.lua) at its point, centred on it; the group icons
-- (Elements/GroupIcons.lua) switched and sized from the profile.
local MAPPED = {
    width = function() return get("cellWidth") end,
    height = function() return get("cellHeight") end,
```

Replace

```lua
    raidMarkerPoint = function() return get("raidMarkerPoint") end,
    raidMarkerX = insetX("raidMarkerPoint"),
    raidMarkerY = insetY("raidMarkerPoint"),
}

function Cell.Resolve(key)
```

with

```lua
    raidMarkerPoint = function() return get("raidMarkerPoint") end,
    raidMarkerX = insetX("raidMarkerPoint"),
    raidMarkerY = insetY("raidMarkerPoint"),
    groupLeader = function() return get("leaderIcon") end,
    groupReadyCheck = function() return get("readyCheckIcon") end,
    groupIconSize = function() return get("iconSize") end,
}

function Cell.Resolve(key)
```

Replace

```lua
    button.key = Cell.KEY
    button.centerTexts = true
    button.showsPower = Cell.ShowsPower
    -- No aura groups at all: no aura containers are made for a cell
    -- (Elements/AuraContainers.lua).
    button.auraGroupKeys = {}
```

with

```lua
    button.key = Cell.KEY
    button.centerTexts = true
    button.showsPower = Cell.ShowsPower
    button.iconPoint = Cell.IconPoint
    -- No aura groups at all: no aura containers are made for a cell
    -- (Elements/AuraContainers.lua).
    button.auraGroupKeys = {}
```

- [ ] **Step 7: The pretend members' group icons**

In `Raid/TestMode.lua`:

Replace

```lua
Test.DEBUFFS = { [2] = { 1, 2 }, [5] = { 3 }, [9] = { 4, 5, 1 } }
-- Raid target markers by raid index: a skull on the first tank, a star.
Test.MARKERS = { [1] = 8, [6] = 1 }

local on = false
```

with

```lua
Test.DEBUFFS = { [2] = { 1, 2 }, [5] = { 3 }, [9] = { 4, 5, 1 } }
-- Raid target markers by raid index: a skull on the first tank, a star.
Test.MARKERS = { [1] = 8, [6] = 1 }
-- Group icons by raid index: you lead and loot, member 2 assists; a ready
-- check under way.
Test.GROUP_ICONS = {
    [1] = { leader = "leader", looter = true, ready = "ready" }, [2] = { leader = "assistant", ready = "ready" },
    [4] = { ready = "notready" }, [5] = { ready = "waiting" },
}

local on = false
```

Replace

```lua
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
-- health, status, role, debuffs, marker } per member, in raid order.
function Test.Members(size)
    local list = {}
    for i = 1, size do
```

with

```lua
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
-- health, status, role, debuffs, marker, groupIcons } per member, in raid
-- order.
function Test.Members(size)
    local list = {}
    for i = 1, size do
```

Replace

```lua
            name = type(names) == "table" and names[s[1]] or s[1],
            health = Test.HEALTH[(i - 1) % #Test.HEALTH + 1], status = Test.STATUS[i] or false,
            debuffs = Test.DEBUFFS[(i - 1) % #Test.SAMPLES + 1] or {}, marker = Test.MARKERS[i],
        }
    end
    return list
```

with

```lua
            name = type(names) == "table" and names[s[1]] or s[1],
            health = Test.HEALTH[(i - 1) % #Test.HEALTH + 1], status = Test.STATUS[i] or false,
            debuffs = Test.DEBUFFS[(i - 1) % #Test.SAMPLES + 1] or {}, marker = Test.MARKERS[i],
            groupIcons = Test.GROUP_ICONS[i] or {},
        }
    end
    return list
```

- [ ] **Step 8: Run the tests**

Run: `tests/run raid_cell_group_icons` → `35 passed, 0 failed`
Run: `tests/run` → Expected: `20083 passed, 0 failed`

- [ ] **Step 9: Commit**

```bash
git add Elements/GroupIcons.lua Media/MasterLooter.tga Raid/Cell.lua Raid/TestMode.lua tests/mock.lua tests/test_raid_cell_group_icons.lua tools/make_master_looter.py
git commit -m "Raid cell: leader, master looter and ready check, each at its point

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Raid cell: the assigned role at its point

**Files:**
- Create: `Raid/CellRole.lua`
- Modify: `Raid/Cell.lua`, `ForeverUnitFrames.toc`
- Test: `tests/test_raid_cell_role.lua`

**Interfaces:**
- Consumes: `ns.RaidCell.IconPoint` (Task 3), `roleIcon*`, `roleIconDamager`, `iconSize`.
- Produces: `ns.RaidCell.Role(frame)` (the assigned role, or the sample's; nil when unreadable); `ns.RaidRole` (element `RaidRole`): `ATLAS`, `LEVELS` (18); `frame.raidRole = { holder, icon, role }`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_cell_role.lua`:

```lua
-- The role icon on raid cells (Raid/CellRole.lua): tank and healer by
-- default, damage when asked, at its point; secret roles show nothing.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell, Role = ns.RaidConfig, ns.RaidHeader, ns.RaidCell, ns.RaidRole
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Tank", class = "WARRIOR", subgroup = 1, assignedRole = "TANK" },
    { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "HEALER" },
    { name = "Bob", class = "MAGE", subgroup = 1, assignedRole = "DAMAGER" },
    { name = "Cid", class = "ROGUE", subgroup = 1 } })
M.RunTimers()

local function role(i) return Header.headers[1]:GetAttribute("child" .. i).raidRole end
local tank, ann, bob, cid = role(1), role(2), role(3), role(4)
H.checkTrue("tank shown", tank.icon:IsShown())
H.check("tank icon", tank.icon._atlas, Role.ATLAS.TANK)
H.check("healer icon", ann.icon._atlas, Role.ATLAS.HEALER)
H.check("damage: not by default", bob.icon:IsShown(), false)
H.check("no role: none", cid.icon:IsShown(), false)
local p, rel, relPoint, x, y = tank.icon:GetPoint(1)
H.checkTrue("left, inside", p == "LEFT" and relPoint == "LEFT" and x == 1 and y == 0)
H.check("size", tank.icon:GetWidth(), 14)
H.check("above the cell's auras", tank.holder:GetFrameLevel(),
    Header.headers[1]:GetAttribute("child1"):GetFrameLevel() + Role.LEVELS)

RC.Set("r10", "roleIconDamager", true)
H.check("damage shown", bob.icon._atlas, Role.ATLAS.DAMAGER)
RC.Set("r10", "roleIconPoint", "BOTTOMLEFT")
p, rel, relPoint, x, y = tank.icon:GetPoint(1)
H.checkTrue("moved", p == "BOTTOMLEFT" and x == 1 and y == 1)
RC.Set("r10", "roleIcon", false)
H.check("off", tank.icon:IsShown(), false)
RC.ResetScope("r10")
H.checkTrue("on again", tank.icon:IsShown())

-- Roles change: the icons follow; secret ones show nothing.
M.units.raid4.role = "HEALER"
M.FireEvent("PLAYER_ROLES_ASSIGNED")
H.check("new healer", cid.icon._atlas, Role.ATLAS.HEALER)
M.units.raid1.role = M.Secret("TANK")
M.FireEvent("PLAYER_ROLES_ASSIGNED")
H.check("secret role: none", tank.icon:IsShown(), false)

-- Unit frames: none.
H.check("player frame: none", ns.Frames.player.raidRole, nil)

-- Test mode: the pretend members' roles.
ns.TestMode.Set(true)
H.check("pretend tank", Cell.fakes[1].raidRole.icon._atlas, Role.ATLAS.TANK)
H.checkTrue("pretend healer", Cell.fakes[2].raidRole.icon:IsShown())
H.check("pretend damage: hidden", Cell.fakes[3].raidRole.icon:IsShown(), false)
ns.TestMode.Set(false)
H.check("no errors", #M.errors, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run test_raid_cell_role.lua`
Expected: `ERROR test_raid_cell_role.lua:19: attempt to index local 'tank' (a nil value)`, `0 passed, 1 failed`

- [ ] **Step 3: Let the role element read a cell's role**

In `Raid/Cell.lua`:

Replace

```lua
    return readable(ok, token)
end

local function roleOf(frame)
    if frame.sample then return frame.sample.role end
    return readable(pcall(UnitGroupRolesAssigned, frame.unit))
end

-- The power strip's rule (powerStrip; OFF switches the bar off
-- altogether): everyone, mana users by class, or healers by assigned
```

with

```lua
    return readable(ok, token)
end

function Cell.Role(frame)
    if frame.sample then return frame.sample.role end
    return readable(pcall(UnitGroupRolesAssigned, frame.unit))
end
local roleOf = Cell.Role

-- The power strip's rule (powerStrip; OFF switches the bar off
-- altogether): everyone, mana users by class, or healers by assigned
```

- [ ] **Step 4: Create `Raid/CellRole.lua`**

Create `Raid/CellRole.lua`:

```lua
local _, ns = ...

-- The assigned role on a raid cell, in the group finder's small role
-- icons (GetMicroIconForRole, Blizzard_SharedXMLBase/TextureUtil.lua: the
-- atlases below): tank and healer, damage too when asked
-- (roleIconDamager). At its own point (Raid/Cell.lua: Cell.IconPoint),
-- the profile's icon size. UnitGroupRolesAssigned is secret while the
-- unit's identity is restricted: nothing shows then. A texture on a
-- plain holder, so it may change in combat; test mode's pretend members
-- show their own role.
local Role = { name = "RaidRole" }
ns.RaidRole = Role

local Cell, Pixel = ns.RaidCell, ns.Pixel
local get = Cell.Get

Role.ATLAS = { TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder", HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
    DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder" }
-- With the other icons (Elements/GroupIcons.lua).
Role.LEVELS = 18

function Role.Build(frame)
    if frame.key ~= Cell.KEY then return end
    local holder = CreateFrame("Frame", nil, frame)
    local icon = holder:CreateTexture(nil, "OVERLAY")
    icon:Hide()
    frame.raidRole = { holder = holder, icon = icon }
end

-- Any time: the icon for r.role, or none.
local function refresh(frame)
    local r = frame.raidRole
    local atlas = Role.ATLAS[r.role or ""]
    local shown = atlas ~= nil and Cell.IconPoint(frame, "role") ~= nil
        and (r.role ~= "DAMAGER" or get("roleIconDamager") == true)
    if shown then r.icon:SetAtlas(atlas) end
    r.icon:SetShown(shown)
end

function Role.Style(frame)
    local r = frame.raidRole
    if not r then return end
    r.holder:SetFrameLevel(frame:GetFrameLevel() + Role.LEVELS)
    r.holder:ClearAllPoints()
    r.holder:SetAllPoints(frame)
    local point, x, y = Cell.IconPoint(frame, "role")
    if point then
        local size = Pixel.Snap(get("iconSize"), nil, 1)
        r.icon:ClearAllPoints()
        r.icon:SetPoint(point, frame, point, Pixel.Snap(x), Pixel.Snap(y))
        r.icon:SetSize(size, size)
    end
    refresh(frame)
end

function Role.Update(frame)
    local r = frame.raidRole
    if not r or r.preview then return end
    r.role = Cell.Role(frame)
    refresh(frame)
end

function Role.Preview(frame, on)
    local r = frame.raidRole
    if not r then return end
    r.preview = on or nil
    r.role = Cell.Role(frame)
    refresh(frame)
end

ns.On("PLAYER_ROLES_ASSIGNED", function(event) ns.Units.UpdateElement(Role, event) end)

ns.RegisterElement(Role)
```

- [ ] **Step 5: Load it**

`Raid\CellRole.lua` loads directly after `Raid\Indicators.lua`.

In `ForeverUnitFrames.toc`:

Replace

```
Raid\Cell.xml
Raid\CellAuras.lua
Raid\Indicators.lua
Raid\Header.lua
Raid\TestMode.lua
Core\Blizzard.lua
```

with

```
Raid\Cell.xml
Raid\CellAuras.lua
Raid\Indicators.lua
Raid\CellRole.lua
Raid\Header.lua
Raid\TestMode.lua
Core\Blizzard.lua
```

- [ ] **Step 6: Run the tests**

Run: `tests/run raid_cell_role` → `19 passed, 0 failed`
Run: `tests/run` → Expected: `20102 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add ForeverUnitFrames.toc Raid/Cell.lua Raid/CellRole.lua tests/test_raid_cell_role.lua
git commit -m "Raid cell: the assigned role at its point

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Raid cell: faded out of range, opacity per size

**Files:**
- Modify: `Elements/Range.lua`, `Raid/Cell.lua`, `Raid/TestMode.lua`, `tests/mock.lua`
- Test: `tests/test_raid_cell_range.lua`

**Interfaces:**
- Consumes: `ns.Range` (poll, `SetAlphaFromBoolean`), `RAID_CELLS_CHANGED` (R2a), `rangeFade` / `rangeAlpha` of Task 1.
- Produces: frame hook `frame.fadesOutOfRange` (set by `Cell.Setup`); the cell's mapping of `rangeFade` / `rangeAlpha`; `Range` takes a raid test cell's own sample (`frame.sample.outOfRange`); `RaidTestMode.OUT_OF_RANGE` and `member.outOfRange`; mock `UnitInRange` checks raid tokens too.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_cell_range.lua`:

```lua
-- Range fading and the grey of the dead and offline on raid cells: the
-- unit frames' elements (Elements/Range.lua, Elements/UnitStatus.lua),
-- switch and opacity from the raid profile of the active size.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell = ns.RaidConfig, ns.RaidHeader, ns.RaidCell
M.units.player = { name = "Me", class = "WARRIOR", className = "Warrior", isPlayer = true, level = 60,
    health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
-- The unit frames do not fade: the timer runs for cells only.
for _, scope in ipairs({ "party", "pet", "target", "targettarget", "focus" }) do ns.Config.Set(scope, "rangeFade", false) end
H.check("solo: no timer for cells", ns.Range.driver:IsShown(), false)
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 },
    { name = "Bob", class = "MAGE", subgroup = 1, unit = { inRange = false } },
    { name = "Cid", class = "ROGUE", subgroup = 1, unit = { dead = true } },
    { name = "Dan", class = "DRUID", subgroup = 1, unit = { offline = true } } })
M.RunTimers()
local function cell(i) return Header.headers[1]:GetAttribute("child" .. i) end

H.checkTrue("in a raid: the timer runs", ns.Range.driver:IsShown())
M.Tick(0.25)
H.check("in range: full", cell(1):GetAlpha(), 1)
H.check("out of range: the raid profile's opacity", cell(2):GetAlpha(), 0.4)
RC.Set("r10", "rangeAlpha", 20)
H.check("opacity per size", cell(2):GetAlpha(), 0.2)
M.units.raid2.inRange = true
M.Tick(0.25)
H.check("back in range", cell(2):GetAlpha(), 1)
M.units.raid2.inRange = false
M.rangeSecret = "inRange"
M.Tick(0.25)
H.check("secret answer: alpha from it", cell(2)._alphaSecret, true)
M.rangeSecret = false
RC.Set("r10", "rangeFade", false)
M.Tick(0.25)
H.check("off: full", cell(2):GetAlpha(), 1)
H.check("off: no timer", ns.Range.driver:IsShown(), false)
RC.ResetScope("r10")
H.checkTrue("on: the timer again", ns.Range.driver:IsShown())

-- The dead and the offline: grey bars, their word.
H.check("dead: grey", cell(3).health._color[1], ns.UnitStatus.GREY[1])
H.check("dead: word", cell(3).texts.healthRight:GetText(), ns.L.STATUS_DEAD)
H.check("offline: grey", cell(4).health._color[1], ns.UnitStatus.GREY[1])
H.check("offline: word", cell(4).texts.healthRight:GetText(), ns.L.STATUS_OFFLINE)
H.checkTrue("alive: class colour", cell(1).health._color[1] ~= ns.UnitStatus.GREY[1])

-- Leaving the raid: no cell shows a unit, the timer stops.
M.SetRaidRoster({})
M.RunTimers()
H.check("left: no timer", ns.Range.driver:IsShown(), false)

-- Test mode: the pretend rogue is out of range.
H.check("member 4 out of range", ns.RaidTestMode.Members(10)[4].outOfRange, true)
H.check("member 14 too", ns.RaidTestMode.Members(20)[14].outOfRange, true)
ns.TestMode.Set(true)
H.check("pretend rogue: faded", Cell.fakes[4]:GetAlpha(), 0.4)
H.check("pretend priest: full", Cell.fakes[2]:GetAlpha(), 1)
ns.TestMode.Set(false)
H.check("no errors", #M.errors, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run test_raid_cell_range.lua`
Expected: 8 failures, the first `FAIL in a raid: the timer runs -> false (want true)`, `13 passed, 8 failed`

- [ ] **Step 3: Mock: raid members are range-checked**

In `tests/mock.lua`:

Replace

```lua
            inRange = d.inRange ~= false
            if d.inRange == nil and d.distance then inRange = d.distance <= 40 end
            checked = d.rangeChecked
            if checked == nil then checked = groupToken(unit) ~= nil or d.inParty == true end
        end
        if M.rangeSecret == "inRange" then return M.Secret(inRange), checked end
        if M.rangeSecret then return M.Secret(inRange), M.Secret(checked) end
```

with

```lua
            inRange = d.inRange ~= false
            if d.inRange == nil and d.distance then inRange = d.distance <= 40 end
            checked = d.rangeChecked
            -- Group members are checked: party and raid tokens.
            if checked == nil then
                checked = groupToken(unit) ~= nil or unit:match("^raid%d+$") ~= nil or d.inParty == true
            end
        end
        if M.rangeSecret == "inRange" then return M.Secret(inRange), checked end
        if M.rangeSecret then return M.Secret(inRange), M.Secret(checked) end
```

- [ ] **Step 4: Cells fade**

In `Elements/Range.lua`:

Replace

```lua
-- Test mode: pretend party member 4 is out of range.
Range.PARTY_SAMPLES = { [4] = true }

-- Frames that may fade: the setting's frames, and the party pets, whose
-- derived scope follows the party's.
local function applies(frame)
    return Settings.AppliesTo(Settings.Get("rangeFade"), frame.key) or frame.key == ns.Party.PET_KEY
end

local function enabled(frame)
```

with

```lua
-- Test mode: pretend party member 4 is out of range.
Range.PARTY_SAMPLES = { [4] = true }

-- Frames that may fade: the setting's frames, the party pets, whose
-- derived scope follows the party's, and raid cells (frame.fadesOutOfRange,
-- Raid/Cell.lua: their derived scope takes switch and opacity from the
-- raid profile).
local function applies(frame)
    return Settings.AppliesTo(Settings.Get("rangeFade"), frame.key) or frame.key == ns.Party.PET_KEY
        or frame.fadesOutOfRange == true
end

local function enabled(frame)
```

Replace

```lua

function Range.Build() end

-- Whether any frame has fading on (the party's setting covers its pets).
local SCOPES = { "party", "target", "targettarget", "focus", "pet" }
local function anyEnabled()
    if not (Range.ReactionOn("friendly") or Range.ReactionOn("hostile")) then return false end
    for _, scope in ipairs(SCOPES) do
        if Config.Get(scope, "rangeFade") then return true end
    end
    return false
end
```

with

```lua

function Range.Build() end

-- Whether any frame has fading on (the party's setting covers its pets;
-- raid cells count while one shows a unit).
local SCOPES = { "party", "target", "targettarget", "focus", "pet" }
local function anyEnabled()
    if not (Range.ReactionOn("friendly") or Range.ReactionOn("hostile")) then return false end
    for _, scope in ipairs(SCOPES) do
        if Config.Get(scope, "rangeFade") then return true end
    end
    for _, cell in ipairs(ns.RaidCell and ns.RaidCell.buttons or {}) do
        if cell.unit and enabled(cell) then return true end
    end
    return false
end
```

Replace

```lua
    Range.driver:SetShown(anyEnabled())
end

-- A mode switched off or on starts or stops the timer; the next check
-- (the poll, or the restyle) redraws the frames.
ns.Listen("CONFIG_CHANGED", function(_, key)
```

with

```lua
    Range.driver:SetShown(anyEnabled())
end

-- Raid cells got or lost units: the timer may be needed now, or no more.
ns.Listen("RAID_CELLS_CHANGED", syncDriver)

-- A mode switched off or on starts or stops the timer; the next check
-- (the poll, or the restyle) redraws the frames.
ns.Listen("CONFIG_CHANGED", function(_, key)
```

Replace

```lua
    if applies(frame) then check(frame) end
end

-- In test mode rangeSample is true for a member shown out of range,
-- false for the others; nil outside test mode.
function Range.Preview(frame, on)
    if not applies(frame) then return end
    if on then
        frame.rangeSample = (frame.sampleIndex and Range.PARTY_SAMPLES[frame.sampleIndex]) and true or false
        check(frame)
```

with

```lua
    if applies(frame) then check(frame) end
end

-- In test mode rangeSample is true for a member shown out of range (a
-- raid test cell's own, frame.sample.outOfRange, or the pretend party's),
-- false for the others; nil outside test mode.
function Range.Preview(frame, on)
    if not applies(frame) then return end
    if on and frame.sample then
        frame.rangeSample = frame.sample.outOfRange == true
        check(frame)
        return
    end
    if on then
        frame.rangeSample = (frame.sampleIndex and Range.PARTY_SAMPLES[frame.sampleIndex]) and true or false
        check(frame)
```

- [ ] **Step 5: Switch and opacity from the raid profile**

In `Raid/Cell.lua`:

Replace

```lua
-- The raid profile's look, in unit-frame settings. The second line's
-- values are the text tags of the same name. The raid marker
-- (Elements/RaidMarker.lua) at its point, centred on it; the group icons
-- (Elements/GroupIcons.lua) switched and sized from the profile.
local MAPPED = {
    width = function() return get("cellWidth") end,
    height = function() return get("cellHeight") end,
```

with

```lua
-- The raid profile's look, in unit-frame settings. The second line's
-- values are the text tags of the same name. The raid marker
-- (Elements/RaidMarker.lua) at its point, centred on it; the group icons
-- (Elements/GroupIcons.lua) switched and sized from the profile; range
-- fading (Elements/Range.lua) from the profile.
local MAPPED = {
    width = function() return get("cellWidth") end,
    height = function() return get("cellHeight") end,
```

Replace

```lua
    groupLeader = function() return get("leaderIcon") end,
    groupReadyCheck = function() return get("readyCheckIcon") end,
    groupIconSize = function() return get("iconSize") end,
}

function Cell.Resolve(key)
```

with

```lua
    groupLeader = function() return get("leaderIcon") end,
    groupReadyCheck = function() return get("readyCheckIcon") end,
    groupIconSize = function() return get("iconSize") end,
    rangeFade = function() return get("rangeFade") end,
    rangeAlpha = function() return get("rangeAlpha") end,
}

function Cell.Resolve(key)
```

Replace

```lua
    button.centerTexts = true
    button.showsPower = Cell.ShowsPower
    button.iconPoint = Cell.IconPoint
    -- No aura groups at all: no aura containers are made for a cell
    -- (Elements/AuraContainers.lua).
    button.auraGroupKeys = {}
```

with

```lua
    button.centerTexts = true
    button.showsPower = Cell.ShowsPower
    button.iconPoint = Cell.IconPoint
    button.fadesOutOfRange = true
    -- No aura groups at all: no aura containers are made for a cell
    -- (Elements/AuraContainers.lua).
    button.auraGroupKeys = {}
```

- [ ] **Step 6: The pretend rogue is out of range**

In `Raid/TestMode.lua`:

Replace

```lua
-- samples): a magic one and a curse, a poison, a disease, one without a
-- type and magic again.
Test.DEBUFFS = { [2] = { 1, 2 }, [5] = { 3 }, [9] = { 4, 5, 1 } }
-- Raid target markers by raid index: a skull on the first tank, a star.
Test.MARKERS = { [1] = 8, [6] = 1 }
-- Group icons by raid index: you lead and loot, member 2 assists; a ready
```

with

```lua
-- samples): a magic one and a curse, a poison, a disease, one without a
-- type and magic again.
Test.DEBUFFS = { [2] = { 1, 2 }, [5] = { 3 }, [9] = { 4, 5, 1 } }
-- Out of range by place in the ten: the rogue.
Test.OUT_OF_RANGE = { [4] = true }
-- Raid target markers by raid index: a skull on the first tank, a star.
Test.MARKERS = { [1] = 8, [6] = 1 }
-- Group icons by raid index: you lead and loot, member 2 assists; a ready
```

Replace

```lua
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
-- health, status, role, debuffs, marker, groupIcons } per member, in raid
-- order.
function Test.Members(size)
    local list = {}
    for i = 1, size do
```

with

```lua
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
-- health, status, role, debuffs, marker, groupIcons, outOfRange } per
-- member, in raid order.
function Test.Members(size)
    local list = {}
    for i = 1, size do
```

Replace

```lua
            health = Test.HEALTH[(i - 1) % #Test.HEALTH + 1], status = Test.STATUS[i] or false,
            debuffs = Test.DEBUFFS[(i - 1) % #Test.SAMPLES + 1] or {}, marker = Test.MARKERS[i],
            groupIcons = Test.GROUP_ICONS[i] or {},
        }
    end
    return list
```

with

```lua
            health = Test.HEALTH[(i - 1) % #Test.HEALTH + 1], status = Test.STATUS[i] or false,
            debuffs = Test.DEBUFFS[(i - 1) % #Test.SAMPLES + 1] or {}, marker = Test.MARKERS[i],
            groupIcons = Test.GROUP_ICONS[i] or {},
            outOfRange = Test.OUT_OF_RANGE[(i - 1) % #Test.SAMPLES + 1] == true,
        }
    end
    return list
```

- [ ] **Step 7: Run the tests**

Run: `tests/run raid_cell_range` → `21 passed, 0 failed`
Run: `tests/run` → Expected: `20123 passed, 0 failed`

- [ ] **Step 8: Commit**

```bash
git add Elements/Range.lua Raid/Cell.lua Raid/TestMode.lua tests/mock.lua tests/test_raid_cell_range.lua
git commit -m "Raid cell: faded out of range, opacity per size

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Raid cell: aggro and target lines along the inside

**Files:**
- Create: `Raid/CellStates.lua`
- Modify: `Raid/TestMode.lua`, `ForeverUnitFrames.toc`
- Test: `tests/test_raid_cell_states.lua`

**Interfaces:**
- Consumes: `aggroBorder` / `targetBorder` of Task 1, `ns.RaidCell.Get`, `ns.Secrets`.
- Produces: `ns.RaidStates` (element `RaidStates`, unit event `UNIT_THREAT_SITUATION_UPDATE`): `AGGRO_COLOR`, `TARGET_COLOR`, `SIZE` (2), `LEVELS` (11), `AGGRO_MIN` / `AGGRO_MAX` (1 / 2), `TEXTURE`, `SAMPLE_AGGRO` (3); `frame.raidStates = { aggro = { bars }, target = { edges }, preview }`; `RaidTestMode.AGGRO`, `RaidTestMode.TARGET`, `member.aggro`, `member.target`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_cell_states.lua`:

```lua
-- Aggro and target lines on raid cells (Raid/CellStates.lua): status bars
-- along the inside fed the threat status as it is (secret or not), and a
-- light line on your current target.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell, States = ns.RaidConfig, ns.RaidHeader, ns.RaidCell, ns.RaidStates
M.units.player = { name = "Me", class = "WARRIOR", className = "Warrior", isPlayer = true, level = 60,
    health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Tank", class = "WARRIOR", subgroup = 1, unit = { threat = 3 } },
    { name = "Ann", class = "PRIEST", subgroup = 1, unit = { threat = 1 } },
    { name = "Bob", class = "MAGE", subgroup = 1 } })
M.RunTimers()
local function cell(i) return Header.headers[1]:GetAttribute("child" .. i) end
local tank, ann, bob = cell(1).raidStates, cell(2).raidStates, cell(3).raidStates

-- Aggro: four bars from 1 to 2, red, fed the status.
local bar = tank.aggro.bars[1]
H.check("four bars", #tank.aggro.bars, 4)
H.check("a status bar", bar:GetObjectType(), "StatusBar")
H.check("from 1 to 2", table.concat({ bar:GetMinMaxValues() }, ","), "1,2")
H.check("red", bar._color[1] .. "," .. bar._color[2], "1,0")
H.check("tanking: status 3", bar:GetValue(), 3)
H.check("not tanking: status 1", ann.aggro.bars[1]:GetValue(), 1)
H.check("no threat: 0", bob.aggro.bars[1]:GetValue(), 0)
H.checkTrue("shown", tank.aggro:IsShown())
local p, rel, relPoint, x, y = bar:GetPoint(1)
H.checkTrue("top edge along the inside", p == "TOPLEFT" and rel == cell(1) and x == 0 and y == 0)
H.check("two pixels", bar:GetHeight(), 2)
H.check("above the texts", tank.aggro:GetFrameLevel(), cell(1):GetFrameLevel() + States.LEVELS)

M.units.raid2.threat = M.Secret(2)
M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "raid2")
H.checkTrue("secret status: passed on as it is", M.IsSecret(ann.aggro.bars[1]:GetValue()))
M.units.raid2.threat = 0
M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "raid2")
H.check("threat gone", ann.aggro.bars[2]:GetValue(), 0)
RC.Set("r10", "aggroBorder", false)
H.check("off: hidden", tank.aggro:IsShown(), false)
RC.ResetScope("r10")
H.checkTrue("on again", tank.aggro:IsShown())

-- Your target: a light line, two pixels further in.
H.check("no target: none", ann.target:IsShown(), false)
M.units.target = M.units.raid2
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("target: shown", ann.target:IsShown())
H.check("target: opaque", ann.target:GetAlpha(), 1)
H.check("others: none", tank.target:IsShown(), false)
local edge = ann.target.edges[1]
p, rel, relPoint, x, y = edge:GetPoint(1)
H.check("inside the red line", x .. "," .. y, "2,-2")
H.check("light", edge._color[1] .. "," .. edge._color[4], "1,0.9")
RC.Set("r10", "targetBorder", false)
H.check("off: hidden", ann.target:IsShown(), false)
RC.ResetScope("r10")
H.checkTrue("on: back", ann.target:IsShown())
M.units.target = nil
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("target cleared", ann.target:IsShown(), false)

-- Unit frames: none.
H.check("player frame: none", ns.Frames.player.raidStates, nil)

-- Test mode: the pretend tank has aggro, member 2 is your target.
ns.TestMode.Set(true)
H.check("pretend tank: aggro", Cell.fakes[1].raidStates.aggro.bars[1]:GetValue(), States.SAMPLE_AGGRO)
H.check("pretend priest: none", Cell.fakes[2].raidStates.aggro.bars[1]:GetValue(), 0)
H.checkTrue("pretend priest: your target", Cell.fakes[2].raidStates.target:IsShown())
H.check("pretend tank: not your target", Cell.fakes[1].raidStates.target:IsShown(), false)
ns.TestMode.Set(false)
H.check("no errors", #M.errors, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run test_raid_cell_states.lua`
Expected: `ERROR test_raid_cell_states.lua:20: attempt to index local 'tank' (a nil value)`, `0 passed, 1 failed`

- [ ] **Step 3: Create `Raid/CellStates.lua`**

Create `Raid/CellStates.lua`:

```lua
local _, ns = ...

-- States of a raid cell drawn as inner borders (the rest is the unit
-- frames' own: range fading, Elements/Range.lua; the grey of the dead and
-- offline, Elements/UnitStatus.lua):
-- * aggro: a red line along the inside while the unit has aggro.
--   UnitThreatSituation is secret while the unit's threat state is
--   restricted, and a secret status cannot be compared or coloured by
--   addon code (GetThreatStatusColor refuses it). Status bars take a
--   secret value (SetValue: SecretArguments AllowedWhenTainted), so the
--   four edges are status bars from 1 to 2, fed the status as it is: at 2
--   (tanking, not securely) and 3 (tanking) they are full, at 0 and 1
--   empty. Nothing is compared here; whether the client draws a secret
--   value that way is checked in game.
-- * your current target: a light line inside the red one. UnitIsUnit may
--   answer with a secret: the line's opacity takes it as it is
--   (SetAlphaFromBoolean), as the party's target highlight does.
-- Plain frames: they change in combat.
local States = { name = "RaidStates", unitEvents = { "UNIT_THREAT_SITUATION_UPDATE" } }
ns.RaidStates = States

local Cell, Pixel, Secrets = ns.RaidCell, ns.Pixel, ns.Secrets
local get = Cell.Get

States.AGGRO_COLOR = { 1, 0, 0, 1 }
States.TARGET_COLOR = { 1, 1, 1, 0.9 }
-- Each line's thickness in pixels.
States.SIZE = 2
-- Above the bars' texts (+10), below the cell's auras (+12).
States.LEVELS = 11
States.AGGRO_MIN, States.AGGRO_MAX = 1, 2
States.TEXTURE = "Interface\\Buttons\\WHITE8x8"
-- Test mode: the status a pretend member with aggro shows.
States.SAMPLE_AGGRO = 3

-- Four edges inside frame, `inset` from its edge, `thick` wide.
local function placeInner(edges, frame, inset, thick)
    local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
    for _, edge in ipairs(edges) do edge:ClearAllPoints() end
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
    top:SetHeight(thick)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    bottom:SetHeight(thick)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -(inset + thick))
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset + thick)
    left:SetWidth(thick)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -(inset + thick))
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset + thick)
    right:SetWidth(thick)
end

function States.Build(frame)
    if frame.key ~= Cell.KEY then return end
    local aggro, target = CreateFrame("Frame", nil, frame), CreateFrame("Frame", nil, frame)
    local c = States.AGGRO_COLOR
    aggro.bars = {}
    for i = 1, 4 do
        local bar = CreateFrame("StatusBar", nil, aggro)
        bar:SetStatusBarTexture(States.TEXTURE)
        bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
        bar:SetMinMaxValues(States.AGGRO_MIN, States.AGGRO_MAX)
        bar:SetValue(0)
        aggro.bars[i] = bar
    end
    local t = States.TARGET_COLOR
    target.edges = {}
    for i = 1, 4 do
        target.edges[i] = target:CreateTexture(nil, "OVERLAY")
        target.edges[i]:SetColorTexture(t[1], t[2], t[3], t[4])
    end
    target:Hide()
    frame.raidStates = { aggro = aggro, target = target }
end

-- The threat status as it is (plain or secret), 0 for none.
local function threat(unit)
    local ok, status = pcall(UnitThreatSituation, unit)
    if not ok or (not Secrets.IsSecret(status) and type(status) ~= "number") then return 0 end
    return status
end

local function showAggro(s, value)
    for _, bar in ipairs(s.aggro.bars) do bar:SetValue(value) end
end

-- shown: plain; answer: the client's answer (plain or secret), nil when
-- shown says it all.
local function showTarget(s, shown, answer)
    s.target:SetShown(shown)
    if not shown then return end
    if answer == nil then s.target:SetAlpha(1) else s.target:SetAlphaFromBoolean(answer, 1, 0) end
end

local function updateTarget(frame)
    local s = frame.raidStates
    if not get("targetBorder") or not frame.unit then
        showTarget(s, false)
        return
    end
    local ok, answer = pcall(UnitIsUnit, frame.unit, "target")
    if not ok then
        showTarget(s, false)
    elseif Secrets.IsSecret(answer) then
        showTarget(s, true, answer)
    else
        showTarget(s, answer == true)
    end
end

-- Test mode: the pretend member's aggro and whether it is your target.
local function showSample(frame)
    local s, member = frame.raidStates, frame.sample or {}
    showAggro(s, member.aggro and States.SAMPLE_AGGRO or 0)
    showTarget(s, member.target == true and get("targetBorder") == true)
end

function States.Style(frame)
    local s = frame.raidStates
    if not s then return end
    local thick = Pixel.Snap(States.SIZE, nil, 1)
    for _, holder in ipairs({ s.aggro, s.target }) do
        holder:SetFrameLevel(frame:GetFrameLevel() + States.LEVELS)
        holder:SetAllPoints(frame)
    end
    placeInner(s.aggro.bars, frame, 0, thick)
    placeInner(s.target.edges, frame, thick, thick)
    s.aggro:SetShown(get("aggroBorder") == true)
    if s.preview then showSample(frame) else updateTarget(frame) end
end

function States.Update(frame)
    local s = frame.raidStates
    if not s or s.preview then return end
    showAggro(s, frame.unit and threat(frame.unit) or 0)
    updateTarget(frame)
end

function States.Preview(frame, on)
    local s = frame.raidStates
    if not s then return end
    s.preview = on or nil
    if on then
        showSample(frame)
    else
        showAggro(s, 0)
        showTarget(s, false)
    end
end

-- A new target: every cell looks again; after combat, threat too.
local function updateAll(event) ns.Units.UpdateElement(States, event) end
ns.On("PLAYER_TARGET_CHANGED", updateAll)
ns.On("PLAYER_REGEN_ENABLED", updateAll)

ns.RegisterElement(States)
```

- [ ] **Step 4: Load it**

`Raid\CellStates.lua` loads directly after `Raid\CellRole.lua`.

In `ForeverUnitFrames.toc`:

Replace

```
Raid\CellAuras.lua
Raid\Indicators.lua
Raid\CellRole.lua
Raid\Header.lua
Raid\TestMode.lua
Core\Blizzard.lua
```

with

```
Raid\CellAuras.lua
Raid\Indicators.lua
Raid\CellRole.lua
Raid\CellStates.lua
Raid\Header.lua
Raid\TestMode.lua
Core\Blizzard.lua
```

- [ ] **Step 5: The pretend tank has aggro, member 2 is your target**

In `Raid/TestMode.lua`:

Replace

```lua
Test.DEBUFFS = { [2] = { 1, 2 }, [5] = { 3 }, [9] = { 4, 5, 1 } }
-- Out of range by place in the ten: the rogue.
Test.OUT_OF_RANGE = { [4] = true }
-- Raid target markers by raid index: a skull on the first tank, a star.
Test.MARKERS = { [1] = 8, [6] = 1 }
-- Group icons by raid index: you lead and loot, member 2 assists; a ready
```

with

```lua
Test.DEBUFFS = { [2] = { 1, 2 }, [5] = { 3 }, [9] = { 4, 5, 1 } }
-- Out of range by place in the ten: the rogue.
Test.OUT_OF_RANGE = { [4] = true }
-- The first tank has aggro; member 2 is your target.
Test.AGGRO = { [1] = true }
Test.TARGET = 2
-- Raid target markers by raid index: a skull on the first tank, a star.
Test.MARKERS = { [1] = 8, [6] = 1 }
-- Group icons by raid index: you lead and loot, member 2 assists; a ready
```

Replace

```lua
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
-- health, status, role, debuffs, marker, groupIcons, outOfRange } per
-- member, in raid order.
function Test.Members(size)
    local list = {}
    for i = 1, size do
```

with

```lua
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
-- health, status, role, debuffs, marker, groupIcons, outOfRange, aggro,
-- target } per member, in raid order.
function Test.Members(size)
    local list = {}
    for i = 1, size do
```

Replace

```lua
            debuffs = Test.DEBUFFS[(i - 1) % #Test.SAMPLES + 1] or {}, marker = Test.MARKERS[i],
            groupIcons = Test.GROUP_ICONS[i] or {},
            outOfRange = Test.OUT_OF_RANGE[(i - 1) % #Test.SAMPLES + 1] == true,
        }
    end
    return list
```

with

```lua
            debuffs = Test.DEBUFFS[(i - 1) % #Test.SAMPLES + 1] or {}, marker = Test.MARKERS[i],
            groupIcons = Test.GROUP_ICONS[i] or {},
            outOfRange = Test.OUT_OF_RANGE[(i - 1) % #Test.SAMPLES + 1] == true,
            aggro = Test.AGGRO[i] == true, target = i == Test.TARGET,
        }
    end
    return list
```

- [ ] **Step 6: Run the tests**

Run: `tests/run raid_cell_states` → `30 passed, 0 failed`
Run: `tests/run` → Expected: `20153 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add ForeverUnitFrames.toc Raid/CellStates.lua Raid/TestMode.lua tests/test_raid_cell_states.lua
git commit -m "Raid cell: aggro and target lines along the inside

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Raid cell: pin down what cells never get

**Files:**
- Modify: `Raid/Cell.lua`
- Test: `tests/test_raid_cell_negative.lua`

**Interfaces:**
- Consumes: every element (`ns.Elements`), the live and pretend cells.
- Produces: nothing new; the test guards that cells never build the castbar, the unit frames' dispel ring and aura containers, the party's target highlight, the threat bar, combo points, totems, status icons, pet happiness, combat and PvP icons, the elite marker, power cost or druid mana, and that threat glow, class icon, portrait, title row and the resurrection icon stay hidden on them.

- [ ] **Step 1: Write the test**

Create `tests/test_raid_cell_negative.lua`:

```lua
-- What raid cells never get, live or pretend: the unit-frame elements
-- that belong to other frames build nothing on them, and those every
-- frame builds stay hidden under the cell's fixed settings
-- (Raid/Cell.lua). Their own auras, icons and lines are tested elsewhere.
local M = H.M
local ns = H.LoadAddon()
local Header, Cell = ns.RaidHeader, ns.RaidCell
M.units.player = { name = "Me", class = "SHAMAN", className = "Shaman", isPlayer = true, level = 60,
    health = 100, healthMax = 100, powerType = 0, power = 10, powerMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Ann", class = "DRUID", subgroup = 1,
    unit = { threat = 3, combat = true, pvp = true, incomingRez = true, powerType = 0, power = 10, powerMax = 100 } } })
M.RunTimers()
ns.TestMode.Set(true)

local NEVER = { "castbar", "dispel", "targetHighlight", "threatBar", "combo", "totems", "statusIcons",
    "petHappiness", "unitIcons", "eliteLayer", "powerCost", "druidMana" }
local live = Header.headers[1]:GetAttribute("child1")
for label, cell in pairs({ live = live, pretend = Cell.fakes[1] }) do
    for _, field in ipairs(NEVER) do
        H.check(label .. ": no " .. field, cell[field], nil)
    end
    H.check(label .. ": no unit-frame aura containers", next(cell.auraContainers or {}), nil)
    H.check(label .. ": threat glow hidden", cell.threat.frame:IsShown(), false)
    H.check(label .. ": threat glow (block) hidden", cell.threat.block:IsShown(), false)
    H.check(label .. ": no class icon", cell.classIcon:IsShown() or cell.classRing:IsShown(), false)
    H.check(label .. ": no portrait", cell.portrait2D:IsShown() or cell.portrait3D:IsShown(), false)
    H.check(label .. ": no title row", cell.title:IsShown(), false)
    H.check(label .. ": no resurrection icon", cell.groupIcons.rez:IsShown(), false)
    H.check(label .. ": not a single frame", ns.Frames[cell.key], nil)
end
ns.TestMode.Set(false)
-- Live: no combat numbers either.
M.FireEvent("UNIT_COMBAT", "raid1", "WOUND", nil, 500, 1)
H.check("live: no combat numbers", live.feedback:IsShown(), false)
H.check("no errors", #M.errors, 0)
```

- [ ] **Step 2: Run the test**

Run: `tests/run test_raid_cell_negative.lua`
Expected: `42 passed, 0 failed` — this test pins down what R2a and R3 already do (the negative checks R2a deferred); it fails as soon as an element starts building on cells.

- [ ] **Step 3: Correct R2a's comment on cell containers**

In `Raid/Cell.lua`:

Replace

```lua
    button.showsPower = Cell.ShowsPower
    button.iconPoint = Cell.IconPoint
    button.fadesOutOfRange = true
    -- No aura groups at all: no aura containers are made for a cell
    -- (Elements/AuraContainers.lua).
    button.auraGroupKeys = {}
    for _, el in ipairs(ns.Elements) do el.Build(button) end
    ns.Units.EnableTooltip(button)
```

with

```lua
    button.showsPower = Cell.ShowsPower
    button.iconPoint = Cell.IconPoint
    button.fadesOutOfRange = true
    -- None of the unit frames' aura groups (Elements/AuraContainers.lua
    -- makes no container for them); a cell's own auras are one container
    -- of its own (Raid/CellAuras.lua).
    button.auraGroupKeys = {}
    for _, el in ipairs(ns.Elements) do el.Build(button) end
    ns.Units.EnableTooltip(button)
```

- [ ] **Step 4: Run the tests**

Run: `tests/run raid_cell_negative` → `42 passed, 0 failed`
Run: `tests/run` → Expected: `20195 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Raid/Cell.lua tests/test_raid_cell_negative.lua
git commit -m "Raid cell: pin down what cells never get

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## After the last task

- `./install "<AddOns folder of _classic_beta_>"`, then a **full restart of the game client** (R3b adds `Media/MasterLooter.tga`; `/reload` does not load new texture files). No Lua error at login. UI only: no moving, casting or fighting.
- Test mode, 10-player profile: member 1 (the warrior) shows the tank icon at the left, a skull at the right, the crown at the top left, the gold coin at the top right and a ready mark in the centre, and the red aggro line; member 2 the healer icon, the assistant icon, a ready mark and the light target line; members 4 and 5 not ready / waiting; member 4 faded; member 6 a star; members 3 (dead) and 7 (offline) grey. Look at the coin at 12 and 14 px. Then `sizeMode = "40"` (`/run ForeverUnitFramesDB.raid["<Name>-<Realm>"].general.sizeMode = "40"`, `/reload`): every icon readable at 80 x 38, nothing overlapping the name; with R3a's test-mode settings on as well, watch the frame rate (performance at 40, spec §9).
- In a real group or raid when available: role icons after roles are assigned; leader and assistant icons; with master loot set the coin on the looter (in a 5-player group with the raid view in party this checks the party index convention: 0 = you); a ready check started by the leader; range fading of members far away; the light line when you target a member.
- **Aggro (spec §9):** in a raid when a mob attacks a member (no fighting by us): does the red line show? It is fed a secret threat status through `StatusBar:SetValue`; if it never shows, note it for R4 (drop `aggroBorder`, the wiki says why).
- No release yet: R4 (options window, locales, wiki) follows; 0.22.0 after the in-game check of the whole part 1.
