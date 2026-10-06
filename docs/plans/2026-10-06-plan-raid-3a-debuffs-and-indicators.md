# Forever Unit Frames — Raid plan R3a: debuffs and corner indicators

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raid cells show the most important debuff you can dispel as an icon in their centre, bordered in its dispel type's colour (or any dispellable debuff), can tint the whole cell in that colour, can show a row of further debuffs, and show up to five corner indicators for chosen spells (HoTs, shields) — all filled by the client through aura containers, in combat too, the addon reading no aura itself — with samples of all of it in test mode. Settings per raid size, no options window yet (R4); unit frames unchanged.

**Architecture:** `Raid/CellAuras.lua` is a new element for raid cells only (`frame.key == "raid"`): a cell makes one aura container (`CustomAuraContainerTemplate`) out of combat when it first shows a unit, and *parts* configure it: aura slots (`AddAuraSlot`) for the centre icon and the tint, an aura group for the debuff row, and (`Raid/Indicators.lua`) one aura slot per corner position with the container's own spell filter (`candidateFilters.includeSpellIDs`). Slots are made when first switched on and then only enabled or disabled. Pretend cells of test mode have no container; each part draws plain sample frames from the cell's pretend member. `Raid/Settings.lua` gets the debuff and indicator settings per size; the mock learns aura slots.

**Tech Stack:** Lua 5.1, WoW: Forever API (Interface 16001, build 1.60.1.70205), offline tests with `lua5.1` + `tests/mock.lua` (`tests/run`).

Spec: `docs/specs/2026-10-06-raid-frames-design.md` (part 1; §5 the cell: Debuffs, Corner indicators; §2 platform facts). Raid plan order: R1 Foundation, R2a Headers, layout and cell, R2b Raid view in party, Blizzard's raid frames, test mode (all done) → **R3a Debuffs and corner indicators (this plan)** → R3b Icons and states (`docs/plans/2026-10-06-plan-raid-3b-icons-and-states.md`) → R4 Options window, locales, wiki, release.

Base: `main` at `70a891e` ("Raid panel: parked headers each get a spot of their own"); `tests/run` there: `19388 passed, 0 failed`. Every task below was replayed in order on a scratch worktree of that commit; the totals under "Expected" are what `tests/run` printed there. A full `tests/run` takes about a minute and a half and several GB of memory (as before).

> **Review change:** Task 4's row filter was changed in review to `"HARMFUL"` (every debuff, the centre icon's one may show twice) by maintainer decision: the negated filters (`CellAuras.ROW_FILTERS`, `"HARMFUL|!RAID"` / `"HARMFUL|!DISPELLABLE"`) hid every dispellable debuff after the first, the centre icon showing one only; the branch has `CellAuras.ROW_FILTER = "HARMFUL"`. The code blocks below still show the original filters.

## Global Constraints

- Everything in English: file names, identifiers, comments. No new user-facing string: the settings get their labels with R4's options window and locales; test mode reuses the unit frames' sample icons.
- Target client: WoW: Forever, `## Interface: 16001`. Client facts only from the Forever UI source (game type `camelot`); the ones used are in the table below. Never write the name of the local lookup tool into the repository.
- The unit frames must not notice: no unit-frame setting is added, no existing key, code, scope letter or default changes. Shared code changes without changing what unit frames do: `AuraButton.DispelCurve` takes an optional opacity (without one: the same opaque curve as before), the button wiring of `Elements/AuraContainers.lua` moves into `AuraContainers.Wire` / `AuraContainers.DispelOptions` (same calls, same order), a text setting of a registry may carry `check` (no unit-frame setting has one). One existing test is edited: `tests/test_raid_cell.lua`'s "no aura containers on cells" (Task 3 says why).
- Raid setting codes are permanent once released and unique within the raid registry. This plan adds (all per size, scopes `r10`/`r20`/`r40`): `dispelIcon` DI, `dispelFilter` DF, `dispelIconSize` DZ, `dispelTint` DT, `debuffRow` DR, `debuffCount` DC, `debuffSize` DS, and per corner position (letter J TOPLEFT, K TOPRIGHT, U BOTTOMLEFT, V BOTTOMRIGHT, T TOP) `indicator<Name>Spells` <letter>S, `…Color` <letter>C, `…Size` <letter>Z, `…Own` <letter>O, `…Time` <letter>M. Enums are stored by index: append only.
- The addon reads no aura data of raid members. Aura containers follow the rules of `Elements/AuraContainers.lua`: made and configured out of combat only (`ns.AfterCombat` key `raidAuras`); buttons get their regions in `initializeFrame`; later restyles only out of combat, guarded with `pcall`, refused ones tried again after combat (`PLAYER_REGEN_ENABLED`); no `SetScript` / `HookScript` on container buttons. No secret-value maths, no secure snippets, no `hooksecurefunc`.
- No new game event (`PLAYER_REGEN_ENABLED` is already in use; `ns.On` throws on unknown names in the client).
- The mock stays faithful: it may be stricter than the client source, never more permissive. Its aura slots follow `Blizzard_CustomAuraContainer.lua` and `Blizzard_AuraContainerSlots.lua`.
- Public repository: no local paths, host names, character names or anything about the author's machine in files or commit messages. Test names are neutral.
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
- Do not push. Every task ends with `tests/run` green and one commit (`git add` only the files the task lists).

## Client facts this plan relies on (build 1.60.1.70205)

Paths below `Interface/AddOns/`; `BAC` = `Blizzard_AuraContainer/`.

| Fact | Source |
|---|---|
| `container:AddAuraSlot(slotKey, filterString, options)` makes one frame (`CustomAuraButtonTemplate`, a frame provider with batch size 1), hands it to `initializeFrame`, then restricts it (`DenyTaintedAccessWhenAurasAreSecret`), and returns it. Options: `templateNames`, `initializeFrame`, `candidateFilters`, `sortMethod`, `sortDirection`. Slots take no part in the flow layout ("must be manually anchored") and add no forbidden aspect to the container | `BAC/Blizzard_CustomAuraContainer.lua` (`AddAuraSlot`, `CreateAuraSlotFrame`), `BAC/Blizzard_AuraContainerShared.lua` (`CustomAuraContainerSlotDefaultOptions`, `CustomAuraContainerConstants`) |
| `SetAuraSlotEnabled(key, bool)`, `SetAuraSlotFilterString`, `SetAuraSlotCandidateFilters`, `SetAuraSlotSortMethod`, `GetAuraSlotFrame`, `HasAuraSlot`, `IsAuraSlotEnabled`; an unknown key raises "aura slot '%s' was not found with this key." | `BAC/Blizzard_CustomAuraContainer.lua` |
| A slot shows the top candidate of a priority list (default comparator: your own, priority auras, `canApplyAura`, then instance ID); the client shows the slot's frame when it assigns an aura and hides it when it clears | `BAC/Blizzard_AuraContainerSlots.lua`, `BAC/Blizzard_ManagedAuraContainer.lua`, `Blizzard_FrameXMLUtil/AuraUtil.lua` |
| `candidateFilters.includeSpellIDs` is a map (`includeSpellIDs[auraData.spellId]`); spell IDs of helpful auras on the player or group members may always be matched (`CanApplyIdentityCandidateFilters`), so this works in combat | `BAC/Blizzard_AuraContainerUtil.lua` |
| Filter components include `HARMFUL`, `HELPFUL`, `PLAYER`, `RAID` ("harmful auras the player can dispel"), `DISPELLABLE` ("dispellable, regardless of whether the player's raid can dispel them"); a leading `!` negates one | `Blizzard_FrameXMLUtil/AuraUtil.lua` (`AuraUtil.AuraFilters`, `IsValidFilterString`) |
| Button inbound calls: `SetIcon`, `SetDurationCooldown` / `ClearDurationCooldown`, `SetDurationText` (a FontString; the default seconds formatter) / `ClearDurationText`, `SetApplicationCount`, `AddDispelTypeTexture`; with style `PreserveAsset` and `customDispelColorCurve` the client sets the texture's vertex colour from the curve (`GetRGBA`, alpha included). Every object must be a descendant of the button | `BAC/Blizzard_CustomAuraButton.lua` |
| A group header can give each child an AuraContainer itself (`auraContainerTemplate`), in combat too — not used, see the design decisions | `Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua` (`SetupUnitButtonConfiguration`) |

## Design decisions

