# Named unit frame profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Account-wide named unit frame profiles; each character uses one (spec `docs/specs/2026-10-21-named-profiles-design.md`, decision 78).

**Architecture:** A new `Core/UnitProfiles.lua` owns `ForeverUnitFramesDB.profiles` / `.active` (migration, active name,
switch, save as, rename, delete). `Core/Storage.lua` keeps loading and saving one profile — the active one — through it.
The options window gets a "Profiles" navigation entry at the bottom whose page holds the profile rows plus the
export/import/reset blocks moved from General › Profile; General's Profile tab goes, its minimap section moves to the
end of General › Frames.

**Tech Stack:** Lua 5.1 (WoW Forever client 1.60.1, Interface 16001), test harness `tests/run [pattern]` (lua5.1).

## Global Constraints

- Stored key of the default profile: `"Default"`; it always exists, cannot be deleted or renamed; shown as `L.PROFILE_DEFAULT`.
- Names: trimmed, 1–40 characters (`UnitProfiles.NAME_LETTERS = 40`), unique ignoring case.
- Character key: `ns.RaidProfiles.CharKey()` ("Name-Realm").
- Raid frames, click-casting bindings, window position and `newsSeen` are not touched.
- Storage providers keep getting one encoded string: the active profile.
- Texts in all four locales: `Locales/enUS.lua`, `deDE.lua`, `esES.lua`, `frFR.lua` (German: never "ß").
- While building run single test files (`tests/run <pattern>`); the full suite (`tests/run`) only once, in Task 3.
- Commits stay local; push and release only when the maintainer says so.

---

### Task 1: Profiles store, migration and Storage

**Files:**
- Create: `Core/UnitProfiles.lua`
- Modify: `ForeverUnitFrames.toc` (add `Core\UnitProfiles.lua` before `Core\Storage.lua`)
- Modify: `Core/Storage.lua` (`Storage.Load`, `Storage.Save`, `handOver`)
- Modify: `Core/News.lua:130` (`hadSettings`)
- Test: `tests/test_unit_profiles.lua` (new); fix `.profile` reads in `tests/test_boot.lua`, `test_border_size_min.lua`,
  `test_locale.lua`, `test_macro_migration.lua`, `test_news_login.lua`, `test_preset_upgrade.lua`,
  `test_config_extras.lua`, `test_storage.lua`

**Interfaces:**
- Produces (`ns.UnitProfiles`):
  - `DEFAULT = "Default"`, `NAME_LETTERS = 40`
  - `Attach(db)` — migrates and picks this character's profile; `db` may be nil
  - `Active() -> string`, `Stored() -> table|nil` (the active profile as saved), `Names() -> { string }` (Default first, rest sorted ignoring case)
  - `Write(profile)` — puts a copy under the active name (used by Storage.Save)
  - `Switch(name) -> true | nil, why`; `SaveAs(name) -> true | nil, why`; `Rename(name) -> true | nil, why`; `Delete() -> true | nil, why`
  - `why` ∈ `"EMPTY"`, `"TOO_LONG"`, `"TAKEN"`, `"DEFAULT"`, `"GONE"`, `"COMBAT"`
  - fires `ns.Fire("UNIT_PROFILES_CHANGED")` after every successful change

- [ ] **Step 1: Write the failing test** `tests/test_unit_profiles.lua`

