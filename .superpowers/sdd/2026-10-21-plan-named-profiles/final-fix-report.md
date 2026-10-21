# Final fix report: named unit frame profiles

Full suite after all fixes: 49247 passed, 0 failed.
Focused: unit_profiles 51/0, window_profiles 350/0, storage 25/0, boot 52/0, macro_migration 126/0, locale 13777/0.

RED evidence: source changes stashed, new tests run.
- window_profiles RED: 339 passed, 11 failed (typed name never reaches Save as/Rename once ClearFocus fires
  OnEditFocusLost: "Type a name first"; EMPTY/TOO_LONG messages; picker-switch one click deleted the profile).
- unit_profiles RED: stops at the first new assertion (mirror, `db.profile` nil). With that line removed it stops
  at the round-trip assertion (line 86, same cause). Later asserts (Default GONE, 40/41 letters, localised Default,
  WAITING) are red by construction (old code) but the Lua error hides them; they pass GREEN.

Per finding:
1. Window.lua: local `typed` bound as get/set of the name box; act() reads `typed` after ClearFocus, resets on success.
   Test types with M.Type, with a client-like ClearFocus (fires OnEditFocusLost) installed on the box.
2. UnitProfiles.Switch: GONE only when the name is not Default. Test "fresh: back to Default".
3. Picker `set` and the UNIT_PROFILES_CHANGED listener call `Disarm()` on the delete button. Test: arm on B, switch via
   picker set to A, one click deletes nothing, second does.
4. Write mirrors Default into `db.profile`; Attach no longer clears it (still adopts it as Default). Migration test
   updated; new tests: mirror follows Default, not other profiles, older version's edit becomes Default, named profile
   survives. Spec Storage section updated.
5. Switch/SaveAs/Rename/Delete return nil,"WAITING" while Storage.IsWaiting(); PROFILE_WAITING in 4 locales; test.
6. Name length counts UTF-8 characters; test 40 umlauts accepted, 41 TOO_LONG.
7. Name equal (case-insensitive) to L.PROFILE_DEFAULT -> TAKEN; test.
8. deleteBlock only calls SetEnabled on a state change. Test: armed text survives CONFIG_CHANGED.
9. UI tests added: EMPTY, TOO_LONG, DEFAULT (Rename on Default) messages; switching via the picker's set; Enter commit.
