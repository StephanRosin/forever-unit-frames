# Forever Unit Frames — Raid plan R4d: What's New window

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After an update, the addon shows once, at login, a small "What's New" window with the news of the new version (0.22.0: the raid frames), in the style of the options windows, with *Open raid options* and *Close*. A fresh install shows nothing. `/fuf news` shows it again at any time.

**Architecture:** `Core/News.lua` holds the news, keyed by the TOC version (`News.ENTRIES["0.22.0"] = { lines = { locale keys }, action = { text = key, run = fn } }`), and the rule: `News.Begin(db)` at the start of PLAYER_LOGIN notes whether the SavedVariables held settings before this login; `News.AtLogin()` runs last, through `ns.AfterCombat("news", …)` (so after the frames and the raid panel, and after combat), shows the window if due and records the version in `ForeverUnitFramesDB.newsSeen`. `Options/News.lua` is the window (`ns.NewsWindow`). `Core/Commands.lua` gets `/fuf news`.

**Tech Stack:** Lua 5.1, WoW: Forever API (Interface 16001, build 1.60.1.70205), offline tests with `lua5.1` + `tests/mock.lua` (`tests/run`).

Raid plan order: R1 … R4a, R4c, R4b (all done) → **R4d What's New window (this plan)**.

Base: the last commit of R4b ("Version 0.22.0: raid frames in the CurseForge description"); `tests/run` there: `23935 passed, 0 failed`. Every task below was replayed in order on a scratch worktree from that commit; the outputs under "Expected" are what `tests/run` printed there.

## Global Constraints

- Everything in English: file names, identifiers, comments. Every new user-facing string is a locale key in all four languages, `Locales/enUS.lua`, `deDE.lua`, `esES.lua`, `frFR.lua` (`tests/test_locale.lua` requires each English key in every language with the same `%` placeholders); German in the style of the existing `deDE` strings.
- Target client: WoW: Forever, `## Interface: 16001`. Client facts only from the Forever UI source (game type `camelot`); the ones used are in the table below. Never write the name of the local lookup tool into the repository.
- The unit frames, the raid frames and both options windows stay the same: no setting, key, code, scope letter or default changes; no existing window code changes. The SavedVariables gain one top-level key, `newsSeen` (a version string); `Core/Storage.lua` keeps writing only `profile` and `version`.
- No secret-value maths, comparisons or truth tests (nothing here reads a unit value). No secure snippets; the news window is a plain frame, nothing protected is touched (`#M.blocked == 0` in every new test). `ns.Print` gets plain locale strings only.
- `ns.On` throws on unknown event names in the client: no game event is added (combat waits through `ns.AfterCombat`, which already listens to `PLAYER_REGEN_ENABLED`).
- The mock stays faithful: it may be stricter than the client source, never more permissive.
- Public repository: no local paths, host names, character names or anything about the author's machine in files or commit messages. Test names are neutral.
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
- Do not push. Every task ends with `tests/run` green and one commit (`git add` only the files the task lists).
- A full `tests/run` takes about a minute and a half and several GB of memory (as before).
- No new setting. New locale keys (12): `NEWS_TITLE` (one `%s`), `NEWS_OPEN_RAID`, `NEWS_CLOSE`, `NEWS_0_22_0_RAID`, `NEWS_0_22_0_BLOCKS`, `NEWS_0_22_0_PROFILES`, `NEWS_0_22_0_DEBUFFS`, `NEWS_0_22_0_ICONS`, `NEWS_0_22_0_WINDOW`, `NEWS_0_22_0_BLIZZARD` (Task 1); `NEWS_AGAIN`, `NEWS_NONE` (Task 3). Changed: `HELP` names `/fuf news` (Task 3).
- No existing test is edited. `tests/mock.lua` changes once (Task 1): `C_AddOns.GetAddOnMetadata` answers only this addon's `Version` (stricter than before); its default stays `"0.1.0"`, a version without news, so no existing test sees the window.
- Do not run `tools/release`, `tools/publish_wiki` or anything that uploads, tags or pushes.

## Client facts this plan relies on (build 1.60.1.70205)

| Fact | Source |
|---|---|
| `C_AddOns.GetAddOnMetadata(name, variable) -> value` (cstring); Blizzard's own code reads `"Version"` with it and checks the result for nil (`AddonList.lua`). Already used by `Options/Window.lua` for the title bar's version. | `Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua`, `Blizzard_AddOnList/AddonList.lua` |
| `UISpecialFrames`: frames named there close with ESC (as both options windows). | used since plan 2 |

Nothing else beyond the earlier plans: the window uses the same frame methods as `Options/Window.lua` and `Raid/Options/Window.lua`.

## Design decisions

- **The rule (Core/News.lua, written there as a comment):** `ForeverUnitFramesDB.newsSeen` is the newest version this account has had news for. At login, after everything else is built and out of combat, the news of the TOC version shows when that version has an entry **and** either `newsSeen` is an older version, or there is no `newsSeen` (or one that is not a string) but the SavedVariables held a unit-frame profile (`profile` table) or raid profiles (`raid` table) before this login — an update from a version before the news. A fresh install (neither) shows nothing. A login that finds an entry records its version as `newsSeen` unless `newsSeen` is newer already (a downgrade keeps it). A version without an entry shows and records nothing, so a bug-fix release without news does not swallow the next one's. The SavedVariables are looked at in `News.Begin`, the first thing PLAYER_LOGIN does after creating the table: before `Storage` (which may migrate a macro backup into `profile`) and `RaidProfiles.Attach` (which creates `raid`) write to it. An old macro backup without SavedVariables counts as a fresh install.
- **Versions compare number by number** (`0.10.0` is newer than `0.9.0`; a missing number counts as 0).
- **When:** `ns.AfterCombat("news", News.AtLogin)` at the end of the PLAYER_LOGIN handler: out of combat it runs at once, after the single frames, party and raid panel (all built in that handler or in combat-queue jobs queued before it); in combat it waits for the end of combat and runs after those jobs. It is recorded when it shows, not before: a login in combat followed by a disconnect shows it next time.
- **Over other windows:** no special rule. At login no options window is open; `/fuf news` is asked for. *Open raid options* closes the news first.
- **The window:** 560 × 440, the options windows' look (`Style.Fill` "bg", `Style.Border`, a title bar in "panel" with the title, the addon name in muted text and the drawn close cross, a footer with buttons), strata HIGH, movable by the title bar (position not saved), ESC closes it. One line per entry key with an accent bullet, wrapping at the window's width. Right in the footer: the entry's action (*Open raid options*; hidden for an entry without action) and *Close*; left a muted hint "/fuf news shows this again." (Task 3). Texts are set each time it opens and again on LANGUAGE_CHANGED while open (no rebuild). The title-bar helpers are a third copy of the two windows' local ones: the existing windows stay unchanged.
- **Content of 0.22.0:** seven lines, all raid frames: sizes and look; blocks and sorting; per-size profiles with a look of their own and copy/reset/export/import; dispellable debuffs (centre icon or corner square) and corner indicators; role/leader/looter/ready icons, range, aggro and target lines; their own window, minimap button and test mode; Blizzard's raid frames hidden and the raid view for a 5-player group. The commits since v0.21.0 that are not raid commits change internals only (mock, factories, movers, comments); the one unit-window change, the *Raid frames…* button, is named in the window line.
- **`/fuf news`:** opens the news of the TOC version (also in combat: a plain frame); a version without news prints `NEWS_NONE`. It never changes `newsSeen`. The help line, `docs/curseforge/description.md` and `docs/wiki/Home.md` name it.
- **Mock:** `C_AddOns.GetAddOnMetadata(name, field)` asserts both arguments, returns `M.addonVersion` (default `"0.1.0"`, set by `M.Reset`) for this addon's `Version` and nil for anything else.

