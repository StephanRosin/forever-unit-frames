# Forever Unit Frames — Raid plan R4a: options menu and window

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The raid frames get their options window: `/fuf raid` opens a window in the unit frames' style with the raid sizes 10, 20 and 40 to edit (the size shown now is marked), the size switch (Automatic / 10 / 20 / 40), and seven tabs — General, Layout, Cell, Texts, Debuffs, Indicators, Icons & states — that reach every raid setting, in English, German, Spanish and French. Before the window, the settings it needs: sorting by role within a block, a class order for the class blocks, corner indicator spells by name from the player's spell book, and an import of one raid size that refuses a text without a raid size and counts what it could not read.

**Architecture:** `Raid/Options/Schema.lua` (`ns.RaidSchema`) is the raid menu: tabs, sections, the raid settings in them, and the raid's own words (`RAID_SETTING_<key>`, `RAID_HINT_…`, `RAID_SECTION_…`, `RAID_TAB_…`, `RAID_ENUM_…`; a raid key may share its name with a unit-frame setting of another meaning). `Raid/Options/Window.lua` (`ns.RaidOptions`) builds the window from the unit window's widgets (`Options/Widgets.lua`, `Options/Style.lua`) and two small exports of `Options/Window.lua` (`Options.Control`, `Options.ConfirmButton`); its rows read and write `ns.RaidConfig` in the edited size's scope (`general` for the character-wide settings). Typed class names become class tokens (`Raid.ParseClassOrder`), typed spell names the IDs of every rank in the spell book (`Raid/Spellbook.lua`). Sorting by role is the group headers' own grouping (`groupBy = "ASSIGNEDROLE"`), no snippets.

**Tech Stack:** Lua 5.1, WoW: Forever API (Interface 16001, build 1.60.1.70205), offline tests with `lua5.1` + `tests/mock.lua` (`tests/run`).

Spec: `docs/specs/2026-10-06-raid-frames-design.md` (part 1; §6 Options window, §4 grouping, §5 corner indicators, §3 storage). Raid plan order: R1 Foundation, R2a Headers, layout and cell, R2b Raid view in party, Blizzard's raid frames, test mode, R3a Debuffs and corner indicators, R3b Icons and states (all done) → **R4a Options menu and window (this plan)** → R4b Window actions, test mode for the edited size, entry points, wiki, release (`docs/plans/2026-10-06-plan-raid-4b-window-actions-wiki-release.md`).

Base: `main` at `2debd38` ("Raid cell: a cell that loses its unit points its auras at none"); `tests/run` there: `20213 passed, 0 failed`. Every task below was replayed in order on a scratch worktree of that commit; the outputs under "Expected" are what `tests/run` printed there.

## Global Constraints

