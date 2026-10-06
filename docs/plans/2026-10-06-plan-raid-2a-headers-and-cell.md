# Forever Unit Frames — Raid plan R2a: headers, layout and cell

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raid frames that work in a raid: one secure group header per block (raid groups of the active size, classes, roles, or one block), blocks laid out from the raid profile of the active size (direction, wrap, cell growth, spacing, titles, empty blocks), a gold border around the panel and optional borders around blocks and cells, a movable panel with one position per size, and a cell that runs the unit-frame elements with the name and missing health centred in the health bar and a thin power strip — built at login, relaid out of combat only, unit frames unchanged.

**Architecture:** `Raid/Settings.lua` gets the layout and cell settings per size. `Raid/Layout.lua` is pure numbers: blocks and their header filters, header attributes, cell, block and panel positions. `Raid/Cell.lua` + `Raid/Cell.xml`: the cell is a unit button made by a `SecureGroupHeaderTemplate` from an XML template (no `initialConfigFunction`), running `ns.Elements` under a derived unit-frame scope `raid` (`Config.Derive("raid", "party", Cell.Resolve)`): everything a cell never shows switched off, its look taken from the raid profile of the active size. Four elements gain hooks switched by frame fields no unit frame sets (`centerTexts`, `sample`, `showsPower`, `auraGroupKeys`). `Core/Movers.lua` learns specs with their own config, a changing scope and a top-left origin. `Raid/Header.lua` builds the anchor (mover target), the headers anchored to it, and a plain panel with titles and borders (`Core/Border.lua` through derived scopes `raidpanel` / `raidblock`). `Core/Boot.lua` builds it after the raid profile is attached.

**Tech Stack:** Lua 5.1, WoW: Forever API (Interface 16001, build 1.60.1.70205), offline tests with `lua5.1` + `tests/mock.lua` (`tests/run`).

Spec: `docs/specs/2026-10-06-raid-frames-design.md` (part 1; §4 panel, grouping and layout, §5 the cell). Raid plan order: R1 Foundation (done) → **R2a Headers, layout and cell (this plan)** → R2b Raid view in party, Blizzard's raid frames, test mode (`docs/plans/2026-10-06-plan-raid-2b-party-blizzard-testmode.md`) → R3 Indicators, icons and states → R4 Options window, locales, wiki, release.

Base: `main` at `f63fb5c` ("Raid spec: storage as a live profile table per character"); `tests/run` there: `18766 passed, 0 failed`. Every task below was replayed in order on a scratch worktree of that commit; the totals under "Expected" are what `tests/run` printed there. A full `tests/run` takes about a minute and several GB of memory (as before this plan).

## Global Constraints

- Everything in English: file names, identifiers, comments. This plan adds no user-facing string: block titles and the mover label are Blizzard's own (`GROUP_NUMBER`, `LOCALIZED_CLASS_NAMES_MALE`, `TANK` / `HEALER` / `DAMAGER`, `RAID`), with the token as the fallback; a cell's "AFK" is the literal the AFK badge already shows.
- Target client: WoW: Forever, `## Interface: 16001`. Client facts only from the Forever UI source (game type `camelot`, family `mainline`); the ones used are in the table below. Never write the name of the local lookup tool into the repository.
- The unit frames must not notice: no unit-frame setting is added, no existing key, code, scope letter or default changes, no existing test is edited, and `tests/run` stays green after every task. The element hooks are switched by frame fields no unit frame sets (`frame.centerTexts`, `frame.sample`, `frame.showsPower`, `frame.auraGroupKeys`); the new mover-spec fields default to today's behaviour.
- Raid setting codes are permanent once released and unique within the raid registry. This plan adds (all per size, scopes `r10`/`r20`/`r40`): `groupBy` GB, `sortBy` SO, `blockDirection` BD, `blocksPerLine` BL, `cellGrowth` CG, `cellsPerLine` CL, `cellWidth` CW, `cellHeight` CH, `cellSpacing` CS, `blockSpacing` BS, `blockTitles` BT, `hideEmpty` HE, `panelBorder` PB, `blockBorder` BB, `cellBorder` CB, `healthColorMode` HM, `powerStrip` PS, `secondLine` SL, `nameClassColor` NC. Enums are stored by index: append only.
- Derived unit-frame scopes (no profile, no options page, nothing stored): `raid` (cells), `raidpanel`, `raidblock` (rings).
- No secret-value maths: health goes through the elements as before; class tokens and assigned roles are read with `pcall` and `ns.Secrets.IsSecret`, an unreadable one counts as unknown.
- No secure snippets (`initialConfigFunction`, `refreshUnitChange`), no `hooksecurefunc` on mixins. Header attributes, `SetPoint` / `SetSize` / `Show` / `Hide` on headers, cells and the anchor run out of combat only, through `ns.AfterCombat` (keys `raidCreate`, `raidLayout`, `raidPlace`). In combat only plain frames change (the panel, block titles and borders).
- `ns.On` throws on an unknown event name: the only new game events are `GROUP_ROSTER_UPDATE` and `PLAYER_ROLES_ASSIGNED` (verified below). New internal event: `RAID_CELLS_CHANGED`.
- The mock stays faithful: the group header is ported from the client's `SecureGroupHeaders.lua`; it may be stricter (snippets and `nameList` raise), never more permissive.
- Public repository: no local paths, host names, character names or anything about the author's machine in files or commit messages. Test names are neutral.
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
- Do not push. Every task ends with `tests/run` green and one commit (`git add` only the files the task lists).

## Client facts this plan relies on (build 1.60.1.70205)

Paths below `Interface/AddOns/`; `Doc/` = `Blizzard_APIDocumentationGenerated/`; `SGH` = `Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua`.

| Fact | Source |
|---|---|
| A group header shows a raid with `showRaid`, else a party with `showParty` (player first with `showPlayer`), else `showSolo` (`GetGroupHeaderType`); members without a name are skipped | `SGH` |
| Filters: `groupFilter` (group numbers, class tokens), `roleFilter` (roles), `strictFiltering`: group only → group and class must match (roles all added); group and role → group, class and role must match; non-strict → any match. Assigned role `NONE` for nobody assigned | `SGH` (`SecureGroupHeader_Update`) |
| `groupBy` (GROUP, CLASS, ROLE, ASSIGNEDROLE) with `groupingOrder`; `sortMethod` INDEX (raid index) or NAME; `sortDir`; `startingIndex` | `SGH` |
| Layout: first child on `point` of the header (and on `columnAnchorPoint` when there is more than one column); next child `point` to the previous one's opposite point, offsets `xOffset` / `yOffset` times the point's axis; a new column every `unitsPerColumn` children, at most `maxColumns`, `columnSpacing` apart on `columnAnchorPoint`; the header sizes itself from child 1, an empty one to `minWidth` / `minHeight` or a button's width or height | `SGH` (`configureChildren`) |
| Updates: `GROUP_ROSTER_UPDATE` / `UNIT_NAME_UPDATE` while visible, every attribute change unless `_ignore` is set, on show; children are made with `CreateFrame(templateType, name.."UnitButton"..i, header, template)` and their `unit` attribute set by the header, in combat too | `SGH` |
| `GetRaidRosterInfo(i)`: the header reads name (1), subgroup (3), class token (6), role MAINTANK/MAINASSIST (10), assigned role (12) | `SGH` (`GetGroupRosterInfo`) |
| `UnitGroupRolesAssigned(unit) -> cstring` and `UnitClass` are `SecretWhenUnitIdentityRestricted`; `UnitPowerType` is not | `Doc/UnitDocumentation.lua` |
| Event `PLAYER_ROLES_ASSIGNED()` | `Doc/PartyInfoDocumentation.lua` |
| This client is game type `camelot`: `CLASS_SORT_ORDER` = WARRIOR, PALADIN, PRIEST, SHAMAN, DRUID, ROGUE, MAGE, WARLOCK, HUNTER | `Blizzard_FrameXMLBase/Blizzard_FrameXMLBase.toc`, `Blizzard_FrameXMLBase/Camelot/Constants.lua` |
| `LOCALIZED_CLASS_NAMES_MALE = LocalizedClassList(false)`; `LocalizedClassList` is documented | `Blizzard_FrameXMLBase/Constants.lua`, `Doc/LocalizationDocumentation.lua` |
| `GROUP_NUMBER` is a format taking the group number; `RAID` is a text; role names are read as `_G[role]`. The strings themselves are not in the source snapshot: the code falls back to the token | `Blizzard_UnitFrame/Shared/CompactRaidGroup.lua`, `Blizzard_FriendsFrame/Camelot/FriendsFrame.lua`, `Blizzard_GroupFinder/Shared/LFGFrame.lua` |

## Design decisions

- **Cell = unit button on the element pipeline** (decided): `Config.Derive("raid", "party", Cell.Resolve)`. `FIXED` turns off what a cell never shows (title row, portrait, castbar, buffs, debuffs, combat feedback, threat glow, raid marker, class icon, overheal lane, heals past the edge, shadow, power texts; rows 90/10, fonts 11/10); `MAPPED` takes width, height, health colour mode, power strip on/off, second line tag, name colour and cell border from the raid profile of the active size (`RaidSize.Current()`, 10 until known). Elements whose settings are limited by `only` (castbar, group icons, dispel, range, target highlight, totems, combo points, …) do not apply to scope `raid` and build nothing.
- **No new unit-frame keys** (deviation from the brief's suggestion): `tests/test_settings.lua` and `tests/test_locale.lua` require a label in four languages for every unit-frame setting, so a key with `only = {}` would add eight invisible strings and permanent codes. The cell's two centred lines are switched by `frame.centerTexts` instead (`Elements/Texts.lua`): the existing `textHealthLeft` (NAME) and `textHealthRight` (the second line's tag of the same name) are re-anchored to the bar's middle; the status word (Dead, Ghost, Offline) and, for cells only, AFK take the second line.
- **Widget cost:** a cell builds every element. The one clearly avoidable cost is cut: `frame.auraGroupKeys = {}` keeps `Elements/AuraContainers.lua` from making a cell's four aura containers (two groups of ten buttons each). What remains is about 190 widgets per cell in the mock (rings 72, soft-outline copies 24, the unused threat-glow holders 24), about 7,600 at 40; skipping elements per frame would touch the loops every unit frame runs through, so it is left for the in-game performance check.
- **Power strip per unit:** `frame.showsPower(frame)` (`Elements/Power.lua`) hides the bar like "hide without power" does: MANA by class (`Cell.MANA_CLASSES`), HEALERS by assigned role, ALL everyone; OFF switches `powerEnabled` off. An unreadable class or role keeps the strip. `PLAYER_ROLES_ASSIGNED` updates it.
- **Blocks:** every block keeps to the groups of the size (10 → 1–2, 20 → 1–4, 40 → 1–8), not only GROUP: CLASS is `groupFilter = "<groups>,<CLASS>"` strict; ROLE is `groupFilter = "<groups>,<every class>"`, `roleFilter` (DAMAGER takes NONE too) strict; NONE is the groups with `groupBy = GROUP`. `cellsPerLine` applies to every block (a class or role block can hold many), not only to NONE.
- **Placing blocks** needs the number of cells per block, which only the roster knows: cells report unit changes (`RAID_CELLS_CHANGED`), the panel counts each header's cells a moment later (`C_Timer.After(0)`) and places the blocks out of combat. A GROUP block always keeps room for five, so a member joining in combat never overlaps the next block; other blocks hold who is there. Hidden empty blocks take no room; their (empty, shown) headers wait below the panel, so a member joining in combat appears there, not on top of a block. In combat a growing block may overlap until the layout after combat.
- **Three frames, nothing protected moves in combat:** the anchor (plain, mover target, headers hang from it), the headers (children of UIParent), the panel (plain, borders and titles, shown and hidden in combat as the group changes).
- **Borders** are `Core/Border.lua`'s ring in derived scopes: panel GOLD 3 px, padding 3; block GOLD 2 px, padding 1; both square without shadow. A cell's border is its own unit-frame border (`borderShow` ← `cellBorder`). Block and cell borders widen the gaps by their reach (as the party pets do).
- **Position:** the raid profile's `x` / `y` are the panel's top-left corner (R1). The mover holds that corner (`origin = "TOPLEFT"`) of the active size's scope in the raid config.
- **Visibility:** headers are shown whenever the raid frames are on (`showParty` follows `showInParty`); the panel shows in a raid, or in a party with the raid view in party on. Raid view in party, Blizzard's raid frames and test mode are R2b.

---
### Task 1: Raid layout and cell settings

**Files:**
- Modify: `Raid/Settings.lua` (`Raid.Scope` guard; definitions appended at the end)
- Test: `tests/test_raid_layout_settings.lua`

**Interfaces:**
- Consumes: `ns.RaidSettings`, `ns.RaidConfig`, `ns.RaidProfiles` (R1).
- Produces: the raid settings listed in the Global Constraints (scope `frame`, i.e. per size); `Raid.Scope(size)` raises for anything but 10, 20, 40.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_layout_settings.lua`:

```lua
-- Raid layout and cell settings (Raid/Settings.lua): one value per raid
-- size, permanent codes, enums stored by index, defaults that give a
-- compact 10/20/40 layout. Raid.Scope knows the three sizes only.
local ns = H.LoadAddon()
local Raid, RS, RC = ns.Raid, ns.RaidSettings, ns.RaidConfig

local CODES = {
    groupBy = "GB", sortBy = "SO", blockDirection = "BD", blocksPerLine = "BL", cellGrowth = "CG",
    cellsPerLine = "CL", cellWidth = "CW", cellHeight = "CH", cellSpacing = "CS", blockSpacing = "BS",
    blockTitles = "BT", hideEmpty = "HE", panelBorder = "PB", blockBorder = "BB", cellBorder = "CB",
    healthColorMode = "HM", powerStrip = "PS", secondLine = "SL", nameClassColor = "NC",
}
for key, code in pairs(CODES) do
    local def = RS.Get(key)
    H.checkTrue(key .. " defined", def)
    if def then
        H.check(key .. " code", def.code, code)
        H.check(key .. " per size", RS.AppliesTo(def, "r40"), true)
        H.check(key .. " not character-wide", RS.AppliesTo(def, "general"), false)
    end
end

local function values(key) return table.concat(RS.Get(key).values, ",") end
H.check("grouping values", values("groupBy"), "GROUP,CLASS,ROLE,NONE")
H.check("sort values", values("sortBy"), "INDEX,NAME")
H.check("direction values", values("blockDirection"), "HORIZONTAL,VERTICAL")
H.check("growth values", values("cellGrowth"), "DOWN,RIGHT")
H.check("health colour values", values("healthColorMode"), "CLASS,STATIC,GRADIENT")
H.check("power strip values", values("powerStrip"), "ALL,MANA,HEALERS,OFF")
H.check("second line values", values("secondLine"), "DEFICIT,PERCENT,CURRENT,NONE")

RC.Use({})
local DEFAULTS = {
    groupBy = "GROUP", sortBy = "INDEX", blockDirection = "HORIZONTAL", blocksPerLine = 8, cellGrowth = "DOWN",
    cellsPerLine = 5, cellSpacing = 2, blockSpacing = 6, blockTitles = false, hideEmpty = true,
    panelBorder = true, blockBorder = false, cellBorder = false, healthColorMode = "CLASS",
    powerStrip = "MANA", secondLine = "DEFICIT", nameClassColor = false,
}
for key, want in pairs(DEFAULTS) do
    H.check(key .. " default", RC.Get("r20", key), want)
end
-- Cells: 80 x 38 at 40, a bit larger at 20 and 10.
H.check("cell width 10", RC.Get("r10", "cellWidth"), 96)
H.check("cell height 10", RC.Get("r10", "cellHeight"), 44)
H.check("cell width 20", RC.Get("r20", "cellWidth"), 88)
H.check("cell height 20", RC.Get("r20", "cellHeight"), 40)
H.check("cell width 40", RC.Get("r40", "cellWidth"), 80)
H.check("cell height 40", RC.Get("r40", "cellHeight"), 38)
H.check("cell width clamped", RS.Validate(RS.Get("cellWidth"), 5), 30)
H.check("blocks per line at most the class count", RS.Get("blocksPerLine").max, 9)

-- Codes are unique within the raid registry and none of R1's changed.
local seen = {}
for _, def in ipairs(RS.All()) do
    H.check("unique code " .. def.code, seen[def.code], nil)
    seen[def.code] = true
end
H.check("R1 codes kept", RS.Get("sizeMode").code .. RS.Get("x").code .. RS.Get("y").code, "SMXY")

-- A size exports with its layout; enums by index.
RC.Set("r10", "groupBy", "ROLE")
RC.Set("r10", "cellWidth", 120)
H.check("export", ns.RaidProfiles.Export(10), "1;aCW120;aGB3")

-- Raid.Scope: the three sizes, nothing else.
H.check("scope 40", Raid.Scope(40), "r40")
H.checkError("scope of an unknown size", function() Raid.Scope(25) end)
H.checkError("scope of nil", function() Raid.Scope(nil) end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run raid_layout_settings`
Expected: 19 lines `FAIL <key> defined -> false (want true)`, then `ERROR test_raid_layout_settings.lua:23: attempt to index a nil value`, `0 passed, 20 failed`

- [ ] **Step 3: Guard `Raid.Scope` and add the definitions**

In `Raid/Settings.lua`:

Replace

```lua
ns.Raid = Raid

Raid.SIZES = { 10, 20, 40 }

-- The scope that holds the profile of a raid size.
function Raid.Scope(size) return "r" .. size end

local RaidSettings = ns.NewRegistry(
    { "general", "r10", "r20", "r40" },
```

with

```lua
ns.Raid = Raid

Raid.SIZES = { 10, 20, 40 }
local IS_SIZE = { [10] = true, [20] = true, [40] = true }

-- The scope that holds the profile of a raid size; anything but 10, 20
-- or 40 is a mistake in the caller.
function Raid.Scope(size)
    assert(IS_SIZE[size], "unknown raid size " .. tostring(size))
    return "r" .. size
end

local RaidSettings = ns.NewRegistry(
    { "general", "r10", "r20", "r40" },
```

Replace

```lua
-- Position of the panel's top left corner, relative to the screen centre.
RaidSettings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000, default = -600 })
RaidSettings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000, default = 150 })
```

with

```lua
-- Position of the panel's top left corner, relative to the screen centre.
RaidSettings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000, default = -600 })
RaidSettings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000, default = 150 })

