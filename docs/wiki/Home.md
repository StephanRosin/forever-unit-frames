# Forever Unit Frames

Clean, fully configurable unit frames for **WoW: Forever**: player, target, target of target, focus,
pet and party, with auras that keep updating in combat, threat, range and dispel indicators.
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

## Profiles

**General** > **Profile**: *Export* gives a text you can copy to share or back up your whole setup,
*Import* takes such a text, *Reset all settings* goes back to the defaults.

## Commands

| Command | What it does |
|---|---|
| `/fuf` | Opens the options |
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

Questions that come up often: [[FAQ]].

## Feedback

Suggestions and bug reports are welcome in the comments on CurseForge or as an issue on GitHub.
Please mention the frame, the tab and the setting, and other addons involved if there are any.
