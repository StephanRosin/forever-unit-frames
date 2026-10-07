# Raid Frames — Design (Part 4: click-casting)

Date: 2026-10-07 · Status: design decided by the assistant on the maintainer's behalf, to be reviewed in the big
in-game test.

VuhDo: "heal, decurse, target, assist or focus raid members with one click; bind any usable item and any macro; up to
40 mouse click combinations; up to 16 keys to cast on mouse-over". Things no addon can do (fire trinkets or spells
automatically, auto-resurrect/decurse without a key press) stay out.

## 1. Decisions

1. **Bindings per character** (spells differ per class): stored in the raid profile's `general` scope (character-wide,
   not per raid size).
2. **Mouse bindings** on the raid cells (main panel, special panels, own panels) and — switchable, on by default — on
   the unit frames' party frames: mouse buttons 1–5 × modifiers (none, Shift, Ctrl, Alt, Shift-Ctrl, Shift-Alt,
   Ctrl-Alt, Shift-Ctrl-Alt) — up to 40 combinations.
3. **Actions** per binding: cast a spell (stored by name, so the client casts the highest known rank — newly learned ranks are used without re-picking; a typed spell ID is turned into its name),
   use an item (name or ID), run a macro text, target, focus, assist, open the unit menu, or "nothing".
4. **Defaults**: left = target, right = menu (as today); everything else unbound. With no bindings the cells behave
   exactly as before.
5. **Key bindings on mouse-over** (up to 16 keys): a hidden secure button per key with `type = "macro"` and
   `/cast [@mouseover,help,nodead] Spell` (or the item/macro), bound with `SetOverrideBindingClick` while the mouse is
   over a cell — set and cleared **out of combat only**; in combat the binding stays as it was when combat started
   (no secure snippets on this client). Decision: the keys are bound for the whole session while the raid frames are
   shown (not only on hover), and the macro's `@mouseover` condition makes them act only on a hovered raid member;
   when the mouse is not over a friendly unit, the key falls through to nothing (documented in the hint).
   Consequence: a key used here is taken from its normal binding while the raid frames show, so the window warns
   when a chosen key already has a binding (`GetBindingAction`) and the hint says to pick keys not used otherwise.
   (Binding only on hover cannot work in combat on this client: override bindings may not change in combat.)
6. **Static attributes**: bindings are written as secure attributes (`shift-type1 = spell`, `shift-spell1 = …`) on
   every cell out of combat; cells the secure headers create in combat get their attributes after combat (a known gap;
   to keep it small, headers pre-create their full set of cells out of combat where the client allows it).
7. **Clique**: if Clique (or another click-cast addon using `ClickCastFrames`) is loaded, our click-casting is off by
   default and the window says so; it can still be switched on.
8. **Window**: a new raid window tab "Click-casting" (de "Klickzauber"): a table of the 40 combinations (button ×
   modifier) with an action dropdown and a value field (spell/item/macro), plus the 16 key slots; a "Clear all" with
   confirmation. Words in four languages; wiki page.
9. Out of combat only: changing bindings applies at once; in combat the window locks the table.

## 2. Architecture

- `Raid/ClickCast.lua`: the binding model (parse/validate per binding), attribute writer for a frame, the set of frames
  (raid cells of all panels + party frames if enabled), out-of-combat application, events.
- `Raid/ClickKeys.lua`: the mouse-over key buttons and override bindings.
- Settings: fixed slots (40 mouse + 16 keys) in the raid registry `general` scope, generated in a loop; codes permanent.

## 3. Limits

- Mouse-over keys: no dynamic hover binding in combat (snippets are broken); the @mouseover macro covers it.
- Cells created in combat have no bindings until combat ends (unless pre-created).
- Spells are stored by name: a name the spell book does not know is refused with a message (like the indicators).
