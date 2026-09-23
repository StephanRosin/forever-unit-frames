# Forever Unit Frames — Plan 3b: Frame details

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the look of the unit frames: a font "apply to all" action, an optional title row (three-row layout), rounded corners, a real outer border around frame, portrait and docked castbar, absorb shields, incoming heals with an optional overheal lane, an elite / rare / boss marker, and combat feedback numbers — each configurable, previewed in test mode, and safe with secret values.

**Architecture:** Everything is built from the existing element pattern (`Build` / `Style` / `Update`, plus an optional `Preview` that test mode calls through the new `ns.Single.Preview`). Rounded corners are four CLAMP-wrapped mask textures per block, anchored in the block's corners; each element lists the textures it wants rounded (`ns.Corners.Add`) and a last element (`Elements/Shape.lua`) applies masks and draws the outer border (`Core/Border.lua`) around a plain "unit box" frame that takes a docked castbar in while it shows. Shields and heals are status bars fed the raw (possibly secret) values; the client does all measuring, clipping happens with `SetClipsChildren`. A new overlay frame keeps texts and markers above bars, overlays and 3D portraits.

**Tech Stack:** Lua 5.1, WoW: Forever API (Interface 16001, build 1.60.1.69977), offline tests with `lua5.1` + `tests/mock.lua` (`tests/run`), Python 3 standard library for one offline texture generator.

Plan order: 1 Foundation (done) → 2 Options window (done) → 3 Remaining frames, portrait, castbar (done) → **3b Frame details (this plan)** → 4 Auras → 5 Release.

Base: branch `plan-3-frames` at `a242ec8` ("Set the font on soft-outline copies before writing text"). Every task below was replayed in order on a scratch copy of that commit; the test totals in "Expected" are what `tests/run` printed there.

## Global Constraints

