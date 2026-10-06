# Forever Unit Frames — Raid plan R4c: cells of their own, a dispel square, a raid minimap button

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raid cells stop following the party frame: every unit-frame setting a cell reads is answered by the raid itself — fonts, bar texture, colours, border and corners, heals, shields and combat numbers become raid settings per size, everything else is fixed at the unit frames' shipped defaults — and a guard test fails as soon as any party or General setting changes a raid answer. The dispellable debuff can show as a small square in a corner (from one pixel), coloured by the client, beside a corner indicator in the same corner. The raid frames get a minimap button of their own (own icon, angle and switch) and an entry in Blizzard's addon compartment. A typed class order or spell list that is refused says why in the chat. Small carry-overs from the R4a review are fixed.

**Architecture:** `Raid/Cell.lua`'s derived scope `raid` answers every key: `FIXED`, then `MAPPED` (raid profile of the active size), then the unit frames' shipped default for a party frame (`ns.Settings.Default(def, "party")`, preset included) — never the party frame's or General's value; the panel's and blocks' rings (`Raid/Header.lua`) derive from the cell instead of the party frame. New raid settings per size feed `MAPPED`; the cell's name and second-line colours reach `Elements/Texts.lua` through a frame field no unit frame sets (`frame.textColors`). The dispel square is one more aura slot of the cell's container (`Raid/CellAuras.lua`) with the centre icon's filter and a texture the client colours through the existing dispel colour curve. `Options/MinimapButton.lua` gains `MinimapButton.New(spec)`, which builds the unit frames' button as before and the raid button (`Raid/MinimapButton.lua`) from the raid profile's General settings.

**Tech Stack:** Lua 5.1, WoW: Forever API (Interface 16001, build 1.60.1.70205), offline tests with `lua5.1` + `tests/mock.lua` (`tests/run`); Python 3 with Pillow for the icon (`tools/`).

Spec: `docs/specs/2026-10-06-raid-frames-design.md` (part 1; §5 The cell, §6 Options window). Raid plan order: R1 Foundation, R2a, R2b, R3a, R3b, R4a Options menu and window (all done) → **R4c Cells of their own, dispel square, raid minimap button (this plan)** → R4b Window actions, test mode for the edited size, entry points, wiki, release (`docs/plans/2026-10-06-plan-raid-4b-window-actions-wiki-release.md`, revised to run after this plan).

Base: branch `raid-r4` at `7735f05` ("Raid options window: sizes, tabs and rows, /fuf raid"); `tests/run` there: `22459 passed, 0 failed`. Every task below was replayed in order on a scratch worktree of that commit; the outputs under "Expected" are what `tests/run` printed there.

## Global Constraints

- Everything in English: file names, identifiers, comments. Every new user-facing string is a locale key in all four languages, `Locales/enUS.lua`, `deDE.lua`, `esES.lua`, `frFR.lua` (`tests/test_locale.lua` requires each English key in every language with the same `%` placeholders); German in the style of the existing `deDE` strings. Raid labels fit the label column and raid hints are no longer than the unit frames' longest English hint (`tests/test_raid_schema.lua` checks both in every language).
- Target client: WoW: Forever, `## Interface: 16001`. Client facts only from the Forever UI source (game type `camelot`); the ones used are in the table below. Never write the name of the local lookup tool into the repository.
- The unit frames and their options window stay the same for users: no unit-frame setting, key, code, scope letter or default changes. `Elements/Texts.lua` reads a field only raid cells set; `Options/MinimapButton.lua` builds the same button through a shared maker (`tests/test_minimap_button.lua` passes unchanged); `tools/make_minimap_icon.py` writes `Media/MinimapIcon.tga` byte for byte as before.
- Raid setting codes are permanent once released and unique within the raid registry; enums are stored by index, append only.
- No secret-value maths, comparisons or truth tests: a value that may be secret is checked with `ns.Secrets.IsSecret` (or `type(x) == "nil"`) before anything else touches it (the mock's secret is a table and would pass a truth test unnoticed). No secure snippets. Protected frames and aura containers change only out of combat (`ns.AfterCombat`).
- `ns.On` throws on unknown event names in the client: no new game event is used.
- The mock stays faithful: it may be stricter than the client source, never more permissive. Task 7 adds Blizzard's addon compartment frame with its `RegisterAddon` (table below).
- Public repository: no local paths, host names, character names or anything about the author's machine in files or commit messages. Test names are neutral.
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
- Do not push. Every task ends with `tests/run` green and one commit (`git add` only the files the task lists).
- A full `tests/run` takes about a minute and a half and several GB of memory (as before).
- New raid settings (codes in brackets), per size unless noted: Task 2 `fontFace` (FF, media font), `nameFontSize` (NF), `secondFontSize` (SF), `fontOutline` (FO, enum), `fontShadow` (FH); Task 3 `healthColor` (HC), `barTexture` (TX, media statusbar), `backgroundColor` (BG), `nameColor` (NA), `secondLineColor` (SC); Task 4 `cellBorderStyle` (CY, enum), `cellBorderSize` (CZ), `cellBorderColor` (CK), `cellCornerRadius` (CR); Task 5 `healPrediction` (IH), `overheal` (OV), `absorbs` (AS), `combatText` (CT); Task 6 `dispelStyle` (DM, enum), `dispelSquarePoint` (DP, enum), `dispelSquareSize` (DQ); Task 7, character-wide (`general`): `minimapShow` (MS), `minimapAngle` (MA). 25 in all.
- New locale keys (53): Task 2: 11 (`RAID_SECTION_fonts`, 5 `RAID_SETTING_*`, 5 `RAID_ENUM_fontOutline_*`); Task 3: 6; Task 4: 9; Task 5: 6; Task 6: 11; Task 7: 6 (`RAID_SECTION_minimap`, `RAID_SETTING_minimapShow`, `RAID_SETTING_minimapAngle`, `RAID_HINT_minimapAngle`, `RAID_MINIMAP_LEFT_CLICK`, `RAID_COMPARTMENT`); Task 8: 4 (`RAID_TYPED_*`). Changed words: `RAID_NOTE_cell`, `RAID_ENUM_healthColorMode_STATIC` (Task 3), `RAID_SETTING_cellBorder` (Task 4), `RAID_SETTING_dispelIcon` (Task 6) in all four languages; Task 9: deDE `RAID_SECTION_arrangement`, `RAID_SETTING_targetBorder`, esES `RAID_HINT_classOrder`, esES and frFR `RAID_HINT_x`, `RAID_HINT_y`.
- Existing tests edited, each because the behaviour they pin changes on purpose: `tests/test_raid_cell.lua` (its header comment and "party look otherwise": cells no longer wear the party look) and `tests/test_raid_header.lua` ("unit-frame border size counts": it no longer does) in Task 1; `tests/test_raid_window.lua`'s "general rows" (the General tab gains the minimap rows) in Task 7; `tests/test_raid_schema.lua`'s "character-wide ones on General" (`tostring`, so a missing setting fails one check instead of ending the file) in Task 9.
- New files and their place in `ForeverUnitFrames.toc`: `Raid\MinimapButton.lua` after `Raid\Options\Window.lua`; `Media/RaidMinimapIcon.tga` (written by `tools/make_raid_minimap_icon.py`; `./install` and `tools/package` copy `Media/*.tga`). A new texture file is only seen after a full restart of the game client, not after `/reload`.
- Game events in use, none new: `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `PLAYER_LOGIN`. Internal events used: `RAID_CONFIG_CHANGED`, `CONFIG_CHANGED` (Raid/Header.lua stops listening to it: cells no longer follow the unit frames' settings).

## Client facts this plan relies on (build 1.60.1.70205)

Paths below `Interface/AddOns/`.

| Fact | Source |
|---|---|
| `AddonCompartmentFrame:RegisterAddon(addonData)` adds an entry besides the TOC's: `addonData` holds `text`, `icon` (file or atlas), `func` (click), `funcOnEnter(button)`, `funcOnLeave(button)`; entries are sorted by text when the menu opens | `Blizzard_Minimap/Mainline/AddonCompartment.lua` |
| The addon compartment loads on this game type: the TOC lists `[Family]\AddonCompartment.lua` for `mainline`, and camelot is a mainline game type (`[Family]\MinimapConstants.lua` has to exclude camelot explicitly, `[Game]\MinimapConstants.lua` is camelot's own) | `Blizzard_Minimap/Blizzard_Minimap.toc` |
| A custom aura container's slot frame takes `AddDispelTypeTexture(texture, { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset, customDispelColorCurve = curve })`: the client sets the texture's colour from the curve by the dispel type of the aura in the slot (the texture must belong to the slot's frame); the slot's frame shows only while the slot holds an aura, as R3a's tint relies on | `Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua` (`AddDispelTypeTexture`), `Blizzard_APIDocumentationGenerated/AuraContainerSharedDocumentation.lua` |
| Minimap shapes (`GetMinimapShape`, a square minimap addon resizing the minimap after login) are handled as by the unit frames' button | `Options/MinimapButton.lua` (unchanged behaviour) |

## Design decisions

- **Every key answered by the raid.** Which unit-frame keys a cell reads was taken from a run of the whole suite with every read through the scope `raid` logged that `FIXED`/`MAPPED` did not answer, plus a search of the elements. Each one now gets its own raid setting or a fixed raid value:

| Keys a cell reads (unit-frame names) | Decision |
|---|---|
| `fontFace`, `fontSize`, `valueFontSize`, `fontOutline`, `fontShadow` | own settings per size (Task 2): `fontFace`, `nameFontSize` 11, `secondFontSize` 10, `fontOutline` OUTLINE, `fontShadow` on (today's shipped look); the block titles take font and outline |
| `barTexture`, `healthColor` (health colour "fixed"), `backgroundColor` | own (Task 3), defaults Raid, the unit frames' green, black 60 % |
| `barNameColorMode` and the texts' white | `nameClassColor` (R2a) plus own `nameColor` and `secondLineColor` (Task 3), white by default, via `frame.textColors` |
| `borderShow`, `borderStyle`, `borderSize`, `borderColor`, `cornerRadius` | `cellBorder` (R2a) plus own `cellBorderStyle` GOLD, `cellBorderSize` 1, `cellBorderColor` black, `cellCornerRadius` 0 (Task 4); the switch moves to the Cell tab beside them |
| `borderPadding` | fixed 0: the ring hugs the cell, the cell spacing keeps cells apart (Task 4) |
| `healPrediction`, `healOverflow`, `absorbEnabled`, `combatFeedback` | own (Task 5): incoming heals on, overheal lane off, shields on, damage and heal numbers off |
| `healBeyond`, `shadowEnabled` | fixed off as before: the next cell sits there |
| `healMyColor`, `healOtherColor`, `absorbColor`, `absorbMode`, `powerColorMana`/`Rage`/`Energy`/`Focus`, `powerMatchesHealth` | fixed at the unit frames' shipped defaults (Task 1): the heal and shield colours are the game's familiar ones, the strip is coloured by power type; own settings can follow later (codes are append-only) |
| `auraBorder`, `auraBorderSize` | fixed at the shipped defaults (on, 1 px): the centre icon's and the row's border shows the debuff's type |
| `reactionHostileColor` (and the other reaction colours), `showSurname`, `textCompact`, `infoClassColor`, `levelColorMode`, `titleColorMode`, `titleText`, `titleTextRight`, `titleBackground`, `awayBadge` | fixed at the shipped defaults: cells have no title row and colour by class; the name shows the surname as shipped |
| the unit frames' aura groups (`buffs*`, `debuffs*`, `dispels*`), `classIcon*`, `portraitStyle`, `groupIcon*` placement, castbar, totems, threat bar … | fixed at the shipped defaults: the groups, badge, portrait and castbar are off for cells (`FIXED`), group icons are placed by `Cell.IconPoint` |
| `width`, `height`, `healthColorMode`, `powerEnabled`, `textHealthRight`, `raidMarker*`, `groupLeader`, `groupReadyCheck`, `groupIconSize`, `rangeFade`, `rangeAlpha`, title row, portrait, castbar, power texts … | mapped or fixed as before (R2a–R3b) |

  The guard (`tests/test_raid_cell_independent.lua`, Task 1) changes every party and General unit-frame setting to another valid value and requires every raid answer (cell, panel ring, block ring) to stay the same. How range is measured (`rangeFriendlyMode` and friends) is read by `Elements/Range.lua` from the unit frames' General settings, not through the raid scope: it is the character's measuring method, not the party frame's look, and stays shared.
- **Defaults keep today's look:** the new raid defaults are the shipped unit-frame values a cell showed so far (Core/Preset.lua: texture Raid, gold border, outline, shadow), except heal prediction on, overheal off, shields on, combat numbers off as decided.
- **Dispel square:** `dispelIcon` stays the switch ("Show the debuff"); `dispelStyle` ICON (the centre icon) or SQUARE. The square is a slot of its own (key `square`) with the icon's filter whose only region is a texture the client colours from `AuraButton.DispelCurve()` (the borders' opaque curve): no colour is computed by the addon. Its corner (four corners) and size (1–16 px, default 6); with a corner indicator that has spells in the same corner (`Indicators.SizeAt`), it moves inwards along the edge by that indicator's size and one pixel. The tint stays a switch of its own. Test mode draws it from the pretend member. The two debuff sizes (`dispelIconSize`, `debuffSize`) were already sliders on the Debuffs tab; the square's size joins them (Task 6 pins all four).
- **Raid minimap button:** its own button (`ForeverUnitFramesRaidMinimapButton`), icon `Media/RaidMinimapIcon.tga`, left click only (toggles the raid window, as `/fuf raid`, through `Commands.ToggleRaidOptions`), drag to move; `minimapShow` and `minimapAngle` (default 250°, beside the unit frames' button) in the raid profile's General settings, on the raid window's General tab. No LibDataBroker launcher of its own. Blizzard's addon compartment gets a second entry for the raid window (`RAID_COMPARTMENT`, the raid icon) through `AddonCompartmentFrame:RegisterAddon`; its text is set at login, in that language. R4b no longer adds Shift-click to the unit frames' button.
- **Typed values:** a refused class order or spell list prints why (`ns.Print`): the unknown or twice-named class, the spell name the spell book does not know (`Spellbook.Resolve`'s second return), or a resolved list longer than `Raid.SPELL_LIST_LETTERS`. The field still flashes and shows the stored value. `Raid.ParseClassOrder` returns `nil, "UNKNOWN"|"TWICE", word` on refusal.
- **Carry-overs:** sorted by role, the damage block (damage and members without a role) groups by role too, damage first; test mode ranks an unknown role with "no role" instead of failing on a nil comparison; clearer words (deDE arrangement and target line, esES/frFR hints); a unit frames' export pasted into the raid import is pinned as refused.

---


### Task 1: Raid cell: every unit-frame setting answered by the raid, none by the party frame

Cells stop following the party frame: whatever `FIXED` and `MAPPED` do not answer is the unit frames' shipped default for a party frame. The tasks after this one turn the keys that matter into raid settings.

**Files:**
- Modify: `Raid/Cell.lua`
- Modify: `Raid/Header.lua`
- Test: `tests/test_raid_cell.lua` (existing; its header comment and "party look otherwise" pin the party look, which cells no longer wear)
- Test: `tests/test_raid_header.lua` (existing; "unit-frame border size counts" pins that General's border size moves the cells, which it no longer does)
- Test: `tests/test_raid_cell_independent.lua`

**Interfaces:**
- Consumes: `ns.Config.Derive` (Core/Config.lua), `ns.Settings.Default`, `ns.Settings.Get`, `ns.Settings.All`, `ns.Party.KEY`, `Raid/Cell.lua`'s `FIXED` and `MAPPED`, `Raid/Header.lua`'s ring scopes.
- Produces: `ns.RaidCell.Resolve(key)` answers every unit-frame key (never nil); `Header.PANEL_SCOPE` and `Header.BLOCK_SCOPE` derive from `ns.RaidCell.KEY`; block titles use `Config.Get(Cell.KEY, "fontFace" / "fontOutline")`; `Raid/Header.lua` no longer listens to `CONFIG_CHANGED`.

- [ ] **Step 1: Write the failing tests**

The guard loads the addon as shipped (`H.LoadShipped()`, preset included), changes every party and General setting and compares every raid answer before and after.

In `tests/test_raid_cell.lua`:

Replace

```lua
-- Raid cells (Raid/Cell.lua, Raid/Cell.xml): unit buttons made by a group
-- header that run the unit-frame elements under the derived scope "raid":
-- the party look, a cell's fixed choices, the raid profile of the active
-- size. Clicks, click-casting, events per unit, the power strip's rule.
local M = H.M
local ns = H.LoadAddon()
local RC, Cell = ns.RaidConfig, ns.RaidCell
```

with

```lua
-- Raid cells (Raid/Cell.lua, Raid/Cell.xml): unit buttons made by a group
-- header that run the unit-frame elements under the derived scope "raid":
-- a cell's fixed choices, the raid profile of the active size, the unit
-- frames' shipped defaults for the rest. Clicks, click-casting, events
-- per unit, the power strip's rule.
local M = H.M
local ns = H.LoadAddon()
local RC, Cell = ns.RaidConfig, ns.RaidCell
```

In `tests/test_raid_cell.lua`:

Replace

```lua
H.check("name white", C.Get("raid", "barNameColorMode"), "WHITE")
H.check("no cell border", C.Get("raid", "borderShow"), false)
H.check("power strip on", C.Get("raid", "powerEnabled"), true)
H.check("party look otherwise", C.Get("raid", "barTexture"), C.Get("party", "barTexture"))
RC.Set("r10", "secondLine", "PERCENT")
RC.Set("r10", "nameClassColor", true)
RC.Set("r10", "cellBorder", true)
```

with

```lua
H.check("name white", C.Get("raid", "barNameColorMode"), "WHITE")
H.check("no cell border", C.Get("raid", "borderShow"), false)
H.check("power strip on", C.Get("raid", "powerEnabled"), true)
C.Set("party", "barTexture", "Other")
H.check("not the party frame's look", C.Get("raid", "barTexture") == "Other", false)
C.Set("party", "barTexture", "Flat")
RC.Set("r10", "secondLine", "PERCENT")
RC.Set("r10", "nameClassColor", true)
RC.Set("r10", "cellBorder", true)
```

In `tests/test_raid_header.lua`:

Replace

```lua
H.check("cell border: cells further apart", Header.headers[1]:GetAttribute("yOffset"), -4)
H.check("cell border: cells inside the block", point(Header.headers[1]), "TOPLEFT anchor TOPLEFT 1 -1")
ns.Config.Set("general", "borderSize", 2)
H.check("unit-frame border size counts", Header.headers[1]:GetAttribute("yOffset"), -6)
ns.Config.Set("general", "borderSize", 1)
RC.Set("r20", "cellBorder", false)

```

with

```lua
H.check("cell border: cells further apart", Header.headers[1]:GetAttribute("yOffset"), -4)
H.check("cell border: cells inside the block", point(Header.headers[1]), "TOPLEFT anchor TOPLEFT 1 -1")
ns.Config.Set("general", "borderSize", 2)
H.check("the unit frames' border size does not count", Header.headers[1]:GetAttribute("yOffset"), -4)
ns.Config.Set("general", "borderSize", 1)
RC.Set("r20", "cellBorder", false)

```

Create `tests/test_raid_cell_independent.lua`:

```lua
-- A raid cell answers every unit-frame setting itself (Raid/Cell.lua):
-- what the raid profile maps, what a cell fixes, and the unit frames'
-- shipped defaults for everything else, never what the party frame or
-- General is set to. The rings around the panel and the blocks
-- (Raid/Header.lua) take the cell's answers for what they do not fix.
-- The addon as shipped: its look (Core/Preset.lua) is the default.
local ns = H.LoadShipped()
local C, Settings, Header = ns.Config, ns.Settings, ns.RaidHeader
C.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

local SCOPES = { ns.RaidCell.KEY, Header.PANEL_SCOPE, Header.BLOCK_SCOPE }

local function text(v)
    if type(v) ~= "table" then return tostring(v) end
    return ("%s,%s,%s,%s"):format(tostring(v[1]), tostring(v[2]), tostring(v[3]), tostring(v[4]))
end

-- Every unit-frame setting as each raid scope answers it.
local function snapshot()
    local values = {}
    for _, def in ipairs(Settings.All()) do
        for _, scope in ipairs(SCOPES) do values[scope .. " " .. def.key] = text(C.Get(scope, def.key)) end
    end
    return values
end

-- A valid value other than the current one.
local function another(def, current)
    local t = def.type
    if t == "bool" then return not current end
    if t == "int" then return current == def.max and def.min or def.max end
    if t == "enum" then
        for _, v in ipairs(def.values) do
            if v ~= current then return v end
        end
    end
    if t == "color" then return current[1] == 0.5 and { 0.25, 0.5, 0.75, 1 } or { 0.5, 0.25, 0.125, 0.5 } end
    if t == "media" then return current == "Other" and "Another" or "Other" end
    if t == "text" then return current == "x" and "y" or "x" end
end

-- The shipped look before anything changes.
H.check("bar texture: the shipped one", C.Get("raid", "barTexture"), "Raid")
H.check("border style: the shipped one", C.Get("raid", "borderStyle"), "GOLD")
H.check("outline: the shipped one", C.Get("raid", "fontOutline"), "OUTLINE")

-- Every party and General setting changed.
local before = snapshot()
local changed = 0
for _, def in ipairs(Settings.All()) do
    for _, scope in ipairs({ "general", ns.Party.KEY }) do
        if Settings.AppliesTo(def, scope) and C.Set(scope, def.key, another(def, C.Get(scope, def.key))) then
            changed = changed + 1
        end
    end
end
H.check("party and General settings changed", changed, 243)
H.check("the party frame's texture did change", C.Get(ns.Party.KEY, "barTexture"), "Another")

-- Not one raid answer follows.
local after, follow = snapshot(), {}
for name, v in pairs(before) do
    if after[name] ~= v then follow[#follow + 1] = name end
end
table.sort(follow)
H.check("raid answers that follow the party frame or General", #follow, 0)
H.check("the first of them", follow[1], nil)
H.check("bar texture still the shipped one", C.Get("raid", "barTexture"), "Raid")
H.check("panel ring still gold", C.Get(Header.PANEL_SCOPE, "borderStyle"), "GOLD")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run test_raid_cell_independent.lua`

Expected:

```text
test_raid_cell_independent.lua
  FAIL raid answers that follow the party frame or General -> 485 (want 0)
  FAIL the first of them -> raid absorbColor (want nil)
  FAIL bar texture still the shipped one -> Another (want Raid)
6 passed, 3 failed
```

Run: `tests/run test_raid_cell.lua`

Expected:

```text
test_raid_cell.lua
  FAIL not the party frame's look -> true (want false)
72 passed, 1 failed
```

Run: `tests/run test_raid_header.lua`

Expected:

```text
test_raid_header.lua
  FAIL the unit frames' border size does not count -> -6 (want -4)
81 passed, 1 failed
```

- [ ] **Step 3: Every key answered by the cell**

In `Raid/Cell.lua`:

Replace

```lua
-- One raid cell: a unit button the block headers (Raid/Header.lua) make
-- from the template in Raid/Cell.xml, running the unit-frame elements
-- (ns.Elements) like a party member does. Its settings come through a
-- derived unit-frame scope, "raid": the party frame's look (fonts, bar
-- texture, colours, border style), with everything a cell never shows
-- switched off and the cell's own look taken from the raid profile of the
-- active size. Name and second line stand centred in the health bar
-- (Elements/Texts.lua, frame.centerTexts); the power strip follows its
-- own rule per unit (frame.showsPower).
--
-- No initialConfigFunction: secure snippets do not run on this client.
-- The XML gives a cell its starting size and clicks; Lua sizes it when
```

with

```lua
-- One raid cell: a unit button the block headers (Raid/Header.lua) make
-- from the template in Raid/Cell.xml, running the unit-frame elements
-- (ns.Elements) like a party member does. Its settings come through a
-- derived unit-frame scope, "raid", that answers every unit-frame setting
-- itself: the cell's look from the raid profile of the active size,
-- everything a cell never shows switched off, and the unit frames'
-- shipped defaults for the rest, so nothing set for the party frame or in
-- General changes a cell. Name and second line stand centred in the
-- health bar (Elements/Texts.lua, frame.centerTexts); the power strip
-- follows its own rule per unit (frame.showsPower).
--
-- No initialConfigFunction: secure snippets do not run on this client.
-- The XML gives a cell its starting size and clicks; Lua sizes it when
```

In `Raid/Cell.lua`:

Replace

```lua
    rangeAlpha = function() return get("rangeAlpha") end,
}

function Cell.Resolve(key)
    local fixed = FIXED[key]
    if fixed ~= nil then return fixed end
    local mapped = MAPPED[key]
    if mapped then return mapped() end
    return nil
end
Config.Derive(Cell.KEY, ns.Party.KEY, Cell.Resolve)

```

with

```lua
    rangeAlpha = function() return get("rangeAlpha") end,
}