```lua
local M = H.M

-- Migration: the old single profile becomes Default.
local ns = H.LoadAddon()
local db = { profile = { player = { width = 300 } } }
local p, src = ns.Storage.Load(db)
H.check("migrated: source", src, "SavedVariables")
H.check("migrated: value", p.player.width, 300)
H.check("migrated: old key gone", db.profile, nil)
H.check("migrated: Default", db.profiles.Default.player.width, 300)
H.check("migrated: active", ns.UnitProfiles.Active(), "Default")

-- Another character's choice is kept; ours falls back to Default.
ns = H.LoadAddon()
db = { profiles = { Default = { player = { width = 200 } }, Healer = { player = { width = 250 } } },
    active = { ["Alt-Testrealm"] = "Healer" } }
p = ns.Storage.Load(db)
H.check("fallback: Default for a character without entry", p.player.width, 200)
local me = ns.RaidProfiles.CharKey()
db.active[me] = "Gone"
ns = H.LoadAddon()
p = ns.Storage.Load(db)
H.check("fallback: a deleted profile reads Default", p.player.width, 200)
H.check("fallback: active name", ns.UnitProfiles.Active(), "Default")

-- Our own choice.
db.active[me] = "Healer"
ns = H.LoadAddon()
ns.Config.Use(ns.Storage.Load(db))
ns.Storage.Attach(db)
H.check("own choice", ns.Config.Get("player", "width"), 250)
H.check("names", table.concat(ns.UnitProfiles.Names(), ","), "Default,Healer")

-- Save writes the active profile only.
ns.Config.Set("player", "width", 260)
ns.Storage.Save()
H.check("save: active written", db.profiles.Healer.player.width, 260)
H.check("save: Default untouched", db.profiles.Default.player.width, 200)

-- Switch.
H.checkTrue("switch", ns.UnitProfiles.Switch("Default"))
H.check("switch: loaded", ns.Config.Get("player", "width"), 200)
H.check("switch: stored for us", db.active[me], "Default")
H.check("switch: the other character keeps its own", db.active["Alt-Testrealm"], "Healer")
H.check("switch: unknown", select(2, ns.UnitProfiles.Switch("Nope")), "GONE")
M.combat = true
H.check("switch: combat", select(2, ns.UnitProfiles.Switch("Healer")), "COMBAT")
M.combat = false

-- Save as: copy of the current settings, we move onto it.
ns.Config.Set("player", "width", 222)
H.checkTrue("save as", ns.UnitProfiles.SaveAs("  Tank  "))
H.check("save as: trimmed name active", ns.UnitProfiles.Active(), "Tank")
H.check("save as: content", db.profiles.Tank.player.width, 222)
H.check("save as: empty", select(2, ns.UnitProfiles.SaveAs("   ")), "EMPTY")
H.check("save as: too long", select(2, ns.UnitProfiles.SaveAs(("x"):rep(41))), "TOO_LONG")
H.check("save as: taken (any case)", select(2, ns.UnitProfiles.SaveAs("healer")), "TAKEN")

-- Rename: every character on it follows; a change of case is allowed.
db.active["Alt-Testrealm"] = "Tank"
H.checkTrue("rename", ns.UnitProfiles.Rename("Tank Prot"))
H.check("rename: moved", db.profiles["Tank Prot"].player.width, 222)
H.check("rename: old gone", db.profiles.Tank, nil)
H.check("rename: other character follows", db.active["Alt-Testrealm"], "Tank Prot")
H.checkTrue("rename: own name, other case", ns.UnitProfiles.Rename("tank prot"))
H.check("rename: taken", select(2, ns.UnitProfiles.Rename("Healer")), "TAKEN")

-- Delete: everybody on it goes to Default, we load Default.
H.checkTrue("delete", ns.UnitProfiles.Delete())
H.check("delete: gone", db.profiles["tank prot"], nil)
H.check("delete: we are on Default", ns.UnitProfiles.Active(), "Default")
H.check("delete: loaded Default", ns.Config.Get("player", "width"), 200)
H.check("delete: other character back to Default", db.active["Alt-Testrealm"], nil)

-- Default cannot be renamed or deleted.
H.check("default: no rename", select(2, ns.UnitProfiles.Rename("X")), "DEFAULT")
H.check("default: no delete", select(2, ns.UnitProfiles.Delete()), "DEFAULT")
```

Check first what the harness calls the combat flag (`grep -n "InCombatLockdown" tests/mock.lua`) and use that
name instead of `M.combat` if it differs; same for how other tests set the second character
(`tests/test_unit_click_cast.lua:177`).

