# AGENTS.md

Guidance for coding agents working in this repo. It's a KDE Plasma 6
applet (Plasmoid), not a standalone app — there's no compile step or
package manager. Everything is QML/JS read directly by `plasmashell` or
`plasmoidviewer` at runtime. `build.sh` (requires `jq` and `tar`) just tars
`contents/` + `metadata.json` into `build/<id>-<version>.tar.xz` for
distribution (e.g. to the KDE Store) — it doesn't compile anything.
`tests/` holds QML unit tests for `DataFetcher.js` and `Scene3D.qml` (see
Runtime/testing below); `main.qml` itself is still only verified by running
the applet, for reasons explained there.

## Project layout

See `README.md` for user-facing docs and `KDESTOREPAGE.md` for the KDE
Store listing copy. Source of truth for structure:

```text
metadata.json               # KPlugin.Id, Name, Version, X-Plasma-API-Minimum-Version
build.sh                    # Packages contents/+metadata.json into build/<id>-<version>.tar.xz
KDESTOREPAGE.md              # KDE Store listing page content — keep in sync with features/config
contents/
├── config/
│   ├── main.xml             # kcfg schema — property name/type/default per entry
│   └── config.qml           # ConfigModel/ConfigCategory list, one per settings page
└── ui/
    ├── main.qml              # PlasmoidItem root
    ├── Scene3D.qml            # Qt Quick 3D scene, loaded via Loader from main.qml
    ├── ConfigGeneral.qml     # settings page QML (Kirigami.FormLayout)
    └── DataFetcher.js         # GitHub GraphQL/scraper + GitLab calendar fetch (.pragma library)
tests/
├── tst_datafetcher.qml       # DataFetcher.js: validation, parsing, level thresholds
├── tst_scene3d.qml           # Scene3D.qml: grid/height/color logic, loaded via Loader
├── CMakeLists.txt            # ctest integration (shells out to qmltestrunner-qt6)
├── run_tests.sh              # standalone runner, no CMake needed
└── README.md                 # what's covered, what isn't, and why
tools/
├── grab_screenshot.qml       # Renders Scene3D.qml offscreen to a transparent PNG (grabToImage)
└── README.md                 # usage/arguments
```

## Config wiring — read this before touching config.qml or ConfigGeneral.qml

Three files must stay in sync for a config value to work end-to-end:

1. `contents/config/main.xml` — declares the kcfg entry (name, type, default).
   Exposed at runtime as `Plasmoid.configuration.<name>`.
2. `contents/ui/ConfigGeneral.qml` — must declare `property alias cfg_<name>`
   (or a plain `property <type> cfg_<name>`) bound to the matching control.
   KDeclarative's config loader matches on the `cfg_` prefix.
3. `contents/config/config.qml` — `ConfigCategory.source` paths are resolved
   **relative to `contents/ui/`**, not the package root. Use `"ConfigGeneral.qml"`,
   never `"ui/ConfigGeneral.qml"` — the latter silently fails to load the
   page (Component creation returns null) and surfaces as a cryptic
   `Could not convert argument 1 from  to QQuickItem*` error from
   `PageRow.qml` when the config window opens. This bit us once already —
   double-check any new `ConfigCategory.source` path against this rule.

kcfg entries don't strictly need step 2 — a `<group>` with no corresponding
`cfg_` control (see the `Camera` group: `cameraRotationX/Y`, `cameraPositionX/Y/Z`,
`cameraZoomZ`) is valid and just means nothing in the Configure dialog shows
it. That's the deliberate pattern for persisted-but-not-user-facing session
state. `main.qml` is kept a thin `Plasmoid.configuration.*` pass-through only
(it has no unit tests, so logic there is unverifiable) — it calls
`Scene3D.qml`'s `restoreCameraState(...)` once on `Loader.onStatusChanged` →
`Ready`, and writes `Plasmoid.configuration.*` from `Scene3D.qml`'s debounced
`cameraStateSettled` signal. All the actual decisions (what the zoom-`0`
sentinel means, how long to debounce) live in `Scene3D.qml`, where they're
covered by `tests/tst_scene3d.qml`.

## Runtime/testing

`Scene3D.qml` and `DataFetcher.js` have QML unit tests in `tests/`
(`./tests/run_tests.sh`, requires `qmltestrunner-qt6`) — run them after
touching either file. See `tests/README.md` for what they cover.

