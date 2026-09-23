# Forever Unit Frames — Plan 3: Remaining frames, portrait, castbar

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Target of Target, Pet, Focus and Party frames, a portrait (off / left / right, 2D / 3D) and a castbar (docked above / below, or detached with its own mover) to every frame the spec lists, all configurable in the options window and visible in test mode, including a pretend party.

**Architecture:** Unit events move from one shared dispatcher to a listener per frame registered with `RegisterUnitEvent` for exactly that frame's unit (`Units/Events.lua`), so party frames do not multiply event traffic. New single frames are entries in `ns.Units.List` (whole-frame refresh events, optional unit filter, optional poll for `targettarget`). Party uses a `SecureGroupHeaderTemplate` without `initialConfigFunction`: the child template in `Units/Party.xml` declares size and clicks, Lua sizes and styles children in `OnAttributeChanged("unit")` out of combat. Portrait and castbar are ordinary elements (`Build` / `Style` / `Update`). Movers become generic (a spec per target) so the party block and detached castbars get handles too.

**Tech Stack:** Lua 5.1, WoW: Forever API (Interface 16001, build 1.60.1.69977), one XML template, offline tests with `lua5.1` + `tests/mock.lua` (`tests/run`).

Plan order: 1 Foundation (done) → 2 Options window (done) → **3 Remaining frames, portrait, castbar (this plan)** → 4 Auras → 5 Release.

## Global Constraints

- Everything in English: UI strings, file names, identifiers, comments. All user-facing strings through `ns.L` (`Locales/enUS.lua`).
- Target client: WoW: Forever, `## Interface: 16001`. API facts only from the `forever` branch of the UI source (build 69977); the facts this plan relies on are listed below with their source files.
- Never do arithmetic, comparisons, concatenation or `tostring` on values that may be secret (unit values, cast values, castGUIDs, duration objects). Pass them through to widgets. Test for presence with `type(x) == "nil"`, never by truth. Readable numbers only via `ns.Secrets.Number`, booleans via `ns.Secrets.Bool`, anything else inside `pcall`.
- Never print a secret value to chat.
- Never `hooksecurefunc` a frame's Lua mixin method. `HookScript` and hooks on plain tables are allowed.
- No secure snippets: no `initialConfigFunction`, `WrapScript`, `_onstate-*`, `RunAttribute` (`loadstring_untainted` is nil on this client).
- Secure frames (unit buttons, the party header and its buttons, pretend party buttons) are created, sized, anchored, shown, hidden and given attributes only out of combat, through `ns.AfterCombat`. The one exception is what the secure group header itself does in combat; our `OnAttributeChanged` handler must then leave protected calls for after combat.
- Every position is settable as numeric X / Y in addition to dragging: every frame, the party block as a whole, every detached castbar (spec §7).
- Setting short codes are permanent and unique. This plan adds exactly: `OR GS SP SO` (party), `PM PS` (portrait), `CE CP CD CX CY CH CI CN CT` (castbar). Existing codes: `FF FS FO FH BT BC BS BO HM HC E W H HP PP PE X Y TL TR UL UR`.
- Public repository: no local paths, host names, character names or anything about the author's machine in files or commit messages.
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp`
- Do not push. Every task ends with `tests/run` green and one commit.

## Client facts this plan relies on (build 69977)

| Fact | Source (`forever` branch) |
|---|---|
| `SecureGroupHeaderTemplate` is `hidden="true"`; `OnShow` runs `SecureGroupHeader_Update`; `OnAttributeChanged` re-runs it while visible unless the name is `_ignore` or `_ignore` is set | `Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.xml`, `.lua:55-75` |
| Header attributes used: `showParty`, `showPlayer`, `showSolo`, `point` (default `TOP`), `xOffset`, `yOffset`, `sortMethod` (`INDEX`), `template`, `templateType` (default `Button`) | `SecureGroupHeaders.lua:27-53` |
| Children: `CreateFrame(templateType, name.."UnitButton"..i, header, template)`, stored as attribute `child<i>`; `initialConfigFunction` only runs when it is a string, so leaving it unset skips snippets; each child gets `SetAttribute("unit", unit)` | `SecureGroupHeaders.lua:110-237` |
| Solo (`showSolo`) lists only `player`; in a party `showPlayer` puts `player` first, then `party1..n` | `SecureGroupHeaders.lua:261-316` |
| `SecureUnitButtonTemplate` defines only `OnClick`; an `OnAttributeChanged` in our template overrides nothing | `Blizzard_FrameXML/SecureTemplates.xml:21-25` |
| XML `<Attribute name= type="string" value=>`, `registerForClicks` on `Button`, `OnAttributeChanged` script | `Blizzard_SharedXML/UI.xsd:380-392, 409, 933` |
| `UnitCastingInfo(unit)` → name, displayName, textureID, startTimeMs, endTimeMs, isTradeskill, castID, notInterruptible, castingSpellID, castBarID, delayTimeMs; `UnitChannelInfo(unit)` → name, displayName, textureID, startTimeMs, endTimeMs, isTradeskill, notInterruptible, spellID, …; both `SecretWhenUnitSpellCastRestricted` | `Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:828-895` |
| `UnitCastingDuration` / `UnitChannelDuration` return a `LuaDurationObject` (`SecretReturns`); `GetRemainingDuration()` gives seconds | `UnitDocumentation.lua:811-868`, `LuaDurationObjectAPIDocumentation.lua:271` |
| `UNIT_SPELLCAST_START/STOP/FAILED/INTERRUPTED/DELAYED/CHANNEL_START/CHANNEL_UPDATE/CHANNEL_STOP`: payload `unitTarget, castGUID, spellID[, interruptedBy]`, and the events are `SecretWhenUnitSpellCastRestricted` — the castGUID can be secret, so it is compared only inside `pcall` | `UnitDocumentation.lua:4597-4823` |
| `Frame:RegisterUnitEvent(eventName, unit...)` | `SimpleFrameAPIDocumentation.lua:1063` |
| `PLAYER_FOCUS_CHANGED` (no payload); `UNIT_PET(unitTarget)`; `UNIT_TARGET(unitTarget)`; `UNIT_PORTRAIT_UPDATE`, `UNIT_MODEL_CHANGED`, `UNIT_CONNECTION(unitTarget, isConnected)` | `UnitDocumentation.lua:3775, 4433, 4853, 4473, 4402, 4167` |
| `SetPortraitTexture(texture, unit, disableMasking=false)`; `PlayerModel:SetUnit(unit)` (`RequiresDeclassifiedUnitIdentity`), `SetPortraitZoom`, `ClearModel`; `UnitIsVisible` | `UnitDocumentation.lua:572, 2428`, `FrameAPICharacterModelBaseDocumentation.lua:219-256`, `SimpleModelAPIDocumentation.lua:26` |
| `StatusBar:SetReverseFill` | `SimpleStatusBarAPIDocumentation.lua:262` |
| `TargetFrameToT` = `TargetFrame:GetName().."ToT"`, a secure child made in `TargetFrameMixin:CreateTargetofTarget` | `Blizzard_UnitFrame/Mainline/TargetFrame.lua:724-729` |
| `PetFrame`: secure button, parent `PlayerFrame` | `Blizzard_UnitFrame/Mainline/PetFrame.xml:11` |
| `FocusFrame` **is** defined (`[Family]\TargetFrame.xml` loads for every game type) — the spec assumed none; it is concealed when present | `Blizzard_UnitFrame/Mainline/TargetFrame.xml:579`, `Blizzard_UnitFrame.toc` |
| `PartyFrame`: plain Edit Mode frame; members in `PartyFrame.PartyMemberFramePool` (secure `PartyMemberFrameTemplate`); `CompactPartyFrame` is made on demand as a child of `PartyFrame` | `Blizzard_UnitFrame/Shared/PartyFrame.lua:20`, `Mainline/PartyFrameTemplates.xml:79`, `Shared/CompactPartyFrame.lua:5` |
| `PlayerCastingBarFrame`: `EditModeCastBarSystemTemplate` (has `HideBase`) | `Blizzard_UIPanels_Game/Mainline/CastingBarFrame.xml:468-482` |

## Design decisions

- **One listener per frame.** `ns.UnitEvents.Bind(frame)` registers every element's unit events for `frame.unit` with `RegisterUnitEvent` on a plain listener frame owned by that frame, and re-binds when the unit changes (party slots, test mode). Extra event arguments (the castGUID) reach `Update(frame, event, unit, ...)`.
- **Target of Target** has no unit events: it refreshes on `PLAYER_TARGET_CHANGED`, on `UNIT_TARGET` for `target`, and on a 0.2 s poll while shown. Poll updates carry the event `ns.Single.POLL`; the portrait ignores it (re-setting a 3D model would restart its animation).
- **Focus** is built only if `pcall(UnitExists, "focus")` succeeds; `/fuf status` reports it.
- **Party block**: header anchored `TOPLEFT` to its mover; X / Y are the block centre like every other position. Layout attributes are set with `_ignore`, then `Hide()` + `Show()` makes the header lay out once (its `OnShow`).
- **Castbar stop handling**: a stop event is ignored only if its castGUID provably differs from the one captured at START (comparison inside `pcall`); otherwise the client is asked what the unit casts now (`type(name) == "nil"` → nothing), so a late stop for an earlier cast never wipes a new one, even with secret GUIDs.
- **Party castbars dock only** (above / below each member, setting `castbarDock`). A detached castbar with its own mover exists for single frames (`castbarPosition` = `DETACHED`, `castbarX` / `castbarY`). Four party castbars sharing one detached mover would stack; this is recorded as an open question for the spec owner.
- **Test mode** shows the player on every single frame, a still sample cast on every enabled castbar, and replaces the party header by a pretend party: four (five with "Show player") secure buttons with `unit = "player"` in a plain block at the party position.

## File structure after this plan

```
Units/Events.lua       per-frame unit event listener (RegisterUnitEvent)          (new)
Units/Units.lua        + targettarget, pet, focus, party entries; FocusAvailable
Units/Single.lua       + SetUnit, POLL, Poll, StyleContent, DrawBorder, unit filters
Units/Party.lua        party header, child buttons, block mover, pretend party   (new)
Units/Party.xml        child button template (size, clicks, scripts)              (new)
Elements/Portrait.lua  2D / 3D portrait                                           (new)
Elements/Castbar.lua   castbar: casts, channels, placement, preview               (new)
Core/Settings.lua      + scopes, def.only, party / portrait / castbar settings
Core/Layout.lua        + PortraitInsets
Core/Movers.lua        generic movers (spec per target)
Core/Blizzard.lua      + ToT, pet, focus, party, player castbar
Core/Storage.lua       + /reload hint when a restored backup switches frames off
Core/Commands.lua      + focus line in /fuf status
Core/Boot.lua          + party, party mover, castbar movers
Options/Schema.lua     + portrait, party layout, castbar tab
Options/Widgets.lua    + label re-fit (row:SetLabel)
Options/Window.lua     + party highlight
Options/TestMode.lua   + castbar preview, pretend party, SetUnit
Locales/enUS.lua       all new strings
tests/mock.lua         + unit events, clock/OnUpdate, secret ==, group header, XML template mirror, casts, models
tests/harness.lua      + skip .xml, ReadFile
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
Units\Units.lua
Elements\Health.lua
Elements\Power.lua
Elements\Texts.lua
+Elements\Portrait.lua
+Elements\Castbar.lua
+Units\Events.lua
Units\Single.lua
+Units\Party.lua
+Units\Party.xml
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

How to apply the code below: new files are given in full. Changes to existing files are given as unified diffs against the state the previous task left; apply them with `git apply` (save the block to a file first) or edit by hand — the `+` lines are the exact code. Test counts in "Expected" are the totals printed by `tests/run` after the task.

---

### Task 1: Unit events per frame (RegisterUnitEvent) and missing health tests

**Files:**
- Create: `Units/Events.lua`
- Modify: `Units/Single.lua`, `Options/TestMode.lua`, `ForeverUnitFrames.toc`, `tests/mock.lua`
- Test: `tests/test_unit_events.lua`

**Interfaces:**
- Consumes: `ns.Elements` (each with `unitEvents`, `Update(frame, event, ...)`), `ns.Frames`, `ns.TestMode.Set`.
- Produces:
  - `ns.UnitEvents.Bind(frame)` — (re)registers all element unit events for `frame.unit` on `frame.eventListener` (a plain frame; allowed in combat). With `frame.unit == nil` it only unregisters. Handler calls `el.Update(frame, event, ...)` (all event arguments) when `UnitExists(frame.unit)`.
  - `ns.Single.SetUnit(frame, unit)` — sets `frame.unit`, the `unit` attribute, and re-binds events. Out of combat only.
  - Mock: `RegisterUnitEvent(event, ...)` on widgets (delivered only if the first event argument is one of the units); secret proxies refuse `==` against another secret; `GetTime()` returns `M.now` (starts at 1000); `M.Tick(seconds)` advances `M.now` and runs `OnUpdate` of every shown created frame.

- [ ] **Step 1: Extend the mock and write the failing test**

Mock changes:

```diff
diff --git a/tests/mock.lua b/tests/mock.lua
index be93cf9..e0a5304 100644
--- a/tests/mock.lua
+++ b/tests/mock.lua
@@ -13,6 +13,9 @@ for _, mm in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow",
     secretMeta[mm] = refuse
 end
 secretMeta.__tostring = refuse
+-- Comparing two secrets throws in the client too (a secret and a plain
+-- value compare without metamethod in Lua 5.1 and are simply unequal).
+secretMeta.__eq = refuse
 secretMeta.__index = function() refuse() end
 
 function M.Secret(v)
@@ -51,6 +54,13 @@ local function newWidget(kind, name, parent)
         self._scripts[s] = function(...) if old then old(...) end fn(...) end
     end
     function w:RegisterEvent(e) self._events[e] = true; M.eventFrames[self] = true end
+    -- Unit events: delivered only when the event's first argument is one of
+    -- the registered units, like the client's RegisterUnitEvent.
+    function w:RegisterUnitEvent(e, ...)
+        self._events[e] = { ... }
+        M.eventFrames[self] = true
+        return true
+    end
     function w:UnregisterEvent(e) self._events[e] = nil end
     function w:UnregisterAllEvents() self._events = {} end
     function w:SetAttribute(k, v) self._attr[k] = v end
@@ -189,6 +199,7 @@ function M.Reset()
     M.macroFrameShown = false
     M.errors = {}          -- whatever reached the global error handler
     M.timers = {}          -- queued C_Timer.After callbacks
+    M.now = 1000           -- GetTime(), advanced by M.Tick
 
     _G.UIParent = newWidget("Frame", "UIParent")
     _G.UIParent._w, _G.UIParent._h = 1920, 1080
@@ -206,6 +217,7 @@ function M.Reset()
         return w
     end
     _G.InCombatLockdown = function() return M.combat end
+    _G.GetTime = function() return M.now end
     _G.geterrorhandler = function()
         return function(err) table.insert(M.errors, err) end
     end
@@ -396,9 +408,30 @@ function M.RunTimers(maxSeconds)
     end
 end
 
+local function wants(registration, unit)
+    if registration == true then return true end
+    for _, u in ipairs(registration) do
+        if u == unit then return true end
+    end
+    return false
+end
+
 function M.FireEvent(event, ...)
+    local unit = ...
     for f in pairs(M.eventFrames) do
-        if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
+        local registration = f._events[event]
+        if registration and f._scripts.OnEvent and wants(registration, unit) then
+            f._scripts.OnEvent(f, event, ...)
+        end
+    end
+end
+
+-- Advances the clock and runs OnUpdate of every shown frame once.
+function M.Tick(seconds)
+    M.now = M.now + seconds
+    for _, f in ipairs(M.frames) do
+        local script = f._scripts.OnUpdate
+        if script and f:IsShown() then script(f, seconds) end
     end
 end
 
```

Create `tests/test_unit_events.lua` (also covers the deferred health tests: GRADIENT, STATIC, readable `UnitReaction`, `UNIT_CONNECTION`):

```lua
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local p, t = ns.Frames.player, ns.Frames.target

-- Each frame listens through its own listener, registered for its unit only.
H.checkTrue("player has a listener", p.eventListener)
H.check("registered for player only", p.eventListener._events.UNIT_HEALTH[1], "player")
H.check("one unit per registration", #p.eventListener._events.UNIT_HEALTH, 1)
H.check("target registered for target", t.eventListener._events.UNIT_HEALTH[1], "target")

M.units.player = { name = "Me", health = 5, healthMax = 10 }
M.units.target = { name = "Foe", health = 7, healthMax = 10 }
M.FireEvent("UNIT_HEALTH", "target")
H.check("target updated", t.health:GetValue(), 7)
H.check("player untouched by target event", p.health:GetValue(), nil)
M.FireEvent("UNIT_HEALTH", "nameplate3")
H.check("nameplate event reaches nobody", p.health:GetValue(), nil)
M.FireEvent("UNIT_HEALTH", "player")
H.check("player updated", p.health:GetValue(), 5)

-- Extra event arguments reach the element (castbars need the castGUID).
-- An element registered before the frames are built is indexed too.
local seen
ns = H.LoadAddon()
ns.RegisterElement({ name = "Probe", unitEvents = { "UNIT_PROBE" },
    Build = function() end, Style = function() end,
    Update = function(_, event, unit, extra) seen = { event, unit, extra } end })
ns.Config.Use({})
ns.Single.CreateAll()
M.units.player = { name = "Me" }
M.FireEvent("UNIT_PROBE", "player", "guid-1")
H.check("event name passed", seen and seen[1], "UNIT_PROBE")
H.check("unit passed", seen and seen[2], "player")
H.check("extra argument passed", seen and seen[3], "guid-1")

-- No update for a unit that does not exist.
seen = nil
M.units.player = nil
M.FireEvent("UNIT_PROBE", "player", "guid-2")
H.check("missing unit: no update", seen, nil)

-- SetUnit re-registers for the new unit.
M.units.player = { name = "Me" }
M.units.party1 = { name = "Friend" }
local f = ns.Frames.target
ns.Single.SetUnit(f, "party1")
H.check("attribute follows", f:GetAttribute("unit"), "party1")
H.check("field follows", f.unit, "party1")
H.check("events follow", f.eventListener._events.UNIT_HEALTH[1], "party1")
seen = nil
M.FireEvent("UNIT_PROBE", "target", "x")
H.check("old unit no longer delivered", seen, nil)
ns.Single.SetUnit(f, "target")

-- Test mode rebinds to the player and back.
ns.TestMode.Set(true)
H.check("test mode: target frame listens to player", f.eventListener._events.UNIT_HEALTH[1], "player")
ns.TestMode.Set(false)
H.check("test mode off: back to target", f.eventListener._events.UNIT_HEALTH[1], "target")

-- Health colours not covered before -----------------------------------------
ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
f = ns.Frames.target

ns.Config.Set("target", "healthColorMode", "GRADIENT")
M.units.target = { health = 3, healthMax = 10, healthPercent = M.Secret(0.3) }
M.FireEvent("UNIT_HEALTH", "target")
H.check("gradient: colour from the curve r", f.health._color[1], 1)
H.check("gradient: colour from the curve b", f.health._color[3], 1)

ns.Config.Set("target", "healthColorMode", "STATIC")
ns.Config.Set("target", "healthColor", { 0.1, 0.2, 0.3, 1 })
M.FireEvent("UNIT_HEALTH", "target")
H.check("static: r", f.health._color[1], 0.1)
H.check("static: g", f.health._color[2], 0.2)
H.check("static: b", f.health._color[3], 0.3)

ns.Config.Set("target", "healthColorMode", "REACTION")
M.units.target = { health = 3, healthMax = 10, reaction = 4 }
M.FireEvent("UNIT_HEALTH", "target")
H.check("readable reaction 4: neutral", f.health._color[1], 0.9)
M.units.target.reaction = 5
M.FireEvent("UNIT_HEALTH", "target")
H.check("readable reaction 5: friendly", f.health._color[1], 0.2)
M.units.target.reaction = 2
M.FireEvent("UNIT_HEALTH", "target")
H.check("readable reaction 2: hostile", f.health._color[1], 0.85)

-- UNIT_CONNECTION refreshes the bar (a member going offline or back).
M.units.target = { health = 9, healthMax = 10 }
M.FireEvent("UNIT_CONNECTION", "target", false)
H.check("connection event refreshes health", f.health:GetValue(), 9)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`
Expected: FAIL — `FAIL player has a listener -> false (want true)` and `ERROR test_unit_events.lua:9: attempt to index field 'eventListener' (a nil value)`; summary `822 passed, 2 failed`.

- [ ] **Step 3: Implement**

Create `Units/Events.lua`:

```lua
local _, ns = ...

-- Unit events reach a frame through its own listener, registered with
-- RegisterUnitEvent for exactly the frame's unit. With party frames the
-- number of frames grows, and one shared handler looping over every frame
-- for every UNIT_* event (nameplates included) would not scale.
local UnitEvents = {}
ns.UnitEvents = UnitEvents

-- event -> elements that listen to it. Built on first use: every element
-- file has registered by then.
local byEvent

local function index()
    if byEvent then return byEvent end
    byEvent = {}
    for _, el in ipairs(ns.Elements) do
        for _, event in ipairs(el.unitEvents or {}) do
            byEvent[event] = byEvent[event] or {}
            table.insert(byEvent[event], el)
        end
    end
    return byEvent
end

local function onEvent(listener, event, ...)
    local frame = listener.owner
    if not frame.unit or not UnitExists(frame.unit) then return end
    for _, el in ipairs(byEvent[event]) do el.Update(frame, event, ...) end
end

-- (Re)registers all element events for frame.unit. Runs again whenever the
-- frame's unit changes (party slots, test mode). The listener is a plain
-- frame, so this is allowed in combat.
function UnitEvents.Bind(frame)
    local listener = frame.eventListener
    if not listener then
        listener = CreateFrame("Frame")
        listener.owner = frame
        listener:SetScript("OnEvent", onEvent)
        frame.eventListener = listener
    end
    listener:UnregisterAllEvents()
    if not frame.unit then return end
    for event in pairs(index()) do
        listener:RegisterUnitEvent(event, frame.unit)
    end
end
```

Replace the shared dispatcher in `Units/Single.lua` by per-frame binding and add `SetUnit`:

```diff
diff --git a/Units/Single.lua b/Units/Single.lua
index 2916e9e..e669861 100644
--- a/Units/Single.lua
+++ b/Units/Single.lua
@@ -91,30 +91,19 @@ function Single.Create(def)
     frame:SetAttribute("*type2", "togglemenu")
     frame:RegisterForClicks("AnyUp")
     for _, el in ipairs(ns.Elements) do el.Build(frame) end
+    ns.UnitEvents.Bind(frame)
     ns.Frames[def.key] = frame
     Single.StyleAll(frame)
     return frame
 end
 
--- Event routing ----------------------------------------------------------------
-
-local unitEventsRegistered = false
-local function registerUnitEvents()
-    if unitEventsRegistered then return end
-    unitEventsRegistered = true
-    -- One handler per (element, event) pair: several elements may share an
-    -- event (e.g. Health and Texts both watch UNIT_HEALTH) and each must
-    -- still run its own Update. registerUnitEvents only runs once, so this
-    -- does not create duplicate handlers on repeated calls.
-    for _, el in ipairs(ns.Elements) do
-        for _, event in ipairs(el.unitEvents or {}) do
-            ns.On(event, function(_, unit)
-                for _, frame in pairs(ns.Frames) do
-                    if frame.unit == unit and UnitExists(unit) then el.Update(frame, event) end
-                end
-            end)
-        end
-    end
+-- Points a frame at another unit: the secure attribute for clicks, the
+-- Lua field for updates, and its event registrations. Out of combat only
+-- (the attribute is protected).
+function Single.SetUnit(frame, unit)
+    frame.unit = unit
+    frame:SetAttribute("unit", unit)
+    ns.UnitEvents.Bind(frame)
 end
 
 -- onBuilt (optional) runs right after the frames exist, inside the same
@@ -129,7 +118,6 @@ function Single.CreateAll(onBuilt)
                 end
             end
         end
-        registerUnitEvents()
         if onBuilt then onBuilt() end
     end)
 end
```

Test mode switches units through `SetUnit`, so the listener follows:

```diff
diff --git a/Options/TestMode.lua b/Options/TestMode.lua
index 15e7741..3df3114 100644
--- a/Options/TestMode.lua
+++ b/Options/TestMode.lua
@@ -18,8 +18,7 @@ local saved = {}
 -- unit watch is unregistered for as long as test mode owns the frame.
 local function applyOn(frame)
     saved[frame] = frame.unit
-    frame.unit = "player"
-    frame:SetAttribute("unit", "player")
+    ns.Single.SetUnit(frame, "player")
     UnregisterUnitWatch(frame)
     frame:Show()
     ns.Single.UpdateAll(frame)
@@ -31,8 +30,7 @@ end
 local function applyOff(frame)
     local unit = saved[frame]
     saved[frame] = nil
-    frame.unit = unit
-    frame:SetAttribute("unit", unit)
+    ns.Single.SetUnit(frame, unit)
     if ns.Config.Get(frame.key, "enabled") then
         RegisterUnitWatch(frame)
     else
```

Load the new file before `Units\Single.lua`:

```diff
diff --git a/ForeverUnitFrames.toc b/ForeverUnitFrames.toc
index e684539..494cffc 100644
--- a/ForeverUnitFrames.toc
+++ b/ForeverUnitFrames.toc
@@ -19,6 +19,7 @@ Units\Units.lua
 Elements\Health.lua
 Elements\Power.lua
 Elements\Texts.lua
+Units\Events.lua
 Units\Single.lua
 Core\Blizzard.lua
 Core\Movers.lua
```

- [ ] **Step 4: Run the tests**

Run: `tests/run`
Expected: `849 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Units/Events.lua Units/Single.lua Options/TestMode.lua ForeverUnitFrames.toc tests/mock.lua tests/test_unit_events.lua
git commit -F - <<'EOF'
Route unit events per frame with RegisterUnitEvent

Each frame gets its own listener registered for exactly its unit, so
party frames do not multiply UNIT_* traffic. Event arguments reach the
elements. Adds the missing health colour and UNIT_CONNECTION tests.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 2: Scopes for the new frames, Target of Target and Pet

**Files:**
- Modify: `Core/Settings.lua`, `Units/Units.lua`, `Units/Single.lua`, `Locales/enUS.lua`, `tests/test_window.lua`
- Test: `tests/test_frames_more.lua`

**Interfaces:**
- Consumes: `ns.UnitEvents.Bind`, `ns.Single.UpdateAll`, `M.Tick`.
- Produces:
  - `ns.Settings.SCOPES = { "general", "player", "target", "targettarget", "pet", "focus", "party" }` (codec prefixes `o e f y` already exist).
  - `def.only` (optional set of frame scopes) honoured by `Settings.AppliesTo(def, scope)`; `general` scope never gets frame settings, frames never get general-only settings.
  - Per-frame defaults: width `{ player 220, target 220, focus 160, party 160, _ 120 }`, height `{ player 46, target 46, focus 36, party 36, _ 28 }`, x `{ player -300, target 300, targettarget 480, pet -352, focus -300, party -760 }`, y `{ player -220, target -220, targettarget -220, pet -272, focus -120, party 120 }`, `textHealthRight` also `PERCENT` for focus and party.
  - `ns.Units.List` entries may carry `eventUnit = { EVENT = "unit" }` (registered with `RegisterUnitEvent`) and `poll = seconds`.
  - `ns.Single.POLL = "FUF_POLL"` — the event name `Update` receives from a poll; `ns.Single.Poll(frame, interval)` — refreshes `frame` every `interval` s while shown (driver in `frame.pollDriver`).
  - Frames `ns.Frames.targettarget` (unit `targettarget`) and `ns.Frames.pet` (unit `pet`), named `ForeverUnitFrames_<key>`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_frames_more.lua`:

```lua
local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

-- Every frame has a scope; the codec prefixes cover them all.
for _, scope in ipairs({ "targettarget", "pet", "focus", "party" }) do
    local found = false
    for _, s in ipairs(S.SCOPES) do if s == scope then found = true end end
    H.checkTrue("scope listed " .. scope, found)
    H.checkTrue("codec prefix " .. scope, S.PREFIX[scope])
end

-- def.only limits a frame setting to some frames.
local partyOnly = { scope = "frame", only = { party = true } }
H.checkTrue("only: applies to party", S.AppliesTo(partyOnly, "party"))
H.check("only: not player", S.AppliesTo(partyOnly, "player"), false)
H.check("only: not general", S.AppliesTo(partyOnly, "general"), false)
H.check("general-only never on frames", S.AppliesTo({ scope = "general" }, "pet"), false)

ns.Config.Use({})
H.check("tot width", ns.Config.Get("targettarget", "width"), 120)
H.check("pet height", ns.Config.Get("pet", "height"), 28)
H.check("tot x", ns.Config.Get("targettarget", "x"), 480)
H.check("pet y", ns.Config.Get("pet", "y"), -272)
H.checkTrue("new scope in profile", ns.Config.Profile().pet)
H.checkTrue("set on new scope", ns.Config.Set("pet", "width", 150))
H.check("codec round trip", ns.Codec.Encode(ns.Config.Profile()), "1;eW150")
H.check("codec decode", ns.Codec.Decode("1;eW150").pet.width, 150)

-- Frames ---------------------------------------------------------------------
ns.Single.CreateAll()
local tot, pet = ns.Frames.targettarget, ns.Frames.pet
H.checkTrue("tot built", tot)
H.checkTrue("pet built", pet)
H.check("tot unit", tot:GetAttribute("unit"), "targettarget")
H.check("pet unit", pet:GetAttribute("unit"), "pet")
H.check("tot secure", tot._template, "SecureUnitButtonTemplate")
H.checkTrue("tot unit watch", tot._unitWatch)
H.check("tot name", tot:GetName(), "ForeverUnitFrames_targettarget")

-- Target of target: refreshed when the target changes its target ...
M.units.targettarget = { name = "Tank", health = 4, healthMax = 10 }
M.FireEvent("UNIT_TARGET", "target")
H.check("tot refreshed on the target's UNIT_TARGET", tot.health:GetValue(), 4)
M.units.targettarget.health = 5
M.FireEvent("UNIT_TARGET", "party2")
H.check("tot ignores other units' UNIT_TARGET", tot.health:GetValue(), 4)
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("tot refreshed on a new target", tot.health:GetValue(), 5)
-- ... and on a timer, since targettarget has no unit events.
M.units.targettarget.health = 6
M.Tick(0.1)
H.check("tot not polled before the interval", tot.health:GetValue(), 5)
M.Tick(0.15)
H.check("tot polled after the interval", tot.health:GetValue(), 6)
tot:Hide()
M.units.targettarget.health = 7
M.Tick(0.25)
H.check("hidden tot not polled", tot.health:GetValue(), 6)
tot:Show()

-- Pet: refreshed when the player's pet changes, with its own unit events.
M.units.pet = { name = "Imp", health = 3, healthMax = 9 }
M.FireEvent("UNIT_PET", "player")
H.check("pet refreshed on UNIT_PET player", pet.health:GetValue(), 3)
M.units.pet.health = 2
M.FireEvent("UNIT_PET", "party1")
H.check("pet ignores a party member's pet", pet.health:GetValue(), 3)
M.FireEvent("UNIT_HEALTH", "pet")
H.check("pet unit events", pet.health:GetValue(), 2)
```

The copy-from list now offers every other frame:

```diff
diff --git a/tests/test_window.lua b/tests/test_window.lua
index b42b70f..e6b7d99 100644
--- a/tests/test_window.lua
+++ b/tests/test_window.lua
@@ -127,7 +127,7 @@ ns.Config.Set("player", "height", 60)
 click(O.copyRow.button)
 local list = ns.Widgets.list
 H.checkTrue("copy list open", list:IsShown())
-H.check("copy list offers other frames only", #list.items, 1)
+H.check("copy list offers other frames only", #list.items, #ns.Units.List - 1)
 H.check("copy item is player", list.items[1].value, "player")
 H.check("copy button keeps its label", O.copyRow.button.text:GetText(), L.COPY_FROM)
 click(list.rows[1])
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`
Expected: FAIL — among others `FAIL scope listed targettarget -> false (want true)`, `FAIL only: not player -> true (want false)`, `FAIL tot x -> 0 (want 480)`, `ERROR test_frames_more.lua:28: attempt to index field 'pet' (a nil value)`; summary `858 passed, 11 failed`.

- [ ] **Step 3: Implement**

Settings: all scopes, `def.only`, defaults for the new frames:

```diff
diff --git a/Core/Settings.lua b/Core/Settings.lua
index 589626f..cefccd3 100644
--- a/Core/Settings.lua
+++ b/Core/Settings.lua
@@ -6,7 +6,7 @@ local _, ns = ...
 local Settings = {}
 ns.Settings = Settings
 
-Settings.SCOPES = { "general", "player", "target" }
+Settings.SCOPES = { "general", "player", "target", "targettarget", "pet", "focus", "party" }
 Settings.PREFIX = {
     general = "g", player = "p", target = "t", targettarget = "o",
     pet = "e", focus = "f", party = "y",
@@ -36,9 +36,13 @@ function Settings.Default(def, scope)
     return d
 end
 
+-- def.only (optional) limits a frame setting to some frames, e.g.
+-- { party = true } for the party layout.
 function Settings.AppliesTo(def, scope)
     if scope == "general" then return def.scope ~= "frame" end
-    return def.scope ~= "general"
+    if def.scope == "general" then return false end
+    if def.only then return def.only[scope] == true end
+    return true
 end
 
 local function inList(values, v)
@@ -100,22 +104,22 @@ Settings.Define({ key = "healthColor", code = "HC", scope = "inherit", type = "c
 -- Frame layout
 Settings.Define({ key = "enabled", code = "E", scope = "frame", type = "bool", default = true })
 Settings.Define({ key = "width", code = "W", scope = "frame", type = "int", min = 40, max = 600,
-    default = { player = 220, target = 220, _ = 120 } })
+    default = { player = 220, target = 220, focus = 160, party = 160, _ = 120 } })
 Settings.Define({ key = "height", code = "H", scope = "frame", type = "int", min = 8, max = 200,
-    default = { player = 46, target = 46, _ = 28 } })
+    default = { player = 46, target = 46, focus = 36, party = 36, _ = 28 } })
 Settings.Define({ key = "healthPercent", code = "HP", scope = "frame", type = "int", min = 10, max = 100, default = 75 })
 Settings.Define({ key = "powerPercent", code = "PP", scope = "frame", type = "int", min = 0, max = 90, default = 25 })
 Settings.Define({ key = "powerEnabled", code = "PE", scope = "frame", type = "bool", default = true })
 Settings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000,
-    default = { player = -300, target = 300, _ = 0 } })
+    default = { player = -300, target = 300, targettarget = 480, pet = -352, focus = -300, party = -760, _ = 0 } })
 Settings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000,
-    default = { player = -220, target = -220, _ = 0 } })
+    default = { player = -220, target = -220, targettarget = -220, pet = -272, focus = -120, party = 120, _ = 0 } })
 
 -- Texts
 Settings.Define({ key = "textHealthLeft", code = "TL", scope = "frame", type = "enum", values = TEXT_TAGS,
     default = { player = "NAME_LEVEL", target = "NAME_LEVEL", _ = "NAME" } })
 Settings.Define({ key = "textHealthRight", code = "TR", scope = "frame", type = "enum", values = TEXT_TAGS,
-    default = { player = "CURRENT_MAX", target = "PERCENT", _ = "NONE" } })
+    default = { player = "CURRENT_MAX", target = "PERCENT", focus = "PERCENT", party = "PERCENT", _ = "NONE" } })
 Settings.Define({ key = "textPowerLeft", code = "UL", scope = "frame", type = "enum", values = TEXT_TAGS, default = "NONE" })
 Settings.Define({ key = "textPowerRight", code = "UR", scope = "frame", type = "enum", values = TEXT_TAGS,
     default = { player = "CURRENT", _ = "NONE" } })
```

Unit list: Target of Target and Pet:

```diff
diff --git a/Units/Units.lua b/Units/Units.lua
index 53789cc..672ffa6 100644
--- a/Units/Units.lua
+++ b/Units/Units.lua
@@ -1,10 +1,17 @@
 local _, ns = ...
 
 -- Which frames exist and which game events make them refresh completely.
+-- eventUnit limits an event to one unit (registered with RegisterUnitEvent).
+-- poll (seconds) refreshes a shown frame on a timer: "targettarget" gets
+-- no unit events of its own.
 ns.Units = {}
 ns.Units.List = {
     { key = "player", unit = "player", events = { "PLAYER_ENTERING_WORLD" } },
     { key = "target", unit = "target", events = { "PLAYER_TARGET_CHANGED" } },
+    { key = "targettarget", unit = "targettarget", events = { "PLAYER_TARGET_CHANGED", "UNIT_TARGET" },
+      eventUnit = { UNIT_TARGET = "target" }, poll = 0.2 },
+    { key = "pet", unit = "pet", events = { "PLAYER_ENTERING_WORLD", "UNIT_PET" },
+      eventUnit = { UNIT_PET = "player" } },
 }
 
 ns.Elements = {}
```

Single frames: per-definition event listener with unit filter, and the poll:

```diff
diff --git a/Units/Single.lua b/Units/Single.lua
index e669861..ee572e3 100644
--- a/Units/Single.lua
+++ b/Units/Single.lua
@@ -106,16 +106,41 @@ function Single.SetUnit(frame, unit)
     ns.UnitEvents.Bind(frame)
 end
 
+-- The event an Update gets when a timer, not the game, asked for it.
+Single.POLL = "FUF_POLL"
+
+-- Whole-frame refreshes: the unit changed (target, pet, ...).
+local function listen(frame, def)
+    local listener = CreateFrame("Frame")
+    for _, event in ipairs(def.events) do
+        local unit = def.eventUnit and def.eventUnit[event]
+        if unit then listener:RegisterUnitEvent(event, unit) else listener:RegisterEvent(event) end
+    end
+    listener:SetScript("OnEvent", function(_, event) Single.UpdateAll(frame, event) end)
+end
+
+-- Plain driver frame: OnUpdate on the secure button itself is not needed.
+function Single.Poll(frame, interval)
+    local driver, elapsedTotal = CreateFrame("Frame"), 0
+    driver:SetScript("OnUpdate", function(_, elapsed)
+        elapsedTotal = elapsedTotal + elapsed
+        if elapsedTotal < interval then return end
+        elapsedTotal = 0
+        if frame:IsShown() then Single.UpdateAll(frame, Single.POLL) end
+    end)
+    frame.pollDriver = driver
+end
+
 -- onBuilt (optional) runs right after the frames exist, inside the same
--- out-of-combat run that built them.
+-- out-of-combat run that built them. Group entries (party) are built by
+-- their own module.
 function Single.CreateAll(onBuilt)
     ns.AfterCombat("createSingle", function()
         for _, def in ipairs(ns.Units.List) do
-            if not ns.Frames[def.key] then
+            if def.unit and not ns.Frames[def.key] then
                 local frame = Single.Create(def)
-                for _, event in ipairs(def.events) do
-                    ns.On(event, function(e) Single.UpdateAll(frame, e) end)
-                end
+                listen(frame, def)
+                if def.poll then Single.Poll(frame, def.poll) end
             end
         end
         if onBuilt then onBuilt() end
```

Strings:

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index f6c24b7..63e5213 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -42,7 +42,7 @@ L.UNLOCKED = "Frames unlocked. Drag them, then type /fuf lock."
 L.LOCKED = "Frames locked."
 L.HELP = "/fuf opens the options. Also: /fuf unlock, /fuf lock, /fuf status, /fuf reset <frame|all>, /fuf set <scope> <setting> <value>"
 L.INVALID_VALUE = "Invalid setting or value."
-L.UNKNOWN_FRAME = "Unknown frame. Use: player, target or all."
+L.UNKNOWN_FRAME = "Unknown frame. Use: player, target, targettarget, pet, focus, party or all."
 L.RESET_DONE = "Settings reset."
 L.STATUS_SOURCE = "Settings loaded from: %s"
 L.SOURCE_SavedVariables = "SavedVariables"
@@ -55,6 +55,8 @@ L.STATUS_BUILD = "Client %s (build %s), interface %d"
 L.STATUS_PROJECT = "Project ID %d"
 L.FRAME_player = "Player"
 L.FRAME_target = "Target"
+L.FRAME_targettarget = "Target of Target"
+L.FRAME_pet = "Pet"
 
 L.TAB_appearance = "Appearance"; L.TAB_colors = "Colors"; L.TAB_profile = "Profile"
 L.TAB_layout = "Layout"; L.TAB_bars = "Bars"; L.TAB_text = "Text"
```

- [ ] **Step 4: Run the tests**

Run: `tests/run`
Expected: `885 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Settings.lua Units/Units.lua Units/Single.lua Locales/enUS.lua tests/test_window.lua tests/test_frames_more.lua
git commit -F - <<'EOF'
Add Target of Target and Pet frames

Scopes for every frame of the spec, settings limited to some frames
(def.only), per-frame defaults. Target of Target refreshes on the
target's UNIT_TARGET and on a short poll; the pet on UNIT_PET for the
player.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 3: Focus frame and focus availability in /fuf status

**Files:**
- Modify: `Units/Units.lua`, `Units/Single.lua`, `Core/Commands.lua`, `Locales/enUS.lua`
- Test: `tests/test_focus.lua`

**Interfaces:**
- Consumes: `ns.Units.List`, `ns.Single.CreateAll`.
- Produces:
  - `ns.Units.FocusAvailable() -> boolean` — `pcall(UnitExists, "focus")` succeeded.
  - `ns.Units.List` entry `{ key = "focus", unit = "focus", events = { "PLAYER_FOCUS_CHANGED" }, available = ns.Units.FocusAvailable }`; `Single.CreateAll` skips entries whose `available()` is false.
  - `/fuf status` prints `L.STATUS_FOCUS` with `L.FOCUS_AVAILABLE` or `L.FOCUS_MISSING`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_focus.lua`:

```lua
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local focus = ns.Frames.focus
H.checkTrue("focus built", focus)
H.check("focus unit", focus:GetAttribute("unit"), "focus")
H.check("focus width", focus:GetWidth(), 160)
H.check("focus events", focus.eventListener._events.UNIT_HEALTH[1], "focus")

M.units.focus = { name = "Boss", health = 8, healthMax = 10 }
M.FireEvent("PLAYER_FOCUS_CHANGED")
H.check("focus refreshed on PLAYER_FOCUS_CHANGED", focus.health:GetValue(), 8)
M.units.focus.health = 6
M.FireEvent("UNIT_HEALTH", "focus")
H.check("focus unit events", focus.health:GetValue(), 6)

-- /fuf status reports whether the client accepts the focus unit.
M.chat = {}
SlashCmdList.FOREVERUNITFRAMES("status")
H.checkTrue("status: focus available",
    table.concat(M.chat, "\n"):find(ns.L.STATUS_FOCUS:format(ns.L.FOCUS_AVAILABLE), 1, true))

-- A client that rejects the token: no focus frame, and status says so.
ns = H.LoadAddon()
local realExists = UnitExists
_G.UnitExists = function(unit)
    if unit == "focus" then error("Invalid unit token") end
    return realExists(unit)
end
ns.Config.Use({})
ns.Single.CreateAll()
H.check("no focus frame without the unit", ns.Frames.focus, nil)
H.checkTrue("other frames still built", ns.Frames.player)
M.chat = {}
SlashCmdList.FOREVERUNITFRAMES("status")
H.checkTrue("status: focus missing",
    table.concat(M.chat, "\n"):find(ns.L.STATUS_FOCUS:format(ns.L.FOCUS_MISSING), 1, true))
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`
Expected: FAIL — `FAIL focus built -> false (want true)`, `ERROR test_focus.lua:7: attempt to index local 'focus' (a nil value)`; summary `885 passed, 2 failed`.

- [ ] **Step 3: Implement**

```diff
diff --git a/Units/Units.lua b/Units/Units.lua
index 672ffa6..429739d 100644
--- a/Units/Units.lua
+++ b/Units/Units.lua
@@ -5,6 +5,14 @@ local _, ns = ...
 -- poll (seconds) refreshes a shown frame on a timer: "targettarget" gets
 -- no unit events of its own.
 ns.Units = {}
+
+-- Blizzard ships no focus frame for this game type. The unit token exists
+-- in the client source; whether the client accepts it is checked at run
+-- time and shown by /fuf status.
+function ns.Units.FocusAvailable()
+    return (pcall(UnitExists, "focus"))
+end
+
 ns.Units.List = {
     { key = "player", unit = "player", events = { "PLAYER_ENTERING_WORLD" } },
     { key = "target", unit = "target", events = { "PLAYER_TARGET_CHANGED" } },
@@ -12,6 +20,7 @@ ns.Units.List = {
       eventUnit = { UNIT_TARGET = "target" }, poll = 0.2 },
     { key = "pet", unit = "pet", events = { "PLAYER_ENTERING_WORLD", "UNIT_PET" },
       eventUnit = { UNIT_PET = "player" } },
+    { key = "focus", unit = "focus", events = { "PLAYER_FOCUS_CHANGED" }, available = ns.Units.FocusAvailable },
 }
 
 ns.Elements = {}