- [ ] **Step 2: Run it to make sure it fails**

Run: `tests/run unit_profiles`
Expected: ERROR — `ns.UnitProfiles` is nil.

- [ ] **Step 3: Create `Core/UnitProfiles.lua`**

```lua
local _, ns = ...

-- Named unit frame profiles (decision 78): account-wide in
-- ForeverUnitFramesDB.profiles, each character's choice in .active
-- ("Name-Realm" -> name). Default always exists. Storage loads and
-- saves the active one; the raid frames keep their own per character.
local UnitProfiles = {}
ns.UnitProfiles = UnitProfiles

UnitProfiles.DEFAULT = "Default"
UnitProfiles.NAME_LETTERS = 40

local db = { profiles = {}, active = {} }
local active = UnitProfiles.DEFAULT

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

local function trimmed(name)
    return type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
end

local function charKey() return ns.RaidProfiles.CharKey() end

-- The stored name with this name ignoring case, if any.
local function find(name)
    local key = name:lower()
    for stored in pairs(db.profiles) do
        if stored:lower() == key then return stored end
    end
    return nil
end

-- At login, before Storage reads the profile. The old single profile
-- becomes Default; it wins over a Default already there, since only an
-- older version (which knows one profile) writes it.
function UnitProfiles.Attach(saved)
    db = type(saved) == "table" and saved or { }
    if type(db.profiles) ~= "table" then db.profiles = {} end
    if type(db.active) ~= "table" then db.active = {} end
    if type(db.profile) == "table" then db.profiles[UnitProfiles.DEFAULT] = db.profile end
    db.profile = nil
    for name, p in pairs(db.profiles) do
        if type(name) ~= "string" or type(p) ~= "table" then db.profiles[name] = nil end
    end
    local chosen = db.active[charKey()]
    active = (type(chosen) == "string" and db.profiles[chosen]) and chosen or UnitProfiles.DEFAULT
end

function UnitProfiles.Active() return active end

function UnitProfiles.Stored() return db.profiles[active] end

function UnitProfiles.Names()
    local names = {}
    for name in pairs(db.profiles) do
        if name ~= UnitProfiles.DEFAULT then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    table.insert(names, 1, UnitProfiles.DEFAULT)
    return names
end

function UnitProfiles.Write(profile)
    db.profiles[active] = copy(profile)
end

local function setActive(name)
    active = name
    db.active[charKey()] = name ~= UnitProfiles.DEFAULT and name or nil
end

-- Loads a stored profile into the frames (Config.Import keeps the
-- personal settings, the language).
local function load(name)
    ns.Storage.Save()   -- the current one, before it is left
    setActive(name)
    ns.Config.Import(ns.Settings.Sanitise(copy(db.profiles[name] or {})))
    ns.Storage.Save()
end

local function changed() ns.Fire("UNIT_PROFILES_CHANGED") return true end

-- nil and why for a name that cannot be used; except: the stored name
-- that may keep it (renaming changes only the case).
local function refuse(name, except)
    if name == "" then return "EMPTY" end
    if #name > UnitProfiles.NAME_LETTERS then return "TOO_LONG" end
    local taken = find(name)
    if taken and taken ~= except then return "TAKEN" end
    return nil
end

function UnitProfiles.Switch(name)
    if InCombatLockdown() then return nil, "COMBAT" end
    if not db.profiles[name] then return nil, "GONE" end
    if name == active then return true end
    load(name)
    return changed()
end

-- The current settings under a new name; this character moves onto it.
-- Written at once: Storage.Save skips a text equal to the last one.
function UnitProfiles.SaveAs(name)
    name = trimmed(name)
    local why = refuse(name)
    if why then return nil, why end
    ns.Storage.Save()
    db.profiles[name] = copy(ns.Config.Profile())
    setActive(name)
    return changed()
end

function UnitProfiles.Rename(name)
    name = trimmed(name)
    if active == UnitProfiles.DEFAULT then return nil, "DEFAULT" end
    local why = refuse(name, active)
    if why then return nil, why end
    if name == active then return true end   -- the move below would drop it
    local old = active
    db.profiles[name], db.profiles[old] = db.profiles[old], nil
    for key, chosen in pairs(db.active) do
        if chosen == old then db.active[key] = name end
    end
    active = name
    return changed()
end

function UnitProfiles.Delete()
    if active == UnitProfiles.DEFAULT then return nil, "DEFAULT" end
    if InCombatLockdown() then return nil, "COMBAT" end
    local old = active
    for key, chosen in pairs(db.active) do
        if chosen == old then db.active[key] = nil end
    end
    -- Not saved back: load() would write the current settings under it again.
    active = UnitProfiles.DEFAULT
    db.profiles[old] = nil
    ns.Config.Import(ns.Settings.Sanitise(copy(db.profiles[UnitProfiles.DEFAULT] or {})))
    ns.Storage.Save()
    return changed()
end
```

