# Raid Frames — Design (Part 1: core)

Date: 2026-10-06 · Status: approved design, not yet implemented

## 1. Goal

Raid frames for Forever Unit Frames, inspired by the feature set of VuhDo
(discontinued) but drawn in the look of this addon. VuhDo is used as a source of
ideas only; no code is taken from it.

The full feature set is split into six parts, each with its own spec, plan and
release. **This spec covers part 1 only.**

| Part | Content |
|---|---|
| **1 — Core** (this spec) | Raid headers up to 40, grouping by group/class/role, layout, cell, indicators, per-character profiles per raid size, own options window, test mode |
| 2 — Special blocks | Main tanks / main assists pulled out of the grid (CTRA/oRA compatible), personal favourites, pets, vehicles |
| 3 — Panels | Up to 10 independent panels, drag-and-drop of blocks between panels |
| 4 — Click-casting | Mouse and key bindings on the cells (spells, items, macros), own binding UI |
| 5 — Buffs | Advanced HoT/buff indicators, Buff Watch window, smart-buff key |
| 6 — Templates | Setup wizard and role templates (healer, tank, DPS, "dispel only") with class suggestions; skins |

Things no addon can do on this client and that are therefore not planned in any
part: firing trinkets or spells automatically, resurrecting, dispelling or
buffing without a key or mouse press. A key that picks the right target and
spell (part 5) is possible.

### Decisions taken

- Raid sizes on Forever are 10, 20 and 40. Each **character** has **three
  profiles**, one per size. Profiles can be copied between sizes and from other
  characters, then adjusted.
- The active size follows the instance (`maxPlayers`); outside a raid instance
  the member count decides, and in a raid the highest occupied group as well
  (five to a group: someone in group 3 means at least 20), so nobody sits in a
  group the profile does not show. A switch fixes it to 10, 20 or 40.
- In a 5-player group the raid view can be shown as well (switch, default off);
  it then uses the 10-player profile and hides the party frames.
- Cell layout default: VuhDo-classic (name and missing health centred, HoT
  squares in the corners, the most important dispellable debuff as a large
  icon in the middle).
- Default frame: one gold border around the whole panel. Borders around each
  block and around each cell can be switched on separately.
- Architecture: a raid module inside the same addon (folder `Raid/`), not new
  scopes in the unit-frame settings and not a separate addon.

## 2. Platform facts this design relies on

Verified against the Forever UI source snapshot of build `1.60.1.70205`.

| Fact | Consequence |
|---|---|
| `SecureGroupHeaderTemplate` supports `groupFilter`, `roleFilter`, `strictFiltering`, `groupBy` (GROUP, CLASS, ROLE, ASSIGNEDROLE), `groupingOrder`, `sortMethod` (INDEX, NAME, NAMELIST), `sortDir`, `maxColumns`, `unitsPerColumn`, `columnSpacing`, `columnAnchorPoint`, `startingIndex` in plain Lua. Only `initialConfigFunction` and `refreshUnitChange` run snippets, and both are optional. | Sorting and filtering work, also in combat. No snippets are used (they fail on this client, see the main design). |
| The header accepts an `auraContainerTemplate` attribute and gives every child it creates an AuraContainer, also in combat. | Cells get their aura container from the header. |
| `UnitGroupRolesAssigned` exists; roles can be set (`UnitSetRole`, role poll). `GetRaidRosterInfo` returns MAINTANK/MAINASSIST, master looter flag and assigned role. | Grouping by role is possible; part 2 can use the main tank assignment. |
| `GetInstanceInfo()` returns `maxPlayers`, not secret. Difficulty IDs: 40 = 9, 20 = 242, 10 = 243. Events: `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_DIFFICULTY_CHANGED`, `INSTANCE_GROUP_SIZE_CHANGED`, `GROUP_ROSTER_UPDATE`. | Size detection without guessing. |
| Reading auras of other members (`GetAuraDataByIndex`, `GetUnitAuras`, the `UNIT_AURA` payload) is secret while auras are restricted. An aura slot with `candidateFilters = { includeSpellIDs = {...} }` on `HELPFUL` auras of group members is always allowed and supports duration text, cooldown swipe and duration bar. | Corner indicators are aura-container slots. The addon reads no aura data itself. |
| `HARMFUL|RAID` means "dispellable by the player"; the client decides. `Elements/Dispel.lua` already colours by dispel type from a container. | Dispel display is reused. |
| `UnitHealth`, `UnitHealthMissing`, `UnitHealthPercent` are always secret; `UnitIsDeadOrGhost`, `UnitIsConnected` are not. | Health is passed through as in `Elements/Health.lua`. |
| `UnitInRange` is secret (use `SetAlphaFromBoolean`); `C_Spell.IsSpellInRange` and `UnitDistanceSquared` are not. | `Elements/Range.lua` is reused. |
| `UnitThreatSituation` is secret when the unit's threat state is restricted; `GetThreatStatusColor` refuses secrets from addon code. | Aggro display is **unverified** (see §9). |
| `GetRaidTargetIndex` is secret (passed to `SetSpriteSheetCell`). `UnitIsGroupLeader`/`UnitIsGroupAssistant` secret only under identity restriction. `C_PartyInfo.GetLootMethod` not secret. There is art for main tank/assist but none for master looter. | Icons as in `Elements/RaidMarker.lua`; own master-looter texture. |

