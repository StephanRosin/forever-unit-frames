# Forever Unit Frames — Raid plan R2b: raid view in party, Blizzard's raid frames, test mode

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The raid panel of R2a takes a 5-player group when "raid view in party" is on (the party frames then hide), Blizzard's raid frames go while ours are on, and test mode shows a pretend raid of the active size laid out exactly like the real blocks — unit frames unchanged when the raid options are off.

**Architecture:** `Units/Party.lua`'s visibility driver asks `ns.RaidHeader.ReplacesParty()`; the raid panel restyles the party block when it is built and when the raid view or the raid frames are switched. `Core/Blizzard.lua` conceals `CompactRaidFrameManager` and `CompactRaidFrameContainer` like the other Blizzard frames. `Raid/TestMode.lua` listens to `TEST_MODE` (fired by `Options/TestMode.lua`, unchanged) and draws pretend cells (secure buttons on the player, `frame.sample` per cell) at the places `Raid/Header.lua` computes for them.

**Tech Stack:** Lua 5.1, WoW: Forever API (Interface 16001, build 1.60.1.70205), offline tests with `lua5.1` + `tests/mock.lua` (`tests/run`).

Spec: `docs/specs/2026-10-06-raid-frames-design.md` (part 1; §4 Party and Blizzard's raid frames, §7 test mode). Raid plan order: R1 Foundation (done) → R2a Headers, layout and cell (`docs/plans/2026-10-06-plan-raid-2a-headers-and-cell.md`) → **R2b (this plan)** → R3 Indicators, icons and states → R4 Options window, locales, wiki, release.

Base: the last commit of R2a ("Build the raid panel at login"); `tests/run` there: `19228 passed, 0 failed`. Every task below was replayed in order on a scratch worktree after R2a; the totals under "Expected" are what `tests/run` printed there.

## Global Constraints

The Global Constraints of R2a hold unchanged (English, no new user-facing string, unit frames identical with the raid options off, no existing test edited, no secret maths, no snippets, protected changes out of combat only, faithful mock, public repository, commit trailer, no push, one green commit per task). In addition:

- No new setting: the raid view in party (`showInParty`), hiding Blizzard's raid frames (`hideBlizzard`) and the raid frames switch (`enabled`) are R1's character-wide raid settings.
- With `showInParty` off, or the raid frames off, the party frames keep exactly today's driver (`Party.RAID_DRIVER` or none).
- Visibility drivers and `UnregisterStateDriver` run out of combat only (`ns.AfterCombat("partyStyle", …)`), as today.
- Pretend raid cells are never registered for click-casting and never get aura containers (`pretend`, `auraGroupKeys`).
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`

## Client facts this plan relies on (build 1.60.1.70205)

Paths below `Interface/AddOns/`.

| Fact | Source |
|---|---|
| Blizzard's raid frames are `CompactRaidFrameContainer` (an Edit Mode system frame, holds the compact unit frames) and `CompactRaidFrameManager` (the panel at the left edge, `hidden="true"`, registers `GROUP_ROSTER_UPDATE` and more, shows the container through `CompactRaidFrameManager_UpdateContainerVisibility`); the addon is not load-on-demand on this client (game type `camelot`, `[Family]` = Mainline) | `Blizzard_CompactRaidFrames/Blizzard_CompactRaidFrames.toc`, `Blizzard_CompactRaidFrameContainer.xml`, `Mainline/Blizzard_CompactRaidFrameManager.xml`, `Mainline/Blizzard_CompactRaidFrameManager.lua` |
| Concealing (`ns.Blizzard.Conceal`): events off; protected frames invisible, mouse off and hidden (Edit Mode frames by `HideBase`), plain frames reparented to a hidden frame | `Core/Blizzard.lua` (existing) |
| Macro conditions in a visibility driver: `[group:raid]` is already in use; `[group]` (a party or a raid) belongs to the same conditional family. The conditions are evaluated by the client, not in the UI source: check `[group]` in game | `RegisterStateDriver` (`SecureStateDriver.lua`) |
| `TEST_MODE` (internal) fires from `Options/TestMode.lua` on every switch; `PLAYER_REGEN_DISABLED` ends test mode before lockdown, or queues the end after combat | `Options/TestMode.lua` (existing) |

## Design decisions

- **Raid view in party** uses the 10-player profile through the active size: AUTO gives 10 in a party. A fixed size mode (20 or 40) applies in a party too (deviation from the spec's "10-player profile" wording: the fixed switch is the user's explicit choice and R1's size rule is kept as it is).
- **Party drivers:** party hidden in raids and raid view on: `[group] hide; show`; party kept in raids and raid view on: `[group:raid] show; [group] hide; show`; raid view off: today's. Before the raid profile is attached (`PLAYER_LOGIN` builds the party block first) `ReplacesParty()` is false; building the raid panel restyles the party block once.
- **Blizzard's raid frames:** both the container and the manager go (the manager would show the container again, and a re-shown container with alpha 0 would leave clickable compact frames). The manager's raid tools (markers, ready check button) go with it — see the in-game check. Hidden at login, when the raid frames or `hideBlizzard` are switched on, and again after each roster change; back only with a `/reload`, as for the unit frames.
- **Test mode:** the active size (no raid options window yet, so no "edited" profile). Forty sample members: ten repeating (class and role), five to a group, health from full to low, member 3 dead and member 7 offline (both in every size); names are Blizzard's localised class names. They go to blocks with the blocks' own filter rule (`Layout.Matches`), sorted like the headers (raid order or name; the single block by group first). The panel and the pretend cells show only while the raid frames are on.

---
### Task 1: Raid view in a 5-player group

**Files:**
- Modify: `Units/Party.lua` (`Party.ShowHeader`)
- Modify: `Raid/Header.lua` (`ReplacesParty`; party restyle on create and on a switch)
- Modify: `Core/Boot.lua` (comment)
- Modify: `tests/mock.lua` (`[group]` condition; drivers re-evaluated on `M.SetGroup`, run as secure code)
- Test: `tests/test_raid_party.lua`

**Interfaces:**
- Consumes: `ns.RaidHeader.Enabled`, `ns.RaidConfig` (`general.showInParty`), `ns.Party.StyleAll`.
- Produces: `ns.RaidHeader.ReplacesParty()`; `Party.GROUP_DRIVER` (`"[group] hide; show"`), `Party.PARTY_DRIVER` (`"[group:raid] show; [group] hide; show"`); `RAID_CONFIG_CHANGED` for `general` `enabled` / `showInParty` (or everything) queues `partyStyle`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_party.lua`:

```lua
-- The raid view in a party (raid profile: showInParty): a 5-player group
-- shows in the raid panel and the party frames hide (Units/Party.lua's
-- visibility driver); with it off, or the raid frames off, the party
-- frames behave as before.
local M = H.M
local ns = H.LoadAddon()
local RC, Party = ns.RaidConfig, ns.Party
_G.ForeverUnitFramesDB = { raid = { ["Tester-Testrealm"] = { general = { showInParty = true } } } }
M.units.player = { name = "Me", class = "MAGE", isPlayer = true, health = 1, healthMax = 1 }
M.units.party1 = { name = "Ann", class = "PRIEST", isPlayer = true, health = 1, healthMax = 1 }

-- Before the raid profile is attached the party block does not ask it;
-- building the raid panel at login restyles the party block.
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local header = Party.header
H.check("login: party hides in any group", M.drivers[header], "[group] hide; show")
H.checkTrue("solo: party header shown", header:IsShown())
M.SetGroup({ "party1" })
M.RunTimers()
H.check("party: party frames hidden", header:IsShown(), false)
H.checkTrue("party: raid panel shown", ns.RaidHeader.panel:IsShown())
H.check("party: you and your party in the panel", ns.RaidHeader.Count(1), 2)
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 } })
H.check("raid: party frames hidden", header:IsShown(), false)
M.SetRaidRoster({})

-- Off: the unit frames' own rule again.
RC.Set("general", "showInParty", false)
H.check("off: hidden in raids only", M.drivers[header], Party.RAID_DRIVER)
H.checkTrue("off: party frames in a party", header:IsShown())
H.check("off: panel hidden in a party", ns.RaidHeader.panel:IsShown(), false)

-- Party frames kept in raids: only the party view hides them.
ns.Config.Set("party", "partyHideInRaid", false)
H.check("kept in raids, no raid view: no driver", M.drivers[header], nil)
RC.Set("general", "showInParty", true)
H.check("kept in raids, raid view: driver", M.drivers[header], "[group:raid] show; [group] hide; show")
H.check("kept in raids: hidden in a party", header:IsShown(), false)
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 } })
H.checkTrue("kept in raids: shown in a raid", header:IsShown())
M.SetRaidRoster({})
ns.Config.Set("party", "partyHideInRaid", true)

-- Raid frames off: the party view is off with them.
RC.Set("general", "enabled", false)
H.check("raid frames off: party rule", M.drivers[header], Party.RAID_DRIVER)
H.checkTrue("raid frames off: party frames shown", header:IsShown())
RC.Set("general", "enabled", true)
H.check("raid frames on: party view again", M.drivers[header], "[group] hide; show")

-- In combat the drivers wait (they are protected).
M.combat = true
RC.Set("general", "showInParty", false)
H.check("combat: unchanged", M.drivers[header], "[group] hide; show")
M.SetCombat(false)
H.check("after combat: changed", M.drivers[header], Party.RAID_DRIVER)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run raid_party`
Expected: `FAIL login: party hides in any group -> [group:raid] hide; show (want [group] hide; show)` among 6 failures, `12 passed, 6 failed`

- [ ] **Step 3: Mock: the `[group]` condition**

In `tests/mock.lua`:

Replace

```lua
    _G.IsInGroup = function() return #M.group > 0 or M.inRaid end
    -- Raid: M.inRaid (M.SetRaid). Visibility drivers (SecureStateDriver.lua:
    -- RegisterStateDriver(frame, "visibility", values) sets state-visibility);
    -- the mock knows the conditions the addon uses.
    M.inRaid = false
    M.drivers = setmetatable({}, { __mode = "k" })
    _G.IsInRaid = function() return M.inRaid end
```

with

```lua
    _G.IsInGroup = function() return #M.group > 0 or M.inRaid end
    -- Raid: M.inRaid (M.SetRaid). Visibility drivers (SecureStateDriver.lua:
    -- RegisterStateDriver(frame, "visibility", values) sets state-visibility);
    -- the mock knows the conditions the addon uses ([group] is a party or a
    -- raid) and evaluates them again when the group changes.
    M.inRaid = false
    M.drivers = setmetatable({}, { __mode = "k" })
    _G.IsInRaid = function() return M.inRaid end
```

Replace

```lua
            local cond, action = clause:match("^%[(.-)%]%s*(%a+)$")
            if not cond then action = clause:match("^(%a+)$") end
            local match = cond == nil or (cond == "group:raid" and M.inRaid) or (cond == "nogroup:raid" and not M.inRaid)
            assert(cond == nil or cond == "group:raid" or cond == "nogroup:raid", "mock: unknown condition " .. tostring(cond))
            if match then
                if action == "show" then frame:Show() else frame:Hide() end
                return
            end
        end
```

with

```lua
            local cond, action = clause:match("^%[(.-)%]%s*(%a+)$")
            if not cond then action = clause:match("^(%a+)$") end
            local match = cond == nil or (cond == "group:raid" and M.inRaid) or (cond == "nogroup:raid" and not M.inRaid)
                or (cond == "group" and IsInGroup())
            assert(cond == nil or cond == "group:raid" or cond == "nogroup:raid" or cond == "group",
                "mock: unknown condition " .. tostring(cond))
            if match then
                -- The state driver is secure code: it may show and hide
                -- protected frames in combat.
                M.secureDepth = M.secureDepth + 1
                if action == "show" then frame:Show() else frame:Hide() end
                M.secureDepth = M.secureDepth - 1
                return
            end
        end
```

Replace

```lua
-- Joins or leaves a party: M.SetGroup({ "party1", "party2" }) or M.SetGroup({}).
function M.SetGroup(units)
    M.group = units
    M.FireEvent("GROUP_ROSTER_UPDATE")
end
```

with

```lua
-- Joins or leaves a party: M.SetGroup({ "party1", "party2" }) or M.SetGroup({}).
function M.SetGroup(units)
    M.group = units
    M.SetRaid(M.inRaid)
    M.FireEvent("GROUP_ROSTER_UPDATE")
end
```

The state driver is the client's secure code, so it may show and hide protected frames in combat; re-evaluating on `M.SetGroup` needs that.

- [ ] **Step 4: The party block asks the raid view**

In `Units/Party.lua`:

Replace

```lua

-- Shows a header (Hide + Show lays its buttons out again, OnShow). In a
-- raid group it hides by a visibility driver when the party is set to;
-- out of combat only, like everything done to the header.
Party.RAID_DRIVER = "[group:raid] hide; show"
function Party.ShowHeader(header, want)
    UnregisterStateDriver(header, "visibility")
    header:Hide()
    if not want then return end
    if get("partyHideInRaid") then
        RegisterStateDriver(header, "visibility", Party.RAID_DRIVER)
    else
        header:Show()
    end
```

with

```lua

-- Shows a header (Hide + Show lays its buttons out again, OnShow). In a
-- raid group it hides by a visibility driver when the party is set to;
-- out of combat only, like everything done to the header. With the raid
-- view in party (Raid/Header.lua) the raid panel shows a 5-player group,
-- so the party hides in any group, or in a party only when it is kept in
-- raids.
Party.RAID_DRIVER = "[group:raid] hide; show"
Party.GROUP_DRIVER = "[group] hide; show"
Party.PARTY_DRIVER = "[group:raid] show; [group] hide; show"
function Party.ShowHeader(header, want)
    UnregisterStateDriver(header, "visibility")
    header:Hide()
    if not want then return end
    local raidView = ns.RaidHeader ~= nil and ns.RaidHeader.ReplacesParty()
    if get("partyHideInRaid") then
        RegisterStateDriver(header, "visibility", raidView and Party.GROUP_DRIVER or Party.RAID_DRIVER)
    elseif raidView then
        RegisterStateDriver(header, "visibility", Party.PARTY_DRIVER)
    else
        header:Show()
    end
```

- [ ] **Step 5: The raid panel answers and restyles the party block**

In `Raid/Header.lua`:

Replace

```lua
    return ns.RaidConfig.Profile() ~= nil and general("enabled") == true
end

-- Whether the panel shows now: in a raid, or in a party with the raid
-- view in party on.
function Header.Active()
```

with

```lua
    return ns.RaidConfig.Profile() ~= nil and general("enabled") == true
end

-- The raid view in party: a 5-player group shows here, the party frames
-- hide (Units/Party.lua asks).
function Header.ReplacesParty()
    return Header.Enabled() and general("showInParty") == true
end

-- Whether the panel shows now: in a raid, or in a party with the raid
-- view in party on.
function Header.Active()
```

Replace

```lua
    Header.panel:SetPoint("TOPLEFT", Header.anchor, "TOPLEFT", 0, 0)
    Header.Refresh()
    ns.Movers.Attach(Header.anchor, Header.MoverSpec())
    return Header.anchor
end
```

with

```lua
    Header.panel:SetPoint("TOPLEFT", Header.anchor, "TOPLEFT", 0, 0)
    Header.Refresh()
    ns.Movers.Attach(Header.anchor, Header.MoverSpec())
    -- The party block may have been styled before the raid profile was
    -- there to ask.
    ns.AfterCombat("partyStyle", ns.Party.StyleAll)
    return Header.anchor
end
```

Replace

```lua
ns.Listen("RAID_SIZE_CHANGED", function() if Header.anchor then refresh() end end)
-- A setting of the active size or the character; another size's profile
-- does not show.
ns.Listen("RAID_CONFIG_CHANGED", function(scope)
    if not Header.anchor then return end
    if scope == nil or scope == "general" or scope == ns.Raid.Scope(Cell.Size()) then refresh() end
end)
-- The cells wear the party look.
ns.Listen("CONFIG_CHANGED", function(scope)
```

with

```lua
ns.Listen("RAID_SIZE_CHANGED", function() if Header.anchor then refresh() end end)
-- A setting of the active size or the character; another size's profile
-- does not show.
ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if not Header.anchor then return end
    if scope == nil or scope == "general" or scope == ns.Raid.Scope(Cell.Size()) then refresh() end
    -- Raid view in party switched, or the raid frames: the party block.
    if scope == nil or (scope == "general" and (key == nil or key == "enabled" or key == "showInParty")) then
        ns.AfterCombat("partyStyle", ns.Party.StyleAll)
    end
end)
-- The cells wear the party look.
ns.Listen("CONFIG_CHANGED", function(scope)
```

- [ ] **Step 6: Correct the boot comment**

In `Core/Boot.lua`:

Replace

```lua
    ns.MinimapButton.Create()
    -- The raid frames last: their profile, the active size, then the
    -- panel built from both (out of combat, like the unit frames). The
    -- unit frames above never read the raid profile.
    ns.RaidProfiles.Attach(ForeverUnitFramesDB)
    ns.RaidSize.Update()
    ns.AfterCombat("raidCreate", ns.RaidHeader.Create)
```

with

```lua
    ns.MinimapButton.Create()
    -- The raid frames last: their profile, the active size, then the
    -- panel built from both (out of combat, like the unit frames). The
    -- party block asks the raid profile whether the raid view takes a
    -- 5-player group: no until it is attached; building the panel styles
    -- the party block again.
    ns.RaidProfiles.Attach(ForeverUnitFramesDB)
    ns.RaidSize.Update()
    ns.AfterCombat("raidCreate", ns.RaidHeader.Create)
```

- [ ] **Step 7: Run the tests**

Run: `tests/run raid_party` → `18 passed, 0 failed`
Run: `tests/run` → Expected: `19246 passed, 0 failed`

- [ ] **Step 8: Commit**

```bash
git add Units/Party.lua Raid/Header.lua Core/Boot.lua tests/mock.lua tests/test_raid_party.lua
git commit -m "Raid view in a 5-player group hides the party frames

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Hide Blizzard's raid frames while ours are on

**Files:**
- Modify: `Core/Blizzard.lua` (appended), `Core/Boot.lua`
- Test: `tests/test_blizzard_raid.lua`

**Interfaces:**
- Consumes: `ns.Blizzard.Conceal`, `ns.RaidConfig` (`general.enabled`, `general.hideBlizzard`).
- Produces: `ns.Blizzard.HideRaid()` (out of combat, `hideBlizzardRaid`); called at login, on `RAID_CONFIG_CHANGED` (`enabled`, `hideBlizzard`, everything) and on `GROUP_ROSTER_UPDATE`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_blizzard_raid.lua`:

```lua
-- Blizzard's raid frames (Blizzard_CompactRaidFrames): the container of
-- compact unit frames (an Edit Mode frame with secure buttons) and the
-- manager panel go while our raid frames are on and set to hide them
-- (Core/Blizzard.lua), out of combat, again after roster changes.
local M = H.M

-- Stand-ins: CompactRaidFrameManager a plain frame with events,
-- CompactRaidFrameContainer an Edit Mode frame (HideBase), protected: it
-- holds secure compact unit frames.
local function blizzardRaid()
    local manager = M.newWidget("Frame", "CompactRaidFrameManager", UIParent)
    manager:RegisterEvent("GROUP_ROSTER_UPDATE")
    local container = M.newWidget("Frame", "CompactRaidFrameContainer", UIParent)
    container:RegisterEvent("GROUP_ROSTER_UPDATE")
    container._protected = true
    local member = M.newWidget("Button", "CompactRaidFrame1", container)
    member._protected = true
    container.hideBaseCalls = 0
    rawset(container, "HideBase", function(self)
        self.hideBaseCalls = self.hideBaseCalls + 1
        self._shown = false
    end)
    _G.CompactRaidFrameManager, _G.CompactRaidFrameContainer = manager, container
    return manager, container
end

local function login(raidProfile)
    local ns = H.LoadAddon()
    local manager, container = blizzardRaid()
    _G.ForeverUnitFramesDB = { raid = { ["Tester-Testrealm"] = raidProfile } }
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    return ns, manager, container
end

-- Default: on, and hidden at login.
local ns, manager, container = login({})
H.check("manager hidden", manager:IsShown(), false)
H.checkTrue("manager under a hidden parent", manager:GetParent() ~= UIParent)
H.check("manager events off", next(manager._events), nil)
H.check("container: invisible", container:GetAlpha(), 0)
H.check("container: mouse off", container._mouse, false)
H.check("container: hidden by its own Hide", container.hideBaseCalls, 1)
H.check("container events off", next(container._events), nil)

-- Shown again by someone: hidden again on the next roster change.
manager:Show()
M.SetGroup({ "party1" })
H.check("roster change: manager hidden again", manager:IsShown(), false)
M.SetGroup({})

-- Kept: the setting off, or our raid frames off.
ns, manager, container = login({ general = { hideBlizzard = false } })
H.checkTrue("kept: manager shown", manager:IsShown())
H.check("kept: container visible", container:GetAlpha(), 1)
ns.RaidConfig.Set("general", "hideBlizzard", true)
H.check("switched on: hidden at once", manager:IsShown(), false)
ns, manager, container = login({ general = { enabled = false } })
H.checkTrue("raid frames off: manager kept", manager:IsShown())
M.combat = true
ns.RaidConfig.Set("general", "enabled", true)
H.checkTrue("combat: waits", manager:IsShown())
M.SetCombat(false)
H.check("after combat: hidden", manager:IsShown(), false)
H.check("nothing blocked", #M.blocked, 0)

-- A client without them: nothing to do.
ns = H.LoadAddon()
_G.CompactRaidFrameManager, _G.CompactRaidFrameContainer = nil, nil
_G.ForeverUnitFramesDB = {}
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
H.check("no Blizzard raid frames: no error", #M.errors, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run blizzard_raid`
Expected: `FAIL manager hidden -> true (want false)` among 10 failures, `6 passed, 10 failed`

- [ ] **Step 3: Conceal them**

In `Core/Blizzard.lua`, at the end of the file:

Replace

```lua
        ns.AfterCombat("hideBlizzardParty", concealParty)
    end
end)
```

with

```lua
        ns.AfterCombat("hideBlizzardParty", concealParty)
    end
end)

-- Blizzard's raid frames (Blizzard_CompactRaidFrames): the container of
-- compact unit frames and the manager panel at the screen's left edge
-- that shows and hides it. Both go while our raid frames are on and set
-- to hide them; getting them back needs a /reload, as for the unit
-- frames. Concealing takes their events, so Blizzard's own code does not
-- bring them back; a roster change hides them again regardless.
local function raidHidden()
    local RC = ns.RaidConfig
    return RC.Profile() ~= nil and RC.Get("general", "enabled") and RC.Get("general", "hideBlizzard")
end

local function concealRaid()
    Blizzard.Conceal(_G.CompactRaidFrameManager)
    Blizzard.Conceal(_G.CompactRaidFrameContainer)
end

function Blizzard.HideRaid()
    if raidHidden() then ns.AfterCombat("hideBlizzardRaid", concealRaid) end
end

ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if scope == nil or (scope == "general" and (key == nil or key == "enabled" or key == "hideBlizzard")) then
        Blizzard.HideRaid()
    end
end)
ns.On("GROUP_ROSTER_UPDATE", Blizzard.HideRaid)
```

In `Core/Boot.lua`:

Replace

```lua
    ns.RaidProfiles.Attach(ForeverUnitFramesDB)
    ns.RaidSize.Update()
    ns.AfterCombat("raidCreate", ns.RaidHeader.Create)
end)

ns.Listen("CONFIG_CHANGED", function()
```

with

```lua
    ns.RaidProfiles.Attach(ForeverUnitFramesDB)
    ns.RaidSize.Update()
    ns.AfterCombat("raidCreate", ns.RaidHeader.Create)
    ns.Blizzard.HideRaid()
end)

ns.Listen("CONFIG_CHANGED", function()
```

- [ ] **Step 4: Run the tests**

Run: `tests/run blizzard_raid` → `16 passed, 0 failed`
Run: `tests/run` → Expected: `19262 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Blizzard.lua Core/Boot.lua tests/test_blizzard_raid.lua
git commit -m "Hide Blizzard's raid frames while ours are on

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Raid test mode: a pretend raid of the active size

**Files:**
- Create: `Raid/TestMode.lua`
- Modify: `Raid/Header.lua` (`Place` returns its numbers; test mode in `Refresh`, `UpdateVisibility` and the deferred placing)
- Modify: `ForeverUnitFrames.toc`
- Test: `tests/test_raid_testmode.lua`

**Interfaces:**
- Consumes: `TEST_MODE`, `ns.RaidLayout.Matches` / `CellOffset` / `HeaderOffset`, `ns.RaidCell.Setup` / `Style` / `fakes`, `ns.Party.ReleaseFake`, the element sample hooks (R2a Task 4).
- Produces: `ns.RaidTestMode` with `SAMPLES`, `HEALTH`, `STATUS`, `IsOn()`, `Members(size)`, `Distribute(blocks, members, size, byName)`, `Show()`, `Hide()`; `ns.RaidHeader.Place(counts)` returns `positions, shape`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_testmode.lua`:

```lua
-- Raid test mode (Raid/TestMode.lua): with test mode on, a pretend raid
-- of the active size where the blocks are, laid out like the real ones;
-- secure buttons on the player with samples of their own. Off, or on
-- entering combat, the real headers come back.
local M = H.M
local ns = H.LoadAddon()
local RC, Header, Cell, Test = ns.RaidConfig, ns.RaidHeader, ns.RaidCell, ns.RaidTestMode
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100, healthMissing = 0, power = 50, powerMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

local function point(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    return table.concat({ p, rel == Header.anchor and "anchor" or "?", relPoint, x, y }, " ")
end

-- The pretend members.
local members = Test.Members(40)
H.check("forty", #members, 40)
H.check("member 1", members[1].class .. " " .. members[1].assignedRole .. " " .. members[1].subgroup, "WARRIOR TANK 1")
H.check("member 6: second group", members[6].subgroup, 2)
H.check("name: Blizzard's class name", members[2].name, "Priest")
H.check("member 3 dead", members[3].status, "DEAD")
H.check("member 7 offline", members[7].status, "OFFLINE")
H.check("others alive", members[4].status, false)

-- On: ten pretend cells for the 10-player profile, in groups 1 and 2.
ns.TestMode.Set(true)
H.checkTrue("panel shown solo", Header.panel:IsShown())
H.check("headers hidden", Header.headers[1]:IsShown(), false)
local shown = 0
for _, f in ipairs(Cell.fakes) do if f:IsShown() then shown = shown + 1 end end
H.check("ten pretend cells", shown, 10)
local f1, f6 = Cell.fakes[1], Cell.fakes[6]
H.check("first cell: block 1", point(f1), "TOPLEFT anchor TOPLEFT 0 0")
H.check("second cell below", point(Cell.fakes[2]), "TOPLEFT anchor TOPLEFT 0 -46")
H.check("sixth cell: block 2", point(f6), "TOPLEFT anchor TOPLEFT 102 0")
H.check("cell size", f1:GetWidth() .. "x" .. f1:GetHeight(), "96x44")
H.check("panel as with a full raid", Header.panel:GetWidth() .. "x" .. Header.panel:GetHeight(), "198x228")
H.check("on the player", f1:GetAttribute("unit"), "player")
H.check("left click targets", M.SecureClick(f1, "LeftButton"), "target")
H.check("not for click-casting", (ClickCastFrames or {})[f1], nil)
H.check("sample name", f1.texts.healthLeft:GetText(), "Warrior")
H.check("sample health", Cell.fakes[4].health:GetValue(), 0.35)
H.check("sample class colour", f1.health._color[1], 0.78)
H.check("dead", Cell.fakes[3].texts.healthRight:GetText(), ns.L.STATUS_DEAD)
H.check("offline", Cell.fakes[7].texts.healthRight:GetText(), ns.L.STATUS_OFFLINE)
H.check("warrior: no mana strip", f1.power:IsShown(), false)
H.checkTrue("priest: mana strip", Cell.fakes[2].power:IsShown())
local seen = {}
ns.Units.ForEachFrame(function(frame) seen[frame] = true end)
H.checkTrue("every-frame loop reaches them", seen[f1])

-- By class: the pretend members go to their class blocks, packed.
RC.Set("r10", "groupBy", "CLASS")
H.check("warriors first", point(Cell.fakes[1]), "TOPLEFT anchor TOPLEFT 0 0")
H.check("both warriors in the warrior block", point(Cell.fakes[2]), "TOPLEFT anchor TOPLEFT 0 -46")
H.check("second warrior's sample", Cell.fakes[2].texts.healthLeft:GetText(), "Warrior")
H.check("paladin block next", point(Cell.fakes[3]), "TOPLEFT anchor TOPLEFT 102 0")
-- By name within one block.
RC.Set("r10", "groupBy", "NONE")
RC.Set("r10", "sortBy", "NAME")
H.check("one block: group 1 first, by name", Cell.fakes[1].texts.healthLeft:GetText(), "Hunter")
RC.ResetScope("r10")

-- The 40-player profile: forty cells.
RC.Set("general", "sizeMode", "40")
shown = 0
for _, f in ipairs(Cell.fakes) do if f:IsShown() then shown = shown + 1 end end
H.check("forty pretend cells", shown, 40)
H.check("cells of the 40 profile", Cell.fakes[1]:GetWidth(), 80)
RC.Set("general", "sizeMode", "AUTO")

-- Raid frames off: no pretend raid.
RC.Set("general", "enabled", false)
H.check("off: pretend cells hidden", Cell.fakes[1]:IsShown(), false)
H.check("off: panel hidden", Header.panel:IsShown(), false)
RC.Set("general", "enabled", true)
H.checkTrue("on: back", Cell.fakes[1]:IsShown())

-- Entering combat ends test mode; the real headers come back.
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: test mode off", ns.TestMode.IsOn(), false)
H.check("combat: pretend cells hidden", Cell.fakes[1]:IsShown(), false)
H.checkTrue("combat: headers back", Header.headers[1]:IsShown())
H.check("combat: panel hidden solo", Header.panel:IsShown(), false)
H.check("nothing blocked", #M.blocked, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run raid_testmode`
Expected: `ERROR test_raid_testmode.lua:20: attempt to index local 'Test' (a nil value)`, `0 passed, 1 failed`

- [ ] **Step 3: Create `Raid/TestMode.lua`**

```lua
local _, ns = ...

-- Test mode for the raid panel (Options/TestMode.lua fires TEST_MODE): a
-- pretend raid of the active size where the blocks are, laid out exactly
-- like the real ones (Raid/Layout.lua). The pretend cells are secure
-- buttons on the player, so clicks target you, each with a sample of its
-- own (Elements/Health.lua: Health.Sample): a class (name and colour; the
-- name is Blizzard's class name), health, a role, and one dead, one
-- offline member. Made once, out of combat, and reused. Entering combat
-- ends test mode (Options/TestMode.lua); the cells go with the next
-- layout, after combat if it had already begun.
local Test = {}
ns.RaidTestMode = Test

local Cell, Layout, Header = ns.RaidCell, ns.RaidLayout, ns.RaidHeader

-- Ten members, repeated: five to a group, a tank and a healer in most.
Test.SAMPLES = {
    { "WARRIOR", "TANK" }, { "PRIEST", "HEALER" }, { "MAGE", "DAMAGER" }, { "ROGUE", "DAMAGER" },
    { "HUNTER", "DAMAGER" }, { "PALADIN", "HEALER" }, { "DRUID", "HEALER" }, { "WARLOCK", "DAMAGER" },
    { "SHAMAN", "HEALER" }, { "WARRIOR", "DAMAGER" },
}
Test.HEALTH = { 1, 0.85, 0.6, 0.35, 0.15, 0.95, 0.7, 0.5 }
-- Member 3 is dead, member 7 offline: both in every size.
Test.STATUS = { [3] = "DEAD", [7] = "OFFLINE" }

local on = false

function Test.IsOn()
    return on and Header.Enabled()
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
-- health, status, role } per member, in raid order.
function Test.Members(size)
    local list = {}
    for i = 1, size do
        local s = Test.SAMPLES[(i - 1) % #Test.SAMPLES + 1]
        local names = LOCALIZED_CLASS_NAMES_MALE
        list[i] = {
            subgroup = math.floor((i - 1) / Layout.GROUP_SIZE) + 1, class = s[1], assignedRole = s[2], role = s[2],
            name = type(names) == "table" and names[s[1]] or s[1],
            health = Test.HEALTH[(i - 1) % #Test.HEALTH + 1], status = Test.STATUS[i] or false,
        }
    end
    return list
end

-- Members into blocks, as the headers would sort them: by raid order or
-- by name, the single block by group first.
function Test.Distribute(blocks, members, size, byName)
    local lists = {}
    for b, block in ipairs(blocks) do
        local list = {}
        for i, m in ipairs(members) do
            if Layout.Matches(block, m, size) then list[#list + 1] = { index = i, member = m } end
        end
        table.sort(list, function(x, y)
            if block.kind == "NONE" and x.member.subgroup ~= y.member.subgroup then
                return x.member.subgroup < y.member.subgroup
            end
            if byName and x.member.name ~= y.member.name then return x.member.name < y.member.name end
            return x.index < y.index
        end)
        lists[b] = list
    end
    return lists
end

local function fakeButton(i)
    local button = Cell.fakes[i]
    if button then return button end
    button = CreateFrame("Button", "ForeverUnitFramesRaidTest" .. i, UIParent, "SecureUnitButtonTemplate")
    -- Shows samples only; never gets live aura containers.
    button.pretend = true
    Cell.Setup(button)
    button:SetAttribute("*type1", "target")
    button:SetAttribute("*type2", "togglemenu")
    button:RegisterForClicks("AnyUp")
    Cell.fakes[i] = button
    return button
end

-- Out of combat (Raid/Header.lua's layout): the pretend raid in place of
-- the headers' cells.
function Test.Show()
    local size = Cell.Size()
    local byName = ns.RaidConfig.Get(ns.Raid.Scope(size), "sortBy") == "NAME"
    local lists = Test.Distribute(Header.blocks, Test.Members(size), size, byName)
    local counts = {}
    for b, list in ipairs(lists) do counts[b] = #list end
    local positions, s = Header.Place(counts)
    local hx, hy = Layout.HeaderOffset(s)
    local used = 0
    for b, list in ipairs(lists) do
        local pos = positions[b]
        for slot, entry in ipairs(list) do
            used = used + 1
            local button = fakeButton(used)
            button.sample = entry.member
            ns.Single.SetUnit(button, "player")
            local x, y = Layout.CellOffset(s, slot)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", Header.anchor, "TOPLEFT", pos.x + hx + x, pos.y + hy + y)
            Cell.Style(button)
            ns.Single.Preview(button, true)
            button:Show()
        end
    end
    for i = used + 1, #Cell.fakes do ns.Party.ReleaseFake(Cell.fakes[i]) end
end

-- Out of combat: every pretend cell hidden and quiet.
function Test.Hide()
    for _, button in ipairs(Cell.fakes) do
        if button.unit or button:IsShown() then ns.Party.ReleaseFake(button) end
    end
end

ns.Listen("TEST_MODE", function(state)
    on = state and true or false
    if Header.anchor then ns.AfterCombat("raidLayout", Header.Refresh) end
end)
```

- [ ] **Step 4: The panel shows the pretend raid**

In `Raid/Header.lua`:

Replace

```lua
-- per block (the headers' own, or test mode's), titles and borders, the
-- panel over the occupied area. A block without room parks its empty
-- header below the panel: someone joining it in combat shows there
-- instead of on top of another block.
function Header.Place(counts)
    local s = Header.Shape()
    local hideEmpty = get("hideEmpty")
```

with

```lua
-- per block (the headers' own, or test mode's), titles and borders, the
-- panel over the occupied area. A block without room parks its empty
-- header below the panel: someone joining it in combat shows there
-- instead of on top of another block. Returns each block's place (nil
-- without room) and the numbers it used (Raid/TestMode.lua).
function Header.Place(counts)
    local s = Header.Shape()
    local hideEmpty = get("hideEmpty")
```

Replace

```lua
    else
        Border.Hide(Header.panel)
    end
end

-- The panel's size, or a cell's while it is empty (the mover's handle).
```

with

```lua
    else
        Border.Hide(Header.panel)
    end
    return positions, s
end

-- The panel's size, or a cell's while it is empty (the mover's handle).
```

Replace

```lua
    }
end

-- Any time, combat included: the panel's plain frames follow the group.
function Header.UpdateVisibility()
    if Header.panel then Header.panel:SetShown(Header.Active()) end
end

-- Out of combat only: the whole layout for the active size. Every header
-- shows again (Hide + Show lays its cells out anew, OnShow); the cells it
-- does not use lose their anchors (it only SetPoints the ones it shows).
function Header.Refresh()
    if not Header.anchor then return end
    local size = Cell.Size()
```

with

```lua
    }
end

local function testing()
    return ns.RaidTestMode ~= nil and ns.RaidTestMode.IsOn()
end

-- Any time, combat included: the panel's plain frames follow the group,
-- or show the pretend raid of test mode.
function Header.UpdateVisibility()
    if Header.panel then Header.panel:SetShown(Header.Active() or testing()) end
end

-- Out of combat only: the whole layout for the active size. Every header
-- shows again (Hide + Show lays its cells out anew, OnShow); the cells it
-- does not use lose their anchors (it only SetPoints the ones it shows).
-- In test mode the headers stay hidden and the pretend raid takes their
-- place.
function Header.Refresh()
    if not Header.anchor then return end
    local size = Cell.Size()
```

Replace

```lua
        Cell.Style(button)
        button:ClearAllPoints()
    end
    local on = Header.Enabled()
    for i, h in ipairs(Header.headers) do
        h:Hide()
        if on and i <= #Header.blocks then h:Show() end
    end
    Header.Place(liveCounts())
    placeAnchor()
    Header.UpdateVisibility()
end
```

with

```lua
        Cell.Style(button)
        button:ClearAllPoints()
    end
    local test = testing()
    local on = Header.Enabled() and not test
    for i, h in ipairs(Header.headers) do
        h:Hide()
        if on and i <= #Header.blocks then h:Show() end
    end
    if test then
        ns.RaidTestMode.Show()
    else
        if ns.RaidTestMode then ns.RaidTestMode.Hide() end
        Header.Place(liveCounts())
    end
    placeAnchor()
    Header.UpdateVisibility()
end
```

Replace

```lua
    C_Timer.After(0, function()
        placing = false
        ns.AfterCombat("raidPlace", function()
            Header.Place(liveCounts())
            placeAnchor()
        end)
```

with

```lua
    C_Timer.After(0, function()
        placing = false
        ns.AfterCombat("raidPlace", function()
            if testing() then return end
            Header.Place(liveCounts())
            placeAnchor()
        end)
```

- [ ] **Step 5: Load it**

In `ForeverUnitFrames.toc`, directly after the line `Raid\Header.lua`, add:

```
Raid\TestMode.lua
```

- [ ] **Step 6: Run the tests**

Run: `tests/run raid_testmode` → `41 passed, 0 failed`
Run: `tests/run` → Expected: `19303 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add Raid/TestMode.lua Raid/Header.lua ForeverUnitFrames.toc tests/test_raid_testmode.lua
git commit -m "Raid test mode: a pretend raid of the active size

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## After the last task

- `./install "<AddOns folder of _classic_beta_>"`, `/reload` in game (the new file loads with `/reload`). No Lua error at login. UI only: no moving, casting or fighting.
- Test mode on (options window): a pretend raid of 10 at the panel's position with the gold border; the party's pretend members as before. For 20 and 40 (no raid options window before R4): `/run ForeverUnitFramesDB.raid["<Name>-<Realm>"].general.sizeMode = "40"`, `/reload`, test mode on. Check: centred name and missing health readable at 80 x 38, the dead and the offline cell grey, mana strips on mana users only, clicks on a pretend cell target you.
- Performance at 40 (spec §9): with test mode at 40, watch the frame rate while the pretend raid shows; about 190 widgets per cell in the mock.
- In a 5-player group with `showInParty` on (set with `/run ForeverUnitFramesDB.raid["<Name>-<Realm>"].general.showInParty = true` and `/reload`): the party frames hide, the raid panel shows you and your party; this also checks the `[group]` macro condition.
- Blizzard's raid frames and the manager panel at the left edge stay hidden in a raid; note what is missed from the manager (world markers, ready check button). Getting them back needs `hideBlizzard` off and a `/reload`.
- In a real raid (when available): blocks per group, members joining in combat appear in their block (or below the panel when their block was empty and hidden), the layout tidies up after combat.
- No release yet: R3 (indicators, icons, states) and R4 (options window, locales, wiki) follow; 0.22.0 after the in-game check of the whole part 1.
