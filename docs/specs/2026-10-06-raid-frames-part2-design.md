# Raid Frames — Design (Part 2: special panels and raid tools)

Date: 2026-10-06 · Status: approved design, not yet implemented

Part 1 (core) is done: see `docs/specs/2026-10-06-raid-frames-design.md` and the raid plans R1–R4d.
This part adds special panels (main tanks, main assists, my tanks, favourites, pets) and a raid
tools bar that replaces what Blizzard's raid manager (hidden by part 1) offered. Vehicles are left
out (Forever's content hardly has them).

## 1. Decisions taken (maintainer)

- Special panels are **separate panels**, each with its own gold frame, mover and position per raid
  size (10/20/40) — not extra blocks inside the main panel.
- Players in a special panel **stay in their group** in the main panel as well (shown twice).
- Main tanks / main assists come from the **raid assignment** (MAINTANK / MAINASSIST, `/maintank`,
  raid leader's menu) — compatible with what CTRA/oRA users see.
- **My tanks** and **favourites** are the player's own lists, kept **per character, permanently**.
  They are edited from the cell's **right-click menu** ("Add to / remove from favourites", "Mark /
  unmark as my tank") and as name lists in the raid window.
- **Pets**: a panel with all raid pets, smaller cells, **off by default**.
- **Raid tools bar**: choosable **docked** (a fold-out handle on the edge of the main panel, moving
  with it) or **free** (its own mover).

## 2. Architecture

`Raid/Header.lua` becomes a general **panel**: a frame with a mover, one or more secure group
headers with filters, a position per size, borders and titles. The main panel is the first panel;
the special panels are further panels of the same kind. This prepares part 3 (up to 10 panels).

| Panel | Who | Secure header filter | Default |
|---|---|---|---|
| Main tanks | raid assignment MAINTANK | `roleFilter = "MAINTANK"` (updates in combat) | on |
| Main assists | raid assignment MAINASSIST | `roleFilter = "MAINASSIST"` | off |
| My tanks | own list | `nameList` (+ `sortMethod NAMELIST`) — changes apply after combat | off |
| Favourites | own list | `nameList` | off |
| Pets | all raid pets | `SecureGroupPetHeaderTemplate` | off |

Cells in special panels look like the main panel's cells of the same size. Per special panel and
size: on/off, title on/off, cells per line, growth direction, position; pets additionally a cell
height. The lists of my tanks and favourites are stored per character (raid `general` scope), as
text validated by a `check` (names, optionally `Name-Realm`, only for players from other realms).
Typed names take WoW's spelling (first letter upper case, the rest of the name lower case; realm kept
as typed) and are compared without case (amended 2026-10-07, decision 4).

Right-click menu entries are added with `Menu.ModifyMenu` on the unit menus raid cells use; they
change the lists (out of combat the panels update at once, in combat after combat).

## 3. Raid tools bar

- For everyone: raid target icons (the 8 icons on the current target; secure buttons with
  `type = "raidtarget"`, the client's `SetRaidTarget`), the result of the last ready check.
- For leader and assistants only: start a ready check (`C_PartyInfo.DoReadyCheck`), role poll
  (`InitiateRolePoll`), world markers (secure buttons with `type = "worldmarker"`) and "clear all",
  everyone assistant (`C_PartyInfo.SetEveryoneIsAssistant`), party ↔ raid
  (`C_PartyInfo.ConvertToRaid` / `ConvertToParty`, as Blizzard's own raid manager — not
  `ConfirmConvertToRaid`, which converts "with no regard for potentially destructive actions";
  amended 2026-10-07, decision 5), loot method (`C_PartyInfo.SetLootMethod`; free for all, round
  robin, master looter — yourself —, group, need before greed and personal, `Enum.LootMethod.Personal`;
  amended, decision 7).
- The secure buttons (raid target icons, world markers) act on the **left mouse button only** and
  are registered for both strokes (`AnyUp`, `AnyDown`): an addon's `SecureActionButtonTemplate`
  acts on the down stroke while `ActionButtonUseKeyDown` is on, else on the up stroke (amended,
  decision 8).
- Docked or free (setting); shown in a raid and in a party, hidden when solo. Docked while the main
  panel is hidden (a party without the raid view in party), the bar falls back to its free position
  (amended, decision 6). Secure buttons are created and moved only out of combat.

## 4. Options window and test mode

New raid window tabs: "Panels" (per panel on/off and layout, the two name lists) and "Tools"
(docked/free, which tools); de "Felder"/"Werkzeuge" — short names, clear inside the raid window
(amended, decision 2). All words in enUS/deDE/esES/frFR; the wiki generator includes the
new tabs. Test mode shows pretend main tanks, favourites and pets in their panels.

## 5. Limits

- Name lists cannot change in combat: a player added in combat appears after combat.
- World markers are placed only by clicking their secure button.
- Special panels add cells: performance at 40 with all panels on is part of the in-game check.
- How the raid roster (`GetRaidRosterInfo`) writes a player's surname is unknown: name lists accept
  both `Name-Surname` (a party member's form) and `Name Surname`; part of the in-game check.

## 6. Out of scope

Vehicles; multiple free panels and drag-and-drop of blocks (part 3); click-casting (part 4); buff
watch (part 5); templates (part 6). Release only after all parts (maintainer decision).