-- Everything else is the unit frames' shipped default for a party frame
-- (Core/Settings.lua with the look of Core/Preset.lua), whatever the party
-- frame or General is set to: the heal, shield and power colours, the
-- aura icons' border, and what a cell has no use for (title texts, the
-- party's aura groups, castbar details ...). The party frame is the
-- derived scope's base only in name: every key is answered here.
local function shipped(key)
    return ns.Settings.Default(ns.Settings.Get(key), ns.Party.KEY)
end

function Cell.Resolve(key)
    local fixed = FIXED[key]
    if fixed ~= nil then return fixed end
    local mapped = MAPPED[key]
    if mapped then return mapped() end
    return shipped(key)
end
Config.Derive(Cell.KEY, ns.Party.KEY, Cell.Resolve)

```

- [ ] **Step 4: The rings and the block titles follow the cell; no restyle for the party frame**

In `Raid/Header.lua`:

Replace

```lua

-- The rings around the panel and around each block: the unit frames' gold
-- border (Core/Border.lua) in derived scopes of their own, square and
-- without shadow, shown while switched on in the raid profile.
local PANEL_RING = { borderStyle = "GOLD", borderSize = 3, borderPadding = 3, cornerRadius = 0, shadowEnabled = false }
local BLOCK_RING = { borderStyle = "GOLD", borderSize = 2, borderPadding = 1, cornerRadius = 0, shadowEnabled = false }
ns.Config.Derive(Header.PANEL_SCOPE, ns.Party.KEY, function(key)
    if key == "borderShow" then return get("panelBorder") end
    return PANEL_RING[key]
end)
ns.Config.Derive(Header.BLOCK_SCOPE, ns.Party.KEY, function(key)
    if key == "borderShow" then return get("blockBorder") end
    return BLOCK_RING[key]
end)
```

with

```lua

-- The rings around the panel and around each block: the unit frames' gold
-- border (Core/Border.lua) in derived scopes of their own, square and
-- without shadow, shown while switched on in the raid profile; the rest
-- as a cell answers it, never as the party frame is set.
local PANEL_RING = { borderStyle = "GOLD", borderSize = 3, borderPadding = 3, cornerRadius = 0, shadowEnabled = false }
local BLOCK_RING = { borderStyle = "GOLD", borderSize = 2, borderPadding = 1, cornerRadius = 0, shadowEnabled = false }
ns.Config.Derive(Header.PANEL_SCOPE, Cell.KEY, function(key)
    if key == "borderShow" then return get("panelBorder") end
    return PANEL_RING[key]
end)
ns.Config.Derive(Header.BLOCK_SCOPE, Cell.KEY, function(key)
    if key == "borderShow" then return get("blockBorder") end
    return BLOCK_RING[key]
end)
```

In `Raid/Header.lua`:

Replace

```lua
        return
    end
    local C = ns.Config
    ns.Texts.SetFont(title, ns.Media.Font(C.Get(ns.Party.KEY, "fontFace")), Header.TITLE_SIZE,
        C.Get(ns.Party.KEY, "fontOutline"))
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
    title:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, 0)
```

with

```lua
        return
    end
    local C = ns.Config
    ns.Texts.SetFont(title, ns.Media.Font(C.Get(Cell.KEY, "fontFace")), Header.TITLE_SIZE,
        C.Get(Cell.KEY, "fontOutline"))
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
    title:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, 0)
```

In `Raid/Header.lua`:

Replace

```lua
        ns.AfterCombat("partyStyle", ns.Party.StyleAll)
    end
end)
-- The cells wear the party look.
ns.Listen("CONFIG_CHANGED", function(scope)
    if not Header.anchor then return end
    if scope == nil or scope == "general" or scope == ns.Party.KEY then refresh() end
end)
ns.Listen("PIXEL_GRID_CHANGED", function() if Header.anchor then refresh() end end)

```

with

```lua
        ns.AfterCombat("partyStyle", ns.Party.StyleAll)
    end
end)
ns.Listen("PIXEL_GRID_CHANGED", function() if Header.anchor then refresh() end end)

```

- [ ] **Step 5: Run the tests**

Run: `tests/run test_raid_cell_independent.lua` → `9 passed, 0 failed`
Run: `tests/run test_raid_cell.lua` → `73 passed, 0 failed`
Run: `tests/run test_raid_header.lua` → `82 passed, 0 failed`
Run: `tests/run` → Expected: `22468 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add Raid/Cell.lua Raid/Header.lua tests/test_raid_cell.lua tests/test_raid_cell_independent.lua tests/test_raid_header.lua
git commit -m "Raid cell: every unit-frame setting answered by the raid, none by the party frame

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Raid cell: fonts of its own per raid size

**Files:**
- Modify: `Raid/Cell.lua`
- Modify: `Raid/Options/Schema.lua`
- Modify: `Raid/Settings.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_raid_fonts.lua`

**Interfaces:**
- Consumes: `ns.RaidSettings.Define`, `ns.Settings.Get("fontOutline").values`, `Raid/Cell.lua`'s `MAPPED`, `ns.RaidSchema.TABS`, `ns.Texts.SetFont` (through the elements).
- Produces: raid settings `fontFace` (FF), `nameFontSize` (NF), `secondFontSize` (SF), `fontOutline` (FO), `fontShadow` (FH); `MAPPED` `fontFace`, `fontSize`, `valueFontSize`, `fontOutline`, `fontShadow` (no longer `FIXED`); Texts tab section `fonts`; locale keys `RAID_SECTION_fonts`, `RAID_SETTING_fontFace`, `RAID_SETTING_nameFontSize`, `RAID_SETTING_secondFontSize`, `RAID_SETTING_fontOutline`, `RAID_SETTING_fontShadow`, `RAID_ENUM_fontOutline_NONE`/`OUTLINE`/`THICKOUTLINE`/`MONOCHROME`/`SOFT`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_fonts.lua`:

```lua
-- The raid cell's fonts (Raid/Settings.lua, Raid/Cell.lua): the face, the
-- name's size and the second line's, outline and shadow, per raid size;
-- the block titles take the face and the outline. The party frame's
-- fonts do not count.
local M = H.M
local ns = H.LoadAddon()
local RC, C, RS, Header = ns.RaidConfig, ns.Config, ns.RaidSettings, ns.RaidHeader
C.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

-- The settings, per size, at today's look.
local function default(key) return RS.Default(RS.Get(key), "r10") end
H.check("font", default("fontFace"), "Friz Quadrata")
H.check("name size", default("nameFontSize"), 11)
H.check("second line size", default("secondFontSize"), 10)
H.check("outline", default("fontOutline"), "OUTLINE")
H.check("shadow", default("fontShadow"), true)
H.check("outline choices: the unit frames'", table.concat(RS.Get("fontOutline").values, ","),
    "NONE,OUTLINE,THICKOUTLINE,MONOCHROME,SOFT")
local codes = {}
for i, key in ipairs({ "fontFace", "nameFontSize", "secondFontSize", "fontOutline", "fontShadow" }) do
    codes[i] = RS.Get(key).code
end
H.check("codes", table.concat(codes, " "), "FF NF SF FO FH")

-- The cell asks the raid profile.
H.check("cell font", C.Get("raid", "fontFace"), "Friz Quadrata")
H.check("cell name size", C.Get("raid", "fontSize"), 11)
H.check("cell value size", C.Get("raid", "valueFontSize"), 10)
H.check("cell outline", C.Get("raid", "fontOutline"), "OUTLINE")
H.check("cell shadow", C.Get("raid", "fontShadow"), true)
C.Set("party", "fontSize", 20)
H.check("not the party frame's size", C.Get("raid", "fontSize"), 11)

-- A cell in a raid, and its block's title.
local function member(name, class, subgroup)
    return { name = name, class = class, subgroup = subgroup, unit = { health = 60, healthMax = 100,
        healthMissing = 40, powerType = 0 } }
end
Header.Create()
M.SetRaidRoster({ member("Ann", "PRIEST", 1), member("Bob", "MAGE", 1) })
RC.Set("r10", "blockTitles", true)
local cell = Header.headers[1]:GetAttribute("child1")
local name, second = cell.texts.healthLeft, cell.texts.healthRight
local function font(fs) return table.concat({ fs:GetFont() }, " ") end
H.check("name font", font(name), "Fonts\\FRIZQT__.TTF 11 OUTLINE")
H.check("second line font", font(second), "Fonts\\FRIZQT__.TTF 10 OUTLINE")
H.check("shadow on", name._shadow[1], 1)
H.check("title font", font(Header.decor[1].title), "Fonts\\FRIZQT__.TTF 11 OUTLINE")

RC.Set("r10", "fontFace", "Arial Narrow")
RC.Set("r10", "nameFontSize", 13)
RC.Set("r10", "secondFontSize", 9)
RC.Set("r10", "fontOutline", "THICKOUTLINE")
RC.Set("r10", "fontShadow", false)
H.check("name font follows", font(name), "Fonts\\ARIALN.TTF 13 THICKOUTLINE")
H.check("second line font follows", font(second), "Fonts\\ARIALN.TTF 9 THICKOUTLINE")
H.check("shadow off", name._shadow[1], 0)
H.check("title font follows", font(Header.decor[1].title), "Fonts\\ARIALN.TTF 11 THICKOUTLINE")
H.check("other sizes keep theirs", RC.Get("r20", "nameFontSize"), 11)

-- In the window: their own section on the Texts tab.
local texts
for _, tab in ipairs(ns.RaidSchema.TABS) do
    if tab.id == "texts" then texts = tab end
end
H.check("fonts section", texts.sections[2].id, "fonts")
H.check("fonts section keys", table.concat(texts.sections[2].keys, ","),
    "fontFace,nameFontSize,secondFontSize,fontOutline,fontShadow")
