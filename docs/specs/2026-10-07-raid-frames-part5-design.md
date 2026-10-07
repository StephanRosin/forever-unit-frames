# Raid Frames — Design (Part 5: buff watch and smart buff key)

Date: 2026-10-07 · Status: design decided by the assistant on the maintainer's behalf, to be reviewed in the big
in-game test.

VuhDo: "Buff Watch: tracks raid buffs, missing/expiring, one click to rebuff; smart buffing chooses target and spell
by itself". On this client an addon cannot buff without a key or mouse press, and secure attributes cannot change in
combat — so rebuffing is **out of combat**: a key or click casts the right buff on the right member, picked by us
beforehand.

## 1. Decisions

1. **Which buffs**: per character, a list of the **player's own group buffs** (from the class's buff spells the spell
   book knows — e.g. Power Word: Fortitude / Prayer of Fortitude, Arcane Intellect / Brilliance, Mark/Gift of the Wild,
   Blessings, Shadow Protection, Thorns (tank only optional)) — offered by class, each switchable. Shipped as a small
   table of spell IDs per class (all ranks, single and group form); the spell book decides what is known; names come
   from the client. Paladin blessings: one blessing per class (VuhDo-like), chosen per class in the window.
2. **Buff watch window** ("Buff watch", de "Buff-Übersicht"): a small movable panel (mover group "raid"), one row per
   watched buff: icon, "missing n / expiring n" (expiring = less than a set time left, default 5 min), click on the row
   = cast that buff on the next member that needs it (secure button, see 4). Hidden when solo and while nothing is
   watched; option to show only when something is missing; locked/hidden in combat (it shows its last state greyed).
3. **Missing buffs on the cells**: an optional indicator (a small icon in a chosen corner) on a cell whose member lacks
   one of the watched buffs (out of combat only; in combat it keeps its last state). Default off.
4. **Smart buff key**: one key (default none, user-set like the click-casting keys) and the watch rows' clicks run a
   hidden secure button whose `type=spell`, `spell` and `unit` attributes we set **out of combat** to the best next
   cast: the group form when ≥ N (setting, default 3) members of one group miss it and the reagent is in the bags,
   else the single form on the member with the least time left (missing first), in range and alive. Recomputed on
   UNIT_AURA / roster / bag changes out of combat (throttled). In combat the key does nothing (attributes cleared at
   combat start). The button's tooltip/chat line says what the next press will cast on whom.
5. **Reading auras**: `C_UnitAuras.GetAuraDataBySpellName` / `GetUnitAuras(unit, "HELPFUL")` — every field checked
   with `Secrets.IsSecret` before use; when auras are secret (`C_Secrets.ShouldAurasBeSecret`) the watch shows
   "unknown" instead of guessing. No comparisons or arithmetic on secret values.
6. **HoT/buff indicators** ("advanced indicators" of the roadmap) are already covered by part 1's indicators; part 5
   adds nothing there. Out of scope: HoTs in heal prediction (separate open item).
7. **Window**: a new raid window tab "Buffs" (watched buffs per class, blessing per class, expiring threshold, group
   threshold, smart buff key, watch window and cell indicator options). Per character (general scope). Words in four
   languages; wiki page.

## 2. Architecture

- `Raid/BuffData.lua`: per-class buff table (spell IDs of single and group forms, reagents), resolved by the spell book.
- `Raid/BuffWatch.lua`: scanning (throttled, out of combat), the state per buff (missing/expiring members), the best
  next cast.
- `Raid/BuffWatchWindow.lua`: the watch window and its secure row buttons; `Raid/SmartBuff.lua`: the key button and its
  override binding (as part 4's keys).
- Settings in the raid registry `general` scope, codes permanent.

## 3. Limits

- No buffing in combat (client rule). Auras that are secret are shown as unknown.
- Range: `UnitInRange`/`C_Spell.IsSpellInRange` results may be secret — a member whose range is unknown counts as in
  range (the cast fails visibly at worst).
- The class buff table needs the client's spell IDs; the builder takes them from the client data the spell book
  exposes and the shipped tracking/buff lists; unknown IDs are simply not offered.