-- Layout (Raid/Layout.lua). The panel is made of blocks, one group header
-- each: raid groups (only those of the size), classes, roles, or a single
-- block for everyone. Stored by index: append only.
RaidSettings.Define({ key = "groupBy", code = "GB", scope = "frame", type = "enum",
    values = { "GROUP", "CLASS", "ROLE", "NONE" }, default = "GROUP" })
-- Order within a block: raid order or name.
RaidSettings.Define({ key = "sortBy", code = "SO", scope = "frame", type = "enum",
    values = { "INDEX", "NAME" }, default = "INDEX" })
-- Blocks side by side (a row of blocks) or stacked (a column), wrapping
-- after blocksPerLine.
RaidSettings.Define({ key = "blockDirection", code = "BD", scope = "frame", type = "enum",
    values = { "HORIZONTAL", "VERTICAL" }, default = "HORIZONTAL" })
RaidSettings.Define({ key = "blocksPerLine", code = "BL", scope = "frame", type = "int", min = 1, max = 9,
    default = 8 })
-- Cells within a block: a column growing down, or a row growing right,
-- with a new column (row) after cellsPerLine cells.
RaidSettings.Define({ key = "cellGrowth", code = "CG", scope = "frame", type = "enum",
    values = { "DOWN", "RIGHT" }, default = "DOWN" })
RaidSettings.Define({ key = "cellsPerLine", code = "CL", scope = "frame", type = "int", min = 1, max = 40,
    default = 5 })
RaidSettings.Define({ key = "cellWidth", code = "CW", scope = "frame", type = "int", min = 30, max = 200,
    default = { r10 = 96, r20 = 88, _ = 80 } })
RaidSettings.Define({ key = "cellHeight", code = "CH", scope = "frame", type = "int", min = 16, max = 100,
    default = { r10 = 44, r20 = 40, _ = 38 } })
-- Room between two cells, and between two blocks (border to border).
RaidSettings.Define({ key = "cellSpacing", code = "CS", scope = "frame", type = "int", min = 0, max = 20, default = 2 })
RaidSettings.Define({ key = "blockSpacing", code = "BS", scope = "frame", type = "int", min = 0, max = 40,
    default = 6 })
-- A title row above each block (group number, class, role).
RaidSettings.Define({ key = "blockTitles", code = "BT", scope = "frame", type = "bool", default = false })
-- Blocks without members take no room.
RaidSettings.Define({ key = "hideEmpty", code = "HE", scope = "frame", type = "bool", default = true })
-- Borders: around the panel (gold), around each block, around each cell.
RaidSettings.Define({ key = "panelBorder", code = "PB", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "blockBorder", code = "BB", scope = "frame", type = "bool", default = false })
RaidSettings.Define({ key = "cellBorder", code = "CB", scope = "frame", type = "bool", default = false })

-- The cell (Raid/Cell.lua). Health in the class colour, the unit-frame
-- health colour, or a gradient by health. Stored by index: append only.
RaidSettings.Define({ key = "healthColorMode", code = "HM", scope = "frame", type = "enum",
    values = { "CLASS", "STATIC", "GRADIENT" }, default = "CLASS" })
-- The power strip at the bottom: everyone, mana users, healers, nobody.
RaidSettings.Define({ key = "powerStrip", code = "PS", scope = "frame", type = "enum",
    values = { "ALL", "MANA", "HEALERS", "OFF" }, default = "MANA" })
-- The line under the name: missing health, percent, current health, none.
-- Dead, ghost, offline and AFK replace it.
RaidSettings.Define({ key = "secondLine", code = "SL", scope = "frame", type = "enum",
    values = { "DEFICIT", "PERCENT", "CURRENT", "NONE" }, default = "DEFICIT" })
RaidSettings.Define({ key = "nameClassColor", code = "NC", scope = "frame", type = "bool", default = false })
```

- [ ] **Step 4: Run the tests**

Run: `tests/run raid_layout_settings` → `138 passed, 0 failed`
Run: `tests/run` → Expected: `18904 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Raid/Settings.lua tests/test_raid_layout_settings.lua
git commit -m "Raid layout and cell settings per size

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Mock: the group header ported from the client, a raid roster

**Files:**
- Modify: `tests/mock.lua` (the group header section; `IsInGroup`; raid roster stand-ins; `M.SetRaidRoster`)
- Test: `tests/test_raid_header_mock.lua`

**Interfaces:**
- Produces (mock): `SecureGroupHeaderTemplate` as `SecureGroupHeader_Update` / `configureChildren` (filters, grouping, sorting, columns, size); `GetRaidRosterInfo(i)` with the client's twelve values; `GetPartyAssignment(assignment, unit)` (`d.assignment`); `CLASS_SORT_ORDER` (camelot); `M.raid`; `M.SetRaidRoster(members)` (`members[i] = { name, class, subgroup, assignedRole, role, unit = {…} }`, unit `raid<i>`, `{}` leaves the raid, fires `GROUP_ROSTER_UPDATE`); `IsInGroup()` true in a raid. Stricter than the client: `initialConfigFunction`, `refreshUnitChange` and `nameList` raise.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_header_mock.lua`:

```lua
-- The mock's group header against the client's SecureGroupHeaders.lua:
-- raid filters, grouping, sorting, columns and the header's own size, as
-- the raid blocks (Raid/Header.lua) use them.
local M = H.M
H.LoadAddon()

local function header(attributes)
    local h = CreateFrame("Frame", "TestRaidHeader" .. #M.frames, UIParent, "SecureGroupHeaderTemplate")
    h:SetAttribute("_ignore", "attributeChanges")
    h:SetAttribute("template", "SecureUnitButtonTemplate")
    for name, value in pairs(attributes) do h:SetAttribute(name, value) end
    h:SetAttribute("_ignore", nil)
    h:Show()
    return h
end

local function units(h)
    local list, i = {}, 1
    while h:GetAttribute("child" .. i) do
        local unit = h:GetAttribute("child" .. i):GetAttribute("unit")
        if unit then list[#list + 1] = unit end
        i = i + 1
    end
    return table.concat(list, ",")
end

M.SetRaidRoster({
    { name = "Tank", class = "WARRIOR", subgroup = 1, assignedRole = "TANK", role = "MAINTANK" },
    { name = "Mage", class = "MAGE", subgroup = 2, assignedRole = "DAMAGER" },
    { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "HEALER" },
    { name = "Zed", class = "WARRIOR", subgroup = 3, assignedRole = "DAMAGER" },
    { name = "Bob", class = "ROGUE", subgroup = 2 },
})
H.check("roster: raid members", GetNumGroupMembers(), 5)
H.check("roster: raid unit data", UnitName("raid4"), "Zed")
local name, _, subgroup, _, _, class, _, _, _, role, _, assigned = GetRaidRosterInfo(1)
H.check("roster info: name", name, "Tank")
H.check("roster info: subgroup", subgroup, 1)
H.check("roster info: class token", class, "WARRIOR")
H.check("roster info: role", role, "MAINTANK")
H.check("roster info: assigned role", assigned, "TANK")
H.check("roster info: unassigned is NONE", select(12, GetRaidRosterInfo(5)), "NONE")
H.checkTrue("a raid is a group", IsInGroup())

-- Not shown in a raid without showRaid.
H.check("no showRaid: nobody", units(header({})), "")
-- Groups.
H.check("group 1", units(header({ showRaid = true, groupFilter = "1" })), "raid1,raid3")
H.check("groups 2,3", units(header({ showRaid = true, groupFilter = "2,3" })), "raid2,raid4,raid5")
-- A class, limited to groups (strict: group and class must both match).
H.check("class, strict", units(header({ showRaid = true, groupFilter = "1,2,WARRIOR", strictFiltering = true })),
    "raid1")
H.check("class, loose matches group or class",
    units(header({ showRaid = true, groupFilter = "2,WARRIOR" })), "raid1,raid2,raid4,raid5")
-- A role among the groups and every class (strict).
local all = "1,2,3,4,5,6,7,8," .. table.concat(CLASS_SORT_ORDER, ",")
H.check("role, strict", units(header({ showRaid = true, groupFilter = all, roleFilter = "DAMAGER,NONE",
    strictFiltering = true })), "raid2,raid4,raid5")
H.check("role, strict, groups limit", units(header({ showRaid = true, groupFilter = "1,2," .. table.concat(CLASS_SORT_ORDER, ","),
    roleFilter = "DAMAGER,NONE", strictFiltering = true })), "raid2,raid5")
-- Sorting: by name; grouped by raid group, then index.
H.check("by name", units(header({ showRaid = true, sortMethod = "NAME" })), "raid3,raid5,raid2,raid1,raid4")
H.check("grouped by group", units(header({ showRaid = true, groupBy = "GROUP", groupingOrder = "1,2,3,4,5,6,7,8" })),
    "raid1,raid3,raid2,raid5,raid4")

-- Columns: 5 units, 2 per column, columns to the right.
local h = header({ showRaid = true, point = "TOP", yOffset = -2, unitsPerColumn = 2, maxColumns = 3,
    columnSpacing = 4, columnAnchorPoint = "LEFT" })
local c1, c2, c3 = h:GetAttribute("child1"), h:GetAttribute("child2"), h:GetAttribute("child3")
for i = 1, 5 do h:GetAttribute("child" .. i):SetSize(80, 38) end
h:Hide()
h:Show()
local p, rel, relPoint, x, y = c2:GetPoint(1)
H.checkTrue("column: second below the first", p == "TOP" and rel == c1 and relPoint == "BOTTOM" and x == 0 and y == -2)
p, rel, relPoint, x, y = c3:GetPoint(1)
H.checkTrue("column: third starts a new column", p == "LEFT" and rel == c1 and relPoint == "RIGHT" and x == 4 and y == 0)
H.check("column: first on the header's top", select(3, c1:GetPoint(1)), "TOP")
H.check("column: first on the header's left too", select(3, c1:GetPoint(2)), "LEFT")
H.check("header width: 3 columns", h:GetWidth(), 3 * 80 + 2 * 4)
H.check("header height: 2 rows", h:GetHeight(), 2 * 38 + 2)
-- maxColumns caps what is shown.
h:SetAttribute("maxColumns", 2)
H.check("max columns: 4 shown", units(h), "raid1,raid2,raid3,raid4")
-- Rows growing right.
local r = header({ showRaid = true, point = "LEFT", xOffset = 3, unitsPerColumn = 3, maxColumns = 2,
    columnSpacing = 5, columnAnchorPoint = "TOP" })
for i = 1, 5 do r:GetAttribute("child" .. i):SetSize(80, 38) end
r:Hide()
r:Show()
p, rel, relPoint, x, y = r:GetAttribute("child4"):GetPoint(1)
H.checkTrue("row: fourth starts a new row below", p == "TOP" and rel == r:GetAttribute("child1")
    and relPoint == "BOTTOM" and x == 0 and y == -5)
H.check("row header width", r:GetWidth(), 3 * 80 + 2 * 3)
H.check("row header height", r:GetHeight(), 2 * 38 + 5)

-- An empty header keeps one button and a sliver of size.
local e = header({ showRaid = true, groupFilter = "8", minWidth = 0.1, minHeight = 0.1 })
H.checkTrue("empty: one button made", e:GetAttribute("child1"))
H.check("empty: button hidden", e:GetAttribute("child1"):IsShown(), false)
H.check("empty: width", e:GetWidth(), 0.1)

-- A party with showParty: the player first (slot 1), then the members.
M.SetRaidRoster({})
H.check("left the raid", IsInRaid(), false)
M.units.player = { name = "Me", class = "MAGE", isPlayer = true }
M.units.party1 = { name = "Ann", class = "PRIEST", isPlayer = true, role = "HEALER" }
M.SetGroup({ "party1" })
local party = header({ showRaid = true, showParty = true, showPlayer = true, groupFilter = "1,MAGE",
    strictFiltering = true })
H.check("party: by class, strict", units(party), "player")
H.check("party: no showParty, nobody", units(header({ showRaid = true })), "")

-- Snippets are refused: they do not run on this client.
local s = CreateFrame("Frame", "TestSnippetHeader", UIParent, "SecureGroupHeaderTemplate")
s:SetAttribute("initialConfigFunction", "self:SetWidth(10)")
H.checkError("snippet", function() s:Show() end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run raid_header_mock`
Expected: `ERROR test_raid_header_mock.lua:27: attempt to call field 'SetRaidRoster' (a nil value)`, `0 passed, 1 failed`

- [ ] **Step 3: Port the group header**

In `tests/mock.lua`, replace everything from the line

```lua
-- SecureGroupHeaderTemplate, reduced to what the addon relies on: party
```

up to, not including, the line

```lua
-- Blizzard_AuraContainer's CustomAuraContainerTemplate: the inbound calls
```

(the old reduced header: its comment, `OPPOSITE`, `MULTIPLIER`, `groupHeaderLayout`, `groupHeaderUpdate`, `makeGroupHeader`) with

