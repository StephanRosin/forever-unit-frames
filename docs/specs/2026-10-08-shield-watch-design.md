# Shield watch — Design (0.25.0)

Date: 2026-10-08 · Status: decided, reworked the same day (maintainer request: "a shield watcher like a WeakAura:
each shield's icon above the player frame, everything freely placeable"). In short: **icons of your active shields
and the exact total of all your absorbs**.

## 1. Facts

`UnitGetTotalAbsorbs("player")` is the exact sum of all absorbs on the player (checked in game). It may be secret
(combat, restricted states): then it is only passed to sinks — never compared, added or truth-tested. A single
shield's remaining absorb (an aura's `points`) is not used: it is not readable when it matters (in combat), and the
total is never attributed to one shield.

## 2. Decisions

1. **Player only**: one block on the player frame, its own switch (default off), its own mover (mover group
   "units", unlocked with the other unit-frame parts) and position (x/y like the castbar's detached position,
   clamped to the screen). The first build also offered target and focus and "Only my shields"; never released,
   removed with their settings.
2. **Watched shields**: a shipped list of absorb spells (all Classic ranks), in groups, each switchable:
   **Priest** (Power Word: Shield), **Mage** (Ice Barrier, Mana Shield, Fire Ward, Frost Ward), **Warlock**
   (Shadow Ward, Sacrifice: the Voidwalker's shield on the warlock) and **Potions and items** (Fire / Frost /
   Shadow / Nature / Holy / Arcane Protection of the normal and Greater protection potions, Aura of Protection,
   The Burrower's Shell, Harm Prevention Belt). The block watches the player's own class's group, the Priest group
   (a priest's shield lands on anyone) and the potions and items. "More shields" adds spells by ID or name
   (validated like the aura blocklist, Core/AuraBlocklist.lua; a name adds the ranks it resolves to). The IDs go to
   the client as they are: an ID it does not know matches nothing, so no name lookup or check is needed.
3. **Icons**: a Blizzard aura container (`CustomAuraContainerTemplate`, the machinery of
   Elements/AuraContainers.lua) on the player with one group, filter `HELPFUL`, candidate filter
   `includeSpellIDs` = the watched IDs. The client reads the auras and fills the icons from secure code, in combat
   too; filtering helpful auras by spell is allowed on the player (`CanApplyIdentityCandidateFilters`). Layout =
   the watch's icon size, spacing and growth (flow from the block's first corner). Swipe and time left are the
   container's own (its duration cooldown; the time text is the cooldown's countdown numbers, placed and styled in
   `initializeFrame` and restyled out of combat). The container is made the first time the block is styled with
   the watch on and is configured only out of combat (`ns.AfterCombat`); its buttons refuse restyling while auras
   are secret, so a refused restyle is tried again after combat. Without container support there are no icons,
   only the total.
4. **Total**: one text, `UnitGetTotalAbsorbs("player")`, written by the client through
   `C_StringUtil.TruncateWhenZero` (the whole number, an empty text at zero; a secret in gives a secret text). That
   is the secret-safe rule for "shown only while the total is above zero": nothing is compared, the client blanks a
   zero. The total counts every absorb on the player, including shields not on the list. No abbreviation (Classic
   absorbs stay small, and the client offers no abbreviation that blanks a zero). Updates on
   `UNIT_ABSORB_AMOUNT_CHANGED` and `UNIT_AURA` (player).
5. **Total placement**: TOP / BOTTOM / LEFT / RIGHT / CENTER of the icon block with X/Y offset, own font, size
   (Automatic: half the icon size), outline, colour (default white). Default: left of the icons with a small gap
   (they grow away from it). The text hangs from the container, which the client sizes to its icons; only frames
   with the untrusted-layout aspect may anchor to a container, so the text lives on a frame made with
   `DisableUntrustedLayoutScriptsTemplate` (as Elements/WeaponEnchants.lua). In test mode it hangs from the block's
   handle instead.
6. **Defaults**: off (existing users see nothing new, no container is made). Test mode shows two sample icons and
   a sample total (our own icons on the handle; the container hides, it shows only real auras). Placement in the
   options: the player's **Auras** tab, a section "Shields" after the dispel section. The 0.25.0 news says where to
   switch it on; its button opens the player's Auras tab.
7. **Hide them in the buffs** (default on, effective only while the watch is on): the watched spell IDs join the
   buffs' excluded set — the same `excludeSpellIDs` path the aura blocklist and "hide tracking" feed
   (Elements/AuraContainers.lua and the query path in Elements/Auras.lua).
8. Plain frames only. Four languages; wiki.

## 3. Verification

- `CustomAuraContainerSharedMixin:AddAuraGroup` / `SetAuraGroupCandidateFilters` (Blizzard_CustomAuraContainer.lua):
  `includeSpellIDs` is a map of permitted spell IDs; spell ID matching is only permitted for helpful auras on
  assistable units; adding a group gives the container the UntrustedLayoutScriptExecution aspect (other frames
  need `DisableUntrustedLayoutScriptsTemplate` to anchor to it); the client sizes the container to its icons
  (`OnLayoutComplete`, secret-wrapped).
- `UnitGetTotalAbsorbs(unit)`: SecretReturns, never nil — passed to the client's formatter only.
- `C_StringUtil.TruncateWhenZero(number)` (StringUtilDocumentation.lua): SecretArguments AllowedWhenTainted;
  "formats the number as an integer (rounding down); zero gives an empty string" (already used for the deficit
  texts, Elements/Texts.lua).
- `UNIT_ABSORB_AMOUNT_CHANGED(unitTarget)` exists (UnitDocumentation.lua).
