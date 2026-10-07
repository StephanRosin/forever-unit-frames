# Aura blocklist — Design (package B)

Date: 2026-10-07 · Status: decided (maintainer: "A und B bitte vorbereiten"); user request of 2026-10-06 ("filter out
buffs/debuffs like a campfire or food buff").

## 1. What the client allows (read from the Forever UI source, no spike needed)

The aura containers apply `candidateFilters.excludeSpellIDs` inside Blizzard's code
(Blizzard_AuraContainerUtil.lua, `CanApplyIdentityCandidateFilters`), in and out of combat. An exclusion takes effect
only where that function allows filtering by spell:

| Aura | On | Excluding works |
|---|---|---|
| any spell flagged never-secret (e.g. Sated, Exhaustion) | anyone | yes |
| buff | you, a group member, a pet / player-controlled unit | yes |
| buff | an enemy (a unit you cannot assist) | **no** |
| debuff | a friendly unit (you, party, raid) | **no** (encounter debuffs must stay visible) |
| debuff | an enemy | yes |

So: campfire, food, well-fed, own and party buffs, and debuffs on your target can be hidden; debuffs on yourself or
your group only when the client marks the spell never-secret. The addon tells the user which case an entry falls
into (`C_Secrets.GetSpellAuraSecrecy(spellID)` → NeverSecret) instead of promising what the client refuses.

## 2. Decisions

1. **Lists**: one account-wide list ("everywhere") plus one per unit frame (player, target, focus, party, pet, …) and
   one per raid size. An aura is hidden where it is on the account list or on that frame's/size's list.
2. **Entries are spell IDs**, typed as IDs or names (a name is turned into its IDs through the client's spell data;
   for a name that matches several IDs, all of them). Unknown ones are refused with a message. Stored as validated text
   ("1234, 5678"), at most 100 IDs per list.
3. **Applying**: through the container's `excludeSpellIDs` (the same path as "hide tracking" today:
   Elements/AuraContainers.lua builds `filters.excludeSpellIDs` from the sets), merged with the tracking set; for the
   query-based paths (Elements/Auras.lua `fill`) the same set is checked on a readable spellId (secret → shown, no
   error). Raid cells: their buff indicators and debuff row use the raid size's list plus the account list.
4. **Adding from the frame**: Shift + right-click on an aura icon (out of combat, only when the aura's spell ID is
   readable) puts it on that frame's list; Shift + Ctrl + right-click on the account list. A chat line says what was
   added and how to undo ("/fuf auras" or the list editor). In combat the click does nothing (the icons are not secure;
   nothing protected is involved, but settings changes rebuild containers out of combat).
5. **Editor**: in each frame's Auras tab (unit frames), the General page (account list) and the raid Debuffs tab
   (size list): a multi-line text field with the list, names shown next to IDs, a "Remove" per entry, and a short note
   on what the client allows (table above in one sentence). Entries the client will ignore here (e.g. a debuff on the
   party list that is not never-secret) are marked "only on enemies"/"not on your group" instead of silently doing
   nothing.
6. **Defaults**: empty lists (nothing changes for anyone).
7. **Export/import/profiles**: the per-frame and per-size lists travel with their profile/size; the account list with
   the account (not in size exports).

## 3. Tests

Container filter built with the lists (and with tracking), in and out of combat; list validation (IDs, names, limits,
duplicates); the secret spell-ID case on the click and query paths (no entry, no error); the "won't apply here"
marking; raid cells use size + account list; profile copy/export carry the per-size list.

## 4. Release

Ships with package A as 0.23.0, with a news line and wiki text.
