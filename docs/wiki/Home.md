# Forever Unit Frames

Clean, fully configurable unit frames for **WoW: Forever**: player, target, target of target, focus,
pet and party, with auras that keep updating in combat, threat, range and dispel indicators, and raid
frames for 10, 20 and 40 players.
English, Deutsch, Español, Français.

Download: [CurseForge](https://www.curseforge.com/projects/1708698) ·
Source: [GitHub](https://github.com/StephanRosin/forever-unit-frames)

## Getting started

- **`/fuf`** opens the options window. The frames are listed on the left (**General** first), the tabs
  of the selected page are along the top.
- **General** sets the look of every frame at once. A frame's own page can override any of those
  settings; an overridden setting has a **Reset** button that hands it back to General.
- **General > Frames** lists every frame with a switch, to turn frames on or off at a glance.
- **Test mode** (button at the bottom of the window) shows every frame with sample values: auras,
  casts, a full party, and every indicator you have switched on, so you can set everything up
  without a target or a group.
- **Moving frames:** *Unlock frames* at the bottom of the window (or `/fuf unlock`), drag them,
  then *Lock frames* (or `/fuf lock`). Exact positions are on each frame's **Layout** tab.
- **Scrolling:** the mouse wheel scrolls the page. To change a slider with the wheel, hold **Shift**.
  You can also drag a slider or type a value into the box next to it.

## Raid frames

- **`/fuf raid`** opens the raid options window (also: the **Raid frames…** button in `/fuf`, the raid
  frames' own minimap button, or their entry in the addon compartment).
- Each character has **three raid profiles**, one per raid size: 10, 20 and 40. The size tabs at the
  top of the window choose the profile you edit; the one shown right now is marked *(shown)*.
  **Raid size shown** next to them follows the raid instance (outside one the group's size), or fixes
  one size.
- **Test mode** in the raid window shows a pretend raid of the size you edit, at that size's place,
  with every option you switched on; closing the window or entering combat ends it.
- **Copy from…** takes another size, or a size of another of your characters (two clicks).
  **Export / Import** shares one size as a text; **Reset this size** goes back to its defaults.
- Corner indicators take spell IDs or spell names from your spell book; a name stands for every rank
  you know. A name or class the window cannot use is named in the chat.
- The cells have a look of their own per raid size (texture, colors, fonts, border): changing the party
  frame does not change them.

## Profiles

**General** > **Profile**: *Export* gives a text you can copy to share or back up your whole setup,
*Import* takes such a text, *Reset all settings* goes back to the defaults.

## Commands

| Command | What it does |
|---|---|
| `/fuf` | Opens the options |
| `/fuf raid` | Opens the raid frames' options |
| `/fuf unlock`, `/fuf lock` | Lets you drag the frames, and locks them again |
| `/fuf status` | Prints the client version and where the settings came from |
| `/fuf reset <frame\|all>` | Resets one frame (player, target, targettarget, pet, focus, party) or everything |
| `/fuf set <scope> <setting> <value>` | Sets one setting by name (for macros) |

## Every setting

The settings pages list every option with what it does, its choices, its default and which frames
have it. They are generated from the addon itself, so they always match the current version.

- [[General|Settings-General]] – the look of all frames at once
- [[Layout|Settings-Layout]] – size, position, bar heights, portrait, border, shadow, corners
- [[Group|Settings-Group]] – party arrangement, party pets, party targets
- [[Bars|Settings-Bars]] – colors, textures, shields, incoming heals, power colors, druid mana
- [[Text|Settings-Text]] – what the texts show and how they read, fonts
- [[Auras|Settings-Auras]] – buffs, debuffs, dispellable debuffs, totems
- [[Status|Settings-Status]] – combat, PvP and status icons, raid markers, combo points, threat,
  highlights, range and out-of-combat fading
- [[Castbar|Settings-Castbar]] – castbars and the threat bar

The raid frames have pages of their own, one per tab of the raid window:

- [[General|Raid-General]] – raid frames on or off, the raid view in a party, Blizzard's raid frames,
  the raid size shown, the raid minimap button
- [[Layout|Raid-Layout]] – grouping, sorting, class order, how blocks and cells are arranged, position,
  borders
- [[Cell|Raid-Cell]] – cell size, bar texture and colors, power strip, border and corners, heals and
  shields
- [[Texts|Raid-Texts]] – the name and the second line, their colors and fonts
- [[Debuffs|Raid-Debuffs]] – the dispellable debuff in the centre or as a square in a corner, the debuff
  row
- [[Indicators|Raid-Indicators]] – the five corner indicators
- [[Icons & states|Raid-Icons-and-states]] – role, raid marker, leader, master looter, ready check,
  range, aggro, your target

Questions that come up often: [[FAQ]].

## Feedback

Suggestions and bug reports are welcome in the comments on CurseForge or as an issue on GitHub.
Please mention the frame, the tab and the setting, and other addons involved if there are any.
