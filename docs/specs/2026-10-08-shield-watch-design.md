# Shield watch — Design (0.25.0)

Date: 2026-10-08 · Status: decided (maintainer request: "a shield watcher like a WeakAura: each shield's icon above the
player frame with the exact absorb left, everything freely placeable").

## 1. Facts (checked in game by the maintainer)

`C_UnitAuras.GetAuraDataBySpellName("player", name).points[1]` is the shield's remaining absorb and changes as the
shield takes damage; `UnitGetTotalAbsorbs("player")` is the exact sum of all absorbs. Values may be secret (combat,
restricted states): then they are only passed to sinks (SetFormattedText, SetTexture, cooldown) — never compared,
added or truth-tested.

## 2. Decisions

1. **Player, target and focus** (maintainer extension of the request; one code for all three): a per-frame
   feature (`only` = player, target, focus), each frame with its own switch (default off), its own block with its
   own mover (mover group "units", unlocked with the other unit-frame parts), its own position (x/y like the
   castbar's detached position, clamped to the screen) and its own text and layout settings. Target and focus
   changes (PLAYER_TARGET_CHANGED, PLAYER_FOCUS_CHANGED) refresh their block. On target and focus a switch "Only my
   shields" (default off) asks the client with the filter "HELPFUL|PLAYER" instead of "HELPFUL", so the client
   decides whose shield it is (sourceUnit is never compared).
2. **Watched shields**: a shipped list of absorb spells (all Classic ranks; names resolved through the client at
   run time, IDs it does not know dropped), in groups, each group switchable: **Priest** (Power Word: Shield),
   **Mage** (Ice Barrier, Mana Shield, Fire Ward, Frost Ward), **Warlock** (Shadow Ward, Sacrifice: the
   Voidwalker's shield on the warlock) and **Potions and items** (Fire / Frost / Shadow / Nature / Arcane
   Protection of the normal and Greater protection potions, Aura of Protection, The Burrower's Shell, Harm
   Prevention Belt). No real absorbs for the other classes in Classic (Divine Shield, Blessing of Protection are
   immunities). The player's block watches its own class's group, the Priest group (a priest's shield lands on
   anyone) and the potions and items; target and focus watch every group. Lookup is by name, so all ranks and
   same-named versions are found. Extra spells can be added by name/ID (validated like the aura blocklist,
   Core/AuraBlocklist.lua helpers).
3. **Per shield**: its icon (the aura's), the **remaining absorb** (points[1], formatted like the health texts:
   abbreviation optional), optionally the **time left** (cooldown swipe and/or text). One icon per active shield, in
   a row/column with growth direction, spacing, icon size.
4. **Text placement**: amount text TOP / BOTTOM / LEFT / RIGHT / CENTER of the icon with X/Y offset, own font, size,
   outline, colour (default white). Time text likewise (default: cooldown swipe only).
5. **Exactness**: shown amount is points[1] of that aura. If the aura data is secret or unreadable for a shield, the
   icon still shows (texture through the sink) and the amount falls back to the exact total (`UnitGetTotalAbsorbs`)
   **only when exactly one watched shield is active**; otherwise the amount is hidden for that shield (never guessed).
   How "exactly one active" is known without reading secret data: count shields found by name lookup — the existence
   check must be secret-safe (verify against the mock's secret model and the API doc flags for
   GetAuraDataBySpellName: RequiresNonSecretAura / SecretWhenUnitAuraRestricted). With "Only my shields" the count
   uses the same filter for what is shown, and the total (everyone's absorbs) is allowed only when exactly one
   watched shield is active from any caster. Where the client refuses (an error, a secret answer, a unit token it
   restricts), nothing is shown for that shield, never a guess.
6. **Updates**: UNIT_AURA (player) and UNIT_ABSORB_AMOUNT_CHANGED (if it exists on Forever — verify) refresh; no
   per-frame OnUpdate (cooldown frames animate themselves).
7. **Defaults**: off (existing users see nothing new); test mode shows two sample shields on each of the three
   frames so they can be placed. Placement in the options (maintainer): each frame's **Auras** tab, a section
   "Shields" after the debuff and dispel sections. The 0.25.0 news line says where to switch it on; its button
   opens the player's Auras tab.
8. Plain frames only (shown/hidden in combat fine). Four languages; wiki.
9. **Hide them in the buffs** (each frame, default on, effective only while that frame's watch is on): the
   watched shield spell IDs of that frame (all ranks plus the user's additions) join the buffs' excluded set —
   the same excludeSpellIDs path the aura blocklist and "hide tracking" feed (Elements/AuraContainers.lua and the
   query path in Elements/Auras.lua). The client filters helpful auras by spell only on you, group members and
   pets (Blizzard_AuraContainerUtil, CanApplyIdentityCandidateFilters), not on hostile units: there the buffs keep
   showing them. Containers are reconfigured only out of combat, as today.

## 3. Verification (§5, §6)

- `C_UnitAuras.GetAuraDataBySpellName(unit, spellName, filter)`: SecretWhenUnitAuraRestricted, RequiresNonSecretAura,
  SecretArguments AllowedWhenUntainted; `filter` is an optional AuraFilters string (HELPFUL, PLAYER as in
  GetUnitAuras); returns a nilable AuraData. Neither flag says how it shows, so the strict reading holds (as the
  mock's): while the unit's auras are restricted the whole answer is secret — the aura's presence is not told —
  and a secret spell's aura makes the call fail. A shield's state is therefore one of three: **active** (a plain
  table), **absent** (nil while `C_Secrets.ShouldSpellAuraBeSecret` says false for that spell) or **unknown**
  (an error, a secret answer, or nil while the spell's aura may be secret). An unknown shield is not shown, and
  while any watched shield is unknown the number of active shields is not known either: no total fallback.
- The unit token types (UnitTokenRestrictedForAddOns, UnitTokenPvPRestrictedForAddOns) are not defined in the
  documentation; every call is guarded, and a refusal counts as unknown.
- `UnitGetTotalAbsorbs(unit)`: SecretReturns, never nil — passed to a text only, never compared.
- `UNIT_ABSORB_AMOUNT_CHANGED(unitTarget)` exists (UnitDocumentation.lua); with UNIT_AURA it refreshes the block.
- `AbbreviateNumbers(number)` takes a secret (AllowedWhenTainted): a secret amount is abbreviated by the client;
  a plain one like the health texts (Secrets.Abbreviate).
- Time left: the aura's own duration, or the client's duration object by aura instance ID
  (Elements/AuraButton.lua), on a cooldown frame; the time text is the cooldown's own countdown numbers, placed
  and styled — no Lua timer.
