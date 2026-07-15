# Contriburg

A KDE Plasma 6 widget that renders your GitHub contribution graph as an
interactive 3D skyline instead of the usual flat 2D grid. Each day is a
cube whose height and color reflect your contribution count for that day;
drag to orbit the scene, scroll to zoom, and hover a cube to see its date
and count.

## Features

- Fetches the last 365 days of contributions via the GitHub GraphQL API.
- Renders a 52x7 grid of cubes with Qt Quick 3D, scaled by contribution
  count and colored by contribution level (matching GitHub's 5-level scale).
- Orbit/zoom camera control, per-cube hover tooltips.
- Configurable GitHub username, personal access token, base color, height
  multiplier, and refresh interval.
- Transparent background so the scene blends into the panel/desktop.

## Requirements

- KDE Plasma 6 (`X-Plasma-API-Minimum-Version: 6.0`)
- Qt 6 with the **Qt Quick 3D** module installed. If it's missing, the
  widget shows an error instead of crashing.
- A GitHub [personal access token](https://github.com/settings/tokens)
  (classic or fine-grained, no scopes needed for public contribution data)
  is required — the widget uses the GitHub GraphQL API, which does not
  allow unauthenticated requests.

## Installation

From the repository root:

```sh
kpackagetool6 --type Plasma/Applet --install .
```

To pick up changes after editing the QML during development, reinstall
with `--upgrade` instead of `--install`:

```sh
kpackagetool6 --type Plasma/Applet --upgrade .
```

Then add "Contriburg" from the widget picker, or run it standalone
without touching your live panels:

```sh
plasmoidviewer -a .
```

## Configuration

Right-click the widget and choose "Configure..." to set:

- **GitHub Username** — the account to visualize.
- **Personal Access Token** — required for API access.
- **Refresh Interval** — how often (in minutes) to re-fetch data.
- **Height Multiplier** — scales how tall the tallest bars get.
- **Base Color** — the color used for the highest contribution level.

## Project structure

```text
metadata.json               # Applet metadata (id, name, version, API level)
contents/
├── config/
│   ├── main.xml             # kcfg configuration schema (defaults, types)
│   └── config.qml           # ConfigModel — registers config pages
└── ui/
    ├── main.qml              # PlasmoidItem entry point, state, loading/error UI
    ├── Scene3D.qml            # View3D scene: cubes, camera, lighting, picking
    ├── ConfigGeneral.qml     # Settings UI (Kirigami.FormLayout)
    └── DataFetcher.js         # GitHub GraphQL request + response parsing
```

## Known limitations

- The color picker in the settings page is currently disabled (the
  `ColorDialog` is commented out in `ConfigGeneral.qml`), so the base
  color can't yet be changed from the UI.
- Only the GraphQL (token-based) data path is implemented; a tokenless
  scraper fallback is stubbed out but not wired up.

## License

GPL-3.0, see `metadata.json`.
