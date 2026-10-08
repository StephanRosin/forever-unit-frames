# User suggestions for 0.24.0 — Design

Date: 2026-10-08 · Status: decided (maintainer forwarded three CurseForge suggestions from a healer).

## 1. Never fade the player/pet frame in a group

Request: "an option to NEVER fade the player/pet frame whilst in a party/raid — as a healer I mouse-over heal without a
target, so my frame fades."

- New player setting `playerFadeGroup` (bool, default false = today): while in a party or raid (`IsInGroup()`, plain),
  the out-of-combat fade does not apply; the player frame (and the pet frame when it follows the player's fade) shows
  in full. Row in the player's fade section, greyed while the fade is off. Group changes re-evaluate the fade
  (GROUP_ROSTER_UPDATE).

## 2. Combat text position, font and size

Request: "choose the location of the combat text (left, center, right) and its font type and size separately."

- New per-frame settings on frames with combat text (`combatFeedback`): `combatFeedbackPoint` LEFT / CENTER / RIGHT
  (default CENTER = today's place exactly), `combatFeedbackX`, `combatFeedbackY` (default 0), `combatFeedbackFont`
  (media font, default = the frame's font as today), `combatFeedbackSize` (0 = automatic = today's size steps; else a
  base size the client's size steps scale from), and `combatFeedbackOutline` (follows the frame by default). Placed on
  the health bar as today. Rows in the Text tab's combat numbers section, greyed while combat text is off. Default look
  unchanged (default-look tests).

## 3. Five-second rule on the mana bar

Request: "a five second rule spark and/or countdown text on the mana bar, dimming the bar slightly during the 5 s,
direction of the spark selectable (left→right or right→left) like PitBull4."

- Player frame only, only while the power bar shows mana (druid forms: the druid mana strip is out of scope).
- **When it starts:** on `UNIT_SPELLCAST_SUCCEEDED` for the player, when the spell has a mana cost
  (`C_Spell.GetSpellPowerCost`, the entry of power type mana). The amount is never compared; only "has a mana entry"
  is used, and only when that is readable (a secret answer → no FSR rather than a guess). A new spell restarts the
  5 s.
- **Display** (each switchable): a spark that runs across the power bar in 5 s, its direction LEFT_TO_RIGHT
  (default) or RIGHT_TO_LEFT; a countdown text (seconds, one decimal under 1 s optional) at a chosen place
  (LEFT/CENTER/RIGHT of the power bar); and a dimming of the power bar's fill to a set opacity (default 70 %) during
  the rule. All three off by default (default look unchanged); a master switch `fsrEnabled` plus the three parts.
- **Mechanics:** the spark moves through an animation (Translation over the bar's width, duration 5 s), and the end
  arrives via the animation's OnFinished. No Lua counts time per frame except the countdown text, which uses a light
  ticker (0.1 s) while the rule runs. Plain frames only (shown and hidden in combat). Test mode shows a running sample.
- Colour of the spark: white with the bar's height; size setting optional (width 2–8 px, default 3).

## 4. Common

Four languages, wiki pages regenerated, news lines for 0.24.0, all defaults keep today's look and behaviour.
