# FAQ

### Why do some things look different in combat, or in dungeons and PvP?

WoW: Forever hides some values from addons in certain situations ("secret values"): the player's
health, a target's threat or class, combo points in PvP and more. Addons may still show them, but
may not compare or calculate with them. Forever Unit Frames always shows what the game allows, so a
few details are simpler then: a secret class token shows the class without its color, a secret
faction shows no PvP crest. Nothing breaks, and it all comes back as soon as the value is readable
again. Where the game itself can draw a secret value (health bars, aura borders, combo points), it
still shows in full.

### Click-casting (Clique) doesn't work

Every unit frame registers with click-casting addons through the common `ClickCastFrames` table
(since 0.15.2). If it still doesn't work, please report it with the addon's version; many addons
aren't built for WoW: Forever yet.

### A portrait shows a flat picture for a moment

With 3D portraits the 2D picture stands in while the game loads the 3D model, usually only for a
split second. If a unit has no 3D model at all, the 2D picture stays.

### Heals over time don't show as incoming heals

The client's incoming-heal information only covers heals being cast, not the ticks of heals over
time. Blizzard's own frames have the same limit.

### Where did an option go?

Each settings page lists every option with its place: tab, then section. For example *Name color in
bar texts* is on [[Text|Settings-Text]] > *Display*. The page names match the tabs in `/fuf`, and the
sidebar on the right lists them all.

### How do I get my frames back in place after a mistake?

`/fuf reset <frame>` resets one frame (player, target, targettarget, pet, focus, party),
`/fuf reset all` everything. Export your profile first (**General** > **Profile**) if you want to keep
a copy.

### Where are Blizzard's own frames?

Blizzard's player, target, focus, pet and party frames are hidden while ours are on. To use
Blizzard's frame for one of them, switch ours off on its **Layout** tab (*Enabled*) and `/reload`.

### I found a bug or have an idea

Comments on CurseForge or an issue on GitHub. The more exact the better: which frame, which tab and
setting, what you expected, and other addons involved.
