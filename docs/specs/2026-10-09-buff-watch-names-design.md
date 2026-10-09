# Buff watch window: who misses a buff — Design (0.26.0)

Date: 2026-10-09 · Status: decided (maintainer request: "a list of the players a buff is missing on; the window is
not clear to read"). In short: **the names under each buff, missing first, out of range greyed; a clearer layout;
buffs switched on and off from the window.**

## 1. Facts

- The watch (Raid/BuffWatch.lua) already knows who needs a buff: each entry's state has `needs` — the members
  missing it (`left = -1`) and those with it running out (`left` = seconds), missing first, then least time left.
  Each need carries `unit` and `member` (class, group, guid). It is read out of combat only.
- The window (Raid/BuffWatchWindow.lua) is protected: its rows are secure action buttons. It is built, sized,
  moved, shown and hidden only out of combat; as combat starts it greys and casts nothing.
- A buff the spell book does not know is not watched (BuffData: `C_SpellBook.IsSpellKnown`), so Divine Spirit
  before level 30 never shows. Nothing to do there.
- What the maintainer cares about: **players missing a buff**. Running out matters only shortly before it ends.

## 2. Decisions

1. **Layout** (top to bottom):
   - **Header line**: the title "Buff watch" left; a gear button (see 4); right of it, the next cast of the smart
     buff key (today's "Next: …" line), cut to fit. A thin line under the header.
   - **Per watched buff a block**: the buff row — icon 18 px (was 16), name, and on the right the counts as short
     marks instead of "missing: 3, expiring: 1": **✖ 3** in red for missing, **⏱ 1** in yellow for running out,
     a zero left out; nothing needed: a green **✓**. "unknown" stays as it is (secret auras), without names.
   - **Name lines under the buff row** (0 to 2): the members who need it, in class colour, missing first
     (alphabetical), then running out (alphabetical, dimmed, with the time left: "Akron 2m"). A member the
     buff's single form does not reach (`C_Spell.IsSpellInRange` plainly false) is grey. More than two lines
     full: the rest as "+N". No name line when nobody needs the buff.
2. **Running out**: the default of "Runs out below (minutes)" (`buffExpiring`) goes from 5 to **3**. A profile
   that set a value keeps it. Only members under that limit are "running out" (unchanged rule, new default).
3. **Tooltip of a buff row**: as today, whom a left click casts on; below it all names with "+N" cut off, and
   the hint "Right-click: stop watching this buff".
4. **Switching buffs on and off from the window**:
   - The gear opens a check menu (Blizzard's menu system, as Raid/Menu.lua uses it) with all group buffs of your
     class: a click switches one on or off. Same settings as the options window's Buffs tab
     (`buffFortitude`, `buffSpirit`, …, `buffBlessings`), so both stay in step. A buff the spell book does not
     know is listed greyed, "not learned yet". A paladin gets one entry "Blessings"; which blessing per class
     stays in the options window.
   - **Right-click on a buff row** switches that buff off. Left click casts as before. The right button must not
     cast: the row's secure `type2` is set so that a right click does nothing secure (to be confirmed from the
     client's SecureTemplates source during implementation), and the switch runs in a post-click handler.
   - Out of combat only, like everything on this window: in combat the gear and right-click do nothing.
5. **Height**: computed per block (buff row + its name lines), no longer rows × fixed height. The window grows
   and shrinks out of combat only; the screen clamp and mover work as today with the new size.
6. **Names**: read with `UnitName` on the need's unit at render time (out of combat), checked with
   `Secrets.Plain`; an unreadable name is left out of the line (it still counts). Class colour from the member's
   class (`RAID_CLASS_COLORS` / `C_ClassColor`), white when unknown. Range is asked at render time too.
7. **Test mode / solo preview**: preview blocks show two sample names (one missing, one running out) so the
   window has a realistic size while it is placed.

## 3. Not done

- No names in combat (the state is not read there; the window keeps its last state, greyed).
- No per-player "buff this one" click on a name: names are plain text, the row's click picks the best target.
- No option to hide the name lines: they are the point of the change.

## 4. Tests

Names and order (missing before running out, alphabetical), dimmed running-out names with time, grey when out of
range, "+N" after two lines, no line when nothing is needed, "unknown" without names, height per block, the
greyed state in combat, gear menu entries (known / not learned / paladin), right-click switches off without a
cast, the new `buffExpiring` default, all four languages (same keys), the generated wiki page.