---

### Task 1: What's New window: the news of a version, the news of 0.22.0

**Files:**
- Create: `Core/News.lua`
- Create: `Options/News.lua`
- Modify: `ForeverUnitFrames.toc`
- Modify: `tests/mock.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_news_window.lua`

**Interfaces:**
- Consumes: `ns.Style` (`Fill`, `Border`, `Text`, `COLORS`), `ns.Widgets.Button`, `ns.RaidOptions.Open` / `IsOpen` / `Close`, `ns.L` (`ADDON_NAME`), internal event `LANGUAGE_CHANGED`, `C_AddOns.GetAddOnMetadata`, `ns.name`.
- Produces: `ns.News.ENTRIES` (`[version] = { lines = { keys }, action = { text = key, run = fn } or nil }`), `ns.News.Current()` (the TOC version), `ns.News.Entry(version)` (entry or nil); `ns.NewsWindow.Open(version)` (false and nothing shown without an entry), `Close()`, `IsOpen()`, fields `frame` (`frame.titleBar.title`, `.addon`, `.close`), `lines` (`{ bullet, text }` per line), `actionButton`, `closeButton`; global frame name `ForeverUnitFramesNews`; mock `M.addonVersion`; locale keys `NEWS_TITLE`, `NEWS_OPEN_RAID`, `NEWS_CLOSE`, `NEWS_0_22_0_*` (7).

- [ ] **Step 1: Write the failing test**

Create `tests/test_news_window.lua`:

```lua
-- The What's New window (Options/News.lua) and the news it shows
-- (Core/News.lua): one line per entry, in the style of the options
-- windows; the entry's action button and Close; ESC; the language.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local News, NW, L = ns.News, ns.NewsWindow, ns.L
local chatBefore = #M.chat

local function click(button) button:GetScript("OnClick")(button) end
local function shownLines()
    local n = 0
    for _, item in ipairs(NW.lines) do if item.text:IsShown() then n = n + 1 end end
    return n
end

-- The version is the TOC's.
H.check("the mock's version", News.Current(), "0.1.0")
M.addonVersion = "0.22.0"
H.check("the TOC's version", News.Current(), "0.22.0")
H.checkTrue("0.22.0 has news", News.Entry("0.22.0"))
H.check("a version without news", News.Entry("0.1.0"), nil)
H.check("no version", News.Entry(nil), nil)

-- Every line and action names an English text (test_locale.lua holds the
-- other languages to the same keys).
for version, entry in pairs(News.ENTRIES) do
    for _, key in ipairs(entry.lines) do
        H.check(version .. ": " .. key, type(rawget(ns.Locales.enUS, key)), "string")
    end
    if entry.action then
        H.check(version .. ": action text", type(rawget(ns.Locales.enUS, entry.action.text)), "string")
        H.check(version .. ": action", type(entry.action.run), "function")
    end
end

-- A version without news opens nothing.
H.check("no news: refused", NW.Open("0.1.0"), false)
H.check("no news: no window", NW.IsOpen(), false)

-- The news of 0.22.0, in the style of the options windows.
H.check("opens", NW.Open("0.22.0"), true)
H.checkTrue("open", NW.IsOpen())
local f = NW.frame
H.check("title", f.titleBar.title:GetText(), "What's new in 0.22.0")
H.check("addon name", f.titleBar.addon:GetText(), "Forever Unit Frames")
H.check("strata of the options windows", f:GetFrameStrata(), "HIGH")
H.check("bordered like them", f.edges[1]._color[1], ns.Style.COLORS.border[1])
H.check("not protected", f:IsProtected(), false)
local escCount = 0
for _, name in ipairs(UISpecialFrames) do if name == "ForeverUnitFramesNews" then escCount = escCount + 1 end end
H.check("ESC closes it", escCount, 1)
H.check("seven lines", shownLines(), 7)
H.check("raid frames first", NW.lines[1].text:GetText(), L.NEWS_0_22_0_RAID)
H.check("the last line", NW.lines[7].text:GetText(), L.NEWS_0_22_0_BLIZZARD)
H.check("a bullet each", NW.lines[3].bullet:GetText(), "•")
local _, below = NW.lines[2].text:GetPoint(1)
H.check("one below the other", below, NW.lines[1].text)
H.check("lines wrap", NW.lines[1].text:GetWordWrap(), true)
H.check("action button", NW.actionButton.text:GetText(), "Open raid options")
H.checkTrue("action shown", NW.actionButton:IsShown())
H.check("close button", NW.closeButton.text:GetText(), "Close")

-- Close, the cross and opening again.
click(NW.closeButton)
H.check("Close closes", NW.IsOpen(), false)
NW.Open("0.22.0")
click(f.titleBar.close)
H.check("the cross closes", NW.IsOpen(), false)
H.check("the same window again", (NW.Open("0.22.0") and NW.frame), f)
escCount = 0
for _, name in ipairs(UISpecialFrames) do if name == "ForeverUnitFramesNews" then escCount = escCount + 1 end end
H.check("ESC entry not doubled", escCount, 1)

-- Open raid options: the raid window opens, the news closes.
click(NW.actionButton)
H.check("action closes the news", NW.IsOpen(), false)
H.checkTrue("raid options open", ns.RaidOptions.IsOpen())
ns.RaidOptions.Close()

-- A new language while it is open.
NW.Open("0.22.0")
ns.Config.Set("general", "language", "deDE")
H.check("German title", f.titleBar.title:GetText(), "Neu in 0.22.0")
H.check("German line", NW.lines[1].text:GetText(), ns.Locales.deDE.NEWS_0_22_0_RAID)
H.check("German close", NW.closeButton.text:GetText(), "Schließen")
ns.Config.Set("general", "language", "AUTO")
H.check("English again", NW.closeButton.text:GetText(), "Close")

-- An entry with fewer lines and no action.
News.ENTRIES["9.9.9"] = { lines = { "NEWS_0_22_0_RAID", "NEWS_0_22_0_ICONS" } }
NW.Open("9.9.9")
H.check("its lines only", shownLines(), 2)
H.check("its title", f.titleBar.title:GetText(), "What's new in 9.9.9")
H.check("no action button", NW.actionButton:IsShown(), false)
NW.Open("0.22.0")
H.check("all lines again", shownLines(), 7)
H.checkTrue("action button again", NW.actionButton:IsShown())
News.ENTRIES["9.9.9"] = nil
NW.Close()

H.check("nothing printed", #M.chat, chatBefore)
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_news_window.lua`

