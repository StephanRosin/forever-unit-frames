# Raid Frames — Design (Part 3: own panels and moving blocks)

Date: 2026-10-07 · Status: design decided by the assistant on the maintainer's behalf ("take the option you would
recommend"), to be reviewed in the big in-game test.

Parts 1 and 2 are done (main panel, special panels, raid tools). Part 3 adds the VuhDo feature "up to 10 independent
raid member panels, any group to any position in any panel, by group, class, role or any combination, arranged by
drag-and-drop".

## 1. Decisions

1. **Up to 10 panels in all**: the main panel plus up to **9 own panels** ("Panel 2" … "Panel 10"). The special panels
   of part 2 (main tanks, …) stay as they are and do not count.
2. **Per raid size** (10/20/40), like everything else in a raid profile: which own panels exist, their settings, their
   position, and which blocks they show. Copy/reset/export/import of a size carry them along.
3. **Each own panel has its own grouping** (group / class / role) and shows a **chosen set of that grouping's blocks**
   (e.g. "Healers" panel: grouping role, block HEALER; "Groups 1–2" panel: grouping group, blocks 1 and 2).
4. **Moving vs. showing again**: a block that an own panel takes **in the main panel's grouping** leaves the main panel
   (it is moved). A block of a **different** grouping shows those players **again** (as with the special panels) —
   this is how "any combination" works.
5. Each own panel has its own layout settings like the main panel (block direction, blocks per line, cell growth,
   cells per line, block titles, hide empty, panel/block borders) and its own title (shown above the panel, optional,
   free text). Cells look like the main panel's cells of that size (one cell look per size).
6. **Arranging** happens in the raid window, new tab **"Arrangement"** (de "Aufteilung"): one column per panel of the
   edited size, each with its blocks as small chips. Blocks are moved by **drag-and-drop** of the chips between
   columns; for keyboard/precision users each chip also has a small menu ("Move to …"). Adding/removing own panels
   (up to 9) and picking each panel's grouping happen there too.
7. No dragging of blocks in the game world (only in the window): the secure headers may not move in combat, and the
   window editor covers the need. Panels themselves are moved with their movers as before (raid window "Unlock").
8. Test mode fills own panels with pretend members exactly as the real blocks would.
9. Defaults: no own panels (today's look unchanged).

## 2. Architecture

- Own panels are panels made with `Panel.New` (Raid/Panel.lua) — slots 2..10 — whose `blocks(size)` come from their
  grouping and chosen block ids; the main panel's `blocks(size)` leaves out the blocks of its grouping that an own
  panel of the same grouping took.
- Settings: fixed slots in the raid registry (codes permanent, unique, generated in a loop like the indicators), per
  size; the chosen blocks per panel as validated text (e.g. "1,2" / "HEALER" / "PRIEST,DRUID").
- Mover group "raid"; movers per own panel; position per size; clamped to the screen like the main panel.
- Combat: panel creation, header attributes and moving only out of combat (`ns.AfterCombat`), as today.

## 3. Limits

- Changes made in combat apply after combat.
- Performance: more panels can show players more than once — part of the in-game check at 40.

## 4. Out of scope

Click-casting (part 4), buff watch (part 5), templates (part 6). Release only after all parts.