```

```diff
diff --git a/Units/Single.lua b/Units/Single.lua
index ee572e3..512d83a 100644
--- a/Units/Single.lua
+++ b/Units/Single.lua
@@ -137,7 +137,8 @@ end
 function Single.CreateAll(onBuilt)
     ns.AfterCombat("createSingle", function()
         for _, def in ipairs(ns.Units.List) do
-            if def.unit and not ns.Frames[def.key] then
+            local usable = def.available == nil or def.available()
+            if def.unit and usable and not ns.Frames[def.key] then
                 local frame = Single.Create(def)
                 listen(frame, def)
                 if def.poll then Single.Poll(frame, def.poll) end
```

```diff
diff --git a/Core/Commands.lua b/Core/Commands.lua
index f4f72dc..036d8cd 100644
--- a/Core/Commands.lua
+++ b/Core/Commands.lua
@@ -31,6 +31,7 @@ local function status()
     ns.Print(L.STATUS_PROJECT:format(WOW_PROJECT_ID or 0))
     local src, isProvider = ns.Storage.Source()
     ns.Print(L.STATUS_SOURCE:format(isProvider and src or L["SOURCE_" .. src]))
+    ns.Print(L.STATUS_FOCUS:format(ns.Units.FocusAvailable() and L.FOCUS_AVAILABLE or L.FOCUS_MISSING))
     local macroError = ns.Storage.MacroError()
     if macroError then ns.Print(L[macroError]) end
 end
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index 63e5213..e013067 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -57,6 +57,10 @@ L.FRAME_player = "Player"
 L.FRAME_target = "Target"
 L.FRAME_targettarget = "Target of Target"
 L.FRAME_pet = "Pet"
+L.FRAME_focus = "Focus"
+L.STATUS_FOCUS = "Focus unit: %s"
+L.FOCUS_AVAILABLE = "available"
+L.FOCUS_MISSING = "not supported by this client"
 
 L.TAB_appearance = "Appearance"; L.TAB_colors = "Colors"; L.TAB_profile = "Profile"
 L.TAB_layout = "Layout"; L.TAB_bars = "Bars"; L.TAB_text = "Text"
```

- [ ] **Step 4: Run the tests**

Run: `tests/run`
Expected: `895 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Units/Units.lua Units/Single.lua Core/Commands.lua Locales/enUS.lua tests/test_focus.lua
git commit -F - <<'EOF'
Add the focus frame and report focus support in /fuf status

The focus frame is built only when the client accepts the focus unit;
/fuf status says whether it does.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 4: Party header and member buttons

**Files:**
- Create: `Units/Party.lua`, `Units/Party.xml`
- Modify: `Units/Single.lua`, `Units/Units.lua`, `Core/Boot.lua`, `ForeverUnitFrames.toc`, `Locales/enUS.lua`, `tests/mock.lua`, `tests/harness.lua`
- Test: `tests/test_party.lua`

**Interfaces:**
- Consumes: `ns.Elements`, `ns.UnitEvents.Bind`, `ns.Single.UpdateAll`, `ns.AfterCombat`.
- Produces:
  - `ns.Single.StyleContent(frame)` — bars, border and element `Style` (nothing protected); `Single.StyleAll` uses it. `Single.UpdateAll` returns early when `frame.unit` is nil.
  - `ns.Party` with `KEY = "party"`, `HEADER = "ForeverUnitFramesParty"`, `TEMPLATE = "ForeverUnitFramesPartyButtonTemplate"`, `MEMBERS = 4`, `SPACING = 12` (removed again in Task 5), `buttons` (header-made buttons in creation order), `header`.
  - `Party.BlockSize() -> w, h`, `Party.StyleButton(button)`, `Party.StyleAll()` (out of combat), `Party.InitButton(button)` (XML `OnLoad`), `Party.OnUnitChanged(button, unit)` (XML `OnAttributeChanged("unit")`), `Party.Create() -> header`.
  - Globals used by the XML: `ForeverUnitFrames.PartyButtonOnLoad(self)`, `ForeverUnitFrames.PartyButtonOnAttributeChanged(self, name, value)`.
  - `ns.Units.List` entry `{ key = "party", group = true }` (no `unit`: `Single.CreateAll` skips it; the options navigation lists it).
  - Boot builds the party right after the single frames (`afterBuild`).
  - Mock: `M.templates` (Lua mirror of `Units/Party.xml`), a `SecureGroupHeaderTemplate` emulation, `SetAttribute` fires `OnAttributeChanged`, `M.group`, `M.SetGroup(units)` (fires `GROUP_ROSTER_UPDATE`), `IsInGroup()`, `M.headerUpdates`. Harness: `H.LoadAddon` skips `.xml`, `H.ReadFile(path)`.

- [ ] **Step 1: Extend mock and harness, write the failing test**

```diff
diff --git a/tests/mock.lua b/tests/mock.lua
index e0a5304..91f9da5 100644
--- a/tests/mock.lua
+++ b/tests/mock.lua
@@ -40,6 +40,80 @@ widget.__index = function(t, k)
     return f
 end
 
+-- XML templates of the addon, mirrored in Lua (the tests cannot load XML).
+-- test_party.lua checks that Units/Party.xml declares the same.
+M.templates = {
+    ForeverUnitFramesPartyButtonTemplate = function(w)
+        w._w, w._h = 160, 36
+        w._clicks = { "AnyUp" }
+        w._attr["*type1"] = "target"
+        w._attr["*type2"] = "togglemenu"
+        w._scripts.OnAttributeChanged = function(self, name, value)
+            ForeverUnitFrames.PartyButtonOnAttributeChanged(self, name, value)
+        end
+        ForeverUnitFrames.PartyButtonOnLoad(w)
+    end,
+}
+
+-- SecureGroupHeaderTemplate, reduced to what the addon relies on: party
+-- or solo detection, showPlayer/showSolo/showParty, point and offsets,
+-- child creation from the template attribute, unit assignment through
+-- SetAttribute("unit"), and updates on show, attribute change and roster
+-- change while shown.
+local OPPOSITE = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT" }
+
+local function groupHeaderUpdate(header)
+    local a = header._attr
+    local kind
+    if #M.group > 0 and a.showParty then kind = "PARTY" elseif a.showSolo then kind = "SOLO" end
+    local units = {}
+    if kind == "SOLO" or (kind == "PARTY" and a.showPlayer) then units[1] = "player" end
+    if kind == "PARTY" then
+        for _, u in ipairs(M.group) do units[#units + 1] = u end
+    end
+    for i = 1, math.max(1, #units) do
+        if not a["child" .. i] then
+            local child = CreateFrame(a.templateType or "Button", header:GetName() .. "UnitButton" .. i, header, a.template)
+            header[i] = child
+            a["child" .. i] = child
+        end
+    end
+    local point = a.point or "TOP"
+    local previous
+    for i, unit in ipairs(units) do
+        local child = a["child" .. i]
+        child:ClearAllPoints()
+        if previous then
+            child:SetPoint(point, previous, OPPOSITE[point], a.xOffset or 0, a.yOffset or 0)
+        else
+            child:SetPoint(point, header, point, 0, 0)
+        end
+        child:SetAttribute("unit", unit)
+        child:Show()
+        previous = child
+    end
+    local i = #units + 1
+    while a["child" .. i] do
+        local child = a["child" .. i]
+        child:Hide()
+        child:ClearAllPoints()
+        child:SetAttribute("unit", nil)
+        i = i + 1
+    end
+    M.headerUpdates = M.headerUpdates + 1
+end
+
+local function makeGroupHeader(w)
+    w._shown = false   -- the template is hidden="true"
+    w:RegisterEvent("GROUP_ROSTER_UPDATE")
+    w._scripts.OnEvent = function(self) if self:IsShown() then groupHeaderUpdate(self) end end
+    w._scripts.OnShow = groupHeaderUpdate
+    w._scripts.OnAttributeChanged = function(self, name)
+        if name == "_ignore" or self._attr._ignore then return end
+        if self:IsShown() then groupHeaderUpdate(self) end
+    end
+end
+
 local function newWidget(kind, name, parent)
     local w = setmetatable({
         _kind = kind, _name = name, _parent = parent, _scripts = {},
@@ -63,7 +137,11 @@ local function newWidget(kind, name, parent)
     end
     function w:UnregisterEvent(e) self._events[e] = nil end
     function w:UnregisterAllEvents() self._events = {} end
-    function w:SetAttribute(k, v) self._attr[k] = v end
+    function w:SetAttribute(k, v)
+        self._attr[k] = v
+        local script = self._scripts.OnAttributeChanged
+        if script then script(self, k, v) end
+    end
     function w:GetAttribute(k) return self._attr[k] end
     function w:RegisterForClicks(...) self._clicks = { ... } end
     function w:SetSize(a, b) self._w, self._h = a, b end
@@ -200,6 +278,8 @@ function M.Reset()
     M.errors = {}          -- whatever reached the global error handler
     M.timers = {}          -- queued C_Timer.After callbacks
     M.now = 1000           -- GetTime(), advanced by M.Tick
+    M.group = {}           -- party unit tokens ("party1", ...) while grouped
+    M.headerUpdates = 0    -- how often a group header laid out its buttons
 
     _G.UIParent = newWidget("Frame", "UIParent")
     _G.UIParent._w, _G.UIParent._h = 1920, 1080
@@ -214,10 +294,13 @@ function M.Reset()
         if kind == "StatusBar" then w._barTex = newWidget("Texture", nil, w) end
         if name then _G[name] = w end
         table.insert(M.frames, w)
+        if template == "SecureGroupHeaderTemplate" then makeGroupHeader(w) end
+        if M.templates[template] then M.templates[template](w) end
         return w
     end
     _G.InCombatLockdown = function() return M.combat end
     _G.GetTime = function() return M.now end
+    _G.IsInGroup = function() return #M.group > 0 end
     _G.geterrorhandler = function()
         return function(err) table.insert(M.errors, err) end
     end
@@ -383,6 +466,12 @@ function M.NewMacroFrame()
     return f
 end
 
+-- Joins or leaves a party: M.SetGroup({ "party1", "party2" }) or M.SetGroup({}).
+function M.SetGroup(units)
+    M.group = units
+    M.FireEvent("GROUP_ROSTER_UPDATE")
+end
+
 function M.SetCombat(v)
     M.combat = v
     if not v then M.FireEvent("PLAYER_REGEN_ENABLED") end
```

```diff
diff --git a/tests/harness.lua b/tests/harness.lua
index c376979..1c8957e 100644
--- a/tests/harness.lua
+++ b/tests/harness.lua
@@ -34,15 +34,26 @@ function H.TocFiles()
 end
 
 -- Fresh mock + fresh namespace, every file loaded like the client does:
--- chunk(addonName, ns). `files` defaults to the whole TOC.
+-- chunk(addonName, ns). `files` defaults to the whole TOC. XML files are
+-- not loaded; the mock mirrors their templates (see M.templates).
 function H.LoadAddon(files)
     M.Reset()
     local ns = {}
     for _, f in ipairs(files or H.TocFiles()) do
-        local chunk = assert(loadfile(ADDONDIR .. "/" .. f))
-        chunk("ForeverUnitFrames", ns)
+        if not f:match("%.xml$") then
+            local chunk = assert(loadfile(ADDONDIR .. "/" .. f))
+            chunk("ForeverUnitFrames", ns)
+        end
     end
     return ns
 end
 
+-- Whole file as a string (for checks on XML the tests cannot load).
+function H.ReadFile(path)
+    local fh = assert(io.open(ADDONDIR .. "/" .. path))
+    local text = fh:read("*a")
+    fh:close()
+    return text
+end
+
 return H
```

Create `tests/test_party.lua`:

```lua
local M = H.M
local ns = H.LoadAddon()

-- The XML template and the mock mirror of it agree.
local xml = H.ReadFile("Units/Party.xml")
H.checkTrue("xml: template name", xml:find('name="ForeverUnitFramesPartyButtonTemplate"', 1, true))
H.checkTrue("xml: secure unit button", xml:find('inherits="SecureUnitButtonTemplate"', 1, true))
H.checkTrue("xml: clicks", xml:find('registerForClicks="AnyUp"', 1, true))
H.checkTrue("xml: size = party defaults", xml:find('<Size x="160" y="36"/>', 1, true))
H.checkTrue("xml: left click targets", xml:find('<Attribute name="*type1" type="string" value="target"/>', 1, true))
H.checkTrue("xml: right click menu", xml:find('<Attribute name="*type2" type="string" value="togglemenu"/>', 1, true))
H.checkTrue("xml: OnLoad", xml:find("ForeverUnitFrames.PartyButtonOnLoad(self)", 1, true))
H.checkTrue("xml: OnAttributeChanged",
    xml:find("ForeverUnitFrames.PartyButtonOnAttributeChanged(self, name, value)", 1, true))
H.checkTrue("xml: no snippet", not xml:find("initialConfigFunction", 1, true))
H.check("default width = xml", ns.Settings.Default(ns.Settings.Get("width"), "party"), 160)
H.check("default height = xml", ns.Settings.Default(ns.Settings.Get("height"), "party"), 36)
local toc = H.ReadFile("ForeverUnitFrames.toc")
H.checkTrue("toc lists the xml after the lua",
    toc:find("Units\\Party.lua\nUnits\\Party.xml", 1, true))

ns.Config.Use({})
ns.Single.CreateAll()
local header = ns.Party.Create()
H.checkTrue("header built", header)
H.check("header template", header._template, "SecureGroupHeaderTemplate")
H.check("header name", header:GetName(), "ForeverUnitFramesParty")
H.check("child template", header:GetAttribute("template"), "ForeverUnitFramesPartyButtonTemplate")
H.check("no snippet attribute", header:GetAttribute("initialConfigFunction"), nil)
H.checkTrue("shows in a party", header:GetAttribute("showParty"))
H.checkTrue("header shown", header:IsShown())
local point, rel, relPoint, x, y = header:GetPoint(1)
H.check("block anchored top left", point, "TOPLEFT")
H.check("block x from centre", x, -760 - 80)
H.check("block y from centre", y, 120 + (4 * 36 + 3 * 12) / 2)

-- Solo: no member buttons in use.
H.check("solo: first button has no unit", header:GetAttribute("child1"):GetAttribute("unit"), nil)
H.check("solo: first button hidden", header:GetAttribute("child1"):IsShown(), false)

-- Joining a party: one button per member, sized and styled from settings.
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.units.party2 = { name = "Bob", health = 7, healthMax = 10 }
ns.Config.Set("party", "width", 180)
M.SetGroup({ "party1", "party2" })
local b1, b2 = header:GetAttribute("child1"), header:GetAttribute("child2")
H.check("button 1 unit", b1:GetAttribute("unit"), "party1")
H.check("button 2 unit", b2:GetAttribute("unit"), "party2")
H.check("lua unit field", b2.unit, "party2")
H.check("button key", b1.key, "party")
H.check("button width from settings", b2:GetWidth(), 180)
H.check("button height from settings", b2:GetHeight(), 36)
H.check("button health", b2.health:GetValue(), 7)
H.check("button events for its unit", b2.eventListener._events.UNIT_HEALTH[1], "party2")
M.units.party2.health = 3
M.FireEvent("UNIT_HEALTH", "party2")
H.check("member event updates the button", b2.health:GetValue(), 3)
H.check("other member untouched", b1.health:GetValue(), 5)
H.check("left click", b1:GetAttribute("*type1"), "target")
H.check("second stacked below the first", select(2, b2:GetPoint(1)), b1)

-- Someone joins in combat: the header makes the button (XML size), the
-- settings size follows after combat.
M.units.party3 = { name = "Cid", health = 9, healthMax = 10 }
M.combat = true
M.SetGroup({ "party1", "party2", "party3" })
local b3 = header:GetAttribute("child3")
H.check("combat join: button made", b3:GetAttribute("unit"), "party3")
H.check("combat join: xml width until combat ends", b3:GetWidth(), 160)
H.check("combat join: data already shown", b3.health:GetValue(), 9)
M.SetCombat(false)
H.check("combat join: sized after combat", b3:GetWidth(), 180)

-- Settings changes restyle every button; disabling hides the block.
ns.Config.Set("party", "height", 40)
H.check("restyle height", b1:GetHeight(), 40)
ns.Config.Set("party", "enabled", false)
H.check("disabled: header hidden", header:IsShown(), false)
ns.Config.Set("party", "enabled", true)
H.checkTrue("enabled again: header shown", header:IsShown())

-- Leaving the group clears the buttons.
M.SetGroup({})
H.check("left group: unit cleared", b1:GetAttribute("unit"), nil)
H.check("left group: events unbound", next(b1.eventListener._events), nil)

-- Built at login together with the single frames.
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
H.checkTrue("login: header built", ns.Party.header)
H.checkTrue("login: header shown", ns.Party.header:IsShown())
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`
Expected: FAIL — `ERROR harness.lua:53: .../Units/Party.xml: No such file or directory`; summary `895 passed, 1 failed`.

- [ ] **Step 3: Implement**

Create `Units/Party.xml` (the size must equal the party width / height defaults from Task 2):

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.blizzard.com/wow/ui/ ..\FrameXML\UI.xsd">
	<!--
		One party member. The SecureGroupHeaderTemplate in Units/Party.lua creates
		these, possibly in combat when someone joins; Lua may not size a secure
		frame then, so the size and click handling live here. Keep the size equal
		to the party width/height defaults in Core/Settings.lua; tests/test_party.lua
		checks that this file and the test mock agree.
	-->
	<Button name="ForeverUnitFramesPartyButtonTemplate" virtual="true" inherits="SecureUnitButtonTemplate" registerForClicks="AnyUp">
		<Size x="160" y="36"/>
		<Attributes>
			<Attribute name="*type1" type="string" value="target"/>
			<Attribute name="*type2" type="string" value="togglemenu"/>
		</Attributes>
		<Scripts>
			<OnLoad>ForeverUnitFrames.PartyButtonOnLoad(self)</OnLoad>
			<OnAttributeChanged>ForeverUnitFrames.PartyButtonOnAttributeChanged(self, name, value)</OnAttributeChanged>
		</Scripts>
	</Button>
</Ui>
```

Create `Units/Party.lua`:

```lua
local _, ns = ...

-- Party frames. A SecureGroupHeaderTemplate creates one button per member
-- from the template in Units/Party.xml. There is no initialConfigFunction:
-- secure snippets do not run on this client. The XML gives each button its
-- starting size and clicks; Lua sizes and styles it when the header hands
-- it a unit, and again after combat if that happened in combat.
local Party = {}
ns.Party = Party

local Config, Single = ns.Config, ns.Single

Party.KEY = "party"
Party.HEADER = "ForeverUnitFramesParty"
Party.TEMPLATE = "ForeverUnitFramesPartyButtonTemplate"
Party.MEMBERS = 4
Party.SPACING = 12
-- Every button the header made, in creation order.
Party.buttons = {}

local function get(key) return Config.Get(Party.KEY, key) end

-- Width and height of the whole block with every slot filled.
function Party.BlockSize()
    local w, h, n = get("width"), get("height"), Party.MEMBERS
    return w, n * h + (n - 1) * Party.SPACING
end

-- Header attributes are set in one go; a single relayout follows.
local function setAttributes(header, attributes)
    header:SetAttribute("_ignore", "attributeChanges")
    for name, value in pairs(attributes) do header:SetAttribute(name, value) end
    header:SetAttribute("_ignore", nil)
end

local function headerAttributes()
    return {
        template = Party.TEMPLATE, templateType = "Button", sortMethod = "INDEX",
        showParty = true, showPlayer = false, showSolo = false,
        point = "TOP", xOffset = 0, yOffset = -Party.SPACING,
    }
end

-- Top-left corner of the block at the configured centre position.
local function place(header)
    local w, h = Party.BlockSize()
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", UIParent, "CENTER", get("x") - w / 2, get("y") + h / 2)
end

function Party.StyleButton(button)
    if not InCombatLockdown() then
        button:SetSize(get("width"), get("height"))
    end
    Single.StyleContent(button)
    Single.UpdateAll(button)
end

local function sizeButtons()
    for _, button in ipairs(Party.buttons) do
        button:SetSize(get("width"), get("height"))
    end
end

-- Out of combat only: attributes, position, size and visibility are
-- protected on the header and its buttons.
function Party.StyleAll()
    local header = Party.header
    if not header then return end
    setAttributes(header, headerAttributes())
    place(header)
    for _, button in ipairs(Party.buttons) do Party.StyleButton(button) end
    -- Hide + Show makes the header lay its buttons out again (OnShow).
    header:Hide()
    if get("enabled") then header:Show() end
end

-- XML OnLoad: the button exists, its unit is not known yet.
function Party.InitButton(button)
    button.key = Party.KEY
    for _, el in ipairs(ns.Elements) do el.Build(button) end
    Party.buttons[#Party.buttons + 1] = button
    Single.StyleContent(button)
end

-- The header assigns or clears a unit, in or out of combat.
function Party.OnUnitChanged(button, unit)
    button.unit = unit
    ns.UnitEvents.Bind(button)
    if not unit then return end
    ns.AfterCombat("partySize", sizeButtons)
    Single.UpdateAll(button)
end

function Party.Create()
    if Party.header then return Party.header end
    local header = CreateFrame("Frame", Party.HEADER, UIParent, "SecureGroupHeaderTemplate")
    header.key = Party.KEY
    Party.header = header
    Party.StyleAll()
    return header
end

-- Called from Units/Party.xml; not part of the public API.
ns.api.PartyButtonOnLoad = Party.InitButton
function ns.api.PartyButtonOnAttributeChanged(button, name, value)
    if name == "unit" then Party.OnUnitChanged(button, value) end
end

ns.Listen("CONFIG_CHANGED", function(scope)
    if scope ~= nil and scope ~= "general" and scope ~= Party.KEY then return end
    ns.AfterCombat("partyStyle", Party.StyleAll)
end)
```

Split the non-protected styling out of `Single.StyleAll` and guard `UpdateAll`:

```diff
diff --git a/Units/Single.lua b/Units/Single.lua
index 512d83a..8d47a51 100644
--- a/Units/Single.lua
+++ b/Units/Single.lua
@@ -69,16 +69,22 @@ local function applyEnabled(frame)
 end
 
 function Single.UpdateAll(frame, event)
-    if not UnitExists(frame.unit) then return end
+    if not frame.unit or not UnitExists(frame.unit) then return end
     for _, el in ipairs(ns.Elements) do el.Update(frame, event) end
 end
 
-function Single.StyleAll(frame)
-    if frame.mover then ns.Movers.Sync(frame) end
-    place(frame)
+-- Everything inside a unit button that is not itself protected: bars,
+-- border, element regions. Party buttons use this in combat too.
+function Single.StyleContent(frame)
     layoutBars(frame)
     border(frame)
     for _, el in ipairs(ns.Elements) do el.Style(frame) end
+end
+
+function Single.StyleAll(frame)
+    if frame.mover then ns.Movers.Sync(frame) end
+    place(frame)
+    Single.StyleContent(frame)
     applyEnabled(frame)
     Single.UpdateAll(frame)
 end
```

```diff
diff --git a/Units/Units.lua b/Units/Units.lua
index 429739d..07045f6 100644
--- a/Units/Units.lua
+++ b/Units/Units.lua
@@ -21,6 +21,8 @@ ns.Units.List = {
     { key = "pet", unit = "pet", events = { "PLAYER_ENTERING_WORLD", "UNIT_PET" },
       eventUnit = { UNIT_PET = "player" } },
     { key = "focus", unit = "focus", events = { "PLAYER_FOCUS_CHANGED" }, available = ns.Units.FocusAvailable },
+    -- Built by Units/Party.lua from a group header, not as a single frame.
+    { key = "party", group = true },
 }
 
 ns.Elements = {}
```

```diff
diff --git a/Core/Boot.lua b/Core/Boot.lua
index 54d57c5..2a24b0e 100644
--- a/Core/Boot.lua
+++ b/Core/Boot.lua
@@ -5,7 +5,9 @@ local _, ns = ...
 -- Character macros may arrive later (see Storage.WaitForMacros). Every
 -- settings change is persisted.
 
-local function attachMovers()
+-- Runs in the same out-of-combat run that built the single frames.
+local function afterBuild()
+    ns.Party.Create()
     for _, frame in pairs(ns.Frames) do ns.Movers.Attach(frame) end
 end
 
@@ -17,8 +19,9 @@ ns.On("PLAYER_LOGIN", function()
     ns.Storage.Attach(ForeverUnitFramesDB)
     -- Nothing found: the macro backup may still be on its way.
     ns.Storage.WaitForMacros()
-    -- Movers go on in the same (possibly deferred) run that builds frames.
-    ns.Single.CreateAll(attachMovers)
+    -- Party and movers follow in the same (possibly deferred) run that
+    -- builds the single frames.
+    ns.Single.CreateAll(afterBuild)
     ns.Blizzard.HideDefaults()
 end)
 
```

```diff
diff --git a/ForeverUnitFrames.toc b/ForeverUnitFrames.toc
index 494cffc..929ed04 100644
--- a/ForeverUnitFrames.toc
+++ b/ForeverUnitFrames.toc
@@ -21,6 +21,8 @@ Elements\Power.lua
 Elements\Texts.lua
 Units\Events.lua
 Units\Single.lua
+Units\Party.lua
+Units\Party.xml
 Core\Blizzard.lua
 Core\Movers.lua
 Core\Commands.lua
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index e013067..96a460b 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -58,6 +58,7 @@ L.FRAME_target = "Target"
 L.FRAME_targettarget = "Target of Target"
 L.FRAME_pet = "Pet"
 L.FRAME_focus = "Focus"
+L.FRAME_party = "Party"
 L.STATUS_FOCUS = "Focus unit: %s"
 L.FOCUS_AVAILABLE = "available"
 L.FOCUS_MISSING = "not supported by this client"
```

- [ ] **Step 4: Run the tests**

Run: `tests/run`
Expected: `942 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Units/Party.lua Units/Party.xml Units/Single.lua Units/Units.lua Core/Boot.lua ForeverUnitFrames.toc Locales/enUS.lua tests/mock.lua tests/harness.lua tests/test_party.lua
git commit -F - <<'EOF'
Add party frames on a secure group header

No initialConfigFunction: the child template declares size and clicks,
Lua sizes and styles each button when the header hands it a unit, and
after combat when that happened in combat.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 5: Party layout settings, generic movers, party block mover

**Files:**
- Modify: `Core/Movers.lua` (rewrite), `Core/Settings.lua`, `Units/Party.lua`, `Core/Boot.lua`, `Options/Schema.lua`, `Locales/enUS.lua`
- Test: `tests/test_party_layout.lua`

**Interfaces:**
- Consumes: `ns.Party`, `ns.Config`, `ns.Settings.AppliesTo` with `only`.
- Produces:
  - Settings (party only): `partyOrientation` (`OR`, `VERTICAL`/`HORIZONTAL`, default `VERTICAL`), `partySpacing` (`GS`, 0–60, default 12), `partyShowPlayer` (`SP`, default false), `partyShowSolo` (`SO`, default false).
  - `Party.Slots() -> n` (4, or 5 with the player), `Party.BlockSize() -> w, h` (orientation-aware), `Party.SlotOffset(i) -> x, y` from the block's top-left corner, `Party.MoverSpec() -> spec`. `Party.SPACING` is removed.
  - Movers: `Movers.Attach(target, spec?)` with spec fields `scope`, `xKey` (default `"x"`), `yKey` (default `"y"`), `size() -> w, h`, `point` (default `"CENTER"`), `anchor` (`false` = do not anchor the target), `active()` (optional; handle hidden while false), `label`, `id` (combat-queue key, default `scope`). `Movers.FrameSpec(frame)` is the spec of a unit frame. `Movers.Sync(target)` reads everything from `target.mover.spec`. Handles shown on unlock only if active; re-evaluated on every `CONFIG_CHANGED` while unlocked. `mover.frameKey` is gone (use `mover.spec.scope`).
  - Boot attaches `Movers.Attach(ns.Party.header, ns.Party.MoverSpec())`.
  - Schema: layout section `group` (the four party keys) before `position`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_party_layout.lua`:

```lua
local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

for _, key in ipairs({ "partyOrientation", "partySpacing", "partyShowPlayer", "partyShowSolo" }) do
    H.checkTrue(key .. " applies to party", S.AppliesTo(S.Get(key), "party"))
    H.check(key .. " not on player", S.AppliesTo(S.Get(key), "player"), false)
end

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local P, C = ns.Party, ns.Config
local header = P.header

-- Vertical by default: the header stacks downwards with the spacing.
H.check("point", header:GetAttribute("point"), "TOP")
H.check("x offset", header:GetAttribute("xOffset"), 0)
H.check("y offset", header:GetAttribute("yOffset"), -12)
H.check("player hidden by default", header:GetAttribute("showPlayer"), false)
H.check("solo hidden by default", header:GetAttribute("showSolo"), false)
local w, h = P.BlockSize()
H.check("block width", w, 160)
H.check("block height", h, 4 * 36 + 3 * 12)

C.Set("party", "partySpacing", 4)
H.check("spacing -> y offset", header:GetAttribute("yOffset"), -4)
C.Set("party", "partyOrientation", "HORIZONTAL")
H.check("horizontal point", header:GetAttribute("point"), "LEFT")
H.check("horizontal x offset", header:GetAttribute("xOffset"), 4)
H.check("horizontal y offset", header:GetAttribute("yOffset"), 0)
w, h = P.BlockSize()
H.check("horizontal block width", w, 4 * 160 + 3 * 4)
H.check("horizontal block height", h, 36)
local sx, sy = P.SlotOffset(3)
H.check("slot 3 x", sx, 2 * (160 + 4))
H.check("slot 3 y", sy, 0)
C.Set("party", "partyOrientation", "VERTICAL")
sx, sy = P.SlotOffset(3)
H.check("vertical slot 3 x", sx, 0)
H.check("vertical slot 3 y", sy, -2 * (36 + 4))

-- Show player / show when solo go straight to the header.
C.Set("party", "partyShowPlayer", true)
H.checkTrue("show player", header:GetAttribute("showPlayer"))
H.check("five slots with the player", P.Slots(), 5)
C.Set("party", "partyShowSolo", true)
H.checkTrue("show solo", header:GetAttribute("showSolo"))
H.check("solo: player shown", header:GetAttribute("child1"):GetAttribute("unit"), "player")
H.checkTrue("solo: button visible", header:GetAttribute("child1"):IsShown())
M.units.party1 = { name = "Ann", health = 1, healthMax = 2 }
M.SetGroup({ "party1" })
H.check("party with player first", header:GetAttribute("child1"):GetAttribute("unit"), "player")
H.check("then the member", header:GetAttribute("child2"):GetAttribute("unit"), "party1")
C.Set("party", "partyShowPlayer", false)
H.check("without player", header:GetAttribute("child1"):GetAttribute("unit"), "party1")

-- The whole block has one mover; X / Y are the block's centre.
local mover = header.mover
H.checkTrue("block mover", mover)
local point, rel, relPoint = header:GetPoint(1)
H.check("header hangs from the mover", rel, mover)
H.check("top-left to top-left", point, "TOPLEFT")
H.check("mover width = block", mover:GetWidth(), 160)
H.check("mover height = block", mover:GetHeight(), 4 * 36 + 3 * 4)
local _, _, _, mx, my = mover:GetPoint(1)
H.check("mover x", mx, -760)
H.check("mover y", my, 120)
C.Set("party", "x", -700)
_, _, _, mx = mover:GetPoint(1)
H.check("numeric X moves the block", mx, -700)
ns.Movers.Unlock()
H.checkTrue("block mover shown when unlocked", mover:IsShown())
mover._cx, mover._cy = 960 - 500, 540 + 100
UIParent._cx, UIParent._cy = 960, 540
ns.Movers.OnDragStop(mover)
H.check("drag writes party x", C.Get("party", "x"), -504)
H.check("drag writes party y", C.Get("party", "y"), 104)
ns.Movers.Lock()

-- Generic movers: own position keys, no anchoring, shown only when active.
local target = CreateFrame("Frame", nil, UIParent)
local active = false
C.Set("player", "width", 200)
ns.Movers.Attach(target, { scope = "player", xKey = "height", yKey = "healthPercent", anchor = false,
    size = function() return 50, 10 end, label = "Probe", id = "probe", active = function() return active end })
H.check("no anchoring when anchor = false", target._points[1], nil)
H.check("custom size", target.mover:GetWidth(), 50)
local _, _, _, px, py = target.mover:GetPoint(1)
H.check("custom x key", px, C.Get("player", "height"))
H.check("custom y key", py, C.Get("player", "healthPercent"))
ns.Movers.Unlock()
H.check("inactive mover stays hidden", target.mover:IsShown(), false)
active = true
C.Set("player", "width", 210)   -- any change re-evaluates while unlocked
H.checkTrue("active mover appears", target.mover:IsShown())
ns.Movers.Lock()
H.check("locked: hidden", target.mover:IsShown(), false)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`
Expected: FAIL — `ERROR .../Core/Settings.lua:43: attempt to index local 'def' (a nil value)` (the party settings do not exist yet); summary `942 passed, 1 failed`.

- [ ] **Step 3: Implement**

Replace `Core/Movers.lua` with the generic version:

```lua
local _, ns = ...

-- Drag handles. Secure frames are anchored to their mover and never moved
-- themselves; moving happens only out of combat.
--
-- Anything can have a mover: a unit frame, the party block, a detached
-- castbar. A spec says which settings hold the position and how big the
-- handle is:
--   scope          settings scope ("player", "party", ...)
--   xKey, yKey     position settings, offsets of the handle's centre from
--                  the screen centre (default "x" / "y")
--   size()         -> width, height of the handle
--   point          anchor point shared by target and handle (default
--                  "CENTER"); the party block hangs from "TOPLEFT"
--   anchor         false: Attach does not anchor the target (its own
--                  Style decides, e.g. a castbar that may also be docked)
--   active()       optional: false keeps the handle hidden when unlocked
--   label          text on the handle
--   id             combat-queue key suffix (default scope)
local Movers = {}
ns.Movers = Movers

local GRID = 8
local unlocked = false
local L = ns.L
-- Every target that has a mover, in attach order.
local targets = {}

function Movers.Snap(v)
    local sign = v < 0 and -1 or 1
    return sign * math.floor(math.abs(v) / GRID + 0.5) * GRID
end

-- The spec of an ordinary unit frame.
function Movers.FrameSpec(frame)
    local key = frame.key
    return {
        scope = key, label = L["FRAME_" .. key],
        size = function() return ns.Config.Get(key, "width"), ns.Config.Get(key, "height") end,
    }
end

local function complete(spec)
    spec.xKey = spec.xKey or "x"
    spec.yKey = spec.yKey or "y"
    spec.point = spec.point or "CENTER"
    spec.id = spec.id or spec.scope
    return spec
end

-- Sizes and positions the mover from config alone, never from the
-- target's own current size: inside a queued combat restyle the target may
-- not have been resized yet, and a value read off it would be stale. No-op
-- if the target has no mover.
function Movers.Sync(target)
    local mover = target.mover
    if not mover then return end
    local spec = mover.spec
    mover:SetSize(spec.size())
    mover:ClearAllPoints()
    mover:SetPoint("CENTER", UIParent, "CENTER",
        ns.Config.Get(spec.scope, spec.xKey), ns.Config.Get(spec.scope, spec.yKey))
end

function Movers.OnDragStop(mover)
    mover.dragging = false
    mover:StopMovingOrSizing()
    local mx, my = mover:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local spec = mover.spec
    ns.Config.Set(spec.scope, spec.xKey, Movers.Snap(mx - ux))
    ns.Config.Set(spec.scope, spec.yKey, Movers.Snap(my - uy))
end

local function isActive(mover)
    return mover.spec.active == nil or mover.spec.active()
end

function Movers.Attach(target, spec)
    if target.mover then return end
    spec = complete(spec or Movers.FrameSpec(target))
    if InCombatLockdown() then
        ns.AfterCombat("attach:" .. spec.id, function() Movers.Attach(target, spec) end)
        return
    end
    local mover = CreateFrame("Frame", nil, UIParent)
    mover.spec = spec
    mover:SetMovable(true)
    -- Unit frames sit at the default MEDIUM strata with opaque bars; without
    -- this the mover's overlay/label are hidden underneath and the secure
    -- unit button (mouse enabled) steals the drag instead of the mover.
    mover:SetFrameStrata("DIALOG")
    mover:SetClampedToScreen(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self.dragging = true
        self:StartMoving()
    end)
    mover:SetScript("OnDragStop", Movers.OnDragStop)
    mover.overlay = mover:CreateTexture(nil, "OVERLAY")
    mover.overlay:SetAllPoints(mover)
    mover.overlay:SetColorTexture(0.3, 0.76, 0.97, 0.35)
    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetFont(ns.Media.Font("Friz Quadrata"), 11, "OUTLINE")
    mover.label:SetPoint("CENTER", mover, "CENTER", 0, 0)
    mover.label:SetText(spec.label)
    target.mover = mover
    targets[#targets + 1] = target
    Movers.Sync(target)
    mover:EnableMouse(false)
    mover:Hide()
    if spec.anchor ~= false then
        target:ClearAllPoints()
        target:SetPoint(spec.point, mover, spec.point, 0, 0)
    end
end

function Movers.IsUnlocked() return unlocked end

-- Shows the handles that are active right now (a castbar's only while it
-- is detached). Also run when settings change while unlocked.
local function showActive()
    for _, target in ipairs(targets) do
        local mover = target.mover
        local on = isActive(mover)
        mover:EnableMouse(on)
        mover:SetShown(on)
    end
end

function Movers.Unlock()
    if InCombatLockdown() then
        ns.Print(L.LOCKED_IN_COMBAT)
        return false
    end
    unlocked = true
    showActive()
    ns.Print(L.UNLOCKED)
    return true
end

-- A drag in progress is stopped at once. In combat only the flag is
-- cleared; hiding and disabling the movers waits until combat ends.
function Movers.Lock()
    unlocked = false
    for _, target in ipairs(targets) do
        local mover = target.mover
        if mover.dragging then
            Movers.OnDragStop(mover)
        else
            mover:StopMovingOrSizing()
        end
    end
    ns.AfterCombat("lockMovers", function()
        if unlocked then return end
        for _, target in ipairs(targets) do
            target.mover:EnableMouse(false)
            target.mover:Hide()
        end
    end)
    ns.Print(L.LOCKED)
end

-- Combat is about to start: lock down before secure lockdown begins.
-- PLAYER_REGEN_DISABLED fires just before lockdown takes effect, so hiding
-- and disabling the (unprotected) movers here is still allowed.
ns.On("PLAYER_REGEN_DISABLED", function()
    if unlocked then Movers.Lock() end
end)

-- A castbar switched to detached (or back) while unlocked gains or loses
-- its handle at once. Unlocked implies out of combat.
ns.Listen("CONFIG_CHANGED", function()
    if unlocked then showActive() end
end)
```

Party settings:

```diff
diff --git a/Core/Settings.lua b/Core/Settings.lua
index cefccd3..5a264f0 100644
--- a/Core/Settings.lua
+++ b/Core/Settings.lua
@@ -115,6 +115,14 @@ Settings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4
 Settings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000,
     default = { player = -220, target = -220, targettarget = -220, pet = -272, focus = -120, party = 120, _ = 0 } })
 
+-- Party block (party only)
+local PARTY = { party = true }
+Settings.Define({ key = "partyOrientation", code = "OR", scope = "frame", only = PARTY, type = "enum",
+    values = { "VERTICAL", "HORIZONTAL" }, default = "VERTICAL" })
+Settings.Define({ key = "partySpacing", code = "GS", scope = "frame", only = PARTY, type = "int", min = 0, max = 60, default = 12 })
+Settings.Define({ key = "partyShowPlayer", code = "SP", scope = "frame", only = PARTY, type = "bool", default = false })
+Settings.Define({ key = "partyShowSolo", code = "SO", scope = "frame", only = PARTY, type = "bool", default = false })
+
 -- Texts
 Settings.Define({ key = "textHealthLeft", code = "TL", scope = "frame", type = "enum", values = TEXT_TAGS,
     default = { player = "NAME_LEVEL", target = "NAME_LEVEL", _ = "NAME" } })
```

Party layout from settings; the header follows its mover once it has one:

```diff
diff --git a/Units/Party.lua b/Units/Party.lua
index e874f20..517b33e 100644
--- a/Units/Party.lua
+++ b/Units/Party.lua
@@ -14,16 +14,36 @@ Party.KEY = "party"
 Party.HEADER = "ForeverUnitFramesParty"
 Party.TEMPLATE = "ForeverUnitFramesPartyButtonTemplate"
 Party.MEMBERS = 4
-Party.SPACING = 12
 -- Every button the header made, in creation order.
 Party.buttons = {}
 
 local function get(key) return Config.Get(Party.KEY, key) end
 
+-- Slots in a full block: four members, plus the player if shown.
+function Party.Slots()
+    return Party.MEMBERS + (get("partyShowPlayer") and 1 or 0)
+end
+
 -- Width and height of the whole block with every slot filled.
 function Party.BlockSize()
-    local w, h, n = get("width"), get("height"), Party.MEMBERS
-    return w, n * h + (n - 1) * Party.SPACING
+    local w, h, s, n = get("width"), get("height"), get("partySpacing"), Party.Slots()
+    if get("partyOrientation") == "HORIZONTAL" then
+        return n * w + (n - 1) * s, h
+    end
+    return w, n * h + (n - 1) * s
+end
+
+-- Offset of slot i (1-based) from the block's top-left corner.
+function Party.SlotOffset(i)
+    local step = i - 1
+    if get("partyOrientation") == "HORIZONTAL" then
+        return step * (get("width") + get("partySpacing")), 0
+    end
+    return 0, -step * (get("height") + get("partySpacing"))
+end
+
+function Party.MoverSpec()
+    return { scope = Party.KEY, point = "TOPLEFT", size = Party.BlockSize, label = ns.L.FRAME_party }
 end
 
 -- Header attributes are set in one go; a single relayout follows.
@@ -34,15 +54,24 @@ local function setAttributes(header, attributes)
 end
 
 local function headerAttributes()
+    local horizontal = get("partyOrientation") == "HORIZONTAL"
+    local spacing = get("partySpacing")
     return {
         template = Party.TEMPLATE, templateType = "Button", sortMethod = "INDEX",
-        showParty = true, showPlayer = false, showSolo = false,
-        point = "TOP", xOffset = 0, yOffset = -Party.SPACING,
+        showParty = true, showPlayer = get("partyShowPlayer"), showSolo = get("partyShowSolo"),
+        point = horizontal and "LEFT" or "TOP",
+        xOffset = horizontal and spacing or 0,
+        yOffset = horizontal and 0 or -spacing,
     }
 end
 
--- Top-left corner of the block at the configured centre position.
+-- The block hangs from its top-left corner; X / Y are its centre, like
+-- every other position. With a mover the header follows the mover.
 local function place(header)
+    if header.mover then
+        ns.Movers.Sync(header)
+        return
+    end
     local w, h = Party.BlockSize()
     header:ClearAllPoints()
     header:SetPoint("TOPLEFT", UIParent, "CENTER", get("x") - w / 2, get("y") + h / 2)
```

```diff
diff --git a/Core/Boot.lua b/Core/Boot.lua
index 2a24b0e..cdf00f4 100644
--- a/Core/Boot.lua
+++ b/Core/Boot.lua
@@ -9,6 +9,7 @@ local _, ns = ...
 local function afterBuild()
     ns.Party.Create()
     for _, frame in pairs(ns.Frames) do ns.Movers.Attach(frame) end
+    ns.Movers.Attach(ns.Party.header, ns.Party.MoverSpec())
 end
 
 ns.On("PLAYER_LOGIN", function()
```

```diff
diff --git a/Options/Schema.lua b/Options/Schema.lua
index 3e16a0f..bfe2ea1 100644
--- a/Options/Schema.lua
+++ b/Options/Schema.lua
@@ -19,6 +19,7 @@ Schema.FRAME = {
         { id = "frame", keys = { "enabled" } },
         { id = "size", keys = { "width", "height" } },
         { id = "barHeights", keys = { "healthPercent", "powerPercent", "powerEnabled" } },
+        { id = "group", keys = { "partyOrientation", "partySpacing", "partyShowPlayer", "partyShowSolo" } },
         { id = "position", keys = { "x", "y" } },
     } },
     { id = "bars", sections = {
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index 96a460b..8e58f84 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -25,6 +25,10 @@ L.SETTING_powerPercent = "Power bar height (%)"
 L.SETTING_powerEnabled = "Show power bar"
 L.SETTING_x = "Position X"
 L.SETTING_y = "Position Y"
+L.SETTING_partyOrientation = "Orientation"
+L.SETTING_partySpacing = "Spacing"
+L.SETTING_partyShowPlayer = "Show player"
+L.SETTING_partyShowSolo = "Show when solo"
 L.SETTING_textHealthLeft = "Health bar, left text"
 L.SETTING_textHealthRight = "Health bar, right text"
 L.SETTING_textPowerLeft = "Power bar, left text"
@@ -70,6 +74,7 @@ L.SECTION_health = "Health bar"; L.SECTION_frame = "Frame"; L.SECTION_size = "Si
 L.SECTION_barHeights = "Bar heights"; L.SECTION_position = "Position"
 L.SECTION_textures = "Textures"; L.SECTION_healthText = "Health bar text"
 L.SECTION_powerText = "Power bar text"
+L.SECTION_group = "Party layout"
 L.HINT_healthPercent = "Share of the frame height"
 L.HINT_powerPercent = "Share of the frame height; the rest becomes the gap"
 L.HINT_x = "Offset from the screen centre"
@@ -82,6 +87,7 @@ L.ENUM_GRADIENT = "Gradient by health"
 L.ENUM_NAME = "Name"; L.ENUM_NAME_LEVEL = "Level and name"; L.ENUM_LEVEL = "Level"
 L.ENUM_CURRENT = "Current"; L.ENUM_CURRENT_MAX = "Current / max"; L.ENUM_PERCENT = "Percent"
 L.ENUM_DEFICIT = "Deficit"
+L.ENUM_VERTICAL = "Vertical"; L.ENUM_HORIZONTAL = "Horizontal"
 L.ENUM_fontOutline_NONE = "None"
 L.ENUM_textHealthLeft_NONE = "Empty"
 
```

- [ ] **Step 4: Run the tests**

Run: `tests/run`
Expected: `1012 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Movers.lua Core/Settings.lua Units/Party.lua Core/Boot.lua Options/Schema.lua Locales/enUS.lua tests/test_party_layout.lua
git commit -F - <<'EOF'
Party layout settings and a mover for the party block

Orientation, spacing, show player and show when solo drive the header.
Movers take a spec (position keys, size, anchor point, active flag), so
the party block and later detached castbars get handles too.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 6: Portrait element (off / left / right, 2D / 3D)

**Files:**
- Create: `Elements/Portrait.lua`
- Modify: `Core/Settings.lua`, `Core/Layout.lua`, `Units/Single.lua`, `ForeverUnitFrames.toc`, `Options/Schema.lua`, `Locales/enUS.lua`, `tests/mock.lua`
- Test: `tests/test_portrait.lua`

**Interfaces:**
- Consumes: `ns.Single.POLL`, `ns.Secrets.Bool`, `ns.Party.Create`.
- Produces:
  - Settings (every frame): `portraitMode` (`PM`, `OFF`/`LEFT`/`RIGHT`, default `OFF`), `portraitStyle` (`PS`, `2D`/`3D`, default `2D`).
  - `ns.Layout.PortraitInsets(mode, height) -> left, right`.
  - Element `ns.Portrait` (`unitEvents = { "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED" }`), regions `frame.portraitBg`, `frame.portrait2D` (texture), `frame.portrait3D` (`PlayerModel`). `Update` ignores `ns.Single.POLL`.
  - Bars start after / end before the portrait square.
  - Mock: `PlayerModel` methods `SetUnit`, `ClearModel`, `SetPortraitZoom`; `UnitIsVisible` (`d.visible ~= false`); `SetPortraitTexture` records `texture._portraitUnit`.

- [ ] **Step 1: Extend the mock and write the failing test**

```diff
diff --git a/tests/mock.lua b/tests/mock.lua
index 91f9da5..9c6cb87 100644
--- a/tests/mock.lua
+++ b/tests/mock.lua
@@ -256,6 +256,10 @@ local function newWidget(kind, name, parent)
     -- Creation
     function w:CreateTexture(n) return newWidget("Texture", n, self) end
     function w:CreateFontString(n) return newWidget("FontString", n, self) end
+    -- PlayerModel
+    function w:SetUnit(unit) self._modelUnit = unit; return true end
+    function w:ClearModel() self._modelUnit = nil; self._cleared = true end
+    function w:SetPortraitZoom(z) self._zoom = z end
     -- Movable
     function w:SetMovable(v) self._movable = v end
     function w:RegisterForDrag(...) self._drag = { ... } end
@@ -327,6 +331,9 @@ function M.Reset()
     _G.UnitLevel = function(unit) local d = u(unit); return d and d.level or 0 end
     _G.UnitClass = function(unit) local d = u(unit); if d then return d.className, d.class end end
     _G.UnitIsPlayer = function(unit) local d = u(unit); return d and d.isPlayer or false end
+    _G.UnitIsVisible = function(unit) local d = u(unit); return d ~= nil and d.visible ~= false end
+    -- Records the last unit drawn into each texture.
+    _G.SetPortraitTexture = function(texture, unit) texture._portraitUnit = unit end
     _G.UnitIsFriend = function(_, unit) local d = u(unit); return d and d.friend or false end
     _G.UnitReaction = function(unit) local d = u(unit); return d and d.reaction end
     _G.UnitHealth = function(unit) local d = u(unit); return d and d.health or 0 end
```

Create `tests/test_portrait.lua`:

```lua
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local C = ns.Config
local f = ns.Frames.player
M.units.player = { name = "Me", health = 5, healthMax = 10 }

-- Layout maths
H.check("left inset", select(1, ns.Layout.PortraitInsets("LEFT", 40)), 40)
H.check("left: no right inset", select(2, ns.Layout.PortraitInsets("LEFT", 40)), 0)
H.check("right inset", select(2, ns.Layout.PortraitInsets("RIGHT", 40)), 40)
H.check("off: none", select(1, ns.Layout.PortraitInsets("OFF", 40)), 0)

-- Off by default: nothing shown, bars use the full width.
H.check("off: background hidden", f.portraitBg:IsShown(), false)
H.check("off: 2D hidden", f.portrait2D:IsShown(), false)
H.check("off: 3D hidden", f.portrait3D:IsShown(), false)
H.check("off: health from the left edge", select(4, f.health:GetPoint(1)), 0)

-- Left, 2D: a square as tall as the frame; the bars start after it.
C.Set("player", "portraitMode", "LEFT")
H.checkTrue("left: shown", f.portrait2D:IsShown())
H.check("left: 3D hidden", f.portrait3D:IsShown(), false)
H.check("left: square width", f.portraitBg:GetWidth(), 46)
H.check("left: square height", f.portraitBg:GetHeight(), 46)
H.check("left: anchored top left", f.portraitBg:GetPoint(1), "TOPLEFT")
H.check("left: health starts after the portrait", select(4, f.health:GetPoint(1)), 46)
H.check("left: health right edge unchanged", select(4, f.health:GetPoint(2)), 0)
H.check("left: power follows", select(4, f.power:GetPoint(1)), 46)
H.check("left: portrait drawn for the unit", f.portrait2D._portraitUnit, "player")

-- Right: the bars end before it.
C.Set("player", "portraitMode", "RIGHT")
H.check("right: anchored top right", f.portraitBg:GetPoint(1), "TOPRIGHT")
H.check("right: health left edge", select(4, f.health:GetPoint(1)), 0)
H.check("right: health right edge", select(4, f.health:GetPoint(2)), -46)

-- 3D: a model of a visible unit, cleared for one out of sight.
C.Set("player", "portraitStyle", "3D")
H.checkTrue("3D shown", f.portrait3D:IsShown())
H.check("2D hidden", f.portrait2D:IsShown(), false)
H.check("model unit", f.portrait3D._modelUnit, "player")
H.check("model zoom", f.portrait3D._zoom, 1)
M.units.player.visible = false
M.FireEvent("UNIT_MODEL_CHANGED", "player")
H.check("out of sight: model cleared", f.portrait3D._modelUnit, nil)
-- A unit the client refuses (restricted identity) clears too.
M.units.player.visible = true
f.portrait3D._cleared = nil
f.portrait3D.SetUnit = function() error("restricted") end
M.FireEvent("UNIT_PORTRAIT_UPDATE", "player")
H.checkTrue("refused unit: cleared, no error", f.portrait3D._cleared)

-- Timer refreshes (target of target) leave the model alone.
local tot = ns.Frames.targettarget
C.Set("targettarget", "portraitMode", "LEFT")
C.Set("targettarget", "portraitStyle", "3D")
M.units.targettarget = { name = "Tank", health = 1, healthMax = 2 }
M.FireEvent("UNIT_TARGET", "target")
H.check("tot model set on a real change", tot.portrait3D._modelUnit, "targettarget")
tot.portrait3D._modelUnit = "untouched"
M.Tick(0.25)
H.check("poll does not reset the model", tot.portrait3D._modelUnit, "untouched")
H.check("poll still updates health", tot.health:GetValue(), 1)

-- Party buttons get portraits too.
local header = ns.Party.Create()
C.Set("party", "portraitMode", "RIGHT")
M.units.party1 = { name = "Ann", health = 1, healthMax = 2 }
M.SetGroup({ "party1" })
local b = header:GetAttribute("child1")
H.checkTrue("party portrait shown", b.portrait2D:IsShown())
H.check("party portrait unit", b.portrait2D._portraitUnit, "party1")
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`
Expected: FAIL — `ERROR test_portrait.lua:10: attempt to call field 'PortraitInsets' (a nil value)`; summary `1012 passed, 1 failed`.

- [ ] **Step 3: Implement**

Create `Elements/Portrait.lua`:

```lua
local _, ns = ...

-- Unit portrait, off or on the left/right of the frame, as a 2D picture or
-- a 3D model. Takes a square as tall as the frame; the bars make room for
-- it (Layout.PortraitInsets).
local Portrait = { name = "Portrait", unitEvents = { "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED" } }
ns.Portrait = Portrait

local Config, Secrets = ns.Config, ns.Secrets

function Portrait.Build(frame)
    frame.portraitBg = frame:CreateTexture(nil, "BACKGROUND")
    frame.portrait2D = frame:CreateTexture(nil, "ARTWORK")
    frame.portrait2D:SetAllPoints(frame.portraitBg)
    frame.portrait3D = CreateFrame("PlayerModel", nil, frame)
    frame.portrait3D:SetAllPoints(frame.portraitBg)
end

function Portrait.Style(frame)
    local scope = frame.key
    local mode = Config.Get(scope, "portraitMode")
    local threeD = Config.Get(scope, "portraitStyle") == "3D"
    local on = mode ~= "OFF"
    local bg = frame.portraitBg
    bg:ClearAllPoints()
    if on then
        local point = mode == "LEFT" and "TOPLEFT" or "TOPRIGHT"
        local size = Config.Get(scope, "height")
        bg:SetPoint(point, frame, point, 0, 0)
        bg:SetSize(size, size)
        local c = Config.Get(scope, "backgroundColor")
        bg:SetColorTexture(c[1], c[2], c[3], c[4])
    end
    bg:SetShown(on)
    frame.portrait2D:SetShown(on and not threeD)
    frame.portrait3D:SetShown(on and threeD)
end

-- A model is only set for a unit the client can see; otherwise, or when
-- the client refuses the unit (restricted identity), it is cleared.
local function updateModel(model, unit)
    if Secrets.Bool(UnitIsVisible, unit) and pcall(model.SetUnit, model, unit) then
        model:SetPortraitZoom(1)
    else
        model:ClearModel()
    end
end

function Portrait.Update(frame, event)
    -- Timer refreshes only move bars and texts; re-setting a model every
    -- few frames would restart its animation.
    if event == ns.Single.POLL then return end
    local scope = frame.key
    if Config.Get(scope, "portraitMode") == "OFF" then return end
    if Config.Get(scope, "portraitStyle") == "3D" then
        updateModel(frame.portrait3D, frame.unit)
    else
        pcall(SetPortraitTexture, frame.portrait2D, frame.unit)
    end
end

ns.RegisterElement(Portrait)
```

```diff
diff --git a/Core/Layout.lua b/Core/Layout.lua
index af03f75..ed6e05a 100644
--- a/Core/Layout.lua
+++ b/Core/Layout.lua
@@ -21,3 +21,11 @@ function Layout.Bars(height, healthPercent, powerPercent, powerEnabled)
     healthH = math.max(1, healthH)
     return healthH, height - healthH - powerH, powerH
 end
+
+-- Space the portrait takes from the bars: a square as tall as the frame,
+-- on the left or the right. Returns left inset, right inset.
+function Layout.PortraitInsets(mode, height)
+    if mode == "LEFT" then return height, 0 end
+    if mode == "RIGHT" then return 0, height end
+    return 0, 0
+end
```

```diff
diff --git a/Units/Single.lua b/Units/Single.lua
index 8d47a51..a8d314a 100644
--- a/Units/Single.lua
+++ b/Units/Single.lua
@@ -26,14 +26,15 @@ local function layoutBars(frame)
     local powerOn = Config.Get(scope, "powerEnabled")
     local hh, gap, ph = Layout.Bars(height, Config.Get(scope, "healthPercent"),
         Config.Get(scope, "powerPercent"), powerOn)
+    local left, right = Layout.PortraitInsets(Config.Get(scope, "portraitMode"), height)
     frame.health:ClearAllPoints()
-    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
-    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
+    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", left, 0)
+    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, 0)
     frame.health:SetHeight(hh)
     if frame.power then
         frame.power:ClearAllPoints()
-        frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
-        frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
+        frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, 0)
+        frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -right, 0)
         frame.power:SetHeight(math.max(ph, 1))
         frame.power:SetShown(powerOn and ph > 0)
     end
```

```diff
diff --git a/Core/Settings.lua b/Core/Settings.lua
index 5a264f0..52ac7af 100644
--- a/Core/Settings.lua
+++ b/Core/Settings.lua
@@ -115,6 +115,12 @@ Settings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4
 Settings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000,
     default = { player = -220, target = -220, targettarget = -220, pet = -272, focus = -120, party = 120, _ = 0 } })
 
+-- Portrait
+Settings.Define({ key = "portraitMode", code = "PM", scope = "frame", type = "enum",
+    values = { "OFF", "LEFT", "RIGHT" }, default = "OFF" })
+Settings.Define({ key = "portraitStyle", code = "PS", scope = "frame", type = "enum",
+    values = { "2D", "3D" }, default = "2D" })
+
 -- Party block (party only)
 local PARTY = { party = true }
 Settings.Define({ key = "partyOrientation", code = "OR", scope = "frame", only = PARTY, type = "enum",
```

```diff
diff --git a/ForeverUnitFrames.toc b/ForeverUnitFrames.toc
index 929ed04..91eb7a0 100644
--- a/ForeverUnitFrames.toc
+++ b/ForeverUnitFrames.toc
@@ -19,6 +19,7 @@ Units\Units.lua
 Elements\Health.lua
 Elements\Power.lua
 Elements\Texts.lua
+Elements\Portrait.lua
 Units\Events.lua
 Units\Single.lua
 Units\Party.lua
```

```diff
diff --git a/Options/Schema.lua b/Options/Schema.lua
index bfe2ea1..073877f 100644
--- a/Options/Schema.lua
+++ b/Options/Schema.lua
@@ -19,6 +19,7 @@ Schema.FRAME = {
         { id = "frame", keys = { "enabled" } },
         { id = "size", keys = { "width", "height" } },
         { id = "barHeights", keys = { "healthPercent", "powerPercent", "powerEnabled" } },
+        { id = "portrait", keys = { "portraitMode", "portraitStyle" } },
         { id = "group", keys = { "partyOrientation", "partySpacing", "partyShowPlayer", "partyShowSolo" } },
         { id = "position", keys = { "x", "y" } },
     } },
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index 8e58f84..3d3243b 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -25,6 +25,8 @@ L.SETTING_powerPercent = "Power bar height (%)"
 L.SETTING_powerEnabled = "Show power bar"
 L.SETTING_x = "Position X"
 L.SETTING_y = "Position Y"
+L.SETTING_portraitMode = "Portrait"
+L.SETTING_portraitStyle = "Portrait style"
 L.SETTING_partyOrientation = "Orientation"
 L.SETTING_partySpacing = "Spacing"
 L.SETTING_partyShowPlayer = "Show player"
@@ -74,6 +76,7 @@ L.SECTION_health = "Health bar"; L.SECTION_frame = "Frame"; L.SECTION_size = "Si
 L.SECTION_barHeights = "Bar heights"; L.SECTION_position = "Position"
 L.SECTION_textures = "Textures"; L.SECTION_healthText = "Health bar text"
 L.SECTION_powerText = "Power bar text"
+L.SECTION_portrait = "Portrait"
 L.SECTION_group = "Party layout"
 L.HINT_healthPercent = "Share of the frame height"
 L.HINT_powerPercent = "Share of the frame height; the rest becomes the gap"
@@ -88,6 +91,8 @@ L.ENUM_NAME = "Name"; L.ENUM_NAME_LEVEL = "Level and name"; L.ENUM_LEVEL = "Leve
 L.ENUM_CURRENT = "Current"; L.ENUM_CURRENT_MAX = "Current / max"; L.ENUM_PERCENT = "Percent"
 L.ENUM_DEFICIT = "Deficit"
 L.ENUM_VERTICAL = "Vertical"; L.ENUM_HORIZONTAL = "Horizontal"
+L.ENUM_OFF = "Off"; L.ENUM_LEFT = "Left"; L.ENUM_RIGHT = "Right"
+L.ENUM_2D = "2D"; L.ENUM_3D = "3D (model)"
 L.ENUM_fontOutline_NONE = "None"
 L.ENUM_textHealthLeft_NONE = "Empty"
 
```

- [ ] **Step 4: Run the tests**

Run: `tests/run`
Expected: `1059 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Elements/Portrait.lua Core/Layout.lua Units/Single.lua Core/Settings.lua ForeverUnitFrames.toc Options/Schema.lua Locales/enUS.lua tests/mock.lua tests/test_portrait.lua
git commit -F - <<'EOF'
Add portraits: off, left or right, 2D or 3D

A square as tall as the frame; the bars make room for it. The 3D model
is set only for visible units, cleared when the client refuses the
unit, and left alone by timer refreshes.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 7: Castbar element (casts, channels, secret-safe), docked below

**Files:**
- Create: `Elements/Castbar.lua`
- Modify: `Core/Settings.lua`, `Units/Single.lua`, `ForeverUnitFrames.toc`, `Options/Schema.lua`, `Locales/enUS.lua`, `tests/mock.lua`, `tests/test_schema.lua`
- Test: `tests/test_castbar.lua`

**Interfaces:**
- Consumes: `ns.UnitEvents` (castGUID as the 4th `Update` argument), `ns.Secrets.Number`, `GetTime`, `ns.Single.DrawBorder`.
- Produces:
  - Settings (player, target, targettarget, focus, party; not pet): `castbarEnabled` (`CE`, default false for player, true otherwise), `castbarHeight` (`CH`, 4–60, `{ player 18, target 16, focus 16, _ 12 }`), `castbarIcon` (`CI`), `castbarName` (`CN`), `castbarTime` (`CT`), all default true.
  - `ns.Single.DrawBorder(owner, scope)` — the border helper, now usable for castbars.
  - Element `ns.Castbar` with `CAST_COLOR`, `CHANNEL_COLOR`, `Applies(scope)`, `Gap(scope)`, `Begin(bar, unit, channel, castGUID) -> bool`, `Refresh(bar, unit)`, `Stop(bar)`, `IsOtherCast(bar, castGUID) -> bool`, `UpdateTime(bar, nowMs?)`, `OnUpdate(bar)`; `frame.castbar` (StatusBar child of the frame) with `.bg`, `.icon`, `.text`, `.time`, `.cast = { startMs, endMs, channel, guid, duration }`.
  - Schema tab `castbar` (after `text`) with sections `castbar`, `castbarContent`.
  - Mock: `SetReverseFill`; `UnitCastingInfo` / `UnitChannelInfo` from `d.cast` / `d.channel` in the client's return order; `UnitCastingDuration` / `UnitChannelDuration` return `d.castDuration`.

- [ ] **Step 1: Extend the mock and write the failing tests**

```diff
diff --git a/tests/mock.lua b/tests/mock.lua
index 9c6cb87..36f8f45 100644
--- a/tests/mock.lua
+++ b/tests/mock.lua
@@ -182,6 +182,7 @@ local function newWidget(kind, name, parent)
     function w:SetStatusBarTexture(t) self._texture = t end
     function w:SetStatusBarColor(r, g, b, a) self._color = { r, g, b, a } end
     function w:GetStatusBarTexture() return self._barTex end
+    function w:SetReverseFill(v) self._reverse = v end
     -- Texture
     function w:SetTexture(t) self._texture = t end
     function w:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
@@ -352,6 +353,19 @@ function M.Reset()
         if curve then return curve:Evaluate(p) end
         return p
     end
+    -- Casts: d.cast / d.channel hold the values UnitCastingInfo /
+    -- UnitChannelInfo return, in the client's order; d.castDuration the
+    -- object UnitCastingDuration / UnitChannelDuration return.
+    _G.UnitCastingInfo = function(unit)
+        local d = u(unit); local c = d and d.cast
+        if c then return c.name, c.name, c.texture, c.startMs, c.endMs, false, c.castID, c.notInterruptible, 1 end
+    end
+    _G.UnitChannelInfo = function(unit)
+        local d = u(unit); local c = d and d.channel
+        if c then return c.name, c.name, c.texture, c.startMs, c.endMs, false, c.notInterruptible, 1 end
+    end
+    _G.UnitCastingDuration = function(unit) local d = u(unit); return d and d.castDuration end
+    _G.UnitChannelDuration = function(unit) local d = u(unit); return d and d.castDuration end
     _G.C_StringUtil = { TruncateWhenZero = function(n) return n end }
     _G.UnitPowerMissing = function(unit) local d = u(unit); return d and d.powerMissing or 0 end
 
```

Create `tests/test_castbar.lua`:

```lua
local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config

-- Which frames have a castbar, and the player's is off by default.
for _, scope in ipairs({ "player", "target", "targettarget", "focus", "party" }) do
    H.checkTrue("castbar on " .. scope, S.AppliesTo(S.Get("castbarEnabled"), scope))
end
H.check("no castbar on the pet", S.AppliesTo(S.Get("castbarEnabled"), "pet"), false)
C.Use({})
H.check("player castbar off by default", C.Get("player", "castbarEnabled"), false)
H.checkTrue("target castbar on by default", C.Get("target", "castbarEnabled"))

ns.Single.CreateAll()
local t = ns.Frames.target
local bar = t.castbar
H.checkTrue("target has a castbar", bar)
H.check("pet has none", ns.Frames.pet.castbar, nil)
H.check("hidden while idle", bar:IsShown(), false)
H.check("parented to the frame", bar:GetParent(), t)

-- Docked below the frame, the icon to its left, room for both borders.
local point, rel, relPoint, x, y = bar:GetPoint(1)
H.check("docked below: point", point, "TOPLEFT")
H.check("docked below: to the frame", rel, t)
H.check("docked below: frame bottom", relPoint, "BOTTOMLEFT")
H.check("icon inset", x, 16)
H.check("gap", y, -4)
H.check("height", bar:GetHeight(), 16)
H.check("icon size", bar.icon:GetWidth(), 16)
C.Set("target", "castbarIcon", false)
H.check("no icon: no inset", select(4, bar:GetPoint(1)), 0)
H.check("icon hidden", bar.icon:IsShown(), false)
C.Set("target", "castbarIcon", true)

-- A readable cast.
M.units.target = { name = "Foe", health = 1, healthMax = 1,
    cast = { name = "Fireball", texture = 135812, startMs = 1000000, endMs = 1002500 } }
M.FireEvent("UNIT_SPELLCAST_START", "target", "cast-1", 133)
H.checkTrue("shown on start", bar:IsShown())
local lo, hi = bar:GetMinMaxValues()
H.check("range start", lo, 1000000)
H.check("range end", hi, 1002500)
H.check("value is the clock", bar:GetValue(), 1000000)
H.check("name", bar.text:GetText(), "Fireball")
H.check("icon", bar.icon._texture, 135812)
H.check("cast colour", bar._color[1], ns.Castbar.CAST_COLOR[1])
H.check("fills left to right", bar._reverse, false)
H.check("time text", bar.time._args[1], 2.5)
M.Tick(1)
H.check("value follows the clock", bar:GetValue(), 1001000)
H.check("time counts down", bar.time._args[1], 1.5)

-- A late stop for an earlier cast leaves the new one alone.
M.FireEvent("UNIT_SPELLCAST_STOP", "target", "cast-0", 133)
H.checkTrue("other cast's stop ignored", bar:IsShown())
-- Its own stop, with the cast over: hidden.
M.units.target.cast = nil
M.FireEvent("UNIT_SPELLCAST_STOP", "target", "cast-1", 133)
H.check("own stop hides", bar:IsShown(), false)

-- Secret cast: everything passes straight through, nothing is computed.
local name, startMs, endMs = M.Secret("Shadow Bolt"), M.Secret(2000000), M.Secret(2003000)
M.units.target.cast = { name = name, texture = M.Secret(136197), startMs = startMs, endMs = endMs }
M.FireEvent("UNIT_SPELLCAST_START", "target", M.Secret("guid-a"), 686)
H.checkTrue("secret cast shown", bar:IsShown())
lo, hi = bar:GetMinMaxValues()
H.check("secret start passed through", lo, startMs)
H.check("secret end passed through", hi, endMs)
H.check("secret name passed through", bar.text:GetText(), name)
M.Tick(0.5)
H.check("secret: time left empty without a duration", bar.time:GetText(), "")
H.checkTrue("secret: still shown after ticks", bar:IsShown())
-- Secret GUIDs cannot be compared: the client is asked instead.
M.FireEvent("UNIT_SPELLCAST_STOP", "target", M.Secret("guid-a"), 686)
H.checkTrue("uncomparable stop, still casting: kept", bar:IsShown())
M.units.target.cast = nil
M.FireEvent("UNIT_SPELLCAST_STOP", "target", M.Secret("guid-a"), 686)
H.check("uncomparable stop, cast over: hidden", bar:IsShown(), false)

-- A duration object shows the time even when the end is secret.
local remaining = M.Secret(1.2)
M.units.target.cast = { name = name, startMs = startMs, endMs = endMs }
M.units.target.castDuration = { GetRemainingDuration = function() return remaining end }
M.FireEvent("UNIT_SPELLCAST_START", "target", "guid-b", 686)
H.check("duration: secret seconds passed through", bar.time._args[1], remaining)
-- A secret duration object refuses to be asked: empty, no error.
M.units.target.castDuration = M.Secret({})
M.FireEvent("UNIT_SPELLCAST_START", "target", "guid-c", 686)
H.check("secret duration object: empty", bar.time:GetText(), "")
M.units.target.cast, M.units.target.castDuration = nil, nil
M.FireEvent("UNIT_SPELLCAST_FAILED", "target", "guid-c", 686)
H.check("failed: hidden", bar:IsShown(), false)

-- Channels drain from the right and end on their own stop.
M.units.target.channel = { name = "Drain Life", texture = 1, startMs = 1001000, endMs = 1006000 }
M.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "target", "c-1", 689)
H.checkTrue("channel shown", bar:IsShown())
H.check("channel colour", bar._color[2], ns.Castbar.CHANNEL_COLOR[2])
H.check("channel fills from the right", bar._reverse, true)
M.FireEvent("UNIT_SPELLCAST_STOP", "target", "x", 1)
H.checkTrue("a cast stop does not end a running channel", bar:IsShown())
M.units.target.channel = nil
M.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target", "c-1", 689)
H.check("channel stop hides", bar:IsShown(), false)

-- A missed stop: a readable end time in the past ends the bar.
M.units.target.cast = { name = "Heal", startMs = 1001000, endMs = 1001500 }
M.FireEvent("UNIT_SPELLCAST_START", "target", "h-1", 2050)
M.Tick(1)
H.check("past a readable end: hidden", bar:IsShown(), false)

-- A new target that is already casting shows its cast at once.
M.units.target.cast = { name = "Frostbolt", startMs = 1001000, endMs = 1004000 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("new target mid-cast", bar:IsShown())
H.check("new target cast name", bar.text:GetText(), "Frostbolt")

-- Disabled: never shown.
C.Set("target", "castbarEnabled", false)
H.check("disabled: hidden", bar:IsShown(), false)
M.FireEvent("UNIT_SPELLCAST_START", "target", "f-2", 116)
H.check("disabled: ignores casts", bar:IsShown(), false)

-- Name and time can be switched off.
C.Set("target", "castbarEnabled", true)
C.Set("target", "castbarName", false)
C.Set("target", "castbarTime", false)
H.check("name hidden", bar.text:IsShown(), false)
H.check("time hidden", bar.time:IsShown(), false)

-- The player's own castbar once switched on.
C.Set("player", "castbarEnabled", true)
local pbar = ns.Frames.player.castbar
M.units.player = { name = "Me", health = 1, healthMax = 1,
    cast = { name = "Hearthstone", startMs = 1001000, endMs = 1011000 } }
M.FireEvent("UNIT_SPELLCAST_START", "player", "p-1", 8690)
H.checkTrue("player castbar", pbar:IsShown())
H.check("target castbar unaffected by player cast", bar:IsShown(), true)

-- Target of target has no cast events: the timer picks casts up.
local tot = ns.Frames.targettarget
M.units.targettarget = { name = "Tank", health = 1, healthMax = 1,
    cast = { name = "Taunt", startMs = 1002000, endMs = 1020000 } }
M.Tick(0.25)
H.checkTrue("tot cast found by the timer", tot.castbar:IsShown())
M.units.targettarget.cast = nil
M.Tick(0.25)
H.check("tot cast gone on the next tick", tot.castbar:IsShown(), false)

-- Party members have castbars, fed by their own unit's events.
local header = ns.Party.Create()
M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
M.SetGroup({ "party1" })
local member = header:GetAttribute("child1")
H.checkTrue("party castbar built", member.castbar)
M.units.party1.cast = { name = "Renew", startMs = 1002000, endMs = 1020000 }
M.FireEvent("UNIT_SPELLCAST_START", "party1", "r-1", 139)
H.checkTrue("party castbar shown", member.castbar:IsShown())
```

The pet has no castbar tab:

```diff
diff --git a/tests/test_schema.lua b/tests/test_schema.lua
index 8f4eb74..eb8972f 100644
--- a/tests/test_schema.lua
+++ b/tests/test_schema.lua
@@ -33,5 +33,7 @@ for _, def in ipairs(Settings.All()) do
 end
 
 H.check("general has profile tab", S.Tabs("general")[3].id, "profile")
-H.check("frame tab count", #S.Tabs("player"), 3)
+H.check("frame tab count", #S.Tabs("player"), 4)
+H.check("castbar tab on frames with a castbar", S.Tabs("player")[4].id, "castbar")
+H.check("no castbar tab for the pet", #S.Tabs("pet"), 3)
 H.check("key-specific enum text wins", S.EnumText(Settings.Get("textHealthLeft"), "NONE"), "Empty")
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`
Expected: FAIL — `ERROR .../Core/Settings.lua:43: attempt to index local 'def' (a nil value)`, `FAIL frame tab count -> 3 (want 4)`; summary `1057 passed, 3 failed`.

- [ ] **Step 3: Implement**

Create `Elements/Castbar.lua`:

```lua
local _, ns = ...

-- Castbar of a unit frame, docked below it.
--
-- Another unit's cast can arrive as secret values: name, icon, start and
-- end time. They are only ever handed to widgets: the bar's range is the
-- raw start and end (milliseconds), its value the clock, which is ours.
-- Whether anything is being cast is asked with type(), never by truth: a
-- secret cannot be tested. A stop event ends the bar only after asking
-- the client what the unit is doing now, so a late stop for an earlier
-- cast cannot wipe a new one; castGUIDs are compared only when the client
-- allows it.
local Castbar = {
    name = "Castbar",
    unitEvents = {
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
        "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
    },
}
ns.Castbar = Castbar

local Config, Secrets, Settings = ns.Config, ns.Secrets, ns.Settings

Castbar.CAST_COLOR = { 1.0, 0.7, 0.0 }
Castbar.CHANNEL_COLOR = { 0.3, 0.8, 0.3 }

local STOP_EVENTS = {
    UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
}

function Castbar.Applies(scope)
    return Settings.AppliesTo(Settings.Get("castbarEnabled"), scope)
end

-- Gap between frame and castbar: room for both borders.
function Castbar.Gap(scope)
    return 2 * Config.Get(scope, "borderSize") + 2
end

local function now() return GetTime() * 1000 end

local function read(unit, channel)
    if channel then return { UnitChannelInfo(unit) } end
    return { UnitCastingInfo(unit) }
end

-- The duration object of the running cast, when the client has one.
local function durationOf(unit, channel)
    local fn = channel and UnitChannelDuration or UnitCastingDuration
    if not fn then return nil end
    local ok, duration = pcall(fn, unit)
    if ok then return duration end
    return nil
end

local function showRemaining(fontString, duration)
    fontString:SetFormattedText("%.1f", duration:GetRemainingDuration())
end

-- Seconds left: computed when the end time is readable, otherwise asked
-- of the duration object (guarded), otherwise left empty.
function Castbar.UpdateTime(bar, nowMs)
    local cast = bar.cast
    if not cast or not bar.time:IsShown() then return end
    local endMs = Secrets.Number(cast.endMs)
    if endMs then
        bar.time:SetFormattedText("%.1f", math.max(0, (endMs - (nowMs or now())) / 1000))
    elseif not (cast.duration ~= nil and pcall(showRemaining, bar.time, cast.duration)) then
        bar.time:SetText("")
    end
end

function Castbar.Stop(bar)
    bar.cast = nil
    bar:Hide()
end

-- Puts the unit's current cast (or channel) on the bar. Returns false
-- when the unit is not casting (channelling) at all.
function Castbar.Begin(bar, unit, channel, castGUID)
    local info = read(unit, channel)
    if type(info[1]) == "nil" then return false end
    bar.cast = { startMs = info[4], endMs = info[5], channel = channel, guid = castGUID,
        duration = durationOf(unit, channel) }
    bar:SetMinMaxValues(info[4], info[5])
    bar:SetReverseFill(channel)
    local c = channel and Castbar.CHANNEL_COLOR or Castbar.CAST_COLOR
    bar:SetStatusBarColor(c[1], c[2], c[3])
    bar.text:SetText(info[1])
    bar.icon:SetTexture(info[3])
    bar:SetValue(now())
    Castbar.UpdateTime(bar)
    bar:Show()
    return true
end

-- Whatever the unit is doing now: a cast, a channel, or nothing.
function Castbar.Refresh(bar, unit)
    if not Castbar.Begin(bar, unit, false) and not Castbar.Begin(bar, unit, true) then
        Castbar.Stop(bar)
    end
end

-- True only when the stop provably belongs to another cast. Comparing may
-- be refused (secret GUIDs); then nothing is known and the caller asks the
-- client instead.
function Castbar.IsOtherCast(bar, castGUID)
    local cast = bar.cast
    if not cast or type(castGUID) == "nil" or type(cast.guid) == "nil" then return false end
    local ok, same = pcall(function() return castGUID == cast.guid end)
    return ok and not same
end

function Castbar.OnUpdate(bar)
    local cast = bar.cast
    if not cast then return end
    local nowMs = now()
    bar:SetValue(nowMs)
    local endMs = Secrets.Number(cast.endMs)
    if endMs and nowMs >= endMs then
        -- The stop event went missing; a readable end time is proof enough.
        Castbar.Stop(bar)
        return
    end
    Castbar.UpdateTime(bar, nowMs)
end

function Castbar.Build(frame)
    if not Castbar.Applies(frame.key) then return end
    local bar = CreateFrame("StatusBar", nil, frame)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.time = bar:CreateFontString(nil, "OVERLAY")
    bar:SetScript("OnUpdate", Castbar.OnUpdate)
    bar:Hide()
    frame.castbar = bar
end

-- The icon sits left of the bar, inside the castbar's own rectangle.
local function anchor(bar, frame, scope, inset)
    local gap = Castbar.Gap(scope)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", inset, -gap)
    bar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -gap)
end

function Castbar.Style(frame)
    local bar = frame.castbar
    if not bar then return end
    local scope = frame.key
    local height = Config.Get(scope, "castbarHeight")
    local showIcon = Config.Get(scope, "castbarIcon")
    anchor(bar, frame, scope, showIcon and height or 0)
    bar:SetHeight(height)
    local tex = ns.Media.StatusBar(Config.Get(scope, "barTexture"))
    bar:SetStatusBarTexture(tex)
    bar.bg:SetTexture(tex)
    local bg = Config.Get(scope, "backgroundColor")
    bar.bg:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    ns.Single.DrawBorder(bar, scope)
    bar.icon:ClearAllPoints()
    bar.icon:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
    bar.icon:SetSize(height, height)
    bar.icon:SetShown(showIcon)
    local font = ns.Media.Font(Config.Get(scope, "fontFace"))
    local outline = Config.Get(scope, "fontOutline")
    local flags = (outline == "NONE") and "" or outline
    local fontSize = math.min(Config.Get(scope, "fontSize"), height)
    for _, fs in ipairs({ bar.text, bar.time }) do fs:SetFont(font, fontSize, flags) end
    bar.text:ClearAllPoints()
    bar.text:SetPoint("LEFT", bar, "LEFT", 4, 0)
    bar.text:SetJustifyH("LEFT")
    bar.text:SetShown(Config.Get(scope, "castbarName"))
    bar.time:ClearAllPoints()
    bar.time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.time:SetJustifyH("RIGHT")
    bar.time:SetShown(Config.Get(scope, "castbarTime"))
    if not Config.Get(scope, "castbarEnabled") then Castbar.Stop(bar) end
end

function Castbar.Update(frame, event, _, castGUID)
    local bar = frame.castbar
    if not bar then return end
    if not Config.Get(frame.key, "castbarEnabled") then
        Castbar.Stop(bar)
        return
    end
    local unit = frame.unit
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
        if not Castbar.Begin(bar, unit, false, castGUID) then Castbar.Stop(bar) end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if not Castbar.Begin(bar, unit, true) then Castbar.Stop(bar) end
    elseif STOP_EVENTS[event] then
        if not Castbar.IsOtherCast(bar, castGUID) then Castbar.Refresh(bar, unit) end
    else
        -- The unit itself changed (new target, timer): start over.
        Castbar.Refresh(bar, unit)
    end
end

ns.RegisterElement(Castbar)
```

Make the border helper public for the castbar:

```diff
diff --git a/Units/Single.lua b/Units/Single.lua
index a8d314a..13ce504 100644
--- a/Units/Single.lua
+++ b/Units/Single.lua
@@ -41,19 +41,21 @@ local function layoutBars(frame)
     frame.gap = gap
 end
 
-local function border(frame)
-    local size = Config.Get(frame.key, "borderSize")
-    local c = Config.Get(frame.key, "borderColor")
-    if not frame.border then
-        frame.border = {}
-        for i = 1, 4 do frame.border[i] = frame:CreateTexture(nil, "OVERLAY") end
+-- A 1-2 px border just outside owner (a unit frame or its castbar), in the
+-- border size and colour of scope.
+function Single.DrawBorder(owner, scope)
+    local size = Config.Get(scope, "borderSize")
+    local c = Config.Get(scope, "borderColor")
+    if not owner.border then
+        owner.border = {}
+        for i = 1, 4 do owner.border[i] = owner:CreateTexture(nil, "OVERLAY") end
     end
-    local b = frame.border
-    -- top, bottom, left, right; drawn just outside the frame
-    b[1]:ClearAllPoints(); b[1]:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -size, 0); b[1]:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", size, 0); b[1]:SetHeight(size)
-    b[2]:ClearAllPoints(); b[2]:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -size, 0); b[2]:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", size, 0); b[2]:SetHeight(size)
-    b[3]:ClearAllPoints(); b[3]:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0); b[3]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0); b[3]:SetWidth(size)
-    b[4]:ClearAllPoints(); b[4]:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0); b[4]:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0); b[4]:SetWidth(size)
+    local b = owner.border
+    -- top, bottom, left, right; drawn just outside the owner
+    b[1]:ClearAllPoints(); b[1]:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", -size, 0); b[1]:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", size, 0); b[1]:SetHeight(size)
+    b[2]:ClearAllPoints(); b[2]:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", -size, 0); b[2]:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", size, 0); b[2]:SetHeight(size)
+    b[3]:ClearAllPoints(); b[3]:SetPoint("TOPRIGHT", owner, "TOPLEFT", 0, 0); b[3]:SetPoint("BOTTOMRIGHT", owner, "BOTTOMLEFT", 0, 0); b[3]:SetWidth(size)
+    b[4]:ClearAllPoints(); b[4]:SetPoint("TOPLEFT", owner, "TOPRIGHT", 0, 0); b[4]:SetPoint("BOTTOMLEFT", owner, "BOTTOMRIGHT", 0, 0); b[4]:SetWidth(size)
     for i = 1, 4 do
         b[i]:SetColorTexture(c[1], c[2], c[3], c[4])
         b[i]:SetShown(size > 0)
