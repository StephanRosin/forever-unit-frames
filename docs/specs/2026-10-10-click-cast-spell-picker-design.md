# Click-casting: spell and rank dropdowns — Design

Date: 2026-10-10 · Status: decided (maintainer: "Dropdown statt Textfeld bei Cast a spell, daneben der Rang, Max
vorausgewählt; nur Zauber, die man auf Freunde wirken kann; bestehende Werte beim Update umwandeln").

## 1. What the client allows (read from the 1.60.1 UI source)

- `C_SpellBook.GetSpellBookItemInfo(slot, bank)` lists every learned rank as its own item: `spellID`, `name`,
  `subName` (the rank text, e.g. "Rank 3", in the client's language), `isPassive`, `itemType`.
- `C_Spell.IsSpellHelpful(id)` → bool; `C_Spell.GetSpellInfo(id).maxRange` (0 for self-only spells).
- `SECURE_ACTIONS.spell` (SecureTemplates.lua): a numeric `spell` attribute is cast with `CastSpellByID` (exactly
  that rank); a name with `CastSpellByName` (the highest learned rank).
- The options dropdown (Options/Widgets.lua) already scrolls long lists.

## 2. Decisions

1. **Which spells**: the player's spell book, spells only (no passives), helpful (`IsSpellHelpful`) and castable on
   someone else (`maxRange > 0`): heals, dispels, buffs, resurrections. Each name once, sorted alphabetically (the
   client's language). Self-only spells (Inner Fire) and self-centred ones (Prayer of Healing, Holy Nova) are not
   listed. Every read guarded (`ns.Secrets`); a secret or missing answer leaves the spell out.
2. **UI**: when a slot's kind is "Cast a spell", the value's text box is replaced by two dropdowns in the same width:
   the spell (wide) and the rank (narrow, right of it). For item and macro the text box stays. The rank dropdown
   lists "Max" first (default) and then every learned rank of that spell by its `subName`; greyed when the spell has
   only one rank or none. The spell dropdown's last item "Other…" shows the text box instead (a spell not in the list:
   not learned on this character, a racial, a self-centred spell; typed as today, `ClickCast.TypedValue`).
3. **Stored value** (per character, as today `spell:<value>`):
   - Max → the spell's name (today's form: a rank learned later is cast without choosing again).
   - A fixed rank → its spell ID (`spell:2061`), cast exactly (CastSpellByID).
4. **Keys** (Raid/ClickKeys.lua, macro `/cast [@mouseover,help,nodead] %s`): Max → the name as today; a fixed rank →
   `Name(<subName>)` from the spell book (e.g. `Renew(Rank 3)` / `Erneuerung(Rang 3)`). In-game check needed; if the
   client refuses the rank form, the keys offer Max only.
5. **Migration** (once per character, flag in `ForeverUnitFramesDB.raidClickSpellsNormalised[character]` — the
   raid profile keeps only settings —, run when the spell book is ready — SPELLS_CHANGED or the end of the login
   loading screen, never in combat): every `spell:` binding (mouse slots and keys) is normalised:
   - a name in the list (case ignored) → the spell book's spelling (Max);
   - a number that is a learned rank → that ID (fixed rank); when it is the highest learned rank → the name (Max, as
     typing an ID meant until now);
   - anything else (not learned, not helpful, unknown) stays as typed and shows under "Other…".
   Imports run through the same normalisation.
6. **Display**: `Schema.KindText`/the binding summary shows "Cast a spell: Renew" for Max and "Cast a spell: Renew
   (Rank 3)" for a fixed rank (the subName read when shown; the ID's name when the rank is no longer known).
7. **Combat**: the rows lock in combat as all rows do; lists are read only while the options are open.

## 3. Tests

Spell list filter (helpful, range, passive, duplicates, secret answers, sort); dropdown swap by kind; rank items and
greying; stored values (name vs ID) and the attributes they produce (CastSpellByID for an ID); key macro text with
rank; migration cases (name, other case, highest-rank ID, lower-rank ID, unknown, not helpful) and its once-only flag;
"Other…" round trip; import normalisation; four languages.

## 4. Release

News line and wiki text; ships as 0.27.0 after the maintainer's in-game check (rank on a mouse click, rank on a key).