```lua
-- SecureGroupHeaderTemplate and SecureGroupPetHeaderTemplate
-- (Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua), ported
-- from the client source: which units a header shows (GetGroupHeaderType:
-- a raid with showRaid, a party with showParty, else showSolo; showPlayer),
-- the filters groupFilter, roleFilter and strictFiltering, groupBy with
-- groupingOrder, sortMethod INDEX or NAME, sortDir, startingIndex, the
-- columns (unitsPerColumn, maxColumns, columnSpacing, columnAnchorPoint),
-- child creation from the template attribute, unit assignment through
-- SetAttribute("unit"), the header's own size, and updates on show,
-- attribute change and roster change while visible. Party members are
-- M.group's tokens in order; raid members M.raid (M.SetRaidRoster), read
-- through GetRaidRosterInfo as the client does. The pet header lists the
-- pets of the units the party rule picks, packed.
-- Stricter than the client: an initialConfigFunction or refreshUnitChange
-- snippet raises (snippets do not run on this client), and so does a
-- nameList (not modelled).
-- Like the client, shown buttons are only SetPoint'ed (never cleared): a
-- button keeps an anchor from an earlier layout on another point. Only
-- unused buttons lose their anchors. The header sizes itself from child1
-- as it is at layout time.
local function relativePoint(point)
    point = point:upper()
    if point == "TOP" then return "BOTTOM", 0, -1 end
    if point == "BOTTOM" then return "TOP", 0, 1 end
    if point == "LEFT" then return "RIGHT", 1, 0 end
    if point == "RIGHT" then return "LEFT", -1, 0 end
    if point == "TOPLEFT" then return "BOTTOMRIGHT", 1, -1 end
    if point == "TOPRIGHT" then return "BOTTOMLEFT", -1, -1 end
    if point == "BOTTOMLEFT" then return "TOPRIGHT", 1, 1 end
    if point == "BOTTOMRIGHT" then return "TOPLEFT", -1, 1 end
    return "CENTER", 0, 0
end

local function headerKind(a)
    if IsInRaid() and a.showRaid then return "RAID", 1, GetNumGroupMembers() end
    if IsInGroup() and a.showParty then return "PARTY", a.showPlayer and 1 or 2, #M.group + 1 end
    if a.showSolo then return "SOLO", 1, #M.group + 1 end
end

-- unit, name, subgroup, class token, role (MAINTANK, MAINASSIST), assigned
-- role, as GetGroupRosterInfo. Party slot 1 is the player (the client's
-- index 0), slot n + 1 is M.group[n].
local function rosterInfo(kind, slot)
    if kind == "RAID" then
        local name, _, subgroup, _, _, className, _, _, _, role, _, assignedRole = GetRaidRosterInfo(slot)
        return "raid" .. slot, name, subgroup, className, role, assignedRole
    end
    local unit = slot > 1 and M.group[slot - 1] or "player"
    local name, className, role, assignedRole
    -- The player always exists in the client, also in a test that gave
    -- it no unit data.
    if unit == "player" and not UnitExists(unit) then return unit, "player", 1, nil, nil, "NONE" end
    if UnitExists(unit) then
        name = UnitName(unit)
        className = select(2, UnitClass(unit))
        if GetPartyAssignment("MAINTANK", unit) then
            role = "MAINTANK"
        elseif GetPartyAssignment("MAINASSIST", unit) then
            role = "MAINASSIST"
        end
        assignedRole = UnitGroupRolesAssigned(unit)
    end
    return unit, name, 1, className, role, assignedRole
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function split(s)
    local parts = {}
    for part in (s .. ","):gmatch("([^,]*),") do parts[#parts + 1] = part end
    return parts
end
-- fillTable: each key (a number when it reads as one) -> its position.
local function fill(t, keys)
    for i, key in ipairs(keys) do t[tonumber(key) or trim(tostring(key))] = i end
    return t
end

local function sortedUnits(header)
    local a = header._attr
    assert(not a.nameList, "mock: nameList is not modelled")
    local kind, start, stop = headerKind(a)
    local units = {}
    if not kind then return units end
    if header._pets then
        -- SecureGroupPetHeaderTemplate: the owners' pets that exist, packed.
        for slot = start, stop do
            local unit = rosterInfo(kind, slot)
            local pet = unit == "player" and "pet" or unit:gsub("^party", "partypet"):gsub("^raid", "raidpet")
            if M.units[pet] then units[#units + 1] = pet end
        end
        return units
    end
    local groupFilter, roleFilter = a.groupFilter, a.roleFilter
    if not groupFilter and not roleFilter then groupFilter = "1,2,3,4,5,6,7,8" end
    local strict = a.strictFiltering
    local tokens = {}
    if groupFilter and not roleFilter then
        fill(tokens, split(groupFilter))
        if strict then fill(tokens, { "MAINTANK", "MAINASSIST", "TANK", "HEALER", "DAMAGER", "NONE" }) end
    elseif roleFilter and not groupFilter then
        fill(tokens, split(roleFilter))
        if strict then
            local keys = { 1, 2, 3, 4, 5, 6, 7, 8 }
            for _, class in ipairs(CLASS_SORT_ORDER) do keys[#keys + 1] = class end
            fill(tokens, keys)
        end
    else
        fill(tokens, split(groupFilter))
        fill(tokens, split(roleFilter))
    end
    local names, grouping, order = {}, {}, {}
    for slot = start, stop do
        local unit, name, subgroup, className, role, assignedRole = rosterInfo(kind, slot)
        local loose = not strict and (tokens[subgroup] or tokens[className] or (role and tokens[role])
            or tokens[assignedRole])
        local tight = tokens[subgroup] and tokens[className] and ((role and tokens[role]) or tokens[assignedRole])
        if name and (loose or tight) then
            units[#units + 1] = unit
            names[unit] = name
            order[unit] = slot
            if a.groupBy == "GROUP" then grouping[unit] = subgroup
            elseif a.groupBy == "CLASS" then grouping[unit] = className
            elseif a.groupBy == "ROLE" then grouping[unit] = role
            elseif a.groupBy == "ASSIGNEDROLE" then grouping[unit] = assignedRole end
        end
    end
    -- The client's IDs: the number in the token ("player" is -1).
    local function id(unit) return tonumber(unit:match("%d+") or -1) end
    local function within(x, y)
        if a.sortMethod == "NAME" then return names[x] < names[y] end
        return id(x) < id(y)
    end
    if a.groupBy then
        local rank = fill({}, split((a.groupingOrder or ""):gsub("%s+", "")))
        table.sort(units, function(x, y)
            local o1, o2 = rank[grouping[x]], rank[grouping[y]]
            if o1 and o2 and o1 ~= o2 then return o1 < o2 end
            if o1 and not o2 then return true end
            if o2 and not o1 then return false end
            return within(x, y)
        end)
    elseif a.sortMethod == "NAME" then
        table.sort(units, function(x, y) return names[x] < names[y] end)
    end
    return units
end

-- configureChildren.
local function groupHeaderLayout(header)
    local a = header._attr
    assert(not a.initialConfigFunction, "mock: secure snippets do not run on this client")
    local units = sortedUnits(header)
    local point = a.point or "TOP"
    local relPoint, xMult, yMult = relativePoint(point)
    local xMultiplier, yMultiplier = math.abs(xMult), math.abs(yMult)
    local xOffset, yOffset = a.xOffset or 0, a.yOffset or 0
    local columnSpacing = a.columnSpacing or 0
    local startingIndex = a.startingIndex or 1
    local unitCount = #units
    local numDisplayed = unitCount - (startingIndex - 1)
    local unitsPerColumn = a.unitsPerColumn
    local numColumns
    if unitsPerColumn and numDisplayed > unitsPerColumn then
        numColumns = math.min(math.ceil(numDisplayed / unitsPerColumn), a.maxColumns or 1)
    else
        unitsPerColumn = numDisplayed
        numColumns = 1
    end
    local loopStart, step = startingIndex, 1
    local loopFinish = math.min((startingIndex - 1) + unitsPerColumn * numColumns, unitCount)
    numDisplayed = loopFinish - (loopStart - 1)
    if a.sortDir == "DESC" then
        loopStart = unitCount - (startingIndex - 1)
        loopFinish = loopStart - (numDisplayed - 1)
        step = -1
    end
    for i = 1, math.max(1, numDisplayed) do
        if not a["child" .. i] then
            local child = CreateFrame(a.templateType or "Button", header:GetName() .. "UnitButton" .. i, header, a.template)
            header[i] = child
            if a.auraContainerTemplate then
                child.AuraContainer = CreateFrame("AuraContainer", nil, child, a.auraContainerTemplate)
            end
            a["child" .. i] = child
        end
    end
    local columnAnchorPoint, columnRelPoint, colxMulti, colyMulti
    if numColumns > 1 then
        columnAnchorPoint = a.columnAnchorPoint
        columnRelPoint, colxMulti, colyMulti = relativePoint(columnAnchorPoint)
    end
    local buttonNum, columnUnitCount, currentAnchor = 0, 0, header
    for i = loopStart, loopFinish, step do
        buttonNum = buttonNum + 1
        columnUnitCount = columnUnitCount + 1
        if columnUnitCount > unitsPerColumn then columnUnitCount = 1 end
        local child = a["child" .. buttonNum]
        if buttonNum == 1 then
            child:SetPoint(point, currentAnchor, point, 0, 0)
            if columnAnchorPoint then child:SetPoint(columnAnchorPoint, currentAnchor, columnAnchorPoint, 0, 0) end
        elseif columnUnitCount == 1 then
            local columnAnchor = a["child" .. (buttonNum - unitsPerColumn)]
            child:SetPoint(columnAnchorPoint, columnAnchor, columnRelPoint, colxMulti * columnSpacing, colyMulti * columnSpacing)
        else
            child:SetPoint(point, currentAnchor, relPoint, xMultiplier * xOffset, yMultiplier * yOffset)
        end
        child:SetAttribute("unit", units[i])
        assert(not child._attr.refreshUnitChange, "mock: secure snippets do not run on this client")
        if not child._attr.statehidden then child:Show() end
        currentAnchor = child
    end
    local i = buttonNum + 1
    while a["child" .. i] do
        local child = a["child" .. i]
        child:Hide()
        child:ClearAllPoints()
        child:SetAttribute("unit", nil)
        i = i + 1
    end
    local bw, bh = a.child1:GetWidth(), a.child1:GetHeight()
    if numDisplayed > 0 then
        local width = xMultiplier * (unitsPerColumn - 1) * bw + ((unitsPerColumn - 1) * (xOffset * xMult)) + bw
        local height = yMultiplier * (unitsPerColumn - 1) * bh + ((unitsPerColumn - 1) * (yOffset * yMult)) + bh
        if numColumns > 1 then
            width = width + ((numColumns - 1) * math.abs(colxMulti) * (width + columnSpacing))
            height = height + ((numColumns - 1) * math.abs(colyMulti) * (height + columnSpacing))
        end
        header:SetWidth(width)
        header:SetHeight(height)
    else
        header:SetWidth(math.max(a.minWidth or (yMultiplier * bw), 0.1))
        header:SetHeight(math.max(a.minHeight or (xMultiplier * bh), 0.1))
    end
    M.headerUpdates = M.headerUpdates + 1
end

-- The header's own (secure) code may move its protected children in
-- combat.
local function groupHeaderUpdate(header)
    M.secureDepth = M.secureDepth + 1
    local ok, err = pcall(groupHeaderLayout, header)
    M.secureDepth = M.secureDepth - 1
    if not ok then error(err, 0) end
end

local function makeGroupHeader(w, pets)
    w._shown = false   -- the template is hidden="true"
    w._pets = pets
    w:RegisterEvent("GROUP_ROSTER_UPDATE")
    w:RegisterEvent("UNIT_NAME_UPDATE")
    if pets then w:RegisterEvent("UNIT_PET") end
    w._scripts.OnEvent = function(self) if self:IsVisible() then groupHeaderUpdate(self) end end
    w._scripts.OnShow = groupHeaderUpdate
    w._scripts.OnAttributeChanged = function(self, name)
        if name == "_ignore" or self._attr._ignore then return end
        if self:IsVisible() then groupHeaderUpdate(self) end
    end
end

```

The existing party tests rely on the player being listed without unit data: the client always has a player (`rosterInfo` covers that).

- [ ] **Step 4: Raid roster stand-ins**

Still in `tests/mock.lua`:

Replace

```lua
    M.resting = false
    _G.IsResting = function() return M.resting end
    _G.GetTime = function() return M.now end
    _G.IsInGroup = function() return #M.group > 0 end
    -- Raid: M.inRaid (M.SetRaid). Visibility drivers (SecureStateDriver.lua:
    -- RegisterStateDriver(frame, "visibility", values) sets state-visibility);
    -- the mock knows the conditions the addon uses.
```

with

```lua
    M.resting = false
    _G.IsResting = function() return M.resting end
    _G.GetTime = function() return M.now end
    -- In a group: a party (M.group) or a raid (M.inRaid).
    _G.IsInGroup = function() return #M.group > 0 or M.inRaid end
    -- Raid: M.inRaid (M.SetRaid). Visibility drivers (SecureStateDriver.lua:
    -- RegisterStateDriver(frame, "visibility", values) sets state-visibility);
    -- the mock knows the conditions the addon uses.
```

Replace

```lua
        if #M.group > 0 then return #M.group + 1 end
        return 0
    end
    -- The player's name and realm (Raid/Profiles.lua: one raid profile per
    -- character). UnitFullName may leave the realm out early in the login.
    M.playerName, M.realm, M.fullNameRealm = "Tester", "Testrealm", true
```

with

```lua
        if #M.group > 0 then return #M.group + 1 end
        return 0
    end
    -- The raid roster (M.SetRaidRoster): member i is unit "raid"..i.
    -- GetRaidRosterInfo's values in the client's order: name, rank,
    -- subgroup, level, class (localised), class token, zone, online,
    -- dead, role (MAINTANK, MAINASSIST or nil), master looter, assigned
    -- role (TANK, HEALER, DAMAGER or NONE).
    M.raid = {}
    _G.GetRaidRosterInfo = function(index)
        local m = M.raid[index]
        if not m then return nil end
        local u = M.units["raid" .. index] or {}
        return m.name, m.rank or 0, m.subgroup, u.level or 60, u.className, m.class, "Zone", not u.offline,
            u.dead or false, m.role, false, m.assignedRole or "NONE"
    end
    -- d.assignment: "MAINTANK" or "MAINASSIST" (party members).
    _G.GetPartyAssignment = function(assignment, unit)
        local d = M.units[unit]
        return d ~= nil and d.assignment == assignment
    end
    -- Blizzard_FrameXMLBase/Camelot/Constants.lua (this game type).
    _G.CLASS_SORT_ORDER = { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER" }
    -- The player's name and realm (Raid/Profiles.lua: one raid profile per
    -- character). UnitFullName may leave the realm out early in the login.
    M.playerName, M.realm, M.fullNameRealm = "Tester", "Testrealm", true
```

Replace

```lua
    M.FireEvent("GROUP_ROSTER_UPDATE")
end

-- Every playing animation group runs to its end: the animated frame takes
-- the last alpha (SetToFinalAlpha), then OnFinished runs.
function M.FinishAnimations()
```

with

```lua
    M.FireEvent("GROUP_ROSTER_UPDATE")
end

-- Joins a raid: members[i] = { name =, class = (token), subgroup =,
-- assignedRole = (TANK, HEALER, DAMAGER or NONE; default NONE), role =
-- (MAINTANK, MAINASSIST or nil), unit = { more unit data } } is unit
-- raid<i>, with its unit data. An empty list leaves the raid. Visibility
-- drivers follow, then GROUP_ROSTER_UPDATE fires.
function M.SetRaidRoster(members)
    M.raid = members
    for token in pairs(M.units) do
        if token:match("^raid%d+$") then M.units[token] = nil end
    end
    for i, m in ipairs(members) do
        local u = { name = m.name, class = m.class, className = m.class, isPlayer = true,
            role = m.assignedRole or "NONE", health = 100, healthMax = 100 }
        for k, v in pairs(m.unit or {}) do u[k] = v end
        M.units["raid" .. i] = u
    end
    M.raidMembers = #members
    M.SetRaid(#members > 0)
    M.FireEvent("GROUP_ROSTER_UPDATE")
end

-- Every playing animation group runs to its end: the animated frame takes
-- the last alpha (SetToFinalAlpha), then OnFinished runs.
function M.FinishAnimations()
```

- [ ] **Step 5: Run the tests**

Run: `tests/run raid_header_mock` → `35 passed, 0 failed`
Run: `tests/run` → Expected: `18939 passed, 0 failed`

No existing test changes: the party and pet headers lay out as before.

- [ ] **Step 6: Commit**

```bash
git add tests/mock.lua tests/test_raid_header_mock.lua
git commit -m "Mock: group header ported from the client, raid roster

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Raid layout: blocks, header filters, positions

**Files:**
- Create: `Raid/Layout.lua`
- Modify: `ForeverUnitFrames.toc`
- Modify: `tests/mock.lua` (Blizzard's title strings)
- Test: `tests/test_raid_layout.lua`

**Interfaces:**
- Consumes: `CLASS_SORT_ORDER` (Task 2), `GROUP_NUMBER`, `LOCALIZED_CLASS_NAMES_MALE`, `TANK` / `HEALER` / `DAMAGER`, `RAID` (mock: this task).
- Produces: `ns.RaidLayout` with `GROUP_SIZE` (5), `ROLES`, `FILTER_KEYS` (groupFilter, roleFilter, strictFiltering, groupBy, groupingOrder), `Groups(size)`, `Blocks(groupBy, size) -> { { kind, id, capacity (GROUP: 5), filter } }`, `Matches(block, member, size)` (member `{ subgroup, class, assignedRole }`), `Title(block)`, and geometry on a shape `s = { cellWidth, cellHeight, cellGap, cellsPerLine, cellGrowth, inset, titleHeight, blockGap, blocksPerLine, blockDirection }`: `HeaderAttributes(s, size)`, `CellOffset(s, i)`, `BlockSize(s, n)`, `HeaderOffset(s)`, `Room(block, count, hideEmpty)`, `Arrange(s, sizes) -> positions, width, height`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_layout.lua`:

```lua
-- Raid layout (Raid/Layout.lua): the blocks of each grouping for a raid
-- size with their header filters, block titles from Blizzard's own
-- strings, header attributes for the cell growth, and where cells and
-- blocks go. Pure numbers; the mock's header checks the filters.
local M = H.M
local ns = H.LoadAddon()
local L = ns.RaidLayout

H.check("groups of 10", table.concat(L.Groups(10), ","), "1,2")
H.check("groups of 20", table.concat(L.Groups(20), ","), "1,2,3,4")
H.check("groups of 40", table.concat(L.Groups(40), ","), "1,2,3,4,5,6,7,8")

local function ids(blocks)
    local list = {}
    for _, b in ipairs(blocks) do list[#list + 1] = tostring(b.id) end
    return table.concat(list, ",")
end
H.check("group blocks at 20", ids(L.Blocks("GROUP", 20)), "1,2,3,4")
H.check("class blocks in Blizzard's class order", ids(L.Blocks("CLASS", 40)),
    "WARRIOR,PALADIN,PRIEST,SHAMAN,DRUID,ROGUE,MAGE,WARLOCK,HUNTER")
H.check("role blocks", ids(L.Blocks("ROLE", 10)), "TANK,HEALER,DAMAGER")
H.check("one block", ids(L.Blocks("NONE", 10)), "ALL")
H.check("group blocks hold five", L.Blocks("GROUP", 40)[1].capacity, 5)
H.check("class blocks grow", L.Blocks("CLASS", 40)[1].capacity, nil)

-- Filters, as the group headers take them.
local g2 = L.Blocks("GROUP", 20)[2].filter
H.check("group filter", g2.groupFilter, "2")
H.check("group: not strict", g2.strictFiltering, nil)
local mage = L.Blocks("CLASS", 10)[7].filter
H.check("class filter: the size's groups and the class", mage.groupFilter, "1,2,MAGE")
H.check("class filter: strict", mage.strictFiltering, true)
local dps = L.Blocks("ROLE", 20)[3].filter
H.check("role filter: groups and every class", dps.groupFilter, "1,2,3,4," .. table.concat(CLASS_SORT_ORDER, ","))
H.check("role filter: damage takes the unassigned", dps.roleFilter, "DAMAGER,NONE")
H.check("role filter: strict", dps.strictFiltering, true)
H.check("tank filter", L.Blocks("ROLE", 20)[1].filter.roleFilter, "TANK")
local all = L.Blocks("NONE", 40)[1].filter
H.check("one block: every group of the size", all.groupFilter, "1,2,3,4,5,6,7,8")
H.check("one block: ordered by group", all.groupBy, "GROUP")
H.check("one block: group order", all.groupingOrder, "1,2,3,4,5,6,7,8")
H.check("filter keys", table.concat(L.FILTER_KEYS, ","), "groupFilter,roleFilter,strictFiltering,groupBy,groupingOrder")

-- Who belongs to a block (test mode's pretend members), as the filters.
local function member(subgroup, class, role) return { subgroup = subgroup, class = class, assignedRole = role } end
H.checkTrue("group match", L.Matches(L.Blocks("GROUP", 10)[2], member(2, "MAGE", "DAMAGER"), 10))
H.check("class in a group beyond the size", L.Matches(L.Blocks("CLASS", 10)[7], member(3, "MAGE", "NONE"), 10), false)
H.checkTrue("unassigned counts as damage", L.Matches(L.Blocks("ROLE", 10)[3], member(1, "MAGE", "NONE"), 10))
H.check("healer is no damage", L.Matches(L.Blocks("ROLE", 10)[3], member(1, "PRIEST", "HEALER"), 10), false)
H.checkTrue("everyone of the size", L.Matches(L.Blocks("NONE", 20)[1], member(4, "PRIEST", "HEALER"), 20))

-- Titles: Blizzard's own strings, the token when the client has none.
LOCALIZED_CLASS_NAMES_MALE.WARRIOR = nil
_G.TANK = nil
H.check("group title", L.Title(L.Blocks("GROUP", 10)[2]), "Group 2")
H.check("class title", L.Title(L.Blocks("CLASS", 10)[7]), "Mage")
H.check("class title without a name", L.Title(L.Blocks("CLASS", 10)[1]), "WARRIOR")
H.check("role title", L.Title(L.Blocks("ROLE", 10)[2]), "Healer")
H.check("role title without a name", L.Title(L.Blocks("ROLE", 10)[1]), "TANK")
H.check("one block title", L.Title(L.Blocks("NONE", 10)[1]), "Raid")

-- Geometry. Cells 80 x 38, 2 apart; a cell border reaching 1 out adds
-- 2 to the gap and insets the cells by 1.
local s = { cellWidth = 80, cellHeight = 38, cellGap = 2, cellsPerLine = 5, cellGrowth = "DOWN",
    blockGap = 6, blocksPerLine = 8, blockDirection = "HORIZONTAL", inset = 0, titleHeight = 0 }
local a = L.HeaderAttributes(s, 40)
H.check("down: point", a.point, "TOP")
H.check("down: y offset", a.yOffset, -2)
H.check("down: x offset", a.xOffset, 0)
H.check("down: per column", a.unitsPerColumn, 5)
H.check("down: enough columns for the size", a.maxColumns, 8)
H.check("down: new columns to the right", a.columnAnchorPoint, "LEFT")
H.check("down: column spacing", a.columnSpacing, 2)
local x, y = L.CellOffset(s, 7)
H.check("cell 7: second column", x, 82)
H.check("cell 7: second row", y, -40)
local w, h = L.BlockSize(s, 5)
H.check("full group: width", w, 80)
H.check("full group: height", h, 5 * 38 + 4 * 2)
w, h = L.BlockSize(s, 7)
H.check("seven: two columns", w, 162)
H.check("seven: five rows", h, 198)

local r = { cellWidth = 80, cellHeight = 38, cellGap = 2, cellsPerLine = 4, cellGrowth = "RIGHT",
    blockGap = 6, blocksPerLine = 2, blockDirection = "VERTICAL", inset = 1, titleHeight = 14 }
a = L.HeaderAttributes(r, 10)
H.check("right: point", a.point, "LEFT")
H.check("right: x offset", a.xOffset, 2)
H.check("right: y offset", a.yOffset, 0)
H.check("right: new rows below", a.columnAnchorPoint, "TOP")
H.check("right: rows for the size", a.maxColumns, 3)
x, y = L.CellOffset(r, 6)
H.check("right cell 6: x", x, 82)
H.check("right cell 6: y", y, -40)
w, h = L.BlockSize(r, 6)
H.check("right block width: four, border inset", w, 4 * 80 + 3 * 2 + 2)
H.check("right block height: two rows, title, inset", h, 2 * 38 + 2 + 2 + 14)
x, y = L.HeaderOffset(r)
H.check("header inside its block: x", x, 1)
H.check("header inside its block: y", y, -15)

-- Room: groups keep room for five; others for who is there; empty blocks
-- take none when hidden, one cell otherwise.
local group, class = L.Blocks("GROUP", 10)[1], L.Blocks("CLASS", 10)[1]
H.check("group room", L.Room(group, 2, true), 5)
H.check("empty group hidden", L.Room(group, 0, true), nil)
H.check("empty group shown", L.Room(group, 0, false), 5)
H.check("class room", L.Room(class, 3, true), 3)
H.check("empty class hidden", L.Room(class, 0, true), nil)
H.check("empty class shown", L.Room(class, 0, false), 1)

-- Arranging blocks: in a row, wrapping after blocksPerLine; dropped
-- blocks leave no gap.
local sizes = { { 80, 198 }, false, { 80, 120 }, { 162, 80 } }
local pos, pw, ph = L.Arrange({ blockGap = 6, blocksPerLine = 2, blockDirection = "HORIZONTAL" }, sizes)
H.check("first block", pos[1].x .. "," .. pos[1].y, "0,0")
H.check("dropped block", pos[2], nil)
H.check("second shown block beside", pos[3].x .. "," .. pos[3].y, "86,0")
H.check("third wraps under the tallest", pos[4].x .. "," .. pos[4].y, "0,-204")
H.check("panel width", pw, 166)
H.check("panel height", ph, 284)
pos, pw, ph = L.Arrange({ blockGap = 6, blocksPerLine = 2, blockDirection = "VERTICAL" }, sizes)
H.check("vertical: second below", pos[3].x .. "," .. pos[3].y, "0,-204")
H.check("vertical: wraps right of the widest", pos[4].x .. "," .. pos[4].y, "86,0")
H.check("vertical panel width", pw, 248)
H.check("vertical panel height", ph, 324)
pos, pw, ph = L.Arrange({ blockGap = 6, blocksPerLine = 2, blockDirection = "VERTICAL" }, { false })
H.check("nothing to show", pw .. "," .. ph, "0,0")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run raid_layout.lua`
Expected: `ERROR test_raid_layout.lua:9: attempt to index local 'L' (a nil value)`, `0 passed, 1 failed`

