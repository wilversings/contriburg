# Contriburg — Your Contribution Graph, in 3D

Turn your GitHub or GitLab contribution graph into an interactive 3D skyline living right on your Plasma desktop. Each day becomes a cube — its height and color reflecting how much you shipped that day — that you can orbit, zoom, and hover for details.

---

## 🚀 Installation

Right-click on your Plasma desktop → **Add Widgets** → search for **Contriburg** → **Install**

---

## ✨ Features

- **Two data sources** — Visualize your GitHub or GitLab contribution graph (pick one; they're mutually exclusive).
- **True 3D skyline** — A 52×7 grid of cubes rendered with Qt Quick 3D, scaled by contribution count and colored by contribution level, just like GitHub's own 5-level scale.
- **Interactive camera** — Drag to orbit, scroll to zoom, or lock the camera in place if you'd rather it stay put.
- **Per-cube tooltips** — Hover any cube to see its exact date and contribution count.
- **Fixed or Random color mode** — Pick your own accent color, or let each cube roll its own random hue and shade from a 7-color palette, with a manual reroll button.
- **Works without a token** — Public GitHub and GitLab profiles need no account or Personal Access Token to visualize.
- **Transparent background** — Blends into the panel or desktop instead of sitting in a box.

---

## ⚙️ Configuration

Right-click the Contriburg widget and select **Configure...** to access all settings:

| Setting | Description |
|---------|-------------|
| **Source** | Switch between `GitHub` and `GitLab` |
| **Username** | The account whose contributions to visualize |
| **Personal Access Token** | GitHub only, optional — required only for the GraphQL API path; omit it to use the public tokenless fallback |
| **GitLab Instance URL** | GitLab only — defaults to `https://gitlab.com`, or point it at a self-hosted instance (`https://` required) |
| **Refresh Interval** | How often, in minutes, to re-fetch contribution data |
| **Height Multiplier** | Scales how tall the busiest days' cubes get |
| **Color Mode** | `Fixed` (pick one base color) or `Random` (each cube gets its own random shade) |
| **Base Color** | Fixed mode only — the color used for the highest contribution level |
| **Reroll** | Random mode only — instantly reshuffles every cube's color |
| **Lock Camera** | Prevents orbiting/zooming with the mouse |

---

## ⚠️ Requirements

- **KDE Plasma 6.0** or later
- **QtQuick3D**: required to render the scene. Install it via your package manager:
  - **Arch Linux / Manjaro:** `qt6-3d`
  - **Fedora:** `qt6-qtquick3d`
  - **openSUSE:** `libqt6qtquick3d`
  - **Debian / Ubuntu:** `libqt6qtquick3d6`
- A GitHub Personal Access Token (classic or fine-grained, no scopes needed) if you want the GraphQL data path; otherwise no account or token is required for either GitHub or GitLab public profiles.

---

## 🔗 Links

- **Source code:** [https://github.com/wilversings/contriburg](https://github.com/wilversings/contriburg)
- **Report issues:** [https://github.com/wilversings/contriburg/issues](https://github.com/wilversings/contriburg/issues)