## 3. Architecture

A folder `Raid/` inside the addon. The raid module has its own settings list,
storage, options window and a lean cell. It reuses the settings machinery and
those unit-frame elements that are cheap.

| File | Responsibility |
|---|---|
| `Raid/Settings.lua` | Raid setting definitions (key, code, type, default), own code prefix space |
| `Raid/Profiles.lua` | Per-character profiles per size; copy between sizes and characters; reset; export/import |
| `Raid/Size.lua` | Determines the active size (instance → member count → fixed switch), fires a change callback |
| `Raid/Header.lua` | Creates and configures the block headers, layout of blocks, panel/block borders, combat queue |
| `Raid/Cell.lua` | Builds one cell on a header child and wires the elements |
| `Raid/Indicators.lua` | Corner indicators as aura-container slots |
| `Raid/TestMode.lua` | Fake raid for the edited profile |
| `Raid/Options/*.lua` | Raid options window: header bar and tabs, built from the schema/widgets engine |

### Generalising the core

`Core/Settings`, `Core/Config` and `Core/Codec` currently know one fixed set of
scopes. They are generalised to hold several **settings domains** side by side:
the existing unit-frame domain and the raid domain. Each domain has its own list
of definitions, scopes and code space. The unit-frame domain keeps its codes and
encoding exactly; existing saved and exported strings stay valid (covered by a
regression test). `Options/Schema` and `Options/Widgets` are made to render
either domain.

### Storage

`ForeverUnitFramesDB.raid[charKey]`, with `charKey = "Name-Realm"`, is one
profile table with the scopes `general` (character-wide raid settings: raid
view in party, hide Blizzard raid frames, size switch) and `r10`, `r20`, `r40`
(one per size). As everywhere else it holds only differences from the
defaults. The table in use is the saved one itself (cleaned at login), so a
change is in SavedVariables at once; the short encoding is used only for
export and import of one size. Storing per character inside the
account-wide table is what makes copying from another character possible.
The unit-frame profile stays account-wide and unchanged.

## 4. Panel, grouping and layout

The panel consists of **blocks**. Each block is a `SecureGroupHeader` with a
filter.

| Group by | Blocks |
|---|---|
| Group | Groups 1–8; by default only those of the size (10 → 1–2, 20 → 1–4, 40 → 1–8); empty blocks can be hidden |
| Class | One block per class, order configurable |
| Role | Tank / Healer / DPS from the assigned role |
| None | A single block; all members flow through one grid |

Within a block: raid order, name, or role.

Layout settings (per size profile):

- blocks side by side (horizontal) or stacked (vertical)
- blocks per row or column (wrap)
- growth of cells within a block: down or right
- with "None": cells per column or row
- cell width and height, cell spacing, block spacing
- block titles on/off

Borders: around the panel (default on), around each block (off), around each
cell (off), using the gold border, corners and shadow from `Core/Border`. The
panel border follows the occupied blocks.

Position: movable with the existing movers, stored per size profile.

Combat: layout changes (size change, settings) are queued during combat and
applied afterwards, as party does today. Joining and leaving members are handled
by the headers themselves.

Party: with "raid view in party" on, a 5-player group is shown by the 10-player
profile and the party frames are hidden; otherwise party frames work as today.

Blizzard's raid frames are hidden while ours are active (option, default on).

## 5. The cell

**Bars**

- Health: class colour (default), fixed colour, or a gradient by health via a
  curve.
- Power: thin strip at the bottom: all, mana classes only (default), healers
  only, off.
- Incoming heals and absorbs: the existing `HealPrediction` and `Absorb`
  elements.

**Texts**

