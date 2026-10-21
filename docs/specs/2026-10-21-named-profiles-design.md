# Unit frames: named profiles — Design

Date: 2026-10-21 · Status: decided (maintainer: "save the current settings under a name so another character can
load them — a different layout per class"). Decision 78.

## Goal

Today the unit frames have one account-wide profile (`ForeverUnitFramesDB.profile`): every character looks the same.
Named profiles are account-wide; each character uses one of them. Editing a profile changes it for every character on
it (the AceDB model, as Forever Consumables).

Not part of it: the raid frames (per character, own templates) and the click-casting bindings (per character, in the
raid store) stay as they are; the options window's position and `newsSeen` stay account-wide.

## Storage

- `ForeverUnitFramesDB.profiles = { [name] = profile }` (account-wide) and
  `ForeverUnitFramesDB.active = { ["Name-Realm"] = name }` (key from `ns.RaidProfiles.CharKey()`).
- Migration, once: an existing `profile` becomes `profiles["Default"]` (localised display name, stored key `Default`);
  `profile` is removed. The look does not change (`presetVersion` stays account-wide; `PresetUpgrade` runs on the
  migrated profile as today).
- A character without an entry, or whose profile was deleted, uses `Default`. `Default` always exists and cannot be
  deleted or renamed.
- Load order unchanged for an empty account: providers → old macro backup → defaults; the result becomes `Default`.
- `Storage.Save` writes the active profile into `profiles[active]`. Storage providers keep getting one string: the
  active profile.

## Options window

- Left navigation: new entry **Profiles** at the bottom, below the frames (separator above, language row stays last).
- Its page, top to bottom:
  1. **Profiles**: dropdown "Active profile" (sorted, `Default` first); buttons "Save as…", "Rename…", "Delete".
  2. **Export**, 3. **Import**, 4. **Reset** — the existing blocks of General › Profile, moved unchanged; they act on
     the active profile.
- General › Profile is removed. Its minimap section (`minimapShow`, `minimapAngle`) moves to the end of
  General › Frames; the keys stay in the profile.

## Actions

- **Switch**: loads the chosen profile with `Config.Import` (combat handling as import today) and stores it in
  `active` for this character.
- **Save as…**: name dialog; copies the current settings under the new name and switches to it.
- **Rename…**: same dialog; every character on that profile follows.
- **Delete**: two-click button (as "apply font to frames"); characters on it go back to `Default`; the current one
  loads `Default` at once.
- Names: trimmed, 1–40 characters, unique ignoring case; the dialog sets `maxLetters` itself (Blizzard's popup keeps
  the last dialog's limit). A refused name shows the reason in the page's message line.

## Not built

"Copy from" (Save as covers it), choosing a profile by class automatically, a profile per specialisation.

## Tests

Migration of an old `profile`; switch, save as, rename and delete including other characters on the profile; fallback
to `Default` for a missing profile; name rules; Storage.Save writes the active one; the page and navigation build;
General has no Profile tab and Frames has the minimap section. Single test files while building, the full suite once
at the end.
