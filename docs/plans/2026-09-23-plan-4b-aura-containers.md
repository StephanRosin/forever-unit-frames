# Forever Unit Frames — Plan 4b: auras through Blizzard's CustomAuraContainerTemplate

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Live buffs and debuffs on every unit frame keep updating in combat, by letting the client draw them through Blizzard's `CustomAuraContainerTemplate` instead of reading them ourselves; the existing aura settings map onto the containers, test mode keeps our own sample icons, and the addon's own read path stays as the fallback for a client that cannot make a container.

**Architecture:** One new file, `Elements/AuraContainers.lua`. Per unit frame and settings group (buffs, debuffs) it makes one aura container (`CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")`) with two container groups, `own` (`<filter>|PLAYER`, own size) and `other` (`<filter>|!PLAYER` on a new line, or the whole filter when yours are not put first). Pure functions map the settings onto the container's flow layout (`AuraContainers.Flow`) and group options (`AuraContainers.Part`); `initializeFrame` gives every button our regions and look (`AuraButton.Decorate` / `StyleManaged`) and registers the regions the client fills (`SetIcon`, `SetDurationCooldown`, `SetApplicationCount`, `AddDispelTypeTexture`). Containers are made on a frame's first live update and configured out of combat only; `Auras.Update` hands live frames to them (`SetUnit` / `UpdateAllAuras`) and keeps `GetUnitAuras` reads only for frames without containers. `Elements/Auras.lua` holders and `Elements/AuraButton.lua` stay for test-mode samples and the fallback.

**Tech Stack:** Lua 5.1, WoW: Forever API (Interface 16001, build 1.60.1.69977), offline tests with `lua5.1` + `tests/mock.lua` (`tests/run`).

Plan order: … → 4 Auras (done) → **4b Aura containers (this plan)** → 5 Release.

Base: branch `plan-3-frames` at `38f53e2` ("Keep Blizzard's cast bar unless asked to hide it"); `tests/run` there: `4474 passed, 0 failed`. Every task below was replayed in order on a scratch worktree of that commit; the totals under "Expected" are what `tests/run` printed there. Work that lands on the branch first changes the totals and may shift diff context; the code does not depend on it.

## Global Constraints