Expected:

```text
test_news_window.lua
  ERROR test_news_window.lua:20: attempt to index local 'News' (a nil value)
0 passed, 1 failed
```

- [ ] **Step 3: The news**

Create `Core/News.lua`:

```lua
local _, ns = ...

-- What's new: the news of a version, keyed by the version in the TOC
-- (## Version). An entry lists locale keys, one line each, and may name
-- an action for the window's left button. A version without an entry has
-- no news. Options/News.lua shows an entry.
local News = {}
ns.News = News

News.ENTRIES = {
    ["0.22.0"] = {
        lines = { "NEWS_0_22_0_RAID", "NEWS_0_22_0_BLOCKS", "NEWS_0_22_0_PROFILES", "NEWS_0_22_0_DEBUFFS",
            "NEWS_0_22_0_ICONS", "NEWS_0_22_0_WINDOW", "NEWS_0_22_0_BLIZZARD" },
        action = { text = "NEWS_OPEN_RAID", run = function() ns.RaidOptions.Open() end },
    },
}

-- The version this client loaded (## Version in the TOC).
function News.Current()
    return C_AddOns.GetAddOnMetadata(ns.name, "Version")
end

-- The news of a version, or nil.
function News.Entry(version)
    if type(version) ~= "string" then return nil end
    return News.ENTRIES[version]
end
```

- [ ] **Step 4: The window**

Create `Options/News.lua`:

```lua
local _, ns = ...

-- The What's New window: one version's news (Core/News.lua) as a list,
-- in the style of the options windows (the same colours, title bar and
-- close cross). Its left button runs the entry's action (0.22.0: opens
-- the raid options window) and closes it; Close closes it. A plain
-- (non-secure) frame; ESC closes it too. Every text is set when it
-- opens, and again when the language changes while it is open.
local NewsWindow = {}
ns.NewsWindow = NewsWindow

local Style, Widgets, L = ns.Style, ns.Widgets, ns.L

local WINDOW_NAME = "ForeverUnitFramesNews"
local WIDTH, HEIGHT = 560, 440
local TITLE_H, FOOTER_H, INSET, LINE_GAP, BULLET_W = 32, 40, 16, 8, 12
local BUTTON_W, WIDE_BUTTON_W, GAP = 120, 160, 8
local CROSS_SIZE, CROSS_ANGLE = 14, math.pi / 4

local frame
local shownVersion

local function line(parent, colorKey)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(unpack(Style.COLORS[colorKey]))
    return t
end

local function horizontalLine(parent, anchor)
    local t = line(parent, "border")
    t:SetHeight(1)
    t:SetPoint(anchor .. "LEFT"); t:SetPoint(anchor .. "RIGHT")
    return t
end

-- The × glyph is not in every game font, so it is drawn from two lines
-- (as in the options windows).
local function closeCross(titleBar)
    local b = CreateFrame("Button", nil, titleBar)
    b:SetSize(TITLE_H, TITLE_H)
    b:SetPoint("RIGHT", titleBar, "RIGHT", 0, 0)
    b.lines = {}
    for i, angle in ipairs({ CROSS_ANGLE, -CROSS_ANGLE }) do
        local t = line(b, "muted")
        t:SetSize(CROSS_SIZE, 2)
        t:SetPoint("CENTER")
        t:SetRotation(angle)
        b.lines[i] = t
    end
    local function paint(colorKey)
        for _, t in ipairs(b.lines) do t:SetColorTexture(unpack(Style.COLORS[colorKey])) end
    end
    b:SetScript("OnEnter", function() paint("accent") end)
    b:SetScript("OnLeave", function() paint("muted") end)
    b:SetScript("OnClick", function() NewsWindow.Close() end)
    return b
end

local function createTitleBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    Style.Fill(bar, "panel")
    horizontalLine(bar, "BOTTOM")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    bar.title = Style.Text(bar, 16, "text")
    bar.title:SetPoint("LEFT", bar, "LEFT", INSET, 0)
    bar.addon = Style.Text(bar, 11, "muted")
    bar.addon:SetPoint("BOTTOMLEFT", bar.title, "BOTTOMRIGHT", 8, 1)
    bar.close = closeCross(bar)
    return bar
end

local function runAction()
    local entry = ns.News.Entry(shownVersion)
    NewsWindow.Close()
    if entry and entry.action then entry.action.run() end
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    local close = Widgets.Button(footer, { text = "", width = BUTTON_W, onClick = function() NewsWindow.Close() end })
    close:SetPoint("RIGHT", footer, "RIGHT", -12, 0)
    local action = Widgets.Button(footer, { text = "", width = WIDE_BUTTON_W, onClick = runAction })
    action:SetPoint("RIGHT", close, "LEFT", -GAP, 0)
    NewsWindow.closeButton, NewsWindow.actionButton = close, action
    return footer
end

local function createWindow()
    frame = CreateFrame("Frame", WINDOW_NAME, UIParent)
    NewsWindow.frame = frame
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetDontSavePosition(true)
    frame:EnableMouse(true)
    Style.Fill(frame, "bg")
    Style.Border(frame)
    frame.titleBar = createTitleBar(frame)
    frame.footer = createFooter(frame)
    NewsWindow.lines = {}
    frame:Hide()
    table.insert(UISpecialFrames, WINDOW_NAME)
end

-- The i-th line of the list: a bullet and a text that wraps.
local function listLine(i)
    local entry = NewsWindow.lines[i]
    if entry then return entry end
    local bullet = Style.Text(frame, 13, "accent")
    bullet:SetText("•")
    local text = Style.Text(frame, 13, "text")
    text:SetWidth(WIDTH - 2 * INSET - BULLET_W)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    if i == 1 then
        text:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", INSET + BULLET_W, -INSET)
    else
        text:SetPoint("TOPLEFT", NewsWindow.lines[i - 1].text, "BOTTOMLEFT", 0, -LINE_GAP)
    end
    bullet:SetPoint("TOPRIGHT", text, "TOPLEFT", -4, 0)
    entry = { bullet = bullet, text = text }
    NewsWindow.lines[i] = entry
    return entry
end

local function render()
    local entry = ns.News.Entry(shownVersion)
    frame.titleBar.title:SetText(L.NEWS_TITLE:format(shownVersion))
    frame.titleBar.addon:SetText(L.ADDON_NAME)
    for i, key in ipairs(entry.lines) do
        local item = listLine(i)
        item.text:SetText(L[key])
        item.bullet:Show(); item.text:Show()
    end
    for i = #entry.lines + 1, #NewsWindow.lines do
        NewsWindow.lines[i].bullet:Hide(); NewsWindow.lines[i].text:Hide()
    end
    NewsWindow.closeButton.text:SetText(L.NEWS_CLOSE)
    local action = entry.action
    NewsWindow.actionButton:SetShown(action ~= nil)
    if action then NewsWindow.actionButton.text:SetText(L[action.text]) end
end

-- Public API ----------------------------------------------------------------------

function NewsWindow.IsOpen()
    return frame ~= nil and frame:IsShown()
end

-- Shows the news of a version; false (and nothing shown) when it has none.
function NewsWindow.Open(version)
    if not ns.News.Entry(version) then return false end
    if not frame then createWindow() end
    shownVersion = version
    render()
    frame:Show()
    return true
end

function NewsWindow.Close()
    if frame then frame:Hide() end
end

ns.Listen("LANGUAGE_CHANGED", function()
    if NewsWindow.IsOpen() then render() end
end)
```

