# Raid Frames — Design (Part 6: role templates and setup wizard)

Date: 2026-10-07 · Status: design decided by the assistant on the maintainer's behalf, to be reviewed in the big
in-game test.

VuhDo: "setup wizard; templates for healer, tank, DPS, decurse-only; class-based suggestions; skins". This part makes
the many raid settings reachable in a few clicks.

## 1. Decisions

1. **Templates** are named sets of raid settings applied to one raid size or to all three (the user picks). A template
   only sets the keys it names; everything else stays. Applying is one change (`Config.SetKeys`), out of combat
   (the window is locked in combat anyway), and can be undone once ("Undo" restores the values from before, kept for
   the session).
2. **Role templates** (shipped):
   - **Healer**: wider cells, health deficit as second line, heal prediction + overheal + absorbs on, debuff row with
     dispellable debuffs highlighted, dispel indicator on, range fade on, buff watch window on (if the class has buffs),
     own HoTs as indicators (the class's HoT spells, part 1 indicators).
   - **Tank**: compact cells, threat indicator on, main tanks panel on with larger cells, debuff row only boss/dispel
     relevant, heal prediction off.
   - **DPS**: small cells, sorted by group, many groups per line, no second line, heal prediction off, debuffs only
     dispellable by you.
   - **Dispel only** ("decurse-only"): DPS look, but dispellable debuffs shown large and the dispel indicator prominent;
     click-casting suggestion: plain left = your dispel spell on the clicked member (only offered, never set without a
     click).
3. **Class suggestions**: the wizard proposes the template from the class and spec role (`GetSpecialization` role or
   `UnitGroupRolesAssigned("player")`, secret-checked; fallback: class default — priest/druid/paladin/shaman = healer,
   warrior = tank, others = DPS) and, for healers and dispellers, click-casting suggestions (the class's main heal on
   Shift-left etc.) that the user can accept or leave.
4. **Looks ("skins")**: three shipped looks that only touch appearance keys (cell shape, borders, fonts, bar texture,
   colours): "Forever" (today's default), "Flat" (no rings, thin borders), "Classic" (Blizzard-like). Applied like
   templates.
5. **Setup wizard**: a small window with 3–4 steps (role template → look → which raid sizes → optional click-casting
   suggestions → summary "Apply"). It opens **once** the first time the raid window is opened by a character with an
   untouched raid profile (never automatically for characters that changed anything), and any time from a button in
   the raid window's General tab ("Setup wizard…"). It respects the login-window rule (LOADING_SCREEN_DISABLED).
6. **Own templates**: the user can save the current size's settings as a named template (per account, so other
   characters can use it) and apply/delete it; export/import already exist per size.
7. **Window**: no new tab — the General tab gets a section "Templates" (apply a role template / look / own template to
   this size or all sizes, save as template, undo, wizard button). Words in four languages; wiki page.

## 2. Architecture

- `Raid/Templates.lua`: shipped templates (key → value tables, validated against the registry at load in tests), apply/
  undo, own templates (account-wide saved variable table inside the existing DB, validated on load like imports).
- `Raid/Wizard.lua`: the wizard window (reuses Options/Widgets).
- Class data for suggestions (HoT spells, dispel spells, main heals) shipped as spell IDs resolved by the spell book
  (as part 5).

## 3. Limits

- Templates set settings only; they never cast or bind anything without the user's click.
- Suggestions depend on the spell book; unknown spells are skipped.