Add `Core\UnitProfiles.lua` to `ForeverUnitFrames.toc` on the line before `Core\Storage.lua`. If the test harness
loads files from its own list (`grep -n "Storage.lua" tests/harness.lua tests/mock.lua`), add it there too, before
`Core/Storage.lua`.

- [ ] **Step 4: Wire Storage and News**

`Core/Storage.lua`, `Storage.Load` — replace the SavedVariables branch:

```lua
function Storage.Load(db)
    ns.UnitProfiles.Attach(db)
    local stored = ns.UnitProfiles.Stored()
    if type(stored) == "table" then
        local profile = ns.Settings.Sanitise(stored)
        -- Saved before the revised look of 0.23.0: it keeps the look it had.
        if ns.PresetUpgrade.Due(db) then ns.PresetUpgrade.Apply(profile) end
        return from("SavedVariables", false, profile)
    end
```

(the provider, macro and defaults branches stay). In `Storage.Save` replace `attached.profile = copy(profile)` with
`ns.UnitProfiles.Write(profile)`; in `handOver` replace `attached and attached.profile` with
`attached and ns.UnitProfiles.Stored()`. The `copy` helper in Storage stays only if still used; delete it otherwise.

`Core/News.lua:130`:

```lua
    hadSettings = type(saved.profile) == "table" or type(saved.profiles) == "table" or type(saved.raid) == "table"
```

- [ ] **Step 5: Run the new test and the storage tests**

Run: `tests/run unit_profiles` then `tests/run storage`, `tests/run boot`, `tests/run macro_migration`,
`tests/run news_login`, `tests/run preset_upgrade`, `tests/run config_extras`, `tests/run border_size_min`, `tests/run locale`
Expected: `test_unit_profiles` passes; the others fail where they read the old key.

- [ ] **Step 6: Update the old assertions**

```bash
sed -i 's/ForeverUnitFramesDB\.profile\b/ForeverUnitFramesDB.profiles.Default/g' tests/test_boot.lua \
  tests/test_border_size_min.lua tests/test_locale.lua tests/test_macro_migration.lua tests/test_news_login.lua \
  tests/test_config_extras.lua
sed -i 's/svdb\.profile\b/svdb.profiles.Default/g' tests/test_storage.lua
```

