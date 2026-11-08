# Plan: tidier unit-frame options (no redesign)

Status: proposal, 08.11.2026. Same window, same left list (General, frames, Profiles), same
setting keys and codes: saved profiles and export strings stay valid. Only the Schema
(Options/Schema.lua), a few labels and hints, and one new widget behaviour change.

## What the usability run showed

30 fresh agents, each given one player goal, clicked through a text simulator of `/fuf`
(the search box was off). All 30 got there, 29 in at most 2 clicks. Two found only half
of the answer, and 17 of 30 called a tab too long to scan.

| Problem | Evidence |
|---|---|
| Long tabs, mostly placement rows | Player Auras 104 rows (39 of them anchor/point/offset/grow), Target Status 42 (20), Party Auras 74 (27). Agents scrolled past Point/Offset blocks to reach the switch they wanted. |
| Threat bar under Castbar | Tank goal "see my threat": found Status > Highlights > Threat glow, never the Threat bar. Two others called Threat bar on the Castbar tab odd. |
| Shield watch hidden in Auras | Priest goal "how much is left on my shield": found Bars > Absorb shields, not Auras > Shields. |
| Value font size far from the texts | "Bigger health numbers": the agent looked in Health bar text first, and the size is in the last section (Font) of the Text tab. |
| Layout vs Group on Party | 2 of 3 party agents opened Layout looking for orientation or "show yourself"; the section there is even called "Party layout". |
| General > Appearance is a catch-all | Font, title-row badge, aura icon borders, hidden auras, border, shadow, opacity. Agents looked for "Hidden auras" under an Auras tab, and for bar texture under Appearance. |
| Fading in two places | Frame opacity on Layout, range and out-of-combat fading at the bottom of Status. One agent went Layout > Opacity first. |
| Small naming issues | Minimap button under the "Frames" tab; the click-casting switch on Frames, its bindings on their own tab; Portrait style and health-text hints do not name the choices. |

## Changes, by size

### 1. Placement folds away (largest effect, one widget change)
Every "where is it" group (Anchor to, Point on the frame/anchor, Point of the icon(s),
Offset X/Y, Grow, New rows, Direction, Place) becomes one collapsed row **"Position…"**
under its section, which unfolds in place. Folded by default; the open state is remembered
per window session only. With all of them folded, Auras goes from 104 to about 65 rows and
Status from 40 to about 24.
- Schema: a section gets `placement = { keys… }` next to `keys`; Window.lua builds the fold.
- The search (Options/Search.lua) unfolds a fold when it reveals a row inside it.
- Tests: section rows (test_menu_layout, test_options_*), search reveal, wiki generator
  (list placement rows under a "Position" sub-heading).

### 2. Buffs/Debuffs: "Mine" as its own block
The ~12 "Mine: …" rows of Buffs and Debuffs (Mine first, size, same rows, place, points,
offsets, growth, per row, caster border colours) move into a section of their own,
**"Your own buffs" / "Your own debuffs"**, directly below. The filters (Only mine, Hide
permanent, Hide longer than, Only dispellable) stay at the top of Buffs/Debuffs.

### 3. Moves between tabs (Schema only)
| Setting(s) | From | To |
|---|---|---|
| Threat bar (section) | Castbar | Status, next to Highlights (Threat glow), as one section **"Threat"** (glow + bar) |
| Shield watch (section) | Auras | end of Bars (player only; next to Absorb shields it pushed druid mana and the five-second rule 20 rows down), renamed **"Shield watch (icons and amount)"** |
| Range, Out of combat | bottom of Status | Layout, into the Opacity section, which becomes **"Visibility and fading"** (Frame opacity, range fading, out-of-combat fading) |
| Font section | bottom of Text | top of Text (the same on General > Appearance stays first) |
| Aura icons (border) and Hidden auras | General > Appearance | new General tab **"Auras"** (Aura icons, Hidden auras everywhere) |
| Minimap button | General > Frames | stays, tab renamed **"Frames & addon"** |
| Click-casting switch | General > Frames | top of the General > Click-casting tab (it stays on each frame's Layout tab) |

### 4. Renames and hints (Locales only, all five languages)
- Party: tab "Layout" → **"Frame"** (size, portrait, border of one member) and "Group" →
  **"Group layout"**. Only on the party page; the others keep "Layout".
- Portrait style hint: "3D model, 2D picture or class icon".
- Health bar text hint: "e.g. current value, percent, deficit".
- Frame opacity hint names where range and out-of-combat fading are (after the move: "below").
- Profiles: one line "Profiles are shared by all your characters: pick the same one on an alt."

### 5. Left alone on purpose
- The left list and the order of the frames.
- Per-frame tabs that only hold a few rows (Castbar after the threat move: 7–15 rows).
- The raid window (its own menu; not part of this run).

## Order of work
1. Moves and renames (sections 3 and 4): Schema and Locales only, small diff, one release.
2. The "Mine" blocks (2): Schema only.
3. Placement folds (1): widget, search, wiki; the biggest change, a release of its own.
After each step: regenerate the wiki (tools/make_wiki), run the click-through simulation again
with the same 30 goals and compare clicks and "too long" votes.

## Risks
- Players who know the old places: News entry per release ("Threat bar moved to Status"), the
  search finds everything as before.
- Section ids are referenced by tests and the wiki anchors; renamed sections change wiki URLs.
- Dependencies (Options/Dependencies.lua) grey out rows by key and do not depend on sections;
  check that a fold whose rows are all greyed out is greyed out too.