- [ ] **Step 5: Load both, after the raid options**

In `ForeverUnitFrames.toc`:

Replace

```text
Raid\MinimapButton.lua
Core\Debug.lua
```

with

```text
Raid\MinimapButton.lua
Core\News.lua
Options\News.lua
Core\Debug.lua
```

- [ ] **Step 6: The mock reads one TOC field, strictly**

In `tests/mock.lua`:

Replace

```lua
    _G.C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end }
```

with

```lua
    -- C_AddOns.GetAddOnMetadata(name, field): a field of an addon's TOC.
    -- The mock knows one: this addon's ## Version (M.addonVersion; tests
    -- set another before PLAYER_LOGIN); any other field or addon is nil.
    M.addonVersion = "0.1.0"
    _G.C_AddOns = { GetAddOnMetadata = function(name, field)
        assert(name ~= nil and type(field) == "string", "GetAddOnMetadata: name and field required")
        if name == "ForeverUnitFrames" and field == "Version" then return M.addonVersion end
        return nil
    end }
```

- [ ] **Step 7: The words in English**

Append to the end of `Locales/enUS.lua`:

```lua
-- What's new (Core/News.lua, Options/News.lua).
L.NEWS_TITLE = "What's new in %s"
L.NEWS_OPEN_RAID = "Open raid options"
L.NEWS_CLOSE = "Close"
L.NEWS_0_22_0_RAID = "Raid frames for 10, 20 and 40 players, in the clean look of the unit frames."
L.NEWS_0_22_0_BLOCKS = "Blocks by raid group, class or role, or one for everyone; side by side or stacked; within a block sorted by raid order, name or role."
L.NEWS_0_22_0_PROFILES = "Each size has a profile of its own per character, with a look entirely its own: cell size, texture, fonts, colours, border. Copy, reset, export and import a size."
L.NEWS_0_22_0_DEBUFFS = "Debuffs you can dispel, as healer addons show them: an icon in the centre or a coloured square in a corner. Up to five corner indicators for your heals over time and shields."
L.NEWS_0_22_0_ICONS = "Role, leader, master looter and ready check icons; members out of range fade; lines inside the cell show aggro and your target."
L.NEWS_0_22_0_WINDOW = "An options window of their own (/fuf raid, or Raid frames… in /fuf), a minimap button of their own, and a test mode that shows a pretend raid of the size you edit."
L.NEWS_0_22_0_BLIZZARD = "Blizzard's raid frames hide while ours are on; a 5-player group can be shown as a raid too."
```

- [ ] **Step 8: German**

Append to the end of `Locales/deDE.lua`:

```lua
-- Neuigkeiten (Core/News.lua, Options/News.lua).
L.NEWS_TITLE = "Neu in %s"
L.NEWS_OPEN_RAID = "Schlachtzugsoptionen öffnen"
L.NEWS_CLOSE = "Schließen"
L.NEWS_0_22_0_RAID = "Schlachtzugsrahmen für 10, 20 und 40 Spieler, im schlichten Stil der Einheitenrahmen."
L.NEWS_0_22_0_BLOCKS = "Blöcke nach Schlachtzuggruppe, Klasse oder Rolle oder einer für alle; nebeneinander oder untereinander; innerhalb eines Blocks nach Schlachtzugsreihenfolge, Name oder Rolle sortiert."
L.NEWS_0_22_0_PROFILES = "Jede Größe hat pro Charakter ein eigenes Profil mit ganz eigenem Aussehen: Zellengröße, Textur, Schriften, Farben, Rahmen. Eine Größe kopieren, zurücksetzen, exportieren und importieren."
L.NEWS_0_22_0_DEBUFFS = "Bannbare Debuffs wie in Heiler-Addons: als Symbol in der Mitte oder als farbiges Quadrat in einer Ecke. Bis zu fünf Eckindikatoren für deine Heilungen über Zeit und Schilde."
L.NEWS_0_22_0_ICONS = "Symbole für Rolle, Anführer, Plündermeister und Bereitschaftscheck; Mitglieder außer Reichweite verblassen; Linien in der Zelle zeigen Aggro und dein Ziel."
L.NEWS_0_22_0_WINDOW = "Ein eigenes Optionsfenster (/fuf raid oder Schlachtzugsrahmen… in /fuf), eine eigene Minikarten-Schaltfläche und ein Testmodus, der einen Probe-Schlachtzug der bearbeiteten Größe zeigt."
L.NEWS_0_22_0_BLIZZARD = "Blizzards Schlachtzugsrahmen sind aus, solange unsere an sind; eine 5er-Gruppe lässt sich auch als Schlachtzug anzeigen."
```