@@ -78,7 +80,7 @@ end
 -- border, element regions. Party buttons use this in combat too.
 function Single.StyleContent(frame)
     layoutBars(frame)
-    border(frame)
+    Single.DrawBorder(frame, frame.key)
     for _, el in ipairs(ns.Elements) do el.Style(frame) end
 end
 
```

```diff
diff --git a/Core/Settings.lua b/Core/Settings.lua
index 52ac7af..b0884d5 100644
--- a/Core/Settings.lua
+++ b/Core/Settings.lua
@@ -129,6 +129,16 @@ Settings.Define({ key = "partySpacing", code = "GS", scope = "frame", only = PAR
 Settings.Define({ key = "partyShowPlayer", code = "SP", scope = "frame", only = PARTY, type = "bool", default = false })
 Settings.Define({ key = "partyShowSolo", code = "SO", scope = "frame", only = PARTY, type = "bool", default = false })
 
+-- Castbar (not on the pet frame; off by default on the player frame)
+local CASTBAR = { player = true, target = true, targettarget = true, focus = true, party = true }
+Settings.Define({ key = "castbarEnabled", code = "CE", scope = "frame", only = CASTBAR, type = "bool",
+    default = { player = false, _ = true } })
+Settings.Define({ key = "castbarHeight", code = "CH", scope = "frame", only = CASTBAR, type = "int", min = 4, max = 60,
+    default = { player = 18, target = 16, focus = 16, _ = 12 } })
+Settings.Define({ key = "castbarIcon", code = "CI", scope = "frame", only = CASTBAR, type = "bool", default = true })
+Settings.Define({ key = "castbarName", code = "CN", scope = "frame", only = CASTBAR, type = "bool", default = true })
+Settings.Define({ key = "castbarTime", code = "CT", scope = "frame", only = CASTBAR, type = "bool", default = true })
+
 -- Texts
 Settings.Define({ key = "textHealthLeft", code = "TL", scope = "frame", type = "enum", values = TEXT_TAGS,
     default = { player = "NAME_LEVEL", target = "NAME_LEVEL", _ = "NAME" } })
```

```diff
diff --git a/ForeverUnitFrames.toc b/ForeverUnitFrames.toc
index 91eb7a0..daf31e0 100644
--- a/ForeverUnitFrames.toc
+++ b/ForeverUnitFrames.toc
@@ -20,6 +20,7 @@ Elements\Health.lua
 Elements\Power.lua
 Elements\Texts.lua
 Elements\Portrait.lua
+Elements\Castbar.lua
 Units\Events.lua
 Units\Single.lua
 Units\Party.lua
```

```diff
diff --git a/Options/Schema.lua b/Options/Schema.lua
index 073877f..699efbf 100644
--- a/Options/Schema.lua
+++ b/Options/Schema.lua
@@ -33,6 +33,10 @@ Schema.FRAME = {
         { id = "powerText", keys = { "textPowerLeft", "textPowerRight" } },
         { id = "font", keys = { "fontFace", "fontSize", "fontOutline", "fontShadow" } },
     } },
+    { id = "castbar", sections = {
+        { id = "castbar", keys = { "castbarEnabled", "castbarHeight" } },
+        { id = "castbarContent", keys = { "castbarIcon", "castbarName", "castbarTime" } },
+    } },
 }
 
 local function applicable(tab, scope)
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index 3d3243b..95a916a 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -27,6 +27,11 @@ L.SETTING_x = "Position X"
 L.SETTING_y = "Position Y"
 L.SETTING_portraitMode = "Portrait"
 L.SETTING_portraitStyle = "Portrait style"
