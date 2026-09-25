**Summary**

Clean, fully configurable unit frames for WoW: Forever. Player, target, target of target, focus, pet and party, with auras that update in combat.

---

# Forever Unit Frames

Unit frames built for **WoW: Forever**, in the spirit of Shadowed Unit Frames. Every size, position, colour and font is configurable in a movable options window. The frames look good out of the box.

## Frames
- Player, Target, Target of Target, Focus, Pet and Party.
- Party pets: a list directly below the party block, showing only the pets that exist, without gaps (can be turned off).
- A three-row layout: a title row with name and level in class colour, health, and power. Each row's height is set in percent of the frame.
- Round class badge, and a secondary name (surname) that can be turned on or off.
- Elite, rare and boss marker on the portrait or as a word.
- Absorb shields and incoming heals drawn in the health bar, with an optional overheal lane.
- Damage and heal numbers on the frame (combat feedback).
- 2D or 3D portraits.

## Auras
- Buffs and debuffs on every frame, drawn by the game's own aura containers, so they **keep updating in combat**.
- Your own debuffs come first and bigger.
- Wraps to new rows when they don't fit, with a limit per row.
- Anchor to the frame, the health bar, the power bar, the castbar or the other aura group, with any of the 9 points and an X/Y offset.
- Size, spacing, growth direction, maximum count, "only mine", "dispellable only", remaining time and dispel-type colours.

## Castbars
- Castbars for player, target, target of target, focus and party.
- Docked below or above the frame, or detached with its own position.
- "Always show" keeps an empty bar in the frame so nothing below it jumps.
- The player castbar can run alongside Blizzard's, or hide it.

## Totems
- Totem icons on the player frame, one per totem slot, with the remaining time. Right-click one to destroy it.
- Placed next to the player frame by default; size, spacing, anchor point and X/Y offset are configurable.

## Look
- Bar textures, including Blizzard's own; LibSharedMedia textures and fonts appear too if another addon provides them. Fonts with size and outline (including a soft outline) and colours.
- Rounded corners, and an outer border (Flat or Gold with shading) that encloses the frame and its docked castbar.
- Soft drop shadow.
- Global font settings with "Apply to all frames".

## Options
- `/fuf` opens a movable options window: frames on the left, tabs on top.
- Every position can be set by dragging (`/fuf unlock`) or as exact X/Y values.
- Test mode shows sample auras, casts, totems and a full party, so you can set everything up without a group.
- Settings are stored compactly. They can be exported and imported as a string.

## Commands
`/fuf` (options), `/fuf unlock`, `/fuf lock`, `/fuf status`, `/fuf reset <frame|all>`, `/fuf set <scope> <setting> <value>`

## Notes
- Made for WoW: Forever only. It relies on Forever's API and will not load on other clients.
- English only for now.
- Updating from 0.2.x: the settings backup in the "FUF Save" character macros is no longer needed. Settings found only there are moved to the normal saved settings once, then the addon deletes its own backup macros.
- Bug reports and ideas are welcome on the project's issue tracker.