- [ ] **Step 9: Spanish**

Append to the end of `Locales/esES.lua`:

```lua
-- Novedades (Core/News.lua, Options/News.lua).
L.NEWS_TITLE = "Novedades de la versión %s"
L.NEWS_OPEN_RAID = "Abrir opciones de banda"
L.NEWS_CLOSE = "Cerrar"
L.NEWS_0_22_0_RAID = "Marcos de banda para 10, 20 y 40 jugadores, con el estilo limpio de los marcos de unidad."
L.NEWS_0_22_0_BLOCKS = "Bloques por grupo de banda, clase o rol, o uno para todos; uno al lado del otro o apilados; dentro de un bloque, por orden de banda, nombre o rol."
L.NEWS_0_22_0_PROFILES = "Cada tamaño tiene un perfil propio por personaje, con un aspecto totalmente propio: tamaño de celda, textura, fuentes, colores, borde. Copia, restablece, exporta e importa un tamaño."
L.NEWS_0_22_0_DEBUFFS = "Perjuicios que puedes disipar, como los muestran los addons de sanación: un icono en el centro o un cuadrado de color en una esquina. Hasta cinco indicadores de esquina para tus sanaciones en el tiempo y escudos."
L.NEWS_0_22_0_ICONS = "Iconos de rol, líder, maestro despojador y comprobación de listos; los miembros fuera de alcance se atenúan; líneas dentro de la celda muestran la amenaza y tu objetivo."
L.NEWS_0_22_0_WINDOW = "Una ventana de opciones propia (/fuf raid, o Marcos de banda… en /fuf), un botón propio en el minimapa y un modo de prueba que muestra una banda ficticia del tamaño que editas."
L.NEWS_0_22_0_BLIZZARD = "Los marcos de banda de Blizzard se ocultan mientras los nuestros están activos; un grupo de 5 también puede mostrarse como banda."
```

- [ ] **Step 10: French**

Append to the end of `Locales/frFR.lua`:

```lua
-- Nouveautés (Core/News.lua, Options/News.lua).
L.NEWS_TITLE = "Nouveautés de la version %s"
L.NEWS_OPEN_RAID = "Ouvrir les options de raid"
L.NEWS_CLOSE = "Fermer"
L.NEWS_0_22_0_RAID = "Des cadres de raid pour 10, 20 et 40 joueurs, dans le style épuré des cadres d'unité."
L.NEWS_0_22_0_BLOCKS = "Des blocs par groupe de raid, classe ou rôle, ou un seul pour tous ; côte à côte ou empilés ; dans un bloc, triés par ordre de raid, nom ou rôle."
L.NEWS_0_22_0_PROFILES = "Chaque taille a son propre profil par personnage, avec une apparence entièrement à elle : taille des cellules, texture, polices, couleurs, bordure. Copiez, réinitialisez, exportez et importez une taille."
L.NEWS_0_22_0_DEBUFFS = "Les affaiblissements que vous pouvez dissiper, comme les montrent les addons de soin : une icône au centre ou un carré coloré dans un coin. Jusqu'à cinq indicateurs de coin pour vos soins sur la durée et vos boucliers."
L.NEWS_0_22_0_ICONS = "Icônes de rôle, de chef, de maître du butin et d'appel ; les membres hors de portée s'estompent ; des lignes dans la cellule montrent l'aggro et votre cible."
L.NEWS_0_22_0_WINDOW = "Une fenêtre d'options à eux (/fuf raid, ou Cadres de raid… dans /fuf), un bouton de minicarte à eux, et un mode test qui affiche un faux raid de la taille que vous modifiez."
L.NEWS_0_22_0_BLIZZARD = "Les cadres de raid de Blizzard se masquent tant que les nôtres sont actifs ; un groupe de 5 peut aussi s'afficher comme un raid."
```

(Each block starts after one blank line, as the earlier blocks do.)

- [ ] **Step 11: Run the tests**

Run: `tests/run test_news_window.lua` → `51 passed, 0 failed`
Run: `tests/run` → Expected: `24076 passed, 0 failed`

- [ ] **Step 12: Commit**

```bash
git add Core/News.lua ForeverUnitFrames.toc Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Options/News.lua tests/mock.lua tests/test_news_window.lua
git commit -m "What's New window: the news of a version, the news of 0.22.0

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: What's New at login: once per new version, only after an update

**Files:**
- Modify: `Core/News.lua`
- Modify: `Core/Boot.lua`
- Test: `tests/test_news_login.lua`

**Interfaces:**
- Consumes: Task 1's `ns.News.Current` / `Entry` / `ENTRIES`, `ns.NewsWindow.Open` / `IsOpen` / `frame`; `ns.AfterCombat`; mock `M.addonVersion`, `M.SetCombat`, PLAYER_LOGOUT (saves the profile).
- Produces: `ns.News.Compare(a, b)` (-1, 0, 1), `ns.News.Begin(db)` (called by Boot first thing at PLAYER_LOGIN), `ns.News.Due()`, `ns.News.AtLogin()` (combat-queue key `"news"`); SavedVariables key `ForeverUnitFramesDB.newsSeen`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_news_login.lua`:

```lua
-- What's New at login (Core/News.lua, Core/Boot.lua): once per new
-- version, only after an update (SavedVariables with a unit-frame or raid
-- profile from before), never in combat; a fresh install only records
-- the version. ForeverUnitFramesDB.newsSeen holds the version recorded.
local M = H.M
local ns

-- A login with these SavedVariables at this TOC version; extra news
-- entries are added before PLAYER_LOGIN.
local function login(db, version, opts)
    opts = opts or {}
    ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
    M.addonVersion = version
    _G.ForeverUnitFramesDB = db
    for v, entry in pairs(opts.entries or {}) do ns.News.ENTRIES[v] = entry end
    M.combat = opts.combat or false
    M.FireEvent("PLAYER_LOGIN")
    if not opts.combat then M.RunTimers() end
    return ns.NewsWindow.IsOpen()
end
local function logout() M.FireEvent("PLAYER_LOGOUT") end
local NEWER = { ["0.23.0"] = { lines = { "NEWS_0_22_0_RAID" } } }

-- Versions compare number by number.
ns = H.LoadAddon()
H.check("older", ns.News.Compare("0.21.0", "0.22.0"), -1)
H.check("same", ns.News.Compare("0.22.0", "0.22.0"), 0)
H.check("newer", ns.News.Compare("0.22.1", "0.22.0"), 1)
H.check("numbers, not letters", ns.News.Compare("0.10.0", "0.9.0"), 1)
H.check("a missing number is 0", ns.News.Compare("1.0", "1.0.0"), 0)

-- A fresh install: nothing shown, the version recorded.
H.check("fresh install: not shown", login(nil, "0.22.0"), false)
H.check("fresh install: no window built", ns.NewsWindow.frame, nil)
H.check("fresh install: recorded", ForeverUnitFramesDB.newsSeen, "0.22.0")
logout()
local db = ForeverUnitFramesDB
H.checkTrue("its profile saved at logout", type(db.profile) == "table")
H.check("next login, same version: not shown", login(db, "0.22.0"), false)
H.check("still recorded", ForeverUnitFramesDB.newsSeen, "0.22.0")
logout()
H.check("a newer version with news: shown", login(db, "0.23.0", { entries = NEWER }), true)
H.check("of that version", ns.NewsWindow.frame.titleBar.title:GetText(), "What's new in 0.23.0")
H.check("the newer one recorded", ForeverUnitFramesDB.newsSeen, "0.23.0")

-- An update from 0.21.0: a unit-frame profile, no newsSeen.
local old = { version = 1, profile = { player = { width = 250 } } }
H.check("update from 0.21.0: shown", login(old, "0.22.0"), true)
H.check("the news of 0.22.0", ns.NewsWindow.frame.titleBar.title:GetText(), "What's new in 0.22.0")
H.check("recorded", ForeverUnitFramesDB.newsSeen, "0.22.0")
H.check("the profile kept", ForeverUnitFramesDB.profile.player.width, 250)
logout()
H.check("same version again: not shown", login(old, "0.22.0"), false)
logout()
H.check("newer version later: shown", login(old, "0.23.0", { entries = NEWER }), true)
H.check("recorded again", ForeverUnitFramesDB.newsSeen, "0.23.0")
logout()

-- Raid profiles alone count as an update too.
H.check("raid profiles only: shown", login({ raid = { ["Other-Realm"] = { r10 = {} } } }, "0.22.0"), true)

-- A newer version without news: nothing shown, nothing recorded.
H.check("no news for 0.22.1: not shown", login({ profile = {}, newsSeen = "0.22.0" }, "0.22.1"), false)
H.check("no news: newsSeen kept", ForeverUnitFramesDB.newsSeen, "0.22.0")
H.check("no news: no window built", ns.NewsWindow.frame, nil)

-- An older version than the one recorded (a downgrade): not shown, kept.
H.check("downgrade: not shown", login({ profile = {}, newsSeen = "0.23.0" }, "0.22.0"), false)
H.check("downgrade: newsSeen kept", ForeverUnitFramesDB.newsSeen, "0.23.0")

-- A newsSeen that is no version string counts as none.
H.check("unreadable newsSeen: shown", login({ profile = {}, newsSeen = 5 }, "0.22.0"), true)
H.check("unreadable newsSeen: replaced", ForeverUnitFramesDB.newsSeen, "0.22.0")

-- Logging in in combat: after combat, after the frames.
local chatBefore
H.check("combat: not shown", login({ profile = {} }, "0.22.0", { combat = true }), false)
H.check("combat: not yet recorded", ForeverUnitFramesDB.newsSeen, nil)
chatBefore = #M.chat
M.SetCombat(false)
H.checkTrue("after combat: shown", ns.NewsWindow.IsOpen())
H.check("after combat: recorded", ForeverUnitFramesDB.newsSeen, "0.22.0")
H.checkTrue("the unit frames built", ns.Frames.player)
H.checkTrue("the raid panel built", ns.RaidHeader.anchor)
H.check("nothing printed", #M.chat, chatBefore)
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_news_login.lua`

Expected:

```text
test_news_login.lua
  ERROR test_news_login.lua:27: attempt to call field 'Compare' (a nil value)
0 passed, 1 failed
```

- [ ] **Step 3: The rule**

Replace the whole of `Core/News.lua` (Task 1's file, with the rule's comment and the functions after `News.Entry`) with:

```lua
local _, ns = ...

-- What's new: the news of a version, keyed by the version in the TOC
-- (## Version). An entry lists locale keys, one line each, and may name
-- an action for the window's left button. A version without an entry has
-- no news. Options/News.lua shows an entry.
--
-- Once per new version, at login (Core/Boot.lua), after everything else
-- is built and out of combat. ForeverUnitFramesDB.newsSeen is the newest
-- version this account has had news for. The news of the TOC version
-- shows when that version has an entry and
--   * newsSeen is an older version, or
--   * there is no newsSeen (or none that is a string), but the
--     SavedVariables held a unit-frame profile or raid profiles before
--     this login: an update from a version before the news.
-- A fresh install (neither) shows nothing. A login that finds an entry
-- records its version as newsSeen, unless newsSeen is newer already (a
-- downgrade keeps it). A version without news shows and records nothing.
local News = {}
ns.News = News

News.ENTRIES = {
    ["0.22.0"] = {
        lines = { "NEWS_0_22_0_RAID", "NEWS_0_22_0_BLOCKS", "NEWS_0_22_0_PROFILES", "NEWS_0_22_0_DEBUFFS",
            "NEWS_0_22_0_ICONS", "NEWS_0_22_0_WINDOW", "NEWS_0_22_0_BLIZZARD" },
        action = { text = "NEWS_OPEN_RAID", run = function() ns.RaidOptions.Open() end },
    },
}

-- The version this client loaded (## Version in the TOC).
function News.Current()
    return C_AddOns.GetAddOnMetadata(ns.name, "Version")
end

-- The news of a version, or nil.
function News.Entry(version)
    if type(version) ~= "string" then return nil end
    return News.ENTRIES[version]
end

-- -1, 0 or 1 as version a is older than, the same as or newer than b:
-- numbers compared one by one, a missing number counts as 0.
function News.Compare(a, b)
    local pa, pb = {}, {}
    for n in a:gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
    for n in b:gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

local db            -- ForeverUnitFramesDB
local hadSettings   -- it held a profile before this login

-- At PLAYER_LOGIN, before anything writes to the SavedVariables.
function News.Begin(saved)
    db = saved
    hadSettings = type(saved.profile) == "table" or type(saved.raid) == "table"
end

local function seenVersion()
    local seen = db.newsSeen
    if type(seen) == "string" then return seen end
    return nil
end

-- Whether this login shows the news of the TOC version (see above).
function News.Due()
    local current = News.Current()
    if not News.Entry(current) then return false end
    local seen = seenVersion()
    if seen then return News.Compare(seen, current) < 0 end
    return hadSettings
end

-- Out of combat, after the frames are built: shows the news if due and
-- records the version.
function News.AtLogin()
    local current = News.Current()
    if not News.Entry(current) then return end
    if News.Due() then ns.NewsWindow.Open(current) end
    local seen = seenVersion()
    if not seen or News.Compare(seen, current) < 0 then db.newsSeen = current end
end
```

