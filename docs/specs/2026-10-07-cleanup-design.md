# Clean-up after 0.22 — Design (package A)

Date: 2026-10-07 · Status: decided (maintainer: "A und B bitte vorbereiten"); no visible change for users.

## Goal

Less duplicated code before the next features build on it. Every saved setting, default look and behaviour stays
exactly as in 0.22.0; the default-look snapshot test (tests/test_default_look.lua) and the full suite stay green.

## 1. Shared window parts (`Options/Chrome.lua`, new)

Today the same pieces are written three or four times:

| Piece | Options/Window.lua | Raid/Options/Window.lua | Options/News.lua | Raid/Wizard.lua |
|---|---|---|---|---|
| title bar (drag, title, sub-title) | createTitleBar | createTitleBar | createTitleBar | own |
| close cross (two rotated lines) | yes | closeButton | closeCross | own |
| hover paint for buttons | hoverable | hoverable | — | — |
| footer row (left/right buttons, hint) | createFooter* | createFooter* | footer | footer |
| armed confirm button | confirmButton | (uses Widgets) | — | — |
| row tooltip | per row | per row | — | — |

`Options/Chrome.lua` offers `Chrome.TitleBar(frame, opts)`, `Chrome.CloseCross(bar, onClick)`, `Chrome.Hoverable(btn,
idle)`, `Chrome.Footer(frame, opts)` and `Chrome.ConfirmButton(...)` (the one in Options/Window.lua, with the optional
armed text, needed() and onDisarm the raid window uses). All four windows use it. Sizes, colours, anchors and texts
stay identical (tests compare the frames' points and sizes before/after where they exist; new tests pin the shared
module).

## 2. One secret check

`readable(pcall(f, ...))` / `plain()` / `token()` helpers exist in Raid/Cell.lua, Elements/GroupIcons.lua,
Raid/BuffWatch.lua, Raid/Tools.lua, Raid/TemplateData.lua, Raid/Lists.lua. Add to `ns.Secrets`:
`Secrets.Call(f, ...)` → the first result if the call succeeded and the result is not secret, else nil; and
`Secrets.Plain(v, kind)` → v if not secret and of type kind. Replace the local copies (same semantics; each call site's
behaviour is pinned by its existing tests).

## 3. Leftovers from the 0.22 reviews

- `Own.Addable` uses the kept tokens (as `Own.Columns`) after an import that names a block twice.
- Tools bar default position: not on top of panel 2's default spot (test against all default spots).
- Totems: `x, y` shadowing → `dx, dy`.
- Elite word: drop the ineffective `SetJustifyH`; wiki wording.
- Default-look snapshot also records the role texture and the pet's 3D portrait alpha.
- Buff cell icon without a readable GUID: in combat it hides instead of keeping a possibly stale state.
- Raid cells: one shared cell-shape helper (Raid/Cell.lua / Panel) instead of the two copies.

## 4. Way of working

Branch `cleanup`; behaviour-neutral refactors are covered by the existing tests (run the focused files while working,
the full suite once per step that moves logic, once at the end); new tests for the shared module. No release on its
own: it ships with package B as 0.23.0.
