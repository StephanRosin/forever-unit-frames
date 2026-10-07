# Roadmap after 0.22.0

Date: 2026-10-07 · Status: confirmed 2026-10-07 — A and B prepared (designs in docs/specs), C deferred far back, D dropped.

0.22.0 shipped the raid frames (parts 1–6), the unit frame requests and the menu rework. This plan covers what was
deferred. Each package gets its own short design note and its own branch; the order below is the recommended one.

| # | Package | Kind | Size | Release |
|---|---|---|---|---|
| 0 | Hotfix readiness for 0.22 feedback | reactive | — | 0.22.x |
| A | Clean-up: shared window parts + review leftovers | internal | S–M | 0.23.0 (design: docs/specs/2026-10-07-cleanup-design.md) |
| B | Aura blocklist (hide single auras) | user request | M | 0.23.0 (design: docs/specs/2026-10-07-aura-blocklist-design.md) |
| C | Border and rounding per bar | CurseForge request | L | deferred, far back |
| D | ~~HoTs in heal prediction~~ | dropped (maintainer) | — | — |

## 0 — Hotfix readiness (first, ongoing)

0.22.0 is the largest release so far. For the first days after the release, a reported Lua error has priority over the packages:
reproduce it in the test mock (a failing test first), fix it, and release it as 0.22.x. Sources are CurseForge comments,
foreverwowui@gmail.com and the maintainer's own play. In-game checks still open from 0.22: GetRaidRosterInfo name form
for surnames/other realms, restricted party calls (ready check, loot method), spell ranks on low-level targets,
GetSpecialization role on talent tabs, `@mouseover` keys, ActionButtonUseKeyDown on world markers.

## A — Clean-up (internal, no visible change)

Goal: smaller code and fewer copies before new features build on it. Default look and saved settings unchanged
(the default-look snapshot test guards it).

1. **Shared window parts.** The title bar, the close cross, the footer button row and the row tooltips exist three
   times (Options/Window.lua, Raid/Options/Window.lua, Options/News.lua, partly Raid/Wizard.lua). Move them into one
   module (e.g. `Options/Chrome.lua`) that every window uses.
2. **One secret check.** `readable(pcall(...))` exists in Raid/Cell.lua and Elements/GroupIcons.lua (and similar
   helpers in Raid/BuffWatch.lua, Raid/Tools.lua). Move it into one helper in `ns.Secrets` and use it everywhere.
3. **Leftovers from the 0.22 reviews:**
   - `Own.Addable` uses raw tokens after an import that names a block twice.
   - The tools bar's default position (300, 300) can overlap panel 2.
   - Totems: rename `x, y` to `dx, dy`.
   - Elite word: `SetJustifyH` has no effect there; fix the wiki wording.
   - The default-look snapshot does not record the role texture or the pet's 3D portrait alpha.
   - A cell icon can keep a stale state when its unit has no readable GUID.
   - The shared cell-shape helper.
4. Run time: a full test run per step only where logic changes; menu and text work uses focused tests.

## B — Aura blocklist (user request, 2026-10-06)

Goal: hide single auras by spell, e.g. campfire or food buffs, on the unit frames and the raid cells.

1. **Settled from the client source** (no in-game spike needed, see the design): exclusions work for buffs on you/your group/pets, debuffs on enemies, and never-secret spells anywhere; not for debuffs on friendly units or buffs on enemies. Original question: does the aura container's `excludeSpellIDs` filter work for debuffs and on hostile
   units, and in combat? (Party buffs are known to work.) Is `aura.spellId` readable outside combat for the
   right-click route? The answers decide which of steps 2–4 work where.
2. **Settings:** one account-wide list plus one list per frame (unit frames: General + each frame; raid: per size),
   stored as validated text of spell IDs (names are turned into IDs through the spell data the client gives; unknown
   ones are refused with a message, as the click-casting does).
3. **Applying:** through the same container filter as "hide tracking", so it also works in combat; in the raid cells'
   debuff row and indicators as well.
4. **UI:**
   - A list editor in each frame's Auras tab and in the raid Debuffs tab.
   - A shift-right-click on an aura icon (out of combat, only when the spell ID is readable) puts it on the list,
     with an undo message.
5. Tests: filter applied in and out of combat, list validation, the secret spell-ID case (no entry, no error).

## C — Border and rounding per bar (CurseForge request, 2026-09-27) — deferred far back

Goal: the health and the power bar each get their own border and slightly rounded corners, independent of the
frame's border, like the pet bar.

1. **Constraint:** at most three masks per texture; one is taken by the frame's rounding (`frame.clip`). Each bar
   needs its own masks for fill and background plus its own ring (Core/Border.lua). The 0.21 mask-limit test
   (tests/test_mask_limit.lua) must stay green for every combination.
2. **Design:** per frame and bar, an on/off switch, a size, a colour and a radius, plus the gap between the bars.
   The frame border and the bar borders can be combined.
3. **Steps:**
   - A mask budget audit: every texture and the masks it can carry.
   - Bar rings built on the existing ring code.
   - Masks for fill, background, heal prediction and absorb.
   - Settings and UI rows (greying through Options/Dependencies.lua).
   - The default-look snapshot unchanged when the feature is off.
4. Biggest risk: heal prediction and absorb bars are clipped by the frame mask today; they must follow the bar's
   rounding instead.

## D — HoTs in heal prediction (dropped)

Dropped by the maintainer on 2026-10-07. The FAQ says that heal prediction shows heals being cast, as Blizzard's frames do.

## Way of working (as for 0.22)

- A design note per package (docs/specs), decisions logged, build on its own branch, test first.
- A review per package by a separate reviewer, then a fix wave and a re-review.
- An in-game check by the maintainer, then release with the maintainer's OK.
- The wiki is regenerated, the news line for the version is written.