- Everything in English: UI strings, file names, identifiers, comments. User-facing strings only through `ns.L` (`Locales/enUS.lua`).
- Target client: WoW: Forever, `## Interface: 16001`, build 1.60.1.69977. Client facts only from the `forever` branch of the UI source (`git -C <wow-ui-source mirror> show FETCH_HEAD:<path>`); the facts used are in the table below, the rest under "Not verifiable offline".
- No secret-value maths anywhere in our code: nothing in this plan reads an aura field. The containers read auras in secure code; the addon only passes plain settings in.
- No `hooksecurefunc` on any mixin (Blizzard's or ours), no secure snippets (`initialConfigFunction`, `WrapScript`, `_onstate-*`, `RunAttribute`), no `SetScript` on a container button (its scripts are Blizzard's; `UntrustedScriptExecution`).
- Container buttons are touched only inside `initializeFrame` and, out of combat, by the guarded restyle (`pcall`); never in combat. Other frames never anchor to a container except the other group's container (which has the layout aspect itself).
- Setting codes are permanent: this plan adds **no** setting and no code. Existing codes and enum orders stay as they are.
- Aura settings keep their meaning; what the container cannot do is listed under "What cannot be mapped" and nowhere silently approximated beyond that list.
- The mock stays faithful: the container stand-in checks at least what the source checks (it may be stricter, never more permissive), and the secret proxy is not loosened.
- A font string gets a font before its first `SetText` (the client's `SetApplicationCount` writes the count at once; the mock asserts it).
- Public repository: no local paths, host names, character names or anything about the author's machine in files or commit messages.
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp`
- Do not push. Every code task ends with `tests/run` green and one commit (`git add` only the files the task lists).

## Client facts this plan relies on (build 69977, `forever` branch)

Paths below `Interface/AddOns/`; `AC/` = `Blizzard_AuraContainer/`, `Doc/` = `Blizzard_APIDocumentationGenerated/`.

| Fact | Source |
|---|---|
| The container's Lua runs in the secure environment; its XML (intrinsic `AuraContainer`, `CustomAuraContainerTemplate`, `CustomAuraButtonTemplate`) is loaded into the global environment "to allow intrinsics and templates to be instantiated by external code without making their created objects implicitly forbidden" | `AC/Blizzard_AuraContainer.toc:6-17, 29, 31` |
| `AuraContainer` and `CustomAuraContainerTemplate` carry `allowUntaintedCreation="true"` and a public inbound mixin (`targetPartition="public"`) | `AC/Blizzard_AuraContainer.xml:4-13`, `AC/Blizzard_CustomAuraContainer.xml:4-8` |
| `SetUnit(unitToken)` asserts a string, re-registers `UNIT_AURA` for that token and refreshes on change; default unit `"none"`; `GetUnit()`; `UpdateAllAuras()` is exposed "to allow external events to trigger refreshes where needed (e.g. target changes)" | `AC/Blizzard_AuraContainer.lua:40-54`, `AC/Blizzard_AuraContainer.xml:9`; Blizzard's target frame does exactly that: `Blizzard_UnitFrame/Mainline/TargetFrame.lua:586-587` |
| Unit events are registered only while the container is visible and enabled; `OnShow` re-registers and refreshes; updates run in `OnUpdate` with `RunWhenVisibleOnce` | `AC/Blizzard_AuraContainer.lua:71-74, 157-159`; `AC/Blizzard_ManagedAuraContainer.lua:102-105` |
| `AddAuraGroup(groupKey, filterString, options)`: non-empty unique key, valid filter string, options merged over `CustomAuraContainerGroupDefaultOptions` (`maxFrameCount` = ∞, `templateNames`, `initializeFrame`, `candidateFilters`, `sortMethod` = `Default`, `sortDirection` = `Normal`, `layout`); makes one batch of buttons at once; after the first group the container gets `ForbiddenAspect.UntrustedLayoutScriptExecution` | `AC/Blizzard_CustomAuraContainer.lua:286-328`; defaults `AC/Blizzard_AuraContainerShared.lua:127-150` |
| Group layout keys: `elementSpacing`, `lineSpacing`, `groupSpacing`, `groupLineSpacing` (numbers), `forceNewLine` (bool), `elementWidth`, `elementHeight` (≥ 0), `layoutIndex`; defaults 0 / false / nil | `AC/Blizzard_CustomAuraContainer.lua:143-181`; `AC/Blizzard_AuraContainerShared.lua:155-165` |
| Reconfiguration without a new container: `SetAuraGroupEnabled`, `SetAuraGroupFilterString`, `SetAuraGroupMaxFrameCount`, `SetAuraGroupCandidateFilters`, `SetAuraGroupSortMethod`, `SetAuraGroupLayout` (replaces the whole layout, merged with the defaults); none checks combat. Groups cannot be removed (`ClearAuraGroups` "intentionally not exposed") | `AC/Blizzard_CustomAuraContainer.lua:359-415, 641-653` |
| Group order in the layout: `layoutIndex`, else registration order; disabled groups take no part; a disabled group's auras are cleared | `AC/Blizzard_CustomAuraContainer.lua:675-754`; `AC/Blizzard_AuraContainerGroups.lua:77-90` |
| `maxFrameCount` caps each group on its own | `AC/Blizzard_AuraContainerGroups.lua:239-255` |
| Container flow: `SetFlowLayoutAxis`, `SetFlowLayoutAnchorPoint`, `SetFlowLayoutGrowthDirection(h, v)`, `SetFlowLayoutPadding`, `SetFlowLayoutMaximumLineSize(n or nil = ∞)`; defaults Horizontal, `TOPLEFT`, Right, Down, no padding, ∞ | `AC/Blizzard_AuraContainerFlowLayout.lua:7-67`; `AC/Blizzard_AuraContainerShared.lua:114-125` |
| `AnchorUtil.FlowLayoutAxis` (Horizontal 0, Vertical 1), `AnchorUtil.FlowDirection` (Left -1, Right 1, Up 1, Down -1). The flow anchors every element at `anchorPoint` of the container with offsets along the growth directions; a line wraps when `used + element > maximumLineSize` (`used` includes the spacing after each element), so n icons fit when `n*size + (n-1)*spacing <= maximumLineSize`; `forceNewLine` starts a non-empty group on a new line after `groupLineSpacing`; empty groups add nothing | `Blizzard_SharedXMLBase/AnchorUtil.lua:465-477, 637-747` |
| Element size in the layout = `elementWidth/Height` if set, else the button's own size; the button itself is not resized. The container sizes itself to its content | `AC/Blizzard_CustomAuraContainer.lua:789-801` |
| Buttons: `CustomAuraButtonTemplate` (always first, plus `templateNames`), `initializeFrame(button)` via `securecallfunction`, **then** access restrictions, then a display update; more batches are made when a group runs out (possibly in combat). `FrameCreationBatchSize` 10, `AccessRestrictionFlags = DenyTaintedAccessWhenAurasAreSecret` | `AC/Blizzard_AuraContainerFrameProviders.lua:75-110`; `AC/Blizzard_AuraContainerShared.lua:101-109` |
| Button regions: `SetIcon(Texture)`, `SetDurationCooldown(Cooldown)`, `SetApplicationCount(FontString, options)` (writes the count at once), `AddDispelTypeTexture(Texture, options)`; each object must be of that type and a descendant of the button | `AC/Blizzard_CustomAuraButton.lua:87-125, 159-168, 243-250, 440-452`; `AC/Blizzard_AuraContainerUtil.lua:318-358` |
| The swipe is set with `SetCooldownFromDurationObject` (so the cooldown's own countdown numbers show the time left) | `AC/Blizzard_CustomAuraButton.lua:598-605` |
| Dispel texture options: `showWithoutDispelType`, `style` (`PreserveAsset` = 3 keeps our texture and applies `AuraUtil.SetAuraBorderColor`), `customDispelColorCurve` (then `C_UnitAuras.GetAuraDispelTypeColor(unit, id, curve)` sets the vertex colour) | `Doc/AuraContainerUtilDocumentation.lua:289-303`; `Doc/AuraContainerSharedDocumentation.lua:18-29`; `AC/Blizzard_CustomAuraButton.lua:519-555` |
| Tooltips: the button's own `OnEnter` shows the container's forbidden `AuraButtonTooltip`; `SetTooltipAnchorPoint(point, x, y)` with `ANCHOR_*` names; the button has `UntrustedScriptExecution`, `UntrustedLayoutScriptExecution`, `ChangeParent` … aspects | `AC/Blizzard_AuraButton.lua:36-60, 80-88, 185-200`; `AC/Blizzard_AuraButton.xml:16-24`; `AC/Mainline/Blizzard_AuraButtonTooltip.xml` |
| Frames an addon anchors to a container with groups must have the layout aspect: `DisableUntrustedLayoutScriptsTemplate`; the aspect propagates to children and "anything anchored to" the object | `AC/Blizzard_CustomAuraContainer.lua:317-324`; `Blizzard_SharedXMLBase/ForbiddenAspectTemplates.xml:4-22`; `Doc/ForbiddenAspectConstantsDocumentation.lua:16` |
| Sorting `Default` = `AuraUtil.DefaultAuraCompare`: yours first, then priority, then can-apply, then instance ID | `AC/Blizzard_AuraContainerUtil.lua:182-207`; `Blizzard_FrameXMLUtil/AuraUtil.lua:140-156` |
| Filter tokens (`HELPFUL`, `HARMFUL`, `PLAYER`, `RAID`, …) with `!` negation, validated by `AuraUtil.IsValidFilterString` | `Blizzard_FrameXMLUtil/AuraUtil.lua:270-320` |
| Full refresh events (`PLAYER_REGEN_*`, …) are registered only with the `ProcessAura` policy (not used here) | `AC/Blizzard_CustomAuraContainer.lua:589-620` |
| Verified in game (user, build 69977): a container made out of combat with `SetUnit("target")` and a `HARMFUL` group updated its icons live in combat without Lua errors | in-game test before this plan |

## Design decisions

- **Which frames.** Every frame with aura groups: player, target, target of target, pet, focus and every party button (party exactly like target). The source puts no restriction on the unit token (`SetUnit` only asserts a string). Units without `UNIT_AURA` of their own (target of target) are refreshed with `UpdateAllAuras()` from the frame's existing timer (at most every `Auras.POLL_SECONDS` = 0.5 s) and on `PLAYER_TARGET_CHANGED` / `UNIT_TARGET`.
- **One container per frame and settings group**, parented to the unit frame at level + `Auras.LEVELS`, anchored exactly like the holder (`Point` → region `FramePoint` + X/Y); `OTHER` hangs it from the other group's container (both have the layout aspect, so this is allowed). Both are cleared before either is anchored, so switching which group hangs from which never makes a loop.
- **Two container groups per container**, made once and reconfigured, never removed: `own` = `ownFilter` (`<filter>|PLAYER`, or the filter itself with "only mine"), `layout.elementWidth/Height = OwnSize`; `other` = `otherFilter` (`<filter>|!PLAYER`) with `forceNewLine = true` and `groupLineSpacing = Spacing`. Yours not first: `own` disabled, `other` takes the whole filter without a new line. Only mine + yours first: `other` disabled.
- **Flow.** Growth Right/Left → horizontal axis, Up/Down → vertical; the row direction (fallback as `Layout.AuraRowDirection`) is the cross direction; the start corner is `Layout.AuraCorner` (the same corner the holders use). Per row: a fixed N → `maximumLineSize = N*Size + (N-1)*Spacing`; Auto (0) → the frame's width (height when growing up/down), which gives exactly `Layout.AuraPerRow`'s count.
- **Button look** is made in `initializeFrame` with the same regions as our own icons (`AuraButton.Decorate`): white border texture (buffs: plain border colour; debuffs: registered as dispel texture, `PreserveAsset` + our dispel colour curve, `showWithoutDispelType` for the NONE colour), cropped icon, `CooldownFrameTemplate` swipe with countdown numbers (`ShowTime`), stack count on a cover above the swipe (plain outline even when the font setting is Soft), tooltip anchor bottom right, clicks through to the unit button (`SetMouseClickEnabled(false)`, guarded).
- **Reconfiguration** only out of combat: settings changes in combat (party buttons restyle in combat) are queued with `ns.AfterCombat("auraContainers", …)`. Out of combat but with auras secret (an instance), the buttons refuse restyling: the layout is applied anyway and the buttons are restyled at the next `PLAYER_REGEN_ENABLED`.
- **Making containers**: on a frame's first live `Auras.Update` (never for the pretend party of test mode); in combat the frame waits until combat ends (shows no auras until then). If the client refuses (an error inside `pcall`), the half-made containers are hidden, the error is reported once, and that frame uses the read path.
- **Capability check** (Task 1): `AuraContainers.Supported()` makes one hidden container on first use and checks every inbound call the addon uses; `false` keeps the whole addon on the read path. `/fuf status` names the path.
- **Test mode**: containers hidden, our samples in the holders (containers show only real auras); test mode off shows the enabled containers again.
- **Read path kept** for clients or frames without containers (`M.auraContainerMissing` in the tests) — `query`, `readGroup`, `applyEvent` stay untouched and are bypassed for container frames; its after-combat re-read skips container frames.

### Settings → container

| Setting | Container |
|---|---|
| Enabled | container shown/hidden; both groups enabled/disabled |
| Only mine | `own`/`other` filters (`|PLAYER`); `other` off when yours are first |
| Dispellable (debuffs) | `|RAID` in the filters |
| Remaining time | `cooldown:SetHideCountdownNumbers(not ShowTime)` on our swipe |
| Anchor FRAME / HEALTH / POWER / CASTBAR / OTHER, Point, FramePoint, X, Y | `container:SetPoint(...)` like the holder; OTHER = the other container |
| Growth, Row growth | `SetFlowLayoutAxis`, `SetFlowLayoutGrowthDirection`, `SetFlowLayoutAnchorPoint(Layout.AuraCorner)` |
| Size, Own size | button size in `initializeFrame` / restyle + `layout.elementWidth/Height` per group |
| Spacing | `elementSpacing`, `lineSpacing`, `groupLineSpacing` |
| Per row (N or Auto) | `SetFlowLayoutMaximumLineSize` |
| Max | `maxFrameCount` per group |
| Yours first + own size | groups `own` then `other` (`forceNewLine`) |
| Dispel colours | dispel texture with our colour curve |

### What cannot be mapped (and the fallback)

1. **Max with "yours first"**: `maxFrameCount` caps each group, and our code cannot know how many of yours there are, so up to `Max` of yours plus `Max` others can show (2 × Max). Without "yours first" Max is exact.
2. **Fixed "per row" with a bigger own size**: the container wraps all groups at one row length (N normal icons); rows of your bigger icons hold as many as fit that length (fewer than N). Auto is exact for both sizes.
3. **Changes in combat** apply when combat ends (sizes, fonts, layout, filters); an instance with secret auras out of combat defers only the button restyle (layout still applies at once).
4. **A party member who joins in combat** gets containers when combat ends (no auras on that button until then).
5. **Stack count with the Soft outline**: plain outline (the client writes the count; our soft copies could not follow).
6. **Tooltips** are Blizzard's aura tooltip (`AuraButtonTooltip`, bottom right of the icon), not `GameTooltip`; tooltip style is Blizzard's.
7. **Sorting** is Blizzard's `DefaultAuraCompare` (yours, priority, can-apply, instance ID), not `UnitAuraSortRule.Default`.
8. **Debuff border** gets `AuraUtil.SetAuraBorderColor` first, then our curve's colour (same colours as today).
9. **Test mode** uses our own icons (samples), not the containers.
10. **Target of target** refreshes at most every 0.5 s and on target changes (no aura events for that token), as before.
11. **Fallback**: a client (or a frame) without containers keeps the current read path, which freezes in combat as before.

## File structure

- Create `Elements/AuraContainers.lua` — capability check, settings → container mapping, button setup, per-frame containers, live refresh. Loaded after `Elements/AuraButton.lua`, before `Elements/Auras.lua`.
- Modify `Elements/AuraButton.lua` — split `Create` into `Decorate` + `Create`; split `Style` into shared `shape` + `Style` / `StyleManaged`; export `DispelCurve`.
- Modify `Elements/Auras.lua` — keep the raw per-row setting and frame length; `AnchorRegion(frame, key, live)`; `Style` passes on to containers; `Update` routes live frames to containers.
- Modify `tests/mock.lua` — `AuraContainer` stand-in with buttons, access restriction and layout aspect; `AnchorUtil`, `AuraContainerSort*`, `Enum.CustomAuraButtonDispelTypeTextureStyle`.
- Modify `ForeverUnitFrames.toc`, `Locales/enUS.lua`, `Core/Commands.lua` (status line).
- Tests: `tests/test_aura_container_check.lua`, `test_aura_container_mock.lua`, `test_aura_container_map.lua`, `test_aura_container_button.lua`, `test_aura_container_frames.lua`, `test_aura_container_live.lua`; `test_aura_own.lua`, `test_aura_read.lua`, `test_aura_updates.lua` opt into the read path.

---
### Task 1: Runtime capability check, container stand-in in the mock

**Files:**
- Create: `Elements/AuraContainers.lua`
- Create: `tests/test_aura_container_check.lua`, `tests/test_aura_container_mock.lua`
- Modify: `tests/mock.lua`, `ForeverUnitFrames.toc`, `Locales/enUS.lua`, `Core/Commands.lua`

**Interfaces:**
- Produces: `ns.AuraContainers` with `TEMPLATE`, `METHODS`, `Supported() -> bool` (cached for the session). Mock: `M.auraContainers` (every container made), `M.auraContainerMissing` (CreateFrame refuses the type), `M.aurasSecret` (buttons refuse out of combat), `M.AURA_BATCH` (10), `M.GrowAuraGroup(container, key)`, `M.NewAuraContainer(w, template)`, `M.AurasSecret()`, `M.IsAuraRestricted(obj)`, `M.HasLayoutAspect(obj)`; container records `_unit`, `_updates`, `_groups[key] = { filter, max, enabled, layout, frames }`, `_groupOrder`, `_flow = { axis, anchor, horizontal, vertical, padding, lineSize }`; button records `_icon`, `_durationCooldown`, `_applicationCount`, `_dispelTextures`, `_tooltipAnchor`.

- [ ] **Step 1: Write the failing tests**

`tests/test_aura_container_check.lua`:

```lua
-- Can this client make aura containers for addons? Asked once, with one
-- hidden container; a client that refuses keeps the addon's own reads.
local M = H.M

local ns = H.LoadAddon()
local AC = ns.AuraContainers
H.check("nothing asked at load", #M.auraContainers, 0)
H.check("supported", AC.Supported(), true)
H.check("one test container", #M.auraContainers, 1)
local probe = M.auraContainers[1]
H.check("test container template", probe._template, "CustomAuraContainerTemplate")
H.check("test container on UIParent", probe:GetParent(), UIParent)
H.check("test container hidden", probe:IsShown(), false)
H.check("test container unused", #probe._groupOrder, 0)
H.check("asked once", AC.Supported(), true)
H.check("still one test container", #M.auraContainers, 1)

-- A client without the frame type: CreateFrame raises, the answer is no.
ns = H.LoadAddon()
M.auraContainerMissing = true
H.check("missing type", ns.AuraContainers.Supported(), false)
H.check("no container made", #M.auraContainers, 0)
M.auraContainerMissing = false
H.check("answer kept for the session", ns.AuraContainers.Supported(), false)

-- A container without one of the calls the addon makes is not used.
ns = H.LoadAddon()
local real = M.NewAuraContainer
M.NewAuraContainer = function(w, template)
    real(w, template)
    w.SetAuraGroupLayout = nil
end
H.check("incomplete container", ns.AuraContainers.Supported(), false)
M.NewAuraContainer = real

-- /fuf status names the path.
local function status(missing)
    ns = H.LoadAddon()
    M.auraContainerMissing = missing
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    SlashCmdList.FOREVERUNITFRAMES("status")
    return table.concat(M.chat, "\n")
end
H.checkTrue("status: containers", status(false):find("Auras: drawn by the client", 1, true))
H.checkTrue("status: read path", status(true):find("Auras: read by the addon", 1, true))
```

`tests/test_aura_container_mock.lua`:

```lua
-- The mock's stand-in for CustomAuraContainerTemplate checks what the
-- source checks, and records what the addon tells it.
local M = H.M
H.LoadAddon()

local c = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
H.checkError("other template", function() CreateFrame("AuraContainer", nil, UIParent, "SomeTemplate") end)
H.check("unit starts at none", c:GetUnit(), "none")
H.checkError("unit must be a string", function() c:SetUnit(nil) end)
local updates = c._updates
c:SetUnit("target")
H.check("unit", c:GetUnit(), "target")
H.check("a new unit refreshes", c._updates, updates + 1)
c:SetUnit("target")
H.check("the same unit does not", c._updates, updates + 1)
c:UpdateAllAuras()
H.check("UpdateAllAuras counted", c._updates, updates + 2)
H.checkError("unknown method", function() c:SetAuraGroupSortMethod("x", 0, 0) end)

-- Groups: key, filter and options are checked.
local inits = {}
local function init(button) inits[#inits + 1] = button end
H.checkError("empty key", function() c:AddAuraGroup("", "HELPFUL") end)
H.checkError("bad filter token", function() c:AddAuraGroup("a", "HELPFUL|MINE") end)
H.checkError("bare negation", function() c:AddAuraGroup("a", "HELPFUL|!") end)
H.checkError("unknown option", function() c:AddAuraGroup("a", "HELPFUL", { size = 3 }) end)
H.checkError("unknown layout key", function() c:AddAuraGroup("a", "HELPFUL", { layout = { width = 3 } }) end)
H.checkError("negative size", function() c:AddAuraGroup("a", "HELPFUL", { layout = { elementWidth = -1 } }) end)
H.checkError("fractional maximum", function() c:AddAuraGroup("a", "HELPFUL", { maxFrameCount = 1.5 }) end)
H.checkError("bad sort", function() c:AddAuraGroup("a", "HELPFUL", { sortMethod = 99 }) end)
H.check("nothing added by the refusals", #c._groupOrder, 0)
c:AddAuraGroup("own", "HARMFUL|RAID|PLAYER", { maxFrameCount = 4, initializeFrame = init,
    layout = { elementWidth = 26, elementHeight = 26, elementSpacing = 2 } })
c:AddAuraGroup("other", "HARMFUL|!PLAYER")
H.checkError("same key twice", function() c:AddAuraGroup("own", "HARMFUL") end)
H.check("order kept", table.concat(c._groupOrder, ","), "own,other")
H.check("filter", c._groups.own.filter, "HARMFUL|RAID|PLAYER")
H.check("maximum", c._groups.own.max, 4)
H.check("no maximum: infinite", c._groups.other.max, math.huge)
H.check("layout width", c._groups.own.layout.elementWidth, 26)
H.check("layout defaults merged", c._groups.own.layout.lineSpacing, 0)
H.check("new line off by default", c._groups.other.layout.forceNewLine, false)
H.check("one batch made", c:GetAuraGroupFrameCount("own"), M.AURA_BATCH)
H.check("each handed to initializeFrame", #inits, M.AURA_BATCH)
H.check("in order", inits[1], c:GetAuraGroupFrame("own", 1))
H.check("buttons are aura buttons", inits[1]._template, "CustomAuraButtonTemplate")
H.check("buttons belong to the container", inits[1]:GetParent(), c)

-- Changes later: the whole layout is replaced; unknown groups raise.
c:SetAuraGroupLayout("own", { elementSpacing = 4 })
H.check("layout replaced", c._groups.own.layout.elementWidth, nil)
H.check("new spacing", c._groups.own.layout.elementSpacing, 4)
c:SetAuraGroupEnabled("other", false)
H.check("group off", c._groups.other.enabled, false)
H.checkError("enabled must be a boolean", function() c:SetAuraGroupEnabled("other", nil) end)
c:SetAuraGroupFilterString("other", "HARMFUL")
H.check("filter changed", c._groups.other.filter, "HARMFUL")
c:SetAuraGroupMaxFrameCount("other", 6)
H.check("maximum changed", c._groups.other.max, 6)
H.checkError("unknown group", function() c:SetAuraGroupLayout("nope", {}) end)
H.checkError("no RemoveAuraGroup", function() c:RemoveAuraGroup("own") end)

-- Flow layout: enum values are checked.
c:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Vertical)
c:SetFlowLayoutAnchorPoint("BOTTOMRIGHT")
c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Up)
c:SetFlowLayoutMaximumLineSize(100)
H.check("axis", c._flow.axis, 1)
H.check("anchor", c._flow.anchor, "BOTTOMRIGHT")
H.check("growth", c._flow.horizontal .. "," .. c._flow.vertical, "-1,1")
H.check("line size", c._flow.lineSize, 100)
c:SetFlowLayoutMaximumLineSize(nil)
H.check("no line size: infinite", c._flow.lineSize, math.huge)
H.checkError("bad axis", function() c:SetFlowLayoutAxis(5) end)
H.checkError("bad direction", function() c:SetFlowLayoutGrowthDirection(0, 1) end)

-- Buttons: regions must be of the right type and below the button.
local b = c:GetAuraGroupFrame("other", 1)
local icon = b:CreateTexture()
local cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
local count = b:CreateFontString()
H.checkError("icon from elsewhere", function() b:SetIcon(UIParent:CreateTexture()) end)
H.checkError("icon of the wrong type", function() b:SetIcon(count) end)
H.checkError("count without a font", function() b:SetApplicationCount(count) end)
count:SetFont("font", 10, "")
b:SetIcon(icon)
b:SetDurationCooldown(cooldown)
b:SetApplicationCount(count)
H.check("icon registered", b._icon, icon)
H.check("count written at once", count:GetText(), "")
b:AddDispelTypeTexture(icon, { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset })
H.checkError("added twice", function() b:AddDispelTypeTexture(icon) end)
H.checkError("bad style", function() b:AddDispelTypeTexture(b:CreateTexture(), { style = 9 }) end)
H.checkError("bad tooltip anchor", function() b:SetTooltipAnchorPoint("BOTTOMRIGHT") end)
b:SetTooltipAnchorPoint("ANCHOR_BOTTOMRIGHT")
H.check("tooltip anchor", b._tooltipAnchor[1], "ANCHOR_BOTTOMRIGHT")
H.checkError("no addon scripts", function() b:SetScript("OnEnter", function() end) end)

-- While auras are secret (combat) the button and its regions refuse us.
local grown = c:GetAuraGroupFrameCount("other")
M.combat = true
H.checkError("button in combat", function() b:SetSize(10, 10) end)
H.checkError("region in combat", function() count:SetFont("font", 12, "") end)
H.checkError("no-op method in combat", function() icon:SetDesaturated(true) end)
-- New buttons are handed to initializeFrame before they are restricted.
local sizedInCombat
c:AddAuraGroup("late", "HELPFUL", { initializeFrame = function(button) button:SetSize(9, 9); sizedInCombat = true end })
H.checkTrue("initializeFrame may style in combat", sizedInCombat)
M.GrowAuraGroup(c, "other")
H.check("grown by a batch", c:GetAuraGroupFrameCount("other"), grown + M.AURA_BATCH)
M.combat = false
b:SetSize(10, 10)
H.check("out of combat again", b:GetWidth(), 10)
M.aurasSecret = true
H.checkError("secret out of combat", function() b:SetSize(11, 11) end)
M.aurasSecret = false

-- Errors in initializeFrame are reported, not raised.
local errors = #M.errors
c:AddAuraGroup("broken", "HELPFUL", { initializeFrame = function() error("oops") end })
H.check("reported once per button", #M.errors - errors, M.AURA_BATCH)

-- Anchoring to a container with groups needs the layout aspect.
local plain = CreateFrame("Frame", nil, UIParent)
H.checkError("plain frame on a container", function() plain:SetPoint("TOP", c, "BOTTOM") end)
local opted = CreateFrame("Frame", nil, UIParent, "DisableUntrustedLayoutScriptsTemplate")
opted:SetPoint("TOP", c, "BOTTOM")
H.check("opted-in frame", select(2, opted:GetPoint(1)), c)
local other = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
H.checkError("container without groups", function() other:SetPoint("TOP", c, "BOTTOM") end)
other:AddAuraGroup("x", "HELPFUL")
other:SetPoint("TOP", c, "BOTTOM")
H.check("container with groups", select(2, other:GetPoint(1)), c)
local empty = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
plain:SetPoint("TOP", empty, "BOTTOM")
H.check("container without groups takes anything", select(2, plain:GetPoint(1)), empty)
-- Children carry their parent's aspect.
local child = CreateFrame("Frame", nil, c)
child:SetPoint("TOP", c, "TOP")
H.check("child of the container", select(2, child:GetPoint(1)), c)
local region = b:CreateTexture()
region:SetPoint("TOPLEFT", b, "TOPLEFT")
H.check("region on its button", select(2, region:GetPoint(1)), b)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`
Expected: `ERROR test_aura_container_check.lua:7: attempt to get length of field 'auraContainers' (a nil value)` and FAIL/ERROR lines under `test_aura_container_mock.lua`.

- [ ] **Step 3: The container stand-in in `tests/mock.lua`**

(a) Replace

```lua
widget.__index = function(t, k)
    -- Unknown CamelCase keys are widget methods that do nothing; anything
    -- else is addon data and must be nil, as in the game.
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local f = function() end
    rawset(t, k, f)
    return f
end
```

with

```lua
widget.__index = function(t, k)
    -- Unknown CamelCase keys are widget methods that do nothing; anything
    -- else is addon data and must be nil, as in the game. Strict objects
    -- (Blizzard aura containers and their buttons) have only the methods
    -- the mock gives them. Under an aura button, even a no-op method
    -- refuses while auras are secret.
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    if rawget(t, "_strict") then error("mock: " .. tostring(rawget(t, "_kind")) .. " has no method " .. k, 2) end
    local f = function(self)
        if M.AurasSecret() and M.IsAuraRestricted(self) then error("aura button: tainted access while auras are secret", 2) end
    end
    rawset(t, k, f)
    return f
end
```

(b) Insert this block directly before `local function newWidget(kind, name, parent)`:

```lua
-- Blizzard_AuraContainer's CustomAuraContainerTemplate: the inbound calls
-- an addon can make (Blizzard_AuraContainer.lua, Blizzard_CustomAuraContainer.lua,
-- Blizzard_AuraContainerFlowLayout.lua, Blizzard_CustomAuraButton.lua,
-- Blizzard_AuraButton.lua), with the source's argument checks. It shows no
-- auras: it records what it is told, and tests read the records
-- (_unit, _updates, _groups[key], _flow). Stricter than the client where
-- the client would silently accept a mistake: unknown option keys and
-- unknown methods raise.
-- Buttons: AddAuraGroup makes one batch (FrameCreationBatchSize) with
-- CustomAuraButtonTemplate and hands each to initializeFrame; after that
-- a button and everything under it refuse tainted access while auras are
-- secret (DenyTaintedAccessWhenAurasAreSecret; in the mock: in combat, or
-- while M.aurasSecret is set, as in an instance out of combat).
-- Once it has a group, only frames with the UntrustedLayoutScriptExecution
-- aspect may anchor to the container.
M.AURA_BATCH = 10
local AURA_FILTERS = { HELPFUL = true, HARMFUL = true, PLAYER = true, RAID = true, CANCELABLE = true,
    INCLUDE_NAME_PLATE_ONLY = true, MAW = true, EXTERNAL_DEFENSIVE = true, CROWD_CONTROL = true,
    RAID_IN_COMBAT = true, RAID_PLAYER_DISPELLABLE = true, BIG_DEFENSIVE = true, IMPORTANT = true,
    DISPELLABLE = true }
local LAYOUT_KEYS = { elementSpacing = "number", lineSpacing = "number", groupSpacing = "number",
    groupLineSpacing = "number", forceNewLine = "boolean", elementWidth = "size", elementHeight = "size",
    layoutIndex = "number" }
local LAYOUT_DEFAULTS = { elementSpacing = 0, lineSpacing = 0, groupSpacing = 0, groupLineSpacing = 0,
    forceNewLine = false }
local GROUP_KEYS = { maxFrameCount = true, templateNames = true, initializeFrame = true, candidateFilters = true,
    sortMethod = true, sortDirection = true, layout = true }
local TOOLTIP_ANCHORS = { ANCHOR_LEFT = true, ANCHOR_RIGHT = true, ANCHOR_BOTTOMLEFT = true, ANCHOR_BOTTOM = true,
    ANCHOR_BOTTOMRIGHT = true, ANCHOR_TOPLEFT = true, ANCHOR_TOP = true, ANCHOR_TOPRIGHT = true,
    ANCHOR_CURSOR = true, ANCHOR_NONE = true, ANCHOR_PRESERVE = true, ANCHOR_CURSOR_LEFT = true,
    ANCHOR_CURSOR_RIGHT = true }
local DISPEL_TEXTURE_KEYS = { showAlways = true, showWhenHarmful = true, showWhenHelpful = true,
    showWithoutDispelType = true, stealableFilter = true, style = true, customDispelAssetMap = true,
    customDispelColorMap = true, customDispelColorCurve = true }

local function validFilter(filter)
    if type(filter) ~= "string" then return false end
    for part in filter:gmatch("[^| ]+") do
        local negated = part:sub(1, 1) == "!"
        if negated then part = part:sub(2) end
        if part == "" or not AURA_FILTERS[part] then return false end
    end
    return true
end

local function isEnumValue(enum, v)
    for _, value in pairs(enum) do
        if value == v then return true end
    end
    return false
end

local function copyLayout(layout)
    assert(layout == nil or type(layout) == "table", "layout must be a table or nil.")
    local out = {}
    for k, v in pairs(LAYOUT_DEFAULTS) do out[k] = v end
    for k, v in pairs(layout or {}) do
        local kind = LAYOUT_KEYS[k]
        assert(kind, "mock: unknown layout key " .. tostring(k))
        if kind == "size" then
            assert(type(v) == "number" and v >= 0, k .. " must be a non-negative number.")
        else
            assert(type(v) == kind, k .. " must be a " .. kind .. ".")
        end
        out[k] = v
    end
    return out
end

local function validMax(n)
    return n == math.huge or (type(n) == "number" and n >= 0 and n == math.floor(n))
end

local function restricted(obj)
    while type(obj) == "table" do
        if rawget(obj, "_auraRestricted") then return true end
        obj = rawget(obj, "_parent")
    end
    return false
end
M.IsAuraRestricted = restricted

function M.AurasSecret() return M.combat or M.aurasSecret end

function M.HasLayoutAspect(obj)
    while type(obj) == "table" do
        if rawget(obj, "_layoutForbidden") then return true end
        obj = rawget(obj, "_parent")
    end
    return false
end

-- Every method of obj and its descendants refuses while auras are secret.
local function guardTree(obj)
    for k, v in pairs(obj) do
        if type(k) == "string" and k:match("^%u") and type(v) == "function" then
            obj[k] = function(...)
                if M.AurasSecret() and restricted(obj) then
                    error("aura button: tainted access while auras are secret", 2)
                end
                return v(...)
            end
        end
    end
    for _, child in ipairs(rawget(obj, "_children") or {}) do guardTree(child) end
end

local function isDescendant(obj, owner)
    local p = type(obj) == "table" and rawget(obj, "_parent")
    while type(p) == "table" do
        if p == owner then return true end
        p = rawget(p, "_parent")
    end
    return false
end

-- AuraContainerUtil.ValidateInboundScriptObject: the right object type,
-- below the button.
local function inbound(button, obj, kind)
    assert(type(obj) == "table" and rawget(obj, "_kind") == kind,
        "bad object in function call (expected object type '" .. kind .. "')")
    assert(isDescendant(obj, button), "bad object in function call (must be a descendant of owner)")
end

local function newAuraButton(container, group)
    local b = M.newWidget("Button", nil, container)
    b._template = "CustomAuraButtonTemplate"
    b._strict = true
    b._layoutForbidden = true
    b._dispelTextures = {}
    b._tooltipAnchor = { "ANCHOR_BOTTOMLEFT", 0, 0 }
    b._shown = false
    function b:SetIcon(texture) inbound(self, texture, "Texture"); self._icon = texture end
    function b:SetDurationCooldown(cooldown) inbound(self, cooldown, "Cooldown"); self._durationCooldown = cooldown end
    function b:SetApplicationCount(fontString, options)
        inbound(self, fontString, "FontString")
        for k in pairs(options or {}) do assert(k == "formatter", "mock: unknown count option " .. tostring(k)) end
        self._applicationCount = fontString
        -- UpdateAuraDisplay writes the (empty) count at once.
        fontString:SetText("")
    end
    function b:SetDurationText(fontString) inbound(self, fontString, "FontString"); self._durationText = fontString end
    function b:AddDispelTypeTexture(texture, options)
        inbound(self, texture, "Texture")
        for _, entry in ipairs(self._dispelTextures) do
            assert(entry.texture ~= texture, "Display element has already been added.")
        end
        for k in pairs(options or {}) do assert(DISPEL_TEXTURE_KEYS[k], "mock: unknown dispel option " .. tostring(k)) end
        if options and options.style ~= nil then
            assert(isEnumValue(Enum.CustomAuraButtonDispelTypeTextureStyle, options.style), "invalid style")
        end
        table.insert(self._dispelTextures, { texture = texture, options = options })
    end
    function b:SetTooltipAnchorPoint(point, x, y)
        assert(TOOLTIP_ANCHORS[point], "point must be a valid tooltip anchor point name")
        assert(x == nil or type(x) == "number", "offsetX must be a number or nil")
        assert(y == nil or type(y) == "number", "offsetY must be a number or nil")
        self._tooltipAnchor = { point, x or 0, y or 0 }
    end
    function b:SetHideTooltipInCombat(v) self._tooltipHideInCombat = v == true end
    -- UntrustedScriptExecution: scripts an addon sets would never run.
    function b:SetScript() error("mock: an aura button runs no addon scripts", 2) end
    function b:HookScript() error("mock: an aura button runs no addon scripts", 2) end
    if group.initializeFrame then
        -- securecallfunction: an error is reported, not raised.
        xpcall(function() group.initializeFrame(b) end, geterrorhandler())
    end
    b._auraRestricted = true
    guardTree(b)
    table.insert(group.frames, b)
    return b
end

-- One more batch for a group, as when it shows more auras than it has
-- buttons (this can happen in combat).
function M.GrowAuraGroup(container, key)
    local group = assert(container._groups[key], "no such group")
    for _ = 1, M.AURA_BATCH do newAuraButton(container, group) end
end

function M.NewAuraContainer(w, template)
    assert(template == "CustomAuraContainerTemplate", "mock: only CustomAuraContainerTemplate is modelled")
    w._strict = true
    w._unit = "none"
    w._enabled = true
    w._updates = 0
    w._groups = {}
    w._groupOrder = {}
    w._flow = { axis = AnchorUtil.FlowLayoutAxis.Horizontal, anchor = "TOPLEFT",
        horizontal = AnchorUtil.FlowDirection.Right, vertical = AnchorUtil.FlowDirection.Down,
        padding = { 0, 0, 0, 0 }, lineSize = math.huge }
    local function required(self, key)
        return assert(self._groups[key], "aura group '" .. tostring(key) .. "' was not found with this key.")
    end
    function w:GetUnit() return self._unit end
    function w:SetUnit(unit)
        assert(type(unit) == "string")
        if self._unit ~= unit then
            self._unit = unit
            self._updates = self._updates + 1
        end
    end
    function w:IsEnabled() return self._enabled end
    function w:SetEnabled(v) self._enabled = v end
    function w:UpdateAllAuras() self._updates = self._updates + 1 end
    function w:AddAuraGroup(key, filter, options)
        assert(type(key) == "string" and key ~= "", "groupKey must be a non-empty string.")
        assert(validFilter(filter), "invalid filter string")
        assert(not self._groups[key], "aura group '" .. key .. "' already exists with this key.")
        options = options or {}
        for k in pairs(options) do assert(GROUP_KEYS[k], "mock: unknown group option " .. tostring(k)) end
        assert(options.initializeFrame == nil or type(options.initializeFrame) == "function",
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
        local group = { key = key, filter = filter, max = max, enabled = true, layout = copyLayout(options.layout),
            initializeFrame = options.initializeFrame, frames = {} }
        self._groups[key] = group
        table.insert(self._groupOrder, key)
        for _ = 1, M.AURA_BATCH do newAuraButton(self, group) end
        self._layoutForbidden = true
        self._updates = self._updates + 1
    end
    function w:HasAuraGroup(key) return self._groups[key] ~= nil end
    function w:IsAuraGroupEnabled(key) return required(self, key).enabled end
    function w:SetAuraGroupEnabled(key, enabled)
        assert(type(enabled) == "boolean", "enabled must be a boolean.")
        required(self, key).enabled = enabled
    end
    function w:SetAuraGroupFilterString(key, filter)
        local group = required(self, key)
        assert(validFilter(filter), "invalid filter string")
        group.filter = filter
    end
    function w:SetAuraGroupMaxFrameCount(key, max)
        local group = required(self, key)
        assert(validMax(max), "maxFrameCount must be a non-negative integer or infinity.")
        group.max = max
    end
    -- Replaces the whole layout (merged with the defaults), like the source.
    function w:SetAuraGroupLayout(key, layout) required(self, key).layout = copyLayout(layout) end
    function w:GetAuraGroupFrameCount(key)
        local group = self._groups[key]
        return group and #group.frames or 0
    end
    function w:GetAuraGroupFrame(key, index)
        local group = self._groups[key]
        return group and group.frames[index]
    end
    function w:SetFlowLayoutAxis(axis)
        assert(isEnumValue(AnchorUtil.FlowLayoutAxis, axis), "layoutAxis must be valid.")
        self._flow.axis = axis
    end
    function w:SetFlowLayoutAnchorPoint(point)
        assert(type(point) == "string", "anchorPoint must be a string.")
        self._flow.anchor = point
    end
    function w:SetFlowLayoutGrowthDirection(h, v)
        assert(isEnumValue(AnchorUtil.FlowDirection, h), "horizontalDirection must be valid.")
        assert(isEnumValue(AnchorUtil.FlowDirection, v), "verticalDirection must be valid.")
        self._flow.horizontal, self._flow.vertical = h, v
    end
    function w:SetFlowLayoutPadding(l, r, t, b)
        for _, v in ipairs({ l, r, t, b }) do assert(type(v) == "number", "padding must be numbers.") end
        self._flow.padding = { l, r, t, b }
    end
    function w:SetFlowLayoutMaximumLineSize(size)
        assert(size == nil or type(size) == "number", "maximumLineSize must be a number or nil.")
        self._flow.lineSize = size or math.huge
    end
    M.auraContainers[#M.auraContainers + 1] = w
end
```

(c) In `newWidget`, right after the `setmetatable({...}, widget)` statement, insert:

```lua
    -- Children in creation order (an aura button's are guarded with it).
    if type(parent) == "table" then
        local kids = rawget(parent, "_children") or {}
        rawset(parent, "_children", kids)
        kids[#kids + 1] = w
    end
```

(d) Replace

```lua
    -- Setting a point that is already anchored replaces that anchor.
    function w:SetPoint(point, ...)
```

with

```lua
    -- Setting a point that is already anchored replaces that anchor.
    -- Anchoring to an aura container that has groups needs the
    -- UntrustedLayoutScriptExecution aspect (Blizzard_CustomAuraContainer.lua);
    -- children have their parent's (ForbiddenAspectConstantsDocumentation.lua).
    function w:SetPoint(point, ...)
        local relativeTo = ...
        if type(relativeTo) == "table" and rawget(relativeTo, "_layoutForbidden")
            and not M.HasLayoutAspect(self) then
            error("mock: anchoring to an aura container needs DisableUntrustedLayoutScriptsTemplate", 2)
        end
```

(e) At the end of `newWidget`,

Replace

```lua
    function w:SetClampedToScreen() end
    return w
end
```

with

```lua
    function w:SetClampedToScreen() end
    -- Made under an aura button after it was restricted: restricted too.
    if restricted(w) then guardTree(w) end
    return w
end
```

(f) In `M.Reset`, after `M.headerUpdates = 0 ...`, insert:

```lua
    -- Aura containers: every one made, in order; M.auraContainerMissing
    -- makes CreateFrame refuse the type (a client without it).
    M.auraContainers = {}
    M.auraContainerMissing = false
    M.aurasSecret = false
    -- Blizzard_SharedXMLBase/AnchorUtil.lua and Blizzard_AuraContainerShared.lua.
    _G.AnchorUtil = { FlowLayoutAxis = { Horizontal = 0, Vertical = 1 },
        FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }
    _G.AuraContainerSortMethod = { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2, ImportantOnly = 3,
        Expiration = 4, ExpirationOnly = 5, Name = 6, NameOnly = 7, AuraInstanceIDOnly = 8 }
    _G.AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
```

(g) In `M.Reset`, the start of `_G.CreateFrame`:

Replace

```lua
    _G.CreateFrame = function(kind, name, parent, template)
        local w = newWidget(kind, name, parent)
        w._template = template
```

with

```lua
    _G.CreateFrame = function(kind, name, parent, template)
        if kind == "AuraContainer" and M.auraContainerMissing then
            error("CreateFrame: Unknown frame type 'AuraContainer'", 2)
        end
        local w = newWidget(kind, name, parent)
        w._template = template
        if template and template:find("DisableUntrustedLayoutScriptsTemplate") then w._layoutForbidden = true end
        if kind == "AuraContainer" then M.NewAuraContainer(w, template) end
```

(h) In `_G.Enum`, after the `UnitAuraSortRule` entry, add:

```lua
        CustomAuraButtonDispelTypeTextureStyle = { Border = 0, BorderWithIcon = 1, Icon = 2, PreserveAsset = 3,
            CustomAsset = 4 },
```

- [ ] **Step 4: The capability check**

Create `Elements/AuraContainers.lua`:

```lua
local _, ns = ...

-- Live auras through Blizzard's CustomAuraContainerTemplate
-- (Blizzard_AuraContainer). The client reads the auras and fills the icons
-- from secure code, in combat too; the addon only configures a container
-- (unit, filters, layout) and gives its buttons their look. Our own read
-- path (Elements/Auras.lua) stays for test mode samples and for clients
-- where a container cannot be made.
local AuraContainers = {}
ns.AuraContainers = AuraContainers

AuraContainers.TEMPLATE = "CustomAuraContainerTemplate"
-- The inbound calls this addon makes; a container without them is not
-- used.
AuraContainers.METHODS = { "SetUnit", "GetUnit", "UpdateAllAuras", "AddAuraGroup", "SetAuraGroupEnabled",
    "SetAuraGroupFilterString", "SetAuraGroupMaxFrameCount", "SetAuraGroupLayout", "SetFlowLayoutAxis",
    "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection", "SetFlowLayoutMaximumLineSize" }

-- nil until asked; then true or false for the session.
local supported

local function complete(container)
    for _, method in ipairs(AuraContainers.METHODS) do
        if type(container[method]) ~= "function" then return false end
    end
    return true
end

local function probe()
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, UIParent, AuraContainers.TEMPLATE)
    if not ok or type(container) ~= "table" then return false end
    container:Hide()
    local asked, answer = pcall(complete, container)
    return asked and answer
end

-- Whether this client can make aura containers for addons. Asked once,
-- with one hidden test container that is never used again.
function AuraContainers.Supported()
    if supported == nil then supported = probe() end
    return supported
end
```

In `ForeverUnitFrames.toc`, add `Elements\AuraContainers.lua` on its own line directly after `Elements\AuraButton.lua`.

In `Locales/enUS.lua`, after `L.FOCUS_MISSING = ...`, add:

```lua
L.STATUS_AURAS = "Auras: %s"
L.AURAS_CONTAINERS = "drawn by the client (update in combat)"
L.AURAS_READ = "read by the addon (frozen in combat)"
```

In `Core/Commands.lua` `status()`, after the `STATUS_FOCUS` line, add:

```lua
    ns.Print(L.STATUS_AURAS:format(ns.AuraContainers.Supported() and L.AURAS_CONTAINERS or L.AURAS_READ))
```

- [ ] **Step 5: Run the tests**

Run: `tests/run`
Expected: `4559 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add Elements/AuraContainers.lua tests/test_aura_container_check.lua tests/test_aura_container_mock.lua tests/mock.lua ForeverUnitFrames.toc Locales/enUS.lua Core/Commands.lua
git commit -F- <<'EOF'
Check at run time whether aura containers can be made

One hidden CustomAuraContainerTemplate on first use, checked for every
inbound call the addon makes; /fuf status names the aura path. The mock
gets a stand-in for the container and its buttons with the source's
checks, access restriction and layout aspect.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

### Task 2: Aura settings mapped onto a container (pure)

**Files:**
- Modify: `Elements/AuraContainers.lua` (append), `Elements/Auras.lua` (`readSettings`)
- Create: `tests/test_aura_container_map.lua`

**Interfaces:**
- Consumes: the group table `Auras.Style` fills (`primary`, `row`, `size`, `ownSize`, `spacing`, `enabled`, `highlightOwn`, `filter`, `ownFilter`, `otherFilter`, `max`), `ns.Layout.AuraRowDirection`, `ns.Layout.AuraCorner`.
- Produces: group fields `perRowSetting` (raw setting, 0 = Auto) and `length` (snapped frame width/height along the growth); `AuraContainers.PARTS = { "own", "other" }`; `AuraContainers.Flow(group) -> { axis, anchor, horizontal, vertical, lineSize }`; `AuraContainers.Part(group, part) -> { enabled, filter, max, layout = { elementWidth, elementHeight, elementSpacing, lineSpacing, groupLineSpacing, forceNewLine } }`.

- [ ] **Step 1: Write the failing test**

`tests/test_aura_container_map.lua`:

```lua
-- Aura settings mapped onto a container: flow layout and the two groups.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local AC, C = ns.AuraContainers, ns.Config
local Axis, Dir = AnchorUtil.FlowLayoutAxis, AnchorUtil.FlowDirection

local function shape(fields)
    local g = { primary = "RIGHT", row = "UP", perRowSetting = 0, length = 200, size = 20, ownSize = 26, spacing = 2,
        enabled = true, highlightOwn = false, filter = "HARMFUL", ownFilter = "HARMFUL|PLAYER",
        otherFilter = "HARMFUL|!PLAYER", max = 16 }
    for k, v in pairs(fields or {}) do g[k] = v end
    return g
end

-- Flow: axis, start corner and both directions from growth + rows.
local cases = {
    { "RIGHT", "UP", Axis.Horizontal, "BOTTOMLEFT", Dir.Right, Dir.Up },
    { "RIGHT", "DOWN", Axis.Horizontal, "TOPLEFT", Dir.Right, Dir.Down },
    { "LEFT", "DOWN", Axis.Horizontal, "TOPRIGHT", Dir.Left, Dir.Down },
    { "LEFT", "UP", Axis.Horizontal, "BOTTOMRIGHT", Dir.Left, Dir.Up },
    { "DOWN", "RIGHT", Axis.Vertical, "TOPLEFT", Dir.Right, Dir.Down },
    { "UP", "LEFT", Axis.Vertical, "BOTTOMRIGHT", Dir.Left, Dir.Up },
    -- A row direction along the growth falls back like Layout.AuraRowDirection.
    { "RIGHT", "LEFT", Axis.Horizontal, "TOPLEFT", Dir.Right, Dir.Down },
    { "UP", "DOWN", Axis.Vertical, "BOTTOMLEFT", Dir.Right, Dir.Up },
}
for _, c in ipairs(cases) do
    local f = AC.Flow(shape({ primary = c[1], row = c[2] }))
    local label = c[1] .. "/" .. c[2]
    H.check(label .. " axis", f.axis, c[3])
    H.check(label .. " corner", f.anchor, c[4])
    H.check(label .. " horizontal", f.horizontal, c[5])
    H.check(label .. " vertical", f.vertical, c[6])
end

-- Row length: Auto is the frame's length; a fixed number is that many
-- normal icons with the spacing between them; never below one icon.
H.check("auto: frame length", AC.Flow(shape()).lineSize, 200)
H.check("8 per row", AC.Flow(shape({ perRowSetting = 8 })).lineSize, 8 * 20 + 7 * 2)
H.check("1 per row", AC.Flow(shape({ perRowSetting = 1 })).lineSize, 20)
H.check("tiny frame: one icon", AC.Flow(shape({ length = 5 })).lineSize, 20)

-- The container's wrap rule (AnchorUtil.ApplyFlowLayout): n icons fit a
-- line when n * size + (n - 1) * spacing <= lineSize. Auto then gives
-- exactly Layout.AuraPerRow's count.
local function fits(lineSize, size, spacing)
    local n = 1
    while (n + 1) * size + n * spacing <= lineSize do n = n + 1 end
    return n
end
for _, length in ipairs({ 20, 21, 43, 44, 160, 199, 200, 201 }) do
    H.check("auto count at " .. length, fits(AC.Flow(shape({ length = length })).lineSize, 20, 2),
        ns.Layout.AuraPerRow(0, length, 20, 2))
end
H.check("fixed 8 holds 8", fits(AC.Flow(shape({ perRowSetting = 8 })).lineSize, 20, 2), 8)

-- Parts. Yours not first: "own" off, "other" takes the group's filter.
local own, other = AC.Part(shape(), "own"), AC.Part(shape(), "other")
H.check("own off", own.enabled, false)
H.check("other on", other.enabled, true)
H.check("other: everything", other.filter, "HARMFUL")
H.check("other size", other.layout.elementWidth .. "x" .. other.layout.elementHeight, "20x20")
H.check("spacing", other.layout.elementSpacing .. "/" .. other.layout.lineSpacing, "2/2")
H.check("no new line", other.layout.forceNewLine, false)
H.check("maximum", other.max, 16)
H.check("own filter kept valid while off", own.filter, "HARMFUL|PLAYER")

-- Yours first: own at its size, the rest on a new line.
local g = shape({ highlightOwn = true })
own, other = AC.Part(g, "own"), AC.Part(g, "other")
H.check("own on", own.enabled, true)
H.check("own filter", own.filter, "HARMFUL|PLAYER")
H.check("own size", own.layout.elementWidth, 26)
H.check("own: no new line", own.layout.forceNewLine, false)
H.check("other filter", other.filter, "HARMFUL|!PLAYER")
H.check("other: new line", other.layout.forceNewLine, true)
H.check("gap to the rows before", other.layout.groupLineSpacing, 2)
H.check("each part up to the maximum", own.max .. "," .. other.max, "16,16")

-- Only yours, first: nothing else.
g = shape({ highlightOwn = true, filter = "HARMFUL|PLAYER" })
g.otherFilter = nil
H.check("only mine: other off", AC.Part(g, "other").enabled, false)
H.check("only mine: other filter valid", AC.Part(g, "other").filter, "HARMFUL|PLAYER")
-- A switched-off group: both parts off.
g = shape({ enabled = false, highlightOwn = true })
H.check("off: own", AC.Part(g, "own").enabled, false)
H.check("off: other", AC.Part(g, "other").enabled, false)

-- Auras.Style keeps the raw per-row setting and the frame length for this.
C.Set("target", "debuffsPerRow", 5)
local d = ns.Frames.target.auras.debuffs
H.check("per row setting kept", d.perRowSetting, 5)
H.check("frame length kept", d.length, C.Get("target", "width"))
C.Set("target", "debuffsGrowth", "UP")
H.check("growing up: frame height", d.length, C.Get("target", "height"))
```

- [ ] **Step 2: Run the test to see it fail**

Run: `tests/run`
Expected: `ERROR test_aura_container_map.lua:30: attempt to call field 'Flow' (a nil value)`

- [ ] **Step 3: Keep the raw per-row setting and length**

In `Elements/Auras.lua` `readSettings`:

Replace

```lua
    local perRow, length = get(frame, group, "PerRow"), frameLength(frame, group.primary)
```

with

```lua
    local perRow, length = get(frame, group, "PerRow"), frameLength(frame, group.primary)
    group.perRowSetting, group.length = perRow, length
```

- [ ] **Step 4: The mapping**

Append to `Elements/AuraContainers.lua`:

```lua
-- Settings to container layout ---------------------------------------------------
-- A settings group (frame.auras.buffs / .debuffs, after Auras.Style read
-- its settings) becomes one container with two groups: "own" (yours, at
-- their own size) and "other" (the rest, or everything when yours are not
-- put first). Plain values in, plain tables out; no widget is touched.
AuraContainers.PARTS = { "own", "other" }

local HORIZONTAL = { RIGHT = true, LEFT = true }
local FLOW_NAMES = { RIGHT = "Right", LEFT = "Left", UP = "Up", DOWN = "Down" }

-- The container's flow: axis, the corner icons start in, both growth
-- directions and the row length at which icons wrap. A fixed number per
-- row is that many icons of the normal size; Auto is the frame's length.
function AuraContainers.Flow(group)
    local Layout = ns.Layout
    local primary = group.primary
    local row = Layout.AuraRowDirection(primary, group.row)
    local horizontal = HORIZONTAL[primary]
    local h, v = primary, row
    if not horizontal then h, v = row, primary end
    local perRow, lineSize = group.perRowSetting, group.length
    if perRow > 0 then lineSize = perRow * group.size + (perRow - 1) * group.spacing end
    return {
        axis = horizontal and AnchorUtil.FlowLayoutAxis.Horizontal or AnchorUtil.FlowLayoutAxis.Vertical,
        anchor = Layout.AuraCorner(primary, row),
        horizontal = AnchorUtil.FlowDirection[FLOW_NAMES[h]],
        vertical = AnchorUtil.FlowDirection[FLOW_NAMES[v]],
        lineSize = math.max(lineSize, group.size),
    }
end

-- One container group: shown or not, filter, maximum and layout. Yours
-- first: "own" takes the PLAYER filter at the own size, "other" the rest
-- on a new line (nothing when only yours are shown). Otherwise "own" is
-- off and "other" shows everything the group's filter lets through.
function AuraContainers.Part(group, part)
    local own = part == "own"
    local enabled, filter, size, newLine
    if own then
        enabled, filter, size, newLine = group.enabled and group.highlightOwn, group.ownFilter, group.ownSize, false
    elseif group.highlightOwn then
        enabled, filter, size, newLine = group.enabled and group.otherFilter ~= nil,
            group.otherFilter or group.filter, group.size, true
    else
        enabled, filter, size, newLine = group.enabled, group.filter, group.size, false
    end
    local spacing = group.spacing
    return {
        enabled = enabled and true or false,
        filter = filter,
        max = group.max,
        layout = { elementWidth = size, elementHeight = size, elementSpacing = spacing, lineSpacing = spacing,
            groupLineSpacing = spacing, forceNewLine = newLine },
    }
end
```

- [ ] **Step 5: Run the tests**

Run: `tests/run`
Expected: `4627 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add Elements/AuraContainers.lua Elements/Auras.lua tests/test_aura_container_map.lua
git commit -F- <<'EOF'
Map aura settings onto container flow and groups

Growth and rows become the flow axis, directions and start corner; per
row a line length (Auto: the frame length, same count as before). Yours
first is two groups, own at its size and the rest on a new line.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

### Task 3: Container buttons get our look, the client fills them

**Files:**
- Modify: `Elements/AuraButton.lua`, `Elements/AuraContainers.lua` (append)
- Create: `tests/test_aura_container_button.lua`

**Interfaces:**
- Consumes: `frame.auras[key]` settings (`size`, `ownSize`, `showTime`), `frame.key`.
- Produces: `AuraButton.Decorate(button, isDebuff)` (regions `border`, `icon`, `cooldown`, `cover`, `count`, field `isDebuff`), `AuraButton.StyleManaged(button, scope, size, showTime)`, `AuraButton.DispelCurve() -> curve`; `AuraContainers.InitButton(entry, own, button)` with `entry = { frame, key, isDebuff, buttons }`, appending `{ button = button, own = own }` to `entry.buttons`.

- [ ] **Step 1: Write the failing test**

`tests/test_aura_container_button.lua`:

```lua
-- A container's button gets our look and hands its regions to the client.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local AC, AuraButton, C = ns.AuraContainers, ns.AuraButton, ns.Config
local t = ns.Frames.target

local c = CreateFrame("AuraContainer", nil, t, "CustomAuraContainerTemplate")
local entry = { frame = t, key = "debuffs", isDebuff = true, buttons = {} }
c:AddAuraGroup("own", "HARMFUL|PLAYER", { initializeFrame = function(b) AC.InitButton(entry, true, b) end })
c:AddAuraGroup("other", "HARMFUL|!PLAYER", { initializeFrame = function(b) AC.InitButton(entry, false, b) end })
H.check("every button recorded", #entry.buttons, 2 * M.AURA_BATCH)
local own, other = entry.buttons[1], entry.buttons[M.AURA_BATCH + 1]
H.check("own recorded as own", own.own, true)
H.check("other recorded as other", other.own, false)
local b = other.button
H.check("record holds the button", b, c:GetAuraGroupFrame("other", 1))

-- Our regions, registered with the client.
H.check("icon registered", b._icon, b.icon)
H.check("swipe registered", b._durationCooldown, b.cooldown)
H.check("count registered", b._applicationCount, b.count)
H.check("count above the swipe", b.cover:GetFrameLevel() > b.cooldown:GetFrameLevel(), true)
H.check("icon cropped", b.icon._texCoord[1], 0.08)
H.check("one dispel texture", #b._dispelTextures, 1)
local dispel = b._dispelTextures[1]
H.check("border is the dispel texture", dispel.texture, b.border)
H.check("keeps our texture", dispel.options.style, Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset)
H.check("no type: NONE colour", dispel.options.showWithoutDispelType, true)
H.check("our colour curve", dispel.options.customDispelColorCurve, AuraButton.DispelCurve())
H.check("tooltip below right", b._tooltipAnchor[1], "ANCHOR_BOTTOMRIGHT")
H.check("clicks pass through", b._clickEnabled, false)

-- Look: sizes per group, fonts, time left.
H.check("other size", b:GetWidth(), C.Get("target", "debuffsSize"))
H.check("own size", own.button:GetWidth(), C.Get("target", "debuffsOwnSize"))
H.checkTrue("count font", b.count:GetFont())
H.check("time left shown", b.cooldown._hideNumbers, false)

-- Buffs: no dispel texture, the plain border colour.
local buffEntry = { frame = t, key = "buffs", isDebuff = false, buttons = {} }
c:AddAuraGroup("buffs", "HELPFUL", { initializeFrame = function(button) AC.InitButton(buffEntry, false, button) end })
local buff = buffEntry.buttons[1].button
H.check("buff: no dispel texture", #buff._dispelTextures, 0)
H.check("buff border colour", buff.border._color[1], C.Get("target", "borderColor")[1])

-- Soft outline: the count the client writes gets the plain outline.
C.Set("general", "fontOutline", "SOFT")
local soft = { frame = t, key = "debuffs", isDebuff = true, buttons = {} }
c:AddAuraGroup("soft", "HARMFUL", { initializeFrame = function(button) AC.InitButton(soft, false, button) end })
local sb = soft.buttons[1].button
H.check("plain outline", select(3, sb.count:GetFont()), "OUTLINE")
H.check("no copies of the count", sb.count.softCopies, nil)
-- Our own icons keep the soft outline.
local plainButton = AuraButton.Create(UIParent, false)
AuraButton.Style(plainButton, "target", 20, true)
H.checkTrue("own icons: soft copies", plainButton.count.softCopies)
C.ResetAll()

-- A batch made in combat is set up the same way (before it is locked).
M.combat = true
M.GrowAuraGroup(c, "other")
M.combat = false
H.check("combat batch recorded", #entry.buttons, 3 * M.AURA_BATCH)
H.check("combat batch registered", entry.buttons[#entry.buttons].button._icon, entry.buttons[#entry.buttons].button.icon)
```

- [ ] **Step 2: Run the test to see it fail**

Run: `tests/run`
Expected: `FAIL every button recorded -> 0 (want 20)` and `ERROR test_aura_container_button.lua:15: attempt to index local 'own' (a nil value)`

- [ ] **Step 3: Split `AuraButton`**

In `Elements/AuraButton.lua`, replace everything from `function AuraButton.Create(parent, isDebuff)` up to (not including) `local function paintBorder(button, c)` with:

```lua
-- The regions of an icon, made on button: our own plain frame, or a
-- Blizzard aura container's button (Elements/AuraContainers.lua).
function AuraButton.Decorate(button, isDebuff)
    button.isDebuff = isDebuff
    button.border = button:CreateTexture(nil, "BACKGROUND")
    button.border:SetAllPoints(button)
    button.border:SetColorTexture(1, 1, 1, 1)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.cooldown:SetReverse(true)
    button.cooldown:SetDrawEdge(false)
    -- The count sits on its own frame so the swipe never covers it.
    button.cover = CreateFrame("Frame", nil, button)
    button.cover:SetAllPoints(button)
    button.cover:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)
    button.count = button.cover:CreateFontString(nil, "OVERLAY")
end

function AuraButton.Create(parent, isDebuff)
    local button = CreateFrame("Frame", nil, parent)
    AuraButton.Decorate(button, isDebuff)
    button:EnableMouse(true)
    button:SetMouseClickEnabled(false)
    button:SetScript("OnEnter", onEnter)
    button:SetScript("OnLeave", onLeave)
    button:Hide()
    return button
end
```

Then replace everything from `local dispelCurve` up to (not including) `local function forget(button)` with:

```lua
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
-- count's font, size and outline setting.
local function shape(button, scope, size, showTime)
    button:SetSize(size, size)
    local inset = Pixel.Snap(1, button, 1)
    button.icon:ClearAllPoints()
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
    local font = ns.Media.Font(Config.Get(scope, "fontFace"))
    local outline = Config.Get(scope, "fontOutline")
    local fontSize = math.max(6, math.floor(size * 0.5 + 0.5))
    button.count:ClearAllPoints()
    button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button.count:SetJustifyH("RIGHT")
    -- The client writes the countdown itself: a soft outline cannot follow
    -- it, so it gets the plain outline.
    local numbers = button.cooldown:GetCountdownFontString()
    if numbers then
        local flags = (outline == "SOFT" or outline == "NONE") and "OUTLINE" or outline
        numbers:SetFont(font, fontSize, flags)
    end
    button.cooldown:SetHideCountdownNumbers(not showTime)
    button.plainBorder = Config.Get(scope, "borderColor")
    if not button.isDebuff then paintBorder(button, button.plainBorder) end
    return font, fontSize, outline
end

-- Size, fonts and countdown numbers; out of combat or on plain frames
-- only, like every Style.
function AuraButton.Style(button, scope, size, showTime)
    local font, fontSize, outline = shape(button, scope, size, showTime)
    ns.Texts.SetFont(button.count, font, fontSize, outline)
end

-- The same for a container's button. The client writes its count, so a
-- soft outline (copies of the text that we would have to write) cannot
-- follow it: it gets the plain outline, like the countdown numbers.
function AuraButton.StyleManaged(button, scope, size, showTime)
    local font, fontSize, outline = shape(button, scope, size, showTime)
    ns.Texts.SetFont(button.count, font, fontSize, outline == "SOFT" and "OUTLINE" or outline)
end
```

- [ ] **Step 4: Button setup**

Append to `Elements/AuraContainers.lua`:

```lua
-- Buttons -----------------------------------------------------------------------
-- The container makes its buttons (a batch at a time, possibly in combat)
-- and hands each to initializeFrame before it locks them against us while
-- auras are secret. There they get our regions and look, and the regions
-- the client fills are registered: icon, swipe (its countdown numbers are
-- the time left), stack count and, for debuffs, the border coloured by
-- dispel type through our colour curve. Tooltips are the container's own.

-- Debuff border: our white texture keeps its asset; the client colours it
-- from the curve, for debuffs without a dispel type too (the NONE colour).
local function dispelOptions()
    return {
        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        showWithoutDispelType = true,
        customDispelColorCurve = ns.AuraButton.DispelCurve(),
    }
end

-- entry = { frame, key, isDebuff, buttons }; own: the button belongs to
-- the "own" group (drawn at the own size).
function AuraContainers.InitButton(entry, own, button)
    local AuraButton = ns.AuraButton
    local group = entry.frame.auras[entry.key]
    local size = own and group.ownSize or group.size
    AuraButton.Decorate(button, entry.isDebuff)
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
```

- [ ] **Step 5: Run the tests**

Run: `tests/run`
Expected: `4654 passed, 0 failed` (the existing `test_aura_button.lua` still passes: `Create` and `Style` behave as before)

- [ ] **Step 6: Commit**

```bash
git add Elements/AuraButton.lua Elements/AuraContainers.lua tests/test_aura_container_button.lua
git commit -F- <<'EOF'
Give aura container buttons our look

initializeFrame builds the same regions as our own icons and hands icon,
swipe, count and the debuff border (our dispel colour curve) to the
client. The count the client writes gets the plain outline.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

### Task 4: Containers per frame, configured out of combat

**Files:**
- Modify: `Elements/AuraContainers.lua` (append), `Elements/Auras.lua`
- Create: `tests/test_aura_container_frames.lua`

**Interfaces:**
- Consumes: `AuraContainers.Supported/Flow/Part/InitButton`, `ns.Auras.LEVELS`, `ns.Settings.AURA_GROUPS`, `ns.AfterCombat`.
- Produces: `frame.auraContainers = { buffs = entry, debuffs = entry }` (`entry = { container, frame, key, isDebuff, buttons, stale }`), `frame.auraContainerFailed`; `AuraContainers.Ensure(frame) -> bool` (true: containers exist or are waiting for the end of combat), `AuraContainers.Style(frame)`; `Auras.AnchorRegion(frame, key, live)`.

- [ ] **Step 1: Write the failing test**

`tests/test_aura_container_frames.lua`:

```lua
-- Each frame's aura groups as containers: made once, configured from the
-- settings out of combat, anchored like the holders.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local AC, C, Auras = ns.AuraContainers, ns.Config, ns.Auras
M.units.target = { name = "Foe", health = 5, healthMax = 10 }
local t = ns.Frames.target

H.checkTrue("target: containers", AC.Ensure(t))
local buffs, debuffs = t.auraContainers.buffs, t.auraContainers.debuffs
local bc, dc = buffs.container, debuffs.container
H.check("buffs container parent", bc:GetParent(), t)
H.check("template", dc._template, "CustomAuraContainerTemplate")
H.check("unit", dc:GetUnit(), "target")
H.check("groups in order", table.concat(dc._groupOrder, ","), "own,other")
H.check("level above the bars", dc:GetFrameLevel(), t:GetFrameLevel() + Auras.LEVELS)
H.checkTrue("shown", dc:IsShown())
H.check("made once", AC.Ensure(t), true)
H.check("still the same", t.auraContainers.debuffs.container, dc)
H.check("two containers plus the test one", #M.auraContainers, 3)

-- Target debuffs: yours first (default) at 26, the rest at 20 on a new line.
H.check("own on", dc._groups.own.enabled, true)
H.check("own filter", dc._groups.own.filter, "HARMFUL|PLAYER")
H.check("other filter", dc._groups.other.filter, "HARMFUL|!PLAYER")
H.check("other new line", dc._groups.other.layout.forceNewLine, true)
H.check("own layout size", dc._groups.own.layout.elementWidth, 26)
H.check("max", dc._groups.other.max, 16)
H.check("own buttons at 26", debuffs.buttons[1].button:GetWidth(), 26)
H.check("other buttons at 20", debuffs.buttons[M.AURA_BATCH + 1].button:GetWidth(), 20)
-- Target buffs: not first, so "own" is off and "other" shows all.
H.check("buffs own off", bc._groups.own.enabled, false)
H.check("buffs other: all", bc._groups.other.filter, "HELPFUL")
-- Flow: right, rows up, from the bottom left; Auto wraps at the width.
H.check("flow anchor", dc._flow.anchor, "BOTTOMLEFT")
H.check("flow growth", dc._flow.horizontal .. "," .. dc._flow.vertical, "1,1")
H.check("flow row length", dc._flow.lineSize, C.Get("target", "width"))
-- Anchors: debuffs on the frame, buffs on the debuffs container.
local p, rel, rp, x, y = dc:GetPoint(1)
H.check("debuffs anchor", p .. ">" .. rp .. " " .. x .. "," .. y, "BOTTOMLEFT>TOPLEFT 0,2")
H.check("debuffs on the frame", rel, t)
H.check("buffs on the debuffs container", select(2, bc:GetPoint(1)), dc)

-- Settings apply at once out of combat.
C.Set("target", "debuffsHighlightOwn", false)
H.check("own off", dc._groups.own.enabled, false)
H.check("other: everything", dc._groups.other.filter, "HARMFUL")
H.check("no new line", dc._groups.other.layout.forceNewLine, false)
C.Set("target", "debuffsHighlightOwn", true)
C.Set("target", "debuffsOnlyMine", true)
H.check("only mine: own", dc._groups.own.filter, "HARMFUL|PLAYER")
H.check("only mine: other off", dc._groups.other.enabled, false)
C.Set("target", "debuffsDispellable", true)
H.check("dispellable", dc._groups.own.filter, "HARMFUL|PLAYER|RAID")
C.ResetScope("target")
C.Set("target", "debuffsSize", 30)
C.Set("target", "debuffsOwnSize", 36)
H.check("other buttons resized", debuffs.buttons[M.AURA_BATCH + 1].button:GetWidth(), 30)
H.check("own buttons resized", debuffs.buttons[1].button:GetWidth(), 36)
H.check("layout follows", dc._groups.other.layout.elementWidth, 30)
C.Set("target", "debuffsPerRow", 4)
H.check("4 per row", dc._flow.lineSize, 4 * 30 + 3 * 2)
C.Set("target", "debuffsGrowth", "LEFT")
C.Set("target", "debuffsRowGrowth", "DOWN")
H.check("left, down: corner", dc._flow.anchor, "TOPRIGHT")
H.check("left, down: growth", dc._flow.horizontal .. "," .. dc._flow.vertical, "-1,-1")
C.Set("target", "debuffsMax", 5)
H.check("max per part", dc._groups.own.max .. "," .. dc._groups.other.max, "5,5")
C.Set("target", "debuffsShowTime", false)
H.check("time left hidden", debuffs.buttons[1].button.cooldown._hideNumbers, true)
C.Set("target", "debuffsEnabled", false)
H.check("off: hidden", dc:IsShown(), false)
H.check("off: parts off", tostring(dc._groups.own.enabled) .. tostring(dc._groups.other.enabled), "falsefalse")
C.ResetScope("target")
H.checkTrue("on again", dc:IsShown())

-- Anchor choices; the containers hang from each other, never in a circle.
C.Set("target", "debuffsAnchor", "HEALTH")
H.check("health bar", select(2, dc:GetPoint(1)), t.health)
C.Set("target", "debuffsAnchor", "OTHER")
H.check("cycle broken", select(2, dc:GetPoint(1)), t)
C.Set("target", "buffsAnchor", "FRAME")
H.check("debuffs on the buffs container", select(2, dc:GetPoint(1)), bc)
H.check("buffs on the frame", select(2, bc:GetPoint(1)), t)
C.ResetScope("target")
H.check("back: buffs on the debuffs", select(2, bc:GetPoint(1)), dc)

-- In combat nothing changes until it ends.
M.SetCombat(true)
C.Set("target", "debuffsSize", 24)
Auras.Style(t)
H.check("combat: layout kept", dc._groups.other.layout.elementWidth, 20)
-- (Read raw: the button refuses its own methods in combat.)
H.check("combat: buttons kept", debuffs.buttons[M.AURA_BATCH + 1].button._w, 20)
M.SetCombat(false)
H.check("after combat: layout", dc._groups.other.layout.elementWidth, 24)
H.check("after combat: buttons", debuffs.buttons[M.AURA_BATCH + 1].button:GetWidth(), 24)
C.ResetScope("target")

-- Auras secret out of combat (an instance): the buttons refuse, the
-- layout is set anyway, the buttons follow after the next combat.
M.aurasSecret = true
C.Set("target", "debuffsSize", 22)
H.check("secret: layout", dc._groups.other.layout.elementWidth, 22)
H.check("secret: marked", debuffs.stale, true)
M.aurasSecret = false
H.check("secret: buttons refused", debuffs.buttons[M.AURA_BATCH + 1].button:GetWidth(), 20)
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("retried", debuffs.buttons[M.AURA_BATCH + 1].button:GetWidth(), 22)
H.check("no longer stale", debuffs.stale, false)
C.ResetScope("target")

-- Made in combat: only after it ends.
local f = ns.Frames.focus
M.SetCombat(true)
H.check("combat: counts as containers", AC.Ensure(f), true)
H.check("combat: none made yet", f.auraContainers, nil)
M.SetCombat(false)
H.checkTrue("made after combat", f.auraContainers)
H.check("focus unit", f.auraContainers.debuffs.container:GetUnit(), "focus")

-- A refusal: nothing kept, the error reported, the frame reads itself.
local pet = ns.Frames.pet
local real = M.NewAuraContainer
M.NewAuraContainer = function(w, template)
    real(w, template)
    if #M.auraContainers > 5 then w.AddAuraGroup = function() error("refused") end end
end
local errors = #M.errors
H.check("refused", AC.Ensure(pet), false)
M.NewAuraContainer = real
H.check("nothing kept", pet.auraContainers, nil)
H.check("reported", #M.errors - errors, 1)
H.check("remembered", AC.Ensure(pet), false)
H.check("half-made container hidden", M.auraContainers[#M.auraContainers]:IsShown(), false)

-- No client support: nothing is made.
ns = H.LoadAddon()
M.auraContainerMissing = true
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.check("unsupported", ns.AuraContainers.Ensure(ns.Frames.target), false)
H.check("unsupported: none", ns.Frames.target.auraContainers, nil)
```

- [ ] **Step 2: Run the test to see it fail**

Run: `tests/run`
Expected: `ERROR test_aura_container_frames.lua:11: attempt to call field 'Ensure' (a nil value)`

- [ ] **Step 3: Containers per frame**

Append to `Elements/AuraContainers.lua`:

```lua
-- Containers per frame ------------------------------------------------------------
-- frame.auraContainers = { buffs = entry, debuffs = entry }, entry =
-- { container, frame, key, isDebuff, buttons, stale }. Made the first time
-- a frame shows live auras, so the pretend party (test mode only) never
-- gets any. Made and configured out of combat only: the container itself
-- would take settings in combat, but its buttons refuse us while auras
-- are secret, and their size must change together with the layout.

-- Every frame with containers.
local all = setmetatable({}, { __mode = "k" })
-- Frames waiting for the end of combat (to be made or configured).
local waiting = setmetatable({}, { __mode = "k" })
-- Frames whose buttons could not be restyled (auras were secret); tried
-- again after combat.
local stale = setmetatable({}, { __mode = "k" })

local function testing()
    return ns.TestMode ~= nil and ns.TestMode.IsOn()
end

-- Adds the container of one group to made (before anything can fail).
local function create(frame, key, made)
    local group = frame.auras[key]
    local container = CreateFrame("AuraContainer", nil, frame, AuraContainers.TEMPLATE)
    local entry = { container = container, frame = frame, key = key, isDebuff = group.isDebuff, buttons = {} }
    made[key] = entry
    for _, part in ipairs(AuraContainers.PARTS) do
        local p, own = AuraContainers.Part(group, part), part == "own"
        container:AddAuraGroup(part, p.filter, { maxFrameCount = p.max, layout = p.layout,
            initializeFrame = function(button) AuraContainers.InitButton(entry, own, button) end })
    end
    container:SetUnit(frame.unit or "none")
end

-- Sizes and fonts of every button made so far; buttons made later get
-- them in InitButton. Refused while auras are secret: tried again later.
local function restyle(entry, group)
    local refused = false
    for _, record in ipairs(entry.buttons) do
        local size = record.own and group.ownSize or group.size
        if not pcall(ns.AuraButton.StyleManaged, record.button, entry.frame.key, size, group.showTime) then
            refused = true
        end
    end
    entry.stale = refused
    return refused
end

local function place(frame, key)
    local Config, Pixel = ns.Config, ns.Pixel
    local scope = frame.key
    frame.auraContainers[key].container:SetPoint(Config.Get(scope, key .. "Point"),
        ns.Auras.AnchorRegion(frame, key, true), Config.Get(scope, key .. "FramePoint"),
        Pixel.Snap(Config.Get(scope, key .. "X")), Pixel.Snap(Config.Get(scope, key .. "Y")))
end

-- Settings (read by Auras.Style into frame.auras) onto the containers.
local function apply(frame)
    local live = not testing()
    stale[frame] = nil
    for _, key in ipairs(ns.Settings.AURA_GROUPS) do
        local group, entry = frame.auras[key], frame.auraContainers[key]
        local container, flow = entry.container, AuraContainers.Flow(group)
        container:SetFlowLayoutAxis(flow.axis)
        container:SetFlowLayoutAnchorPoint(flow.anchor)
        container:SetFlowLayoutGrowthDirection(flow.horizontal, flow.vertical)
        container:SetFlowLayoutMaximumLineSize(flow.lineSize)
        for _, part in ipairs(AuraContainers.PARTS) do
            local p = AuraContainers.Part(group, part)
            container:SetAuraGroupFilterString(part, p.filter)
            container:SetAuraGroupMaxFrameCount(part, p.max)
            container:SetAuraGroupLayout(part, p.layout)
            container:SetAuraGroupEnabled(part, p.enabled)
        end
        if restyle(entry, group) then stale[frame] = true end
        container:SetFrameLevel(frame:GetFrameLevel() + ns.Auras.LEVELS)
        container:SetShown(live and group.enabled)
    end
    -- Anchors last, all cleared first: a group may hang from the other.
    for _, key in ipairs(ns.Settings.AURA_GROUPS) do frame.auraContainers[key].container:ClearAllPoints() end
    for _, key in ipairs(ns.Settings.AURA_GROUPS) do place(frame, key) end
end

-- Makes both containers of a frame. On a refusal nothing made is kept
-- and the frame reads its auras itself from then on.
local function build(frame)
    local made = {}
    local ok, err = pcall(function()
        for _, key in ipairs(ns.Settings.AURA_GROUPS) do create(frame, key, made) end
    end)
    if not ok then
        for _, entry in pairs(made) do entry.container:Hide() end
        frame.auraContainerFailed = true
        geterrorhandler()(err)
        return false
    end
    frame.auraContainers = made
    all[frame] = true
    apply(frame)
    return true
end

local function flush()
    local frames = {}
    for frame in pairs(waiting) do frames[#frames + 1] = frame end
    for _, frame in ipairs(frames) do
        waiting[frame] = nil
        if frame.auraContainers then
            apply(frame)
        elseif not frame.auraContainerFailed then
            build(frame)
        end
    end
end

local function later(frame)
    waiting[frame] = true
    ns.AfterCombat("auraContainers", flush)
end

-- Whether frame's live auras come from containers: made now, or waiting
-- for the end of combat. False: the addon reads them itself (no client
-- support, or the client refused this frame's containers).
function AuraContainers.Ensure(frame)
    if frame.auraContainers then return true end
    if frame.auraContainerFailed or not AuraContainers.Supported() then return false end
    if InCombatLockdown() then
        later(frame)
        return true
    end
    return build(frame)
end

-- Settings changed (Auras.Style): applied now, or after combat.
function AuraContainers.Style(frame)
    if not frame.auraContainers then return end
    if InCombatLockdown() then
        later(frame)
        return
    end
    apply(frame)
end

ns.On("PLAYER_REGEN_ENABLED", function()
    for frame in pairs(stale) do
        if not waiting[frame] then apply(frame) end
    end
end)
```

- [ ] **Step 4: Hook them into `Elements/Auras.lua`**

Replace

```lua
local Config, Layout, Pixel, AuraButton, Secrets = ns.Config, ns.Layout, ns.Pixel, ns.AuraButton, ns.Secrets
```

with

```lua
local Config, Layout, Pixel, AuraButton, Secrets = ns.Config, ns.Layout, ns.Pixel, ns.AuraButton, ns.Secrets
local AuraContainers = ns.AuraContainers
```

Replace

```lua
-- The region a group hangs from.
function Auras.AnchorRegion(frame, key)
```

with

```lua
-- The region a group hangs from. live: the frame's aura containers
-- (Elements/AuraContainers.lua) rather than its holders hang from each
-- other.
function Auras.AnchorRegion(frame, key, live)
```

Replace

```lua
        if key == "debuffs" and Config.Get(scope, "buffsAnchor") == "OTHER" then return frame end
        return frame.auras[GROUPS[key].other].holder
```

with

```lua
        if key == "debuffs" and Config.Get(scope, "buffsAnchor") == "OTHER" then return frame end
        local other = GROUPS[key].other
        if live then return frame.auraContainers[other].container end
        return frame.auras[other].holder
```

Replace

```lua
        group.holder:SetPoint(get(frame, group, "Point"), Auras.AnchorRegion(frame, key), get(frame, group, "FramePoint"),
            Pixel.Snap(get(frame, group, "X")), Pixel.Snap(get(frame, group, "Y")))
    end
end
```

with

```lua
        group.holder:SetPoint(get(frame, group, "Point"), Auras.AnchorRegion(frame, key), get(frame, group, "FramePoint"),
            Pixel.Snap(get(frame, group, "X")), Pixel.Snap(get(frame, group, "Y")))
    end
    AuraContainers.Style(frame)
end
```

- [ ] **Step 5: Run the tests**

Run: `tests/run`
Expected: `4722 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add Elements/AuraContainers.lua Elements/Auras.lua tests/test_aura_container_frames.lua
git commit -F- <<'EOF'
Aura containers per frame, configured from the settings

Two containers per frame, anchored like the holders (OTHER hangs from
the other container). Settings apply out of combat; buttons that refuse
while auras are secret are restyled after the next combat. A refused
container leaves the frame on the read path.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

### Task 5: Live auras through the containers

**Files:**
- Modify: `Elements/AuraContainers.lua` (append), `Elements/Auras.lua` (`Update`, after-combat re-read)
- Modify: `tests/test_aura_own.lua`, `tests/test_aura_read.lua`, `tests/test_aura_updates.lua` (opt into the read path)
- Create: `tests/test_aura_container_live.lua`

**Interfaces:**
- Consumes: `AuraContainers.Ensure`, `frame.auraContainers`, `ns.Single.POLL`, `TEST_MODE`.
- Produces: `AuraContainers.Refresh(frame, event)`, `AuraContainers.Hide(frame)`; `Auras.Update` reads only for frames without containers.

- [ ] **Step 1: Write the failing test; keep the read-path tests on the read path**

`tests/test_aura_container_live.lua`:

```lua
-- Live auras through the containers: no reads by the addon, units and
-- refreshes follow the frames, in combat too; test mode shows samples.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Auras, P = ns.Auras, ns.Party

local function aura(id, fields)
    local a = { auraInstanceID = id, icon = 100 + id, applications = 0, duration = 0, expirationTime = 0 }
    for k, v in pairs(fields or {}) do a[k] = v end
    return a
end
M.units.player = { name = "Me", health = 5, healthMax = 10 }
M.units.target = { name = "Foe", health = 5, healthMax = 10,
    auras = { aura(1, { isHelpful = true }), aura(2, { dispelName = "Magic" }) } }

-- A new target: the containers are made for it and refreshed; the addon
-- reads nothing and its holders stay empty.
local t = ns.Frames.target
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("target containers", t.auraContainers)
local dc = t.auraContainers.debuffs.container
H.check("unit", dc:GetUnit(), "target")
H.check("no reads", M.auraQueries, 0)
H.check("holders empty", t.auras.debuffs.count, 0)
local updates = dc._updates
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("another target: refreshed", dc._updates, updates + 1)
-- UNIT_AURA is the container's own business.
updates = dc._updates
M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
H.check("UNIT_AURA: nothing from us", dc._updates, updates)
H.check("UNIT_AURA: still no reads", M.auraQueries, 0)

-- Combat: reads would be refused; the containers are refreshed anyway.
M.auraError = true
M.SetCombat(true)
updates = dc._updates
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("combat: refreshed", dc._updates, updates + 1)
M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
H.check("combat: no errors", #M.errors, 0)
M.SetCombat(false)
M.auraError = false
H.check("after combat: no reads", M.auraQueries, 0)

-- Focus: its own containers and unit.
M.units.focus = { name = "Other", health = 5, healthMax = 10 }
M.FireEvent("PLAYER_FOCUS_CHANGED")
H.check("focus unit", ns.Frames.focus.auraContainers.debuffs.container:GetUnit(), "focus")

-- Target of target: no aura events for that token; the frame's timer
-- refreshes its containers at most every POLL_SECONDS.
M.units.targettarget = { name = "Tank", health = 5, healthMax = 10 }
local tot = ns.Frames.targettarget
M.FireEvent("PLAYER_TARGET_CHANGED")
local tc = tot.auraContainers.buffs.container
H.check("tot unit", tc:GetUnit(), "targettarget")
updates = tc._updates
M.Tick(0.2)
M.Tick(0.2)
H.check("tot: not before 0.5 s", tc._updates, updates)
M.Tick(0.2)
H.check("tot: refreshed after 0.6 s", tc._updates, updates + 1)

-- Party: containers per member, the unit follows the header in combat.
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.units.party2 = { name = "Bob", health = 5, healthMax = 10 }
M.units.party3 = { name = "Cid", health = 5, healthMax = 10 }
M.SetGroup({ "party1" })
local b1 = P.header:GetAttribute("child1")
H.check("member 1 unit", b1.auraContainers.debuffs.container:GetUnit(), "party1")
M.SetCombat(true)
M.SetGroup({ "party2", "party3" })
H.check("combat: slot 1 follows", b1.auraContainers.debuffs.container:GetUnit(), "party2")
local b2 = P.header:GetAttribute("child2")
H.check("combat: new member waits", b2.auraContainers, nil)
M.SetCombat(false)
H.checkTrue("after combat: new member's containers", b2.auraContainers)
H.check("new member unit", b2.auraContainers.debuffs.container:GetUnit(), "party3")
H.check("party: still no reads", M.auraQueries, 0)

-- Test mode: our samples, containers hidden; the pretend party never
-- gets containers.
ns.TestMode.Set(true)
H.check("test: container hidden", dc:IsShown(), false)
H.check("test: samples", t.auras.debuffs.count, 16)
for i, fake in ipairs(P.fakes) do H.check("pretend member " .. i .. ": no containers", fake.auraContainers, nil) end
ns.TestMode.Set(false)
H.checkTrue("test off: container back", dc:IsShown())
H.check("test off: samples gone", t.auras.debuffs.count, 0)
H.check("test off: buffs off stay hidden", ns.Frames.player.auraContainers.buffs.container:IsShown(), false)
H.check("test off: no reads", M.auraQueries, 0)

-- Without client support the addon reads (the fallback).
ns = H.LoadAddon()
M.auraContainerMissing = true
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.units.target = { name = "Foe", health = 5, healthMax = 10, auras = { aura(1, { isHelpful = true }) } }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("fallback: reads", M.auraQueries > 0)
H.check("fallback: icon", ns.Frames.target.auras.buffs.count, 1)
H.check("fallback: no containers", ns.Frames.target.auraContainers, nil)
```

In each of `tests/test_aura_own.lua`, `tests/test_aura_read.lua`, `tests/test_aura_updates.lua`:

Replace

```lua
local ns = H.LoadAddon()
```

with

```lua
local ns = H.LoadAddon()
-- The addon's own reads: the fallback for clients without aura containers.
M.auraContainerMissing = true
```

- [ ] **Step 2: Run the tests to see the new one fail**

Run: `tests/run`
Expected: `FAIL target containers -> false (want true)` and `ERROR test_aura_container_live.lua:23: attempt to index field 'auraContainers' (a nil value)`; the three read-path files still pass.

- [ ] **Step 3: Refresh, hide, show again**

Append to `Elements/AuraContainers.lua`:

```lua
-- Live updates ----------------------------------------------------------------------
-- The containers take UNIT_AURA for their unit themselves. What they cannot
-- know: the frame's unit changed (party slots, test mode), or the same
-- token now means someone else (a new target or focus) or has no aura
-- events at all (target of target, on the frame's timer).
function AuraContainers.Refresh(frame, event)
    if not frame.auraContainers then return end
    local unit = frame.unit or "none"
    for _, key in ipairs(ns.Settings.AURA_GROUPS) do
        local container = frame.auraContainers[key].container
        if container:GetUnit() ~= unit then
            container:SetUnit(unit)
        elseif event ~= "UNIT_AURA" then
            container:UpdateAllAuras()
        end
    end
end

-- Test mode shows our samples instead (a container shows only real auras).
function AuraContainers.Hide(frame)
    if not frame.auraContainers then return end
    for _, key in ipairs(ns.Settings.AURA_GROUPS) do frame.auraContainers[key].container:Hide() end
end

ns.Listen("TEST_MODE", function(on)
    if on then return end
    for frame in pairs(all) do
        for _, key in ipairs(ns.Settings.AURA_GROUPS) do
            frame.auraContainers[key].container:SetShown(frame.auras[key].enabled)
        end
    end
end)
```

- [ ] **Step 4: Route live frames in `Elements/Auras.lua`**

Replace

```lua
function Auras.Update(frame, event, _, info)
    if testing() then
        showSamples(frame)
        return
    end
    if event == "UNIT_AURA" and not frame.auraSamples and applyEvent(frame, info) then return end
    local now = GetTime()
    if event == ns.Single.POLL then
        if frame.auraPolled and now - frame.auraPolled < Auras.POLL_SECONDS then return end
    end
    frame.auraPolled = now
    readAll(frame, event == "UNIT_AURA")
end

-- After combat every shown frame reads again: reads refused in combat left
-- icons out of date.
ns.On("PLAYER_REGEN_ENABLED", function()
    for frame in pairs(built) do
        if frame.unit and frame:IsShown() and UnitExists(frame.unit) then Auras.Update(frame) end
    end
end)
```

with

```lua
-- A timer refresh (target of target) runs at most every POLL_SECONDS.
local function tooSoon(frame, event)
    local now = GetTime()
    if event == ns.Single.POLL and frame.auraPolled and now - frame.auraPolled < Auras.POLL_SECONDS then
        return true
    end
    frame.auraPolled = now
    return false
end

-- Live auras come from the frame's containers where the client makes
-- them (Elements/AuraContainers.lua); the reads below are the fallback.
function Auras.Update(frame, event, _, info)
    if testing() then
        AuraContainers.Hide(frame)
        showSamples(frame)
        return
    end
    if AuraContainers.Ensure(frame) then
        if frame.auraSamples then clear(frame) end
        if not tooSoon(frame, event) then AuraContainers.Refresh(frame, event) end
        return
    end
    if event == "UNIT_AURA" and not frame.auraSamples and applyEvent(frame, info) then return end
    if tooSoon(frame, event) then return end
    readAll(frame, event == "UNIT_AURA")
end

-- After combat every shown frame that reads its auras itself reads again:
-- reads refused in combat left icons out of date.
ns.On("PLAYER_REGEN_ENABLED", function()
    for frame in pairs(built) do
        if not frame.auraContainers and frame.unit and frame:IsShown() and UnitExists(frame.unit) then
            Auras.Update(frame)
        end
    end
end)
```

- [ ] **Step 5: Run the tests**

Run: `tests/run`
Expected: `4755 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add Elements/AuraContainers.lua Elements/Auras.lua tests/test_aura_container_live.lua tests/test_aura_own.lua tests/test_aura_read.lua tests/test_aura_updates.lua
git commit -F- <<'EOF'
Live auras through aura containers

Frames with containers read nothing themselves: the unit follows the
frame (party slots in combat too), new targets and the target of target
timer refresh them, test mode hides them for our samples. Without
containers the addon reads as before.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

### Task 6: In-game check (the user, in combat)

**Files:** none (report only). Needs a build of the branch after Task 5 in the client's `Interface/AddOns/ForeverUnitFrames` (copy the tracked files of a clean checkout; nothing else).

- [ ] **Step 1: Out of combat, after `/reload`**
  1. `/fuf status` → `Auras: drawn by the client (update in combat)`. (If it says `read by the addon`, stop: report the line; the rest of this list does not apply.)
  2. Target a friendly player with buffs and a mob with debuffs: icons appear on the target frame at the configured place; debuffs you cast first and bigger (target default), others on the next row; debuff borders coloured by dispel type; stack counts; swipes with time left.
  3. Hover an icon → Blizzard's aura tooltip at the icon's bottom right. Left-click an icon → the unit is targeted (click passes through), no Lua error.
  4. Options → Auras: change Size, Own size, Spacing, Per row (8, then Auto), Growth Left, Row growth Down, Max 3, Yours first off/on, Only mine, Dispellable, Remaining time off, Anchor Other / Health / Castbar, the 9-point anchors, X/Y. Each change shows at once on the live target.
  5. Test mode on: sample icons as before (no live icons underneath); off: live icons back.
- [ ] **Step 2: In combat (a mob, in a group)**
  1. Party frames: a party member gains and loses a buff during the fight → the icon appears/disappears on the party frame during combat.
  2. Target: switch targets during combat → icons follow the new target at once; a debuff you apply shows up during combat; the swipe runs down.
  3. Focus (`/focus`), target of target, pet and player frames: auras change during combat.
  4. Change an aura setting during combat (options window) → nothing changes until combat ends, then it applies; no Lua error.
  5. Someone joins the group during combat → their party frame shows auras once combat ends.
- [ ] **Step 3: Report**
  For each item: works / what was seen. Plus any Lua error text (BugSack or the default error frame) and whether `Auras cannot be accessed` appears anywhere. Items that fail go into a follow-up plan; nothing is committed in this task.


## Not verifiable offline

1. Whether party tokens (`party1`–`4`), `focus`, `pet` and `targettarget` behave like `target` in a container (the source puts no restriction on the token; only `target` was tried in game). `UnitTokenRestrictedForAddOns` is not defined in the source.
2. Whether `SetUnit`, `UpdateAllAuras`, `SetShown` on a container work in combat for an addon (no combat check in the source; the in-game target test did not call them in combat).
3. Whether `CreateFrame("AuraContainer", …)` and `AddAuraGroup` work in combat (this plan avoids it: made after combat).
4. What `DenyTaintedAccessWhenAurasAreSecret` blocks exactly (API calls only, or also Lua fields on the button table; children too?) and whether it applies out of combat in instances. The plan only writes button fields inside `initializeFrame` and restyles out of combat inside `pcall`.
5. Whether `SetMouseClickEnabled(false)` is allowed on a container button and makes clicks reach the unit button (guarded with `pcall`; `AlwaysPropagateInput` may do this anyway).
6. Whether `securecallfunction` reports an error in `initializeFrame` or swallows it silently (the mock reports it).
7. Whether the dispel colour curve maps the client's dispel type numbers as in `AuraButton.DISPEL_POINTS` (same open point as plan 4).
8. Whether `AuraUtil.SetAuraBorderColor` (applied before our curve with `PreserveAsset`) leaves anything visible our curve does not overwrite.
9. Whether anchoring a container to the other container (both with the layout aspect) is accepted, and whether anchoring a container to our health/power/castbar regions is accepted (the aspect restricts what is anchored *to* the container, per the source comment).
10. Whether the probe container (hidden, never used) costs anything noticeable.