- [ ] **Step 3: Create `Raid/Layout.lua`**

```lua
local _, ns = ...

-- The raid panel's layout as plain numbers: which blocks a grouping makes
-- for a raid size, the filters and attributes of their group headers
-- (Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua, plain
-- attributes only, no snippets), and where blocks and cells go. No frames
-- here: Raid/Header.lua applies it, test mode places its pretend cells
-- with the same numbers.
local Layout = {}
ns.RaidLayout = Layout

Layout.ROLES = { "TANK", "HEALER", "DAMAGER" }
-- Every filter attribute a block may set; the others are cleared.
Layout.FILTER_KEYS = { "groupFilter", "roleFilter", "strictFiltering", "groupBy", "groupingOrder" }
-- A group never holds more than five.
Layout.GROUP_SIZE = 5

-- The raid groups a size shows: 10 -> 1-2, 20 -> 1-4, 40 -> 1-8.
function Layout.Groups(size)
    local list = {}
    for g = 1, size / Layout.GROUP_SIZE do list[g] = g end
    return list
end

local function joined(list) return table.concat(list, ",") end

-- Blizzard's class order for this game type (CLASS_SORT_ORDER).
local function classes()
    return CLASS_SORT_ORDER or { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK",
        "HUNTER" }
end

-- The blocks of a grouping: { kind, id, capacity (groups only), filter }.
-- Each block keeps to the size's groups. A class or role block filters
-- strictly: group and class (and role) must all match. Members without
-- an assigned role count as damage.
function Layout.Blocks(groupBy, size)
    local groups = joined(Layout.Groups(size))
    local blocks = {}
    if groupBy == "GROUP" then
        for g = 1, size / Layout.GROUP_SIZE do
            blocks[g] = { kind = "GROUP", id = g, capacity = Layout.GROUP_SIZE, filter = { groupFilter = tostring(g) } }
        end
    elseif groupBy == "CLASS" then
        for i, token in ipairs(classes()) do
            blocks[i] = { kind = "CLASS", id = token,
                filter = { groupFilter = groups .. "," .. token, strictFiltering = true } }
        end
    elseif groupBy == "ROLE" then
        local everyClass = groups .. "," .. joined(classes())
        for i, role in ipairs(Layout.ROLES) do
            blocks[i] = { kind = "ROLE", id = role, filter = { groupFilter = everyClass,
                roleFilter = role == "DAMAGER" and "DAMAGER,NONE" or role, strictFiltering = true } }
        end
    else
        blocks[1] = { kind = "NONE", id = "ALL",
            filter = { groupFilter = groups, groupBy = "GROUP", groupingOrder = groups } }
    end
    return blocks
end

-- Whether a member { subgroup, class, assignedRole } belongs to a block,
-- as its filter decides (test mode's pretend members).
function Layout.Matches(block, member, size)
    local inGroups = member.subgroup >= 1 and member.subgroup <= size / Layout.GROUP_SIZE
    if block.kind == "GROUP" then return member.subgroup == block.id end
    if not inGroups then return false end
    if block.kind == "CLASS" then return member.class == block.id end
    if block.kind == "ROLE" then
        local role = member.assignedRole or "NONE"
        if block.id == "DAMAGER" then return role == "DAMAGER" or role == "NONE" end
        return role == block.id
    end
    return true
end

-- A block's title in Blizzard's own words (GROUP_NUMBER, the localised
-- class names, the role names, RAID); the token where the client has none.
local function global(name)
    local v = _G[name]
    if type(v) == "string" then return v end
    return nil
end

function Layout.Title(block)
    if block.kind == "GROUP" then
        local format = global("GROUP_NUMBER")
        return format and format:format(block.id) or tostring(block.id)
    elseif block.kind == "CLASS" then
        local names = LOCALIZED_CLASS_NAMES_MALE
        return type(names) == "table" and names[block.id] or block.id
    elseif block.kind == "ROLE" then
        return global(block.id) or block.id
    end
    return global("RAID") or ""
end

-- Geometry. s holds, on the pixel grid: cellWidth, cellHeight, cellGap
-- (spacing plus both cells' borders), cellsPerLine, cellGrowth (DOWN or
-- RIGHT), inset (how far the cells sit inside their block: a cell
-- border's reach), titleHeight (0 without titles); for arranging blocks:
-- blockGap, blocksPerLine, blockDirection.

-- The cell layout of a group header: a column growing down with new
-- columns to the right, or a row growing right with new rows below; as
-- many columns (rows) as the size can fill.
function Layout.HeaderAttributes(s, size)
    local down = s.cellGrowth == "DOWN"
    return {
        point = down and "TOP" or "LEFT",
        xOffset = down and 0 or s.cellGap,
        yOffset = down and -s.cellGap or 0,
        unitsPerColumn = s.cellsPerLine,
        maxColumns = math.ceil(size / s.cellsPerLine),
        columnSpacing = s.cellGap,
        columnAnchorPoint = down and "LEFT" or "TOP",
    }
end

-- Cell i (1-based) from its header's top-left corner, as the header
-- places it.
function Layout.CellOffset(s, i)
    local line, pos = math.floor((i - 1) / s.cellsPerLine), (i - 1) % s.cellsPerLine
    local stepX, stepY = s.cellWidth + s.cellGap, s.cellHeight + s.cellGap
    if s.cellGrowth == "DOWN" then return line * stepX, -pos * stepY end
    return pos * stepX, -line * stepY
end

-- Width and height of a block with room for n cells: the cells, their
-- borders' reach on every side, and the title row.
function Layout.BlockSize(s, n)
    local lines, across = math.ceil(n / s.cellsPerLine), math.min(n, s.cellsPerLine)
    local cols, rows = lines, across
    if s.cellGrowth ~= "DOWN" then cols, rows = across, lines end
    local w = cols * s.cellWidth + (cols - 1) * s.cellGap + 2 * s.inset
    local h = rows * s.cellHeight + (rows - 1) * s.cellGap + 2 * s.inset + s.titleHeight
    return w, h
end

-- The header's top-left corner inside its block: below the title, inside
-- the cell borders.
function Layout.HeaderOffset(s)
    return s.inset, -(s.titleHeight + s.inset)
end

-- How many cells a block makes room for, or nil: no room at all. A group
-- keeps room for a full group, so members joining in combat (when blocks
-- cannot move) never overlap the next block; other blocks hold who is
-- there. An empty block takes no room when empty blocks are hidden, else
-- one cell.
function Layout.Room(block, count, hideEmpty)
    if count == 0 and hideEmpty then return nil end
    if block.capacity then return block.capacity end
    return math.max(count, 1)
end

-- Places blocks of the given sizes ({ w, h }, or false for a block
-- without room): in a row (HORIZONTAL) or a column (VERTICAL), a new one
-- after blocksPerLine blocks, past the tallest (widest) block of the line
-- before. Returns each block's top-left corner from the panel's ({ x, y },
-- nil for blocks without room) and the panel's width and height.
function Layout.Arrange(s, sizes)
    local positions = {}
    local horizontal = s.blockDirection == "HORIZONTAL"
    local along, lineStart, lineDepth, inLine = 0, 0, 0, 0
    local width, height = 0, 0
    for i, size in ipairs(sizes) do
        if size then
            if inLine == s.blocksPerLine then
                lineStart = lineStart + lineDepth + s.blockGap
                along, lineDepth, inLine = 0, 0, 0
            end
            local w, h = size[1], size[2]
            local x, y
            if horizontal then
                x, y = along, 0 - lineStart
                along = along + w + s.blockGap
                lineDepth = math.max(lineDepth, h)
            else
                x, y = lineStart, 0 - along
                along = along + h + s.blockGap
                lineDepth = math.max(lineDepth, w)
            end
            inLine = inLine + 1
            positions[i] = { x = x, y = y }
            width = math.max(width, x + w)
            height = math.max(height, -y + h)
        end
    end
    return positions, width, height
end
```

- [ ] **Step 4: Load it and give the mock Blizzard's title strings**

In `ForeverUnitFrames.toc`, directly after the line `Raid\Size.lua`, add:

```
Raid\Layout.lua
```

In `tests/mock.lua`:

Replace

```lua
    end
    -- Blizzard_FrameXMLBase/Camelot/Constants.lua (this game type).
    _G.CLASS_SORT_ORDER = { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER" }
    -- The player's name and realm (Raid/Profiles.lua: one raid profile per
    -- character). UnitFullName may leave the realm out early in the login.
    M.playerName, M.realm, M.fullNameRealm = "Tester", "Testrealm", true
```

with

```lua
    end
    -- Blizzard_FrameXMLBase/Camelot/Constants.lua (this game type).
    _G.CLASS_SORT_ORDER = { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER" }
    -- Blizzard's strings for raid block titles (GlobalStrings; the class
    -- names from LocalizedClassList, Blizzard_FrameXMLBase/Constants.lua).
    _G.GROUP_NUMBER = "Group %d"
    _G.RAID = "Raid"
    _G.TANK, _G.HEALER, _G.DAMAGER = "Tank", "Healer", "Damage"
    _G.LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", PALADIN = "Paladin", PRIEST = "Priest",
        SHAMAN = "Shaman", DRUID = "Druid", ROGUE = "Rogue", MAGE = "Mage", WARLOCK = "Warlock", HUNTER = "Hunter" }
    -- The player's name and realm (Raid/Profiles.lua: one raid profile per
    -- character). UnitFullName may leave the realm out early in the login.
    M.playerName, M.realm, M.fullNameRealm = "Tester", "Testrealm", true
```

- [ ] **Step 5: Run the tests**

Run: `tests/run raid_layout.lua` → `73 passed, 0 failed`
Run: `tests/run` → Expected: `19012 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add Raid/Layout.lua ForeverUnitFrames.toc tests/mock.lua tests/test_raid_layout.lua
git commit -m "Raid layout: blocks, header filters, cell and block positions

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Element hooks for a cell: centred texts, samples, a power rule

**Files:**
- Modify: `Elements/Health.lua`, `Elements/Texts.lua`, `Elements/UnitStatus.lua`, `Elements/Power.lua`
- Test: `tests/test_raid_cell_elements.lua`

**Interfaces:**
- Produces: `frame.centerTexts` (Texts: health texts centred, second line below the name, AFK as a status word); `frame.sample = { class, name, health, status, role }` while previewing (`Health.Sample(frame)`, `Health.FrameColor(frame, mode)`; Health, Texts and UnitStatus use it); `frame.showsPower(frame) -> bool` (Power hides the bar when false); `Texts.CENTRE_INSET` (2); `Texts.Apply` option `sampleName`. No unit frame sets any of the fields.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_cell_elements.lua`:

```lua
-- What the elements offer a raid cell (Raid/Cell.lua), each switched by a
-- field no unit frame sets: centred name and second line with AFK as a
-- status (frame.centerTexts), a test-mode sample of its own per frame
-- (frame.sample: class, name, health share, status), and a power bar
-- that a rule of the frame hides (frame.showsPower).
local M = H.M
local ns = H.LoadAddon()
local C = ns.Config
C.Use({})
C.Set("party", "textHealthLeft", "NAME")
C.Set("party", "textHealthRight", "DEFICIT")
C.Set("party", "healthColorMode", "CLASS")
C.Set("party", "barNameColorMode", "CLASS")
M.units.player = { name = "Me", class = "WARLOCK", className = "Warlock", isPlayer = true, level = 60,
    health = 50, healthMax = 100, healthMissing = 50, power = 10, powerMax = 100 }

local function button()
    local b = CreateFrame("Button", nil, UIParent, "SecureUnitButtonTemplate")
    b.key = "party"
    for _, el in ipairs(ns.Elements) do el.Build(b) end
    return b
end

-- A unit frame: the bar's texts at its ends, as always.
local plain = button()
ns.Single.StyleContent(plain)
local p, rel, relPoint, x, y = plain.texts.healthLeft:GetPoint(1)
H.checkTrue("unit frame: name at the left end", p == "LEFT" and rel == plain.health and relPoint == "LEFT" and x == 4 and y == 0)
H.check("unit frame: name justified left", plain.texts.healthLeft._justifyH, "LEFT")
H.check("unit frame: value justified right", plain.texts.healthRight._justifyH, "RIGHT")

-- Centred: the name above the middle, the second line below, each as
-- wide as the bar less 2 on either side.
local cell = button()
cell.centerTexts = true
ns.Single.StyleContent(cell)
local name, second = cell.texts.healthLeft, cell.texts.healthRight
p, rel, relPoint, x, y = name:GetPoint(1)
H.checkTrue("centred: name from the bar's left", p == "LEFT" and rel == cell.health and relPoint == "LEFT" and x == 2)
H.check("centred: name half a value line up", y, 6)
p, rel, relPoint, x, y = name:GetPoint(2)
H.checkTrue("centred: name to the bar's right", p == "RIGHT" and rel == cell.health and relPoint == "RIGHT" and x == -2)
H.check("centred: name justified centre", name._justifyH, "CENTER")
H.check("centred: name on one line", name:GetWordWrap(), false)
p, rel, relPoint, x, y = second:GetPoint(1)
H.checkTrue("centred: second line from the bar's left", p == "LEFT" and rel == cell.health and x == 2)
H.check("centred: second line half a name line down", y, -6)
H.check("centred: second line justified centre", second._justifyH, "CENTER")
C.Set("party", "valueFontSize", 10)
ns.Single.StyleContent(cell)
H.check("value font: name moves half of it up", select(5, name:GetPoint(1)), 5)
H.check("value font: second line keeps half the name", select(5, second:GetPoint(1)), -6)

-- Live: name and missing health; AFK in the second line of a cell only;
-- dead wins over AFK.
ns.Single.SetUnit(cell, "player")
ns.Single.SetUnit(plain, "player")
ns.Single.UpdateAll(cell)
H.check("name", name:GetText(), "Me")
H.check("missing health", second:GetText(), 50)
M.units.player.afk = true
M.FireEvent("PLAYER_FLAGS_CHANGED", "player")
H.check("AFK in the second line", second:GetText(), "AFK")
H.check("unit frame: no AFK word on the bar", plain.texts.healthRight:GetText(), 50)
M.units.player.dead = true
M.FireEvent("UNIT_HEALTH", "player")
H.check("dead wins over AFK", second:GetText(), ns.L.STATUS_DEAD)
M.units.player.dead, M.units.player.afk = nil, nil
M.FireEvent("UNIT_HEALTH", "player")
H.check("back to the value", second:GetText(), 50)

-- Samples: the frame's own class, name, health and status in test mode.
cell.sample = { class = "DRUID", name = "Druid", health = 0.3, status = false }
ns.Single.Preview(cell, true)
H.check("sample health", cell.health:GetValue(), 0.3)
local c = cell.health._color
H.checkTrue("sample class colour", c[1] == 1 and c[2] == 0.49 and c[3] == 0.04)
H.check("sample name", name:GetText(), "Druid")
H.check("sample name in its class colour", name._color[2], 0.49)
H.check("sample missing health", second:GetText(), 70)
cell.sample.status = "OFFLINE"
ns.Single.Preview(cell, true)
H.check("sample status", second:GetText(), ns.L.STATUS_OFFLINE)
H.check("sample status greys the bar", cell.health._color[1], 0.5)
-- A party pretend member keeps the shared sample and the player's colour.
plain.sampleIndex = 1
ns.Single.Preview(plain, true)
H.check("unit frame sample: shared health", plain.health:GetValue(), ns.Health.SAMPLE)
H.check("unit frame sample: the player's class colour", plain.health._color[1], 0.53)
ns.Single.Preview(cell, false)
ns.Single.UpdateAll(cell)
H.check("sample over: live name", name:GetText(), "Me")
H.check("sample over: live colour", cell.health._color[1], 0.53)

-- A power rule of the frame hides the bar; the health bar takes its row.
cell.showsPower = function() return false end
ns.Power.Update(cell)
H.check("rule: power hidden", cell.power:IsShown(), false)
H.check("rule: health takes the row", cell.health:GetHeight(), 32)
cell.showsPower = function(frame) return frame == cell end
ns.Power.Update(cell)
H.checkTrue("rule: power back", cell.power:IsShown())
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run raid_cell_elements`
Expected: 19 `FAIL` lines, the first `FAIL centred: name from the bar's left -> false (want true)`, then `14 passed, 19 failed`