Then fix by hand what is left (`db.profile` in `test_news_login.lua:46` and `test_preset_upgrade.lua:97,103` →
`db.profiles.Default`). A check like `ForeverUnitFramesDB.profiles.Default, nil` is right: Attach creates the empty
`profiles` table. Re-run the files from Step 5. Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add Core/UnitProfiles.lua Core/Storage.lua Core/News.lua ForeverUnitFrames.toc tests/
git commit -m "Named unit frame profiles: store, migration, Storage on the active one"
```

---

### Task 2: Options window — Profiles page, General without Profile

**Files:**
- Modify: `Options/Schema.lua` (GENERAL: drop the `profile` tab, minimap section to the end of `frames`; new `Schema.PROFILES`; `Schema.Tabs`; `applicable`)
- Modify: `Options/Window.lua` (`isFrameScope`, `createNav`, `pageFor`, `buildProfilePage`, new `profileRows`, `UNIT_PROFILES_CHANGED` listener)
- Modify: `Locales/enUS.lua`, `deDE.lua`, `esES.lua`, `frFR.lua`
- Test: `tests/test_window_profiles.lua` (new); update `tests/test_schema.lua:41`, `test_menu_layout.lua:63`,
  `test_minimap_button.lua:39`, `test_window.lua:82,137,207,298`, `test_border_size_min.lua:62`

**Interfaces:**
- Consumes: `ns.UnitProfiles.*` from Task 1.
- Produces: navigation key and scope `"profiles"`, tab id `"profiles"`; `Options.profilePicker`, `Options.profileName`,
  `Options.profileSaveButton`, `Options.profileRenameButton`, `Options.profileDeleteButton`, `Options.profileMessage`
  (the tests use them).

- [ ] **Step 1: Write the failing test** `tests/test_window_profiles.lua`

```lua
local ns = H.LoadAddon()
H.Boot(ns)   -- use the same login helper as tests/test_window.lua does
local O = ns.Options

