# Forever Unit Frames — Design

Date: 2026-09-23 · Status: approved design, not yet implemented

## 1. Goal

A polished, flat unit frame addon in the spirit of Shadowed Unit Frames, built
**only for WoW: Forever** (client 1.60.x, Interface `16001`). Intended for public
release on CurseForge once it has been proven in real play.

- Addon folder / TOC: `ForeverUnitFrames`
- Display name: **Forever Unit Frames**
- Slash command: `/fuf`
- SavedVariables: `ForeverUnitFramesDB` (account-wide)
- Language: everything in English — UI, file names, identifiers, comments.
  All user-facing strings go through `Locales/enUS.lua`; further locales can be
  added later without touching code.

### Frames in scope (v1)

Player, Target, Target of Target, Pet, Focus, Party (party1–4, optional player).
Raid frames are out of scope for v1.

Focus: the `focus` unit token, `/focus` and `PLAYER_FOCUS_CHANGED` exist in the
build-69977 UI source; Blizzard ships no FocusFrame for this game type. The Focus
frame is built but must verify `focus` works at runtime and report it in
`/fuf status`.

### Non-goals (v1)

Raid frames, click-casting, heal prediction/absorbs, nameplates, per-character
profiles, a TBC/Classic Era build.

## 2. Platform facts this design relies on

Verified against the `forever` branch of Gethe/wow-ui-source (build
`1.60.1 (69977)`) and against ForeverUI 0.4.15, which runs on this client.

| Fact | Consequence |
|---|---|
| `loadstring_untainted` is nil → secure snippets (`WrapScript`, `_onstate-*`, `initialConfigFunction`, `RunAttribute`) throw | No snippets anywhere. |
| `RegisterUnitWatch`, `RegisterAttributeDriver`, `RegisterStateDriver` are plain Lua in `SecureStateDriver.lua` (Show/Hide via the manager, no snippet) | Usable for single frames and header visibility. |
| `SecureGroupHeaderTemplate` works **without** `initialConfigFunction` (ForeverUI `Layout.lua:494-508`) | Party uses a header; child size/style set in `OnAttributeChanged("unit")` out of combat. |
| `UnitHealth`, `UnitHealthPercent`, `UnitHealthMissing` are `SecretReturns`; `UnitPower*` secret when power restricted; `UnitCastingInfo` secret when spellcast restricted; aura data secret when restricted | Never do Lua arithmetic or comparisons on these values (see §5). |
| `StatusBar:SetMinMaxValues/SetValue`, `FontString:SetText/SetFormattedText` accept secrets | Bars and text are fed raw values. |
| `UnitHealthPercent(unit, usePredicted, curve)` + `C_CurveUtil.CreateCurve/CreateColorCurve` | Percent text and health-gradient colour without maths. |
| `hooksecurefunc` on a frame's Lua mixin method makes it nil for Blizzard code (observed on this client) | Never hook frame mixin methods. Hooking plain tables and `HookScript` is fine. |
| `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE`, Interface `16001` | Detect the game by `WOW_PROJECT_ID`; the TOC lists `16001` first. |
| SavedVariables are written but never read back in the beta | Three storage paths, see §6. |

Before every API use: look it up in the API documentation of the current client
build. Line numbers from error reports are always read against the `forever`
branch of the UI source, never against another game version.

## 3. Architecture

One addon, split into small units with one purpose each.

```
ForeverUnitFrames/
  ForeverUnitFrames.toc
  Locales/enUS.lua          all UI strings
  Core/Init.lua             namespace, event hub, combat queue
  Core/Secrets.lua          secret-safe helpers (never calculate, pass through)
  Core/Config.lua           defaults, inheritance (General -> frame), change notifications
  Core/Codec.lua            compact diff-to-defaults encoding (§6)
  Core/Storage.lua          storage source selection, provider API
  Core/Media.lua            font and texture lists (LibSharedMedia if present)
  Core/Blizzard.lua         hiding default Player/Target/Party/Focus frames
  Core/Movers.lua           drag handles; secure frames are anchored to them
  Units/Units.lua           unit definitions (key, unit token, events, defaults)
  Units/Single.lua          builds single frames (SecureUnitButtonTemplate)
  Units/Party.lua           party header and children
  Elements/Health.lua
  Elements/Power.lua
  Elements/Texts.lua
  Elements/Portrait.lua
  Elements/Auras.lua
  Elements/Castbar.lua
  Options/Window.lua        movable window shell, navigation, tabs
  Options/Widgets.lua       slider+editbox, dropdown, colour, checkbox, anchor picker
  Options/Schema.lua        declarative description of every page
  Options/TestMode.lua      fake data for all frames incl. party
```