- [ ] **Step 3: Health: a frame's sample**

In `Elements/Health.lua`:

Replace

```lua
    return c[1], c[2], c[3]
end

-- Tapped by someone else: a creature (not player-controlled) another
-- player or group has claimed. Blizzard's grey. A secret answer counts as
-- not tapped (the bar keeps its colour).
```

with

```lua
    return c[1], c[2], c[3]
end

-- A frame's own test-mode sample while it shows samples: { class (token),
-- name, health (share), status (UnitStatus, or false) }. Only raid test
-- cells have one (Raid/TestMode.lua); unit frames share Health.SAMPLE.
function Health.Sample(frame)
    return frame.health.preview and frame.sample or nil
end

-- UnitColor of the frame's unit, or of its sample's class.
function Health.FrameColor(frame, mode)
    local sample = Health.Sample(frame)
    if sample and mode == "CLASS" then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[sample.class]
        if c then return c.r, c.g, c.b end
    end
    return Health.UnitColor(frame.unit, mode, frame.key)
end

-- Tapped by someone else: a creature (not player-controlled) another
-- player or group has claimed. Blizzard's grey. A secret answer counts as
-- not tapped (the bar keeps its colour).
```

Replace

```lua
    end
    local mode = Config.Get(scope, "healthColorMode")
    if mode == "CLASS" or mode == "REACTION" then
        return Health.UnitColor(unit, mode, scope)
    end
    if mode == "GRADIENT" then
        return UnitHealthPercent(unit, true, gradient()):GetRGB()
    end
    local c = Config.Get(scope, "healthColor")
```

with

```lua
    end
    local mode = Config.Get(scope, "healthColorMode")
    if mode == "CLASS" or mode == "REACTION" then
        return Health.FrameColor(frame, mode)
    end
    if mode == "GRADIENT" then
        local sample = Health.Sample(frame)
        if sample then return gradient():Evaluate(sample.health):GetRGB() end
        return UnitHealthPercent(unit, true, gradient()):GetRGB()
    end
    local c = Config.Get(scope, "healthColor")
```

Replace

```lua
    bar.preview = on or nil
    if not on then return end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(Health.SAMPLE)
end

ns.RegisterElement(Health)
```

with

```lua
    bar.preview = on or nil
    if not on then return end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(frame.sample and frame.sample.health or Health.SAMPLE)
end

ns.RegisterElement(Health)
```

- [ ] **Step 4: Texts: centred lines, AFK, the sample's name and health**

In `Elements/Texts.lua`:

Replace

```lua
    if not frame.health.preview then return nil end
    local max = Secrets.Number(UnitHealthMax(frame.unit))
    if not max or max <= 0 then max = Texts.SAMPLE_MAX end
    local current = math.floor(max * ns.Health.SAMPLE + 0.5)
    return { current = current, max = max, missing = max - current, percent = ns.Health.SAMPLE * 100 }
end

-- The value tags drawn from sample numbers.
```

with

```lua
    if not frame.health.preview then return nil end
    local max = Secrets.Number(UnitHealthMax(frame.unit))
    if not max or max <= 0 then max = Texts.SAMPLE_MAX end
    -- A raid test cell's own share (Health.Sample), else the shared one.
    local own = ns.Health.Sample(frame)
    local share = own and own.health or ns.Health.SAMPLE
    local current = math.floor(max * share + 0.5)
    return { current = current, max = max, missing = max - current, percent = share * 100 }
end

-- The value tags drawn from sample numbers.
```

Replace

```lua
-- sample (optional): plain health numbers that replace the unit's for
-- the value tags of health texts (test mode).
-- opts (optional): levelColored (the level in its difficulty colour),
-- compact ("1234/1234"), infoColor (INFO's class part coloured), scope.
local NO_OPTS = {}
function Texts.Apply(fs, tag, unit, kind, showSurname, sample, opts)
    opts = opts or NO_OPTS
```

with

```lua
-- sample (optional): plain health numbers that replace the unit's for
-- the value tags of health texts (test mode).
-- opts (optional): levelColored (the level in its difficulty colour),
-- compact ("1234/1234"), infoColor (INFO's class part coloured), scope,
-- sampleName (a test-mode name that NAME shows instead of the unit's).
local NO_OPTS = {}
function Texts.Apply(fs, tag, unit, kind, showSurname, sample, opts)
    opts = opts or NO_OPTS
```

Replace

```lua
        applySample(fs, tag, sample, opts.compact)
    elseif tag == "NONE" then
        fs:SetText("")
    elseif tag == "NAME" then
        Texts.SetName(fs, unit, showSurname)
    elseif tag == "NAME_LEVEL" then
```

with

```lua
        applySample(fs, tag, sample, opts.compact)
    elseif tag == "NONE" then
        fs:SetText("")
    elseif tag == "NAME" and opts.sampleName then
        fs:SetText(opts.sampleName)
    elseif tag == "NAME" then
        Texts.SetName(fs, unit, showSurname)
    elseif tag == "NAME_LEVEL" then
```

Replace

```lua
-- The power texts' layer above the power bar and anything on it.
Texts.POWER_TEXT_LEVELS = 5

function Texts.Style(frame)
    local scope = frame.key
    frame.powerTextLayer:SetFrameLevel(frame.power:GetFrameLevel() + Texts.POWER_TEXT_LEVELS)
```

with

```lua
-- The power texts' layer above the power bar and anything on it.
Texts.POWER_TEXT_LEVELS = 5

-- Raid cells (Raid/Cell.lua) set frame.centerTexts: the health bar's two
-- texts stand in its middle, the left one (the name) above the right one
-- (the second line, or a status word), each as wide as the bar less a
-- small inset on either side and cut off with "...". The two lines are
-- half the other's font size away from the middle. No unit frame sets it.
Texts.CENTRE_INSET = 2

local function placeCentred(frame, nameSize, secondSize)
    local Pixel, inset = ns.Pixel, Texts.CENTRE_INSET
    for field, y in pairs({ healthLeft = secondSize / 2, healthRight = -nameSize / 2 }) do
        local fs = frame.texts[field]
        local dy = Pixel.Snap(y, fs)
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", frame.health, "LEFT", Pixel.Snap(inset, fs), dy)
        fs:SetPoint("RIGHT", frame.health, "RIGHT", Pixel.Snap(-inset, fs), dy)
        fs:SetJustifyH("CENTER")
        fs:SetWordWrap(false)
    end
end

function Texts.Style(frame)
    local scope = frame.key
    frame.powerTextLayer:SetFrameLevel(frame.power:GetFrameLevel() + Texts.POWER_TEXT_LEVELS)
```

Replace

```lua
        end
        fs:SetJustifyH(slot.point)
    end
    local title = frame.texts.title
    title:SetWordWrap(false)
    title:SetShown(frame.titleHeight > 0)
```

with

```lua
        end
        fs:SetJustifyH(slot.point)
    end
    if frame.centerTexts then
        local secondTag = Config.Get(scope, "textHealthRight")
        placeCentred(frame, size, (SAMPLE_TAGS[secondTag] and valueSize > 0) and valueSize or size)
    end
    local title = frame.texts.title
    title:SetWordWrap(false)
    title:SetShown(frame.titleHeight > 0)
```

Replace

```lua
local function paintBars(frame, wordSlot)
    local mode = Config.Get(frame.key, "barNameColorMode")
    local r, g, b = 1, 1, 1
    if mode ~= "WHITE" then r, g, b = ns.Health.UnitColor(frame.unit, mode, frame.key) end
    for _, slot in ipairs(SLOTS) do
        if slot.bar ~= "title" then
            local named = slot.field ~= wordSlot and Texts.NAME_TAGS[Config.Get(frame.key, slot.setting)]
```

with

```lua
local function paintBars(frame, wordSlot)
    local mode = Config.Get(frame.key, "barNameColorMode")
    local r, g, b = 1, 1, 1
    if mode ~= "WHITE" then r, g, b = ns.Health.FrameColor(frame, mode) end
    for _, slot in ipairs(SLOTS) do
        if slot.bar ~= "title" then
            local named = slot.field ~= wordSlot and Texts.NAME_TAGS[Config.Get(frame.key, slot.setting)]
```

Replace

```lua
        compact = Config.Get(frame.key, "textCompact"),
        infoColor = Config.Get(frame.key, "infoClassColor"),
        scope = frame.key,
    }
    local sample = sampleHealth(frame)
    local word = ns.UnitStatus.Word(ns.UnitStatus.Of(frame))
    local wordSlot = word and statusSlot(frame)
    for _, slot in ipairs(SLOTS) do
        local fs = frame.texts[slot.field]
```

with

```lua
        compact = Config.Get(frame.key, "textCompact"),
        infoColor = Config.Get(frame.key, "infoClassColor"),
        scope = frame.key,
        sampleName = ns.Health.Sample(frame) and ns.Health.Sample(frame).name,
    }
    local sample = sampleHealth(frame)
    local word = ns.UnitStatus.Word(ns.UnitStatus.Of(frame))
    -- A cell's second line also says AFK (the badge's word; the badge
    -- itself needs a unit frame's title row).
    if not word and frame.centerTexts and Texts.AwayState(frame.unit) == "AFK" then word = "AFK" end
    local wordSlot = word and statusSlot(frame)
    for _, slot in ipairs(SLOTS) do
        local fs = frame.texts[slot.field]
```

- [ ] **Step 5: UnitStatus and Power**

In `Elements/UnitStatus.lua`:

Replace

```lua
    redraw(frame, status)
end

-- In test mode statusSample holds the frame's sample, false for none.
function UnitStatus.Preview(frame, on)
    if on then
        frame.statusSample = frame.sampleIndex and UnitStatus.PARTY_SAMPLES[frame.sampleIndex] or false
    else
        frame.statusSample = nil
```

with

```lua
    redraw(frame, status)
end

-- In test mode statusSample holds the frame's sample, false for none: a
-- raid test cell's own (frame.sample.status), else the pretend party's.
function UnitStatus.Preview(frame, on)
    if on and frame.sample then
        frame.statusSample = frame.sample.status or false
    elseif on then
        frame.statusSample = frame.sampleIndex and UnitStatus.PARTY_SAMPLES[frame.sampleIndex] or false
    else
        frame.statusSample = nil
```

In `Elements/Power.lua`:

Replace

```lua
    -- Config.Get answers every scope; the setting exists for some only.
    local applies = ns.Settings.AppliesTo(ns.Settings.Get("powerHideEmpty"), frame.key)
    local empty = applies and Config.Get(frame.key, "powerHideEmpty") == true and Power.IsEmpty(frame.unit)
    if empty == (frame.powerEmpty == true) then return end
    frame.powerEmpty = empty
    -- The rows only: the health bar takes the power bar's row. Auras hung
```

with

```lua
    -- Config.Get answers every scope; the setting exists for some only.
    local applies = ns.Settings.AppliesTo(ns.Settings.Get("powerHideEmpty"), frame.key)
    local empty = applies and Config.Get(frame.key, "powerHideEmpty") == true and Power.IsEmpty(frame.unit)
    -- A rule of the frame's own (raid cells: the power strip setting,
    -- Raid/Cell.lua); no unit frame has one.
    if not empty and frame.showsPower then empty = not frame.showsPower(frame) end
    if empty == (frame.powerEmpty == true) then return end
    frame.powerEmpty = empty
    -- The rows only: the health bar takes the power bar's row. Auras hung
```

- [ ] **Step 6: Run the tests**

Run: `tests/run raid_cell_elements` → `33 passed, 0 failed`
Run: `tests/run` → Expected: `19045 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add Elements/Health.lua Elements/Power.lua Elements/Texts.lua Elements/UnitStatus.lua tests/test_raid_cell_elements.lua
git commit -m "Elements: centred cell texts, per-frame samples, a frame's own power rule

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Raid cell: a unit button under the derived scope `raid`

**Files:**
- Create: `Raid/Cell.lua`, `Raid/Cell.xml`
- Modify: `ForeverUnitFrames.toc`, `Units/Units.lua` (`ForEachFrame`), `Elements/AuraContainers.lua` (comment), `tests/mock.lua` (template mirror)
- Test: `tests/test_raid_cell.lua`

**Interfaces:**
- Consumes: Task 1 settings, Task 4 hooks, `ns.Config.Derive`, `ns.RaidSize.Current()`, `ns.Single.*`, `ns.UnitEvents.Bind`, `ns.Units.EnableTooltip` / `EnableClickCast`.
- Produces: `ns.RaidCell` with `KEY` ("raid"), `TEMPLATE` ("ForeverUnitFramesRaidButtonTemplate"), `buttons`, `fakes` (filled by R2b), `Size()`, `Resolve(key)`, `MANA_CLASSES`, `ShowsPower(frame)`, `Setup(button)`, `InitButton(button)`, `OnUnitChanged(button, unit)`, `Style(button)`; internal event `RAID_CELLS_CHANGED` on every unit change; `ForeverUnitFrames.RaidButtonOnLoad` / `RaidButtonOnAttributeChanged` (XML); `ns.Units.ForEachFrame` covers cells and pretend cells; `frame.auraGroupKeys` honoured by `Elements/AuraContainers.lua`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_cell.lua`:

```lua
-- Raid cells (Raid/Cell.lua, Raid/Cell.xml): unit buttons made by a group
-- header that run the unit-frame elements under the derived scope "raid":
-- the party look, a cell's fixed choices, the raid profile of the active
-- size. Clicks, click-casting, events per unit, the power strip's rule.
local M = H.M
local ns = H.LoadAddon()
local RC, Cell = ns.RaidConfig, ns.RaidCell

-- The XML template and the mock mirror of it agree.
local xml = H.ReadFile("Raid/Cell.xml")
H.checkTrue("xml: template name", xml:find('name="ForeverUnitFramesRaidButtonTemplate"', 1, true))
H.checkTrue("xml: secure unit button", xml:find('inherits="SecureUnitButtonTemplate"', 1, true))
H.checkTrue("xml: clicks", xml:find('registerForClicks="AnyUp"', 1, true))
H.checkTrue("xml: size = 40-player cell defaults", xml:find('<Size x="80" y="38"/>', 1, true))
H.checkTrue("xml: left click targets", xml:find('<Attribute name="*type1" type="string" value="target"/>', 1, true))
H.checkTrue("xml: right click menu", xml:find('<Attribute name="*type2" type="string" value="togglemenu"/>', 1, true))
H.checkTrue("xml: OnLoad", xml:find("ForeverUnitFrames.RaidButtonOnLoad(self)", 1, true))
H.checkTrue("xml: OnAttributeChanged",
    xml:find("ForeverUnitFrames.RaidButtonOnAttributeChanged(self, name, value)", 1, true))
H.checkTrue("xml: no snippet", not xml:find("initialConfigFunction", 1, true))
H.check("default width = xml", ns.RaidSettings.Default(ns.RaidSettings.Get("cellWidth"), "r40"), 80)
H.check("default height = xml", ns.RaidSettings.Default(ns.RaidSettings.Get("cellHeight"), "r40"), 38)
local toc = H.ReadFile("ForeverUnitFrames.toc")
H.checkTrue("toc lists the xml after the lua", toc:find("Raid\\Cell.lua\nRaid\\Cell.xml", 1, true))

ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
H.check("size before a raid", Cell.Size(), 10)

-- The derived scope: the cell's own look from the active size's profile.
local C = ns.Config
H.check("width from the 10 profile", C.Get("raid", "width"), 96)
H.check("height from the 10 profile", C.Get("raid", "height"), 44)
RC.Set("r10", "cellWidth", 110)
H.check("width follows the profile", C.Get("raid", "width"), 110)
H.check("no title row", C.Get("raid", "titlePercent"), 0)
H.check("no portrait", C.Get("raid", "portraitMode"), "OFF")
H.check("no castbar", C.Get("raid", "castbarEnabled"), false)
H.check("no buffs", C.Get("raid", "buffsEnabled"), false)
H.check("no debuffs", C.Get("raid", "debuffsEnabled"), false)
H.check("no combat numbers", C.Get("raid", "combatFeedback"), false)
H.check("no threat glow", C.Get("raid", "threatGlow"), false)
H.check("no shadow", C.Get("raid", "shadowEnabled"), false)
H.check("name on the bar", C.Get("raid", "textHealthLeft"), "NAME")
H.check("second line: missing health", C.Get("raid", "textHealthRight"), "DEFICIT")
H.check("class colour", C.Get("raid", "healthColorMode"), "CLASS")
H.check("name white", C.Get("raid", "barNameColorMode"), "WHITE")
H.check("no cell border", C.Get("raid", "borderShow"), false)
H.check("power strip on", C.Get("raid", "powerEnabled"), true)
H.check("party look otherwise", C.Get("raid", "barTexture"), C.Get("party", "barTexture"))
RC.Set("r10", "secondLine", "PERCENT")
RC.Set("r10", "nameClassColor", true)
RC.Set("r10", "cellBorder", true)
RC.Set("r10", "powerStrip", "OFF")
H.check("second line percent", C.Get("raid", "textHealthRight"), "PERCENT")
H.check("name in class colour", C.Get("raid", "barNameColorMode"), "CLASS")
H.check("cell border", C.Get("raid", "borderShow"), true)
H.check("power strip off", C.Get("raid", "powerEnabled"), false)
RC.ResetScope("r10")
H.checkError("a raid cell's settings are not stored", function() assert(C.Set("raid", "width", 50)) end)

-- A header makes cells in a raid.
local function member(name, class, subgroup, role)
    return { name = name, class = class, subgroup = subgroup, assignedRole = role,
        unit = { health = 60, healthMax = 100, healthMissing = 40, powerType = class == "WARRIOR" and 1 or 0 } }
end
local header = CreateFrame("Frame", "TestRaidCells", UIParent, "SecureGroupHeaderTemplate")
header:SetAttribute("template", Cell.TEMPLATE)
header:SetAttribute("showRaid", true)
M.SetRaidRoster({ member("Tank", "WARRIOR", 1, "TANK"), member("Ann", "PRIEST", 1, "HEALER") })
header:Show()
local tank, ann = header:GetAttribute("child1"), header:GetAttribute("child2")
H.check("cell unit", tank.unit, "raid1")
H.check("cell key", tank.key, "raid")
H.check("cells listed", #Cell.buttons, 2)
H.check("cell size from the profile", tank:GetWidth(), 96)
H.check("events for its unit", tank.eventListener._events.UNIT_HEALTH[1], "raid1")
H.checkTrue("click-cast registered", ClickCastFrames[tank])
H.check("left click targets", M.SecureClick(tank, "LeftButton"), "target")
H.check("right click menu", M.SecureClick(tank, "RightButton"), "togglemenu")
H.check("name centred", tank.texts.healthLeft._justifyH, "CENTER")
H.check("name", tank.texts.healthLeft:GetText(), "Tank")
H.check("missing health", tank.texts.healthRight:GetText(), 40)
H.check("health", tank.health:GetValue(), 60)
local onCells = 0
for _, container in ipairs(M.auraContainers) do
    if container:GetParent() == tank or container:GetParent() == ann then onCells = onCells + 1 end
end
H.check("no aura containers on cells", onCells, 0)
H.check("no castbar", tank.castbar, nil)
H.check("title row hidden", tank.title:IsShown(), false)
local seen = {}
ns.Units.ForEachFrame(function(frame) seen[frame] = true end)
H.checkTrue("every-frame loop reaches cells", seen[tank] and seen[ann])

-- Power strip: mana users by default.
H.check("mana rule: warrior without strip", tank.power:IsShown(), false)
H.checkTrue("mana rule: priest with strip", ann.power:IsShown())
RC.Set("r10", "powerStrip", "HEALERS")
ns.Power.Update(tank)
ns.Power.Update(ann)
H.check("healers: tank without", tank.power:IsShown(), false)
H.checkTrue("healers: healer with", ann.power:IsShown())
M.units.raid1.role = "HEALER"
M.FireEvent("PLAYER_ROLES_ASSIGNED")
H.checkTrue("roles assigned: new healer gets the strip", tank.power:IsShown())
M.units.raid1.role = M.Secret("HEALER")
M.units.raid2.class = M.Secret("PRIEST")
RC.Set("r10", "powerStrip", "MANA")
H.checkTrue("unknown class keeps the strip", Cell.ShowsPower(ann))
RC.Set("r10", "powerStrip", "HEALERS")
H.checkTrue("unknown role keeps the strip", Cell.ShowsPower(tank))
RC.Set("r10", "powerStrip", "ALL")
H.checkTrue("all: everyone", Cell.ShowsPower(tank))
RC.ResetScope("r10")

-- Someone joins in combat: the cell is made at the XML size.
M.combat = true
M.SetRaidRoster({ member("Tank", "WARRIOR", 1, "TANK"), member("Ann", "PRIEST", 1, "HEALER"),
    member("Cid", "MAGE", 1, "DAMAGER") })
local cid = header:GetAttribute("child3")
H.check("combat join: cell made", cid.unit, "raid3")
H.check("combat join: xml width", cid:GetWidth(), 80)
H.check("combat join: data shown", cid.texts.healthLeft:GetText(), "Cid")
H.check("combat join: nothing blocked", #M.blocked, 0)
M.combat = false
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run raid_cell.lua`
Expected: `ERROR harness.lua:71: .../Raid/Cell.xml: No such file or directory`, `0 passed, 1 failed`