- [ ] **Step 4: Boot asks first and shows last**

In `Core/Boot.lua`:

Replace

```lua
    ForeverUnitFramesDB = ForeverUnitFramesDB or {}
    ns.Config.Use(ns.Storage.Load(ForeverUnitFramesDB))
```

with

```lua
    ForeverUnitFramesDB = ForeverUnitFramesDB or {}
    -- Whether the SavedVariables held settings before this login (an
    -- update), before anything writes to them.
    ns.News.Begin(ForeverUnitFramesDB)
    ns.Config.Use(ns.Storage.Load(ForeverUnitFramesDB))
```

In `Core/Boot.lua`:

Replace

```lua
    ns.AfterCombat("raidCreate", ns.RaidHeader.Create)
    ns.Blizzard.HideRaid()
end)
```

with

```lua
    ns.AfterCombat("raidCreate", ns.RaidHeader.Create)
    ns.Blizzard.HideRaid()
    -- What's new, once per new version: after everything above, out of
    -- combat.
    ns.AfterCombat("news", ns.News.AtLogin)
end)
```

- [ ] **Step 5: Run the tests**

Run: `tests/run test_news_login.lua` → `38 passed, 0 failed`
Run: `tests/run` → Expected: `24114 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add Core/Boot.lua Core/News.lua tests/test_news_login.lua
git commit -m "What's New at login: once per new version, only after an update

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: /fuf news: the news of this version again

**Files:**
- Modify: `Core/Commands.lua`
- Modify: `Options/News.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Modify: `docs/curseforge/description.md`
- Modify: `docs/wiki/Home.md`
- Test: `tests/test_news_command.lua`

**Interfaces:**
- Consumes: `ns.News.Current`, `ns.NewsWindow.Open` / `IsOpen` / `Close` / `frame` (Task 1), the login rule (Task 2: `newsSeen` set at login), `SlashCmdList.FOREVERUNITFRAMES`, `ns.Print`.
- Produces: `ns.Commands.ShowNews()`, the `/fuf news` subcommand, `ns.NewsWindow.hint`; locale keys `NEWS_AGAIN`, `NEWS_NONE`; `HELP` names `/fuf news` in all four languages.

- [ ] **Step 1: Write the failing test**

Create `tests/test_news_command.lua`:

```lua
-- /fuf news (Core/Commands.lua): the news of this version again, any
-- time, without touching what was recorded; the help and the window's
-- footer name it.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.addonVersion = "0.22.0"
_G.ForeverUnitFramesDB = { profile = {}, newsSeen = "0.22.0" }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local run, NW, L = SlashCmdList.FOREVERUNITFRAMES, ns.NewsWindow, ns.L

H.check("seen: not shown at login", NW.IsOpen(), false)
run("news")
H.checkTrue("/fuf news opens it", NW.IsOpen())
H.check("the news of this version", NW.frame.titleBar.title:GetText(), "What's new in 0.22.0")
H.check("the footer names the command", NW.hint:GetText(), "/fuf news shows this again.")
H.check("newsSeen untouched", ForeverUnitFramesDB.newsSeen, "0.22.0")
run("NEWS")
H.checkTrue("any case, open again", NW.IsOpen())
NW.Close()

-- In combat too: a plain window.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
run("news")
H.checkTrue("in combat too", NW.IsOpen())
M.SetCombat(false)
NW.Close()

-- A version without news says so.
M.addonVersion = "0.22.1"
local chatBefore = #M.chat
run("news")
H.check("no news: no window", NW.IsOpen(), false)
H.check("no news: one line", #M.chat, chatBefore + 1)
H.check("no news: says so", M.chat[#M.chat]:find(L.NEWS_NONE, 1, true) ~= nil, true)
H.check("no news: newsSeen untouched", ForeverUnitFramesDB.newsSeen, "0.22.0")

-- The help names it, in every language.
run("help")
H.checkTrue("help names /fuf news", M.chat[#M.chat]:find("/fuf news", 1, true))
for _, code in ipairs({ "deDE", "esES", "frFR" }) do
    H.checkTrue(code .. ": help names /fuf news", ns.Locales[code].HELP:find("/fuf news", 1, true))
    H.checkTrue(code .. ": hint names /fuf news", ns.Locales[code].NEWS_AGAIN:find("/fuf news", 1, true))
end
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_news_command.lua`

Expected:

```text
test_news_command.lua
  FAIL /fuf news opens it -> false (want true)
  ERROR test_news_command.lua:16: attempt to index field 'frame' (a nil value)
1 passed, 2 failed
```

(Before this task `/fuf news` falls through to the help line.)

- [ ] **Step 3: The command**

In `Core/Commands.lua`:

Replace

```lua
-- Unlocking is refused in combat (Movers.Unlock says so).
```

with

```lua
-- /fuf news: the news of this version again (Options/News.lua), or why
-- not. What was recorded at login stays as it is.
function Commands.ShowNews()
    if not ns.NewsWindow.Open(ns.News.Current()) then ns.Print(L.NEWS_NONE) end
end

-- Unlocking is refused in combat (Movers.Unlock says so).
```

In `Core/Commands.lua`:

Replace

```lua
    elseif cmd == "raid" then
        Commands.ToggleRaidOptions()
```

with

```lua
    elseif cmd == "raid" then
        Commands.ToggleRaidOptions()
    elseif cmd == "news" then
        Commands.ShowNews()
```

- [ ] **Step 4: The window's footer says so**

In `Options/News.lua`:

Replace

```lua
-- (non-secure) frame; ESC closes it too. Every text is set when it
-- opens, and again when the language changes while it is open.
```

with

```lua
-- (non-secure) frame; ESC closes it too; /fuf news opens it again (its
-- footer says so). Every text is set when it opens, and again when the
-- language changes while it is open.
```