+L.SETTING_castbarEnabled = "Show castbar"
+L.SETTING_castbarHeight = "Castbar height"
+L.SETTING_castbarIcon = "Spell icon"
+L.SETTING_castbarName = "Spell name"
+L.SETTING_castbarTime = "Cast time"
 L.SETTING_partyOrientation = "Orientation"
 L.SETTING_partySpacing = "Spacing"
 L.SETTING_partyShowPlayer = "Show player"
@@ -70,7 +75,7 @@ L.FOCUS_AVAILABLE = "available"
 L.FOCUS_MISSING = "not supported by this client"
 
 L.TAB_appearance = "Appearance"; L.TAB_colors = "Colors"; L.TAB_profile = "Profile"
-L.TAB_layout = "Layout"; L.TAB_bars = "Bars"; L.TAB_text = "Text"
+L.TAB_layout = "Layout"; L.TAB_bars = "Bars"; L.TAB_text = "Text"; L.TAB_castbar = "Castbar"
 L.SECTION_font = "Font"; L.SECTION_bars = "Bars"; L.SECTION_border = "Border"
 L.SECTION_health = "Health bar"; L.SECTION_frame = "Frame"; L.SECTION_size = "Size"
 L.SECTION_barHeights = "Bar heights"; L.SECTION_position = "Position"