- [ ] **Step 3: Create `Raid/Cell.xml`**

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.blizzard.com/wow/ui/ ..\FrameXML\UI.xsd">
	<!--
		One raid cell. The group headers of Raid/Header.lua create these,
		possibly in combat when someone joins; Lua may not size a secure frame
		then, so the size and click handling live here. Keep the size equal to
		the 40-player cell width/height defaults in Raid/Settings.lua;
		tests/test_raid_cell.lua checks that this file and the test mock agree.
	-->
	<Button name="ForeverUnitFramesRaidButtonTemplate" virtual="true" inherits="SecureUnitButtonTemplate" registerForClicks="AnyUp">
		<Size x="80" y="38"/>
		<Attributes>
			<Attribute name="*type1" type="string" value="target"/>
			<Attribute name="*type2" type="string" value="togglemenu"/>
		</Attributes>
		<Scripts>
			<OnLoad>ForeverUnitFrames.RaidButtonOnLoad(self)</OnLoad>
			<OnAttributeChanged>ForeverUnitFrames.RaidButtonOnAttributeChanged(self, name, value)</OnAttributeChanged>
		</Scripts>
	</Button>
</Ui>
```

- [ ] **Step 4: Create `Raid/Cell.lua`**

```lua
local _, ns = ...

-- One raid cell: a unit button the block headers (Raid/Header.lua) make
-- from the template in Raid/Cell.xml, running the unit-frame elements
-- (ns.Elements) like a party member does. Its settings come through a
-- derived unit-frame scope, "raid": the party frame's look (fonts, bar
-- texture, colours, border style), with everything a cell never shows
-- switched off and the cell's own look taken from the raid profile of the
-- active size. Name and second line stand centred in the health bar
-- (Elements/Texts.lua, frame.centerTexts); the power strip follows its
-- own rule per unit (frame.showsPower).
--
-- No initialConfigFunction: secure snippets do not run on this client.
-- The XML gives a cell its starting size and clicks; Lua sizes it when
-- it is made out of combat, else after combat (Raid/Header.lua).
local Cell = {}
ns.RaidCell = Cell

local Config, Secrets = ns.Config, ns.Secrets

Cell.KEY = "raid"
Cell.TEMPLATE = "ForeverUnitFramesRaidButtonTemplate"
-- Every cell a header made, in creation order.
Cell.buttons = {}
-- Test mode's pretend cells (Raid/TestMode.lua).
Cell.fakes = {}

-- The size whose profile the cells show; 10 until the size is known.
function Cell.Size()
    return ns.RaidSize.Current() or 10
end

local function get(key)
    return ns.RaidConfig.Get(ns.Raid.Scope(Cell.Size()), key)
end

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
    healthColorMode = function() return get("healthColorMode") end,
    powerEnabled = function() return get("powerStrip") ~= "OFF" end,
    textHealthRight = function() return get("secondLine") end,
    barNameColorMode = function() return get("nameClassColor") and "CLASS" or "WHITE" end,
    borderShow = function() return get("cellBorder") end,
}

function Cell.Resolve(key)
    local fixed = FIXED[key]
    if fixed ~= nil then return fixed end
    local mapped = MAPPED[key]
    if mapped then return mapped() end
    return nil
end
Config.Derive(Cell.KEY, ns.Party.KEY, Cell.Resolve)

-- Classes that use mana (this game type's classes).
Cell.MANA_CLASSES = { PALADIN = true, PRIEST = true, SHAMAN = true, DRUID = true, MAGE = true, WARLOCK = true,
    HUNTER = true }

-- The class token and the assigned role of a cell's unit (a test cell's:
-- its sample's), or nil: both are secret while the unit's identity is
-- restricted.
local function readable(ok, v)
    if not ok or Secrets.IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

local function classOf(frame)
    if frame.sample then return frame.sample.class end
    local ok, _, token = pcall(UnitClass, frame.unit)
    return readable(ok, token)
end

local function roleOf(frame)
    if frame.sample then return frame.sample.role end
    return readable(pcall(UnitGroupRolesAssigned, frame.unit))
end

-- The power strip's rule (powerStrip; OFF switches the bar off
-- altogether): everyone, mana users by class, or healers by assigned
-- role. A unit that cannot be told keeps its strip, as a power bar does
-- whenever nothing can be told (Elements/Power.lua).
function Cell.ShowsPower(frame)
    local strip = get("powerStrip")
    if strip == "MANA" then
        local class = classOf(frame)
        if class then return Cell.MANA_CLASSES[class] == true end
    elseif strip == "HEALERS" then
        local role = roleOf(frame)
        if role then return role == "HEALER" end
    end
    return true
end

-- What every cell is, real or pretend.
function Cell.Setup(button)
    button.key = Cell.KEY
    button.centerTexts = true
    button.showsPower = Cell.ShowsPower
    -- No aura groups at all: no aura containers are made for a cell
    -- (Elements/AuraContainers.lua).
    button.auraGroupKeys = {}
    for _, el in ipairs(ns.Elements) do el.Build(button) end
    ns.Units.EnableTooltip(button)
end