Every element implements the same interface:

- `Build(frame)` — create regions once, out of combat
- `Update(frame, event)` — refresh from unit data (combat-safe, secret-safe)
- `Style(frame, cfg)` — apply size, textures, fonts, colours (out of combat for
  secure-affecting changes)

**Data flow.** Events → `Core/Init` dispatch table → frames registered for that
unit → element `Update`. A settings change → `Config` notifies → `Style` on
affected frames; if in combat, the call is queued and flushed on
`PLAYER_REGEN_ENABLED`.

**Secure frames.** `CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")`,
attributes `unit`, `*type1 = "target"`, `*type2 = "togglemenu"`,
`RegisterForClicks("AnyUp")`, `RegisterUnitWatch(frame)`. Created only out of
combat. Frames are anchored to their mover and never moved directly.

**Hiding Blizzard frames.** `UnregisterAllEvents`; protected frames get
`SetAlpha(0)` + `EnableMouse(false)` (+ `Hide` out of combat), no reparenting;
unprotected frames are reparented to a hidden parent. Use `HideBase` where
Edit Mode overrides `Hide`. No hooks on mixin methods.

## 4. Settings

### Inheritance

`General` holds font, texture, background, border and colours. Each frame
inherits them and may override single values. Only non-default values are
stored.

### General

- **Appearance:** font face, font size, font style (None / Outline / Thick
  Outline / Monochrome), font shadow; bar texture; background texture, colour
  and alpha; border (None / 1 px / 2 px) and border colour.
- **Colors:** health colour mode (Class / Reaction / Static / Gradient by
  health), static health colour, power colours per power type, background
  colour.
- **Profile:** export, import, reset all.

### Per frame (Player, Target, Target of Target, Pet, Focus, Party)

- **Layout:** enabled; width; height; **Health %** and **Power %** of the frame
  height (sum ≤ 100, the remainder becomes the gap between the bars; with the
  power bar disabled the health bar fills the frame); portrait
  Off / Left / Right, 2D / 3D; position X / Y (numeric, also set by dragging).
  Party adds orientation (vertical / horizontal), spacing, show player, show
  when solo.
- **Bars:** colour mode override, power bar on/off, texture and background
  overrides.
- **Text:** four slots — health left, health right, power left, power right.
  Each slot picks one tag: None, Name, Name + Level, Level, Current,
  Current / Max, Percent, Deficit. Optional font-size override.
- **Auras:** buffs and debuffs configured separately, each with:
  - enabled, only mine, show remaining time
  - **anchor to:** Frame, Health bar, Power bar, Castbar, or the other aura group
  - **frame anchor point** and **aura anchor point** (one of 9 points each)
  - **X / Y offset**
  - **growth:** primary direction (Right / Left / Up / Down) and row direction
  - size, spacing, per row, max
- **Castbar** (Player, Target, Target of Target, Focus, Party; default off for
  Player): enabled; docked above / below or detached (own mover, position X / Y);
  height; icon;
  cast time; spell name.

## 5. Secret-value handling

Rule: **never calculate, pass through.**

- Health bar: `SetMinMaxValues(0, UnitHealthMax(u))`, `SetValue(UnitHealth(u))`.
- Percent text: `SetFormattedText("%.0f%%", UnitHealthPercent(u, true, curve))`
  with a 0→0, 1→100 curve.
- Gradient colour: colour curve evaluated by `UnitHealthPercent`, applied with
  `SetStatusBarColor(color:GetRGB())`.
- Current / Max text: `SetFormattedText("%s / %s", …)`. Abbreviation ("3.2k")
  only when the value is readable (`issecretvalue` false); otherwise the full
  number.
- Booleans that may be secret (`UnitIsDead`, `UnitIsConnected`, …) are read
  through a `pcall` helper with a default.