@@ -78,6 +83,8 @@ L.SECTION_textures = "Textures"; L.SECTION_healthText = "Health bar text"
 L.SECTION_powerText = "Power bar text"
 L.SECTION_portrait = "Portrait"
 L.SECTION_group = "Party layout"
+L.SECTION_castbar = "Castbar"
+L.SECTION_castbarContent = "Shown on the bar"
 L.HINT_healthPercent = "Share of the frame height"
 L.HINT_powerPercent = "Share of the frame height; the rest becomes the gap"
 L.HINT_x = "Offset from the screen centre"
```

- [ ] **Step 4: Run the tests**

Run: `tests/run`
Expected: `1152 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Elements/Castbar.lua Units/Single.lua Core/Settings.lua ForeverUnitFrames.toc Options/Schema.lua Locales/enUS.lua tests/mock.lua tests/test_castbar.lua tests/test_schema.lua
git commit -F - <<'EOF'
Add castbars for player, target, target of target, focus and party

Raw start/end times go to the bar, the clock is the value; presence is
tested with type(). A stop ends the bar only after asking the client
what the unit casts now, unless its castGUID provably belongs to an
earlier cast. Off by default on the player frame.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 8: Castbar above / below / detached with its own mover

**Files:**
- Modify: `Elements/Castbar.lua`, `Core/Settings.lua`, `Core/Boot.lua`, `Options/Schema.lua`, `Locales/enUS.lua`
- Test: `tests/test_castbar_place.lua`

**Interfaces:**
- Consumes: generic `ns.Movers.Attach(target, spec)` / `Sync` from Task 5.
- Produces:
  - Settings: `castbarPosition` (`CP`, `BELOW`/`ABOVE`/`DETACHED`, default `BELOW`; player, target, targettarget, focus), `castbarDock` (`CD`, `BELOW`/`ABOVE`, default `BELOW`; party only), `castbarX` (`CX`) / `castbarY` (`CY`) (−4000…4000; single frames; defaults x `{ target 300, targettarget 480, focus -300, _ 0 }`, y `{ player -160, focus -170, _ -300 }`).
  - `Castbar.Placement(scope) -> "BELOW" | "ABOVE" | "DETACHED"`, `Castbar.MoverSpec(frame) -> spec` (id `castbar:<key>`, keys `castbarX`/`castbarY`, `anchor = false`, active only while enabled + detached), `Castbar.AttachMover(frame)` (single frames only).
  - Boot attaches castbar movers after the frame movers.
  - Schema: castbar section gains `castbarPosition`, `castbarDock`; new section `castbarDetached` (`castbarX`, `castbarY`).

- [ ] **Step 1: Write the failing test**

Create `tests/test_castbar_place.lua`:

```lua
local M = H.M
local ns = H.LoadAddon()
local S = ns.Settings

H.checkTrue("position on single frames", S.AppliesTo(S.Get("castbarPosition"), "focus"))
H.check("no detached party castbars", S.AppliesTo(S.Get("castbarPosition"), "party"), false)
H.checkTrue("party docks", S.AppliesTo(S.Get("castbarDock"), "party"))
H.check("dock is party only", S.AppliesTo(S.Get("castbarDock"), "target"), false)
H.check("detached X not on party", S.AppliesTo(S.Get("castbarX"), "party"), false)

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
local t = ns.Frames.target
local bar = t.castbar

-- Above the frame.
C.Set("target", "castbarPosition", "ABOVE")
local point, rel, relPoint, x, y = bar:GetPoint(1)
H.check("above: bar bottom", point, "BOTTOMLEFT")
H.check("above: to the frame top", relPoint, "TOPLEFT")
H.check("above: to the frame", rel, t)
H.check("above: icon inset", x, 16)
H.check("above: gap", y, 4)

-- Detached: anchored to its own mover, which X / Y place.
H.checkTrue("detachable castbar has a mover", bar.mover)
C.Set("target", "castbarPosition", "DETACHED")
point, rel = bar:GetPoint(1)
H.check("detached: to its mover", rel, bar.mover)
H.check("detached: icon inset kept", select(4, bar:GetPoint(1)), 16)
local _, _, _, mx, my = bar.mover:GetPoint(1)
H.check("detached: default x", mx, 300)
H.check("detached: default y", my, -300)
H.check("mover width = frame width", bar.mover:GetWidth(), 220)
H.check("mover height = castbar height", bar.mover:GetHeight(), 16)
C.Set("target", "castbarX", 120)
C.Set("target", "castbarY", -40)
_, _, _, mx, my = bar.mover:GetPoint(1)
H.check("numeric x", mx, 120)
H.check("numeric y", my, -40)

-- Unlocked: a detached castbar's handle shows, a docked one's does not.
local playerBar = ns.Frames.player.castbar
ns.Movers.Unlock()
H.checkTrue("detached castbar handle shown", bar.mover:IsShown())
H.check("player castbar handle hidden (off, docked)", playerBar.mover:IsShown(), false)
H.check("handle label", bar.mover.label:GetText(), "Target castbar")
bar.mover._cx, bar.mover._cy = 960 + 40, 540 - 64
UIParent._cx, UIParent._cy = 960, 540
ns.Movers.OnDragStop(bar.mover)
H.check("drag writes castbar x", C.Get("target", "castbarX"), 40)
H.check("drag writes castbar y", C.Get("target", "castbarY"), -64)
H.check("frame position untouched by the castbar drag", C.Get("target", "x"), 300)
C.Set("target", "castbarPosition", "BELOW")
H.check("docked again: handle hidden while unlocked", bar.mover:IsShown(), false)
H.check("docked again: to the frame", select(2, bar:GetPoint(1)), t)
ns.Movers.Lock()

-- Party castbars dock above or below each member.
M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
M.SetGroup({ "party1" })
local member = ns.Party.header:GetAttribute("child1")
H.check("party: below by default", member.castbar:GetPoint(1), "TOPLEFT")
C.Set("party", "castbarDock", "ABOVE")
H.check("party: above", member.castbar:GetPoint(1), "BOTTOMLEFT")
H.check("party: no mover", member.castbar.mover, nil)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`
Expected: FAIL — `ERROR .../Core/Settings.lua:43: attempt to index local 'def' (a nil value)`; summary `1152 passed, 1 failed`.

- [ ] **Step 3: Implement**

```diff
diff --git a/Core/Settings.lua b/Core/Settings.lua
index b0884d5..e5ab000 100644
--- a/Core/Settings.lua
+++ b/Core/Settings.lua
@@ -133,6 +133,17 @@ Settings.Define({ key = "partyShowSolo", code = "SO", scope = "frame", only = PA
 local CASTBAR = { player = true, target = true, targettarget = true, focus = true, party = true }
 Settings.Define({ key = "castbarEnabled", code = "CE", scope = "frame", only = CASTBAR, type = "bool",
     default = { player = false, _ = true } })
+-- Single frames may detach their castbar (own mover); party castbars
+-- dock above or below each member.
+local CASTBAR_SINGLE = { player = true, target = true, targettarget = true, focus = true }
+Settings.Define({ key = "castbarPosition", code = "CP", scope = "frame", only = CASTBAR_SINGLE, type = "enum",
+    values = { "BELOW", "ABOVE", "DETACHED" }, default = "BELOW" })
+Settings.Define({ key = "castbarDock", code = "CD", scope = "frame", only = PARTY, type = "enum",
+    values = { "BELOW", "ABOVE" }, default = "BELOW" })
+Settings.Define({ key = "castbarX", code = "CX", scope = "frame", only = CASTBAR_SINGLE, type = "int", min = -4000, max = 4000,
+    default = { target = 300, targettarget = 480, focus = -300, _ = 0 } })
+Settings.Define({ key = "castbarY", code = "CY", scope = "frame", only = CASTBAR_SINGLE, type = "int", min = -4000, max = 4000,
+    default = { player = -160, focus = -170, _ = -300 } })
 Settings.Define({ key = "castbarHeight", code = "CH", scope = "frame", only = CASTBAR, type = "int", min = 4, max = 60,
     default = { player = 18, target = 16, focus = 16, _ = 12 } })
 Settings.Define({ key = "castbarIcon", code = "CI", scope = "frame", only = CASTBAR, type = "bool", default = true })
```

