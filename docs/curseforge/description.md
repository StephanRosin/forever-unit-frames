**Summary**

Clean, fully configurable unit frames for WoW: Forever. Player, target, target of target, focus, pet and party, with auras that update in combat.

---

# Forever Unit Frames

Unit frames built for **WoW: Forever**, in the spirit of Shadowed Unit Frames. Every size, position, colour and font is configurable in a movable options window. The frames look good out of the box.

## Frames
- Player, Target, Target of Target, Focus, Pet and Party.
- A three-row layout: a title row with name and level in class colour, health, and power. Each row's height is set in percent of the frame.
- Round class badge, and a secondary name (surname) that can be turned on or off.
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

## Look
- Bar textures, including Blizzard's own; LibSharedMedia textures and fonts appear too if another addon provides them. Fonts with size and outline (including a soft outline) and colours.
- Rounded corners, and an outer border (Flat or Gold with shading) that encloses the frame and its docked castbar.
- Soft drop shadow.
- Global font settings with "Apply to all frames".

## Options
- `/fuf` opens a movable options window: frames on the left, tabs on top.
- Every position can be set by dragging (`/fuf unlock`) or as exact X/Y values.
- Test mode shows sample auras, casts and a full party, so you can set everything up without a group.
- Settings are stored compactly. They can be exported and imported as a string.
- Settings survive client restarts: the addon keeps a small backup in character macros named "Forever Unit Frames backup – keep". Please don't delete these macros.

## Commands
`/fuf` (options), `/fuf unlock`, `/fuf lock`, `/fuf status`, `/fuf reset <frame|all>`, `/fuf set <scope> <setting> <value>`

## Notes
- Made for WoW: Forever only. It relies on Forever's API and will not load on other clients.
- English only for now.
- Bug reports and ideas are welcome on the project's issue tracker.