- Castbar: raw start/end times to `SetMinMaxValues`; value from `GetTime()`;
  cast-end matched by the castGUID captured from the START event; emptiness
  tested with `type(x) == "nil"`, never by truthiness; text formatting inside
  `pcall`.
- Auras: `C_UnitAuras` APIs wrapped in `pcall`; if duration data is secret the
  icon is shown without remaining time.
- Never print a secret value to chat (ForeverUI 0.4.12: corrupts chat history).

The test stub (§8) enforces this rule.

## 6. Storage

### Paths

1. **SavedVariables** (`ForeverUnitFramesDB`) — the normal path; works for
   everyone once Blizzard fixes the beta bug.
2. **Storage providers** — other addons may register a provider through
   `ForeverUnitFrames.RegisterStorageProvider(name, { load = fn, save = fn })`.
   `load()` returns an encoded string or nil; `save(str)` receives the encoded
   string after every change. The addon ships no provider of its own; the API
   exists so that local workarounds stay outside this repository.
3. **Macro backup** — for users in the beta: one or two character macros
   named `FUF Save 1..n`, 255 characters each minus a header line
   `#Forever Unit Frames backup i/n - keep`. Written only when the encoded string
   changed, never in combat, never while the macro frame is open, respecting
   `MAX_CHARACTER_MACROS`.

On load the first path that yields data wins, in the order above; the source is
reported in `/fuf status` (SavedVariables / provider name / macro backup /
defaults).

### Codec (shared by providers, macro backup and export/import)

- Stores only values that differ from the defaults.
- Every setting has a fixed short code that is never reused.
- Format: `<version>;<entry>;<entry>…`, entry = frame prefix letter + setting
  code + value, e.g. `1;pW220;pH48;tA1;gF3`.
- Numbers as integers (fractions scaled), enums as index, booleans `0/1`,
  colours as 6 or 8 hex digits, media by name index.
- Decoding skips unknown codes; an unknown format version is rejected with a
  message, nothing is applied.
- Expected size 150–400 characters for a heavily customised profile.

Export/import in the Profile tab uses the same string.

## 7. Options window

- Own window (not the Blizzard settings panel): movable, clamped to screen,
  remembers its position, closes with ESC, flat style matching the frames.
- Left: General, Player, Target, Target of Target, Pet, Focus, Party.
  Top: tabs of the selected entry (General: Appearance / Colors / Profile;
  frames: Layout / Bars / Text / Auras / Castbar).
- Every numeric control is a slider with an edit box for exact values.
- **Every position is settable as numeric X / Y** in addition to dragging: each
  frame, the party block as a whole, every detached castbar, and the aura
  offsets. Dragging and the X / Y fields write the same settings.
- Selecting a frame briefly highlights the real frame in the game world.
- Buttons: Unlock (movers, 8 px grid), Test mode, Copy from …, Reset (per frame).
- Test mode shows every frame with sample data, including party without a group.
- In combat the window is locked with the notice "Changes apply after combat".
- Pages are built from `Options/Schema.lua`; widgets never hard-code settings.

## 8. Errors and diagnostics

- A missing API disables only the affected element; it reports once in chat
  and in `/fuf status`; everything else keeps working.
- `/fuf status`: build, interface number, project ID, storage source, disabled
  elements, focus availability.
- No `print` of secret values; diagnostic output goes through a helper that
  checks `issecretvalue`.

## 9. Testing

- Offline with `lua5.1` against a WoW API stub.
- The stub models **secret values** as proxy objects that throw on arithmetic,
  comparison, concatenation and `tostring` — any forbidden calculation fails in
  the test, not in combat.
- Covered: codec round-trip, size budget, unknown codes and versions;
  inheritance; schema completeness (every setting has a widget, code and
  locale string); combat queue; element updates with secret inputs; storage
  source selection.
- Then in-game testing; re-check on every new build, especially
  the release build in November.

## 10. Release preparation

Repository `StephanRosin/forever-unit-frames`, `README.md` (CurseForge
description), `CHANGELOG.md`, `LICENSE`, `.pkgmeta` for the packager,
an install script that copies the addon into a given AddOns folder. The name is confirmed free
only when the CurseForge project is created.
