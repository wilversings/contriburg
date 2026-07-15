# Contriburg

A KDE Plasma 6 widget that renders your GitHub contribution graph as an
interactive 3D skyline instead of the usual flat 2D grid. Each day is a
cube whose height and color reflect your contribution count for that day;
drag to orbit the scene, scroll to zoom, and hover a cube to see its date
and count.

## Features

- Fetches the last ~365 days of contributions from GitHub or GitLab
  (mutually exclusive, pick one in settings).
- Renders a 52x7 grid of cubes with Qt Quick 3D, scaled by contribution
  count and colored by contribution level (matching GitHub's 5-level scale).
- Orbit/zoom camera control (or lock the camera in place), per-cube hover
  tooltips.
- Configurable username, base color, height multiplier, and refresh interval.
- Transparent background so the scene blends into the panel/desktop.

## Requirements

- KDE Plasma 6 (`X-Plasma-API-Minimum-Version: 6.0`)
- Qt 6 with the **Qt Quick 3D** module installed. If it's missing, the
  widget shows an error instead of crashing.
- No account or token is strictly required for public GitHub/GitLab
  profiles — see Data sources below.

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

- **Source** — GitHub or GitLab (mutually exclusive).
- **Username** — the account to visualize.
- **Personal Access Token** (GitHub only, optional) — see Data sources below.
- **GitLab Instance URL** (GitLab only) — defaults to `https://gitlab.com`;
  point it at a self-hosted instance if needed. Must be `https://`.
- **Refresh Interval** — how often (in minutes) to re-fetch data.
- **Height Multiplier** — scales how tall the tallest bars get.
- **Color Mode** — Fixed (pick one color yourself) or Random, shown on the
  same row as either the Base Color swatch (Fixed) or a Reroll button
  (Random).

In Random mode, each day's cube independently picks one of 7 preset hues
and a random lighter/darker shade of it. Cubes reroll whenever the data
refreshes, whenever you switch into Random mode, or on demand via the
Reroll button next to the mode selector.

## Data sources

- **GitHub** — if a personal access token is set, the widget uses GitHub's
  GraphQL API (`api.github.com/graphql`), which requires one for every
  request (GitHub allows no anonymous GraphQL access at all, even for
  public data). Without a token, it falls back to scraping the public
  `github.com/users/<username>/contributions` page, which needs no
  authentication but depends on GitHub's current HTML structure and can
  break if that changes.
- **GitLab** — always uses the public, unauthenticated
  `<instance>/users/<username>/calendar.json` endpoint. No token is
  collected or used for GitLab; that endpoint doesn't authenticate via
  personal access tokens (session cookie or a separate feed token only),
  so only public profiles are supported.

## Building & packaging

To package the widget for distribution (e.g. the KDE Store), run:

```sh
./build.sh
```

This creates `build/contriburg-<version>.tar.xz` containing `contents/`
and `metadata.json`. Requires `jq` and `tar`.

To run the unit tests, run `./tests/run_tests.sh` (requires
`qmltestrunner-qt6`). See `tests/README.md` for what's covered.

## Project structure

```text
metadata.json               # Applet metadata (id, name, version, API level)
build.sh                     # Packages contents/+metadata.json into a .tar.xz for distribution
contents/
├── config/
│   ├── main.xml             # kcfg configuration schema (defaults, types)
│   └── config.qml           # ConfigModel — registers config pages
└── ui/
    ├── main.qml              # PlasmoidItem entry point, state, loading/error UI
    ├── Scene3D.qml            # View3D scene: cubes, camera, lighting, picking
    ├── ConfigGeneral.qml     # Settings UI (Kirigami.FormLayout)
    └── DataFetcher.js         # GitHub GraphQL/scraper + GitLab calendar fetch
tests/                        # QML unit tests, see tests/README.md
```

## Known limitations

- The tokenless GitHub path scrapes a public HTML page rather than calling
  a stable API, so it can silently break if GitHub changes that page's
  markup; the token-based GraphQL path is not affected.
- GitLab private profiles aren't supported — `calendar.json` only serves
  public contribution data (see Data sources above).

## License

GPL-3.0, see `metadata.json`.