- Name centred, truncated to the cell width, optional class colour.
- Second line: missing health (default), percent, current, off.
- Status instead of the number: Dead, Ghost, Offline, AFK.

**Debuffs**

- The most important dispellable debuff as an icon in the middle, border in the
  dispel-type colour.
- Filter: dispellable by me (default, `HARMFUL|RAID`) or all dispellable.
- Option: tint the whole cell in the dispel-type colour.
- Optional row of further debuffs (count and size configurable).

**Corner indicators**

- Up to five positions: four corners and top centre.
- Per position: spell IDs (one or several, e.g. all ranks), colour, size, own
  casts only, remaining time as number or as darkening.
- Implemented as aura-container slots with `includeSpellIDs`.
- Empty by default; class suggestions come with the templates in part 6.
- Cells without any enabled indicator build no indicator slots.

**Icons** (each switchable, position selectable)

- Role (tank, healer), raid target marker, leader / assistant / master looter
  (own texture), ready check.

**States**

- Out of range: faded, alpha configurable (`Elements/Range.lua`).
- Aggro: red inner border — subject to §9.
- Dead or offline: grey.
- Current target: light border.

**Clicks**

Left click targets, right click opens the unit menu (`SecureUnitButtonTemplate`,
up and down registered as on party). Cells are registered in `ClickCastFrames`
so Clique works. Own click-casting is part 4.

**Performance**

- No own aura scanning; containers do it.
- Unit events per cell via `RegisterUnitEvent`.
- Range updates throttled by a timer.

## 6. Options window

Own window, same style as the unit-frame window, built from the schema/widgets
engine. Opened with `/fuf raid`, a "Raid frames …" button in the main window,
or the minimap button menu.

**Header bar (always visible)**

- Tabs 10 / 20 / 40: which profile is being edited; the active one is marked.
- Size switch: Automatic / 10 / 20 / 40.
- Copy from …: another size, or another character and size, with confirmation.
- Reset; Export / Import (one size as a string).
- Test mode on/off.

**Tabs**

| Tab | Content |
|---|---|
| General | Raid view in party, hide Blizzard raid frames, raid frames on/off |
| Layout | Grouping, sorting, direction, wrap, spacing, block titles, the three borders |
| Cell | Size, bar texture, colours, power strip, heal prediction and absorbs |
| Texts | Name and second line, font sizes |
| Debuffs | Dispel filter, centre icon, tint, debuff row |
| Indicators | The corner positions with spell selection (ID or name from the spellbook) |
| Icons & states | Role, raid marker, leader/looter, ready check, range, aggro, target |

All strings in enUS, deDE, esES, frFR. `tools/make_wiki` gets raid pages;
`tests/test_wiki_current.lua` covers them.

## 7. Test mode

Shows a fake raid in the size of the **edited** profile at that profile's
position. Fake members cover mixed classes and roles, several health levels, one
dead, one offline, one out of range, debuffs and HoTs, so every option is
visible. Closing the window ends test mode; entering combat ends it too.

## 8. Testing

Offline suite (`tests/run`, mock extended with raid units, `GetInstanceInfo`,
`GetRaidRosterInfo` and header attributes):

- size selection: instance → member count → fixed switch, and events
- profiles: per-character storage, copy between sizes and characters,
  export/import, raid codes not colliding with unit-frame codes
- regression: existing unit-frame strings decode unchanged after the core is
  generalised
- header attributes for each grouping and layout, block positions, panel border
  size
- combat queue: changes deferred and applied after combat
- cell: status texts, power-strip rules, indicator slots only when enabled
- locale completeness, wiki up to date

In game (UI only, test mode; no moving, casting or fighting): look at 10, 20 and
40 in test mode; a real raid when available; the open questions in §9.

## 9. Open questions and risks

- **Aggro.** Threat of raid members is probably secret in combat. Idea to try:
  a hidden-range status bar (min 2, max 3) fed the secret status via `SetValue`,
  so it fills only at aggro. If that does not work, the aggro display is
  dropped and the wiki says why.
- **Indicator fallback.** Whether HoTs such as Renew and Rejuvenation are
  `NeverSecret` (`C_Secrets.GetSpellAuraSecrecy`). Only relevant for an
  out-of-container fallback; the container path does not depend on it.
- **Performance at 40.** Measured in test mode with all indicators on. Cell
  borders stay off by default.

## 10. Release

Minor version 0.22.0 after the in-game check. Wiki regenerated, CurseForge
description updated by hand as usual.
