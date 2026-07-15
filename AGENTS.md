# AGENTS.md

Guidance for coding agents working in this repo. It's a KDE Plasma 6
applet (Plasmoid), not a standalone app — there's no build step, package
manager, or test suite. Everything is QML/JS read directly by `plasmashell`
or `plasmoidviewer` at runtime.

## Project layout

See `REQUIREMENTS.md` for the original feature spec and `README.md` for
user-facing docs. Source of truth for structure:

```text
metadata.json               # KPlugin.Id, Name, Version, X-Plasma-API-Minimum-Version
contents/
├── config/
│   ├── main.xml             # kcfg schema — property name/type/default per entry
│   └── config.qml           # ConfigModel/ConfigCategory list, one per settings page
└── ui/
    ├── main.qml              # PlasmoidItem root
    ├── Scene3D.qml            # Qt Quick 3D scene, loaded via Loader from main.qml
    ├── ConfigGeneral.qml     # settings page QML (Kirigami.FormLayout)
    └── DataFetcher.js         # GitHub GraphQL fetch (.pragma library)
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

## Runtime/testing

No automated tests exist. Verify changes by actually running the applet:

```sh
# Standalone window, doesn't touch live panels — fastest iteration loop
plasmoidviewer -a .

# Install/upgrade into the real Plasma session
kpackagetool6 --type Plasma/Applet --install .   # first time
kpackagetool6 --type Plasma/Applet --upgrade .   # subsequent changes
```

`plasmoidviewer` does not hot-reload — restart it after editing QML.
There is no `qmllint`/`qmlformat` available in this environment (checked);
review QML changes by reading them carefully and running the applet rather
than relying on a linter.

When changing `Scene3D.qml`, confirm Qt Quick 3D is actually present
(`qmlimportscanner` or just run `plasmoidviewer`) — the fallback error
path in `main.qml`'s `Loader.onStatusChanged` is the only thing standing
between a missing dependency and a silent blank widget.

## Conventions / gotchas already found in this codebase

- `main.qml` sets `Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground`
  intentionally, and `Scene3D.qml`'s `SceneEnvironment` uses
  `backgroundMode: SceneEnvironment.Transparent`. Keep both if you want the
  widget to stay borderless/transparent — removing one without the other
  leaves a visible opaque/boxed background.
- The GitHub PAT (`cfg_githubToken`) is stored via kcfg in plain text
  (standard Plasma applet config storage, not the system keychain) and
  sent as an `Authorization: bearer` header directly from QML/JS. Don't
  log it, and don't widen its usage beyond the existing GraphQL call in
  `DataFetcher.js`.
- `DataFetcher.js` has a commented-out HTML-scraper fallback
  (`fetchWithScraper`) for tokenless use — it's unfinished/unwired, not
  dead code to delete casually; check with the user before removing or
  completing it.
- `ConfigGeneral.qml`'s color-swatch `MouseArea` calls `colorDialog.open()`
  but the `ColorDialog` itself is commented out, so clicking it currently
  throws a runtime `ReferenceError`. Known, not yet fixed.