-- General has no Profile tab any more; the minimap section ends Frames.
local ids = {}
for _, tab in ipairs(ns.Schema.Tabs("general")) do ids[#ids + 1] = tab.id end
H.check("general tabs", table.concat(ids, ","), "frames,clickCast,appearance,bars,status")
local frames = ns.Schema.Tabs("general")[1]
H.check("minimap last in Frames", frames.sections[#frames.sections].id, "minimap")

-- The Profiles page from the navigation.
H.checkTrue("nav entry", O.navButtons and O.navButtons.profiles)
O.Open("profiles")
H.check("scope", O.currentScope, "profiles")
H.check("its tab", O.currentTab, "profiles")
H.checkTrue("export moved here", O.exportArea and O.exportArea:IsVisible())
H.checkTrue("frame footer hidden", not O.copyRow:IsShown())

-- Save as from the page.
O.profileName:SetText("Healer")
O.profileSaveButton:Click()
H.check("saved and active", ns.UnitProfiles.Active(), "Healer")
H.check("picker shows it", O.profilePicker.button.text:GetText(), "Healer")
O.profileName:SetText("healer")
O.profileSaveButton:Click()
H.check("taken: message", O.profileMessage:GetText(), ns.L.PROFILE_NAME_TAKEN)

-- Delete needs two clicks.
O.profileDeleteButton:Click()
H.check("armed only", ns.UnitProfiles.Active(), "Healer")
O.profileDeleteButton:Click()
H.check("deleted", ns.UnitProfiles.Active(), "Default")
H.check("default shown localised", O.profilePicker.button.text:GetText(), ns.L.PROFILE_DEFAULT)
```

Before running, look at how `tests/test_window.lua` boots and clicks (`H.Boot`, `:Click()`, the button's text field)
and use the same calls; the assertions stay.

- [ ] **Step 2: Run it to make sure it fails**

Run: `tests/run window_profiles`
Expected: FAIL on "general tabs" (still lists `profile`) and on the nav entry.

- [ ] **Step 3: Schema**

In `Options/Schema.lua` delete the GENERAL entry `{ id = "profile", custom = "profile", sections = { minimap } }`
(and its comment line); append the minimap section to the `frames` tab:

```lua
    { id = "frames", sections = {
        { id = "frames", keys = { "unitFrames" }, frames = true },
        -- Click-casting (decision 76): the unit frames' switch; the
        -- bindings are on the next tab.
        { id = "clickCast", keys = { "clickCast" } },
        -- Still in the profile; its page left with General's Profile tab (decision 78).
        { id = "minimap", keys = { "minimapShow", "minimapAngle" } },
    } },
```

After `Schema.FRAME`:

```lua
-- The navigation's last entry: the named profiles, export, import, reset
-- (Options/Window.lua builds the page).
Schema.PROFILES = {
    { id = "profiles", custom = "profiles", sections = {} },
}
```

`applicable`: `if tab.custom then return true end`. `Schema.Tabs`:

```lua
    local source = scope == "general" and Schema.GENERAL or scope == "profiles" and Schema.PROFILES or Schema.FRAME
```

- [ ] **Step 4: Window**

`Options/Window.lua:43`:

```lua
local function isFrameScope(scope) return scope ~= "general" and scope ~= "profiles" end
```

`createNav`, after the frames loop and before `languageRow(nav)`:

```lua
    y = y + 6
    local below = line(nav, "border")
    below:SetHeight(1)
    below:SetPoint("TOPLEFT", nav, "TOPLEFT", INSET, -y)
    below:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -INSET, -y)
    y = y + 7
    navButton(nav, "profiles", L.NAV_PROFILES, y)
```

`pageFor`: `if tab.custom == "profiles" then buildProfilePage(page, scope, tab)`. Before `CUSTOM_BLOCKS`, the
profile rows (same widgets and two-click button as the raid window's own profiles, `Raid/Options/Profiles.lua:186-235`):

```lua
local PROFILE_WHY = {
    EMPTY = function() return L.PROFILE_NAME_EMPTY end,
    TOO_LONG = function() return L.PROFILE_NAME_TOO_LONG:format(ns.UnitProfiles.NAME_LETTERS) end,
    TAKEN = function() return L.PROFILE_NAME_TAKEN end,
    DEFAULT = function() return L.PROFILE_DEFAULT_FIXED end,
    GONE = function() return L.PROFILE_GONE end,
    COMBAT = function() return L.PROFILE_COMBAT end,
}

local function profileText(name)
    return name == ns.UnitProfiles.DEFAULT and L.PROFILE_DEFAULT or name
end

local function profileSay(ok, why, done)
    Options.profileMessage:SetText(ok and done or PROFILE_WHY[why]())
    Style.Paint(Options.profileMessage, ok and "accent" or "error")
end

local function typedProfileName() return Options.profileName:GetText() or "" end

local function profileRows(page, stack)
    local P = ns.UnitProfiles
    local picker = Widgets.Dropdown(page, {
        label = L.PROFILE_ACTIVE,
        items = function()
            local items = {}
            for _, name in ipairs(P.Names()) do items[#items + 1] = { value = name, text = profileText(name) } end
            return items
        end,
        get = P.Active,
        set = function(name) local ok, why = P.Switch(name); profileSay(ok, why, L.PROFILE_SWITCHED:format(profileText(name))) end,
    })
    stack.add(picker)
    local nameRow = Widgets.NewRow(page, { label = L.PROFILE_NAME })
    local box = Widgets.TextBox(nameRow, { width = BUTTON_W + 40, maxLetters = P.NAME_LETTERS,
        get = function() return "" end, set = function() return true end })
    box:SetPoint("LEFT", nameRow, "LEFT", Widgets.CONTROL_X, 0)
    local function act(fn, done)
        box:ClearFocus()
        local name = typedProfileName():match("^%s*(.-)%s*$")
        local ok, why = fn(name)
        if ok then box:SetText("") end
        profileSay(ok, why, done:format(name))
    end
    local save = Widgets.Button(nameRow, { text = L.PROFILE_SAVE_AS, width = BUTTON_W,
        onClick = function() act(P.SaveAs, L.PROFILE_SAVED) end })
    save:SetPoint("LEFT", box, "RIGHT", FOOTER_GAP, 0)
    local rename = Widgets.Button(nameRow, { text = L.PROFILE_RENAME, width = BUTTON_W,
        onClick = function() act(P.Rename, L.PROFILE_RENAMED) end })
    rename:SetPoint("LEFT", save, "RIGHT", FOOTER_GAP, 0)
    function nameRow:SetEnabled(on) box:SetEnabled(on); save:SetEnabled(on); rename:SetEnabled(on and P.Active() ~= P.DEFAULT) end
    function nameRow:Refresh() rename:SetEnabled(P.Active() ~= P.DEFAULT) end
    stack.add(nameRow)
    local deleteBlock = newBlock(page)
    local delete = confirmButton(deleteBlock, L.PROFILE_DELETE, function()
        local name = P.Active()
        local ok, why = P.Delete()
        profileSay(ok, why, L.PROFILE_DELETED:format(name))
    end)
    delete:SetPoint("TOPLEFT", deleteBlock, "TOPLEFT", INSET, -6)
    local message = Style.Text(deleteBlock, 11, "muted")
    message:SetPoint("LEFT", delete, "RIGHT", FOOTER_GAP, 0)
    message:SetJustifyH("LEFT")
    function deleteBlock:SetEnabled(on) delete:SetEnabled(on and P.Active() ~= P.DEFAULT) end
    function deleteBlock:Refresh() delete:SetEnabled(P.Active() ~= P.DEFAULT) end
    stack.add(deleteBlock, BUTTON_H + 12)
    Options.profilePicker, Options.profileName, Options.profileSaveButton = picker, box, save
    Options.profileRenameButton, Options.profileDeleteButton, Options.profileMessage = rename, delete, message
end
```

Check the real names before using them: `Widgets.NewRow`, `Widgets.CONTROL_X`, and whether a row's `Refresh` is
called with the combat state (`setRowStates` calls `SetEnabled(on)` only on change — `Refresh` must therefore not
enable anything in combat: guard with `and not InCombatLockdown()` in both `Refresh` functions).

`buildProfilePage` — the profile rows first, then the moved blocks; no sections:

```lua
-- The Profiles page: the named profiles, then export, import, reset
-- (they act on the active profile).
local function buildProfilePage(page)
    local stack = newStack(page)
    local header = Widgets.Header(page, L.PROFILES_SECTION)
    header.isSection = true
    stack.add(header)
    profileRows(page, stack)
    for _, entry in ipairs(CUSTOM_BLOCKS) do
        header = Widgets.Header(page, L[entry.header])
        header.isSection = true
        stack.add(header)
        stack.add(entry.build(page))
    end
    stack.finish()
end
```

Next to the `CONFIG_CHANGED` listener (line ~944), repaint the open profiles page:

```lua
ns.Listen("UNIT_PROFILES_CHANGED", function()
    if Options.IsOpen() and Options.currentScope == "profiles" then
        forEachRow(function(row) row:Refresh() end)
    end
end)
```

- [ ] **Step 5: Locales**

Remove `L.TAB_profile` in all four files; add (enUS shown, then the translations):

```lua
L.NAV_PROFILES = "Profiles"; L.TAB_profiles = "Profiles"; L.PROFILES_SECTION = "Profiles"
L.PROFILE_DEFAULT = "Default"
L.PROFILE_ACTIVE = "Active profile"; L.PROFILE_NAME = "Name"
L.PROFILE_SAVE_AS = "Save as"; L.PROFILE_RENAME = "Rename"; L.PROFILE_DELETE = "Delete profile"
L.PROFILE_SAVED = "Saved as %s; this character uses it now."; L.PROFILE_RENAMED = "Renamed to %s."
L.PROFILE_DELETED = "%s deleted; its characters use Default."; L.PROFILE_SWITCHED = "This character uses %s."
L.PROFILE_NAME_EMPTY = "Type a name first."; L.PROFILE_NAME_TOO_LONG = "At most %d characters."
L.PROFILE_NAME_TAKEN = "A profile with this name exists."
L.PROFILE_DEFAULT_FIXED = "Default cannot be renamed or deleted."
L.PROFILE_GONE = "This profile no longer exists."; L.PROFILE_COMBAT = "Not in combat."
```

deDE: Profile / Profile / Profile; Standard; Aktives Profil; Name; Speichern unter; Umbenennen; Profil löschen;
„Als %s gespeichert, dieser Charakter nutzt es jetzt.“; „In %s umbenannt.“; „%s gelöscht, seine Charaktere nutzen
Standard.“; „Dieser Charakter nutzt %s.“; „Zuerst einen Namen eingeben.“; „Höchstens %d Zeichen.“; „Ein Profil mit
diesem Namen gibt es schon.“; „Standard lässt sich weder umbenennen noch löschen.“; „Dieses Profil gibt es nicht
mehr.“; „Nicht im Kampf.“ — esES and frFR in the same sense (Predeterminado / Par défaut). Keep each file's line style.

`SECTION_minimap` stays; if `tests/test_locale.lua` checks every key in every locale, run it now.

- [ ] **Step 6: Update the old tests**

- `tests/test_schema.lua:41`: General has five tabs, the last `status`; add `H.check("profiles page", S.Tabs("profiles")[1].id, "profiles")`.
- `tests/test_menu_layout.lua:63`: `where("general", "minimapShow")` → `"frames:minimap"`, label "General: minimap button on Frames".
- `tests/test_minimap_button.lua:39`: `"in Frames", tab, "frames"`.
- `tests/test_window.lua:82,137,207,298` and `tests/test_border_size_min.lua:62`: `Open("general", "profile")` /
  `SelectTab("profile")` → `Open("profiles")`.

- [ ] **Step 7: Run the window tests**

Run: `tests/run window`, `tests/run schema`, `tests/run menu_layout`, `tests/run minimap`, `tests/run border_size_min`, `tests/run locale`
Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add Options/ Locales/ tests/
git commit -m "Options: Profiles page at the bottom of the navigation; minimap button on General > Frames"
```

---

### Task 3: News, wiki, version, full suite

**Files:**
- Modify: `Core/News.lua` (entry `0.32.0`), the four locales (its lines), `ForeverUnitFrames.toc` (`## Version: 0.32.0`)
- Modify: `docs/wiki/Home.md` (section "Profiles", line ~69), `docs/wiki/Settings-General.md` (Profile section → minimap on Frames)

- [ ] **Step 1: What's New entry** — NOT announced (maintainer: no announcement); it only shows via `/fuf news`

```lua
    -- Named unit frame profiles; the Profiles page (decision 78). Not announced.
    ["0.32.0"] = {
        lines = { "NEWS_0_32_0_PROFILES", "NEWS_0_32_0_PAGE" },
    },
```

Texts (enUS; translate for deDE/esES/frFR):
`L.NEWS_0_32_0_PROFILES = "Named profiles: save your settings under a name and pick them on any character, e.g. one layout per class."`
`L.NEWS_0_32_0_PAGE = "Profiles, export, import and reset are now at the bottom of the navigation; the minimap button moved to General > Frames."`

- [ ] **Step 2: Wiki** — Home "Profiles": the Profiles page (active profile, save as, rename, delete; export/import/reset
act on the active profile; Default; raid frames keep their own per character). Settings-General: delete the
**Profile** tab section and its entry in the contents line; list the minimap button under **Frames**.

- [ ] **Step 3: Full suite once**

Run: `tests/run` (takes a while; the 8 GB limit is set by the script)
Expected: `N passed, 0 failed`.

- [ ] **Step 4: Commit**

```bash
git add Core/News.lua Locales/ ForeverUnitFrames.toc docs/wiki/
git commit -m "0.32.0: named profiles — news, wiki"
```

- [ ] **Step 5: Hand over** — install into Forever (`./install "<AddOns folder of _classic_beta_>"`) for the maintainer
to try in game.
No push or release without the maintainer's go.
