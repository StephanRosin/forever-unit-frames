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
  then *Lock frames* (or `/fuf lock`). Exact positions are on each frame's **Layout** tab. This
  moves the unit frames; the raid panel has its own *Unlock frames* in the raid window.
- **Scrolling:** the mouse wheel scrolls the page. To change a slider with the wheel, hold **Shift**.
  You can also drag a slider or type a value into the box next to it.

## Raid frames

- **`/fuf raid`** opens the raid options window (also: the **Raid frames…** button at the bottom of `/fuf`, the raid
  frames' own minimap button, or their entry in the addon compartment).
- The top bar of the raid window reads **General | 10 | 20 | 40 | Profiles**. **General** holds the
  settings of your character, the same at every size (General, Click-casting, Buffs, Tools). Each character
  has **three raid profiles**, one per raid size: 10, 20 and 40; picking a size shows its tabs and edits its
  profile, the one shown right now is marked *(shown)*. **Profiles** holds what acts on sizes as a whole
  (see below).
  **Raid size shown** next to them follows the raid instance (outside one the group's size), or fixes
  one size.
- **Unlock frames** in the raid window lets you drag the raid panels and the raid tools bar (only these;
  `/fuf lock` locks them too). **Test mode** in the raid window shows a pretend raid of the size you edit, at
  that size's place, with every option you switched on, and pretend players in the special panels you switched
  on; closing the window or entering combat ends it.
- **Special panels** (the **Special panels** tab) show the raid's main tanks (on by default) and main assists, your own
  lists of tanks and of favorites, and the raid's pets, each in a panel of its own with its own place per
  raid size. Players stay in their group as well. Right-click a cell to put a player on your tanks or your
  favorites, or type the names on the **Special panels** tab; in combat the panel follows after the fight.
- **Own panels** (the **Own panels** tab): up to nine panels of your own beside the main panel, per raid size,
  each with its grouping (group, class or role), the blocks it shows, a title and a layout of its own. Drag a
  block from one panel's column to another's, or click it and pick **Move to …**. A block of the main panel's
  grouping leaves the main panel; one of another grouping shows its players again (a "Healers" panel beside
  the groups). Changes made in combat apply after the fight.
- The **raid tools bar** (the **Tools** tab) takes the place of Blizzard's raid manager: raid target icons and
  the last ready check for everyone; starting a ready check, a role poll and world markers for the leader and
  assistants; everyone an assistant, party to raid and back and the loot method for the leader. It sits behind
  a handle on the right edge of the raid panel (click it to fold the bar out), or free where you drag it. It
  folds out and in, and follows changes of who leads, only out of combat.
- The **Profiles** tab (beside the sizes) starts with the role templates, the looks and the setup wizard's
  button (see [[Templates|Raid-Templates]]). Below them it keeps your own profiles (all three sizes or one, under a
  name, for every character of your account), copies one size onto another (everything, or without layout and sizes)
  or a size of another of your characters, resets a size, and exports all sizes or one as a text and imports
  it again. Applying, copying between sizes and importing several sizes can be undone once.
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
| `/fuf news` | Shows what's new in this version (shown once by itself after an update) |
| `/fuf unlock`, `/fuf lock` | Lets you drag the unit frames, and locks them (and the raid panel) again |
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
- [[Status|Settings-Status]] – combat, PvP and status icons, raid markers, the elite marker, combo points,
  threat, highlights, range and out-of-combat fading
- [[Castbar|Settings-Castbar]] – castbars and the threat bar

The raid frames have pages of their own, one per tab of the raid window, grouped as its top bar groups
them.

Under **General** (your character's, the same at every size):

- [[General|Raid-General]] – raid frames on or off, the raid view in a party, Blizzard's raid frames,
  the raid size shown, the raid minimap button
- [[Click-casting|Raid-Click-casting]] – spells, items, macros, target, focus, assist and the menu on
  mouse clicks over the cells and party frames, and keys that cast on the raid member under the mouse
- [[Buffs|Raid-Buffs]] – the buff watch: missing and expiring group buffs, one click or key to rebuff
- [[Tools|Raid-Tools]] – the raid tools bar: docked or free, which tools it holds

Under a raid size (10, 20, 40: each size its own):

- [[Cell|Raid-Cell]] – cell size, bar texture and colors, power strip, border and corners, heals and
  shields
- [[Text|Raid-Text]] – the name and the second line, their colors and fonts
- [[Debuffs|Raid-Debuffs]] – the dispellable debuff in the center or as a square in a corner, the debuff
  row
- [[Indicators|Raid-Indicators]] – the five corner indicators
- [[Icons & states|Raid-Icons-and-states]] – role, raid marker, leader, master looter, ready check,
  range, aggro, your target
- [[Layout|Raid-Layout]] – grouping, sorting, class order, how blocks and cells are arranged, position,
  borders
- [[Special panels|Raid-Special-panels]] – the special panels: main tanks, main assists, my tanks, favorites, pets
  (the name lists are per character)
- [[Own panels|Raid-Own-panels]] – up to nine panels of your own: which blocks each one shows, moved by
  drag-and-drop, and each panel's layout

Under **Profiles**:

- [[Profiles|Raid-Profiles]] – templates and the setup wizard, own profiles, copy between sizes and from
  another character, reset, export and import of all sizes or one
- [[Templates|Raid-Templates]] – role templates (healer, tank, DPS, dispel only) and looks (Forever, Flat,
  Classic) at the top of the Profiles page, and the setup wizard

Questions that come up often: [[FAQ]].

## Feedback

Suggestions and bug reports are welcome in the comments on CurseForge or as an issue on GitHub.
Please mention the frame, the tab and the setting, and other addons involved if there are any.