H.check("section title", ns.RaidSchema.SectionTitle("fonts"), "Fonts")
H.check("label", ns.RaidSchema.Label("secondFontSize"), "Second line size")
H.check("outline word", ns.RaidSchema.EnumText(RS.Get("fontOutline"), "SOFT"), "Soft outline")
H.check("nothing blocked", #M.blocked, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_fonts.lua`

Expected:

```text
test_raid_fonts.lua
  ERROR .../Core/Registry.lua:73: attempt to index local 'def' (a nil value)
0 passed, 1 failed
```

- [ ] **Step 3: The settings**

In `Raid/Settings.lua`:

Replace

```lua
RaidSettings.Define({ key = "secondLine", code = "SL", scope = "frame", type = "enum",
    values = { "DEFICIT", "PERCENT", "CURRENT", "NONE" }, default = "DEFICIT" })
RaidSettings.Define({ key = "nameClassColor", code = "NC", scope = "frame", type = "bool", default = false })

-- Debuffs (Raid/CellAuras.lua). The centre icon shows the most important
-- debuff you can dispel (MINE, the client's RAID filter) or any
```

with

```lua
RaidSettings.Define({ key = "secondLine", code = "SL", scope = "frame", type = "enum",
    values = { "DEFICIT", "PERCENT", "CURRENT", "NONE" }, default = "DEFICIT" })
RaidSettings.Define({ key = "nameClassColor", code = "NC", scope = "frame", type = "bool", default = false })
-- The cell's texts: the font, the name's size and the second line's (the
-- status words too), outline and shadow; the block titles take the font
-- and the outline. The outlines are the unit frames' (Core/Settings.lua),
-- stored by index: append only.
RaidSettings.Define({ key = "fontFace", code = "FF", scope = "frame", type = "media", mediaKind = "font",
    default = "Friz Quadrata" })
RaidSettings.Define({ key = "nameFontSize", code = "NF", scope = "frame", type = "int", min = 6, max = 24, default = 11 })
RaidSettings.Define({ key = "secondFontSize", code = "SF", scope = "frame", type = "int", min = 6, max = 24,
    default = 10 })
RaidSettings.Define({ key = "fontOutline", code = "FO", scope = "frame", type = "enum",
    values = ns.Settings.Get("fontOutline").values, default = "OUTLINE" })
RaidSettings.Define({ key = "fontShadow", code = "FH", scope = "frame", type = "bool", default = true })

-- Debuffs (Raid/CellAuras.lua). The centre icon shows the most important
-- debuff you can dispel (MINE, the client's RAID filter) or any
```

- [ ] **Step 4: The cell asks them**

In `Raid/Cell.lua`:

Replace

```lua
    buffsEnabled = false, debuffsEnabled = false, threatGlow = false,
    titleClassIcon = false, healOverflow = false, healBeyond = false, shadowEnabled = false, groupResurrect = false,
    textHealthLeft = "NAME", textPowerLeft = "NONE", textPowerRight = "NONE",
    healthPercent = 90, powerPercent = 10, fontSize = 11, valueFontSize = 10,
}

-- An icon at one of the cell's points sits just inside it: a pixel in
```

with

```lua
    buffsEnabled = false, debuffsEnabled = false, threatGlow = false,
    titleClassIcon = false, healOverflow = false, healBeyond = false, shadowEnabled = false, groupResurrect = false,
    textHealthLeft = "NAME", textPowerLeft = "NONE", textPowerRight = "NONE",
    healthPercent = 90, powerPercent = 10,
}

-- An icon at one of the cell's points sits just inside it: a pixel in
```

In `Raid/Cell.lua`:

Replace

```lua
    powerEnabled = function() return get("powerStrip") ~= "OFF" end,
    textHealthRight = function() return get("secondLine") end,
    barNameColorMode = function() return get("nameClassColor") and "CLASS" or "WHITE" end,
    borderShow = function() return get("cellBorder") end,
    raidMarker = function() return get("raidMarker") end,
    raidMarkerSize = function() return get("iconSize") end,
```

with

```lua
    powerEnabled = function() return get("powerStrip") ~= "OFF" end,
    textHealthRight = function() return get("secondLine") end,
    barNameColorMode = function() return get("nameClassColor") and "CLASS" or "WHITE" end,
    fontFace = function() return get("fontFace") end,
    fontSize = function() return get("nameFontSize") end,
    valueFontSize = function() return get("secondFontSize") end,
    fontOutline = function() return get("fontOutline") end,
    fontShadow = function() return get("fontShadow") end,
    borderShow = function() return get("cellBorder") end,
    raidMarker = function() return get("raidMarker") end,
    raidMarkerSize = function() return get("iconSize") end,
```

- [ ] **Step 5: On the Texts tab**

In `Raid/Options/Schema.lua`:

Replace

```lua
    } },
    { id = "texts", sections = {
        { id = "texts", keys = { "nameClassColor", "secondLine" } },
    } },
    { id = "debuffs", sections = {
        { id = "dispel", keys = { "dispelIcon", "dispelFilter", "dispelIconSize", "dispelTint" } },
```

with

```lua
    } },
    { id = "texts", sections = {
        { id = "texts", keys = { "nameClassColor", "secondLine" } },
        { id = "fonts", keys = { "fontFace", "nameFontSize", "secondFontSize", "fontOutline", "fontShadow" } },
    } },
    { id = "debuffs", sections = {
        { id = "dispel", keys = { "dispelIcon", "dispelFilter", "dispelIconSize", "dispelTint" } },
```

- [ ] **Step 6: The words in English**

Append to the end of `Locales/enUS.lua`:

```lua

-- Raid frames: the cell's fonts.
L.RAID_SECTION_fonts = "Fonts"
L.RAID_SETTING_fontFace = "Font"
L.RAID_SETTING_nameFontSize = "Name size"
L.RAID_SETTING_secondFontSize = "Second line size"
L.RAID_SETTING_fontOutline = "Font style"
L.RAID_SETTING_fontShadow = "Font shadow"
L.RAID_ENUM_fontOutline_NONE = "None"
L.RAID_ENUM_fontOutline_OUTLINE = "Outline"
L.RAID_ENUM_fontOutline_THICKOUTLINE = "Thick outline"
L.RAID_ENUM_fontOutline_MONOCHROME = "Monochrome"
L.RAID_ENUM_fontOutline_SOFT = "Soft outline"
```

- [ ] **Step 7: German**

Append to the end of `Locales/deDE.lua`:

```lua

-- Schlachtzugsrahmen: die Schriften der Zelle.
L.RAID_SECTION_fonts = "Schriften"
L.RAID_SETTING_fontFace = "Schriftart"
L.RAID_SETTING_nameFontSize = "Größe des Namens"
L.RAID_SETTING_secondFontSize = "Größe der 2. Zeile"
L.RAID_SETTING_fontOutline = "Schriftstil"
L.RAID_SETTING_fontShadow = "Schriftschatten"
L.RAID_ENUM_fontOutline_NONE = "Keine"
L.RAID_ENUM_fontOutline_OUTLINE = "Kontur"
L.RAID_ENUM_fontOutline_THICKOUTLINE = "Dicke Kontur"
L.RAID_ENUM_fontOutline_MONOCHROME = "Monochrom"
L.RAID_ENUM_fontOutline_SOFT = "Weiche Kontur"
```

- [ ] **Step 8: Spanish**

Append to the end of `Locales/esES.lua`:

```lua

-- Marcos de banda: las fuentes de la celda.
L.RAID_SECTION_fonts = "Fuentes"
L.RAID_SETTING_fontFace = "Fuente"
L.RAID_SETTING_nameFontSize = "Tamaño del nombre"
L.RAID_SETTING_secondFontSize = "Tamaño de la 2.ª línea"
L.RAID_SETTING_fontOutline = "Estilo de fuente"
L.RAID_SETTING_fontShadow = "Sombra de fuente"
L.RAID_ENUM_fontOutline_NONE = "Ninguno"
L.RAID_ENUM_fontOutline_OUTLINE = "Contorno"
L.RAID_ENUM_fontOutline_THICKOUTLINE = "Contorno grueso"
L.RAID_ENUM_fontOutline_MONOCHROME = "Monocromo"
L.RAID_ENUM_fontOutline_SOFT = "Contorno suave"
```

- [ ] **Step 9: French**

Append to the end of `Locales/frFR.lua`:

```lua

-- Cadres de raid : les polices de la cellule.
L.RAID_SECTION_fonts = "Polices"
L.RAID_SETTING_fontFace = "Police"
L.RAID_SETTING_nameFontSize = "Taille du nom"
L.RAID_SETTING_secondFontSize = "Taille de la 2e ligne"
L.RAID_SETTING_fontOutline = "Style de police"
L.RAID_SETTING_fontShadow = "Ombre de police"
L.RAID_ENUM_fontOutline_NONE = "Aucun"
L.RAID_ENUM_fontOutline_OUTLINE = "Contour"
L.RAID_ENUM_fontOutline_THICKOUTLINE = "Contour épais"
L.RAID_ENUM_fontOutline_MONOCHROME = "Monochrome"
L.RAID_ENUM_fontOutline_SOFT = "Contour doux"
```

- [ ] **Step 10: Run the tests**

Run: `tests/run test_raid_fonts.lua` → `28 passed, 0 failed`
Run: `tests/run` → Expected: `22689 passed, 0 failed`

- [ ] **Step 11: Commit**

```bash
git add Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Raid/Cell.lua Raid/Options/Schema.lua Raid/Settings.lua tests/test_raid_fonts.lua
git commit -m "Raid cell: fonts of its own per raid size

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Raid cell: bar texture and colours of its own per raid size

**Files:**
- Modify: `Elements/Texts.lua`
- Modify: `Raid/Cell.lua`
- Modify: `Raid/Options/Schema.lua`
- Modify: `Raid/Settings.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_raid_colors.lua`

**Interfaces:**
- Consumes: `ns.RaidSettings.Define`, `Raid/Cell.lua`'s `MAPPED` and `Cell.Setup`, `Elements/Texts.lua`'s `paintBars`, `ns.Health.FrameColor`.
- Produces: raid settings `healthColor` (HC), `barTexture` (TX), `backgroundColor` (BG), `nameColor` (NA), `secondLineColor` (SC); `MAPPED` `healthColor`, `barTexture`, `backgroundColor`; `ns.RaidCell.TextColors()` → name colour, second-line colour; `button.textColors` on every cell, read by `Elements/Texts.lua` (white without it); locale keys `RAID_SETTING_healthColor`, `RAID_SETTING_barTexture`, `RAID_SETTING_backgroundColor`, `RAID_SETTING_nameColor`, `RAID_SETTING_secondLineColor`, `RAID_HINT_nameColor`; changed `RAID_NOTE_cell`, `RAID_ENUM_healthColorMode_STATIC`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_colors.lua`:

```lua
-- The raid cell's bar texture and colours (Raid/Settings.lua,
-- Raid/Cell.lua, Elements/Texts.lua): the texture, the fixed health
-- colour, the background, the name's colour (or its class colour) and
-- the second line's, per raid size. The party frame's do not count.
local M = H.M
local ns = H.LoadAddon()
local RC, C, RS, Header = ns.RaidConfig, ns.Config, ns.RaidSettings, ns.RaidHeader
C.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

-- The settings, per size, at today's look.
local function default(key)
    local v = RS.Default(RS.Get(key), "r10")
    if type(v) == "table" then return table.concat(v, " ") end
    return v
end
H.check("texture", default("barTexture"), "Raid")
H.check("fixed health colour", default("healthColor"), "0.2 0.75 0.3 1")
H.check("background", default("backgroundColor"), "0 0 0 0.6")
H.check("name colour", default("nameColor"), "1 1 1 1")
H.check("second line colour", default("secondLineColor"), "1 1 1 1")
local codes = {}
for i, key in ipairs({ "barTexture", "healthColor", "backgroundColor", "nameColor", "secondLineColor" }) do
    codes[i] = RS.Get(key).code
end
H.check("codes", table.concat(codes, " "), "TX HC BG NA SC")

-- The cell asks the raid profile.
H.check("cell texture", C.Get("raid", "barTexture"), "Raid")
RC.Set("r10", "healthColor", { 0.1, 0.2, 0.3, 1 })
H.check("cell health colour", C.Get("raid", "healthColor")[3], 0.3)
H.check("cell background", C.Get("raid", "backgroundColor")[4], 0.6)
C.Set("party", "barTexture", "Flat")
C.Set("party", "healthColor", { 1, 0, 0, 1 })
H.check("not the party frame's texture", C.Get("raid", "barTexture"), "Raid")
H.check("not the party frame's colour", C.Get("raid", "healthColor")[1], 0.1)

-- A cell in a raid.
local function member(name, class, subgroup)
    return { name = name, class = class, subgroup = subgroup, unit = { health = 60, healthMax = 100,
        healthMissing = 40, powerType = 0 } }
end
Header.Create()
M.SetRaidRoster({ member("Ann", "MAGE", 1), member("Bob", "PRIEST", 1) })
local cell = Header.headers[1]:GetAttribute("child1")
local function color(c) return table.concat({ c[1], c[2], c[3], c[4] }, " ") end
H.check("health texture", cell.health._texture, "Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
H.check("background colour", color(cell.healthBg._color), "0 0 0 0.6")
H.check("name white", color(cell.texts.healthLeft._color), "1 1 1 1")
H.check("second line white", color(cell.texts.healthRight._color), "1 1 1 1")

RC.Set("r10", "healthColorMode", "STATIC")
RC.Set("r10", "barTexture", "Flat")
RC.Set("r10", "backgroundColor", { 0.1, 0.1, 0.1, 0.8 })
RC.Set("r10", "nameColor", { 1, 0.8, 0, 1 })
RC.Set("r10", "secondLineColor", { 0.6, 0.6, 0.6, 1 })
H.check("health in the fixed colour", table.concat(cell.health._color, " ", 1, 3), "0.1 0.2 0.3")
H.check("texture follows", cell.health._texture, "Interface\\Buttons\\WHITE8X8")
H.check("background follows", color(cell.healthBg._color), "0.1 0.1 0.1 0.8")
H.check("name colour", color(cell.texts.healthLeft._color), "1 0.8 0 1")
H.check("second line colour", color(cell.texts.healthRight._color), "0.6 0.6 0.6 1")
RC.Set("r10", "nameClassColor", true)
local r, g, b = ns.Health.UnitColor(cell.unit, "CLASS")
H.check("a mage's blue", r < 1, true)
H.check("class colour wins", color(cell.texts.healthLeft._color), table.concat({ r, g, b, 1 }, " "))
H.check("second line keeps its colour", color(cell.texts.healthRight._color), "0.6 0.6 0.6 1")

-- A unit frame keeps white texts.
local party = CreateFrame("Button", nil, UIParent, "SecureUnitButtonTemplate")
party.key = "party"
for _, el in ipairs(ns.Elements) do el.Build(party) end
ns.Single.StyleContent(party)
M.units.player = { name = "Me", class = "MAGE", isPlayer = true, health = 50, healthMax = 100, healthMissing = 50 }
ns.Single.SetUnit(party, "player")
ns.Single.UpdateAll(party)
H.check("unit frame: value text white", color(party.texts.healthRight._color), "1 1 1 1")

-- In the window.
local function tab(id)
    for _, t in ipairs(ns.RaidSchema.TABS) do
        if t.id == id then return t end
    end
end
H.check("bars section", table.concat(tab("cell").sections[2].keys, ","),
    "healthColorMode,healthColor,barTexture,backgroundColor,powerStrip")
H.check("texts section", table.concat(tab("texts").sections[1].keys, ","),
    "nameClassColor,nameColor,secondLine,secondLineColor")
H.check("fixed colour choice", ns.RaidSchema.EnumText(RS.Get("healthColorMode"), "STATIC"), "Fixed color")
H.check("label", ns.RaidSchema.Label("nameColor"), "Name color")
H.check("the cell's note", ns.RaidSchema.Note("cell"), "Heals, shields and the power strip keep the unit frames' standard colors.")
H.check("nothing blocked", #M.blocked, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_colors.lua`

Expected:

```text
test_raid_colors.lua
  ERROR .../Core/Registry.lua:73: attempt to index local 'def' (a nil value)
0 passed, 1 failed
```

- [ ] **Step 3: The settings**

In `Raid/Settings.lua`:

Replace

```lua
RaidSettings.Define({ key = "blockBorder", code = "BB", scope = "frame", type = "bool", default = false })
RaidSettings.Define({ key = "cellBorder", code = "CB", scope = "frame", type = "bool", default = false })

-- The cell (Raid/Cell.lua). Health in the class colour, the unit-frame
-- health colour, or a gradient by health. Stored by index: append only.
RaidSettings.Define({ key = "healthColorMode", code = "HM", scope = "frame", type = "enum",
    values = { "CLASS", "STATIC", "GRADIENT" }, default = "CLASS" })
-- The power strip at the bottom: everyone, mana users, healers, nobody.
RaidSettings.Define({ key = "powerStrip", code = "PS", scope = "frame", type = "enum",
    values = { "ALL", "MANA", "HEALERS", "OFF" }, default = "MANA" })
```

with

```lua
RaidSettings.Define({ key = "blockBorder", code = "BB", scope = "frame", type = "bool", default = false })
RaidSettings.Define({ key = "cellBorder", code = "CB", scope = "frame", type = "bool", default = false })

-- The cell (Raid/Cell.lua). Health in the class colour, a fixed colour
-- (healthColor), or a gradient by health. Stored by index: append only.
RaidSettings.Define({ key = "healthColorMode", code = "HM", scope = "frame", type = "enum",
    values = { "CLASS", "STATIC", "GRADIENT" }, default = "CLASS" })
RaidSettings.Define({ key = "healthColor", code = "HC", scope = "frame", type = "color",
    default = { 0.2, 0.75, 0.3, 1 } })
-- The bars' texture and the colour behind them.
RaidSettings.Define({ key = "barTexture", code = "TX", scope = "frame", type = "media", mediaKind = "statusbar",
    default = "Raid" })
RaidSettings.Define({ key = "backgroundColor", code = "BG", scope = "frame", type = "color",
    default = { 0, 0, 0, 0.6 } })
-- The power strip at the bottom: everyone, mana users, healers, nobody.
RaidSettings.Define({ key = "powerStrip", code = "PS", scope = "frame", type = "enum",
    values = { "ALL", "MANA", "HEALERS", "OFF" }, default = "MANA" })
```

In `Raid/Settings.lua`:

Replace

```lua
RaidSettings.Define({ key = "secondLine", code = "SL", scope = "frame", type = "enum",
    values = { "DEFICIT", "PERCENT", "CURRENT", "NONE" }, default = "DEFICIT" })
RaidSettings.Define({ key = "nameClassColor", code = "NC", scope = "frame", type = "bool", default = false })
-- The cell's texts: the font, the name's size and the second line's (the
-- status words too), outline and shadow; the block titles take the font
-- and the outline. The outlines are the unit frames' (Core/Settings.lua),
```

with

```lua
RaidSettings.Define({ key = "secondLine", code = "SL", scope = "frame", type = "enum",
    values = { "DEFICIT", "PERCENT", "CURRENT", "NONE" }, default = "DEFICIT" })
RaidSettings.Define({ key = "nameClassColor", code = "NC", scope = "frame", type = "bool", default = false })
-- The name's colour when it is not in the class colour, and the second
-- line's (the status words too).
RaidSettings.Define({ key = "nameColor", code = "NA", scope = "frame", type = "color", default = { 1, 1, 1, 1 } })
RaidSettings.Define({ key = "secondLineColor", code = "SC", scope = "frame", type = "color",
    default = { 1, 1, 1, 1 } })
-- The cell's texts: the font, the name's size and the second line's (the
-- status words too), outline and shadow; the block titles take the font
-- and the outline. The outlines are the unit frames' (Core/Settings.lua),
```

- [ ] **Step 4: Colours for a cell's texts**

In `Elements/Texts.lua`:

Replace

```lua
-- texts and the status word stay white.
Texts.NAME_TAGS = { NAME = true, NAME_LEVEL = true, INFO = true }

local function paintBars(frame, wordSlot)
    local mode = Config.Get(frame.key, "barNameColorMode")
    local r, g, b = 1, 1, 1
    if mode ~= "WHITE" then r, g, b = ns.Health.FrameColor(frame, mode) end
    for _, slot in ipairs(SLOTS) do
        if slot.bar ~= "title" then
            local named = slot.field ~= wordSlot and Texts.NAME_TAGS[Config.Get(frame.key, slot.setting)]
            if named then
                frame.texts[slot.field]:SetTextColor(r, g, b, 1)
            else
                frame.texts[slot.field]:SetTextColor(1, 1, 1, 1)
            end
        end
    end
```

with

```lua
-- texts and the status word stay white.
Texts.NAME_TAGS = { NAME = true, NAME_LEVEL = true, INFO = true }

-- Raid cells (Raid/Cell.lua) set frame.textColors: it returns the colours
-- of a name and of the other texts in place of white (a name in the class
-- or reaction colour keeps that). No unit frame sets it.
local WHITE = { 1, 1, 1, 1 }

local function plainColors(frame)
    if frame.textColors then return frame.textColors(frame) end
    return WHITE, WHITE
end

local function paintBars(frame, wordSlot)
    local mode = Config.Get(frame.key, "barNameColorMode")
    local name, other = plainColors(frame)
    local r, g, b, a = name[1], name[2], name[3], name[4]
    if mode ~= "WHITE" then
        r, g, b = ns.Health.FrameColor(frame, mode)
        a = 1
    end
    for _, slot in ipairs(SLOTS) do
        if slot.bar ~= "title" then
            local named = slot.field ~= wordSlot and Texts.NAME_TAGS[Config.Get(frame.key, slot.setting)]
            if named then
                frame.texts[slot.field]:SetTextColor(r, g, b, a)
            else
                frame.texts[slot.field]:SetTextColor(other[1], other[2], other[3], other[4])
            end
        end
    end
```

- [ ] **Step 5: The cell asks the settings and hands over its text colours**

In `Raid/Cell.lua`:

Replace

```lua
    width = function() return get("cellWidth") end,
    height = function() return get("cellHeight") end,
    healthColorMode = function() return get("healthColorMode") end,
    powerEnabled = function() return get("powerStrip") ~= "OFF" end,
    textHealthRight = function() return get("secondLine") end,
    barNameColorMode = function() return get("nameClassColor") and "CLASS" or "WHITE" end,
```

with

```lua
    width = function() return get("cellWidth") end,
    height = function() return get("cellHeight") end,
    healthColorMode = function() return get("healthColorMode") end,
    healthColor = function() return get("healthColor") end,
    barTexture = function() return get("barTexture") end,
    backgroundColor = function() return get("backgroundColor") end,
    powerEnabled = function() return get("powerStrip") ~= "OFF" end,
    textHealthRight = function() return get("secondLine") end,
    barNameColorMode = function() return get("nameClassColor") and "CLASS" or "WHITE" end,
```

In `Raid/Cell.lua`:

Replace

```lua
    return true
end

-- What every cell is, real or pretend.
function Cell.Setup(button)
    button.key = Cell.KEY
    button.centerTexts = true
    button.showsPower = Cell.ShowsPower
    button.iconPoint = Cell.IconPoint
    button.fadesOutOfRange = true
```

with

```lua
    return true
end

-- The colours of the name and of the second line (Elements/Texts.lua
-- asks): the name's gives way to the class colour when that is on.
function Cell.TextColors()
    return get("nameColor"), get("secondLineColor")
end

-- What every cell is, real or pretend.
function Cell.Setup(button)
    button.key = Cell.KEY
    button.centerTexts = true
    button.textColors = Cell.TextColors
    button.showsPower = Cell.ShowsPower
    button.iconPoint = Cell.IconPoint
    button.fadesOutOfRange = true
```

- [ ] **Step 6: On the Cell and Texts tabs**

In `Raid/Options/Schema.lua`:

Replace

```lua
        { id = "position", keys = { "x", "y" } },
        { id = "borders", keys = { "panelBorder", "blockBorder", "cellBorder" } },
    } },
    -- The cells wear the party frame's look (bar texture, font, heal and
    -- shield colours): the note says so.
    { id = "cell", note = "cell", sections = {
        { id = "size", keys = { "cellWidth", "cellHeight" } },
        { id = "bars", keys = { "healthColorMode", "powerStrip" } },
    } },
    { id = "texts", sections = {
        { id = "texts", keys = { "nameClassColor", "secondLine" } },
        { id = "fonts", keys = { "fontFace", "nameFontSize", "secondFontSize", "fontOutline", "fontShadow" } },
    } },
    { id = "debuffs", sections = {
```

with

```lua
        { id = "position", keys = { "x", "y" } },
        { id = "borders", keys = { "panelBorder", "blockBorder", "cellBorder" } },
    } },
    -- Heals, shields and the power strip keep the unit frames' shipped
    -- colours (Raid/Cell.lua): the note says so.
    { id = "cell", note = "cell", sections = {
        { id = "size", keys = { "cellWidth", "cellHeight" } },
        { id = "bars", keys = { "healthColorMode", "healthColor", "barTexture", "backgroundColor", "powerStrip" } },
    } },
    { id = "texts", sections = {
        { id = "texts", keys = { "nameClassColor", "nameColor", "secondLine", "secondLineColor" } },
        { id = "fonts", keys = { "fontFace", "nameFontSize", "secondFontSize", "fontOutline", "fontShadow" } },
    } },
    { id = "debuffs", sections = {
```

- [ ] **Step 7: The words in English**

In `Locales/enUS.lua`:

Replace

```lua
L.RAID_TAB_debuffs = "Debuffs"
L.RAID_TAB_indicators = "Indicators"
L.RAID_TAB_icons = "Icons & states"
L.RAID_NOTE_cell = "Bar texture, font and the colors of heals and shields follow the party frame."
L.RAID_SECTION_raidFrames = "Raid frames"
L.RAID_SECTION_grouping = "Grouping"
L.RAID_SECTION_arrangement = "Arrangement"
```

with

```lua
L.RAID_TAB_debuffs = "Debuffs"
L.RAID_TAB_indicators = "Indicators"
L.RAID_TAB_icons = "Icons & states"
L.RAID_NOTE_cell = "Heals, shields and the power strip keep the unit frames' standard colors."
L.RAID_SECTION_raidFrames = "Raid frames"
L.RAID_SECTION_grouping = "Grouping"
L.RAID_SECTION_arrangement = "Arrangement"
```

In `Locales/enUS.lua`:

Replace

```lua
L.RAID_ENUM_cellGrowth_DOWN = "Down"
L.RAID_ENUM_cellGrowth_RIGHT = "Right"
L.RAID_ENUM_healthColorMode_CLASS = "Class"
L.RAID_ENUM_healthColorMode_STATIC = "The party frame's color"
L.RAID_ENUM_healthColorMode_GRADIENT = "Gradient by health"
L.RAID_ENUM_powerStrip_ALL = "Everyone"
L.RAID_ENUM_powerStrip_MANA = "Mana users"
```

with

```lua
L.RAID_ENUM_cellGrowth_DOWN = "Down"
L.RAID_ENUM_cellGrowth_RIGHT = "Right"
L.RAID_ENUM_healthColorMode_CLASS = "Class"
L.RAID_ENUM_healthColorMode_STATIC = "Fixed color"
L.RAID_ENUM_healthColorMode_GRADIENT = "Gradient by health"
L.RAID_ENUM_powerStrip_ALL = "Everyone"
L.RAID_ENUM_powerStrip_MANA = "Mana users"
```

Append to the end of `Locales/enUS.lua`:

```lua

-- Raid frames: the cell's texture and colors.
L.RAID_SETTING_healthColor = "Fixed health color"
L.RAID_SETTING_barTexture = "Bar texture"
L.RAID_SETTING_backgroundColor = "Background color"
L.RAID_SETTING_nameColor = "Name color"
L.RAID_SETTING_secondLineColor = "Second line color"
L.RAID_HINT_nameColor = "Unless the name is in its class color"
```

- [ ] **Step 8: German**

In `Locales/deDE.lua`:

Replace

```lua
L.RAID_TAB_debuffs = "Debuffs"
L.RAID_TAB_indicators = "Indikatoren"
L.RAID_TAB_icons = "Symbole & Zustände"
L.RAID_NOTE_cell = "Leistentextur, Schrift und die Farben von Heilungen und Schilden folgen dem Gruppenrahmen."
L.RAID_SECTION_raidFrames = "Schlachtzugsrahmen"
L.RAID_SECTION_grouping = "Gruppierung"
L.RAID_SECTION_arrangement = "Anordnung"
```

with

```lua
L.RAID_TAB_debuffs = "Debuffs"
L.RAID_TAB_indicators = "Indikatoren"
L.RAID_TAB_icons = "Symbole & Zustände"
L.RAID_NOTE_cell = "Heilungen, Schilde und der Ressourcenstreifen behalten die Standardfarben der Einheitenrahmen."
L.RAID_SECTION_raidFrames = "Schlachtzugsrahmen"
L.RAID_SECTION_grouping = "Gruppierung"
L.RAID_SECTION_arrangement = "Anordnung"
```

In `Locales/deDE.lua`:

Replace

```lua
L.RAID_ENUM_cellGrowth_DOWN = "Nach unten"
L.RAID_ENUM_cellGrowth_RIGHT = "Nach rechts"
L.RAID_ENUM_healthColorMode_CLASS = "Klasse"
L.RAID_ENUM_healthColorMode_STATIC = "Farbe des Gruppenrahmens"
L.RAID_ENUM_healthColorMode_GRADIENT = "Verlauf nach Gesundheit"
L.RAID_ENUM_powerStrip_ALL = "Alle"
L.RAID_ENUM_powerStrip_MANA = "Manaklassen"
```

with

```lua
L.RAID_ENUM_cellGrowth_DOWN = "Nach unten"
L.RAID_ENUM_cellGrowth_RIGHT = "Nach rechts"
L.RAID_ENUM_healthColorMode_CLASS = "Klasse"
L.RAID_ENUM_healthColorMode_STATIC = "Feste Farbe"
L.RAID_ENUM_healthColorMode_GRADIENT = "Verlauf nach Gesundheit"
L.RAID_ENUM_powerStrip_ALL = "Alle"
L.RAID_ENUM_powerStrip_MANA = "Manaklassen"
```

Append to the end of `Locales/deDE.lua`:

```lua

-- Schlachtzugsrahmen: Textur und Farben der Zelle.
L.RAID_SETTING_healthColor = "Feste Gesundheitsfarbe"
L.RAID_SETTING_barTexture = "Leistentextur"
L.RAID_SETTING_backgroundColor = "Hintergrundfarbe"
L.RAID_SETTING_nameColor = "Farbe des Namens"
L.RAID_SETTING_secondLineColor = "Farbe der 2. Zeile"
L.RAID_HINT_nameColor = "Außer der Name steht in Klassenfarbe"
```

- [ ] **Step 9: Spanish**

In `Locales/esES.lua`:

Replace

```lua
L.RAID_TAB_debuffs = "Perjuicios"
L.RAID_TAB_indicators = "Indicadores"
L.RAID_TAB_icons = "Iconos y estados"
L.RAID_NOTE_cell = "La textura de barra, la fuente y los colores de sanaciones y escudos siguen al marco de grupo."
L.RAID_SECTION_raidFrames = "Marcos de banda"
L.RAID_SECTION_grouping = "Agrupación"
L.RAID_SECTION_arrangement = "Disposición"
```

with

```lua
L.RAID_TAB_debuffs = "Perjuicios"
L.RAID_TAB_indicators = "Indicadores"
L.RAID_TAB_icons = "Iconos y estados"
L.RAID_NOTE_cell = "Las sanaciones, los escudos y la franja de recurso usan los colores estándar de los marcos de unidad."
L.RAID_SECTION_raidFrames = "Marcos de banda"
L.RAID_SECTION_grouping = "Agrupación"
L.RAID_SECTION_arrangement = "Disposición"
```

In `Locales/esES.lua`:

Replace

```lua
L.RAID_ENUM_cellGrowth_DOWN = "Hacia abajo"
L.RAID_ENUM_cellGrowth_RIGHT = "Hacia la derecha"
L.RAID_ENUM_healthColorMode_CLASS = "Clase"
L.RAID_ENUM_healthColorMode_STATIC = "Color del marco de grupo"
L.RAID_ENUM_healthColorMode_GRADIENT = "Degradado según la salud"
L.RAID_ENUM_powerStrip_ALL = "Todos"
L.RAID_ENUM_powerStrip_MANA = "Usuarios de maná"
```

with

```lua
L.RAID_ENUM_cellGrowth_DOWN = "Hacia abajo"
L.RAID_ENUM_cellGrowth_RIGHT = "Hacia la derecha"
L.RAID_ENUM_healthColorMode_CLASS = "Clase"
L.RAID_ENUM_healthColorMode_STATIC = "Color fijo"
L.RAID_ENUM_healthColorMode_GRADIENT = "Degradado según la salud"
L.RAID_ENUM_powerStrip_ALL = "Todos"
L.RAID_ENUM_powerStrip_MANA = "Usuarios de maná"
```

Append to the end of `Locales/esES.lua`:

```lua

-- Marcos de banda: textura y colores de la celda.
L.RAID_SETTING_healthColor = "Color de salud fijo"
L.RAID_SETTING_barTexture = "Textura de barra"
L.RAID_SETTING_backgroundColor = "Color de fondo"
L.RAID_SETTING_nameColor = "Color del nombre"
L.RAID_SETTING_secondLineColor = "Color de la 2.ª línea"
L.RAID_HINT_nameColor = "Salvo si el nombre va en color de clase"
```

- [ ] **Step 10: French**

In `Locales/frFR.lua`:

Replace

```lua
L.RAID_TAB_debuffs = "Affaiblissements"
L.RAID_TAB_indicators = "Indicateurs"
L.RAID_TAB_icons = "Icônes et états"
L.RAID_NOTE_cell = "La texture des barres, la police et les couleurs des soins et boucliers suivent le cadre de groupe."
L.RAID_SECTION_raidFrames = "Cadres de raid"
L.RAID_SECTION_grouping = "Regroupement"
L.RAID_SECTION_arrangement = "Agencement"
```

with

```lua
L.RAID_TAB_debuffs = "Affaiblissements"
L.RAID_TAB_indicators = "Indicateurs"
L.RAID_TAB_icons = "Icônes et états"
L.RAID_NOTE_cell = "Les soins, les boucliers et la bande de ressource gardent les couleurs standard des cadres d'unité."
L.RAID_SECTION_raidFrames = "Cadres de raid"
L.RAID_SECTION_grouping = "Regroupement"
L.RAID_SECTION_arrangement = "Agencement"
```

In `Locales/frFR.lua`:

Replace

```lua
L.RAID_ENUM_cellGrowth_DOWN = "Vers le bas"
L.RAID_ENUM_cellGrowth_RIGHT = "Vers la droite"
L.RAID_ENUM_healthColorMode_CLASS = "Classe"
L.RAID_ENUM_healthColorMode_STATIC = "Couleur du cadre de groupe"
L.RAID_ENUM_healthColorMode_GRADIENT = "Dégradé selon la santé"
L.RAID_ENUM_powerStrip_ALL = "Tout le monde"
L.RAID_ENUM_powerStrip_MANA = "Utilisateurs de mana"
```

with

```lua
L.RAID_ENUM_cellGrowth_DOWN = "Vers le bas"
L.RAID_ENUM_cellGrowth_RIGHT = "Vers la droite"
L.RAID_ENUM_healthColorMode_CLASS = "Classe"
L.RAID_ENUM_healthColorMode_STATIC = "Couleur fixe"
L.RAID_ENUM_healthColorMode_GRADIENT = "Dégradé selon la santé"
L.RAID_ENUM_powerStrip_ALL = "Tout le monde"
L.RAID_ENUM_powerStrip_MANA = "Utilisateurs de mana"
```

Append to the end of `Locales/frFR.lua`:

```lua

-- Cadres de raid : texture et couleurs de la cellule.
L.RAID_SETTING_healthColor = "Couleur de santé fixe"
L.RAID_SETTING_barTexture = "Texture des barres"
L.RAID_SETTING_backgroundColor = "Couleur de fond"
L.RAID_SETTING_nameColor = "Couleur du nom"
L.RAID_SETTING_secondLineColor = "Couleur de la 2e ligne"
L.RAID_HINT_nameColor = "Sauf si le nom est en couleur de classe"
```

- [ ] **Step 11: Run the tests**

Run: `tests/run test_raid_colors.lua` → `30 passed, 0 failed`
Run: `tests/run` → Expected: `22847 passed, 0 failed`

- [ ] **Step 12: Commit**

```bash
git add Elements/Texts.lua Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Raid/Cell.lua Raid/Options/Schema.lua Raid/Settings.lua tests/test_raid_colors.lua
git commit -m "Raid cell: bar texture and colours of its own per raid size

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Raid cell: border style, thickness, colour and corner radius of its own

**Files:**
- Modify: `Raid/Cell.lua`
- Modify: `Raid/Options/Schema.lua`
- Modify: `Raid/Settings.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_raid_cell_border.lua`

**Interfaces:**
- Consumes: `ns.RaidSettings.Define`, `ns.Settings.Get("borderStyle").values`, `Raid/Cell.lua`'s `FIXED` and `MAPPED`, `Core/Border.lua` (through the cell), `Raid/Header.lua`'s `Header.Shape` (cell gaps from `Border.Extent`).
- Produces: raid settings `cellBorderStyle` (CY), `cellBorderSize` (CZ), `cellBorderColor` (CK), `cellCornerRadius` (CR); `MAPPED` `borderStyle`, `borderSize`, `borderColor`, `cornerRadius`; `FIXED` `borderPadding = 0`; Cell tab section `cellShape` (with `cellBorder`, moved from Layout's borders); locale keys `RAID_SECTION_cellShape`, `RAID_SETTING_cellBorderStyle`, `RAID_SETTING_cellBorderSize`, `RAID_SETTING_cellBorderColor`, `RAID_SETTING_cellCornerRadius`, `RAID_HINT_cellBorderColor`, `RAID_HINT_cellCornerRadius`, `RAID_ENUM_cellBorderStyle_FLAT`/`GOLD`; changed `RAID_SETTING_cellBorder`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_cell_border.lua`:

```lua
-- The raid cell's border and corners (Raid/Settings.lua, Raid/Cell.lua):
-- the ring around each cell (switched on the Cell tab now) in its own
-- style, thickness and colour, and the cell's corner radius, per raid
-- size. The party frame's border does not count.
local M = H.M
local ns = H.LoadAddon()
local RC, C, RS, Header = ns.RaidConfig, ns.Config, ns.RaidSettings, ns.RaidHeader
C.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

-- The settings, per size, at today's look.
local function default(key)
    local v = RS.Default(RS.Get(key), "r10")
    if type(v) == "table" then return table.concat(v, " ") end
    return v
end
H.check("style", default("cellBorderStyle"), "GOLD")
H.check("style choices: the unit frames'", table.concat(RS.Get("cellBorderStyle").values, ","), "FLAT,GOLD")
H.check("thickness", default("cellBorderSize"), 1)
H.check("colour", default("cellBorderColor"), "0 0 0 1")
H.check("corner radius", default("cellCornerRadius"), 0)
local codes = {}
for i, key in ipairs({ "cellBorderStyle", "cellBorderSize", "cellBorderColor", "cellCornerRadius" }) do
    codes[i] = RS.Get(key).code
end
H.check("codes", table.concat(codes, " "), "CY CZ CK CR")

-- The cell asks the raid profile; the ring hugs the cell.
H.check("cell style", C.Get("raid", "borderStyle"), "GOLD")
H.check("cell thickness", C.Get("raid", "borderSize"), 1)
H.check("cell radius", C.Get("raid", "cornerRadius"), 0)
H.check("no padding", C.Get("raid", "borderPadding"), 0)
C.Set("party", "borderStyle", "FLAT")
C.Set("party", "cornerRadius", 6)
C.Set("party", "borderPadding", 4)
H.check("not the party frame's style", C.Get("raid", "borderStyle"), "GOLD")
H.check("not the party frame's radius", C.Get("raid", "cornerRadius"), 0)
H.check("not the party frame's padding", C.Get("raid", "borderPadding"), 0)
RC.Set("r10", "cellBorderStyle", "FLAT")
RC.Set("r10", "cellBorderSize", 3)
RC.Set("r10", "cellBorderColor", { 0.5, 0, 0, 1 })
RC.Set("r10", "cellCornerRadius", 4)
H.check("style follows", C.Get("raid", "borderStyle"), "FLAT")
H.check("thickness follows", C.Get("raid", "borderSize"), 3)
H.check("colour follows", C.Get("raid", "borderColor")[1], 0.5)
H.check("radius follows", C.Get("raid", "cornerRadius"), 4)
RC.ResetScope("r10")

-- Cells in a raid: the ring's thickness sets them apart.
local function member(name, subgroup)
    return { name = name, class = "MAGE", subgroup = subgroup, unit = { health = 60, healthMax = 100, powerType = 0 } }
end
Header.Create()
M.SetRaidRoster({ member("Ann", 1), member("Bob", 1) })
RC.Set("r10", "cellBorder", true)
H.check("thin ring: cells apart", Header.headers[1]:GetAttribute("yOffset"), -4)
RC.Set("r10", "cellBorderSize", 2)
H.check("thicker ring: further apart", Header.headers[1]:GetAttribute("yOffset"), -6)
RC.Set("r10", "cellBorderStyle", "FLAT")
RC.Set("r10", "cellBorderColor", { 0.5, 0, 0, 1 })
local cell = Header.headers[1]:GetAttribute("child1")
H.check("ring in its colour", cell.frameRing.border[1]._color[1], 0.5)

-- In the window: the switch with the ring's look on the Cell tab.
local function tab(id)
    for _, t in ipairs(ns.RaidSchema.TABS) do
        if t.id == id then return t end
    end
end
H.check("cell section", tab("cell").sections[3].id, "cellShape")
H.check("cell section keys", table.concat(tab("cell").sections[3].keys, ","),
    "cellBorder,cellBorderStyle,cellBorderSize,cellBorderColor,cellCornerRadius")
H.check("layout borders", table.concat(tab("layout").sections[4].keys, ","), "panelBorder,blockBorder")
H.check("section title", ns.RaidSchema.SectionTitle("cellShape"), "Border and corners")
H.check("switch label", ns.RaidSchema.Label("cellBorder"), "Border around the cell")
H.check("style word", ns.RaidSchema.EnumText(RS.Get("cellBorderStyle"), "GOLD"), "Gold")
H.check("nothing blocked", #M.blocked, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_cell_border.lua`

Expected:

```text
test_raid_cell_border.lua
  ERROR .../Core/Registry.lua:73: attempt to index local 'def' (a nil value)
0 passed, 1 failed
```

- [ ] **Step 3: The settings**

In `Raid/Settings.lua`:

Replace

```lua
RaidSettings.Define({ key = "panelBorder", code = "PB", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "blockBorder", code = "BB", scope = "frame", type = "bool", default = false })
RaidSettings.Define({ key = "cellBorder", code = "CB", scope = "frame", type = "bool", default = false })

-- The cell (Raid/Cell.lua). Health in the class colour, a fixed colour
-- (healthColor), or a gradient by health. Stored by index: append only.
```

with

```lua
RaidSettings.Define({ key = "panelBorder", code = "PB", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "blockBorder", code = "BB", scope = "frame", type = "bool", default = false })
RaidSettings.Define({ key = "cellBorder", code = "CB", scope = "frame", type = "bool", default = false })
-- The cell's ring (Core/Border.lua): the unit frames' styles, stored by
-- index: append only; the colour is the flat style's. The corner radius
-- rounds the cell's bars, with or without a ring.
RaidSettings.Define({ key = "cellBorderStyle", code = "CY", scope = "frame", type = "enum",
    values = ns.Settings.Get("borderStyle").values, default = "GOLD" })
RaidSettings.Define({ key = "cellBorderSize", code = "CZ", scope = "frame", type = "int", min = 1, max = 8, default = 1 })
RaidSettings.Define({ key = "cellBorderColor", code = "CK", scope = "frame", type = "color", default = { 0, 0, 0, 1 } })
RaidSettings.Define({ key = "cellCornerRadius", code = "CR", scope = "frame", type = "int", min = 0, max = 12,
    default = 0 })

-- The cell (Raid/Cell.lua). Health in the class colour, a fixed colour
-- (healthColor), or a gradient by health. Stored by index: append only.
```

- [ ] **Step 4: The cell asks them; its ring hugs it**

In `Raid/Cell.lua`:

Replace

```lua
-- portrait, castbar, the unit frames' aura icons (a cell's are its own,
-- Raid/CellAuras.lua), combat numbers or threat glow, no overheal lane or
-- heals past the edge (the next cell sits there), no shadow (it would lie
-- on the neighbours), no power texts. The rows: a thin power strip under
-- the health bar.
local FIXED = {
    titlePercent = 0, portraitMode = "OFF", castbarEnabled = false, combatFeedback = false,
    buffsEnabled = false, debuffsEnabled = false, threatGlow = false,
    titleClassIcon = false, healOverflow = false, healBeyond = false, shadowEnabled = false, groupResurrect = false,
    textHealthLeft = "NAME", textPowerLeft = "NONE", textPowerRight = "NONE",
    healthPercent = 90, powerPercent = 10,
}

-- An icon at one of the cell's points sits just inside it: a pixel in
```

with

```lua
-- portrait, castbar, the unit frames' aura icons (a cell's are its own,
-- Raid/CellAuras.lua), combat numbers or threat glow, no overheal lane or
-- heals past the edge (the next cell sits there), no shadow (it would lie
-- on the neighbours), no power texts, a ring right around the cell (the
-- cell spacing keeps them apart). The rows: a thin power strip under the
-- health bar.
local FIXED = {
    titlePercent = 0, portraitMode = "OFF", castbarEnabled = false, combatFeedback = false,
    buffsEnabled = false, debuffsEnabled = false, threatGlow = false,
    titleClassIcon = false, healOverflow = false, healBeyond = false, shadowEnabled = false, groupResurrect = false,
    textHealthLeft = "NAME", textPowerLeft = "NONE", textPowerRight = "NONE",
    healthPercent = 90, powerPercent = 10, borderPadding = 0,
}

-- An icon at one of the cell's points sits just inside it: a pixel in
```

In `Raid/Cell.lua`:

Replace

```lua
    fontOutline = function() return get("fontOutline") end,
    fontShadow = function() return get("fontShadow") end,
    borderShow = function() return get("cellBorder") end,
    raidMarker = function() return get("raidMarker") end,
    raidMarkerSize = function() return get("iconSize") end,
    raidMarkerFramePoint = function() return get("raidMarkerPoint") end,
```

with

```lua
    fontOutline = function() return get("fontOutline") end,
    fontShadow = function() return get("fontShadow") end,
    borderShow = function() return get("cellBorder") end,
    borderStyle = function() return get("cellBorderStyle") end,
    borderSize = function() return get("cellBorderSize") end,
    borderColor = function() return get("cellBorderColor") end,
    cornerRadius = function() return get("cellCornerRadius") end,
    raidMarker = function() return get("raidMarker") end,
    raidMarkerSize = function() return get("iconSize") end,
    raidMarkerFramePoint = function() return get("raidMarkerPoint") end,
```

- [ ] **Step 5: On the Cell tab**

In `Raid/Options/Schema.lua`:

Replace

```lua
        { id = "arrangement", keys = { "blockDirection", "blocksPerLine", "blockSpacing", "cellGrowth",
            "cellsPerLine", "cellSpacing" } },
        { id = "position", keys = { "x", "y" } },
        { id = "borders", keys = { "panelBorder", "blockBorder", "cellBorder" } },
    } },
    -- Heals, shields and the power strip keep the unit frames' shipped
    -- colours (Raid/Cell.lua): the note says so.
    { id = "cell", note = "cell", sections = {
        { id = "size", keys = { "cellWidth", "cellHeight" } },
        { id = "bars", keys = { "healthColorMode", "healthColor", "barTexture", "backgroundColor", "powerStrip" } },
    } },
    { id = "texts", sections = {
        { id = "texts", keys = { "nameClassColor", "nameColor", "secondLine", "secondLineColor" } },
```

with

```lua
        { id = "arrangement", keys = { "blockDirection", "blocksPerLine", "blockSpacing", "cellGrowth",
            "cellsPerLine", "cellSpacing" } },
        { id = "position", keys = { "x", "y" } },
        { id = "borders", keys = { "panelBorder", "blockBorder" } },
    } },
    -- Heals, shields and the power strip keep the unit frames' shipped
    -- colours (Raid/Cell.lua): the note says so.
    { id = "cell", note = "cell", sections = {
        { id = "size", keys = { "cellWidth", "cellHeight" } },
        { id = "bars", keys = { "healthColorMode", "healthColor", "barTexture", "backgroundColor", "powerStrip" } },
        { id = "cellShape", keys = { "cellBorder", "cellBorderStyle", "cellBorderSize", "cellBorderColor",
            "cellCornerRadius" } },
    } },
    { id = "texts", sections = {
        { id = "texts", keys = { "nameClassColor", "nameColor", "secondLine", "secondLineColor" } },
```

- [ ] **Step 6: The words in English**

In `Locales/enUS.lua`:

Replace

```lua
L.RAID_SETTING_hideEmpty = "Hide empty blocks"
L.RAID_SETTING_panelBorder = "Around the panel"
L.RAID_SETTING_blockBorder = "Around each block"
L.RAID_SETTING_cellBorder = "Around each cell"
L.RAID_SETTING_healthColorMode = "Health color"
L.RAID_SETTING_powerStrip = "Power strip"
L.RAID_SETTING_secondLine = "Second line"
```

with

```lua
L.RAID_SETTING_hideEmpty = "Hide empty blocks"
L.RAID_SETTING_panelBorder = "Around the panel"
L.RAID_SETTING_blockBorder = "Around each block"
L.RAID_SETTING_cellBorder = "Border around the cell"
L.RAID_SETTING_healthColorMode = "Health color"
L.RAID_SETTING_powerStrip = "Power strip"
L.RAID_SETTING_secondLine = "Second line"
```

Append to the end of `Locales/enUS.lua`:

```lua

-- Raid frames: the cell's border and corners.
L.RAID_SECTION_cellShape = "Border and corners"
L.RAID_SETTING_cellBorderStyle = "Border style"
L.RAID_SETTING_cellBorderSize = "Border size"
L.RAID_SETTING_cellBorderColor = "Border color"
L.RAID_SETTING_cellCornerRadius = "Corner radius"
L.RAID_HINT_cellBorderColor = "For the flat style"
L.RAID_HINT_cellCornerRadius = "0 = square corners"
L.RAID_ENUM_cellBorderStyle_FLAT = "Flat"
L.RAID_ENUM_cellBorderStyle_GOLD = "Gold"
```

- [ ] **Step 7: German**

In `Locales/deDE.lua`:

Replace

```lua
L.RAID_SETTING_hideEmpty = "Leere Blöcke ausblenden"
L.RAID_SETTING_panelBorder = "Um das Feld"
L.RAID_SETTING_blockBorder = "Um jeden Block"
L.RAID_SETTING_cellBorder = "Um jede Zelle"
L.RAID_SETTING_healthColorMode = "Gesundheitsfarbe"
L.RAID_SETTING_powerStrip = "Ressourcenstreifen"
L.RAID_SETTING_secondLine = "Zweite Zeile"
```

with

```lua
L.RAID_SETTING_hideEmpty = "Leere Blöcke ausblenden"
L.RAID_SETTING_panelBorder = "Um das Feld"
L.RAID_SETTING_blockBorder = "Um jeden Block"
L.RAID_SETTING_cellBorder = "Rahmen um die Zelle"
L.RAID_SETTING_healthColorMode = "Gesundheitsfarbe"
L.RAID_SETTING_powerStrip = "Ressourcenstreifen"
L.RAID_SETTING_secondLine = "Zweite Zeile"
```

Append to the end of `Locales/deDE.lua`:

```lua

-- Schlachtzugsrahmen: Rahmen und Ecken der Zelle.
L.RAID_SECTION_cellShape = "Rahmen und Ecken"
L.RAID_SETTING_cellBorderStyle = "Rahmenstil"
L.RAID_SETTING_cellBorderSize = "Rahmenstärke"
L.RAID_SETTING_cellBorderColor = "Rahmenfarbe"
L.RAID_SETTING_cellCornerRadius = "Eckenradius"
L.RAID_HINT_cellBorderColor = "Für den flachen Stil"
L.RAID_HINT_cellCornerRadius = "0 = eckig"
L.RAID_ENUM_cellBorderStyle_FLAT = "Flach"
L.RAID_ENUM_cellBorderStyle_GOLD = "Gold"
```

- [ ] **Step 8: Spanish**

In `Locales/esES.lua`:

Replace

```lua
L.RAID_SETTING_hideEmpty = "Ocultar bloques vacíos"
L.RAID_SETTING_panelBorder = "Alrededor del panel"
L.RAID_SETTING_blockBorder = "Alrededor de cada bloque"
L.RAID_SETTING_cellBorder = "Alrededor de cada celda"
L.RAID_SETTING_healthColorMode = "Color de salud"
L.RAID_SETTING_powerStrip = "Franja de recurso"
L.RAID_SETTING_secondLine = "Segunda línea"
```

with

```lua
L.RAID_SETTING_hideEmpty = "Ocultar bloques vacíos"
L.RAID_SETTING_panelBorder = "Alrededor del panel"
L.RAID_SETTING_blockBorder = "Alrededor de cada bloque"
L.RAID_SETTING_cellBorder = "Borde alrededor de la celda"
L.RAID_SETTING_healthColorMode = "Color de salud"
L.RAID_SETTING_powerStrip = "Franja de recurso"
L.RAID_SETTING_secondLine = "Segunda línea"
```

Append to the end of `Locales/esES.lua`:

```lua

-- Marcos de banda: borde y esquinas de la celda.
L.RAID_SECTION_cellShape = "Borde y esquinas"
L.RAID_SETTING_cellBorderStyle = "Estilo del borde"
L.RAID_SETTING_cellBorderSize = "Grosor del borde"
L.RAID_SETTING_cellBorderColor = "Color del borde"
L.RAID_SETTING_cellCornerRadius = "Radio de las esquinas"
L.RAID_HINT_cellBorderColor = "Para el estilo plano"
L.RAID_HINT_cellCornerRadius = "0 = esquinas rectas"
L.RAID_ENUM_cellBorderStyle_FLAT = "Plano"
L.RAID_ENUM_cellBorderStyle_GOLD = "Dorado"
```

- [ ] **Step 9: French**

In `Locales/frFR.lua`:

Replace

```lua
L.RAID_SETTING_hideEmpty = "Masquer les blocs vides"
L.RAID_SETTING_panelBorder = "Autour du panneau"
L.RAID_SETTING_blockBorder = "Autour de chaque bloc"
L.RAID_SETTING_cellBorder = "Autour de chaque cellule"
L.RAID_SETTING_healthColorMode = "Couleur de la santé"
L.RAID_SETTING_powerStrip = "Bande de ressource"
L.RAID_SETTING_secondLine = "Deuxième ligne"
```

with

```lua
L.RAID_SETTING_hideEmpty = "Masquer les blocs vides"
L.RAID_SETTING_panelBorder = "Autour du panneau"
L.RAID_SETTING_blockBorder = "Autour de chaque bloc"
L.RAID_SETTING_cellBorder = "Bordure autour de la cellule"
L.RAID_SETTING_healthColorMode = "Couleur de la santé"
L.RAID_SETTING_powerStrip = "Bande de ressource"
L.RAID_SETTING_secondLine = "Deuxième ligne"
```

Append to the end of `Locales/frFR.lua`:

```lua

-- Cadres de raid : bordure et coins de la cellule.
L.RAID_SECTION_cellShape = "Bordure et coins"
L.RAID_SETTING_cellBorderStyle = "Style de bordure"
L.RAID_SETTING_cellBorderSize = "Épaisseur de la bordure"
L.RAID_SETTING_cellBorderColor = "Couleur de la bordure"
L.RAID_SETTING_cellCornerRadius = "Rayon des coins"
L.RAID_HINT_cellBorderColor = "Pour le style plat"
L.RAID_HINT_cellCornerRadius = "0 = coins carrés"
L.RAID_ENUM_cellBorderStyle_FLAT = "Plat"
L.RAID_ENUM_cellBorderStyle_GOLD = "Or"
```

- [ ] **Step 10: Run the tests**

Run: `tests/run test_raid_cell_border.lua` → `27 passed, 0 failed`
Run: `tests/run` → Expected: `23031 passed, 0 failed`

- [ ] **Step 11: Commit**

```bash
git add Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Raid/Cell.lua Raid/Options/Schema.lua Raid/Settings.lua tests/test_raid_cell_border.lua
git commit -m "Raid cell: border style, thickness, colour and corner radius of its own

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Raid cell: heals, overheal lane, shields and combat numbers switched per raid size

**Files:**
- Modify: `Raid/Cell.lua`
- Modify: `Raid/Options/Schema.lua`
- Modify: `Raid/Settings.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_raid_cell_heals.lua`

**Interfaces:**
- Consumes: `ns.RaidSettings.Define`, `Raid/Cell.lua`'s `FIXED` and `MAPPED`, `Elements/HealPrediction.lua` (`frame.healClip`), `Elements/Absorb.lua` (`frame.absorbClip`), `Elements/CombatFeedback.lua`.
- Produces: raid settings `healPrediction` (IH, on), `overheal` (OV, off), `absorbs` (AS, on), `combatText` (CT, off); `MAPPED` `healPrediction`, `healOverflow`, `absorbEnabled`, `combatFeedback` (no longer `FIXED`); `healBeyond` stays fixed off; Cell tab section `heals`; locale keys `RAID_SECTION_heals`, `RAID_SETTING_healPrediction`, `RAID_SETTING_overheal`, `RAID_SETTING_absorbs`, `RAID_SETTING_combatText`, `RAID_HINT_overheal`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_cell_heals.lua`:

```lua
-- Heals, shields and combat numbers on a raid cell (Raid/Settings.lua,
-- Raid/Cell.lua): incoming heals (on), the overheal lane (off), absorb
-- shields (on) and the damage and heal numbers (off), per raid size. The
-- party frame's switches do not count; heals past the cell's edge stay
-- off (the next cell sits there).
local M = H.M
local ns = H.LoadAddon()
local RC, C, RS, Header = ns.RaidConfig, ns.Config, ns.RaidSettings, ns.RaidHeader
C.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

local KEYS = { healPrediction = true, overheal = false, absorbs = true, combatText = false }
local codes = {}
for i, key in ipairs({ "healPrediction", "overheal", "absorbs", "combatText" }) do
    H.check("default " .. key, RS.Default(RS.Get(key), "r10"), KEYS[key])
    codes[i] = RS.Get(key).code
end
H.check("codes", table.concat(codes, " "), "IH OV AS CT")

-- The cell asks the raid profile.
H.check("cell heals", C.Get("raid", "healPrediction"), true)
H.check("cell overheal lane", C.Get("raid", "healOverflow"), false)
H.check("cell shields", C.Get("raid", "absorbEnabled"), true)
H.check("cell numbers", C.Get("raid", "combatFeedback"), false)
H.check("never past the edge", C.Get("raid", "healBeyond"), false)
C.Set("party", "healPrediction", false)
C.Set("party", "absorbEnabled", false)
C.Set("party", "combatFeedback", true)
H.check("not the party frame's heals", C.Get("raid", "healPrediction"), true)
H.check("not the party frame's shields", C.Get("raid", "absorbEnabled"), true)
H.check("not the party frame's numbers", C.Get("raid", "combatFeedback"), false)

-- On a cell in a raid.
local function member(name, subgroup)
    return { name = name, class = "MAGE", subgroup = subgroup, unit = { health = 60, healthMax = 100, powerType = 0 } }
end
Header.Create()
M.SetRaidRoster({ member("Ann", 1), member("Bob", 1) })
local cell = Header.headers[1]:GetAttribute("child1")
H.check("heals shown", cell.healClip:IsShown(), true)
H.check("shield shown", cell.absorbClip:IsShown(), true)
RC.Set("r10", "healPrediction", false)
RC.Set("r10", "absorbs", false)
RC.Set("r10", "overheal", true)
RC.Set("r10", "combatText", true)
H.check("heals off", cell.healClip:IsShown(), false)
H.check("shield off", cell.absorbClip:IsShown(), false)
H.check("overheal lane on", C.Get("raid", "healOverflow"), true)
H.check("numbers on", C.Get("raid", "combatFeedback"), true)
H.check("other sizes keep theirs", RC.Get("r20", "healPrediction"), true)

-- In the window: a section of their own on the Cell tab.
local cellTab
for _, t in ipairs(ns.RaidSchema.TABS) do
    if t.id == "cell" then cellTab = t end
end
H.check("heals section", cellTab.sections[4].id, "heals")
H.check("heals section keys", table.concat(cellTab.sections[4].keys, ","),
    "healPrediction,overheal,absorbs,combatText")
H.check("section title", ns.RaidSchema.SectionTitle("heals"), "Heals and shields")
H.check("label", ns.RaidSchema.Label("overheal"), "Overheal lane")
H.check("nothing blocked", #M.blocked, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_cell_heals.lua`

Expected:

```text
test_raid_cell_heals.lua
  ERROR .../Core/Registry.lua:73: attempt to index local 'def' (a nil value)
0 passed, 1 failed
```

- [ ] **Step 3: The settings**

In `Raid/Settings.lua`:

Replace

```lua
    default = "Raid" })
RaidSettings.Define({ key = "backgroundColor", code = "BG", scope = "frame", type = "color",
    default = { 0, 0, 0, 0.6 } })
-- The power strip at the bottom: everyone, mana users, healers, nobody.
RaidSettings.Define({ key = "powerStrip", code = "PS", scope = "frame", type = "enum",
    values = { "ALL", "MANA", "HEALERS", "OFF" }, default = "MANA" })
```

with

```lua
    default = "Raid" })
RaidSettings.Define({ key = "backgroundColor", code = "BG", scope = "frame", type = "color",
    default = { 0, 0, 0, 0.6 } })
-- Incoming heals, the overheal lane at the end of the health bar (heals
-- past full health; never past the cell's edge), absorb shields, and the
-- damage and heal numbers in the cell.
RaidSettings.Define({ key = "healPrediction", code = "IH", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "overheal", code = "OV", scope = "frame", type = "bool", default = false })
RaidSettings.Define({ key = "absorbs", code = "AS", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "combatText", code = "CT", scope = "frame", type = "bool", default = false })
-- The power strip at the bottom: everyone, mana users, healers, nobody.
RaidSettings.Define({ key = "powerStrip", code = "PS", scope = "frame", type = "enum",
    values = { "ALL", "MANA", "HEALERS", "OFF" }, default = "MANA" })
```

- [ ] **Step 4: The cell asks them**

In `Raid/Cell.lua`:

Replace

```lua
end
local get = Cell.Get

-- What a cell never shows, whatever the party frame does: no title row,
-- portrait, castbar, the unit frames' aura icons (a cell's are its own,
-- Raid/CellAuras.lua), combat numbers or threat glow, no overheal lane or
-- heals past the edge (the next cell sits there), no shadow (it would lie
-- on the neighbours), no power texts, a ring right around the cell (the
-- cell spacing keeps them apart). The rows: a thin power strip under the
-- health bar.
local FIXED = {
    titlePercent = 0, portraitMode = "OFF", castbarEnabled = false, combatFeedback = false,
    buffsEnabled = false, debuffsEnabled = false, threatGlow = false,
    titleClassIcon = false, healOverflow = false, healBeyond = false, shadowEnabled = false, groupResurrect = false,
    textHealthLeft = "NAME", textPowerLeft = "NONE", textPowerRight = "NONE",
    healthPercent = 90, powerPercent = 10, borderPadding = 0,
}
```

with

```lua
end
local get = Cell.Get

-- What a cell never shows: no title row, portrait, castbar, the unit
-- frames' aura icons (a cell's are its own, Raid/CellAuras.lua) or threat
-- glow, no heals past the edge (the next cell sits there), no shadow (it
-- would lie on the neighbours), no power texts, a ring right around the
-- cell (the cell spacing keeps them apart). The rows: a thin power strip
-- under the health bar.
local FIXED = {
    titlePercent = 0, portraitMode = "OFF", castbarEnabled = false,
    buffsEnabled = false, debuffsEnabled = false, threatGlow = false,
    titleClassIcon = false, healBeyond = false, shadowEnabled = false, groupResurrect = false,
    textHealthLeft = "NAME", textPowerLeft = "NONE", textPowerRight = "NONE",
    healthPercent = 90, powerPercent = 10, borderPadding = 0,
}
```

In `Raid/Cell.lua`:

Replace

```lua
    barTexture = function() return get("barTexture") end,
    backgroundColor = function() return get("backgroundColor") end,
    powerEnabled = function() return get("powerStrip") ~= "OFF" end,
    textHealthRight = function() return get("secondLine") end,
    barNameColorMode = function() return get("nameClassColor") and "CLASS" or "WHITE" end,
    fontFace = function() return get("fontFace") end,
```

with

```lua
    barTexture = function() return get("barTexture") end,
    backgroundColor = function() return get("backgroundColor") end,
    powerEnabled = function() return get("powerStrip") ~= "OFF" end,
    healPrediction = function() return get("healPrediction") end,
    healOverflow = function() return get("overheal") end,
    absorbEnabled = function() return get("absorbs") end,
    combatFeedback = function() return get("combatText") end,
    textHealthRight = function() return get("secondLine") end,
    barNameColorMode = function() return get("nameClassColor") and "CLASS" or "WHITE" end,
    fontFace = function() return get("fontFace") end,
```

- [ ] **Step 5: On the Cell tab**

In `Raid/Options/Schema.lua`:

Replace

```lua
        { id = "bars", keys = { "healthColorMode", "healthColor", "barTexture", "backgroundColor", "powerStrip" } },
        { id = "cellShape", keys = { "cellBorder", "cellBorderStyle", "cellBorderSize", "cellBorderColor",
            "cellCornerRadius" } },
    } },
    { id = "texts", sections = {
        { id = "texts", keys = { "nameClassColor", "nameColor", "secondLine", "secondLineColor" } },
```

with

```lua
        { id = "bars", keys = { "healthColorMode", "healthColor", "barTexture", "backgroundColor", "powerStrip" } },
        { id = "cellShape", keys = { "cellBorder", "cellBorderStyle", "cellBorderSize", "cellBorderColor",
            "cellCornerRadius" } },
        { id = "heals", keys = { "healPrediction", "overheal", "absorbs", "combatText" } },
    } },
    { id = "texts", sections = {
        { id = "texts", keys = { "nameClassColor", "nameColor", "secondLine", "secondLineColor" } },
```

- [ ] **Step 6: The words in English**

Append to the end of `Locales/enUS.lua`:

```lua

-- Raid frames: heals, shields and numbers on the cell.
L.RAID_SECTION_heals = "Heals and shields"
L.RAID_SETTING_healPrediction = "Incoming heals"
L.RAID_SETTING_overheal = "Overheal lane"
L.RAID_SETTING_absorbs = "Absorb shields"
L.RAID_SETTING_combatText = "Damage and heal numbers"
L.RAID_HINT_overheal = "Heals past full health at the bar's end"
```

- [ ] **Step 7: German**

Append to the end of `Locales/deDE.lua`:

```lua

-- Schlachtzugsrahmen: Heilungen, Schilde und Zahlen auf der Zelle.
L.RAID_SECTION_heals = "Heilungen und Schilde"
L.RAID_SETTING_healPrediction = "Eingehende Heilung"
L.RAID_SETTING_overheal = "Überheilungsspur"
L.RAID_SETTING_absorbs = "Absorptionsschilde"
L.RAID_SETTING_combatText = "Schadens- und Heilzahlen"
L.RAID_HINT_overheal = "Heilung über volle Gesundheit am Leistenende"
```

- [ ] **Step 8: Spanish**

Append to the end of `Locales/esES.lua`:

```lua

-- Marcos de banda: sanaciones, escudos y números en la celda.
L.RAID_SECTION_heals = "Sanaciones y escudos"
L.RAID_SETTING_healPrediction = "Sanación entrante"
L.RAID_SETTING_overheal = "Carril de sobrecuración"
L.RAID_SETTING_absorbs = "Escudos de absorción"
L.RAID_SETTING_combatText = "Números de daño y sanación"
L.RAID_HINT_overheal = "Sanación por encima del máximo, al final"
```

- [ ] **Step 9: French**

Append to the end of `Locales/frFR.lua`:

```lua

-- Cadres de raid : soins, boucliers et chiffres sur la cellule.
L.RAID_SECTION_heals = "Soins et boucliers"
L.RAID_SETTING_healPrediction = "Soins entrants"
L.RAID_SETTING_overheal = "Couloir des soins en excès"
L.RAID_SETTING_absorbs = "Boucliers d'absorption"
L.RAID_SETTING_combatText = "Chiffres de dégâts et de soins"
L.RAID_HINT_overheal = "Soins au-delà de la santé max., en fin de barre"
```

- [ ] **Step 10: Run the tests**

Run: `tests/run test_raid_cell_heals.lua` → `25 passed, 0 failed`
Run: `tests/run` → Expected: `23174 passed, 0 failed`

- [ ] **Step 11: Commit**

```bash
git add Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Raid/Cell.lua Raid/Options/Schema.lua Raid/Settings.lua tests/test_raid_cell_heals.lua
git commit -m "Raid cell: heals, overheal lane, shields and combat numbers switched per raid size

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Raid cell: the dispellable debuff as a square in a corner

**Files:**
- Modify: `Raid/CellAuras.lua`
- Modify: `Raid/Indicators.lua`
- Modify: `Raid/Options/Schema.lua`
- Modify: `Raid/Settings.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_raid_dispel_square.lua`

**Interfaces:**
- Consumes: `ns.RaidAuras.SetSlot`, `ns.RaidAuras.AddPart`, `ns.AuraButton.DispelCurve()`, `ns.AuraButton.DISPEL_COLORS`, `Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset`, the slot frame's `AddDispelTypeTexture`, `ns.RaidCell.Inset`, `ns.RaidIndicators.INSET`, `ns.Raid.INDICATORS`, `ns.RaidOptions.Open` / `rows` (row `.slider`).
- Produces: raid settings `dispelStyle` (DM: ICON, SQUARE), `dispelSquarePoint` (DP: TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT), `dispelSquareSize` (DQ, 1–16, default 6); container slot `square` (frame field `.square`: the texture); `ns.RaidIndicators.SizeAt(point)` → the size of an indicator with spells at that point, or nil; `ns.RaidAuras.SQUARE_GAP = 1`; pretend cells' `samples.square` (`.texture`); locale keys `RAID_SETTING_dispelStyle`, `RAID_SETTING_dispelSquarePoint`, `RAID_SETTING_dispelSquareSize`, `RAID_HINT_dispelSquarePoint`, `RAID_HINT_dispelSquareSize`, `RAID_ENUM_dispelStyle_ICON`/`SQUARE`, `RAID_ENUM_dispelSquarePoint_*` (4); changed `RAID_SETTING_dispelIcon`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_dispel_square.lua`:

```lua
-- The dispellable debuff as a small square in a corner of a raid cell
-- (Raid/CellAuras.lua): a slot of its own with the centre icon's filter,
-- whose only region is a texture the client colours by dispel type
-- through our colour curve; its corner and size (from one pixel) per raid
-- size. A corner indicator in the same corner pushes it inwards. The tint
-- stays a switch of its own. Test mode draws it from the pretend members.
local M = H.M
local ns = H.LoadAddon()
local RC, RS, Header, CellAuras, Cell = ns.RaidConfig, ns.RaidSettings, ns.RaidHeader, ns.RaidAuras, ns.RaidCell
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

-- The settings.
H.check("style", RS.Default(RS.Get("dispelStyle"), "r10"), "ICON")
H.check("styles", table.concat(RS.Get("dispelStyle").values, ","), "ICON,SQUARE")
H.check("corner", RS.Default(RS.Get("dispelSquarePoint"), "r10"), "TOPRIGHT")
H.check("corners", table.concat(RS.Get("dispelSquarePoint").values, ","), "TOPLEFT,TOPRIGHT,BOTTOMLEFT,BOTTOMRIGHT")
H.check("size", RS.Default(RS.Get("dispelSquareSize"), "r10"), 6)
H.check("from one pixel", RS.Get("dispelSquareSize").min, 1)
H.check("codes", RS.Get("dispelStyle").code .. " " .. RS.Get("dispelSquarePoint").code .. " "
    .. RS.Get("dispelSquareSize").code, "DM DP DQ")

local function member(name, class, subgroup)
    return { name = name, class = class, subgroup = subgroup, assignedRole = "DAMAGER" }
end
M.SetRaidRoster({ member("Ann", "PRIEST", 1), member("Bob", "MAGE", 1) })
M.RunTimers()
local cell = Header.headers[1]:GetAttribute("child1")
local c = cell.raidAuras.container

-- Off by default: no slot for it.
H.check("no square slot", c._slots.square, nil)

-- The square instead of the icon.
RC.Set("r10", "dispelStyle", "SQUARE")
local slot = c._slots.square
H.checkTrue("square slot made", slot)
H.check("same filter as the icon", slot.filter, "HARMFUL|RAID")
H.check("square on", slot.enabled, true)
H.check("icon off", c._slots.dispel.enabled, false)
local square = slot.frame
local function place(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    return table.concat({ p, rel == cell and "cell" or "?", relPoint, x, y }, " ")
end
H.check("square size", square:GetWidth() .. "x" .. square:GetHeight(), "6x6")
H.check("in its corner, a pixel in", place(square), "TOPRIGHT cell TOPRIGHT -1 -1")
local entry = square._dispelTextures[1]
H.check("its texture coloured by the client", entry.texture, square.square)
H.check("the borders' curve: opaque", entry.options.customDispelColorCurve, ns.AuraButton.DispelCurve())
H.check("texture fills the square", square.square._allPoints, square)
H.check("no mouse", square._clickEnabled, false)
H.check("above the texts", square:GetFrameLevel() >= cell:GetFrameLevel() + CellAuras.LEVELS, true)

-- Corner and size; a two-pixel square.
RC.Set("r10", "dispelSquareSize", 2)
RC.Set("r10", "dispelSquarePoint", "BOTTOMLEFT")
H.check("2 x 2", square:GetWidth() .. "x" .. square:GetHeight(), "2x2")
H.check("bottom left", place(square), "BOTTOMLEFT cell BOTTOMLEFT 1 1")
RC.Set("r10", "dispelFilter", "ALL")
H.check("filter follows", slot.filter, "HARMFUL|DISPELLABLE")

-- A corner indicator in the same corner: the square moves in beside it.
RC.Set("r10", "indicatorBottomLeftSpells", "774")
H.check("beside the indicator", place(square), "BOTTOMLEFT cell BOTTOMLEFT 10 1")
RC.Set("r10", "indicatorBottomLeftSize", 12)
H.check("beside a bigger one", place(square), "BOTTOMLEFT cell BOTTOMLEFT 14 1")
RC.Set("r10", "dispelSquarePoint", "TOPRIGHT")
H.check("another corner: back in the corner", place(square), "TOPRIGHT cell TOPRIGHT -1 -1")
RC.Set("r10", "indicatorTopRightSpells", "139")
H.check("moves in from the right", place(square), "TOPRIGHT cell TOPRIGHT -10 -1")
RC.Set("r10", "indicatorTopRightSpells", "")
H.check("indicator gone: back", place(square), "TOPRIGHT cell TOPRIGHT -1 -1")

-- The tint stays its own switch; off hides both.
RC.Set("r10", "dispelTint", true)
H.check("tint with the square", c._slots.tint.enabled, true)
H.check("square still on", slot.enabled, true)
RC.Set("r10", "dispelIcon", false)
H.check("debuff off: no square", slot.enabled, false)
H.check("debuff off: no icon", c._slots.dispel.enabled, false)
RC.Set("r10", "dispelIcon", true)
RC.Set("r10", "dispelStyle", "ICON")
H.check("icon again", c._slots.dispel.enabled, true)
H.check("square off", slot.enabled, false)

-- In combat nothing is touched; the change lands after combat.
M.SetCombat(true)
RC.Set("r10", "dispelStyle", "SQUARE")
H.check("combat: unchanged", slot.enabled, false)
M.SetCombat(false)
H.check("after combat", slot.enabled, true)
RC.ResetScope("r10")

-- Test mode: the pretend member's first debuff with a type, in its colour.
RC.Set("r10", "dispelStyle", "SQUARE")
ns.TestMode.Set(true)
local s2 = Cell.fakes[2].raidAuras.samples
H.checkTrue("sample square shown", s2.square:IsShown())
H.check("sample: magic's colour", s2.square.texture._color[3], 1.0)
H.check("sample: no icon", s2.icon:IsShown(), false)
H.check("sample size", s2.square:GetWidth(), 6)
H.check("member 1: none", Cell.fakes[1].raidAuras.samples.square:IsShown(), false)
RC.Set("r10", "dispelStyle", "ICON")
H.check("sample: icon again", s2.icon:IsShown(), true)
H.check("sample: square hidden", s2.square:IsShown(), false)
ns.TestMode.Set(false)

-- In the window: the Debuffs tab, sizes as sliders.
local tab
for _, t in ipairs(ns.RaidSchema.TABS) do
    if t.id == "debuffs" then tab = t end
end
H.check("dispel section", table.concat(tab.sections[1].keys, ","),
    "dispelIcon,dispelFilter,dispelStyle,dispelIconSize,dispelSquarePoint,dispelSquareSize,dispelTint")
H.check("row section", table.concat(tab.sections[2].keys, ","), "debuffRow,debuffCount,debuffSize")
ns.RaidOptions.Open(10, "debuffs")
local sliders = {}
for _, row in ipairs(ns.RaidOptions.rows) do
    if row.slider then sliders[#sliders + 1] = row.key end
end
H.check("sliders", table.concat(sliders, ","), "dispelIconSize,dispelSquareSize,debuffCount,debuffSize")
ns.RaidOptions.Close()
H.check("square word", ns.RaidSchema.EnumText(RS.Get("dispelStyle"), "SQUARE"), "Square in a corner")
H.check("nothing blocked", #M.blocked, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_dispel_square.lua`

Expected:

```text
test_raid_dispel_square.lua
  ERROR .../Core/Registry.lua:73: attempt to index local 'def' (a nil value)
0 passed, 1 failed
```

- [ ] **Step 3: The settings**

In `Raid/Settings.lua`:

Replace

```lua
    values = { "MINE", "ALL" }, default = "MINE" })
RaidSettings.Define({ key = "dispelIconSize", code = "DZ", scope = "frame", type = "int", min = 8, max = 40,
    default = { r10 = 20, r20 = 18, _ = 16 } })
-- The whole cell tinted in the debuff type's colour.
RaidSettings.Define({ key = "dispelTint", code = "DT", scope = "frame", type = "bool", default = false })
-- A row along the bottom of the cell with every debuff ("HARMFUL"); the
```

with

```lua
    values = { "MINE", "ALL" }, default = "MINE" })
RaidSettings.Define({ key = "dispelIconSize", code = "DZ", scope = "frame", type = "int", min = 8, max = 40,
    default = { r10 = 20, r20 = 18, _ = 16 } })
-- How it shows: the centre icon, or a small square in the type's colour
-- in one of the cell's corners (from a single pixel). Stored by index:
-- append only.
RaidSettings.Define({ key = "dispelStyle", code = "DM", scope = "frame", type = "enum",
    values = { "ICON", "SQUARE" }, default = "ICON" })
RaidSettings.Define({ key = "dispelSquarePoint", code = "DP", scope = "frame", type = "enum",
    values = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }, default = "TOPRIGHT" })
RaidSettings.Define({ key = "dispelSquareSize", code = "DQ", scope = "frame", type = "int", min = 1, max = 16,
    default = 6 })
-- The whole cell tinted in the debuff type's colour.
RaidSettings.Define({ key = "dispelTint", code = "DT", scope = "frame", type = "bool", default = false })
-- A row along the bottom of the cell with every debuff ("HARMFUL"); the
```

- [ ] **Step 4: Which indicator takes a corner**

In `Raid/Indicators.lua`:

Replace

```lua
    local set = {}
    for _, id in ipairs(ids) do set[id] = true end
    return set
end

function Indicators.Filter(key)
```

with

```lua
    local set = {}
    for _, id in ipairs(ids) do set[id] = true end
    return set
end

-- The size of the indicator at a point while it has spells, on the
-- pixel grid; nil while it is off (the dispel square, Raid/CellAuras.lua,
-- moves in beside it).
function Indicators.SizeAt(point)
    for _, ind in ipairs(Raid.INDICATORS) do
        local key = Indicators.Key(ind)
        if ind.point == point and Indicators.SpellSet(get(key .. "Spells")) then
            return Pixel.Snap(get(key .. "Size"), nil, 1)
        end
    end
    return nil
end

function Indicators.Filter(key)
```

- [ ] **Step 5: The square: a slot, its place, its sample**

In `Raid/CellAuras.lua`:

Replace

```lua
--   player", AuraUtil.AuraFilters) or any dispellable one
--   ("HARMFUL|DISPELLABLE"), bordered in its type's colour through our
--   colour curve, as the unit frames' debuff icons are;
-- * the tint: a second slot with the same filter whose only region is a
--   texture over the health bar, coloured by the client from a curve of
--   the same colours at a lower opacity. Its own slot, so switching it is
--   a container call (SetAuraSlotEnabled), never a touch of a button;
```

with

```lua
--   player", AuraUtil.AuraFilters) or any dispellable one
--   ("HARMFUL|DISPELLABLE"), bordered in its type's colour through our
--   colour curve, as the unit frames' debuff icons are;
-- * or, in its place, the square: a slot with the same filter whose only
--   region is a texture filling a small frame in one of the cell's
--   corners, coloured by the client from the borders' curve; beside a
--   corner indicator in the same corner (Raid/Indicators.lua), not under
--   it;
-- * the tint: a further slot with the same filter whose only region is a
--   texture over the health bar, coloured by the client from a curve of
--   the same colours at a lower opacity. Its own slot, so switching it is
--   a container call (SetAuraSlotEnabled), never a touch of a button;
```

In `Raid/CellAuras.lua`:

Replace

```lua
    ns.AuraContainers.Wire(button, true)
end

-- The centre icon and the tint --------------------------------------------------------

local function dispelSize()
    return Pixel.Snap(get("dispelIconSize"), nil, 1)
```

with

```lua
    ns.AuraContainers.Wire(button, true)
end

-- The centre icon, the square and the tint --------------------------------------------

local function dispelSize()
    return Pixel.Snap(get("dispelIconSize"), nil, 1)
```

In `Raid/CellAuras.lua`:

Replace

```lua
local function initIcon(frame, button)
    decorate(frame, button, dispelSize())
    button:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
end

-- The tint: a slot frame of one pixel with no mouse; its texture covers
```

with

```lua
local function initIcon(frame, button)
    decorate(frame, button, dispelSize())
    button:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
end

-- The square: just inside its corner; with a corner indicator there, that
-- far further in along the edge and a gap more.
CellAuras.SQUARE_GAP = 1

local function placeSquare(frame, square)
    local point = get("dispelSquarePoint")
    local size = Pixel.Snap(get("dispelSquareSize"), nil, 1)
    local inset = Pixel.Snap(ns.RaidIndicators.INSET)
    local dx, dy = Cell.Inset(point)
    local x, y = dx * inset, dy * inset
    local beside = ns.RaidIndicators.SizeAt(point)
    if beside then x = x + dx * (beside + Pixel.Snap(CellAuras.SQUARE_GAP)) end
    square:SetSize(size, size)
    square:ClearAllPoints()
    square:SetPoint(point, frame, point, x, y)
end

-- A slot frame with no mouse whose texture the client colours by the
-- debuff's type.
local function initSquare(frame, button)
    pcall(button.SetMouseClickEnabled, button, false)
    pcall(button.SetMouseMotionEnabled, button, false)
    local square = button:CreateTexture(nil, "ARTWORK")
    square:SetColorTexture(1, 1, 1, 1)
    square:SetAllPoints(button)
    button.square = square
    button:AddDispelTypeTexture(square, { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        customDispelColorCurve = AuraButton.DispelCurve() })
    placeSquare(frame, button)
end

-- The tint: a slot frame of one pixel with no mouse; its texture covers
```

In `Raid/CellAuras.lua`:

Replace

```lua
end
CellAuras.SampleDebuffs = sampleDebuffs

CellAuras.AddPart({
    Apply = function(frame, container)
        local filter = CellAuras.FILTERS[get("dispelFilter")]
        local icon = CellAuras.SetSlot(frame, container, "dispel", filter, get("dispelIcon"), initIcon)
        CellAuras.SetSlot(frame, container, "tint", filter, get("dispelTint"), initTint)
        return icon ~= nil and not pcall(AuraButton.StyleManaged, icon, frame.key, dispelSize(), false)
    end,
    BuildSample = function(frame, samples)
        samples.icon = AuraButton.Create(frame, true)
        -- A frame needs a rect of its own for its texture to be drawn.
        samples.tint = CreateFrame("Frame", nil, frame)
        samples.tint:SetAllPoints(frame.health)
```

with

```lua
end
CellAuras.SampleDebuffs = sampleDebuffs

-- Which of the two shows the debuff: "ICON", "SQUARE", or nil (off).
local function dispelShows()
    if not get("dispelIcon") then return nil end
    return get("dispelStyle")
end

CellAuras.AddPart({
    Apply = function(frame, container)
        local filter, shows = CellAuras.FILTERS[get("dispelFilter")], dispelShows()
        local icon = CellAuras.SetSlot(frame, container, "dispel", filter, shows == "ICON", initIcon)
        local square = CellAuras.SetSlot(frame, container, "square", filter, shows == "SQUARE", initSquare)
        CellAuras.SetSlot(frame, container, "tint", filter, get("dispelTint"), initTint)
        local refused = icon ~= nil and not pcall(AuraButton.StyleManaged, icon, frame.key, dispelSize(), false)
        if square ~= nil and not pcall(placeSquare, frame, square) then refused = true end
        return refused
    end,
    BuildSample = function(frame, samples)
        samples.icon = AuraButton.Create(frame, true)
        samples.square = CreateFrame("Frame", nil, frame)
        samples.square.texture = samples.square:CreateTexture(nil, "ARTWORK")
        samples.square.texture:SetColorTexture(1, 1, 1, 1)
        samples.square.texture:SetAllPoints(samples.square)
        samples.square:Hide()
        -- A frame needs a rect of its own for its texture to be drawn.
        samples.tint = CreateFrame("Frame", nil, frame)
        samples.tint:SetAllPoints(frame.health)
```

In `Raid/CellAuras.lua`:

Replace

```lua
        samples.tint:Hide()
    end,
    ShowSample = function(frame, samples, member, start)
        local centre = sampleDebuffs(member)
        local icon, tint = samples.icon, samples.tint
        icon:SetFrameLevel(frame:GetFrameLevel() + CellAuras.LEVELS)
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
        AuraButton.Style(icon, frame.key, dispelSize(), false)
        if centre and get("dispelIcon") then AuraButton.ShowSample(icon, centre, start) else AuraButton.Clear(icon) end
        tint:SetFrameLevel(frame:GetFrameLevel() + CellAuras.TINT_LEVELS)
        local c = centre and AuraButton.DISPEL_COLORS[centre.dispel]
        if c then tint.texture:SetVertexColor(c[1], c[2], c[3], CellAuras.TINT_ALPHA) end
        tint:SetShown(c ~= nil and get("dispelTint") == true)
    end,
```

with

```lua
        samples.tint:Hide()
    end,
    ShowSample = function(frame, samples, member, start)
        local centre, shows = sampleDebuffs(member), dispelShows()
        local icon, square, tint = samples.icon, samples.square, samples.tint
        icon:SetFrameLevel(frame:GetFrameLevel() + CellAuras.LEVELS)
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
        AuraButton.Style(icon, frame.key, dispelSize(), false)
        if centre and shows == "ICON" then AuraButton.ShowSample(icon, centre, start) else AuraButton.Clear(icon) end
        local c = centre and AuraButton.DISPEL_COLORS[centre.dispel]
        square:SetFrameLevel(frame:GetFrameLevel() + CellAuras.LEVELS)
        placeSquare(frame, square)
        if c then square.texture:SetVertexColor(c[1], c[2], c[3], 1) end
        square:SetShown(c ~= nil and shows == "SQUARE")
        tint:SetFrameLevel(frame:GetFrameLevel() + CellAuras.TINT_LEVELS)
        if c then tint.texture:SetVertexColor(c[1], c[2], c[3], CellAuras.TINT_ALPHA) end
        tint:SetShown(c ~= nil and get("dispelTint") == true)
    end,
```

- [ ] **Step 6: On the Debuffs tab**

In `Raid/Options/Schema.lua`:

Replace

```lua
        { id = "fonts", keys = { "fontFace", "nameFontSize", "secondFontSize", "fontOutline", "fontShadow" } },
    } },
    { id = "debuffs", sections = {
        { id = "dispel", keys = { "dispelIcon", "dispelFilter", "dispelIconSize", "dispelTint" } },
        { id = "debuffRow", keys = { "debuffRow", "debuffCount", "debuffSize" } },
    } },
    { id = "indicators", sections = {
```

with

```lua
        { id = "fonts", keys = { "fontFace", "nameFontSize", "secondFontSize", "fontOutline", "fontShadow" } },
    } },
    { id = "debuffs", sections = {
        { id = "dispel", keys = { "dispelIcon", "dispelFilter", "dispelStyle", "dispelIconSize", "dispelSquarePoint",
            "dispelSquareSize", "dispelTint" } },
        { id = "debuffRow", keys = { "debuffRow", "debuffCount", "debuffSize" } },
    } },
    { id = "indicators", sections = {
```

- [ ] **Step 7: The words in English**

In `Locales/enUS.lua`:

Replace

```lua
L.RAID_SETTING_powerStrip = "Power strip"
L.RAID_SETTING_secondLine = "Second line"
L.RAID_SETTING_nameClassColor = "Name in class color"
L.RAID_SETTING_dispelIcon = "Icon in the center"
L.RAID_SETTING_dispelFilter = "Which debuffs"
L.RAID_SETTING_dispelIconSize = "Icon size"
L.RAID_SETTING_dispelTint = "Tint the cell"
```

with

```lua
L.RAID_SETTING_powerStrip = "Power strip"
L.RAID_SETTING_secondLine = "Second line"
L.RAID_SETTING_nameClassColor = "Name in class color"
L.RAID_SETTING_dispelIcon = "Show the debuff"
L.RAID_SETTING_dispelFilter = "Which debuffs"
L.RAID_SETTING_dispelIconSize = "Icon size"
L.RAID_SETTING_dispelTint = "Tint the cell"
```

Append to the end of `Locales/enUS.lua`:

```lua

-- Raid frames: the dispellable debuff as a square in a corner.
L.RAID_SETTING_dispelStyle = "Shown as"
L.RAID_SETTING_dispelSquarePoint = "Corner of the square"
L.RAID_SETTING_dispelSquareSize = "Square size"
L.RAID_HINT_dispelSquarePoint = "Beside a corner indicator in the same corner"
L.RAID_HINT_dispelSquareSize = "In pixels, from 1"
L.RAID_ENUM_dispelStyle_ICON = "Icon in the center"
L.RAID_ENUM_dispelStyle_SQUARE = "Square in a corner"
L.RAID_ENUM_dispelSquarePoint_TOPLEFT = "Top left"
L.RAID_ENUM_dispelSquarePoint_TOPRIGHT = "Top right"
L.RAID_ENUM_dispelSquarePoint_BOTTOMLEFT = "Bottom left"
L.RAID_ENUM_dispelSquarePoint_BOTTOMRIGHT = "Bottom right"
```

- [ ] **Step 8: German**

In `Locales/deDE.lua`:

Replace

```lua
L.RAID_SETTING_powerStrip = "Ressourcenstreifen"
L.RAID_SETTING_secondLine = "Zweite Zeile"
L.RAID_SETTING_nameClassColor = "Name in Klassenfarbe"
L.RAID_SETTING_dispelIcon = "Symbol in der Mitte"
L.RAID_SETTING_dispelFilter = "Welche Debuffs"
L.RAID_SETTING_dispelIconSize = "Symbolgröße"
L.RAID_SETTING_dispelTint = "Zelle einfärben"
```

with

```lua
L.RAID_SETTING_powerStrip = "Ressourcenstreifen"
L.RAID_SETTING_secondLine = "Zweite Zeile"
L.RAID_SETTING_nameClassColor = "Name in Klassenfarbe"
L.RAID_SETTING_dispelIcon = "Debuff anzeigen"
L.RAID_SETTING_dispelFilter = "Welche Debuffs"
L.RAID_SETTING_dispelIconSize = "Symbolgröße"
L.RAID_SETTING_dispelTint = "Zelle einfärben"
```

Append to the end of `Locales/deDE.lua`:

```lua

-- Schlachtzugsrahmen: der bannbare Debuff als Quadrat in einer Ecke.
L.RAID_SETTING_dispelStyle = "Anzeige als"
L.RAID_SETTING_dispelSquarePoint = "Ecke des Quadrats"
L.RAID_SETTING_dispelSquareSize = "Größe des Quadrats"
L.RAID_HINT_dispelSquarePoint = "Neben einem Eckanzeiger in derselben Ecke"
L.RAID_HINT_dispelSquareSize = "In Pixeln, ab 1"
L.RAID_ENUM_dispelStyle_ICON = "Symbol in der Mitte"
L.RAID_ENUM_dispelStyle_SQUARE = "Quadrat in einer Ecke"
L.RAID_ENUM_dispelSquarePoint_TOPLEFT = "Oben links"
L.RAID_ENUM_dispelSquarePoint_TOPRIGHT = "Oben rechts"
L.RAID_ENUM_dispelSquarePoint_BOTTOMLEFT = "Unten links"
L.RAID_ENUM_dispelSquarePoint_BOTTOMRIGHT = "Unten rechts"
```

- [ ] **Step 9: Spanish**

In `Locales/esES.lua`:

Replace

```lua
L.RAID_SETTING_powerStrip = "Franja de recurso"
L.RAID_SETTING_secondLine = "Segunda línea"
L.RAID_SETTING_nameClassColor = "Nombre en color de clase"
L.RAID_SETTING_dispelIcon = "Icono en el centro"
L.RAID_SETTING_dispelFilter = "Qué perjuicios"
L.RAID_SETTING_dispelIconSize = "Tamaño de icono"
L.RAID_SETTING_dispelTint = "Teñir la celda"
```

with

```lua
L.RAID_SETTING_powerStrip = "Franja de recurso"
L.RAID_SETTING_secondLine = "Segunda línea"
L.RAID_SETTING_nameClassColor = "Nombre en color de clase"
L.RAID_SETTING_dispelIcon = "Mostrar el perjuicio"
L.RAID_SETTING_dispelFilter = "Qué perjuicios"
L.RAID_SETTING_dispelIconSize = "Tamaño de icono"
L.RAID_SETTING_dispelTint = "Teñir la celda"
```

Append to the end of `Locales/esES.lua`:

```lua

-- Marcos de banda: el perjuicio disipable como un cuadrado en una esquina.
L.RAID_SETTING_dispelStyle = "Mostrar como"
L.RAID_SETTING_dispelSquarePoint = "Esquina del cuadrado"
L.RAID_SETTING_dispelSquareSize = "Tamaño del cuadrado"
L.RAID_HINT_dispelSquarePoint = "Junto a un indicador en la misma esquina"
L.RAID_HINT_dispelSquareSize = "En píxeles, desde 1"
L.RAID_ENUM_dispelStyle_ICON = "Icono en el centro"
L.RAID_ENUM_dispelStyle_SQUARE = "Cuadrado en una esquina"
L.RAID_ENUM_dispelSquarePoint_TOPLEFT = "Arriba a la izquierda"
L.RAID_ENUM_dispelSquarePoint_TOPRIGHT = "Arriba a la derecha"
L.RAID_ENUM_dispelSquarePoint_BOTTOMLEFT = "Abajo a la izquierda"
L.RAID_ENUM_dispelSquarePoint_BOTTOMRIGHT = "Abajo a la derecha"
```

- [ ] **Step 10: French**

In `Locales/frFR.lua`:

Replace

```lua
L.RAID_SETTING_powerStrip = "Bande de ressource"
L.RAID_SETTING_secondLine = "Deuxième ligne"
L.RAID_SETTING_nameClassColor = "Nom en couleur de classe"
L.RAID_SETTING_dispelIcon = "Icône au centre"
L.RAID_SETTING_dispelFilter = "Quels affaiblissements"
L.RAID_SETTING_dispelIconSize = "Taille de l'icône"
L.RAID_SETTING_dispelTint = "Teinter la cellule"
```

with

```lua
L.RAID_SETTING_powerStrip = "Bande de ressource"
L.RAID_SETTING_secondLine = "Deuxième ligne"
L.RAID_SETTING_nameClassColor = "Nom en couleur de classe"
L.RAID_SETTING_dispelIcon = "Afficher l'affaiblissement"
L.RAID_SETTING_dispelFilter = "Quels affaiblissements"
L.RAID_SETTING_dispelIconSize = "Taille de l'icône"
L.RAID_SETTING_dispelTint = "Teinter la cellule"
```

Append to the end of `Locales/frFR.lua`:

```lua

-- Cadres de raid : l'affaiblissement dissipable comme un carré dans un coin.
L.RAID_SETTING_dispelStyle = "Affiché comme"
L.RAID_SETTING_dispelSquarePoint = "Coin du carré"
L.RAID_SETTING_dispelSquareSize = "Taille du carré"
L.RAID_HINT_dispelSquarePoint = "À côté d'un indicateur dans le même coin"
L.RAID_HINT_dispelSquareSize = "En pixels, à partir de 1"
L.RAID_ENUM_dispelStyle_ICON = "Icône au centre"
L.RAID_ENUM_dispelStyle_SQUARE = "Carré dans un coin"
L.RAID_ENUM_dispelSquarePoint_TOPLEFT = "En haut à gauche"
L.RAID_ENUM_dispelSquarePoint_TOPRIGHT = "En haut à droite"
L.RAID_ENUM_dispelSquarePoint_BOTTOMLEFT = "En bas à gauche"
L.RAID_ENUM_dispelSquarePoint_BOTTOMRIGHT = "En bas à droite"
```

- [ ] **Step 11: Run the tests**

Run: `tests/run test_raid_dispel_square.lua` → `47 passed, 0 failed`
Run: `tests/run` → Expected: `23394 passed, 0 failed`

- [ ] **Step 12: Commit**

```bash
git add Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Raid/CellAuras.lua Raid/Indicators.lua Raid/Options/Schema.lua Raid/Settings.lua tests/test_raid_dispel_square.lua
git commit -m "Raid cell: the dispellable debuff as a square in a corner

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Raid frames: a minimap button of their own and an addon compartment entry

**Files:**
- Modify: `Core/Boot.lua`
- Modify: `Core/Commands.lua`
- Modify: `ForeverUnitFrames.toc`
- Modify: `Options/MinimapButton.lua`
- Create: `Raid/MinimapButton.lua`
- Modify: `Raid/Options/Schema.lua`
- Modify: `Raid/Settings.lua`
- Modify: `tests/mock.lua`
- Modify: `tools/make_minimap_icon.py`
- Create: `tools/make_raid_minimap_icon.py`
- Generate: `Media/RaidMinimapIcon.tga` (by `tools/make_raid_minimap_icon.py`)
- Modify: `Locales/deDE.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_raid_window.lua` (existing; its "general rows" lists the General tab's rows, which gains the minimap button's two)
- Test: `tests/test_raid_minimap_button.lua`

**Interfaces:**
- Consumes: `Options/MinimapButton.lua` (its placing, drag and tooltip), `ns.RaidConfig`, `ns.RaidSettings.Define`, `ns.Commands.IsReady`, `ns.RaidOptions.Toggle`, `AddonCompartmentFrame:RegisterAddon`, `tools/make_minimap_icon.py`'s circle cut.
- Produces: `ns.MinimapButton.New(spec)` → button with `button.place()` (spec: `name`, `icon`, `clicks`, `onClick`, `lines(tooltip)`, `config`, `show`, `angle`); `ns.MinimapButton.button` built through it; `ns.RaidMinimapButton` (`ICON`, `button`, `Create()`); raid settings `minimapShow` (MS), `minimapAngle` (MA, 250) in `general`, General tab section `minimap`; `ns.Commands.ToggleRaidOptions()` (also used by `/fuf raid`); `tools/make_minimap_icon.py`'s `write_round_tga(image, path)`; `tools/make_raid_minimap_icon.py` → `Media/RaidMinimapIcon.tga`; mock `AddonCompartmentFrame.registeredAddons`; locale keys `RAID_SECTION_minimap`, `RAID_SETTING_minimapShow`, `RAID_SETTING_minimapAngle`, `RAID_HINT_minimapAngle`, `RAID_MINIMAP_LEFT_CLICK`, `RAID_COMPARTMENT`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_raid_window.lua`:

Replace

```lua
for i, b in ipairs(RO.tabButtons) do titles[i] = b.text:GetText() end
H.check("tabs", table.concat(titles, ","), "General,Layout,Cell,Texts,Debuffs,Indicators,Icons & states")
H.check("first tab", RO.currentTab, "general")
H.check("general rows", keys(), "enabled,showInParty,hideBlizzard")
H.check("label", rowFor("showInParty").label:GetText(), "Raid view in a party")
H.check("hint", rowFor("hideBlizzard").hintText:GetText(), "Needs /reload to show them again")
click(rowFor("showInParty").box)
```

with

```lua
for i, b in ipairs(RO.tabButtons) do titles[i] = b.text:GetText() end
H.check("tabs", table.concat(titles, ","), "General,Layout,Cell,Texts,Debuffs,Indicators,Icons & states")
H.check("first tab", RO.currentTab, "general")
H.check("general rows", keys(), "enabled,showInParty,hideBlizzard,minimapShow,minimapAngle")
H.check("label", rowFor("showInParty").label:GetText(), "Raid view in a party")
H.check("hint", rowFor("hideBlizzard").hintText:GetText(), "Needs /reload to show them again")
click(rowFor("showInParty").box)
```

Create `tests/test_raid_minimap_button.lua`:

```lua
-- The raid frames' own minimap button (Raid/MinimapButton.lua): its own
-- icon, angle and switch in the raid profile's General settings, dragged
-- around the minimap like the unit frames' button; a left click opens or
-- closes the raid options window. Blizzard's addon compartment gets an
-- entry for the raid window as well.
local M = H.M

local function boot()
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local function close(a, b) return math.abs(a - b) < 1e-6 end

-- Settings: the character's own, on the General tab.
do
    local ns = H.LoadAddon()
    local RS = ns.RaidSettings
    for key, code in pairs({ minimapShow = "MS", minimapAngle = "MA" }) do
        local def = RS.Get(key)
        H.check("code of " .. key, def.code, code)
        H.checkTrue(key .. " character-wide", RS.AppliesTo(def, "general"))
        H.check(key .. " not per size", RS.AppliesTo(def, "r10"), false)
    end
    H.check("shown by default", RS.Default(RS.Get("minimapShow"), "general"), true)
    H.check("default angle: below the unit frames' button", RS.Default(RS.Get("minimapAngle"), "general"), 250)
    H.check("angle range", RS.Get("minimapAngle").min .. "-" .. RS.Get("minimapAngle").max, "0-359")
    local general = ns.RaidSchema.TABS[1]
    H.check("minimap section", general.sections[2].id, "minimap")
    H.check("section keys", table.concat(general.sections[2].keys, ","), "minimapShow,minimapAngle")
    H.check("section title", ns.RaidSchema.SectionTitle("minimap"), "Minimap button")
end

-- The button.
do
    local ns = boot()
    local RC, RO = ns.RaidConfig, ns.RaidOptions
    local button = ns.RaidMinimapButton.button
    H.checkTrue("button built", button)
    H.check("its name", button:GetName(), "ForeverUnitFramesRaidMinimapButton")
    H.check("on the minimap", button:GetParent(), Minimap)
    H.check("not the unit frames' button", button ~= ns.MinimapButton.button, true)
    H.check("not secure", button._template, nil)
    H.checkTrue("shown", button:IsShown())
    H.check("its own icon", button.icon._texture, "Interface\\AddOns\\ForeverUnitFrames\\Media\\RaidMinimapIcon.tga")
    H.check("tracking border", button.border._texture, "Interface\\Minimap\\MiniMap-TrackingBorder")
    H.check("left clicks only", table.concat(button._clicks, ","), "LeftButtonUp")

    -- On the circle at its own angle; a square minimap squares it off.
    local r = 70 + 5
    local p = { button:GetPoint(1) }
    H.check("centred on the minimap", p[1] .. p[2]:GetName() .. p[3], "CENTERMinimapCENTER")
    H.checkTrue("round: x", close(p[4], math.cos(math.rad(250)) * r))
    H.checkTrue("round: y", close(p[5], math.sin(math.rad(250)) * r))
    _G.GetMinimapShape = function() return "SQUARE" end
    RC.Set("general", "minimapAngle", 180)
    p = { button:GetPoint(1) }
    H.checkTrue("square, left: x", close(p[4], -r))
    _G.GetMinimapShape = nil
    Minimap:SetSize(200, 200)
    p = { button:GetPoint(1) }
    H.checkTrue("resized minimap: on the new edge", close(p[4], -(100 + 5)))
    Minimap:SetSize(140, 140)

    -- Dragging saves its own angle; the unit frames' stays.
    button:GetScript("OnDragStart")(button)
    M.cursor = { 1700, 900 + 50 }
    button:GetScript("OnUpdate")(button, 0.01)
    button:GetScript("OnDragStop")(button)
    H.check("its angle saved", RC.Get("general", "minimapAngle"), 90)
    H.check("in the raid profile", RC.Profile().general.minimapAngle, 90)
    H.check("the unit frames' button keeps its angle", ns.Config.Get("general", "minimapAngle"), 225)

    -- Left-click: the raid window opens and closes; in combat it opens, locked.
    button:GetScript("OnClick")(button, "LeftButton")
    H.checkTrue("opens the raid window", RO.IsOpen())
    H.check("not the unit window", ns.Options.IsOpen(), false)
    button:GetScript("OnClick")(button, "LeftButton")
    H.check("again: closed", RO.IsOpen(), false)
    M.combat = true
    M.FireEvent("PLAYER_REGEN_DISABLED")
    button:GetScript("OnClick")(button, "LeftButton")
    H.checkTrue("combat: opens", RO.IsOpen())
    H.checkTrue("combat: locked", RO.combatNotice:IsShown())
    RO.Close()
    M.SetCombat(false)

    -- Tooltip.
    button:GetScript("OnEnter")(button)
    H.check("tooltip lines", table.concat(M.tooltipLines, "|"),
        "Forever Unit Frames|Left-click: raid frame options|Drag: move button")
    button:GetScript("OnLeave")(button)
    H.check("tooltip hidden", GameTooltip._owner, nil)

    -- Hidden in the raid settings; the unit frames' button stays.
    RC.Set("general", "minimapShow", false)
    H.check("hidden", button:IsShown(), false)
    H.checkTrue("unit frames' button still shown", ns.MinimapButton.button:IsShown())
    RC.Set("general", "minimapShow", true)
    H.check("shown again", button:IsShown(), true)

    -- The addon compartment: an entry of its own for the raid window.
    local entries = AddonCompartmentFrame.registeredAddons
    H.check("one entry", #entries, 1)
    local entry = entries[1]
    H.check("entry text", entry.text, "Forever Unit Frames: raid frames")
    H.check("entry icon", entry.icon, "Interface\\AddOns\\ForeverUnitFrames\\Media\\RaidMinimapIcon.tga")
    entry.func()
    H.checkTrue("entry opens the raid window", RO.IsOpen())
    entry.func()
    H.check("entry again: closed", RO.IsOpen(), false)
    local row = CreateFrame("Button", nil, UIParent)
    entry.funcOnEnter(row)
    H.check("entry tooltip", table.concat(M.tooltipLines, "|"), "Forever Unit Frames|Left-click: raid frame options")
    entry.funcOnLeave(row)
    H.check("entry tooltip hidden", GameTooltip._owner, nil)

    -- /fuf raid takes the same way.
    ns.Commands.ToggleRaidOptions()
    H.checkTrue("toggle opens", RO.IsOpen())
    ns.Commands.ToggleRaidOptions()
    H.check("toggle closes", RO.IsOpen(), false)
    H.check("nothing blocked", #M.blocked, 0)
end

-- Without the compartment (another client) nothing fails.
do
    local ns = H.LoadAddon()
    _G.AddonCompartmentFrame = nil
    M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    local ok = pcall(M.FireEvent, "PLAYER_LOGIN")
    H.check("no compartment: fine", ok, true)
    H.checkTrue("button anyway", ns.RaidMinimapButton.button)
end

-- The icon file: 64 x 64 TGA, round (transparent corners).
do
    local fh = assert(io.open(ADDONDIR .. "/Media/RaidMinimapIcon.tga", "rb"))
    local d = fh:read("*a")
    fh:close()
    H.check("icon size", #d, 18 + 64 * 64 * 4)
    H.check("icon width", d:byte(13), 64)
    H.check("icon corner transparent", d:byte(18 + 4), 0)
    H.checkTrue("icon centre opaque", d:byte(18 + (32 * 64 + 32) * 4 + 4) > 200)
    local toc = H.ReadFile("ForeverUnitFrames.toc")
    H.checkTrue("toc lists the raid button after the raid window",
        toc:find("Raid\\Options\\Window.lua\nRaid\\MinimapButton.lua", 1, true))
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run test_raid_minimap_button.lua`

Expected:

```text
test_raid_minimap_button.lua
  ERROR test_raid_minimap_button.lua:25: attempt to index local 'def' (a nil value)
0 passed, 1 failed
```

Run: `tests/run test_raid_window.lua`

Expected:

```text
test_raid_window.lua
  FAIL general rows -> enabled,showInParty,hideBlizzard (want enabled,showInParty,hideBlizzard,minimapShow,minimapAngle)
65 passed, 1 failed
```

- [ ] **Step 3: The mock's addon compartment**

In `tests/mock.lua`:

Replace

```lua
    M.cursor = { 0, 0 }
    _G.GetCursorPosition = function() return M.cursor[1], M.cursor[2] end
    _G.LibStub = nil
    local function auraTooltip(method)
        GameTooltip[method] = function(self, unit, id, filter)
            refuseAuras()
```

with

```lua
    M.cursor = { 0, 0 }
    _G.GetCursorPosition = function() return M.cursor[1], M.cursor[2] end
    _G.LibStub = nil
    -- Blizzard's addon compartment (Blizzard_Minimap/Mainline/
    -- AddonCompartment.lua, loaded on this game type too): besides the
    -- TOC's entries, addons may add their own with RegisterAddon({ text,
    -- icon, func, funcOnEnter, funcOnLeave }).
    _G.AddonCompartmentFrame = newWidget("Frame", "AddonCompartmentFrame")
    AddonCompartmentFrame.registeredAddons = {}
    function AddonCompartmentFrame:RegisterAddon(data)
        table.insert(self.registeredAddons, data)
    end
    local function auraTooltip(method)
        GameTooltip[method] = function(self, unit, id, filter)
            refuseAuras()
```

- [ ] **Step 4: One maker for minimap buttons**

In `Options/MinimapButton.lua`:

Replace

```lua
--
-- When another addon provides LibDataBroker-1.1 through LibStub, a
-- launcher with the same clicks is registered too, for broker displays.
local MinimapButton = {}
ns.MinimapButton = MinimapButton

```

with

```lua
--
-- When another addon provides LibDataBroker-1.1 through LibStub, a
-- launcher with the same clicks is registered too, for broker displays.
--
-- MinimapButton.New builds such a button for any settings registry: the
-- raid frames have one of their own (Raid/MinimapButton.lua).
local MinimapButton = {}
ns.MinimapButton = MinimapButton

```

In `Options/MinimapButton.lua`:

Replace

```lua
-- Out of combat or in: the button is not protected.
function MinimapButton.Place()
    local button = MinimapButton.button
    if not button then return end
    moveTo(button, Config.Get("general", "minimapAngle"))
    button:SetShown(Config.Get("general", "minimapShow"))
end

-- The cursor's angle around the minimap's centre, in whole degrees.
```

with

```lua
-- Out of combat or in: the button is not protected.
function MinimapButton.Place()
    local button = MinimapButton.button
    if button then button.place() end
end

-- The cursor's angle around the minimap's centre, in whole degrees.
```

In `Options/MinimapButton.lua`:

Replace

```lua
    tooltip:AddLine(L.MINIMAP_RIGHT_CLICK, 1, 1, 1)
end

local function showTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(L.ADDON_NAME)
    tooltipLines(GameTooltip)
    GameTooltip:AddLine(L.MINIMAP_DRAG, 1, 1, 1)
    GameTooltip:Show()
end

local function hideTooltip(button)
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end
```

with

```lua
    tooltip:AddLine(L.MINIMAP_RIGHT_CLICK, 1, 1, 1)
end

local function hideTooltip(button)
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end
```

In `Options/MinimapButton.lua`:

Replace

```lua
    return t
end

local function newButton()
    local button = CreateFrame("Button", "ForeverUnitFramesMinimapButton", Minimap)
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(HIGHLIGHT, "ADD")
    button.background = texture(button, BACKGROUND, "BACKGROUND", BACKGROUND_SIZE, 7, -5)
    button.icon = texture(button, MinimapButton.ICON, "ARTWORK", ICON_SIZE, 6.5, -6)
    button.border = texture(button, BORDER, "OVERLAY", BORDER_SIZE, 0, 0)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", hideTooltip)
    button:SetScript("OnDragStart", function(self)
        hideTooltip(self)
```

with

```lua
    return t
end

-- A button on the minimap's edge. spec: name (the frame's), icon (a file),
-- clicks (for RegisterForClicks), onClick, lines(tooltip) (the
-- tooltip's lines under the addon's name; the drag hint follows), and
-- config with the keys of its General settings: show (whether it shows)
-- and angle (where; set by dragging). button.place() puts it where they
-- say; it follows a minimap another addon resizes.
function MinimapButton.New(spec)
    local button = CreateFrame("Button", spec.name, Minimap)
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks(unpack(spec.clicks))
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(HIGHLIGHT, "ADD")
    button.background = texture(button, BACKGROUND, "BACKGROUND", BACKGROUND_SIZE, 7, -5)
    button.icon = texture(button, spec.icon, "ARTWORK", ICON_SIZE, 6.5, -6)
    button.border = texture(button, BORDER, "OVERLAY", BORDER_SIZE, 0, 0)
    button:SetScript("OnClick", spec.onClick)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.ADDON_NAME)
        spec.lines(GameTooltip)
        GameTooltip:AddLine(L.MINIMAP_DRAG, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", hideTooltip)
    button:SetScript("OnDragStart", function(self)
        hideTooltip(self)
```

In `Options/MinimapButton.lua`:

Replace

```lua
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if self.dragAngle then Config.Set("general", "minimapAngle", self.dragAngle) end
        self.dragAngle = nil
    end)
    return button
end

```

with

```lua
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if self.dragAngle then spec.config.Set("general", spec.angle, self.dragAngle) end
        self.dragAngle = nil
    end)
    function button.place()
        moveTo(button, spec.config.Get("general", spec.angle))
        button:SetShown(spec.config.Get("general", spec.show))
    end
    button.place()
    -- The offset is fixed at placing: follow a minimap another addon
    -- resizes later (a square minimap does so in its own PLAYER_LOGIN,
    -- after ours). HookScript, not hooksecurefunc: Forever hides hooked
    -- frame methods from Blizzard's code.
    Minimap:HookScript("OnSizeChanged", button.place)
    return button
end

```

In `Options/MinimapButton.lua`:

Replace

```lua
-- Once, after the settings are loaded (Core/Boot.lua).
function MinimapButton.Create()
    if MinimapButton.button or not Minimap then return end
    MinimapButton.button = newButton()
    MinimapButton.Place()
    -- The offset is fixed at placing: follow a minimap another addon resizes
    -- later (a square minimap does so in its own PLAYER_LOGIN, after ours).
    -- HookScript, not hooksecurefunc: Forever hides hooked frame methods
    -- from Blizzard's code.
    Minimap:HookScript("OnSizeChanged", MinimapButton.Place)
    registerLauncher()
end

```

with

```lua
-- Once, after the settings are loaded (Core/Boot.lua).
function MinimapButton.Create()
    if MinimapButton.button or not Minimap then return end
    MinimapButton.button = MinimapButton.New({
        name = "ForeverUnitFramesMinimapButton", icon = MinimapButton.ICON,
        clicks = { "LeftButtonUp", "RightButtonUp" }, onClick = onClick, lines = tooltipLines,
        config = Config, show = "minimapShow", angle = "minimapAngle",
    })
    registerLauncher()
end

```

- [ ] **Step 5: The raid icon**

In `tools/make_minimap_icon.py`:

Replace

```python
    height = round(graphic.height * GRAPHIC_WIDTH / graphic.width)
    graphic = graphic.resize((GRAPHIC_WIDTH, height), Image.LANCZOS)
    canvas.paste(graphic, ((logo.width - GRAPHIC_WIDTH) // 2, (logo.height - height) // 2), graphic)
    icon = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    rows = []
    for y in range(SIZE - 1, -1, -1):  # bottom row first
```

with

```python
    height = round(graphic.height * GRAPHIC_WIDTH / graphic.width)
    graphic = graphic.resize((GRAPHIC_WIDTH, height), Image.LANCZOS)
    canvas.paste(graphic, ((logo.width - GRAPHIC_WIDTH) // 2, (logo.height - height) // 2), graphic)
    write_round_tga(canvas, os.path.join(here, "..", "Media", "MinimapIcon.tga"))


def write_round_tga(image, path):
    """Scales an RGBA image to SIZE x SIZE, cuts it to the icon's circle
    and writes it as an uncompressed 32-bit TGA (also used by
    tools/make_raid_minimap_icon.py)."""
    icon = image.resize((SIZE, SIZE), Image.LANCZOS)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    rows = []
    for y in range(SIZE - 1, -1, -1):  # bottom row first
```

In `tools/make_minimap_icon.py`:

Replace

```python
            alpha = int(round(a * circle_coverage(x, y)))
            row += bytes((b, g, r, alpha))
        rows.append(bytes(row))
    with open(os.path.join(here, "..", "Media", "MinimapIcon.tga"), "wb") as fh:
        fh.write(header)
        fh.write(b"".join(rows))

```

with

```python
            alpha = int(round(a * circle_coverage(x, y)))
            row += bytes((b, g, r, alpha))
        rows.append(bytes(row))
    with open(path, "wb") as fh:
        fh.write(header)
        fh.write(b"".join(rows))

```

Create `tools/make_raid_minimap_icon.py`:

```python
#!/usr/bin/env python3
"""Writes the raid minimap button's icon, Media/RaidMinimapIcon.tga: the
project logo's look (its dark background, a gold frame, green health
bars) as a raid panel, two columns of three cells, one of them with a
dispel square in its corner. Drawn on a 512 px canvas, then scaled,
cut to a circle and written like the unit frames' icon
(tools/make_minimap_icon.py, whose write_round_tga it uses).

Needs Pillow (python3 -m pip install pillow). Run from the repository
root:  python3 tools/make_raid_minimap_icon.py
"""
import os

from PIL import Image, ImageDraw

from make_minimap_icon import write_round_tga

CANVAS = 512
BACKGROUND = (14, 18, 27, 255)
# The panel's frame: gold, darker at the bottom (the logo's bevel).
GOLD_LIGHT = (240, 200, 110, 255)
GOLD_DARK = (150, 105, 35, 255)
INSIDE = (22, 27, 39, 255)
# Cells: health green, the missing part dark, a magic-blue dispel square.
GREEN = (46, 185, 69, 255)
MISSING = (10, 12, 18, 255)
DISPEL = (79, 145, 243, 255)
# The panel inside the circle (left, top, right, bottom), its frame's
# thickness, the gap between cells, and each cell's share of health.
PANEL = (96, 106, 416, 406)
FRAME = 18
GAP = 12
HEALTH = ((1.0, 0.7), (0.45, 1.0), (0.85, 0.6))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    canvas = Image.new("RGBA", (CANVAS, CANVAS), BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    left, top, right, bottom = PANEL
    height = bottom - top
    for y in range(top, bottom):  # the frame, light to dark
        share = (y - top) / height
        color = tuple(int(GOLD_LIGHT[i] + (GOLD_DARK[i] - GOLD_LIGHT[i]) * share) for i in range(4))
        draw.line([(left, y), (right, y)], fill=color)
    inner = (left + FRAME, top + FRAME, right - FRAME, bottom - FRAME)
    draw.rectangle(inner, fill=INSIDE)
    cell_w = (inner[2] - inner[0] - 3 * GAP) / 2
    cell_h = (inner[3] - inner[1] - 4 * GAP) / 3
    for row, shares in enumerate(HEALTH):
        for col, share in enumerate(shares):
            x0 = inner[0] + GAP + col * (cell_w + GAP)
            y0 = inner[1] + GAP + row * (cell_h + GAP)
            draw.rectangle((x0, y0, x0 + cell_w, y0 + cell_h), fill=MISSING)
            draw.rectangle((x0, y0, x0 + cell_w * share, y0 + cell_h), fill=GREEN)
            if (row, col) == (1, 1):
                square = cell_h * 0.4
                draw.rectangle((x0 + cell_w - square, y0, x0 + cell_w, y0 + square), fill=DISPEL)
    write_round_tga(canvas, os.path.join(here, "..", "Media", "RaidMinimapIcon.tga"))


if __name__ == "__main__":
    main()
```

Run: `python3 tools/make_raid_minimap_icon.py`

It writes `Media/RaidMinimapIcon.tga` (64 × 64, cut round). Running `python3 tools/make_minimap_icon.py` again rewrites `Media/MinimapIcon.tga` byte for byte: `git status` shows no change to it.

- [ ] **Step 6: The settings**

In `Raid/Settings.lua`:

Replace

```lua
RaidSettings.Define({ key = "showInParty", code = "SP", scope = "general", type = "bool", default = false })
-- Blizzard's raid frames hidden while ours are on.
RaidSettings.Define({ key = "hideBlizzard", code = "HB", scope = "general", type = "bool", default = true })

-- Per size ------------------------------------------------------------------------
-- Position of the panel's top left corner, relative to the screen centre.
```

with

```lua
RaidSettings.Define({ key = "showInParty", code = "SP", scope = "general", type = "bool", default = false })
-- Blizzard's raid frames hidden while ours are on.
RaidSettings.Define({ key = "hideBlizzard", code = "HB", scope = "general", type = "bool", default = true })
-- The raid frames' minimap button (Raid/MinimapButton.lua): shown, and its
-- angle around the minimap in degrees, counter-clockwise from the right
-- (250: below the unit frames' button); set by dragging it.
RaidSettings.Define({ key = "minimapShow", code = "MS", scope = "general", type = "bool", default = true })
RaidSettings.Define({ key = "minimapAngle", code = "MA", scope = "general", type = "int", min = 0, max = 359,
    default = 250 })

-- Per size ------------------------------------------------------------------------
-- Position of the panel's top left corner, relative to the screen centre.
```

- [ ] **Step 7: One toggle for /fuf raid and the button**

In `Core/Commands.lua`:

Replace

```lua
    if Commands.IsReady() then ns.Options.Toggle() end
end

-- Unlocking is refused in combat (Movers.Unlock says so).
function Commands.ToggleLock()
    if not Commands.IsReady() then return end
```

with

```lua
    if Commands.IsReady() then ns.Options.Toggle() end
end

-- The raid frames' window: /fuf raid, the raid minimap button and its
-- addon compartment entry.
function Commands.ToggleRaidOptions()
    if Commands.IsReady() then ns.RaidOptions.Toggle() end
end

-- Unlocking is refused in combat (Movers.Unlock says so).
function Commands.ToggleLock()
    if not Commands.IsReady() then return end
```

In `Core/Commands.lua`:

Replace

```lua
    elseif cmd == "help" then
        ns.Print(L.HELP)
    elseif cmd == "raid" then
        ns.RaidOptions.Toggle()
    elseif cmd == "unlock" then
        ns.Movers.Unlock()
    elseif cmd == "lock" then
```

with

```lua
    elseif cmd == "help" then
        ns.Print(L.HELP)
    elseif cmd == "raid" then
        Commands.ToggleRaidOptions()
    elseif cmd == "unlock" then
        ns.Movers.Unlock()
    elseif cmd == "lock" then
```

- [ ] **Step 8: The button and the compartment entry**

Create `Raid/MinimapButton.lua`:

```lua
local _, ns = ...

-- The raid frames' own minimap button: a left click opens or closes the
-- raid options window (the same as /fuf raid, with its rules), dragging
-- moves it around the minimap's edge. Built like the unit frames' button
-- (Options/MinimapButton.lua), with its own icon (tools/
-- make_raid_minimap_icon.py) and its own switch and angle in the raid
-- profile's General settings. A plain button, not secure.
--
-- Blizzard's addon compartment lists the TOC's entry (the unit frames'
-- window); the raid window gets an entry of its own there
-- (AddonCompartmentFrame:RegisterAddon, Blizzard_Minimap/Mainline/
-- AddonCompartment.lua). Its text is set once, in the language of the
-- login.
local RaidMinimapButton = {}
ns.RaidMinimapButton = RaidMinimapButton

local L = ns.L

RaidMinimapButton.ICON = "Interface\\AddOns\\ForeverUnitFrames\\Media\\RaidMinimapIcon.tga"

local function onClick()
    ns.Commands.ToggleRaidOptions()
end

local function tooltipLines(tooltip)
    tooltip:AddLine(L.RAID_MINIMAP_LEFT_CLICK, 1, 1, 1)
end

local function registerCompartment()
    local compartment = AddonCompartmentFrame
    if not (compartment and compartment.RegisterAddon) then return end
    compartment:RegisterAddon({
        text = L.RAID_COMPARTMENT, icon = RaidMinimapButton.ICON, func = onClick,
        funcOnEnter = function(menuButton)
            GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
            GameTooltip:SetText(L.ADDON_NAME)
            tooltipLines(GameTooltip)
            GameTooltip:Show()
        end,
        funcOnLeave = function(menuButton)
            if GameTooltip:IsOwned(menuButton) then GameTooltip:Hide() end
        end,
    })
end

-- Once, after the raid profile is attached (Core/Boot.lua).
function RaidMinimapButton.Create()
    if RaidMinimapButton.button or not Minimap then return end
    RaidMinimapButton.button = ns.MinimapButton.New({
        name = "ForeverUnitFramesRaidMinimapButton", icon = RaidMinimapButton.ICON,
        clicks = { "LeftButtonUp" }, onClick = onClick, lines = tooltipLines,
        config = ns.RaidConfig, show = "minimapShow", angle = "minimapAngle",
    })
    registerCompartment()
end

ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if not RaidMinimapButton.button then return end
    if scope == nil or (scope == "general" and (key == nil or key == "minimapAngle" or key == "minimapShow")) then
        RaidMinimapButton.button.place()
    end
end)
```

In `ForeverUnitFrames.toc`:

Replace

```text
Options\MinimapButton.lua
Raid\Options\Schema.lua
Raid\Options\Window.lua
Core\Debug.lua
Core\Boot.lua

```

with

```text
Options\MinimapButton.lua
Raid\Options\Schema.lua
Raid\Options\Window.lua
Raid\MinimapButton.lua
Core\Debug.lua
Core\Boot.lua

```

In `Core/Boot.lua`:

Replace

```lua
    -- 5-player group: no until it is attached; with the raid view in
    -- party on, building the panel styles the party block again.
    ns.RaidProfiles.Attach(ForeverUnitFramesDB)
    ns.RaidSize.Update()
    ns.AfterCombat("raidCreate", ns.RaidHeader.Create)
    ns.Blizzard.HideRaid()
```

with

```lua
    -- 5-player group: no until it is attached; with the raid view in
    -- party on, building the panel styles the party block again.
    ns.RaidProfiles.Attach(ForeverUnitFramesDB)
    ns.RaidMinimapButton.Create()
    ns.RaidSize.Update()
    ns.AfterCombat("raidCreate", ns.RaidHeader.Create)
    ns.Blizzard.HideRaid()
```

- [ ] **Step 9: On the General tab**

In `Raid/Options/Schema.lua`:

Replace

```lua
Schema.TABS = {
    { id = "general", sections = {
        { id = "raidFrames", keys = { "enabled", "showInParty", "hideBlizzard" } },
    } },
    { id = "layout", sections = {
        { id = "grouping", keys = { "groupBy", "sortBy", "classOrder", "hideEmpty", "blockTitles" } },
```

with

```lua
Schema.TABS = {
    { id = "general", sections = {
        { id = "raidFrames", keys = { "enabled", "showInParty", "hideBlizzard" } },
        { id = "minimap", keys = { "minimapShow", "minimapAngle" } },
    } },
    { id = "layout", sections = {
        { id = "grouping", keys = { "groupBy", "sortBy", "classOrder", "hideEmpty", "blockTitles" } },
```

- [ ] **Step 10: The words in English**

Append to the end of `Locales/enUS.lua`:

```lua

-- Raid frames: their own minimap button and compartment entry.
L.RAID_SECTION_minimap = "Minimap button"
L.RAID_SETTING_minimapShow = "Show the button"
L.RAID_SETTING_minimapAngle = "Button position"
L.RAID_HINT_minimapAngle = "Degrees around the minimap; or drag it"
L.RAID_MINIMAP_LEFT_CLICK = "Left-click: raid frame options"
L.RAID_COMPARTMENT = "Forever Unit Frames: raid frames"
```

- [ ] **Step 11: German**

Append to the end of `Locales/deDE.lua`:

```lua

-- Schlachtzugsrahmen: eigene Minikarten-Schaltfläche und Eintrag im Addon-Fach.
L.RAID_SECTION_minimap = "Minikarten-Schaltfläche"
L.RAID_SETTING_minimapShow = "Schaltfläche anzeigen"
L.RAID_SETTING_minimapAngle = "Position der Schaltfläche"
L.RAID_HINT_minimapAngle = "Grad um die Minikarte; oder ziehen"
L.RAID_MINIMAP_LEFT_CLICK = "Linksklick: Optionen der Schlachtzugsrahmen"
L.RAID_COMPARTMENT = "Forever Unit Frames: Schlachtzugsrahmen"
```

- [ ] **Step 12: Spanish**

Append to the end of `Locales/esES.lua`:

```lua

-- Marcos de banda: su propio botón del minimapa y su entrada en el compartimento.
L.RAID_SECTION_minimap = "Botón del minimapa"
L.RAID_SETTING_minimapShow = "Mostrar el botón"
L.RAID_SETTING_minimapAngle = "Posición del botón"
L.RAID_HINT_minimapAngle = "Grados alrededor del minimapa; o arrástralo"
L.RAID_MINIMAP_LEFT_CLICK = "Clic izquierdo: opciones de marcos de banda"
L.RAID_COMPARTMENT = "Forever Unit Frames: marcos de banda"
```

- [ ] **Step 13: French**

Append to the end of `Locales/frFR.lua`:

```lua

-- Cadres de raid : leur propre bouton de minicarte et leur entrée dans le compartiment.
L.RAID_SECTION_minimap = "Bouton de minicarte"
L.RAID_SETTING_minimapShow = "Afficher le bouton"
L.RAID_SETTING_minimapAngle = "Position du bouton"
L.RAID_HINT_minimapAngle = "Degrés autour de la minicarte ; ou glissez-le"
L.RAID_MINIMAP_LEFT_CLICK = "Clic gauche : options des cadres de raid"
L.RAID_COMPARTMENT = "Forever Unit Frames : cadres de raid"
```

- [ ] **Step 14: Run the tests**

Run: `tests/run test_raid_minimap_button.lua` → `56 passed, 0 failed`
Run: `tests/run test_raid_window.lua` → `66 passed, 0 failed`
Run: `tests/run test_minimap_button.lua` → `65 passed, 0 failed`
Run: `tests/run` → Expected: `23540 passed, 0 failed`

- [ ] **Step 15: Commit**

```bash
git add Core/Boot.lua Core/Commands.lua ForeverUnitFrames.toc Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Media/RaidMinimapIcon.tga Options/MinimapButton.lua Raid/MinimapButton.lua Raid/Options/Schema.lua Raid/Settings.lua tests/mock.lua tests/test_raid_minimap_button.lua tests/test_raid_window.lua tools/make_minimap_icon.py tools/make_raid_minimap_icon.py
git commit -m "Raid frames: a minimap button of their own and an addon compartment entry

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Raid options window: say why a typed class order or spell list is refused

**Files:**
- Modify: `Raid/Options/Window.lua`
- Modify: `Raid/Settings.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_raid_typed_values.lua`

**Interfaces:**
- Consumes: `ns.Raid.ParseClassOrder`, `ns.RaidSpellbook.Resolve` (`nil, word` on refusal), `ns.Raid.SPELL_LIST_LETTERS`, `ns.Print`, the window's `settingRow`.
- Produces: `ns.Raid.ParseClassOrder(text)` → tokens, or `nil, "UNKNOWN"|"TWICE", word`; the window prints `RAID_TYPED_CLASS_UNKNOWN`, `RAID_TYPED_CLASS_TWICE`, `RAID_TYPED_SPELL_UNKNOWN` (one `%s` each) or `RAID_TYPED_TOO_LONG` (one `%d`) when it refuses a typed value.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_typed_values.lua`:

```lua
-- Typed values the raid options window refuses (Raid/Options/Window.lua,
-- Raid/Settings.lua, Raid/Spellbook.lua) say why in the chat: the spell
-- name the spell book does not know, a list too long to store, a class
-- that is unknown or named twice. The field flashes and keeps what was
-- stored, as before.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, Raid = ns.RaidOptions, ns.RaidConfig, ns.Raid

local function rowFor(key)
    for _, row in ipairs(RO.rows) do
        if row.key == key then return row end
    end
end
local function enter(row, text)
    row.edit:SetText(text)
    row.edit:GetScript("OnEnterPressed")(row.edit)
end
local function said() return M.chat[#M.chat] end

-- The class order: why a typed order is refused.
H.check("unknown class", select(2, Raid.ParseClassOrder("Priest, Monk")), "UNKNOWN")
H.check("the word", select(3, Raid.ParseClassOrder("Priest, Monk")), "Monk")
H.check("named twice", select(2, Raid.ParseClassOrder("Priest, priest")), "TWICE")
H.check("the second naming", select(3, Raid.ParseClassOrder("Priest, priest")), "priest")
H.check("fine", Raid.ParseClassOrder("Priest, Druid"), "PRIEST,DRUID")

RO.Open(10, "layout")
local before = #M.chat
enter(rowFor("classOrder"), "Priest, Monk")
H.check("said: unknown class", said(), "|cff4fc3f7Forever Unit Frames:|r Unknown class: Monk")
H.check("nothing stored", RC.Get("r10", "classOrder"), "")
enter(rowFor("classOrder"), "Druid, Mage, druid")
H.check("said: twice", said(), "|cff4fc3f7Forever Unit Frames:|r Class named twice: druid")
enter(rowFor("classOrder"), "Druid, Mage")
H.check("stored", RC.Get("r10", "classOrder"), "DRUID,MAGE")
H.check("nothing said when stored", #M.chat, before + 2)

-- Spells: the name the spell book does not know.
RO.SelectTab("indicators")
local spells = rowFor("indicatorTopLeftSpells")
enter(spells, "139, Nope")
H.check("said: not in the spell book", said(), "|cff4fc3f7Forever Unit Frames:|r Not a spell in your spell book: Nope")
H.check("spells unchanged", RC.Get("r10", "indicatorTopLeftSpells"), "")

-- A name with more ranks than the list can hold.
for i = 1, 40 do
    M.spells[100000 + i] = { name = "Long Spell", maxRange = 40 }
    M.known[100000 + i] = true
end
enter(spells, "Long Spell")
H.check("said: too long", said(),
    ("|cff4fc3f7Forever Unit Frames:|r Too many spells: the list may hold %d characters."):format(Raid.SPELL_LIST_LETTERS))
H.check("still unchanged", RC.Get("r10", "indicatorTopLeftSpells"), "")
M.known[2050] = true
enter(spells, "Lesser Heal")
H.check("a name stored", RC.Get("r10", "indicatorTopLeftSpells"), "2050")
RO.Close()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_typed_values.lua`

Expected:

```text
test_raid_typed_values.lua
  FAIL unknown class -> nil (want UNKNOWN)
  FAIL the word -> nil (want Monk)
  FAIL named twice -> nil (want TWICE)
  FAIL the second naming -> nil (want priest)
  FAIL said: unknown class -> nil (want |cff4fc3f7Forever Unit Frames:|r Unknown class: Monk)
  FAIL said: twice -> nil (want |cff4fc3f7Forever Unit Frames:|r Class named twice: druid)
  FAIL nothing said when stored -> 0 (want 2)
  FAIL said: not in the spell book -> nil (want |cff4fc3f7Forever Unit Frames:|r Not a spell in your spell book: Nope)
  FAIL said: too long -> nil (want |cff4fc3f7Forever Unit Frames:|r Too many spells: the list may hold 200 characters.)
6 passed, 9 failed
```

- [ ] **Step 3: Why a class order is refused**

In `Raid/Settings.lua`:

Replace

```lua

-- What the options window stores for a typed class order: the tokens,
-- comma-separated. It takes tokens in any case and the game's class
-- names (commas between them, a name may hold a space); nil when a
-- class is unknown or named twice.
local function tokenOf(word)
    local upper = word:upper()
    if isClass(upper) then return upper end
```

with

```lua

-- What the options window stores for a typed class order: the tokens,
-- comma-separated. It takes tokens in any case and the game's class
-- names (commas between them, a name may hold a space). nil, why
-- ("UNKNOWN" or "TWICE") and the word in question when a class is
-- unknown or named twice.
local function tokenOf(word)
    local upper = word:upper()
    if isClass(upper) then return upper end
```

In `Raid/Settings.lua`:

Replace

```lua
        local word = piece:match("^%s*(.-)%s*$")
        if word ~= "" then
            local token = tokenOf(word)
            if not token or seen[token] then return nil end
            seen[token] = true
            tokens[#tokens + 1] = token
        end
```

with

```lua
        local word = piece:match("^%s*(.-)%s*$")
        if word ~= "" then
            local token = tokenOf(word)
            if not token then return nil, "UNKNOWN", word end
            if seen[token] then return nil, "TWICE", word end
            seen[token] = true
            tokens[#tokens + 1] = token
        end
```

- [ ] **Step 4: The window says it**

In `Raid/Options/Window.lua`:

Replace

```lua
-- Setting rows ------------------------------------------------------------------

-- What a typed text becomes before it is stored: class names to tokens,
-- spell names to the IDs of their ranks. nil refuses it.
local function typedValue(key)
    if key == "classOrder" then return Raid.ParseClassOrder end
    if key:match("^indicator%a+Spells$") then return ns.RaidSpellbook.Resolve end
    return nil
end

```

with

```lua
-- Setting rows ------------------------------------------------------------------

-- What a typed text becomes before it is stored: class names to tokens,
-- spell names to the IDs of their ranks. nil and why (for the chat)
-- refuses it: an unknown class or one named twice, a spell name the
-- spell book does not know, more spell IDs than the setting can hold.
local function classOrder(text)
    local tokens, problem, word = Raid.ParseClassOrder(text)
    if tokens then return tokens end
    return nil, (problem == "TWICE" and L.RAID_TYPED_CLASS_TWICE or L.RAID_TYPED_CLASS_UNKNOWN):format(word)
end

local function spellList(text)
    local ids, word = ns.RaidSpellbook.Resolve(text)
    if not ids then return nil, L.RAID_TYPED_SPELL_UNKNOWN:format(word) end
    if #ids > Raid.SPELL_LIST_LETTERS then return nil, L.RAID_TYPED_TOO_LONG:format(Raid.SPELL_LIST_LETTERS) end
    return ids
end

local function typedValue(key)
    if key == "classOrder" then return classOrder end
    if key:match("^indicator%a+Spells$") then return spellList end
    return nil
end

```

In `Raid/Options/Window.lua`:

Replace

```lua
        label = Schema.Label(key), hint = Schema.Hint(key), enumText = Schema.EnumText,
        get = function() return RaidConfig.Get(scopeOf(def), key) end,
        set = function(v)
            if convert then v = convert(v) end
            if v == nil then return false end
            return RaidConfig.Set(scopeOf(def), key, v)
        end,
    })
```

with

```lua
        label = Schema.Label(key), hint = Schema.Hint(key), enumText = Schema.EnumText,
        get = function() return RaidConfig.Get(scopeOf(def), key) end,
        set = function(v)
            if convert then
                local converted, why = convert(v)
                if converted == nil then
                    ns.Print(why)
                    return false
                end
                v = converted
            end
            return RaidConfig.Set(scopeOf(def), key, v)
        end,
    })
```

- [ ] **Step 5: The words in English**

Append to the end of `Locales/enUS.lua`:

```lua

-- Raid frames: why a typed value was refused.
L.RAID_TYPED_CLASS_UNKNOWN = "Unknown class: %s"
L.RAID_TYPED_CLASS_TWICE = "Class named twice: %s"
L.RAID_TYPED_SPELL_UNKNOWN = "Not a spell in your spell book: %s"
L.RAID_TYPED_TOO_LONG = "Too many spells: the list may hold %d characters."
```

- [ ] **Step 6: German**

Append to the end of `Locales/deDE.lua`:

```lua

-- Schlachtzugsrahmen: warum ein eingegebener Wert abgelehnt wurde.
L.RAID_TYPED_CLASS_UNKNOWN = "Unbekannte Klasse: %s"
L.RAID_TYPED_CLASS_TWICE = "Klasse doppelt genannt: %s"
L.RAID_TYPED_SPELL_UNKNOWN = "Kein Zauber aus deinem Zauberbuch: %s"
L.RAID_TYPED_TOO_LONG = "Zu viele Zauber: Die Liste fasst %d Zeichen."
```

- [ ] **Step 7: Spanish**

Append to the end of `Locales/esES.lua`:

```lua

-- Marcos de banda: por qué se rechazó un valor escrito.
L.RAID_TYPED_CLASS_UNKNOWN = "Clase desconocida: %s"
L.RAID_TYPED_CLASS_TWICE = "Clase nombrada dos veces: %s"
L.RAID_TYPED_SPELL_UNKNOWN = "No es un hechizo de tu libro de hechizos: %s"
L.RAID_TYPED_TOO_LONG = "Demasiados hechizos: la lista admite %d caracteres."
```

- [ ] **Step 8: French**

Append to the end of `Locales/frFR.lua`:

```lua

-- Cadres de raid : pourquoi une valeur saisie a été refusée.
L.RAID_TYPED_CLASS_UNKNOWN = "Classe inconnue : %s"
L.RAID_TYPED_CLASS_TWICE = "Classe nommée deux fois : %s"
L.RAID_TYPED_SPELL_UNKNOWN = "Pas un sort de votre grimoire : %s"
L.RAID_TYPED_TOO_LONG = "Trop de sorts : la liste peut contenir %d caractères."
```

- [ ] **Step 9: Run the tests**

Run: `tests/run test_raid_typed_values.lua` → `15 passed, 0 failed`
Run: `tests/run` → Expected: `23591 passed, 0 failed`

- [ ] **Step 10: Commit**

```bash
git add Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Raid/Options/Window.lua Raid/Settings.lua tests/test_raid_typed_values.lua
git commit -m "Raid options window: say why a typed class order or spell list is refused

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Raid: damage block sorted by role, clearer words, a unit frames' string refused

`tests/test_raid_import_unit_string.lua` pins behaviour that is already right (R4a's import refuses a text without a raid size): it passes from the start.

**Files:**
- Modify: `Raid/Layout.lua`
- Modify: `Raid/TestMode.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_raid_schema.lua` (existing; "character-wide ones on General" concatenates values that are nil when a setting is missing, which ends the file with an error instead of failing one check)
- Test: `tests/test_raid_damage_block.lua`
- Test: `tests/test_raid_import_unit_string.lua`
- Test: `tests/test_raid_words.lua`

**Interfaces:**
- Consumes: `ns.RaidLayout.Blocks`, `Layout.ROLE_ORDER`, `ns.RaidTestMode.Distribute`, `ns.RaidProfiles.Import`, `ns.Codec.Encode`, `ns.Locales`.
- Produces: sorted by role, the damage role block gets `groupBy = "ASSIGNEDROLE"`, `groupingOrder = ROLE_ORDER`; test mode ranks a role not in `ROLE_ORDER` as `NONE`; changed words deDE `RAID_SECTION_arrangement`, `RAID_SETTING_targetBorder`, esES `RAID_HINT_classOrder`, esES/frFR `RAID_HINT_x`, `RAID_HINT_y`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_raid_schema.lua`:

Replace

```lua
    seen[key] = "header"
end
for _, def in ipairs(RS.All()) do H.checkTrue("reachable: " .. def.key, seen[def.key]) end
H.check("character-wide ones on General", seen.showInParty .. seen.hideBlizzard .. seen.enabled,
    "generalgeneralgeneral")
H.check("class order beside the grouping", seen.classOrder, "layout")
H.check("position on Layout", seen.x, "layout")
H.check("states with the icons", seen.aggroBorder, "icons")
```

with

```lua
    seen[key] = "header"
end
for _, def in ipairs(RS.All()) do H.checkTrue("reachable: " .. def.key, seen[def.key]) end
H.check("character-wide ones on General", tostring(seen.showInParty) .. tostring(seen.hideBlizzard)
    .. tostring(seen.enabled), "generalgeneralgeneral")
H.check("class order beside the grouping", seen.classOrder, "layout")
H.check("position on Layout", seen.x, "layout")
H.check("states with the icons", seen.aggroBorder, "icons")
```

Create `tests/test_raid_damage_block.lua`:

```lua
-- The damage block of the role grouping (Raid/Layout.lua) holds damage
-- and the members without a role; sorted by role it shows damage first,
-- as test mode does (Raid/TestMode.lua), and a role test mode does not
-- know ranks with those without one.
local ns = H.LoadAddon()
local Layout, Test = ns.RaidLayout, ns.RaidTestMode

local blocks = Layout.Blocks("ROLE", 10, "ROLE")
H.check("tank block: one role", blocks[1].filter.groupBy, nil)
H.check("healer block: one role", blocks[2].filter.groupBy, nil)
H.check("damage block: damage and no role", blocks[3].filter.roleFilter, "DAMAGER,NONE")
H.check("damage block: by role", blocks[3].filter.groupBy, "ASSIGNEDROLE")
H.check("damage block: damage first", blocks[3].filter.groupingOrder, Layout.ROLE_ORDER)
H.check("unsorted: none", Layout.Blocks("ROLE", 10, "INDEX")[3].filter.groupBy, nil)

local function member(name, role)
    return { name = name, class = "MAGE", subgroup = 1, assignedRole = role }
end
local members = { member("A", "NONE"), member("B", "DAMAGER"), member("C", "NONE"), member("D", "DAMAGER") }
local names = {}
for i, entry in ipairs(Test.Distribute(blocks, members, 10, "ROLE")[3]) do names[i] = entry.member.name end
H.check("damage, then no role", table.concat(names, ","), "B,D,A,C")

members[2] = member("B", "SOMETHING")
local ok, lists = pcall(Test.Distribute, Layout.Blocks("GROUP", 10, "ROLE"), members, 10, "ROLE")
H.check("an unknown role does not break the order", ok, true)
names = {}
for i, entry in ipairs(ok and lists[1] or {}) do names[i] = entry.member.name end
H.check("ranked with no role", table.concat(names, ","), "D,A,B,C")
```

Create `tests/test_raid_import_unit_string.lua`:

```lua
-- A unit frames' export pasted into the raid import (Raid/Profiles.lua)
-- is refused: it holds no raid size, and nothing of the raid profile
-- changes, not even the character-wide settings whose codes the two
-- registries share.
local ns = H.LoadAddon()
local C, RC, P = ns.Config, ns.RaidConfig, ns.RaidProfiles
C.Use({})
P.Attach({})

C.Set("general", "minimapShow", false)
C.Set("general", "fontSize", 14)
C.Set("party", "width", 200)
C.Set("player", "height", 60)
local unit = ns.Codec.Encode(C.Profile())
H.check("a real unit frames' export", unit, "1;gFS14;gMS0;pH60;yW200")
RC.Set("r10", "cellWidth", 120)
local ok, err = P.Import(unit, 10)
H.check("refused", ok, nil)
H.check("no raid size in it", err, "RAID_NO_SIZE")
H.check("the size kept", RC.Get("r10", "cellWidth"), 120)
H.check("the raid button kept", RC.Get("general", "minimapShow"), true)
H.check("the message", ns.L["IMPORT_" .. err], "This text holds no raid size.")
```

Create `tests/test_raid_words.lua`:

```lua
-- Words of the raid menu that were unclear or lost part of their meaning
-- in a translation (Locales/*.lua).
local ns = H.LoadAddon()
local de, es, fr = ns.Locales.deDE, ns.Locales.esES, ns.Locales.frFR

H.check("German: the arrangement section is not the tab's word", de.RAID_SECTION_arrangement ~= de.RAID_TAB_layout, true)
H.check("German: arrangement", de.RAID_SECTION_arrangement, "Blöcke und Zellen")
H.check("German: target line", de.RAID_SETTING_targetBorder, "Helle Linie bei deinem Ziel")
H.check("Spanish: the classes not named follow", es.RAID_HINT_classOrder,
    "Nombres de clase, p. ej. Sacerdote, Druida; el resto sigue")
H.check("Spanish: from the screen's centre (x)", es.RAID_HINT_x, "Esquina sup. izquierda, desde el centro de la pantalla")
H.check("Spanish: from the screen's centre (y)", es.RAID_HINT_y, es.RAID_HINT_x)
H.check("French: from the screen's centre (x)", fr.RAID_HINT_x, "Coin sup. gauche, depuis le centre de l'écran")
H.check("French: from the screen's centre (y)", fr.RAID_HINT_y, fr.RAID_HINT_x)
```

- [ ] **Step 2: Run the tests to verify they fail**

`test_raid_import_unit_string.lua` and `test_raid_schema.lua` pass already.

Run: `tests/run test_raid_import_unit_string.lua`

Expected:

```text
test_raid_import_unit_string.lua
6 passed, 0 failed
```

Run: `tests/run test_raid_damage_block.lua`

Expected:

```text
test_raid_damage_block.lua
  FAIL damage block: by role -> nil (want ASSIGNEDROLE)
  FAIL damage block: damage first -> nil (want TANK,HEALER,DAMAGER,NONE)
  FAIL damage, then no role -> A,B,C,D (want B,D,A,C)
  FAIL an unknown role does not break the order -> false (want true)
  FAIL ranked with no role ->  (want D,A,B,C)
4 passed, 5 failed
```

Run: `tests/run test_raid_words.lua`

Expected:

```text
test_raid_words.lua
  FAIL German: the arrangement section is not the tab's word -> false (want true)
  FAIL German: arrangement -> Anordnung (want Blöcke und Zellen)
  FAIL German: target line -> Helle Linie am Ziel (want Helle Linie bei deinem Ziel)
  FAIL Spanish: the classes not named follow -> Nombres de clase, p. ej. Sacerdote, Druida (want Nombres de clase, p. ej. Sacerdote, Druida; el resto sigue)
  FAIL Spanish: from the screen's centre (x) -> Esquina superior izquierda, desde el centro (want Esquina sup. izquierda, desde el centro de la pantalla)
  FAIL French: from the screen's centre (x) -> Coin supérieur gauche, depuis le centre (want Coin sup. gauche, depuis le centre de l'écran)
2 passed, 6 failed
```

Run: `tests/run test_raid_schema.lua`

Expected:

```text
test_raid_schema.lua
1295 passed, 0 failed
```

- [ ] **Step 3: The damage block sorted by role**

In `Raid/Layout.lua`:

Replace

```lua
    return list
end

-- Sorted by role: the header groups its members by assigned role (a role
-- block holds one role already). In the single block this replaces the
-- order by group.
local function sortByRole(blocks)
    for _, block in ipairs(blocks) do
        if block.kind ~= "ROLE" then
            block.filter.groupBy, block.filter.groupingOrder = "ASSIGNEDROLE", Layout.ROLE_ORDER
        end
    end
```

with

```lua
    return list
end

-- Sorted by role: the header groups its members by assigned role. A tank
-- or healer block holds one role already; the damage block holds damage
-- and the members without a role, damage first. In the single block this
-- replaces the order by group.
local function sortByRole(blocks)
    for _, block in ipairs(blocks) do
        if block.kind ~= "ROLE" or block.id == "DAMAGER" then
            block.filter.groupBy, block.filter.groupingOrder = "ASSIGNEDROLE", Layout.ROLE_ORDER
        end
    end
```

In `Raid/Layout.lua`:

Replace

```lua
        end
    elseif groupBy == "ROLE" then
        local everyClass = groups .. "," .. joined(classes())
        for i, role in ipairs(Layout.ROLES) do
            blocks[i] = { kind = "ROLE", id = role, filter = { groupFilter = everyClass,
                roleFilter = role == "DAMAGER" and "DAMAGER,NONE" or role, strictFiltering = true } }
```

with

```lua
        end
    elseif groupBy == "ROLE" then
        local everyClass = groups .. "," .. joined(classes())
        -- The damage block takes the members without a role as well, so
        -- nobody is left out of the role blocks.
        for i, role in ipairs(Layout.ROLES) do
            blocks[i] = { kind = "ROLE", id = role, filter = { groupFilter = everyClass,
                roleFilter = role == "DAMAGER" and "DAMAGER,NONE" or role, strictFiltering = true } }
```

- [ ] **Step 4: Test mode: an unknown role ranks with none**

In `Raid/TestMode.lua`:

Replace

```lua
end

-- What a block's header groups its members by (its filter's groupBy),
-- as a rank: the group, or the place of the assigned role; 0 without.
local ROLE_RANK, rank = {}, 0
for role in Layout.ROLE_ORDER:gmatch("[^,]+") do
    rank = rank + 1
```

with

```lua
end

-- What a block's header groups its members by (its filter's groupBy),
-- as a rank: the group, or the place of the assigned role (a role not in
-- the order ranks with no role); 0 without.
local ROLE_RANK, rank = {}, 0
for role in Layout.ROLE_ORDER:gmatch("[^,]+") do
    rank = rank + 1
```

In `Raid/TestMode.lua`:

Replace

```lua
local function groupRank(block, member)
    local by = block.filter.groupBy
    if by == "GROUP" then return member.subgroup end
    if by == "ASSIGNEDROLE" then return ROLE_RANK[member.assignedRole or "NONE"] end
    return 0
end

```

with

```lua
local function groupRank(block, member)
    local by = block.filter.groupBy
    if by == "GROUP" then return member.subgroup end
    if by == "ASSIGNEDROLE" then return ROLE_RANK[member.assignedRole or "NONE"] or ROLE_RANK.NONE end
    return 0
end

```

- [ ] **Step 5: German**

In `Locales/deDE.lua`:

Replace

```lua
L.RAID_NOTE_cell = "Heilungen, Schilde und der Ressourcenstreifen behalten die Standardfarben der Einheitenrahmen."
L.RAID_SECTION_raidFrames = "Schlachtzugsrahmen"
L.RAID_SECTION_grouping = "Gruppierung"
L.RAID_SECTION_arrangement = "Anordnung"
L.RAID_SECTION_position = "Position"
L.RAID_SECTION_borders = "Rahmen"
L.RAID_SECTION_size = "Größe"
```

with

```lua
L.RAID_NOTE_cell = "Heilungen, Schilde und der Ressourcenstreifen behalten die Standardfarben der Einheitenrahmen."
L.RAID_SECTION_raidFrames = "Schlachtzugsrahmen"
L.RAID_SECTION_grouping = "Gruppierung"
L.RAID_SECTION_arrangement = "Blöcke und Zellen"
L.RAID_SECTION_position = "Position"
L.RAID_SECTION_borders = "Rahmen"
L.RAID_SECTION_size = "Größe"
```

In `Locales/deDE.lua`:

Replace

```lua
L.RAID_SETTING_rangeFade = "Außer Reichweite verblassen"
L.RAID_SETTING_rangeAlpha = "Deckkraft außer Reichweite (%)"
L.RAID_SETTING_aggroBorder = "Rote Linie bei Aggro"
L.RAID_SETTING_targetBorder = "Helle Linie am Ziel"
L.RAID_HINT_showInParty = "Eine 5er-Gruppe als Schlachtzug; Gruppenrahmen aus"
L.RAID_HINT_hideBlizzard = "Erst nach /reload wieder sichtbar"
L.RAID_HINT_sizeMode = "Automatisch: Größe der Instanz, sonst der Gruppe"
```

with

```lua
L.RAID_SETTING_rangeFade = "Außer Reichweite verblassen"
L.RAID_SETTING_rangeAlpha = "Deckkraft außer Reichweite (%)"
L.RAID_SETTING_aggroBorder = "Rote Linie bei Aggro"
L.RAID_SETTING_targetBorder = "Helle Linie bei deinem Ziel"
L.RAID_HINT_showInParty = "Eine 5er-Gruppe als Schlachtzug; Gruppenrahmen aus"
L.RAID_HINT_hideBlizzard = "Erst nach /reload wieder sichtbar"
L.RAID_HINT_sizeMode = "Automatisch: Größe der Instanz, sonst der Gruppe"
```

- [ ] **Step 6: Spanish**

In `Locales/esES.lua`:

Replace

```lua
L.RAID_HINT_showInParty = "Un grupo de 5 como banda; sin marcos de grupo"
L.RAID_HINT_hideBlizzard = "Necesita /reload para volver a mostrarlos"
L.RAID_HINT_sizeMode = "Automático: tamaño de la instancia, si no del grupo"
L.RAID_HINT_x = "Esquina superior izquierda, desde el centro"
L.RAID_HINT_y = "Esquina superior izquierda, desde el centro"
L.RAID_HINT_sortBy = "Rol: tanques, sanadores, daño y el resto"
L.RAID_HINT_classOrder = "Nombres de clase, p. ej. Sacerdote, Druida"
L.RAID_HINT_hideEmpty = "Los bloques sin miembros no ocupan sitio"
L.RAID_HINT_blocksPerLine = "Luego una nueva fila (o columna) de bloques"
L.RAID_HINT_cellsPerLine = "Luego una nueva columna (o fila) de celdas"
```

with

```lua
L.RAID_HINT_showInParty = "Un grupo de 5 como banda; sin marcos de grupo"
L.RAID_HINT_hideBlizzard = "Necesita /reload para volver a mostrarlos"
L.RAID_HINT_sizeMode = "Automático: tamaño de la instancia, si no del grupo"
L.RAID_HINT_x = "Esquina sup. izquierda, desde el centro de la pantalla"
L.RAID_HINT_y = "Esquina sup. izquierda, desde el centro de la pantalla"
L.RAID_HINT_sortBy = "Rol: tanques, sanadores, daño y el resto"
L.RAID_HINT_classOrder = "Nombres de clase, p. ej. Sacerdote, Druida; el resto sigue"
L.RAID_HINT_hideEmpty = "Los bloques sin miembros no ocupan sitio"
L.RAID_HINT_blocksPerLine = "Luego una nueva fila (o columna) de bloques"
L.RAID_HINT_cellsPerLine = "Luego una nueva columna (o fila) de celdas"
```

- [ ] **Step 7: French**

In `Locales/frFR.lua`:

Replace

```lua
L.RAID_HINT_showInParty = "Un groupe de 5 comme un raid ; cadres de groupe masqués"
L.RAID_HINT_hideBlizzard = "Nécessite /reload pour les réafficher"
L.RAID_HINT_sizeMode = "Automatique : taille de l'instance, sinon du groupe"
L.RAID_HINT_x = "Coin supérieur gauche, depuis le centre"
L.RAID_HINT_y = "Coin supérieur gauche, depuis le centre"
L.RAID_HINT_sortBy = "Rôle : tanks, soigneurs, dégâts, puis le reste"
L.RAID_HINT_classOrder = "Noms de classe, p. ex. Prêtre, Druide ; le reste suit"
L.RAID_HINT_hideEmpty = "Les blocs sans membres ne prennent pas de place"
```

with

```lua
L.RAID_HINT_showInParty = "Un groupe de 5 comme un raid ; cadres de groupe masqués"
L.RAID_HINT_hideBlizzard = "Nécessite /reload pour les réafficher"
L.RAID_HINT_sizeMode = "Automatique : taille de l'instance, sinon du groupe"
L.RAID_HINT_x = "Coin sup. gauche, depuis le centre de l'écran"
L.RAID_HINT_y = "Coin sup. gauche, depuis le centre de l'écran"
L.RAID_HINT_sortBy = "Rôle : tanks, soigneurs, dégâts, puis le reste"
L.RAID_HINT_classOrder = "Noms de classe, p. ex. Prêtre, Druide ; le reste suit"
L.RAID_HINT_hideEmpty = "Les blocs sans membres ne prennent pas de place"
```

- [ ] **Step 8: Run the tests**

Run: `tests/run test_raid_import_unit_string.lua` → `6 passed, 0 failed`
Run: `tests/run test_raid_damage_block.lua` → `9 passed, 0 failed`
Run: `tests/run test_raid_words.lua` → `8 passed, 0 failed`
Run: `tests/run test_raid_schema.lua` → `1295 passed, 0 failed`
Run: `tests/run` → Expected: `23614 passed, 0 failed`

- [ ] **Step 9: Commit**

```bash
git add Locales/deDE.lua Locales/esES.lua Locales/frFR.lua Raid/Layout.lua Raid/TestMode.lua tests/test_raid_damage_block.lua tests/test_raid_import_unit_string.lua tests/test_raid_schema.lua tests/test_raid_words.lua
git commit -m "Raid: damage block sorted by role, clearer words, a unit frames' string refused

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## After the last task

- `./install "<AddOns folder of _classic_beta_>"`, then **restart the game client** (the new `Media/RaidMinimapIcon.tga` is not loaded by `/reload`). No Lua error at login. UI only: no moving, casting or fighting.
- Raid window, test mode of the unit frames (`/fuf` → Test mode) or a group: Texts tab — font, sizes, outline, shadow, name and second-line colours change the cells; Cell tab — texture, fixed health colour, background, border style/size/colour, corner radius, heals, overheal lane, shields, combat numbers. Then change the party frame's texture, font and border in `/fuf`: the raid cells must not change.
- Debuffs tab: *Shown as* → *Square in a corner*; with a debuff on a member (test mode shows one) a small square in the chosen corner in the debuff type's colour; size 1, 2 and 4 px; put a corner indicator with a spell into the same corner: the square sits beside it.
- The raid minimap button: its icon, tooltip, left click opens and closes the raid window, drag around a round and a square minimap (with the square minimap addon on), hide it on the General tab; the unit frames' button is unchanged. The addon compartment lists "Forever Unit Frames: raid frames" with the raid icon and opens the raid window.
- Type an unknown spell name, a class twice and an unknown class: the chat says why.
- Role grouping, sorted by role, in a real raid when available: damage before members without a role in the damage block.
- Then R4b (`docs/plans/2026-10-06-plan-raid-4b-window-actions-wiki-release.md`).