-- XML OnLoad: the cell exists, its unit is not known yet.
function Cell.InitButton(button)
    Cell.Setup(button)
    Cell.buttons[#Cell.buttons + 1] = button
    ns.Units.EnableClickCast(button)
    -- Made in combat it keeps the XML size until the relayout after combat.
    if not InCombatLockdown() then button:SetSize(ns.Single.Size(Cell.KEY)) end
    ns.Single.StyleContent(button)
end

-- The header assigns or clears a unit, in or out of combat. The panel
-- hears of it (RAID_CELLS_CHANGED): blocks may have grown or emptied.
function Cell.OnUnitChanged(button, unit)
    button.unit = unit
    ns.UnitEvents.Bind(button)
    ns.Fire("RAID_CELLS_CHANGED")
    if unit then ns.Single.UpdateAll(button) end
end

-- Size, contents and data of one cell; its size out of combat only.
function Cell.Style(button)
    if not InCombatLockdown() then button:SetSize(ns.Single.Size(Cell.KEY)) end
    ns.Single.StyleContent(button)
    ns.Single.UpdateAll(button)
end

-- Called from Raid/Cell.xml; not part of the public API.
ns.api.RaidButtonOnLoad = Cell.InitButton
function ns.api.RaidButtonOnAttributeChanged(button, name, value)
    if name == "unit" then Cell.OnUnitChanged(button, value) end
end

-- Roles changed: the healers' power strips follow.
ns.On("PLAYER_ROLES_ASSIGNED", function(event)
    for _, button in ipairs(Cell.buttons) do
        if button.unit and UnitExists(button.unit) then ns.Power.Update(button, event) end
    end
end)
```

- [ ] **Step 5: Load them; mirror the template; every-frame loop; aura groups**

In `ForeverUnitFrames.toc`, directly after the line `Units\PartyTargets.lua`, add:

```
Raid\Cell.lua
Raid\Cell.xml
```

In `tests/mock.lua` (the template mirror, before the party pet one):

Replace

```lua
        end
        ForeverUnitFrames.PartyButtonOnLoad(w)
    end,
    -- Units/PartyPets.xml
    ForeverUnitFramesPartyPetButtonTemplate = function(w)
        w._w, w._h = 160, 20
```

with

```lua
        end
        ForeverUnitFrames.PartyButtonOnLoad(w)
    end,
    -- Raid/Cell.xml
    ForeverUnitFramesRaidButtonTemplate = function(w)
        w._w, w._h = 80, 38
        w._clicks = { "AnyUp" }
        w._attr["*type1"] = "target"
        w._attr["*type2"] = "togglemenu"
        w._scripts.OnAttributeChanged = function(self, name, value)
            ForeverUnitFrames.RaidButtonOnAttributeChanged(self, name, value)
        end
        ForeverUnitFrames.RaidButtonOnLoad(w)
    end,
    -- Units/PartyPets.xml
    ForeverUnitFramesPartyPetButtonTemplate = function(w)
        w._w, w._h = 160, 20
```

In `Units/Units.lua`:

Replace

```lua
end

-- Every unit frame that exists: the single frames, the party members and
-- pets the headers made, and the pretend ones of test mode. For events
-- that concern all of them at once (raid markers, the group's leader, a
-- ready check). fn(frame) runs for each, shown or not.
function ns.Units.ForEachFrame(fn)
    for _, frame in pairs(ns.Frames or {}) do fn(frame) end
    for _, list in ipairs({ ns.Party and ns.Party.buttons, ns.Party and ns.Party.fakes,
        ns.PartyPets and ns.PartyPets.buttons, ns.PartyPets and ns.PartyPets.fakes }) do
        for _, frame in ipairs(list or {}) do fn(frame) end
    end
end
```

with

```lua
end

-- Every unit frame that exists: the single frames, the party members and
-- pets and the raid cells the headers made, and the pretend ones of test
-- mode. For events that concern all of them at once (raid markers, the
-- group's leader, a ready check). fn(frame) runs for each, shown or not.
function ns.Units.ForEachFrame(fn)
    for _, frame in pairs(ns.Frames or {}) do fn(frame) end
    for _, list in ipairs({ ns.Party and ns.Party.buttons, ns.Party and ns.Party.fakes,
        ns.PartyPets and ns.PartyPets.buttons, ns.PartyPets and ns.PartyPets.fakes,
        ns.RaidCell and ns.RaidCell.buttons, ns.RaidCell and ns.RaidCell.fakes }) do
        for _, frame in ipairs(list or {}) do fn(frame) end
    end
end
```

In `Elements/AuraContainers.lua` (comment only: the cache field `auraGroupKeys` may be preset by a frame):

Replace

```lua
-- are secret, and their size must change together with the layout.

-- The groups a frame has containers for: those whose settings apply to
-- it (the dispels group only on the party).
local function groupKeys(frame)
    if frame.auraGroupKeys then return frame.auraGroupKeys end
    local keys = {}
```

with

```lua
-- are secret, and their size must change together with the layout.

-- The groups a frame has containers for: those whose settings apply to
-- it (the dispels group only on the party). A frame may bring its own
-- list in frame.auraGroupKeys (raid cells: none, Raid/Cell.lua).
local function groupKeys(frame)
    if frame.auraGroupKeys then return frame.auraGroupKeys end
    local keys = {}
```

- [ ] **Step 6: Run the tests**

Run: `tests/run raid_cell.lua` → `64 passed, 0 failed`
Run: `tests/run` → Expected: `19109 passed, 0 failed`

Without `button.auraGroupKeys = {}` in `Cell.Setup` the check `no aura containers on cells` fails with `4`.

- [ ] **Step 7: Commit**

```bash
git add Raid/Cell.lua Raid/Cell.xml ForeverUnitFrames.toc Units/Units.lua Elements/AuraContainers.lua tests/mock.lua tests/test_raid_cell.lua
git commit -m "Raid cell: unit button on the element pipeline, derived scope raid

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Movers: own config, changing scope, top-left corner

**Files:**
- Modify: `Core/Movers.lua`
- Test: `tests/test_movers_spec.lua`

**Interfaces:**
- Produces: mover-spec fields `config` (default `ns.Config`), `scope` as a string or a function, `origin` (`"CENTER"` default, `"TOPLEFT"`: x / y are the handle's top-left corner), `id` required when `scope` is a function; `Movers.Sync` sets the label again; `RAID_CONFIG_CHANGED` shows or hides active handles while unlocked. Unit-frame specs behave as before.

- [ ] **Step 1: Write the failing test**

Create `tests/test_movers_spec.lua`:

```lua
-- Movers for positions outside the unit-frame profile (Core/Movers.lua):
-- a spec may bring its own config, a scope that changes (a function) and
-- a top-left origin. Unit-frame movers keep their centre and profile.
local M = H.M
local ns = H.LoadAddon()
local Movers, RC = ns.Movers, ns.RaidConfig
ns.Config.Use({})
ns.RaidProfiles.Attach({})

local function point(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    return table.concat({ p, rel == UIParent and "UIParent" or "?", relPoint, x, y }, " ")
end

local target = CreateFrame("Frame", nil, UIParent)
local size, current = { 120, 60 }, "r10"
Movers.Attach(target, {
    scope = function() return current end, config = RC, id = "test", point = "TOPLEFT", origin = "TOPLEFT",
    size = function() return size[1], size[2] end, label = function() return "Test " .. current end,
    active = function() return RC.Get("general", "enabled") end,
})
local mover = target.mover
H.check("corner from its own config", point(mover), "TOPLEFT UIParent CENTER -600 150")
local p, rel, relPoint = target:GetPoint(1)
H.checkTrue("target hangs from the handle's corner", p == "TOPLEFT" and rel == mover and relPoint == "TOPLEFT")
H.check("label", mover.label:GetText(), "Test r10")
size = { 200, 80 }
Movers.Sync(target)
H.check("bigger: the corner stays", point(mover), "TOPLEFT UIParent CENTER -600 150")
H.check("bigger: handle size", mover:GetWidth(), 200)

-- Dragged: the corner, snapped to the grid, into its own config and scope.
Movers.Unlock()
mover._cx, mover._cy = 97 + 100, -47 - 40
Movers.OnDragStop(mover)
H.check("x stored as the corner", RC.Get("r10", "x"), 96)
H.check("y stored as the corner", RC.Get("r10", "y"), -48)
H.check("unit-frame profile untouched", next(ns.Config.Profile().general), nil)
Movers.Sync(target)
H.check("synced to the stored corner", point(mover), "TOPLEFT UIParent CENTER 96 -48")

-- The scope changes: the other scope's corner and label.
RC.Set("r20", "x", 200)
current = "r20"
Movers.Sync(target)
H.check("other scope's corner", point(mover), "TOPLEFT UIParent CENTER 200 150")
H.check("label follows", mover.label:GetText(), "Test r20")

-- Its own settings switch it off while unlocked.
H.checkTrue("active: shown", mover:IsShown())
RC.Set("general", "enabled", false)
H.check("inactive: hidden at once", mover:IsShown(), false)
RC.Set("general", "enabled", true)
H.checkTrue("active again", mover:IsShown())
Movers.Lock()

-- A unit frame's mover: its centre, the unit-frame profile.
local frame = CreateFrame("Frame", nil, UIParent)
frame.key = "player"
Movers.Attach(frame)
H.check("unit frame: centre", point(frame.mover), "CENTER UIParent CENTER -300 -220")
Movers.Unlock()
frame.mover._cx, frame.mover._cy = 41, 9
Movers.OnDragStop(frame.mover)
H.check("unit frame: x", ns.Config.Get("player", "x"), 40)
H.check("unit frame: y", ns.Config.Get("player", "y"), 8)
H.check("unit frame: raid profile untouched", RC.Get("r10", "x"), 96)
Movers.Lock()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run movers_spec`
Expected: `FAIL corner from its own config -> CENTER UIParent CENTER 0 0 (want TOPLEFT UIParent CENTER -600 150)` among 9 failures, `9 passed, 9 failed`

- [ ] **Step 3: Extend `Core/Movers.lua`**

Replace

```lua
-- themselves; moving happens only out of combat.
--
-- Anything can have a mover: a unit frame, the party block, a detached
-- castbar. A spec says which settings hold the position and how big the
-- handle is:
--   scope          settings scope ("player", "party", ...)
--   xKey, yKey     position settings, offsets of the handle's centre from
--                  the screen centre (default "x" / "y")
--   size()         -> width, height of the handle
--   point          anchor point shared by target and handle (default
--                  "CENTER"); the party block hangs from "TOPLEFT"
```

with

```lua
-- themselves; moving happens only out of combat.
--
-- Anything can have a mover: a unit frame, the party block, a detached
-- castbar, the raid panel. A spec says which settings hold the position
-- and how big the handle is:
--   scope          settings scope ("player", "party", ...), or a function
--                  returning it (the raid panel: the active size's)
--   config         the settings it is in (default ns.Config; the raid
--                  panel: ns.RaidConfig)
--   xKey, yKey     position settings, offsets of the handle's centre from
--                  the screen centre (default "x" / "y")
--   origin         "TOPLEFT": xKey / yKey hold the handle's top-left
--                  corner instead of its centre (the raid panel, whose
--                  size changes with the group)
--   size()         -> width, height of the handle
--   point          anchor point shared by target and handle (default
--                  "CENTER"); the party block hangs from "TOPLEFT"
```

Replace

```lua
--   active()       optional: false keeps the handle hidden when unlocked
--   label          text on the handle, or a function returning it (asked
--                  again when the language changes)
--   id             combat-queue key suffix (default scope)
local Movers = {}
ns.Movers = Movers
```

with

```lua
--   active()       optional: false keeps the handle hidden when unlocked
--   label          text on the handle, or a function returning it (asked
--                  again when the language changes)
--   id             combat-queue key suffix (default scope; required when
--                  scope is a function)
local Movers = {}
ns.Movers = Movers
```

Replace

```lua
end

local function complete(spec)
    spec.xKey = spec.xKey or "x"
    spec.yKey = spec.yKey or "y"
    spec.point = spec.point or "CENTER"
    spec.id = spec.id or spec.scope
    return spec
end

-- Sizes and positions the mover from config alone, never from the
-- target's own current size: inside a queued combat restyle the target may
-- not have been resized yet, and a value read off it would be stale. No-op
```

with

```lua
end

local function complete(spec)
    spec.config = spec.config or ns.Config
    spec.xKey = spec.xKey or "x"
    spec.yKey = spec.yKey or "y"
    spec.point = spec.point or "CENTER"
    spec.origin = spec.origin or "CENTER"
    spec.id = spec.id or spec.scope
    return spec
end

local function scopeOf(spec)
    if type(spec.scope) == "function" then return spec.scope() end
    return spec.scope
end

-- Sizes and positions the mover from config alone, never from the
-- target's own current size: inside a queued combat restyle the target may
-- not have been resized yet, and a value read off it would be stale. No-op
```

Replace

```lua
    mover:ClearAllPoints()
    -- On the pixel grid: the handle's edges, and so its target's, land on
    -- whole pixels.
    mover:SetPoint("CENTER", UIParent, "CENTER",
        Pixel.Centre(ns.Config.Get(spec.scope, spec.xKey), w), Pixel.Centre(ns.Config.Get(spec.scope, spec.yKey), h))
end

function Movers.OnDragStop(mover)
```

with

```lua
    mover:ClearAllPoints()
    -- On the pixel grid: the handle's edges, and so its target's, land on
    -- whole pixels.
    local scope = scopeOf(spec)
    local x, y = spec.config.Get(scope, spec.xKey), spec.config.Get(scope, spec.yKey)
    if spec.origin == "TOPLEFT" then
        mover:SetPoint("TOPLEFT", UIParent, "CENTER", Pixel.Snap(x), Pixel.Snap(y))
    else
        mover:SetPoint("CENTER", UIParent, "CENTER", Pixel.Centre(x, w), Pixel.Centre(y, h))
    end
    mover.label:SetText(labelOf(spec))
end

function Movers.OnDragStop(mover)
```

Replace

```lua
    local mx, my = mover:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local spec = mover.spec
    ns.Config.Set(spec.scope, spec.xKey, Movers.Snap(mx - ux))
    ns.Config.Set(spec.scope, spec.yKey, Movers.Snap(my - uy))
end

local function isActive(mover)
```

with

```lua
    local mx, my = mover:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local spec = mover.spec
    local x, y = mx - ux, my - uy
    if spec.origin == "TOPLEFT" then x, y = x - mover:GetWidth() / 2, y + mover:GetHeight() / 2 end
    local scope = scopeOf(spec)
    spec.config.Set(scope, spec.xKey, Movers.Snap(x))
    spec.config.Set(scope, spec.yKey, Movers.Snap(y))
end

local function isActive(mover)
```

Replace

```lua
    if unlocked then Movers.Lock() end
end)

-- A castbar switched to detached (or back) while unlocked gains or loses
-- its handle at once. Unlocked implies out of combat.
ns.Listen("CONFIG_CHANGED", function()
    if unlocked then showActive() end
end)

-- Handles only hold a plain text: set it again in the new language.
ns.Listen("LANGUAGE_CHANGED", function()
```

with

```lua
    if unlocked then Movers.Lock() end
end)

-- A castbar switched to detached (or back), or the raid frames switched
-- on or off, while unlocked: the handle comes or goes at once. Unlocked
-- implies out of combat.
ns.Listen("CONFIG_CHANGED", function()
    if unlocked then showActive() end
end)
ns.Listen("RAID_CONFIG_CHANGED", function()
    if unlocked then showActive() end
end)

-- Handles only hold a plain text: set it again in the new language.
ns.Listen("LANGUAGE_CHANGED", function()
```

- [ ] **Step 4: Run the tests**

Run: `tests/run movers_spec` → `18 passed, 0 failed`
Run: `tests/run` → Expected: `19127 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Movers.lua tests/test_movers_spec.lua
git commit -m "Movers: own config, changing scope, top-left corner

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Raid panel: one group header per block, placed by its cells; mover

**Files:**
- Create: `Raid/Header.lua`
- Modify: `ForeverUnitFrames.toc`
- Test: `tests/test_raid_header.lua`, `tests/test_raid_mover.lua`

**Interfaces:**
- Consumes: `ns.RaidLayout` (Task 3), `ns.RaidCell` (Task 5), mover specs (Task 6), `ns.Border.Draw` / `Extent` / `Hide`, `ns.Texts.SetFont`, `ns.Config.Derive`.
- Produces: `ns.RaidHeader` with `NAME` ("ForeverUnitFramesRaid", headers `…Block<i>`), `headers`, `blocks`, `decor`, `PANEL_SCOPE` / `BLOCK_SCOPE` (derived scopes `raidpanel` / `raidblock`), `TITLE_SIZE`, `TITLE_HEIGHT`, `TITLE_COLOR`, `Enabled()`, `Active()`, `Shape()`, `Count(i)`, `Place(counts)`, `Size()`, `MoverSpec()`, `UpdateVisibility()`, `Refresh()` (out of combat), `Create()`; `anchor` (mover target), `panel`; listens to `RAID_CELLS_CHANGED`, `GROUP_ROSTER_UPDATE`, `RAID_SIZE_CHANGED`, `RAID_CONFIG_CHANGED`, `CONFIG_CHANGED`, `PIXEL_GRID_CHANGED`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_raid_header.lua`:

```lua
-- The raid panel (Raid/Header.lua): one group header per block with its
-- filter and cell layout, blocks placed by how many cells they hold,
-- titles and borders on plain frames, the active size's profile, nothing
-- protected touched in combat.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell = ns.RaidConfig, ns.RaidHeader, ns.RaidCell
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

local function point(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    local name = rel == UIParent and "UIParent" or rel == Header.anchor and "anchor"
        or rel == Header.anchor.mover and "mover" or "?"
    return table.concat({ p, name, relPoint, x, y }, " ")
end
local function member(name, class, subgroup, role)
    return { name = name, class = class, subgroup = subgroup, assignedRole = role,
        unit = { health = 100, healthMax = 100, powerType = 0 } }
end
local CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID" }
-- n members, five to a group, classes in turn.
local function raid(n)
    local list = {}
    for i = 1, n do
        list[i] = member("M" .. string.format("%02d", i), CLASSES[(i - 1) % #CLASSES + 1], math.floor((i - 1) / 5) + 1,
            i == 1 and "TANK" or "NONE")
    end
    return list
end

-- Solo: the headers of the 10-player profile, empty; the panel hidden.
Header.Create()
H.check("anchor name", Header.anchor:GetName(), "ForeverUnitFramesRaid")
H.check("anchor follows its mover", point(Header.anchor), "TOPLEFT mover TOPLEFT 0 0")
H.check("mover at the profile's top-left corner", point(Header.anchor.mover), "TOPLEFT UIParent CENTER -600 150")
H.check("two group blocks at 10", #Header.blocks, 2)
local h1, h2 = Header.headers[1], Header.headers[2]
H.check("header name", h1:GetName(), "ForeverUnitFramesRaidBlock1")
H.check("header template", h1._template, "SecureGroupHeaderTemplate")
H.check("cell template", h1:GetAttribute("template"), "ForeverUnitFramesRaidButtonTemplate")
H.check("no snippet", h1:GetAttribute("initialConfigFunction"), nil)
H.check("shows in a raid", h1:GetAttribute("showRaid"), true)
H.check("not in a party by default", h1:GetAttribute("showParty"), false)
H.check("group filter 1", h1:GetAttribute("groupFilter"), "1")
H.check("group filter 2", h2:GetAttribute("groupFilter"), "2")
H.check("cells down", h1:GetAttribute("point"), "TOP")
H.check("cell spacing", h1:GetAttribute("yOffset"), -2)
H.check("five per column", h1:GetAttribute("unitsPerColumn"), 5)
H.check("sorted by raid order", h1:GetAttribute("sortMethod"), "INDEX")
H.checkTrue("headers shown", h1:IsShown() and h2:IsShown())
H.check("panel hidden solo", Header.panel:IsShown(), false)

-- A raid of 7: 10-player profile, groups 1 and 2.
M.SetRaidRoster(raid(7))
M.RunTimers()
H.check("size", Cell.Size(), 10)
H.checkTrue("panel shown in a raid", Header.panel:IsShown())
H.check("group 1 cells", Header.Count(1), 5)
H.check("group 2 cells", Header.Count(2), 2)
local c1 = h1:GetAttribute("child1")
H.check("cell unit", c1.unit, "raid1")
H.check("cell size", c1:GetWidth() .. "x" .. c1:GetHeight(), "96x44")
H.check("block 1 at the corner", point(h1), "TOPLEFT anchor TOPLEFT 0 0")
H.check("block 2 beside it", point(h2), "TOPLEFT anchor TOPLEFT 102 0")
H.check("panel width", Header.panel:GetWidth(), 198)
H.check("panel height: room for a full group", Header.panel:GetHeight(), 5 * 44 + 4 * 2)
H.checkTrue("panel border", Header.panel.border and Header.panel.border[1]:IsShown())
H.check("panel border gold", ns.Config.Get(Header.PANEL_SCOPE, "borderStyle"), "GOLD")
H.check("block border off", Header.decor[1].border[1]:IsShown(), false)
H.check("no titles", Header.decor[1].title:IsShown(), false)

-- 15 members: the 20-player profile, groups 1-4; group 4 is empty and
-- takes no room, its header waits below the panel.
M.SetRaidRoster(raid(15))
M.RunTimers()
H.check("size 20", Cell.Size(), 20)
H.check("four blocks", #Header.blocks, 4)
H.check("cells of the 20 profile", Header.headers[1]:GetAttribute("child1"):GetWidth(), 88)
H.check("group 3 beside group 2", point(Header.headers[3]), "TOPLEFT anchor TOPLEFT 188 0")
H.check("empty group 4 parked below", point(Header.headers[4]), "TOPLEFT anchor TOPLEFT 0 -214")
H.check("empty block's frame hidden", Header.decor[4]:IsShown(), false)
H.check("panel: three blocks", Header.panel:GetWidth(), 3 * 88 + 2 * 6)
RC.Set("r20", "hideEmpty", false)
H.check("empty group shown: room for five", point(Header.headers[4]), "TOPLEFT anchor TOPLEFT 282 0")

-- By class: one block per class, packed; titles from the class names.
RC.Set("r20", "hideEmpty", true)
RC.Set("r20", "groupBy", "CLASS")
RC.Set("r20", "blockTitles", true)
M.RunTimers()
H.check("nine class blocks", #Header.blocks, 9)
H.check("warrior filter", Header.headers[1]:GetAttribute("groupFilter"), "1,2,3,4,WARRIOR")
H.check("strict", Header.headers[1]:GetAttribute("strictFiltering"), true)
H.check("warriors", Header.Count(1), 3)
H.check("paladins", Header.Count(2), 0)
H.check("warriors first, below their title", point(Header.headers[1]), "TOPLEFT anchor TOPLEFT 0 -14")
H.check("priests next (no paladins)", point(Header.headers[3]), "TOPLEFT anchor TOPLEFT 94 -14")
H.check("title", Header.decor[1].title:GetText(), "Warrior")
H.checkTrue("title shown", Header.decor[1].title:IsShown())
H.check("block height with title", Header.decor[1]:GetHeight(), 14 + 3 * 40 + 2 * 2)
-- Back to groups: the class filter is cleared.
RC.Set("r20", "groupBy", "GROUP")
H.check("filter back to a group", Header.headers[1]:GetAttribute("groupFilter"), "1")
H.check("strict cleared", Header.headers[1]:GetAttribute("strictFiltering"), nil)
H.check("unused headers hidden", Header.headers[9]:IsShown(), false)
RC.Set("r20", "blockTitles", false)

-- Borders: a block's ring between the blocks, a cell's between the cells.
RC.Set("r20", "blockBorder", true)
H.checkTrue("block border", Header.decor[1].border[1]:IsShown())
H.check("block border widens the gap", point(Header.headers[2]), "TOPLEFT anchor TOPLEFT 100 0")
RC.Set("r20", "blockBorder", false)
RC.Set("r20", "cellBorder", true)
H.check("cell border: cells further apart", Header.headers[1]:GetAttribute("yOffset"), -4)
H.check("cell border: cells inside the block", point(Header.headers[1]), "TOPLEFT anchor TOPLEFT 1 -1")
ns.Config.Set("general", "borderSize", 2)
H.check("unit-frame border size counts", Header.headers[1]:GetAttribute("yOffset"), -6)
ns.Config.Set("general", "borderSize", 1)
RC.Set("r20", "cellBorder", false)

-- Rows instead of columns.
RC.Set("r20", "cellGrowth", "RIGHT")
H.check("rows: point", Header.headers[1]:GetAttribute("point"), "LEFT")
H.check("rows: blocks stacked by width", point(Header.headers[2]), "TOPLEFT anchor TOPLEFT " .. (5 * 88 + 4 * 2 + 6) .. " 0")
RC.Set("r20", "cellGrowth", "DOWN")

-- Another size's profile changes nothing now.
local updates = M.headerUpdates
RC.Set("r40", "cellWidth", 60)
H.check("other size: no relayout", M.headerUpdates, updates)

-- Combat: settings wait; a joining member is placed by the header.
M.combat = true
RC.Set("r20", "cellSpacing", 5)
H.check("combat: spacing waits", Header.headers[1]:GetAttribute("yOffset"), -2)
local list = raid(15)
list[16] = member("M16", "MAGE", 4, "NONE")
M.SetRaidRoster(list)
H.check("combat: joiner gets a cell", Header.Count(4), 1)
H.check("combat: nothing blocked", #M.blocked, 0)
M.SetCombat(false)
H.check("after combat: spacing", Header.headers[1]:GetAttribute("yOffset"), -5)
H.check("after combat: group 4 placed", point(Header.headers[4]), "TOPLEFT anchor TOPLEFT 282 0")
RC.Set("r20", "cellSpacing", 2)

-- Raid frames off: headers and panel hidden.
RC.Set("general", "enabled", false)
H.check("off: headers hidden", Header.headers[1]:IsShown(), false)
H.check("off: panel hidden", Header.panel:IsShown(), false)
RC.Set("general", "enabled", true)
H.checkTrue("on again", Header.headers[1]:IsShown() and Header.panel:IsShown())

-- A party: shown only with the raid view in party on.
M.SetRaidRoster({})
M.units.player = { name = "Me", class = "MAGE", isPlayer = true }
M.units.party1 = { name = "Ann", class = "PRIEST", isPlayer = true }
M.SetGroup({ "party1" })
M.RunTimers()
H.check("party: panel hidden", Header.panel:IsShown(), false)
H.check("party: no cells", Header.Count(1), 0)
RC.Set("general", "showInParty", true)
M.RunTimers()
H.checkTrue("raid view in party: panel", Header.panel:IsShown())
H.check("raid view in party: you and your party", Header.Count(1), 2)
H.check("raid view in party: header attribute", Header.headers[1]:GetAttribute("showParty"), true)
```

Create `tests/test_raid_mover.lua`:

```lua
-- The raid panel's mover (Core/Movers.lua with a raid spec): its handle
-- covers the panel, holds the top-left corner of the active size's
-- profile (raid profile, not the unit-frame one) and shows while the raid
-- frames are on.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Movers = ns.RaidConfig, ns.RaidHeader, ns.Movers
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
Header.Create()
local mover = Header.anchor.mover
H.checkTrue("mover made", mover)
H.check("combat-queue id", mover.spec.id, "raid")
local p, rel, relPoint, x, y = mover:GetPoint(1)
H.check("handle at the top-left corner", table.concat({ p, rel == UIParent and "UIParent" or "?", relPoint, x, y }, " "),
    "TOPLEFT UIParent CENTER -600 150")
p, rel = Header.anchor:GetPoint(1)
H.checkTrue("panel follows the handle", p == "TOPLEFT" and rel == mover)
H.check("empty panel: a cell's size", mover:GetWidth() .. "x" .. mover:GetHeight(), "96x44")
H.check("label", mover.label:GetText(), "Raid 10")

-- Dragged: the raid profile of the active size takes the corner, snapped
-- to the movers' grid; the unit frames' profile is not touched.
Movers.Unlock()
H.checkTrue("shown when unlocked", mover:IsShown())
local w, h = mover:GetWidth(), mover:GetHeight()
mover._cx, mover._cy = 97 + w / 2, -47 - h / 2
Movers.OnDragStop(mover)
H.check("x stored", RC.Get("r10", "x"), 96)
H.check("y stored", RC.Get("r10", "y"), -48)
H.check("unit frames untouched", ns.Config.IsOverridden("party", "x"), false)
H.check("handle follows", select(4, mover:GetPoint(1)) .. "," .. select(5, mover:GetPoint(1)), "96,-48")

-- A raid: the handle covers the blocks.
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 }, { name = "Bob", class = "MAGE", subgroup = 2 } })
M.RunTimers()
H.check("handle covers the panel", mover:GetWidth() .. "x" .. mover:GetHeight(), "198x228")

-- Another size: its own corner, its own label.
RC.Set("r20", "x", 200)
RC.Set("general", "sizeMode", "20")
H.check("20: own corner", select(4, mover:GetPoint(1)), 200)
H.check("20: label", mover.label:GetText(), "Raid 20")

-- Switched off: no handle.
RC.Set("general", "enabled", false)
H.check("off: handle hidden", mover:IsShown(), false)
RC.Set("general", "enabled", true)
H.checkTrue("on: handle back", mover:IsShown())
Movers.Lock()
H.check("locked: hidden", mover:IsShown(), false)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run raid_header.lua`
Expected: `ERROR test_raid_header.lua:34: attempt to index local 'Header' (a nil value)`, `0 passed, 1 failed`

Run: `tests/run raid_mover`
Expected: `ERROR test_raid_mover.lua:11: attempt to index local 'Header' (a nil value)`, `0 passed, 1 failed`

- [ ] **Step 3: Create `Raid/Header.lua`**

```lua
local _, ns = ...

-- The raid panel. Each block (Raid/Layout.lua) is a SecureGroupHeader
-- with a filter that makes its cells (Raid/Cell.lua) and assigns their
-- units by itself, in combat too. Everything else is ours, out of combat
-- only: the headers' attributes, where each block goes, the cells' size.
--
-- Three kinds of frames, so that nothing protected ever has to move in
-- combat:
-- * the anchor: a plain frame at the panel's position (the raid profile's
--   x / y: its top-left corner from the screen centre); the headers hang
--   from it and it never moves in combat;
-- * the headers, children of UIParent, each anchored to the anchor at its
--   block's place;
-- * the panel: a plain frame over the occupied area with the panel border,
--   and one plain frame per block with its title and border. Nothing
--   secure hangs from them, so they show and hide in combat as the group
--   changes.
--
-- Blocks are placed by how many cells each holds, counted out of combat a
-- moment after the headers changed their cells (RAID_CELLS_CHANGED). In
-- combat a joining member makes a block grow in place; the next layout
-- after combat tidies up. A group block keeps room for five, so a group
-- never runs into the next block.
local Header = {}
ns.RaidHeader = Header

local Layout, Cell, Pixel, Border = ns.RaidLayout, ns.RaidCell, ns.Pixel, ns.Border

Header.NAME = "ForeverUnitFramesRaid"
-- Header i is named NAME .. "Block" .. i; block i of the current grouping.
Header.headers = {}
Header.blocks = {}
-- The plain frame of each block: title and border.
Header.decor = {}
Header.PANEL_SCOPE = "raidpanel"
Header.BLOCK_SCOPE = "raidblock"
-- Block titles: font size and the row they take above the cells.
Header.TITLE_SIZE = 11
Header.TITLE_HEIGHT = 14
Header.TITLE_COLOR = { 1, 0.82, 0 }

local function get(key) return ns.RaidConfig.Get(ns.Raid.Scope(Cell.Size()), key) end
local function general(key) return ns.RaidConfig.Get("general", key) end

-- The rings around the panel and around each block: the unit frames' gold
-- border (Core/Border.lua) in derived scopes of their own, square and
-- without shadow, shown while switched on in the raid profile.
local PANEL_RING = { borderStyle = "GOLD", borderSize = 3, borderPadding = 3, cornerRadius = 0, shadowEnabled = false }
local BLOCK_RING = { borderStyle = "GOLD", borderSize = 2, borderPadding = 1, cornerRadius = 0, shadowEnabled = false }
ns.Config.Derive(Header.PANEL_SCOPE, ns.Party.KEY, function(key)
    if key == "borderShow" then return get("panelBorder") end
    return PANEL_RING[key]
end)
ns.Config.Derive(Header.BLOCK_SCOPE, ns.Party.KEY, function(key)
    if key == "borderShow" then return get("blockBorder") end
    return BLOCK_RING[key]
end)

-- Switched on, with a raid profile attached.
function Header.Enabled()
    return ns.RaidConfig.Profile() ~= nil and general("enabled") == true
end

-- Whether the panel shows now: in a raid, or in a party with the raid
-- view in party on.
function Header.Active()
    if not Header.Enabled() then return false end
    return IsInRaid() or (IsInGroup() and general("showInParty") == true)
end

-- The numbers Raid/Layout.lua works with, on the pixel grid. A cell's
-- border reaches out between the cells and from the block's edge, a
-- block's border between the blocks.
function Header.Shape()
    local w, h = ns.Single.Size(Cell.KEY)
    local cellExtent = Border.Extent(Cell.KEY)
    return {
        cellWidth = w, cellHeight = h,
        cellGap = Pixel.Snap(get("cellSpacing")) + 2 * cellExtent,
        cellsPerLine = get("cellsPerLine"), cellGrowth = get("cellGrowth"),
        inset = cellExtent,
        titleHeight = get("blockTitles") and Pixel.Snap(Header.TITLE_HEIGHT) or 0,
        blockGap = Pixel.Snap(get("blockSpacing")) + 2 * Border.Extent(Header.BLOCK_SCOPE),
        blocksPerLine = get("blocksPerLine"), blockDirection = get("blockDirection"),
    }
end

-- Header attributes are set in one go; one relayout follows (Show). The
-- filter keys a block does not use are cleared.
local function setAttributes(header, attributes, filter)
    header:SetAttribute("_ignore", "attributeChanges")
    for name, value in pairs(attributes) do header:SetAttribute(name, value) end
    for _, name in ipairs(Layout.FILTER_KEYS) do header:SetAttribute(name, filter[name]) end
    header:SetAttribute("_ignore", nil)
end

local function headerAttributes(s, size)
    local a = Layout.HeaderAttributes(s, size)
    a.template, a.templateType = Cell.TEMPLATE, "Button"
    a.showRaid, a.showParty, a.showPlayer, a.showSolo = true, general("showInParty") == true, true, false
    a.sortMethod = get("sortBy")
    return a
end

local function header(i)
    local h = Header.headers[i]
    if h then return h end
    h = CreateFrame("Frame", Header.NAME .. "Block" .. i, UIParent, "SecureGroupHeaderTemplate")
    h.key = Cell.KEY
    Header.headers[i] = h
    return h
end

local function decor(i)
    local d = Header.decor[i]
    if d then return d end
    d = CreateFrame("Frame", nil, Header.panel)
    d.title = d:CreateFontString(nil, "OVERLAY")
    Header.decor[i] = d
    return d
end

-- Cells holding a unit in header i (the Lua field each cell keeps).
function Header.Count(i)
    local h, n, k = Header.headers[i], 0, 1
    if not h then return 0 end
    while h:GetAttribute("child" .. k) do
        if h:GetAttribute("child" .. k).unit then n = n + 1 end
        k = k + 1
    end
    return n
end

local function liveCounts()
    local counts = {}
    for i in ipairs(Header.blocks) do counts[i] = Header.Count(i) end
    return counts
end

local function styleTitle(d, block, s)
    local title = d.title
    if s.titleHeight == 0 then
        title:Hide()
        return
    end
    local C = ns.Config
    ns.Texts.SetFont(title, ns.Media.Font(C.Get(ns.Party.KEY, "fontFace")), Header.TITLE_SIZE,
        C.Get(ns.Party.KEY, "fontOutline"))
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
    title:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, 0)
    title:SetHeight(s.titleHeight)
    title:SetJustifyH("CENTER")
    title:SetWordWrap(false)
    local c = Header.TITLE_COLOR
    title:SetTextColor(c[1], c[2], c[3], 1)
    title:SetText(Layout.Title(block))
    title:Show()
end

-- Out of combat: blocks to their places for the given number of cells
-- per block (the headers' own, or test mode's), titles and borders, the
-- panel over the occupied area. A block without room parks its empty
-- header below the panel: someone joining it in combat shows there
-- instead of on top of another block.
function Header.Place(counts)
    local s = Header.Shape()
    local hideEmpty = get("hideEmpty")
    local sizes = {}
    for i, block in ipairs(Header.blocks) do
        local room = Layout.Room(block, counts[i] or 0, hideEmpty)
        sizes[i] = room and { Layout.BlockSize(s, room) } or false
    end
    local positions, width, height = Layout.Arrange(s, sizes)
    local hx, hy = Layout.HeaderOffset(s)
    local parked = { x = 0, y = -(height + s.blockGap) }
    for i, block in ipairs(Header.blocks) do
        local pos, d = positions[i], decor(i)
        if pos then
            d:ClearAllPoints()
            d:SetPoint("TOPLEFT", Header.panel, "TOPLEFT", pos.x, pos.y)
            d:SetSize(sizes[i][1], sizes[i][2])
            styleTitle(d, block, s)
            Border.Draw(d, Header.BLOCK_SCOPE, d, 0)
            d:Show()
        else
            d:Hide()
        end
        local h = Header.headers[i]
        if h then
            local at = pos or parked
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", Header.anchor, "TOPLEFT", at.x + hx, at.y + hy)
        end
    end
    for i = #Header.blocks + 1, #Header.decor do Header.decor[i]:Hide() end
    Header.width, Header.height = width, height
    Header.panel:SetSize(math.max(width, 1), math.max(height, 1))
    if width > 0 then
        Border.Draw(Header.panel, Header.PANEL_SCOPE, Header.panel, 0)
    else
        Border.Hide(Header.panel)
    end
end

-- The panel's size, or a cell's while it is empty (the mover's handle).
function Header.Size()
    if (Header.width or 0) > 0 then return Header.width, Header.height end
    return ns.Single.Size(Cell.KEY)
end

-- The panel's top-left corner from the screen centre, on the pixel grid;
-- with a mover the anchor follows the mover.
local function placeAnchor()
    local anchor = Header.anchor
    anchor:SetSize(Header.Size())
    if anchor.mover then
        ns.Movers.Sync(anchor)
        return
    end
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", UIParent, "CENTER", Pixel.Snap(get("x")), Pixel.Snap(get("y")))
end

-- The mover (Core/Movers.lua): it holds the active size's x / y in the
-- raid profile, as the panel's top-left corner. Its label is Blizzard's
-- word for a raid and the size.
function Header.MoverSpec()
    return {
        scope = function() return ns.Raid.Scope(Cell.Size()) end, config = ns.RaidConfig, id = "raid",
        point = "TOPLEFT", origin = "TOPLEFT", size = Header.Size, active = Header.Enabled,
        label = function() return ("%s %d"):format(Layout.Title({ kind = "NONE" }), Cell.Size()) end,
    }
end

-- Any time, combat included: the panel's plain frames follow the group.
function Header.UpdateVisibility()
    if Header.panel then Header.panel:SetShown(Header.Active()) end
end

-- Out of combat only: the whole layout for the active size. Every header
-- shows again (Hide + Show lays its cells out anew, OnShow); the cells it
-- does not use lose their anchors (it only SetPoints the ones it shows).
function Header.Refresh()
    if not Header.anchor then return end
    local size = Cell.Size()
    Header.blocks = Layout.Blocks(get("groupBy"), size)
    local s = Header.Shape()
    for i, block in ipairs(Header.blocks) do
        setAttributes(header(i), headerAttributes(s, size), block.filter)
    end
    for _, button in ipairs(Cell.buttons) do
        Cell.Style(button)
        button:ClearAllPoints()
    end
    local on = Header.Enabled()
    for i, h in ipairs(Header.headers) do
        h:Hide()
        if on and i <= #Header.blocks then h:Show() end
    end
    Header.Place(liveCounts())
    placeAnchor()
    Header.UpdateVisibility()
end

-- Built once, out of combat, after the raid profile is attached.
function Header.Create()
    if Header.anchor then return Header.anchor end
    Header.anchor = CreateFrame("Frame", Header.NAME, UIParent)
    Header.anchor.key = Cell.KEY
    Header.panel = CreateFrame("Frame", nil, UIParent)
    Header.panel:SetPoint("TOPLEFT", Header.anchor, "TOPLEFT", 0, 0)
    Header.Refresh()
    ns.Movers.Attach(Header.anchor, Header.MoverSpec())
    return Header.anchor
end

local function refresh() ns.AfterCombat("raidLayout", Header.Refresh) end

-- Cells got or lost units. In combat: a cell made now needs its size and
-- the blocks their places, after combat. Out of combat: blocks are placed
-- once all headers are done, a moment later.
local placing = false
ns.Listen("RAID_CELLS_CHANGED", function()
    if not Header.anchor then return end
    if InCombatLockdown() then
        refresh()
        return
    end
    if placing then return end
    placing = true
    C_Timer.After(0, function()
        placing = false
        ns.AfterCombat("raidPlace", function()
            Header.Place(liveCounts())
            placeAnchor()
        end)
    end)
end)

ns.On("GROUP_ROSTER_UPDATE", Header.UpdateVisibility)
ns.Listen("RAID_SIZE_CHANGED", function() if Header.anchor then refresh() end end)
-- A setting of the active size or the character; another size's profile
-- does not show.
ns.Listen("RAID_CONFIG_CHANGED", function(scope)
    if not Header.anchor then return end
    if scope == nil or scope == "general" or scope == ns.Raid.Scope(Cell.Size()) then refresh() end
end)
-- The cells wear the party look.
ns.Listen("CONFIG_CHANGED", function(scope)
    if not Header.anchor then return end
    if scope == nil or scope == "general" or scope == ns.Party.KEY then refresh() end
end)
ns.Listen("PIXEL_GRID_CHANGED", function() if Header.anchor then refresh() end end)
```

- [ ] **Step 4: Load it**

In `ForeverUnitFrames.toc`, directly after the line `Raid\Cell.xml`, add:

```
Raid\Header.lua
```

- [ ] **Step 5: Run the tests**

Run: `tests/run raid_header.lua` → `74 passed, 0 failed`
Run: `tests/run raid_mover` → `17 passed, 0 failed`
Run: `tests/run` → Expected: `19218 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add Raid/Header.lua ForeverUnitFrames.toc tests/test_raid_header.lua tests/test_raid_mover.lua
git commit -m "Raid panel: one group header per block, placed by its cells; mover

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Build the raid panel at login

**Files:**
- Modify: `Core/Boot.lua` (end of the `PLAYER_LOGIN` handler; the comment R1 left there)
- Test: `tests/test_raid_frames_boot.lua`

**Interfaces:**
- Consumes: `ns.RaidProfiles.Attach`, `ns.RaidSize.Update` (R1), `ns.RaidHeader.Create` (Task 7).
- Produces: after `PLAYER_LOGIN` (or after combat, for a login in combat) the raid panel exists, built for the active size.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_frames_boot.lua`:

```lua
-- The raid frames at login (Core/Boot.lua): built after the raid profile
-- is attached and the size known, out of combat; a login in combat
-- builds them when combat ends.
local M = H.M
local ns = H.LoadAddon()
M.SetRaidRoster({
    { name = "Ann", class = "PRIEST", subgroup = 1, assignedRole = "HEALER" },
    { name = "Bob", class = "WARRIOR", subgroup = 2, assignedRole = "TANK" },
})
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
H.check("nothing before login", ns.RaidHeader.anchor, nil)
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.checkTrue("panel built", ns.RaidHeader.anchor)
H.check("size known when built", ns.RaidCell.Size(), 10)
H.check("group 1 cell", ns.RaidHeader.headers[1]:GetAttribute("child1").unit, "raid1")
H.check("group 2 cell", ns.RaidHeader.headers[2]:GetAttribute("child1").unit, "raid2")
H.checkTrue("panel shown in the raid", ns.RaidHeader.panel:IsShown())

-- A /reload in combat: built after combat, nothing blocked.
ns = H.LoadAddon()
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 } })
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.combat = true
M.FireEvent("PLAYER_LOGIN")
H.check("combat login: not yet", ns.RaidHeader.anchor, nil)
M.SetCombat(false)
H.checkTrue("combat login: built after combat", ns.RaidHeader.anchor)
H.check("combat login: nothing blocked", #M.blocked, 0)
H.check("combat login: cell", ns.RaidHeader.headers[1]:GetAttribute("child1").unit, "raid1")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run raid_frames_boot`
Expected: `FAIL panel built -> false (want true)`, `ERROR test_raid_frames_boot.lua:16: attempt to index field '?' (a nil value)`, `2 passed, 2 failed`

- [ ] **Step 3: Build after the profile and the size; correct the comment**

In `Core/Boot.lua`:

Replace

```lua
    ns.Single.CreateAll(afterBuild)
    ns.Blizzard.HideDefaults()
    ns.MinimapButton.Create()
    -- Raid profiles last: nothing above depends on them.
    ns.RaidProfiles.Attach(ForeverUnitFramesDB)
    ns.RaidSize.Update()
end)

ns.Listen("CONFIG_CHANGED", function()
```

with

```lua
    ns.Single.CreateAll(afterBuild)
    ns.Blizzard.HideDefaults()
    ns.MinimapButton.Create()
    -- The raid frames last: their profile, the active size, then the
    -- panel built from both (out of combat, like the unit frames). The
    -- unit frames above never read the raid profile.
    ns.RaidProfiles.Attach(ForeverUnitFramesDB)
    ns.RaidSize.Update()
    ns.AfterCombat("raidCreate", ns.RaidHeader.Create)
end)

ns.Listen("CONFIG_CHANGED", function()
```

- [ ] **Step 4: Run the tests**

Run: `tests/run raid_frames_boot` → `10 passed, 0 failed`
Run: `tests/run` → Expected: `19228 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Boot.lua tests/test_raid_frames_boot.lua
git commit -m "Build the raid panel at login

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## After the last task

- `./install "<AddOns folder of _classic_beta_>"`, `/reload` in game (new Lua and XML files load with `/reload`). No Lua error at login.
- Solo: nothing new shows (the panel is hidden outside a raid); `/fuf unlock` shows a handle "Raid 10" at the top-left position.
- In a raid (when available): blocks per group, gold panel border, cells with name and missing health centred, class-coloured health, mana strip on mana users. Look for: Blizzard's raid frames still show (hidden in R2b), cells made in combat have their size after combat.
- No release for R2a alone: it ships with R2b–R4 (0.22.0). R2b follows directly.