```diff
diff --git a/Elements/Castbar.lua b/Elements/Castbar.lua
index 9d43c61..e5ce3b4 100644
--- a/Elements/Castbar.lua
+++ b/Elements/Castbar.lua
@@ -1,6 +1,7 @@
 local _, ns = ...
 
--- Castbar of a unit frame, docked below it.
+-- Castbar of a unit frame: docked below or above it, or (single frames)
+-- detached with a mover of its own.
 --
 -- Another unit's cast can arrive as secret values: name, icon, start and
 -- end time. They are only ever handed to widgets: the bar's range is the
@@ -140,12 +141,64 @@ function Castbar.Build(frame)
     frame.castbar = bar
 end
 
+-- BELOW, ABOVE or DETACHED. Party castbars only dock.
+function Castbar.Placement(scope)
+    if Settings.AppliesTo(Settings.Get("castbarPosition"), scope) then
+        return Config.Get(scope, "castbarPosition")
+    end
+    return Config.Get(scope, "castbarDock")
+end
+
+-- Whole castbar size, icon included: the frame's width.
+local function size(scope)
+    return Config.Get(scope, "width"), Config.Get(scope, "castbarHeight")
+end
+
 -- The icon sits left of the bar, inside the castbar's own rectangle.
 local function anchor(bar, frame, scope, inset)
+    local placement = Castbar.Placement(scope)
     local gap = Castbar.Gap(scope)
     bar:ClearAllPoints()
-    bar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", inset, -gap)
-    bar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -gap)
+    if placement == "DETACHED" then
+        if bar.mover then
+            ns.Movers.Sync(bar)
+            bar:SetPoint("TOPLEFT", bar.mover, "TOPLEFT", inset, 0)
+            bar:SetPoint("BOTTOMRIGHT", bar.mover, "BOTTOMRIGHT", 0, 0)
+        else
+            local w, h = size(scope)
+            bar:SetPoint("TOPLEFT", UIParent, "CENTER",
+                Config.Get(scope, "castbarX") - w / 2 + inset, Config.Get(scope, "castbarY") + h / 2)
+            bar:SetWidth(w - inset)
+        end
+    elseif placement == "ABOVE" then
+        bar:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", inset, gap)
+        bar:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, gap)
+    else
+        bar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", inset, -gap)
+        bar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -gap)
+    end
+end
+
+-- Handle for a detached castbar; shown while unlocked only if detached.
+function Castbar.MoverSpec(frame)
+    local scope = frame.key
+    return {
+        id = "castbar:" .. scope, scope = scope, xKey = "castbarX", yKey = "castbarY", anchor = false,
+        label = ns.L.MOVER_CASTBAR:format(ns.L["FRAME_" .. scope]),
+        size = function() return size(scope) end,
+        active = function()
+            return Config.Get(scope, "enabled") and Config.Get(scope, "castbarEnabled")
+                and Castbar.Placement(scope) == "DETACHED"
+        end,
+    }
+end
+
+-- Single frames only (party castbars cannot be detached).
+function Castbar.AttachMover(frame)
+    local bar = frame.castbar
+    if not bar or not Settings.AppliesTo(Settings.Get("castbarPosition"), frame.key) then return end
+    ns.Movers.Attach(bar, Castbar.MoverSpec(frame))
+    ns.AfterCombat("castbarStyle:" .. frame.key, function() Castbar.Style(frame) end)
 end
 
 function Castbar.Style(frame)
```

```diff
diff --git a/Core/Boot.lua b/Core/Boot.lua
index cdf00f4..2e29757 100644
--- a/Core/Boot.lua
+++ b/Core/Boot.lua
@@ -10,6 +10,7 @@ local function afterBuild()
     ns.Party.Create()
     for _, frame in pairs(ns.Frames) do ns.Movers.Attach(frame) end
     ns.Movers.Attach(ns.Party.header, ns.Party.MoverSpec())
+    for _, frame in pairs(ns.Frames) do ns.Castbar.AttachMover(frame) end
 end
 
 ns.On("PLAYER_LOGIN", function()
```

```diff
diff --git a/Options/Schema.lua b/Options/Schema.lua
index 699efbf..fb4dd65 100644
--- a/Options/Schema.lua
+++ b/Options/Schema.lua
@@ -34,8 +34,9 @@ Schema.FRAME = {
         { id = "font", keys = { "fontFace", "fontSize", "fontOutline", "fontShadow" } },
     } },
     { id = "castbar", sections = {
-        { id = "castbar", keys = { "castbarEnabled", "castbarHeight" } },
+        { id = "castbar", keys = { "castbarEnabled", "castbarPosition", "castbarDock", "castbarHeight" } },
         { id = "castbarContent", keys = { "castbarIcon", "castbarName", "castbarTime" } },
+        { id = "castbarDetached", keys = { "castbarX", "castbarY" } },
     } },
 }
 
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index 95a916a..c43ffa8 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -28,6 +28,10 @@ L.SETTING_y = "Position Y"
 L.SETTING_portraitMode = "Portrait"
 L.SETTING_portraitStyle = "Portrait style"
 L.SETTING_castbarEnabled = "Show castbar"
+L.SETTING_castbarPosition = "Castbar position"
+L.SETTING_castbarDock = "Castbar position"
+L.SETTING_castbarX = "Detached X"
+L.SETTING_castbarY = "Detached Y"
 L.SETTING_castbarHeight = "Castbar height"
 L.SETTING_castbarIcon = "Spell icon"
 L.SETTING_castbarName = "Spell name"
@@ -85,6 +89,10 @@ L.SECTION_portrait = "Portrait"
 L.SECTION_group = "Party layout"
 L.SECTION_castbar = "Castbar"
 L.SECTION_castbarContent = "Shown on the bar"
+L.SECTION_castbarDetached = "Detached position"
+L.HINT_castbarX = "Used when detached"
+L.HINT_castbarY = "Used when detached"
+L.MOVER_CASTBAR = "%s castbar"
 L.HINT_healthPercent = "Share of the frame height"
 L.HINT_powerPercent = "Share of the frame height; the rest becomes the gap"
 L.HINT_x = "Offset from the screen centre"
@@ -100,6 +108,7 @@ L.ENUM_DEFICIT = "Deficit"
 L.ENUM_VERTICAL = "Vertical"; L.ENUM_HORIZONTAL = "Horizontal"
 L.ENUM_OFF = "Off"; L.ENUM_LEFT = "Left"; L.ENUM_RIGHT = "Right"
 L.ENUM_2D = "2D"; L.ENUM_3D = "3D (model)"
+L.ENUM_BELOW = "Below the frame"; L.ENUM_ABOVE = "Above the frame"; L.ENUM_DETACHED = "Detached"
 L.ENUM_fontOutline_NONE = "None"
 L.ENUM_textHealthLeft_NONE = "Empty"
 
```

- [ ] **Step 4: Run the tests**

Run: `tests/run`
Expected: `1207 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Elements/Castbar.lua Core/Settings.lua Core/Boot.lua Options/Schema.lua Locales/enUS.lua tests/test_castbar_place.lua
git commit -F - <<'EOF'
Dock castbars above or below, or detach them with a mover

Detached castbars of single frames have their own handle and numeric
X / Y; party castbars dock above or below each member.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 9: Hide Blizzard's frames for the new units; /reload hint after a restore

**Files:**
- Modify: `Core/Blizzard.lua`, `Core/Storage.lua`, `Locales/enUS.lua`
- Test: `tests/test_blizzard_more.lua`

**Interfaces:**
- Consumes: `Blizzard.Conceal(frame)` (unchanged), `ns.Config`, `ns.MacroBackup`.
- Produces:
  - `Blizzard.HideDefaults()` additionally conceals `TargetFrameToT` (targettarget enabled), `PetFrame` (pet), `FocusFrame` (focus, if it exists), `PartyFrame` + every active `PartyFrame.PartyMemberFramePool` member + `CompactPartyFrame` (party), `PlayerCastingBarFrame` (player enabled and its castbar enabled). Missing frames are skipped.
  - `HideDefaults` re-runs on `CONFIG_CHANGED` for `key == nil`, `"enabled"` or `"castbarEnabled"` (newly enabled frames hide Blizzard's at once); party members acquired later are concealed on `GROUP_ROSTER_UPDATE` (after combat).
  - A macro-backup restore that switches any frame from enabled to disabled prints `L.RELOAD_FOR_BLIZZARD` once.

- [ ] **Step 1: Write the failing test**

Create `tests/test_blizzard_more.lua`:

```lua
local M = H.M

-- Stand-ins for the Blizzard frames of build 69977. TargetFrameToT is a
-- secure child of TargetFrame, PetFrame a secure button, FocusFrame a
-- secure TargetFrameTemplate, PartyFrame a plain frame whose pooled
-- member buttons are secure, PlayerCastingBarFrame a plain StatusBar.
local function blizzardFrames()
    local frames = {}
    for _, name in ipairs({ "PlayerFrame", "TargetFrame", "TargetFrameToT", "PetFrame", "FocusFrame",
        "PlayerCastingBarFrame", "PartyFrame", "CompactPartyFrame" }) do
        frames[name] = M.newWidget("Frame", name)
        _G[name] = frames[name]
    end
    for _, name in ipairs({ "TargetFrameToT", "PetFrame", "FocusFrame" }) do frames[name]._protected = true end
    local member = M.newWidget("Button", "PartyMember1")
    member._protected = true
    frames.member = member
    local active = { [member] = true }
    frames.PartyFrame.PartyMemberFramePool = { EnumerateActive = function() return pairs(active) end }
    frames.active = active
    return frames
end

local ns = H.LoadAddon()
local B = blizzardFrames()
ns.Config.Use({})
ns.Blizzard.HideDefaults()
H.check("tot: invisible", B.TargetFrameToT:GetAlpha(), 0)
H.check("tot: hidden", B.TargetFrameToT:IsShown(), false)
H.check("pet: invisible", B.PetFrame:GetAlpha(), 0)
H.check("focus: invisible", B.FocusFrame:GetAlpha(), 0)
H.check("party: hidden", B.PartyFrame:IsShown(), false)
H.check("party member: invisible", B.member:GetAlpha(), 0)
H.check("party member: mouse off", B.member._mouse, false)
H.check("compact party: hidden", B.CompactPartyFrame:IsShown(), false)
H.check("player castbar kept while ours is off", B.PlayerCastingBarFrame:IsShown(), true)

-- Switching our player castbar on hides Blizzard's at once.
ns.Config.Set("player", "castbarEnabled", true)
H.check("player castbar: hidden", B.PlayerCastingBarFrame:IsShown(), false)
H.checkTrue("player castbar: reparented", B.PlayerCastingBarFrame:GetParent() ~= nil)

-- Members Blizzard acquires later are hidden on the roster update.
local late = M.newWidget("Button", "PartyMember2")
late._protected = true
B.active[late] = true
M.SetGroup({ "party1" })
H.check("late member: invisible", late:GetAlpha(), 0)
M.SetGroup({})

-- Disabled frames keep Blizzard's.
ns = H.LoadAddon()
B = blizzardFrames()
ns.Config.Use({ targettarget = { enabled = false }, pet = { enabled = false }, focus = { enabled = false },
    party = { enabled = false } })
ns.Blizzard.HideDefaults()
H.check("tot kept", B.TargetFrameToT:GetAlpha(), 1)
H.check("pet kept", B.PetFrame:GetAlpha(), 1)
H.check("focus kept", B.FocusFrame:GetAlpha(), 1)
H.checkTrue("party kept", B.PartyFrame:IsShown())
H.check("party member kept", B.member:GetAlpha(), 1)
local late2 = M.newWidget("Button", "PartyMember3")
B.active[late2] = true
M.SetGroup({ "party1" })
H.check("roster update leaves a kept party alone", late2:GetAlpha(), 1)
M.SetGroup({})
-- Enabling one later hides Blizzard's without a reload.
ns.Config.Set("pet", "enabled", true)
H.check("pet enabled later: invisible", B.PetFrame:GetAlpha(), 0)

-- Missing frames (FocusFrame may not exist for this game type) are fine.
ns = H.LoadAddon()
ns.Config.Use({})
for _, name in ipairs({ "PlayerFrame", "TargetFrame", "TargetFrameToT", "PetFrame", "FocusFrame",
    "PlayerCastingBarFrame", "PartyFrame", "CompactPartyFrame", "ComboFrame" }) do _G[name] = nil end
H.checkTrue("no error without Blizzard frames", pcall(ns.Blizzard.HideDefaults))

-- A macro backup that switches frames off asks for a /reload.
ns = H.LoadAddon()
H.checkTrue("setup: backup", ns.MacroBackup.Write("1;eE0"))
local backup = M.macros
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.macros = backup
M.chat = {}
M.FireEvent("UPDATE_MACROS")
H.check("restored", ns.Storage.Source(), "MacroBackup")
H.checkTrue("reload hint", table.concat(M.chat, "\n"):find(ns.L.RELOAD_FOR_BLIZZARD, 1, true))

ns = H.LoadAddon()
H.checkTrue("setup: harmless backup", ns.MacroBackup.Write("1;pW300"))
backup = M.macros
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.macros = backup
M.chat = {}
M.FireEvent("UPDATE_MACROS")
H.check("restored width", ns.Config.Get("player", "width"), 300)
H.check("no reload hint", table.concat(M.chat, "\n"):find(ns.L.RELOAD_FOR_BLIZZARD, 1, true), nil)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`
Expected: FAIL — among others `FAIL tot: invisible -> 1 (want 0)`, `FAIL party member: invisible -> 1 (want 0)`, `FAIL reload hint -> false (want true)`; summary `1220 passed, 13 failed`.

- [ ] **Step 3: Implement**

```diff
diff --git a/Core/Blizzard.lua b/Core/Blizzard.lua
index 7ddaeb0..aea5736 100644
--- a/Core/Blizzard.lua
+++ b/Core/Blizzard.lua
@@ -31,12 +31,50 @@ function Blizzard.Conceal(frame)
     end
 end
 
+-- Blizzard's party: the member buttons live in a pool on PartyFrame; the
+-- raid-style CompactPartyFrame is created on demand as its child.
+local function concealParty()
+    local party = _G.PartyFrame
+    if party then
+        local pool = party.PartyMemberFramePool
+        if pool then
+            for member in pool:EnumerateActive() do Blizzard.Conceal(member) end
+        end
+        Blizzard.Conceal(party)
+    end
+    Blizzard.Conceal(_G.CompactPartyFrame)
+end
+
+local function enabled(scope) return ns.Config.Get(scope, "enabled") end
+
+-- Only frames we replace are hidden. Running again is harmless, so newly
+-- enabled frames are covered at once; getting a Blizzard frame back needs
+-- a /reload.
 function Blizzard.HideDefaults()
     ns.AfterCombat("hideBlizzard", function()
-        if ns.Config.Get("player", "enabled") then Blizzard.Conceal(_G.PlayerFrame) end
-        if ns.Config.Get("target", "enabled") then
+        if enabled("player") then
+            Blizzard.Conceal(_G.PlayerFrame)
+            if ns.Config.Get("player", "castbarEnabled") then Blizzard.Conceal(_G.PlayerCastingBarFrame) end
+        end
+        if enabled("target") then
             Blizzard.Conceal(_G.TargetFrame)
             Blizzard.Conceal(_G.ComboFrame)
         end
+        if enabled("targettarget") then Blizzard.Conceal(_G.TargetFrameToT) end
+        if enabled("pet") then Blizzard.Conceal(_G.PetFrame) end
+        if enabled("focus") then Blizzard.Conceal(_G.FocusFrame) end
+        if enabled("party") then concealParty() end
     end)
 end
+
+ns.Listen("CONFIG_CHANGED", function(_, key)
+    if key == nil or key == "enabled" or key == "castbarEnabled" then Blizzard.HideDefaults() end
+end)
+
+-- Blizzard's party code acquires member frames and creates the compact
+-- party frame when the roster changes; those are hidden as they come.
+ns.On("GROUP_ROSTER_UPDATE", function()
+    if ns.Config.Profile() and enabled("party") then
+        ns.AfterCombat("hideBlizzardParty", concealParty)
+    end
+end)
```

```diff
diff --git a/Core/Storage.lua b/Core/Storage.lua
index 2d552fc..98025b2 100644
--- a/Core/Storage.lua
+++ b/Core/Storage.lua
@@ -182,12 +182,34 @@ local function endWait(newSource)
     end
 end
 
+-- Frames switched on at the moment, by scope.
+local function enabledFrames()
+    local states = {}
+    for _, scope in ipairs(ns.Settings.SCOPES) do
+        if scope ~= "general" then states[scope] = ns.Config.Get(scope, "enabled") end
+    end
+    return states
+end
+
+-- Blizzard's frames are already hidden for every frame that was on; one
+-- the backup turns off only gets Blizzard's back after a /reload.
+local function hintReload(before)
+    for scope, was in pairs(before) do
+        if was and not ns.Config.Get(scope, "enabled") then
+            ns.Print(ns.L.RELOAD_FOR_BLIZZARD)
+            return
+        end
+    end
+end
+
 -- Returns true once a complete backup has been read and imported.
 function tryRestore()
     local str = ns.MacroBackup.Read()
     local profile = fromString(str)
     if not profile then return false end
+    local before = enabledFrames()
     ns.Config.Import(profile)   -- its CONFIG_CHANGED save is held or queued
+    hintReload(before)
     lastMacro = str             -- already in the macros, no need to rewrite it
     endWait("MacroBackup")
     ns.Print(ns.L.RESTORED_FROM_MACRO)
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index c43ffa8..433de2e 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -65,6 +65,7 @@ L.SOURCE_MacroBackup = "macro backup"
 L.SOURCE_Defaults = "defaults"
 L.SOURCE_Waiting = "waiting for macros"
 L.RESTORED_FROM_MACRO = "Settings restored from the macro backup."
+L.RELOAD_FOR_BLIZZARD = "The restored settings switch frames off. Type /reload to get Blizzard's frames back."
 L.NOT_READY = "Forever Unit Frames is still loading."
 L.STATUS_BUILD = "Client %s (build %s), interface %d"
 L.STATUS_PROJECT = "Project ID %d"
```

- [ ] **Step 4: Run the tests**

Run: `tests/run`
Expected: `1233 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Blizzard.lua Core/Storage.lua Locales/enUS.lua tests/test_blizzard_more.lua
git commit -F - <<'EOF'
Hide Blizzard's frames for the new units

Target of target, pet, focus, party (pool members and the compact
party frame) and the player castbar are hidden when ours replace them.
A restored backup that switches frames off asks for a /reload.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 10: Options for all new settings, party highlight, label re-fit

**Files:**
- Modify: `Options/Widgets.lua`, `Options/Window.lua`, `Units/Party.lua`, `Locales/enUS.lua`, `tests/test_schema.lua`
- Test: `tests/test_options_frames.lua`

**Interfaces:**
- Consumes: `ns.Schema` (tabs / sections from Tasks 5–8), `Settings.AppliesTo` with `only` (the window and `Schema.Tabs` already filter by it, so party-only rows show only on the Party page and the castbar tab disappears for the pet).
- Produces:
  - `Party.HighlightTarget()` — the frame the window outlines when Party is selected (the header).
  - Widgets: labels re-fit when their text changes — `fitLeftColumn` resets the width to natural (`SetWidth(0)`) before measuring; every row has `row:SetLabel(text)`; `Widgets.LABEL_MAX_W` is exported.
  - Schema completeness is checked for every frame scope, not only the player.

- [ ] **Step 1: Write the failing tests**

```diff
diff --git a/tests/test_schema.lua b/tests/test_schema.lua
index eb8972f..35a8a84 100644
--- a/tests/test_schema.lua
+++ b/tests/test_schema.lua
@@ -17,12 +17,15 @@ local function keysOf(tabs)
 end
 
 local general, frame = keysOf(S.GENERAL), keysOf(S.FRAME)
+local FRAMES = { "player", "target", "targettarget", "pet", "focus", "party" }
 for _, def in ipairs(Settings.All()) do
     if Settings.AppliesTo(def, "general") then
         H.check("general shows " .. def.key .. " once", general[def.key], 1)
     end
-    if Settings.AppliesTo(def, "player") then
-        H.check("frame shows " .. def.key .. " once", frame[def.key], 1)
+    for _, scope in ipairs(FRAMES) do
+        if Settings.AppliesTo(def, scope) then
+            H.check(scope .. " page shows " .. def.key .. " once", frame[def.key], 1)
+        end
     end
     if def.type == "enum" then
         for _, v in ipairs(def.values) do
```

Create `tests/test_options_frames.lua`:

```lua
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local O, L = ns.Options, ns.L

local function rowKeys()
    local keys = {}
    for _, row in ipairs(O.rows) do if row.key then keys[row.key] = row end end
    return keys
end
local function tabIds(scope)
    local ids = {}
    for _, tab in ipairs(ns.Schema.Tabs(scope)) do ids[#ids + 1] = tab.id end
    return table.concat(ids, ",")
end

O.Open()
-- Navigation lists every frame.
for _, key in ipairs({ "player", "target", "targettarget", "pet", "focus", "party" }) do
    H.checkTrue("nav entry " .. key, O.navButtons[key])
    H.check("nav label " .. key, O.navButtons[key].text:GetText(), L["FRAME_" .. key])
end

-- Tabs per frame: no castbar for the pet.
H.check("player tabs", tabIds("player"), "layout,bars,text,castbar")
H.check("pet tabs", tabIds("pet"), "layout,bars,text")
H.check("party tabs", tabIds("party"), "layout,bars,text,castbar")

-- Party layout only on the party page; portrait everywhere.
O.Select("party")
O.SelectTab("layout")
local rows = rowKeys()
H.checkTrue("party: orientation row", rows.partyOrientation)
H.checkTrue("party: spacing row", rows.partySpacing)
H.checkTrue("party: show player row", rows.partyShowPlayer)
H.checkTrue("party: show solo row", rows.partyShowSolo)
H.checkTrue("party: block X", rows.x)
H.checkTrue("party: portrait", rows.portraitMode)
rows.partySpacing.edit:SetText("20")
rows.partySpacing.edit:GetScript("OnEnterPressed")(rows.partySpacing.edit)
H.check("spacing set through the window", ns.Config.Get("party", "partySpacing"), 20)
H.check("header follows", ns.Party.header:GetAttribute("yOffset"), -20)

O.Select("player")
O.SelectTab("layout")
rows = rowKeys()
H.check("player: no party rows", rows.partySpacing, nil)
H.checkTrue("player: portrait style", rows.portraitStyle)

-- Castbar tab: detached position for single frames, dock for party.
O.SelectTab("castbar")
rows = rowKeys()
H.checkTrue("player castbar: position", rows.castbarPosition)
H.checkTrue("player castbar: detached X", rows.castbarX)
H.check("player castbar: no dock", rows.castbarDock, nil)
H.check("player castbar: off by default", rows.castbarEnabled.box:GetChecked(), false)
O.Select("party")
H.check("tab kept on party", O.currentTab, "castbar")
rows = rowKeys()
H.checkTrue("party castbar: dock", rows.castbarDock)
H.check("party castbar: no detached X", rows.castbarX, nil)
H.check("party castbar: no position", rows.castbarPosition, nil)
O.Select("pet")
H.check("pet falls back to its first tab", O.currentTab, "layout")

-- Selecting Party outlines the party block.
O.Select("party")
local hl = ns.Party.header.optionsHighlight
H.checkTrue("party highlight created", hl)
H.check("party highlight visible", hl[1]:GetAlpha(), 1)
M.RunTimers()

-- Every setting label fits the label column (mock: half the font size per
-- character at 12 px).
for _, def in ipairs(ns.Settings.All()) do
    local fs = M.newWidget("FontString")
    fs:SetFont("x", 12, "")
    fs:SetText(L["SETTING_" .. def.key])
    H.checkTrue("label fits: " .. def.key, fs:GetStringWidth() <= ns.Widgets.LABEL_MAX_W)
end

-- A label whose text changes is fitted again.
local row = ns.Widgets.Slider(CreateFrame("Frame", nil, UIParent), { label = "x", min = 0, max = 1, step = 1,
    get = function() return 0 end, set = function() return true end })
row:SetLabel(string.rep("W", 60))
H.check("long label limited", row.label:GetWidth(), ns.Widgets.LABEL_MAX_W)
row:SetLabel("Short")
H.check("short label back to its natural width", row.label:GetWidth(), 0)
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`
Expected: FAIL — `FAIL party highlight created -> false (want true)`, `ERROR test_options_frames.lua:71: attempt to index local 'hl' (a nil value)`; summary `1421 passed, 2 failed`.

- [ ] **Step 3: Implement**