`main.qml` itself has no unit tests: it reads config through
`Plasmoid.configuration`, an **attached property** resolved by the real
`org.kde.plasma.plasmoid` C++ plugin against a live `PlasmoidItem`/applet
instance — unlike a plain context property, it can't be swapped for a mock
QML object outside of that real environment. Verify `main.qml` changes by
actually running the applet:

```sh
# Standalone window, doesn't touch live panels — fastest iteration loop
plasmoidviewer -a .

# Install/upgrade into the real Plasma session
kpackagetool6 --type Plasma/Applet --install .   # first time
kpackagetool6 --type Plasma/Applet --upgrade .   # subsequent changes
```

`plasmoidviewer` does not hot-reload — restart it after editing QML.
`qmllint-qt6` is available in this environment and understands both `.qml`
and `.js` files — run it over touched files before calling a change done.

When changing `Scene3D.qml`, confirm Qt Quick 3D is actually present
(`qmlimportscanner` or just run `plasmoidviewer`) — the fallback error
path in `main.qml`'s `Loader.onStatusChanged` is the only thing standing
between a missing dependency and a silent blank widget.

## Conventions / gotchas already found in this codebase

- `Scene3D.qml`'s camera is a `cameraRig` `Node` (pitch + vertical pivot)
  containing a `PerspectiveCamera` with zero rotation of its own. Don't put
  rotation directly back on the camera — `OrbitCameraController`'s zoom only
  ever translates `camera.z`, and if the camera carried its own fixed pitch,
  that translation would drift the look-at point off-center as distance
  changes (this exact bug shipped once already: zooming in visibly slid the
  grid toward the bottom of the frame). Whatever world Y `cameraRig.y` is set
  to always renders at the vertical center of frame, by construction.
  Also: the camera's `fieldOfViewOrientation` is deliberately `Horizontal`,
  not the default — the grid is very wide and short, and locking to
  *vertical* FOV instead makes the horizontal FOV balloon past 100° at
  typical wide/short panel aspect ratios (fisheye distortion, not "zoomed
  in" — this also shipped once, briefly). `camera.z`'s `widthFitZ`/
  `heightFitZ` and `cameraRig.y` (`maxBarHeight / 2`) were derived together
  assuming symmetric framing around that pivot; if you change one, check the
  other still fits both the grid width and the tallest current bar.
- `KDESTOREPAGE.md` is the KDE Store listing copy, separate from
  `README.md` (which is for developers/GitHub visitors). When a change
  adds/removes a user-facing feature or config option, or changes
  requirements, update both so they don't drift apart.
- `main.qml` sets `Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground`
  intentionally, and `Scene3D.qml`'s `SceneEnvironment` uses
  `backgroundMode: SceneEnvironment.Transparent`. Keep both if you want the
  widget to stay borderless/transparent — removing one without the other
  leaves a visible opaque/boxed background.
- The GitHub PAT (`cfg_githubToken`, optional) is stored via kcfg in plain
  text (standard Plasma applet config storage, not the system keychain) and
  sent as an `Authorization: bearer` header directly from QML/JS to
  `api.github.com/graphql` only. Don't log it, and don't widen its usage
  beyond that one call in `DataFetcher.js`.
- There is intentionally **no** GitLab PAT field/config entry. GitLab's
  `calendar.json` (used by `fetchGitlabCalendar`) authenticates via session
  cookie or a separate feed token, never a personal access token, so
  collecting one would just be an inert secret sitting in plaintext config
  for no functional benefit — don't re-add it without a real authenticated
  call (e.g. `/api/v4`) that actually uses it.
- `DataFetcher.js`'s tokenless GitHub path (`fetchGithubContributionsPage` /
  `parseGithubContributionsHtml`) scrapes the public
  `github.com/users/<username>/contributions` page instead of calling an
  API. GitHub's grid HTML lists `<td>` cells in row-major (day-of-week)
  order, not chronological order, and per-day counts live in separate
  `<tool-tip for="<td id>">` elements, not inside the `<td>` — the parser
  keys tooltips by id and sorts the result by date; don't "simplify" that
  away or the skyline will come out visually scrambled. This is inherently
  more fragile than the GraphQL path since GitHub's HTML isn't a stable
  contract — if it silently breaks, `parseGithubContributionsHtml` returns
  an empty array and `fetchGithubContributionsPage` reports "GitHub may
  have changed their page layout" rather than misrendering.
