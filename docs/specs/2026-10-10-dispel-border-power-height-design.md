# Raid cells: debuff-coloured border and power strip height — Design

Date: 2026-10-10 · Status: decided (maintainer forwarded two CurseForge suggestions: "a border in the debuff's colour,
easier to see than the tint" and "adjust the power bar height").

## 1. Debuff-coloured border

- New per-size settings: `dispelBorder` (bool, default false) and `dispelBorderSize` (int 1–6 px, default 2). Rows in
  the Debuffs tab next to "Tint the cell by debuff colour"; the size greyed while the border is off; `dispelFilter`
  applies when the icon, the tint or the border is on (Raid/Options/Dependencies.lua).
- Mechanics as the tint (Raid/CellAuras.lua initTint): a slot of the same filter in the cell's aura container whose
  button carries the border's textures, each added with `AddDispelTypeTexture` (the client keeps a list of them,
  Blizzard_CustomAuraButton.lua) with the dispel colour curve at full alpha. Nothing reads the dispel type; works in
  combat. Built and resized only out of combat, as every container slot.
- Shape: four edge textures inside the cell (pixel-snapped, on top of the health and power bars, under the icons).
  With rounded cells (`cellCornerRadius` > 0) the border must follow the rounding — use the cell's existing ring code
  (Core/Border.lua) if its textures can be dispel-coloured, else edges clipped by the cell's mask; respect the
  three-masks-per-texture limit (tests/test_mask_limit.lua).
- Tint and border combine. Test mode shows the border on the sample members with a dispellable debuff.

## 2. Power strip height

- New per-size setting `powerStripHeight` (percent of the cell's height, 5–40, default 10 = today's fixed
  `powerPercent`). Replaces the fixed value in Raid/Cell.lua FIXED; the health bar takes the rest. Row in the cell
  look tab next to the power strip rule, greyed while the strip is OFF. Layout class (copying between sizes follows
  the existing rules for layout settings).

## 3. Common

Default look unchanged (default-look snapshot). Four languages, wiki, news line for 0.28.0 (not announced). Templates
unchanged unless a template sets the power strip.