```diff
diff --git a/Options/Widgets.lua b/Options/Widgets.lua
index 57e3b40..5ea204b 100644
--- a/Options/Widgets.lua
+++ b/Options/Widgets.lua
@@ -37,11 +37,15 @@ end
 local function fitLeftColumn(fontString, alwaysFull)
     fontString:SetWordWrap(false)
     fontString:SetJustifyH("LEFT")
-    -- A label keeps its natural width (the inherit marker follows it).
+    -- Width 0 is the natural width: a label whose text changes is measured
+    -- afresh instead of keeping an earlier limit. A label keeps its
+    -- natural width (the inherit marker follows it).
+    fontString:SetWidth(0)
     if alwaysFull or fontString:GetStringWidth() > LABEL_MAX_W then
         fontString:SetWidth(LABEL_MAX_W)
     end
 end
+Widgets.LABEL_MAX_W = LABEL_MAX_W
 
 local function newRow(parent, opts)
     local row = CreateFrame("Frame", nil, parent)
@@ -74,6 +78,10 @@ local function newRow(parent, opts)
         row.reset:SetScript("OnClick", function() opts.inherit.clear() end)
         trackHover(row, row.reset)
     end
+    function row:SetLabel(text)
+        row.label:SetText(text)
+        fitLeftColumn(row.label)
+    end
     function row:RefreshInherit()
         if not opts.inherit then return end
         local over = opts.inherit.isOverridden()
```

```diff
diff --git a/Options/Window.lua b/Options/Window.lua
index 20e4f21..919830c 100644
--- a/Options/Window.lua
+++ b/Options/Window.lua
@@ -124,6 +124,7 @@ end
 -- Textures on a secure frame are created and anchored out of combat only.
 local function highlightFrame(scope)
     local unitFrame = ns.Frames[scope]
+    if scope == ns.Party.KEY then unitFrame = ns.Party.HighlightTarget() end
     if not unitFrame or InCombatLockdown() then return end
     local edges = unitFrame.optionsHighlight or createOutline(unitFrame)
     anchorOutline(unitFrame, edges)
```

```diff
diff --git a/Units/Party.lua b/Units/Party.lua
index 517b33e..aa1ddde 100644
--- a/Units/Party.lua
+++ b/Units/Party.lua
@@ -121,6 +121,11 @@ function Party.OnUnitChanged(button, unit)
     Single.UpdateAll(button)
 end
 
+-- What the options window outlines when Party is selected.
+function Party.HighlightTarget()
+    return Party.header
+end
+
 function Party.Create()
     if Party.header then return Party.header end
     local header = CreateFrame("Frame", Party.HEADER, UIParent, "SecureGroupHeaderTemplate")
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index 433de2e..28471ea 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -99,6 +99,8 @@ L.HINT_powerPercent = "Share of the frame height; the rest becomes the gap"
 L.HINT_x = "Offset from the screen centre"
 L.HINT_y = "Offset from the screen centre"
 L.HINT_enabled = "Needs /reload after re-enabling"
+L.HINT_partyShowSolo = "Shows your own frame outside a group"
+L.HINT_portraitMode = "Square as tall as the frame"
 L.ENUM_NONE = "None"; L.ENUM_OUTLINE = "Outline"; L.ENUM_THICKOUTLINE = "Thick outline"
 L.ENUM_MONOCHROME = "Monochrome"
 L.ENUM_CLASS = "Class"; L.ENUM_REACTION = "Reaction"; L.ENUM_STATIC = "Static colour"
```

- [ ] **Step 4: Run the tests**

Run: `tests/run`
Expected: `1462 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Options/Widgets.lua Options/Window.lua Units/Party.lua Locales/enUS.lua tests/test_schema.lua tests/test_options_frames.lua
git commit -F - <<'EOF'
Options pages for the new frames, party highlight, label re-fit

Every frame page shows exactly the settings that apply to it; selecting
Party outlines the block; row labels are measured again when their
text changes.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 11: Test mode for the new frames, castbar preview, pretend party

**Files:**
- Modify: `Options/TestMode.lua`, `Elements/Castbar.lua`, `Units/Party.lua`, `Locales/enUS.lua`
- Test: `tests/test_testmode_frames.lua`

**Interfaces:**
- Consumes: `ns.Single.SetUnit`, `Party.SlotOffset`, `Party.BlockSize`, `Party.StyleButton`, `header.mover`.
- Produces:
  - `Castbar.Preview(frame, on)` — still sample cast (`L.TEST_CAST`, `Castbar.PREVIEW_ICON`) on an enabled castbar; `bar.preview` makes `Update` and `OnUpdate` ignore real casts; `Castbar.Style` re-applies it.
  - `Party.SetTest(on)` (out of combat) — hides the header and shows `Party.fakes` (secure `SecureUnitButtonTemplate` buttons named `ForeverUnitFramesPartyTest<i>`, `unit = "player"`, clicks target / menu) in `Party.testBlock` (plain frame at the block position); `Party.StyleAll` keeps them in sync with the settings; `Party.HighlightTarget()` returns the test block while testing.
  - `TestMode.Set` and the combat release call `Party.SetTest`; `applyOn` / `applyOff` switch the castbar preview.

- [ ] **Step 1: Write the failing test**

Create `tests/test_testmode_frames.lua`:

```lua
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, P = ns.Config, ns.Party
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10 }

H.checkTrue("test mode on", ns.TestMode.Set(true))

-- Every single frame shows the player.
for _, key in ipairs({ "player", "target", "targettarget", "pet", "focus" }) do
    local f = ns.Frames[key]
    H.check(key .. ": player data", f:GetAttribute("unit"), "player")
    H.checkTrue(key .. ": shown", f:IsShown())
    H.check(key .. ": no unit watch", f._unitWatch, nil)
end
H.check("pet health from the player", ns.Frames.pet.health:GetValue(), 5)

-- Sample casts on enabled castbars only (the player's is off by default).
local tbar = ns.Frames.target.castbar
H.checkTrue("target: sample cast", tbar:IsShown())
H.check("sample cast name", tbar.text:GetText(), ns.L.TEST_CAST)
H.check("player castbar off: no sample", ns.Frames.player.castbar:IsShown(), false)
C.Set("player", "castbarEnabled", true)
H.checkTrue("switched on during test mode: sample", ns.Frames.player.castbar:IsShown())
M.units.player.cast = nil
M.FireEvent("UNIT_SPELLCAST_STOP", "player", "x", 1)
H.checkTrue("real events leave the sample alone", ns.Frames.player.castbar:IsShown())
M.Tick(0.25)
H.checkTrue("timer leaves the tot sample alone", ns.Frames.targettarget.castbar:IsShown())

-- The party block becomes a pretend party of four on the player.
H.check("real header hidden", P.header:IsShown(), false)
H.checkTrue("test block shown", P.testBlock:IsShown())
H.check("four pretend members", #P.fakes, 4)
for i, b in ipairs(P.fakes) do
    H.check("fake " .. i .. " unit", b:GetAttribute("unit"), "player")
    H.check("fake " .. i .. " secure", b._template, "SecureUnitButtonTemplate")
    H.check("fake " .. i .. " clicks target", b:GetAttribute("*type1"), "target")
    H.checkTrue("fake " .. i .. " shown", b:IsShown())
    H.check("fake " .. i .. " width", b:GetWidth(), 160)
end
H.check("fake 2 below fake 1", select(5, P.fakes[2]:GetPoint(1)), -(36 + 12))
H.check("fake health", P.fakes[3].health:GetValue(), 5)
H.checkTrue("fake sample cast", P.fakes[1].castbar:IsShown())
H.check("fakes are not header buttons", #P.buttons, 1)

-- Party settings apply to the pretend party at once.
C.Set("party", "partyOrientation", "HORIZONTAL")
H.check("horizontal: fake 2 to the right", select(4, P.fakes[2]:GetPoint(1)), 160 + 12)
C.Set("party", "partyShowPlayer", true)
H.check("with the player: five", #P.fakes, 5)
H.checkTrue("fifth shown", P.fakes[5]:IsShown())
C.Set("party", "partyShowPlayer", false)
H.check("without the player: fifth hidden", P.fakes[5]:IsShown(), false)
C.Set("party", "enabled", false)
H.check("disabled party: block hidden", P.testBlock:IsShown(), false)
C.Set("party", "enabled", true)
H.checkTrue("enabled again: block shown", P.testBlock:IsShown())

-- The options window outlines the pretend party while testing.
ns.Options.Open("party")
H.check("highlight on the test block", P.HighlightTarget(), P.testBlock)
M.RunTimers()

-- Off: real header back, pretend party gone, castbars back to real casts.
ns.TestMode.Set(false)
H.checkTrue("header back", P.header:IsShown())
H.check("test block hidden", P.testBlock:IsShown(), false)
H.check("fakes hidden", P.fakes[1]:IsShown(), false)
H.check("target back on target", ns.Frames.target:GetAttribute("unit"), "target")
H.check("sample cast gone", tbar:IsShown(), false)
H.check("preview flag cleared", tbar.preview, nil)
H.check("highlight on the header again", P.HighlightTarget(), P.header)

-- Combat ends test mode for the party too.
ns.TestMode.Set(true)
M.FireEvent("PLAYER_REGEN_DISABLED")
H.checkTrue("combat: header back", P.header:IsShown())
H.check("combat: fakes hidden", P.fakes[1]:IsShown(), false)

-- Lockdown already started: the party is handed back after combat.
ns.TestMode.Set(true)
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.checkTrue("late combat: fakes still up in combat", P.fakes[1]:IsShown())
M.SetCombat(false)
H.check("late combat: fakes hidden after combat", P.fakes[1]:IsShown(), false)
H.checkTrue("late combat: header back after combat", P.header:IsShown())
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `tests/run`
Expected: FAIL — among others `FAIL target: sample cast -> false (want true)`, `FAIL real header hidden -> true (want false)`, `ERROR test_testmode_frames.lua:34: attempt to index field 'testBlock' (a nil value)`; summary `1480 passed, 7 failed`.

- [ ] **Step 3: Implement**

```diff
diff --git a/Elements/Castbar.lua b/Elements/Castbar.lua
index e5ce3b4..ddf683c 100644
--- a/Elements/Castbar.lua
+++ b/Elements/Castbar.lua
@@ -25,6 +25,7 @@ local Config, Secrets, Settings = ns.Config, ns.Secrets, ns.Settings
 
 Castbar.CAST_COLOR = { 1.0, 0.7, 0.0 }
 Castbar.CHANNEL_COLOR = { 0.3, 0.8, 0.3 }
+Castbar.PREVIEW_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
 
 local STOP_EVENTS = {
     UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true,
@@ -116,7 +117,7 @@ end
 
 function Castbar.OnUpdate(bar)
     local cast = bar.cast
-    if not cast then return end
+    if not cast or bar.preview then return end
     local nowMs = now()
     bar:SetValue(nowMs)
     local endMs = Secrets.Number(cast.endMs)
@@ -232,12 +233,38 @@ function Castbar.Style(frame)
     bar.time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
     bar.time:SetJustifyH("RIGHT")
     bar.time:SetShown(Config.Get(scope, "castbarTime"))
-    if not Config.Get(scope, "castbarEnabled") then Castbar.Stop(bar) end
+    if bar.preview then
+        Castbar.Preview(frame, true)
+    elseif not Config.Get(scope, "castbarEnabled") then
+        Castbar.Stop(bar)
+    end
 end
 
-function Castbar.Update(frame, event, _, castGUID)
+-- Test mode: a still sample cast on every enabled castbar. Real casts are
+-- ignored until the preview ends.
+function Castbar.Preview(frame, on)
     local bar = frame.castbar
     if not bar then return end
+    bar.preview = on or nil
+    if not (on and Config.Get(frame.key, "castbarEnabled")) then
+        Castbar.Stop(bar)
+        return
+    end
+    bar.cast = nil
+    bar:SetMinMaxValues(0, 1)
+    bar:SetValue(0.6)
+    bar:SetReverseFill(false)
+    local c = Castbar.CAST_COLOR
+    bar:SetStatusBarColor(c[1], c[2], c[3])
+    bar.text:SetText(ns.L.TEST_CAST)
+    bar.icon:SetTexture(Castbar.PREVIEW_ICON)
+    bar.time:SetText("1.5")
+    bar:Show()
+end
+
+function Castbar.Update(frame, event, _, castGUID)
+    local bar = frame.castbar
+    if not bar or bar.preview then return end
     if not Config.Get(frame.key, "castbarEnabled") then
         Castbar.Stop(bar)
         return
@@ -250,7 +277,7 @@ function Castbar.Update(frame, event, _, castGUID)
     elseif STOP_EVENTS[event] then
         if not Castbar.IsOtherCast(bar, castGUID) then Castbar.Refresh(bar, unit) end
     else
-        -- The unit itself changed (new target, timer): start over.
+        -- The unit itself changed (new target, test mode, timer): start over.
         Castbar.Refresh(bar, unit)
     end
 end
```

```diff
diff --git a/Units/Party.lua b/Units/Party.lua
index aa1ddde..7a3b325 100644
--- a/Units/Party.lua
+++ b/Units/Party.lua
@@ -16,6 +16,10 @@ Party.TEMPLATE = "ForeverUnitFramesPartyButtonTemplate"
 Party.MEMBERS = 4
 -- Every button the header made, in creation order.
 Party.buttons = {}
+-- Test mode: pretend members (secure buttons on the player) in a plain
+-- block where the header would be.
+Party.fakes = {}
+local testing = false
 
 local function get(key) return Config.Get(Party.KEY, key) end
 
@@ -91,6 +95,55 @@ local function sizeButtons()
     end
 end
 
+-- A pretend member: a real secure button on the player, so clicks target
+-- you, drawn like the others. Never touched by the group header.
+local function fakeButton(i)
+    local button = Party.fakes[i]
+    if button then return button end
+    button = CreateFrame("Button", "ForeverUnitFramesPartyTest" .. i, Party.testBlock, "SecureUnitButtonTemplate")
+    button.key = Party.KEY
+    button:SetAttribute("*type1", "target")
+    button:SetAttribute("*type2", "togglemenu")
+    button:RegisterForClicks("AnyUp")
+    for _, el in ipairs(ns.Elements) do el.Build(button) end
+    Single.SetUnit(button, "player")
+    Party.fakes[i] = button
+    return button
+end
+
+local function showFakes()
+    local block = Party.testBlock
+    if not block then
+        block = CreateFrame("Frame", nil, UIParent)
+        block.key = Party.KEY
+        Party.testBlock = block
+    end
+    local w, h = Party.BlockSize()
+    block:SetSize(w, h)
+    block:ClearAllPoints()
+    if Party.header.mover then
+        block:SetPoint("TOPLEFT", Party.header.mover, "TOPLEFT", 0, 0)
+    else
+        block:SetPoint("TOPLEFT", UIParent, "CENTER", get("x") - w / 2, get("y") + h / 2)
+    end
+    block:SetShown(get("enabled"))
+    local slots = Party.Slots()
+    for i = 1, slots do
+        local button = fakeButton(i)
+        button:ClearAllPoints()
+        button:SetPoint("TOPLEFT", block, "TOPLEFT", Party.SlotOffset(i))
+        Party.StyleButton(button)
+        ns.Castbar.Preview(button, true)
+        button:Show()
+    end
+    for i = slots + 1, #Party.fakes do Party.fakes[i]:Hide() end
+end
+
+local function hideFakes()
+    if Party.testBlock then Party.testBlock:Hide() end
+    for _, button in ipairs(Party.fakes) do button:Hide() end
+end
+
 -- Out of combat only: attributes, position, size and visibility are
 -- protected on the header and its buttons.
 function Party.StyleAll()
@@ -101,7 +154,18 @@ function Party.StyleAll()
     for _, button in ipairs(Party.buttons) do Party.StyleButton(button) end
     -- Hide + Show makes the header lay its buttons out again (OnShow).
     header:Hide()
-    if get("enabled") then header:Show() end
+    if testing then
+        showFakes()
+    else
+        hideFakes()
+        if get("enabled") then header:Show() end
+    end
+end
+
+-- Test mode on or off (out of combat, from Options/TestMode.lua).
+function Party.SetTest(on)
+    testing = on and true or false
+    Party.StyleAll()
 end
 
 -- XML OnLoad: the button exists, its unit is not known yet.
@@ -123,6 +187,7 @@ end
 
 -- What the options window outlines when Party is selected.
 function Party.HighlightTarget()
+    if testing and Party.testBlock then return Party.testBlock end
     return Party.header
 end
 
```

```diff
diff --git a/Options/TestMode.lua b/Options/TestMode.lua
index 3df3114..15d9c06 100644
--- a/Options/TestMode.lua
+++ b/Options/TestMode.lua
@@ -1,8 +1,10 @@
 local _, ns = ...
 
 -- Shows every enabled frame with the player's data, so frames can be
--- configured without a target. Only touches secure attributes and unit
--- watch out of combat (existing ns.AfterCombat paths).
+-- configured without a target, and a sample cast on every castbar. The
+-- party block is replaced by a pretend party (Units/Party.lua). Only
+-- touches secure attributes and unit watch out of combat (existing
+-- ns.AfterCombat paths).
 local TestMode = {}
 ns.TestMode = TestMode
 
@@ -21,6 +23,7 @@ local function applyOn(frame)
     ns.Single.SetUnit(frame, "player")
     UnregisterUnitWatch(frame)
     frame:Show()
+    ns.Castbar.Preview(frame, true)
     ns.Single.UpdateAll(frame)
 end
 
@@ -31,6 +34,7 @@ local function applyOff(frame)
     local unit = saved[frame]
     saved[frame] = nil
     ns.Single.SetUnit(frame, unit)
+    ns.Castbar.Preview(frame, false)
     if ns.Config.Get(frame.key, "enabled") then
         RegisterUnitWatch(frame)
     else
@@ -59,6 +63,7 @@ function TestMode.Set(state)
     else
         for frame in pairs(saved) do applyOff(frame) end
     end
+    ns.Party.SetTest(on)
     ns.Fire("TEST_MODE", on)
     return true
 end
@@ -106,6 +111,7 @@ ns.On("PLAYER_REGEN_DISABLED", function()
     on = false
     ns.AfterCombat("testmode", function()
         for frame in pairs(saved) do applyOff(frame) end
+        ns.Party.SetTest(false)
     end, "last")
     ns.Fire("TEST_MODE", false)
 end)
```

```diff
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
index 28471ea..34705fe 100644
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -120,6 +120,7 @@ L.RESET_OVERRIDE = "Reset"
 
 L.TEST_MODE_COMBAT = "Test mode is not available in combat."
 L.TEST_MODE_ON = "Test mode"
+L.TEST_CAST = "Test cast"
 
 L.GENERAL = "General"
 L.UNLOCK_FRAMES = "Unlock frames"; L.LOCK_FRAMES = "Lock frames"
```

- [ ] **Step 4: Run the tests**

Run: `tests/run`
Expected: `1531 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Options/TestMode.lua Elements/Castbar.lua Units/Party.lua Locales/enUS.lua tests/test_testmode_frames.lua
git commit -F - <<'EOF'
Test mode: new frames, sample casts and a pretend party

Every frame shows the player, every enabled castbar a still sample
cast, and the party block becomes four (five with the player) secure
buttons on the player, laid out like the real party.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp
EOF
```

---

### Task 12: In-game verification (controller: UI actions only)

No code changes. The controller installs the build and checks it in the game using only the interface (chat commands, the options window, mouse on movers and options). The controller does **not** move the character, cast spells, target anything in the world or enter combat; the user runs the combat checks at the end.

**Files:** none (report the results; if a check fails, stop and report the failing step with a screenshot — do not fix inside this task).

- [ ] **Step 1: Install and load**

Run: `./install "<AddOns folder of the WoW: Forever client>"`
Expected: `Installed to .../ForeverUnitFrames`. Then in game: `/reload`. No Lua error window appears (if an error appears: note file and line, read them against the `forever` branch of the UI source).

- [ ] **Step 2: Status**

Type `/fuf status`.
Expected: build line `Client 1.60.1 (build 69977), interface 16001`, `Project ID 1`, `Settings loaded from: …`, and `Focus unit: available` (if it says `not supported by this client`, the focus frame is absent — report it, the rest continues).

- [ ] **Step 3: Blizzard frames gone**

Look at the screen without a target. Expected: Blizzard's player frame, pet frame (if a pet is out), party frames (if grouped) and focus frame are not visible; the Blizzard player castbar is still there (ours is off by default).

- [ ] **Step 4: Options pages**

Type `/fuf`. Expected: navigation lists General, Player, Target, Target of Target, Pet, Focus, Party. Click each frame: the frame (or the party block) is outlined briefly. Pet shows tabs Layout / Bars / Text; all others also show Castbar. Party → Layout shows the section "Party layout" (Orientation, Spacing, Show player, Show when solo); Player → Layout does not. No label runs under its control.

- [ ] **Step 5: Test mode**

Click "Test mode". Expected: Player, Target, Target of Target, Pet and Focus frames show your own name and health; Target, Target of Target, Focus show a castbar "Test cast" below the frame; the Party position shows four frames with your name, each with a "Test cast" castbar. Clicking a pretend party frame targets yourself (UI click only).

- [ ] **Step 6: Party layout live**

With test mode on, Party → Layout: set Orientation to Horizontal → the four frames line up left to right. Spacing 30 → gaps widen. Show player on → five frames. Portrait: Left → a square portrait at the left of every party frame; Portrait style 3D → your model appears in the square. Set everything back (Reset frame → click twice).

- [ ] **Step 7: Castbar placement**

Target → Castbar: Castbar position Above → the sample cast moves above the target frame. Detached → it moves to its own place; "Unlock frames" shows a handle labelled "Target castbar"; drag it; Detached X / Y fields update to the new position (multiples of 8). Type a value in Detached X → the castbar moves. Lock frames, set position back to Below the frame. Party → Castbar shows "Castbar position" with Below / Above only and no Detached X / Y.

- [ ] **Step 8: Party block mover**

Unlock frames: a handle labelled "Party" covers the whole block; drag it; Party → Layout → Position X / Y update. Type X = -700 → the block moves. Lock frames.

- [ ] **Step 9: Player castbar switch**

Player → Castbar → Show castbar on. Expected: Blizzard's player castbar is gone from now on (visible only when casting, which the user checks below). Leave test mode.

- [ ] **Step 10: Checks for the user (combat and casting — not the controller)**

Hand these to the user:
1. Cast a spell with a cast time: the player castbar fills with name, icon and time, and disappears on completion; interrupt one by moving: it disappears.
2. Target an enemy caster: its cast shows with name; if the time stays empty the cast is restricted (secret) — expected.
3. Channel a spell (e.g. a drain): the bar fills from the right and ends with the channel.
4. Target of Target follows your target's target within a fraction of a second, including in combat.
5. Group with someone (or have someone join during combat): the new member's frame appears in combat at the template size and takes the configured size after combat.
6. Enter combat with test mode on: test mode ends, the real party returns after combat.
7. `/focus` an enemy: the focus frame shows it, including its casts.


## Self-review against the spec

| Spec requirement (scope of this plan) | Task |
|---|---|
| Target of Target, Pet, Focus, Party frames | 2, 3, 4 |
| Focus built but verified at run time, shown in `/fuf status` | 3 |
| Party: orientation, spacing, show player, show when solo | 5 |
| Party block positioned as a whole by X / Y and by dragging | 5 |
| Portrait Off / Left / Right, 2D / 3D | 6 |
| Castbar for Player, Target, ToT, Focus, Party; off by default for Player | 7 |
| Castbar height, icon, cast time, spell name | 7 |
| Castbar docked above / below or detached with own mover and X / Y | 8 (party: docked only, see Design decisions) |
| Castbar secret handling: raw times, castGUID from START, `type(x) == "nil"`, `pcall` for text | 7 |
| Hide Blizzard's frames for the new units | 9 |
| Every new setting in the options window, party-only settings only on Party | 5–8, 10 |
| Test mode shows every frame incl. a pretend party of secure buttons on the player | 11 |
| Everything English via `ns.L` | every task |
| Deferred: RegisterUnitEvent per unit; GRADIENT / STATIC / readable reaction / UNIT_CONNECTION tests; /reload hint after restore; label re-fit | 1, 1, 9, 10 |

## Open questions (not verifiable offline)

- Creating child regions (status bars, a `PlayerModel`) on a party button from its XML `OnLoad` when the header creates the button in combat is assumed allowed (the children are not protected). If the client refuses, move those regions into `Units/Party.xml`.
- `RegisterUnitEvent(event, "targettarget")` is assumed harmless (no events arrive for that token; the poll covers it).
- A method call on a secret `LuaDurationObject` (`GetRemainingDuration`) is done inside `pcall`; if the client refuses it, restricted casts simply show no time.
- `FontString:SetWidth(0)` is assumed to restore the natural width (label re-fit).
- Detached castbars for party members are not offered (Design decisions); confirm with the spec owner.
