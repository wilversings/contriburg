# tools/

## grab_screenshot.qml

Renders `Scene3D.qml` offscreen with sample contribution data and saves it
as a **transparent** PNG. Useful for KDE Store listing screenshots, README
images, etc. — anywhere you want the skyline without a background to crop
or key out by hand.

It doesn't touch a live Plasmoid, panel, or `plasmoidviewer` at all:
`Scene3D.qml` has no `Plasmoid.configuration` dependency, so it loads the
same way here as it does under `tests/tst_scene3d.qml`. The transparency
comes from `Scene3D.qml`'s own `SceneEnvironment.Transparent` setup — this
script just grabs the rendered frame with `Item.grabToImage()`, which
preserves alpha, instead of screenshotting a real window (desktop
screenshot tools flatten transparency against whatever's behind the
window, so they won't work for this).

### Usage

Requires the `qml-qt6` binary (ships with `qt6-qtdeclarative`/
`qt6-qtdeclarative-devel`, same as `tests/`). Run from the `tools/`
directory (the script's `Loader` source path is relative to it):

```bash
cd tools
qml-qt6 grab_screenshot.qml
```

This saves `scene.png` (1200x600, fixed color mode, default green) into
the current directory.

All arguments are optional and positional:

```bash
qml-qt6 grab_screenshot.qml [outputPath] [width] [height] [colorMode] [baseColor]
```

Examples:

```bash
# Custom output path and size
qml-qt6 grab_screenshot.qml store-listing.png 1600 900

# Random color mode with a specific accent
qml-qt6 grab_screenshot.qml random-shot.png 1200 600 random

# Fixed mode with a custom base color
qml-qt6 grab_screenshot.qml blue-shot.png 1200 600 fixed "#3b82f6"
```

The rendered data is randomly generated each run (weighted so it looks
like a plausible year of activity, not sparse or maxed out), so re-running
with the same arguments produces a different-looking grid each time.

### Troubleshooting

- **Blank/empty image, exit code 1, "failed to load Scene3D.qml"**: Qt
  Quick 3D isn't installed in this environment. Same requirement as
  running the actual widget — see `AGENTS.md`.
- **No output at all**: `console.log` doesn't reliably surface from
  `qml-qt6` in some sandboxed environments — check the exit code
  (`echo $?`) and whether the output file was actually created instead of
  relying on the printed "Saved ..." message.