- Everything in English: UI strings, file names, identifiers, comments. All user-facing strings through `ns.L` (`Locales/enUS.lua`).
- Target client: WoW: Forever, `## Interface: 16001`, build 1.60.1.69977. Client API facts only from the `forever` branch of the UI source (`git show` / `git grep` on its `FETCH_HEAD`); the facts this plan relies on are listed below with their files. Anything not verifiable there is listed at the end under "Not verifiable offline".
- Never do arithmetic, comparisons, concatenation or `tostring` on values that may be secret (health, absorbs, incoming heals, combat amounts and event kinds, classification if it ever becomes secret). Pass them through to widgets (`SetValue`, `SetMinMaxValues`, `SetText`, `SetFormattedText`). Test presence with `type(x) == "nil"`, never by truth. Readable numbers only via `ns.Secrets.Number`, booleans via `ns.Secrets.Bool`, strings via `ns.Secrets.IsSecret` + `type(x) == "string"`.
- The mock's secret proxy stays strict: no test may loosen `secretMeta` in `tests/mock.lua`.
- Never `hooksecurefunc` a frame's Lua mixin method. `HookScript` on our own frames and hooks on plain tables are allowed.
- No secure snippets (`initialConfigFunction`, `WrapScript`, `_onstate-*`, `RunAttribute`).
- Secure frames (unit buttons, party header and buttons, pretend party buttons) are sized, anchored, shown, hidden and given attributes only out of combat, through `ns.AfterCombat`. Plain child frames and regions (overlay, unit box, masks, shield / heal bars, feedback text) may change in combat.
- A font string gets a font before its first `SetText` / `SetFormattedText` (the mock asserts it).
- Setting codes are permanent and unique; existing codes never change and enum value orders never change (values may only be appended). This plan adds exactly: `TP NT NC` (title row), `CR` (corner radius), `BP` (border padding), `AB AC` (absorbs), `IH OV MC OC` (incoming heals), `EM` (elite marker), `CF` (combat feedback). Existing codes: `FF FS FO FH BT BC BS BO HM HC E W H HP PP PE X Y PM PS OR GS SP SO CE CP CD CX CY CH CI CN CT TL TR UL UR`. `borderSize` (`BS`) only gets a larger maximum (2 → 8).
- Public repository: no local paths, host names, character names or anything about the author's machine in files or commit messages.
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp`
- Do not push. Every task ends with `tests/run` green and one commit.

## Client facts this plan relies on (build 69977, `forever` branch)

Paths are below `Interface/AddOns/`; `Doc/` stands for `Blizzard_APIDocumentationGenerated/`.

| Fact | Source |
|---|---|
| `Frame:CreateMaskTexture(name, drawLayer, templateName, subLevel)` → `SimpleMaskTexture` | `Doc/SimpleFrameAPIDocumentation.lua:113` |
| `Texture:AddMaskTexture(mask)`, `RemoveMaskTexture(mask)`, `GetNumMaskTextures()` | `Doc/SimpleTextureAPIDocumentation.lua:10, 37, 51` |
| `SimpleMaskTextureAPI` has no functions of its own; `SetTexture(asset, wrapH, wrapV, filter)`, `SetTexCoord`, `SetAtlas` are TextureBase methods (Blizzard calls `SetAtlas` / `SetTexCoord` on masks) | `Doc/SimpleMaskTextureAPIDocumentation.lua`, `Doc/SimpleTextureBaseAPIDocumentation.lua:366, 576, 600`; `Blizzard_UnitFrame/Mainline/UnitPowerBarAlt.lua:734`, `Blizzard_FrameXML/RewardTrackTemplates.lua:439` |
| Wrap modes `CLAMP`, `REPEAT`, `CLAMPTOBLACK`, `CLAMPTOBLACKADDITIVE`, `CLAMPTOWHITE`, `MIRROR`; a `MaskTexture` with `hWrapMode="CLAMP"` exists in Blizzard XML | `Blizzard_SharedXML/UI.xsd:178-187`; `Blizzard_UIPanels_Game/Mainline/WorldMapFrameTemplates.xml:126` |
| A mask on a frame masks textures of child frames, including status bar fills (`PetFrameHealthBarMask` on the health bar masks the fill and the heal prediction / absorb bars' textures) | `Blizzard_UnitFrame/Mainline/PetFrame.xml:90-123`, `PetFrame.lua:27-36` |
| `SetTextureSliceMargins` / `SetTextureSliceMode` exist on TextureBase; the XSD allows `TextureSliceMargins` inside `MaskTexture`, but no Blizzard code slices a mask — **not used** (see Design decisions) | `Doc/SimpleTextureBaseAPIDocumentation.lua:618, 632`; `UI.xsd:677, 716-741` |
| `Frame:SetClipsChildren`, `SetFrameLevel`, `GetFrameLevel` | `Doc/SimpleFrameAPIDocumentation.lua:1217, 1280, 421` |
| `StatusBar:SetMinMaxValues` / `SetValue` accept secrets (`AllowedWhenTainted`); `GetStatusBarTexture`, `SetStatusBarTexture`, `SetReverseFill` | `Doc/SimpleStatusBarAPIDocumentation.lua:229, 355, 136, 318, 262` |
| `FontString:SetText` / `SetFormattedText` accept secrets (`AllowedWhenTainted`) | `Doc/SimpleFontStringAPIDocumentation.lua:539, 664` |
| `UnitGetTotalAbsorbs(unit)` → number, `SecretReturns`; `UnitGetIncomingHeals(unit[, healerUnit])` → number, **nilable**, `SecretReturns` | `Doc/UnitDocumentation.lua:1286, 1269` |
| `UNIT_ABSORB_AMOUNT_CHANGED(unitTarget)`, `UNIT_HEAL_PREDICTION(unitTarget)`, `UNIT_MAXHEALTH(unitTarget)` | `Doc/UnitDocumentation.lua:4075, 4292, 4380` |
| A heal prediction calculator exists (`CreateUnitHealPredictionCalculator`, `UnitGetDetailedHealPrediction(unit, healer, calculator)`, clamp modes, `GetIncomingHeals()` → amount, amountFromHealer, amountFromOthers, clamped) — **not used**: no Blizzard code in this build calls it, and the plain API plus clipping needs no clamping | `Doc/UnitDocumentation.lua:72, 1257`; `Doc/UnitHealPredictionCalculatorAPIDocumentation.lua`, `…SharedDocumentation.lua` |
| `UnitClassification(unit)` → cstring, **no secret flags** in the docs; values Blizzard tests: `worldboss`, `elite`, `rareelite`, `rare`, `minus` (plus `normal`, `trivial`); `UnitIsBossMob(unit)` → bool; `UNIT_CLASSIFICATION_CHANGED(unitTarget)` | `Doc/UnitDocumentation.lua:966, 1824, 4143`; `Blizzard_UnitFrame/Mainline/TargetFrame.lua:380-462`, `TargetFrameUtils.lua:1-19` |
| Atlases `nameplates-icon-elite-gold` (elite / world boss), `nameplates-icon-elite-silver` (rare elite), `UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star` (rare) are used by Blizzard code in this build | `Blizzard_NamePlates/Blizzard_NamePlateClassificationFrame.lua:121-125`; `Blizzard_DamageMeter/DamageMeterEntry.lua:74-78` |
| `Texture:SetAtlas(atlas, useAtlasSize=false, …)` | `Doc/SimpleTextureBaseAPIDocumentation.lua:366` |
| `UNIT_COMBAT(unitTarget, event, flagText, amount, schoolMask)`; Blizzard's `CombatFeedback_OnCombatEvent`: `WOUND` with `amount ~= 0` shows the number (bigger for `CRITICAL` / `CRUSHING`), a zero `WOUND` shows `ABSORB` / `BLOCK` / `RESIST` or `MISS`, `HEAL` green, words for `IMMUNE`, `BLOCK`, `DODGE`, `PARRY`, `MISS`, `RESIST`, `EVADE`, `DEFLECT`, `ABSORB`, `REFLECT`, `INTERRUPT`; fade 0.2 s in, 0.7 s hold, 0.3 s out; the player frame forwards `UNIT_COMBAT` for its unit | `Doc/UnitDocumentation.lua:4153`; `Blizzard_FrameXML/Mainline/CombatFeedback.lua:1-119`; `Blizzard_UnitFrame/Mainline/PlayerFrame.lua:73, 120-123` |
| `CreateAnimationGroup`; `AnimationGroup:CreateAnimation("Alpha")`, `Play`, `Stop`, `SetToFinalAlpha`; `Alpha:SetFromAlpha`, `SetToAlpha`; `Animation:SetDuration`, `SetOrder`; `OnFinished` script on groups; Blizzard uses `CreateAnimation("Alpha")` and `SetScript("OnFinished", …)` from Lua | `Doc/SimpleAnimatableObjectAPIDocumentation.lua:10`, `Doc/SimpleAnimGroupAPIDocumentation.lua:10, 276, 349, 359`, `Doc/SimpleAnimAlphaAPIDocumentation.lua:38, 49`, `Doc/SimpleAnimAPIDocumentation.lua:308, 330`; `UI.xsd:1534, 1646`; `Blizzard_HelpPlate/Blizzard_HelpPlate.lua:60`, `Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.lua:144` |

## Design decisions

- **Title row.** A texture in the unit frame's BACKGROUND layer, spanning the bars' width (between portrait insets), with the bars' background colour and texture. Its text is a new slot `title` of `Elements/Texts.lua` (values of kind `health` if a value tag is chosen). Row split: `Layout.Rows` (whole units) → title, power and gap snapped to the pixel grid, health takes the rest. The gap stays between health and power.
- **Changed defaults (look changes for profiles without overrides).** Health colour `CLASS` → `STATIC` (green, `healthColor` default unchanged). Player / target / focus: title 30 %, health 45 %, power 25 %; title text `NAME_LEVEL` (focus `NAME`), health left `CURRENT_MAX` (focus `NONE`), health right `PERCENT`. Party, target of target, pet: title 0 %, health 75 %, texts as before. Frame heights are unchanged.
- **Rounded corners without nine-slice.** A mask per corner, `radius × radius`, CLAMP-wrapped: the mask file's right column and bottom row are opaque, so beyond the mask everything passes and each mask only cuts its own corner; four masks on a texture give a rounded rectangle of any aspect ratio. This avoids the unverified nine-slice masks (`SetTextureSliceMargins` on a mask) and stretched single masks. Blocks: the whole frame (title, health, power, portrait background, 2D portrait, shields, heals, lane) and each castbar (bar and icon). A 3D portrait (`PlayerModel`) cannot be masked and stays square.
- **Outer border.** One ring per unit around a plain "unit box" frame: the frame, plus a docked castbar while it is shown (castbar `OnShow` / `OnHide` refit the box; allowed in combat, the box is not protected). Ring = 4 edges + 4 corner squares; with a radius each corner square is masked by the outer arc (`Corner.tga`, radius `r + padding + size`) and the inner arc (`CornerInverse.tga`, radius `r + padding`), concentric with the frame's own corners. With radius 0 the ring is square even when padded. A docked castbar loses its own border; a detached one gets its own ring. The frame-to-castbar gap keeps its formula (`2 × size + 2 px`), so the default look and all existing gap numbers stay; `DockedDepth` counts `Border.Extent` (= padding + size), which equals the old value for padding 0. Party spacing still counts from frame edge to frame edge: with thick or padded borders, raise the spacing.
- **Mask texture.** 64 × 64, white, alpha = anti-aliased (4×4 supersampled) quarter disc; `CornerInverse.tga` uses radius 63 so its left column and top row are fully opaque (needed for CLAMP on the inner arc). Generated by `tools/make_corners.py`, deterministic, committed as binary; `install` copies `Media/*.tga` (it otherwise only copies TOC-listed files).
- **Absorbs** are an overlay: a reverse-filled status bar over the whole health bar, `0 .. UnitHealthMax`, value `UnitGetTotalAbsorbs`. It shows total shields from the bar's right end (over missing health first, over the fill when the shield is larger than what is missing); the status bar clamps at the bar's end, no Lua maths.
- **Incoming heals** are two status bars anchored to the health fill texture's right edge, each as wide as the health bar and scaled `0 .. UnitHealthMax`, stacked from the same origin (all heals under yours) — no subtraction. A clip frame (`SetClipsChildren`) over the health bar cuts them at full health; with the overheal lane on, the health bar gives the last 8 % (min 4) of its row to a lane with the background colour and the clip reaches into it, so the part of a heal that would overheal shows there.
- **Overlay.** `frame.overlay` (level frame + 10) carries title and health texts, the elite marker and combat feedback, so they draw above shield / heal bars and a 3D portrait. Power texts stay on the power bar (they must hide with it).
- **Elite marker.** Portrait on → badge (≈ 45 % of the frame height) on the portrait's outer top corner, sticking out by a third; portrait off → a word just above the frame's top right corner, clear of the border. Boss = `UnitIsBossMob` or `worldboss`. A secret or unknown classification shows nothing.
- **Combat feedback.** Numbers `floor(fontSize × 1.5)`, criticals × 1.5 again, over the portrait if shown else mid health bar. The amount is `SetFormattedText("%s", Secrets.Abbreviate(amount))` — abbreviated when readable, passed through when secret. A secret event kind shows nothing (its colour cannot be chosen). A secret zero `WOUND` shows as a number (it cannot be told from a hit).
- **Test mode.** `ns.Single.Preview(frame, on)` replaces the direct `ns.Castbar.Preview` calls; samples: shield 30 %, heals 25 % (12 % yours), marker "rare elite", feedback "1234" (still, no fade). Real events are ignored while a sample shows.

## File structure after this plan

```
Core/Corners.lua              corner masks: radius, clipper, fit                    (new)
Core/Border.lua               outer border ring: size, padding, extent, draw       (new)
Elements/HealPrediction.lua   incoming heals, overheal lane                         (new)
Elements/Absorb.lua           absorb shield overlay                                 (new)
Elements/Classification.lua   elite / rare / boss marker                            (new)
Elements/CombatFeedback.lua   damage / heal numbers                                 (new)
Elements/Shape.lua            frame block corners, unit box, frame border (last)    (new)
Media/Corner.tga              corner mask                                           (new, generated)
Media/CornerInverse.tga       inverted corner mask                                  (new, generated)
tools/make_corners.py         writes the two masks (standard library only)          (new)
Core/Settings.lua             + FONT_KEYS, title row, corner, border, shield, heal, marker, feedback settings; new defaults
Core/Config.lua               + ClearFrameOverrides
Core/Layout.lua               + Rows (three rows), OverhealLane
Elements/Health.lua           + title texture, overlay frame, Unit/Class/ReactionColor, corner targets
Elements/Texts.lua            + title slot, texts on the overlay
Elements/Power.lua            + corner targets
Elements/Portrait.lua         + corner targets
Elements/Castbar.lua          + box, clipper, Height; own ring only when detached
Units/Single.lua              + title row / lane layout, Preview; DrawBorder removed
Units/Party.lua               Preview through Single.Preview
Options/Schema.lua            + section actions, new sections
Options/Window.lua            + action blocks, highlight outside the border
Options/TestMode.lua          Preview through Single.Preview
Locales/enUS.lua              all new strings
install                       + copies Media/*.tga
.gitignore                    + __pycache__/
tests/mock.lua                + masks, tex coords, atlases, frame levels, clipping, animations, absorb / heal / classification APIs
```

TOC after this plan (new lines marked `+`):

```
Locales\enUS.lua
Core\Init.lua
Core\Secrets.lua
Core\Settings.lua
Core\Config.lua
Core\Codec.lua
Core\MacroBackup.lua
Core\Storage.lua
Core\Media.lua
Core\Layout.lua
+Core\Corners.lua
+Core\Border.lua
Units\Units.lua
Elements\Health.lua
+Elements\HealPrediction.lua
+Elements\Absorb.lua
Elements\Power.lua
Elements\Texts.lua
Elements\Portrait.lua
Elements\Castbar.lua
+Elements\Classification.lua
+Elements\CombatFeedback.lua
+Elements\Shape.lua
Units\Events.lua
Units\Single.lua
Units\Party.lua
Units\Party.xml
Core\Blizzard.lua
Core\Movers.lua
Core\Commands.lua
Options\Style.lua
Options\Widgets.lua
Options\Schema.lua
Options\TestMode.lua
Options\Window.lua
Core\Boot.lua
```

`Elements/Shape.lua` must stay the last element file: it collects the corner targets every other element listed while building.

How to apply the code below: new files are given in full. Changes to existing files are unified diffs against the state the previous task left; apply them with `git apply` (save the block to a file first) or edit by hand — the `+` lines are the exact code. Test totals in "Expected" are what `tests/run` printed after the task during the replay.

---

### Task 1: Apply the global font to all frames

General → Appearance gets a two-click button "Apply to all frames" under the font rows. It removes `fontFace`, `fontSize`, `fontOutline` and `fontShadow` overrides from every frame scope, so all frames inherit the General font again.

**Files:**
- Modify: `Core/Config.lua`
- Modify: `Core/Settings.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Options/Schema.lua`
- Modify: `Options/Window.lua`
- Test (new): `tests/test_font_apply.lua`

**Interfaces:**
- Consumes: `ns.Config` (profile with one table per scope), `confirmButton(parent, text, action)` in `Options/Window.lua` (two-click, 3 s timeout, `button.Disarm()`), `newBlock(page)`.
- Produces:
  - `ns.Settings.FONT_KEYS` = `{ "fontFace", "fontSize", "fontOutline", "fontShadow" }`.
  - `ns.Config.ClearFrameOverrides(keys)` — clears `keys` in every scope except `general`; fires `CONFIG_CHANGED(nil, nil)` once.
  - Schema sections may carry `action = "<id>"`; `Options/Window.lua` renders a two-click button block after the section's rows (`L["ACTION_<id>"]`, hint `L["ACTION_HINT_<id>"]`). `ns.Options.actionButtons[id]` holds the button; closing the window disarms it; it locks in combat like every row.

- [ ] **Step 1: Write the failing test**

**New file `tests/test_font_apply.lua`:**

```lua
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, O, L, S = ns.Config, ns.Options, ns.L, ns.Settings

H.check("font keys", table.concat(S.FONT_KEYS, ","), "fontFace,fontSize,fontOutline,fontShadow")

local function overrideFonts()
    C.Set("general", "fontSize", 14)
    C.Set("player", "fontSize", 20)
    C.Set("target", "fontFace", "Morpheus")
    C.Set("party", "fontOutline", "OUTLINE")
    C.Set("focus", "fontShadow", true)
    C.Set("player", "width", 250)
end

-- Config: every frame's font overrides go, nothing else does.
overrideFonts()
local changes = 0
ns.Listen("CONFIG_CHANGED", function() changes = changes + 1 end)
C.ClearFrameOverrides(S.FONT_KEYS)
H.check("one change event", changes, 1)
for _, scope in ipairs({ "player", "target", "targettarget", "pet", "focus", "party" }) do
    for _, key in ipairs(S.FONT_KEYS) do
        H.check(scope .. " " .. key .. " inherits", C.IsOverridden(scope, key), false)
    end
end
H.check("player now uses the general size", C.Get("player", "fontSize"), 14)
H.check("general keeps its own value", C.Get("general", "fontSize"), 14)
H.check("other overrides stay", C.Get("player", "width"), 250)
H.check("frames restyled", ns.Frames.player.texts.healthLeft._font[2], 14)

-- Options: General -> Appearance has the button under the font rows.
overrideFonts()
O.Open("general")
O.SelectTab("appearance")
local button = O.actionButtons.applyFontToFrames
H.checkTrue("button exists", button)
H.check("button text", button.text:GetText(), L.ACTION_applyFontToFrames)
local shadowRow
for i, row in ipairs(O.rows) do
    if row.key == "fontShadow" then shadowRow = i end
end
H.check("block right after the last font row", O.rows[shadowRow + 1], button:GetParent())
local click = button:GetScript("OnClick")
click(button)
H.check("first click only arms", C.IsOverridden("player", "fontSize"), true)
H.check("asks to confirm", button.text:GetText(), L.CONFIRM)
click(button)
H.check("second click applies", C.IsOverridden("player", "fontSize"), false)
H.check("target font inherits", C.Get("target", "fontFace"), C.Get("general", "fontFace"))
H.check("label back", button.text:GetText(), L.ACTION_applyFontToFrames)

-- The confirmation expires; closing the window disarms it.
click(button)
M.RunTimers()
H.check("expired", button.text:GetText(), L.ACTION_applyFontToFrames)
click(button)
O.Close()
H.check("closing disarms", button.text:GetText(), L.ACTION_applyFontToFrames)

-- Locked in combat like every other control.
O.Open("general")
O.SelectTab("appearance")
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("locked in combat", button:IsEnabled(), false)
M.FireEvent("PLAYER_REGEN_ENABLED")
H.checkTrue("unlocked after combat", button:IsEnabled())

-- Only on General: frame pages have no such button.
O.Select("player")
O.SelectTab("text")
local found = false
for _, row in ipairs(O.rows) do if row == button:GetParent() then found = true end end
H.check("not on frame pages", found, false)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`

Expected: FAIL — the new test cannot find `ns.Settings.FONT_KEYS`. The output ends with:

```
  ERROR test_font_apply.lua:7: bad argument #1 to 'concat' (table expected, got nil)
2429 passed, 1 failed
```

- [ ] **Step 3: Implement**

Changes to existing files (unified diffs against the previous task's state; `git apply` them or edit by hand):

```diff
diff --git a/Core/Config.lua b/Core/Config.lua
index cec9f0d..10b85b5 100644
--- a/Core/Config.lua
+++ b/Core/Config.lua
@@ -82,6 +82,18 @@ function Config.ClearOverride(scope, key)
     ns.Fire("CONFIG_CHANGED", scope, key)
 end
 
+-- Removes the given keys from every frame scope, so each frame falls back
+-- to General again. General itself keeps its values. One CONFIG_CHANGED
+-- for everything.
+function Config.ClearFrameOverrides(keys)
+    for _, scope in ipairs(Settings.SCOPES) do
+        if scope ~= "general" then
+            for _, key in ipairs(keys) do profile[scope][key] = nil end
+        end
+    end
+    ns.Fire("CONFIG_CHANGED", nil, nil)
+end
+
 -- Copying reproduces the source frame's look as it is shown, including the
 -- per-frame defaults it does not override. Position and whether the frame
 -- is shown at all stay with the target: copying must not stack two frames
```

```diff
diff --git a/Core/Settings.lua b/Core/Settings.lua
index 17d07e7..42840e0 100644
--- a/Core/Settings.lua
+++ b/Core/Settings.lua
@@ -86,6 +86,8 @@ local TEXT_TAGS = { "NONE", "NAME", "NAME_LEVEL", "LEVEL", "CURRENT", "CURRENT_M
 Settings.TEXT_TAGS = TEXT_TAGS
 
 -- General appearance (inherited by every frame, overridable per frame)
+-- The font settings, in the order the options page lists them.
+Settings.FONT_KEYS = { "fontFace", "fontSize", "fontOutline", "fontShadow" }
 Settings.Define({ key = "fontFace", code = "FF", scope = "inherit", type = "media", mediaKind = "font", default = "Friz Quadrata" })
 Settings.Define({ key = "fontSize", code = "FS", scope = "inherit", type = "int", min = 6, max = 32, default = 12 })
 Settings.Define({ key = "fontOutline", code = "FO", scope = "inherit", type = "enum",
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index 65655cd..f7120d4 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -131,6 +131,8 @@ L.CONFIRM = "Click again to confirm"
 L.COMBAT_LOCKED = "In combat — changes are possible again after the fight."
 L.EXPORT = "Export"; L.IMPORT = "Import"; L.RESET = "Reset"
 L.RESET_ALL = "Reset all settings"
+L.ACTION_applyFontToFrames = "Apply to all frames"
+L.ACTION_HINT_applyFontToFrames = "Removes every frame's own font settings"
 L.EXPORT_HINT = "Copy this text to share or back up your profile."
 L.IMPORT_DONE = "Profile imported."
 L.IMPORT_CODEC_EMPTY = "Nothing to import."
```

```diff
diff --git a/Options/Schema.lua b/Options/Schema.lua
index fb4dd65..b180f05 100644
--- a/Options/Schema.lua
+++ b/Options/Schema.lua
@@ -4,7 +4,8 @@ ns.Schema = Schema
 
 Schema.GENERAL = {
     { id = "appearance", sections = {
-        { id = "font", keys = { "fontFace", "fontSize", "fontOutline", "fontShadow" } },
+        -- action: a two-click button under the rows (Options/Window.lua).
+        { id = "font", keys = { "fontFace", "fontSize", "fontOutline", "fontShadow" }, action = "applyFontToFrames" },
         { id = "bars", keys = { "barTexture", "backgroundColor" } },
         { id = "border", keys = { "borderSize", "borderColor" } },
     } },
```

```diff
diff --git a/Options/Window.lua b/Options/Window.lua
index 2bae6f2..9f46583 100644
--- a/Options/Window.lua
+++ b/Options/Window.lua
@@ -225,6 +225,9 @@ local function sectionHeader(page, id)
     return header
 end
 
+-- Defined with the other blocks below; a section's action button.
+local actionBlock
+
 local function buildSettingsPage(page, scope, tab)
     local stack = newStack(page)
     for _, section in ipairs(tab.sections) do
@@ -235,6 +238,7 @@ local function buildSettingsPage(page, scope, tab)
         if #keys > 0 then
             stack.add(sectionHeader(page, section.id))
             for _, key in ipairs(keys) do stack.add(settingRow(page, scope, key)) end
+            if section.action then stack.add(actionBlock(page, section.action)) end
         end
     end
     stack.finish()
@@ -278,6 +282,26 @@ local function confirmButton(parent, text, action)
     return button
 end
 
+-- Section actions: what the button does. Two clicks, like Reset.
+local ACTIONS = {
+    applyFontToFrames = function() Config.ClearFrameOverrides(ns.Settings.FONT_KEYS) end,
+}
+-- The buttons by action id, for the tests and for disarming on close.
+Options.actionButtons = {}
+
+function actionBlock(page, id)
+    local block = newBlock(page)
+    local button = confirmButton(block, L["ACTION_" .. id], ACTIONS[id])
+    button:SetPoint("TOPLEFT", block, "TOPLEFT", INSET, -6)
+    local hint = Style.Text(block, 10, "muted")
+    hint:SetPoint("LEFT", button, "RIGHT", FOOTER_GAP, 0)
+    hint:SetText(L["ACTION_HINT_" .. id])
+    Options.actionButtons[id] = button
+    function block:SetEnabled(on) button:SetEnabled(on) end
+    block:SetHeight(BUTTON_H + 12)
+    return block
+end
+
 local function exportBlock(page)
     local block = newBlock(page)
     local hint = Style.Text(block, 11, "muted")
@@ -702,6 +726,7 @@ local function createWindow()
         Widgets.CloseList()
         Options.resetFrameButton.Disarm()
         if Options.resetAllButton then Options.resetAllButton.Disarm() end
+        for _, button in pairs(Options.actionButtons) do button.Disarm() end
     end)
     frame:Hide()
     table.insert(UISpecialFrames, WINDOW_NAME)
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `tests/run`
Expected: `2472 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Config.lua Core/Settings.lua Locales/enUS.lua Options/Schema.lua Options/Window.lua tests/test_font_apply.lua
git commit -F - <<'EOF'
Options: apply the global font to every frame

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 2: Title row (three-row layout), static green health by default

A unit frame gets an optional title row above the health bar: its own background, one text (tag, default `NAME_LEVEL`) coloured by class for players and by reaction for NPCs (option Class / Reaction / White). Row heights are shares of the frame height: new `titlePercent` (0 = old two-row layout), `healthPercent`, `powerPercent`; the rest is the gap between health and power. New defaults: health colour `STATIC` (green); player / target / focus 30 / 45 / 25 with the name in the title row and values on the health bar; party, target of target and pet keep two rows.

**Files:**
- Modify: `Core/Layout.lua`
- Modify: `Core/Settings.lua`
- Modify: `Elements/Health.lua`
- Modify: `Elements/Texts.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Options/Schema.lua`
- Modify: `Units/Single.lua`
- Test (new): `tests/test_title_row.lua`
- Test (modify): `tests/test_config.lua`
- Test (modify): `tests/test_config_extras.lua`
- Test (modify): `tests/test_health.lua`
- Test (modify): `tests/test_pixel.lua`
- Test (modify): `tests/test_power_texts.lua`
- Test (modify): `tests/test_soft_outline.lua`

**Interfaces:**
- Consumes: `ns.Layout.Bars`, `ns.Pixel.Snap`, `Texts.Apply(fs, tag, unit, kind)`, `Health.ColorFor(frame)`.
- Produces:
  - `ns.Layout.Rows(height, titlePercent, healthPercent, powerPercent, powerEnabled)` → `titleH, healthH, gap, powerH` (whole units; the title gives way first, health keeps at least 1). `ns.Layout.Bars(...)` stays and returns `healthH, gap, powerH` of a title-less split.
  - `frame.title` — the title row's background texture (BACKGROUND layer of the unit frame); `frame.titleHeight` — its snapped height, 0 when off. The health bar hangs below it.
  - `frame.texts.title` — the title text (slot `title`, values of kind `health`).
  - `ns.Health.ReactionColor(unit)` → `{ r, g, b }`; `ns.Health.ClassColor(unit)` → `r, g, b` or nothing; `ns.Health.UnitColor(unit, mode)` → `r, g, b` (mode `CLASS`: class for players, else reaction; any other mode: reaction).
  - Settings `titlePercent` (`TP`), `titleText` (`NT`), `titleColorMode` (`NC`: `CLASS`, `REACTION`, `WHITE`).

- [ ] **Step 1: Write the failing test**

Changes to existing test files (mock support and expectations that change with this task):

```diff
diff --git a/tests/test_config.lua b/tests/test_config.lua
index aa08658..25f96df 100644
--- a/tests/test_config.lua
+++ b/tests/test_config.lua
@@ -36,5 +36,5 @@ C.Set("player", "width", 300)
 C.ResetScope("player")
 H.check("reset scope", C.Get("player", "width"), 220)
 C.ResetAll()
-H.check("reset all", C.Get("target", "healthColorMode"), "CLASS")
+H.check("reset all", C.Get("target", "healthColorMode"), "STATIC")
 H.check("last event is reset all", changes[#changes], "*.*")
```

```diff
diff --git a/tests/test_config_extras.lua b/tests/test_config_extras.lua
index 09633f0..1b65ee7 100644
--- a/tests/test_config_extras.lua
+++ b/tests/test_config_extras.lua
@@ -23,7 +23,7 @@ H.check("target's own override replaced", C.Get("target", "height"), 46)
 C.Import({ general = {}, player = { enabled = false }, target = { y = 12 } })
 H.check("setup: player has no text overrides", C.IsOverridden("player", "textHealthRight"), false)
 C.CopyScope("player", "target")
-H.check("copy: player's default health text", C.Get("target", "textHealthRight"), "CURRENT_MAX")
+H.check("copy: player's default castbar switch", C.Get("target", "castbarEnabled"), false)
 H.check("copy: player's default power text", C.Get("target", "textPowerRight"), "CURRENT")
 H.check("copy: same default stays no override", C.IsOverridden("target", "width"), false)
 H.check("copy: enabled not copied", C.Get("target", "enabled"), true)
```

```diff
diff --git a/tests/test_health.lua b/tests/test_health.lua
index 78d7dfe..c09e41e 100644
--- a/tests/test_health.lua
+++ b/tests/test_health.lua
@@ -11,10 +11,13 @@ H.check("right click menu", f:GetAttribute("*type2"), "togglemenu")
 H.checkTrue("unit watch", f._unitWatch)
 H.check("width from config", f:GetWidth(), 220)
 
--- Health bar height follows the layout maths (power bar arrives in Task 9).
-local hh = ns.Layout.Bars(46, 75, 25, true)
+-- Health bar height follows the layout maths: title, health, gap, power.
+local _, hh = ns.Layout.Rows(46, 30, 45, 25, true)
 H.check("health height", f.health:GetHeight(), hh)
 
+-- Class colours are a choice (the default is a static green).
+ns.Config.Set("player", "healthColorMode", "CLASS")
+
 -- Secret health values pass straight through to the bar.
 local hp, hpMax = M.Secret(900), M.Secret(1000)
 M.units.player = { name = "Tester", level = 60, class = "WARLOCK", className = "Warlock",
```

```diff
diff --git a/tests/test_pixel.lua b/tests/test_pixel.lua
index 97d014b..0993bb5 100644
--- a/tests/test_pixel.lua
+++ b/tests/test_pixel.lua
@@ -51,8 +51,10 @@ H.checkTrue("mover near its setting", math.abs(p[4] - -251) < px)
 checkGrid("health height", f.health:GetHeight())
 checkGrid("power height", f.power:GetHeight())
 checkGrid("health left inset", pointOf(f.health, "TOPLEFT")[4])
-H.check("health + gap + power fill the frame",
-    math.abs(f.health:GetHeight() + f.gap + f.power:GetHeight() - f:GetHeight()) < 1e-6, true)
+checkGrid("title height", f.titleHeight)
+H.check("title + health + gap + power fill the frame",
+    math.abs(f.titleHeight + f.health:GetHeight() + f.gap + f.power:GetHeight() - f:GetHeight()) < 1e-6, true)
+checkGrid("health below the title", pointOf(f.health, "TOPLEFT")[5])
 checkGrid("border", f.border[1]:GetHeight())
 H.check("one-unit border is at least a pixel", f.border[1]:GetHeight() >= px, true)
 checkGrid("border offset", pointOf(f.border[1], "BOTTOMLEFT")[4])
```

```diff
diff --git a/tests/test_power_texts.lua b/tests/test_power_texts.lua
index 912ea1e..8fe6345 100644
--- a/tests/test_power_texts.lua
+++ b/tests/test_power_texts.lua
@@ -7,24 +7,26 @@ M.units.player = { name = "Tester", level = 60, class = "WARLOCK", className = "
 ns.Single.CreateAll()
 local f = ns.Frames.player
 
-local _, _, ph = ns.Layout.Bars(46, 75, 25, true)
+local _, _, _, ph = ns.Layout.Rows(46, 30, 45, 25, true)
 H.check("power height", f.power:GetHeight(), ph)
 H.check("power value secret passthrough", f.power:GetValue(), M.units.player.power)
 H.check("mana colour", f.power._color[3], ns.Power.COLORS[0][3])
 
--- Player defaults: health left NAME_LEVEL, health right CURRENT_MAX, power right CURRENT.
+-- Player defaults: title NAME_LEVEL, health left CURRENT_MAX, health right
+-- PERCENT, power right CURRENT.
 local t = f.texts
-H.check("name level format", t.healthLeft._fmt, "%s %s")
-H.check("name level level arg", t.healthLeft._args[1], "60")
-H.check("current/max format", t.healthRight._fmt, "%s / %s")
-H.check("current/max passes secret", t.healthRight._args[1], M.units.player.health)
+H.check("name level format", t.title._fmt, "%s %s")
+H.check("name level level arg", t.title._args[1], "60")
+H.check("current/max format", t.healthLeft._fmt, "%s / %s")
+H.check("current/max passes secret", t.healthLeft._args[1], M.units.player.health)
+H.check("percent on the right", t.healthRight._fmt, "%.0f%%")
 H.check("power current secret", t.powerRight._text, M.units.player.power)
 H.check("unused slot empty", t.powerLeft._text, "")
 
 -- Readable values are abbreviated.
 M.units.player.health, M.units.player.healthMax = 12345, 20000
 M.FireEvent("UNIT_HEALTH", "player")
-H.check("abbreviated when readable", t.healthRight._args[1], "12.3k")
+H.check("abbreviated when readable", t.healthLeft._args[1], "12.3k")
 
 -- Percent uses the curve and a format, never Lua maths.
 ns.Config.Set("player", "textHealthRight", "PERCENT")
@@ -37,12 +39,12 @@ H.check("deficit passes through", t.healthRight._text, M.units.player.healthMiss
 -- Level ?? for unknown (-1) level
 M.units.target = { name = "Boss", level = -1, health = 1, healthMax = 1 }
 M.FireEvent("PLAYER_TARGET_CHANGED")
-H.check("boss level", ns.Frames.target.texts.healthLeft._args[1], "??")
+H.check("boss level", ns.Frames.target.texts.title._args[1], "??")
 
 -- Power bar off hides it and health fills the frame.
 ns.Config.Set("player", "powerEnabled", false)
 H.check("power hidden", f.power:IsShown(), false)
-H.check("health full height", f.health:GetHeight(), 46)
+H.check("health takes all below the title", f.health:GetHeight(), 46 - f.titleHeight)
 
 -- Fonts follow config
 ns.Config.Set("general", "fontSize", 15)
```

```diff
diff --git a/tests/test_soft_outline.lua b/tests/test_soft_outline.lua
index 11cc2a7..7a1d81f 100644
--- a/tests/test_soft_outline.lua
+++ b/tests/test_soft_outline.lua
@@ -59,16 +59,16 @@ local function checkCopies(label, fs)
     end
 end
 
-for _, field in ipairs({ "healthLeft", "healthRight", "powerLeft", "powerRight" }) do
+for _, field in ipairs({ "title", "healthLeft", "healthRight", "powerLeft", "powerRight" }) do
     checkCopies(field, f.texts[field])
 end
 H.check("left text keeps no word wrap on copies", f.texts.healthLeft.softCopies[1]:GetWordWrap(), false)
 
 -- Every write reaches the copies, secrets passed through untouched.
-local hl, hr, pr = f.texts.healthLeft, f.texts.healthRight, f.texts.powerRight
-H.check("formatted text mirrored", hl.softCopies[3]._fmt, "%s %s")
-H.check("formatted args mirrored", hl.softCopies[3]._args[2], "Tester")
-H.check("secret formatted arg mirrored", hr.softCopies[2]._args[1], M.units.player.health)
+local tt, hl, pr = f.texts.title, f.texts.healthLeft, f.texts.powerRight
+H.check("formatted text mirrored", tt.softCopies[3]._fmt, "%s %s")
+H.check("formatted args mirrored", tt.softCopies[3]._args[2], "Tester")
+H.check("secret formatted arg mirrored", hl.softCopies[2]._args[1], M.units.player.health)
 H.check("secret text mirrored", pr.softCopies[4]._text, M.units.player.power)
 hl:SetText("plain")
 for i = 1, 4 do H.check("SetText mirrored " .. i, hl.softCopies[i]._text, "plain") end
```

**New file `tests/test_title_row.lua`:**

```lua
local M = H.M
local ns = H.LoadAddon()
local S, Lay = ns.Settings, ns.Layout

-- Settings: new codes; the health colour enum keeps its order.
H.check("title height code", S.Get("titlePercent").code, "TP")
H.check("title text code", S.Get("titleText").code, "NT")
H.check("title colour code", S.Get("titleColorMode").code, "NC")
H.check("colour modes", table.concat(S.Get("titleColorMode").values, ","), "CLASS,REACTION,WHITE")
H.check("health colour modes unchanged", table.concat(S.Get("healthColorMode").values, ","),
    "CLASS,REACTION,STATIC,GRADIENT")
H.check("health colour now static", S.Default(S.Get("healthColorMode"), "general"), "STATIC")
H.check("static colour is green", S.Default(S.Get("healthColor"), "general")[2], 0.75)
for scope, want in pairs({ player = 30, target = 30, focus = 30, party = 0, targettarget = 0, pet = 0 }) do
    H.check(scope .. " title default", S.Default(S.Get("titlePercent"), scope), want)
end
H.check("player health default", S.Default(S.Get("healthPercent"), "player"), 45)
H.check("party health default", S.Default(S.Get("healthPercent"), "party"), 75)
H.check("player title text", S.Default(S.Get("titleText"), "player"), "NAME_LEVEL")
H.check("player health left", S.Default(S.Get("textHealthLeft"), "player"), "CURRENT_MAX")
H.check("party health left keeps the name", S.Default(S.Get("textHealthLeft"), "party"), "NAME")

-- Layout maths: title, health, gap, power.
local function rows(...) return table.concat({ Lay.Rows(...) }, ",") end
H.check("three rows", rows(46, 30, 45, 25, true), "14,21,0,11")
H.check("gap is the rest", rows(50, 20, 40, 20, true), "10,20,10,10")
H.check("no title: two rows", rows(40, 0, 75, 25, true), "0,30,0,10")
H.check("power off: health takes the rest", rows(46, 30, 45, 25, false), "14,32,0,0")
H.check("too much: title gives way", rows(20, 60, 50, 50, true), "9,1,0,10")
H.check("two-row helper unchanged", table.concat({ Lay.Bars(46, 75, 25, true) }, ","), "35,0,11")

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, L = ns.Config, ns.L
local f = ns.Frames.player
local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

-- The player frame: title row on top, health below it, power at the bottom.
H.checkTrue("title row shown", f.title:IsShown())
H.check("title height", f.title:GetHeight(), 14)
H.check("title at the top", point(f.title, "TOPLEFT")[5], 0)
H.check("health below the title", point(f.health, "TOPLEFT")[5], -14)
H.check("health height", f.health:GetHeight(), 21)
H.check("power height", f.power:GetHeight(), 11)
H.check("title background colour", f.title._color[4], C.Get("player", "backgroundColor")[4])

-- Title text: name and level, class coloured for players.
M.units.player = { name = "Me", level = 60, class = "WARLOCK", className = "Warlock", isPlayer = true,
    health = 5, healthMax = 10 }
M.FireEvent("PLAYER_ENTERING_WORLD")
local tt = f.texts.title
H.check("title text on the title row", point(tt, "LEFT")[2], f.title)
H.check("ends at the row's right", point(tt, "RIGHT")[2], f.title)
H.checkTrue("title text shown", tt:IsShown())
H.check("name and level", tt._args[2], "Me")
H.check("class colour", tt._color[1], RAID_CLASS_COLORS.WARLOCK.r)
H.check("health shows values", f.texts.healthLeft._fmt, "%s / %s")
H.check("static green health", f.health._color[2], 0.75)

-- NPCs: reaction colour; REACTION and WHITE modes.
M.units.target = { name = "Wolf", level = 10, health = 1, healthMax = 1, reaction = 2 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("npc: reaction red", ns.Frames.target.texts.title._color[1], 0.85)
C.Set("player", "titleColorMode", "REACTION")
M.units.player.reaction = 5
M.FireEvent("PLAYER_ENTERING_WORLD")
H.check("reaction mode for a player", tt._color[2], 0.75)
C.Set("player", "titleColorMode", "WHITE")
H.check("white", tt._color[1] + tt._color[2] + tt._color[3], 3)

-- A portrait takes the title row's left end too.
C.Set("player", "portraitMode", "LEFT")
H.check("title after the portrait", point(f.title, "TOPLEFT")[4], 46)

-- No title row: the old two rows.
C.Set("player", "titlePercent", 0)
H.check("title hidden", f.title:IsShown(), false)
H.check("title text hidden", tt:IsShown(), false)
H.check("health at the top", point(f.health, "TOPLEFT")[5], 0)
local header = ns.Party.header
M.units.party1 = { name = "Ann", health = 1, healthMax = 2 }
M.SetGroup({ "party1" })
local member = header:GetAttribute("child1")
H.check("party: no title row", member.title:IsShown(), false)
H.check("party: name on the health bar", member.texts.healthLeft:GetText(), "Ann")

-- Options: the row heights in Layout, the title text in Text.
local O = ns.Options
O.Open("player")
O.SelectTab("layout")
local keys = {}
for _, row in ipairs(O.rows) do if row.key then keys[row.key] = true end end
H.checkTrue("layout: title height", keys.titlePercent)
O.SelectTab("text")
keys = {}
for _, row in ipairs(O.rows) do if row.key then keys[row.key] = true end end
H.checkTrue("text: title text", keys.titleText)
H.checkTrue("text: title colour", keys.titleColorMode)
H.check("class mode label", ns.Schema.EnumText(S.Get("titleColorMode"), "CLASS"), L.ENUM_titleColorMode_CLASS)
M.RunTimers()
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`

Expected: FAIL — `ns.Layout.Rows` and the new settings do not exist yet; the adjusted existing tests expect the new defaults. The output ends with:

```
  FAIL reset all -> CLASS (want STATIC)
  ERROR test_health.lua:15: attempt to call field 'Rows' (a nil value)
  FAIL title height on the pixel grid -> false (want true)
  ERROR test_pixel.lua:56: attempt to perform arithmetic on field 'titleHeight' (a nil value)
  ERROR test_power_texts.lua:10: attempt to call field 'Rows' (a nil value)
  ERROR test_soft_outline.lua:27: attempt to index local 'fs' (a nil value)
  ERROR test_title_row.lua:6: attempt to index a nil value
1843 passed, 7 failed
```

- [ ] **Step 3: Implement**

Changes to existing files (unified diffs against the previous task's state; `git apply` them or edit by hand):

```diff
diff --git a/Core/Layout.lua b/Core/Layout.lua
index fecc34f..547d6fb 100644
--- a/Core/Layout.lua
+++ b/Core/Layout.lua
@@ -6,20 +6,34 @@ ns.Layout = Layout
 
 local function round(v) return math.floor(v + 0.5) end
 
--- Split a frame height into health bar, gap and power bar. Percentages are
--- of the whole frame; whatever they leave over becomes the gap. With the
--- power bar off, health takes everything.
-function Layout.Bars(height, healthPercent, powerPercent, powerEnabled)
-    if not powerEnabled or powerPercent <= 0 then
-        return height, 0, 0
+-- Split a frame height into title row, health bar, gap and power bar.
+-- Percentages are of the whole frame; whatever they leave over becomes the
+-- gap between health and power. A title of 0 % means no title row; with
+-- the power bar off, health takes everything below the title. Health keeps
+-- at least 1: the title gives way first.
+function Layout.Rows(height, titlePercent, healthPercent, powerPercent, powerEnabled)
+    local powered = powerEnabled and powerPercent > 0
+    local powerH = powered and math.max(1, math.floor(height * powerPercent / 100)) or 0
+    local titleH = 0
+    if titlePercent > 0 then
+        titleH = math.max(1, round(height * titlePercent / 100))
+        titleH = math.max(0, math.min(titleH, height - powerH - 1))
+    end
+    if not powered then
+        return titleH, height - titleH, 0, 0
     end
-    local powerH = math.max(1, math.floor(height * powerPercent / 100))
     local healthH = round(height * healthPercent / 100)
-    if healthH + powerH > height then
-        healthH = height - powerH
+    if titleH + healthH + powerH > height then
+        healthH = height - titleH - powerH
     end
     healthH = math.max(1, healthH)
-    return healthH, height - healthH - powerH, powerH
+    return titleH, healthH, height - titleH - healthH - powerH, powerH
+end
+
+-- The two-row split (no title row): health, gap, power.
+function Layout.Bars(height, healthPercent, powerPercent, powerEnabled)
+    local _, healthH, gap, powerH = Layout.Rows(height, 0, healthPercent, powerPercent, powerEnabled)
+    return healthH, gap, powerH
 end
 
 -- Space the portrait takes from the bars: a square as tall as the frame,
```

```diff
diff --git a/Core/Settings.lua b/Core/Settings.lua
index 42840e0..2c1b478 100644
--- a/Core/Settings.lua
+++ b/Core/Settings.lua
@@ -100,7 +100,7 @@ Settings.Define({ key = "borderColor", code = "BO", scope = "inherit", type = "c
 
 -- Colors
 Settings.Define({ key = "healthColorMode", code = "HM", scope = "inherit", type = "enum",
-    values = { "CLASS", "REACTION", "STATIC", "GRADIENT" }, default = "CLASS" })
+    values = { "CLASS", "REACTION", "STATIC", "GRADIENT" }, default = "STATIC" })
 Settings.Define({ key = "healthColor", code = "HC", scope = "inherit", type = "color", default = { 0.2, 0.75, 0.3, 1 } })
 
 -- Frame layout
@@ -109,7 +109,13 @@ Settings.Define({ key = "width", code = "W", scope = "frame", type = "int", min
     default = { player = 220, target = 220, focus = 160, party = 160, _ = 120 } })
 Settings.Define({ key = "height", code = "H", scope = "frame", type = "int", min = 8, max = 200,
     default = { player = 46, target = 46, focus = 36, party = 36, _ = 28 } })
-Settings.Define({ key = "healthPercent", code = "HP", scope = "frame", type = "int", min = 10, max = 100, default = 75 })
+-- Rows, top to bottom: title, health, power; each a share of the frame
+-- height, the rest is the gap between health and power. A title of 0 is
+-- the two-row layout.
+Settings.Define({ key = "titlePercent", code = "TP", scope = "frame", type = "int", min = 0, max = 60,
+    default = { player = 30, target = 30, focus = 30, _ = 0 } })
+Settings.Define({ key = "healthPercent", code = "HP", scope = "frame", type = "int", min = 10, max = 100,
+    default = { player = 45, target = 45, focus = 45, _ = 75 } })
 Settings.Define({ key = "powerPercent", code = "PP", scope = "frame", type = "int", min = 0, max = 90, default = 25 })
 Settings.Define({ key = "powerEnabled", code = "PE", scope = "frame", type = "bool", default = true })
 Settings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000,
@@ -152,11 +158,16 @@ Settings.Define({ key = "castbarIcon", code = "CI", scope = "frame", only = CAST
 Settings.Define({ key = "castbarName", code = "CN", scope = "frame", only = CASTBAR, type = "bool", default = true })
 Settings.Define({ key = "castbarTime", code = "CT", scope = "frame", only = CASTBAR, type = "bool", default = true })
 
--- Texts
-Settings.Define({ key = "textHealthLeft", code = "TL", scope = "frame", type = "enum", values = TEXT_TAGS,
+-- Texts. With a title row the name moves up there and the health bar
+-- shows values.
+Settings.Define({ key = "titleText", code = "NT", scope = "frame", type = "enum", values = TEXT_TAGS,
     default = { player = "NAME_LEVEL", target = "NAME_LEVEL", _ = "NAME" } })
+Settings.Define({ key = "titleColorMode", code = "NC", scope = "frame", type = "enum",
+    values = { "CLASS", "REACTION", "WHITE" }, default = "CLASS" })
+Settings.Define({ key = "textHealthLeft", code = "TL", scope = "frame", type = "enum", values = TEXT_TAGS,
+    default = { player = "CURRENT_MAX", target = "CURRENT_MAX", focus = "NONE", _ = "NAME" } })
 Settings.Define({ key = "textHealthRight", code = "TR", scope = "frame", type = "enum", values = TEXT_TAGS,
-    default = { player = "CURRENT_MAX", target = "PERCENT", focus = "PERCENT", party = "PERCENT", _ = "NONE" } })
+    default = { player = "PERCENT", target = "PERCENT", focus = "PERCENT", party = "PERCENT", _ = "NONE" } })
 Settings.Define({ key = "textPowerLeft", code = "UL", scope = "frame", type = "enum", values = TEXT_TAGS, default = "NONE" })
 Settings.Define({ key = "textPowerRight", code = "UR", scope = "frame", type = "enum", values = TEXT_TAGS,
     default = { player = "CURRENT", _ = "NONE" } })
```

```diff
diff --git a/Elements/Health.lua b/Elements/Health.lua
index 86ae074..73dd017 100644
--- a/Elements/Health.lua
+++ b/Elements/Health.lua
@@ -22,7 +22,8 @@ local function gradient()
     return gradientCurve
 end
 
-local function reactionColor(unit)
+-- { r, g, b } of the unit's reaction to the player.
+function Health.ReactionColor(unit)
     local r = Secrets.Number(UnitReaction(unit, "player"))
     if r then
         if r <= 3 then return REACTION.hostile end
@@ -34,19 +35,31 @@ local function reactionColor(unit)
     return REACTION.hostile
 end
 
+-- r, g, b of a player's class, or nothing (not a player, class unknown).
+function Health.ClassColor(unit)
+    if not Secrets.Bool(UnitIsPlayer, unit) then return end
+    local ok, c = pcall(function()
+        local _, class = UnitClass(unit)
+        return RAID_CLASS_COLORS[class]
+    end)
+    if ok and c then return c.r, c.g, c.b end
+end
+
+-- Class colour for players, reaction colour for everyone else.
+function Health.UnitColor(unit, mode)
+    if mode == "CLASS" then
+        local r, g, b = Health.ClassColor(unit)
+        if r then return r, g, b end
+    end
+    local c = Health.ReactionColor(unit)
+    return c[1], c[2], c[3]
+end
+
 function Health.ColorFor(frame)
     local scope, unit = frame.key, frame.unit
     local mode = Config.Get(scope, "healthColorMode")
-    if mode == "CLASS" and Secrets.Bool(UnitIsPlayer, unit) then
-        local ok, c = pcall(function()
-            local _, class = UnitClass(unit)
-            return RAID_CLASS_COLORS[class]
-        end)
-        if ok and c then return c.r, c.g, c.b end
-    end
     if mode == "CLASS" or mode == "REACTION" then
-        local c = reactionColor(unit)
-        return c[1], c[2], c[3]
+        return Health.UnitColor(unit, mode)
     end
     if mode == "GRADIENT" then
         return UnitHealthPercent(unit, true, gradient()):GetRGB()
@@ -56,6 +69,9 @@ function Health.ColorFor(frame)
 end
 
 function Health.Build(frame)
+    -- The title row: its own background above the health bar; its text
+    -- is Elements/Texts.lua's.
+    frame.title = frame:CreateTexture(nil, "BACKGROUND")
     frame.health = CreateFrame("StatusBar", nil, frame)
     frame.healthBg = frame.health:CreateTexture(nil, "BACKGROUND")
     frame.healthBg:SetAllPoints(frame.health)
@@ -68,6 +84,8 @@ function Health.Style(frame)
     frame.healthBg:SetTexture(tex)
     local bg = Config.Get(scope, "backgroundColor")
     frame.healthBg:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
+    frame.title:SetTexture(tex)
+    frame.title:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
 end
 
 function Health.Update(frame)
```

```diff
diff --git a/Elements/Texts.lua b/Elements/Texts.lua
index 1f58bd5..eba356f 100644
--- a/Elements/Texts.lua
+++ b/Elements/Texts.lua
@@ -9,7 +9,10 @@ ns.Texts = Texts
 
 local Config, Secrets = ns.Config, ns.Secrets
 
+-- bar: the row the text sits on; kind: whose values it shows (health or
+-- power, default the bar).
 local SLOTS = {
+    { field = "title", setting = "titleText", bar = "title", kind = "health", point = "LEFT", x = 4 },
     { field = "healthLeft", setting = "textHealthLeft", bar = "health", point = "LEFT", x = 4, before = "healthRight" },
     { field = "healthRight", setting = "textHealthRight", bar = "health", point = "RIGHT", x = -4 },
     { field = "powerLeft", setting = "textPowerLeft", bar = "power", point = "LEFT", x = 4, before = "powerRight" },
@@ -139,8 +142,10 @@ end
 function Texts.Build(frame)
     frame.texts = {}
     for _, slot in ipairs(SLOTS) do
-        -- Parent to the bar so the text sits above it.
-        frame.texts[slot.field] = frame[slot.bar]:CreateFontString(nil, "OVERLAY")
+        -- Parent to the bar so the text sits above it; the title row is a
+        -- texture, its text goes on the frame.
+        local parent = slot.bar == "title" and frame or frame[slot.bar]
+        frame.texts[slot.field] = parent:CreateFontString(nil, "OVERLAY")
     end
 end
 
@@ -165,12 +170,25 @@ function Texts.Style(frame)
         end
         fs:SetJustifyH(slot.point)
     end
+    local title = frame.texts.title
+    title:SetPoint("RIGHT", frame.title, "RIGHT", ns.Pixel.Snap(-4, title), 0)
+    title:SetWordWrap(false)
+    title:SetShown(frame.titleHeight > 0)
+end
+
+-- Title text colour: class (players) or reaction, or plain white.
+local function paintTitle(frame)
+    local mode = Config.Get(frame.key, "titleColorMode")
+    local r, g, b = 1, 1, 1
+    if mode ~= "WHITE" then r, g, b = ns.Health.UnitColor(frame.unit, mode) end
+    frame.texts.title:SetTextColor(r, g, b, 1)
 end
 
 function Texts.Update(frame)
     for _, slot in ipairs(SLOTS) do
-        Texts.Apply(frame.texts[slot.field], Config.Get(frame.key, slot.setting), frame.unit, slot.bar)
+        Texts.Apply(frame.texts[slot.field], Config.Get(frame.key, slot.setting), frame.unit, slot.kind or slot.bar)
     end
+    paintTitle(frame)
 end
 
 ns.RegisterElement(Texts)
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index f7120d4..58827e2 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -20,6 +20,7 @@ L.SETTING_healthColor = "Static health color"
 L.SETTING_enabled = "Enabled"
 L.SETTING_width = "Width"
 L.SETTING_height = "Height"
+L.SETTING_titlePercent = "Title row height (%)"
 L.SETTING_healthPercent = "Health bar height (%)"
 L.SETTING_powerPercent = "Power bar height (%)"
 L.SETTING_powerEnabled = "Show power bar"
@@ -40,6 +41,8 @@ L.SETTING_partyOrientation = "Orientation"
 L.SETTING_partySpacing = "Spacing"
 L.SETTING_partyShowPlayer = "Show player"
 L.SETTING_partyShowSolo = "Show when solo"
+L.SETTING_titleText = "Title row text"
+L.SETTING_titleColorMode = "Title text color"
 L.SETTING_textHealthLeft = "Health bar, left text"
 L.SETTING_textHealthRight = "Health bar, right text"
 L.SETTING_textPowerLeft = "Power bar, left text"
@@ -87,6 +90,10 @@ L.SECTION_health = "Health bar"; L.SECTION_frame = "Frame"; L.SECTION_size = "Si
 L.SECTION_barHeights = "Bar heights"; L.SECTION_position = "Position"
 L.SECTION_textures = "Textures"; L.SECTION_healthText = "Health bar text"
 L.SECTION_powerText = "Power bar text"
+L.SECTION_titleText = "Title row"
+L.HINT_titlePercent = "0 = no title row"
+L.ENUM_WHITE = "White"
+L.ENUM_titleColorMode_CLASS = "Class (players)"
 L.SECTION_portrait = "Portrait"
 L.SECTION_group = "Party layout"
 L.SECTION_castbar = "Castbar"
```

```diff
diff --git a/Options/Schema.lua b/Options/Schema.lua
index b180f05..17f51b0 100644
--- a/Options/Schema.lua
+++ b/Options/Schema.lua
@@ -19,7 +19,7 @@ Schema.FRAME = {
     { id = "layout", sections = {
         { id = "frame", keys = { "enabled" } },
         { id = "size", keys = { "width", "height" } },
-        { id = "barHeights", keys = { "healthPercent", "powerPercent", "powerEnabled" } },
+        { id = "barHeights", keys = { "titlePercent", "healthPercent", "powerPercent", "powerEnabled" } },
         { id = "portrait", keys = { "portraitMode", "portraitStyle" } },
         { id = "group", keys = { "partyOrientation", "partySpacing", "partyShowPlayer", "partyShowSolo" } },
         { id = "position", keys = { "x", "y" } },
@@ -30,6 +30,7 @@ Schema.FRAME = {
         { id = "border", keys = { "borderSize", "borderColor" } },
     } },
     { id = "text", sections = {
+        { id = "titleText", keys = { "titleText", "titleColorMode" } },
         { id = "healthText", keys = { "textHealthLeft", "textHealthRight" } },
         { id = "powerText", keys = { "textPowerLeft", "textPowerRight" } },
         { id = "font", keys = { "fontFace", "fontSize", "fontOutline", "fontShadow" } },
```

```diff
diff --git a/Units/Single.lua b/Units/Single.lua
index 0253795..75d1a71 100644
--- a/Units/Single.lua
+++ b/Units/Single.lua
@@ -36,23 +36,31 @@ local function place(frame)
 end
 
 -- The split is worked out in whole units, then put on the pixel grid:
--- power bar and gap are snapped, health takes the rest of the (snapped)
--- frame height, so the three always fill the frame exactly.
+-- title row, power bar and gap are snapped, health takes the rest of the
+-- (snapped) frame height, so the rows always fill the frame exactly.
 local function layoutBars(frame)
     local scope = frame.key
     local _, height = Single.Size(scope)
     local powerOn = Config.Get(scope, "powerEnabled")
-    local _, gap, ph = Layout.Bars(Config.Get(scope, "height"), Config.Get(scope, "healthPercent"),
-        Config.Get(scope, "powerPercent"), powerOn)
+    local th, _, gap, ph = Layout.Rows(Config.Get(scope, "height"), Config.Get(scope, "titlePercent"),
+        Config.Get(scope, "healthPercent"), Config.Get(scope, "powerPercent"), powerOn)
     local powerShown = powerOn and ph > 0
     local pixel = Pixel.Snap(1, nil, 1)
+    local titleH = th > 0 and Pixel.Snap(th, nil, 1) or 0
     local powerH = powerShown and Pixel.Snap(ph, nil, 1) or 0
     gap = powerShown and Pixel.Snap(gap) or 0
-    local healthH = math.max(height - gap - powerH, pixel)
+    local healthH = math.max(height - titleH - gap - powerH, pixel)
     local left, right = Layout.PortraitInsets(Config.Get(scope, "portraitMode"), height)
+    local title = frame.title
+    title:ClearAllPoints()
+    title:SetPoint("TOPLEFT", frame, "TOPLEFT", left, 0)
+    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, 0)
+    title:SetHeight(math.max(titleH, pixel))
+    title:SetShown(titleH > 0)
+    frame.titleHeight = titleH
     frame.health:ClearAllPoints()
-    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", left, 0)
-    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, 0)
+    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -titleH)
+    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, -titleH)
     frame.health:SetHeight(healthH)
     if frame.power then
         frame.power:ClearAllPoints()
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `tests/run`
Expected: `2650 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Layout.lua Core/Settings.lua Elements/Health.lua Elements/Texts.lua Locales/enUS.lua Options/Schema.lua Units/Single.lua tests/test_config.lua tests/test_config_extras.lua tests/test_health.lua tests/test_pixel.lua tests/test_power_texts.lua tests/test_soft_outline.lua tests/test_title_row.lua
git commit -F - <<'EOF'
Add a title row above the health bar; static green health by default

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 3: Rounded corners (corner masks)

An inherited setting `cornerRadius` (0–12, 0 = square) rounds the corners of the whole frame block (title row, bars, portrait) and of every castbar (bar and icon) with four mask textures per block. The mask file is generated offline by a dependency-free Python script and shipped in `Media/`.

**Files:**
- Create: `Core/Corners.lua`
- Create: `Elements/Shape.lua`
- Create: `tools/make_corners.py`
- Generate: `Media/Corner.tga` (by `tools/make_corners.py`, committed as binary)
- Generate: `Media/CornerInverse.tga` (by `tools/make_corners.py`, committed as binary)
- Modify: `.gitignore`
- Modify: `Core/Settings.lua`
- Modify: `Elements/Castbar.lua`
- Modify: `Elements/Health.lua`
- Modify: `Elements/Portrait.lua`
- Modify: `Elements/Power.lua`
- Modify: `ForeverUnitFrames.toc`
- Modify: `Locales/enUS.lua`
- Modify: `Options/Schema.lua`
- Modify: `install`
- Test (new): `tests/test_corners.lua`
- Test (modify): `tests/mock.lua`

**Interfaces:**
- Consumes: `ns.Config`, `ns.Pixel.Snap`, `frame.title`, `frame.healthBg`, `frame.powerBg`, `frame.portraitBg`, `frame.portrait2D`, castbar regions `bar.bg`, `bar.remain`, `bar.icon`.
- Produces:
  - `Media/Corner.tga`, `Media/CornerInverse.tga` (64×64, 32-bit, uncompressed, bottom-up) from `tools/make_corners.py`; `install` copies `Media/*.tga`.
  - `ns.Corners.TEXTURE`, `ns.Corners.INVERSE` (paths), `ns.Corners.POINTS` = `{ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }`, `ns.Corners.COORDS` (tex coords mirroring the top-left shape).
  - `ns.Corners.Radius(scope)` → snapped radius, 0 = square.
  - `ns.Corners.NewMask(owner, file, i)` → a CLAMP-wrapped mask for corner `i`.
  - `ns.Corners.Add(owner, target)` — elements list their textures while building (`target` is a texture or a function returning one, for status bar fills).
  - `ns.Corners.Clipper(owner)` → `{ masks = {4}, targets = owner.cornerTargets }`; `ns.Corners.Fit(clip, box, radius)` anchors the masks to `box`'s corners and masks / unmasks every target once.
  - Element `ns.Shape` (built last): `frame.clip`; castbar: `bar.box` (bar plus icon), `bar.clip`.

- [ ] **Step 1: Write the failing test**

Changes to existing test files (mock support and expectations that change with this task):

```diff
diff --git a/tests/mock.lua b/tests/mock.lua
index edc1242..af218f3 100644
--- a/tests/mock.lua
+++ b/tests/mock.lua
@@ -207,7 +207,20 @@ local function newWidget(kind, name, parent)
     function w:GetStatusBarTexture() return self._barTex end
     function w:SetReverseFill(v) self._reverse = v end
     -- Texture
-    function w:SetTexture(t) self._texture = t end
+    function w:SetTexture(t, wrapH, wrapV) self._texture = t; self._wrap = { wrapH, wrapV } end
+    function w:SetTexCoord(...) self._texCoord = { ... } end
+    function w:SetAtlas(name) self._atlas = name end
+    -- Masks: a texture keeps the masks added to it, in order.
+    function w:AddMaskTexture(mask)
+        self._masks = self._masks or {}
+        table.insert(self._masks, mask)
+    end
+    function w:RemoveMaskTexture(mask)
+        for i, m in ipairs(self._masks or {}) do
+            if m == mask then table.remove(self._masks, i) return end
+        end
+    end
+    function w:GetNumMaskTextures() return #(self._masks or {}) end
     function w:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
     function w:SetVertexColor(r, g, b, a) self._color = { r, g, b, a } end
     function w:SetAllPoints(p) self._allPoints = p or true end
@@ -295,6 +308,7 @@ local function newWidget(kind, name, parent)
     function w:GetVerticalScrollRange() return self._vrange or 0 end
     -- Creation
     function w:CreateTexture(n) return newWidget("Texture", n, self) end
+    function w:CreateMaskTexture(n) return newWidget("MaskTexture", n, self) end
     function w:CreateFontString(n, layer)
         local fs = newWidget("FontString", n, self)
         fs._layer, fs._sublevel = layer or "ARTWORK", 0
```

**New file `tests/test_corners.lua`:**

```lua
local M = H.M
local ns = H.LoadAddon()
local S, Co = ns.Settings, ns.Corners

-- The mask files: 64 x 64 uncompressed 32-bit TGA, rows bottom to top.
local function tga(path)
    local fh = assert(io.open(ADDONDIR .. "/" .. path, "rb"))
    local data = fh:read("*a")
    fh:close()
    return data
end
local function alphaAt(data, x, y) -- x right, y down from the top-left
    local row = 63 - y
    return data:byte(18 + (row * 64 + x) * 4 + 4)
end
for _, file in ipairs({ "Media/Corner.tga", "Media/CornerInverse.tga" }) do
    local d = tga(file)
    H.check(file .. " size", #d, 18 + 64 * 64 * 4)
    H.check(file .. " type: uncompressed true colour", d:byte(3), 2)
    H.check(file .. " width", d:byte(13) + 256 * d:byte(14), 64)
    H.check(file .. " height", d:byte(15) + 256 * d:byte(16), 64)
    H.check(file .. " 32 bits", d:byte(17), 32)
    H.check(file .. " 8 alpha bits, bottom-up rows", d:byte(18), 8)
end
local corner, inverse = tga("Media/Corner.tga"), tga("Media/CornerInverse.tga")
H.check("corner: outer texel cut", alphaAt(corner, 0, 0), 0)
H.check("corner: inner texel kept", alphaAt(corner, 63, 63), 255)
H.check("corner: whole right column kept", alphaAt(corner, 63, 0), 255)
H.check("corner: whole bottom row kept", alphaAt(corner, 0, 63), 255)
H.check("corner: white", corner:byte(19) + corner:byte(20) + corner:byte(21), 3 * 255)
H.check("inverse: outer texel kept", alphaAt(inverse, 0, 0), 255)
H.check("inverse: inner texel cut", alphaAt(inverse, 63, 63), 0)
H.check("inverse: whole left column kept", alphaAt(inverse, 0, 63), 255)
H.check("inverse: whole top row kept", alphaAt(inverse, 63, 0), 255)

-- The installer ships them (it copies only what the TOC lists otherwise).
local dir = os.tmpname()
os.remove(dir)
os.execute("mkdir -p '" .. dir .. "'")
os.execute("'" .. ADDONDIR .. "/install' '" .. dir .. "' > /dev/null")
local shipped = io.open(dir .. "/ForeverUnitFrames/Media/Corner.tga", "rb")
H.checkTrue("installed corner mask", shipped)
if shipped then shipped:close() end
H.checkTrue("installed inverse mask", io.open(dir .. "/ForeverUnitFrames/Media/CornerInverse.tga", "rb"))
os.execute("rm -rf '" .. dir .. "'")

-- Setting: inherited, 0..12, square by default.
local def = S.Get("cornerRadius")
H.check("code", def.code, "CR")
H.check("inherited", def.scope, "inherit")
H.check("default square", S.Default(def, "general"), 0)
H.check("max", S.Validate(def, 40), 12)

ns.Config.Use({})
ns.Single.CreateAll()
local C = ns.Config
local f = ns.Frames.target
local bar = f.castbar
local function masked(texture) return texture:GetNumMaskTextures() end

-- Square: nothing masked, masks hidden.
H.check("square: health background unmasked", masked(f.healthBg), 0)
H.check("square: masks hidden", f.clip.masks[1]:IsShown(), false)
H.check("radius 0", Co.Radius("target"), 0)

-- General radius 6 reaches every frame.
C.Set("general", "cornerRadius", 6)
H.check("radius", Co.Radius("target"), 6)
for _, name in ipairs({ "title", "healthBg", "powerBg", "portraitBg", "portrait2D" }) do
    H.check(name .. " rounded", masked(f[name]), 4)
end
H.check("health fill rounded", masked(f.health:GetStatusBarTexture()), 4)
H.check("power fill rounded", masked(f.power:GetStatusBarTexture()), 4)
for i, mask in ipairs(f.clip.masks) do
    local point = Co.POINTS[i]
    local p, rel, relPoint = mask:GetPoint(1)
    H.check("mask " .. i .. " in its corner", p, point)
    H.check("mask " .. i .. " of the frame", rel, f)
    H.check("mask " .. i .. " same corner", relPoint, point)
    H.check("mask " .. i .. " size", mask:GetWidth(), 6)
    H.check("mask " .. i .. " file", mask._texture, Co.TEXTURE)
    H.check("mask " .. i .. " clamps", mask._wrap[1] .. mask._wrap[2], "CLAMPCLAMP")
    H.check("mask " .. i .. " mirrored", table.concat(mask._texCoord, ","), table.concat(Co.COORDS[i], ","))
    H.checkTrue("mask " .. i .. " shown", mask:IsShown())
end
H.check("file path", Co.TEXTURE, "Interface\\AddOns\\ForeverUnitFrames\\Media\\Corner.tga")

-- Restyling does not stack masks.
C.Set("general", "cornerRadius", 8)
H.check("still four masks", masked(f.healthBg), 4)
H.check("new size", f.clip.masks[1]:GetWidth(), 8)

-- Castbar: its own block, icon included.
H.check("castbar background rounded", masked(bar.bg), 4)
H.check("castbar fill rounded", masked(bar:GetStatusBarTexture()), 4)
H.check("castbar icon rounded", masked(bar.icon), 4)
H.check("castbar masks on its box", select(2, bar.clip.masks[1]:GetPoint(1)), bar.box)
H.check("box starts at the icon", select(4, bar.box:GetPoint(1)), -16)
C.Set("target", "castbarIcon", false)
H.check("no icon: box starts at the bar", select(4, bar.box:GetPoint(1)), 0)

-- A frame can stay square.
C.Set("target", "cornerRadius", 0)
H.check("override: square again", masked(f.healthBg), 0)
H.check("override: castbar square", masked(bar.bg), 0)
H.check("other frames keep theirs", masked(ns.Frames.player.healthBg), 4)

-- Party buttons are rounded too.
local header = ns.Party.Create()
M.units.party1 = { name = "Ann", health = 1, healthMax = 2 }
M.SetGroup({ "party1" })
H.check("party rounded", masked(header:GetAttribute("child1").healthBg), 4)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`

Expected: FAIL — `Media/Corner.tga` does not exist yet. The output ends with:

```
  ERROR test_corners.lua:7: <repo>/Media/Corner.tga: No such file or directory
2650 passed, 1 failed
```

- [ ] **Step 3: Implement**

**New file `Core/Corners.lua`:**

```lua
local _, ns = ...

-- Rounded corners. Four mask textures, one per corner, each as big as the
-- radius and sitting in its corner of a box. The mask file is the top-left
-- corner of a rounded rectangle (tools/make_corners.py); the other corners
-- mirror it with texture coordinates. CLAMP wrapping repeats the mask's
-- opaque right column and bottom row outwards, so each mask only cuts its
-- own corner and lets the rest of the box through. A texture under all
-- four masks is rounded at every corner of the box it lies in.
local Corners = {}
ns.Corners = Corners

local Config, Pixel = ns.Config, ns.Pixel

local MEDIA = "Interface\\AddOns\\ForeverUnitFrames\\Media\\"
Corners.TEXTURE = MEDIA .. "Corner.tga"
Corners.INVERSE = MEDIA .. "CornerInverse.tga"
Corners.POINTS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
-- left, right, top, bottom: mirrored copies of the top-left shape.
Corners.COORDS = { { 0, 1, 0, 1 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 1, 0, 1, 0 } }

-- Corner radius of scope on the pixel grid; 0 means square.
function Corners.Radius(scope)
    local r = Config.Get(scope, "cornerRadius")
    if r <= 0 then return 0 end
    return Pixel.Snap(r, nil, 1)
end

-- Mask i (1..4, Corners.POINTS order) of file on owner.
function Corners.NewMask(owner, file, i)
    local mask = owner:CreateMaskTexture()
    mask:SetTexture(file, "CLAMP", "CLAMP")
    local c = Corners.COORDS[i]
    mask:SetTexCoord(c[1], c[2], c[3], c[4])
    return mask
end

-- A textures list for owner's rounded block. Elements add their textures
-- while building: a texture, or a function returning one (a status bar's
-- fill is asked for each time).
function Corners.Add(owner, target)
    owner.cornerTargets = owner.cornerTargets or {}
    table.insert(owner.cornerTargets, target)
end

-- The four masks of owner, made once, for the textures Corners.Add listed.
function Corners.Clipper(owner)
    local clip = { masks = {}, targets = owner.cornerTargets or {} }
    for i = 1, 4 do clip.masks[i] = Corners.NewMask(owner, Corners.TEXTURE, i) end
    return clip
end

local function resolve(target)
    if type(target) == "function" then return target() end
    return target
end

-- Rounds the corners of box by radius (0: square, masks removed). A
-- texture is masked once; its own field remembers it.
function Corners.Fit(clip, box, radius)
    local on = radius > 0
    for i, mask in ipairs(clip.masks) do
        mask:ClearAllPoints()
        mask:SetPoint(Corners.POINTS[i], box, Corners.POINTS[i], 0, 0)
        mask:SetSize(radius, radius)
        mask:SetShown(on)
    end
    for _, target in ipairs(clip.targets) do
        local texture = resolve(target)
        if texture and on and not texture.fufRounded then
            for _, mask in ipairs(clip.masks) do texture:AddMaskTexture(mask) end
            texture.fufRounded = true
        elseif texture and not on and texture.fufRounded then
            for _, mask in ipairs(clip.masks) do texture:RemoveMaskTexture(mask) end
            texture.fufRounded = nil
        end
    end
end
```

**New file `Elements/Shape.lua`:**

```lua
local _, ns = ...

-- The frame's outline: rounded corners of the whole block (bars and
-- portrait). Built after every other element, so all their textures are
-- listed (ns.Corners.Add) by then.
local Shape = { name = "Shape" }
ns.Shape = Shape

function Shape.Build(frame)
    frame.clip = ns.Corners.Clipper(frame)
end

function Shape.Style(frame)
    ns.Corners.Fit(frame.clip, frame, ns.Corners.Radius(frame.key))
end

function Shape.Update() end

ns.RegisterElement(Shape)
```

**New file `tools/make_corners.py`:**

```python
#!/usr/bin/env python3
"""Writes the two corner masks the addon ships (Media/Corner.tga and
Media/CornerInverse.tga). No dependencies beyond the standard library.

Both are 64 x 64, uncompressed 32-bit TGA, white, the shape in the alpha
channel, rows stored bottom to top (the TGA default).

Corner.tga: the top-left corner of a rounded rectangle. A quarter disc
of radius 64 centred on the texture's bottom-right corner is opaque,
the rest transparent. Every texel of the right column and the bottom row
is (nearly) opaque, so a mask of this texture with CLAMP wrapping lets
everything right of and below it through.

CornerInverse.tga: transparent inside a quarter disc of radius 63 around
the same corner, opaque outside. One texel smaller than the texture, so
the whole left column and top row stay opaque: a CLAMP mask of it lets
everything left of and above it through. Used for the inner edge of a
rounded border.

Run from the repository root:  python3 tools/make_corners.py
The output is deterministic; re-running it must not change the files.
"""
import os
import struct

SIZE = 64
SUB = 4  # sub-samples per axis for the anti-aliased edge


def coverage(x, y, radius=SIZE):
    """Share of texel (x, y) (x to the right, y downwards) inside the disc
    of the given radius around the texture's bottom-right corner."""
    inside = 0
    for i in range(SUB):
        for j in range(SUB):
            px = x + (i + 0.5) / SUB
            py = y + (j + 0.5) / SUB
            dx, dy = SIZE - px, SIZE - py
            if dx * dx + dy * dy <= radius * radius:
                inside += 1
    return inside / (SUB * SUB)


def write_tga(path, alpha_of):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    rows = []
    for y in range(SIZE - 1, -1, -1):  # bottom row first
        row = bytearray()
        for x in range(SIZE):
            a = int(round(alpha_of(x, y) * 255))
            row += bytes((255, 255, 255, a))  # B, G, R, A
        rows.append(bytes(row))
    with open(path, "wb") as fh:
        fh.write(header)
        fh.write(b"".join(rows))


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Media")
    os.makedirs(root, exist_ok=True)
    write_tga(os.path.join(root, "Corner.tga"), coverage)
    write_tga(os.path.join(root, "CornerInverse.tga"), lambda x, y: 1 - coverage(x, y, SIZE - 1))


if __name__ == "__main__":
    main()
```

Generate the masks (from the repository root) and check they are byte-identical to what this plan was replayed with:

```bash
python3 tools/make_corners.py
sha256sum Media/Corner.tga Media/CornerInverse.tga
```

Expected:

```
6433fd3a3f44ea964de7d1cd3a05d3e587ea912b35891bc63327d2c02fbba419  Media/Corner.tga
5a85a39c7882809a2e734afa98d47bd726512bb0ed481aea844808de9a07a646  Media/CornerInverse.tga
```

Changes to existing files (unified diffs against the previous task's state; `git apply` them or edit by hand):

```diff
diff --git a/.gitignore b/.gitignore
index 0b1b46d..dc0bfe0 100644
--- a/.gitignore
+++ b/.gitignore
@@ -1,3 +1,4 @@
 *.swp
 .DS_Store
 /dist/
+__pycache__/
```

```diff
diff --git a/Core/Settings.lua b/Core/Settings.lua
index 2c1b478..da6c37f 100644
--- a/Core/Settings.lua
+++ b/Core/Settings.lua
@@ -97,6 +97,7 @@ Settings.Define({ key = "barTexture", code = "BT", scope = "inherit", type = "me
 Settings.Define({ key = "backgroundColor", code = "BC", scope = "inherit", type = "color", default = { 0, 0, 0, 0.6 } })
 Settings.Define({ key = "borderSize", code = "BS", scope = "inherit", type = "int", min = 0, max = 2, default = 1 })
 Settings.Define({ key = "borderColor", code = "BO", scope = "inherit", type = "color", default = { 0, 0, 0, 1 } })
+Settings.Define({ key = "cornerRadius", code = "CR", scope = "inherit", type = "int", min = 0, max = 12, default = 0 })
 
 -- Colors
 Settings.Define({ key = "healthColorMode", code = "HM", scope = "inherit", type = "enum",
```

```diff
diff --git a/Elements/Castbar.lua b/Elements/Castbar.lua
index f0a5a1f..6787672 100644
--- a/Elements/Castbar.lua
+++ b/Elements/Castbar.lua
@@ -173,6 +173,12 @@ function Castbar.Build(frame)
     bar.icon = bar:CreateTexture(nil, "ARTWORK")
     bar.text = bar:CreateFontString(nil, "OVERLAY")
     bar.time = bar:CreateFontString(nil, "OVERLAY")
+    -- The castbar's whole rectangle, icon included: its corners are
+    -- rounded, and a detached castbar's border goes around it.
+    bar.box = CreateFrame("Frame", nil, bar)
+    for _, texture in ipairs({ bar.bg, bar.remain, bar.icon }) do ns.Corners.Add(bar, texture) end
+    ns.Corners.Add(bar, function() return bar:GetStatusBarTexture() end)
+    bar.clip = ns.Corners.Clipper(bar)
     bar:SetScript("OnUpdate", Castbar.OnUpdate)
     bar:Hide()
     frame.castbar = bar
@@ -268,6 +274,10 @@ function Castbar.Style(frame)
     bar.icon:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
     bar.icon:SetSize(height, height)
     bar.icon:SetShown(showIcon)
+    bar.box:ClearAllPoints()
+    bar.box:SetPoint("TOPLEFT", bar, "TOPLEFT", showIcon and -height or 0, 0)
+    bar.box:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
+    ns.Corners.Fit(bar.clip, bar.box, ns.Corners.Radius(scope))
     local font = ns.Media.Font(Config.Get(scope, "fontFace"))
     local outline = Config.Get(scope, "fontOutline")
     local fontSize = math.min(Config.Get(scope, "fontSize"), Config.Get(scope, "castbarHeight"))
```

```diff
diff --git a/Elements/Health.lua b/Elements/Health.lua
index 73dd017..0935681 100644
--- a/Elements/Health.lua
+++ b/Elements/Health.lua
@@ -75,6 +75,9 @@ function Health.Build(frame)
     frame.health = CreateFrame("StatusBar", nil, frame)
     frame.healthBg = frame.health:CreateTexture(nil, "BACKGROUND")
     frame.healthBg:SetAllPoints(frame.health)
+    ns.Corners.Add(frame, frame.title)
+    ns.Corners.Add(frame, frame.healthBg)
+    ns.Corners.Add(frame, function() return frame.health:GetStatusBarTexture() end)
 end
 
 function Health.Style(frame)
```

```diff
diff --git a/Elements/Portrait.lua b/Elements/Portrait.lua
index 1c76d2b..722b51e 100644
--- a/Elements/Portrait.lua
+++ b/Elements/Portrait.lua
@@ -14,6 +14,9 @@ function Portrait.Build(frame)
     frame.portrait2D:SetAllPoints(frame.portraitBg)
     frame.portrait3D = CreateFrame("PlayerModel", nil, frame)
     frame.portrait3D:SetAllPoints(frame.portraitBg)
+    -- A model is no texture: the 3D portrait stays square.
+    ns.Corners.Add(frame, frame.portraitBg)
+    ns.Corners.Add(frame, frame.portrait2D)
 end
 
 function Portrait.Style(frame)
```

```diff
diff --git a/Elements/Power.lua b/Elements/Power.lua
index 9ac8032..83dd6a0 100644
--- a/Elements/Power.lua
+++ b/Elements/Power.lua
@@ -19,6 +19,8 @@ function Power.Build(frame)
     frame.power = CreateFrame("StatusBar", nil, frame)
     frame.powerBg = frame.power:CreateTexture(nil, "BACKGROUND")
     frame.powerBg:SetAllPoints(frame.power)
+    ns.Corners.Add(frame, frame.powerBg)
+    ns.Corners.Add(frame, function() return frame.power:GetStatusBarTexture() end)
 end
 
 function Power.Style(frame)
```

```diff
diff --git a/ForeverUnitFrames.toc b/ForeverUnitFrames.toc
index daf31e0..0aed2a0 100644
--- a/ForeverUnitFrames.toc
+++ b/ForeverUnitFrames.toc
@@ -15,12 +15,14 @@ Core\MacroBackup.lua
 Core\Storage.lua
 Core\Media.lua
 Core\Layout.lua
+Core\Corners.lua
 Units\Units.lua
 Elements\Health.lua
 Elements\Power.lua
 Elements\Texts.lua
 Elements\Portrait.lua
 Elements\Castbar.lua
+Elements\Shape.lua
 Units\Events.lua
 Units\Single.lua
 Units\Party.lua
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index 58827e2..9480042 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -15,6 +15,7 @@ L.SETTING_barTexture = "Bar texture"
 L.SETTING_backgroundColor = "Background color"
 L.SETTING_borderSize = "Border size"
 L.SETTING_borderColor = "Border color"
+L.SETTING_cornerRadius = "Corner radius"
 L.SETTING_healthColorMode = "Health color"
 L.SETTING_healthColor = "Static health color"
 L.SETTING_enabled = "Enabled"
@@ -95,6 +96,8 @@ L.HINT_titlePercent = "0 = no title row"
 L.ENUM_WHITE = "White"
 L.ENUM_titleColorMode_CLASS = "Class (players)"
 L.SECTION_portrait = "Portrait"
+L.SECTION_shape = "Shape"
+L.HINT_cornerRadius = "0 = square corners"
 L.SECTION_group = "Party layout"
 L.SECTION_castbar = "Castbar"
 L.SECTION_castbarContent = "Shown on the bar"
```

```diff
diff --git a/Options/Schema.lua b/Options/Schema.lua
index 17f51b0..47c30a1 100644
--- a/Options/Schema.lua
+++ b/Options/Schema.lua
@@ -8,6 +8,7 @@ Schema.GENERAL = {
         { id = "font", keys = { "fontFace", "fontSize", "fontOutline", "fontShadow" }, action = "applyFontToFrames" },
         { id = "bars", keys = { "barTexture", "backgroundColor" } },
         { id = "border", keys = { "borderSize", "borderColor" } },
+        { id = "shape", keys = { "cornerRadius" } },
     } },
     { id = "colors", sections = {
         { id = "health", keys = { "healthColorMode", "healthColor" } },
@@ -28,6 +29,7 @@ Schema.FRAME = {
         { id = "health", keys = { "healthColorMode", "healthColor" } },
         { id = "textures", keys = { "barTexture", "backgroundColor" } },
         { id = "border", keys = { "borderSize", "borderColor" } },
+        { id = "shape", keys = { "cornerRadius" } },
     } },
     { id = "text", sections = {
         { id = "titleText", keys = { "titleText", "titleColorMode" } },
```

```diff
diff --git a/install b/install
index 21f631e..2ef177a 100755
--- a/install
+++ b/install
@@ -15,4 +15,7 @@ grep -v '^\s*#' "$HERE/ForeverUnitFrames.toc" | grep -v '^\s*$' | tr -d '\r' | w
     mkdir -p "$TARGET/$(dirname "$f")"
     cp "$HERE/$f" "$TARGET/$f"
 done
+# Textures the Lua code loads by path (made by tools/make_corners.py).
+mkdir -p "$TARGET/Media"
+cp "$HERE"/Media/*.tga "$TARGET/Media/"
 echo "Installed to $TARGET"
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `tests/run`
Expected: `2748 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add .gitignore Core/Corners.lua Core/Settings.lua Elements/Castbar.lua Elements/Health.lua Elements/Portrait.lua Elements/Power.lua Elements/Shape.lua ForeverUnitFrames.toc Locales/enUS.lua Media/Corner.tga Media/CornerInverse.tga Options/Schema.lua install tests/mock.lua tests/test_corners.lua tools/make_corners.py
git commit -F - <<'EOF'
Round the corners of frames and castbars with corner masks

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 4: Outer border: thickness, padding, one ring around the unit

`borderSize` goes up to 8 px (same code `BS`); new inherited `borderPadding` (`BP`, 0–8) is the gap between frame and border. The border is one ring around the unit box — the frame plus a docked castbar while it shows — and follows the corner radius (concentric arcs). A detached castbar gets its own ring. Replaces `Single.DrawBorder`.

**Files:**
- Create: `Core/Border.lua`
- Modify: `Core/Settings.lua`
- Modify: `Elements/Castbar.lua`
- Modify: `Elements/Shape.lua`
- Modify: `ForeverUnitFrames.toc`
- Modify: `Locales/enUS.lua`
- Modify: `Options/Schema.lua`
- Modify: `Options/Window.lua`
- Modify: `Units/Single.lua`
- Test (new): `tests/test_border.lua`

**Interfaces:**
- Consumes: `ns.Corners.NewMask/POINTS/TEXTURE/INVERSE/Radius`, `ns.Castbar.Gap/Placement`, `frame.castbar`, `bar.box`.
- Produces:
  - `ns.Border.Size(scope)` (thickness on the grid, 0 = off), `ns.Border.Padding(scope)`, `ns.Border.Extent(scope)` (padding + thickness, 0 without border).
  - `ns.Border.Draw(owner, scope, box)` — `owner.border[1..4]` edges (top, bottom, left, right; `[1]` keeps its `BOTTOMLEFT` anchor), `owner.border.corners[1..4]` squares, `.outer` / `.inner` masks; `ns.Border.Hide(owner)`.
  - `ns.Castbar.Height(scope)`; `Castbar.DockedDepth` now counts `Border.Extent` (same value as before for padding 0).
  - `ns.Shape.FitBox(frame)`; `frame.unitBox` (plain frame: frame, plus the docked castbar while shown; follows castbar OnShow / OnHide).
  - `ns.Single.BorderSize(scope)` delegates to `ns.Border.Size`; `ns.Single.DrawBorder` is removed.

- [ ] **Step 1: Write the failing test**

**New file `tests/test_border.lua`:**

```lua
local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

-- Settings: thicker borders, a new padding; the size code is unchanged.
H.check("size code kept", S.Get("borderSize").code, "BS")
H.check("size up to 8", S.Validate(S.Get("borderSize"), 20), 8)
local pad = S.Get("borderPadding")
H.check("padding code", pad.code, "BP")
H.check("padding inherited", pad.scope, "inherit")
H.check("padding default", S.Default(pad, "general"), 0)
H.check("padding max", S.Validate(pad, 20), 8)

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, B = ns.Config, ns.Border
local f = ns.Frames.target
local b = f.border
local box = f.unitBox
local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

-- Default: one pixel, no padding, square: the ring hugs the frame.
H.check("extent", B.Extent("target"), 1)
H.check("top edge thickness", b[1]:GetHeight(), 1)
H.check("top edge on the box", point(b[1], "BOTTOMLEFT")[2], box)
H.check("top edge from the box's left", point(b[1], "BOTTOMLEFT")[4], 0)
H.check("top edge right on the box's top", point(b[1], "BOTTOMLEFT")[5], 0)
H.check("left edge", point(b[3], "TOPRIGHT")[4], 0)
H.check("corner square", b.corners[1]:GetWidth(), 1)
H.check("corner outside the box", point(b.corners[1], "TOPLEFT")[4], -1)
H.check("corner outside the box (y)", point(b.corners[1], "TOPLEFT")[5], 1)
H.check("square corners unmasked", b.corners[1]:GetNumMaskTextures(), 0)
H.checkTrue("shown", b[1]:IsShown() and b.corners[4]:IsShown())
H.check("colour", b[2]._color[4], 1)

-- The box is the frame while no castbar shows.
H.check("idle castbar: box bottom on the frame", point(box, "BOTTOMRIGHT")[5], 0)
H.check("box top on the frame", point(box, "TOPLEFT")[5], 0)

-- Thicker, padded.
C.Set("general", "borderSize", 4)
C.Set("general", "borderPadding", 2)
H.check("extent adds up", B.Extent("target"), 6)
H.check("thick edge", b[1]:GetHeight(), 4)
H.check("edge padded away", point(b[1], "BOTTOMLEFT")[5], 2)
H.check("edge between the corners", point(b[1], "BOTTOMLEFT")[4], -2)
H.check("left edge padded", point(b[3], "TOPRIGHT")[4], -2)
H.check("corner square size", b.corners[1]:GetWidth(), 4)
H.check("corner at the ring's corner", point(b.corners[4], "BOTTOMRIGHT")[4], 6)
H.check("corner at the ring's corner (y)", point(b.corners[4], "BOTTOMRIGHT")[5], -6)

-- Rounded: corner squares as big as the outer radius, masked twice.
C.Set("general", "cornerRadius", 5)
local corner = b.corners[1]
H.check("round corner size", corner:GetWidth(), 5 + 6)
H.check("round: edge starts after the corner", point(b[1], "BOTTOMLEFT")[4], 5)
H.check("round: two masks", corner:GetNumMaskTextures(), 2)
H.check("outer arc file", b.outer[1]._texture, ns.Corners.TEXTURE)
H.check("inner arc file", b.inner[1]._texture, ns.Corners.INVERSE)
H.check("outer arc on the corner", point(b.outer[1], "TOPLEFT")[2], corner)
H.check("outer arc size", b.outer[1]:GetWidth(), 11)
H.check("inner arc inset by the thickness", point(b.inner[1], "TOPLEFT")[4], 4)
H.check("inner arc inset by the thickness (y)", point(b.inner[1], "TOPLEFT")[5], -4)
H.check("inner arc size", b.inner[1]:GetWidth(), 7)
H.check("mirrored for the bottom right", point(b.inner[4], "BOTTOMRIGHT")[4], -4)
C.Set("general", "cornerRadius", 6)
H.check("restyle keeps two masks", corner:GetNumMaskTextures(), 2)
C.Set("general", "cornerRadius", 0)
H.check("square again: masks off", corner:GetNumMaskTextures(), 0)

-- Per frame override, and off.
C.Set("target", "borderSize", 0)
H.check("override: off", b[1]:IsShown(), false)
H.check("override: corners off", b.corners[1]:IsShown(), false)
H.check("no border: no extent", B.Extent("target"), 0)
H.checkTrue("other frames keep theirs", ns.Frames.player.border[1]:IsShown())
C.Set("target", "borderSize", 4)
C.Set("target", "borderColor", { 1, 0, 0, 1 })
H.check("own colour", b[1]._color[1], 1)
H.check("own colour on corners", b.corners[2]._color[1], 1)

-- A docked castbar joins the box while it shows.
local bar = f.castbar
M.units.target = { name = "Foe", health = 1, healthMax = 1,
    cast = { name = "Bolt", texture = 1, startMs = 1000000, endMs = 1002000 } }
M.FireEvent("UNIT_SPELLCAST_START", "target", "c1", 1)
local reach = ns.Castbar.Gap("target") + ns.Castbar.Height("target")
H.check("casting: box takes the castbar in", point(box, "BOTTOMRIGHT")[5], -reach)
H.check("docked castbar: no border of its own", bar.border == nil or not bar.border[1]:IsShown(), true)
M.units.target.cast = nil
M.FireEvent("UNIT_SPELLCAST_STOP", "target", "c1", 1)
H.check("cast over: box back to the frame", point(box, "BOTTOMRIGHT")[5], 0)
C.Set("target", "castbarPosition", "ABOVE")
ns.Castbar.Preview(f, true)
H.check("above: box grows upwards", point(box, "TOPLEFT")[5], reach)
H.check("above: bottom on the frame", point(box, "BOTTOMRIGHT")[5], 0)
ns.Castbar.Preview(f, false)

-- Room for the border in the docked depth (party spacing uses it).
H.check("docked depth counts the whole ring", ns.Castbar.DockedDepth("target"),
    ns.Castbar.Gap("target") + ns.Castbar.Height("target") + 6)

-- Detached: the castbar has its own ring around bar and icon.
C.Set("target", "castbarPosition", "DETACHED")
ns.Castbar.Preview(f, true)
H.checkTrue("detached: own border", bar.border and bar.border[1]:IsShown())
H.check("detached: around the castbar box", point(bar.border[1], "BOTTOMLEFT")[2], bar.box)
H.check("detached: frame box without castbar", point(box, "TOPLEFT")[5], 0)
C.Set("target", "castbarPosition", "BELOW")
H.check("docked again: castbar ring hidden", bar.border[1]:IsShown(), false)
ns.Castbar.Preview(f, false)

-- The options highlight sits outside the whole ring.
ns.Options.Open("target")
local hl = f.optionsHighlight
H.check("highlight outside the border", point(hl[1], "BOTTOMLEFT")[5], B.Extent("target"))
M.RunTimers()
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`

Expected: FAIL — `borderPadding` does not exist and `borderSize` still stops at 2. The output ends with:

```
  FAIL size up to 8 -> 2 (want 8)
  ERROR test_border.lua:9: attempt to index local 'pad' (a nil value)
2749 passed, 2 failed
```

- [ ] **Step 3: Implement**

**New file `Core/Border.lua`:**

```lua
local _, ns = ...

-- The outer border: a ring around a box, `borderPadding` away from it and
-- `borderSize` thick. A unit frame's box takes in a docked castbar while
-- it shows (Elements/Shape.lua), so frame, portrait and castbar sit in one
-- border. Eight pieces: four edges and four corner squares. With rounded
-- corners each corner square is masked twice: the outer arc (Corner.tga)
-- and the inner arc (CornerInverse.tga), both centred where the box's own
-- rounded corner is centred, so ring and box stay concentric.
local Border = {}
ns.Border = Border

local Config, Pixel = ns.Config, ns.Pixel

-- Outward direction of each corner (Corners.POINTS order).
local OUT = { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }

-- Thickness on the pixel grid: at least one pixel unless the border is off.
function Border.Size(scope)
    local size = Config.Get(scope, "borderSize")
    if size <= 0 then return 0 end
    return Pixel.Snap(size, nil, 1)
end

function Border.Padding(scope)
    local padding = Config.Get(scope, "borderPadding")
    if padding <= 0 then return 0 end
    return Pixel.Snap(padding, nil, 1)
end

-- How far the border reaches out from its box; 0 without a border.
function Border.Extent(scope)
    local size = Border.Size(scope)
    if size == 0 then return 0 end
    return Border.Padding(scope) + size
end

local function pieces(owner)
    if owner.border then return owner.border end
    local b = { corners = {}, outer = {}, inner = {} }
    for i = 1, 4 do b[i] = owner:CreateTexture(nil, "OVERLAY") end
    for i = 1, 4 do
        b.corners[i] = owner:CreateTexture(nil, "OVERLAY")
        b.outer[i] = ns.Corners.NewMask(owner, ns.Corners.TEXTURE, i)
        b.inner[i] = ns.Corners.NewMask(owner, ns.Corners.INVERSE, i)
    end
    owner.border = b
    return b
end

-- Masks a corner piece (round) or takes its masks off again.
local function roundCorner(b, i, round)
    local piece = b.corners[i]
    if round and not piece.fufRounded then
        piece:AddMaskTexture(b.outer[i])
        piece:AddMaskTexture(b.inner[i])
        piece.fufRounded = true
    elseif not round and piece.fufRounded then
        piece:RemoveMaskTexture(b.outer[i])
        piece:RemoveMaskTexture(b.inner[i])
        piece.fufRounded = nil
    end
end

local function placeEdges(b, box, size, padding, reach, corner)
    local inset = corner - reach
    b[1]:ClearAllPoints()
    b[1]:SetPoint("BOTTOMLEFT", box, "TOPLEFT", inset, padding)
    b[1]:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -inset, padding)
    b[1]:SetHeight(size)
    b[2]:ClearAllPoints()
    b[2]:SetPoint("TOPLEFT", box, "BOTTOMLEFT", inset, -padding)
    b[2]:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", -inset, -padding)
    b[2]:SetHeight(size)
    b[3]:ClearAllPoints()
    b[3]:SetPoint("TOPRIGHT", box, "TOPLEFT", -padding, -inset)
    b[3]:SetPoint("BOTTOMRIGHT", box, "BOTTOMLEFT", -padding, inset)
    b[3]:SetWidth(size)
    b[4]:ClearAllPoints()
    b[4]:SetPoint("TOPLEFT", box, "TOPRIGHT", padding, -inset)
    b[4]:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", padding, inset)
    b[4]:SetWidth(size)
end

local function placeCorners(b, box, size, reach, corner, round)
    for i, point in ipairs(ns.Corners.POINTS) do
        local piece, sx, sy = b.corners[i], OUT[i][1], OUT[i][2]
        piece:ClearAllPoints()
        piece:SetPoint(point, box, point, sx * reach, sy * reach)
        piece:SetSize(corner, corner)
        local outer, inner = b.outer[i], b.inner[i]
        outer:ClearAllPoints()
        outer:SetPoint(point, piece, point, 0, 0)
        outer:SetSize(corner, corner)
        inner:ClearAllPoints()
        inner:SetPoint(point, piece, point, -sx * size, -sy * size)
        inner:SetSize(corner - size, corner - size)
        outer:SetShown(round)
        inner:SetShown(round)
        roundCorner(b, i, round)
    end
end

-- Draws owner's border around box in scope's size, padding, colour and
-- corner radius.
function Border.Draw(owner, scope, box)
    local b = pieces(owner)
    local size, padding = Border.Size(scope), Border.Padding(scope)
    local radius = ns.Corners.Radius(scope)
    local round = size > 0 and radius > 0
    local reach = padding + size
    -- Corner squares: as big as the ring's outer radius when round, else
    -- just the size x size corner of the ring.
    local corner = round and (radius + reach) or size
    placeEdges(b, box, size, padding, reach, corner)
    placeCorners(b, box, size, reach, corner, round)
    local c = Config.Get(scope, "borderColor")
    for _, piece in ipairs({ b[1], b[2], b[3], b[4], unpack(b.corners) }) do
        piece:SetColorTexture(c[1], c[2], c[3], c[4])
        piece:SetShown(size > 0)
    end
end

function Border.Hide(owner)
    local b = owner.border
    if not b then return end
    for i = 1, 4 do
        b[i]:Hide()
        b.corners[i]:Hide()
        b.outer[i]:Hide()
        b.inner[i]:Hide()
    end
end
```

Changes to existing files (unified diffs against the previous task's state; `git apply` them or edit by hand):

```diff
diff --git a/Core/Settings.lua b/Core/Settings.lua
index da6c37f..34c2fdb 100644
--- a/Core/Settings.lua
+++ b/Core/Settings.lua
@@ -95,8 +95,9 @@ Settings.Define({ key = "fontOutline", code = "FO", scope = "inherit", type = "e
 Settings.Define({ key = "fontShadow", code = "FH", scope = "inherit", type = "bool", default = false })
 Settings.Define({ key = "barTexture", code = "BT", scope = "inherit", type = "media", mediaKind = "statusbar", default = "Flat" })
 Settings.Define({ key = "backgroundColor", code = "BC", scope = "inherit", type = "color", default = { 0, 0, 0, 0.6 } })
-Settings.Define({ key = "borderSize", code = "BS", scope = "inherit", type = "int", min = 0, max = 2, default = 1 })
+Settings.Define({ key = "borderSize", code = "BS", scope = "inherit", type = "int", min = 0, max = 8, default = 1 })
 Settings.Define({ key = "borderColor", code = "BO", scope = "inherit", type = "color", default = { 0, 0, 0, 1 } })
+Settings.Define({ key = "borderPadding", code = "BP", scope = "inherit", type = "int", min = 0, max = 8, default = 0 })
 Settings.Define({ key = "cornerRadius", code = "CR", scope = "inherit", type = "int", min = 0, max = 12, default = 0 })
 
 -- Colors
```

```diff
diff --git a/Elements/Castbar.lua b/Elements/Castbar.lua
index 6787672..0309bcd 100644
--- a/Elements/Castbar.lua
+++ b/Elements/Castbar.lua
@@ -41,8 +41,10 @@ end
 local function barHeight(scope)
     return ns.Pixel.Snap(Config.Get(scope, "castbarHeight"))
 end
+Castbar.Height = barHeight
 
--- Gap between frame and castbar: room for both borders, on the pixel grid.
+-- Gap between frame and a docked castbar, on the pixel grid. Both sit in
+-- the unit's one border; the gap grows with the border's weight.
 function Castbar.Gap(scope)
     return 2 * ns.Single.BorderSize(scope) + ns.Pixel.Snap(2)
 end
@@ -192,14 +194,14 @@ function Castbar.Placement(scope)
     return Config.Get(scope, "castbarDock")
 end
 
--- Room a docked castbar takes next to its frame: gap, bar and its outer
--- border. Zero when the castbar is off or detached.
+-- Room a docked castbar takes next to its frame: gap, bar and the unit's
+-- outer border beyond it. Zero when the castbar is off or detached.
 function Castbar.DockedDepth(scope)
     if not Castbar.Applies(scope) or not Config.Get(scope, "castbarEnabled")
         or Castbar.Placement(scope) == "DETACHED" then
         return 0
     end
-    return Castbar.Gap(scope) + barHeight(scope) + ns.Single.BorderSize(scope)
+    return Castbar.Gap(scope) + barHeight(scope) + ns.Border.Extent(scope)
 end
 
 -- Whole castbar size, icon included: the frame's width.
@@ -269,7 +271,6 @@ function Castbar.Style(frame)
     bar.bg:SetTexture(tex)
     bar.remain:SetTexture(tex)
     paint(bar)
-    ns.Single.DrawBorder(bar, scope)
     bar.icon:ClearAllPoints()
     bar.icon:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
     bar.icon:SetSize(height, height)
@@ -278,6 +279,12 @@ function Castbar.Style(frame)
     bar.box:SetPoint("TOPLEFT", bar, "TOPLEFT", showIcon and -height or 0, 0)
     bar.box:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
     ns.Corners.Fit(bar.clip, bar.box, ns.Corners.Radius(scope))
+    -- Docked, the frame's border takes the castbar in (Elements/Shape.lua).
+    if Castbar.Placement(scope) == "DETACHED" then
+        ns.Border.Draw(bar, scope, bar.box)
+    else
+        ns.Border.Hide(bar)
+    end
     local font = ns.Media.Font(Config.Get(scope, "fontFace"))
     local outline = Config.Get(scope, "fontOutline")
     local fontSize = math.min(Config.Get(scope, "fontSize"), Config.Get(scope, "castbarHeight"))
```

```diff
diff --git a/Elements/Shape.lua b/Elements/Shape.lua
index 9378c67..7c9b1e8 100644
--- a/Elements/Shape.lua
+++ b/Elements/Shape.lua
@@ -1,17 +1,43 @@
 local _, ns = ...
 
 -- The frame's outline: rounded corners of the whole block (bars and
--- portrait). Built after every other element, so all their textures are
--- listed (ns.Corners.Add) by then.
+-- portrait) and the outer border around the unit. Built after every other
+-- element, so all their textures are listed (ns.Corners.Add) and the
+-- castbar exists by then.
 local Shape = { name = "Shape" }
 ns.Shape = Shape
 
+-- The unit's box: the frame, and a docked castbar while it shows. A plain
+-- frame, so it may follow the castbar in combat.
+function Shape.FitBox(frame)
+    local scope, bar = frame.key, frame.castbar
+    local above, below = 0, 0
+    if bar and bar:IsShown() then
+        local reach = ns.Castbar.Gap(scope) + ns.Castbar.Height(scope)
+        local placement = ns.Castbar.Placement(scope)
+        if placement == "ABOVE" then above = reach elseif placement == "BELOW" then below = reach end
+    end
+    local box = frame.unitBox
+    box:ClearAllPoints()
+    box:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, above)
+    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -below)
+end
+
 function Shape.Build(frame)
     frame.clip = ns.Corners.Clipper(frame)
+    frame.unitBox = CreateFrame("Frame", nil, frame)
+    local bar = frame.castbar
+    if bar then
+        bar:HookScript("OnShow", function() Shape.FitBox(frame) end)
+        bar:HookScript("OnHide", function() Shape.FitBox(frame) end)
+    end
 end
 
 function Shape.Style(frame)
-    ns.Corners.Fit(frame.clip, frame, ns.Corners.Radius(frame.key))
+    local scope = frame.key
+    ns.Corners.Fit(frame.clip, frame, ns.Corners.Radius(scope))
+    Shape.FitBox(frame)
+    ns.Border.Draw(frame, scope, frame.unitBox)
 end
 
 function Shape.Update() end
```

```diff
diff --git a/ForeverUnitFrames.toc b/ForeverUnitFrames.toc
index 0aed2a0..8d516d9 100644
--- a/ForeverUnitFrames.toc
+++ b/ForeverUnitFrames.toc
@@ -16,6 +16,7 @@ Core\Storage.lua
 Core\Media.lua
 Core\Layout.lua
 Core\Corners.lua
+Core\Border.lua
 Units\Units.lua
 Elements\Health.lua
 Elements\Power.lua
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index 9480042..5182191 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -16,6 +16,7 @@ L.SETTING_backgroundColor = "Background color"
 L.SETTING_borderSize = "Border size"
 L.SETTING_borderColor = "Border color"
 L.SETTING_cornerRadius = "Corner radius"
+L.SETTING_borderPadding = "Border padding"
 L.SETTING_healthColorMode = "Health color"
 L.SETTING_healthColor = "Static health color"
 L.SETTING_enabled = "Enabled"
@@ -98,6 +99,8 @@ L.ENUM_titleColorMode_CLASS = "Class (players)"
 L.SECTION_portrait = "Portrait"
 L.SECTION_shape = "Shape"
 L.HINT_cornerRadius = "0 = square corners"
+L.HINT_borderSize = "0 = no border"
+L.HINT_borderPadding = "Gap between frame and border"
 L.SECTION_group = "Party layout"
 L.SECTION_castbar = "Castbar"
 L.SECTION_castbarContent = "Shown on the bar"
```

```diff
diff --git a/Options/Schema.lua b/Options/Schema.lua
index 47c30a1..d86ad65 100644
--- a/Options/Schema.lua
+++ b/Options/Schema.lua
@@ -7,7 +7,7 @@ Schema.GENERAL = {
         -- action: a two-click button under the rows (Options/Window.lua).
         { id = "font", keys = { "fontFace", "fontSize", "fontOutline", "fontShadow" }, action = "applyFontToFrames" },
         { id = "bars", keys = { "barTexture", "backgroundColor" } },
-        { id = "border", keys = { "borderSize", "borderColor" } },
+        { id = "border", keys = { "borderSize", "borderPadding", "borderColor" } },
         { id = "shape", keys = { "cornerRadius" } },
     } },
     { id = "colors", sections = {
@@ -28,7 +28,7 @@ Schema.FRAME = {
     { id = "bars", sections = {
         { id = "health", keys = { "healthColorMode", "healthColor" } },
         { id = "textures", keys = { "barTexture", "backgroundColor" } },
-        { id = "border", keys = { "borderSize", "borderColor" } },
+        { id = "border", keys = { "borderSize", "borderPadding", "borderColor" } },
         { id = "shape", keys = { "cornerRadius" } },
     } },
     { id = "text", sections = {
```

```diff
diff --git a/Options/Window.lua b/Options/Window.lua
index 9f46583..dbc24db 100644
--- a/Options/Window.lua
+++ b/Options/Window.lua
@@ -92,7 +92,7 @@ end
 
 -- Drawn just outside the frame's own border.
 local function anchorOutline(unitFrame, edges)
-    local o = ns.Single.BorderSize(unitFrame.key)
+    local o = ns.Border.Extent(unitFrame.key)
     local hw = ns.Pixel.Snap(HIGHLIGHT_W, nil, 1)
     local w = o + hw
     for _, t in ipairs(edges) do t:ClearAllPoints() end
```

```diff
diff --git a/Units/Single.lua b/Units/Single.lua
index 75d1a71..4dda09d 100644
--- a/Units/Single.lua
+++ b/Units/Single.lua
@@ -14,12 +14,9 @@ function Single.Size(scope)
     return Pixel.Snap(Config.Get(scope, "width")), Pixel.Snap(Config.Get(scope, "height"))
 end
 
--- Border thickness of scope on the pixel grid: at least one pixel unless
--- the border is off.
+-- Border thickness of scope on the pixel grid (ns.Border.Size).
 function Single.BorderSize(scope)
-    local size = Config.Get(scope, "borderSize")
-    if size <= 0 then return 0 end
-    return Pixel.Snap(size, nil, 1)
+    return ns.Border.Size(scope)
 end
 
 local function place(frame)
@@ -72,27 +69,6 @@ local function layoutBars(frame)
     frame.gap = gap
 end
 
--- A 1-2 px border just outside owner (a unit frame or its castbar), in the
--- border size and colour of scope.
-function Single.DrawBorder(owner, scope)
-    local size = Single.BorderSize(scope)
-    local c = Config.Get(scope, "borderColor")
-    if not owner.border then
-        owner.border = {}
-        for i = 1, 4 do owner.border[i] = owner:CreateTexture(nil, "OVERLAY") end
-    end
-    local b = owner.border
-    -- top, bottom, left, right; drawn just outside the owner
-    b[1]:ClearAllPoints(); b[1]:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", -size, 0); b[1]:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", size, 0); b[1]:SetHeight(size)
-    b[2]:ClearAllPoints(); b[2]:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", -size, 0); b[2]:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", size, 0); b[2]:SetHeight(size)
-    b[3]:ClearAllPoints(); b[3]:SetPoint("TOPRIGHT", owner, "TOPLEFT", 0, 0); b[3]:SetPoint("BOTTOMRIGHT", owner, "BOTTOMLEFT", 0, 0); b[3]:SetWidth(size)
-    b[4]:ClearAllPoints(); b[4]:SetPoint("TOPLEFT", owner, "TOPRIGHT", 0, 0); b[4]:SetPoint("BOTTOMLEFT", owner, "BOTTOMRIGHT", 0, 0); b[4]:SetWidth(size)
-    for i = 1, 4 do
-        b[i]:SetColorTexture(c[1], c[2], c[3], c[4])
-        b[i]:SetShown(size > 0)
-    end
-end
-
 local function applyEnabled(frame)
     if Config.Get(frame.key, "enabled") then
         RegisterUnitWatch(frame)
@@ -107,11 +83,11 @@ function Single.UpdateAll(frame, event)
     for _, el in ipairs(ns.Elements) do el.Update(frame, event) end
 end
 
--- Everything inside a unit button that is not itself protected: bars,
--- border, element regions. Party buttons use this in combat too.
+-- Everything inside a unit button that is not itself protected: bars and
+-- element regions (the border is Elements/Shape.lua). Party buttons use
+-- this in combat too.
 function Single.StyleContent(frame)
     layoutBars(frame)
-    Single.DrawBorder(frame, frame.key)
     for _, el in ipairs(ns.Elements) do el.Style(frame) end
 end
 
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `tests/run`
Expected: `2819 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Border.lua Core/Settings.lua Elements/Castbar.lua Elements/Shape.lua ForeverUnitFrames.toc Locales/enUS.lua Options/Schema.lua Options/Window.lua Units/Single.lua tests/test_border.lua
git commit -F - <<'EOF'
Outer border: up to 8 px, padding, one ring around frame and docked castbar

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 5: Absorb shields

A status bar over the health bar, filling from its right end, shows the unit's total absorbs on the scale of its maximum health. Values pass straight through (they are secret in combat). Per-frame toggle `absorbEnabled` (`AB`), inherited colour `absorbColor` (`AC`). Adds the frame overlay layer (texts above shields) and a generic test-mode preview hook.

**Files:**
- Create: `Elements/Absorb.lua`
- Modify: `Core/Settings.lua`
- Modify: `Elements/Health.lua`
- Modify: `Elements/Texts.lua`
- Modify: `ForeverUnitFrames.toc`
- Modify: `Locales/enUS.lua`
- Modify: `Options/Schema.lua`
- Modify: `Options/TestMode.lua`
- Modify: `Units/Party.lua`
- Modify: `Units/Single.lua`
- Test (new): `tests/test_absorb.lua`
- Test (modify): `tests/mock.lua`

**Interfaces:**
- Consumes: `UnitGetTotalAbsorbs`, `UnitHealthMax`, `ns.Corners.Add`, `ns.Media.StatusBar`.
- Produces:
  - `frame.overlay` — plain frame over the whole unit frame, level `frame + 10`; title and health texts live on it (power texts stay on the power bar).
  - `frame.absorb` — reverse-filled StatusBar over `frame.health`, level `health + 2`.
  - `ns.Absorb.SAMPLE` (0.3), `ns.Absorb.Preview(frame, on)`.
  - `ns.Single.Preview(frame, on)` — calls `Preview(frame, on)` of every element that has one; test mode and the pretend party use it instead of `ns.Castbar.Preview`.
  - Mock: `SetFrameLevel` / `GetFrameLevel` (new frames start one above their parent), `SetClipsChildren`, `UnitGetTotalAbsorbs` (`d.absorbs`), `UnitGetIncomingHeals` (`d.healsAll`, `d.healsMine`).

- [ ] **Step 1: Write the failing test**

Changes to existing test files (mock support and expectations that change with this task):

```diff
diff --git a/tests/mock.lua b/tests/mock.lua
index af218f3..bbfcb51 100644
--- a/tests/mock.lua
+++ b/tests/mock.lua
@@ -195,6 +195,10 @@ local function newWidget(kind, name, parent)
     function w:EnableMouse(v) self._mouse = v end
     function w:IsProtected() return self._protected or false end
     function w:SetFrameStrata(v) self._strata = v end
+    -- Frame level: CreateFrame starts a frame one above its parent.
+    function w:SetFrameLevel(v) self._level = v end
+    function w:GetFrameLevel() return self._level or 0 end
+    function w:SetClipsChildren(v) self._clips = v end
     function w:GetFrameStrata() return self._strata end
     function w:GetEffectiveScale() return M.scale end
     -- StatusBar
@@ -381,6 +385,7 @@ function M.Reset()
         w._template = template
         if template and template:find("Secure") then w._protected = true end
         if kind == "StatusBar" then w._barTex = newWidget("Texture", nil, w) end
+        w._level = (parent and parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 1
         if name then _G[name] = w end
         table.insert(M.frames, w)
         if template == "SecureGroupHeaderTemplate" then makeGroupHeader(w) end
@@ -452,6 +457,15 @@ function M.Reset()
     _G.UnitChannelDuration = function(unit) local d = u(unit); return d and d.castDuration end
     _G.C_StringUtil = { TruncateWhenZero = function(n) return n end }
     _G.UnitPowerMissing = function(unit) local d = u(unit); return d and d.powerMissing or 0 end
+    -- Shields and heals: d.absorbs; d.healsAll / d.healsMine (nil like the
+    -- client when nothing is known).
+    _G.UnitGetTotalAbsorbs = function(unit) local d = u(unit); return d and d.absorbs or 0 end
+    _G.UnitGetIncomingHeals = function(unit, healer)
+        local d = u(unit)
+        if not d then return nil end
+        if healer == "player" then return d.healsMine end
+        return d.healsAll
+    end
 
     _G.C_Timer = { After = function(sec, fn) table.insert(M.timers, { sec = sec, fn = fn }) end }
 
```

**New file `tests/test_absorb.lua`:**

```lua
local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

H.check("toggle code", S.Get("absorbEnabled").code, "AB")
H.check("toggle per frame", S.Get("absorbEnabled").scope, "frame")
H.check("colour code", S.Get("absorbColor").code, "AC")
H.check("colour inherited", S.Get("absorbColor").scope, "inherit")

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
local f = ns.Frames.player
local bar = f.absorb

-- A bar over the health bar, filling from the right.
H.check("on the health bar", bar:GetParent(), f.health)
H.check("covers it", bar._allPoints, f.health)
H.checkTrue("fills from the right end", bar._reverse)
H.checkTrue("above the health bar", bar:GetFrameLevel() > f.health:GetFrameLevel())
H.checkTrue("shown by default", bar:IsShown())
H.check("colour", bar._color[4], 0.45)

-- Health texts stay on top of it; power texts stay on their bar.
H.check("health text on the overlay", f.texts.healthLeft:GetParent(), f.overlay)
H.checkTrue("overlay above the shield", f.overlay:GetFrameLevel() > bar:GetFrameLevel())
H.check("power text on its bar", f.texts.powerRight:GetParent(), f.power)

-- Secret values pass straight through.
local shield, hpMax = M.Secret(300), M.Secret(1000)
M.units.player = { name = "Me", health = M.Secret(900), healthMax = hpMax, absorbs = shield }
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("value is the secret", bar:GetValue(), shield)
H.check("max is the secret", select(2, bar:GetMinMaxValues()), hpMax)
M.units.player.absorbs = nil
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("no shield: empty", bar:GetValue(), 0)
M.units.player.absorbs = 50
M.units.player.healthMax = 200
M.FireEvent("UNIT_MAXHEALTH", "player")
H.check("max health change rescales", select(2, bar:GetMinMaxValues()), 200)

-- Colour from General, overridable per frame.
C.Set("general", "absorbColor", { 1, 1, 1, 0.5 })
H.check("general colour", bar._color[4], 0.5)
C.Set("player", "absorbColor", { 0, 0, 1, 0.8 })
H.check("own colour", bar._color[3], 1)

-- Off: hidden and left alone.
C.Set("player", "absorbEnabled", false)
H.check("off: hidden", bar:IsShown(), false)
M.units.player.absorbs = 99
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("off: not updated", bar:GetValue(), 50)
C.Set("player", "absorbEnabled", true)

-- Rounded with the frame.
C.Set("general", "cornerRadius", 4)
H.check("shield rounded", bar:GetStatusBarTexture():GetNumMaskTextures(), 4)
C.Set("general", "cornerRadius", 0)

-- Test mode: a sample shield, real events ignored until it ends.
ns.TestMode.Set(true)
H.check("sample shield", bar:GetValue(), ns.Absorb.SAMPLE)
H.check("sample scale", select(2, bar:GetMinMaxValues()), 1)
M.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
H.check("sample kept", bar:GetValue(), ns.Absorb.SAMPLE)
H.check("target shows a sample too", ns.Frames.target.absorb:GetValue(), ns.Absorb.SAMPLE)
H.check("pretend party too", ns.Party.fakes[1].absorb:GetValue(), ns.Absorb.SAMPLE)
ns.TestMode.Set(false)
H.check("real value back", bar:GetValue(), 99)
H.check("preview flag cleared", bar.preview, nil)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`

Expected: FAIL — `absorbEnabled` is not defined. The output ends with:

```
  ERROR test_absorb.lua:5: attempt to index a nil value
2819 passed, 1 failed
```

- [ ] **Step 3: Implement**

**New file `Elements/Absorb.lua`:**

```lua
local _, ns = ...

-- Absorb shields: a bar over the health bar, filling from its right end,
-- as long as the unit's total absorbs on a scale of its maximum health.
-- Both values may be secret; the status bar takes them as they are and
-- clamps at the bar's end itself.
local Absorb = { name = "Absorb", unitEvents = { "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_MAXHEALTH" } }
ns.Absorb = Absorb

local Config = ns.Config

-- Test mode: a shield of 30 % of maximum health.
Absorb.SAMPLE = 0.3

function Absorb.Build(frame)
    local bar = CreateFrame("StatusBar", nil, frame.health)
    bar:SetAllPoints(frame.health)
    bar:SetFrameLevel(frame.health:GetFrameLevel() + 2)
    bar:SetReverseFill(true)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    frame.absorb = bar
    ns.Corners.Add(frame, function() return bar:GetStatusBarTexture() end)
end

function Absorb.Style(frame)
    local bar, scope = frame.absorb, frame.key
    bar:SetStatusBarTexture(ns.Media.StatusBar(Config.Get(scope, "barTexture")))
    local c = Config.Get(scope, "absorbColor")
    bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
    bar:SetShown(Config.Get(scope, "absorbEnabled"))
end

function Absorb.Update(frame)
    local bar = frame.absorb
    if bar.preview or not Config.Get(frame.key, "absorbEnabled") then return end
    local amount = UnitGetTotalAbsorbs(frame.unit)
    -- Presence is asked with type(): a secret cannot be tested by truth.
    if type(amount) == "nil" then amount = 0 end
    bar:SetMinMaxValues(0, UnitHealthMax(frame.unit))
    bar:SetValue(amount)
end

function Absorb.Preview(frame, on)
    local bar = frame.absorb
    bar.preview = on or nil
    if not on then return end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(Absorb.SAMPLE)
end

ns.RegisterElement(Absorb)
```

Changes to existing files (unified diffs against the previous task's state; `git apply` them or edit by hand):

```diff
diff --git a/Core/Settings.lua b/Core/Settings.lua
index 34c2fdb..6c4e4e1 100644
--- a/Core/Settings.lua
+++ b/Core/Settings.lua
@@ -104,6 +104,7 @@ Settings.Define({ key = "cornerRadius", code = "CR", scope = "inherit", type = "
 Settings.Define({ key = "healthColorMode", code = "HM", scope = "inherit", type = "enum",
     values = { "CLASS", "REACTION", "STATIC", "GRADIENT" }, default = "STATIC" })
 Settings.Define({ key = "healthColor", code = "HC", scope = "inherit", type = "color", default = { 0.2, 0.75, 0.3, 1 } })
+Settings.Define({ key = "absorbColor", code = "AC", scope = "inherit", type = "color", default = { 0.8, 0.9, 1, 0.45 } })
 
 -- Frame layout
 Settings.Define({ key = "enabled", code = "E", scope = "frame", type = "bool", default = true })
@@ -120,6 +121,7 @@ Settings.Define({ key = "healthPercent", code = "HP", scope = "frame", type = "i
     default = { player = 45, target = 45, focus = 45, _ = 75 } })
 Settings.Define({ key = "powerPercent", code = "PP", scope = "frame", type = "int", min = 0, max = 90, default = 25 })
 Settings.Define({ key = "powerEnabled", code = "PE", scope = "frame", type = "bool", default = true })
+Settings.Define({ key = "absorbEnabled", code = "AB", scope = "frame", type = "bool", default = true })
 Settings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000,
     default = { player = -300, target = 300, targettarget = 480, pet = -352, focus = -300, party = -760, _ = 0 } })
 Settings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000,
```

```diff
diff --git a/Elements/Health.lua b/Elements/Health.lua
index 0935681..6b7bd01 100644
--- a/Elements/Health.lua
+++ b/Elements/Health.lua
@@ -73,6 +73,11 @@ function Health.Build(frame)
     -- is Elements/Texts.lua's.
     frame.title = frame:CreateTexture(nil, "BACKGROUND")
     frame.health = CreateFrame("StatusBar", nil, frame)
+    -- Above the bars, their overlays and a 3D portrait: health texts and
+    -- markers live here.
+    frame.overlay = CreateFrame("Frame", nil, frame)
+    frame.overlay:SetAllPoints(frame)
+    frame.overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
     frame.healthBg = frame.health:CreateTexture(nil, "BACKGROUND")
     frame.healthBg:SetAllPoints(frame.health)
     ns.Corners.Add(frame, frame.title)
```

```diff
diff --git a/Elements/Texts.lua b/Elements/Texts.lua
index eba356f..6f2869f 100644
--- a/Elements/Texts.lua
+++ b/Elements/Texts.lua
@@ -142,9 +142,9 @@ end
 function Texts.Build(frame)
     frame.texts = {}
     for _, slot in ipairs(SLOTS) do
-        -- Parent to the bar so the text sits above it; the title row is a
-        -- texture, its text goes on the frame.
-        local parent = slot.bar == "title" and frame or frame[slot.bar]
+        -- Title and health texts sit on the overlay, above shields and
+        -- heals; power texts on their bar, so they hide with it.
+        local parent = slot.bar == "power" and frame.power or frame.overlay
         frame.texts[slot.field] = parent:CreateFontString(nil, "OVERLAY")
     end
 end
```

```diff
diff --git a/ForeverUnitFrames.toc b/ForeverUnitFrames.toc
index 8d516d9..ebc7cdc 100644
--- a/ForeverUnitFrames.toc
+++ b/ForeverUnitFrames.toc
@@ -19,6 +19,7 @@ Core\Corners.lua
 Core\Border.lua
 Units\Units.lua
 Elements\Health.lua
+Elements\Absorb.lua
 Elements\Power.lua
 Elements\Texts.lua
 Elements\Portrait.lua
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index 5182191..b1fa4e7 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -17,6 +17,8 @@ L.SETTING_borderSize = "Border size"
 L.SETTING_borderColor = "Border color"
 L.SETTING_cornerRadius = "Corner radius"
 L.SETTING_borderPadding = "Border padding"
+L.SETTING_absorbEnabled = "Show absorb shields"
+L.SETTING_absorbColor = "Absorb shield color"
 L.SETTING_healthColorMode = "Health color"
 L.SETTING_healthColor = "Static health color"
 L.SETTING_enabled = "Enabled"
@@ -98,6 +100,8 @@ L.ENUM_WHITE = "White"
 L.ENUM_titleColorMode_CLASS = "Class (players)"
 L.SECTION_portrait = "Portrait"
 L.SECTION_shape = "Shape"
+L.SECTION_absorbs = "Absorb shields"
+L.HINT_absorbEnabled = "Over the end of the health bar"
 L.HINT_cornerRadius = "0 = square corners"
 L.HINT_borderSize = "0 = no border"
 L.HINT_borderPadding = "Gap between frame and border"
```

```diff
diff --git a/Options/Schema.lua b/Options/Schema.lua
index d86ad65..907b885 100644
--- a/Options/Schema.lua
+++ b/Options/Schema.lua
@@ -12,6 +12,7 @@ Schema.GENERAL = {
     } },
     { id = "colors", sections = {
         { id = "health", keys = { "healthColorMode", "healthColor" } },
+        { id = "absorbs", keys = { "absorbColor" } },
     } },
     { id = "profile", custom = "profile" },
 }
@@ -28,6 +29,7 @@ Schema.FRAME = {
     { id = "bars", sections = {
         { id = "health", keys = { "healthColorMode", "healthColor" } },
         { id = "textures", keys = { "barTexture", "backgroundColor" } },
+        { id = "absorbs", keys = { "absorbEnabled", "absorbColor" } },
         { id = "border", keys = { "borderSize", "borderPadding", "borderColor" } },
         { id = "shape", keys = { "cornerRadius" } },
     } },
```

```diff
diff --git a/Options/TestMode.lua b/Options/TestMode.lua
index 15d9c06..0503495 100644
--- a/Options/TestMode.lua
+++ b/Options/TestMode.lua
@@ -1,7 +1,8 @@
 local _, ns = ...
 
 -- Shows every enabled frame with the player's data, so frames can be
--- configured without a target, and a sample cast on every castbar. The
+-- configured without a target, and sample data (a cast, a shield, ...)
+-- from every element that has a Preview. The
 -- party block is replaced by a pretend party (Units/Party.lua). Only
 -- touches secure attributes and unit watch out of combat (existing
 -- ns.AfterCombat paths).
@@ -23,7 +24,7 @@ local function applyOn(frame)
     ns.Single.SetUnit(frame, "player")
     UnregisterUnitWatch(frame)
     frame:Show()
-    ns.Castbar.Preview(frame, true)
+    ns.Single.Preview(frame, true)
     ns.Single.UpdateAll(frame)
 end
 
@@ -34,7 +35,7 @@ local function applyOff(frame)
     local unit = saved[frame]
     saved[frame] = nil
     ns.Single.SetUnit(frame, unit)
-    ns.Castbar.Preview(frame, false)
+    ns.Single.Preview(frame, false)
     if ns.Config.Get(frame.key, "enabled") then
         RegisterUnitWatch(frame)
     else
```

```diff
diff --git a/Units/Party.lua b/Units/Party.lua
index 16c9dd2..4402110 100644
--- a/Units/Party.lua
+++ b/Units/Party.lua
@@ -132,7 +132,7 @@ end
 -- binds the button again.
 local function releaseFake(button)
     button:Hide()
-    ns.Castbar.Preview(button, false)
+    Single.Preview(button, false)
     button.unit = nil
     ns.UnitEvents.Bind(button)
 end
@@ -172,7 +172,7 @@ local function showFakes()
         button:ClearAllPoints()
         button:SetPoint("TOPLEFT", block, "TOPLEFT", Party.SlotOffset(i))
         Party.StyleButton(button)
-        ns.Castbar.Preview(button, true)
+        Single.Preview(button, true)
         button:Show()
     end
     for i = slots + 1, #Party.fakes do releaseFake(Party.fakes[i]) end
```

```diff
diff --git a/Units/Single.lua b/Units/Single.lua
index 4dda09d..a045350 100644
--- a/Units/Single.lua
+++ b/Units/Single.lua
@@ -78,6 +78,13 @@ local function applyEnabled(frame)
     end
 end
 
+-- Test mode: every element with sample data shows (or drops) it.
+function Single.Preview(frame, on)
+    for _, el in ipairs(ns.Elements) do
+        if el.Preview then el.Preview(frame, on) end
+    end
+end
+
 function Single.UpdateAll(frame, event)
     if not frame.unit or not UnitExists(frame.unit) then return end
     for _, el in ipairs(ns.Elements) do el.Update(frame, event) end
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `tests/run`
Expected: `2874 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Settings.lua Elements/Absorb.lua Elements/Health.lua Elements/Texts.lua ForeverUnitFrames.toc Locales/enUS.lua Options/Schema.lua Options/TestMode.lua Units/Party.lua Units/Single.lua tests/mock.lua tests/test_absorb.lua
git commit -F - <<'EOF'
Show absorb shields over the health bar

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 6: Incoming heals and the overheal lane

Two status bars start at the right edge of the health fill, as wide as the health bar and on its scale: all incoming heals (other-heals colour) under yours (your colour). A clipping frame cuts them at full health, or at the end of an optional overheal lane that takes the last 8 % (at least 4) of the health row. Settings `healPrediction` (`IH`), `healOverflow` (`OV`), `healMyColor` (`MC`), `healOtherColor` (`OC`).

**Files:**
- Create: `Elements/HealPrediction.lua`
- Modify: `Core/Layout.lua`
- Modify: `Core/Settings.lua`
- Modify: `ForeverUnitFrames.toc`
- Modify: `Locales/enUS.lua`
- Modify: `Options/Schema.lua`
- Modify: `Units/Single.lua`
- Test (new): `tests/test_heal_prediction.lua`

**Interfaces:**
- Consumes: `UnitGetIncomingHeals(unit[, healer])`, `UnitHealthMax`, `frame.health:GetStatusBarTexture()`, `ns.Corners.Add`.
- Produces:
  - `ns.Layout.OverhealLane(barWidth)` → `max(4, round(barWidth * 0.08))`.
  - `frame.healthWidth` (health bar width without the lane), `frame.overhealLane` (snapped lane width, 0 when off) — set by `layoutBars` in `Units/Single.lua`.
  - `frame.healClip` (clips children, over health + lane), `frame.healAll`, `frame.healMine` (StatusBars), `frame.overhealBg` (lane background).
  - `ns.HealPrediction.SAMPLE_ALL` (0.25), `SAMPLE_MINE` (0.12), `Preview(frame, on)`.

- [ ] **Step 1: Write the failing test**

**New file `tests/test_heal_prediction.lua`:**

```lua
local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

for key, code in pairs({ healPrediction = "IH", healOverflow = "OV", healMyColor = "MC", healOtherColor = "OC" }) do
    H.check(key .. " code", S.Get(key).code, code)
end
H.check("toggle per frame", S.Get("healPrediction").scope, "frame")
H.check("colours inherited", S.Get("healMyColor").scope, "inherit")
H.check("lane off by default", S.Default(S.Get("healOverflow"), "player"), false)
H.check("lane width", ns.Layout.OverhealLane(220), 18)
H.check("lane at least 4", ns.Layout.OverhealLane(30), 4)

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
local f = ns.Frames.player
local clip, all, mine = f.healClip, f.healAll, f.healMine
local fill = f.health:GetStatusBarTexture()
local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

-- Two bars in a clipping frame over the health bar.
H.checkTrue("clips", clip._clips)
H.check("clip on the health bar", clip:GetParent(), f.health)
H.check("clip ends with the bar", point(clip, "BOTTOMRIGHT")[4], 0)
H.check("all heals in the clip", all:GetParent(), clip)
H.checkTrue("yours above", mine:GetFrameLevel() > all:GetFrameLevel())
H.checkTrue("below the shield", clip:GetFrameLevel() < f.absorb:GetFrameLevel())
for name, bar in pairs({ all = all, mine = mine }) do
    H.check(name .. ": starts at the health fill", point(bar, "TOPLEFT")[2], fill)
    H.check(name .. ": at its right edge", point(bar, "TOPLEFT")[3], "TOPRIGHT")
    H.check(name .. ": bottom too", point(bar, "BOTTOMLEFT")[3], "BOTTOMRIGHT")
    H.check(name .. ": as wide as the health bar", bar:GetWidth(), 220)
end
H.check("your colour", mine._color[2], 0.95)
H.check("others' colour", all._color[2], 0.65)
H.check("no lane", f.overhealBg:IsShown(), false)

-- Secret values pass straight through.
local hpMax, allV, mineV = M.Secret(1000), M.Secret(200), M.Secret(120)
M.units.player = { name = "Me", health = M.Secret(500), healthMax = hpMax, healsAll = allV, healsMine = mineV }
M.FireEvent("UNIT_HEAL_PREDICTION", "player")
H.check("all heals: the secret", all:GetValue(), allV)
H.check("yours: the secret", mine:GetValue(), mineV)
H.check("scale: maximum health", select(2, mine:GetMinMaxValues()), hpMax)
M.units.player.healsAll, M.units.player.healsMine = nil, nil
M.FireEvent("UNIT_HEAL_PREDICTION", "player")
H.check("nothing known: empty", all:GetValue(), 0)
H.check("nothing known: yours empty", mine:GetValue(), 0)

-- Colours from General, per frame override.
C.Set("general", "healMyColor", { 1, 1, 0, 1 })
H.check("general colour", mine._color[1], 1)
C.Set("player", "healOtherColor", { 0, 0, 1, 1 })
H.check("own colour", all._color[3], 1)

-- Overheal lane: the health bar gives up the end of its row.
C.Set("player", "healOverflow", true)
local lane = f.overhealLane
H.check("lane width", lane, 18)
H.check("health bar shorter", point(f.health, "TOPRIGHT")[4], -18)
H.check("power bar keeps the width", point(f.power, "BOTTOMRIGHT")[4], 0)
H.check("clip reaches into the lane", point(clip, "BOTTOMRIGHT")[4], 18)
H.check("bars on the health scale", mine:GetWidth(), 220 - 18)
H.checkTrue("lane background", f.overhealBg:IsShown())
H.check("lane right of the bar", point(f.overhealBg, "TOPLEFT")[3], "TOPRIGHT")
H.check("lane in the background colour", f.overhealBg._color[4], C.Get("player", "backgroundColor")[4])

-- Off: no bars, no lane.
C.Set("player", "healPrediction", false)
H.check("off: hidden", clip:IsShown(), false)
H.check("off: no lane", f.overhealLane, 0)
H.check("off: full bar", point(f.health, "TOPRIGHT")[4], 0)
M.units.player.healsAll = 5
M.FireEvent("UNIT_HEAL_PREDICTION", "player")
H.check("off: not updated", all:GetValue(), 0)
C.Set("player", "healPrediction", true)

-- Rounded with the frame.
C.Set("general", "cornerRadius", 4)
H.check("heals rounded", mine:GetStatusBarTexture():GetNumMaskTextures(), 4)
H.check("lane rounded", f.overhealBg:GetNumMaskTextures(), 4)
C.Set("general", "cornerRadius", 0)

-- Test mode: sample heals.
ns.TestMode.Set(true)
H.check("sample: all", all:GetValue(), ns.HealPrediction.SAMPLE_ALL)
H.check("sample: yours", mine:GetValue(), ns.HealPrediction.SAMPLE_MINE)
H.check("sample scale", select(2, all:GetMinMaxValues()), 1)
M.FireEvent("UNIT_HEAL_PREDICTION", "player")
H.check("sample kept", all:GetValue(), ns.HealPrediction.SAMPLE_ALL)
H.check("party sample", ns.Party.fakes[2].healMine:GetValue(), ns.HealPrediction.SAMPLE_MINE)
ns.TestMode.Set(false)
H.check("real value back", all:GetValue(), 5)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`

Expected: FAIL — `healPrediction` is not defined. The output ends with:

```
  ERROR test_heal_prediction.lua:6: attempt to index a nil value
2874 passed, 1 failed
```

- [ ] **Step 3: Implement**

**New file `Elements/HealPrediction.lua`:**

```lua
local _, ns = ...

-- Incoming heals: two status bars starting where the health fill ends,
-- each as wide as the health bar and on the same scale (0 .. maximum
-- health), so a point of healing is as wide as a point of health. The
-- lower bar holds all incoming heals in the other-heals colour, the upper
-- one only yours: what shows of the lower one past yours is everyone
-- else's. No value is added, subtracted or compared; they may be secret.
-- A clipping frame over the health bar cuts them at full health, or at
-- the end of the overheal lane when that is on (Units/Single.lua makes
-- the room).
local HealPrediction = {
    name = "HealPrediction",
    unitEvents = { "UNIT_HEAL_PREDICTION", "UNIT_HEALTH", "UNIT_MAXHEALTH" },
}
ns.HealPrediction = HealPrediction

local Config = ns.Config

-- Test mode: 25 % of maximum health coming in, 12 % of it yours.
HealPrediction.SAMPLE_ALL, HealPrediction.SAMPLE_MINE = 0.25, 0.12

function HealPrediction.Build(frame)
    local clip = CreateFrame("Frame", nil, frame.health)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(frame.health:GetFrameLevel() + 1)
    local all = CreateFrame("StatusBar", nil, clip)
    local mine = CreateFrame("StatusBar", nil, clip)
    mine:SetFrameLevel(all:GetFrameLevel() + 1)
    for _, bar in ipairs({ all, mine }) do
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
    end
    -- The empty lane looks like the rest of the bar's background.
    frame.overhealBg = frame:CreateTexture(nil, "BACKGROUND")
    frame.healClip, frame.healAll, frame.healMine = clip, all, mine
    ns.Corners.Add(frame, frame.overhealBg)
    ns.Corners.Add(frame, function() return all:GetStatusBarTexture() end)
    ns.Corners.Add(frame, function() return mine:GetStatusBarTexture() end)
end

function HealPrediction.Style(frame)
    local scope, health = frame.key, frame.health
    local lane = frame.overhealLane or 0
    local fill = health:GetStatusBarTexture()
    local tex = ns.Media.StatusBar(Config.Get(scope, "barTexture"))
    local clip = frame.healClip
    clip:ClearAllPoints()
    clip:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
    clip:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", lane, 0)
    clip:SetShown(Config.Get(scope, "healPrediction"))
    for _, pair in ipairs({ { frame.healAll, "healOtherColor" }, { frame.healMine, "healMyColor" } }) do
        local bar, key = pair[1], pair[2]
        bar:SetStatusBarTexture(tex)
        local c = Config.Get(scope, key)
        bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
        bar:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
        bar:SetWidth(frame.healthWidth)
    end
    local lanes = frame.overhealBg
    lanes:ClearAllPoints()
    lanes:SetPoint("TOPLEFT", health, "TOPRIGHT", 0, 0)
    lanes:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", lane, 0)
    lanes:SetTexture(tex)
    local bg = Config.Get(scope, "backgroundColor")
    lanes:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    lanes:SetShown(lane > 0)
end

local function show(bar, amount, maximum)
    if type(amount) == "nil" then amount = 0 end
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(amount)
end

function HealPrediction.Update(frame)
    if frame.healClip.preview or not Config.Get(frame.key, "healPrediction") then return end
    local unit = frame.unit
    local maximum = UnitHealthMax(unit)
    show(frame.healAll, UnitGetIncomingHeals(unit), maximum)
    show(frame.healMine, UnitGetIncomingHeals(unit, "player"), maximum)
end

function HealPrediction.Preview(frame, on)
    frame.healClip.preview = on or nil
    if not on then return end
    show(frame.healAll, HealPrediction.SAMPLE_ALL, 1)
    show(frame.healMine, HealPrediction.SAMPLE_MINE, 1)
end

ns.RegisterElement(HealPrediction)
```

Changes to existing files (unified diffs against the previous task's state; `git apply` them or edit by hand):

```diff
diff --git a/Core/Layout.lua b/Core/Layout.lua
index 547d6fb..b87e439 100644
--- a/Core/Layout.lua
+++ b/Core/Layout.lua
@@ -36,6 +36,12 @@ function Layout.Bars(height, healthPercent, powerPercent, powerEnabled)
     return healthH, gap, powerH
 end
 
+-- Width of the overheal lane at the end of a health bar of barWidth: 8 %,
+-- at least 4.
+function Layout.OverhealLane(barWidth)
+    return math.max(4, round(barWidth * 0.08))
+end
+
 -- Space the portrait takes from the bars: a square as tall as the frame,
 -- on the left or the right. Returns left inset, right inset.
 function Layout.PortraitInsets(mode, height)
```

```diff
diff --git a/Core/Settings.lua b/Core/Settings.lua
index 6c4e4e1..ba39050 100644
--- a/Core/Settings.lua
+++ b/Core/Settings.lua
@@ -105,6 +105,8 @@ Settings.Define({ key = "healthColorMode", code = "HM", scope = "inherit", type
     values = { "CLASS", "REACTION", "STATIC", "GRADIENT" }, default = "STATIC" })
 Settings.Define({ key = "healthColor", code = "HC", scope = "inherit", type = "color", default = { 0.2, 0.75, 0.3, 1 } })
 Settings.Define({ key = "absorbColor", code = "AC", scope = "inherit", type = "color", default = { 0.8, 0.9, 1, 0.45 } })
+Settings.Define({ key = "healMyColor", code = "MC", scope = "inherit", type = "color", default = { 0.3, 0.95, 0.45, 0.65 } })
+Settings.Define({ key = "healOtherColor", code = "OC", scope = "inherit", type = "color", default = { 0.15, 0.65, 0.3, 0.55 } })
 
 -- Frame layout
 Settings.Define({ key = "enabled", code = "E", scope = "frame", type = "bool", default = true })
@@ -122,6 +124,8 @@ Settings.Define({ key = "healthPercent", code = "HP", scope = "frame", type = "i
 Settings.Define({ key = "powerPercent", code = "PP", scope = "frame", type = "int", min = 0, max = 90, default = 25 })
 Settings.Define({ key = "powerEnabled", code = "PE", scope = "frame", type = "bool", default = true })
 Settings.Define({ key = "absorbEnabled", code = "AB", scope = "frame", type = "bool", default = true })
+Settings.Define({ key = "healPrediction", code = "IH", scope = "frame", type = "bool", default = true })
+Settings.Define({ key = "healOverflow", code = "OV", scope = "frame", type = "bool", default = false })
 Settings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000,
     default = { player = -300, target = 300, targettarget = 480, pet = -352, focus = -300, party = -760, _ = 0 } })
 Settings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000,
```

```diff
diff --git a/ForeverUnitFrames.toc b/ForeverUnitFrames.toc
index ebc7cdc..43c74c9 100644
--- a/ForeverUnitFrames.toc
+++ b/ForeverUnitFrames.toc
@@ -19,6 +19,7 @@ Core\Corners.lua
 Core\Border.lua
 Units\Units.lua
 Elements\Health.lua
+Elements\HealPrediction.lua
 Elements\Absorb.lua
 Elements\Power.lua
 Elements\Texts.lua
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index b1fa4e7..78a4c53 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -19,6 +19,10 @@ L.SETTING_cornerRadius = "Corner radius"
 L.SETTING_borderPadding = "Border padding"
 L.SETTING_absorbEnabled = "Show absorb shields"
 L.SETTING_absorbColor = "Absorb shield color"
+L.SETTING_healPrediction = "Show incoming heals"
+L.SETTING_healOverflow = "Overheal lane"
+L.SETTING_healMyColor = "Your heals color"
+L.SETTING_healOtherColor = "Other heals color"
 L.SETTING_healthColorMode = "Health color"
 L.SETTING_healthColor = "Static health color"
 L.SETTING_enabled = "Enabled"
@@ -102,6 +106,8 @@ L.SECTION_portrait = "Portrait"
 L.SECTION_shape = "Shape"
 L.SECTION_absorbs = "Absorb shields"
 L.HINT_absorbEnabled = "Over the end of the health bar"
+L.SECTION_healPrediction = "Incoming heals"
+L.HINT_healOverflow = "Shows heals past full health"
 L.HINT_cornerRadius = "0 = square corners"
 L.HINT_borderSize = "0 = no border"
 L.HINT_borderPadding = "Gap between frame and border"
```

```diff
diff --git a/Options/Schema.lua b/Options/Schema.lua
index 907b885..c1004af 100644
--- a/Options/Schema.lua
+++ b/Options/Schema.lua
@@ -13,6 +13,7 @@ Schema.GENERAL = {
     { id = "colors", sections = {
         { id = "health", keys = { "healthColorMode", "healthColor" } },
         { id = "absorbs", keys = { "absorbColor" } },
+        { id = "healPrediction", keys = { "healMyColor", "healOtherColor" } },
     } },
     { id = "profile", custom = "profile" },
 }
@@ -30,6 +31,7 @@ Schema.FRAME = {
         { id = "health", keys = { "healthColorMode", "healthColor" } },
         { id = "textures", keys = { "barTexture", "backgroundColor" } },
         { id = "absorbs", keys = { "absorbEnabled", "absorbColor" } },
+        { id = "healPrediction", keys = { "healPrediction", "healOverflow", "healMyColor", "healOtherColor" } },
         { id = "border", keys = { "borderSize", "borderPadding", "borderColor" } },
         { id = "shape", keys = { "cornerRadius" } },
     } },
```

```diff
diff --git a/Units/Single.lua b/Units/Single.lua
index a045350..e3ad69f 100644
--- a/Units/Single.lua
+++ b/Units/Single.lua
@@ -55,9 +55,17 @@ local function layoutBars(frame)
     title:SetHeight(math.max(titleH, pixel))
     title:SetShown(titleH > 0)
     frame.titleHeight = titleH
+    local width = Single.Size(scope) - left - right
+    -- The overheal lane (Elements/HealPrediction.lua) takes the end of
+    -- the health bar's row; title and power bar keep the full width.
+    local lane = 0
+    if Config.Get(scope, "healPrediction") and Config.Get(scope, "healOverflow") then
+        lane = Pixel.Snap(Layout.OverhealLane(width))
+    end
+    frame.healthWidth, frame.overhealLane = width - lane, lane
     frame.health:ClearAllPoints()
     frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -titleH)
-    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, -titleH)
+    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(right + lane), -titleH)
     frame.health:SetHeight(healthH)
     if frame.power then
         frame.power:ClearAllPoints()
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `tests/run`
Expected: `2977 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Layout.lua Core/Settings.lua Elements/HealPrediction.lua ForeverUnitFrames.toc Locales/enUS.lua Options/Schema.lua Units/Single.lua tests/test_heal_prediction.lua
git commit -F - <<'EOF'
Show incoming heals with an optional overheal lane

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 7: Elite / rare / boss marker

Target, Focus, Target of Target and Party show what the unit is: with a portrait, Blizzard's nameplate badge on the portrait's outer top corner; without, a short word (Boss, Elite, Rare Elite, Rare) above the frame's top right corner. Setting `eliteMarker` (`EM`, those four frames only).

**Files:**
- Create: `Elements/Classification.lua`
- Modify: `Core/Settings.lua`
- Modify: `ForeverUnitFrames.toc`
- Modify: `Locales/enUS.lua`
- Modify: `Options/Schema.lua`
- Test (new): `tests/test_classification.lua`
- Test (modify): `tests/mock.lua`

**Interfaces:**
- Consumes: `UnitClassification`, `UnitIsBossMob`, `frame.overlay`, `frame.portraitBg`, `ns.Border.Extent`, `ns.Texts.SetFont`.
- Produces:
  - `ns.Classification.Kind(unit)` → `"boss"`, `"elite"`, `"rareelite"`, `"rare"` or `nil` (secret / other → nil).
  - `ns.Classification.MARKERS[kind]` = `{ atlas, color }`, `SAMPLE` = `"rareelite"`, `Preview(frame, on)`, `Applies(scope)`.
  - `frame.eliteIcon` (texture), `frame.eliteText` (font string), `frame.eliteMode` (`"ICON"`, `"TEXT"` or nil), `frame.eliteKind`.
  - Mock: `UnitClassification` (`d.classification`, default `"normal"`), `UnitIsBossMob` (`d.bossMob`), `SetAtlas` records `_atlas`.

- [ ] **Step 1: Write the failing test**

Changes to existing test files (mock support and expectations that change with this task):

```diff
diff --git a/tests/mock.lua b/tests/mock.lua
index bbfcb51..2c797bd 100644
--- a/tests/mock.lua
+++ b/tests/mock.lua
@@ -459,6 +459,8 @@ function M.Reset()
     _G.UnitPowerMissing = function(unit) local d = u(unit); return d and d.powerMissing or 0 end
     -- Shields and heals: d.absorbs; d.healsAll / d.healsMine (nil like the
     -- client when nothing is known).
+    _G.UnitClassification = function(unit) local d = u(unit); return d and d.classification or "normal" end
+    _G.UnitIsBossMob = function(unit) local d = u(unit); return d and d.bossMob or false end
     _G.UnitGetTotalAbsorbs = function(unit) local d = u(unit); return d and d.absorbs or 0 end
     _G.UnitGetIncomingHeals = function(unit, healer)
         local d = u(unit)
```

**New file `tests/test_classification.lua`:**

```lua
local M = H.M
local ns = H.LoadAddon()
local S, L, Cl = ns.Settings, ns.L, ns.Classification

local def = S.Get("eliteMarker")
H.check("code", def.code, "EM")
for _, scope in ipairs({ "target", "targettarget", "focus", "party" }) do
    H.checkTrue("applies to " .. scope, S.AppliesTo(def, scope))
end
H.check("not on the player", S.AppliesTo(def, "player"), false)
H.check("not on the pet", S.AppliesTo(def, "pet"), false)
H.check("on by default", S.Default(def, "target"), true)

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
local f = ns.Frames.target
local icon, text = f.eliteIcon, f.eliteText
H.check("player frame has none", ns.Frames.player.eliteIcon, nil)
H.check("icon on the overlay", icon:GetParent(), f.overlay)
H.check("word on the overlay", text:GetParent(), f.overlay)

-- What a unit is.
local function kindOf(fields)
    M.units.target = fields
    return Cl.Kind("target")
end
H.check("elite", kindOf({ classification = "elite" }), "elite")
H.check("rare", kindOf({ classification = "rare" }), "rare")
H.check("rare elite", kindOf({ classification = "rareelite" }), "rareelite")
H.check("world boss", kindOf({ classification = "worldboss" }), "boss")
H.check("boss mob", kindOf({ classification = "elite", bossMob = true }), "boss")
H.check("normal", kindOf({ classification = "normal" }), nil)
H.check("trivial", kindOf({ classification = "trivial" }), nil)
H.check("secret: none", kindOf({ classification = M.Secret("elite") }), nil)
H.check("secret boss flag: by classification", kindOf({ classification = "rare", bossMob = M.Secret(true) }), "rare")

-- No portrait: a word above the frame's top right corner.
M.units.target = { name = "Ogre", health = 1, healthMax = 1, classification = "elite" }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("word shown", text:IsShown())
H.check("icon hidden", icon:IsShown(), false)
H.check("word", text:GetText(), L.CLASS_elite)
H.check("gold", text._color[2], 0.82)
local p = { text:GetPoint(1) }
H.check("above the frame", p[1] .. p[3], "BOTTOMRIGHTTOPRIGHT")
H.check("clear of the border", p[5], ns.Border.Extent("target") + ns.Pixel.One())
H.checkTrue("font set", text._font)

-- The event changes it.
M.units.target.classification = "rareelite"
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.check("rare elite word", text:GetText(), L.CLASS_rareelite)
H.check("silver", text._color[1], 0.78)
M.units.target.classification = "normal"
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.check("normal: nothing", text:IsShown(), false)

-- Portrait on: the badge on its outer top corner.
M.units.target.classification = "rare"
C.Set("target", "portraitMode", "LEFT")
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.checkTrue("badge shown", icon:IsShown())
H.check("word hidden", text:IsShown(), false)
H.check("rare star", icon._atlas, "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star")
p = { icon:GetPoint(1) }
H.check("on the portrait", p[2], f.portraitBg)
H.check("outer corner", p[1], "TOPLEFT")
H.checkTrue("sticks out to the left", p[4] < 0)
H.check("size", icon:GetWidth(), ns.Pixel.Snap(46 * 0.45))
C.Set("target", "portraitMode", "RIGHT")
H.check("right: outer corner", icon:GetPoint(1), "TOPRIGHT")
H.checkTrue("sticks out to the right", select(4, icon:GetPoint(1)) > 0)
M.units.target.classification = "elite"
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.check("elite badge", icon._atlas, "nameplates-icon-elite-gold")

-- Off.
C.Set("target", "eliteMarker", false)
H.check("off: no badge", icon:IsShown(), false)
H.check("off: no word", text:IsShown(), false)
C.Set("target", "eliteMarker", true)
H.checkTrue("on again", icon:IsShown())

-- Test mode: a sample rare elite marker where markers apply.
ns.TestMode.Set(true)
H.check("sample on target", icon._atlas, "nameplates-icon-elite-silver")
H.checkTrue("sample on focus (word)", ns.Frames.focus.eliteText:IsShown())
H.check("sample word", ns.Frames.focus.eliteText:GetText(), L.CLASS_rareelite)
H.checkTrue("sample on the pretend party", ns.Party.fakes[1].eliteText:IsShown())
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "player")
H.checkTrue("sample kept", ns.Frames.focus.eliteText:IsShown())
ns.TestMode.Set(false)
H.check("target: real marker back", icon._atlas, "nameplates-icon-elite-gold")
H.check("focus: nothing", ns.Frames.focus.eliteText:IsShown(), false)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`

Expected: FAIL — `eliteMarker` is not defined. The output ends with:

```
  ERROR test_classification.lua:6: attempt to index local 'def' (a nil value)
2977 passed, 1 failed
```

- [ ] **Step 3: Implement**

**New file `Elements/Classification.lua`:**

```lua
local _, ns = ...

-- Elite / rare marker. With a portrait: Blizzard's nameplate badge on the
-- portrait's outer top corner. Without: a short word above the frame's
-- top right corner. UnitClassification is not documented as secret; it is
-- still only compared when it is a plain string.
local Classification = { name = "Classification", unitEvents = { "UNIT_CLASSIFICATION_CHANGED" } }
ns.Classification = Classification

local Config, Secrets, Settings, L = ns.Config, ns.Secrets, ns.Settings, ns.L

local GOLD, SILVER = { 1, 0.82, 0 }, { 0.78, 0.8, 0.85 }
-- Atlas names as Blizzard's own nameplates and target frame use them.
Classification.MARKERS = {
    boss = { atlas = "nameplates-icon-elite-gold", color = GOLD },
    elite = { atlas = "nameplates-icon-elite-gold", color = GOLD },
    rareelite = { atlas = "nameplates-icon-elite-silver", color = SILVER },
    rare = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star", color = SILVER },
}
-- Test mode shows this one.
Classification.SAMPLE = "rareelite"

function Classification.Applies(scope)
    return Settings.AppliesTo(Settings.Get("eliteMarker"), scope)
end

-- "boss", "elite", "rareelite", "rare" or nil.
function Classification.Kind(unit)
    if Secrets.Bool(UnitIsBossMob, unit) then return "boss" end
    local ok, c = pcall(UnitClassification, unit)
    if not ok or Secrets.IsSecret(c) or type(c) ~= "string" then return nil end
    if c == "worldboss" then return "boss" end
    if Classification.MARKERS[c] then return c end
    return nil
end

-- Shows the marker for kind (nil: none) in the frame's current style.
local function show(frame, kind)
    frame.eliteKind = kind
    local marker = Classification.MARKERS[kind or ""]
    local mode = frame.eliteMode
    local icon, text = frame.eliteIcon, frame.eliteText
    icon:SetShown(marker ~= nil and mode == "ICON")
    text:SetShown(marker ~= nil and mode == "TEXT")
    if not marker then return end
    icon:SetAtlas(marker.atlas)
    text:SetText(L["CLASS_" .. kind])
    text:SetTextColor(marker.color[1], marker.color[2], marker.color[3], 1)
end

function Classification.Build(frame)
    if not Classification.Applies(frame.key) then return end
    -- On the overlay: above bars and a 3D portrait.
    frame.eliteIcon = frame.overlay:CreateTexture(nil, "OVERLAY")
    frame.eliteText = frame.overlay:CreateFontString(nil, "OVERLAY")
    frame.eliteText:SetFont(ns.Media.Font(nil), 10, "")
end

local function placeIcon(frame, mode)
    local size = ns.Pixel.Snap(math.max(10, Config.Get(frame.key, "height") * 0.45))
    local point = mode == "LEFT" and "TOPLEFT" or "TOPRIGHT"
    local out = ns.Pixel.Snap(size / 3)
    local icon = frame.eliteIcon
    icon:ClearAllPoints()
    icon:SetPoint(point, frame.portraitBg, point, mode == "LEFT" and -out or out, out)
    icon:SetSize(size, size)
end

local function placeText(frame)
    local scope, text = frame.key, frame.eliteText
    local font = ns.Media.Font(Config.Get(scope, "fontFace"))
    ns.Texts.SetFont(text, font, math.max(Config.Get(scope, "fontSize") - 2, 6), Config.Get(scope, "fontOutline"))
    text:ClearAllPoints()
    text:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, ns.Border.Extent(scope) + ns.Pixel.One())
    text:SetJustifyH("RIGHT")
end

function Classification.Style(frame)
    if not frame.eliteIcon then return end
    local scope = frame.key
    local portrait = Config.Get(scope, "portraitMode")
    if not Config.Get(scope, "eliteMarker") then
        frame.eliteMode = nil
    elseif portrait == "OFF" then
        frame.eliteMode = "TEXT"
    else
        frame.eliteMode = "ICON"
    end
    placeIcon(frame, portrait)
    placeText(frame)
    show(frame, frame.eliteKind)
end

function Classification.Update(frame)
    if not frame.eliteIcon or frame.eliteIcon.preview then return end
    show(frame, Classification.Kind(frame.unit))
end

function Classification.Preview(frame, on)
    if not frame.eliteIcon then return end
    frame.eliteIcon.preview = on or nil
    show(frame, on and Classification.SAMPLE or nil)
end

ns.RegisterElement(Classification)
```

Changes to existing files (unified diffs against the previous task's state; `git apply` them or edit by hand):

```diff
diff --git a/Core/Settings.lua b/Core/Settings.lua
index ba39050..3701c5f 100644
--- a/Core/Settings.lua
+++ b/Core/Settings.lua
@@ -137,6 +137,10 @@ Settings.Define({ key = "portraitMode", code = "PM", scope = "frame", type = "en
 Settings.Define({ key = "portraitStyle", code = "PS", scope = "frame", type = "enum",
     values = { "2D", "3D" }, default = "2D" })
 
+-- Elite / rare marker: frames that show units other than you and your pet.
+Settings.Define({ key = "eliteMarker", code = "EM", scope = "frame",
+    only = { target = true, targettarget = true, focus = true, party = true }, type = "bool", default = true })
+
 -- Party block (party only)
 local PARTY = { party = true }
 Settings.Define({ key = "partyOrientation", code = "OR", scope = "frame", only = PARTY, type = "enum",
```

```diff
diff --git a/ForeverUnitFrames.toc b/ForeverUnitFrames.toc
index 43c74c9..5a77c84 100644
--- a/ForeverUnitFrames.toc
+++ b/ForeverUnitFrames.toc
@@ -25,6 +25,7 @@ Elements\Power.lua
 Elements\Texts.lua
 Elements\Portrait.lua
 Elements\Castbar.lua
+Elements\Classification.lua
 Elements\Shape.lua
 Units\Events.lua
 Units\Single.lua
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index 78a4c53..a547c85 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -23,6 +23,7 @@ L.SETTING_healPrediction = "Show incoming heals"
 L.SETTING_healOverflow = "Overheal lane"
 L.SETTING_healMyColor = "Your heals color"
 L.SETTING_healOtherColor = "Other heals color"
+L.SETTING_eliteMarker = "Elite / rare marker"
 L.SETTING_healthColorMode = "Health color"
 L.SETTING_healthColor = "Static health color"
 L.SETTING_enabled = "Enabled"
@@ -108,6 +109,9 @@ L.SECTION_absorbs = "Absorb shields"
 L.HINT_absorbEnabled = "Over the end of the health bar"
 L.SECTION_healPrediction = "Incoming heals"
 L.HINT_healOverflow = "Shows heals past full health"
+L.SECTION_indicators = "Indicators"
+L.HINT_eliteMarker = "On the portrait, else above the frame"
+L.CLASS_boss = "Boss"; L.CLASS_elite = "Elite"; L.CLASS_rareelite = "Rare Elite"; L.CLASS_rare = "Rare"
 L.HINT_cornerRadius = "0 = square corners"
 L.HINT_borderSize = "0 = no border"
 L.HINT_borderPadding = "Gap between frame and border"
```

```diff
diff --git a/Options/Schema.lua b/Options/Schema.lua
index c1004af..e27cd65 100644
--- a/Options/Schema.lua
+++ b/Options/Schema.lua
@@ -24,6 +24,7 @@ Schema.FRAME = {
         { id = "size", keys = { "width", "height" } },
         { id = "barHeights", keys = { "titlePercent", "healthPercent", "powerPercent", "powerEnabled" } },
         { id = "portrait", keys = { "portraitMode", "portraitStyle" } },
+        { id = "indicators", keys = { "eliteMarker" } },
         { id = "group", keys = { "partyOrientation", "partySpacing", "partyShowPlayer", "partyShowSolo" } },
         { id = "position", keys = { "x", "y" } },
     } },
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `tests/run`
Expected: `3037 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Settings.lua Elements/Classification.lua ForeverUnitFrames.toc Locales/enUS.lua Options/Schema.lua tests/mock.lua tests/test_classification.lua
git commit -F - <<'EOF'
Elite, rare and boss marker for target, focus, target of target and party

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 8: Combat feedback numbers

Damage (red) and heal (green) numbers inside the frame, like Blizzard's player frame hit indicator, plus words for misses, dodges and the like. The amount goes to `SetFormattedText("%s", …)` untouched; a fade animation group (0.2 s in, 0.7 s hold, 0.3 s out) hides it. Per-frame `combatFeedback` (`CF`, on for player and pet).

**Files:**
- Create: `Elements/CombatFeedback.lua`
- Modify: `Core/Settings.lua`
- Modify: `ForeverUnitFrames.toc`
- Modify: `Locales/enUS.lua`
- Modify: `Options/Schema.lua`
- Test (new): `tests/test_combat_feedback.lua`
- Test (modify): `tests/mock.lua`

**Interfaces:**
- Consumes: `UNIT_COMBAT` payload `unitTarget, event, flagText, amount, schoolMask`, `ns.Secrets.Abbreviate/Number/IsSecret`, `ns.Texts.SetFont`, `frame.overlay`.
- Produces:
  - `frame.feedback` (holder frame, animated alpha), `frame.feedbackText`, `frame.feedbackFade` (AnimationGroup of three Alpha steps, `SetToFinalAlpha(true)`, hides the holder on `OnFinished`).
  - `ns.CombatFeedback.Size(scope)` → `floor(fontSize * 1.5 + 0.5)`; `DAMAGE`, `HEAL`, `WORD` colours; `SAMPLE` = 1234; `Preview(frame, on)`.
  - Mock: `CreateAnimationGroup` / `CreateAnimation` with the Alpha setters, `Play`, `Stop`, `IsPlaying`, `SetToFinalAlpha`; `M.FinishAnimations()` ends all playing groups.

- [ ] **Step 1: Write the failing test**

Changes to existing test files (mock support and expectations that change with this task):

```diff
diff --git a/tests/mock.lua b/tests/mock.lua
index 2c797bd..526e85e 100644
--- a/tests/mock.lua
+++ b/tests/mock.lua
@@ -318,6 +318,27 @@ local function newWidget(kind, name, parent)
         fs._layer, fs._sublevel = layer or "ARTWORK", 0
         return fs
     end
+    -- Animation groups: Play marks the group playing; M.FinishAnimations
+    -- ends every playing group like the client would when it is done.
+    function w:CreateAnimationGroup()
+        local group = newWidget("AnimationGroup", nil, self)
+        group._anims = {}
+        function group:CreateAnimation(kind)
+            local anim = newWidget(kind, nil, self)
+            function anim:SetFromAlpha(v) self._from = v end
+            function anim:SetToAlpha(v) self._to = v end
+            function anim:SetDuration(v) self._duration = v end
+            function anim:SetStartDelay(v) self._delay = v end
+            function anim:SetOrder(v) self._order = v end
+            table.insert(self._anims, anim)
+            return anim
+        end
+        function group:SetToFinalAlpha(v) self._toFinal = v end
+        function group:Play() self._playing = true; M.playing[self] = true end
+        function group:Stop() self._playing = false; M.playing[self] = nil end
+        function group:IsPlaying() return self._playing or false end
+        return group
+    end
     -- PlayerModel
     function w:SetUnit(unit) self._modelUnit = unit; return true end
     function w:ClearModel() self._modelUnit = nil; self._cleared = true end
@@ -346,6 +367,7 @@ function M.Reset()
     M.now = 1000           -- GetTime(), advanced by M.Tick
     M.group = {}           -- party unit tokens ("party1", ...) while grouped
     M.headerUpdates = 0    -- how often a group header laid out its buttons
+    M.playing = {}         -- animation groups that are playing
 
     -- Pixel grid. By default one physical pixel is one UI unit (768 pixels
     -- high, scale 1), so layout numbers stay whole; tests change these.
@@ -618,6 +640,20 @@ function M.SetGroup(units)
     M.FireEvent("GROUP_ROSTER_UPDATE")
 end
 
+-- Every playing animation group runs to its end: the animated frame takes
+-- the last alpha (SetToFinalAlpha), then OnFinished runs.
+function M.FinishAnimations()
+    local groups = M.playing
+    M.playing = {}
+    for group in pairs(groups) do
+        group._playing = false
+        local last = group._anims[#group._anims]
+        if group._toFinal and last then group:GetParent():SetAlpha(last._to) end
+        local done = group:GetScript("OnFinished")
+        if done then done(group) end
+    end
+end
+
 function M.SetCombat(v)
     M.combat = v
     if not v then M.FireEvent("PLAYER_REGEN_ENABLED") end
```

**New file `tests/test_combat_feedback.lua`:**

```lua
local M = H.M
local ns = H.LoadAddon()
local S, L, CF = ns.Settings, ns.L, ns.CombatFeedback

local def = S.Get("combatFeedback")
H.check("code", def.code, "CF")
H.check("per frame", def.scope, "frame")
H.check("on for the player", S.Default(def, "player"), true)
H.check("on for the pet", S.Default(def, "pet"), true)
H.check("off for the target", S.Default(def, "target"), false)

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
local f = ns.Frames.player
local holder, text, fade = f.feedback, f.feedbackText, f.feedbackFade
M.units.player = { name = "Me", health = 5, healthMax = 10 }

H.check("on the overlay", holder:GetParent(), f.overlay)
H.check("hidden at rest", holder:IsShown(), false)
H.check("mid health bar", select(2, text:GetPoint(1)), f.health)
H.check("font size", text._font[2], CF.Size("player"))
H.check("size from the frame font", CF.Size("player"), 18)
-- The fade: in, hold, out, Blizzard's timings, ending hidden.
H.check("three steps", #fade._anims, 3)
H.check("fade in", fade._anims[1]._from .. ">" .. fade._anims[1]._to, "0>1")
H.check("fade in time", fade._anims[1]._duration, 0.2)
H.check("hold", fade._anims[2]._duration, 0.7)
H.check("fade out", fade._anims[3]._to, 0)
H.check("in order", fade._anims[3]._order, 3)

-- A secret hit: passed through untouched, red.
local hit = M.Secret(532)
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "", hit, 1)
H.checkTrue("shown", holder:IsShown())
H.checkTrue("fading", fade:IsPlaying())
H.check("format", text._fmt, "%s")
H.check("amount is the secret", text._args[1], hit)
H.check("red", text._color[1] .. "," .. text._color[2], "1,0.25")
M.FinishAnimations()
H.check("gone after the fade", holder:IsShown(), false)

-- A readable heal: abbreviated, green; a critical one bigger.
M.FireEvent("UNIT_COMBAT", "player", "HEAL", "CRITICAL", 12345, 2)
H.check("heal text", text._args[1], "12.3k")
H.check("green", text._color[2], 1)
H.check("critical: bigger", text._font[2], 27)
M.FireEvent("UNIT_COMBAT", "player", "HEAL", "", 300, 2)
H.check("normal size again", text._font[2], 18)

-- Words: a dodge; a readable zero hit names its flag, else a miss.
M.FireEvent("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
H.check("dodge", text:GetText(), L.FEEDBACK_DODGE)
H.check("white", text._color[3], 1)
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "ABSORB", 0, 1)
H.check("absorbed", text:GetText(), L.FEEDBACK_ABSORB)
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "", 0, 1)
H.check("missed", text:GetText(), L.FEEDBACK_MISS)

-- Secret or unknown event kinds show nothing new.
M.FinishAnimations()
M.FireEvent("UNIT_COMBAT", "player", M.Secret("WOUND"), "", 5, 1)
H.check("secret kind: nothing", holder:IsShown(), false)
M.FireEvent("UNIT_COMBAT", "player", "ENERGIZE", "", 5, 1)
H.check("energize: nothing", holder:IsShown(), false)
-- Other refreshes are not feedback.
ns.Single.UpdateAll(f, "PLAYER_ENTERING_WORLD")
H.check("refresh: nothing", holder:IsShown(), false)

-- With a portrait the number sits on it.
C.Set("player", "portraitMode", "LEFT")
H.check("on the portrait", select(2, text:GetPoint(1)), f.portraitBg)

-- Off for the target by default; switchable per frame.
M.units.target = { name = "Foe", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
M.FireEvent("UNIT_COMBAT", "target", "WOUND", "", 10, 1)
H.check("target: off", ns.Frames.target.feedback:IsShown(), false)
C.Set("target", "combatFeedback", true)
M.FireEvent("UNIT_COMBAT", "target", "WOUND", "", 10, 1)
H.checkTrue("target: on", ns.Frames.target.feedback:IsShown())
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "", 10, 1)
C.Set("player", "combatFeedback", false)
H.check("switched off: hidden at once", holder:IsShown(), false)
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "", 10, 1)
H.check("switched off: nothing", holder:IsShown(), false)
C.Set("player", "combatFeedback", true)
M.FinishAnimations()

-- Test mode: a still sample number where feedback is on.
ns.TestMode.Set(true)
H.checkTrue("sample shown", holder:IsShown())
H.check("sample amount", text._args[1], "1234")
H.check("sample still", fade:IsPlaying(), false)
H.check("sample opaque", holder:GetAlpha(), 1)
M.FireEvent("UNIT_COMBAT", "player", "HEAL", "", 1, 2)
H.check("sample kept", text._args[1], "1234")
H.check("off frames: no sample", ns.Frames.focus.feedback:IsShown(), false)
ns.TestMode.Set(false)
H.check("sample gone", holder:IsShown(), false)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`

Expected: FAIL — `combatFeedback` is not defined. The output ends with:

```
  ERROR test_combat_feedback.lua:6: attempt to index local 'def' (a nil value)
3037 passed, 1 failed
```

- [ ] **Step 3: Implement**

**New file `Elements/CombatFeedback.lua`:**

```lua
local _, ns = ...

-- Damage and heal numbers inside the frame, like Blizzard's hit indicator
-- on the player frame (CombatFeedback.lua): damage red, heals green,
-- misses and the like as a word. The amount may be secret: it goes to the
-- font string untouched (SetFormattedText) and is never measured. The
-- fade is an animation group on a holder frame, so no Lua counts time.
local CombatFeedback = { name = "CombatFeedback", unitEvents = { "UNIT_COMBAT" } }
ns.CombatFeedback = CombatFeedback

local Config, Secrets, L = ns.Config, ns.Secrets, ns.L

CombatFeedback.DAMAGE = { 1, 0.25, 0.25 }
CombatFeedback.HEAL = { 0.3, 1, 0.4 }
CombatFeedback.WORD = { 1, 1, 1 }
-- Blizzard's timings: fade in, hold, fade out (seconds).
CombatFeedback.FADE_IN, CombatFeedback.HOLD, CombatFeedback.FADE_OUT = 0.2, 0.7, 0.3
-- Test mode shows this as damage.
CombatFeedback.SAMPLE = 1234

-- Events without a number that Blizzard names with a word.
local WORDS = {
    IMMUNE = true, BLOCK = true, DODGE = true, PARRY = true, MISS = true, RESIST = true,
    EVADE = true, DEFLECT = true, ABSORB = true, REFLECT = true, INTERRUPT = true,
}
-- A WOUND of readable zero: the flag says what happened, else a miss.
local ZERO_WOUND = { ABSORB = true, BLOCK = true, RESIST = true }
local CRITICAL = { CRITICAL = true, CRUSHING = true }

-- A plain string, or nil when secret or not a string.
local function plain(v)
    if Secrets.IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

local function alphaStep(group, from, to, duration, order)
    local anim = group:CreateAnimation("Alpha")
    anim:SetFromAlpha(from)
    anim:SetToAlpha(to)
    anim:SetDuration(duration)
    anim:SetOrder(order)
end

function CombatFeedback.Build(frame)
    local holder = CreateFrame("Frame", nil, frame.overlay)
    holder:SetAllPoints(frame.overlay)
    holder:Hide()
    local text = holder:CreateFontString(nil, "OVERLAY")
    text:SetFont(ns.Media.Font(nil), 12, "")
    local fade = holder:CreateAnimationGroup()
    alphaStep(fade, 0, 1, CombatFeedback.FADE_IN, 1)
    alphaStep(fade, 1, 1, CombatFeedback.HOLD, 2)
    alphaStep(fade, 1, 0, CombatFeedback.FADE_OUT, 3)
    fade:SetToFinalAlpha(true)
    fade:SetScript("OnFinished", function() holder:Hide() end)
    frame.feedback, frame.feedbackText, frame.feedbackFade = holder, text, fade
end

-- Font size of the numbers: half again the frame's font size.
function CombatFeedback.Size(scope)
    return math.floor(Config.Get(scope, "fontSize") * 1.5 + 0.5)
end

local function setFont(frame, size)
    local scope = frame.key
    ns.Texts.SetFont(frame.feedbackText, ns.Media.Font(Config.Get(scope, "fontFace")), size,
        Config.Get(scope, "fontOutline"))
end

local function paint(text, color)
    text:SetTextColor(color[1], color[2], color[3], 1)
end

function CombatFeedback.Style(frame)
    local scope, text = frame.key, frame.feedbackText
    setFont(frame, CombatFeedback.Size(scope))
    text:ClearAllPoints()
    -- Over the portrait when there is one, like Blizzard's; else mid bar.
    local anchor = Config.Get(scope, "portraitMode") == "OFF" and frame.health or frame.portraitBg
    text:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    local on = Config.Get(scope, "combatFeedback")
    if frame.feedback.preview then
        frame.feedback:SetShown(on)
    elseif not on then
        frame.feedbackFade:Stop()
        frame.feedback:Hide()
    end
end

local function play(frame)
    local holder = frame.feedback
    frame.feedbackFade:Stop()
    holder:SetAlpha(0)
    holder:Show()
    frame.feedbackFade:Play()
end

-- UNIT_COMBAT: unit, action, flags, amount, school. Other events (whole
-- frame refreshes) are not feedback.
function CombatFeedback.Update(frame, event, _, action, flags, amount)
    if event ~= "UNIT_COMBAT" or frame.feedback.preview then return end
    local scope = frame.key
    if not Config.Get(scope, "combatFeedback") then return end
    local kind, flag = plain(action), plain(flags)
    local text, size = frame.feedbackText, CombatFeedback.Size(scope)
    if kind == "WOUND" and Secrets.Number(amount) == 0 then
        kind = ZERO_WOUND[flag] and flag or "MISS"
    end
    if kind == "WOUND" or kind == "HEAL" then
        if CRITICAL[flag] then size = math.floor(size * 1.5 + 0.5) end
        setFont(frame, size)
        text:SetFormattedText("%s", Secrets.Abbreviate(amount))
        paint(text, kind == "WOUND" and CombatFeedback.DAMAGE or CombatFeedback.HEAL)
    elseif WORDS[kind] then
        setFont(frame, size)
        text:SetText(L["FEEDBACK_" .. kind])
        paint(text, CombatFeedback.WORD)
    else
        return
    end
    play(frame)
end

function CombatFeedback.Preview(frame, on)
    local holder = frame.feedback
    holder.preview = on or nil
    frame.feedbackFade:Stop()
    if not on then
        holder:Hide()
        return
    end
    setFont(frame, CombatFeedback.Size(frame.key))
    frame.feedbackText:SetFormattedText("%s", Secrets.Abbreviate(CombatFeedback.SAMPLE))
    paint(frame.feedbackText, CombatFeedback.DAMAGE)
    holder:SetAlpha(1)
    holder:SetShown(Config.Get(frame.key, "combatFeedback"))
end

ns.RegisterElement(CombatFeedback)
```

Changes to existing files (unified diffs against the previous task's state; `git apply` them or edit by hand):

```diff
diff --git a/Core/Settings.lua b/Core/Settings.lua
index 3701c5f..6ace0d4 100644
--- a/Core/Settings.lua
+++ b/Core/Settings.lua
@@ -140,6 +140,10 @@ Settings.Define({ key = "portraitStyle", code = "PS", scope = "frame", type = "e
 -- Elite / rare marker: frames that show units other than you and your pet.
 Settings.Define({ key = "eliteMarker", code = "EM", scope = "frame",
     only = { target = true, targettarget = true, focus = true, party = true }, type = "bool", default = true })
+-- Damage and heal numbers inside the frame (Blizzard shows them on the
+-- player and pet frames).
+Settings.Define({ key = "combatFeedback", code = "CF", scope = "frame", type = "bool",
+    default = { player = true, pet = true, _ = false } })
 
 -- Party block (party only)
 local PARTY = { party = true }
```

```diff
diff --git a/ForeverUnitFrames.toc b/ForeverUnitFrames.toc
index 5a77c84..83d1137 100644
--- a/ForeverUnitFrames.toc
+++ b/ForeverUnitFrames.toc
@@ -26,6 +26,7 @@ Elements\Texts.lua
 Elements\Portrait.lua
 Elements\Castbar.lua
 Elements\Classification.lua
+Elements\CombatFeedback.lua
 Elements\Shape.lua
 Units\Events.lua
 Units\Single.lua
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index a547c85..db1f73e 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -24,6 +24,7 @@ L.SETTING_healOverflow = "Overheal lane"
 L.SETTING_healMyColor = "Your heals color"
 L.SETTING_healOtherColor = "Other heals color"
 L.SETTING_eliteMarker = "Elite / rare marker"
+L.SETTING_combatFeedback = "Damage and heal numbers"
 L.SETTING_healthColorMode = "Health color"
 L.SETTING_healthColor = "Static health color"
 L.SETTING_enabled = "Enabled"
@@ -111,6 +112,11 @@ L.SECTION_healPrediction = "Incoming heals"
 L.HINT_healOverflow = "Shows heals past full health"
 L.SECTION_indicators = "Indicators"
 L.HINT_eliteMarker = "On the portrait, else above the frame"
+L.HINT_combatFeedback = "Shown briefly inside the frame"
+L.FEEDBACK_IMMUNE = "Immune"; L.FEEDBACK_BLOCK = "Block"; L.FEEDBACK_DODGE = "Dodge"
+L.FEEDBACK_PARRY = "Parry"; L.FEEDBACK_MISS = "Miss"; L.FEEDBACK_RESIST = "Resist"
+L.FEEDBACK_EVADE = "Evade"; L.FEEDBACK_DEFLECT = "Deflect"; L.FEEDBACK_ABSORB = "Absorb"
+L.FEEDBACK_REFLECT = "Reflect"; L.FEEDBACK_INTERRUPT = "Interrupt"
 L.CLASS_boss = "Boss"; L.CLASS_elite = "Elite"; L.CLASS_rareelite = "Rare Elite"; L.CLASS_rare = "Rare"
 L.HINT_cornerRadius = "0 = square corners"
 L.HINT_borderSize = "0 = no border"
```

```diff
diff --git a/Options/Schema.lua b/Options/Schema.lua
index e27cd65..f379c01 100644
--- a/Options/Schema.lua
+++ b/Options/Schema.lua
@@ -24,7 +24,7 @@ Schema.FRAME = {
         { id = "size", keys = { "width", "height" } },
         { id = "barHeights", keys = { "titlePercent", "healthPercent", "powerPercent", "powerEnabled" } },
         { id = "portrait", keys = { "portraitMode", "portraitStyle" } },
-        { id = "indicators", keys = { "eliteMarker" } },
+        { id = "indicators", keys = { "eliteMarker", "combatFeedback" } },
         { id = "group", keys = { "partyOrientation", "partySpacing", "partyShowPlayer", "partyShowSolo" } },
         { id = "position", keys = { "x", "y" } },
     } },
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `tests/run`
Expected: `3093 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Settings.lua Elements/CombatFeedback.lua ForeverUnitFrames.toc Locales/enUS.lua Options/Schema.lua tests/mock.lua tests/test_combat_feedback.lua
git commit -F - <<'EOF'
Damage and heal numbers inside the frame

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 9: In-game verification (controller: UI actions only)

No code changes. The controller installs the build and checks it in the game using only the interface (chat commands, the options window, the mouse on movers and options). The controller does **not** move the character, cast, target anything in the world or enter combat; the user runs the combat checks at the end.

**Files:** none (report the results; if a check fails, stop and report the failing step with a screenshot — do not fix inside this task).

- [ ] **Step 1: Install and load**

Run: `./install "<AddOns folder of the WoW: Forever client>"`
Expected: `Installed to .../ForeverUnitFrames`, and `.../ForeverUnitFrames/Media/Corner.tga` exists. In game: `/reload`. No Lua error window.

- [ ] **Step 2: Title row and defaults**

Start from a profile without overrides (type `/fuf reset all`), then click "Test mode". Expected: Player, Target and Focus show a title row with the name (and level) above a green health bar with `current / max` on the left and a percentage on the right; the name is in your class colour. Party, Target of Target and Pet have two rows as before. Player → Layout → "Title row height (%)" 0 → the player frame goes back to two rows.

- [ ] **Step 3: Font apply**

Player → Text → Font size 20. General → Appearance → "Apply to all frames" → the button reads "Click again to confirm"; click again → the player's texts go back to the General size; Player → Text shows the font rows as inherited.

- [ ] **Step 4: Corners**

General → Appearance → Corner radius 8. Expected: every frame, its title row, bars, portrait (2D) and castbar (with icon) have rounded outer corners; nothing square pokes out at a corner. Radius 0 → square again. If corners look inverted, cut straight, or whole bars vanish, stop and report (CLAMP on masks is the part that cannot be checked offline).

- [ ] **Step 5: Border**

General → Appearance → Border size 4, Border padding 3, Corner radius 8. Expected: one border ring around each frame, 3 px away from it, rounded concentrically with the frame; on Target (test mode shows a sample cast) the ring encloses the frame and the docked castbar together. Target → Castbar → position Detached: the castbar gets its own ring, the frame's ring shrinks to the frame. Back to Below. Border size 0 → no border.

- [ ] **Step 6: Shields, heals, marker, feedback samples**

In test mode: every frame shows a pale shield at the right end of its health bar and a two-tone heal prediction starting where health ends; Player → Bars → "Overheal lane" on → the health bar gets shorter and a lane appears at its end. Target / Focus / party frames show "Rare Elite" above their top right corner; Target → Layout → Portrait Left → a silver badge sits on the portrait's top left corner. The player frame shows a red "1234" in the middle of the health bar (over the portrait when one is shown). Leave test mode: samples disappear.

- [ ] **Step 7: Checks for the user (combat, groups — not the controller)**

Hand these to the user:
1. Take damage and get healed: red numbers and green numbers fade in and out on the player frame (and the pet frame); in combat against a secret-restricted source the number still shows (maybe unabbreviated).
2. Get a shield (e.g. Power Word: Shield): a pale bar at the right end of the health bar, also in combat; it shrinks as it absorbs.
3. In a group, have a healer cast on you: the heal prediction appears where your health ends; your own heals on others show in your colour over the others' colour. With the overheal lane on, heals on a full-health member show in the lane.
4. Target an elite, a rare elite, a rare and a boss (with and without a portrait): gold badge for elite and boss, silver badge for rare elite, star for rare; the words Elite / Rare Elite / Rare / Boss without a portrait.
5. Enter combat with a rounded, bordered layout and switch targets: no Lua errors; the ring follows the target's castbar as it starts and stops.

---

## Self-review against the requests

| Request | Task |
|---|---|
| Font: "Apply to all frames" on General → Appearance clearing `fontFace`, `fontSize`, `fontOutline`, `fontShadow` of every frame, two-click confirm | 1 |
| Three-row layout: title row (own background, text tag default `NAME_LEVEL`, colour Class / Reaction / White), health, power; `titlePercent` 0 = old layout; row heights % of frame height, rest is the gap; static green health default; texts move to title / values on the health bar; schema in Layout and Text tabs; tests incl. layout maths and pixel grid | 2 |
| Corner radius 0–12, global + per frame, on background, bars, border, portrait, castbars; masks researched (CreateMaskTexture, AddMaskTexture, slicing, Blizzard atlases), shipped TGA from an offline Python script | 3 (border: 4) |
| Outer border: up to 8 px, padding, encloses portrait and docked castbar, follows the radius, global + per frame, new unique codes | 4 |
| Absorb shields as an overlay on the health bar, secret-safe status bar, clipped to the bar | 5 |
| Incoming heals anchored to the end of the health fill, proportional, clipped at full health, optional overheal lane, own / other colours | 6 |
| Elite / rare marker for Target, Focus, Target of Target, Party: badge on the portrait side or a text badge without portrait, Blizzard atlases verified by name | 7 |
| Combat feedback inside the frame, red / green, pass-through amounts, AnimationGroup fade, per-frame toggle | 8 |
| Settings in `Core/Settings.lua`, schema entries, enUS strings, test-mode samples, mock-style tests with the strict secret proxy | every task |

## Changelog notes (for the release notes)

- New default look for profiles without overrides: health bars are a static green instead of class coloured (Class, Reaction and Gradient remain selectable); Player, Target and Focus get a title row with the name (and level) above the health bar, which now shows current / max and percent. Party, Target of Target and Pet keep their two-row layout.
- Border size now goes up to 8 px; new border padding; the border encloses a docked castbar. With the defaults (1 px, no padding, square) the frames look as before, except that a docked castbar shares the frame's border instead of having its own.
- New: rounded corners, absorb shields, incoming heals (with overheal lane), elite / rare / boss marker, combat feedback numbers, "Apply to all frames" for fonts.

## Not verifiable offline (check in game, Task 9)

- **CLAMP wrapping on mask textures** repeating the edge texels (the whole rounded-corner technique relies on it). Blizzard XML sets `hWrapMode="CLAMP"` on a mask, but its visual effect is not in the source. Fallback if it fails: `CLAMPTOWHITE` (in the XSD, unused by Blizzard) or one stretched rounded-rectangle mask per block.
- Loading a TGA from `Interface\AddOns\ForeverUnitFrames\Media\` (not in the UI source; standard client behaviour) and whether the client wants power-of-two sizes (64 × 64 is).
- Four masks on one texture (no documented limit; Blizzard code uses one or two).
- Masks and child regions created on a party button that the group header makes **in combat** (same open question as Plan 3 for other child regions).
- Whether `UnitGetTotalAbsorbs`, `UnitGetIncomingHeals`, `UNIT_COMBAT` amounts are actually secret for addons in combat (documented as `SecretReturns` / unflagged payload); the code works either way.
- Whether `UnitClassification` can be secret for restricted units (docs: not); a secret value simply shows no marker.
- The exact look and native size of the three atlases (only their names are proven by Blizzard code).
- Frame levels in the client: the overlay is set to the unit frame's level + 10 at build time; if another element later raises its own level above that, texts could slip under it.

## Open decisions for the user

- Party spacing counts from frame edge to frame edge: thick or padded borders eat into it (not added automatically, so existing spacings keep their meaning).
- The docked castbar gap keeps `2 × border size + 2 px` (unchanged default look); with an 8 px border the gap inside the ring is 18 px.
- The elite word sits above the frame's top right corner; with a castbar docked above it overlaps the castbar ring.
- Title row: percentages are of the frame height with unchanged frame heights (player / target 46 → title 14 px, health 21 px, power 11 px); taller default heights would give more room but change every existing position test.