- **A container per cell, made by the cell** (decided against the spec's "from the header"): the header's `auraContainerTemplate` would make containers in combat too, but slots and groups can only be added out of combat (our rule, as for every container), so a cell born in combat waits for the end of combat either way; and the header would give a container to every child it makes, including the empty child each header keeps for its size (one per block, up to nine), and to children that never show a unit. A cell makes its container the first time it has a unit, out of combat; a client without aura containers (`ns.AuraContainers.Supported()`) gets none and no error.
- **Slots, not groups**, for the centre icon, the tint and each indicator: one frame each instead of a batch of ten, switched with `SetAuraSlotEnabled` (a container call, never a touch of a restricted button), made only the first time they are wanted. Positions without spells make no slot.
- **Centre icon:** `HARMFUL|RAID` (MINE, default) or `HARMFUL|DISPELLABLE` (ALL); the client's default order; the unit frames' debuff icon look (`AuraButton.Decorate`, `StyleManaged`, `AuraContainers.Wire`), no countdown numbers, centred on the health bar, 20/18/16 by size, at frame level +12 (above the texts, below the icons of R3b).
- **Tint** (spec variant C): a second slot with the same filter whose only region is a texture over the health bar, under the texts, coloured from a curve of the dispel colours at 35 % opacity. Off by default.
- **Debuff row:** an aura group `debuffs` along the bottom of the health bar, left to right, 1 to 6 icons (default 3), 14/13/12 by size, off by default. It shows the debuffs the centre icon does not: its filter negated while the centre icon is on (`HARMFUL|!RAID` / `HARMFUL|!DISPELLABLE`), else `HARMFUL`. The row's position is fixed for now.
- **Corner indicators:** TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT, TOP; spells as a text of spell IDs (commas or spaces) checked when set (`Raid.SpellList`; names are turned into IDs by R4's options window); empty is off (the default); own casts only (`HELPFUL|PLAYER`, default) or anyone's (`HELPFUL`); a coloured square with a dark one-pixel edge, one pixel inside the cell's edge, 8 px by default; time left as a darkening swipe (default), the client's number, or nothing.
- **Test mode:** pretend cells have no container; each part makes plain frames on them (`part.BuildSample`) and draws its member's sample (`part.ShowSample`): debuffs by place in the ten (member 2 magic and curse, 5 poison, 9 disease, untyped and magic), every position with spells on every living member (swipe at 12 of 15 s, or "12").
- **Cost at 40** (spec §9): per cell one container and one slot frame by default; the tint and each indicator add one frame; the debuff row adds a batch of ten buttons. Measured in game with R3b's icons (see After the last task).

---

### Task 1: Raid debuff and corner indicator settings

**Files:**
- Modify: `Core/Registry.lua`, `Raid/Settings.lua`
- Test: `tests/test_raid_aura_settings.lua`

**Interfaces:**
- Consumes: `ns.RaidSettings`, `ns.RaidConfig`, `ns.RaidProfiles.Export`, `ns.RaidCodec` (R1).
- Produces: the raid settings listed in the Global Constraints (scope `frame`, i.e. per size); `Raid.INDICATORS` (`{ point, name, letter, color }` ×5, in the order TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT, TOP); `Raid.SpellList(text)` → list of spell IDs, or nil when the text holds anything else; `Raid.SPELL_LIST_LETTERS` (200); a registry text setting may carry `check(text) → bool` (refused values are not stored).

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_aura_settings.lua`:

```lua
-- Raid debuff and corner indicator settings (Raid/Settings.lua): one value
-- per raid size, permanent codes, enums stored by index. An indicator's
-- spells are a text of spell IDs, checked when it is set.
local ns = H.LoadAddon()
local Raid, RS, RC = ns.Raid, ns.RaidSettings, ns.RaidConfig

local CODES = {
    dispelIcon = "DI", dispelFilter = "DF", dispelIconSize = "DZ", dispelTint = "DT",
    debuffRow = "DR", debuffCount = "DC", debuffSize = "DS",
}
for _, ind in ipairs(Raid.INDICATORS) do
    local key = "indicator" .. ind.name
    CODES[key .. "Spells"] = ind.letter .. "S"
    CODES[key .. "Color"] = ind.letter .. "C"
    CODES[key .. "Size"] = ind.letter .. "Z"
    CODES[key .. "Own"] = ind.letter .. "O"
    CODES[key .. "Time"] = ind.letter .. "M"
end
for key, code in pairs(CODES) do
    local def = RS.Get(key)
    H.checkTrue(key .. " defined", def)
    if def then
        H.check(key .. " code", def.code, code)
        H.check(key .. " per size", RS.AppliesTo(def, "r20"), true)
        H.check(key .. " not character-wide", RS.AppliesTo(def, "general"), false)
    end
end

-- Five positions: the four corners and the top centre.
local points = {}
for _, ind in ipairs(Raid.INDICATORS) do points[#points + 1] = ind.point end
H.check("positions", table.concat(points, ","), "TOPLEFT,TOPRIGHT,BOTTOMLEFT,BOTTOMRIGHT,TOP")
H.check("names", Raid.INDICATORS[1].name .. Raid.INDICATORS[5].name, "TopLeftTop")

local function values(key) return table.concat(RS.Get(key).values, ",") end
H.check("dispel filter values", values("dispelFilter"), "MINE,ALL")
H.check("time values", values("indicatorTopLeftTime"), "SWIPE,NUMBER,NONE")

RC.Use({})
local DEFAULTS = {
    dispelIcon = true, dispelFilter = "MINE", dispelTint = false, debuffRow = false, debuffCount = 3,
    indicatorTopLeftSpells = "", indicatorTopLeftSize = 8, indicatorTopLeftOwn = true,
    indicatorTopLeftTime = "SWIPE", indicatorTopSpells = "",
}
for key, want in pairs(DEFAULTS) do
    H.check(key .. " default", RC.Get("r40", key), want)
end
H.check("dispel icon 10", RC.Get("r10", "dispelIconSize"), 20)
H.check("dispel icon 20", RC.Get("r20", "dispelIconSize"), 18)
H.check("dispel icon 40", RC.Get("r40", "dispelIconSize"), 16)
H.check("debuff size 10", RC.Get("r10", "debuffSize"), 14)
H.check("debuff size 40", RC.Get("r40", "debuffSize"), 12)
H.check("top left green", RC.Get("r40", "indicatorTopLeftColor")[2], 0.9)
H.check("bottom right red", RC.Get("r40", "indicatorBottomRightColor")[1], 1)

-- Spell lists: IDs separated by commas or spaces.
H.check("list", table.concat(Raid.SpellList("139, 6074 6075,,10927"), " "), "139 6074 6075 10927")
H.check("empty list", #Raid.SpellList("  "), 0)
H.check("a name is not a list", Raid.SpellList("Renew"), nil)
H.check("zero is no spell", Raid.SpellList("0"), nil)
H.check("no fractions", Raid.SpellList("139.5"), nil)
H.check("no signs", Raid.SpellList("-139"), nil)
H.checkTrue("stored", RC.Set("r40", "indicatorTopLeftSpells", " 139, 6074 "))
H.check("stored trimmed", RC.Get("r40", "indicatorTopLeftSpells"), "139, 6074")
H.check("a name is refused", RC.Set("r40", "indicatorTopLeftSpells", "Renew"), false)
H.check("refused: kept", RC.Get("r40", "indicatorTopLeftSpells"), "139, 6074")
local long = string.rep("12345,", 33)
H.check("room for many ranks", RC.Set("r40", "indicatorTopSpells", long:sub(1, -2)), true)
H.check("but not without end", RC.Set("r40", "indicatorTopSpells", long .. long), false)
-- The unit frames' free texts are not checked.
H.check("unit-frame text: no check", ns.Settings.Get("rangeFriendlySpell").check, nil)
H.check("unit-frame text: names stay", ns.Settings.Validate(ns.Settings.Get("rangeFriendlySpell"), "Renew"), "Renew")

-- Codes are unique within the raid registry; a size exports its lists.
local seen = {}
for _, def in ipairs(RS.All()) do
    H.check("unique code " .. def.code, seen[def.code], nil)
    seen[def.code] = true
end
RC.Set("r10", "indicatorTopRightSpells", "774,1058")
RC.Set("r10", "dispelFilter", "ALL")
H.check("export", ns.RaidProfiles.Export(10), "1;aDF2;aKS'774,1058")
local decoded = ns.RaidCodec.Decode(ns.RaidProfiles.Export(10))
H.check("decoded", decoded.r10.indicatorTopRightSpells, "774,1058")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run test_raid_aura_settings.lua`
Expected: `ERROR test_raid_aura_settings.lua:11: bad argument #1 to 'ipairs' (table expected, got nil)`, `0 passed, 1 failed`

- [ ] **Step 3: Let a text setting refuse what does not parse**

In `Core/Registry.lua`:

Replace

```lua
        if type(v) ~= "string" or v == "" then return nil end
        return v
    elseif t == "text" then
        -- Free text, trimmed; empty is allowed. def.maxLetters caps it.
        if type(v) ~= "string" then return nil end
        v = v:match("^%s*(.-)%s*$")
        if #v > (def.maxLetters or TEXT_MAX) then return nil end
        return v
    end
    return nil
```

with

```lua
        if type(v) ~= "string" or v == "" then return nil end
        return v
    elseif t == "text" then
        -- Free text, trimmed; empty is allowed. def.maxLetters caps it;
        -- def.check (optional) refuses what does not parse.
        if type(v) ~= "string" then return nil end
        v = v:match("^%s*(.-)%s*$")
        if #v > (def.maxLetters or TEXT_MAX) then return nil end
        if def.check and not def.check(v) then return nil end
        return v
    end
    return nil
```

- [ ] **Step 4: Add the definitions**

The definitions go at the end of the file.

In `Raid/Settings.lua`:

Replace

```lua
RaidSettings.Define({ key = "secondLine", code = "SL", scope = "frame", type = "enum",
    values = { "DEFICIT", "PERCENT", "CURRENT", "NONE" }, default = "DEFICIT" })
RaidSettings.Define({ key = "nameClassColor", code = "NC", scope = "frame", type = "bool", default = false })
```

with

```lua
RaidSettings.Define({ key = "secondLine", code = "SL", scope = "frame", type = "enum",
    values = { "DEFICIT", "PERCENT", "CURRENT", "NONE" }, default = "DEFICIT" })
RaidSettings.Define({ key = "nameClassColor", code = "NC", scope = "frame", type = "bool", default = false })

-- Debuffs (Raid/CellAuras.lua). The centre icon shows the most important
-- debuff you can dispel (MINE, the client's RAID filter) or any
-- dispellable one (ALL), bordered in its type's colour. Stored by index:
-- append only.
RaidSettings.Define({ key = "dispelIcon", code = "DI", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "dispelFilter", code = "DF", scope = "frame", type = "enum",
    values = { "MINE", "ALL" }, default = "MINE" })
RaidSettings.Define({ key = "dispelIconSize", code = "DZ", scope = "frame", type = "int", min = 8, max = 40,
    default = { r10 = 20, r20 = 18, _ = 16 } })
-- The whole cell tinted in the debuff type's colour.
RaidSettings.Define({ key = "dispelTint", code = "DT", scope = "frame", type = "bool", default = false })
-- A row of further debuffs along the bottom of the cell.
RaidSettings.Define({ key = "debuffRow", code = "DR", scope = "frame", type = "bool", default = false })
RaidSettings.Define({ key = "debuffCount", code = "DC", scope = "frame", type = "int", min = 1, max = 6, default = 3 })
RaidSettings.Define({ key = "debuffSize", code = "DS", scope = "frame", type = "int", min = 8, max = 32,
    default = { r10 = 14, r20 = 13, _ = 12 } })

-- A spell list: spell IDs separated by commas or spaces. Returns the IDs,
-- or nil when anything else is in it (a name, a sign, a fraction).
function Raid.SpellList(text)
    local ids = {}
    for token in text:gmatch("[^,%s]+") do
        if not token:match("^%d+$") then return nil end
        local id = tonumber(token)
        if id < 1 then return nil end
        ids[#ids + 1] = id
    end
    return ids
end

local function isSpellList(text) return Raid.SpellList(text) ~= nil end

-- Corner indicators (Raid/Indicators.lua): five positions, each showing
-- one of its spells while it is on the unit. Empty spells: off. The
-- letter starts every code of the position.
Raid.INDICATORS = {
    { point = "TOPLEFT", name = "TopLeft", letter = "J", color = { 0.2, 0.9, 0.2, 1 } },
    { point = "TOPRIGHT", name = "TopRight", letter = "K", color = { 1, 0.85, 0.1, 1 } },
    { point = "BOTTOMLEFT", name = "BottomLeft", letter = "U", color = { 0.3, 0.6, 1, 1 } },
    { point = "BOTTOMRIGHT", name = "BottomRight", letter = "V", color = { 1, 0.3, 0.3, 1 } },
    { point = "TOP", name = "Top", letter = "T", color = { 1, 1, 1, 1 } },
}
-- Room for every rank of a few spells.
Raid.SPELL_LIST_LETTERS = 200
for _, ind in ipairs(Raid.INDICATORS) do
    local key, l = "indicator" .. ind.name, ind.letter
    RaidSettings.Define({ key = key .. "Spells", code = l .. "S", scope = "frame", type = "text",
        maxLetters = Raid.SPELL_LIST_LETTERS, check = isSpellList, default = "" })
    RaidSettings.Define({ key = key .. "Color", code = l .. "C", scope = "frame", type = "color",
        default = ind.color })
    RaidSettings.Define({ key = key .. "Size", code = l .. "Z", scope = "frame", type = "int", min = 4, max = 24,
        default = 8 })
    -- Only your own casts of the spells.
    RaidSettings.Define({ key = key .. "Own", code = l .. "O", scope = "frame", type = "bool", default = true })
    -- The time left: darkening (a swipe), a number, or not shown. Stored
    -- by index: append only.
    RaidSettings.Define({ key = key .. "Time", code = l .. "M", scope = "frame", type = "enum",
        values = { "SWIPE", "NUMBER", "NONE" }, default = "SWIPE" })
end
```

- [ ] **Step 5: Run the tests**

Run: `tests/run raid_aura_settings` → `222 passed, 0 failed`
Run: `tests/run` → Expected: `19642 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add Core/Registry.lua Raid/Settings.lua tests/test_raid_aura_settings.lua
git commit -m "Raid debuff and corner indicator settings per size

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Mock: aura slots

**Files:**
- Modify: `tests/mock.lua`
- Test: `tests/test_aura_slot_mock.lua`

**Interfaces:**
- Consumes: the mock's aura container (`M.NewAuraContainer`, `newAuraButton`).
- Produces (mock): `container:AddAuraSlot(key, filter, options)` → frame; `HasAuraSlot`, `GetAuraSlotFrame`, `IsAuraSlotEnabled`, `SetAuraSlotEnabled`, `SetAuraSlotFilterString`, `SetAuraSlotCandidateFilters`, `SetAuraSlotSortMethod`; records `container._slots[key] = { key, filter, enabled, candidateFilters, sortMethod, frame }` and `container._slotOrder`; buttons get `ClearDurationCooldown` / `ClearDurationText`. Candidate filters are checked alike for groups and slots; spell ID maps take any positive whole number as key (Renew rank 1 is 139; the old `> 1000` test only told a map from a list, which `v == true` already does).

- [ ] **Step 1: Write the failing test**

Create `tests/test_aura_slot_mock.lua`:

```lua
-- The mock's aura slots (Blizzard_CustomAuraContainer.lua AddAuraSlot,
-- Blizzard_AuraContainerSlots.lua): one frame per slot, made at once and
-- handed to initializeFrame, locked like a group's buttons afterwards;
-- the source's argument checks; no part in the layout.
local M = H.M
H.LoadAddon()

local c = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
local seen
local frame = c:AddAuraSlot("dispel", "HARMFUL|RAID", {
    candidateFilters = { includeSpellIDs = { [139] = true, [6074] = true } },
    initializeFrame = function(b) seen = b end,
})
H.checkTrue("a frame back", frame)
H.check("initialised once with it", seen, frame)
H.check("found by key", c:GetAuraSlotFrame("dispel"), frame)
H.check("unknown key: none", c:GetAuraSlotFrame("other"), nil)
H.check("has it", c:HasAuraSlot("dispel"), true)
H.check("a custom aura button", frame._template, "CustomAuraButtonTemplate")
H.check("hidden until an aura comes", frame:IsShown(), false)
H.check("on the container", frame:GetParent(), c)
H.check("enabled", c:IsAuraSlotEnabled("dispel"), true)
H.check("filter", c._slots.dispel.filter, "HARMFUL|RAID")
H.checkTrue("small spell IDs are fine", c._slots.dispel.candidateFilters.includeSpellIDs[139])
H.check("slots do not lock anchoring to the container", rawget(c, "_layoutForbidden"), nil)
-- Anchoring the slot's frame is the addon's business.
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
H.check("anchored", (frame:GetPoint(1)), "CENTER")

c:SetAuraSlotEnabled("dispel", false)
H.check("disabled", c:IsAuraSlotEnabled("dispel"), false)
c:SetAuraSlotFilterString("dispel", "HARMFUL|DISPELLABLE")
H.check("filter changed", c._slots.dispel.filter, "HARMFUL|DISPELLABLE")
c:SetAuraSlotCandidateFilters("dispel", nil)
H.check("filters cleared", c._slots.dispel.candidateFilters, nil)
c:SetAuraSlotSortMethod("dispel", AuraContainerSortMethod.Expiration, AuraContainerSortDirection.Normal)
H.check("sort", c._slots.dispel.sortMethod, AuraContainerSortMethod.Expiration)

-- The source's checks.
H.checkError("empty key", function() c:AddAuraSlot("", "HARMFUL") end)
H.checkError("bad filter", function() c:AddAuraSlot("x", "HARMFUL|NOPE") end)
H.checkError("same key twice", function() c:AddAuraSlot("dispel", "HARMFUL") end)
H.checkError("unknown option", function() c:AddAuraSlot("y", "HARMFUL", { layout = {} }) end)
H.checkError("a list of spell IDs", function()
    c:AddAuraSlot("z", "HELPFUL", { candidateFilters = { includeSpellIDs = { 139, 774 } } })
end)
H.checkError("unknown slot", function() c:SetAuraSlotEnabled("none", true) end)
H.checkError("enabled must be a boolean", function() c:SetAuraSlotEnabled("dispel", 1) end)
H.checkError("bad sort", function() c:SetAuraSlotSortMethod("dispel", 99, 0) end)
H.checkError("a list for a group too", function()
    c:AddAuraGroup("g", "HARMFUL", { candidateFilters = { excludeSpellIDs = { 139 } } })
end)

-- The frame's duration displays: registered below it, cleared again.
local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
local text = frame:CreateFontString(nil, "OVERLAY")
frame:SetDurationCooldown(cooldown)
frame:SetDurationText(text)
H.check("swipe registered", frame._durationCooldown, cooldown)
H.check("number registered", frame._durationText, text)
frame:ClearDurationCooldown()
frame:ClearDurationText()
H.check("swipe cleared", frame._durationCooldown, nil)
H.check("number cleared", frame._durationText, nil)
H.checkError("a text that is not below it", function() frame:SetDurationText(UIParent:CreateFontString()) end)

-- Locked while auras are secret, like a group's buttons.
M.aurasSecret = true
H.checkError("locked while secret", function() frame:SetSize(10, 10) end)
H.checkError("its regions too", function() text:SetText("1") end)
M.aurasSecret = false
frame:SetSize(10, 10)
H.check("open again", frame:GetWidth(), 10)
-- Made while secret: initializeFrame still runs on the open frame.
M.combat = true
local ran = false
c:AddAuraSlot("hot", "HELPFUL|PLAYER", { initializeFrame = function(b)
    b:SetSize(6, 6)
    ran = true
end })
H.check("made in combat: initialised", ran, true)
H.checkError("made in combat: locked after", function() c:GetAuraSlotFrame("hot"):SetSize(7, 7) end)
M.combat = false
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run test_aura_slot_mock.lua`
Expected: `ERROR test_aura_slot_mock.lua:10: mock: AuraContainer has no method AddAuraSlot`, `0 passed, 1 failed`

- [ ] **Step 3: Teach the mock aura slots**

In `tests/mock.lua`:

Replace

```lua
-- while M.aurasSecret is set, as in an instance out of combat).
-- Once it has a group, only frames with the UntrustedLayoutScriptExecution
-- aspect may anchor to the container.
M.AURA_BATCH = 10
local AURA_FILTERS = { HELPFUL = true, HARMFUL = true, PLAYER = true, RAID = true, CANCELABLE = true,
    INCLUDE_NAME_PLATE_ONLY = true, MAW = true, EXTERNAL_DEFENSIVE = true, CROWD_CONTROL = true,
```

with

```lua
-- while M.aurasSecret is set, as in an instance out of combat).
-- Once it has a group, only frames with the UntrustedLayoutScriptExecution
-- aspect may anchor to the container.
-- Aura slots (AddAuraSlot, Blizzard_AuraContainerSlots.lua) hold one frame
-- each, made at once and handed to initializeFrame like a group's; they
-- take no part in the layout (anchored by the addon) and record what they
-- are told in _slots[key].
M.AURA_BATCH = 10
local AURA_FILTERS = { HELPFUL = true, HARMFUL = true, PLAYER = true, RAID = true, CANCELABLE = true,
    INCLUDE_NAME_PLATE_ONLY = true, MAW = true, EXTERNAL_DEFENSIVE = true, CROWD_CONTROL = true,
```

Replace

```lua
    forceNewLine = false }
local GROUP_KEYS = { maxFrameCount = true, templateNames = true, initializeFrame = true, candidateFilters = true,
    sortMethod = true, sortDirection = true, layout = true }
local TOOLTIP_ANCHORS = { ANCHOR_LEFT = true, ANCHOR_RIGHT = true, ANCHOR_BOTTOMLEFT = true, ANCHOR_BOTTOM = true,
    ANCHOR_BOTTOMRIGHT = true, ANCHOR_TOPLEFT = true, ANCHOR_TOP = true, ANCHOR_TOPRIGHT = true,
    ANCHOR_CURSOR = true, ANCHOR_NONE = true, ANCHOR_PRESERVE = true, ANCHOR_CURSOR_LEFT = true,
```

with

```lua
    forceNewLine = false }
local GROUP_KEYS = { maxFrameCount = true, templateNames = true, initializeFrame = true, candidateFilters = true,
    sortMethod = true, sortDirection = true, layout = true }
local SLOT_KEYS = { templateNames = true, initializeFrame = true, candidateFilters = true, sortMethod = true,
    sortDirection = true }
local TOOLTIP_ANCHORS = { ANCHOR_LEFT = true, ANCHOR_RIGHT = true, ANCHOR_BOTTOMLEFT = true, ANCHOR_BOTTOM = true,
    ANCHOR_BOTTOMRIGHT = true, ANCHOR_TOPLEFT = true, ANCHOR_TOP = true, ANCHOR_TOPRIGHT = true,
    ANCHOR_CURSOR = true, ANCHOR_NONE = true, ANCHOR_PRESERVE = true, ANCHOR_CURSOR_LEFT = true,
```

Replace

```lua
    return out
end

local function validMax(n)
    return n == math.huge or (type(n) == "number" and n >= 0 and n == math.floor(n))
end
```

with

```lua
    return out
end

-- candidateFilters (Blizzard_CustomAuraContainer.lua ValidateCandidateFilters):
-- a table or nil; maxDuration a non-negative number (hides permanent
-- auras). includeSpellIDs / excludeSpellIDs are maps, spell ID -> true:
-- the container looks up includeSpellIDs[aura.spellId]. A list would hold
-- the IDs as values and match nothing.
local function checkCandidateFilters(filters)
    assert(filters == nil or type(filters) == "table", "candidateFilters must be a table or nil.")
    for _, field in ipairs({ "includeSpellIDs", "excludeSpellIDs" }) do
        local ids = filters and filters[field]
        if ids ~= nil then
            assert(type(ids) == "table", field .. " must be a table or nil")
            for k, v in pairs(ids) do
                assert(type(k) == "number" and k > 0 and k == math.floor(k) and v == true,
                    field .. " must map spell IDs to true, not list them")
            end
        end
    end
    if filters and filters.maxDuration ~= nil then
        assert(type(filters.maxDuration) == "number" and filters.maxDuration >= 0,
            "maxDuration must be a non-negative number or nil.")
    end
end

local function checkSort(options)
    assert(options.sortMethod == nil or isEnumValue(AuraContainerSortMethod, options.sortMethod),
        "sortMethod must be a valid AuraContainerSortMethod.")
    assert(options.sortDirection == nil or isEnumValue(AuraContainerSortDirection, options.sortDirection),
        "sortDirection must be a valid AuraContainerSortDirection.")
end

local function validMax(n)
    return n == math.huge or (type(n) == "number" and n >= 0 and n == math.floor(n))
end
```

Replace

```lua
        fontString:SetText("")
    end
    function b:SetDurationText(fontString) inbound(self, fontString, "FontString"); self._durationText = fontString end
    function b:AddDispelTypeTexture(texture, options)
        inbound(self, texture, "Texture")
        for _, entry in ipairs(self._dispelTextures) do
```

with

```lua
        fontString:SetText("")
    end
    function b:SetDurationText(fontString) inbound(self, fontString, "FontString"); self._durationText = fontString end
    function b:ClearDurationCooldown() self._durationCooldown = nil end
    function b:ClearDurationText() self._durationText = nil end
    function b:AddDispelTypeTexture(texture, options)
        inbound(self, texture, "Texture")
        for _, entry in ipairs(self._dispelTextures) do
```

Replace

```lua
    w._updates = 0
    w._groups = {}
    w._groupOrder = {}
    w._flow = { axis = AnchorUtil.FlowLayoutAxis.Horizontal, anchor = "TOPLEFT",
        horizontal = AnchorUtil.FlowDirection.Right, vertical = AnchorUtil.FlowDirection.Down,
        padding = { 0, 0, 0, 0 }, lineSize = math.huge }
```

with

```lua
    w._updates = 0
    w._groups = {}
    w._groupOrder = {}
    w._slots = {}
    w._slotOrder = {}
    w._flow = { axis = AnchorUtil.FlowLayoutAxis.Horizontal, anchor = "TOPLEFT",
        horizontal = AnchorUtil.FlowDirection.Right, vertical = AnchorUtil.FlowDirection.Down,
        padding = { 0, 0, 0, 0 }, lineSize = math.huge }
```

Replace

```lua
            "initializeFrame must be a function or nil.")
        assert(options.templateNames == nil or type(options.templateNames) == "table",
            "templateNames must be a table or nil.")
        assert(options.candidateFilters == nil or type(options.candidateFilters) == "table",
            "candidateFilters must be a table or nil.")
        assert(options.sortMethod == nil or isEnumValue(AuraContainerSortMethod, options.sortMethod),
            "sortMethod must be a valid AuraContainerSortMethod.")
        assert(options.sortDirection == nil or isEnumValue(AuraContainerSortDirection, options.sortDirection),
            "sortDirection must be a valid AuraContainerSortDirection.")
        local max = options.maxFrameCount
        if max == nil then max = math.huge end
        assert(validMax(max), "maxFrameCount must be a non-negative integer or infinity.")
```

with

```lua
            "initializeFrame must be a function or nil.")
        assert(options.templateNames == nil or type(options.templateNames) == "table",
            "templateNames must be a table or nil.")
        checkCandidateFilters(options.candidateFilters)
        checkSort(options)
        local max = options.maxFrameCount
        if max == nil then max = math.huge end
        assert(validMax(max), "maxFrameCount must be a non-negative integer or infinity.")
```

Replace

```lua
    end
    -- Replaces the whole layout (merged with the defaults), like the source.
    function w:SetAuraGroupLayout(key, layout) required(self, key).layout = copyLayout(layout) end
    -- candidateFilters (Blizzard_CustomAuraContainer.lua ValidateCandidateFilters):
    -- a table or nil; maxDuration a non-negative number (hides permanent auras).
    function w:SetAuraGroupCandidateFilters(key, filters)
        assert(filters == nil or type(filters) == "table", "candidateFilters must be a table or nil.")
        -- includeSpellIDs / excludeSpellIDs are maps, spell ID -> true: the
        -- container looks up excludeSpellIDs[aura.spellId]. A list would
        -- hold the IDs as values and match nothing.
        for _, field in ipairs({ "includeSpellIDs", "excludeSpellIDs" }) do
            local ids = filters and filters[field]
            if ids ~= nil then
                assert(type(ids) == "table", field .. " must be a table or nil")
                for k, v in pairs(ids) do
                    assert(type(k) == "number" and k > 1000 and v == true,
                        field .. " must map spell IDs to true, not list them")
                end
            end
        end
        if filters and filters.maxDuration ~= nil then
            assert(type(filters.maxDuration) == "number" and filters.maxDuration >= 0,
                "maxDuration must be a non-negative number or nil.")
        end
        required(self, key).candidateFilters = filters
    end
    function w:GetAuraGroupFrameCount(key)
        local group = self._groups[key]
```

with

```lua
    end
    -- Replaces the whole layout (merged with the defaults), like the source.
    function w:SetAuraGroupLayout(key, layout) required(self, key).layout = copyLayout(layout) end
    function w:SetAuraGroupCandidateFilters(key, filters)
        local group = required(self, key)
        checkCandidateFilters(filters)
        group.candidateFilters = filters
    end
    -- Aura slots: one frame each, at a place the addon anchors.
    local function requiredSlot(self, key)
        return assert(self._slots[key], "aura slot '" .. tostring(key) .. "' was not found with this key.")
    end
    function w:AddAuraSlot(key, filter, options)
        assert(type(key) == "string" and key ~= "", "slotKey must be a non-empty string.")
        assert(validFilter(filter), "invalid filter string")
        assert(not self._slots[key], "aura slot '" .. key .. "' already exists with this key.")
        options = options or {}
        for k in pairs(options) do assert(SLOT_KEYS[k], "mock: unknown slot option " .. tostring(k)) end
        assert(options.initializeFrame == nil or type(options.initializeFrame) == "function",
            "initializeFrame must be a function or nil.")
        checkCandidateFilters(options.candidateFilters)
        checkSort(options)
        local slot = { key = key, filter = filter, enabled = true, candidateFilters = options.candidateFilters,
            sortMethod = options.sortMethod, initializeFrame = options.initializeFrame, frames = {} }
        self._slots[key] = slot
        table.insert(self._slotOrder, key)
        slot.frame = newAuraButton(self, slot)
        self._updates = self._updates + 1
        return slot.frame
    end
    function w:HasAuraSlot(key) return self._slots[key] ~= nil end
    function w:GetAuraSlotFrame(key)
        local slot = self._slots[key]
        return slot and slot.frame
    end
    function w:IsAuraSlotEnabled(key) return requiredSlot(self, key).enabled end
    function w:SetAuraSlotEnabled(key, enabled)
        assert(type(enabled) == "boolean", "enabled must be a boolean.")
        requiredSlot(self, key).enabled = enabled
    end
    function w:SetAuraSlotFilterString(key, filter)
        local slot = requiredSlot(self, key)
        assert(validFilter(filter), "invalid filter string")
        slot.filter = filter
    end
    function w:SetAuraSlotCandidateFilters(key, filters)
        local slot = requiredSlot(self, key)
        checkCandidateFilters(filters)
        slot.candidateFilters = filters
    end
    function w:SetAuraSlotSortMethod(key, method, direction)
        local slot = requiredSlot(self, key)
        checkSort({ sortMethod = method, sortDirection = direction })
        slot.sortMethod = method
    end
    function w:GetAuraGroupFrameCount(key)
        local group = self._groups[key]
```

- [ ] **Step 4: Run the tests**

Run: `tests/run aura_slot_mock` → `36 passed, 0 failed`
Run: `tests/run` → Expected: `19678 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add tests/mock.lua tests/test_aura_slot_mock.lua
git commit -m "Mock: aura slots, as the client's custom aura container has them

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Raid cell: the most important dispellable debuff in the centre, optional tint

**Files:**
- Create: `Raid/CellAuras.lua`
- Modify: `Elements/AuraButton.lua`, `Elements/AuraContainers.lua`, `Raid/Cell.lua`, `ForeverUnitFrames.toc`, `tests/test_raid_cell.lua`
- Test: `tests/test_raid_dispel.lua`

**Interfaces:**
- Consumes: `ns.AuraContainers.Supported` / `TEMPLATE`, `ns.AuraButton.Decorate` / `StyleManaged` / `DISPEL_COLORS`, `ns.RaidCell.Size`, the settings of Task 1, the mock's slots (Task 2).
- Produces: `ns.AuraButton.DispelCurve(alpha)` (one curve per opacity, none = opaque as before); `ns.AuraContainers.DispelOptions()`, `ns.AuraContainers.Wire(button, isDebuff)`; `ns.RaidCell.Get(key)` (a setting of the size the cells show); `ns.RaidAuras` (element `RaidAuras`): `FILTERS`, `LEVELS` (12), `TINT_LEVELS` (2), `TINT_ALPHA` (0.35), `METHODS`, `AddPart(part)` with `part.Apply(frame, container, auras)` → true when a button refused a restyle, `SetSlot(frame, container, key, filter, wanted, init)` → the slot's frame or nil; per cell `frame.raidAuras = { slots, container, built, failed }`, slots `dispel` and `tint`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_dispel.lua`:

```lua
-- The centre debuff icon and the tint of raid cells (Raid/CellAuras.lua):
-- a cell makes one aura container when it first shows a unit and adds
-- aura slots to it, out of combat only; the client fills them. The addon
-- reads no aura itself.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell, CellAuras = ns.RaidConfig, ns.RaidHeader, ns.RaidCell, ns.RaidAuras
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

local function member(name, class, subgroup)
    return { name = name, class = class, subgroup = subgroup, assignedRole = "DAMAGER" }
end
M.SetRaidRoster({ member("Ann", "PRIEST", 1), member("Bob", "MAGE", 1) })
M.RunTimers()

-- A container per cell with a unit.
local header = Header.headers[1]
H.check("header: no container template", header:GetAttribute("auraContainerTemplate"), nil)
local cell = header:GetAttribute("child1")
local c = cell.raidAuras.container
H.checkTrue("cell: container", c)
H.check("container on the cell", c:GetParent(), cell)
H.check("a custom aura container", c._template, "CustomAuraContainerTemplate")
H.check("the second block's empty cell: none", Header.headers[2]:GetAttribute("child1").raidAuras.container, nil)
H.check("container: the cell's unit", c:GetUnit(), "raid1")
H.check("container: no edit mode samples", c:IsEditModePreviewEnabled(), false)
H.check("container: above the texts", c:GetFrameLevel(), cell:GetFrameLevel() + CellAuras.LEVELS)
H.check("no aura groups", #c._groupOrder, 0)

-- The centre icon: one slot, debuffs you can dispel.
H.check("one slot", table.concat(c._slotOrder, ","), "dispel")
local slot = c._slots.dispel
H.check("dispellable by me", slot.filter, "HARMFUL|RAID")
H.check("enabled", slot.enabled, true)
local icon = slot.frame
H.check("icon size: 10 profile", icon:GetWidth(), 20)
local p, rel, relPoint = icon:GetPoint(1)
H.checkTrue("icon centred on the health bar", p == "CENTER" and rel == cell.health and relPoint == "CENTER")
H.check("icon registered", icon._icon, icon.icon)
H.check("swipe registered", icon._durationCooldown, icon.cooldown)
H.check("count registered", icon._applicationCount, icon.count)
local border = icon._dispelTextures[1]
H.check("border by dispel type", border.texture, icon.border)
H.check("border colours: our curve", border.options.customDispelColorCurve, ns.AuraButton.DispelCurve())
H.check("no countdown numbers", icon.cooldown._hideNumbers, true)
H.check("clicks go to the cell", icon._clickEnabled, false)

-- Settings of the active size.
RC.Set("r10", "dispelFilter", "ALL")
H.check("all dispellable", slot.filter, "HARMFUL|DISPELLABLE")
RC.Set("r10", "dispelIconSize", 26)
H.check("icon resized", icon:GetWidth(), 26)
RC.Set("r20", "dispelIconSize", 30)
H.check("another size's profile: unchanged", icon:GetWidth(), 26)
RC.Set("r10", "dispelIcon", false)
H.check("icon off: slot disabled", slot.enabled, false)
RC.Set("r10", "dispelIcon", true)
H.check("icon on again", slot.enabled, true)

-- The tint: a slot of its own, made when first switched on.
RC.Set("r10", "dispelTint", true)
local tint = c._slots.tint
H.checkTrue("tint slot made", tint)
H.check("tint: same filter", tint.filter, "HARMFUL|DISPELLABLE")
local tintTexture = tint.frame.tint
local entry = tint.frame._dispelTextures[1]
H.check("tint texture registered", entry.texture, tintTexture)
H.check("tint: lighter colours", entry.options.customDispelColorCurve, ns.AuraButton.DispelCurve(CellAuras.TINT_ALPHA))
H.check("tint curve: magic at the tint opacity", entry.options.customDispelColorCurve.points[2][2].a, 0.35)
H.check("border curve stays opaque", ns.AuraButton.DispelCurve().points[2][2].a, 1)
H.check("tint over the health bar", tintTexture._allPoints, cell.health)
H.check("tint under the texts", tint.frame:GetFrameLevel(), cell:GetFrameLevel() + CellAuras.TINT_LEVELS)
H.check("tint: no mouse", tint.frame._motionEnabled, false)
RC.Set("r10", "dispelTint", false)
H.check("tint off: disabled", tint.enabled, false)
RC.ResetScope("r10")
H.check("reset: mine again", slot.filter, "HARMFUL|RAID")

-- A roster change that keeps the unit: the container looks again.
local updates = c._updates
M.SetRaidRoster({ member("Cid", "PRIEST", 1), member("Bob", "MAGE", 1) })
H.checkTrue("same unit, someone else: updated", c._updates > updates)

-- In combat: settings wait, and a cell made now gets its slots after it.
M.combat = true
RC.Set("r10", "dispelFilter", "ALL")
H.check("combat: filter unchanged", slot.filter, "HARMFUL|RAID")
M.SetRaidRoster({ member("Cid", "PRIEST", 1), member("Bob", "MAGE", 1), member("Dan", "ROGUE", 1) })
local late = header:GetAttribute("child3")
H.check("combat join: no container yet", late.raidAuras.container, nil)
M.SetCombat(false)
H.check("after combat: filter", slot.filter, "HARMFUL|DISPELLABLE")
local lateContainer = late.raidAuras.container
H.check("after combat: the new cell's slot", lateContainer._slots.dispel.filter, "HARMFUL|DISPELLABLE")
H.check("after combat: its unit", lateContainer:GetUnit(), "raid3")
H.check("nothing blocked", #M.blocked, 0)

-- Auras secret out of combat (an instance): a resize is refused and tried
-- again after the next combat.
M.aurasSecret = true
RC.Set("r10", "dispelIconSize", 24)
M.aurasSecret = false
H.check("secret: icon kept its size", icon:GetWidth(), 20)
M.combat = true
M.SetCombat(false)
H.check("after combat: resized", icon:GetWidth(), 24)
RC.ResetScope("r10")
H.check("no errors", #M.errors, 0)

-- Test mode's pretend cells have no container.
ns.TestMode.Set(true)
H.check("pretend cell: no container", Cell.fakes[1].raidAuras.container, nil)
H.check("pretend cell: nothing built", Cell.fakes[1].raidAuras.built, nil)
ns.TestMode.Set(false)

-- Unit frames build nothing of it.
H.check("player frame: nothing", ns.Frames.player.raidAuras, nil)

-- A client without aura containers: cells without auras, no error.
ns = H.LoadAddon()
M.auraContainerMissing = true
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ member("Ann", "PRIEST", 1) })
H.check("no containers: the cell has none", ns.RaidHeader.headers[1]:GetAttribute("child1").raidAuras.container, nil)
H.check("no containers: no error", #M.errors, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run test_raid_dispel.lua`
Expected: `ERROR test_raid_dispel.lua:23: attempt to index field 'raidAuras' (a nil value)`, `1 passed, 1 failed`

- [ ] **Step 3: A dispel colour curve per opacity**

In `Elements/AuraButton.lua`:

Replace

```lua
    button.border:SetVertexColor(c[1], c[2], c[3], 1)
end

local dispelCurve
local function getDispelCurve()
    if dispelCurve then return dispelCurve end
    dispelCurve = C_CurveUtil.CreateColorCurve()
    if Enum and Enum.LuaCurveType then dispelCurve:SetType(Enum.LuaCurveType.Step) end
    for _, point in ipairs(DISPEL_POINTS) do
        local c = AuraButton.DISPEL_COLORS[point[2]]
        dispelCurve:AddPoint(point[1], CreateColor(c[1], c[2], c[3], 1))
    end
    return dispelCurve
end
-- The dispel colour curve (dispel type number -> border colour), made once.
AuraButton.DispelCurve = getDispelCurve

-- Size, icon inset, countdown numbers and the buff border. Returns the
```

with

```lua
    button.border:SetVertexColor(c[1], c[2], c[3], 1)
end

local dispelCurves = {}
local function getDispelCurve(alpha)
    alpha = alpha or 1
    local curve = dispelCurves[alpha]
    if curve then return curve end
    curve = C_CurveUtil.CreateColorCurve()
    if Enum and Enum.LuaCurveType then curve:SetType(Enum.LuaCurveType.Step) end
    for _, point in ipairs(DISPEL_POINTS) do
        local c = AuraButton.DISPEL_COLORS[point[2]]
        curve:AddPoint(point[1], CreateColor(c[1], c[2], c[3], alpha))
    end
    dispelCurves[alpha] = curve
    return curve
end
-- The dispel colour curve (dispel type number -> border colour), made once
-- per opacity: opaque for borders (no argument), less for a tint
-- (Raid/CellAuras.lua).
AuraButton.DispelCurve = getDispelCurve

-- Size, icon inset, countdown numbers and the buff border. Returns the
```

- [ ] **Step 4: Share the container buttons' wiring**

Behaviour of the unit frames' containers is unchanged: the same calls in the same order.

In `Elements/AuraContainers.lua`:

Replace

```lua

-- Debuff border: our white texture keeps its asset; the client colours it
-- from the curve, for debuffs without a dispel type too (the NONE colour).
local function dispelOptions()
    return {
        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        showWithoutDispelType = true,
```

with

```lua

-- Debuff border: our white texture keeps its asset; the client colours it
-- from the curve, for debuffs without a dispel type too (the NONE colour).
function AuraContainers.DispelOptions()
    return {
        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        showWithoutDispelType = true,
```

Replace

```lua
    }
end

-- entry = { frame, key, isDebuff, buttons }; own: the button belongs to
-- the "own" group (drawn at the own size).
function AuraContainers.InitButton(entry, own, button)
```

with

```lua
    }
end

-- A decorated button's regions handed to the client: icon, swipe, count
-- and, for a debuff, the border coloured by dispel type. Tooltips on
-- hover, clicks through to the unit button below. In initializeFrame
-- only (Raid/CellAuras.lua wires its debuff icons the same way).
function AuraContainers.Wire(button, isDebuff)
    button:SetIcon(button.icon)
    button:SetDurationCooldown(button.cooldown)
    button:SetApplicationCount(button.count)
    if isDebuff then button:AddDispelTypeTexture(button.border, AuraContainers.DispelOptions()) end
    button:SetTooltipAnchorPoint("ANCHOR_BOTTOMRIGHT")
    pcall(button.SetMouseClickEnabled, button, false)
end

-- entry = { frame, key, isDebuff, buttons }; own: the button belongs to
-- the "own" group (drawn at the own size).
function AuraContainers.InitButton(entry, own, button)
```

Replace

```lua
    -- Fonts before the count is registered: the client writes it at once.
    AuraButton.StyleManaged(button, entry.frame.key, size, group.showTime)
    entry.buttons[#entry.buttons + 1] = { button = button, own = own }
    button:SetIcon(button.icon)
    button:SetDurationCooldown(button.cooldown)
    button:SetApplicationCount(button.count)
    if entry.isDebuff then button:AddDispelTypeTexture(button.border, dispelOptions()) end
    button:SetTooltipAnchorPoint("ANCHOR_BOTTOMRIGHT")
    -- Tooltips on hover, clicks through to the unit button below.
    pcall(button.SetMouseClickEnabled, button, false)
end

-- Containers per frame ------------------------------------------------------------
```

with

```lua
    -- Fonts before the count is registered: the client writes it at once.
    AuraButton.StyleManaged(button, entry.frame.key, size, group.showTime)
    entry.buttons[#entry.buttons + 1] = { button = button, own = own }
    AuraContainers.Wire(button, entry.isDebuff)
end

-- Containers per frame ------------------------------------------------------------
```

- [ ] **Step 5: Let other raid files read the cells' profile**

In `Raid/Cell.lua`:

Replace

```lua
    return ns.RaidSize.Current() or 10
end

local function get(key)
    return ns.RaidConfig.Get(ns.Raid.Scope(Cell.Size()), key)
end

-- What a cell never shows, whatever the party frame does: no title row,
-- portrait, castbar, auras, combat numbers, threat glow or raid marker
```

with

```lua
    return ns.RaidSize.Current() or 10
end

-- A setting of the raid profile the cells show.
function Cell.Get(key)
    return ns.RaidConfig.Get(ns.Raid.Scope(Cell.Size()), key)
end
local get = Cell.Get

-- What a cell never shows, whatever the party frame does: no title row,
-- portrait, castbar, auras, combat numbers, threat glow or raid marker
```

- [ ] **Step 6: Create `Raid/CellAuras.lua`**

Create `Raid/CellAuras.lua`:

```lua
local _, ns = ...

-- The auras of a raid cell. The addon reads none itself (other members'
-- auras are secret in combat): a cell gets one aura container
-- (CustomAuraContainerTemplate) when it first shows a unit, and the
-- client fills what this file configures on it, in combat too. Parts add
-- their slots and groups to it:
-- * the centre icon: one aura slot (AddAuraSlot) with the most important
--   debuff you can dispel ("HARMFUL|RAID": RAID is "dispellable by the
--   player", AuraUtil.AuraFilters) or any dispellable one
--   ("HARMFUL|DISPELLABLE"), bordered in its type's colour through our
--   colour curve, as the unit frames' debuff icons are;
-- * the tint: a second slot with the same filter whose only region is a
--   texture over the health bar, coloured by the client from a curve of
--   the same colours at a lower opacity. Its own slot, so switching it is
--   a container call (SetAuraSlotEnabled), never a touch of a button;
-- * more parts register with CellAuras.AddPart (the debuff row, the corner
--   indicators).
-- A slot is made the first time it is switched on: cells that never use
-- one never pay for its frame.
--
-- As for the unit frames' containers (Elements/AuraContainers.lua): made
-- and configured out of combat only, a cell the header made in combat
-- waits for the end of combat; buttons are given their regions in
-- initializeFrame, restyled later only out of combat and, while auras are
-- secret, refused (tried again after combat). No scripts on them.
-- The group header could hand every cell a container itself
-- (auraContainerTemplate), in combat too, but slots can only be added out
-- of combat anyway, and it would give one to every child it makes, the
-- empty one each header keeps for its size included. Test mode's pretend
-- cells have none (they show samples).
local CellAuras = { name = "RaidAuras" }
ns.RaidAuras = CellAuras

local Cell, AuraButton = ns.RaidCell, ns.AuraButton
local get = Cell.Get

CellAuras.FILTERS = { MINE = "HARMFUL|RAID", ALL = "HARMFUL|DISPELLABLE" }
-- Above the bars' texts (+10), below the raid marker and icons (+18).
CellAuras.LEVELS = 12
-- The tint lies on the health bar, under its texts.
CellAuras.TINT_LEVELS = 2
CellAuras.TINT_ALPHA = 0.35
-- Everything a container must take before a cell uses it.
CellAuras.METHODS = { "SetUnit", "GetUnit", "UpdateAllAuras", "SetEditModePreviewEnabled", "AddAuraSlot",
    "SetAuraSlotEnabled", "SetAuraSlotFilterString", "SetAuraSlotCandidateFilters", "AddAuraGroup",
    "SetAuraGroupEnabled", "SetAuraGroupFilterString", "SetAuraGroupMaxFrameCount", "SetAuraGroupLayout",
    "SetFlowLayoutAxis", "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection" }

-- part.Apply(frame, container, auras) configures the part out of combat;
-- it returns true when a button refused to be restyled.
local parts = {}
function CellAuras.AddPart(part)
    parts[#parts + 1] = part
end

-- Cells waiting for the end of combat, cells whose buttons refused a
-- restyle.
local waiting = setmetatable({}, { __mode = "k" })
local stale = setmetatable({}, { __mode = "k" })

-- Slots -------------------------------------------------------------------------------

-- A slot of the cell's container, made the first time it is wanted.
-- auras.slots[key] is its frame.
function CellAuras.Slot(frame, container, key, filter, init)
    local auras = frame.raidAuras
    if not auras.slots[key] then
        auras.slots[key] = container:AddAuraSlot(key, filter, { initializeFrame = function(b) init(frame, b) end })
    end
    return auras.slots[key]
end

-- Switches a slot, making it when it is wanted for the first time; one
-- that was never wanted is not made. Returns its frame, or nil.
function CellAuras.SetSlot(frame, container, key, filter, wanted, init)
    local slot = frame.raidAuras.slots[key]
    if not slot and not wanted then return nil end
    slot = CellAuras.Slot(frame, container, key, filter, init)
    container:SetAuraSlotFilterString(key, filter)
    container:SetAuraSlotEnabled(key, wanted == true)
    return slot
end

-- The centre icon and the tint --------------------------------------------------------

local function dispelSize()
    return ns.Pixel.Snap(get("dispelIconSize"), nil, 1)
end

-- The icon: the unit frames' debuff icon look, centred on the health bar.
local function initIcon(frame, button)
    AuraButton.Decorate(button, true)
    AuraButton.StyleManaged(button, frame.key, dispelSize(), false)
    button:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
    ns.AuraContainers.Wire(button, true)
end

-- The tint: a slot frame of one pixel with no mouse; its texture covers
-- the health bar.
local function initTint(frame, button)
    pcall(button.SetMouseClickEnabled, button, false)
    pcall(button.SetMouseMotionEnabled, button, false)
    button:SetSize(1, 1)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    button:SetFrameLevel(frame:GetFrameLevel() + CellAuras.TINT_LEVELS)
    local tint = button:CreateTexture(nil, "ARTWORK")
    tint:SetColorTexture(1, 1, 1, 1)
    tint:SetAllPoints(frame.health)
    button.tint = tint
    button:AddDispelTypeTexture(tint, { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        customDispelColorCurve = AuraButton.DispelCurve(CellAuras.TINT_ALPHA) })
end

CellAuras.AddPart({
    Apply = function(frame, container)
        local filter = CellAuras.FILTERS[get("dispelFilter")]
        local icon = CellAuras.SetSlot(frame, container, "dispel", filter, get("dispelIcon"), initIcon)
        CellAuras.SetSlot(frame, container, "tint", filter, get("dispelTint"), initTint)
        return icon ~= nil and not pcall(AuraButton.StyleManaged, icon, frame.key, dispelSize(), false)
    end,
})

-- The container -----------------------------------------------------------------------

local function usable(container)
    for _, method in ipairs(CellAuras.METHODS) do
        if type(container[method]) ~= "function" then return false end
    end
    return true
end

-- Every part onto the container; out of combat.
local function apply(frame)
    local container = frame.raidAuras.container
    stale[frame] = nil
    container:SetFrameLevel(frame:GetFrameLevel() + CellAuras.LEVELS)
    for _, part in ipairs(parts) do
        if part.Apply(frame, container, frame.raidAuras) then stale[frame] = true end
    end
end

-- The container and its first configuration, out of combat. A client
-- without the calls a cell needs, or a refusal, leaves the cell without
-- auras for the session (a refusal is reported once).
local function build(frame)
    local auras = frame.raidAuras
    local ok, err = pcall(function()
        local container = CreateFrame("AuraContainer", nil, frame, ns.AuraContainers.TEMPLATE)
        auras.container = container
        if not usable(container) then
            auras.failed = true
            return
        end
        container:SetEditModePreviewEnabled(false)
        apply(frame)
        container:SetUnit(frame.unit or "none")
    end)
    if not ok then
        auras.failed = true
        geterrorhandler()(err)
    end
    if auras.failed then
        if auras.container then auras.container:Hide() end
        auras.container = nil
        return false
    end
    auras.built = true
    return true
end

local function flush()
    local frames = {}
    for frame in pairs(waiting) do frames[#frames + 1] = frame end
    for _, frame in ipairs(frames) do
        waiting[frame] = nil
        local auras = frame.raidAuras
        if auras.built then
            apply(frame)
        elseif not auras.failed then
            build(frame)
        end
    end
end

local function later(frame)
    waiting[frame] = true
    ns.AfterCombat("raidAuras", flush)
end

-- Whether the cell's container is configured and can be told its unit.
local function ready(frame)
    local auras = frame.raidAuras
    if not auras or auras.failed or frame.pretend then return false end
    if auras.built then return true end
    if not ns.AuraContainers.Supported() then
        auras.failed = true
        return false
    end
    if InCombatLockdown() then
        later(frame)
        return false
    end
    return build(frame)
end

-- Element -------------------------------------------------------------------------------

function CellAuras.Build(frame)
    if frame.key ~= Cell.KEY then return end
    frame.raidAuras = { slots = {} }
end

-- Settings changed: applied now, or after combat.
function CellAuras.Style(frame)
    local auras = frame.raidAuras
    if not (auras and auras.built) then return end
    if InCombatLockdown() then later(frame) else apply(frame) end
end

-- A new unit, or the same raid unit after a roster change (it may be
-- someone else now): the container looks again.
function CellAuras.Update(frame)
    if not ready(frame) then return end
    local container, unit = frame.raidAuras.container, frame.unit or "none"
    if container:GetUnit() ~= unit then
        container:SetUnit(unit)
    else
        container:UpdateAllAuras()
    end
end

ns.On("PLAYER_REGEN_ENABLED", function()
    for frame in pairs(stale) do
        if not waiting[frame] then apply(frame) end
    end
end)

ns.RegisterElement(CellAuras)
```

- [ ] **Step 7: Load it**

`Raid\CellAuras.lua` loads directly after `Raid\Cell.xml`.

In `ForeverUnitFrames.toc`:

Replace

```
Units\PartyTargets.lua
Raid\Cell.lua
Raid\Cell.xml
Raid\Header.lua
Raid\TestMode.lua
Core\Blizzard.lua
```

with

```
Units\PartyTargets.lua
Raid\Cell.lua
Raid\Cell.xml
Raid\CellAuras.lua
Raid\Header.lua
Raid\TestMode.lua
Core\Blizzard.lua
```

- [ ] **Step 8: Correct R2a's check on cell containers**

`tests/test_raid_cell.lua` (R2a) checks that cells get no aura containers at all; it now fails with `FAIL no aura containers on cells -> 2 (want 0)`, because each cell makes one container of its own for its debuffs. What R2a meant still holds and is checked instead: no container for the unit frames' aura groups (`frame.auraGroupKeys = {}`), and exactly one own container per cell.

In `tests/test_raid_cell.lua`:

Replace

```lua
for _, container in ipairs(M.auraContainers) do
    if container:GetParent() == tank or container:GetParent() == ann then onCells = onCells + 1 end
end
H.check("no aura containers on cells", onCells, 0)
H.check("no castbar", tank.castbar, nil)
H.check("title row hidden", tank.title:IsShown(), false)
local seen = {}
```

with

```lua
for _, container in ipairs(M.auraContainers) do
    if container:GetParent() == tank or container:GetParent() == ann then onCells = onCells + 1 end
end
-- The unit frames' aura groups stay off (frame.auraGroupKeys); the one
-- container per cell is the cell's own (Raid/CellAuras.lua).
H.check("no unit-frame aura containers on cells", next(tank.auraContainers or {}), nil)
H.check("one container of its own per cell", onCells, 2)
H.check("no castbar", tank.castbar, nil)
H.check("title row hidden", tank.title:IsShown(), false)
local seen = {}
```

- [ ] **Step 9: Run the tests**

Run: `tests/run raid_dispel` → `52 passed, 0 failed`
Run: `tests/run test_raid_cell.lua` → `73 passed, 0 failed`
Run: `tests/run` → Expected: `19731 passed, 0 failed`

- [ ] **Step 10: Commit**

```bash
git add Elements/AuraButton.lua Elements/AuraContainers.lua ForeverUnitFrames.toc Raid/Cell.lua Raid/CellAuras.lua tests/test_raid_cell.lua tests/test_raid_dispel.lua
git commit -m "Raid cell: the most important dispellable debuff in the centre, optional tint

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Raid cell: a row of further debuffs

**Files:**
- Modify: `Raid/CellAuras.lua`
- Test: `tests/test_raid_debuffs.lua`

**Interfaces:**
- Consumes: `ns.RaidAuras.AddPart` (Task 3), `debuffRow` / `debuffCount` / `debuffSize` / `dispelIcon` / `dispelFilter`.
- Produces: `CellAuras.ROW_FILTERS`, `ROW_GROUP` (`"debuffs"`), `ROW_INSET` (1), `ROW_SPACING` (1); the group is made when first switched on; `frame.raidAuras.row` lists its buttons.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_debuffs.lua`:

```lua
-- The debuff row of raid cells (Raid/CellAuras.lua): an aura group of the
-- cell's container along the bottom of the health bar, made when first
-- switched on, showing the debuffs the centre icon does not.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, CellAuras = ns.RaidConfig, ns.RaidHeader, ns.RaidAuras
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 } })
M.RunTimers()

local cell = Header.headers[1]:GetAttribute("child1")
local c = cell.raidAuras.container
H.check("off by default: no group", #c._groupOrder, 0)

RC.Set("r10", "debuffRow", true)
local group = c._groups[CellAuras.ROW_GROUP]
H.checkTrue("on: a group", group)
H.check("the rest of the debuffs", group.filter, "HARMFUL|!RAID")
H.check("three", group.max, 3)
H.check("icons of the 10 profile", group.layout.elementWidth, 14)
H.check("a pixel apart", group.layout.elementSpacing, 1)
H.check("enabled", group.enabled, true)
H.check("flow: a row", c._flow.axis, AnchorUtil.FlowLayoutAxis.Horizontal)
H.check("flow: from the bottom left", c._flow.anchor, "BOTTOMLEFT")
H.check("flow: rightwards, then up", c._flow.horizontal .. "," .. c._flow.vertical, "1,1")
local p, rel, relPoint, x, y = c:GetPoint(1)
H.checkTrue("on the health bar's bottom left", p == "BOTTOMLEFT" and rel == cell.health and relPoint == "BOTTOMLEFT")
H.check("a pixel in", x .. "," .. y, "1,1")
H.check("a batch of buttons", #cell.raidAuras.row, M.AURA_BATCH)
local b = cell.raidAuras.row[1]
H.check("button size", b:GetWidth(), 14)
H.check("icon registered", b._icon, b.icon)
H.check("border by dispel type", b._dispelTextures[1].texture, b.border)
H.check("the centre icon stays", c._slots.dispel.enabled, true)

-- Filters follow the centre icon.
RC.Set("r10", "dispelFilter", "ALL")
H.check("all dispellable in the centre: the rest", group.filter, "HARMFUL|!DISPELLABLE")
RC.Set("r10", "dispelIcon", false)
H.check("no centre icon: every debuff", group.filter, "HARMFUL")
RC.Set("r10", "dispelIcon", true)
RC.Set("r10", "dispelFilter", "MINE")

-- Count and size.
RC.Set("r10", "debuffCount", 5)
H.check("five", group.max, 5)
RC.Set("r10", "debuffSize", 18)
H.check("layout resized", group.layout.elementWidth, 18)
H.check("buttons resized", b:GetWidth(), 18)

-- The 40-player profile has its own.
RC.Set("general", "sizeMode", "40")
H.check("40: off there", group.enabled, false)
RC.Set("r40", "debuffRow", true)
H.check("40: on", group.enabled, true)
H.check("40: its size", group.layout.elementWidth, 12)
H.check("40: its count", group.max, 3)
RC.Set("general", "sizeMode", "AUTO")

-- Off again: the group stays, disabled.
RC.Set("r10", "debuffRow", false)
H.check("off: disabled", group.enabled, false)
H.check("still one group", #c._groupOrder, 1)
H.check("no errors", #M.errors, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run test_raid_debuffs.lua`
Expected: `FAIL on: a group -> false (want true)`, then `ERROR test_raid_debuffs.lua:21: attempt to index local 'group' (a nil value)`, `1 passed, 2 failed`

- [ ] **Step 3: The debuff row as a part of the cell's container**

In `Raid/CellAuras.lua`:

Replace

```lua
--   texture over the health bar, coloured by the client from a curve of
--   the same colours at a lower opacity. Its own slot, so switching it is
--   a container call (SetAuraSlotEnabled), never a touch of a button;
-- * more parts register with CellAuras.AddPart (the debuff row, the corner
--   indicators).
-- A slot is made the first time it is switched on: cells that never use
-- one never pay for its frame.
--
```

with

```lua
--   texture over the health bar, coloured by the client from a curve of
--   the same colours at a lower opacity. Its own slot, so switching it is
--   a container call (SetAuraSlotEnabled), never a touch of a button;
-- * the debuff row: an aura group along the bottom of the health bar
--   with the debuffs the centre icon does not show (its filter negated
--   while it is on: "!" is AuraUtil.AuraFilterNegationPrefix);
-- * more parts register with CellAuras.AddPart (the corner indicators).
-- A slot is made the first time it is switched on: cells that never use
-- one never pay for its frame.
--
```

Replace

```lua
local CellAuras = { name = "RaidAuras" }
ns.RaidAuras = CellAuras

local Cell, AuraButton = ns.RaidCell, ns.AuraButton
local get = Cell.Get

CellAuras.FILTERS = { MINE = "HARMFUL|RAID", ALL = "HARMFUL|DISPELLABLE" }
-- Above the bars' texts (+10), below the raid marker and icons (+18).
CellAuras.LEVELS = 12
-- The tint lies on the health bar, under its texts.
```

with

```lua
local CellAuras = { name = "RaidAuras" }
ns.RaidAuras = CellAuras

local Cell, AuraButton, Pixel = ns.RaidCell, ns.AuraButton, ns.Pixel
local get = Cell.Get

CellAuras.FILTERS = { MINE = "HARMFUL|RAID", ALL = "HARMFUL|DISPELLABLE" }
CellAuras.ROW_FILTERS = { MINE = "HARMFUL|!RAID", ALL = "HARMFUL|!DISPELLABLE" }
CellAuras.ROW_GROUP = "debuffs"
-- The row's distance from the health bar's corner and between its icons.
CellAuras.ROW_INSET = 1
CellAuras.ROW_SPACING = 1
-- Above the bars' texts (+10), below the raid marker and icons (+18).
CellAuras.LEVELS = 12
-- The tint lies on the health bar, under its texts.
```

Replace

```lua
-- The centre icon and the tint --------------------------------------------------------

local function dispelSize()
    return ns.Pixel.Snap(get("dispelIconSize"), nil, 1)
end

-- The icon: the unit frames' debuff icon look, centred on the health bar.
```

with

```lua
-- The centre icon and the tint --------------------------------------------------------

local function dispelSize()
    return Pixel.Snap(get("dispelIconSize"), nil, 1)
end

-- The icon: the unit frames' debuff icon look, centred on the health bar.
```

Replace

```lua
    end,
})

-- The container -----------------------------------------------------------------------

local function usable(container)
```

with

```lua
    end,
})

-- The debuff row ----------------------------------------------------------------------

local function rowFilter()
    if get("dispelIcon") then return CellAuras.ROW_FILTERS[get("dispelFilter")] end
    return "HARMFUL"
end

local function rowSize()
    return Pixel.Snap(get("debuffSize"), nil, 1)
end

local function rowLayout(size)
    local spacing = Pixel.Snap(CellAuras.ROW_SPACING)
    return { elementWidth = size, elementHeight = size, elementSpacing = spacing, lineSpacing = spacing }
end

local function initRowButton(frame, button)
    AuraButton.Decorate(button, true)
    AuraButton.StyleManaged(button, frame.key, rowSize(), false)
    ns.AuraContainers.Wire(button, true)
    local row = frame.raidAuras.row
    row[#row + 1] = button
end

-- The group is made the first time the row is switched on; its buttons
-- (a batch at a time, the client's choice) are recorded for restyling.
CellAuras.AddPart({
    Apply = function(frame, container, auras)
        local wanted, key = get("debuffRow") == true, CellAuras.ROW_GROUP
        if not auras.row and not wanted then return false end
        local size, layout = rowSize(), rowLayout(rowSize())
        if not auras.row then
            auras.row = {}
            container:AddAuraGroup(key, rowFilter(), { maxFrameCount = get("debuffCount"), layout = layout,
                initializeFrame = function(b) initRowButton(frame, b) end })
        end
        container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
        container:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
        container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
        container:SetAuraGroupFilterString(key, rowFilter())
        container:SetAuraGroupMaxFrameCount(key, get("debuffCount"))
        container:SetAuraGroupLayout(key, layout)
        container:SetAuraGroupEnabled(key, wanted)
        local inset = Pixel.Snap(CellAuras.ROW_INSET)
        container:ClearAllPoints()
        container:SetPoint("BOTTOMLEFT", frame.health, "BOTTOMLEFT", inset, inset)
        local refused = false
        for _, button in ipairs(auras.row) do
            if not pcall(AuraButton.StyleManaged, button, frame.key, size, false) then refused = true end
        end
        return refused
    end,
})

-- The container -----------------------------------------------------------------------

local function usable(container)
```

- [ ] **Step 4: Run the tests**

Run: `tests/run raid_debuffs` → `29 passed, 0 failed`
Run: `tests/run` → Expected: `19760 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Raid/CellAuras.lua tests/test_raid_debuffs.lua
git commit -m "Raid cell: a row of further debuffs

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Raid cell: corner indicators as aura slots by spell ID

**Files:**
- Create: `Raid/Indicators.lua`
- Modify: `Raid/CellAuras.lua`, `ForeverUnitFrames.toc`
- Test: `tests/test_raid_indicators.lua`

**Interfaces:**
- Consumes: `ns.Raid.INDICATORS`, `ns.Raid.SpellList` (Task 1), `ns.RaidAuras.AddPart` / `SetSlot` (Task 3), `ns.Texts.SetFont`, `ns.Media.Font`.
- Produces: `CellAuras.SetSlot(frame, container, key, filter, wanted, init, candidateFilters)` (7th argument new: given at `AddAuraSlot` and set on every apply); `ns.RaidIndicators`: `INSET` (1), `EDGE` (1), `EDGE_COLOR`, `Key(ind)` (`"indicator" .. name`), `SlotKey(ind)` (`"indicator" .. point`), `SpellSet(text)` (map or nil), `Filter(key)`; slot frames carry `edge`, `color`, `cooldown`, `time`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_indicators.lua`:

```lua
-- Corner indicators of raid cells (Raid/Indicators.lua): an aura slot of
-- the cell's container per position with spells, the container's own
-- spell filter, the square, swipe and number as regions of the slot's
-- frame. Positions without spells make no slot.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Raid, Ind = ns.RaidConfig, ns.RaidHeader, ns.Raid, ns.RaidIndicators
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 }, { name = "Bob", class = "MAGE", subgroup = 1 } })
M.RunTimers()

local cell = Header.headers[1]:GetAttribute("child1")
local other = Header.headers[1]:GetAttribute("child2")
local c = cell.raidAuras.container
H.check("none by default", table.concat(c._slotOrder, ","), "dispel")
H.check("slot key", Ind.SlotKey(Raid.INDICATORS[1]), "indicatorTOPLEFT")
H.check("spell set", Ind.SpellSet("139, 6074")[6074], true)
H.check("empty: off", Ind.SpellSet(""), nil)

-- Renew in the top left corner.
RC.Set("r10", "indicatorTopLeftSpells", "139, 6074")
local slot = c._slots.indicatorTOPLEFT
H.checkTrue("a slot", slot)
H.check("your own buffs", slot.filter, "HELPFUL|PLAYER")
H.check("the spells, as a map", slot.candidateFilters.includeSpellIDs[139], true)
H.check("both ranks", slot.candidateFilters.includeSpellIDs[6074], true)
H.check("enabled", slot.enabled, true)
H.checkTrue("the other cell too", other.raidAuras.container._slots.indicatorTOPLEFT)
local b = slot.frame
H.check("size", b:GetWidth() .. "x" .. b:GetHeight(), "8x8")
local p, rel, relPoint, x, y = b:GetPoint(1)
H.checkTrue("in the corner", p == "TOPLEFT" and rel == cell and relPoint == "TOPLEFT")
H.check("a pixel in", x .. "," .. y, "1,-1")
H.check("green", b.color._color[2], 0.9)
H.check("dark edge", b.edge._color[1], 0)
H.check("swipe registered", b._durationCooldown, b.cooldown)
H.check("no number", b._durationText, nil)
H.check("no mouse", b._clickEnabled, false)

-- Settings of the position.
RC.Set("r10", "indicatorTopLeftOwn", false)
H.check("anyone's", slot.filter, "HELPFUL")
RC.Set("r10", "indicatorTopLeftTime", "NUMBER")
H.check("number registered", b._durationText, b.time)
H.check("swipe cleared", b._durationCooldown, nil)
RC.Set("r10", "indicatorTopLeftTime", "NONE")
H.check("no time: no number", b._durationText, nil)
H.check("no time: no swipe", b._durationCooldown, nil)
RC.Set("r10", "indicatorTopLeftSize", 12)
H.check("resized", b:GetWidth(), 12)
H.check("number font follows", select(2, b.time:GetFont()), 12)
RC.Set("r10", "indicatorTopLeftColor", { 0.5, 0, 1, 1 })
H.check("recoloured", b.color._color[1], 0.5)
RC.Set("r10", "indicatorTopLeftSpells", "774")
H.check("new spells", slot.candidateFilters.includeSpellIDs[774], true)
H.check("old ones gone", slot.candidateFilters.includeSpellIDs[139], nil)

-- The top centre.
RC.Set("r10", "indicatorTopSpells", "17")
local top = c._slots.indicatorTOP.frame
p, rel, relPoint, x, y = top:GetPoint(1)
H.checkTrue("top centre", p == "TOP" and relPoint == "TOP" and x == 0 and y == -1)
H.check("white", top.color._color[1], 1)

-- Spells removed: disabled, the frame kept.
RC.Set("r10", "indicatorTopLeftSpells", "")
H.check("off: disabled", slot.enabled, false)
H.check("off: still the same frame", c._slots.indicatorTOPLEFT.frame, b)

-- Another size: its own indicators (none).
RC.Set("general", "sizeMode", "40")
H.check("40: top centre off", c._slots.indicatorTOP.enabled, false)
RC.Set("general", "sizeMode", "AUTO")
H.check("10 again: on", c._slots.indicatorTOP.enabled, true)

-- In combat: after combat.
M.combat = true
RC.Set("r10", "indicatorBottomRightSpells", "10060")
H.check("combat: no slot yet", c._slots.indicatorBOTTOMRIGHT, nil)
M.SetCombat(false)
H.checkTrue("after combat: the slot", c._slots.indicatorBOTTOMRIGHT)
H.check("after combat: red", c._slots.indicatorBOTTOMRIGHT.frame.color._color[1], 1)
H.check("nothing blocked", #M.blocked, 0)
H.check("no errors", #M.errors, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run test_raid_indicators.lua`
Expected: `ERROR test_raid_indicators.lua:19: attempt to index local 'Ind' (a nil value)`, `1 passed, 1 failed`

- [ ] **Step 3: Slots with the container's own filters**

In `Raid/CellAuras.lua`:

Replace

```lua
-- * the debuff row: an aura group along the bottom of the health bar
--   with the debuffs the centre icon does not show (its filter negated
--   while it is on: "!" is AuraUtil.AuraFilterNegationPrefix);
-- * more parts register with CellAuras.AddPart (the corner indicators).
-- A slot is made the first time it is switched on: cells that never use
-- one never pay for its frame.
--
```

with

```lua
-- * the debuff row: an aura group along the bottom of the health bar
--   with the debuffs the centre icon does not show (its filter negated
--   while it is on: "!" is AuraUtil.AuraFilterNegationPrefix);
-- * more parts register with CellAuras.AddPart (the corner indicators,
--   Raid/Indicators.lua).
-- A slot is made the first time it is switched on: cells that never use
-- one never pay for its frame.
--
```

Replace

```lua

-- Slots -------------------------------------------------------------------------------

-- A slot of the cell's container, made the first time it is wanted.
-- auras.slots[key] is its frame.
function CellAuras.Slot(frame, container, key, filter, init)
    local auras = frame.raidAuras
    if not auras.slots[key] then
        auras.slots[key] = container:AddAuraSlot(key, filter, { initializeFrame = function(b) init(frame, b) end })
    end
    return auras.slots[key]
end

-- Switches a slot, making it when it is wanted for the first time; one
-- that was never wanted is not made. Returns its frame, or nil.
function CellAuras.SetSlot(frame, container, key, filter, wanted, init)
    local slot = frame.raidAuras.slots[key]
    if not slot and not wanted then return nil end
    slot = CellAuras.Slot(frame, container, key, filter, init)
    container:SetAuraSlotFilterString(key, filter)
    container:SetAuraSlotEnabled(key, wanted == true)
    return slot
end

-- The centre icon and the tint --------------------------------------------------------
```

with

```lua

-- Slots -------------------------------------------------------------------------------

-- Switches a slot of the cell's container, making it when it is wanted
-- for the first time (init(frame, button) gives its frame regions); one
-- that was never wanted is not made. candidateFilters (optional) are the
-- container's own filters for it. Returns its frame, or nil.
-- auras.slots[key] is the frame.
function CellAuras.SetSlot(frame, container, key, filter, wanted, init, candidateFilters)
    local slots = frame.raidAuras.slots
    if not slots[key] and not wanted then return nil end
    if not slots[key] then
        slots[key] = container:AddAuraSlot(key, filter, { candidateFilters = candidateFilters,
            initializeFrame = function(b) init(frame, b) end })
    end
    container:SetAuraSlotFilterString(key, filter)
    if candidateFilters then container:SetAuraSlotCandidateFilters(key, candidateFilters) end
    container:SetAuraSlotEnabled(key, wanted == true)
    return slots[key]
end

-- The centre icon and the tint --------------------------------------------------------
```

- [ ] **Step 4: Create `Raid/Indicators.lua`**

Create `Raid/Indicators.lua`:

```lua
local _, ns = ...

-- Corner indicators of a raid cell: up to five small squares (the four
-- corners and the top centre), each showing while one of its spells is
-- on the unit (a HoT, a shield, a buff), in its own colour, with the time
-- left as a darkening swipe, a number, or not at all.
--
-- Each is an aura slot of the cell's container (Raid/CellAuras.lua) with
-- the container's own spell filter (candidateFilters.includeSpellIDs, a
-- map: Blizzard_AuraContainerUtil.lua looks up includeSpellIDs[spellId]).
-- Matching helpful auras by spell ID on group members is always allowed
-- (AuraContainerUtil.CanApplyIdentityCandidateFilters), in combat too; the
-- client picks the aura and shows the slot's frame, the addon reads
-- nothing. "Own casts only" adds PLAYER to the filter. A position without
-- spells makes no slot; one switched off later is disabled.
--
-- The square, its swipe and its number are regions of the slot's frame,
-- made in initializeFrame. Size, colour and the time display change only
-- out of combat; while auras are secret the frame refuses and they are
-- tried again after combat (Raid/CellAuras.lua).
local Indicators = {}
ns.RaidIndicators = Indicators

local Raid, Cell, Pixel, CellAuras = ns.Raid, ns.RaidCell, ns.Pixel, ns.RaidAuras
local get = Cell.Get

-- From the cell's edge, and the dark edge around the colour.
Indicators.INSET = 1
Indicators.EDGE = 1
Indicators.EDGE_COLOR = { 0, 0, 0, 1 }
-- The way in from each position.
local INWARD = { TOPLEFT = { 1, -1 }, TOPRIGHT = { -1, -1 }, BOTTOMLEFT = { 1, 1 }, BOTTOMRIGHT = { -1, 1 },
    TOP = { 0, -1 } }

-- The settings of a position share this start ("indicatorTopLeft").
function Indicators.Key(ind)
    return "indicator" .. ind.name
end

function Indicators.SlotKey(ind)
    return "indicator" .. ind.point
end

-- A spell list as the container wants it: spell ID -> true; nil for an
-- empty or unreadable list (the position is off).
function Indicators.SpellSet(text)
    local ids = Raid.SpellList(text or "")
    if not ids or #ids == 0 then return nil end
    local set = {}
    for _, id in ipairs(ids) do set[id] = true end
    return set
end

function Indicators.Filter(key)
    return get(key .. "Own") and "HELPFUL|PLAYER" or "HELPFUL"
end

-- Size, place, colour and time display of a position's frame.
local function look(frame, button, ind)
    local key = Indicators.Key(ind)
    local size = Pixel.Snap(get(key .. "Size"), nil, 1)
    local inset, edge = Pixel.Snap(Indicators.INSET), Pixel.Snap(Indicators.EDGE, nil, 1)
    local d = INWARD[ind.point]
    button:SetSize(size, size)
    button:ClearAllPoints()
    button:SetPoint(ind.point, frame, ind.point, d[1] * inset, d[2] * inset)
    button.color:ClearAllPoints()
    button.color:SetPoint("TOPLEFT", button, "TOPLEFT", edge, -edge)
    button.color:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -edge, edge)
    local c = get(key .. "Color")
    button.color:SetVertexColor(c[1], c[2], c[3], c[4])
    local font = ns.Media.Font(ns.Config.Get(frame.key, "fontFace"))
    ns.Texts.SetFont(button.time, font, math.max(6, size), "OUTLINE")
    local time = get(key .. "Time")
    if time == "SWIPE" then
        button:SetDurationCooldown(button.cooldown)
    else
        button:ClearDurationCooldown()
        button.cooldown:Clear()
    end
    if time == "NUMBER" then
        button:SetDurationText(button.time)
    else
        button:ClearDurationText()
        button.time:SetText("")
    end
end

-- The frame's regions: a dark edge, the colour, a swipe that darkens as
-- the time runs out, a number. No mouse: the cell below takes it.
local function init(frame, button, ind)
    pcall(button.SetMouseClickEnabled, button, false)
    pcall(button.SetMouseMotionEnabled, button, false)
    local e = Indicators.EDGE_COLOR
    button.edge = button:CreateTexture(nil, "BACKGROUND")
    button.edge:SetAllPoints(button)
    button.edge:SetColorTexture(e[1], e[2], e[3], e[4])
    button.color = button:CreateTexture(nil, "ARTWORK")
    button.color:SetColorTexture(1, 1, 1, 1)
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.color)
    button.cooldown:SetReverse(true)
    button.cooldown:SetDrawEdge(false)
    button.cooldown:SetHideCountdownNumbers(true)
    button.time = button:CreateFontString(nil, "OVERLAY")
    button.time:SetPoint("CENTER", button, "CENTER", 0, 0)
    look(frame, button, ind)
end

CellAuras.AddPart({
    Apply = function(frame, container)
        local refused = false
        for _, ind in ipairs(Raid.INDICATORS) do
            local key = Indicators.Key(ind)
            local spells = Indicators.SpellSet(get(key .. "Spells"))
            local slot = CellAuras.SetSlot(frame, container, Indicators.SlotKey(ind), Indicators.Filter(key),
                spells ~= nil, function(f, b) init(f, b, ind) end, spells and { includeSpellIDs = spells })
            if slot and not pcall(look, frame, slot, ind) then refused = true end
        end
        return refused
    end,
})
```

- [ ] **Step 5: Load it**

`Raid\Indicators.lua` loads directly after `Raid\CellAuras.lua`.

In `ForeverUnitFrames.toc`:

Replace

```
Raid\Cell.lua
Raid\Cell.xml
Raid\CellAuras.lua
Raid\Header.lua
Raid\TestMode.lua
Core\Blizzard.lua
```

with

```
Raid\Cell.lua
Raid\Cell.xml
Raid\CellAuras.lua
Raid\Indicators.lua
Raid\Header.lua
Raid\TestMode.lua
Core\Blizzard.lua
```

- [ ] **Step 6: Run the tests**

Run: `tests/run raid_indicators` → `39 passed, 0 failed`
Run: `tests/run` → Expected: `19799 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add ForeverUnitFrames.toc Raid/CellAuras.lua Raid/Indicators.lua tests/test_raid_indicators.lua
git commit -m "Raid cell: corner indicators as aura slots by spell ID

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Raid test mode: debuff and corner indicator samples

**Files:**
- Modify: `Raid/CellAuras.lua`, `Raid/Indicators.lua`, `Raid/TestMode.lua`
- Test: `tests/test_raid_testmode_auras.lua`

**Interfaces:**
- Consumes: `ns.Auras.SAMPLES.debuffs`, `ns.AuraButton.Create` / `Style` / `ShowSample` / `Clear`, the pretend cells of R2b (`frame.pretend`, `frame.sample`).
- Produces: optional part hooks `part.BuildSample(frame, samples)` and `part.ShowSample(frame, samples, member, start)` (member nil: hidden); `CellAuras.SAMPLES`, `CellAuras.SampleDebuffs(member)` → centre sample, rest; `CellAuras.Preview`; per pretend cell `frame.raidAuras.samples = { icon, tint, row, indicators }` and `previewing`; `RaidIndicators.SAMPLE_DURATION` (15) / `SAMPLE_LEFT` (12); `RaidTestMode.DEBUFFS` and `member.debuffs`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_testmode_auras.lua`:

```lua
-- Raid test mode's debuffs and corner indicators (Raid/CellAuras.lua,
-- Raid/Indicators.lua): pretend cells have no aura container, so each
-- draws its pretend member's sample with plain frames, following the
-- raid profile like the live cells.
local M = H.M
local ns = H.LoadAddon()
local RC, Cell, Test, CellAuras = ns.RaidConfig, ns.RaidCell, ns.RaidTestMode, ns.RaidAuras
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100, healthMissing = 0, power = 50, powerMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

-- The pretend members' debuffs.
local members = Test.Members(20)
H.check("member 2: magic and a curse", table.concat(members[2].debuffs, ","), "1,2")
H.check("member 12 like member 2", table.concat(members[12].debuffs, ","), "1,2")
H.check("member 1: none", #members[1].debuffs, 0)
local centre, rest = CellAuras.SampleDebuffs(members[9])
H.check("centre: the first with a type", centre.dispel, "Disease")
H.check("the rest", #rest, 2)

ns.TestMode.Set(true)
local f1, f2, f3, f9 = Cell.fakes[1], Cell.fakes[2], Cell.fakes[3], Cell.fakes[9]
local s2 = f2.raidAuras.samples
H.check("no container", f2.raidAuras.container, nil)
H.checkTrue("centre icon shown", s2.icon:IsShown())
H.check("centre: magic", s2.icon.border._color[3], 1.0)
H.check("centre: the 10 profile's size", s2.icon:GetWidth(), 20)
local p, rel = s2.icon:GetPoint(1)
H.checkTrue("centre of the health bar", p == "CENTER" and rel == f2.health)
H.check("member 1: no icon", f1.raidAuras.samples.icon:IsShown(), false)
H.check("tint off by default", s2.tint:IsShown(), false)
H.check("row off by default", s2.row[1]:IsShown(), false)
H.check("no indicators without spells", s2.indicators[1]:IsShown(), false)
local onFakes = 0
for _, container in ipairs(M.auraContainers) do
    if container:GetParent().pretend then onFakes = onFakes + 1 end
end
H.check("no container on any pretend cell", onFakes, 0)

-- Settings show at once.
RC.Set("r10", "dispelTint", true)
H.checkTrue("tint shown", s2.tint:IsShown())
H.check("tint: magic, light", s2.tint.texture._color[4], CellAuras.TINT_ALPHA)
RC.Set("r10", "debuffRow", true)
H.checkTrue("row: the curse", s2.row[1]:IsShown())
H.check("row: only the rest", s2.row[2]:IsShown(), false)
H.check("row: the 10 profile's size", s2.row[1]:GetWidth(), 14)
local s9 = f9.raidAuras.samples
H.check("member 9: two in the row", (s9.row[1]:IsShown() and 1 or 0) + (s9.row[2]:IsShown() and 1 or 0), 2)
RC.Set("r10", "debuffCount", 1)
H.check("count 1: one", s9.row[2]:IsShown(), false)
RC.Set("r10", "dispelIcon", false)
H.check("no centre icon", s2.icon:IsShown(), false)
H.checkTrue("its debuff joins the row", s2.row[1]:IsShown())
H.check("row starts with it", s2.row[1].border._color[3], 1.0)
RC.ResetScope("r10")

-- Indicators with spells: on the living.
RC.Set("r10", "indicatorTopLeftSpells", "139")
local ind = f1.raidAuras.samples.indicators[1]
H.checkTrue("top left shown", ind:IsShown())
H.check("green", ind.color._color[2], 0.9)
H.check("size", ind:GetWidth(), 8)
p, rel = ind:GetPoint(1)
H.checkTrue("in the corner", p == "TOPLEFT" and rel == f1)
H.checkTrue("swipe running", ind.cooldown._cooldown ~= nil)
H.check("dead member: none", f3.raidAuras.samples.indicators[1]:IsShown(), false)
RC.Set("r10", "indicatorTopLeftTime", "NUMBER")
H.check("number", ind.time:GetText(), "12")
H.check("no other position", f1.raidAuras.samples.indicators[2]:IsShown(), false)
RC.ResetScope("r10")
H.check("reset: gone", ind:IsShown(), false)

-- Test mode off: everything hidden.
RC.Set("r10", "debuffRow", true)
ns.TestMode.Set(false)
H.check("off: icon hidden", s2.icon:IsShown(), false)
H.check("off: row hidden", s2.row[1]:IsShown(), false)
H.check("off: sample gone", f2.raidAuras.previewing, nil)
H.check("no errors", #M.errors, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run test_raid_testmode_auras.lua`
Expected: `ERROR test_raid_testmode_auras.lua:16: bad argument #1 to 'concat' (table expected, got nil)`, `0 passed, 1 failed`

- [ ] **Step 3: Samples of the centre icon, the tint and the row**

In `Raid/CellAuras.lua`:

Replace

```lua
-- The group header could hand every cell a container itself
-- (auraContainerTemplate), in combat too, but slots can only be added out
-- of combat anyway, and it would give one to every child it makes, the
-- empty one each header keeps for its size included. Test mode's pretend
-- cells have none (they show samples).
local CellAuras = { name = "RaidAuras" }
ns.RaidAuras = CellAuras
```

with

```lua
-- The group header could hand every cell a container itself
-- (auraContainerTemplate), in combat too, but slots can only be added out
-- of combat anyway, and it would give one to every child it makes, the
-- empty one each header keeps for its size included.
--
-- Test mode's pretend cells have no container: each part draws a sample
-- with plain frames of their own (part.BuildSample, part.ShowSample) from
-- the cell's pretend member (frame.sample, Raid/TestMode.lua): its
-- debuffs (indices into CellAuras.SAMPLES), and whether it is alive (the
-- corner indicators show on the living).
local CellAuras = { name = "RaidAuras" }
ns.RaidAuras = CellAuras
```

Replace

```lua
    "SetAuraGroupEnabled", "SetAuraGroupFilterString", "SetAuraGroupMaxFrameCount", "SetAuraGroupLayout",
    "SetFlowLayoutAxis", "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection" }

-- part.Apply(frame, container, auras) configures the part out of combat;
-- it returns true when a button refused to be restyled.
local parts = {}
function CellAuras.AddPart(part)
    parts[#parts + 1] = part
```

with

```lua
    "SetAuraGroupEnabled", "SetAuraGroupFilterString", "SetAuraGroupMaxFrameCount", "SetAuraGroupLayout",
    "SetFlowLayoutAxis", "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection" }

-- Test mode's debuffs: the unit frames' samples (dispel types Magic,
-- Curse, Poison, Disease, then one without).
CellAuras.SAMPLES = ns.Auras.SAMPLES.debuffs

-- part.Apply(frame, container, auras) configures the part out of combat;
-- it returns true when a button refused to be restyled. Optional, for
-- pretend cells: part.BuildSample(frame, samples) makes plain frames,
-- part.ShowSample(frame, samples, member, start) draws them (member nil:
-- hidden).
local parts = {}
function CellAuras.AddPart(part)
    parts[#parts + 1] = part
```

Replace

```lua
        customDispelColorCurve = AuraButton.DispelCurve(CellAuras.TINT_ALPHA) })
end

CellAuras.AddPart({
    Apply = function(frame, container)
        local filter = CellAuras.FILTERS[get("dispelFilter")]
```

with

```lua
        customDispelColorCurve = AuraButton.DispelCurve(CellAuras.TINT_ALPHA) })
end

-- A pretend member's debuffs: the one the centre icon shows (the first
-- with a dispel type) and the rest.
local function sampleDebuffs(member)
    local centre, rest = nil, {}
    for _, i in ipairs(member and member.debuffs or {}) do
        local sample = CellAuras.SAMPLES[i]
        if not centre and sample.dispel then centre = sample else rest[#rest + 1] = sample end
    end
    return centre, rest
end
CellAuras.SampleDebuffs = sampleDebuffs

CellAuras.AddPart({
    Apply = function(frame, container)
        local filter = CellAuras.FILTERS[get("dispelFilter")]
```

Replace

```lua
        CellAuras.SetSlot(frame, container, "tint", filter, get("dispelTint"), initTint)
        return icon ~= nil and not pcall(AuraButton.StyleManaged, icon, frame.key, dispelSize(), false)
    end,
})

-- The debuff row ----------------------------------------------------------------------
```

with

```lua
        CellAuras.SetSlot(frame, container, "tint", filter, get("dispelTint"), initTint)
        return icon ~= nil and not pcall(AuraButton.StyleManaged, icon, frame.key, dispelSize(), false)
    end,
    BuildSample = function(frame, samples)
        samples.icon = AuraButton.Create(frame, true)
        samples.tint = CreateFrame("Frame", nil, frame)
        samples.tint.texture = samples.tint:CreateTexture(nil, "ARTWORK")
        samples.tint.texture:SetColorTexture(1, 1, 1, 1)
        samples.tint.texture:SetAllPoints(frame.health)
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
})

-- The debuff row ----------------------------------------------------------------------
```

Replace

```lua
        end
        return refused
    end,
})

-- The container -----------------------------------------------------------------------
```

with

```lua
        end
        return refused
    end,
    -- As many plain icons as the row can hold.
    BuildSample = function(frame, samples)
        samples.row = {}
        for i = 1, ns.RaidSettings.Get("debuffCount").max do samples.row[i] = AuraButton.Create(frame, true) end
    end,
    -- The debuffs the centre icon does not show (all, with it off).
    ShowSample = function(frame, samples, member, start)
        local centre, rest = sampleDebuffs(member)
        if centre and not get("dispelIcon") then table.insert(rest, 1, centre) end
        local size, inset = rowSize(), Pixel.Snap(CellAuras.ROW_INSET)
        local step = size + Pixel.Snap(CellAuras.ROW_SPACING)
        local count = get("debuffRow") and get("debuffCount") or 0
        for i, button in ipairs(samples.row) do
            button:SetFrameLevel(frame:GetFrameLevel() + CellAuras.LEVELS)
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", frame.health, "BOTTOMLEFT", inset + (i - 1) * step, inset)
            AuraButton.Style(button, frame.key, size, false)
            if i <= count and rest[i] then AuraButton.ShowSample(button, rest[i], start) else AuraButton.Clear(button) end
        end
    end,
})

-- The container -----------------------------------------------------------------------
```

Replace

```lua

-- Element -------------------------------------------------------------------------------

function CellAuras.Build(frame)
    if frame.key ~= Cell.KEY then return end
    frame.raidAuras = { slots = {} }
end

-- Settings changed: applied now, or after combat.
function CellAuras.Style(frame)
    local auras = frame.raidAuras
    if not (auras and auras.built) then return end
    if InCombatLockdown() then later(frame) else apply(frame) end
end

-- A new unit, or the same raid unit after a roster change (it may be
-- someone else now): the container looks again.
function CellAuras.Update(frame)
```

with

```lua

-- Element -------------------------------------------------------------------------------

-- Pretend cells get the parts' sample frames instead of a container.
function CellAuras.Build(frame)
    if frame.key ~= Cell.KEY then return end
    frame.raidAuras = { slots = {} }
    if not frame.pretend then return end
    local samples = {}
    for _, part in ipairs(parts) do
        if part.BuildSample then part.BuildSample(frame, samples) end
    end
    frame.raidAuras.samples = samples
end

-- The sample of a pretend cell, drawn from its member; nil member hides it.
local function showSamples(frame, member)
    local auras = frame.raidAuras
    auras.sampleStart = member and (auras.sampleStart or GetTime()) or nil
    for _, part in ipairs(parts) do
        if part.ShowSample then part.ShowSample(frame, auras.samples, member, auras.sampleStart) end
    end
end

-- Settings changed: applied now, or after combat; a pretend cell redraws
-- its sample.
function CellAuras.Style(frame)
    local auras = frame.raidAuras
    if auras and auras.samples then
        if auras.previewing then showSamples(frame, frame.sample) end
        return
    end
    if not (auras and auras.built) then return end
    if InCombatLockdown() then later(frame) else apply(frame) end
end

-- Test mode: a pretend cell shows its member's sample.
function CellAuras.Preview(frame, on)
    local auras = frame.raidAuras
    if not (auras and auras.samples) then return end
    auras.previewing = on and frame.sample ~= nil or nil
    showSamples(frame, auras.previewing and frame.sample or nil)
end

-- A new unit, or the same raid unit after a roster change (it may be
-- someone else now): the container looks again.
function CellAuras.Update(frame)
```

- [ ] **Step 4: Samples of the corner indicators**

In `Raid/Indicators.lua`:

Replace

```lua
    return get(key .. "Own") and "HELPFUL|PLAYER" or "HELPFUL"
end

-- Size, place, colour and time display of a position's frame.
local function look(frame, button, ind)
    local key = Indicators.Key(ind)
    local size = Pixel.Snap(get(key .. "Size"), nil, 1)
    local inset, edge = Pixel.Snap(Indicators.INSET), Pixel.Snap(Indicators.EDGE, nil, 1)
```

with

```lua
    return get(key .. "Own") and "HELPFUL|PLAYER" or "HELPFUL"
end

-- Size, place, colour and font of a position's frame (a slot's, or a
-- pretend cell's plain one).
local function place(frame, button, ind)
    local key = Indicators.Key(ind)
    local size = Pixel.Snap(get(key .. "Size"), nil, 1)
    local inset, edge = Pixel.Snap(Indicators.INSET), Pixel.Snap(Indicators.EDGE, nil, 1)
```

Replace

```lua
    button.color:SetVertexColor(c[1], c[2], c[3], c[4])
    local font = ns.Media.Font(ns.Config.Get(frame.key, "fontFace"))
    ns.Texts.SetFont(button.time, font, math.max(6, size), "OUTLINE")
    local time = get(key .. "Time")
    if time == "SWIPE" then
        button:SetDurationCooldown(button.cooldown)
    else
```

with

```lua
    button.color:SetVertexColor(c[1], c[2], c[3], c[4])
    local font = ns.Media.Font(ns.Config.Get(frame.key, "fontFace"))
    ns.Texts.SetFont(button.time, font, math.max(6, size), "OUTLINE")
end

-- The slot's frame: placed, and its time display handed to the client.
local function look(frame, button, ind)
    place(frame, button, ind)
    local time = get(Indicators.Key(ind) .. "Time")
    if time == "SWIPE" then
        button:SetDurationCooldown(button.cooldown)
    else
```

Replace

```lua
end

-- The frame's regions: a dark edge, the colour, a swipe that darkens as
-- the time runs out, a number. No mouse: the cell below takes it.
local function init(frame, button, ind)
    pcall(button.SetMouseClickEnabled, button, false)
    pcall(button.SetMouseMotionEnabled, button, false)
    local e = Indicators.EDGE_COLOR
    button.edge = button:CreateTexture(nil, "BACKGROUND")
    button.edge:SetAllPoints(button)
```

with

```lua
end

-- The frame's regions: a dark edge, the colour, a swipe that darkens as
-- the time runs out, a number.
local function regions(button)
    local e = Indicators.EDGE_COLOR
    button.edge = button:CreateTexture(nil, "BACKGROUND")
    button.edge:SetAllPoints(button)
```

Replace

```lua
    button.cooldown:SetHideCountdownNumbers(true)
    button.time = button:CreateFontString(nil, "OVERLAY")
    button.time:SetPoint("CENTER", button, "CENTER", 0, 0)
    look(frame, button, ind)
end

CellAuras.AddPart({
    Apply = function(frame, container)
        local refused = false
```

with

```lua
    button.cooldown:SetHideCountdownNumbers(true)
    button.time = button:CreateFontString(nil, "OVERLAY")
    button.time:SetPoint("CENTER", button, "CENTER", 0, 0)
end

-- A slot's frame. No mouse: the cell below takes it.
local function init(frame, button, ind)
    pcall(button.SetMouseClickEnabled, button, false)
    pcall(button.SetMouseMotionEnabled, button, false)
    regions(button)
    look(frame, button, ind)
end

-- Test mode: what a sample's time display shows.
Indicators.SAMPLE_DURATION = 15
Indicators.SAMPLE_LEFT = 12

CellAuras.AddPart({
    Apply = function(frame, container)
        local refused = false
```

Replace

```lua
        end
        return refused
    end,
})
```

with

```lua
        end
        return refused
    end,
    BuildSample = function(frame, samples)
        samples.indicators = {}
        for i in ipairs(Raid.INDICATORS) do
            local button = CreateFrame("Frame", nil, frame)
            regions(button)
            button:Hide()
            samples.indicators[i] = button
        end
    end,
    -- Every position with spells, on a living member.
    ShowSample = function(frame, samples, member, start)
        for i, ind in ipairs(Raid.INDICATORS) do
            local button, key = samples.indicators[i], Indicators.Key(ind)
            local shown = member ~= nil and not member.status and Indicators.SpellSet(get(key .. "Spells")) ~= nil
            button:SetFrameLevel(frame:GetFrameLevel() + CellAuras.LEVELS + 1)
            place(frame, button, ind)
            local time = get(key .. "Time")
            local elapsed = Indicators.SAMPLE_DURATION - Indicators.SAMPLE_LEFT
            if shown and time == "SWIPE" then
                button.cooldown:SetCooldown(start - elapsed, Indicators.SAMPLE_DURATION)
            else
                button.cooldown:Clear()
            end
            button.time:SetText(shown and time == "NUMBER" and tostring(Indicators.SAMPLE_LEFT) or "")
            button:SetShown(shown)
        end
    end,
})
```

- [ ] **Step 5: The pretend members' debuffs**

In `Raid/TestMode.lua`:

Replace

```lua
Test.HEALTH = { 1, 0.85, 0.6, 0.35, 0.15, 0.95, 0.7, 0.5 }
-- Member 3 is dead, member 7 offline: both in every size.
Test.STATUS = { [3] = "DEAD", [7] = "OFFLINE" }

local on = false
```

with

```lua
Test.HEALTH = { 1, 0.85, 0.6, 0.35, 0.15, 0.95, 0.7, 0.5 }
-- Member 3 is dead, member 7 offline: both in every size.
Test.STATUS = { [3] = "DEAD", [7] = "OFFLINE" }
-- Debuffs by place in the ten (indices into Raid/CellAuras.lua's
-- samples): a magic one and a curse, a poison, a disease, one without a
-- type and magic again.
Test.DEBUFFS = { [2] = { 1, 2 }, [5] = { 3 }, [9] = { 4, 5, 1 } }

local on = false
```

Replace

```lua
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
-- health, status, role } per member, in raid order.
function Test.Members(size)
    local list = {}
    for i = 1, size do
```

with

```lua
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
-- health, status, role, debuffs } per member, in raid order.
function Test.Members(size)
    local list = {}
    for i = 1, size do
```

Replace

```lua
            subgroup = math.floor((i - 1) / Layout.GROUP_SIZE) + 1, class = s[1], assignedRole = s[2], role = s[2],
            name = type(names) == "table" and names[s[1]] or s[1],
            health = Test.HEALTH[(i - 1) % #Test.HEALTH + 1], status = Test.STATUS[i] or false,
        }
    end
    return list
```

with

```lua
            subgroup = math.floor((i - 1) / Layout.GROUP_SIZE) + 1, class = s[1], assignedRole = s[2], role = s[2],
            name = type(names) == "table" and names[s[1]] or s[1],
            health = Test.HEALTH[(i - 1) % #Test.HEALTH + 1], status = Test.STATUS[i] or false,
            debuffs = Test.DEBUFFS[(i - 1) % #Test.SAMPLES + 1] or {},
        }
    end
    return list
```

- [ ] **Step 6: Run the tests**

Run: `tests/run raid_testmode_auras` → `38 passed, 0 failed`
Run: `tests/run` → Expected: `19837 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add Raid/CellAuras.lua Raid/Indicators.lua Raid/TestMode.lua tests/test_raid_testmode_auras.lua
git commit -m "Raid test mode: debuff and corner indicator samples

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## After the last task

- `./install "<AddOns folder of _classic_beta_>"`, `/reload` in game (R3a adds Lua files only; no new texture). No Lua error at login. UI only: no moving, casting or fighting.
- Test mode (options window), 10-player profile: member 2 shows a magic debuff icon in the centre with a blue border, members 5 and 9 one each. Before R4 settings are changed in the SavedVariables: `/run local p = ForeverUnitFramesDB.raid["<Name>-<Realm>"]; p.r10.dispelTint = true; p.r10.debuffRow = true; p.r10.indicatorTopLeftSpells = "139,6074"`, then `/reload`, test mode on: the tint over member 2's health bar, the curse in its row, a green square in every living member's top left corner with its swipe. Check that icon, row and squares are readable at 80 x 38 (`sizeMode = "40"`).
- In a group or raid when it happens on its own (no fighting): a member with a debuff you can dispel shows it in the centre; your own Renew (or Rejuvenation, …) with its IDs set shows its square. These are the first live uses of `AddAuraSlot` and `includeSpellIDs` on this client: watch for Lua errors.
- Performance at 40 (spec §9) is checked after R3b, with every icon on.
- No release yet: R3b (icons and states) and R4 (options window, locales, wiki) follow; 0.22.0 after the in-game check of the whole part 1.