In `Options/News.lua`:

Replace

```lua
    action:SetPoint("RIGHT", close, "LEFT", -GAP, 0)
    NewsWindow.closeButton, NewsWindow.actionButton = close, action
```

with

```lua
    action:SetPoint("RIGHT", close, "LEFT", -GAP, 0)
    local hint = Style.Text(footer, 11, "muted")
    hint:SetPoint("LEFT", footer, "LEFT", INSET, 0)
    NewsWindow.closeButton, NewsWindow.actionButton, NewsWindow.hint = close, action, hint
```

In `Options/News.lua`:

Replace

```lua
    NewsWindow.closeButton.text:SetText(L.NEWS_CLOSE)
```

with

```lua
    NewsWindow.closeButton.text:SetText(L.NEWS_CLOSE)
    NewsWindow.hint:SetText(L.NEWS_AGAIN)
```

- [ ] **Step 5: The words in English**

In `Locales/enUS.lua`:

Replace

```lua
L.HELP = "/fuf opens the options, /fuf raid the raid frames' options. Also: /fuf unlock, /fuf lock, /fuf status, /fuf reset <frame|all>, /fuf set <scope> <setting> <value>"
```

with

```lua
L.HELP = "/fuf opens the options, /fuf raid the raid frames' options, /fuf news what's new. Also: /fuf unlock, /fuf lock, /fuf status, /fuf reset <frame|all>, /fuf set <scope> <setting> <value>"
```

Append to the end of `Locales/enUS.lua` (right after Task 1's block, no blank line):

```lua
L.NEWS_AGAIN = "/fuf news shows this again."
L.NEWS_NONE = "This version has no news."
```

- [ ] **Step 6: German**

In `Locales/deDE.lua`:

Replace

```lua
L.HELP = "/fuf öffnet die Optionen, /fuf raid die der Schlachtzugsrahmen. Außerdem: /fuf unlock, /fuf lock, /fuf status, /fuf reset <Rahmen|all>, /fuf set <Bereich> <Einstellung> <Wert>"
```

with

```lua
L.HELP = "/fuf öffnet die Optionen, /fuf raid die der Schlachtzugsrahmen, /fuf news die Neuigkeiten. Außerdem: /fuf unlock, /fuf lock, /fuf status, /fuf reset <Rahmen|all>, /fuf set <Bereich> <Einstellung> <Wert>"
```

Append to the end of `Locales/deDE.lua` (right after Task 1's block, no blank line):

```lua
L.NEWS_AGAIN = "/fuf news zeigt dies erneut."
L.NEWS_NONE = "Diese Version hat keine Neuigkeiten."
```

- [ ] **Step 7: Spanish**

In `Locales/esES.lua`:

Replace

```lua
L.HELP = "/fuf abre las opciones, /fuf raid las de los marcos de banda. Además: /fuf unlock, /fuf lock, /fuf status, /fuf reset <marco|all>, /fuf set <ámbito> <ajuste> <valor>"
```

with

```lua
L.HELP = "/fuf abre las opciones, /fuf raid las de los marcos de banda, /fuf news las novedades. Además: /fuf unlock, /fuf lock, /fuf status, /fuf reset <marco|all>, /fuf set <ámbito> <ajuste> <valor>"
```

Append to the end of `Locales/esES.lua` (right after Task 1's block, no blank line):

```lua
L.NEWS_AGAIN = "/fuf news vuelve a mostrar esto."
L.NEWS_NONE = "Esta versión no tiene novedades."
```

- [ ] **Step 8: French**

In `Locales/frFR.lua`:

Replace

```lua
L.HELP = "/fuf ouvre les options, /fuf raid celles des cadres de raid. Aussi : /fuf unlock, /fuf lock, /fuf status, /fuf reset <cadre|all>, /fuf set <portée> <réglage> <valeur>"
```

with

```lua
L.HELP = "/fuf ouvre les options, /fuf raid celles des cadres de raid, /fuf news les nouveautés. Aussi : /fuf unlock, /fuf lock, /fuf status, /fuf reset <cadre|all>, /fuf set <portée> <réglage> <valeur>"
```

Append to the end of `Locales/frFR.lua` (right after Task 1's block, no blank line):

```lua
L.NEWS_AGAIN = "/fuf news affiche ceci à nouveau."
L.NEWS_NONE = "Cette version n'a pas de nouveautés."
```

- [ ] **Step 9: The command in the description and the wiki**

In `docs/curseforge/description.md` (section **Commands**), replace

```markdown
`/fuf` (options), `/fuf raid` (raid frames' options), `/fuf unlock`
```

with

```markdown
`/fuf` (options), `/fuf raid` (raid frames' options), `/fuf news` (what's new in this version), `/fuf unlock`
```

(the rest of that line stays).

In `docs/wiki/Home.md`:

Replace

```markdown
| `/fuf raid` | Opens the raid frames' options |
```

with

```markdown
| `/fuf raid` | Opens the raid frames' options |
| `/fuf news` | Shows what's new in this version (shown once by itself after an update) |
```

- [ ] **Step 10: Run the tests**

Run: `tests/run test_news_command.lua` → `20 passed, 0 failed`
Run: `tests/run` → Expected: `24152 passed, 0 failed`

- [ ] **Step 11: Commit**

```bash
git add Core/Commands.lua Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Options/News.lua docs/curseforge/description.md docs/wiki/Home.md tests/test_news_command.lua
git commit -m "/fuf news: the news of this version again

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## After the last task

- `./install "<AddOns folder of _classic_beta_>"`, then `/reload`. No Lua error at login. UI only: no moving, casting or fighting.
- The update case on this account (SavedVariables from 0.21.0 or the 0.22.0 test builds, no `newsSeen`): the What's New window shows once after login, over the frames, centred a little above the middle; the title reads "What's new in 0.22.0". `/reload`: it does not show again (`newsSeen` is `"0.22.0"`). Check the seven lines in all four languages (General > Language) — they must fit above the footer at 560 × 440 (German and French are the longest); if a language overflows, raise `HEIGHT` in `Options/News.lua` (no test depends on it).
- *Open raid options* closes the news and opens the raid window; *Close*, the cross and ESC close it; the title bar drags it.
- `/fuf news` shows it again, also in combat; `/fuf help` names it.
- A fresh install is covered by the offline tests (do not delete the SavedVariables in game).
- The version stays 0.22.0; the maintainer releases separately (`tools/release`, not part of this plan).