- Everything in English: file names, identifiers, comments. Every new user-facing string is a locale key in all four languages, `Locales/enUS.lua`, `deDE.lua`, `esES.lua`, `frFR.lua` (`tests/test_locale.lua` requires each English key in every language with the same `%` placeholders); German in the style of the existing `deDE` strings.
- Target client: WoW: Forever, `## Interface: 16001`. Client facts only from the Forever UI source (game type `camelot`); the ones used are in the table below. Never write the name of the local lookup tool into the repository.
- The unit frames and their options window stay the same for users: no unit-frame setting, key, code, scope letter or default changes.
- Raid setting codes are permanent once released and unique within the raid registry; enums are stored by index, append only.
- No secret-value maths, comparisons or truth tests: a value that may be secret is checked with `ns.Secrets.IsSecret` (or `type(x) == "nil"`) before anything else touches it (the mock's secret is a table and would pass a truth test unnoticed). No secure snippets. Protected frames change only out of combat (`ns.AfterCombat`).
- `ns.On` throws on unknown event names in the client: no new game event is used (the ones below are in use already).
- The mock stays faithful: it may be stricter than the client source, never more permissive.
- Public repository: no local paths, host names, character names or anything about the author's machine in files or commit messages. Test names are neutral.
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
- Do not push. Every task ends with `tests/run` green and one commit (`git add` only the files the task lists).
- A full `tests/run` takes about a minute and a half and several GB of memory (as before).
- This plan adds one raid setting, per size: `classOrder` CO (text). `sortBy` gets a third value, `ROLE` (stored as 3).
- New locale keys (126): `IMPORT_RAID_NO_SIZE`, `IMPORT_SKIPPED` (Task 1); the raid menu's words (Task 5: 7 `RAID_TAB_*`, 22 `RAID_SECTION_*`, `RAID_NOTE_cell`, 46 `RAID_SETTING_*`, 15 `RAID_HINT_*`, 31 `RAID_ENUM_*`); `RAID_WINDOW_TITLE`, `RAID_SIZE_SHOWN` (Task 6). `HELP` changes in all four languages (Task 6: it names `/fuf raid`).
- One existing test is edited: `tests/test_raid_layout_settings.lua`'s "sort values" (Task 2: the enum gains `ROLE`).
- `Options/Window.lua` changes without changing the unit window: `enumItems` takes an optional word function (the unit frames' by default), and two functions are exported for the raid window (`Options.Control`, `Options.ConfirmButton`).
- New files and their place in `ForeverUnitFrames.toc`: `Raid\Spellbook.lua` after `Raid\Settings.lua`; `Raid\Options\Schema.lua` and `Raid\Options\Window.lua` after `Options\MinimapButton.lua`. `./install` and `tools/package` copy what the TOC lists, sub-folders included.
- Game events in use, none new: `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`. Internal events used: `RAID_CONFIG_CHANGED`, `RAID_SIZE_CHANGED`, `LANGUAGE_CHANGED`.

## Client facts this plan relies on (build 1.60.1.70205)

Paths below `Interface/AddOns/`; `Doc/` = `Blizzard_APIDocumentationGenerated/`.

| Fact | Source |
|---|---|
| `C_SpellBook.GetNumSpellBookSkillLines() -> number`; `GetSpellBookSkillLineInfo(index) -> { name, iconID, itemIndexOffset, numSpellBookItems, isGuild, shouldHide, ... }` (may return nothing; slot `itemIndexOffset + 1` is the line's first); `GetSpellBookItemInfo(slot, bank) -> { actionID, spellID?, itemType, name, subName, iconID, isPassive, isOffSpec, skillLineIndex? }` (may return nothing). None is documented as secret (`SecretArguments = "AllowedWhenUntainted"` only) | `Doc/SpellBookDocumentation.lua` |
| `Enum.SpellBookSpellBank`: Player 0, Pet 1; `Enum.SpellBookItemType`: None 0, Spell 1, FutureSpell 2, PetAction 3, Flyout 4 | `Doc/SpellBookConstantsDocumentation.lua` |
| Every rank of a spell is a spell book item of its own; Blizzard's spell book window only hides the low ranks (`C_SpellBook.IsSpellBookItemLowRank`, CVar `ShowAllSpellRanks`) | `Blizzard_PlayerSpells/SpellBook/Blizzard_SpellBookFrame.lua` (`ShouldDisplaySpellBookItem`) |
| A group header with `groupBy` sorts its units by the place of their group key in `groupingOrder`, then by `sortMethod` within (`NAME`, else the unit's index); `groupBy = "ASSIGNEDROLE"` keys by the assigned role from `GetRaidRosterInfo` (in a party `UnitGroupRolesAssigned`). `sortMethod` takes `INDEX`, `NAME`, `NAMELIST` | `Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua` (`SecureGroupHeader_Update`, `GetGroupRosterInfo`) |
| The assigned role is secret while the unit's identity is restricted (`UnitGroupRolesAssigned`: `SecretWhenUnitIdentityRestricted`): the header looks it up itself, as for R2a's role blocks; whether it sorts in a restricted raid is an in-game check | `Doc/UnitDocumentation.lua` |
| `CLASS_SORT_ORDER` (this game type's nine classes), `LOCALIZED_CLASS_NAMES_MALE` / `LOCALIZED_CLASS_NAMES_FEMALE` (token → the game's class name) | `Blizzard_FrameXMLBase/Camelot/Constants.lua`, `Blizzard_FrameXMLBase/Constants.lua` |

## Design decisions

- **Import of one size** (a must-fix carried over from the earlier reviews): a text without any raid-size entry is refused (`RAID_NO_SIZE`) unless it is exactly what a size at the defaults exports — the format version alone, `"1"` — which resets the size. On success `Import` returns `true` and the codec's `rejected` count, which the window (R4b) shows.
- **Sort by role:** `sortBy = ROLE` makes every block but a role block group by assigned role (`groupBy = "ASSIGNEDROLE"`, `groupingOrder = "TANK,HEALER,DAMAGER,NONE"`), raid order within; in the single block this replaces the order by group. The header's `sortMethod` is `NAME` or `INDEX` (never the setting's `ROLE`). Test mode sorts its pretend members the same way.
- **Class order:** a text of class tokens, commas or spaces, each once (`check`), empty for Blizzard's order; the classes not named follow in Blizzard's order, so a partial order is enough. The window turns what is typed — tokens in any case, or the game's class names, between commas — into tokens (`Raid.ParseClassOrder`) and refuses unknown classes. Room for 100 letters.
- **Spell names:** the window turns names into the IDs of every rank of that name the player has learned (spell book items of type Spell, case ignored), IDs typed stay as they are; an unknown name is refused (the field flashes). Stored are IDs only, so the cells and R3a's `Raid.SpellList` are unchanged. A name is read only when typed, never in combat paths. A spell learned later (a new rank) needs the name typed again: an in-game note, not automated.
- **The menu:** General (raid frames on/off, raid view in a party, hide Blizzard's raid frames), Layout (grouping, sorting, class order, empty blocks, titles; arrangement; position; the three borders), Cell (size; health colour and power strip — bar texture, font and heal colours follow the party frame, a note says so), Texts, Debuffs, Indicators (one section per position), Icons & states (icon size; each icon's switch and point; range, aggro, target). `sizeMode` sits in the header bar. A test pins down that every raid setting is reachable exactly once.
- **Words:** the five indicator positions share their row labels (the section names the position), the icons share "Show" / "Position"; points use the unit frames' words (`ENUM_TOPLEFT`, …). Labels fit the label column in every language, hints are no longer than the unit frames' longest English hint (as `tests/test_locale.lua` checks for the unit frames).
- **The window:** 780 × 560 like the unit window, no navigation column: title bar, header bar (size tabs, the shown one says "(shown)"; the size switch at the right), tab row, combat notice, scroll area, footer (filled in R4b). Pages are built once per tab; their rows read the edited size whenever they refresh. Locked in combat like the unit window (rows and the size switch; the size tabs stay usable). Its own position in `ForeverUnitFramesDB.raidWindow`. A new language builds a new window on the same size and tab.
- **Mock carry-over:** the mock's `SetAllPoints` only stores a flag and `ClearAllPoints` does not clear it (more permissive than the client); no task relies on `SetAllPoints` anchors, so it stays as it is.

---

### Task 1: Raid import: refuse a text without a raid size, count what was left out

**Files:**
- Modify: `Raid/Profiles.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_raid_import.lua`

**Interfaces:**
- Consumes: `ns.RaidCodec.Decode(str)` → profile, nil, rejected (or nil, errorKey); `ns.RaidCodec.VERSION`; `ns.RaidConfig.CopyScopeFrom`, `ResetScope`; `ns.Raid.Scope`, `ns.Raid.SIZES`.
- Produces: `ns.RaidProfiles.Import(str, size)` → `true, skipped` (entries the codec could not read) or `nil, errorKey` (`CODEC_EMPTY`, `CODEC_FORMAT`, `CODEC_VERSION`, or `RAID_NO_SIZE`); locale keys `IMPORT_RAID_NO_SIZE`, `IMPORT_SKIPPED` (one `%d`).

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_import.lua`:

```lua
-- Importing one raid size (Raid/Profiles.lua): a string must hold a raid
-- size, or be exactly the string of a size left at the defaults; what the
-- codec could not read is counted and handed back.
local ns = H.LoadAddon()
local RC, P, L = ns.RaidConfig, ns.RaidProfiles, ns.L
P.Attach({})

-- A size's export goes on, nothing skipped.
RC.Set("r20", "cellWidth", 120)
local ok, skipped = P.Import(P.Export(20), 10)
H.check("export imports", ok, true)
H.check("nothing skipped", skipped, 0)
H.check("imported", RC.Get("r10", "cellWidth"), 120)

-- The defaults string resets the size.
RC.Set("r40", "cellWidth", 150)
ok, skipped = P.Import("1", 40)
H.check("defaults string imports", ok, true)
H.check("defaults string: nothing skipped", skipped, 0)
H.check("defaults string resets", RC.Get("r40", "cellWidth"), 80)

-- Anything else without a size is refused, and the size kept.
RC.Set("r40", "cellWidth", 150)
local err
ok, err = P.Import("1;gSM2", 40)
H.check("only character-wide entries: refused", ok, nil)
H.check("refused: no size", err, "RAID_NO_SIZE")
ok, err = P.Import("1;zzz", 40)
H.check("unreadable entries only: refused", ok, nil)
H.check("refused: no size either", err, "RAID_NO_SIZE")
ok, err = P.Import("1;", 40)
H.check("an empty entry is not the defaults string", ok, nil)
H.check("size kept after a refusal", RC.Get("r40", "cellWidth"), 150)
H.check("a codec error stays the codec's", select(2, P.Import("garbage", 40)), "CODEC_FORMAT")

-- Entries the codec could not read are counted.
ok, skipped = P.Import("1;aCW100;aCWx;aZZ1;junk", 20)
H.check("readable part imports", ok, true)
H.check("unreadable entries counted", skipped, 2)
H.check("readable part applied", RC.Get("r20", "cellWidth"), 100)

-- The messages for the window.
H.check("no-size message", L.IMPORT_RAID_NO_SIZE, "This text holds no raid size.")
H.check("skipped message", L.IMPORT_SKIPPED:format(2), "Imported; 2 entries could not be read and were left out.")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_import.lua`

Expected:

```text
test_raid_import.lua
  FAIL nothing skipped -> nil (want 0)
  FAIL defaults string: nothing skipped -> nil (want 0)
  FAIL only character-wide entries: refused -> true (want nil)
  FAIL refused: no size -> nil (want RAID_NO_SIZE)
  FAIL unreadable entries only: refused -> true (want nil)
  FAIL refused: no size either -> nil (want RAID_NO_SIZE)
  FAIL an empty entry is not the defaults string -> true (want nil)
  FAIL size kept after a refusal -> 80 (want 150)
  FAIL unreadable entries counted -> nil (want 2)
  FAIL no-size message -> IMPORT_RAID_NO_SIZE (want This text holds no raid size.)
  FAIL skipped message -> IMPORT_SKIPPED (want Imported; 2 entries could not be read and were left out.)
7 passed, 11 failed
```

- [ ] **Step 3: Refuse a text without a raid size**

In `Raid/Profiles.lua`:

Replace

```lua
end

-- Puts an exported size on `size`, replacing everything that size had.
-- The first size found in the string counts (an export holds one); a
-- string with none is a size left at the defaults. Returns true, or nil
-- and the codec's error key.
function Profiles.Import(str, size)
    local decoded, err = RaidCodec.Decode(str)
    if not decoded then return nil, err end
    local target = Raid.Scope(size)
    for _, s in ipairs(Raid.SIZES) do
        local scope = Raid.Scope(s)
        if next(decoded[scope]) then
            RaidConfig.CopyScopeFrom(decoded, scope, target)
            return true
        end
    end
    RaidConfig.ResetScope(target)
    return true
end
```

with

```lua
end

-- Puts an exported size on `size`, replacing everything that size had.
-- The first size found in the string counts (an export holds one). A
-- string without any is refused (RAID_NO_SIZE), unless it is exactly
-- what a size left at the defaults exports: the format version alone,
-- which resets the size. Returns true and how many entries the codec
-- could not read (they are left out); or nil and an error key.
function Profiles.Import(str, size)
    local decoded, err, rejected = RaidCodec.Decode(str)
    if not decoded then return nil, err end
    local target = Raid.Scope(size)
    for _, s in ipairs(Raid.SIZES) do
        local scope = Raid.Scope(s)
        if next(decoded[scope]) then
            RaidConfig.CopyScopeFrom(decoded, scope, target)
            return true, rejected
        end
    end
    if str ~= tostring(RaidCodec.VERSION) then return nil, "RAID_NO_SIZE" end
    RaidConfig.ResetScope(target)
    return true, rejected
end
```

- [ ] **Step 4: The messages in English**

Append to the end of `Locales/enUS.lua`:

```lua

-- Raid frames: importing one raid size.
L.IMPORT_RAID_NO_SIZE = "This text holds no raid size."
L.IMPORT_SKIPPED = "Imported; %d entries could not be read and were left out."
```

- [ ] **Step 5: German**

Append to the end of `Locales/deDE.lua`:

```lua

-- Schlachtzugsrahmen: eine Schlachtzugsgröße importieren.
L.IMPORT_RAID_NO_SIZE = "Dieser Text enthält keine Schlachtzugsgröße."
L.IMPORT_SKIPPED = "Importiert; %d Einträge waren nicht lesbar und wurden ausgelassen."
```

- [ ] **Step 6: Spanish**

Append to the end of `Locales/esES.lua`:

```lua

-- Marcos de banda: importar un tamaño de banda.
L.IMPORT_RAID_NO_SIZE = "Este texto no contiene ningún tamaño de banda."
L.IMPORT_SKIPPED = "Importado; %d entradas no se pudieron leer y se omitieron."
```

- [ ] **Step 7: French**

Append to the end of `Locales/frFR.lua`:

```lua

-- Cadres de raid : importer une taille de raid.
L.IMPORT_RAID_NO_SIZE = "Ce texte ne contient aucune taille de raid."
L.IMPORT_SKIPPED = "Importé ; %d entrées illisibles ont été ignorées."
```

- [ ] **Step 8: Run the tests**

Run: `tests/run test_raid_import.lua` → `18 passed, 0 failed`
Run: `tests/run` → Expected: `20249 passed, 0 failed`

- [ ] **Step 9: Commit**

```bash
git add Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Raid/Profiles.lua tests/test_raid_import.lua
git commit -m "Raid import: refuse a string without a raid size, count what was left out

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Raid: sort by role within a block

**Files:**
- Modify: `Raid/Settings.lua`
- Modify: `Raid/Layout.lua`
- Modify: `Raid/Header.lua`
- Modify: `Raid/TestMode.lua`
- Test: `tests/test_raid_layout_settings.lua` (existing; its "sort values" pins the enum, which gains `ROLE`)
- Test: `tests/test_raid_sort_role.lua`

**Interfaces:**
- Consumes: `ns.RaidSettings` (`sortBy`), `ns.RaidLayout.Blocks`, `Raid/Header.lua`'s `headerAttributes` and `Header.Refresh`, `ns.RaidTestMode.Distribute`, `ns.RaidTestMode.Members`.
- Produces: `sortBy` values `INDEX`, `NAME`, `ROLE` (3); `ns.RaidLayout.ROLE_ORDER = "TANK,HEALER,DAMAGER,NONE"`; `ns.RaidLayout.Blocks(groupBy, size, sortBy)` (ROLE: `filter.groupBy = "ASSIGNEDROLE"`, `filter.groupingOrder = ROLE_ORDER` on every block but a role block); the header's `sortMethod` is `NAME` or `INDEX`; `ns.RaidTestMode.Distribute(blocks, members, size, sortBy)` — the fourth argument is now the setting (`"INDEX"`, `"NAME"`, `"ROLE"`), no longer a boolean.

- [ ] **Step 1: Write the failing tests**

In `tests/test_raid_layout_settings.lua`:

Replace

```lua

local function values(key) return table.concat(RS.Get(key).values, ",") end
H.check("grouping values", values("groupBy"), "GROUP,CLASS,ROLE,NONE")
H.check("sort values", values("sortBy"), "INDEX,NAME")
H.check("direction values", values("blockDirection"), "HORIZONTAL,VERTICAL")
H.check("growth values", values("cellGrowth"), "DOWN,RIGHT")
H.check("health colour values", values("healthColorMode"), "CLASS,STATIC,GRADIENT")
```

with

```lua

local function values(key) return table.concat(RS.Get(key).values, ",") end
H.check("grouping values", values("groupBy"), "GROUP,CLASS,ROLE,NONE")
H.check("sort values", values("sortBy"), "INDEX,NAME,ROLE")
H.check("direction values", values("blockDirection"), "HORIZONTAL,VERTICAL")
H.check("growth values", values("cellGrowth"), "DOWN,RIGHT")
H.check("health colour values", values("healthColorMode"), "CLASS,STATIC,GRADIENT")
```

Create `tests/test_raid_sort_role.lua`:

```lua
-- Sorting by role within a block (Raid/Layout.lua, Raid/Header.lua,
-- Raid/TestMode.lua): tanks, healers, damage, then members without a
-- role, each in raid order; the headers group by the assigned role.
local M = H.M
local ns = H.LoadAddon()
local RC, Layout, Header, Test = ns.RaidConfig, ns.RaidLayout, ns.RaidHeader, ns.RaidTestMode
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

-- The setting: ROLE appended to the enum.
H.check("sort choices", table.concat(ns.RaidSettings.Get("sortBy").values, ","), "INDEX,NAME,ROLE")
RC.Set("r10", "sortBy", "ROLE")
H.check("stored by index", ns.RaidProfiles.Export(10), "1;aSO3")

-- The blocks: every block but a role block groups by the assigned role.
H.check("role order", Layout.ROLE_ORDER, "TANK,HEALER,DAMAGER,NONE")
local group = Layout.Blocks("GROUP", 10, "ROLE")[1].filter
H.check("group block: by role", group.groupBy, "ASSIGNEDROLE")
H.check("group block: role order", group.groupingOrder, "TANK,HEALER,DAMAGER,NONE")
H.check("group block: still its group", group.groupFilter, "1")
local class = Layout.Blocks("CLASS", 10, "ROLE")[1].filter
H.check("class block: by role", class.groupBy, "ASSIGNEDROLE")
H.check("class block: still strict", class.strictFiltering, true)
local all = Layout.Blocks("NONE", 20, "ROLE")[1].filter
H.check("one block: by role instead of group", all.groupBy, "ASSIGNEDROLE")
H.check("one block: role order", all.groupingOrder, "TANK,HEALER,DAMAGER,NONE")
H.check("one block: still the size's groups", all.groupFilter, "1,2,3,4")
H.check("role block: one role already", Layout.Blocks("ROLE", 10, "ROLE")[1].filter.groupBy, nil)
H.check("raid order: no grouping", Layout.Blocks("GROUP", 10, "INDEX")[1].filter.groupBy, nil)
H.check("no sort given: no grouping", Layout.Blocks("GROUP", 10)[1].filter.groupBy, nil)

-- The headers: a group in raid order of damage, healer, tank, nobody,
-- damage shows tank, healer, damage, damage, nobody.
Header.Create()
M.SetRaidRoster({
    { name = "Dps", class = "MAGE", subgroup = 1, assignedRole = "DAMAGER" },
    { name = "Heal", class = "PRIEST", subgroup = 1, assignedRole = "HEALER" },
    { name = "Tank", class = "WARRIOR", subgroup = 1, assignedRole = "TANK" },
    { name = "Nobody", class = "ROGUE", subgroup = 1 },
    { name = "Dps2", class = "HUNTER", subgroup = 1, assignedRole = "DAMAGER" },
})
M.RunTimers()
local h1 = Header.headers[1]
H.check("header groups by role", h1:GetAttribute("groupBy"), "ASSIGNEDROLE")
H.check("header: within a role, raid order", h1:GetAttribute("sortMethod"), "INDEX")
local order = {}
for i = 1, 5 do order[i] = h1:GetAttribute("child" .. i).unit end
H.check("cells by role", table.concat(order, ","), "raid3,raid2,raid1,raid5,raid4")
RC.Set("r10", "sortBy", "NAME")
H.check("by name: no grouping", h1:GetAttribute("groupBy"), nil)
H.check("by name: header sorts names", h1:GetAttribute("sortMethod"), "NAME")
RC.Set("r10", "sortBy", "INDEX")
H.check("raid order", h1:GetAttribute("sortMethod"), "INDEX")

-- Test mode places its pretend members the same way.
local members = Test.Members(10)
local function indices(list)
    local out = {}
    for i, entry in ipairs(list) do out[i] = entry.index end
    return table.concat(out, ",")
end
local lists = Test.Distribute(Layout.Blocks("GROUP", 10, "ROLE"), members, 10, "ROLE")
H.check("test mode: group 1 by role", indices(lists[1]), "1,2,3,4,5")
H.check("test mode: group 2 by role", indices(lists[2]), "6,7,9,8,10")
lists = Test.Distribute(Layout.Blocks("NONE", 10, "ROLE"), members, 10, "ROLE")
H.check("test mode: one block by role", indices(lists[1]), "1,2,6,7,9,3,4,5,8,10")
lists = Test.Distribute(Layout.Blocks("NONE", 10, "INDEX"), members, 10, "INDEX")
H.check("test mode: one block by group", indices(lists[1]), "1,2,3,4,5,6,7,8,9,10")
lists = Test.Distribute(Layout.Blocks("GROUP", 10, "NAME"), members, 10, "NAME")
H.check("test mode: by name", indices(lists[1]), "5,3,2,4,1")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run test_raid_layout_settings.lua`

Expected:

```text
test_raid_layout_settings.lua
  FAIL sort values -> INDEX,NAME (want INDEX,NAME,ROLE)
185 passed, 1 failed
```

Run: `tests/run test_raid_sort_role.lua`

Expected:

```text
test_raid_sort_role.lua
  FAIL sort choices -> INDEX,NAME (want INDEX,NAME,ROLE)
  FAIL stored by index -> 1 (want 1;aSO3)
  FAIL role order -> nil (want TANK,HEALER,DAMAGER,NONE)
  FAIL group block: by role -> nil (want ASSIGNEDROLE)
  FAIL group block: role order -> nil (want TANK,HEALER,DAMAGER,NONE)
  FAIL class block: by role -> nil (want ASSIGNEDROLE)
  FAIL one block: by role instead of group -> GROUP (want ASSIGNEDROLE)
  FAIL one block: role order -> 1,2,3,4 (want TANK,HEALER,DAMAGER,NONE)
  FAIL header groups by role -> nil (want ASSIGNEDROLE)
  FAIL cells by role -> raid1,raid2,raid3,raid4,raid5 (want raid3,raid2,raid1,raid5,raid4)
  FAIL test mode: group 1 by role -> 5,3,2,4,1 (want 1,2,3,4,5)
  FAIL test mode: group 2 by role -> 7,6,9,8,10 (want 6,7,9,8,10)
  FAIL test mode: one block by role -> 5,3,2,4,1,7,6,9,8,10 (want 1,2,6,7,9,3,4,5,8,10)
  FAIL test mode: one block by group -> 5,3,2,4,1,7,6,9,8,10 (want 1,2,3,4,5,6,7,8,9,10)
11 passed, 14 failed
```

- [ ] **Step 3: Append ROLE to the setting**

In `Raid/Settings.lua`:

Replace

```lua
-- block for everyone. Stored by index: append only.
RaidSettings.Define({ key = "groupBy", code = "GB", scope = "frame", type = "enum",
    values = { "GROUP", "CLASS", "ROLE", "NONE" }, default = "GROUP" })
-- Order within a block: raid order or name.
RaidSettings.Define({ key = "sortBy", code = "SO", scope = "frame", type = "enum",
    values = { "INDEX", "NAME" }, default = "INDEX" })
-- Blocks side by side (a row of blocks) or stacked (a column), wrapping
-- after blocksPerLine.
RaidSettings.Define({ key = "blockDirection", code = "BD", scope = "frame", type = "enum",
```

with

```lua
-- block for everyone. Stored by index: append only.
RaidSettings.Define({ key = "groupBy", code = "GB", scope = "frame", type = "enum",
    values = { "GROUP", "CLASS", "ROLE", "NONE" }, default = "GROUP" })
-- Order within a block: raid order, name, or role (tanks, healers,
-- damage, the rest; each in raid order).
RaidSettings.Define({ key = "sortBy", code = "SO", scope = "frame", type = "enum",
    values = { "INDEX", "NAME", "ROLE" }, default = "INDEX" })
-- Blocks side by side (a row of blocks) or stacked (a column), wrapping
-- after blocksPerLine.
RaidSettings.Define({ key = "blockDirection", code = "BD", scope = "frame", type = "enum",
```

- [ ] **Step 4: Blocks group by role**

In `Raid/Layout.lua`:

Replace

```lua
ns.RaidLayout = Layout

Layout.ROLES = { "TANK", "HEALER", "DAMAGER" }
-- Every filter attribute a block may set; the others are cleared.
Layout.FILTER_KEYS = { "groupFilter", "roleFilter", "strictFiltering", "groupBy", "groupingOrder" }
-- A group never holds more than five.
```

with

```lua
ns.RaidLayout = Layout

Layout.ROLES = { "TANK", "HEALER", "DAMAGER" }
-- Sorted by role within a block: the assigned roles in this order, those
-- without one last.
Layout.ROLE_ORDER = "TANK,HEALER,DAMAGER,NONE"
-- Every filter attribute a block may set; the others are cleared.
Layout.FILTER_KEYS = { "groupFilter", "roleFilter", "strictFiltering", "groupBy", "groupingOrder" }
-- A group never holds more than five.
```

In `Raid/Layout.lua`:

Replace

```lua
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
```

with

```lua
        "HUNTER" }
end

-- Sorted by role: the header groups its members by assigned role (a role
-- block holds one role already). In the single block this replaces the
-- order by group.
local function sortByRole(blocks)
    for _, block in ipairs(blocks) do
        if block.kind ~= "ROLE" then
            block.filter.groupBy, block.filter.groupingOrder = "ASSIGNEDROLE", Layout.ROLE_ORDER
        end
    end
end

-- The blocks of a grouping: { kind, id, capacity (groups only), filter }.
-- Each block keeps to the size's groups. A class or role block filters
-- strictly: group and class (and role) must all match. Members without
-- an assigned role count as damage. sortBy (the setting, optional):
-- ROLE sorts by role within each block.
function Layout.Blocks(groupBy, size, sortBy)
    local groups = joined(Layout.Groups(size))
    local blocks = {}
    if groupBy == "GROUP" then
```

In `Raid/Layout.lua`:

Replace

```lua
        blocks[1] = { kind = "NONE", id = "ALL",
            filter = { groupFilter = groups, groupBy = "GROUP", groupingOrder = groups } }
    end
    return blocks
end

```

with

```lua
        blocks[1] = { kind = "NONE", id = "ALL",
            filter = { groupFilter = groups, groupBy = "GROUP", groupingOrder = groups } }
    end
    if sortBy == "ROLE" then sortByRole(blocks) end
    return blocks
end

```

- [ ] **Step 5: The header's sort method and blocks**

In `Raid/Header.lua`:

Replace

```lua
    local a = Layout.HeaderAttributes(s, size)
    a.template, a.templateType = Cell.TEMPLATE, "Button"
    a.showRaid, a.showParty, a.showPlayer, a.showSolo = true, general("showInParty") == true, true, false
    a.sortMethod = get("sortBy")
    return a
end

```

with

```lua
    local a = Layout.HeaderAttributes(s, size)
    a.template, a.templateType = Cell.TEMPLATE, "Button"
    a.showRaid, a.showParty, a.showPlayer, a.showSolo = true, general("showInParty") == true, true, false
    -- By role: the blocks group by role (Raid/Layout.lua), raid order within.
    a.sortMethod = get("sortBy") == "NAME" and "NAME" or "INDEX"
    return a
end

```

In `Raid/Header.lua`:

Replace

```lua
function Header.Refresh()
    if not Header.anchor then return end
    local size = Cell.Size()
    Header.blocks = Layout.Blocks(get("groupBy"), size)
    local s = Header.Shape()
    for i, block in ipairs(Header.blocks) do
        setAttributes(header(i), headerAttributes(s, size), block.filter)
```

with

```lua
function Header.Refresh()
    if not Header.anchor then return end
    local size = Cell.Size()
    Header.blocks = Layout.Blocks(get("groupBy"), size, get("sortBy"))
    local s = Header.Shape()
    for i, block in ipairs(Header.blocks) do
        setAttributes(header(i), headerAttributes(s, size), block.filter)
```

- [ ] **Step 6: Test mode sorts its pretend members the same way**

In `Raid/TestMode.lua`:

Replace

```lua
    return list
end

-- Members into blocks, as the headers would sort them: by raid order or
-- by name, the single block by group first.
function Test.Distribute(blocks, members, size, byName)
    local lists = {}
    for b, block in ipairs(blocks) do
        local list = {}
```

with

```lua
    return list
end

-- What a block's header groups its members by (its filter's groupBy),
-- as a rank: the group, or the place of the assigned role; 0 without.
local ROLE_RANK, rank = {}, 0
for role in Layout.ROLE_ORDER:gmatch("[^,]+") do
    rank = rank + 1
    ROLE_RANK[role] = rank
end
local function groupRank(block, member)
    local by = block.filter.groupBy
    if by == "GROUP" then return member.subgroup end
    if by == "ASSIGNEDROLE" then return ROLE_RANK[member.assignedRole or "NONE"] end
    return 0
end

-- Members into blocks, as the headers would sort them (sortBy: the
-- setting): grouped as the block's header groups them, then by name or
-- raid order.
function Test.Distribute(blocks, members, size, sortBy)
    local lists = {}
    for b, block in ipairs(blocks) do
        local list = {}
```

In `Raid/TestMode.lua`:

Replace

```lua
            if Layout.Matches(block, m, size) then list[#list + 1] = { index = i, member = m } end
        end
        table.sort(list, function(x, y)
            if block.kind == "NONE" and x.member.subgroup ~= y.member.subgroup then
                return x.member.subgroup < y.member.subgroup
            end
            if byName and x.member.name ~= y.member.name then return x.member.name < y.member.name end
            return x.index < y.index
        end)
        lists[b] = list
```

with

```lua
            if Layout.Matches(block, m, size) then list[#list + 1] = { index = i, member = m } end
        end
        table.sort(list, function(x, y)
            local rx, ry = groupRank(block, x.member), groupRank(block, y.member)
            if rx ~= ry then return rx < ry end
            if sortBy == "NAME" and x.member.name ~= y.member.name then return x.member.name < y.member.name end
            return x.index < y.index
        end)
        lists[b] = list
```

In `Raid/TestMode.lua`:

Replace

```lua
-- the headers' cells.
function Test.Show()
    local size = Cell.Size()
    local byName = ns.RaidConfig.Get(ns.Raid.Scope(size), "sortBy") == "NAME"
    local lists = Test.Distribute(Header.blocks, Test.Members(size), size, byName)
    local counts = {}
    for b, list in ipairs(lists) do counts[b] = #list end
    local positions, s = Header.Place(counts)
```

with

```lua
-- the headers' cells.
function Test.Show()
    local size = Cell.Size()
    local sortBy = ns.RaidConfig.Get(ns.Raid.Scope(size), "sortBy")
    local lists = Test.Distribute(Header.blocks, Test.Members(size), size, sortBy)
    local counts = {}
    for b, list in ipairs(lists) do counts[b] = #list end
    local positions, s = Header.Place(counts)
```

- [ ] **Step 7: Run the tests**

Run: `tests/run test_raid_layout_settings.lua` → `186 passed, 0 failed`
Run: `tests/run test_raid_sort_role.lua` → `25 passed, 0 failed`
Run: `tests/run` → Expected: `20274 passed, 0 failed`

- [ ] **Step 8: Commit**

```bash
git add Raid/Header.lua Raid/Layout.lua Raid/Settings.lua Raid/TestMode.lua tests/test_raid_layout_settings.lua tests/test_raid_sort_role.lua
git commit -m "Raid: sort by role within a block

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Raid: the class blocks' order is configurable

**Files:**
- Modify: `Raid/Settings.lua`
- Modify: `Raid/Layout.lua`
- Modify: `Raid/Header.lua`
- Test: `tests/test_raid_class_order.lua`

**Interfaces:**
- Consumes: `ns.RaidSettings.Define` (text with `check`, `maxLetters`), `ns.RaidLayout.Blocks` (Task 2), `CLASS_SORT_ORDER`, `LOCALIZED_CLASS_NAMES_MALE` / `_FEMALE`.
- Produces: `classOrder` CO (text, per size, default `""`, room for `Raid.CLASS_ORDER_LETTERS = 100` letters, only class tokens, each once); `ns.Raid.Classes()` (Blizzard's class order); `ns.Raid.ParseClassOrder(text)` → tokens joined by commas, `""` for an empty text, nil for an unknown or repeated class (tokens in any case or the game's class names, between commas); `ns.RaidLayout.Classes(order)`; `ns.RaidLayout.Blocks(groupBy, size, sortBy, classOrder)`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_class_order.lua`:

```lua
-- The order of the class blocks (Raid/Settings.lua classOrder,
-- Raid/Layout.lua): the classes named first, the others after them in
-- Blizzard's order; empty is Blizzard's order.
local M = H.M
local ns = H.LoadAddon()
local Raid, RS, RC, Layout, Header, Test = ns.Raid, ns.RaidSettings, ns.RaidConfig, ns.RaidLayout, ns.RaidHeader,
    ns.RaidTestMode
ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

local def = RS.Get("classOrder")
H.checkTrue("defined", def)
H.check("code", def and def.code, "CO")
H.check("text", def and def.type, "text")
H.check("per size", def and RS.AppliesTo(def, "r20"), true)
H.check("not character-wide", def and RS.AppliesTo(def, "general"), false)
H.check("default: Blizzard's order", RC.Get("r10", "classOrder"), "")

-- Only class tokens, each once.
H.checkTrue("tokens", RC.Set("r10", "classOrder", "PRIEST,DRUID"))
H.check("stored", RC.Get("r10", "classOrder"), "PRIEST,DRUID")
H.checkTrue("spaces too", RC.Set("r20", "classOrder", "MAGE SHAMAN"))
H.check("unknown class refused", RC.Set("r10", "classOrder", "PRIEST,MONK"), false)
H.check("lower case refused", RC.Set("r10", "classOrder", "priest"), false)
H.check("twice refused", RC.Set("r10", "classOrder", "PRIEST,DRUID,PRIEST"), false)
H.check("kept after refusals", RC.Get("r10", "classOrder"), "PRIEST,DRUID")
H.check("exported", ns.RaidProfiles.Export(10), "1;aCO'PRIEST,DRUID")

-- The class list: named classes first, the rest in Blizzard's order.
H.check("Blizzard's order", table.concat(Layout.Classes(""), ","), table.concat(CLASS_SORT_ORDER, ","))
H.check("named first", table.concat(Layout.Classes("PRIEST,DRUID"), ","),
    "PRIEST,DRUID,WARRIOR,PALADIN,SHAMAN,ROGUE,MAGE,WARLOCK,HUNTER")
H.check("spaces", table.concat(Layout.Classes("MAGE SHAMAN"), ",", 1, 2), "MAGE,SHAMAN")
H.check("no order given", #Layout.Classes(nil), 9)
local function ids(blocks)
    local list = {}
    for i, b in ipairs(blocks) do list[i] = b.id end
    return table.concat(list, ",")
end
H.check("class blocks in the given order", ids(Layout.Blocks("CLASS", 10, "INDEX", "PRIEST,DRUID")),
    "PRIEST,DRUID,WARRIOR,PALADIN,SHAMAN,ROGUE,MAGE,WARLOCK,HUNTER")
H.check("first block's filter", Layout.Blocks("CLASS", 10, "INDEX", "PRIEST,DRUID")[1].filter.groupFilter,
    "1,2,PRIEST")

-- What the options window turns into tokens: tokens in any case, or the
-- game's class names.
H.check("parse tokens", Raid.ParseClassOrder("priest, Druid"), "PRIEST,DRUID")
H.check("parse empty", Raid.ParseClassOrder("  "), "")
H.check("parse unknown", Raid.ParseClassOrder("Priest, Monk"), nil)
H.check("parse twice", Raid.ParseClassOrder("Priest, priest"), nil)
local male, female = LOCALIZED_CLASS_NAMES_MALE.PRIEST, LOCALIZED_CLASS_NAMES_FEMALE
LOCALIZED_CLASS_NAMES_MALE.PRIEST = "Priester"
_G.LOCALIZED_CLASS_NAMES_FEMALE = { PRIEST = "Priesterin" }
H.check("parse class names", Raid.ParseClassOrder("priester; Druid"), nil)
H.check("parse class names, commas", Raid.ParseClassOrder("priester, Druid"), "PRIEST,DRUID")
H.check("parse female class names", Raid.ParseClassOrder("Priesterin"), "PRIEST")
LOCALIZED_CLASS_NAMES_MALE.PRIEST, _G.LOCALIZED_CLASS_NAMES_FEMALE = male, female

-- The headers follow the order of the size shown.
RC.Set("r10", "groupBy", "CLASS")
Header.Create()
H.check("header 1: priests", Header.headers[1]:GetAttribute("groupFilter"), "1,2,PRIEST")
H.check("header 2: druids", Header.headers[2]:GetAttribute("groupFilter"), "1,2,DRUID")
RC.Set("r10", "classOrder", "")
H.check("back to Blizzard's order", Header.headers[1]:GetAttribute("groupFilter"), "1,2,WARRIOR")

-- Test mode places its pretend members in the same blocks.
local lists = Test.Distribute(Layout.Blocks("CLASS", 10, "INDEX", "PRIEST,DRUID"), Test.Members(10), 10, "INDEX")
H.check("test mode: the priest first", lists[1][1].index, 2)
H.check("test mode: the druid second", lists[2][1].index, 7)
H.check("nothing blocked", #M.blocked, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_class_order.lua`

Expected:

```text
test_raid_class_order.lua
  FAIL defined -> false (want true)
  FAIL code -> nil (want CO)
  FAIL text -> nil (want text)
  FAIL per size -> nil (want true)
  FAIL not character-wide -> nil (want false)
  ERROR .../Core/Config.lua:79: unknown setting classOrder
0 passed, 6 failed
```

- [ ] **Step 3: The setting, the class list and the parser**

In `Raid/Settings.lua`:

Replace

```lua
function Raid.Scope(size)
    assert(IS_SIZE[size], "unknown raid size " .. tostring(size))
    return "r" .. size
end

local RaidSettings = ns.NewRegistry(
```

with

```lua
function Raid.Scope(size)
    assert(IS_SIZE[size], "unknown raid size " .. tostring(size))
    return "r" .. size
end

-- Blizzard's class order for this game type (CLASS_SORT_ORDER), read
-- when asked: the class tokens a class order may name.
function Raid.Classes()
    return CLASS_SORT_ORDER or { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK",
        "HUNTER" }
end

local function isClass(token)
    for _, class in ipairs(Raid.Classes()) do
        if class == token then return true end
    end
    return false
end

-- A class order as stored: class tokens separated by commas or spaces,
-- each once.
local function isClassOrder(text)
    local seen = {}
    for token in text:gmatch("[^,%s]+") do
        if seen[token] or not isClass(token) then return false end
        seen[token] = true
    end
    return true
end
-- Every class with a separator.
Raid.CLASS_ORDER_LETTERS = 100

-- What the options window stores for a typed class order: the tokens,
-- comma-separated. It takes tokens in any case and the game's class
-- names (commas between them, a name may hold a space); nil when a
-- class is unknown or named twice.
local function tokenOf(word)
    local upper = word:upper()
    if isClass(upper) then return upper end
    for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
        if type(names) == "table" then
            for token, name in pairs(names) do
                if type(name) == "string" and name:lower() == word:lower() and isClass(token) then return token end
            end
        end
    end
    return nil
end

function Raid.ParseClassOrder(text)
    local tokens, seen = {}, {}
    for piece in text:gmatch("[^,]+") do
        local word = piece:match("^%s*(.-)%s*$")
        if word ~= "" then
            local token = tokenOf(word)
            if not token or seen[token] then return nil end
            seen[token] = true
            tokens[#tokens + 1] = token
        end
    end
    return table.concat(tokens, ",")
end

local RaidSettings = ns.NewRegistry(
```

In `Raid/Settings.lua`:

Replace

```lua
-- damage, the rest; each in raid order).
RaidSettings.Define({ key = "sortBy", code = "SO", scope = "frame", type = "enum",
    values = { "INDEX", "NAME", "ROLE" }, default = "INDEX" })
-- Blocks side by side (a row of blocks) or stacked (a column), wrapping
-- after blocksPerLine.
RaidSettings.Define({ key = "blockDirection", code = "BD", scope = "frame", type = "enum",
```

with

```lua
-- damage, the rest; each in raid order).
RaidSettings.Define({ key = "sortBy", code = "SO", scope = "frame", type = "enum",
    values = { "INDEX", "NAME", "ROLE" }, default = "INDEX" })
-- The class blocks' order: class tokens (commas or spaces), each once;
-- the classes not named follow in Blizzard's order. Empty: Blizzard's
-- order.
RaidSettings.Define({ key = "classOrder", code = "CO", scope = "frame", type = "text",
    maxLetters = Raid.CLASS_ORDER_LETTERS, check = isClassOrder, default = "" })
-- Blocks side by side (a row of blocks) or stacked (a column), wrapping
-- after blocksPerLine.
RaidSettings.Define({ key = "blockDirection", code = "BD", scope = "frame", type = "enum",
```

- [ ] **Step 4: Class blocks in the order**

In `Raid/Layout.lua`:

Replace

```lua

local function joined(list) return table.concat(list, ",") end

-- Blizzard's class order for this game type (CLASS_SORT_ORDER).
local function classes()
    return CLASS_SORT_ORDER or { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK",
        "HUNTER" }
end

-- Sorted by role: the header groups its members by assigned role (a role
```

with

```lua

local function joined(list) return table.concat(list, ",") end

-- Blizzard's class order for this game type (Raid/Settings.lua).
local function classes() return ns.Raid.Classes() end

-- The class blocks' order: the classes a class order (the setting, as
-- stored) names, then the others in Blizzard's order.
function Layout.Classes(order)
    local list, named = {}, {}
    for token in (order or ""):gmatch("[^,%s]+") do
        list[#list + 1] = token
        named[token] = true
    end
    for _, token in ipairs(classes()) do
        if not named[token] then list[#list + 1] = token end
    end
    return list
end

-- Sorted by role: the header groups its members by assigned role (a role
```

In `Raid/Layout.lua`:

Replace

```lua
-- Each block keeps to the size's groups. A class or role block filters
-- strictly: group and class (and role) must all match. Members without
-- an assigned role count as damage. sortBy (the setting, optional):
-- ROLE sorts by role within each block.
function Layout.Blocks(groupBy, size, sortBy)
    local groups = joined(Layout.Groups(size))
    local blocks = {}
    if groupBy == "GROUP" then
```

with

```lua
-- Each block keeps to the size's groups. A class or role block filters
-- strictly: group and class (and role) must all match. Members without
-- an assigned role count as damage. sortBy (the setting, optional):
-- ROLE sorts by role within each block; classOrder (the setting,
-- optional): the class blocks' order.
function Layout.Blocks(groupBy, size, sortBy, classOrder)
    local groups = joined(Layout.Groups(size))
    local blocks = {}
    if groupBy == "GROUP" then
```

In `Raid/Layout.lua`:

Replace

```lua
            blocks[g] = { kind = "GROUP", id = g, capacity = Layout.GROUP_SIZE, filter = { groupFilter = tostring(g) } }
        end
    elseif groupBy == "CLASS" then
        for i, token in ipairs(classes()) do
            blocks[i] = { kind = "CLASS", id = token,
                filter = { groupFilter = groups .. "," .. token, strictFiltering = true } }
        end
```

with

```lua
            blocks[g] = { kind = "GROUP", id = g, capacity = Layout.GROUP_SIZE, filter = { groupFilter = tostring(g) } }
        end
    elseif groupBy == "CLASS" then
        for i, token in ipairs(Layout.Classes(classOrder)) do
            blocks[i] = { kind = "CLASS", id = token,
                filter = { groupFilter = groups .. "," .. token, strictFiltering = true } }
        end
```

- [ ] **Step 5: The header passes the order**

In `Raid/Header.lua`:

Replace

```lua
function Header.Refresh()
    if not Header.anchor then return end
    local size = Cell.Size()
    Header.blocks = Layout.Blocks(get("groupBy"), size, get("sortBy"))
    local s = Header.Shape()
    for i, block in ipairs(Header.blocks) do
        setAttributes(header(i), headerAttributes(s, size), block.filter)
```

with

```lua
function Header.Refresh()
    if not Header.anchor then return end
    local size = Cell.Size()
    Header.blocks = Layout.Blocks(get("groupBy"), size, get("sortBy"), get("classOrder"))
    local s = Header.Shape()
    for i, block in ipairs(Header.blocks) do
        setAttributes(header(i), headerAttributes(s, size), block.filter)
```

- [ ] **Step 6: Run the tests**

Run: `tests/run test_raid_class_order.lua` → `33 passed, 0 failed`
Run: `tests/run` → Expected: `20310 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add Raid/Header.lua Raid/Layout.lua Raid/Settings.lua tests/test_raid_class_order.lua
git commit -m "Raid: the class blocks' order is configurable

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Raid: corner indicator spells by name from the spell book

The mock gets the spell book first; the test checks it against the documented shapes.

**Files:**
- Modify: `tests/mock.lua`
- Create: `Raid/Spellbook.lua`
- Modify: `ForeverUnitFrames.toc`
- Test: `tests/test_raid_spell_names.lua`

**Interfaces:**
- Consumes: `C_SpellBook.GetNumSpellBookSkillLines`, `GetSpellBookSkillLineInfo`, `GetSpellBookItemInfo`, `Enum.SpellBookSpellBank`, `Enum.SpellBookItemType`; `ns.Secrets.IsSecret`; `ns.Raid.SpellList` (R3a).
- Produces: `ns.RaidSpellbook.IDs(name)` → the spell IDs of every learned rank (case ignored, spell book order); `ns.RaidSpellbook.Resolve(text)` → IDs joined by commas (IDs separated by commas or spaces, names between commas, each ID once) or `nil, piece`; mock: the spell book above, `M.futureSpells[id] = true`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_spell_names.lua`:

```lua
-- Corner indicator spells by name (Raid/Spellbook.lua): a name stands for
-- every rank of it in the player's spell book; the options window stores
-- the IDs. Nothing read from the spell book is compared while secret.
local M = H.M
local ns = H.LoadAddon()
local Book, Raid = ns.RaidSpellbook, ns.Raid
M.known[2050], M.known[2052] = true, true

-- The mock's spell book: learned spells in line 1, every rank an item.
H.check("two skill lines", C_SpellBook.GetNumSpellBookSkillLines(), 2)
local line = C_SpellBook.GetSpellBookSkillLineInfo(1)
H.check("learned spells", line.numSpellBookItems, 2)
local item = C_SpellBook.GetSpellBookItemInfo(line.itemIndexOffset + 1, Enum.SpellBookSpellBank.Player)
H.check("an item", item.name .. " " .. item.spellID .. " " .. item.itemType, "Lesser Heal 2050 1")
H.check("pet bank: nothing", C_SpellBook.GetSpellBookItemInfo(1, Enum.SpellBookSpellBank.Pet), nil)
H.checkError("slot required", function() C_SpellBook.GetSpellBookItemInfo(nil, 0) end)

-- Every learned rank of a name, case ignored.
H.check("ranks", table.concat(Book.IDs("lesser heal"), ","), "2050,2052")
H.check("a spell not learned", #Book.IDs("Heal"), 0)
M.futureSpells[2053] = true
H.check("future spells are not learned", table.concat(Book.IDs("Lesser Heal"), ","), "2050,2052")

-- A typed list: IDs (commas or spaces) and names (between commas).
H.check("a name", Book.Resolve("Lesser Heal"), "2050,2052")
H.check("IDs and a name", Book.Resolve("139, Lesser Heal"), "139,2050,2052")
H.check("IDs only", Book.Resolve("139 6074"), "139,6074")
H.check("each once", Book.Resolve("2050, Lesser Heal"), "2050,2052")
H.check("empty", Book.Resolve("  "), "")
local ids, unknown = Book.Resolve("Lesser Heal, Nope")
H.check("unknown name refused", ids, nil)
H.check("the unknown name", unknown, "Nope")
H.check("zero refused", Book.Resolve("0"), nil)
H.checkTrue("a valid spell list", Raid.SpellList(Book.Resolve("139, Lesser Heal")))

-- Secret items are skipped, never compared.
local real = C_SpellBook.GetSpellBookItemInfo
C_SpellBook.GetSpellBookItemInfo = function()
    return { name = M.Secret("Lesser Heal"), spellID = M.Secret(2050), itemType = M.Secret(1) }
end
H.check("secret items skipped", #Book.IDs("Lesser Heal"), 0)
C_SpellBook.GetSpellBookItemInfo = real

-- Without the spell book API names cannot be read; IDs still can.
C_SpellBook.GetNumSpellBookSkillLines = nil
H.check("no spell book: no ranks", #Book.IDs("Lesser Heal"), 0)
H.check("no spell book: IDs", Book.Resolve("139"), "139")
H.check("no spell book: names refused", Book.Resolve("Lesser Heal"), nil)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_spell_names.lua`

Expected:

```text
test_raid_spell_names.lua
  ERROR test_raid_spell_names.lua:10: attempt to call field 'GetNumSpellBookSkillLines' (a nil value)
0 passed, 1 failed
```

- [ ] **Step 3: The mock's spell book**

In `tests/mock.lua`:

Replace

```lua
    -- The old globals come from Blizzard_DeprecatedSpellBook (only with
    -- the loadDeprecationFallbacks CVar); a test may remove either side.
    _G.C_SpellBook = { IsSpellKnown = function(id) return M.known[id] == true end }
    _G.IsPlayerSpell = function(id) return M.known[id] == true end
    _G.IsSpellKnown = function(id) return M.known[id] == true end
    _G.GetReadyCheckStatus = function(unit) local d = u(unit); return d and d.readyCheck end
```

with

```lua
    -- The old globals come from Blizzard_DeprecatedSpellBook (only with
    -- the loadDeprecationFallbacks CVar); a test may remove either side.
    _G.C_SpellBook = { IsSpellKnown = function(id) return M.known[id] == true end }
    -- The spell book (SpellBookDocumentation.lua): skill line 1 holds the
    -- learned spells (M.known) by ID, line 2 those still to learn
    -- (M.futureSpells[id] = true) as FutureSpell items. Every rank is an
    -- item of its own: the client's spell book window only hides the low
    -- ranks. Only the player's bank is modelled; the pet's is empty.
    M.futureSpells = {}
    local function bookLines()
        local learned, future = {}, {}
        for id in pairs(M.known) do if M.spells[id] then learned[#learned + 1] = id end end
        for id in pairs(M.futureSpells) do if M.spells[id] then future[#future + 1] = id end end
        table.sort(learned)
        table.sort(future)
        return { learned, future }
    end
    C_SpellBook.GetNumSpellBookSkillLines = function() return 2 end
    C_SpellBook.GetSpellBookSkillLineInfo = function(index)
        local lines, offset = bookLines(), 0
        if not lines[index] then return nil end
        for i = 1, index - 1 do offset = offset + #lines[i] end
        return { name = index == 1 and "General" or "Class", iconID = 1, itemIndexOffset = offset,
            numSpellBookItems = #lines[index], isGuild = false, shouldHide = false }
    end
    C_SpellBook.GetSpellBookItemInfo = function(slot, bank)
        assert(type(slot) == "number" and type(bank) == "number", "GetSpellBookItemInfo(slot, bank)")
        if bank ~= Enum.SpellBookSpellBank.Player then return nil end
        for i, line in ipairs(bookLines()) do
            local id = line[slot]
            if id then
                return { actionID = id, spellID = id, name = M.spells[id].name, subName = "", iconID = 1,
                    itemType = i == 1 and Enum.SpellBookItemType.Spell or Enum.SpellBookItemType.FutureSpell,
                    isPassive = false, isOffSpec = false, skillLineIndex = i }
            end
            slot = slot - #line
        end
        return nil
    end
    _G.IsPlayerSpell = function(id) return M.known[id] == true end
    _G.IsSpellKnown = function(id) return M.known[id] == true end
    _G.GetReadyCheckStatus = function(unit) local d = u(unit); return d and d.readyCheck end
```

In `tests/mock.lua`:

Replace

```lua

    _G.Enum = {
        LootMethod = { Freeforall = 0, Roundrobin = 1, Masterlooter = 2, Group = 3, Needbeforegreed = 4, Personal = 5 },
        StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
        StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
        UITextureSliceMode = { Stretched = 0, Tiled = 1 },
```

with

```lua

    _G.Enum = {
        LootMethod = { Freeforall = 0, Roundrobin = 1, Masterlooter = 2, Group = 3, Needbeforegreed = 4, Personal = 5 },
        SpellBookSpellBank = { Player = 0, Pet = 1 },
        SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 },
        StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
        StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
        UITextureSliceMode = { Stretched = 0, Tiled = 1 },
```

- [ ] **Step 4: Names to the IDs of their ranks**

Create `Raid/Spellbook.lua`:

```lua
local _, ns = ...

-- Corner indicator spells by name: the options window turns a name into
-- the IDs of every rank of it in the player's spell book (each rank is an
-- item there; Blizzard's spell book window only hides the low ones), so a
-- heal-over-time shows whichever rank was cast. Read only when the player
-- types a name, never in combat paths. Nothing read from the spell book
-- is compared or changed while secret (it is not documented as secret;
-- guarded anyway).
local Spellbook = {}
ns.RaidSpellbook = Spellbook

local Secrets = ns.Secrets

local function plain(v, kind)
    return not Secrets.IsSecret(v) and type(v) == kind
end

-- The items of one skill line of the player's bank, as fn(item).
local function forEachItem(book, line, fn)
    local info = book.GetSpellBookSkillLineInfo(line)
    if type(info) ~= "table" then return end
    if not (plain(info.itemIndexOffset, "number") and plain(info.numSpellBookItems, "number")) then return end
    local bank = Enum.SpellBookSpellBank.Player
    for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
        local item = book.GetSpellBookItemInfo(slot, bank)
        if type(item) == "table" then fn(item) end
    end
end

-- The spell IDs of every learned rank of a spell name (case ignored), in
-- spell book order; empty when there is none or no spell book to read.
function Spellbook.IDs(name)
    local book, ids = C_SpellBook, {}
    if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo
        and book.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank) then
        return ids
    end
    local wanted, spell, seen = name:lower(), Enum.SpellBookItemType.Spell, {}
    local lines = book.GetNumSpellBookSkillLines()
    if not plain(lines, "number") then return ids end
    for line = 1, lines do
        forEachItem(book, line, function(item)
            local id = item.spellID
            if plain(item.itemType, "number") and item.itemType == spell and plain(item.name, "string")
                and plain(id, "number") and item.name:lower() == wanted and not seen[id] then
                seen[id] = true
                ids[#ids + 1] = id
            end
        end)
    end
    return ids
end

-- A typed spell list as the options window stores it: IDs (separated by
-- commas or spaces) and spell names (separated by commas; a name may hold
-- spaces), each ID once, comma-separated. nil and the piece in question
-- when a name is not in the spell book or an ID is not a positive number.
function Spellbook.Resolve(text)
    local ids, seen = {}, {}
    local function add(id)
        if not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    for piece in text:gmatch("[^,]+") do
        local word = piece:match("^%s*(.-)%s*$")
        if word:match("^[%d%s]+$") then
            for digits in word:gmatch("%d+") do
                local id = tonumber(digits)
                if id < 1 then return nil, word end
                add(id)
            end
        elseif word ~= "" then
            local found = Spellbook.IDs(word)
            if #found == 0 then return nil, word end
            for _, id in ipairs(found) do add(id) end
        end
    end
    return table.concat(ids, ",")
end
```

- [ ] **Step 5: Load it after the raid settings**

In `ForeverUnitFrames.toc`:

Replace

```text
Core\MacroBackup.lua
Core\Storage.lua
Raid\Settings.lua
Raid\Profiles.lua
Raid\Size.lua
Raid\Layout.lua
```

with

```text
Core\MacroBackup.lua
Core\Storage.lua
Raid\Settings.lua
Raid\Spellbook.lua
Raid\Profiles.lua
Raid\Size.lua
Raid\Layout.lua
```

- [ ] **Step 6: Run the tests**

Run: `tests/run test_raid_spell_names.lua` → `21 passed, 0 failed`
Run: `tests/run` → Expected: `20331 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add ForeverUnitFrames.toc Raid/Spellbook.lua tests/mock.lua tests/test_raid_spell_names.lua
git commit -m "Raid: corner indicator spells by name from the spell book

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Raid options menu: tabs, sections and their words

Every word of the menu in all four languages: the four locale blocks below are long but plain.

**Files:**
- Create: `Raid/Options/Schema.lua`
- Modify: `ForeverUnitFrames.toc`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_raid_schema.lua`

**Interfaces:**
- Consumes: `ns.RaidSettings` (every raid setting), `ns.Raid.INDICATORS`, `ns.Settings.POINTS`, `ns.L`, `ns.Widgets.LABEL_MAX_W`.
- Produces: `ns.RaidSchema.TABS` (`general`, `layout`, `cell` (with `note = "cell"`), `texts`, `debuffs`, `indicators`, `icons`; each `{ id, sections = { { id, keys } } }`), `ns.RaidSchema.HEADER_KEYS = { "sizeMode" }`, `WordKey(key)`, `Label(key)`, `Hint(key)` (nil without one), `SectionTitle(id)`, `TabTitle(id)`, `Note(id)`, `EnumText(def, value)`; the locale keys of the Global Constraints.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_schema.lua`:

```lua
-- The raid options menu (Raid/Options/Schema.lua): every raid setting in
-- exactly one place, every word of it in every language, labels that fit
-- the window's label column.
local M = H.M
local ns = H.LoadAddon()
local Schema, RS, L = ns.RaidSchema, ns.RaidSettings, ns.L

local function ids(list)
    local out = {}
    for i, t in ipairs(list) do out[i] = t.id end
    return table.concat(out, ",")
end
H.check("tabs", ids(Schema.TABS), "general,layout,cell,texts,debuffs,indicators,icons")

-- Every setting once: in a section, or in the header bar.
local seen = {}
for _, tab in ipairs(Schema.TABS) do
    for _, sec in ipairs(tab.sections) do
        for _, key in ipairs(sec.keys) do
            H.checkTrue("known setting " .. key, RS.Get(key))
            H.check("once: " .. key, seen[key], nil)
            seen[key] = tab.id
        end
    end
end
for _, key in ipairs(Schema.HEADER_KEYS) do
    H.check("header bar only: " .. key, seen[key], nil)
    seen[key] = "header"
end
for _, def in ipairs(RS.All()) do H.checkTrue("reachable: " .. def.key, seen[def.key]) end
H.check("character-wide ones on General", seen.showInParty .. seen.hideBlizzard .. seen.enabled,
    "generalgeneralgeneral")
H.check("class order beside the grouping", seen.classOrder, "layout")
H.check("position on Layout", seen.x, "layout")
H.check("states with the icons", seen.aggroBorder, "icons")

-- Shared words.
H.check("indicator spells", Schema.WordKey("indicatorBottomLeftSpells"), "indicatorSpells")
H.check("icon switch", Schema.WordKey("looterIcon"), "iconShow")
H.check("icon point", Schema.WordKey("looterIconPoint"), "iconPoint")
H.check("own word", Schema.WordKey("roleIconDamager"), "roleIconDamager")
H.check("label", Schema.Label("indicatorTopSpells"), "Spells")
H.check("section", Schema.SectionTitle("indicatorTopRight"), "Top right corner")
H.check("tab", Schema.TabTitle("icons"), "Icons & states")
H.check("point choices: the unit frames' words", Schema.EnumText(RS.Get("roleIconPoint"), "TOPLEFT"), "Top left")
H.check("raid's own choice", Schema.EnumText(RS.Get("sizeMode"), "AUTO"), "Automatic")
H.check("hint", Schema.Hint("indicatorTopLeftSpells"), "Spell IDs, or names from your spell book")
H.check("no hint", Schema.Hint("cellWidth"), nil)
H.checkTrue("the cell's note", Schema.Note("cell"))

-- Every word in every language: labels, sections, tabs, notes, choices.
local needed = {}
local function need(name) needed[name] = true end
for _, tab in ipairs(Schema.TABS) do
    need("RAID_TAB_" .. tab.id)
    if tab.note then need("RAID_NOTE_" .. tab.note) end
    for _, sec in ipairs(tab.sections) do need("RAID_SECTION_" .. sec.id) end
end
for _, def in ipairs(RS.All()) do
    need("RAID_SETTING_" .. Schema.WordKey(def.key))
    if def.type == "enum" and def.values ~= ns.Settings.POINTS then
        for _, v in ipairs(def.values) do need("RAID_ENUM_" .. Schema.WordKey(def.key) .. "_" .. v) end
    end
end
for _, v in ipairs(ns.Settings.POINTS) do need("ENUM_" .. v) end
for name in pairs(needed) do
    for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
        H.checkTrue(code .. " has " .. name, type(ns.Locales[code][name]) == "string")
    end
end

-- Labels fit the label column, hints are no longer than the unit frames'
-- longest, in every language (mock: half the font size per character).
local function width(text, size)
    local fs = M.newWidget("FontString")
    fs:SetFont("x", size, "")
    fs:SetText(text)
    return fs:GetStringWidth()
end
local longestHint = 0
for key, v in pairs(ns.Locales.enUS) do
    if key:match("^HINT_") then longestHint = math.max(longestHint, width(v, 10)) end
end
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    for key, v in pairs(ns.Locales[code]) do
        if key:match("^RAID_SETTING_") then
            H.checkTrue(code .. " label fits: " .. key, width(v, 12) <= ns.Widgets.LABEL_MAX_W)
        elseif key:match("^RAID_HINT_") then
            H.checkTrue(code .. " hint fits: " .. key, width(v, 10) <= longestHint)
        end
    end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_schema.lua`

Expected:

```text
test_raid_schema.lua
  ERROR test_raid_schema.lua:13: attempt to index local 'Schema' (a nil value)
0 passed, 1 failed
```

- [ ] **Step 3: The menu**

Create `Raid/Options/Schema.lua`:

```lua
local _, ns = ...

-- The raid options window's menu (Raid/Options/Window.lua) and the raid
-- pages of the wiki (tools/make_wiki.lua): tabs, their sections and the
-- raid settings in them, and the words for all of it. Every raid setting
-- is in exactly one section, except sizeMode, which the window's header
-- bar holds. The words are the raid's own (RAID_SETTING_<key>, ...): a
-- raid key may share its name with a unit-frame setting of another
-- meaning.
local Schema = {}
ns.RaidSchema = Schema

local L = ns.L

-- The settings of one corner indicator position.
local function indicator(name)
    local key = "indicator" .. name
    return { id = key, keys = { key .. "Spells", key .. "Color", key .. "Size", key .. "Own", key .. "Time" } }
end

-- One icon: its switch and its point.
local function icon(id, key, extra)
    local keys = { key, key .. "Point" }
    if extra then keys[#keys + 1] = extra end
    return { id = id, keys = keys }
end

Schema.TABS = {
    { id = "general", sections = {
        { id = "raidFrames", keys = { "enabled", "showInParty", "hideBlizzard" } },
    } },
    { id = "layout", sections = {
        { id = "grouping", keys = { "groupBy", "sortBy", "classOrder", "hideEmpty", "blockTitles" } },
        { id = "arrangement", keys = { "blockDirection", "blocksPerLine", "blockSpacing", "cellGrowth",
            "cellsPerLine", "cellSpacing" } },
        { id = "position", keys = { "x", "y" } },
        { id = "borders", keys = { "panelBorder", "blockBorder", "cellBorder" } },
    } },
    -- The cells wear the party frame's look (bar texture, font, heal and
    -- shield colours): the note says so.
    { id = "cell", note = "cell", sections = {
        { id = "size", keys = { "cellWidth", "cellHeight" } },
        { id = "bars", keys = { "healthColorMode", "powerStrip" } },
    } },
    { id = "texts", sections = {
        { id = "texts", keys = { "nameClassColor", "secondLine" } },
    } },
    { id = "debuffs", sections = {
        { id = "dispel", keys = { "dispelIcon", "dispelFilter", "dispelIconSize", "dispelTint" } },
        { id = "debuffRow", keys = { "debuffRow", "debuffCount", "debuffSize" } },
    } },
    { id = "indicators", sections = {
        indicator("TopLeft"), indicator("TopRight"), indicator("BottomLeft"), indicator("BottomRight"),
        indicator("Top"),
    } },
    { id = "icons", sections = {
        { id = "icons", keys = { "iconSize" } },
        icon("role", "roleIcon", "roleIconDamager"),
        icon("raidMarker", "raidMarker"),
        icon("leader", "leaderIcon"),
        icon("looter", "looterIcon"),
        icon("readyCheck", "readyCheckIcon"),
        { id = "states", keys = { "rangeFade", "rangeAlpha", "aggroBorder", "targetBorder" } },
    } },
}

-- Held by the header bar, not by a tab.
Schema.HEADER_KEYS = { "sizeMode" }

-- Settings that share their words: the five indicator positions (the
-- section names the position), the icons' switches and points (the
-- section names the icon).
local SHARED = {}
for _, ind in ipairs(ns.Raid.INDICATORS) do
    for _, part in ipairs({ "Spells", "Color", "Size", "Own", "Time" }) do
        SHARED["indicator" .. ind.name .. part] = "indicator" .. part
    end
end
for _, key in ipairs({ "roleIcon", "raidMarker", "leaderIcon", "looterIcon", "readyCheckIcon" }) do
    SHARED[key], SHARED[key .. "Point"] = "iconShow", "iconPoint"
end

-- The name a setting's words go by.
function Schema.WordKey(key)
    return SHARED[key] or key
end

local function word(prefix, key)
    local name = prefix .. key
    local v = L[name]
    if v ~= name then return v end
    return nil
end

function Schema.Label(key) return word("RAID_SETTING_", Schema.WordKey(key)) or key end
function Schema.Hint(key) return word("RAID_HINT_", Schema.WordKey(key)) end
function Schema.SectionTitle(id) return word("RAID_SECTION_", id) or id end
function Schema.TabTitle(id) return word("RAID_TAB_", id) or id end
function Schema.Note(id) return word("RAID_NOTE_", id) end

-- A choice of an enum: the raid's own word, else the unit frames' (the
-- nine points).
function Schema.EnumText(def, value)
    return word("RAID_ENUM_" .. Schema.WordKey(def.key) .. "_", value) or word("ENUM_", value) or value
end
```

- [ ] **Step 4: Load it after the unit window's files**

In `ForeverUnitFrames.toc`:

Replace

```text
Options\TestMode.lua
Options\Window.lua
Options\MinimapButton.lua
Core\Debug.lua
Core\Boot.lua
```

with

```text
Options\TestMode.lua
Options\Window.lua
Options\MinimapButton.lua
Raid\Options\Schema.lua
Core\Debug.lua
Core\Boot.lua
```

- [ ] **Step 5: The words in English**

Append to the end of `Locales/enUS.lua`:

```lua

-- Raid frames: the options menu (Raid/Options/Schema.lua).
L.RAID_TAB_general = "General"
L.RAID_TAB_layout = "Layout"
L.RAID_TAB_cell = "Cell"
L.RAID_TAB_texts = "Texts"
L.RAID_TAB_debuffs = "Debuffs"
L.RAID_TAB_indicators = "Indicators"
L.RAID_TAB_icons = "Icons & states"
L.RAID_NOTE_cell = "Bar texture, font and the colors of heals and shields follow the party frame."
L.RAID_SECTION_raidFrames = "Raid frames"
L.RAID_SECTION_grouping = "Grouping"
L.RAID_SECTION_arrangement = "Arrangement"
L.RAID_SECTION_position = "Position"
L.RAID_SECTION_borders = "Borders"
L.RAID_SECTION_size = "Size"
L.RAID_SECTION_bars = "Bars"
L.RAID_SECTION_texts = "Texts"
L.RAID_SECTION_dispel = "Dispellable debuff"
L.RAID_SECTION_debuffRow = "Debuff row"
L.RAID_SECTION_indicatorTopLeft = "Top left corner"
L.RAID_SECTION_indicatorTopRight = "Top right corner"
L.RAID_SECTION_indicatorBottomLeft = "Bottom left corner"
L.RAID_SECTION_indicatorBottomRight = "Bottom right corner"
L.RAID_SECTION_indicatorTop = "Top edge"
L.RAID_SECTION_icons = "Icons"
L.RAID_SECTION_role = "Role"
L.RAID_SECTION_raidMarker = "Raid target marker"
L.RAID_SECTION_leader = "Leader and assistants"
L.RAID_SECTION_looter = "Master looter"
L.RAID_SECTION_readyCheck = "Ready check"
L.RAID_SECTION_states = "States"
L.RAID_SETTING_enabled = "Show raid frames"
L.RAID_SETTING_showInParty = "Raid view in a party"
L.RAID_SETTING_hideBlizzard = "Hide Blizzard's raid frames"
L.RAID_SETTING_sizeMode = "Raid size shown"
L.RAID_SETTING_x = "Position X"
L.RAID_SETTING_y = "Position Y"
L.RAID_SETTING_groupBy = "Group by"
L.RAID_SETTING_sortBy = "Sort within a block"
L.RAID_SETTING_classOrder = "Class order"
L.RAID_SETTING_blockDirection = "Blocks"
L.RAID_SETTING_blocksPerLine = "Blocks per line"
L.RAID_SETTING_blockSpacing = "Block spacing"
L.RAID_SETTING_cellGrowth = "Cells grow"
L.RAID_SETTING_cellsPerLine = "Cells per line"
L.RAID_SETTING_cellSpacing = "Cell spacing"
L.RAID_SETTING_cellWidth = "Cell width"
L.RAID_SETTING_cellHeight = "Cell height"
L.RAID_SETTING_blockTitles = "Block titles"
L.RAID_SETTING_hideEmpty = "Hide empty blocks"
L.RAID_SETTING_panelBorder = "Around the panel"
L.RAID_SETTING_blockBorder = "Around each block"
L.RAID_SETTING_cellBorder = "Around each cell"
L.RAID_SETTING_healthColorMode = "Health color"
L.RAID_SETTING_powerStrip = "Power strip"
L.RAID_SETTING_secondLine = "Second line"
L.RAID_SETTING_nameClassColor = "Name in class color"
L.RAID_SETTING_dispelIcon = "Icon in the center"
L.RAID_SETTING_dispelFilter = "Which debuffs"
L.RAID_SETTING_dispelIconSize = "Icon size"
L.RAID_SETTING_dispelTint = "Tint the cell"
L.RAID_SETTING_debuffRow = "Show the row"
L.RAID_SETTING_debuffCount = "Number of icons"
L.RAID_SETTING_debuffSize = "Icon size"
L.RAID_SETTING_indicatorSpells = "Spells"
L.RAID_SETTING_indicatorColor = "Color"
L.RAID_SETTING_indicatorSize = "Size"
L.RAID_SETTING_indicatorOwn = "Your own casts only"
L.RAID_SETTING_indicatorTime = "Time left"
L.RAID_SETTING_iconShow = "Show"
L.RAID_SETTING_iconPoint = "Position"
L.RAID_SETTING_roleIconDamager = "Damage dealers too"
L.RAID_SETTING_iconSize = "Icon size"
L.RAID_SETTING_rangeFade = "Fade out of range"
L.RAID_SETTING_rangeAlpha = "Opacity out of range (%)"
L.RAID_SETTING_aggroBorder = "Red line on aggro"
L.RAID_SETTING_targetBorder = "Light line on your target"
L.RAID_HINT_showInParty = "A 5-player group as a raid; party frames hide"
L.RAID_HINT_hideBlizzard = "Needs /reload to show them again"
L.RAID_HINT_sizeMode = "Automatic: the raid instance's size, else the group's"
L.RAID_HINT_x = "Top left corner, from the screen centre"
L.RAID_HINT_y = "Top left corner, from the screen centre"
L.RAID_HINT_sortBy = "Role: tanks, healers, damage, then the rest"
L.RAID_HINT_classOrder = "Class names, e.g. Priest, Druid; the rest follow"
L.RAID_HINT_hideEmpty = "Blocks without members take no room"
L.RAID_HINT_blocksPerLine = "Then a new row (or column) of blocks"
L.RAID_HINT_cellsPerLine = "Then a new column (or row) of cells"
L.RAID_HINT_dispelTint = "The whole cell in the debuff type's color"
L.RAID_HINT_debuffRow = "Every debuff, along the bottom of the cell"
L.RAID_HINT_indicatorSpells = "Spell IDs, or names from your spell book"
L.RAID_HINT_roleIconDamager = "Tanks and healers always show"
L.RAID_HINT_aggroBorder = "Along the inside of the cell"
L.RAID_ENUM_sizeMode_AUTO = "Automatic"
L.RAID_ENUM_sizeMode_10 = "10 players"
L.RAID_ENUM_sizeMode_20 = "20 players"
L.RAID_ENUM_sizeMode_40 = "40 players"
L.RAID_ENUM_groupBy_GROUP = "Group"
L.RAID_ENUM_groupBy_CLASS = "Class"
L.RAID_ENUM_groupBy_ROLE = "Role"
L.RAID_ENUM_groupBy_NONE = "None (one block)"
L.RAID_ENUM_sortBy_INDEX = "Raid order"
L.RAID_ENUM_sortBy_NAME = "Name"
L.RAID_ENUM_sortBy_ROLE = "Role"
L.RAID_ENUM_blockDirection_HORIZONTAL = "Side by side"
L.RAID_ENUM_blockDirection_VERTICAL = "Stacked"
L.RAID_ENUM_cellGrowth_DOWN = "Down"
L.RAID_ENUM_cellGrowth_RIGHT = "Right"
L.RAID_ENUM_healthColorMode_CLASS = "Class"
L.RAID_ENUM_healthColorMode_STATIC = "The party frame's color"
L.RAID_ENUM_healthColorMode_GRADIENT = "Gradient by health"
L.RAID_ENUM_powerStrip_ALL = "Everyone"
L.RAID_ENUM_powerStrip_MANA = "Mana users"
L.RAID_ENUM_powerStrip_HEALERS = "Healers"
L.RAID_ENUM_powerStrip_OFF = "Off"
L.RAID_ENUM_secondLine_DEFICIT = "Missing health"
L.RAID_ENUM_secondLine_PERCENT = "Percent"
L.RAID_ENUM_secondLine_CURRENT = "Current health"
L.RAID_ENUM_secondLine_NONE = "None"
L.RAID_ENUM_dispelFilter_MINE = "Dispellable by me"
L.RAID_ENUM_dispelFilter_ALL = "Any dispellable"
L.RAID_ENUM_indicatorTime_SWIPE = "Darkening"
L.RAID_ENUM_indicatorTime_NUMBER = "Number"
L.RAID_ENUM_indicatorTime_NONE = "Not shown"
```

- [ ] **Step 6: German**

Append to the end of `Locales/deDE.lua`:

```lua

-- Schlachtzugsrahmen: das Optionsmenü (Raid/Options/Schema.lua).
L.RAID_TAB_general = "Allgemein"
L.RAID_TAB_layout = "Anordnung"
L.RAID_TAB_cell = "Zelle"
L.RAID_TAB_texts = "Texte"
L.RAID_TAB_debuffs = "Debuffs"
L.RAID_TAB_indicators = "Indikatoren"
L.RAID_TAB_icons = "Symbole & Zustände"
L.RAID_NOTE_cell = "Leistentextur, Schrift und die Farben von Heilungen und Schilden folgen dem Gruppenrahmen."
L.RAID_SECTION_raidFrames = "Schlachtzugsrahmen"
L.RAID_SECTION_grouping = "Gruppierung"
L.RAID_SECTION_arrangement = "Anordnung"
L.RAID_SECTION_position = "Position"
L.RAID_SECTION_borders = "Rahmen"
L.RAID_SECTION_size = "Größe"
L.RAID_SECTION_bars = "Leisten"
L.RAID_SECTION_texts = "Texte"
L.RAID_SECTION_dispel = "Bannbarer Debuff"
L.RAID_SECTION_debuffRow = "Debuff-Reihe"
L.RAID_SECTION_indicatorTopLeft = "Ecke oben links"
L.RAID_SECTION_indicatorTopRight = "Ecke oben rechts"
L.RAID_SECTION_indicatorBottomLeft = "Ecke unten links"
L.RAID_SECTION_indicatorBottomRight = "Ecke unten rechts"
L.RAID_SECTION_indicatorTop = "Oberer Rand"
L.RAID_SECTION_icons = "Symbole"
L.RAID_SECTION_role = "Rolle"
L.RAID_SECTION_raidMarker = "Zielmarkierung"
L.RAID_SECTION_leader = "Anführer und Assistenten"
L.RAID_SECTION_looter = "Plündermeister"
L.RAID_SECTION_readyCheck = "Bereitschaftscheck"
L.RAID_SECTION_states = "Zustände"
L.RAID_SETTING_enabled = "Schlachtzugsrahmen anzeigen"
L.RAID_SETTING_showInParty = "Schlachtzugsansicht in Gruppe"
L.RAID_SETTING_hideBlizzard = "Blizzard-Schlachtzugsrahmen aus"
L.RAID_SETTING_sizeMode = "Angezeigte Größe"
L.RAID_SETTING_x = "Position X"
L.RAID_SETTING_y = "Position Y"
L.RAID_SETTING_groupBy = "Gruppieren nach"
L.RAID_SETTING_sortBy = "Sortierung im Block"
L.RAID_SETTING_classOrder = "Klassenreihenfolge"
L.RAID_SETTING_blockDirection = "Blöcke"
L.RAID_SETTING_blocksPerLine = "Blöcke pro Reihe"
L.RAID_SETTING_blockSpacing = "Abstand der Blöcke"
L.RAID_SETTING_cellGrowth = "Zellen wachsen"
L.RAID_SETTING_cellsPerLine = "Zellen pro Reihe"
L.RAID_SETTING_cellSpacing = "Abstand der Zellen"
L.RAID_SETTING_cellWidth = "Zellenbreite"
L.RAID_SETTING_cellHeight = "Zellenhöhe"
L.RAID_SETTING_blockTitles = "Blocktitel"
L.RAID_SETTING_hideEmpty = "Leere Blöcke ausblenden"
L.RAID_SETTING_panelBorder = "Um das Feld"
L.RAID_SETTING_blockBorder = "Um jeden Block"
L.RAID_SETTING_cellBorder = "Um jede Zelle"
L.RAID_SETTING_healthColorMode = "Gesundheitsfarbe"
L.RAID_SETTING_powerStrip = "Ressourcenstreifen"
L.RAID_SETTING_secondLine = "Zweite Zeile"
L.RAID_SETTING_nameClassColor = "Name in Klassenfarbe"
L.RAID_SETTING_dispelIcon = "Symbol in der Mitte"
L.RAID_SETTING_dispelFilter = "Welche Debuffs"
L.RAID_SETTING_dispelIconSize = "Symbolgröße"
L.RAID_SETTING_dispelTint = "Zelle einfärben"
L.RAID_SETTING_debuffRow = "Reihe anzeigen"
L.RAID_SETTING_debuffCount = "Anzahl der Symbole"
L.RAID_SETTING_debuffSize = "Symbolgröße"
L.RAID_SETTING_indicatorSpells = "Zauber"
L.RAID_SETTING_indicatorColor = "Farbe"
L.RAID_SETTING_indicatorSize = "Größe"
L.RAID_SETTING_indicatorOwn = "Nur eigene Zauber"
L.RAID_SETTING_indicatorTime = "Restzeit"
L.RAID_SETTING_iconShow = "Anzeigen"
L.RAID_SETTING_iconPoint = "Position"
L.RAID_SETTING_roleIconDamager = "Auch Schadensverursacher"
L.RAID_SETTING_iconSize = "Symbolgröße"
L.RAID_SETTING_rangeFade = "Außer Reichweite verblassen"
L.RAID_SETTING_rangeAlpha = "Deckkraft außer Reichweite (%)"
L.RAID_SETTING_aggroBorder = "Rote Linie bei Aggro"
L.RAID_SETTING_targetBorder = "Helle Linie am Ziel"
L.RAID_HINT_showInParty = "Eine 5er-Gruppe als Schlachtzug; Gruppenrahmen aus"
L.RAID_HINT_hideBlizzard = "Erst nach /reload wieder sichtbar"
L.RAID_HINT_sizeMode = "Automatisch: Größe der Instanz, sonst der Gruppe"
L.RAID_HINT_x = "Obere linke Ecke, ab Bildschirmmitte"
L.RAID_HINT_y = "Obere linke Ecke, ab Bildschirmmitte"
L.RAID_HINT_sortBy = "Rolle: Tanks, Heiler, Schaden, dann der Rest"
L.RAID_HINT_classOrder = "Klassennamen, z. B. Priester, Druide; der Rest folgt"
L.RAID_HINT_hideEmpty = "Blöcke ohne Mitglieder brauchen keinen Platz"
L.RAID_HINT_blocksPerLine = "Danach eine neue Reihe (Spalte) von Blöcken"
L.RAID_HINT_cellsPerLine = "Danach eine neue Spalte (Reihe) von Zellen"
L.RAID_HINT_dispelTint = "Die ganze Zelle in der Farbe des Debufftyps"
L.RAID_HINT_debuffRow = "Jeder Debuff, am unteren Rand der Zelle"
L.RAID_HINT_indicatorSpells = "Zauber-IDs oder Namen aus dem Zauberbuch"
L.RAID_HINT_roleIconDamager = "Tanks und Heiler immer"
L.RAID_HINT_aggroBorder = "Innen am Rand der Zelle"
L.RAID_ENUM_sizeMode_AUTO = "Automatisch"
L.RAID_ENUM_sizeMode_10 = "10 Spieler"
L.RAID_ENUM_sizeMode_20 = "20 Spieler"
L.RAID_ENUM_sizeMode_40 = "40 Spieler"
L.RAID_ENUM_groupBy_GROUP = "Gruppe"
L.RAID_ENUM_groupBy_CLASS = "Klasse"
L.RAID_ENUM_groupBy_ROLE = "Rolle"
L.RAID_ENUM_groupBy_NONE = "Keine (ein Block)"
L.RAID_ENUM_sortBy_INDEX = "Schlachtzugsreihenfolge"
L.RAID_ENUM_sortBy_NAME = "Name"
L.RAID_ENUM_sortBy_ROLE = "Rolle"
L.RAID_ENUM_blockDirection_HORIZONTAL = "Nebeneinander"
L.RAID_ENUM_blockDirection_VERTICAL = "Untereinander"
L.RAID_ENUM_cellGrowth_DOWN = "Nach unten"
L.RAID_ENUM_cellGrowth_RIGHT = "Nach rechts"
L.RAID_ENUM_healthColorMode_CLASS = "Klasse"
L.RAID_ENUM_healthColorMode_STATIC = "Farbe des Gruppenrahmens"
L.RAID_ENUM_healthColorMode_GRADIENT = "Verlauf nach Gesundheit"
L.RAID_ENUM_powerStrip_ALL = "Alle"
L.RAID_ENUM_powerStrip_MANA = "Manaklassen"
L.RAID_ENUM_powerStrip_HEALERS = "Heiler"
L.RAID_ENUM_powerStrip_OFF = "Aus"
L.RAID_ENUM_secondLine_DEFICIT = "Fehlende Gesundheit"
L.RAID_ENUM_secondLine_PERCENT = "Prozent"
L.RAID_ENUM_secondLine_CURRENT = "Aktuelle Gesundheit"
L.RAID_ENUM_secondLine_NONE = "Keine"
L.RAID_ENUM_dispelFilter_MINE = "Von mir bannbar"
L.RAID_ENUM_dispelFilter_ALL = "Alle bannbaren"
L.RAID_ENUM_indicatorTime_SWIPE = "Abdunkeln"
L.RAID_ENUM_indicatorTime_NUMBER = "Zahl"
L.RAID_ENUM_indicatorTime_NONE = "Nicht anzeigen"
```

- [ ] **Step 7: Spanish**

Append to the end of `Locales/esES.lua`:

```lua

-- Marcos de banda: el menú de opciones (Raid/Options/Schema.lua).
L.RAID_TAB_general = "General"
L.RAID_TAB_layout = "Diseño"
L.RAID_TAB_cell = "Celda"
L.RAID_TAB_texts = "Textos"
L.RAID_TAB_debuffs = "Perjuicios"
L.RAID_TAB_indicators = "Indicadores"
L.RAID_TAB_icons = "Iconos y estados"
L.RAID_NOTE_cell = "La textura de barra, la fuente y los colores de sanaciones y escudos siguen al marco de grupo."
L.RAID_SECTION_raidFrames = "Marcos de banda"
L.RAID_SECTION_grouping = "Agrupación"
L.RAID_SECTION_arrangement = "Disposición"
L.RAID_SECTION_position = "Posición"
L.RAID_SECTION_borders = "Bordes"
L.RAID_SECTION_size = "Tamaño"
L.RAID_SECTION_bars = "Barras"
L.RAID_SECTION_texts = "Textos"
L.RAID_SECTION_dispel = "Perjuicio disipable"
L.RAID_SECTION_debuffRow = "Fila de perjuicios"
L.RAID_SECTION_indicatorTopLeft = "Esquina superior izquierda"
L.RAID_SECTION_indicatorTopRight = "Esquina superior derecha"
L.RAID_SECTION_indicatorBottomLeft = "Esquina inferior izquierda"
L.RAID_SECTION_indicatorBottomRight = "Esquina inferior derecha"
L.RAID_SECTION_indicatorTop = "Borde superior"
L.RAID_SECTION_icons = "Iconos"
L.RAID_SECTION_role = "Rol"
L.RAID_SECTION_raidMarker = "Marca de objetivo de banda"
L.RAID_SECTION_leader = "Líder y ayudantes"
L.RAID_SECTION_looter = "Maestro despojador"
L.RAID_SECTION_readyCheck = "Comprobación de listos"
L.RAID_SECTION_states = "Estados"
L.RAID_SETTING_enabled = "Mostrar marcos de banda"
L.RAID_SETTING_showInParty = "Vista de banda en grupo"
L.RAID_SETTING_hideBlizzard = "Ocultar marcos de Blizzard"
L.RAID_SETTING_sizeMode = "Tamaño mostrado"
L.RAID_SETTING_x = "Posición X"
L.RAID_SETTING_y = "Posición Y"
L.RAID_SETTING_groupBy = "Agrupar por"
L.RAID_SETTING_sortBy = "Orden dentro del bloque"
L.RAID_SETTING_classOrder = "Orden de clases"
L.RAID_SETTING_blockDirection = "Bloques"
L.RAID_SETTING_blocksPerLine = "Bloques por línea"
L.RAID_SETTING_blockSpacing = "Espaciado de bloques"
L.RAID_SETTING_cellGrowth = "Las celdas crecen"
L.RAID_SETTING_cellsPerLine = "Celdas por línea"
L.RAID_SETTING_cellSpacing = "Espaciado de celdas"
L.RAID_SETTING_cellWidth = "Ancho de celda"
L.RAID_SETTING_cellHeight = "Alto de celda"
L.RAID_SETTING_blockTitles = "Títulos de bloque"
L.RAID_SETTING_hideEmpty = "Ocultar bloques vacíos"
L.RAID_SETTING_panelBorder = "Alrededor del panel"
L.RAID_SETTING_blockBorder = "Alrededor de cada bloque"
L.RAID_SETTING_cellBorder = "Alrededor de cada celda"
L.RAID_SETTING_healthColorMode = "Color de salud"
L.RAID_SETTING_powerStrip = "Franja de recurso"
L.RAID_SETTING_secondLine = "Segunda línea"
L.RAID_SETTING_nameClassColor = "Nombre en color de clase"
L.RAID_SETTING_dispelIcon = "Icono en el centro"
L.RAID_SETTING_dispelFilter = "Qué perjuicios"
L.RAID_SETTING_dispelIconSize = "Tamaño de icono"
L.RAID_SETTING_dispelTint = "Teñir la celda"
L.RAID_SETTING_debuffRow = "Mostrar la fila"
L.RAID_SETTING_debuffCount = "Número de iconos"
L.RAID_SETTING_debuffSize = "Tamaño de icono"
L.RAID_SETTING_indicatorSpells = "Hechizos"
L.RAID_SETTING_indicatorColor = "Color"
L.RAID_SETTING_indicatorSize = "Tamaño"
L.RAID_SETTING_indicatorOwn = "Solo tus propios hechizos"
L.RAID_SETTING_indicatorTime = "Tiempo restante"
L.RAID_SETTING_iconShow = "Mostrar"
L.RAID_SETTING_iconPoint = "Posición"
L.RAID_SETTING_roleIconDamager = "También daño"
L.RAID_SETTING_iconSize = "Tamaño de icono"
L.RAID_SETTING_rangeFade = "Atenuar fuera de alcance"
L.RAID_SETTING_rangeAlpha = "Opacidad fuera de alcance (%)"
L.RAID_SETTING_aggroBorder = "Línea roja con aggro"
L.RAID_SETTING_targetBorder = "Línea clara en tu objetivo"
L.RAID_HINT_showInParty = "Un grupo de 5 como banda; sin marcos de grupo"
L.RAID_HINT_hideBlizzard = "Necesita /reload para volver a mostrarlos"
L.RAID_HINT_sizeMode = "Automático: tamaño de la instancia, si no del grupo"
L.RAID_HINT_x = "Esquina superior izquierda, desde el centro"
L.RAID_HINT_y = "Esquina superior izquierda, desde el centro"
L.RAID_HINT_sortBy = "Rol: tanques, sanadores, daño y el resto"
L.RAID_HINT_classOrder = "Nombres de clase, p. ej. Sacerdote, Druida"
L.RAID_HINT_hideEmpty = "Los bloques sin miembros no ocupan sitio"
L.RAID_HINT_blocksPerLine = "Luego una nueva fila (o columna) de bloques"
L.RAID_HINT_cellsPerLine = "Luego una nueva columna (o fila) de celdas"
L.RAID_HINT_dispelTint = "Toda la celda en el color del tipo de perjuicio"
L.RAID_HINT_debuffRow = "Cada perjuicio, a lo largo del borde inferior"
L.RAID_HINT_indicatorSpells = "IDs de hechizo o nombres de tu libro de hechizos"
L.RAID_HINT_roleIconDamager = "Tanques y sanadores siempre"
L.RAID_HINT_aggroBorder = "Por dentro del borde de la celda"
L.RAID_ENUM_sizeMode_AUTO = "Automático"
L.RAID_ENUM_sizeMode_10 = "10 jugadores"
L.RAID_ENUM_sizeMode_20 = "20 jugadores"
L.RAID_ENUM_sizeMode_40 = "40 jugadores"
L.RAID_ENUM_groupBy_GROUP = "Grupo"
L.RAID_ENUM_groupBy_CLASS = "Clase"
L.RAID_ENUM_groupBy_ROLE = "Rol"
L.RAID_ENUM_groupBy_NONE = "Ninguno (un bloque)"
L.RAID_ENUM_sortBy_INDEX = "Orden de la banda"
L.RAID_ENUM_sortBy_NAME = "Nombre"
L.RAID_ENUM_sortBy_ROLE = "Rol"
L.RAID_ENUM_blockDirection_HORIZONTAL = "Uno al lado del otro"
L.RAID_ENUM_blockDirection_VERTICAL = "Uno encima del otro"
L.RAID_ENUM_cellGrowth_DOWN = "Hacia abajo"
L.RAID_ENUM_cellGrowth_RIGHT = "Hacia la derecha"
L.RAID_ENUM_healthColorMode_CLASS = "Clase"
L.RAID_ENUM_healthColorMode_STATIC = "Color del marco de grupo"
L.RAID_ENUM_healthColorMode_GRADIENT = "Degradado según la salud"
L.RAID_ENUM_powerStrip_ALL = "Todos"
L.RAID_ENUM_powerStrip_MANA = "Usuarios de maná"
L.RAID_ENUM_powerStrip_HEALERS = "Sanadores"
L.RAID_ENUM_powerStrip_OFF = "Desactivada"
L.RAID_ENUM_secondLine_DEFICIT = "Salud que falta"
L.RAID_ENUM_secondLine_PERCENT = "Porcentaje"
L.RAID_ENUM_secondLine_CURRENT = "Salud actual"
L.RAID_ENUM_secondLine_NONE = "Ninguna"
L.RAID_ENUM_dispelFilter_MINE = "Que puedo disipar"
L.RAID_ENUM_dispelFilter_ALL = "Cualquiera disipable"
L.RAID_ENUM_indicatorTime_SWIPE = "Oscurecer"
L.RAID_ENUM_indicatorTime_NUMBER = "Número"
L.RAID_ENUM_indicatorTime_NONE = "No mostrar"
```

- [ ] **Step 8: French**

Append to the end of `Locales/frFR.lua`:

```lua

-- Cadres de raid : le menu des options (Raid/Options/Schema.lua).
L.RAID_TAB_general = "Général"
L.RAID_TAB_layout = "Disposition"
L.RAID_TAB_cell = "Cellule"
L.RAID_TAB_texts = "Textes"
L.RAID_TAB_debuffs = "Affaiblissements"
L.RAID_TAB_indicators = "Indicateurs"
L.RAID_TAB_icons = "Icônes et états"
L.RAID_NOTE_cell = "La texture des barres, la police et les couleurs des soins et boucliers suivent le cadre de groupe."
L.RAID_SECTION_raidFrames = "Cadres de raid"
L.RAID_SECTION_grouping = "Regroupement"
L.RAID_SECTION_arrangement = "Agencement"
L.RAID_SECTION_position = "Position"
L.RAID_SECTION_borders = "Bordures"
L.RAID_SECTION_size = "Taille"
L.RAID_SECTION_bars = "Barres"
L.RAID_SECTION_texts = "Textes"
L.RAID_SECTION_dispel = "Affaiblissement dissipable"
L.RAID_SECTION_debuffRow = "Rangée d'affaiblissements"
L.RAID_SECTION_indicatorTopLeft = "Coin supérieur gauche"
L.RAID_SECTION_indicatorTopRight = "Coin supérieur droit"
L.RAID_SECTION_indicatorBottomLeft = "Coin inférieur gauche"
L.RAID_SECTION_indicatorBottomRight = "Coin inférieur droit"
L.RAID_SECTION_indicatorTop = "Bord supérieur"
L.RAID_SECTION_icons = "Icônes"
L.RAID_SECTION_role = "Rôle"
L.RAID_SECTION_raidMarker = "Marqueur de cible"
L.RAID_SECTION_leader = "Chef et assistants"
L.RAID_SECTION_looter = "Maître du butin"
L.RAID_SECTION_readyCheck = "Appel"
L.RAID_SECTION_states = "États"
L.RAID_SETTING_enabled = "Afficher les cadres de raid"
L.RAID_SETTING_showInParty = "Vue de raid en groupe"
L.RAID_SETTING_hideBlizzard = "Masquer les cadres de Blizzard"
L.RAID_SETTING_sizeMode = "Taille affichée"
L.RAID_SETTING_x = "Position X"
L.RAID_SETTING_y = "Position Y"
L.RAID_SETTING_groupBy = "Regrouper par"
L.RAID_SETTING_sortBy = "Tri dans un bloc"
L.RAID_SETTING_classOrder = "Ordre des classes"
L.RAID_SETTING_blockDirection = "Blocs"
L.RAID_SETTING_blocksPerLine = "Blocs par ligne"
L.RAID_SETTING_blockSpacing = "Espacement des blocs"
L.RAID_SETTING_cellGrowth = "Les cellules s'ajoutent"
L.RAID_SETTING_cellsPerLine = "Cellules par ligne"
L.RAID_SETTING_cellSpacing = "Espacement des cellules"
L.RAID_SETTING_cellWidth = "Largeur de cellule"
L.RAID_SETTING_cellHeight = "Hauteur de cellule"
L.RAID_SETTING_blockTitles = "Titres des blocs"
L.RAID_SETTING_hideEmpty = "Masquer les blocs vides"
L.RAID_SETTING_panelBorder = "Autour du panneau"
L.RAID_SETTING_blockBorder = "Autour de chaque bloc"
L.RAID_SETTING_cellBorder = "Autour de chaque cellule"
L.RAID_SETTING_healthColorMode = "Couleur de la santé"
L.RAID_SETTING_powerStrip = "Bande de ressource"
L.RAID_SETTING_secondLine = "Deuxième ligne"
L.RAID_SETTING_nameClassColor = "Nom en couleur de classe"
L.RAID_SETTING_dispelIcon = "Icône au centre"
L.RAID_SETTING_dispelFilter = "Quels affaiblissements"
L.RAID_SETTING_dispelIconSize = "Taille de l'icône"
L.RAID_SETTING_dispelTint = "Teinter la cellule"
L.RAID_SETTING_debuffRow = "Afficher la rangée"
L.RAID_SETTING_debuffCount = "Nombre d'icônes"
L.RAID_SETTING_debuffSize = "Taille des icônes"
L.RAID_SETTING_indicatorSpells = "Sorts"
L.RAID_SETTING_indicatorColor = "Couleur"
L.RAID_SETTING_indicatorSize = "Taille"
L.RAID_SETTING_indicatorOwn = "Vos propres sorts seulement"
L.RAID_SETTING_indicatorTime = "Temps restant"
L.RAID_SETTING_iconShow = "Afficher"
L.RAID_SETTING_iconPoint = "Position"
L.RAID_SETTING_roleIconDamager = "Dégâts aussi"
L.RAID_SETTING_iconSize = "Taille des icônes"
L.RAID_SETTING_rangeFade = "Estomper hors de portée"
L.RAID_SETTING_rangeAlpha = "Opacité hors de portée (%)"
L.RAID_SETTING_aggroBorder = "Ligne rouge en cas d'aggro"
L.RAID_SETTING_targetBorder = "Ligne claire sur votre cible"
L.RAID_HINT_showInParty = "Un groupe de 5 comme un raid ; cadres de groupe masqués"
L.RAID_HINT_hideBlizzard = "Nécessite /reload pour les réafficher"
L.RAID_HINT_sizeMode = "Automatique : taille de l'instance, sinon du groupe"
L.RAID_HINT_x = "Coin supérieur gauche, depuis le centre"
L.RAID_HINT_y = "Coin supérieur gauche, depuis le centre"
L.RAID_HINT_sortBy = "Rôle : tanks, soigneurs, dégâts, puis le reste"
L.RAID_HINT_classOrder = "Noms de classe, p. ex. Prêtre, Druide ; le reste suit"
L.RAID_HINT_hideEmpty = "Les blocs sans membres ne prennent pas de place"
L.RAID_HINT_blocksPerLine = "Puis une nouvelle ligne (ou colonne) de blocs"
L.RAID_HINT_cellsPerLine = "Puis une nouvelle colonne (ou ligne) de cellules"
L.RAID_HINT_dispelTint = "Toute la cellule à la couleur du type d'affaiblissement"
L.RAID_HINT_debuffRow = "Chaque affaiblissement, le long du bas de la cellule"
L.RAID_HINT_indicatorSpells = "ID de sorts ou noms de votre grimoire"
L.RAID_HINT_roleIconDamager = "Tanks et soigneurs toujours"
L.RAID_HINT_aggroBorder = "Le long de l'intérieur de la cellule"
L.RAID_ENUM_sizeMode_AUTO = "Automatique"
L.RAID_ENUM_sizeMode_10 = "10 joueurs"
L.RAID_ENUM_sizeMode_20 = "20 joueurs"
L.RAID_ENUM_sizeMode_40 = "40 joueurs"
L.RAID_ENUM_groupBy_GROUP = "Groupe"
L.RAID_ENUM_groupBy_CLASS = "Classe"
L.RAID_ENUM_groupBy_ROLE = "Rôle"
L.RAID_ENUM_groupBy_NONE = "Aucun (un bloc)"
L.RAID_ENUM_sortBy_INDEX = "Ordre du raid"
L.RAID_ENUM_sortBy_NAME = "Nom"
L.RAID_ENUM_sortBy_ROLE = "Rôle"
L.RAID_ENUM_blockDirection_HORIZONTAL = "Côte à côte"
L.RAID_ENUM_blockDirection_VERTICAL = "Empilés"
L.RAID_ENUM_cellGrowth_DOWN = "Vers le bas"
L.RAID_ENUM_cellGrowth_RIGHT = "Vers la droite"
L.RAID_ENUM_healthColorMode_CLASS = "Classe"
L.RAID_ENUM_healthColorMode_STATIC = "Couleur du cadre de groupe"
L.RAID_ENUM_healthColorMode_GRADIENT = "Dégradé selon la santé"
L.RAID_ENUM_powerStrip_ALL = "Tout le monde"
L.RAID_ENUM_powerStrip_MANA = "Utilisateurs de mana"
L.RAID_ENUM_powerStrip_HEALERS = "Soigneurs"
L.RAID_ENUM_powerStrip_OFF = "Désactivée"
L.RAID_ENUM_secondLine_DEFICIT = "Santé manquante"
L.RAID_ENUM_secondLine_PERCENT = "Pourcentage"
L.RAID_ENUM_secondLine_CURRENT = "Santé actuelle"
L.RAID_ENUM_secondLine_NONE = "Aucune"
L.RAID_ENUM_dispelFilter_MINE = "Dissipables par moi"
L.RAID_ENUM_dispelFilter_ALL = "Tous les dissipables"
L.RAID_ENUM_indicatorTime_SWIPE = "Assombrissement"
L.RAID_ENUM_indicatorTime_NUMBER = "Nombre"
L.RAID_ENUM_indicatorTime_NONE = "Non affiché"
```

- [ ] **Step 9: Run the tests**

Run: `tests/run test_raid_schema.lua` → `946 passed, 0 failed`
Run: `tests/run` → Expected: `22375 passed, 0 failed`

- [ ] **Step 10: Commit**

```bash
git add ForeverUnitFrames.toc Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Raid/Options/Schema.lua tests/test_raid_schema.lua
git commit -m "Raid options menu: tabs, sections and their words

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Raid options window: sizes, tabs and rows, /fuf raid

**Files:**
- Modify: `Options/Window.lua`
- Create: `Raid/Options/Window.lua`
- Modify: `ForeverUnitFrames.toc`
- Modify: `Core/Commands.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_raid_window.lua`

**Interfaces:**
- Consumes: `ns.RaidSchema` (Task 5), `ns.RaidSpellbook.Resolve` (Task 4), `ns.Raid.ParseClassOrder` (Task 3), `ns.RaidConfig`, `ns.RaidSize.Current`, `ns.Widgets`, `ns.Style`, `ns.L`.
- Produces: `ns.Options.Control(parent, def, opts)` (the unit window's row builders for any registry; `opts.enumText` for an enum's words), `ns.Options.ConfirmButton(parent, text, action)`; `ns.RaidOptions`: `Open(size?, tabId?)`, `Close()`, `Toggle()`, `IsOpen()`, `Size()` (the edited size), `SelectSize(size)`, `SelectTab(id)`, `Rebuild()`; fields `frame` (`frame.titleBar.title`, `frame.footer`, `frame.lockedControls`), `sizeTabs[size]` (`text`, `underline`), `sizeModeRow`, `tabButtons`, `currentTab`, `page` (`page.note`), `rows` (each `row.key`), `combatNotice`; window `ForeverUnitFramesRaidOptions` (ESC closes it), position in `ForeverUnitFramesDB.raidWindow`; `/fuf raid`; locale keys `RAID_WINDOW_TITLE`, `RAID_SIZE_SHOWN` (one `%s`); `HELP` names `/fuf raid`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_window.lua`:

```lua
-- The raid options window (Raid/Options/Window.lua): opened with
-- /fuf raid; the edited size and the size shown in the header bar; the
-- raid menu's tabs and rows; names typed for classes and spells; the
-- combat lock; a new window for a new language.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, L = ns.RaidOptions, ns.RaidConfig, ns.L

local function click(button) button:GetScript("OnClick")(button) end
local function rowFor(key)
    for _, row in ipairs(RO.rows) do if row.key == key then return row end end
end
local function keys()
    local list = {}
    for _, row in ipairs(RO.rows) do if row.key then list[#list + 1] = row.key end end
    return table.concat(list, ",")
end
local function enter(row, text)
    row.edit:SetText(text)
    row.edit:GetScript("OnEnterPressed")(row.edit)
end
local function errorBorder(box)
    return box.edges[1]._color[1] == ns.Style.COLORS.error[1]
end

-- Opening.
SlashCmdList.FOREVERUNITFRAMES("raid")
H.checkTrue("/fuf raid opens it", RO.IsOpen())
H.check("not the unit frames' window", ns.Options.IsOpen(), false)
local count = 0
for _, name in ipairs(UISpecialFrames) do if name == "ForeverUnitFramesRaidOptions" then count = count + 1 end end
H.check("ESC closes it", count, 1)
H.check("title", RO.frame.titleBar.title:GetText(), "Raid frames")

-- The header bar: solo, the 10-player profile is shown and edited.
H.check("edits the size shown", RO.Size(), 10)
H.check("10: shown", RO.sizeTabs[10].text:GetText(), "10 players (shown)")
H.check("20: plain", RO.sizeTabs[20].text:GetText(), "20 players")
H.checkTrue("edited size underlined", RO.sizeTabs[10].underline:IsShown())
H.check("others not", RO.sizeTabs[40].underline:IsShown(), false)
H.check("size switch", RO.sizeModeRow.button.text:GetText(), "Automatic")

-- The menu.
local titles = {}
for i, b in ipairs(RO.tabButtons) do titles[i] = b.text:GetText() end
H.check("tabs", table.concat(titles, ","), "General,Layout,Cell,Texts,Debuffs,Indicators,Icons & states")
H.check("first tab", RO.currentTab, "general")
H.check("general rows", keys(), "enabled,showInParty,hideBlizzard")
H.check("label", rowFor("showInParty").label:GetText(), "Raid view in a party")
H.check("hint", rowFor("hideBlizzard").hintText:GetText(), "Needs /reload to show them again")
click(rowFor("showInParty").box)
H.check("character-wide setting", RC.Get("general", "showInParty"), true)
click(rowFor("showInParty").box)

RO.SelectTab("layout")
H.checkTrue("selected tab underlined", RO.tabButtons[2].underline:IsShown())
enter(rowFor("cellsPerLine"), "4")
H.check("set on the edited size", RC.Get("r10", "cellsPerLine"), 4)
H.check("other sizes untouched", RC.Get("r40", "cellsPerLine"), 5)
H.check("choice words", rowFor("blockDirection").button.text:GetText(), "Side by side")

-- Another size: the rows show and change its profile.
click(RO.sizeTabs[40])
H.check("edits 40", RO.Size(), 40)
H.checkTrue("40 underlined", RO.sizeTabs[40].underline:IsShown())
H.check("10 still shown", RO.sizeTabs[10].text:GetText(), "10 players (shown)")
H.check("row reads 40", rowFor("cellsPerLine").edit:GetText(), "5")
enter(rowFor("blocksPerLine"), "2")
H.check("set on 40", RC.Get("r40", "blocksPerLine"), 2)
H.check("10 untouched", RC.Get("r10", "blocksPerLine"), 8)
RO.SelectTab("cell")
H.check("cell width of 40", rowFor("cellWidth").edit:GetText(), "80")
H.check("the cell's note", RO.page.note:GetText(), L.RAID_NOTE_cell)

-- The size switch: the panel shows 20; the marker follows.
click(RO.sizeModeRow.button)
local list = ns.Widgets.list
H.checkTrue("size list open", list:IsShown())
H.check("four choices", #list.items, 4)
click(list.rows[3])
H.check("switch set", RC.Get("general", "sizeMode"), "20")
H.check("20 now shown", RO.sizeTabs[20].text:GetText(), "20 players (shown)")
H.check("10 no longer", RO.sizeTabs[10].text:GetText(), "10 players")
H.check("still editing 40", RO.Size(), 40)
RC.Set("general", "sizeMode", "AUTO")
H.check("switch follows a change from elsewhere", RO.sizeModeRow.button.text:GetText(), "Automatic")

-- Typed names: class names to tokens, spell names to their ranks' IDs.
RO.SelectTab("layout")
enter(rowFor("classOrder"), "priest, Druid")
H.check("class order stored as tokens", RC.Get("r40", "classOrder"), "PRIEST,DRUID")
H.check("shown as stored", rowFor("classOrder").edit:GetText(), "PRIEST,DRUID")
enter(rowFor("classOrder"), "Priest, Monk")
H.check("unknown class refused", RC.Get("r40", "classOrder"), "PRIEST,DRUID")
H.checkTrue("refusal flashes", errorBorder(rowFor("classOrder").edit))
RO.SelectTab("indicators")
H.check("five positions", #RO.rows, 5 * 6)
M.known[2050], M.known[2052] = true, true
local spells = rowFor("indicatorTopLeftSpells")
H.check("spells hint", spells.hintText:GetText(), "Spell IDs, or names from your spell book")
enter(spells, "139, Lesser Heal")
H.check("names to the IDs of their ranks", RC.Get("r40", "indicatorTopLeftSpells"), "139,2050,2052")
enter(spells, "Nope")
H.check("unknown spell refused", RC.Get("r40", "indicatorTopLeftSpells"), "139,2050,2052")
H.checkTrue("spell refusal flashes", errorBorder(spells.edit))
H.check("point words", ns.RaidSchema.EnumText(ns.RaidSettings.Get("roleIconPoint"), "LEFT"), "Left")

-- Live refresh from outside.
RC.Set("r40", "indicatorTopLeftSize", 12)
H.check("row follows", rowFor("indicatorTopLeftSize").edit:GetText(), "12")

-- Combat: rows and the size switch lock, the notice shows.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("row locked", rowFor("indicatorTopLeftSize").edit._enabled, false)
H.check("size switch locked", RO.sizeModeRow.button:IsEnabled(), false)
H.checkTrue("notice", RO.combatNotice:IsShown())
H.check("sizes stay selectable", RO.sizeTabs[20]:IsEnabled(), true)
M.SetCombat(false)
H.check("row unlocked", rowFor("indicatorTopLeftSize").edit._enabled, true)
H.check("notice gone", RO.combatNotice:IsShown(), false)

-- Position saved, toggled closed by the slash command.
local f = RO.frame
f._points = { { "TOPLEFT", UIParent, "TOPLEFT", 120, -80 } }
f.titleBar:GetScript("OnDragStop")(f.titleBar)
H.check("position saved", ForeverUnitFramesDB.raidWindow.x, 120)
SlashCmdList.FOREVERUNITFRAMES("raid")
H.check("toggled closed", RO.IsOpen(), false)
RO.Open()
H.check("reopens on the same size", RO.Size(), 40)
H.check("and tab", RO.currentTab, "indicators")
H.check("where it was", select(4, RO.frame:GetPoint(1)), 120)

-- A new language: a new window on the same size and tab.
ns.Config.Set("general", "language", "deDE")
H.checkTrue("new window", RO.frame ~= f)
H.check("old one hidden", f:IsShown(), false)
H.checkTrue("open", RO.IsOpen())
H.check("German tabs", RO.tabButtons[1].text:GetText(), "Allgemein")
H.check("German sizes", RO.sizeTabs[10].text:GetText(), "10 Spieler (angezeigt)")
H.check("size kept", RO.Size(), 40)
count = 0
for _, name in ipairs(UISpecialFrames) do if name == "ForeverUnitFramesRaidOptions" then count = count + 1 end end
H.check("ESC entry not doubled", count, 1)
ns.Config.Set("general", "language", "AUTO")

-- The slash help names it.
SlashCmdList.FOREVERUNITFRAMES("help")
H.checkTrue("help names /fuf raid", M.chat[#M.chat]:find("/fuf raid", 1, true))
H.check("nothing blocked", #M.blocked, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_window.lua`

Expected:

```text
test_raid_window.lua
  ERROR test_raid_window.lua:31: attempt to index local 'RO' (a nil value)
0 passed, 1 failed
```

- [ ] **Step 3: Two exports of the unit window**

Behaviour of the unit window unchanged: `enumItems` falls back to the unit frames' words, the exports are the existing local functions.

In `Options/Window.lua`:

Replace

```lua

-- Setting rows ------------------------------------------------------------------

local function enumItems(def)
    return function()
        local items = {}
        for _, v in ipairs(def.values) do items[#items + 1] = { value = v, text = Schema.EnumText(def, v) } end
        return items
    end
end
```

with

```lua

-- Setting rows ------------------------------------------------------------------

-- enumText (optional): the words of the choices; the unit frames' by
-- default (the raid window has its own).
local function enumItems(def, enumText)
    enumText = enumText or Schema.EnumText
    return function()
        local items = {}
        for _, v in ipairs(def.values) do items[#items + 1] = { value = v, text = enumText(def, v) } end
        return items
    end
end
```

In `Options/Window.lua`:

Replace

```lua
    end,
    bool = function(parent, _, opts) return Widgets.Checkbox(parent, opts) end,
    enum = function(parent, def, opts)
        opts.items = enumItems(def)
        return Widgets.Dropdown(parent, opts)
    end,
    media = function(parent, def, opts)
```

with

```lua
    end,
    bool = function(parent, _, opts) return Widgets.Checkbox(parent, opts) end,
    enum = function(parent, def, opts)
        opts.items = enumItems(def, opts.enumText)
        return Widgets.Dropdown(parent, opts)
    end,
    media = function(parent, def, opts)
```

In `Options/Window.lua`:

Replace

```lua
        return Widgets.TextInput(parent, opts)
    end,
}

local function inheritOpts(scope, key)
    return {
```

with

```lua
        return Widgets.TextInput(parent, opts)
    end,
}

-- The control row for a setting definition of any registry (the raid
-- window builds its rows with it): opts as for the widgets, plus
-- opts.enumText for an enum's words.
function Options.Control(parent, def, opts)
    return ROW_BUILDERS[def.type](parent, def, opts)
end

local function inheritOpts(scope, key)
    return {
```

In `Options/Window.lua`:

Replace

```lua
    button.Disarm = disarm
    return button
end

-- Section actions: what the button does. Two clicks, like Reset.
local ACTIONS = {
```

with

```lua
    button.Disarm = disarm
    return button
end
Options.ConfirmButton = confirmButton

-- Section actions: what the button does. Two clicks, like Reset.
local ACTIONS = {
```

- [ ] **Step 4: The window**

Create `Raid/Options/Window.lua`:

```lua
local _, ns = ...

-- The raid options window, in the style of the unit frames' (the same
-- widgets and colours): a header bar with the raid size whose profile is
-- edited (the one shown now is marked) and which size the panel shows,
-- the tabs of the raid menu (Raid/Options/Schema.lua) and their rows. A
-- plain (non-secure) frame: every change goes through ns.RaidConfig,
-- whose RAID_CONFIG_CHANGED listeners restyle the raid panel out of
-- combat. In combat the window stays open but its controls lock.
local RaidOptions = {}
ns.RaidOptions = RaidOptions

local Style, Widgets, Schema, L = ns.Style, ns.Widgets, ns.RaidSchema, ns.L
local RaidConfig, Raid = ns.RaidConfig, ns.Raid

local WINDOW_NAME = "ForeverUnitFramesRaidOptions"
local WIDTH, HEIGHT = 780, 560
local TITLE_H, SIZE_BAR_H, TAB_H, FOOTER_H, NOTICE_H = 32, 40, 30, 40, 26
local SIZE_TAB_PADDING, TAB_PADDING, TAB_MIN_W, UNDERLINE_H, ACCENT_W = 24, 28, 70, 2, 3
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET, NOTE_H = 4, 16, 8, 16, 34
local BUTTON_H, DROPDOWN_W, GAP = 24, 160, 8
local DEFAULT_POSITION = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 90, y = -150 }

local frame
local pages = {}
local inCombat = false

-- Helpers ---------------------------------------------------------------------

local function line(parent, colorKey)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(unpack(Style.COLORS[colorKey]))
    return t
end

local function horizontalLine(parent, anchor)
    local t = line(parent, "border")
    t:SetHeight(1)
    t:SetPoint(anchor .. "LEFT"); t:SetPoint(anchor .. "RIGHT")
    return t
end

local function forEachRow(fn)
    for _, row in ipairs(RaidOptions.rows or {}) do fn(row) end
end

-- The size whose profile the window edits.
function RaidOptions.Size()
    return RaidOptions.size or ns.RaidSize.Current() or Raid.SIZES[1]
end

-- Where a setting lives: the character's, or the edited size's.
local function scopeOf(def)
    if def.scope == "general" then return "general" end
    return Raid.Scope(RaidOptions.Size())
end

local function sizeText(size) return Schema.EnumText(ns.RaidSettings.Get("sizeMode"), tostring(size)) end

-- Position (SavedVariables only, like the unit frames' window) -------------------

local function savedPosition()
    local pos = ForeverUnitFramesDB and ForeverUnitFramesDB.raidWindow
    if type(pos) == "table" and type(pos.point) == "string"
        and type(pos.x) == "number" and type(pos.y) == "number" then
        return pos
    end
    return DEFAULT_POSITION
end

local function restorePosition()
    local pos = savedPosition()
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
end

local function savePosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if not point then return end
    ForeverUnitFramesDB = ForeverUnitFramesDB or {}
    ForeverUnitFramesDB.raidWindow = { point = point, relativePoint = relativePoint or point, x = x, y = y }
end

-- Setting rows ------------------------------------------------------------------

-- What a typed text becomes before it is stored: class names to tokens,
-- spell names to the IDs of their ranks. nil refuses it.
local function typedValue(key)
    if key == "classOrder" then return Raid.ParseClassOrder end
    if key:match("^indicator%a+Spells$") then return ns.RaidSpellbook.Resolve end
    return nil
end

local function settingRow(parent, key)
    local def = ns.RaidSettings.Get(key)
    local convert = typedValue(key)
    local row = ns.Options.Control(parent, def, {
        label = Schema.Label(key), hint = Schema.Hint(key), enumText = Schema.EnumText,
        get = function() return RaidConfig.Get(scopeOf(def), key) end,
        set = function(v)
            if convert then v = convert(v) end
            if v == nil then return false end
            return RaidConfig.Set(scopeOf(def), key, v)
        end,
    })
    row.key = key
    return row
end

-- Pages -------------------------------------------------------------------------

local function newStack(page)
    local stack = { y = PAGE_TOP, rows = {} }
    function stack.add(row, height)
        if row.isSection and #stack.rows > 0 then stack.y = stack.y + SECTION_GAP end
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -stack.y)
        row:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -stack.y)
        row:SetHeight(height or row:GetHeight())
        stack.rows[#stack.rows + 1] = row
        stack.y = stack.y + row:GetHeight()
    end
    function stack.finish()
        page.rows, page.height = stack.rows, stack.y + PAGE_BOTTOM
    end
    return stack
end

-- A muted line of text above the sections, as wide as the page.
local function noteBlock(page, text)
    local block = CreateFrame("Frame", nil, page)
    block.text = Style.Text(block, 11, "muted")
    block.text:SetPoint("TOPLEFT", block, "TOPLEFT", INSET, -6)
    block.text:SetPoint("TOPRIGHT", block, "TOPRIGHT", -INSET, -6)
    block.text:SetJustifyH("LEFT")
    block.text:SetWordWrap(true)
    block.text:SetText(text)
    function block:Refresh() end
    function block:SetEnabled() end
    page.note = block.text
    return block
end

local function buildPage(page, tab)
    local stack = newStack(page)
    if tab.note then stack.add(noteBlock(page, Schema.Note(tab.note)), NOTE_H) end
    for _, section in ipairs(tab.sections) do
        local header = Widgets.Header(page, Schema.SectionTitle(section.id))
        header.isSection = true
        stack.add(header)
        for _, key in ipairs(section.keys) do stack.add(settingRow(page, key)) end
    end
    stack.finish()
end

-- One page per tab: the rows read the edited size when they refresh.
local function pageFor(tab)
    if pages[tab.id] then return pages[tab.id] end
    local page = CreateFrame("Frame", nil, frame.scrollChild)
    page:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, 0)
    page:SetWidth(CONTENT_W)
    buildPage(page, tab)
    page:SetHeight(page.height)
    page:Hide()
    pages[tab.id] = page
    return page
end

-- Scrolling ---------------------------------------------------------------------

local function updateScrollbar()
    local scroll, thumb = frame.scroll, frame.scrollThumb
    local range, view = scroll:GetVerticalScrollRange(), scroll:GetHeight()
    if range <= 0 or view <= 0 then thumb:Hide(); return end
    local thumbH = view * view / (view + range)
    thumb:SetHeight(thumbH)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", SCROLLBAR_W - 3, -(view - thumbH) * scroll:GetVerticalScroll() / range)
    thumb:Show()
end

local function onWheel(scroll, delta)
    local v = scroll:GetVerticalScroll() - delta * WHEEL_STEP
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange(), v)))
    updateScrollbar()
end

local function createScroll(body)
    local scroll = CreateFrame("ScrollFrame", nil, body)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", onWheel)
    scroll:SetScript("OnScrollRangeChanged", updateScrollbar)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(CONTENT_W, 1)
    scroll:SetScrollChild(child)
    local thumb = body:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(unpack(Style.COLORS.accent))
    thumb:SetWidth(2)
    thumb:Hide()
    frame.scroll, frame.scrollChild, frame.scrollThumb = scroll, child, thumb
end

-- Tabs: the raid sizes and the menu ------------------------------------------------

local function paintSelection(entry, selected, idleColor)
    Style.Paint(entry.text, selected and "accent" or idleColor)
    entry.selected = selected
end

local function hoverable(button, idleColor)
    button:SetScript("OnEnter", function(self)
        if not self.selected then Style.Paint(self.text, "text") end
    end)
    button:SetScript("OnLeave", function(self)
        if not self.selected then Style.Paint(self.text, idleColor) end
    end)
end

local function tabButton(parent, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(height)
    b.text = Style.Text(b, 12, "muted")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.underline = line(b, "accent")
    b.underline:SetHeight(UNDERLINE_H)
    b.underline:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 8, 0)
    b.underline:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 0)
    hoverable(b, "muted")
    return b
end

-- The sizes: the edited one underlined, the one shown now says so.
local function renderSizeTabs()
    local shown = ns.RaidSize.Current()
    for _, size in ipairs(Raid.SIZES) do
        local b = RaidOptions.sizeTabs[size]
        local text = sizeText(size)
        if size == shown then text = L.RAID_SIZE_SHOWN:format(text) end
        b.text:SetText(text)
        b:SetWidth((b.text:GetStringWidth() or 0) + SIZE_TAB_PADDING)
        paintSelection(b, size == RaidOptions.Size(), "muted")
        b.underline:SetShown(size == RaidOptions.Size())
    end
end

local function menuTabs()
    for i, tab in ipairs(Schema.TABS) do
        local b = tabButton(frame.tabRow, TAB_H)
        b.tabId = tab.id
        b.text:SetText(Schema.TabTitle(tab.id))
        b:SetWidth(math.max(TAB_MIN_W, (b.text:GetStringWidth() or 0) + TAB_PADDING))
        b:SetScript("OnClick", function(self) RaidOptions.SelectTab(self.tabId) end)
        local previous = RaidOptions.tabButtons[i - 1]
        if previous then
            b:SetPoint("LEFT", previous, "RIGHT", 0, 0)
        else
            b:SetPoint("LEFT", frame.tabRow, "LEFT", 8, 0)
        end
        RaidOptions.tabButtons[i] = b
    end
end

local function paintTabs()
    for _, b in ipairs(RaidOptions.tabButtons) do
        local selected = b.tabId == RaidOptions.currentTab
        paintSelection(b, selected, "muted")
        b.underline:SetShown(selected)
    end
end

-- Header bar ----------------------------------------------------------------------

-- A dropdown that is only its button: the size the panel shows.
local function sizeModeRow(bar)
    local def = ns.RaidSettings.Get("sizeMode")
    local row = ns.Options.Control(bar, def, {
        enumText = Schema.EnumText,
        get = function() return RaidConfig.Get("general", "sizeMode") end,
        set = function(v) return RaidConfig.Set("general", "sizeMode", v) end,
    })
    row:SetSize(DROPDOWN_W, BUTTON_H)
    row:EnableMouse(false)
    row.hover:SetAlpha(0)
    row.button:ClearAllPoints()
    row.button:SetAllPoints(row)
    row:SetPoint("RIGHT", bar, "RIGHT", -12, 0)
    local label = Style.Text(bar, 12, "muted")
    label:SetPoint("RIGHT", row, "LEFT", -GAP, 0)
    label:SetText(Schema.Label("sizeMode"))
    row:Refresh()
    return row
end

local function createSizeBar(parent, titleBar)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(SIZE_BAR_H)
    bar:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    Style.Fill(bar, "panel")
    horizontalLine(bar, "BOTTOM")
    RaidOptions.sizeTabs = {}
    local previous
    for _, size in ipairs(Raid.SIZES) do
        local b = tabButton(bar, SIZE_BAR_H)
        b:SetScript("OnClick", function() RaidOptions.SelectSize(size) end)
        if previous then b:SetPoint("LEFT", previous, "RIGHT", 0, 0) else b:SetPoint("LEFT", bar, "LEFT", 8, 0) end
        RaidOptions.sizeTabs[size] = b
        previous = b
    end
    RaidOptions.sizeModeRow = sizeModeRow(bar)
    frame.sizeBar = bar
end

-- Combat lock -------------------------------------------------------------------

local function anchorScroll()
    local top = inCombat and RaidOptions.combatNotice or frame.tabRow
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -SCROLLBAR_W, 0)
end

local function applyLock()
    local on = not inCombat
    forEachRow(function(row) row:SetEnabled(on) end)
    for _, control in ipairs(frame.lockedControls) do control:SetEnabled(on) end
    RaidOptions.combatNotice:SetShown(inCombat)
    anchorScroll()
end

-- Title bar, footer, body ---------------------------------------------------------

local CROSS_SIZE, CROSS_ANGLE = 14, math.pi / 4

local function closeButton(titleBar)
    local b = CreateFrame("Button", nil, titleBar)
    b:SetSize(TITLE_H, TITLE_H)
    b:SetPoint("RIGHT", titleBar, "RIGHT", 0, 0)
    b.lines = {}
    for i, angle in ipairs({ CROSS_ANGLE, -CROSS_ANGLE }) do
        local t = line(b, "muted")
        t:SetSize(CROSS_SIZE, 2)
        t:SetPoint("CENTER")
        t:SetRotation(angle)
        b.lines[i] = t
    end
    local function paint(colorKey)
        for _, t in ipairs(b.lines) do t:SetColorTexture(unpack(Style.COLORS[colorKey])) end
    end
    b:SetScript("OnEnter", function() paint("accent") end)
    b:SetScript("OnLeave", function() paint("muted") end)
    b:SetScript("OnClick", function() RaidOptions.Close() end)
    return b
end

local function createTitleBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    Style.Fill(bar, "panel")
    horizontalLine(bar, "BOTTOM")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePosition()
    end)
    local title = Style.Text(bar, 16, "text")
    title:SetPoint("LEFT", bar, "LEFT", INSET, 0)
    title:SetText(L.RAID_WINDOW_TITLE)
    local addon = Style.Text(bar, 11, "muted")
    addon:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
    addon:SetText(L.ADDON_NAME)
    bar.title, bar.close = title, closeButton(bar)
    return bar
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    frame.footer = footer
    return footer
end

local function createNotice(body)
    local notice = CreateFrame("Frame", nil, body)
    notice:SetHeight(NOTICE_H)
    notice:SetPoint("TOPLEFT", frame.tabRow, "BOTTOMLEFT", 0, 0)
    notice:SetPoint("TOPRIGHT", frame.tabRow, "BOTTOMRIGHT", 0, 0)
    local tint = notice:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints(notice)
    local a = Style.COLORS.accent
    tint:SetColorTexture(a[1], a[2], a[3], 0.12)
    local bar = line(notice, "accent")
    bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(ACCENT_W)
    local text = Style.Text(notice, 12, "accent")
    text:SetPoint("LEFT", notice, "LEFT", INSET, 0)
    text:SetText(L.COMBAT_LOCKED)
    notice:Hide()
    RaidOptions.combatNotice = notice
end

local function createBody(parent, top, footer)
    local body = CreateFrame("Frame", nil, parent)
    body:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
    frame.body = body
    local tabRow = CreateFrame("Frame", nil, body)
    tabRow:SetHeight(TAB_H)
    tabRow:SetPoint("TOPLEFT"); tabRow:SetPoint("TOPRIGHT")
    horizontalLine(tabRow, "BOTTOM")
    frame.tabRow = tabRow
    RaidOptions.tabButtons = {}
    menuTabs()
    createNotice(body)
    createScroll(body)
    anchorScroll()
end

-- Window ------------------------------------------------------------------------

local function createWindow()
    frame = CreateFrame("Frame", WINDOW_NAME, UIParent)
    RaidOptions.frame = frame
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetDontSavePosition(true)
    frame:EnableMouse(true)
    Style.Fill(frame, "bg")
    Style.Border(frame)
    frame.titleBar = createTitleBar(frame)
    createSizeBar(frame, frame.titleBar)
    local footer = createFooter(frame)
    createBody(frame, frame.sizeBar, footer)
    -- Locked in combat with the rows.
    frame.lockedControls = { RaidOptions.sizeModeRow }
    -- Hiding the window (ESC, close button, /fuf raid) takes an open
    -- dropdown list with it.
    frame:SetScript("OnHide", function() Widgets.CloseList() end)
    frame:Hide()
    for _, name in ipairs(UISpecialFrames) do
        if name == WINDOW_NAME then return end
    end
    table.insert(UISpecialFrames, WINDOW_NAME)
end

local function ensureWindow()
    if not frame then createWindow() end
end

local function refreshAll()
    forEachRow(function(row) row:Refresh() end)
    RaidOptions.sizeModeRow:Refresh()
    renderSizeTabs()
end

-- Public API ----------------------------------------------------------------------

function RaidOptions.IsOpen()
    return frame ~= nil and frame:IsShown()
end

function RaidOptions.SelectTab(id)
    ensureWindow()
    for _, tab in ipairs(Schema.TABS) do
        if tab.id == id then
            Widgets.CloseList()
            if RaidOptions.page then RaidOptions.page:Hide() end
            local page = pageFor(tab)
            RaidOptions.page, RaidOptions.currentTab, RaidOptions.rows = page, id, page.rows
            frame.scrollChild:SetHeight(page.height)
            frame.scroll:SetVerticalScroll(0)
            page:Show()
            forEachRow(function(row) row:Refresh() end)
            paintTabs()
            applyLock()
            updateScrollbar()
            return
        end
    end
end

-- Edits another size's profile: the rows read it from now on.
function RaidOptions.SelectSize(size)
    ensureWindow()
    Raid.Scope(size)
    Widgets.CloseList()
    RaidOptions.size = size
    refreshAll()
end

function RaidOptions.Open(size, tabId)
    if not RaidConfig.Profile() then return end
    ensureWindow()
    if InCombatLockdown() then inCombat = true end
    if not frame:IsShown() then
        restorePosition()
        frame:Show()
    end
    RaidOptions.SelectSize(size or RaidOptions.Size())
    RaidOptions.SelectTab(tabId or RaidOptions.currentTab or Schema.TABS[1].id)
end

function RaidOptions.Close()
    if frame then frame:Hide() end
end

function RaidOptions.Toggle()
    if RaidOptions.IsOpen() then RaidOptions.Close() else RaidOptions.Open() end
end

-- Live updates ----------------------------------------------------------------------

-- Values also change from outside the window: mover drags, Copy, Import,
-- another size becoming the one shown.
ns.Listen("RAID_CONFIG_CHANGED", function()
    if RaidOptions.IsOpen() then refreshAll() end
end)
ns.Listen("RAID_SIZE_CHANGED", function()
    if RaidOptions.IsOpen() then renderSizeTabs() end
end)

-- Every label is set once, when its widget is built: a new language gets a
-- new window (as the unit frames' window does), on the same size and tab.
function RaidOptions.Rebuild()
    if not frame then return end
    local wasOpen = frame:IsShown()
    frame:Hide()
    frame, RaidOptions.frame = nil, nil
    pages = {}
    RaidOptions.page, RaidOptions.rows = nil, nil
    if wasOpen then RaidOptions.Open(RaidOptions.size, RaidOptions.currentTab) end
end

ns.Listen("LANGUAGE_CHANGED", function() RaidOptions.Rebuild() end)

-- Tracked from the events rather than InCombatLockdown(): lockdown only
-- starts after PLAYER_REGEN_DISABLED has fired.
ns.On("PLAYER_REGEN_DISABLED", function()
    inCombat = true
    if frame then applyLock() end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    inCombat = false
    if frame then applyLock() end
end)
```

- [ ] **Step 5: Load it after the menu**

In `ForeverUnitFrames.toc`:

Replace

```text
Options\Window.lua
Options\MinimapButton.lua
Raid\Options\Schema.lua
Core\Debug.lua
Core\Boot.lua
```

with

```text
Options\Window.lua
Options\MinimapButton.lua
Raid\Options\Schema.lua
Raid\Options\Window.lua
Core\Debug.lua
Core\Boot.lua
```

- [ ] **Step 6: /fuf raid**

In `Core/Commands.lua`:

Replace

```lua
        ns.Options.Toggle()
    elseif cmd == "help" then
        ns.Print(L.HELP)
    elseif cmd == "unlock" then
        ns.Movers.Unlock()
    elseif cmd == "lock" then
```

with

```lua
        ns.Options.Toggle()
    elseif cmd == "help" then
        ns.Print(L.HELP)
    elseif cmd == "raid" then
        ns.RaidOptions.Toggle()
    elseif cmd == "unlock" then
        ns.Movers.Unlock()
    elseif cmd == "lock" then
```

- [ ] **Step 7: The words in English (and the slash help)**

In `Locales/enUS.lua`:

Replace

```lua
L.LOCKED_IN_COMBAT = "Frames cannot be moved in combat."
L.UNLOCKED = "Frames unlocked. Drag them, then type /fuf lock."
L.LOCKED = "Frames locked."
L.HELP = "/fuf opens the options. Also: /fuf unlock, /fuf lock, /fuf status, /fuf reset <frame|all>, /fuf set <scope> <setting> <value>"
L.INVALID_VALUE = "Invalid setting or value."
L.UNKNOWN_FRAME = "Unknown frame. Use: player, target, targettarget, pet, focus, party or all."
L.RESET_DONE = "Settings reset."
```

with

```lua
L.LOCKED_IN_COMBAT = "Frames cannot be moved in combat."
L.UNLOCKED = "Frames unlocked. Drag them, then type /fuf lock."
L.LOCKED = "Frames locked."
L.HELP = "/fuf opens the options, /fuf raid the raid frames' options. Also: /fuf unlock, /fuf lock, /fuf status, /fuf reset <frame|all>, /fuf set <scope> <setting> <value>"
L.INVALID_VALUE = "Invalid setting or value."
L.UNKNOWN_FRAME = "Unknown frame. Use: player, target, targettarget, pet, focus, party or all."
L.RESET_DONE = "Settings reset."
```

Append to the end of `Locales/enUS.lua`:

```lua

-- Raid frames: the options window (Raid/Options/Window.lua).
L.RAID_WINDOW_TITLE = "Raid frames"
L.RAID_SIZE_SHOWN = "%s (shown)"
```

- [ ] **Step 8: German**

In `Locales/deDE.lua`:

Replace

```lua
L.LOCKED_IN_COMBAT = "Rahmen können im Kampf nicht verschoben werden."
L.UNLOCKED = "Rahmen entsperrt. Verschieben, danach /fuf lock eingeben."
L.LOCKED = "Rahmen gesperrt."
L.HELP = "/fuf öffnet die Optionen. Außerdem: /fuf unlock, /fuf lock, /fuf status, /fuf reset <Rahmen|all>, /fuf set <Bereich> <Einstellung> <Wert>"
L.INVALID_VALUE = "Ungültige Einstellung oder ungültiger Wert."
L.UNKNOWN_FRAME = "Unbekannter Rahmen. Möglich: player, target, targettarget, pet, focus, party oder all."
L.RESET_DONE = "Einstellungen zurückgesetzt."
```

with

```lua
L.LOCKED_IN_COMBAT = "Rahmen können im Kampf nicht verschoben werden."
L.UNLOCKED = "Rahmen entsperrt. Verschieben, danach /fuf lock eingeben."
L.LOCKED = "Rahmen gesperrt."
L.HELP = "/fuf öffnet die Optionen, /fuf raid die der Schlachtzugsrahmen. Außerdem: /fuf unlock, /fuf lock, /fuf status, /fuf reset <Rahmen|all>, /fuf set <Bereich> <Einstellung> <Wert>"
L.INVALID_VALUE = "Ungültige Einstellung oder ungültiger Wert."
L.UNKNOWN_FRAME = "Unbekannter Rahmen. Möglich: player, target, targettarget, pet, focus, party oder all."
L.RESET_DONE = "Einstellungen zurückgesetzt."
```

Append to the end of `Locales/deDE.lua`:

```lua

-- Schlachtzugsrahmen: das Optionsfenster (Raid/Options/Window.lua).
L.RAID_WINDOW_TITLE = "Schlachtzugsrahmen"
L.RAID_SIZE_SHOWN = "%s (angezeigt)"
```

- [ ] **Step 9: Spanish**

In `Locales/esES.lua`:

Replace

```lua
L.LOCKED_IN_COMBAT = "Los marcos no se pueden mover en combate."
L.UNLOCKED = "Marcos desbloqueados. Arrástralos y escribe /fuf lock."
L.LOCKED = "Marcos bloqueados."
L.HELP = "/fuf abre las opciones. Además: /fuf unlock, /fuf lock, /fuf status, /fuf reset <marco|all>, /fuf set <ámbito> <ajuste> <valor>"
L.INVALID_VALUE = "Ajuste o valor no válido."
L.UNKNOWN_FRAME = "Marco desconocido. Usa: player, target, targettarget, pet, focus, party o all."
L.RESET_DONE = "Ajustes restablecidos."
```

with

```lua
L.LOCKED_IN_COMBAT = "Los marcos no se pueden mover en combate."
L.UNLOCKED = "Marcos desbloqueados. Arrástralos y escribe /fuf lock."
L.LOCKED = "Marcos bloqueados."
L.HELP = "/fuf abre las opciones, /fuf raid las de los marcos de banda. Además: /fuf unlock, /fuf lock, /fuf status, /fuf reset <marco|all>, /fuf set <ámbito> <ajuste> <valor>"
L.INVALID_VALUE = "Ajuste o valor no válido."
L.UNKNOWN_FRAME = "Marco desconocido. Usa: player, target, targettarget, pet, focus, party o all."
L.RESET_DONE = "Ajustes restablecidos."
```

Append to the end of `Locales/esES.lua`:

```lua

-- Marcos de banda: la ventana de opciones (Raid/Options/Window.lua).
L.RAID_WINDOW_TITLE = "Marcos de banda"
L.RAID_SIZE_SHOWN = "%s (mostrado)"
```

- [ ] **Step 10: French**

In `Locales/frFR.lua`:

Replace

```lua
L.LOCKED_IN_COMBAT = "Les cadres ne peuvent pas être déplacés en combat."
L.UNLOCKED = "Cadres déverrouillés. Déplacez-les, puis tapez /fuf lock."
L.LOCKED = "Cadres verrouillés."
L.HELP = "/fuf ouvre les options. Aussi : /fuf unlock, /fuf lock, /fuf status, /fuf reset <cadre|all>, /fuf set <portée> <réglage> <valeur>"
L.INVALID_VALUE = "Réglage ou valeur non valide."
L.UNKNOWN_FRAME = "Cadre inconnu. Utilisez : player, target, targettarget, pet, focus, party ou all."
L.RESET_DONE = "Réglages réinitialisés."
```

with

```lua
L.LOCKED_IN_COMBAT = "Les cadres ne peuvent pas être déplacés en combat."
L.UNLOCKED = "Cadres déverrouillés. Déplacez-les, puis tapez /fuf lock."
L.LOCKED = "Cadres verrouillés."
L.HELP = "/fuf ouvre les options, /fuf raid celles des cadres de raid. Aussi : /fuf unlock, /fuf lock, /fuf status, /fuf reset <cadre|all>, /fuf set <portée> <réglage> <valeur>"
L.INVALID_VALUE = "Réglage ou valeur non valide."
L.UNKNOWN_FRAME = "Cadre inconnu. Utilisez : player, target, targettarget, pet, focus, party ou all."
L.RESET_DONE = "Réglages réinitialisés."
```

Append to the end of `Locales/frFR.lua`:

```lua

-- Cadres de raid : la fenêtre des options (Raid/Options/Window.lua).
L.RAID_WINDOW_TITLE = "Cadres de raid"
L.RAID_SIZE_SHOWN = "%s (affiché)"
```

- [ ] **Step 11: Run the tests**

Run: `tests/run test_raid_window.lua` → `66 passed, 0 failed`
Run: `tests/run` → Expected: `22459 passed, 0 failed`

- [ ] **Step 12: Commit**

```bash
git add Core/Commands.lua ForeverUnitFrames.toc Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Options/Window.lua Raid/Options/Window.lua tests/test_raid_window.lua
git commit -m "Raid options window: sizes, tabs and rows, /fuf raid

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## After the last task

- `./install "<AddOns folder of _classic_beta_>"`, then `/reload` (no new texture). No Lua error at login. UI only: no moving, casting or fighting.
- `/fuf raid`: the window opens in the unit window's style; the size shown now reads "(shown)"; click 20 and 40: the rows follow; every tab readable, nothing cut off or overlapping (also in German: `/fuf`, language Deutsch, then `/fuf raid`); the size switch changes the panel's size (with R2b's test mode on: `/fuf`, *Test mode*).
- Indicators: type a heal's name (e.g. Renew, Rejuvenation) into a position's *Spells*: the field shows the IDs of every rank you know; a typo flashes the field and keeps the old value.
- Layout: *Class order* `Priest, Druid` turns into `PRIEST,DRUID`; with *Group by* Class the priests' block comes first (test mode).
- In a real raid when available: *Sort within a block* Role puts tanks first, then healers (spec: assigned roles are read by the header itself; check it also works when identities are restricted).
- No release yet: R4b (window actions, test mode for the edited size, entry points, wiki, 0.22.0) follows.
